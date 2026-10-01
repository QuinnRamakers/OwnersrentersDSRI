function fig_ruin_line(out_dir)
%FIG_RUIN_LINE  Does the ruin boundary move up the income axis as the cube is
%   refined?
%
%   decision_by_grid found that the share of the (c, pi) square that is ruin at
%   the age-34 occupied state runs 0, 0, 16, 53 per cent across the ladder. The
%   state moves slightly between cubes, so that alone cannot separate a
%   resolution effect from the state drifting into a bad region.
%
%   ruin_line_by_grid scans the whole u1 line at the occupied (u2, u3) in every
%   cube. A boundary that sits at the same u1 in each cube means the age-34
%   jump was the state moving; a boundary that marches as the cube is refined
%   means the objective at a fixed state is changing.

if nargin < 1 || isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
fd = fullfile(out_dir, 'factorial_figs');
L  = load(fullfile(out_dir, 'ruin_line_by_grid.mat')); G = L.G;
[~, o] = sort([G.n]); G = G(o);
nG = numel(G); g = 5;
col = [0.85 0.33 0.10; 0.95 0.70 0.15; 0.25 0.60 0.45; 0.15 0.35 0.70];
col = col(1:nG, :);
AGES = 24 + G(1).t;

% occupancy band, for marking where households of that age actually are
occ = [];
osrc = fullfile(out_dir, 'occupancy_src.mat');
if isfile(osrc), Q = load(osrc); occ = Q.s; end

f  = figure('Position', [10 10 560*numel(AGES) 880], 'Color', 'w', 'Visible', 'off');
tl = tiledlayout(f, 2, numel(AGES), 'Padding', 'compact', 'TileSpacing', 'compact');
h  = gobjects(nG, 1);
for ai = 1:numel(AGES)
    ax1 = nexttile(tl, ai);               hold(ax1, 'on'); grid(ax1, 'on'); ax1.GridAlpha = .12;
    ax2 = nexttile(tl, numel(AGES) + ai); hold(ax2, 'on'); grid(ax2, 'on'); ax2.GridAlpha = .12;
    fprintf('\n=== age %d, along the u1 line at the occupied (u2, u3) ===\n', AGES(ai));
    fprintf('%-14s %6s %10s %10s %14s\n', 'cube', 'nodes', 'u2', 'u3', 'ruin reaches u1');
    for i = 1:nG
        u1 = G(i).u1(:).';
        fr = nan(size(u1)); zb = nan(size(u1));
        for j = 1:numel(u1)
            k  = sub2ind(G(i).N, j, G(i).i2(ai), G(i).i3(ai));
            fn = fullfile(G(i).dir, sprintf('scan_t%03d_k%06d.mat', G(i).t(ai), k));
            if ~isfile(fn), continue; end
            S = load(fn);
            Z = ((1-g)*S.rhs).^(1/(1-g)); Z(~isfinite(Z)) = 0; Z = max(Z, 0);
            zb(j) = max(Z(:));
            if zb(j) > 0, fr(j) = mean(Z(:) <= 0.02*zb(j)); end
        end
        hh = plot(ax1, u1, 100*fr, '-o', 'Color', col(i, :), 'LineWidth', 1.8, ...
            'MarkerSize', 4, 'MarkerFaceColor', col(i, :));
        plot(ax2, u1, zb, '-o', 'Color', col(i, :), 'LineWidth', 1.8, ...
            'MarkerSize', 4, 'MarkerFaceColor', col(i, :));
        if ai == 1, h(i) = hh; end
        k = find(fr(:).' > 0.01, 1, 'last');   % top of the ruin region
        ub = NaN; if ~isempty(k), ub = u1(k); end
        fprintf('%-14s %6d %10.3f %10.3f %14.4f\n', mat2str(G(i).N), G(i).n, ...
            G(i).coord23(ai, 1), G(i).coord23(ai, 2), ub);
    end
    if ~isempty(occ)
        tt = min(G(1).t(ai), size(occ.lambda, 2));
        q  = prctile(occ.lambda(:, tt), [5 95]);
        for ax = [ax1 ax2]
            yl = ylim(ax);
            patch(ax, [q(1) q(2) q(2) q(1)], [yl(1) yl(1) yl(2) yl(2)], [.55 .75 .95], ...
                'FaceAlpha', .18, 'EdgeColor', 'none');
            uistack(findobj(ax, 'Type', 'patch'), 'bottom');
            ylim(ax, yl);
        end
    end
    set([ax1 ax2], 'XScale', 'log');
    xlabel(ax1, 'u1  (income as a share of wealth)');
    ylabel(ax1, 'share of the (c, \pi) square that is ruin, %');
    title(ax1, sprintf('age %d', AGES(ai)), 'FontWeight', 'normal');
    xlabel(ax2, 'u1  (income as a share of wealth)');
    ylabel(ax2, 'best z at the node');
    title(ax2, sprintf('age %d: the value itself', AGES(ai)), 'FontWeight', 'normal');
end
ok = find(isgraphics(h)).';
lg = legend(h(ok), arrayfun(@(q) sprintf('%s = %d nodes', mat2str(q.N), q.n), G(ok), 'uni', 0), ...
    'Box', 'off', 'NumColumns', numel(ok));
lg.Layout.Tile = 'south';
sgtitle(f, ['The ruin boundary along the income axis, cube by cube, at the (u2, u3) households occupy. ' ...
    'Shaded band = where households of that age actually sit. ' ...
    'A boundary in the same place in every cube is the model''s; one that moves is the solution''s.'], ...
    'FontWeight', 'normal', 'FontSize', 11, 'Interpreter', 'tex');
exportgraphics(f, fullfile(fd, 'S34_ruin_line_by_grid.png'), 'Resolution', 115); close(f);
fprintf('\nS34 written\n');
end
