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
%   The freetau scenarios are skipped under CGM_GRID=lna -- choose_tau_S is a
%   simplex-solver feature and bellman_step_lna asserts against it.
%
%   Saves combined_{renter,owner}[_freetau].mat here, with an _lna suffix on
%   the cube grid so the two grid systems never overwrite each other.
%   Simplex saves carry a small top-level `welfare0` struct (V_tilde at the
%   initial state) so scenarios can be welfare-ranked without loading sol/sim.
%
%   Grid system (CGM_GRID):
%     simplex (default) : (lambda, s_A, s_H), sized to MATCH
%                         run_spline_strategies' default sweep grid
%                         (25x15x15, gh_n=5) rather than the full 40^3/gh_n=7
%                         production grid, so welfare numbers from the two
%                         scripts are directly comparable. Remove the
%                         grid-override block below if you want production.
%     lna               : (u1,u2,u3) cube grid, every point feasible -- see
%                         solver.bellman_step_lna. CGM_SKIP_POLISH=1 also
%                         skips the fmincon polish. Not matched to
%                         run_spline_strategies, so lna output is not
%                         welfare-comparable to the sweep at any grid size.
%
%   Set CGM_N_WORKERS to force an n-worker process pool -- useful on the
%   cluster pod, and where the Threads profile is capped at 2.
%
%   Requires the Optimization and Parallel Computing toolboxes. At this grid,
%   budget roughly ten minutes per scenario on 16 cores.

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
    'name',       {'renter', 'owner', 'renter_freetau', 'owner_freetau'}, ...
    'is_owner',   {false,    true,    false,            true           }, ...
    'choose_tau', {false,    false,   true,             true           } );

N_sim = 10000;

for k = 1:numel(scenarios)
    sc = scenarios(k);
    if use_lna && sc.choose_tau
        fprintf('\n=== Scenario: %s SKIPPED (choose_tau_S unsupported on the lna grid) ===\n', sc.name);
        continue
    end
    fprintf('\n=== Scenario: %s (grid: %s) ===\n', sc.name, grid_type);
    p = config.params();
    p.is_owner = sc.is_owner;
    p.choose_tau_S = sc.choose_tau;

    % Match run_spline_strategies.m's default sweep grid (state 25x15x15,
    % gh_n=5) instead of config.params()'s full 40^3/gh_n=7 production
    % grid, so V_tilde welfare numbers from this script are directly
    % comparable to the spline-strategy sweep. Only applies to the simplex
    % path -- lna has no equivalent in run_spline_strategies to match.
    if ~use_lna
        % build_state_grids rebuilds the linspaces AND re-inserts the welfare
        % anchors, so N_lambda/N_sH come back +2 -- read them off p, never off
        % the requested dims.
        % CGM_STATE_GRID / CGM_GH_N override the sweep grid for smoke runs
        % only; unset (the production path) they are a no-op. See
        % utility.grid_override.
        [dims_sweep, gh_sweep] = utility.grid_override([25 15 15], 5);
        p = utility.build_state_grids(p, dims_sweep, gh_sweep);
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
        sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);
    else
        sol = solver.solve_lifecycle(p, profile, shocks, ann_price);
    end
    fprintf('  Solver: %.1f s  (pool: %s, %d workers, host: %s)\n', ...
        sol.elapsed, sol.timing.pool.type, sol.timing.pool.num_workers, sol.timing.hostname);

    % Welfare summary at the initial state (see welfare_dc_strategies.m):
    % V(W,state) = W^(1-gamma) * V_tilde(state); saved top-level so
    % compare_spline_strategies.m (and similar) can read Vt0 via matfile
    % without loading the big sol/sim arrays -- same convention as
    % run_spline_strategies.m. Simplex path only: lna uses different state
    % coordinates (u1,u2,u3) with no equivalent consumer to match today.
    if ~use_lna
        welfare0 = utility.welfare_summary(p, sol.V(:,:,:,1));
        fprintf('  V_tilde0 = %.6g (corner, b=0) | %.6g at b0=%.4f | %.6g at b_alt=%.4f\n', ...
            welfare0.Vt0, welfare0.Vt0_b0, welfare0.b0, welfare0.Vt0_b_alt, welfare0.b_alt);
    end

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
    if ~use_lna
        save(fname, 'p', 'profile', 'shocks', 'ann_price', 'sol', 'sim', 'sc', 'timing', 'welfare0');
    else
        save(fname, 'p', 'profile', 'shocks', 'ann_price', 'sol', 'sim', 'sc', 'timing');
    end
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
