function [files, resolved] = strategy_panel(folders, rows, opts)
%STRATEGY_PANEL  A grid of boxes, one row per strategy and one column per tenure.
%
%   figures.strategy_panel(["knot_night", "spline_night", "night_medium"])
%   figures.strategy_panel(folders, ["best_renter", "reference", "s100_20h_r50"], pension=["share", "total"])
%   [files, resolved] = figures.strategy_panel(folders, rows, draw=false)   % only resolve the roles
%
%   Reads the strategies saved in the folders through model.rank_strategies
%   (same checks; only the saved summaries; nothing is solved). Each box
%   shows how that column's tenure behaves under that row's strategy, in
%   four small panels on one age axis with a line at retirement:
%     1. savings: mean liquid wealth (X.mean) and mean pension pot (A.mean),
%        stacked, thousands of euros; no housing
%     2. the liquid equity share (pi), the mean with the 10th-90th band
%     3. consumption, the median with the 10th-90th band, thousands of euros
%     4. the pension fund by age, one bar an age: stocks (dc_share), REIT
%        (dc_reit) and bonds (the rest); opts.pension:
%          "share"  every bar 1 high
%          "level"  the bar is A.mean (thousands of euros)
%          "total"  the bar is X + A, 1 high, split into liquid stocks,
%                   liquid bonds, pension stocks, pension REIT, pension bonds.
%                   Liquid stocks are the mean equity share times mean
%                   liquid wealth (the summary keeps no household split),
%                   and pension parts the fund's mean shares times A.mean.
%          "pyramid" the same five parts in thousands of euros: the savings
%                   of panel 1 split by asset
%   Means and bands are over the households not bankrupt at that age, as in
%   model.summarize. Each panel type has one y-scale across the grid. In
%   "pyramid" and "total" the liquid parts are greens and sit below a thin
%   black line, the pension parts (blue stocks, orange REIT, grey bonds) above.
%
%   rows: a strategy name or a role for each row, in order. Roles, from the
%   ranking (opts.exclude, by default free choice and no pension account):
%     "best_renter", "best_owner"  the best fund for that tenure
%     "maxmin"     the max-min fund, against each type's best
%                  (opts.maxmin_against "best", the default) or against the
%                  reference ("reference")
%     "reference"  the ranking's reference (production)
%   Any other string is a strategy name. Default ["best_renter",
%   "best_owner", "maxmin"]. Two rows that resolve to the same strategy are
%   both drawn; the later one's title says "same as row k". A strategy
%   without a solve for a column's tenure gets an empty box with a note.
%
%   Box titles: the role (when given as one), the fund in words
%   (figures.describe_strategy) and the welfare gain for that tenure against
%   the reference and against that tenure's best. The figure's title gives
%   the grid and the number of households.
%
%   Writes <file>_<pension>.png for each version of opts.pension and
%   <file>.pdf with all of them, in the first folder (or opts.out); file is
%   "strategy_panel" by default. Returns the file names and resolved, one
%   per row: row, input, role ("" for a name), strategy, same_as (0 or the
%   earlier row).
%
%   Options: tenures (["renter" "owner"], or one), exclude (["free"
%   "no_dc"]), maxmin_against, pension ("share"), reference, ages ([25
%   100]), out, file, draw (true).

arguments
    folders {mustBeText}
    rows (1,:) string = ["best_renter", "best_owner", "maxmin"]
    opts.tenures (1,:) string {mustBeMember(opts.tenures, ["renter", "owner"])} = ["renter", "owner"]
    opts.exclude string = ["free", "no_dc"]
    opts.maxmin_against (1,1) string {mustBeMember(opts.maxmin_against, ["best", "reference"])} = "best"
    opts.pension (1,:) string {mustBeMember(opts.pension, ["share", "level", "total", "pyramid"])} = "share"
    opts.reference (1,:) char = ''
    opts.ages (1,2) double = [25 100]
    opts.out (1,:) char = ''
    opts.file (1,:) char = 'strategy_panel'
    opts.draw (1,1) logical = true
end

