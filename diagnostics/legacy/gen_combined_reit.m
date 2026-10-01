function gen_combined_reit()
%GEN_COMBINED_REIT  Build combined_{renter,owner}_lna.mat with the REIT active,
%   so make_plots.m can be rendered to check the REIT-aware dashboard panels.
%   Moderate grid + skip_polish: fast, and the DC/allocation panels this checks
%   are policy-independent anyway.

repo = 'C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI-rentproc';
addpath(repo); cd(repo);

for tenure = {'renter','owner'}
    p = config.params();
    p.is_owner = strcmp(tenure{1}, 'owner');
    p.grid_type = 'lna';
    p.u1_grid = linspace(0,1,14).'; p.N_u1 = 14;
    p.u2_grid = linspace(0,1,10).'; p.N_u2 = 10;
    p.u3_grid = linspace(0,1,10).'; p.N_u3 = 10;
    p.gh_n = 5; p.gh_n_reit = 3;
    p.N_c = 15; p.N_pi = 15;
    p.skip_polish = true;
    p = config.insert_anchor_nodes(p);   % keep welfare anchors on-grid (simplex vecs)

    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth   = mu_growth;
    profile.sigma_l_log = sigma_l_log;
    profile.p_surv      = config.survival(p);
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);
    evalc('sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);');
    sim = simulate.forward(p, profile, sol, ann_price, 4000);

    fname = fullfile(repo, sprintf('combined_%s_lna.mat', tenure{1}));
    save(fname, 'p', 'profile', 'shocks', 'ann_price', 'sol', 'sim');
    fprintf('wrote %s  (reit_active=%d, mean reit_A=%.3f)\n', ...
        fname, config.reit_active(p), mean(sim.reit_A(:)));
end
end
