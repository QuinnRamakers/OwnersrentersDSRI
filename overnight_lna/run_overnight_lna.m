function run_overnight_lna(slice, opts)
%RUN_OVERNIGHT_LNA  Overnight cluster job: the DC equity-share frontier solved
% on the LNA (u1,u2,u3) coordinate system instead of the (lambda,s_A,s_H)
% simplex. Uses solver.solve_lifecycle_lna and simulate.paths_lna unmodified.
%
%   run_overnight_lna                    % all 5 arms, ~7.4 h at 4x local
%   run_overnight_lna(1:3)               % instance A
%   run_overnight_lna(4:5)               % instance B
%   run_overnight_lna([], housing='renter')
%
%   WHY THIS RUN. Four ways of computing welfare on the identical model
%   disagree about the SIGN of the DC equity effect (2026-08-05 diagnosis).
%   CEV vs the tau = 0 arm, owner, at the b0 anchor:
%
%       tau    simplex N_sA=15   simplex N_sA=31   LNA cube   simulated E[U]
%              (production)
%       0.50        -5.62%            -2.99%        +1.84%        +7.95%
%       1.00       -14.61%            -5.20%        +1.64%        +8.69%
%
%   The production simplex grid is the only one of the four that ranks tau = 0
%   first. One suspect is solver.build_fill_map: the simplex feasible set is a
%   simplex, so infeasible cube nodes must be filled, and that fill sits one
%   interpolation cell from the sX = 0 face where the welfare anchor lives. The
%   LNA coordinates
%       u1 = lambda,  u2 = (A+H)/(W-Y),  u3 = A/(A+H)
%   map the whole cube onto feasible simplex points, so there is NO fill at
%   all and the DC gets its own axis (u3) rather than a 15-node s_A share.
%   This job extends the 3-point LNA check to a full 5-point frontier.
%
%   WHAT THIS RUN DOES NOT SETTLE. At gamma = 5 roughly 60% of E[U] comes from
%   the worst 1% of paths, and production leaves that region undefined --
%   solver.bellman_step_lna charges V = -1e15 when LW <= 0 while
%   simulate.paths_lna sets C = 0 and forgives the shortfall, i.e. the two
%   sides solve different models exactly where the welfare weight sits. Until
%   both carry the same consumption floor, a ranking that the value function
%   and the simulation disagree about is not decidable. compare_overnight_lna
%   reports both so you can see whether they line up.
%
%   OUTPUT  ovn_lna_flat{TTT}_{housing}.mat with a top-level welfare0 carrying
%   Vt0_b0, read at the b0 anchor mapped into u-coordinates. Resume-safe:
%   existing files are skipped, so a killed job can just be relaunched.
%   Rank with:  compare_overnight_lna
%
%   BUDGET  ~22 min/arm locally on 16 cores at the default cube, so ~89 min/arm
%   at a 4x cluster factor -> 5 arms ~ 7.4 h. Watch the per-arm time printed
%   for arm 1: if it is well over 90 min, kill and relaunch with a smaller
%   opts.cube rather than losing the night. Arms save individually, so an
%   overrun costs you the last arm, not the run.

arguments
    slice (1,:) double = []
    opts.housing    (1,1) string {mustBeMember(opts.housing,["owner","renter"])} = "owner"
    opts.taus       (1,:) double = [0 0.25 0.50 0.75 1.00]
    opts.cube       (1,3) double = [18 14 14]
    opts.n_sim      (1,1) double = 5000
    opts.skip_polish(1,1) logical = true    % grid search only; ~5-10x faster
end

OUT  = utility.output_dir();
LOG  = fullfile(OUT,'overnight_lna_log.txt');
taus = opts.taus;
if isempty(slice), slice = 1:numel(taus); end
slice = slice(slice >= 1 & slice <= numel(taus));

