function plot_fill_fix_diagnostics()
%PLOT_FILL_FIX_DIAGNOSTICS  Visual diagnostics for the phantom-penalty fix.
%
%   Companion to tests/smoke_fill_fix.m, which reports the same evidence as
%   numbers. Six panels:
%
%     1-2  The fill itself. log10(z) on the (lambda, s_H) slice at s_A = 0.
%          OLD: the infeasible triangle is a flat floor at the global minimum
%          z -- the z-image of the -1e15 ruin assignment -- so the interpolant
%          falls off a cliff at the sX = 0 face. NEW: the nearest-feasible
%          projection continues the surface smoothly across the boundary.
%     3    Where the correction lives: median CEV against sX, the distance
%          from the face. The phantom penalty was one interpolation cell
%          wide, so this must decay -- that shape is the diagnosis.
%     4    Correction by age.
%     5    Why the MAXIMUM is not quotable: median CEV against |V_old|. The
%          eye-catching figures (+711% renter, +4406% owner) sit entirely in
%          the near-ruin decades where |V| ~ 1e13 and the CEV ratio
%          (V_new/V_old)^(1/(1-gamma)) explodes on economically empty
%          changes.
%     6    Distribution (ECDF) with median / p90 / p99 and the t=1 welfare
%          anchor CEVs marked -- the anchors are the quotable numbers.
%
%   Solves both tenures under both fills (~15 min on a laptop pool) and
%   caches to tempdir, keyed on the grid + calibration, so re-plotting is
%   instant. Writes fig_fill_fix_diagnostics.png next to the repo.
%
%   Usage:  cd <repo>; tests/plot_fill_fix_diagnostics

repo = fileparts(fileparts(mfilename('fullpath')));
addpath(repo);

D = get_solves(repo);
p = D.p; g = p.gamma;

[Lam, SA, SH] = ndgrid(p.lambda_grid, p.sA_grid, p.sH_grid);
feas   = (Lam + SA + SH) <= 1 + 1e-12;
sX_all = 1 - Lam - SA - SH;

fig = figure('Visible', 'off', 'Position', [60 60 1500 820]);
tl  = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
cols = [0.00 0.45 0.74; 0.85 0.33 0.10];   % renter, owner
tens = {'renter', 'owner'};

% ---- panels 1-2: the fill itself -------------------------------------------
t_slice = round(p.T / 2);
V_next  = D.renter.new.V(:,:,:,t_slice+1);
[z_old, z_new] = both_fills(V_next, p, feas);
ia0 = find(p.sA_grid == 0, 1);
zo  = log10(squeeze(z_old(:, ia0, :)));
zn  = log10(squeeze(z_new(:, ia0, :)));
cl  = [min(zn(:)) max(zn(:))];

for k = 1:2
    nexttile(tl, k);
    if k == 1, Z = zo; ttl = 'OLD fill: global-minimum z'; else, Z = zn; ttl = 'NEW fill: nearest feasible'; end
    imagesc(p.sH_grid, p.lambda_grid, Z, cl); set(gca, 'YDir', 'normal');
    hold on;
    plot([0 1], [1 0], 'w-', 'LineWidth', 1.6);          % the sX = 0 face
    text(0.52, 0.52, 'sX = 0', 'Color', 'w', 'FontSize', 8, 'Rotation', -45);
    xlabel('s_H'); ylabel('\lambda');
    title(sprintf('%s  (s_A=0, age %d)', ttl, p.age0 + t_slice - 1), 'FontSize', 9);
    c = colorbar; c.Label.String = 'log_{10} z';
end

% ---- panel 3: correction vs distance from the face -------------------------
nexttile(tl, 3); hold on; grid on;
h3 = gobjects(1, 2);
for i = 1:2
    S = D.(tens{i});
    [cev, sx, ~, ~] = pool_cev(S.old.V, S.new.V, feas, sX_all, g);
    [bx, bm, blo, bhi] = binned(sx, cev, linspace(0, 0.8, 17));
    fill([bx fliplr(bx)], 100*[blo fliplr(bhi)], cols(i,:), ...
         'FaceAlpha', 0.15, 'EdgeColor', 'none');
    h3(i) = plot(bx, 100*bm, '-o', 'Color', cols(i,:), 'LineWidth', 1.7, 'MarkerSize', 3);
end
% Floor the axis above binned()'s positive clamp: the median genuinely tends
% to 0 in the interior and a log axis would otherwise draw the clamp as a
% spurious cliff.
set(gca, 'YScale', 'log'); ylim([1e-2 1e2]);
xlabel('s_X  (distance from the s_X = 0 face)');
ylabel('median CEV correction (%), band = IQR');
title('Correction decays away from the face', 'FontSize', 9);
legend(h3, tens, 'Location', 'northeast', 'FontSize', 7);

