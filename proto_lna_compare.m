% PROTO_LNA_COMPARE  Validate the (u1,u2,u3) = (lambda, n-tilde, a) cube grid
% against the production (lambda, s_A, s_H) simplex grid.
%
%   Solves ONE scenario (renter) both ways at matched state counts, using
%   IDENTICAL params/profile/shocks/ann_price built ONCE from config.params()
%   in this script. NEVER load params from stored .mat files here -- they
%   embed stale calibrations and silently void the comparison.
%
%   Modes (PROTO_MODE env var):
%     smoke (default): old 11^3 cube (286 feasible)   vs new 8x6x6    = 288
%     full           : old 40^3 cube (11480 feasible) vs new 28x20x20 = 11200
%
%   Other env switches:
%     PROTO_SKIP_POLISH  '1' (default): the NEW arm skips the fmincon polish
%                        (grid-search only, ~5-10x faster; policies accurate
%                        to the 41x41 inner grid spacing ~0.025). The OLD arm
%                        runs production solver.bellman_step, which always
%                        polishes -- so with skip on, up to ~0.02 of the
%                        reported |dc|/|dpi| is polish-vs-grid quantisation,
%                        not grid-geometry error. Set '0' for full fidelity.
%     PROTO_N_WORKERS    parallel workers (default: feature('numcores')).
%                        NOTE this laptop's 'Threads' profile caps at 2
%                        workers, so a PROCESS pool is created explicitly.
%
%   Invariant check: Y, A and H are policy-independent processes, so with the
%   same seed both simulations must reproduce them EXACTLY (bit-identical);
%   otherwise the shock plumbing differs and the comparison is void.
%
%   Pass criterion: INTERIOR (sX >= 0.15) mean |dc| and |dpi| at old-sim
%   visited states of order the grid spacing (~0.02-0.05) at every probe
%   age, no age-localized blowups. Boundary (sX < 0.05) stats are reported
%   separately: the old grid's z_min fill contaminates interpolation cells
%   straddling the sX=0 plane, so boundary disagreement reflects the OLD
%   arm's known bias, shrinking only with resolution (smoke diagnosis
%   2026-07-13: at t=T-1 interior arms agree to dc~0.007/dpi~0.03/dz~0.003;
%   boundary dz was already 0.60 one step from terminal).
%
%   Cluster use (bootstrap_pod.m pod): commit+push, run bootstrap_pod, then
%     setenv('PROTO_MODE','full'); setenv('PROTO_SKIP_POLISH','1');
%     setenv('PROTO_N_WORKERS','32'); proto_lna_compare
%   (skip_polish first; rerun with '0' for the full-fidelity pass).

clear; clc;

% ---------------------------------------------------------------- config --
mode = getenv('PROTO_MODE');
if isempty(mode), mode = 'smoke'; end
switch lower(mode)
    case 'smoke'
        N_old = 11;  Nu = [8, 6, 6];
    case 'full'
        N_old = 40;  Nu = [28, 20, 20];
    otherwise
        error('proto_lna_compare:mode', 'PROTO_MODE must be smoke or full, got "%s"', mode);
end

sp_env = getenv('PROTO_SKIP_POLISH');
if isempty(sp_env), sp_env = '1'; end
skip_polish = ~strcmp(sp_env, '0');

nw = str2double(getenv('PROTO_N_WORKERS'));
if isnan(nw) || nw < 1, nw = feature('numcores'); end

fprintf('=== proto_lna_compare: mode=%s, old grid %d^3, new grid %dx%dx%d, ', ...
        mode, N_old, Nu(1), Nu(2), Nu(3));
fprintf('skip_polish(new arm)=%d, workers=%d ===\n', skip_polish, nw);

% Process pool ('Threads' is capped at 2 workers on hybrid-CPU laptops)
pool = gcp('nocreate');
if isempty(pool) || pool.NumWorkers ~= nw || isa(pool, 'parallel.ThreadPool')
    if ~isempty(pool), delete(pool); end
    clus = parcluster('local');
    clus.NumWorkers = max(clus.NumWorkers, nw);
    parpool(clus, nw);
end

% -------------------------------- shared inputs, built ONCE, used by BOTH --
p_base = config.params();
p_base.is_owner = false;                      % renter scenario

[~, mu_growth, sigma_l_log] = config.income_profile(p_base);
profile.mu_growth   = mu_growth;
profile.sigma_l_log = sigma_l_log;
profile.p_surv      = config.survival(p_base);
shocks    = grids.shock_grid(p_base);
ann_price = pension.annuity_price(p_base, profile, shocks);

fprintf('shared inputs: kappa=%.3f, gamma=%.1f, mu_S_level=%.3f, tau_inc=%.2f, ann_price(t_ret)=%.3f\n', ...
        p_base.kappa, p_base.gamma, p_base.mu_S_level, p_base.tau_inc, ann_price(p_base.t_ret));

