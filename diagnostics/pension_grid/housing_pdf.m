function housing_pdf(cover_lines, step, out)
%HOUSING_PDF  The grid study's pages for a housing step.
%
%   housing_pdf(cover_lines)          % step 7b
%   housing_pdf(cover_lines, 13)      % step 13, housing with AOW and the DC pension
%   housing_pdf(cover_lines, step, out)
%
%   The step with maintenance on the purchase price and the limit share,
%   renter and owner, from the saved solves (case_load, suffix _lim_mop).
%   The reference (black) is the finest grid solved. Pages, each where its
%   solves are there:
%     1-2  owner and renter: figures.robustness with a row for the ladder's grid
%          (evenly spaced 16x16, as ladder.sensitivity solved it), one for the
%          bunched grids (power 3) and one for the log-wealth grids
%     3    the largest gap to the reference against grid size, both families,
%          by age band, and the solve time of each grid
%     4    owner: where households are against the grid points at 16 points per
%          axis, evenly spaced, bunched and log-wealth; where the pension
%          against the house (u3) is a live axis, also u3 at its base and
%          doubled points
%     then the checks on a fixed grid, per household and grid: u3 doubled
%          (_u3x2) and without the grid search before fmincon (_nosweep),
%          against the same grid as solved
%   Writes housing_<n>.png and grid_study_housing_<step>.pdf into
%   <standard numerics dir>/pension_grid/housing_<step>/ unless out is given.

if nargin < 2 || isempty(step), step = '7b'; end
S = ladder.steps();
k = ladder.index(step, S);
sid = ladder.number(k, S);
what = sprintf('Step %s (%s%s, maintenance on the purchase price)', sid, lower(S(k).label(1)), S(k).label(2:end));
if nargin < 3 || isempty(out)
    out = fullfile(ladder.numerics('standard').dir, 'pension_grid', ['housing_' sid]);
end
if ~isfolder(out), mkdir(out); end
st = figures.style();
P3 = {'pow3_16x16_lim_mop', 'pow3_24x24_lim_mop', 'pow3_32x32_lim_mop', 'pow3_48x48_lim_mop', 'pow3_64x64_lim_mop'};
LW = {'logw_16x16_lim_mop', 'logw_32x32_lim_mop', 'logw_64x48_lim_mop'};
pages = {};
refs = struct();
for arm = {'owner', 'renter'}
    a = arm{1};
    [REF, ref] = finest(sid, a, [P3, LW]);
    refs.(a) = REF;
    if isempty(REF), continue; end
    sel = @(cs) cs(cellfun(@(c) ~strcmp(c, REF) && ~isempty(case_load(sid, a, c)), cs));
    p3 = sel(P3); lw = sel(LW);
    G = struct('name', {'The ladder''s grid', 'Bunched (power 3)', 'Log-wealth'}, ...
        'rs', {{case_load(sid, a, 'standard_mop')}, ...
               cellfun(@(c) case_load(sid, a, c), p3, 'UniformOutput', false), ...
               cellfun(@(c) case_load(sid, a, c), lw, 'UniformOutput', false)}, ...
        'labels', {{'evenly spaced 16x16, 100% stored where nothing is saved'}, ...
                   cellfun(@lab, p3, 'UniformOutput', false), cellfun(@lab, lw, 'UniformOutput', false)});
    G = G(arrayfun(@(g) ~isempty(g.rs) && all(~cellfun(@isempty, g.rs)), G));
    if isempty(G), continue; end
    pages{end+1} = page(out, pages); %#ok<AGROW>
    figures.robustness(ref, [lab(REF) ' with the limit share'], G, ...
        sprintf('%s, %s: the answer on each grid size and rule', what, a), pages{end}, 'the finest grid solved');
end
pages{end+1} = page(out, pages);
gaps_page(st, sid, P3, LW, refs, pages{end});
if ~isempty(refs.owner)
    pages{end+1} = page(out, pages);
    points_page(st, sid, S(k).name, [P3, LW], pages{end});
end
pages = check_pages(sid, what, out, pages);

pdf = fullfile(out, sprintf('grid_study_housing_%s.pdf', sid));
if isfile(pdf), delete(pdf); end
cover(pdf, cover_lines);
for i = 1:numel(pages), add_png(pdf, pages{i}); end
fprintf('Wrote %s\n', pdf);
end

% ------------------------------------------------------------------------
function f = page(out, pages)
f = fullfile(out, sprintf('housing_%d.png', numel(pages) + 1));
end

function s = lab(c)
s = strrep(strrep(regexprep(c, '_lim_mop$', ''), 'pow3_', 'bunched '), 'logw_', 'log-wealth ');
end

