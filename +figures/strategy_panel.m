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
%   model.summarize. Each panel type has one y-scale across the grid. The
%   bars of "pyramid" and "total" are grouped by asset class, stocks at the bottom,
%   then REIT, then bonds, thin lines between the classes; within a class the
%   pension part is dark and the liquid part light (no liquid REIT).
%
%   rows: a strategy name or a role for each row, in order. Roles, from the
%   ranking (opts.exclude, by default free choice and no pension account):
%     "best_renter", "best_owner"  the best fund for that tenure
%     "maxmin"     the max-min fund, against each type's best
%                  (opts.maxmin_against "best", the default) or against the
%                  reference ("reference")
%     "reference"  the ranking's reference (production)
%   Any other string is a strategy name. Default ["best_owner",
%   "best_renter", "maxmin"]. Two rows that resolve to the same strategy are
%   both drawn; the later one's heading says "same strategy as row k". A
%   strategy without a solve for a column's tenure gets an empty box.
%
%   Wording (Quinn, 23 November 2026). The figure is titled "Optimal
%   unconditional investment strategies", with the note "Welfare is measured as a
%   certainty equivalent ratio giving the change in lifetime consumption",
%   what the lines and bands are and the
%   number of households. Each row has a heading: "Optimal strategy for
%   owners", "Optimal strategy for renters", "Max-min compromise between
%   owners and renters", "Reference strategy", or the strategy's label
%   for a name. Each box is headed by its tenure, with its welfare compared
%   with the optimal strategy for renters and for owners (for that box's
%   households), or "This is the optimal strategy for ...". No internal
%   names. Panels: "Savings", "Equity share of private savings",
%   "Consumption", and "Pension account investment allocation" (share),
%   "Pension account assets" (level), "Total portfolio assets" (pyramid),
%   "Asset shares of the total portfolio" (total); amounts in thousands of
%   2025 euros, shares as fractions; the allocation panels end at 1 and their
%   legend sits below the box.
%
%   Writes <file>_<pension>.png for each version of opts.pension and
%   <file>.pdf with all of them (vector), in the first folder (or opts.out); file is
%   "strategy_panel" by default. Returns the file names and resolved, one
%   per row: row, input, role ("" for a name), strategy, same_as (0 or the
%   earlier row).
%
%   Options: tenures (["renter" "owner"], or one), exclude (["free"
%   "no_dc"]), maxmin_against, pension ("share"), reference, ages ([25
%   100]), out, file, draw (true).

arguments
    folders {mustBeText}
    rows (1,:) string = ["best_owner", "best_renter", "maxmin"]
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
heads = struct('best_renter', 'Optimal strategy for renters', 'best_owner', 'Optimal strategy for owners', ...
    'maxmin', char(ternary(opts.maxmin_against == "best", "Max-min compromise between owners and renters", ...
                            "Max-min improvement over the reference strategy")), ...
    'reference', 'Reference strategy');