% ----------------------------------------------- arm 1: old simplex grid --
p_old = p_base;
p_old.N_lambda = N_old; p_old.N_sA = N_old; p_old.N_sH = N_old;
p_old.lambda_grid = linspace(0, 1, N_old).';
p_old.sA_grid     = linspace(0, 1, N_old).';
p_old.sH_grid     = linspace(0, 1, N_old).';
[Lg, Ag, Hg] = ndgrid(p_old.lambda_grid, p_old.sA_grid, p_old.sH_grid);
n_feas_old = nnz(Lg + Ag + Hg <= 1 + 1e-12);
fprintf('\n--- OLD arm: %d^3 = %d cube points, %d feasible (%.1f%%), polish always ON ---\n', ...
        N_old, N_old^3, n_feas_old, 100 * n_feas_old / N_old^3);

sol_old = solver.solve_lifecycle(p_old, profile, shocks, ann_price);
fprintf('OLD solve: %.1f s (%s, %d workers)\n', sol_old.elapsed, ...
        sol_old.timing.pool.type, sol_old.timing.pool.num_workers);

% ------------------------------------------------- arm 2: new cube grid --
p_new = p_base;
p_new.u1_grid = linspace(0, 1, Nu(1)).';
p_new.u2_grid = linspace(0, 1, Nu(2)).';
p_new.u3_grid = linspace(0, 1, Nu(3)).';
p_new.skip_polish = skip_polish;
fprintf('\n--- NEW arm: %dx%dx%d = %d cube points, all feasible, skip_polish=%d ---\n', ...
        Nu(1), Nu(2), Nu(3), prod(Nu), skip_polish);

sol_new = solver.solve_lifecycle_lna(p_new, profile, shocks, ann_price);
fprintf('NEW solve: %.1f s (%s, %d workers)\n', sol_new.elapsed, ...
        sol_new.timing.pool.type, sol_new.timing.pool.num_workers);

% ------------------------------------------------------------- simulate --
N_sim = 5000;                                 % default seed 20260511 in both
sim_old = simulate.paths(p_old, profile, sol_old, ann_price, N_sim);
sim_new = simulate.paths_lna(p_new, profile, sol_new, ann_price, N_sim);

% -------------------------------------- invariant: exogenous paths match --
dY = max(abs(sim_old.Y(:) - sim_new.Y(:)));
dA = max(abs(sim_old.A(:) - sim_new.A(:)));
dH = max(abs(sim_old.H(:) - sim_new.H(:)));
fprintf('\n--- Invariant check (must be EXACTLY 0) ---\n');
fprintf('max|dY| = %g, max|dA| = %g, max|dH| = %g\n', dY, dA, dH);
assert(dY == 0 && dA == 0 && dH == 0, ...
       'proto_lna_compare:invariant', ...
       'Exogenous paths differ between arms -- shock plumbing mismatch, comparison VOID.');
fprintf('OK: Y, A, H paths bit-identical across arms.\n');

% ------------------------- policy diffs at OLD-sim visited states per age --
% Stratified by distance to the simplex boundary sX = 1-lam-sA-sH: the old
% grid fills infeasible cube nodes with z_min, which drags interpolated
% continuation values down in every cell straddling the sX=0 plane, so the
% two discretizations legitimately disagree there at coarse resolution (the
% old arm is the contaminated one; see 2026-07-13 smoke diagnosis). The
% verdict below therefore uses INTERIOR (sX >= 0.15) means; boundary stats
% and the CE-per-unit-wealth ratio z_new/z_old are reported for convergence
% tracking across resolutions.
ages_probe = [30, 50, 65, 75];
omg = 1 - p_base.gamma;
fprintf('\n--- Diffs at old-sim visited states: INTERIOR sX>=0.15 | BOUNDARY sX<0.05 ---\n');
fprintf('  age  n_int  mean|dc|  mean|dpi|  mean|dz/z| | n_bnd  mean|dc|  mean|dpi|  mean|dz/z|\n');
worst_mean = 0;
diag_diffs = struct('age', {}, 'mean_dc_int', {}, 'mean_dpi_int', {}, 'mean_dz_int', {}, ...
                    'mean_dc_bnd', {}, 'mean_dpi_bnd', {}, 'mean_dz_bnd', {});
