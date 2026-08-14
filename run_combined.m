% RUN_COMBINED  Solve and simulate the combined pension+housing model.
%
%   Four scenarios, tenure x DC-investment regime. The contribution rate is
%   the franchise-based age profile p.kappa from config.params, roughly
%   10.9%-14.6% over the working life. The kappa = 0 no-pension benchmark
%   lives in run_nodc.m.
%     1) renter          glide tau_S; pays alpha * H_t per period.
%     2) owner           glide tau_S; pays (theta + m_rate_t) * H_t, bequest +H.
%     3) renter_freetau  choose_tau_S = true: the DC equity share is a free
%                        per-state choice, benchmarking the value of free
%                        pension investment choice against the glide plan.
%     4) owner_freetau   same, owner tenure.
%   All four scenarios solve on both coordinate systems. The cube grew free DC
%   choice in the solver, and simulate.paths_lna now reads sol.tau_pol, so the
%   freetau arms no longer have to be skipped there.
%
%   Saves combined_{renter,owner}[_freetau].mat, with an _lna suffix on the
%   cube so the two coordinate systems never overwrite each other -- see
%   utility.grid_suffix for why the cube keeps the suffix even as the default.
%   Every save carries a small top-level `welfare0` struct (V_tilde at the
%   initial state) so scenarios can be welfare-ranked without loading sol/sim.
%
%   Grid system (CGM_GRID), via utility.active_grid:
%     lna (default) : (u1,u2,u3) cube, every point feasible -- see
%                     solver.bellman_step_lna. CGM_SKIP_POLISH=1 also skips
%                     the fmincon polish.
%     simplex       : (lambda, s_A, s_H), the maintained alternative.
%   Either way the grid comes from utility.production_grid, which is also what
%   run_nodc and run_spline_strategies read, so all three stay welfare-
%   comparable within a coordinate system. Across the two they are not, and
%   utility.param_fingerprint enforces that.
%
%   Set CGM_N_WORKERS to force an n-worker process pool -- useful on the
%   cluster pod, and where the Threads profile is capped at 2.
%
%   Requires the Optimization and Parallel Computing toolboxes. Budget roughly
%   ten minutes per scenario on 16 cores on the simplex sweep grid; the cube
%   default carries many more live states, so see utility.production_grid.

clear; clc;

grid_type = utility.active_grid();
use_lna   = strcmp(grid_type, 'lna');

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
    'name',       {'renter', 'owner', 'renter_freetau', 'owner_freetau'}, ...
    'is_owner',   {false,    true,    false,            true           }, ...
    'choose_tau', {false,    false,   true,             true           } );

N_sim = 10000;

