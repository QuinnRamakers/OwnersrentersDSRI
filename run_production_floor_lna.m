function run_production_floor_lna()
%RUN_PRODUCTION_FLOOR_LNA  The run_production_floor arms on the LNA cube.
%
%   Same two rent calibrations, same floor, same seed and path count as
%   run_production_floor, solved on the alternative (u1, u2, u3) cube instead
%   of the (lambda, s_A, s_H) simplex:
%       u1 = lambda,  u2 = (A+H)/(W-Y),  u3 = A/(A+H)
%   Every point of [0,1]^3 is feasible there, so 28x20x20 = 11,200 states is
%   close to the simplex's 12,642 feasible nodes -- a like-for-like comparison
%   at matched resolution rather than matched cube size.
%
%   The point is the discretisation itself. The two coordinate systems are
%   approximations of one model, so any welfare difference between them is
%   discretisation error, and the repo has an open disagreement about the sign
%   of the DC equity effect that splits along exactly this line (see the header
%   of overnight_lna/run_overnight_lna). Running both under the consumption
%   floor tests whether the floor changes that.
%
%   Note on comparability: utility.param_fingerprint keys on N_lambda/N_sA/N_sH
%   and does not record the cube dimensions or which coordinate system was
%   used, so a simplex file and an LNA file fingerprint IDENTICALLY. Do not put
%   them in one ranking table without tagging them by hand.

CUBE  = [28 20 20];    % matches the simplex feasible-point count, see config.params
GH_N  = 7;
N_SIM = 20000;
SEED  = 20260812;

arms = struct( ...
    'tag',   {'new', 'old'}, ...
    'name',  {'new (rent estimate)', 'old (house process)'}, ...
    'mu',    {0.0097, 0.027}, ...
    'sigma', {0.018,  0.037});

fprintf('run_production_floor_lna\n');
fprintf('  cube [%d %d %d] on (u1,u2,u3), gh_n = %d, %d paths, seed %d\n', ...
        CUBE(1), CUBE(2), CUBE(3), GH_N, N_SIM, SEED);

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
    p.gh_n = GH_N;
    p.grid_type = 'lna';        % declared for the fingerprint; the solver asserts it
    p.N_u1 = CUBE(1); p.N_u2 = CUBE(2); p.N_u3 = CUBE(3);
    p.u1_grid = linspace(0, 1, p.N_u1).';
    p.u2_grid = linspace(0, 1, p.N_u2).';
    p.u3_grid = linspace(0, 1, p.N_u3).';
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

    sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);

    % Welfare anchor at the calibrated buffer b0, in u-coordinates. Same
    % conversion overnight_lna/run_overnight_lna uses.
    den  = p.b0 + p.h_mult + 1;
    lam0 = 1/den;  sH0 = p.h_mult/den;
    u1 = lam0;  u2 = sH0/(1 - lam0);  u3 = 0;
    F  = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, sol.V(:,:,:,1), ...
                            'linear', 'nearest');
    welfare0 = struct('Vt0_b0', F(u1, u2, u3), 'u', [u1 u2 u3], 'b0', p.b0);

    sim = simulate.paths_lna(p, profile, sol, ann_price, N_SIM, SEED, p.b0);

    fprintf('  solved and simulated in %.1f min\n', toc(t0)/60);
    report_arm(p, sol, sim, welfare0);

    save(sprintf('prod_floor_lna_%s.mat', arms(a).tag), ...
         'p', 'profile', 'sol', 'ann_price', 'sim', 'welfare0', '-v7.3');
    fprintf('  wrote prod_floor_lna_%s.mat\n\n', arms(a).tag);
end

fprintf('done\n');
end

function report_arm(p, sol, sim, welfare0)
ages = p.age0 : p.age0 + p.T - 1;
key  = [1 21 43 51 61 71 76];
F    = p.phi_floor * sim.Y;

fprintf('  V finite everywhere         : %d\n', all(isfinite(sol.V(~isnan(sol.V)))));
fprintf('  -1e15 sentinel present      : %d (expected 0)\n', any(sol.V(:) == -1e15));
fprintf('  min simulated consumption   : %.6g (expected > 0)\n', min(sim.C(:)));
fprintf('  floor binds                 : %.2f%% of household-years\n', 100*mean(sim.LW(:) < F(:)));
fprintf('  V_tilde at b0               : %.10g\n', welfare0.Vt0_b0);

fprintf('   age |     rent | %% net AOW | floor binds | median C\n');
for i = key
    rent = p.alpha * sim.H(:,i);
    naow = (1 - p.tau_inc) * sim.Y(:,i);
    fprintf('  %4d | %8.0f | %8.0f%% | %10.1f%% | %8.0f\n', ...
        ages(i), median(rent), 100*median(rent./max(naow,1)), ...
        100*mean(sim.LW(:,i) < F(:,i)), median(sim.C(:,i)));
end
end
