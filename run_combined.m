% RUN_COMBINED  Solve and simulate the combined pension+housing model.
%
%   Two scenarios:
%     1) Renter (is_owner = false): pays alpha * H_t per period.
%     2) Owner  (is_owner = true ): pays (theta + m_rate_t) * H_t; bequest +H.
%   Pension is ON in both (kappa > 0, tau_S glide path, annuitisation at t_ret).
%
%   Saves combined_renter.mat and combined_owner.mat in this directory
%   (with an _lna suffix when the cube grid is selected, so the two grid
%   systems never overwrite each other's results).
%
%   Grid system (CGM_GRID environment variable):
%     simplex (default) : production (lambda, s_A, s_H) grid, 40^3 cube with
%                         feasibility mask (11,480 feasible states).
%     lna               : (u1,u2,u3) = (lambda, n-tilde, a) cube grid, every
%                         point feasible, 28x20x20 = 11,200 states -- see
%                         solver.bellman_step_lna. CGM_SKIP_POLISH=1
%                         additionally skips the fmincon polish (~15% faster,
%                         policies accurate to the 41x41 inner grid).
%   Workers: set CGM_N_WORKERS to force an n-worker PROCESS pool (use on the
%   cluster pod, and on laptops where the 'Threads' profile is capped at 2).
%
%   Requires Optimization Toolbox and Parallel Computing Toolbox. At the
%   production grid (40x40x40 states, 7x7x7 shock nodes) each scenario takes
%   roughly 1-2 hours on a 16-core machine; both scenarios run sequentially.

clear; clc;

grid_type = getenv('CGM_GRID');
if isempty(grid_type), grid_type = 'simplex'; end
assert(any(strcmp(grid_type, {'simplex', 'lna'})), ...
       'CGM_GRID must be ''simplex'' or ''lna'', got ''%s''', grid_type);
use_lna = strcmp(grid_type, 'lna');

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
            % Cluster pods can fail to start process workers; Threads spans
            % all cores in one process and handles fmincon fine.
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

scenarios = struct( ...
    'name',  {'renter', 'owner'}, ...
    'is_owner', {false,   true } );

N_sim = 5000;

for k = 1:numel(scenarios)
    sc = scenarios(k);
    fprintf('\n=== Scenario: %s (grid: %s) ===\n', sc.name, grid_type);
    p = config.params();
    p.is_owner = sc.is_owner;
    if use_lna && strcmp(getenv('CGM_SKIP_POLISH'), '1')
        p.skip_polish = true;
    end

    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth   = mu_growth;
    profile.sigma_l_log = sigma_l_log;
    profile.p_surv      = config.survival(p);
    shocks = grids.shock_grid(p);

    ann_price = pension.annuity_price(p, profile, shocks);

    fprintf('  kappa=%.3f, alpha=%.3f, theta=%.3f, h_mult=%.1f\n', ...
        p.kappa, p.alpha, p.theta, p.h_mult);
    fprintf('  tau_S glide: t=1 -> %.2f, t_ret-1 -> %.2f\n', ...
        p.tau_S(1), p.tau_S(p.t_ret-1));
    fprintf('  ann_price(t_ret)=%.3f\n', ann_price(p.t_ret));
    if sc.is_owner
        fprintf('  mortgage rate (years 1..%d): %.4f per period\n', ...
            p.N_mort, p.m_rate_path(1));
    end

    if use_lna
        fprintf('  lna grid %dx%dx%d (%d states, all feasible), skip_polish=%d\n', ...
            p.N_u1, p.N_u2, p.N_u3, p.N_u1*p.N_u2*p.N_u3, p.skip_polish);
        sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);
    else
        sol = solver.solve_lifecycle(p, profile, shocks, ann_price);
    end
    fprintf('  Solver: %.1f s  (pool: %s, %d workers, host: %s)\n', ...
        sol.elapsed, sol.timing.pool.type, sol.timing.pool.num_workers, sol.timing.hostname);

    t_sim = tic;
    if use_lna
        sim = simulate.paths_lna(p, profile, sol, ann_price, N_sim);
    else
        sim = simulate.paths(p, profile, sol, ann_price, N_sim);
    end
    sim_elapsed = toc(t_sim);
    fprintf('  Simulated %d households in %.1f s\n', N_sim, sim_elapsed);

    % Quick summary at three ages
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

    suffix = ''; if use_lna, suffix = '_lna'; end
    fname = fullfile(utility.output_dir(), sprintf('combined_%s%s.mat', sc.name, suffix));
    save(fname, 'p', 'profile', 'shocks', 'ann_price', 'sol', 'sim', 'sc', 'timing');
    fprintf('  Saved %s\n', fname);
end

fprintf('\nBoth scenarios done.\n');
