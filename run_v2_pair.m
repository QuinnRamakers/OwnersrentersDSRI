function run_v2_pair()
%RUN_V2_PAIR  Renter and owner under polish_ver = 2, for dashboards.
%
%   smoke_polish_v2 proves the solver properties but cannot produce dashboards:
%   it is renter-only, never simulates, and saves nothing. This solves both
%   tenures with the new polish and simulates them, so make_plots has the pair
%   it needs for the per-scenario dashboards AND fig_renter_vs_owner.
%
%   Sweep grid (the repo's [25 15 15] / gh_n = 5 convention), not production:
%   the point is a like-for-like tenure comparison of the v2 solver, and both
%   arms are on identical settings so the comparison is clean.
%
%   Writes v2_renter.mat / v2_owner.mat. NOT combined_*.mat -- those are
%   tracked files in this repo and staging over them destroys them.

GRID  = [25 15 15];
GH_N  = 5;
N_SIM = 20000;
SEED  = 20260813;

arms = struct('tag', {'renter', 'owner'}, 'is_owner', {false, true});

fprintf('run_v2_pair: grid [%d %d %d], gh_n = %d, %d paths, polish_ver = 2\n', ...
        GRID(1), GRID(2), GRID(3), GH_N, N_SIM);
pool = gcp();
parfevalOnAll(pool, @() warning('off', 'MATLAB:nearlySingularMatrix'), 0);
parfevalOnAll(pool, @() warning('off', 'MATLAB:singularMatrix'), 0);

for a = 1:numel(arms)
    fprintf('\n[%d/%d] %s\n', a, numel(arms), arms(a).tag);
    t0 = tic;

    p = config.params();
    % Pinned to the simplex: this file drives the simplex solver/simulator
    % directly, and config.params now defaults to the cube (utility.active_grid).
    p.grid_type = 'simplex';
    p.is_owner    = arms(a).is_owner;
    p.legacy_fill = false;
    p.polish_ver  = 2;
    p = utility.build_state_grids(p, GRID, GH_N);

    [~, mg, sl] = config.income_profile(p);
    profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(p));
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);

    sol      = solver.solve_lifecycle(p, profile, shocks, ann_price);
    welfare0 = utility.welfare_summary(p, sol.V(:,:,:,1));
    sim      = simulate.paths(p, profile, sol, ann_price, N_SIM, SEED, p.b0);

    F = p.phi_floor * sim.Y;
    fprintf('  %.1f min | Vt0_b0 = %.6g | floor binds %.2f%% | min C %.4g\n', ...
            toc(t0)/60, welfare0.Vt0_b0, 100*mean(sim.LW(:) < F(:)), min(sim.C(:)));
    fprintf('  median pi at 25/45/67/85: %.3f %.3f %.3f %.3f\n', ...
        median(sim.pi(:,1)), median(sim.pi(:,21)), ...
        median(sim.pi(:,p.t_ret)), median(sim.pi(:,61)));

    save(sprintf('v2_%s.mat', arms(a).tag), 'p', 'profile', 'sol', 'ann_price', ...
         'sim', 'welfare0', '-v7.3');
    fprintf('  wrote v2_%s.mat\n', arms(a).tag);
end

fprintf('\ndone\n');
end