R = model.rank_strategies(folders, reference = opts.reference, exclude = opts.exclude, write = false);
T = R.table;
roles = ["best_renter", "best_owner", "maxmin", "reference"];
resolved = struct('row', {}, 'input', {}, 'role', {}, 'strategy', {}, 'same_as', {});
for k = 1:numel(rows)
    in = rows(k); role = ""; name = in;
    switch in
        case "best_renter"
            [~, i] = max(T.gain_renter); name = string(T.strategy{i}); role = in;
        case "best_owner"
            [~, i] = max(T.gain_owner); name = string(T.strategy{i}); role = in;
        case "maxmin"
            if opts.maxmin_against == "best"
                B = model.rank_strategies(folders, reference = 'best', exclude = opts.exclude, write = false);
                name = string(B.table.strategy{1});
            else
                name = string(T.strategy{1});
            end
            role = in;
        case "reference"
            name = string(R.reference); role = in;
    end
    assert(any(strcmp(T.strategy, name)), ...
        'strategy_panel:name', 'No strategy %s in the folders (after exclude).', name);
    same = find(strcmp([resolved.strategy], name), 1); if isempty(same), same = 0; end
    resolved(end+1) = struct('row', k, 'input', in, 'role', role, 'strategy', name, 'same_as', same); %#ok<AGROW>
end
files = {};
if ~opts.draw, return, end

out = opts.out; if isempty(out), out = R.folders{1}; end
st = figures.style();
nr = numel(resolved); nc = numel(opts.tenures);
words = struct('best_renter', 'Best fund for renters', 'best_owner', 'Best fund for owners', ...
    'maxmin', sprintf('Max-min fund (against %s)', char(ternary(opts.maxmin_against == "best", "each type's best", "the reference"))), ...
    'reference', 'Reference (production)');

% Read every box once: the summary, the strategy and the calibration.
box = cell(nr, nc); p0 = []; N = NaN;
for r = 1:nr
    for c = 1:nc
        a = find(strcmp({R.arms.name}, resolved(r).strategy) & strcmp({R.arms.tenure}, opts.tenures(c)), 1);
        if isempty(a), continue, end
        L = load(R.arms(a).file, 'summary', 'strategy', 'p', 'timing');
        box{r, c} = L;
        if isempty(p0), p0 = L.p; N = L.timing.N_sim; end
    end
end
assert(~isempty(p0), 'strategy_panel:empty', 'None of the rows has a solve for the tenures asked.');

% One y-scale per panel type across the grid.
ymax = zeros(1, 4);
for k = 1:numel(box)
    L = box{k}; if isempty(L), continue, end
    s = L.summary;
    ymax(1) = max(ymax(1), max(s.X.mean + s.A.mean, [], 'omitnan') / 1e3);
    ymax(3) = max(ymax(3), max(s.C.p90, [], 'omitnan') / 1e3);
    ymax(4) = max(ymax(4), max(s.A.mean, [], 'omitnan') / 1e3);
end
ymax = ymax * 1.05;

