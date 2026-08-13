function run_production_floor()
%RUN_PRODUCTION_FLOOR  Production-grid solve of the renter under both rent
%   processes, with the consumption floor on.
%
%   Two purposes. It validates that the floor behaves at production resolution
%   (40^3, gh_n = 7) rather than only on the coarse smoke grid, and it redoes
%   the old-versus-new rent comparison under the fixed ruin treatment, so the
%   earlier table can be restated without the debt-forgiveness artefact.
%
%   Each arm is saved as soon as it finishes, so a partial run is still usable.
%   Expect roughly two hours per arm on 16 workers.

GRID  = [40 40 40];
GH_N  = 7;
N_SIM = 20000;
SEED  = 20260812;

arms = struct( ...
    'tag',   {'new', 'old'}, ...
    'name',  {'new (rent estimate)', 'old (house process)'}, ...
    'mu',    {0.0097, 0.027}, ...
    'sigma', {0.018,  0.037});

fprintf('run_production_floor\n');
fprintf('  grid [%d %d %d], gh_n = %d, %d paths, seed %d\n', ...
        GRID(1), GRID(2), GRID(3), GH_N, N_SIM, SEED);

% The fmincon KKT warnings are emitted inside parfor workers, where a
% warning('off') on the client does not reach. Silence them on the pool.
pool = gcp();
parfevalOnAll(pool, @() warning('off', 'MATLAB:nearlySingularMatrix'), 0);
parfevalOnAll(pool, @() warning('off', 'MATLAB:singularMatrix'), 0);
fprintf('  pool: %d workers\n\n', pool.NumWorkers);

for a = 1:numel(arms)
    fprintf('[%d/%d] %s: mu_R_level = %.4f, sigma_R_level = %.4f\n', ...
            a, numel(arms), arms(a).name, arms(a).mu, arms(a).sigma);
    t0 = tic;

    p = config.params();
    p.is_owner    = false;
    p.legacy_fill = false;
    p = utility.build_state_grids(p, GRID, GH_N);
    p.mu_R_level    = arms(a).mu;
    p.sigma_R_level = arms(a).sigma;
    p.sigma_R = sqrt(log(1 + (p.sigma_R_level / (1 + p.mu_R_level))^2));
    p.mu_R    = log(1 + p.mu_R_level) - 0.5 * p.sigma_R^2;

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
    report_arm(p, sol, sim, welfare0);

    save(sprintf('prod_floor_%s.mat', arms(a).tag), ...
         'p', 'profile', 'sol', 'ann_price', 'sim', 'welfare0', '-v7.3');
    fprintf('  wrote prod_floor_%s.mat\n\n', arms(a).tag);
end

fprintf('done\n');
end

function report_arm(p, sol, sim, welfare0)
ages = p.age0 : p.age0 + p.T - 1;
key  = [1 21 43 51 61 71 76];
F    = p.phi_floor * sim.Y;

% Floor and solver health at production resolution
fprintf('  V finite on the feasible set : %d\n', all(isfinite(sol.V(~isnan(sol.V)))));
fprintf('  -1e15 sentinel present       : %d (expected 0)\n', any(sol.V(:) == -1e15));
fprintf('  min simulated consumption    : %.6g (expected > 0)\n', min(sim.C(:)));
fprintf('  floor binds                  : %.2f%% of household-years\n', 100*mean(sim.LW(:) < F(:)));
fprintf('  V_tilde at b0                : %.6g\n', welfare0.Vt0_b0);

fprintf('   age |     rent | %% net AOW | %% resources | floor binds | median C\n');
for i = key
    rent  = p.alpha * sim.H(:,i);
    naow  = (1 - p.tau_inc) * sim.Y(:,i);
    nres  = (1 - p.tau_inc) * (sim.Y(:,i) + sim.ann_pay(:,i));
    fprintf('  %4d | %8.0f | %8.0f%% | %10.0f%% | %10.1f%% | %8.0f\n', ...
        ages(i), median(rent), 100*median(rent./max(naow,1)), ...
        100*median(rent./max(nres,1)), 100*mean(sim.LW(:,i) < F(:,i)), ...
        median(sim.C(:,i)));
end
end
