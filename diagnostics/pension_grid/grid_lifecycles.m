function grid_lifecycles(step, arm, rows, file, ttl)
%GRID_LIFECYCLES  Simulated life cycles of one step as the grid is refined.
%
%   From the repository root:
%       addpath diagnostics/pension_grid
%       rows = struct('name', {'u1 x u2'}, 'cases', {{'pow3_20x20_lim_u3p2', ...
%           'pow3_24x24_lim_u3p2'}}, 'labels', {{'20x20', '24x24'}}, ...
%           'extra', {'standard'}, 'extra_label', {'ladder grid'});
%       grid_lifecycles(16, 'owner', rows, 'lifecycles_16_owner.png', 'Owner, step 16')
%
%   rows is a struct array, one row of panels per refinement sequence, with
%   fields name, cases (case_load names, coarse to fine) and labels, and
%   optionally extra and extra_label: one more case drawn grey and dashed
%   beside the sequence, such as the ladder's own grid ('' for none).
%   Columns: mean and median consumption and mean liquid saving (multiples of
%   mean income at entry), the mean liquid equity share, the equity share of
%   liquid saving (all households' stocks over their liquid saving, case_load's
%   piw), and the share of households at the floor. Every line is over the
%   same simulated households. Within a row coarse grids are light and fine
%   ones dark, in one hue; the second row takes a second hue. Dotted vertical
%   lines: the end of the mortgage (owners) and retirement.

hex = @(h) sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;
ramps = {{'#86b6ef', '#3987e5', '#256abf', '#184f95', '#0d366b'}, ...    % blue, ordinal
         {'#f2a27a', '#eb6834', '#c9521f', '#a04118', '#763010'}};       % orange, ordinal
grey = hex('#898781'); ink2 = hex('#52514e'); gridc = hex('#e1e0d9');
cols = {'mean consumption', 'median consumption', 'mean liquid saving', ...
        'mean liquid equity share', 'equity share of liquid saving', 'share at the floor'};
nc = numel(cols); nr = numel(rows);

fig = figure('Visible', 'off', 'Position', [20 20 420 * nc, 380 * nr + 90], 'Color', 'w');
tl = tiledlayout(fig, nr, nc, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {ttl, ['Each line is the same 10,000 simulated households on a different grid; light = coarse, dark = fine. ' ...
    'Levels in multiples of mean income at 25. Dotted: end of the mortgage (owners) and retirement']}, ...
    'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');

for i = 1:nr
    R = rows(i);
    n = numel(R.cases);
    ramp = ramps{1 + mod(i - 1, numel(ramps))};
    pick = round(linspace(1, numel(ramp), n));
    if n == 1, pick = numel(ramp); end
    lines = cell(1, n); names = R.labels;
    for k = 1:n
        lines{k} = series(step, arm, R.cases{k});
        lines{k}.color = hex(ramp{pick(k)}); lines{k}.style = '-';
    end
    if isfield(R, 'extra') && ~isempty(R.extra)
        e = series(step, arm, R.extra);
        if ~isempty(e)
            e.color = grey; e.style = '--';
            lines = [{e}, lines]; names = [{R.extra_label}, names];
        end
    end
    keep = ~cellfun(@isempty, lines);
    lines = lines(keep); names = names(keep);
    if isempty(lines), continue; end
    Y0 = lines{end}.Y0;
    for j = 1:nc
        ax = nexttile(tl, (i - 1) * nc + j); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
        set(ax, 'FontSize', 9, 'GridColor', gridc, 'GridAlpha', 1, 'XColor', ink2, 'YColor', ink2);
        h = gobjects(1, numel(lines));
        for k = 1:numel(lines)
            L = lines{k};
            switch j
                case 1, v = L.C / Y0;
                case 2, v = L.Cmed / Y0;
                case 3, v = L.X / Y0;
                case 4, v = L.pi;
                case 5, v = L.piw;
                case 6, v = 100 * L.fl;
            end
            h(k) = plot(ax, L.ages, v, L.style, 'Color', L.color, 'LineWidth', 2);
        end
        xlim(ax, [25 L.ages(end)]);
        for x = lines{end}.marks, xline(ax, x, ':', 'Color', grey, 'HandleVisibility', 'off'); end
        if j == 4 || j == 5, ylim(ax, [0 1]); end
        if j == 6, ylabel(ax, '% of households'); end
        if i == nr, xlabel(ax, 'age'); end
        title(ax, sprintf('%s: %s', R.name, cols{j}), 'FontSize', 10, 'Interpreter', 'none');
        if j == nc      % the floor panel: its top left is empty until old age
            legend(ax, h, names, 'Location', 'northwest', 'FontSize', 8.5, 'Interpreter', 'none', ...
                'TextColor', hex('#0b0b0b'));
        end
    end
end
exportgraphics(fig, file, 'Resolution', 110);
close(fig);
fprintf('wrote %s\n', file);
end

function L = series(step, arm, name)
% The age profiles of one saved solve; [] when it is not there.
r = case_load(step, arm, name);
if isempty(r), L = []; return; end
s = figures.panel_data(r).sim;
L.ages = s.ages(:).';
L.C    = mean(s.C, 1);
L.Cmed = median(s.C, 1);
L.X    = mean(s.X, 1);
L.pi   = mean(s.pi, 1);
L.piw  = r.piw;
L.fl   = mean(s.floored, 1);
L.Y0   = mean(s.Y(:, 1));
L.marks = r.p.retirement_age;
if any(r.p.q_live)
    L.marks = [r.p.age0 + find(r.p.q_live, 1, 'last'), L.marks];   % first age without a mortgage
end
end