pdf = fullfile(out, [opts.file '.pdf']);
if isfile(pdf), delete(pdf); end
for pv = opts.pension
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [20 20 760 * nc + 80, 820 * nr + 120]);
    tl = tiledlayout(fig, nr, nc, 'TileSpacing', 'loose', 'Padding', 'compact');
    title(tl, {sprintf('DC fund strategies by tenure: savings, liquid equity share, consumption and the pension fund (%s)', pv), ...
        sprintf('Solved on base grid %s (u1, u2, u3, q), %d quadrature nodes a shock; %d simulated households', mat2str(p0.grid_dims), p0.gh_n, N)}, ...
        'FontSize', st.font + 3, 'Color', st.ink, 'Interpreter', 'none');
    first = true;
    for r = 1:nr
        for c = 1:nc
            tb = tiledlayout(tl, 4, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
            tb.Layout.Tile = (r - 1) * nc + c;
            ten = opts.tenures(c);
            head = sprintf('%ss, row %d', capitalize(ten), r);
            if resolved(r).role ~= "", head = sprintf('%s: %s', head, words.(resolved(r).role)); end
            if resolved(r).same_as > 0, head = sprintf('%s (same as row %d)', head, resolved(r).same_as); end
            L = box{r, c};
            if isempty(L)
                ax = nexttile(tb, [4 1]); axis(ax, 'off');
                text(ax, 0.5, 0.5, sprintf('%s has no %s solve in these folders', resolved(r).strategy, ten), ...
                    'HorizontalAlignment', 'center', 'Color', st.ink2, 'Interpreter', 'none');
                title(tb, head, 'FontSize', st.font, 'FontWeight', 'bold', 'Color', st.ink, 'Interpreter', 'none');
                continue
            end
            g = T.("gain_" + ten); gs = g(strcmp(T.strategy, resolved(r).strategy)); gb = max(g);
            [~, ib] = max(g);
            vs_best = 100 * ((1 + gs / 100) / (1 + gb / 100) - 1);
            title(tb, {head, sprintf('%s  [%s]', figures.describe_strategy(L.strategy), resolved(r).strategy), ...
                sprintf('Welfare: %+.2f%% vs %s, %+.2f%% vs best %s fund (%s)', gs, R.reference, vs_best, ten, T.strategy{ib})}, ...
                'FontSize', st.font - 1, 'Color', st.ink, 'Interpreter', 'none');
            draw_box(tb, L.summary, L.p, pv, ymax, opts.ages, st, true, r == nr);   % labels in every box
            first = false;
        end
    end
    f = fullfile(out, sprintf('%s_%s.png', opts.file, pv));
    exportgraphics(fig, f, 'Resolution', 110);
    close(fig);
    files{end+1} = f; %#ok<AGROW>
end
for k = 1:numel(files)                              % the PDF: one page a version
    im = imread(files{k});
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', 'Position', [0 0 21 29.7]);
    ax = axes(fig, 'Units', 'normalized', 'Position', [0.02 0.02 0.96 0.96]);
    image(ax, im); axis(ax, 'image', 'off');
    exportgraphics(fig, pdf, 'ContentType', 'image', 'Resolution', 300, 'Append', k > 1);
    close(fig);
end
files{end+1} = pdf;
end

% ------------------------------------------------------------------------
function draw_box(tb, s, p, pv, ymax, ages, st, legends, bottom)
hex = @(h) sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;
c_liq = hex('#1baf7a'); c_pot = st.series(1, :);
c_stk = st.series(1, :); c_reit = st.series(2, :); c_bond = hex('#dcdad3');
c_lstk = hex('#0f7a52'); c_lbond = hex('#a8e3cc');      % liquid in greens (as liquid wealth in panel 1), pension in blue, orange, grey
a = s.ages(:); ret = p.retirement_age;
ax = gobjects(1, 4);
for k = 1:4
    ax(k) = nexttile(tb); hold(ax(k), 'on'); grid(ax(k), 'on');
    set(ax(k), 'FontSize', st.font - 2, 'GridColor', st.grid, 'XLim', ages, 'XColor', st.ink2, 'YColor', st.ink2, 'Layer', 'top');
    xline(ax(k), ret, ':', 'Color', st.ink2);
    if k < 4 || ~bottom, ax(k).XTickLabel = []; end
end
% 1. Savings.
h1 = area(ax(1), a, [s.X.mean(:), s.A.mean(:)] / 1e3, 'LineStyle', 'none');
h1(1).FaceColor = c_liq; h1(2).FaceColor = c_pot;
ylim(ax(1), [0 ymax(1)]); ylabel(ax(1), 'EUR 1,000');
text(ax(1), ages(1) + 1, 0.92 * ymax(1), 'Savings', 'FontSize', st.font - 2, 'FontWeight', 'bold', 'Color', st.ink);
% 2. Liquid equity share.
band(ax(2), a, s.pi_p10(:), s.pi_p90(:), st.series(3, :));
plot(ax(2), a, s.pi(:), 'Color', st.series(3, :), 'LineWidth', 1.4);
ylim(ax(2), [0 1]); ylabel(ax(2), 'share');
text(ax(2), ages(1) + 1, 0.9, 'Liquid equity share', 'FontSize', st.font - 2, 'FontWeight', 'bold', 'Color', st.ink);
% 3. Consumption.
band(ax(3), a, s.C.p10(:) / 1e3, s.C.p90(:) / 1e3, st.series(7, :));
plot(ax(3), a, s.C.p50(:) / 1e3, 'Color', st.series(7, :), 'LineWidth', 1.4);
ylim(ax(3), [0 ymax(3)]); ylabel(ax(3), 'EUR 1,000');
text(ax(3), ages(1) + 1, 0.9 * ymax(3), 'Consumption', 'FontSize', st.font - 2, 'FontWeight', 'bold', 'Color', st.ink);
% 4. The pension fund (no fund is held after the last age).
j = 1:numel(a) - 1; S = s.dc_share(j).'; E = s.dc_reit(j).'; Bd = max(1 - S - E, 0);
switch pv
    case "share"
        M = [S, E, Bd]; cols = [c_stk; c_reit; c_bond]; lab = {'pension stocks', 'pension REIT', 'pension bonds'};
        yl = [0 1]; yt = 'share'; nm = 'Pension fund';
    case "level"
        A = s.A.mean(j).' / 1e3;
        M = [S, E, Bd] .* A; cols = [c_stk; c_reit; c_bond]; lab = {'pension stocks', 'pension REIT', 'pension bonds'};
        yl = [0 ymax(4)]; yt = 'EUR 1,000'; nm = 'Pension fund';
    case "pyramid"
        X = s.X.mean(j).' / 1e3; A = s.A.mean(j).' / 1e3; pi_ = s.pi(j).'; pi_(isnan(pi_)) = 0;
        M = [pi_ .* X, (1 - pi_) .* X, S .* A, E .* A, Bd .* A];
        cols = [c_lstk; c_lbond; c_stk; c_reit; c_bond];
        lab = {'liquid stocks', 'liquid bonds', 'pension stocks', 'pension REIT', 'pension bonds'};
        yl = [0 ymax(1)]; yt = 'EUR 1,000'; nm = 'Savings by asset';
    case "total"
        X = s.X.mean(j).'; A = s.A.mean(j).'; W = max(X + A, realmin); pi_ = s.pi(j).'; pi_(isnan(pi_)) = 0;
        M = [pi_ .* X, (1 - pi_) .* X, S .* A, E .* A, Bd .* A] ./ W;
        cols = [c_lstk; c_lbond; c_stk; c_reit; c_bond];
        lab = {'liquid stocks', 'liquid bonds', 'pension stocks', 'pension REIT', 'pension bonds'};
        yl = [0 1]; yt = 'share of X + A'; nm = 'Liquid and pension portfolio';
end
hb = bar(ax(4), a(j), M, 1, 'stacked', 'EdgeColor', 'none');
for k = 1:numel(hb), hb(k).FaceColor = cols(k, :); end
if any(pv == ["pyramid", "total"])
    % The boundary between the liquid part (below) and the pension part (above).
    stairs(ax(4), [a(j) - 0.5; a(j(end)) + 0.5], [sum(M(:, 1:2), 2); sum(M(end, 1:2), 2)], 'Color', st.ink, 'LineWidth', 0.8);
end
yl(2) = 1.32 * yl(2);                              % room for the label and the legend, the same in every box
ylim(ax(4), yl); ylabel(ax(4), yt);
text(ax(4), ages(1) + 1, 0.9 * yl(2), nm, 'FontSize', st.font - 2, 'FontWeight', 'bold', 'Color', st.ink);
if bottom, xlabel(ax(4), 'Age', 'Color', st.ink2); end
if legends
    legend(ax(1), h1, {'liquid wealth', 'pension pot'}, 'Location', 'northeast', 'Box', 'off', 'FontSize', st.font - 3);
    legend(ax(4), hb, lab, 'Location', 'northeast', 'Orientation', 'horizontal', 'NumColumns', min(numel(lab), 3), ...
        'Box', 'off', 'FontSize', st.font - 3);
end
linkaxes(ax, 'x');
end

function band(ax, a, lo, hi, col)
ok = ~isnan(lo) & ~isnan(hi);
fill(ax, [a(ok); flipud(a(ok))], [lo(ok); flipud(hi(ok))], col, 'FaceAlpha', 0.18, 'EdgeColor', 'none');
end

function s = capitalize(s)
s = char(s); s(1) = upper(s(1));
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
