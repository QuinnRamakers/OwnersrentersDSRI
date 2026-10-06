% RUN_COMBINED  Solve and simulate the model.
% This function will solve an renter and an owner
%
%   Set CGM_N_WORKERS to force an n-worker process pool. For a quick smoke run,
%   set CGM_STATE_GRID (e.g. "8 6 6") and CGM_GH_N (e.g. "3"), small N_sim depending on your runtime.
%
%   Requires the Optimization and Parallel Computing toolboxes.

clear; clc;

%  an explicit worker count via CGM_N_WORKERS, else default threads pool
%  (then processes or in series). Threads is required to run on the DSRI

nw = str2double(getenv('CGM_N_WORKERS'));
if ~isnan(nw) && nw >= 1
    pool = gcp('nocreate');
    if isempty(pool) || pool.NumWorkers < nw
        if ~isempty(pool), delete(pool); end
        try
            clus = parcluster('local');
            clus.NumWorkers = max(clus.NumWorkers, nw);
            parpool(clus, nw);
        catch err
            fprintf('Process pool failed (%s); falling back to Threads.\n', err.message);
            parpool('Threads');
        end
    end
elseif isempty(gcp('nocreate'))
    try
        parpool('Threads');
    catch
        try, parpool('local'); catch, warning('parpool failed; running serial'); end
    end
end

%makes the storage of thescenario
scenarios = struct('name', {'renter', 'owner'}, 'is_owner', {false, true});

N_sim = 10000;

%loop to call the actual model solver for a given scenario or configuration
for k = 1:numel(scenarios)
    sc = scenarios(k);
    fprintf('\n=== Scenario: %s (LNA cube) ===\n', sc.name);
    p = config.params();
    p.is_owner = sc.is_owner;

    % Makes the grid and hardcodes in a welfare evaluation point such that
    % that point is always on the grid and not interpolated
    [dims, gh] = utility.production_grid(p);
    p = utility.build_state_grids(p, dims, gh);
    fprintf('  grid: requested [%d %d %d] gh_n=%d -> N_u1=%d N_u2=%d N_u3=%d\n', ...
        dims(1), dims(2), dims(3), gh, p.N_u1, p.N_u2, p.N_u3);

    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth   = mu_growth;
    profile.sigma_l_log = sigma_l_log;
    profile.p_surv      = config.survival(p);
    shocks = grids.shock_grid(p);

    ann_price = pension.annuity_price(p, profile, shocks);

    kap_w = config.kappa_path(p); kap_w = kap_w(1 : p.t_ret - 1);
    fprintf('  kappa_t=%.3f-%.3f (franchise-based), alpha=%.3f, theta=%.3f, h_mult=%.1f\n', ...
        min(kap_w), max(kap_w), p.alpha, p.theta, p.h_mult);
    fprintf('  tau_S glide: t=1 -> %.2f, t_ret-1 -> %.2f\n', ...
        p.tau_S(1), p.tau_S(p.t_ret-1));
    fprintf('  ann_price(t_ret)=%.3f\n', ann_price(p.t_ret));
    if sc.is_owner
        fprintf('  mortgage rate (years 1..%d): %.4f per period\n', ...
            p.N_mort, p.m_rate_path(1));
    end
    fprintf('  lna grid %dx%dx%d (%d states, all feasible)\n', ...
        p.N_u1, p.N_u2, p.N_u3, p.N_u1*p.N_u2*p.N_u3);

    sol = solver.solve(p, profile, shocks, ann_price);
    fprintf('  Solver: %.1f s  (pool: %s, %d workers, host: %s)\n', ...
        sol.elapsed, sol.timing.pool.type, sol.timing.pool.num_workers, sol.timing.hostname);

%SIMULATE
    t_sim = tic;
    sim = simulate.forward(p, profile, sol, ann_price, N_sim);
    sim_elapsed = toc(t_sim);
    fprintf('  Simulated %d households in %.1f s\n', N_sim, sim_elapsed);

        %SUMMARY STATISTICS
    ages_probe = [30, 50, 65];
    fprintf('  age   mean pi    mean C     mean LW    mean A     mean H\n');
    for a = ages_probe
        t = a - p.age0 + 1;
        fprintf('  %3d  %8.4f  %9.3f  %9.3f  %9.3f  %9.3f\n', ...
                a, mean(sim.pi(:,t)), mean(sim.C(:,t)), ...
                mean(sim.LW(:,t)), mean(sim.A(:,t)), mean(sim.H(:,t)));
    end

    timing = sol.timing;
    timing.sim_sec = sim_elapsed;

    fname = fullfile(utility.output_dir(), ...
        sprintf('combined_%s%s.mat', sc.name, utility.grid_suffix(p)));
    save(fname, 'p', 'profile', 'shocks', 'ann_price', 'sol', 'sim', 'sc', 'timing');
    fprintf('  Saved %s\n', fname);
end

fprintf('\nAll scenarios done.\n');
