function occupancy_figure(steps, arm, panel_name, grids, file)
%OCCUPANCY_FIGURE  Where households live on (u1, u2) by age, against grid points.
%
%   occupancy_figure([6 9 10 11 12], 'owner', 'pow3_96x96', ...
%                    {'uniform_16x16', 'pow3_32x32'}, 'occ_owner.png')
%
%   One column per step, from the simulated panel of the case panel_name
%   (uniform_64x64, then the standard solve, where a step lacks it).
%   Row 1: total resources over income, W/Y = 1/u1, log scale, the shading
%   the share of households at each age. Row 2: liquid savings over liquid
%   savings plus the pension pot, 1 - u2, log scale (u2 near 1 is little
%   liquid saving beside the pot). Rows 3-4: how many grid points of each grid
%   lie inside the band where the middle 90% of households live, by age. Grid
%   points are drawn as horizontal lines, one colour per grid.

S = ladder.steps();
cmap = [linspace(1, 0.10, 256).', linspace(1, 0.30, 256).', linspace(1, 0.60, 256).'];
gc = [0 0 0; 0.85 0.33 0.10; 0 0.45 0.74; 0.47 0.67 0.19];
gs = {'-', '--', ':', '-.'};
n = numel(steps);
fig = figure('Visible', 'off', 'Position', [20 20 520 * n 1500], 'Color', 'w');
tl = tiledlayout(fig, 4, n, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('Where %s households live on the grid, age by age (panel of %s)', arm, panel_name), ...
    ['Shading: share of households at each age (darker = more), scaled to each age''s largest bin. ' ...
     'Lines: grid points. Orange: the median household. Rows 3-4: grid points inside the middle-90% band']}, ...
    'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
for j = 1:n
    k = ladder.index(steps(j), S);
    r = case_load(steps(j), arm, panel_name);
    for alt = {'uniform_64x64', 'standard'}               % steps without that solve
        if isempty(r), r = case_load(steps(j), arm, alt{1}); end
    end
    if isempty(r), continue; end
    s = figures.panel_data(r).sim; ages = s.ages(:).';
    u1 = s.lambda; u2 = (s.sA + s.sH) ./ max(1 - u1, 1e-12);
    P = cell(1, numel(grids));
    for g = 1:numel(grids)
        rg = case_load(steps(j), arm, grids{g});
        if isempty(rg) && strcmp(grids{g}, 'uniform_16x16'), rg = case_load(steps(j), arm, 'standard'); end
        if isempty(rg), rg = struct('p', case_params(S(k).name, arm, grids{g})); end
        P{g} = rg.p;
    end
    y1 = log10(1 ./ max(u1, 1e-4));            % W/Y
    y2 = log10(max(1 - u2, 1e-4));             % liquid share of non-income wealth
    for row = 1:2
        ax = nexttile(tl, (row - 1) * n + j); hold(ax, 'on');
        if row == 1
            Y = y1; edges = linspace(0, 3.2, 121);
            yt = [1 2 3 5 10 20 50 100 300 1000];
            heat(ax, ages, edges, Y, cmap);
            for g = 1:numel(grids), hl(ax, log10(1 ./ P{g}.u1_grid), gc(g, :), gs{g}); end
            ttl = {sprintf('Step %s %s', ladder.number(k, S), S(k).name), 'total resources / income, W/Y'};
        else
            Y = y2; edges = linspace(-4, 0, 121);
            yt = [1e-4 1e-3 0.01 0.03 0.1 0.3 1];
            heat(ax, ages, edges, Y, cmap);
            for g = 1:numel(grids), hl(ax, log10(max(1 - P{g}.u2_grid, 1e-4)), gc(g, :), gs{g}); end
            ttl = 'liquid / (liquid + pension pot) = 1 - u2';
        end
        plot(ax, ages, median(Y, 1), '-', 'Color', [0.95 0.65 0.10], 'LineWidth', 2);
        set(ax, 'YTick', log10(yt), 'YTickLabel', arrayfun(@(v) sprintf('%g', v), yt, 'UniformOutput', false), ...
            'FontSize', 9, 'Layer', 'top');
        ylim(ax, edges([1 end])); xlim(ax, [25 100]); xline(ax, r.p.retirement_age, 'k:');
        title(ax, ttl, 'FontSize', 10, 'Interpreter', 'none');
    end
    for row = 3:4
        ax = nexttile(tl, (row - 1) * n + j); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        if row == 3, Y = u1; else, Y = u2; end
        lo = prctile(Y, 5, 1); hi = prctile(Y, 95, 1);
        h = gobjects(1, numel(grids));
        for g = 1:numel(grids)
            if row == 3, nodes = P{g}.u1_grid; else, nodes = P{g}.u2_grid; end
            cnt = arrayfun(@(t) sum(nodes >= lo(t) & nodes <= hi(t)), 1:numel(ages));
            h(g) = plot(ax, ages, cnt, gs{g}, 'Color', gc(g, :), 'LineWidth', 1.6);
        end
        xlim(ax, [25 100]); xline(ax, r.p.retirement_age, 'k:'); set(ax, 'FontSize', 9);
        if row == 3, title(ax, 'u1 grid points in the middle-90% band', 'FontSize', 10);
        else, title(ax, 'u2 grid points in the middle-90% band', 'FontSize', 10); end
        if j == 1 && row == 3, legend(ax, h, grids, 'Location', 'northeast', 'Interpreter', 'none'); end
        xlabel(ax, 'age');
    end
end
exportgraphics(fig, file, 'Resolution', 100);
close(fig);
end

function heat(ax, ages, edges, Y, cmap)
H = zeros(numel(edges) - 1, numel(ages));
for t = 1:numel(ages)
    c = histcounts(Y(:, t), edges);
    H(:, t) = c / max(max(c), 1);
end
mids = (edges(1:end-1) + edges(2:end)) / 2;
imagesc(ax, ages, mids, H); set(ax, 'YDir', 'normal'); colormap(ax, cmap); clim(ax, [0 1]);
end

function hl(ax, y, col, st)
for v = y(:).'
    yline(ax, v, st, 'Color', col, 'LineWidth', 0.8, 'Alpha', 0.8);
end
end
