function grid_study()
%GRID_STUDY  Does either coordinate system converge, and does node placement help?
%
%   Two questions the production runs left open.
%
%   (A) CONVERGENCE. Each scheme is solved at three resolutions. A scheme whose
%       V_tilde and policy stop moving as the grid refines is resolved; one that
%       keeps moving is not, and its numbers are grid artefacts. This is the
%       only way to tell the two apart without a reference solution -- neither
%       is truth, so they can only be judged on whether they settle.
%
%   (B) NODE PLACEMENT. The two schemes were measured to disagree most in early
%       life, where the household sits within one grid cell of the s_X = 0 face
%       (simplex) or the u2 = 1 edge (cube) -- and that is also where the
%       welfare anchor is read. Clustering nodes there costs nothing in state
%       count. Run at the same sizes as the finest uniform case, so any
%       difference is placement alone.
%
%   gh_n = 5 throughout: the question is state-grid resolution, and the
%   quadrature is a separate axis. Absolute levels therefore are not comparable
%   to the gh_n = 7 production runs; the comparison here is within this table.
%
%   Writes grid_study.mat and prints one row per configuration.

GH_N  = 5;
N_SIM = 8000;
SEED  = 20260812;

cfg = struct('tag', {}, 'grid', {}, 'dims', {}, 'pow', {});
cfg(end+1) = struct('tag','lna_16',      'grid','lna',     'dims',[16 12 12], 'pow',1);
cfg(end+1) = struct('tag','lna_22',      'grid','lna',     'dims',[22 16 16], 'pow',1);
cfg(end+1) = struct('tag','lna_28',      'grid','lna',     'dims',[28 20 20], 'pow',1);
cfg(end+1) = struct('tag','lna_28_clus', 'grid','lna',     'dims',[28 20 20], 'pow',2.5);
cfg(end+1) = struct('tag','sx_24',       'grid','simplex', 'dims',[24 24 24], 'pow',1);
cfg(end+1) = struct('tag','sx_32',       'grid','simplex', 'dims',[32 32 32], 'pow',1);
cfg(end+1) = struct('tag','sx_40',       'grid','simplex', 'dims',[40 40 40], 'pow',1);
cfg(end+1) = struct('tag','sx_40_clus',  'grid','simplex', 'dims',[40 40 40], 'pow',2.5);

fprintf('grid_study: %d configurations, gh_n = %d, %d paths\n\n', numel(cfg), GH_N, N_SIM);
pool = gcp();
parfevalOnAll(pool, @() warning('off', 'MATLAB:nearlySingularMatrix'), 0);
parfevalOnAll(pool, @() warning('off', 'MATLAB:singularMatrix'), 0);

% Resume: configs run strictly in order and each is saved as it finishes, so
% anything already in grid_study.mat is a prefix of cfg and can be skipped.
R = struct();
if isfile('grid_study.mat')
    S = load('grid_study.mat', 'R');
    if isfield(S, 'R') && numel(S.R) >= 1 && isfield(S.R, 'tag')
        R = S.R;
        fprintf('resuming: %d configuration(s) already on disk (%s)\n\n', ...
                numel(R), strjoin({R.tag}, ', '));
    end
end
AGES = [25 35 45 55 67 85];

