function housing_pdf(cover_lines, out)
%HOUSING_PDF  The bunched grid against the log-wealth grid at housing step 7b.
%
%   housing_pdf(cover_lines)          % into <standard numerics dir>/pension_grid/housing/
%
%   Step 7b (annuity mortgage) with maintenance on the purchase price and the
%   limit share, renter and owner, from the saved solves (case_load, suffix
%   _lim_mop). The reference (black) is bunched 64x64. Pages:
%     1-2  owner and renter: figures.robustness with a row for the ladder's grid
%          (evenly spaced 16x16, as ladder.sensitivity solved it), one for the
%          bunched grids (power 3) and one for the log-wealth grids
%     3    the largest gap to the reference against grid size, both families,
%          by age band, and the solve time of each grid
%     4    owner: where households are against the grid points, evenly spaced,
%          bunched and log-wealth at 16 points per axis
%   Writes housing_<n>.png and grid_study_housing.pdf.

if nargin < 2 || isempty(out)
    out = fullfile(ladder.numerics('standard').dir, 'pension_grid', 'housing');
end
if ~isfolder(out), mkdir(out); end
st = figures.style();
P3 = {'pow3_16x16_lim_mop', 'pow3_24x24_lim_mop', 'pow3_32x32_lim_mop', 'pow3_48x48_lim_mop', 'pow3_64x64_lim_mop'};
LW = {'logw_16x16_lim_mop', 'logw_32x32_lim_mop', 'logw_64x48_lim_mop'};
lab = @(c) strrep(strrep(regexprep(c, '_lim_mop$', ''), 'pow3_', 'bunched '), 'logw_', 'log-wealth ');
pages = {};
refs = struct();
for arm = {'owner', 'renter'}
    a = arm{1};
    % The reference: the solved grid with the most points (bunched 64x64 once it is there)
    [REF, ref] = finest(a, [P3, LW]);      % bunched 64x64 once solved; the finest so far before that
    refs.(a) = REF;
    sel = @(cs) cs(cellfun(@(c) ~strcmp(c, REF) && ~isempty(case_load("7b", a, c)), cs));
    p3 = sel(P3); lw = sel(LW);
    G = struct('name', {'The ladder''s grid', 'Bunched (power 3)', 'Log-wealth'}, ...
        'rs', {{case_load("7b", a, 'standard_mop')}, ...
               cellfun(@(c) case_load("7b", a, c), p3, 'UniformOutput', false), ...
               cellfun(@(c) case_load("7b", a, c), lw, 'UniformOutput', false)}, ...
        'labels', {{'evenly spaced 16x16, 100% stored where nothing is saved'}, ...
                   cellfun(lab, p3, 'UniformOutput', false), cellfun(lab, lw, 'UniformOutput', false)});
    G = G(arrayfun(@(g) ~isempty(g.rs) && all(~cellfun(@isempty, g.rs)), G));
    pages{end+1} = fullfile(out, sprintf('housing_%d.png', numel(pages) + 1)); %#ok<AGROW>
    figures.robustness(ref, [lab(REF) ' with the limit share'], G, ...
        sprintf('Step 7b (annuity mortgage, maintenance on the purchase price), %s: the answer on each grid size and rule', a), ...
        pages{end}, 'the finest grid solved');
end
pages{end+1} = fullfile(out, 'housing_3.png');
gaps_page(st, P3, LW, refs, pages{end});
pages{end+1} = fullfile(out, 'housing_4.png');
points_page(st, pages{end});

pdf = fullfile(out, 'grid_study_housing.pdf');
if isfile(pdf), delete(pdf); end
cover(pdf, cover_lines);
for i = 1:numel(pages), add_png(pdf, pages{i}); end
fprintf('Wrote %s\n', pdf);
end

% ------------------------------------------------------------------------
function [name, r] = finest(arm, cases)
% The solved case with the most grid points.
name = ''; r = []; best = 0;
for c = cases
    x = case_load("7b", arm, c{1});
    if ~isempty(x) && x.p.N_u1 * x.p.N_u2 > best
        best = x.p.N_u1 * x.p.N_u2; name = c{1}; r = x;
    end
end
end

% ------------------------------------------------------------------------
function gaps_page(st, P3, LW, refs, file)
fams = {P3, LW}; fname = {'bunched (power 3)', 'log-wealth'};
cols = {st.series(1, :), st.series(2, :)};
rows = {'C', 1, 'consumption, ages 26-39', 100, '%'; 'C', 2, 'consumption, ages 40-66', 100, '%'; ...
        'C', 3, 'consumption, ages 67-95', 100, '%'; 'piw', 2, 'equity share of liquid saving, 40-66', 1, ''; ...
        'piw', 3, 'equity share of liquid saving, 67-95', 1, ''; 'time', 0, 'solve time', 1 / 60, 'minutes'};