for k = 1:numel(scenarios)
    sc = scenarios(k);
    fprintf('\n=== Scenario: %s (grid: %s) ===\n', sc.name, grid_type);
    p = config.params();
    p.is_owner = sc.is_owner;
    p.choose_tau_S = sc.choose_tau;

    % The one grid definition run_nodc and run_spline_strategies also read, so
    % all three stay welfare-comparable within a coordinate system.
    % build_state_grids rebuilds the axis vectors AND re-inserts the welfare
    % anchors, so two of the three come back up to +2 larger -- read the sizes
    % off p, never off the requested dims. CGM_STATE_GRID / CGM_GH_N override
    % for smoke runs only; unset (the production path) they are a no-op.
    [dims_sweep, gh_sweep] = utility.production_grid(p);
    p = utility.build_state_grids(p, dims_sweep, gh_sweep);
    if use_lna
        fprintf('  grid: requested [%d %d %d] gh_n=%d -> N_u1=%d N_u2=%d N_u3=%d\n', ...
            dims_sweep(1), dims_sweep(2), dims_sweep(3), gh_sweep, ...
            p.N_u1, p.N_u2, p.N_u3);
    else
        fprintf('  grid: requested [%d %d %d] gh_n=%d -> N_lambda=%d N_sA=%d N_sH=%d\n', ...
            dims_sweep(1), dims_sweep(2), dims_sweep(3), gh_sweep, ...
            p.N_lambda, p.N_sA, p.N_sH);
    end
    p = assert_production_fill(p);

    if use_lna && strcmp(getenv('CGM_SKIP_POLISH'), '1')
        p.skip_polish = true;
    end

    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth   = mu_growth;
    profile.sigma_l_log = sigma_l_log;
    profile.p_surv      = config.survival(p);
    shocks = grids.shock_grid(p);

    ann_price = pension.annuity_price(p, profile, shocks);

    kap_w = config.kappa_path(p); kap_w = kap_w(1 : p.t_ret - 1);
    fprintf('  kappa_t=%.3f-%.3f (franchise-based), alpha=%.3f, theta=%.3f, h_mult=%.1f\n', ...
        min(kap_w), max(kap_w), p.alpha, p.theta, p.h_mult);
    if sc.choose_tau
        fprintf('  DC equity share: FREE per-state choice (N_tau=%d); annuity still priced off the tau_S glide\n', ...
            p.N_tau);
    else
        fprintf('  tau_S glide: t=1 -> %.2f, t_ret-1 -> %.2f\n', ...
            p.tau_S(1), p.tau_S(p.t_ret-1));
    end
    fprintf('  ann_price(t_ret)=%.3f\n', ann_price(p.t_ret));
    if sc.is_owner
        fprintf('  mortgage rate (years 1..%d): %.4f per period\n', ...
            p.N_mort, p.m_rate_path(1));
    end

    if use_lna
        fprintf('  lna grid %dx%dx%d (%d states, all feasible), skip_polish=%d\n', ...
            p.N_u1, p.N_u2, p.N_u3, p.N_u1*p.N_u2*p.N_u3, p.skip_polish);
    end
    sol = solver.solve(p, profile, shocks, ann_price);
    fprintf('  Solver: %.1f s  (pool: %s, %d workers, host: %s)\n', ...
        sol.elapsed, sol.timing.pool.type, sol.timing.pool.num_workers, sol.timing.hostname);

    % Welfare summary at the initial state (see utility.welfare_summary):
    % V(W,state) = W^(1-gamma) * V_tilde(state); saved top-level so
    % compare_spline_strategies.m (and similar) can read Vt0 via matfile
    % without loading the big sol/sim arrays -- same convention as
    % run_spline_strategies.m. Both coordinate systems now: utility.welfare_anchor
    % reads the cube's (u1,u2) anchor as an exact node exactly as it reads the
    % simplex's (lambda,s_H), so Vt0 means the same thing on either grid.
    welfare0 = utility.welfare_summary(p, sol.V(:,:,:,1));
    fprintf('  V_tilde0 = %.6g (corner, b=0) | %.6g at b0=%.4f | %.6g at b_alt=%.4f\n', ...
        welfare0.Vt0, welfare0.Vt0_b0, welfare0.b0, welfare0.Vt0_b_alt, welfare0.b_alt);

    t_sim = tic;
    sim = simulate.forward(p, profile, sol, ann_price, N_sim);
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

    fname = fullfile(utility.output_dir(), ...
        sprintf('combined_%s%s.mat', sc.name, utility.grid_suffix(p)));
    save(fname, 'p', 'profile', 'shocks', 'ann_price', 'sol', 'sim', 'sc', 'timing', 'welfare0');
    fprintf('  Saved %s\n', fname);
end

fprintf('\nAll scenarios done.\n');

%% =======================================================================
function p = assert_production_fill(p)
% PRODUCTION GUARD -- see run_nodc.m for the full rationale. Short version:
% p.legacy_fill restores the pre-fix continuation fill (a ruin-blended
% penalty one interpolation cell wide along the sX = 0 face, which is where
% the welfare anchor sits) and is test-only. Stamping false explicitly is
% what makes utility.param_fingerprint fence pre-fix files off from post-fix
% ones -- an absent field fingerprints as NaN on BOTH vintages.
assert(~(isfield(p, 'legacy_fill') && p.legacy_fill), 'run_combined:legacy_fill', ...
    'p.legacy_fill is set -- that is the pre-fix phantom-penalty fill, test-only.');
p.legacy_fill = false;
end
