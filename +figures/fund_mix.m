function f = fund_mix(folders, names, tenures, opts)
%FUND_MIX  The DC fund's stock, REIT and bond shares by age, one panel a strategy.
%
%   figures.fund_mix(["spline_night", "night_medium"], ...
%       ["s80_20z_r75", "s80_40z_r50", "lifecycle", "free", "free"], ...
%       ["renter", "owner", "renter", "renter", "owner"])
%
%   Reads the solves that model.strategies saved (through
%   model.rank_strategies, so the same folders and checks) and draws, for
%   each strategy and tenure pair, the fund's shares from 25 to 99 as stacked
%   areas: stocks, REIT and bonds (the rest). With free choice the shares are
%   the means across the households not bankrupt at that age. Each panel's
%   title gives the strategy's label and its welfare change for each tenure
%   (the panel's own first)
%   against each of opts.versus (default free choice and "best": the best
%   strategy of the same tenure, leaving out opts.best_without, by default
%   free choice and no pension account); with versus empty, against the
%   ranking's reference. Writes fund_mix.png (or opts.file) in
%   the first folder (or opts.out).
%
%   Options: reference and exclude (passed to model.rank_strategies), out,
%   file, titles (one per panel, instead of the labels), versus, best_without,
%   columns (panels a row; default up to 3).

arguments
    folders {mustBeText}
    names (1,:) string
    tenures (1,:) string {mustBeMember(tenures, ["renter", "owner"])}
    opts.reference (1,:) char = ''
    opts.exclude string = strings(1, 0)
    opts.out (1,:) char = ''
    opts.file (1,:) char = 'fund_mix.png'
    opts.titles string = strings(1, 0)
    opts.versus string = ["free", "best"]
    opts.best_without string = ["free", "no_dc"]
    opts.columns double = []
end
assert(numel(names) == numel(tenures), 'figures:fund_mix', 'names and tenures must pair up.');

R = model.rank_strategies(folders, reference = opts.reference, exclude = opts.exclude, write = false);
out = opts.out; if isempty(out), out = R.folders{1}; end
st = figures.style();
col = [st.series(1, :); st.series(2, :); 0.86 0.85 0.82];    % stocks, REIT, bonds
n = numel(names);
nc = min(n, 3); if ~isempty(opts.columns), nc = opts.columns; end
nr = ceil(n / nc);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 560 * nc + 60, 430 * nr + 90]);
tl = tiledlayout(fig, nr, nc, 'TileSpacing', 'compact', 'Padding', 'compact');
ttl = sprintf('DC fund mix by age (gains against `%s`)', R.reference);
if ~isempty(opts.versus), ttl = {'DC fund mix by age', 'Welfare change against free choice and against the best fund for the same tenure', sprintf(['(certainty-equivalent consumption at entry; ' ...
    'the best leaves out %s)'], ...
    strjoin(replace(opts.best_without, ["free", "no_dc"], ["free choice", "no pension account"]), ' and '))}; end
title(tl, ttl, 'FontSize', st.font + 4, ...
    'Interpreter', 'none', 'Color', st.ink);
for k = 1:n
    i = find(strcmp({R.arms.name}, names(k)) & strcmp({R.arms.tenure}, tenures(k)), 1);
    assert(~isempty(i), 'figures:fund_mix', 'No %s %s solve in the folders.', names(k), tenures(k));
    L = load(R.arms(i).file, 'summary', 'strategy');
    s = L.summary;
    a = s.ages(1:end-1);                                  % no fund is held after the last age
    S = s.dc_share(1:end-1); E = s.dc_reit(1:end-1);
    ax = nexttile(tl); hold(ax, 'on');
    ar = area(ax, a, [S(:), E(:), 1 - S(:) - E(:)], 'LineStyle', 'none');
    for j = 1:3, ar(j).FaceColor = col(j, :); end
    plot(ax, a, S + E, 'Color', st.ink, 'LineWidth', 1.4);
    xline(ax, 67, ':', 'Color', st.ink2);
    set(ax, 'FontSize', st.font, 'XLim', [a(1) a(end)], 'YLim', [0 1], 'YTick', 0:0.2:1, ...
        'YTickLabel', compose('%d%%', 0:20:100), 'Layer', 'top', 'XColor', st.ink2, 'YColor', st.ink2, 'Box', 'off');
    lab = L.strategy.label; if ~isempty(opts.titles), lab = char(opts.titles(k)); end
    % Welfare for both tenures, the panel's own first: the same fund (for free
    % choice the same rule) held by renters and by owners.
    tens = [tenures(k), setdiff(R.tenures, tenures(k), 'stable')];
    wl = {};
    for tt = tens
        col_g = R.table.("gain_" + tt);
        g = col_g(strcmp(R.table.strategy, names(k)));
        parts = {sprintf('%+.2f%% vs %s', g, R.reference)};
        if ~isempty(opts.versus), parts = {}; end
        for v = opts.versus
            if v == "best"
                % The best of that tenure, leaving out opts.best_without.
                ok = ~ismember(R.table.strategy, cellstr(opts.best_without));
                [gv, ib] = max(col_g(ok)); nm = R.table.strategy(ok); vname = sprintf('best %s fund (%s)', tt, nm{ib});
            else
                gv = col_g(strcmp(R.table.strategy, v)); vname = char(v);
                if v == "free", vname = 'free choice'; end
            end
            parts{end+1} = sprintf('%+.2f%% vs %s', 100 * ((1 + g / 100) / (1 + gv / 100) - 1), vname); %#ok<AGROW>
        end
        wl{end+1} = sprintf('%ss: %s', capitalize(tt), strjoin(parts, ',  ')); %#ok<AGROW>
    end
    % Heading: the tenure and the panel's title; then what the fund holds
    % (the strategy's label and name) and the welfare changes, own tenure first.
    head = sprintf('%ss: %s', capitalize(tenures(k)), lab);
    what = sprintf('%s  [%s]', L.strategy.label, names(k));
    if strcmp(lab, L.strategy.label), head = sprintf('%ss', capitalize(tenures(k))); end
    title(ax, head, 'FontWeight', 'bold', 'FontSize', st.font + 1, 'Interpreter', 'none', 'Color', st.ink);
    subtitle(ax, [{what}, wl], 'FontSize', st.font - 1, 'Interpreter', 'none', 'Color', st.ink2);
    % Shares at 25, 67 and 99, written on the boundary line.
    for t = [25 67 99]
        j = find(a == t, 1); if isempty(j), continue, end
        text(ax, t, min(S(j) + E(j) + 0.04, 0.96), sprintf('%.0f%%', 100 * (S(j) + E(j))), 'FontSize', st.font - 1, ...
            'Color', st.ink, 'HorizontalAlignment', ternary(t == 25, 'left', ternary(t == 99, 'right', 'center')));
    end
    if k > n - nc, xlabel(ax, 'Age', 'Color', st.ink2); end
end
lg = legend(ar, {'Stocks', 'REIT', 'Bonds'}, 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', st.font);
lg.Layout.Tile = 'south';
f = fullfile(out, opts.file);
exportgraphics(fig, f, 'Resolution', 130);
close(fig);
end

function s = capitalize(s)
s = char(s); s(1) = upper(s(1));
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
