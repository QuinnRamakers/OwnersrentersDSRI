function smoke_reit()
%SMOKE_REIT  Minimal end-to-end check of the DC REIT extension (LNA cube).
%   Tiny grid + skip_polish + small N, per the "keep verification runs short"
%   rule. Checks the shock-grid active/inactive gate, a full backward solve,
%   the annuity, and a forward simulation, both with the REIT on and off.

here = fileparts(mfilename('fullpath'));
repo = 'C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI-rentproc';
addpath(repo); cd(repo); %#ok<MCCD>

fprintf('=== SMOKE: DC REIT extension ===\n');

% ---- tiny, fast configuration -------------------------------------------
function p = tiny(p)
    p.grid_type = 'lna';
    p.u1_grid = linspace(0,1,6).';  p.N_u1 = 6;
    p.u2_grid = linspace(0,1,5).';  p.N_u2 = 5;
    p.u3_grid = linspace(0,1,5).';  p.N_u3 = 5;
    p.gh_n = 3; p.gh_n_reit = 3;
    p.N_c = 11; p.N_pi = 11;
    p.skip_polish = true;
end

% ================= 1. shock-grid gate ====================================
p_on  = tiny(config.params());                         % tau_REIT = 0.10 default
p_off = p_on; p_off.tau_REIT = 0; ...
    p_off.corr_RL = 0; p_off.corr_RS = 0; p_off.corr_RH = 0;

assert(config.reit_active(p_on),  'reit_active should be TRUE with tau_REIT=0.10');
assert(~config.reit_active(p_off),'reit_active should be FALSE with tau_REIT=0 & corr=0');

s_on  = grids.shock_grid(p_on);
s_off = grids.shock_grid(p_off);
n_on  = numel(s_on.joint.w);
n_off = numel(s_off.joint.w);
fprintf('shock nodes: on=%d (expect %d), off=%d (expect %d)\n', ...
    n_on, p_on.gh_n^3*p_on.gh_n_reit, n_off, p_off.gh_n^3);
assert(n_on  == p_on.gh_n^3 * p_on.gh_n_reit, 'active joint node count wrong');
assert(n_off == p_off.gh_n^3,                 'inactive joint node count wrong');
assert(abs(sum(s_on.joint.w)  - 1) < 1e-12, 'active weights must sum to 1');
assert(abs(sum(s_off.joint.w) - 1) < 1e-12, 'inactive weights must sum to 1');
assert(all(isfinite(s_on.joint.R_REIT)) && numel(s_on.joint.R_REIT)==n_on, 'joint.R_REIT bad (on)');
assert(all(s_off.joint.R_REIT == 1), 'joint.R_REIT must be unit vector when off');
fprintf('  [OK] shock-grid gate\n');

% ================= 2/3. solve + simulate, OFF (baseline) then ON =========
% OFF is numerically the pre-REIT model (tau_R=0, R_REIT=1), so its non-finite
% count is the baseline; ON must not be worse.
[sim_off, sol_off] = solve_and_sim(p_off);
[sim_on,  sol_on ] = solve_and_sim(p_on);
nf_off = nnz(~isfinite(sol_off.V));
nf_on  = nnz(~isfinite(sol_on.V));
fprintf('non-finite V: off(baseline)=%d, on=%d  (of %d)\n', nf_off, nf_on, numel(sol_on.V));
assert(nf_on <= nf_off, 'REIT introduced NEW non-finite V entries beyond baseline');
fprintf('  [OK] REIT-off  solve+sim: meanA(age65)=%.3g, sim NaNs=%d\n', ...
    mean(sim_off.A(:,41)), nnz(~isfinite(sim_off.A)));
fprintf('  [OK] REIT-on   solve+sim: mean tau_A=%.3f, meanA(age65)=%.3g, sim NaNs=%d\n', ...
    mean(sim_on.tau_A(:)), mean(sim_on.A(:,41)), nnz(~isfinite(sim_on.A)));
assert(~any(~isfinite(sim_on.A(:))),  'REIT-on simulation produced non-finite A');
assert(~any(~isfinite(sim_on.C(:))),  'REIT-on simulation produced non-finite C');
% REIT adds a positive-excess-return asset to the DC fund, so with the same
% shocks the accumulated fund should be at least as large on average by age 65.
fprintf('meanA(age65): on=%.4g vs off=%.4g\n', mean(sim_on.A(:,41)), mean(sim_off.A(:,41)));

% ================= 4. annuity sanity (REIT raises E[R_A] -> lower a_t) ====
[prof_on, sh_on]  = setup(p_on);
[prof_off, sh_off]= setup(p_off);
a_on  = pension.annuity_price(p_on,  prof_on,  sh_on);
a_off = pension.annuity_price(p_off, prof_off, sh_off);
tr = p_on.t_ret;
fprintf('annuity a(t_ret): on=%.4f, off=%.4f (REIT should lower it)\n', a_on(tr), a_off(tr));
assert(all(isfinite(a_on)) && all(isfinite(a_off)), 'annuity has non-finite entries');
assert(a_on(tr) < a_off(tr) + 1e-9, 'REIT (positive excess return) should not raise a(t_ret)');
fprintf('  [OK] annuity\n');

fprintf('=== SMOKE PASSED ===\n');
end

function [profile, shocks] = setup(p)
    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth   = mu_growth;
    profile.sigma_l_log = sigma_l_log;
    profile.p_surv      = config.survival(p);
    shocks    = grids.shock_grid(p);
end

function [sim, sol] = solve_and_sim(p)
    [profile, shocks] = setup(p);
    ann_price = pension.annuity_price(p, profile, shocks);
    sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);
    sim = simulate.forward(p, profile, sol, ann_price, 500);
end