% ------------------------------------------------------------------------
function [name, r] = finest(sid, arm, cases)
% The solved case with the most grid points.
name = ''; r = []; best = 0;
for c = cases
    x = case_load(sid, arm, c{1});
    if ~isempty(x) && x.p.N_u1 * x.p.N_u2 > best
        best = x.p.N_u1 * x.p.N_u2; name = c{1}; r = x;
    end
end
end

% ------------------------------------------------------------------------
function gaps_page(st, sid, P3, LW, refs, file)
fams = {P3, LW}; fname = {'bunched (power 3)', 'log-wealth'};
cols = {st.series(1, :), st.series(2, :)};
rows = {'C', 1, 'consumption, ages 26-39', 100, '%'; 'C', 2, 'consumption, ages 40-66', 100, '%'; ...
        'C', 3, 'consumption, ages 67-95', 100, '%'; 'piw', 2, 'equity share of liquid saving, 40-66', 1, ''; ...
        'piw', 3, 'equity share of liquid saving, 67-95', 1, ''; 'time', 0, 'solve time', 1 / 60, 'minutes'};
arms = {'owner', 'renter'};
has = @(cs) any(cellfun(@(a) any(cellfun(@(c) ~isempty(case_load(sid, a, c)), cs)), arms));
key = {'Blue: bunched (power 3).'};
if has(LW), key{end+1} = 'Orange: log-wealth.'; end
if has({'standard_mop'}), key{end+1} = 'Black square: the ladder''s grid (evenly spaced 16x16).'; end
key{end+1} = 'Dashed: the stop rule (2% in consumption, 0.02 in the share)';
fig = figure('Visible', 'off', 'Position', [30 30 1700 2100], 'Color', 'w');
tl = tiledlayout(fig, size(rows, 1), 2, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('Step %s: the largest gap to the finest grid (owner %s, renter %s) against grid size, and the solve time', ...
    sid, lab(refs.owner), lab(refs.renter)), strjoin(key, ' '), ...
    'Solve times ran beside other solves on this PC: alone they are shorter'}, ...
    'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
L = 'abcdefghijklmnop'; k = 0;
for i = 1:size(rows, 1)
    for j = 1:2
        k = k + 1;
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        ax.FontSize = 10; set(ax, 'XScale', 'log');
        ref = case_load(sid, arms{j}, refs.(arms{j}));
        timing = strcmp(rows{i, 1}, 'time');
        h = gobjects(0); names = {};
        for f = 1:2
            x = []; y = [];
            for c = fams{f}
                r = case_load(sid, arms{j}, c{1});
                if isempty(r) || (~timing && (isempty(ref) || strcmp(c{1}, refs.(arms{j})))), continue; end
                x(end+1) = side(r); %#ok<AGROW>
                y(end+1) = metric(r, ref, rows(i, :)); %#ok<AGROW>
            end
            if isempty(x), continue; end
            [x, o] = sort(x); y = y(o);
            h(end+1) = plot(ax, x, y, '-o', 'Color', cols{f}, 'LineWidth', 1.8, 'MarkerFaceColor', 'w'); %#ok<AGROW>
            names{end+1} = fname{f}; %#ok<AGROW>
        end
        r0 = case_load(sid, arms{j}, 'standard_mop');
        if ~isempty(r0) && ~isempty(ref)
            plot(ax, side(r0), metric(r0, ref, rows(i, :)), 's', 'Color', 'k', 'MarkerFaceColor', 'k', 'MarkerSize', 7);
        end
        if ~timing
            yline(ax, 2 * strcmp(rows{i, 1}, 'C') + 0.02 * strcmp(rows{i, 1}, 'piw'), 'k--');
            ylim(ax, [0, max([ax.YLim(2), 0.05])]);
        end
        xlim(ax, [14 72]); set(ax, 'XTick', [16 24 32 48 64], 'XTickLabel', {'16x16', '24x24', '32x32', '48x48', '64x64'});
        ylabel(ax, rows{i, 5});
        if i == size(rows, 1)
            xl = 'grid size'; if has(LW), xl = [xl ' (log-wealth 64x48 drawn at 55)']; end %#ok<AGROW>
            xlabel(ax, xl);
        end
        title(ax, sprintf('(%s)  %s: %s', L(k), arms{j}, rows{i, 3}), 'FontSize', 11);
        if k == 1 && ~isempty(h), legend(ax, h, names, 'Location', 'northeast', 'FontSize', 9); end
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
function points_page(st, sid, sname, cases, file)
% Owner: the households at each age against the grid points of each rule at
% 16 points per axis; with a live u3 axis a third row for u3.
[~, r] = finest(sid, 'owner', cases);
sim = figures.panel_data(r).sim; ages = sim.ages(:).';
wy  = 1 ./ sim.lambda;
liq = max(1 - (sim.sA + sim.sH) ./ max(1 - sim.lambda, 1e-12), 1e-4);
P = {case_params(sname, 'owner', 'uniform_16x16_mop'), case_params(sname, 'owner', 'pow3_16x16_lim_mop')};
gname = {'evenly spaced 16x16 (the ladder''s grid)', 'bunched 16x16 (power 3)'};
if any(cellfun(@(c) ~isempty(case_load(sid, 'owner', c)), {'logw_16x16_lim_mop', 'logw_32x32_lim_mop', 'logw_64x48_lim_mop'}))
    P{end+1} = case_params(sname, 'owner', 'logw_16x16_lim_mop'); gname{end+1} = 'log-wealth 16x16';