for k = 1:numel(cfg)
    c = cfg(k);
    if k <= numel(R) && isfield(R, 'tag') && strcmp(R(k).tag, c.tag)
        fprintf('[%d/%d] %-12s already done, skipping\n', k, numel(cfg), c.tag);
        continue
    end
    fprintf('[%d/%d] %-12s %-7s dims=%s pow=%.1f\n', k, numel(cfg), c.tag, c.grid, ...
            mat2str(c.dims), c.pow);
    t0 = tic;

    p = config.params();
    p.is_owner    = false;
    p.legacy_fill = false;
    p.grid_type   = c.grid;
    p.grid_pow    = c.pow;
    p = utility.build_state_grids(p, c.dims, GH_N);

    [~, mg, sl] = config.income_profile(p);
    profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(p));
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);

    if strcmp(c.grid, 'lna')
        sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);
        sim = simulate.paths_lna(p, profile, sol, ann_price, N_SIM, SEED, p.b0);
        nst = p.N_u1 * p.N_u2 * p.N_u3;
    else
        sol = solver.solve_lifecycle(p, profile, shocks, ann_price);
        sim = simulate.paths(p, profile, sol, ann_price, N_SIM, SEED, p.b0);
        [L,A,H] = ndgrid(p.lambda_grid, p.sA_grid, p.sH_grid);
        nst = nnz((L+A+H) <= 1+1e-12);
    end
    w = utility.welfare_summary(p, sol.V(:,:,:,1));

    pi_med = zeros(1, numel(AGES));
    for j = 1:numel(AGES)
        pi_med(j) = median(sim.pi(:, AGES(j) - p.age0 + 1));
    end
    F = p.phi_floor * sim.Y;

    R(k).tag      = c.tag;
    R(k).grid     = c.grid;
    R(k).pow      = c.pow;
    R(k).n_states = nst;
    R(k).Vt0_b0   = w.Vt0_b0;
    R(k).z        = ((1 - p.gamma) * w.Vt0_b0)^(1/(1 - p.gamma));
    R(k).pi_med   = pi_med;
    R(k).floor    = mean(sim.LW(:) < F(:));
    R(k).minutes  = toc(t0)/60;
    fprintf('    %d states, %.1f min, Vt0_b0=%.6g, z=%.5g, floor=%.2f%%\n\n', ...
            nst, R(k).minutes, R(k).Vt0_b0, R(k).z, 100*R(k).floor);
    save('grid_study.mat', 'R', 'cfg', 'AGES', 'GH_N', 'N_SIM', 'SEED');
end

fprintf('\n===== SUMMARY =====\n');
fprintf('%-13s %-8s %8s %13s %11s %8s | median pi at ages %s\n', ...
        'config','grid','states','Vt0_b0','z(CE/W)','floor%', mat2str(AGES));
for k = 1:numel(R)
    fprintf('%-13s %-8s %8d %13.5g %11.5g %7.2f%% | %s\n', R(k).tag, R(k).grid, ...
        R(k).n_states, R(k).Vt0_b0, R(k).z, 100*R(k).floor, ...
        sprintf('%6.3f', R(k).pi_med));
end

fprintf('\n--- convergence: successive change in z, uniform refinements ---\n');
report_seq(R, {'lna_16','lna_22','lna_28'});
report_seq(R, {'sx_24','sx_32','sx_40'});
fprintf('\n--- clustering at matched size: z and policy shift ---\n');
report_pair(R, 'lna_28', 'lna_28_clus');
report_pair(R, 'sx_40',  'sx_40_clus');
fprintf('\nwrote grid_study.mat\ndone\n');
end

function report_seq(R, tags)
idx = cellfun(@(t) find(strcmp({R.tag}, t), 1), tags, 'UniformOutput', false);
if any(cellfun(@isempty, idx)), return; end
idx = cell2mat(idx);
for j = 2:numel(idx)
    a = R(idx(j-1)); b = R(idx(j));
    fprintf('  %-10s -> %-10s  z %10.5g -> %10.5g  (%+.1f%%)   max|dpi| %.3f\n', ...
        a.tag, b.tag, a.z, b.z, 100*(b.z/a.z - 1), max(abs(b.pi_med - a.pi_med)));
end
end

function report_pair(R, t1, t2)
i1 = find(strcmp({R.tag}, t1), 1); i2 = find(strcmp({R.tag}, t2), 1);
if isempty(i1) || isempty(i2), return; end
a = R(i1); b = R(i2);
fprintf('  %-10s -> %-10s  z %10.5g -> %10.5g  (%+.1f%%)   max|dpi| %.3f\n', ...
    a.tag, b.tag, a.z, b.z, 100*(b.z/a.z - 1), max(abs(b.pi_med - a.pi_med)));
end
