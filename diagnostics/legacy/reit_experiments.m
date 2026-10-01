function reit_experiments()
%REIT_EXPERIMENTS  Comparative statics on the DC REIT: does the model respond
%   as expected to REIT return level, volatility and allocation share?
%
%   DC-fund accumulation is policy-independent (contributions are mandatory
%   kappa*Y compounded at R_A), so E[A] and the annuity are clean functions of
%   the return parameters -- a moderate grid + skip_polish gives reliable
%   comparative statics.

repo = 'C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI-rentproc';
addpath(repo); cd(repo); %#ok<MCCD>

base = config.params();
base.grid_type = 'lna';
base.u1_grid = linspace(0,1,12).'; base.N_u1 = 12;
base.u2_grid = linspace(0,1,9).';  base.N_u2 = 9;
base.u3_grid = linspace(0,1,9).';  base.N_u3 = 9;
base.gh_n = 5; base.gh_n_reit = 3;
base.N_c = 15; base.N_pi = 15;
base.skip_polish = true;
N_sim = 3000;

tr = base.t_ret;   % retirement period index (age 67)

fprintf('\n================ REIT COMPARATIVE STATICS ================\n');
fprintf('grid %dx%dx%d  gh_n=%d gh_n_reit=%d  N_sim=%d  age@t_ret=%d\n\n', ...
    base.N_u1, base.N_u2, base.N_u3, base.gh_n, base.gh_n_reit, N_sim, base.age0+tr-1);

% -------- Experiment A: REIT excess return level (share fixed 0.10) --------
fprintf('--- A) vary mu_REIT_level  (sigma=0.12, tau_REIT=0.10) ---\n');
hdr();
muvec = [0.00 0.02 0.04 0.06];
for mu = muvec
    p = base; p.mu_REIT_level = mu; p.sigma_REIT_level = 0.12; p.tau_REIT = 0.10;
    row(p, tr, N_sim, sprintf('mu=%.2f', mu));
end

% -------- Experiment B: REIT volatility (mean return held fixed) ----------
fprintf('\n--- B) vary sigma_REIT_level  (mu=0.04, tau_REIT=0.10) ---\n');
fprintf('    [expect: E[A] ~flat (mean gross return is 1+r+mu, sigma-invariant); std[A] rises]\n');
hdr();
sigvec = [0.05 0.12 0.25 0.40];
for sig = sigvec
    p = base; p.mu_REIT_level = 0.04; p.sigma_REIT_level = sig; p.tau_REIT = 0.10;
    row(p, tr, N_sim, sprintf('sig=%.2f', sig));
end

% -------- Experiment C: REIT allocation share (mu>0, so more = more) ------
fprintf('\n--- C) vary tau_REIT  (mu=0.04, sigma=0.12) ---\n');
hdr();
tauvec = [0.00 0.05 0.10 0.20];
for tR = tauvec
    p = base; p.mu_REIT_level = 0.04; p.sigma_REIT_level = 0.12; p.tau_REIT = tR;
    row(p, tr, N_sim, sprintf('tauR=%.2f', tR));
end

fprintf('\n=========================================================\n');
end

function hdr()
    fprintf('  %-10s | %-9s | %8s %9s %9s | %8s %8s | %9s\n', ...
        'case','E[Rreit]','E[A67]','std[A67]','cv[A67]','a(tret)','C_ret','active');
end

function row(p, tr, N_sim, label)
    [profile, shocks] = setup(p);
    ann_price = pension.annuity_price(p, profile, shocks);
    evalc('sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);'); %#ok<*NASGU> suppress per-period prints
    sim = simulate.forward(p, profile, sol, ann_price, N_sim);
    A67  = sim.A(:, tr);
    mA   = mean(A67); sA = std(A67);
    [muR, sgR] = config.reit_process(p);
    ERg  = exp(muR + 0.5*sgR^2);                      % E[gross REIT return]
    Cret = mean(mean(sim.C(:, tr:end)));              % mean retirement consumption
    fprintf('  %-10s | %-9.4f | %8.4g %9.4g %9.3f | %8.4f %8.4g | %9d\n', ...
        label, ERg, mA, sA, sA/max(mA,eps), ann_price(tr), Cret, config.reit_active(p));
end

function [profile, shocks] = setup(p)
    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth   = mu_growth;
    profile.sigma_l_log = sigma_l_log;
    profile.p_surv      = config.survival(p);
    shocks    = grids.shock_grid(p);
end