for a = ages_probe
    t = a - p_base.age0 + 1;
    lam = sim_old.lambda(:,t); sA = sim_old.sA(:,t); sH = sim_old.sH(:,t);
    sX  = 1 - lam - sA - sH;
    int_m = sX >= 0.15;  bnd_m = sX < 0.05;
    u1  = min(max(lam, 0), 1);
    sAH = sA + sH;
    u2  = min(max(sAH ./ max(1 - lam, 1e-12), 0), 1);
    u3  = min(max(sA ./ max(sAH, 1e-12), 0), 1);
    Fc  = griddedInterpolant({p_new.u1_grid, p_new.u2_grid, p_new.u3_grid}, ...
                             sol_new.c_pol(:,:,:,t), 'linear', 'nearest');
    Fpi = griddedInterpolant({p_new.u1_grid, p_new.u2_grid, p_new.u3_grid}, ...
                             sol_new.pi_pol(:,:,:,t), 'linear', 'nearest');
    Fz_new = z_interp({p_new.u1_grid, p_new.u2_grid, p_new.u3_grid}, sol_new.V(:,:,:,t), omg);
    Fz_old = z_interp({p_old.lambda_grid, p_old.sA_grid, p_old.sH_grid}, sol_old.V(:,:,:,t), omg);
    c_new_v  = min(max(Fc(u1, u2, u3), 0), 1);
    pi_new_v = min(max(Fpi(u1, u2, u3), 0), 1);
    dc  = abs(sim_old.c_frac(:,t) - c_new_v);      % old-sim policies are the
    dpi = abs(sim_old.pi(:,t)    - pi_new_v);      % clamped interpolated values
    dz  = abs(Fz_new(u1, u2, u3) ./ Fz_old(lam, sA, sH) - 1);
    fprintf('  %3d  %5d  %8.4f  %9.4f  %10.4f | %5d  %8.4f  %9.4f  %10.4f\n', a, ...
            nnz(int_m), mean(dc(int_m)), mean(dpi(int_m)), mean(dz(int_m)), ...
            nnz(bnd_m), mean(dc(bnd_m)), mean(dpi(bnd_m)), mean(dz(bnd_m)));
    worst_mean = max([worst_mean, mean(dc(int_m)), mean(dpi(int_m))]);
    diag_diffs(end+1) = struct('age', a, ...
        'mean_dc_int', mean(dc(int_m)), 'mean_dpi_int', mean(dpi(int_m)), 'mean_dz_int', mean(dz(int_m)), ...
        'mean_dc_bnd', mean(dc(bnd_m)), 'mean_dpi_bnd', mean(dpi(bnd_m)), 'mean_dz_bnd', mean(dz(bnd_m))); %#ok<SAGROW>
end

% ------------------------------------------------------ simulated moments --
fprintf('\n--- Simulated moments, old | new ---\n');
fprintf('  age    mean pi          mean C           mean X           mean W\n');
for a = ages_probe
    t = a - p_base.age0 + 1;
    fprintf('  %3d  %6.3f|%6.3f  %7.3f|%7.3f  %7.3f|%7.3f  %7.3f|%7.3f\n', a, ...
            mean(sim_old.pi(:,t)), mean(sim_new.pi(:,t)), ...
            mean(sim_old.C(:,t)),  mean(sim_new.C(:,t)), ...
            mean(sim_old.X(:,t)),  mean(sim_new.X(:,t)), ...
            mean(sim_old.W(:,t)),  mean(sim_new.W(:,t)));
end
fprintf('  mean bequest: %.3f | %.3f\n', mean(sim_old.bequest), mean(sim_new.bequest));
fprintf('  clamp diagnostics old: c=%d pi=%d negLW=%d | new: c=%d pi=%d negLW=%d\n', ...
        sim_old.diagnostics.n_clamp_c, sim_old.diagnostics.n_clamp_pi, sim_old.diagnostics.n_negLW, ...
        sim_new.diagnostics.n_clamp_c, sim_new.diagnostics.n_clamp_pi, sim_new.diagnostics.n_negLW);

% ---------------------------------------------------------------- verdict --
tol_mean = 0.05;    % of order the state/inner grid spacing
if worst_mean <= tol_mean
    fprintf('\nPASS: all INTERIOR mean policy diffs <= %.2f (worst %.4f).\n', tol_mean, worst_mean);
else
    fprintf('\nCHECK: worst INTERIOR mean policy diff %.4f exceeds %.2f -- inspect per-age table above.\n', ...
            worst_mean, tol_mean);
end
fprintf('Solve time old %.1f s vs new %.1f s (new arm skip_polish=%d).\n', ...
        sol_old.elapsed, sol_new.elapsed, skip_polish);

% ------------------------------------------------------------------- save --
out = fullfile(utility.output_dir(), sprintf('proto_lna_%s.mat', lower(mode)));
save(out, 'p_old', 'p_new', 'profile', 'shocks', 'ann_price', ...
     'sol_old', 'sol_new', 'sim_old', 'sim_new', 'diag_diffs', ...
     'skip_polish', 'N_sim', '-v7.3');
fprintf('Saved %s\n', out);

% -------------------------------------------------------- local functions --
function F = z_interp(gridcell, V, omg)
% CE-per-unit-wealth interpolant z = ((1-gamma)V)^(1/(1-gamma)), with the
% same z_min fill for non-finite nodes the solvers use (old-grid infeasible
% NaNs and cash-infeasible -1e15 sentinels both end up at z_min).
z = omg * V; z(z <= 0) = NaN; z = z .^ (1/omg);
z_min = min(z(isfinite(z)), [], 'all');
z(~isfinite(z)) = z_min;
F = griddedInterpolant(gridcell, z, 'linear', 'linear');
end