lp(LOG,'\n%s\novernight_lna start %s\n', repmat('=',1,64), datestr(now,'yyyy-mm-dd HH:MM:SS'));
lp(LOG,'housing=%s  cube=[%d %d %d]  skip_polish=%d  n_sim=%d\n', ...
    opts.housing, opts.cube, opts.skip_polish, opts.n_sim);
lp(LOG,'arms in this slice: %s\n%s\n', mat2str(taus(slice)), repmat('-',1,64));

for i = slice(:).'
    f  = taus(i);
    nm = sprintf('ovn_lna_flat%03d_%s', round(100*f), opts.housing);
    out_file = fullfile(OUT,[nm '.mat']);
    if isfile(out_file), lp(LOG,'SKIP %s (exists)\n',nm); continue; end
    lp(LOG,'\n--- %s ---\n', nm); t0 = tic;

    p = config.params();
    p.is_owner     = (opts.housing == "owner");
    p.choose_tau_S = false;          % bellman_step_lna asserts against free tau
    p.skip_polish  = opts.skip_polish;
    p.legacy_fill  = false;
    % Flat accumulation share with a cliff to 0 at retirement, so the
    % decumulation share is common to every arm. The production menu cannot do
    % this: its knots sit at [age0, retirement_age, age0+T-2], so knots 2-3
    % silently set the retirement share too (see strategy.menu).
    p.tau_S = strategy.spline_tau(p, ...
        [p.age0, p.retirement_age-1, p.retirement_age, p.age0+p.T-2], [f f 0 0]);
    p.N_u1 = opts.cube(1); p.N_u2 = opts.cube(2); p.N_u3 = opts.cube(3);
    p.u1_grid = linspace(0,1,p.N_u1).';
    p.u2_grid = linspace(0,1,p.N_u2).';
    p.u3_grid = linspace(0,1,p.N_u3).';

    [~,mg,sl] = config.income_profile(p);
    profile   = struct('mu_growth',mg,'sigma_l_log',sl,'p_surv',config.survival(p));
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);

    sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);

    % Welfare anchor at the calibrated buffer b0, mapped into u-coordinates:
    %   lambda = 1/(b0+h_mult+1), s_A = 0, s_H = h_mult/(b0+h_mult+1)
    % so u1 = lambda, u2 = s_H/(1-lambda), u3 = 0.
    den  = p.b0 + p.h_mult + 1;
    lam0 = 1/den;  sH0 = p.h_mult/den;
    u1 = lam0;  u2 = sH0/(1-lam0);  u3 = 0;
    F  = griddedInterpolant({p.u1_grid,p.u2_grid,p.u3_grid}, sol.V(:,:,:,1), ...
                            'linear','nearest');
    welfare0 = struct('Vt0_b0',F(u1,u2,u3),'u',[u1 u2 u3],'b0',p.b0,'tau_flat',f);

    sim = simulate.paths_lna(p, profile, sol, ann_price, opts.n_sim, 20260511, p.b0);
    strat_info = struct('name',nm,'type','lna_flat','tau_flat',f, ...
                        'housing',char(opts.housing));
    timing = sol.timing;
    save(out_file,'p','profile','shocks','ann_price','sol','sim', ...
                  'strat_info','timing','welfare0','-v7.3');
    lp(LOG,'  Vt0_b0 = %.10g | LW<0 in %.2f%% of hh-years | solver %.0f s | TOTAL %.1f min\n', ...
        welfare0.Vt0_b0, 100*sim.diagnostics.n_negLW/numel(sim.C), sol.elapsed, toc(t0)/60);
end
lp(LOG,'\novernight_lna slice done %s\n%s\n', datestr(now,'yyyy-mm-dd HH:MM:SS'), repmat('=',1,64));
end

function lp(f,varargin)
    m = sprintf(varargin{:});
    fprintf('%s',m);
    fid = fopen(f,'a'); if fid>=0, fprintf(fid,'%s',m); fclose(fid); end
end
