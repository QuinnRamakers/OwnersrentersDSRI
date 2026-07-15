% RUN_COMBINED  Solve and simulate the combined pension+housing model.
%
%   Four scenarios, is_owner x kappa:
%     1) Renter        (is_owner = false, kappa = p.kappa default): pays
%        alpha * H_t per period.
%     2) Owner         (is_owner = true,  kappa = p.kappa default): pays
%        (theta + m_rate_t) * H_t; bequest +H.
%     3) Renter_kappa0 (is_owner = false, kappa = 0): NO-DC-PENSION
%        benchmark -- isolates the DC pension's welfare contribution by
%        comparison against scenario 1 (same housing tenure, pension off).
%     4) Owner_kappa0  (is_owner = true,  kappa = 0): same benchmark, owner
%        tenure.
%   AOW (first pillar) is always on; only the DC second pillar (kappa) is
%   toggled by the kappa0 scenarios. tau_S glide path and annuitisation at
%   t_ret still apply whenever kappa > 0.
%
%   Saves combined_renter.mat, combined_owner.mat, combined_renter_kappa0.mat,
%   and combined_owner_kappa0.mat in this directory (with an _lna suffix
%   when the cube grid is selected, so the two grid systems never overwrite
%   each other's results). Simplex-path saves also carry a small top-level
%   `welfare0` struct (V_tilde at the initial state), same convention as
%   run_spline_strategies.m, so e.g. the renter_kappa0/owner_kappa0 files
%   can be read as a "no pension" welfare benchmark without loading sol/sim.
%
%   Grid system (CGM_GRID environment variable):
%     simplex (default) : (lambda, s_A, s_H) grid, sized to MATCH
%                         run_spline_strategies.m's default sweep grid
%                         (state 25x15x15, gh_n=5 -> 125 joint nodes), not
%                         the full 40^3/gh_n=7 production grid -- so
%                         welfare (V_tilde) numbers from run_combined and
%                         run_spline_strategies are directly comparable
%                         (see that function's own docstring: "All sweep
%                         runs must share gh_n/state_grid"). If you need
%                         the full production grid instead, remove the
%                         grid-override block below.
%     lna               : (u1,u2,u3) = (lambda, n-tilde, a) cube grid, every
%                         point feasible, 28x20x20 = 11,200 states -- see
%                         solver.bellman_step_lna. CGM_SKIP_POLISH=1
%                         additionally skips the fmincon polish (~15% faster,
%                         policies accurate to the 41x41 inner grid). NOT
%                         matched to run_spline_strategies.m (which has no
%                         lna path) -- lna outputs are not welfare-comparable
%                         to the spline sweep regardless of grid size.
%   Workers: set CGM_N_WORKERS to force an n-worker PROCESS pool (use on the
%   cluster pod, and on laptops where the 'Threads' profile is capped at 2).
%
%   Requires Optimization Toolbox and Parallel Computing Toolbox. At this
%   reduced grid, one scenario measured ~17 min on a laptop (2-worker
%   Threads pool) vs ~2 min on the cluster (per-job timings from
%   spline_strategies_log.txt at the same grid) -- so expect ~1-1.5h total
%   on a laptop or ~8-10 min total on the cluster for all four scenarios.

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
    'name',     {'renter', 'owner', 'renter_kappa0', 'owner_kappa0'}, ...
    'is_owner', {false,    true,    false,           true          }, ...
    'kappa',    {NaN,      NaN,     0,               0             } );

N_sim = 5000;

for k = 1:numel(scenarios)
    sc = scenarios(k);
    fprintf('\n=== Scenario: %s (grid: %s) ===\n', sc.name, grid_type);
    p = config.params();
    p.is_owner = sc.is_owner;
    if ~isnan(sc.kappa)
        p.kappa = sc.kappa;
    end

    % Match run_spline_strategies.m's default sweep grid (state 25x15x15,
    % gh_n=5) instead of config.params()'s full 40^3/gh_n=7 production
    % grid, so V_tilde welfare numbers from this script are directly
    % comparable to the spline-strategy sweep. Only applies to the simplex
    % path -- lna has no equivalent in run_spline_strategies to match.
    if ~use_lna
        p.gh_n     = 5;
        p.N_lambda = 25;
        p.N_sA     = 15;
        p.N_sH     = 15;
        p.lambda_grid = linspace(0, 1, p.N_lambda).';
        p.sA_grid     = linspace(0, 1, p.N_sA).';
        p.sH_grid     = linspace(0, 1, p.N_sH).';
    end

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

    % Welfare summary at the initial state (see welfare_dc_strategies.m):
    % V(W,state) = W^(1-gamma) * V_tilde(state); saved top-level so
    % compare_spline_strategies.m (and similar) can read Vt0 via matfile
    % without loading the big sol/sim arrays -- same convention as
    % run_spline_strategies.m. Simplex path only: lna uses different state
    % coordinates (u1,u2,u3) with no equivalent consumer to match today.
    if ~use_lna
        lam0 = 1 / (1 + p.h_mult);
        sH0  = p.h_mult / (1 + p.h_mult);
        V0f  = fill_nan_nearest_3d(sol.V(:,:,:,1));
        Fv   = griddedInterpolant({p.lambda_grid, p.sA_grid, p.sH_grid}, ...
                                  V0f, 'linear', 'nearest');
        welfare0 = struct('Vt0', Fv(lam0, 0, sH0), 'lam0', lam0, 'sA0', 0, ...
                          'sH0', sH0, 'gamma', p.gamma);
        fprintf('  V_tilde0 = %.6g\n', welfare0.Vt0);
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
function Z = fill_nan_nearest_3d(M)
% Same boundary-NaN helper as run_spline_strategies.m / welfare_dc_strategies.m
% -- the initial state sits exactly on the feasibility boundary, so 'linear'
% interpolation would pick up a NaN corner.
Z = M;
if ~any(isnan(Z(:))), return; end
[NL, NA, NH] = size(Z);
mask_ok = ~isnan(Z);
[Ig, Jg, Kg] = ndgrid(1:NL, 1:NA, 1:NH);
I_ok = Ig(mask_ok); J_ok = Jg(mask_ok); K_ok = Kg(mask_ok); V_ok = Z(mask_ok);
I_bad = Ig(~mask_ok); J_bad = Jg(~mask_ok); K_bad = Kg(~mask_ok);
for k = 1:numel(I_bad)
    di = I_bad(k) - I_ok; dj = J_bad(k) - J_ok; dk = K_bad(k) - K_ok;
    d2 = di.*di + dj.*dj + dk.*dk;
    [~, q] = min(d2);
    Z(I_bad(k), J_bad(k), K_bad(k)) = V_ok(q);
end
end
