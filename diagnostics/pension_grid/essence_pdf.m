function essence_pdf(out)
%ESSENCE_PDF  The grid study of the pension steps in five pages.
%
%   essence_pdf()                  % into <standard numerics dir>/pension_grid/essence/
%   essence_pdf(folder)
%
%   From the saved solves of the grid study (case_load), in the style of the
%   ladder's comparison pages: black is the finest grid solved for the step,
%   with its 10th-90th percentile band; lines are means over the same 10,000
%   simulated households.
%     1  step 12, owner: the answer on each grid size, before and after the fix
%        (figures.robustness, one row each)
%     2  steps 6 and 9-12, owner: the ladder's standard grid against the
%        finest grid and the fixed grid at 48x48
%     3  the same for the renter
%     4  step 10: the equity share stored where nothing is saved
%     5  why: where the households of step 12 are, against the grid points
%   Writes essence_<n>.png and grid_study_essence.pdf.

if nargin < 1 || isempty(out)
    out = fullfile(ladder.numerics('standard').dir, 'pension_grid', 'essence');
end
if ~isfolder(out), mkdir(out); end
st = figures.style();
pages = {};

% 1. Step 12, owner, by grid size
ref = case_load(12, 'owner', 'pow3_64x64_lim');
G = struct('name', {'Before the fix', 'After the fix'}, ...
           'rs', {cellfun(@(c) case_load(12, 'owner', c), {'standard', 'uniform_32x32', 'uniform_64x64'}, 'UniformOutput', false), ...
                  cellfun(@(c) case_load(12, 'owner', c), {'pow3_16x16_lim', 'pow3_32x32_lim', 'pow3_48x48_lim'}, 'UniformOutput', false)}, ...
           'labels', {{'evenly spaced 16x16 (the ladder''s standard grid)', 'evenly spaced 32x32', 'evenly spaced 64x64'}, ...
                      {'bunched 16x16', 'bunched 32x32', 'bunched 48x48'}});
pages{end+1} = fullfile(out, 'essence_1.png');
figures.robustness(ref, 'bunched 64x64 with the limit share', G, ...
    ['Step 12 (AOW), owner: the answer on each grid size. Top row: before the fix (evenly spaced grids). ' ...
     'Bottom row: after the fix (bunched grids, limit share)'], pages{end}, 'the finest grid solved');

% 2-3. Every pension step, old grid against the finest and the fixed grid
for arm = {'owner', 'renter'}
    pages{end+1} = fullfile(out, sprintf('essence_%d.png', numel(pages) + 1)); %#ok<AGROW>
    all_steps(arm{1}, st, pages{end});
end

% 4. Step 10: what is stored where nothing is saved
pages{end+1} = fullfile(out, 'essence_4.png');
stored_share(st, pages{end});

% 5. Why: households against grid points, step 12 owner
pages{end+1} = fullfile(out, 'essence_5.png');
grid_points(st, pages{end});

pdf = fullfile(out, 'grid_study_essence.pdf');
if isfile(pdf), delete(pdf); end
cover(pdf);
for i = 1:numel(pages), add_png(pdf, pages{i}); end
fprintf('Wrote %s\n', pdf);
end

% ------------------------------------------------------------------------
function all_steps(arm, st, file)
steps = [12 11 10 9 6];
name = containers.Map({12, 11, 10, 9, 6}, {'Step 12, AOW at 30.7%', 'Step 11, glide-path fund', ...
    'Step 10, all-stock fund', 'Step 9, all-bond fund', 'Step 6, no pension (control)'});
finest = containers.Map({12, 11, 10, 9, 6}, {'pow3_64x64_lim', 'pow3_64x64_lim', 'pow3_96x96_lim', ...
    'pow3_64x64_lim', 'uniform_128x128'});
fixed = containers.Map({12, 11, 10, 9, 6}, {'pow3_48x48_lim', 'pow3_48x48_lim', 'pow3_48x48_lim', ...
    'pow3_48x48_lim', 'pow3_32x32_lim'});
fig = figure('Visible', 'off', 'Position', [30 30 2200 2350], 'Color', 'w');
tl = tiledlayout(fig, numel(steps), 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('Every pension step, %s: the ladder''s standard grid against the finest grid', arm), ...
    ['Black = the finest grid solved for the step, with its 10th-90th percentile band. Orange dashed = the ladder''s ' ...
     'standard grid (evenly spaced 16x16), as the ladder solved it.'], ...
    ['Blue = the fixed grid (bunched 48x48 with the limit share; step 6: bunched 32x32). ' ...
     'It lies on the black line almost everywhere, so it is mostly hidden']}, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
