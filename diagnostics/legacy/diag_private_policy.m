function diag_private_policy()
%DIAG_PRIVATE_POLICY  Is the degenerate liquid policy (pi=0, c_frac=1) a
%   skip_polish artifact, and is the REIT implicated? Solve owner four ways.

repo = 'C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI-rentproc';
addpath(repo); cd(repo);

base = config.params();
base.is_owner = true; base.grid_type = 'lna';
base.u1_grid = linspace(0,1,16).'; base.N_u1 = 16;
base.u2_grid = linspace(0,1,12).'; base.N_u2 = 12;
base.u3_grid = linspace(0,1,10).'; base.N_u3 = 10;
base.gh_n = 5; base.gh_n_reit = 3;
base.N_c = 25; base.N_pi = 25;      % finer inner grid than the plotting run
base = config.insert_anchor_nodes(base);

cfg = { ...
  'skip_polish + REIT', setfield_(base, 'skip_polish', true);
  'POLISH on + REIT',   setfield_(base, 'skip_polish', false);
  'POLISH on + noREIT',  setfield_(setfield_(base,'skip_polish',false),'tau_REIT',0);
};

ages = base.age0:(base.age0+base.T-1);
probe_ages = [30 40 50 60];
idx = arrayfun(@(a) find(ages==a,1), probe_ages);

fprintf('\n%-22s | %-18s | %-18s | pi_pol range\n', 'config', ...
    sprintf('pi @ ages %s', mat2str(probe_ages)), 'c_frac @ same');
fprintf('%s\n', repmat('-',1,90));
for i = 1:size(cfg,1)
    p = cfg{i,2};
    [profile, shocks] = setup(p);
    ann = pension.annuity_price(p, profile, shocks);
    evalc('sol = solver.solve_lifecycle_lna(p, profile, shocks, ann);');
    sim = simulate.forward(p, profile, sol, ann, 3000);
    pim = mean(sim.pi,1); cfm = mean(sim.c_frac,1);
    fprintf('%-22s | %s | %s | [%.3f, %.3f]\n', cfg{i,1}, ...
        num2str(pim(idx),'%6.3f'), num2str(cfm(idx),'%6.3f'), ...
        min(sol.pi_pol(:)), max(sol.pi_pol(:)));
end
fprintf('\n(Merton after-tax pi ~ 0.3 expected; X is tiny so pi barely affects welfare.)\n');
end

function s = setfield_(s, f, v), s.(f) = v; end

function [profile, shocks] = setup(p)
    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth = mu_growth; profile.sigma_l_log = sigma_l_log;
    profile.p_surv = config.survival(p);
    shocks = grids.shock_grid(p);
end
