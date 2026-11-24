function files = grid_compare(folders, opts)
%GRID_COMPARE  The same strategies' simulated life cycles on two grids.
%
%   files = figures.grid_compare(["knot_night", "grid_night"])
%   files = figures.grid_compare(folders, labels=["Medium grid", "Production grid"], names=[...])
%
%   folders: two strategy folders (names under <output_dir>/strategies or full
%   paths), the coarser first. Each folder is read with model.rank_strategies,
%   so its gains are against the production fund on its own grid.
%
%   Page 1 shows, for every strategy saved in both folders, the second grid's
%   life cycle minus the first's, by tenure. One page per strategy then
%   draws both grids' life cycles over each other (first grid dashed, second
%   solid): mean private savings, mean pension account, mean equity share of
%   private savings, median consumption (10th to 90th percentile bands) and
%   the mean pension payout. Each box gives the strategy's gain on both grids.
%
%   Options
%     labels  the two grids' names in the legends
%     names   strategies to draw (default: every one in both folders, in the
%             second folder's max-min order)
%     out     folder for the files (default: the second folder)
%     file    file name stem (default 'grid_compare')
%     ages    age range on the x axis
%
%   Writes <file>_<k>.png per page (220 dpi) and <file>.pdf with all pages
%   (vector); returns their paths.

arguments
    folders (1,2) string
    opts.labels (1,2) string = ["Medium grid", "Production grid"]
    opts.names string = strings(1, 0)
    opts.out (1,:) char = ''
    opts.file (1,:) char = 'grid_compare'
    opts.ages (1,2) double = [25 100]
end

R = {model.rank_strategies(folders(1), write = false), model.rank_strategies(folders(2), write = false)};
out = opts.out; if isempty(out), out = R{2}.folders{1}; end
names = opts.names;
if isempty(names)
    names = string(R{2}.table.strategy(ismember(R{2}.table.strategy, R{1}.table.strategy))).';
end
assert(~isempty(names), 'grid_compare:none', 'No strategy is saved in both folders.');
ten = ["renter", "owner"];
st = figures.style();

% Read the summaries: S{g}.(name).(tenure), empty when not solved.
S = cell(1, 2); G = cell(1, 2); lab = struct();
for g = 1:2
    for n = names
        for t = ten
            a = find(strcmp({R{g}.arms.name}, n) & strcmp({R{g}.arms.tenure}, t), 1);
            L = [];
            if ~isempty(a)
                L = load(R{g}.arms(a).file, 'summary', 'strategy', 'p');
                if ~isfield(lab, n), lab.(n) = describe(L.strategy); end
            end
            S{g}.(n).(t) = L;
        end
        row = strcmp(R{g}.table.strategy, n);
        G{g}.(n) = struct('renter', R{g}.table.gain_renter(row), 'owner', R{g}.table.gain_owner(row));
    end
end
p0 = [];
for n = names, for t = ten, if ~isempty(S{2}.(n).(t)), p0 = S{2}.(n).(t).p; break, end, end, if ~isempty(p0), break, end, end

vars = { ...
    'Private savings, mean',               @(s) s.X.mean / 1e3,       'Thousands of 2025 euros'; ...
    'Pension account, mean',               @(s) s.A.mean / 1e3,       'Thousands of 2025 euros'; ...
    'Equity share of private savings, mean', @(s) s.pi,               'fraction'; ...
    'Consumption, median',                 @(s) s.C.p50 / 1e3,        'Thousands of 2025 euros'; ...
    'Pension payout, mean',                @(s) s.ann_pay.mean / 1e3, 'Thousands of 2025 euros'};
nv = size(vars, 1);
pdf = fullfile(out, [opts.file '.pdf']);
if isfile(pdf), delete(pdf); end
files = {};

% Page 1: second grid minus first, every strategy.
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [20 20 1500 300 * nv + 260]);
tl = tiledlayout(fig, nv, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('%s minus %s: simulated life cycles by strategy', opts.labels(2), lower(opts.labels(1))), ...
    'FontSize', st.font + 5, 'FontWeight', 'bold', 'Color', st.ink);
subtitle(tl, sprintf('Each line is one strategy: its life cycle on the %s minus that on the %s. Dotted line: retirement at %d.', ...
    lower(opts.labels(2)), lower(opts.labels(1)), p0.retirement_age), 'FontSize', st.font + 1, 'Color', st.ink2);
hl = gobjects(0); ll = {};
for v = 1:nv
    for c = 1:2
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); prep(ax, st, opts.ages, p0.retirement_age);
        yline(ax, 0, '-', 'Color', st.ink2);
        for k = 1:numel(names)
            A = S{1}.(names(k)).(ten(c)); B = S{2}.(names(k)).(ten(c));
            if isempty(A) || isempty(B), continue, end
            [a, d] = diffline(A.summary, B.summary, vars{v, 2});
            h = plot(ax, a, d, 'Color', st.series(mod(k - 1, 8) + 1, :), 'LineWidth', st.lw);
            if v == 1 && ~any(strcmp(ll, lab.(names(k)))), hl(end+1) = h; ll{end+1} = lab.(names(k)); end %#ok<AGROW>
        end
        if v == 1, title(ax, sprintf('%ss', capitalize(ten(c))), 'FontSize', st.font + 3, 'FontWeight', 'bold', 'Color', st.ink); end
        if c == 1, ylabel(ax, {vars{v, 1}, ['difference, ' vars{v, 3}]}, 'FontSize', st.font - 1); end
        if v == nv, xlabel(ax, 'Age'); end
    end
