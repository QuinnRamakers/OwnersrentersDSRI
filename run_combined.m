% RUN_COMBINED  Solve and simulate the combined pension+housing model.
%
%   Two scenarios:
%     1) Renter (is_owner = false): pays alpha * H_t per period.
%     2) Owner  (is_owner = true ): pays (theta + m_rate_t) * H_t; bequest +H.
%   Pension is ON in both (kappa > 0, tau_S glide path, annuitisation at t_ret).
%
%   Saves combined_renter.mat and combined_owner.mat in this directory.
%
%   Requires Optimization Toolbox and Parallel Computing Toolbox. At the
%   production grid (40x40x40 states, 7x7x7 shock nodes) each scenario takes
%   roughly 1-2 hours on a 16-core machine; both scenarios run sequentially.

clear; clc;

if isempty(gcp('nocreate'))
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
    fprintf('\n=== Scenario: %s ===\n', sc.name);
    p = config.params();
    p.is_owner = sc.is_owner;

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

    sol = solver.solve_lifecycle(p, profile, shocks, ann_price);
    fprintf('  Solver: %.1f s  (pool: %s, %d workers, host: %s)\n', ...
        sol.elapsed, sol.timing.pool.type, sol.timing.pool.num_workers, sol.timing.hostname);

    t_sim = tic;
    sim = simulate.paths(p, profile, sol, ann_price, N_sim);
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

    fname = sprintf('combined_%s.mat', sc.name);
    save(fname, 'p', 'profile', 'shocks', 'ann_price', 'sol', 'sim', 'sc', 'timing');
    fprintf('  Saved %s\n', fname);
end

fprintf('\nBoth scenarios done.\n');
