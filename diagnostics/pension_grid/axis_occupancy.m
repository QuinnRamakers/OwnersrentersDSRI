function T = axis_occupancy(step, arm, panel_case, grids, labels, file)
%AXIS_OCCUPANCY  Where households sit on each grid axis, by age, against grid points.
%
%   From the repository root:
%       addpath diagnostics/pension_grid
%       T = axis_occupancy(16, 'owner', 'pow3_32x32_lim_u3p2', ...
%           {'uniform_16x16', 'pow3_24x24_lim_u3p2'}, {'ladder grid', 'bunched 24x24'}, ...
%           'occupancy_16_owner.png');
%
%   The households are the simulated panel of panel_case (case_load). One
%   column per axis: total resources over income W/Y = 1/u1 (log scale), the
%   liquid share of non-income wealth 1 - u2 (log scale), the pot against pot
%   plus house u3, and for owners the purchase price over the house q (a
%   state only while the mortgage runs). One row per grid in grids (case_params
%   names; 'uniform_16x16' is the ladder's own grid): the shading is the share
%   of households at each age, scaled to each age's largest bin, the grey
%   lines the grid points, the orange line the median household. The last row
%   counts each grid's points inside the band of the middle 90% of
%   households, by age. Returns that count at a few ages as a table.

hex = @(h) sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;
cmap = interp1([0 1], [hex('#fcfcfb'); hex('#256abf')], linspace(0, 1, 256));
gcol = {hex('#0b0b0b'), hex('#eb6834'), hex('#1baf7a'), hex('#e87ba4')};
node_col = hex('#52514e'); med_col = hex('#eb6834');

r = case_load(step, arm, panel_case);
assert(~isempty(r), 'axis_occupancy:panel', 'the panel %s (%s) is not solved.', panel_case, arm);
s = figures.panel_data(r).sim; ages = s.ages(:).';
sAH = s.sA + s.sH;
X = {s.lambda, sAH ./ max(1 - s.lambda, 1e-12), s.sA ./ max(sAH, 1e-12), s.q};
P = cellfun(@(g) case_params(step, arm, g), grids, 'UniformOutput', false);
nodes = @(p) {p.u1_grid, p.u2_grid, p.u3_grid, p.q_grid};

ax_names = {'total resources / income, W/Y = 1/u1', 'liquid / non-income wealth, 1 - u2', ...
            'pot / (pot + house), u3', 'purchase price / house, q'};
fwd = {@(v) log10(1 ./ max(v, 1e-5)), @(v) log10(max(1 - v, 1e-4)), @(v) v, @(v) v};
edges = {linspace(0, 3.8, 121), linspace(-4, 0, 121), linspace(0, 1, 101), linspace(0, 2.5, 101)};
ticks = {[1 2 5 10 20 50 100 300 1000 3000], [1e-4 1e-3 0.01 0.03 0.1 0.3 1], 0:0.2:1, 0:0.5:2.5};
tpos  = {@log10, @log10, @(v) v, @(v) v};     % where a tick value sits on the drawn scale
na = 3 + any(r.p.q_live);
xmax = [100 100 100 r.p.age0 + find(r.p.q_live, 1, 'last') + 5];
ng = numel(grids);

fig = figure('Visible', 'off', 'Position', [20 20 520 * na, 330 * (ng + 1) + 80], 'Color', 'w');
tl = tiledlayout(fig, ng + 1, na, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('%s, step %s: where households sit on each axis, by age (panel of %s)', arm, string(step), panel_case), ...
    ['Shading: share of households at each age (darker = more). Grey lines: grid points. ' ...
     'Orange: the median household. Last row: grid points inside the middle-90% band']}, ...
    'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
cnt = cell(ng, na);
for j = 1:na
    Y = fwd{j}(X{j});
    lo = prctile(X{j}, 5, 1); hi = prctile(X{j}, 95, 1);
    for g = 1:ng
        nd = nodes(P{g}); nd = nd{j};
        cnt{g, j} = arrayfun(@(t) sum(nd >= lo(t) - 1e-12 & nd <= hi(t) + 1e-12), 1:numel(ages));
        ax = nexttile(tl, (g - 1) * na + j); hold(ax, 'on');
        heat(ax, ages, edges{j}, Y, cmap);
        for v = fwd{j}(nd(:)).'
            yline(ax, v, '-', 'Color', node_col, 'LineWidth', 0.6, 'Alpha', 0.7);
        end
        plot(ax, ages, median(Y, 1), '-', 'Color', med_col, 'LineWidth', 2);
        set(ax, 'YTick', tpos{j}(ticks{j}), 'YTickLabel', arrayfun(@(v) sprintf('%g', v), ...
            ticks{j}, 'UniformOutput', false), 'FontSize', 9, 'Layer', 'top');
        ylim(ax, edges{j}([1 end])); xlim(ax, [25 xmax(j)]);
        xline(ax, r.p.retirement_age, 'k:');
        title(ax, sprintf('%s: %s (%d points)', labels{g}, ax_names{j}, numel(nd)), ...
            'FontSize', 10, 'Interpreter', 'none');
    end
    ax = nexttile(tl, ng * na + j); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    h = gobjects(1, ng);
    for g = 1:ng
        h(g) = plot(ax, ages, cnt{g, j}, '-', 'Color', gcol{g}, 'LineWidth', 1.8);
    end
    xlim(ax, [25 xmax(j)]); xline(ax, r.p.retirement_age, 'k:'); set(ax, 'FontSize', 9);
    title(ax, sprintf('points inside the middle-90%% band: %s', ax_names{j}), 'FontSize', 10, 'Interpreter', 'none');
    xlabel(ax, 'age');
    if j == 1, legend(ax, h, labels, 'Location', 'northwest', 'Interpreter', 'none', 'FontSize', 8.5); end
end
exportgraphics(fig, file, 'Resolution', 100);
close(fig);
fprintf('wrote %s\n', file);

pick = [30 40 50 55 60 67 75 85 95];
k = ismember(ages, pick);
T = table();
short = {'u1', 'u2', 'u3', 'q'};
for g = 1:ng
    for j = 1:na
        row = table(string(labels{g}), string(short{j}), 'VariableNames', {'grid', 'axis'});
        c = cnt{g, j}(k);
        for i = 1:numel(pick), row.(sprintf('a%d', pick(i))) = c(i); end
        T = [T; row]; %#ok<AGROW>
    end
end
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
