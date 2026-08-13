function run_lna_benchmarks(which, opts)
%RUN_LNA_BENCHMARKS  The two benchmark arms on the LNA coordinate system:
% free DC investment choice, and no pension at all. Same cube, same
% skip_polish, same anchor as run_overnight_lna, so all three are comparable.
%
%   run_lna_benchmarks                 % both
%   run_lna_benchmarks("free")         % free-tau only  (SLOW: N_tau slices)
%   run_lna_benchmarks("nodc")         % no-pension only (fast)
%   run_lna_benchmarks([], cube=[14 11 11], housing='owner')
%
%   COST. nodc is one ordinary arm. free-tau sweeps p.N_tau + 1 tau slices per
%   state at every working age, so budget roughly N_tau x a spline arm -- at
%   N_tau = 11 and cube [14 11 11] expect on the order of 6-8 h at a 4x cluster
%   factor. Cut p.N_tau (e.g. 5) if that will not fit; the tau grid always
%   includes the glide value so a coarse grid still cannot lose to the glide.
%
%   WARNING -- the free arm uses ovnf.*, a PORT. solver.bellman_step_lna
%   asserts against choose_tau_S; ovnf adds it as a pure grid sweep over
%   (c, pi, tau) with no fmincon polish on the tau axis. It has NOT been
%   validated against solver.bellman_step's free-tau branch, which additionally
%   runs a 3-var polish and a derivative-free ridge refinement. Expect the ovnf
%   free arm to be a LOWER BOUND on the true free-choice value, so the gap it
%   shows to the splines is a conservative one. Do not quote its level.

arguments
    which (1,:) string = ["nodc","free"]
    opts.housing     (1,1) string {mustBeMember(opts.housing,["owner","renter"])} = "owner"
    opts.cube        (1,3) double = [14 11 11]
    opts.n_sim       (1,1) double = 5000
    opts.skip_polish (1,1) logical = true
    opts.N_tau       (1,1) double = 11
end

OUT = utility.output_dir();
LOG = fullfile(OUT,'overnight_lna_log.txt');
if isempty(getenv('CGM_OUTPUT_DIR'))
    warning('run_lna_benchmarks:ephemeral_output', ...
        'CGM_OUTPUT_DIR unset -- results go to %s, which is ephemeral on a pod.', OUT);
end
nw = str2double(getenv('CGM_N_WORKERS'));
if ~isnan(nw) && nw >= 1
    pool = gcp('nocreate');
    if isempty(pool) || pool.NumWorkers < nw
        if ~isempty(pool), delete(pool); end
        try
            clus = parcluster('local'); clus.NumWorkers = max(clus.NumWorkers,nw);
            parpool(clus,nw);
        catch err
            fprintf('Process pool failed (%s); falling back to Threads.\n', err.message);
            parpool('Threads');
        end
    end
elseif isempty(gcp('nocreate'))
    try, parpool('Threads'); catch, try, parpool('local'); catch, end, end
end
pl = gcp('nocreate');
if isempty(pl), lp(LOG,'POOL: NONE -- SERIAL\n');
else,           lp(LOG,'POOL: %s, %d workers\n', class(pl), pl.NumWorkers); end

for a = which(:).'
    nm = sprintf('ovn_lna_%s_%s', a, opts.housing);
    out_file = fullfile(OUT,[nm '.mat']);
    if isfile(out_file), lp(LOG,'SKIP %s (exists)\n',nm); continue; end
    lp(LOG,'\n--- %s ---\n', nm); t0 = tic;

    p = config.params();
    p.is_owner    = (opts.housing == "owner");
    p.skip_polish = opts.skip_polish;
    p.legacy_fill = false;
    p.N_u1 = opts.cube(1); p.N_u2 = opts.cube(2); p.N_u3 = opts.cube(3);
    p.u1_grid = linspace(0,1,p.N_u1).';
    p.u2_grid = linspace(0,1,p.N_u2).';
    p.u3_grid = linspace(0,1,p.N_u3).';

    switch a
        case "nodc"
            p.kappa = 0;                 % no DC second pillar; AOW still on
            p.choose_tau_S = false;
        case "free"
            p.choose_tau_S = true;       % per-state DC share while working
            p.N_tau = opts.N_tau;
        otherwise
            error('run_lna_benchmarks:which','unknown arm "%s"', a);
    end

    [~,mg,sl] = config.income_profile(p);
    profile   = struct('mu_growth',mg,'sigma_l_log',sl,'p_surv',config.survival(p));
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);

    p.grid_type = 'lna';        % cube solve; asserted by both LNA solvers
    if a == "free"
        sol = ovnf.solve_lifecycle_lna(p, profile, shocks, ann_price);
        sim = ovnf.paths_lna(p, profile, sol, ann_price, opts.n_sim, 20260511, p.b0);
    else
        sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);
        sim = simulate.paths_lna(p, profile, sol, ann_price, opts.n_sim, 20260511, p.b0);
    end

    den  = p.b0 + p.h_mult + 1;
    lam0 = 1/den;  sH0 = p.h_mult/den;
    u1 = lam0;  u2 = sH0/(1-lam0);  u3 = 0;
    F  = griddedInterpolant({p.u1_grid,p.u2_grid,p.u3_grid}, sol.V(:,:,:,1),'linear','nearest');
    % knot_* kept so compare/analyse read these arms with the same code path.
    welfare0 = struct('Vt0_b0',F(u1,u2,u3),'u',[u1 u2 u3],'b0',p.b0, ...
                      'knot_ages',[p.age0 p.retirement_age p.age0+p.T-2], ...
                      'knot_fracs',[NaN NaN NaN],'arm',char(a));
    strat_info = struct('name',char(a),'type',['lna_' char(a)], ...
        'knot_ages',welfare0.knot_ages,'knot_fracs',welfare0.knot_fracs, ...
        'housing',char(opts.housing));
    timing = sol.timing;
    save(out_file,'p','profile','shocks','ann_price','sol','sim', ...
                  'strat_info','timing','welfare0','-v7.3');
    lp(LOG,'  Vt0_b0 = %.10g | LW<0 in %.2f%% of hh-years | %.1f min\n', ...
        welfare0.Vt0_b0, 100*sim.diagnostics.n_negLW/numel(sim.C), toc(t0)/60);
end
end

function lp(f,varargin)
    m = sprintf(varargin{:}); fprintf('%s',m);
    fid = fopen(f,'a'); if fid>=0, fprintf(fid,'%s',m); fclose(fid); end
end