L = 'abcdefghijklmnopqrstuvwxyz';
k = 0;
for i = 1:numel(steps)
    s = steps(i);
    R = {case_load(s, arm, finest(s)), case_load(s, arm, 'standard'), case_load(s, arm, fixed(s))};
    S = cellfun(@(r) r.summary, R, 'UniformOutput', false);
    a = S{1}.ages; sc = 1e-3;
    cols = {[0 0 0], st.series(2, :), st.series(1, :)};
    sty = {'-', '--', '-'}; lw = [2.4 1.9 1.7];
    for j = 1:3
        k = k + 1;
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        ax.FontSize = 10; ax.XLim = [25 100];
        xline(ax, 67, 'k--', 'HandleVisibility', 'off');
        switch j
            case 1
                band(ax, a, S{1}.X.p10 * sc, S{1}.X.p90 * sc);
                v = cellfun(@(x) x.X.mean * sc, S, 'UniformOutput', false);
                what = 'Liquid savings'; ylab = 'thousand EUR (2025)';
            case 2
                band(ax, a, S{1}.C.p10 * sc, S{1}.C.p90 * sc);
                v = cellfun(@(x) x.C.mean * sc, S, 'UniformOutput', false);
                what = 'Consumption and income'; ylab = 'thousand EUR (2025)';
                gc = [0.45 0.45 0.45];
                hy(1) = plot(ax, a, S{1}.Y.mean * sc, '--', 'Color', gc, 'LineWidth', 1.3);
                hy(2) = plot(ax, a, S{1}.net_income.mean * sc, ':', 'Color', gc, 'LineWidth', 1.6);
            case 3
                v = cellfun(@(r) r.piw, R, 'UniformOutput', false);
                what = 'Equity share of liquid saving'; ylab = 'stocks / liquid saving';
                ylim(ax, [0 1]);
        end
        h = gobjects(1, 3);
        for q = 3:-1:1
            h(q) = plot(ax, a, v{q}, sty{q}, 'Color', cols{q}, 'LineWidth', lw(q));
        end
        uistack(h(1), 'top');
        ylabel(ax, ylab);
        if i == numel(steps), xlabel(ax, 'Age'); end
        title(ax, sprintf('(%s)  %s: %s', L(k), name(s), lower(what)), 'FontSize', 11);
        if j == 2
            gap = 100 * (v{2}(a == 66) / v{1}(a == 66) - 1);
            text(ax, 0.98, 0.06, sprintf('consumption at 66: standard grid %+.1f%%', gap), 'Units', 'normalized', ...
                'HorizontalAlignment', 'right', 'FontSize', 10, 'Color', cols{2});
        elseif j == 1
            gap = 100 * (v{2}(a == 60) / v{1}(a == 60) - 1);
            text(ax, 0.98, 0.92, sprintf('liquid savings at 60: standard grid %+.0f%%', gap), 'Units', 'normalized', ...
                'HorizontalAlignment', 'right', 'FontSize', 10, 'Color', cols{2});
        end
        if i == 1 && j == 1
            legend(ax, h, {'finest grid', 'standard grid (as in the ladder)', 'fixed grid'}, 'Location', 'northwest', 'FontSize', 9);
        elseif i == 1 && j == 2
            legend(ax, hy, {'gross income', 'income after tax and contributions'}, 'Location', 'northwest', 'FontSize', 9);
        elseif i == 1 && j == 3
            text(ax, 0.02, 0.06, 'stocks over liquid saving across all households; blank where saving is under 1% of income', ...
                'Units', 'normalized', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);
        end
    end
end
exportgraphics(fig, file, 'Resolution', 110);
close(fig);
end

% ------------------------------------------------------------------------
function stored_share(st, file)
fig = figure('Visible', 'off', 'Position', [30 30 2000 760], 'Color', 'w');
tl = tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'Step 10 (all-stock fund): the equity share stored where nothing is saved, ages 55-80', ...
    ['Orange dashed: the ladder''s standard grid with 100% in stocks stored where nothing is saved (the rule of 15 October). ' ...
     'Blue: the same grid,'], ...
    ['with the share the first euro would take stored instead (the limit share). Black: the finest grid (bunched 96x96). ' ...
     'Consumption and savings are the same on both standard-grid solves']}, ...
    'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
