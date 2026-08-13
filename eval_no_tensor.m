function eval_no_tensor()
%EVAL_NO_TENSOR  Performance and correctness of warm-start + scaling WITHOUT
%   the grid search -- polish_ver = 2, grid_mode = 'none'.
%
%   Two questions.
%
%   PERFORMANCE, and specifically how it scales. At [25 15 15]/gh_n = 5 dropping
%   the tensor was only 1.09x, because the tensor is vectorised while fmincon is
%   an iterative scalar solve, so the polish dominates. Whether that holds at
%   production resolution is a separate question: the tensor is
%   n_shock x NC x NP per state, so it grows with gh_n. This runs two scales to
%   find out rather than extrapolating.
%
%   CORRECTNESS. With the fixed starts, 'none' seeds from {warm, (0.5,0.5),
%   (0.15,1.0)} and 'full' seeds from those PLUS the tensor argmax -- a strict
%   superset. Per step from the same continuation, 'full' can therefore only be
%   >= 'none'. Yet 'none' reported +9.7% at the welfare anchor over a full
%   solve. The per-step check below uses a REAL solved continuation, not a
%   random one, since a random V_next was already shown to manufacture effects
%   that do not exist on the solution path.

SCALES = struct('tag', {'sweep', 'mid'}, ...
                'dims', {[25 15 15], [32 24 24]}, ...
                'gh',   {5, 7});
N_SIM = 8000; SEED = 20260813; PHI = 0.05;

fprintf('eval_no_tensor: polish_ver = 2, phi_floor = %.3g\n\n', PHI);
pool = gcp();
parfevalOnAll(pool, @() warning('off', 'MATLAB:nearlySingularMatrix'), 0);
parfevalOnAll(pool, @() warning('off', 'MATLAB:singularMatrix'), 0);

fprintf('%-7s %-9s %-6s %8s %14s %10s %9s\n', ...
        'scale', 'mode', 'ver', 'minutes', 'Vt0_b0', 'floor%', 'C@45');
R = struct(); n = 0;
for s = 1:numel(SCALES)
    for cfg = {{1,'full'}, {2,'none'}}
        ver = cfg{1}{1}; mode = cfg{1}{2};
        n = n + 1; t0 = tic;
        p = config.params();
        p.is_owner = false; p.legacy_fill = false;
        p.polish_ver = ver; p.grid_mode = mode; p.phi_floor = PHI;
        p = utility.build_state_grids(p, SCALES(s).dims, SCALES(s).gh);
        [~, mg, sl] = config.income_profile(p);
        profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(p));
        shocks = grids.shock_grid(p);
        ann    = pension.annuity_price(p, profile, shocks);
        sol = solver.solve_lifecycle(p, profile, shocks, ann);
        w   = utility.welfare_summary(p, sol.V(:,:,:,1));
        sim = simulate.paths(p, profile, sol, ann, N_SIM, SEED, p.b0);
        F = p.phi_floor * sim.Y;

        R(n).scale = SCALES(s).tag; R(n).mode = mode; R(n).ver = ver;
        R(n).min = toc(t0)/60; R(n).Vt0 = w.Vt0_b0;
        R(n).floor = mean(sim.LW(:) < F(:));
        R(n).C = median(sim.C, 1); R(n).pi = median(sim.pi, 1);
        fprintf('%-7s %-9s v%-5d %8.2f %14.6g %9.2f%% %9.0f\n', ...
                R(n).scale, mode, ver, R(n).min, R(n).Vt0, 100*R(n).floor, R(n).C(21));
        save('eval_no_tensor.mat', 'R');
    end
end

fprintf('\n===== no-tensor v2 against full-tensor v1 =====\n');
for s = 1:numel(SCALES)
    a = R(find(strcmp({R.scale}, SCALES(s).tag) & [R.ver] == 1, 1));
    b = R(find(strcmp({R.scale}, SCALES(s).tag) & [R.ver] == 2, 1));
    dC  = max(abs(b.C - a.C) ./ max(abs(a.C), 1));
    fprintf(['  %-7s speedup %5.2fx | rel dVt0 %+8.2f%% | max rel dC %.3g | ' ...
             'max dpi %.3g | dfloor %+.3fpp\n'], SCALES(s).tag, a.min/b.min, ...
            100*(b.Vt0/a.Vt0 - 1), dC, max(abs(b.pi - a.pi)), 100*(b.floor - a.floor));
end

% ---- per-step, REAL continuation: does 'full' dominate 'none' as theory says?
fprintf('\n===== per step, real solved continuation =====\n');
p = config.params(); p.is_owner=false; p.legacy_fill=false; p.phi_floor=PHI;
p.polish_ver = 2;
p = utility.build_state_grids(p, [16 12 12], 3); p.N_c=21; p.N_pi=21;
[~,mg,sl] = config.income_profile(p);
profile = struct('mu_growth',mg,'sigma_l_log',sl,'p_surv',config.survival(p));
shocks = grids.shock_grid(p); ann = pension.annuity_price(p, profile, shocks);
pfull = p; pfull.grid_mode = 'full';
sol = solver.solve_lifecycle(pfull, profile, shocks, ann);
[L,A,H] = ndgrid(p.lambda_grid,p.sA_grid,p.sH_grid); feas = (L+A+H) <= 1+1e-12;
t = 20;
Vn  = sol.V(:,:,:,t+1);
pol = struct('c', sol.c_pol(:,:,:,t+1), 'pi', sol.pi_pol(:,:,:,t+1), 'tau', []);
Vf = solver.bellman_step(t, Vn, pfull, profile, shocks, ann, pol);
pnone = p; pnone.grid_mode = 'none';
Vnn = solver.bellman_step(t, Vn, pnone, profile, shocks, ann, pol);
r = (Vnn(feas) - Vf(feas)) ./ abs(Vf(feas));
fprintf('  none vs full: better %d, worse %d | max +%.4g | worst %.4g\n', ...
        nnz(r > 1e-12), nnz(r < -1e-12), max(r), min(r));
fprintf(['  full seeds from a superset, so worse-count > 0 is expected and\n' ...
         '  measures what the tensor is buying at a single step.\n']);
save('eval_no_tensor.mat', 'R');
fprintf('\nwrote eval_no_tensor.mat\ndone\n');
end