arms = {'owner', 'renter'};
fig = figure('Visible', 'off', 'Position', [30 30 1700 2100], 'Color', 'w');
tl = tiledlayout(fig, size(rows, 1), 2, 'Padding', 'compact', 'TileSpacing', 'compact');
nm = @(c) strrep(strrep(regexprep(c, '_lim_mop$', ''), 'pow3_', 'bunched '), 'logw_', 'log-wealth ');
title(tl, {sprintf('Step 7b: the largest gap to the finest grid (owner %s, renter %s) against grid size, and the solve time', ...
    nm(refs.owner), nm(refs.renter)), ...
    ['Blue: bunched (power 3). Orange: log-wealth. Black square: the ladder''s grid (evenly spaced 16x16). ' ...
     'Dashed: the stop rule (2% in consumption, 0.02 in the share)'], ...
    'Solve times ran two or three at a time on this PC: alone they are shorter'}, ...
    'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
L = 'abcdefghijklmnop'; k = 0;
for i = 1:size(rows, 1)
    for j = 1:2
        k = k + 1;
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        ax.FontSize = 10; set(ax, 'XScale', 'log');
        ref = case_load("7b", arms{j}, refs.(arms{j}));
        timing = strcmp(rows{i, 1}, 'time');
        h = gobjects(0); lab = {};
        for f = 1:2
            x = []; y = [];
            for c = fams{f}
                r = case_load("7b", arms{j}, c{1});
                if isempty(r) || (~timing && strcmp(c{1}, refs.(arms{j}))), continue; end
                x(end+1) = side(r); %#ok<AGROW>
                y(end+1) = metric(r, ref, rows(i, :)); %#ok<AGROW>
            end
            if isempty(x), continue; end
            [x, o] = sort(x); y = y(o);
            h(end+1) = plot(ax, x, y, '-o', 'Color', cols{f}, 'LineWidth', 1.8, 'MarkerFaceColor', 'w'); %#ok<AGROW>
            lab{end+1} = fname{f}; %#ok<AGROW>
        end
        r0 = case_load("7b", arms{j}, 'standard_mop');
        if ~isempty(r0) && ~isempty(ref)
            plot(ax, side(r0), metric(r0, ref, rows(i, :)), 's', 'Color', 'k', 'MarkerFaceColor', 'k', 'MarkerSize', 7);
        end
        if ~strcmp(rows{i, 1}, 'time')
            yline(ax, 2 * strcmp(rows{i, 1}, 'C') + 0.02 * strcmp(rows{i, 1}, 'piw'), 'k--');
            ylim(ax, [0, max([ax.YLim(2), 0.05])]);
        end
        xlim(ax, [14 72]); set(ax, 'XTick', [16 24 32 48 64], 'XTickLabel', {'16x16', '24x24', '32x32', '48x48', '64x64'});
        ylabel(ax, rows{i, 5}); if i == size(rows, 1), xlabel(ax, 'grid size (log-wealth 64x48 drawn at 55)'); end
        title(ax, sprintf('(%s)  %s: %s', L(k), arms{j}, rows{i, 3}), 'FontSize', 11);
        if k == 1 && ~isempty(h), legend(ax, h, lab, 'Location', 'northeast', 'FontSize', 9); end
    end
end
exportgraphics(fig, file, 'Resolution', 110);
close(fig);
end

function s = side(r)
% Base points per axis (the entry anchors add two to each), as one number
s = sqrt((r.p.N_u1 - 2) * (r.p.N_u2 - 2));
end

function v = metric(r, ref, row)
if strcmp(row{1}, 'time'), v = r.timing.solve_sec * row{4}; return; end
g = case_gaps(r, ref);
v = g.(row{1})(row{2}) * row{4};
end

% ------------------------------------------------------------------------
function points_page(st, file)
[~, r] = finest('owner', {'pow3_64x64_lim_mop', 'logw_64x48_lim_mop', 'pow3_48x48_lim_mop', 'pow3_32x32_lim_mop', 'pow3_24x24_lim_mop'});
sim = figures.panel_data(r).sim; ages = sim.ages(:).';
wy  = 1 ./ sim.lambda;
liq = max(1 - (sim.sA + sim.sH) ./ max(1 - sim.lambda, 1e-12), 1e-4);
P = {case_params('annuity', 'owner', 'uniform_16x16_mop'), case_params('annuity', 'owner', 'pow3_16x16_lim_mop'), ...
     case_params('annuity', 'owner', 'logw_16x16_lim_mop')};
gname = {'evenly spaced 16x16 (the ladder''s grid)', 'bunched 16x16 (power 3)', 'log-wealth 16x16'};
fig = figure('Visible', 'off', 'Position', [30 30 2400 1300], 'Color', 'w');
tl = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'Step 7b, owner: where households are, against the grid points (16 per axis on every grid)', ...
    'Blue: the households at each age (line: median; dark band: middle half; light band: middle 90%), from the finest grid.', ...
    ['Black lines: grid points. With housing, total resources include the house, and the second axis is ' ...
     'liquid savings against liquid savings plus the house']}, 'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
c = st.series(1, :);
for row = 1:2
    for g = 1:3
        ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on');
        ax.FontSize = 10; ax.XLim = [25 100]; set(ax, 'YScale', 'log');
        if row == 1
            Y = wy; pts = 1 ./ P{g}.u1_grid; yl = [1 6000]; yt = [1 2 5 10 20 50 100 200 500 1000 5000];
            what = 'total resources over income (1/u1)';
        else
            Y = liq; pts = 1 - P{g}.u2_grid; pts = pts(pts > 0); yl = [1e-4 1]; yt = [1e-4 1e-3 1e-2 0.1 1];
            what = 'liquid / (liquid + house) (1 - u2)';
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
        w = ages >= 30 & ages <= 85;
        title(ax, sprintf('(%s)  %s: %d to %d points where the middle 90%% are (30-85)', ...
            char('a' + 3 * (row - 1) + g - 1), gname{g}, min(inband(w)), max(inband(w))), 'FontSize', 11, 'Interpreter', 'none');
    end
end
exportgraphics(fig, file, 'Resolution', 110);
close(fig);
end

% ------------------------------------------------------------------------
function cover(pdf, L)
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
