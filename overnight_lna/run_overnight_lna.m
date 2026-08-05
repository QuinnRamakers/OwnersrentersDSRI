function run_overnight_lna(strats, opts)
%RUN_OVERNIGHT_LNA  Solve as many glide-path strategies as fit a wall-clock
% budget, on the LNA (u1,u2,u3) coordinate system instead of the simplex.
%
%   run_overnight_lna                              % menu([0 .5 1]), 8 h budget
%   run_overnight_lna(strategy.menu(0:0.25:1))     % the 35-strategy grid
%   run_overnight_lna([], budget_hours=6)
%   run_overnight_lna(M(1:18))                     % explicit slice
%
%   Stops starting new arms once the projected finish would exceed
%   budget_hours, using the running mean of completed arms as the estimate, so
%   the job ends cleanly instead of being killed mid-solve. Resume-safe: arms
%   already on disk are skipped, so relaunching continues where it stopped.
%
%   WHY LNA COORDINATES. Four ways of computing welfare on the identical model
%   disagree about the SIGN of the DC equity effect (2026-08-05). CEV vs the
%   tau = 0 arm, owner, at the b0 anchor:
%
%       tau    simplex N_sA=15   simplex N_sA=31   LNA cube   simulated E[U]
%              (production)
%       0.50        -5.62%            -2.99%        +1.84%        +7.95%
%       1.00       -14.61%            -5.20%        +1.64%        +8.69%
%
%   The production simplex is the only one of the four that ranks tau = 0
%   first. One suspect is solver.build_fill_map: the simplex feasible set needs
%   its infeasible cube nodes filled, and that fill sits one interpolation cell
%   from the sX = 0 face where the welfare anchor lives. The LNA map
%   u1 = lambda, u2 = (A+H)/(W-Y), u3 = A/(A+H) makes every cube point
%   feasible, so there is no fill at all and the DC gets its own axis.
%
%   TWO THINGS THIS RUN CANNOT SETTLE, both of which matter for reading it:
%     1. Resolution. Halving the s_A spacing on the simplex removed 47-64% of
%        the measured tau penalty and Richardson extrapolation spanned zero.
%        Cheap arms mean a coarse cube, which is the same lever. If you want
%        many strategies, take the count from opts.cube knowingly.
%     2. The left tail. At gamma = 5 roughly 60% of E[U] comes from the worst
%        1% of paths, and production leaves that region undefined -- the solver
%        charges V = -1e15 when LW <= 0 while simulate.paths_lna sets C = 0 and
%        forgives the shortfall. compare_overnight_lna reports the
%        value-function and simulated rankings side by side; if they disagree,
%        the ranking is not decidable without a consumption floor carried by
%        both sides.
%
%   NOTE ON THE MENU FAMILY. strategy.menu puts its knots at
%   [age0, retirement_age, age0+T-2], so knots 2-3 set the RETIREMENT equity
%   share as well as the glide. Two menu entries can differ far more in
%   decumulation than in accumulation -- at the b0 anchor the accumulation axis
%   was worth ~4 CEV points and the decumulation knot ~13. Read the ranking as
%   over (glide, decumulation) pairs, not over glides.
%
%   OUTPUT  ovn_lna_{strategy}_{housing}.mat with a top-level welfare0 carrying
%   Vt0_b0 read at the b0 anchor in u-coordinates. Rank with
%   compare_overnight_lna.

arguments
    strats = []
    opts.housing      (1,1) string {mustBeMember(opts.housing,["owner","renter"])} = "owner"
    opts.budget_hours (1,1) double {mustBePositive} = 8
    opts.cube         (1,3) double = [14 11 11]
    opts.n_sim        (1,1) double = 5000
    opts.skip_polish  (1,1) logical = true
    opts.arm_est_min  (1,1) double = 45     % prior for arm 1, cluster minutes
end

if isempty(strats), strats = strategy.menu([0 0.5 1]); end
assert(isstruct(strats) && all(isfield(strats,{'name','knot_ages','knot_fracs'})), ...
    'run_overnight_lna:badinput', ...
    'strats must be a struct array with name/knot_ages/knot_fracs (see strategy.menu).');

OUT = utility.output_dir();
LOG = fullfile(OUT,'overnight_lna_log.txt');

% Loud guard: unset CGM_OUTPUT_DIR sends a long run to the current folder,
% which on a cluster pod is ephemeral and wiped on restart.
if isempty(getenv('CGM_OUTPUT_DIR'))
    warning('run_overnight_lna:ephemeral_output', ...
        ['CGM_OUTPUT_DIR is not set, so results go to the current folder:\n' ...
         '    %s\n' ...
         'On a cluster pod that is ephemeral. Set it to a mounted volume\n' ...
         '(export CGM_OUTPUT_DIR=/data) and relaunch, or accept the risk.'], OUT);
end

lp(LOG,'\n%s\novernight_lna start %s\n', repmat('=',1,68), datestr(now,'yyyy-mm-dd HH:MM:SS'));
lp(LOG,'housing=%s  cube=[%d %d %d]  skip_polish=%d  n_sim=%d\n', ...
    opts.housing, opts.cube, opts.skip_polish, opts.n_sim);