arms = {'renter', 'owner'};
for i = 1:2
    R = {case_load(10, arms{i}, 'pow3_96x96_lim'), case_load(10, arms{i}, 'standard'), case_load(10, arms{i}, 'uniform_16x16_lim')};
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    ax.FontSize = 10; ax.XLim = [55 80]; ylim(ax, [0 1]);
    xline(ax, 67, 'k--', 'HandleVisibility', 'off');
    a = R{1}.summary.ages;
    cols = {[0 0 0], st.series(2, :), st.series(1, :)}; sty = {'-o', '--o', '-o'}; lw = [2.4 1.9 1.7];
    h = gobjects(1, 3);
    for q = 3:-1:1
        h(q) = plot(ax, a, R{q}.piw, sty{q}, 'Color', cols{q}, 'LineWidth', lw(q), 'MarkerSize', 5, ...
            'MarkerFaceColor', 'w');
    end
    uistack(h(1), 'top');
    v66 = cellfun(@(r) r.piw(r.summary.ages == 66), R);
    fin = sprintf('%.2f on the finest grid', v66(1));
    if isnan(v66(1)), fin = 'finest grid: almost no liquid saving left at 66'; end
    text(ax, 67.5, 0.62, sprintf('at 66:\n%.2f with 100%% stored\n%.2f with the limit share\n%s', ...
        v66(2), v66(3), fin), 'FontSize', 11, 'Color', [0.2 0.2 0.2], 'VerticalAlignment', 'top');
    ylabel(ax, 'equity share of liquid saving (stocks / liquid saving)'); xlabel(ax, 'Age');
    title(ax, sprintf('(%s)  %s', char('a' + i - 1), arms{i}), 'FontSize', 11);
    if i == 1
        legend(ax, h, {'finest grid', 'standard grid, 100% stored', 'standard grid, limit share'}, 'Location', 'southwest', 'FontSize', 9);
    end
end
exportgraphics(fig, file, 'Resolution', 110);
close(fig);
end

% ------------------------------------------------------------------------
function grid_points(st, file)
r = case_load(12, 'owner', 'pow3_64x64_lim');
sim = figures.panel_data(r).sim; ages = sim.ages(:).';
wy = 1 ./ sim.lambda;
liq = max(1 - (sim.sA + sim.sH) ./ max(1 - sim.lambda, 1e-12), 1e-4);
P = {case_params(12, 'owner', 'uniform_16x16'), case_params(12, 'owner', 'pow3_16x16_lim')};
gname = {'evenly spaced 16x16 (the ladder''s standard grid)', 'bunched 16x16 (the fix)'};
fig = figure('Visible', 'off', 'Position', [30 30 2000 1300], 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'Why: where the households of step 12 (owner) are, against the grid points', ...
    'Blue: the households at each age (line: median; dark band: middle half; light band: middle 90%), from the finest grid.', ...
    ['Black lines: grid points; the solver knows the value function only there and draws straight lines in between. ' ...
     'Both grids have the same number of points']}, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
c = st.series(1, :);
for row = 1:2
    for g = 1:2
        ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on');
        ax.FontSize = 10; ax.XLim = [25 100]; set(ax, 'YScale', 'log');
        if row == 1
            Y = wy; pts = 1 ./ P{g}.u1_grid; yl = [1 1500];
            yt = [1 2 5 10 20 50 100 200 500 1000];
            what = 'total resources over income (W/Y = 1/u1)';
        else
            Y = liq; pts = 1 - P{g}.u2_grid; pts = pts(pts > 0); yl = [1e-4 1];
            yt = [1e-4 1e-3 1e-2 0.1 1];
            what = 'liquid savings over liquid savings plus pension pot (1 - u2)';
        end
        q = prctile(Y, [5 25 50 75 95], 1);
        fill(ax, [ages, fliplr(ages)], [q(1, :), fliplr(q(5, :))], c, 'EdgeColor', 'none', 'FaceAlpha', 0.15);
        fill(ax, [ages, fliplr(ages)], [q(2, :), fliplr(q(4, :))], c, 'EdgeColor', 'none', 'FaceAlpha', 0.35);
        plot(ax, ages, q(3, :), '-', 'Color', c, 'LineWidth', 2);
        for v = pts(pts >= yl(1) & pts <= yl(2)).'
            yline(ax, v, '-', 'Color', [0 0 0], 'LineWidth', 0.9, 'Alpha', 0.6);
        end
        xline(ax, 67, 'k--');
        ylim(ax, yl); set(ax, 'YTick', yt, 'YTickLabel', arrayfun(@(t) sprintf('%g', t), yt, 'UniformOutput', false));
        ylabel(ax, what); xlabel(ax, 'Age');
        inband = arrayfun(@(t) sum(pts >= q(1, t) & pts <= q(5, t)), 1:numel(ages));
        r67 = ages >= 67 & ages <= 85;
        title(ax, sprintf('(%s)  %s: %s', char('a' + 2 * (row - 1) + g - 1), gname{g}, ...
            sprintf('%d to %d points where the middle 90%% of retirees (67-85) are', min(inband(r67)), max(inband(r67)))), ...
            'FontSize', 11, 'Interpreter', 'none');
    end
