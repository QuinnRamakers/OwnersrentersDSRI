% RUN_NODC  No-DC-account benchmark at the CURRENT calibration + production
% grid, for comparison against the free-DC-choice (freetau) runs.
%
%   Two scenarios (kappa = 0, so the DC second pillar is OFF; AOW first
%   pillar still on, tau_S/annuity irrelevant with no DC balance):
%     renter_nodc (is_owner=false), owner_nodc (is_owner=true).
%   Same simplex grid as run_combined (25x15x15, gh_n=5) so welfare0.Vt0 is
%   directly comparable to combined_{renter,owner}{,_freetau}.mat, and the
%   same tax calibration (tau_inc=0.376, tau_wealth=0.0197) so these are the
%   correct no-pension baseline for THIS vintage (the old
%   combined_*_kappa0.mat are a pre-tax-change vintage -- do NOT reuse).
%   Saves combined_{renter,owner}_nodc.mat with the welfare0 convention
%   (utility.welfare_summary: corner Vt0, the calibrated b0 / b_alt anchors,
%   and the b_grid sensitivity curve).
%
%   This IS the no-pension benchmark the comparison scripts look for. The old
%   combined_*_kappa0.mat name was retired with run_combined's kappa=0
%   scenarios on 2026-07-16; compare_spline_strategies and
%   compare_strategy_vs_nopension load _nodc first and only fall back to
%   _kappa0 for legacy folders.

clear; clc;
if isempty(gcp('nocreate'))
    try, parpool('Threads'); catch, warning('no pool'); end
end

scenarios = struct('name', {'renter_nodc', 'owner_nodc'}, ...
                   'is_owner', {false, true});
N_sim = 5000;

for k = 1:numel(scenarios)
    sc = scenarios(k);
    fprintf('\n=== Scenario: %s (no DC account, kappa=0) ===\n', sc.name);
    p = config.params();
    p.is_owner     = sc.is_owner;
    p.kappa        = 0;
    p.choose_tau_S = false;

    % Match run_combined's production sweep grid. build_state_grids rebuilds
    % the linspaces AND re-inserts the welfare anchors, so N_lambda/N_sH come
    % back +2 -- read them off p, never off the requested dims.
    p = utility.build_state_grids(p, [25 15 15], 5);
    p = assert_production_fill(p);

    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth   = mu_growth;
    profile.sigma_l_log = sigma_l_log;
    profile.p_surv      = config.survival(p);
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);

    fprintf('  kappa=%.3f (DC off), alpha=%.3f, theta=%.3f, h_mult=%.1f, tau_inc=%.3f, tau_wealth=%.4f\n', ...
        p.kappa, p.alpha, p.theta, p.h_mult, p.tau_inc, p.tau_wealth);

    sol = solver.solve_lifecycle(p, profile, shocks, ann_price);
    fprintf('  Solver: %.1f s (%d workers)\n', sol.elapsed, sol.timing.pool.num_workers);

    welfare0 = utility.welfare_summary(p, sol.V(:,:,:,1));
    fprintf('  V_tilde0 = %.6g (corner, b=0) | %.6g at b0=%.4f | %.6g at b_alt=%.4f\n', ...
        welfare0.Vt0, welfare0.Vt0_b0, welfare0.b0, welfare0.Vt0_b_alt, welfare0.b_alt);

    sim = simulate.paths(p, profile, sol, ann_price, N_sim);
    timing = sol.timing;

    fname = fullfile(utility.output_dir(), sprintf('combined_%s.mat', sc.name));
    save(fname, 'p', 'profile', 'shocks', 'ann_price', 'sol', 'sim', 'sc', 'timing', 'welfare0');
    fprintf('  Saved %s\n', fname);
end
fprintf('\nNo-DC benchmark done.\n');

function p = assert_production_fill(p)
% PRODUCTION GUARD. p.legacy_fill is a TEST-ONLY switch in
% solver.bellman_step that restores the pre-fix continuation fill (infeasible
% cube nodes filled with the global minimum feasible z, i.e. the z-image of
% the -1e15 ruin assignment) so tests/smoke_fill_fix.m can A/B it. It puts a
% ruin-blended penalty one interpolation cell wide along the entire sX = 0
% face -- which is exactly where the welfare anchor sits. Nothing solved with
% it may be presented as a result.
%
% Setting the field to false explicitly (rather than leaving it absent) is
% load-bearing: utility.param_fingerprint reads absent fields as NaN, so a
% stamped post-fix file ("legacy_fill=0") fingerprints differently from a
% pre-fix file that never had the field ("legacy_fill=NaN") and the two can
% never be ranked together. Leave the field absent and both read NaN.
assert(~(isfield(p, 'legacy_fill') && p.legacy_fill), 'run_nodc:legacy_fill', ...
    'p.legacy_fill is set -- that is the pre-fix phantom-penalty fill, test-only.');
p.legacy_fill = false;
end
