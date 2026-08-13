function confirm_no_tensor()
%CONFIRM_NO_TENSOR  Full-solve check that dropping the tensor is safe.
%
%   The per-state evidence says the NC x NP tensor is redundant once the polish
%   has a warm start and fixed starts: one step from an identical continuation,
%   'none' matched 'full' exactly (same +28.8% ceiling over the original
%   solver, zero regressions). This confirms it over a full backward induction,
%   where per-state differences compound, and measures the speedup.
%
%   Also runs polish_ver = 1 as the reference the whole comparison is against.

GRID = [25 15 15]; GH_N = 5; N_SIM = 8000; SEED = 20260813;
cfgs = struct( ...
    'tag',  {'v1_full',       'v2_full', 'v2_none'}, ...
    'ver',  {1,               2,         2}, ...
    'mode', {'full',          'full',    'none'});

fprintf('confirm_no_tensor: grid [%d %d %d], gh_n = %d, phi_floor = 0.05\n\n', ...
        GRID(1), GRID(2), GRID(3), GH_N);
pool = gcp();
parfevalOnAll(pool, @() warning('off', 'MATLAB:nearlySingularMatrix'), 0);
parfevalOnAll(pool, @() warning('off', 'MATLAB:singularMatrix'), 0);

R = struct();
for k = 1:numel(cfgs)
    t0 = tic;
    p = config.params();
    p.is_owner = false; p.legacy_fill = false;
    p.polish_ver = cfgs(k).ver;
    p.grid_mode  = cfgs(k).mode;
    p.phi_floor  = 0.05;
    p = utility.build_state_grids(p, GRID, GH_N);
    [~, mg, sl] = config.income_profile(p);
    profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(p));
    shocks = grids.shock_grid(p);
    ann    = pension.annuity_price(p, profile, shocks);

    sol = solver.solve_lifecycle(p, profile, shocks, ann);
    w   = utility.welfare_summary(p, sol.V(:,:,:,1));
    sim = simulate.paths(p, profile, sol, ann, N_SIM, SEED, p.b0);
    F   = p.phi_floor * sim.Y;

    R(k).tag = cfgs(k).tag;
    R(k).z   = ((1 - p.gamma) * w.Vt0_b0)^(1/(1 - p.gamma));
    R(k).min = toc(t0)/60;
    R(k).floor = mean(sim.LW(:) < F(:));
    R(k).pi  = [median(sim.pi(:,1)) median(sim.pi(:,11)) median(sim.pi(:,21)) ...
                median(sim.pi(:,p.t_ret)) median(sim.pi(:,61))];
    fprintf('%-9s %5.1f min  z = %10.6g  floor %.2f%%  pi@25/35/45/67/85 %s\n', ...
            R(k).tag, R(k).min, R(k).z, 100*R(k).floor, sprintf('%6.3f', R(k).pi));
end

fprintf('\n===== vs v1_full =====\n');
ref = R(1);
for k = 1:numel(R)
    fprintf('%-9s  rel z %+8.3f%%   speedup %5.2fx   max|dpi| vs v1 %.4f\n', ...
        R(k).tag, 100*(R(k).z/ref.z - 1), ref.min/R(k).min, max(abs(R(k).pi - ref.pi)));
end
save('confirm_no_tensor.mat', 'R');
fprintf('\nwrote confirm_no_tensor.mat\ndone\n');
end