end
exportgraphics(fig, file, 'Resolution', 110);
close(fig);
end

% ------------------------------------------------------------------------
function band(ax, a, lo, hi)
fill(ax, [a, fliplr(a)], [lo, fliplr(hi)], [0.85 0.85 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.6, ...
    'HandleVisibility', 'off');
end

function cover(pdf)
L = {
 'The grid study of the pension steps, in five pages (16 October 2026)'
 ''
 'What was found'
 '1. On the ladder''s standard grid (evenly spaced 16x16) the pension steps 9-12 are not grid-converged.'
 '   Against the finest grid, liquid savings at 60 are 16-37% too high and consumption at 66 is 3-11% too high.'
 '   Step 6, without a pension, is converged on the same grid. So the pension is what breaks it.'
 '2. Why: with a pension, retirees hold 15-60 years of income in total resources and keep little liquid saving'
 '   beside the pot. The evenly spaced grid has no point between 15 and 1,250 years of income and two points'
 '   above a pot share of 0.93, so these households sit in one wide cell and the value between points is a'
 '   straight line. A second, smaller problem: where a household saves nothing the solver stored 100% in'
 '   stocks, and savers next to such points take part of that number (visible at step 10).'
 '3. The fix changes no economics: the same axes and number of points, bunched by a cube'
 '   (grid_pow 3, grid_pow_u2 3), and the share the first euro would take stored where nothing is saved'
 '   (pi_nothing_saved = ''limit''). With it the answers stop moving with the grid; 48x48 is within the'
 '   ladder''s tolerance at every pension step.'
 ''
 'The pages'
 '1. Step 12, owner: the answer on each grid size, before the fix (top row) and after it (bottom row).'
 '2. Every pension step, owner: the standard grid against the finest grid and the fixed grid.'
 '3. The same for the renter.'
 '4. Step 10: the equity share stored where nothing is saved.'
 '5. Why: where the households are, against the grid points.'
 ''
 'Black is always the finest grid solved for the step, with its 10th-90th percentile band. Lines are means over'
 'the same 10,000 simulated households. On page 1 the difference panels have their own scale in each row, and the'
 'spike in the equity share around 31 is households who do not save yet: their share has no effect.'
 'Scripts: diagnostics/pension_grid/ (essence_pdf.m); details in HANDOFF.md.'
};
fig = figure('Visible', 'off', 'Position', [0 0 1700 1100], 'Color', 'w');
ax = axes(fig, 'Position', [0.05 0.04 0.9 0.92]); axis(ax, 'off');
text(ax, 0, 1, L, 'FontSize', 13, 'VerticalAlignment', 'top', 'Interpreter', 'none');
exportgraphics(fig, pdf, 'Append', true, 'ContentType', 'image', 'Resolution', 100);
close(fig);
end

function add_png(pdf, file)
I = imread(file);
[h, w, ~] = size(I);
fig = figure('Visible', 'off', 'Position', [0 0 round(w / 1.3) round(h / 1.3)], 'Color', 'w');
ax = axes(fig, 'Position', [0 0 1 1]);
image(ax, I); axis(ax, 'image', 'off');
exportgraphics(fig, pdf, 'Append', true, 'ContentType', 'image', 'Resolution', 110);
close(fig);
end