% The optimal strategy of each tenure (after exclude), for the welfare lines.
[~, i] = max(T.gain_renter); opt.renter = T.strategy{i};
[~, i] = max(T.gain_owner);  opt.owner  = T.strategy{i};

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
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [20 20 760 * nc + 80, 880 * nr + 170]);
    tl = tiledlayout(fig, nr, 1, 'TileSpacing', 'loose', 'Padding', 'compact');
    title(tl, 'Optimal unconditional investment strategies', 'FontSize', st.font + 6, 'FontWeight', 'bold', 'Color', st.ink);
    subtitle(tl, {'Welfare is measured as a certainty equivalent ratio giving the change in lifetime consumption.', ...
                  sprintf(['Lines: means (savings, equity share) and medians (consumption); bands: 10th to 90th percentile ' ...
                   'across households; dotted line: retirement at %d. %s simulated households.'], p0.retirement_age, ...
                   thousands(N))}, 'FontSize', st.font + 1, 'Color', st.ink2);
    for r = 1:nr
        tr = tiledlayout(tl, 1, nc, 'TileSpacing', 'loose', 'Padding', 'tight');
        tr.Layout.Tile = r;
        if resolved(r).role ~= "", rh = heads.(resolved(r).role); else, rh = first_label(box(r, :)); end
        if resolved(r).same_as > 0, rh = sprintf('%s (same strategy as row %d)', rh, resolved(r).same_as); end
        title(tr, rh, 'FontSize', st.font + 4, 'FontWeight', 'bold', 'Color', st.ink, 'Interpreter', 'none');
        for c = 1:nc
            tb = tiledlayout(tr, 4, 1, 'TileSpacing', 'compact', 'Padding', 'tight');
            tb.Layout.Tile = c;
            ten = opts.tenures(c);
            L = box{r, c};
            if isempty(L)
                ax = nexttile(tb, [4 1]); axis(ax, 'off');
                text(ax, 0.5, 0.5, sprintf('Not solved for %ss', ten), 'HorizontalAlignment', 'center', 'Color', st.ink2);
                title(tb, sprintf('%ss', capitalize(ten)), 'FontSize', st.font + 2, 'FontWeight', 'bold', 'Color', st.ink);
                continue
            end
            g = T.("gain_" + ten); gs = g(strcmp(T.strategy, resolved(r).strategy));
            wl = {};
            for o = ["renter", "owner"]
                if strcmp(resolved(r).strategy, opt.(o))
                    wl{end+1} = sprintf('This is the optimal strategy for %ss', o); %#ok<AGROW>
                else
                    go = g(strcmp(T.strategy, opt.(o)));
                    wl{end+1} = sprintf('Welfare compared with the optimal strategy for %ss: %+.2f%%', o, ...
                        100 * ((1 + gs / 100) / (1 + go / 100) - 1)); %#ok<AGROW>
                end
            end
            title(tb, sprintf('%ss', capitalize(ten)), 'FontSize', st.font + 2, 'FontWeight', 'bold', 'Color', st.ink);
            subtitle(tb, wl, 'FontSize', st.font, 'Color', st.ink);
            draw_box(tb, L.summary, L.p, pv, ymax, opts.ages, st, r == nr);
        end
    end
    f = fullfile(out, sprintf('%s_%s.png', opts.file, pv));
    exportgraphics(fig, f, 'Resolution', 220);
    exportgraphics(fig, pdf, 'ContentType', 'vector', 'Append', ~isempty(files));   % the PDF: one vector page a version
    close(fig);
    files{end+1} = f; %#ok<AGROW>
end
files{end+1} = pdf;
end