% ---- panel 4: correction by age --------------------------------------------
nexttile(tl, 4); hold on; grid on;
for i = 1:2
    S = D.(tens{i}); med_t = nan(1, p.T);
    for t = 1:p.T
        [cev, ~, ~, ~] = pool_cev(S.old.V(:,:,:,t), S.new.V(:,:,:,t), feas, sX_all, g);
        if ~isempty(cev), med_t(t) = median(cev); end
    end
    plot(p.age0 + (0:p.T-1), 100*med_t, '-', 'Color', cols(i,:), 'LineWidth', 1.7);
end
xline(p.retirement_age, ':k', 'retirement', 'FontSize', 7, 'LabelOrientation', 'horizontal');
xlabel('age'); ylabel('median CEV correction (%)');
title('Correction by age', 'FontSize', 9);
legend(tens, 'Location', 'northwest', 'FontSize', 7);

% ---- panel 5: the near-ruin artefact ---------------------------------------
nexttile(tl, 5); hold on; grid on;
ed = 10.^(0:2:14); h5 = gobjects(1, 2);
for i = 1:2
    S = D.(tens{i});
    [cev, ~, vo, ~] = pool_cev(S.old.V, S.new.V, feas, sX_all, g);
    xm = nan(1, numel(ed)-1); ym = nan(1, numel(ed)-1); yh = nan(1, numel(ed)-1);
    for b = 1:numel(ed)-1
        s = abs(vo) >= ed(b) & abs(vo) < ed(b+1);
        if nnz(s) > 20
            xm(b) = sqrt(ed(b)*ed(b+1)); ym(b) = median(cev(s)); yh(b) = max(cev(s));
        end
    end
    h5(i) = plot(xm, 100*ym, '-o', 'Color', cols(i,:), 'LineWidth', 1.7, 'MarkerSize', 3); %#ok<AGROW>
    plot(xm, 100*yh, '--', 'Color', cols(i,:), 'LineWidth', 1.0);
end
set(gca, 'XScale', 'log', 'YScale', 'log');
xlabel('|V_{old}|  (near-ruin states have huge |V|)');
ylabel('CEV correction (%)');
title({'Why the maximum is not quotable:', 'solid = median, dashed = max'}, 'FontSize', 9);
legend(h5, tens, 'Location', 'northwest', 'FontSize', 7);

% ---- panel 6: distribution + the anchors -----------------------------------
nexttile(tl, 6); hold on; grid on;
h6 = gobjects(1, 4); lbl6 = cell(1, 4);
for i = 1:2
    S = D.(tens{i});
    [cev, ~, ~, ~] = pool_cev(S.old.V, S.new.V, feas, sX_all, g);
    x = sort(max(100*cev, 1e-4)); F = (1:numel(x))/numel(x);
    h6(i) = plot(x, F, '-', 'Color', cols(i,:), 'LineWidth', 1.7);
    lbl6{i} = sprintf('%s (median %+.1f%%)', tens{i}, median(100*cev));
    % Anchors as markers ON the curve rather than xlines: four labelled
    % verticals in one axes overlap into an unreadable smear.
    ax = 100*S.anchor(:).';
    ay = arrayfun(@(v) mean(x <= v), ax);
    h6(2+i) = plot(ax, ay, 'd', 'Color', cols(i,:), 'MarkerFaceColor', cols(i,:), ...
                   'MarkerSize', 7, 'LineStyle', 'none');
    lbl6{2+i} = sprintf('%s t=1 anchors (%.1f%%, %.1f%%)', tens{i}, ax(1), ax(2));
end
set(gca, 'XScale', 'log'); xlim([1e-2 1e4]);
xlabel('CEV correction (%)'); ylabel('cumulative share of state-periods');
title('Distribution; anchors = the quotable numbers', 'FontSize', 9);
legend(h6, lbl6, 'Location', 'northwest', 'FontSize', 6.5);

title(tl, sprintf(['Phantom-penalty fix: global-minimum vs nearest-feasible fill ' ...
                   '(%dx%dx%d, gh_n=%d, kappa=0)'], ...
                  p.N_lambda, p.N_sA, p.N_sH, p.gh_n), 'FontWeight', 'bold');

out = fullfile(repo, 'fig_fill_fix_diagnostics.png');
exportgraphics(fig, out, 'Resolution', 150);   % not print(): hangs headless
close(fig);
fprintf('Saved %s\n', out);
end