lp(LOG,'budget %.1f h over %d candidate strategies (%s ... %s)\n%s\n', ...
    opts.budget_hours, numel(strats), strats(1).name, strats(end).name, repmat('-',1,68));

t_wall = tic;  done = 0;  est_min = opts.arm_est_min;  manifest = {};

for i = 1:numel(strats)
    st = strats(i);
    nm = sprintf('ovn_lna_%s_%s', st.name, opts.housing);
    out_file = fullfile(OUT,[nm '.mat']);
    if isfile(out_file), lp(LOG,'SKIP %s (exists)\n',nm); continue; end

    elapsed_h   = toc(t_wall)/3600;
    projected_h = elapsed_h + est_min/60;
    if projected_h > opts.budget_hours
        lp(LOG,['\nBUDGET STOP after %d arm(s): %.2f h used, next arm ~%.0f min\n' ...
                'would land at %.2f h against a %.1f h budget. %d strategies\n' ...
                'left unsolved -- relaunch to continue, finished arms are kept.\n'], ...
            done, elapsed_h, est_min, projected_h, opts.budget_hours, numel(strats)-i+1);
        break
    end

    lp(LOG,'\n--- [%d/%d] %s  (%.2f h used, ~%.0f min/arm) ---\n', ...
        i, numel(strats), nm, elapsed_h, est_min);
    lp(LOG,'    knots: ages [%s] fracs [%s]\n', ...
        strjoin(compose('%.0f',st.knot_ages),' '), strjoin(compose('%.2f',st.knot_fracs),' '));
    t0 = tic;

    p = config.params();
    p.is_owner     = (opts.housing == "owner");
    p.choose_tau_S = false;          % bellman_step_lna asserts against free tau
    p.skip_polish  = opts.skip_polish;
    p.legacy_fill  = false;
    p.tau_S = strategy.spline_tau(p, st.knot_ages, st.knot_fracs);
    p.N_u1 = opts.cube(1); p.N_u2 = opts.cube(2); p.N_u3 = opts.cube(3);
    p.u1_grid = linspace(0,1,p.N_u1).';
    p.u2_grid = linspace(0,1,p.N_u2).';
    p.u3_grid = linspace(0,1,p.N_u3).';

    [~,mg,sl] = config.income_profile(p);
    profile   = struct('mu_growth',mg,'sigma_l_log',sl,'p_surv',config.survival(p));
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);

    sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);

    % Welfare anchor at the calibrated buffer b0, in u-coordinates:
    %   lambda = 1/(b0+h_mult+1), s_A = 0, s_H = h_mult/(b0+h_mult+1)
    den  = p.b0 + p.h_mult + 1;
    lam0 = 1/den;  sH0 = p.h_mult/den;
    u1 = lam0;  u2 = sH0/(1-lam0);  u3 = 0;
    F  = griddedInterpolant({p.u1_grid,p.u2_grid,p.u3_grid}, sol.V(:,:,:,1), ...
                            'linear','nearest');
    welfare0 = struct('Vt0_b0',F(u1,u2,u3),'u',[u1 u2 u3],'b0',p.b0, ...
                      'knot_fracs',st.knot_fracs,'knot_ages',st.knot_ages);

    sim = simulate.paths_lna(p, profile, sol, ann_price, opts.n_sim, 20260511, p.b0);
    strat_info = struct('name',st.name,'type','lna_spline', ...
        'knot_ages',st.knot_ages,'knot_fracs',st.knot_fracs,'housing',char(opts.housing));
    timing = sol.timing;
    save(out_file,'p','profile','shocks','ann_price','sol','sim', ...
                  'strat_info','timing','welfare0','-v7.3');

    arm_min = toc(t0)/60;  done = done + 1;
    est_min = ((done-1)*est_min + arm_min)/done;      % running mean
    manifest{end+1} = {st.name, arm_min};             %#ok<AGROW>
    lp(LOG,'    Vt0_b0 = %.10g | LW<0 in %.2f%% of hh-years | %.1f min\n', ...
        welfare0.Vt0_b0, 100*sim.diagnostics.n_negLW/numel(sim.C), arm_min);
    if done == 1
        lp(LOG,'    >> first arm took %.1f min; budget %.1f h projects ~%d arms total\n', ...
            arm_min, opts.budget_hours, max(1,floor(opts.budget_hours*60/arm_min)));
    end
end

lp(LOG,'\n%s\nDONE %s -- %d arm(s) in %.2f h\n', repmat('=',1,68), ...
    datestr(now,'yyyy-mm-dd HH:MM:SS'), done, toc(t_wall)/3600);
for k = 1:numel(manifest)
    lp(LOG,'  %-24s %.1f min\n', manifest{k}{1}, manifest{k}{2});
end
lp(LOG,'%s\n', repmat('=',1,68));
end

function lp(f,varargin)
    m = sprintf(varargin{:});
    fprintf('%s',m);
    fid = fopen(f,'a'); if fid>=0, fprintf(fid,'%s',m); fclose(fid); end
end