end
lg = legend(hl, ll, 'NumColumns', 1, 'Box', 'off', 'FontSize', st.font - 1, 'Interpreter', 'none');
lg.Layout.Tile = 'south';
files = save_page(fig, out, opts.file, 1, pdf, files);

% One page per strategy: both grids over each other.
cg = [st.series(2, :); st.series(1, :)]; ls = ["--", "-"];
for k = 1:numel(names)
    n = names(k);
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [20 20 1500 300 * nv + 200]);
    tl = tiledlayout(fig, nv, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, lab.(n), 'FontSize', st.font + 4, 'FontWeight', 'bold', 'Color', st.ink, 'Interpreter', 'none');
    subtitle(tl, sprintf(['%s dashed, %s solid. Means of private savings, pension account, equity share and payout; ' ...
        'median consumption with 10th to 90th percentile bands. Dotted line: retirement at %d.'], ...
        opts.labels(1), lower(opts.labels(2)), p0.retirement_age), 'FontSize', st.font + 1, 'Color', st.ink2);
    hl = gobjects(1, 2);
    for v = 1:nv
        for c = 1:2
            ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); prep(ax, st, opts.ages, p0.retirement_age);
            for g = 1:2
                L = S{g}.(n).(ten(c)); if isempty(L), continue, end
                s = L.summary; a = s.ages(:); y = vars{v, 2}(s); y = y(:);
                if v == 4
                    lo = s.C.p10(:) / 1e3; hi = s.C.p90(:) / 1e3; ok = ~isnan(lo) & ~isnan(hi);
                    fill(ax, [a(ok); flipud(a(ok))], [lo(ok); flipud(hi(ok))], cg(g, :), 'FaceAlpha', 0.12, 'EdgeColor', 'none');
                end
                hl(g) = plot(ax, a, y, ls(g), 'Color', cg(g, :), 'LineWidth', st.lw);
            end
            if v == 1
                title(ax, sprintf('%ss', capitalize(ten(c))), 'FontSize', st.font + 3, 'FontWeight', 'bold', 'Color', st.ink);
                subtitle(ax, gainline(G, n, ten(c), opts.labels), 'FontSize', st.font, 'Color', st.ink);
            end
            if c == 1, ylabel(ax, {vars{v, 1}, vars{v, 3}}, 'FontSize', st.font - 1); end
            if v == 3, ylim(ax, [0 1]); end
            if v == nv, xlabel(ax, 'Age'); end
        end
    end
    ok = isgraphics(hl);
    lg = legend(hl(ok), cellstr(opts.labels(ok)), 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', st.font);
    lg.Layout.Tile = 'south';
    files = save_page(fig, out, opts.file, k + 1, pdf, files);
end
files{end+1} = pdf;
end

% ------------------------------------------------------------------------
function prep(ax, st, ages, ret)
set(ax, 'FontSize', st.font - 1, 'GridColor', st.grid, 'XLim', ages, 'XColor', st.ink2, 'YColor', st.ink2);
xline(ax, ret, ':', 'Color', st.ink2);
end

function [a, d] = diffline(sa, sb, f)
% Second minus first on the ages both have.
[a, ia, ib] = intersect(sa.ages(:), sb.ages(:));
ya = f(sa); yb = f(sb);
d = yb(ib); d = d(:) - reshape(ya(ia), [], 1);
end

function t = gainline(G, n, ten, labels)
g = {G{1}.(n).(ten), G{2}.(n).(ten)}; w = strings(1, 2);
for i = 1:2
    if isempty(g{i}) || isnan(g{i}), w(i) = lower(labels(i)) + " not solved";
    else, w(i) = sprintf('%s %+.3f%%', lower(labels(i)), g{i}); end
end
t = "Welfare gain over the current default fund: " + strjoin(w, ', ');
end

function d = describe(strategy)
if strcmp(strategy.name, 'lifecycle')
    d = 'Current default fund: 80% risky to 39, 0% at 67, half REIT';
else
    d = figures.describe_strategy(strategy);
end
end

function files = save_page(fig, out, stem, k, pdf, files)
f = fullfile(out, sprintf('%s_%d.png', stem, k));
exportgraphics(fig, f, 'Resolution', 220);
exportgraphics(fig, pdf, 'ContentType', 'vector', 'Append', isfile(pdf));
close(fig);
files{end+1} = f;
end

function s = capitalize(s)
s = char(s); s(1) = upper(s(1));
end
