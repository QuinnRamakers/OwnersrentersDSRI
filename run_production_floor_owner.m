function run_production_floor_owner()
%RUN_PRODUCTION_FLOOR_OWNER  The missing owner arm, matched to prod_floor_new.
%
%   Same grid, floor, seed and path count as run_production_floor, with
%   is_owner = true. One arm is enough: config.h_process hands owners the
%   housing pair (mu_H, sigma_H) whatever mu_R_level says, so the owner problem
%   is identical under both rent calibrations -- tests/smoke_rent_process
%   asserts exactly that. The rent fields are left at the production values so
%   this file's fingerprint differs from prod_floor_new.mat only in is_owner.
%
%   Needed because every solve in this fork so far has been the renter: the
%   session was about the rent process, and owner/renter comparisons have
%   nothing to stand on without this.

GRID  = [40 40 40];
GH_N  = 7;
N_SIM = 20000;
SEED  = 20260812;

fprintf('run_production_floor_owner\n');
fprintf('  grid [%d %d %d], gh_n = %d, %d paths, seed %d\n', ...
        GRID(1), GRID(2), GRID(3), GH_N, N_SIM, SEED);

pool = gcp();
parfevalOnAll(pool, @() warning('off', 'MATLAB:nearlySingularMatrix'), 0);
parfevalOnAll(pool, @() warning('off', 'MATLAB:singularMatrix'), 0);
fprintf('  pool: %d workers\n\n', pool.NumWorkers);

t0 = tic;
p = config.params();
% Pinned to the simplex: this file drives the simplex solver/simulator
% directly, and config.params now defaults to the cube (utility.active_grid).
p.grid_type = 'simplex';
p.is_owner    = true;
p.legacy_fill = false;
p = utility.build_state_grids(p, GRID, GH_N);

[~, mg, sl] = config.income_profile(p);
profile.mu_growth   = mg;
profile.sigma_l_log = sl;
profile.p_surv      = config.survival(p);
shocks    = grids.shock_grid(p);
ann_price = pension.annuity_price(p, profile, shocks);

sol      = solver.solve_lifecycle(p, profile, shocks, ann_price);
welfare0 = utility.welfare_summary(p, sol.V(:,:,:,1));
sim      = simulate.paths(p, profile, sol, ann_price, N_SIM, SEED, p.b0);

fprintf('  solved and simulated in %.1f min\n', toc(t0)/60);

ages = p.age0 : p.age0 + p.T - 1;
F    = p.phi_floor * sim.Y;
fprintf('  V finite on the feasible set : %d\n', all(isfinite(sol.V(~isnan(sol.V)))));
fprintf('  -1e15 sentinel present       : %d (expected 0)\n', any(sol.V(:) == -1e15));
fprintf('  min simulated consumption    : %.6g\n', min(sim.C(:)));
fprintf('  floor binds                  : %.2f%% of household-years\n', 100*mean(sim.LW(:) < F(:)));
fprintf('  V_tilde at b0                : %.10g\n', welfare0.Vt0_b0);
fprintf('   age | housing cost | %% net income | floor binds | median C\n');
for i = [1 21 43 51 61 71 76]
    hc = (p.theta + p.m_rate_path(min(i, numel(p.m_rate_path)))) * sim.H(:,i);
    ny = (1 - p.tau_inc) * (sim.Y(:,i) + sim.ann_pay(:,i));
    fprintf('  %4d | %12.0f | %11.0f%% | %10.1f%% | %8.0f\n', ...
        ages(i), median(hc), 100*median(hc./max(ny,1)), ...
        100*mean(sim.LW(:,i) < F(:,i)), median(sim.C(:,i)));
end

save('prod_floor_owner.mat', 'p', 'profile', 'sol', 'ann_price', 'sim', ...
     'welfare0', '-v7.3');
fprintf('\nwrote prod_floor_owner.mat\ndone\n');
end
