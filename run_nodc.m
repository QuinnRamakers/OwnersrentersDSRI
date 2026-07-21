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
%   Saves combined_{renter,owner}_nodc.mat with the welfare0 convention.

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

    % Match run_combined's production sweep grid.
    p.gh_n = 5; p.N_lambda = 25; p.N_sA = 15; p.N_sH = 15;
    p.lambda_grid = linspace(0, 1, p.N_lambda).';
    p.sA_grid     = linspace(0, 1, p.N_sA).';
    p.sH_grid     = linspace(0, 1, p.N_sH).';

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

    lam0 = 1 / (1 + p.h_mult);
    sH0  = p.h_mult / (1 + p.h_mult);
    V0f  = fill_nan_nearest_3d(sol.V(:,:,:,1));
    Fv   = griddedInterpolant({p.lambda_grid, p.sA_grid, p.sH_grid}, V0f, 'linear', 'nearest');
    welfare0 = struct('Vt0', Fv(lam0, 0, sH0), 'lam0', lam0, 'sA0', 0, 'sH0', sH0, 'gamma', p.gamma);
    fprintf('  V_tilde0 = %.6g\n', welfare0.Vt0);

    sim = simulate.paths(p, profile, sol, ann_price, N_sim);
    timing = sol.timing;

    fname = fullfile(utility.output_dir(), sprintf('combined_%s.mat', sc.name));
    save(fname, 'p', 'profile', 'shocks', 'ann_price', 'sol', 'sim', 'sc', 'timing', 'welfare0');
    fprintf('  Saved %s\n', fname);
end
fprintf('\nNo-DC benchmark done.\n');

function Z = fill_nan_nearest_3d(M)
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