% ---------------------------------------------------------------------------
function [cev, sx, vo_out, t_out] = pool_cev(Vo, Vn, feas, sX_all, g)
% CEV over feasible, non-sentinel state-periods. Vo/Vn may be 3-D or 4-D.
cev = []; sx = []; vo_out = []; t_out = [];
for t = 1:size(Vo, 4)
    A = Vo(:,:,:,t); B = Vn(:,:,:,t);
    ok = feas & isfinite(A) & isfinite(B) & ~(A < -1e14) & ~(B < -1e14);
    if ~any(ok(:)), continue; end
    cev = [cev; (B(ok)./A(ok)).^(1/(1-g)) - 1];
    sx  = [sx;  sX_all(ok)];
    vo_out = [vo_out; A(ok)];
    t_out  = [t_out; repmat(t, nnz(ok), 1)];
end
end

function [bx, bm, blo, bhi] = binned(x, y, edges)
bx = nan(1, numel(edges)-1); bm = bx; blo = bx; bhi = bx;
for b = 1:numel(edges)-1
    s = x >= edges(b) & x < edges(b+1);
    if nnz(s) > 20
        bx(b) = 0.5*(edges(b)+edges(b+1));
        bm(b) = median(y(s)); blo(b) = prctile(y(s), 25); bhi(b) = prctile(y(s), 75);
    end
end
k = ~isnan(bx); bx = bx(k); bm = bm(k); blo = blo(k); bhi = bhi(k);
% Log axis: keep the IQR band strictly positive.
blo = max(blo, 1e-6); bhi = max(bhi, 1e-6); bm = max(bm, 1e-6);
end

function [z_old, z_new] = both_fills(V_next, p, feas)
% Reproduce bellman_step's two fills on the same V_next.
omg = 1 - p.gamma;
Vf  = V_next; Vf(~feas) = NaN;
arg = omg * Vf; arg(arg <= 0) = NaN;
z   = arg .^ (1/omg);
zmin = min(z(isfinite(z)));
z_old = z; z_old(~feas) = zmin; z_old(isnan(z_old)) = zmin;
m = solver.build_fill_map(p.lambda_grid, p.sA_grid, p.sH_grid);
z_new = z; z_new(m.infeas_lin) = z(m.src_lin); z_new(isnan(z_new)) = zmin;
end

% ---------------------------------------------------------------------------
function D = get_solves(~)
p = config.params();
% Pinned to the simplex: this file drives the simplex solver/simulator
% directly, and config.params now defaults to the cube (utility.active_grid).
p.grid_type = 'simplex';
p.kappa = 0; p.choose_tau_S = false; p.gh_n = 3;
p.N_lambda = 10; p.N_sA = 10; p.N_sH = 10;
p.lambda_grid = linspace(0, 1, p.N_lambda).';
p.sA_grid     = linspace(0, 1, p.N_sA).';
p.sH_grid     = linspace(0, 1, p.N_sH).';
p = config.insert_anchor_nodes(p);
p.N_c = 11; p.N_pi = 11;

key   = sprintf('filldiag_%d_%d_%d_%d_%g', p.N_lambda, p.N_sA, p.N_sH, p.gh_n, p.gamma);
cache = fullfile(tempdir, [key '.mat']);
if isfile(cache)
    fprintf('Loading cached solves: %s\n', cache);
    S = load(cache, 'D'); D = S.D; return
end

if isempty(gcp('nocreate'))
    try
        clus = parcluster('local');
        clus.NumWorkers = max(clus.NumWorkers, feature('numcores'));
        parpool(clus, clus.NumWorkers);
    catch
        try, parpool('Threads'); catch, warning('plot_fill_fix:nopool', 'no pool'); end
    end
end

D = struct('p', p);
for ten = {'renter', 'owner'}
    q = p; q.is_owner = strcmp(ten{1}, 'owner');
    [~, mg, sl] = config.income_profile(q);
    profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(q));
    shocks  = grids.shock_grid(q);
    ann     = pension.annuity_price(q, profile, shocks);
    qo = q; qo.legacy_fill = true;
    fprintf('%s: solving OLD fill ...\n', ten{1});
    so = solver.solve_lifecycle(qo, profile, shocks, ann);
    fprintf('%s: solving NEW fill ...\n', ten{1});
    sn = solver.solve_lifecycle(q,  profile, shocks, ann);

    ia0 = find(q.sA_grid == 0, 1); anc = nan(1, 2); bs = [q.b0, q.b_alt];
    for a = 1:2
        den = 1 + q.h_mult + bs(a);
        il0 = find(q.lambda_grid == 1/den, 1);
        ih0 = find(q.sH_grid == q.h_mult/den, 1);
        anc(a) = (sn.V(il0,ia0,ih0,1) / so.V(il0,ia0,ih0,1))^(1/(1-q.gamma)) - 1;
    end
    D.(ten{1}) = struct('old', so, 'new', sn, 'anchor', anc);
end
save(cache, 'D', '-v7.3');
fprintf('Cached solves to %s\n', cache);
end