end
dc = P{1}.kappa_base > 0;
live_u3 = P{1}.N_u3 > 2;
ng = numel(P); nr = 2 + live_u3;
if dc
    liq_what = 'liquid / (liquid + house + pension pot) (1 - u2)';
    note = 'liquid savings against liquid savings plus the house and the pension pot';
else
    liq_what = 'liquid / (liquid + house) (1 - u2)';
    note = 'liquid savings against liquid savings plus the house';
end
fig = figure('Visible', 'off', 'Position', [30 30 800 * ng 650 * nr], 'Color', 'w');
tl = tiledlayout(fig, nr, ng, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('Step %s, owner: where households are, against the grid points (16 per axis on every grid)', sid), ...
    'Blue: the households at each age (line: median; dark band: middle half; light band: middle 90%), from the finest grid.', ...
    ['Black lines: grid points. With housing, total resources include the house, and the second axis is ' note]}, ...
    'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
c = st.series(1, :);
for row = 1:nr
    for g = 1:ng
        ax = nexttile(tl);
        if row == 3
            % u3 is placed the same way under every rule: base points, then doubled
            if g > 2, axis(ax, 'off'); continue; end
            p3 = P{2}; if g == 2, p3 = case_params(sname, 'owner', 'pow3_16x16_lim_mop_u3x2'); end
            Y = sim.sA ./ max(sim.sA + sim.sH, 1e-12); pts = p3.u3_grid; yl = [0 1]; yt = 0:0.2:1; logy = false;
            what = 'pension pot / (pot + house) (u3)';
            tag = {'base', 'doubled'};
            gtitle = sprintf('u3 at %d points (%s)', p3.N_u3, tag{g});
        elseif row == 1
            Y = wy; pts = 1 ./ P{g}.u1_grid; yl = [1 6000]; yt = [1 2 5 10 20 50 100 200 500 1000 5000]; logy = true;
            what = 'total resources over income (1/u1)'; gtitle = gname{g};
        else
            Y = liq; pts = 1 - P{g}.u2_grid; pts = pts(pts > 0); yl = [1e-4 1]; yt = [1e-4 1e-3 1e-2 0.1 1]; logy = true;
            what = liq_what; gtitle = gname{g};
        end
        hold(ax, 'on'); box(ax, 'on');
        ax.FontSize = 10; ax.XLim = [25 100];
        if logy, set(ax, 'YScale', 'log'); end
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
            char('a' + ng * (row - 1) + g - 1), gtitle, min(inband(w)), max(inband(w))), 'FontSize', 11, 'Interpreter', 'none');
    end
end
exportgraphics(fig, file, 'Resolution', 110);
close(fig);
end

% ------------------------------------------------------------------------
function pages = check_pages(sid, what, out, pages)
% u3 doubled and no grid search, each against the same grid as solved.
for arm = {'owner', 'renter'}
    a = arm{1};
    for base = {'pow3_16x16_lim_mop', 'pow3_32x32_lim_mop'}
        b = base{1};
        r0 = case_load(sid, a, b);
        if isempty(r0), continue; end
        G = struct('name', {}, 'rs', {}, 'labels', {});
        r = case_load(sid, a, [b '_u3x2']);
        if ~isempty(r)
            G(end+1) = struct('name', 'u3 doubled', 'rs', {{r}}, ...
                'labels', {{sprintf('u3 (pension against house) at %d points', r.p.N_u3)}}); %#ok<AGROW>
        end
        r = case_load(sid, a, [b '_nosweep']);
        if ~isempty(r)
            G(end+1) = struct('name', 'No grid search', 'rs', {{r}}, ...
                'labels', {{'fmincon from the warm start, without the (c, pi) grid search'}}); %#ok<AGROW>
        end
        if isempty(G), continue; end
        pages{end+1} = page(out, pages); %#ok<AGROW>
        figures.robustness(r0, sprintf('%s, limit share, u3 at %d points, with the grid search', lab(b), r0.p.N_u3), G, ...
            sprintf('%s, %s: the checks on %s', what, a, lab(b)), pages{end}, 'the same grid as solved');
    end
end
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
