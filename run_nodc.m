% RUN_NODC  No-DC-account benchmark at the current calibration, for comparison
% against the glide and free-DC runs.
%
%   Two scenarios with kappa = 0, so the DC second pillar is off. The AOW
%   first pillar is still on; tau_S and the annuity are irrelevant with no DC
%   balance.
%     renter_nodc (is_owner = false), owner_nodc (is_owner = true).
%
%   Solved on the same grid as run_combined (utility.production_grid, for
%   whichever coordinate system CGM_GRID selects -- the cube by default) and at
%   the same calibration, so welfare0 is directly comparable to
%   combined_{renter,owner}{,_freetau}[_lna].mat. Saves
%   combined_{renter,owner}_nodc[_lna].mat with the welfare0 convention: corner
%   Vt0, the calibrated b0 / b_alt anchors, and the b_grid sensitivity curve.
%
%   This is the no-pension benchmark the comparison scripts look for. The
%   older combined_*_kappa0.mat name is a pre-tax-change vintage and is not
%   comparable; the comparison scripts load _nodc first and fall back to
%   _kappa0 only for legacy folders.

clear; clc;
if isempty(gcp('nocreate'))
    try, parpool('Threads'); catch, warning('no pool'); end
end

scenarios = struct('name', {'renter_nodc', 'owner_nodc'}, ...
                   'is_owner', {false, true});
N_sim = 10000;

for k = 1:numel(scenarios)
    sc = scenarios(k);
    fprintf('\n=== Scenario: %s (no DC account, kappa=0) ===\n', sc.name);
    p = config.params();
    p.is_owner     = sc.is_owner;
    p.kappa        = 0;
    p.choose_tau_S = false;

    % Same production grid as run_combined and run_spline_strategies.
    % build_state_grids also inserts the welfare anchors, so the realised axis
    % sizes can exceed the requested dims -- read them off p. CGM_STATE_GRID /
    % CGM_GH_N override only for smoke runs.
    [dims_sweep, gh_sweep] = utility.production_grid(p);
    p = utility.build_state_grids(p, dims_sweep, gh_sweep);
    fprintf('  grid: %s, requested [%d %d %d] gh_n=%d -> [%d %d %d]\n', ...
        p.grid_type, dims_sweep(1), dims_sweep(2), dims_sweep(3), gh_sweep, ...
        utility.grid_sizes(p));
    p = assert_production_fill(p);

    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth   = mu_growth;
    profile.sigma_l_log = sigma_l_log;
    profile.p_surv      = config.survival(p);
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);

    fprintf('  kappa=%.3f (DC off), alpha=%.3f, theta=%.3f, h_mult=%.1f, tau_inc=%.3f, tau_wealth=%.4f\n', ...
        max(p.kappa), p.alpha, p.theta, p.h_mult, p.tau_inc, p.tau_wealth);

    sol = solver.solve(p, profile, shocks, ann_price);
    fprintf('  Solver: %.1f s (%d workers)\n', sol.elapsed, sol.timing.pool.num_workers);

    welfare0 = utility.welfare_summary(p, sol.V(:,:,:,1));
    fprintf('  V_tilde0 = %.6g (corner, b=0) | %.6g at b0=%.4f | %.6g at b_alt=%.4f\n', ...
        welfare0.Vt0, welfare0.Vt0_b0, welfare0.b0, welfare0.Vt0_b_alt, welfare0.b_alt);

    sim = simulate.forward(p, profile, sol, ann_price, N_sim);
    timing = sol.timing;

    fname = fullfile(utility.output_dir(), ...
        sprintf('combined_%s%s.mat', sc.name, utility.grid_suffix(p)));
    save(fname, 'p', 'profile', 'shocks', 'ann_price', 'sol', 'sim', 'sc', 'timing', 'welfare0');
    fprintf('  Saved %s\n', fname);
end
fprintf('\nNo-DC benchmark done.\n');

function p = assert_production_fill(p)
% p.legacy_fill selects an old continuation-fill rule (used by
% tests/smoke_fill_fix) and must be off for a production run. Setting it to
% false explicitly, rather than leaving it absent, is what the fingerprint
% records so this run is never ranked against one made with the old rule.
assert(~(isfield(p, 'legacy_fill') && p.legacy_fill), 'run_nodc:legacy_fill', ...
    'p.legacy_fill is set, which is a test-only continuation fill.');
p.legacy_fill = false;
end