% ------------------------------------------------------------------------
function draw_box(tb, s, p, pv, ymax, ages, st, bottom)
hex = @(h) sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;
c_liq = hex('#1baf7a'); c_pot = st.series(1, :);
c_stk = st.series(1, :); c_reit = st.series(2, :); c_bond = hex('#b9b6ad');
c_lstk = hex('#9ec5f4'); c_lbond = hex('#e4e2da');      % within each asset class: pension dark, liquid light
eur = 'Thousands of 2025 euros';
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
ylim(ax(1), [0 ymax(1)]); ylabel(ax(1), eur);
ptitle(ax(1), 'Savings', st);
legend(ax(1), h1, {'private savings', 'pension account'}, 'Location', 'northeast', 'Box', 'off', 'FontSize', st.font - 3);
% 2. Equity share of private savings.
band(ax(2), a, s.pi_p10(:), s.pi_p90(:), st.series(3, :));
plot(ax(2), a, s.pi(:), 'Color', st.series(3, :), 'LineWidth', 1.4);
ylim(ax(2), [0 1]); ylabel(ax(2), 'fraction');
ptitle(ax(2), 'Equity share of private savings', st);
% 3. Consumption.
band(ax(3), a, s.C.p10(:) / 1e3, s.C.p90(:) / 1e3, st.series(7, :));
plot(ax(3), a, s.C.p50(:) / 1e3, 'Color', st.series(7, :), 'LineWidth', 1.4);
ylim(ax(3), [0 ymax(3)]); ylabel(ax(3), eur);
ptitle(ax(3), 'Consumption', st);
% 4. The pension fund or the whole portfolio (no fund is held after the last age).
j = 1:numel(a) - 1; S = s.dc_share(j).'; E = s.dc_reit(j).'; Bd = max(1 - S - E, 0);
switch pv
    case "share"
        M = [S, E, Bd]; cols = [c_stk; c_reit; c_bond]; lab = {'stocks', 'REIT', 'bonds'};
        yl = [0 1]; yt = 'fraction'; nm = 'Pension account investment allocation';
    case "level"
        A = s.A.mean(j).' / 1e3;
        M = [S, E, Bd] .* A; cols = [c_stk; c_reit; c_bond]; lab = {'stocks', 'REIT', 'bonds'};
        yl = [0 ymax(4)]; yt = eur; nm = 'Pension account assets';
    case "pyramid"
        X = s.X.mean(j).' / 1e3; A = s.A.mean(j).' / 1e3; pi_ = s.pi(j).'; pi_(isnan(pi_)) = 0;
        M = [S .* A, pi_ .* X, E .* A, Bd .* A, (1 - pi_) .* X];        % stocks (pension, liquid), REIT, bonds (pension, liquid)
        cols = [c_stk; c_lstk; c_reit; c_bond; c_lbond];
        lab = {'stocks: pension account', 'stocks: private savings', 'REIT: pension account', 'bonds: pension account', 'bonds: private savings'};
        yl = [0 ymax(1)]; yt = eur; nm = 'Total portfolio assets';
    case "total"
        X = s.X.mean(j).'; A = s.A.mean(j).'; W = max(X + A, realmin); pi_ = s.pi(j).'; pi_(isnan(pi_)) = 0;
        M = [S .* A, pi_ .* X, E .* A, Bd .* A, (1 - pi_) .* X] ./ W;
        cols = [c_stk; c_lstk; c_reit; c_bond; c_lbond];
        lab = {'stocks: pension account', 'stocks: private savings', 'REIT: pension account', 'bonds: pension account', 'bonds: private savings'};
        yl = [0 1]; yt = {'share of pension account', 'and private savings'}; nm = 'Asset shares of the total portfolio';
end
hb = bar(ax(4), a(j), M, 1, 'stacked', 'EdgeColor', 'none');
for k = 1:numel(hb), hb(k).FaceColor = cols(k, :); end
if any(pv == ["pyramid", "total"])
    % Thin lines between the asset classes: above the stocks and above the REIT.
    xs = [a(j) - 0.5; a(j(end)) + 0.5];
    for cb = [2 3], v = sum(M(:, 1:cb), 2); stairs(ax(4), xs, [v; v(end)], 'Color', st.ink, 'LineWidth', 0.7); end
end
ylim(ax(4), yl); ylabel(ax(4), yt);
ptitle(ax(4), nm, st);
if bottom, xlabel(ax(4), 'Age', 'Color', st.ink2); end
lg = legend(ax(4), hb, lab, 'Orientation', 'horizontal', 'NumColumns', min(numel(lab), 3), 'Box', 'off', 'FontSize', st.font - 3);
lg.Layout.Tile = 'south';                           % below the box, so the bars can end at the top
linkaxes(ax, 'x');
end

function ptitle(ax, txt, st)
title(ax, txt, 'FontSize', st.font - 1, 'FontWeight', 'bold', 'Color', st.ink);
end

function band(ax, a, lo, hi, col)
ok = ~isnan(lo) & ~isnan(hi);
fill(ax, [a(ok); flipud(a(ok))], [lo(ok); flipud(hi(ok))], col, 'FaceAlpha', 0.18, 'EdgeColor', 'none');
end

function l = first_label(Ls)
% The label of a row's strategy, from its first saved box.
l = '';
for k = 1:numel(Ls)
    if ~isempty(Ls{k}), l = Ls{k}.strategy.label; return, end
end
end

function t = thousands(n)
t = regexprep(sprintf('%d', round(n)), '(\d)(?=(\d{3})+$)', '$1,');
end

function s = capitalize(s)
s = char(s); s(1) = upper(s(1));
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
