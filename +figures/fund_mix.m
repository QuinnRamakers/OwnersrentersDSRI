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
%   title gives the strategy's label and its welfare gain for that tenure
%   against the ranking's reference. Writes fund_mix.png (or opts.file) in
%   the first folder (or opts.out).
%
%   Options: reference and exclude (passed to model.rank_strategies), out,
%   file, titles (one per panel, instead of the labels).

arguments
    folders {mustBeText}
    names (1,:) string
    tenures (1,:) string {mustBeMember(tenures, ["renter", "owner"])}
    opts.reference (1,:) char = ''
    opts.exclude string = strings(1, 0)
    opts.out (1,:) char = ''
    opts.file (1,:) char = 'fund_mix.png'
    opts.titles string = strings(1, 0)
end
assert(numel(names) == numel(tenures), 'figures:fund_mix', 'names and tenures must pair up.');

R = model.rank_strategies(folders, reference = opts.reference, exclude = opts.exclude, write = false);
out = opts.out; if isempty(out), out = R.folders{1}; end
st = figures.style();
col = [st.series(1, :); st.series(2, :); 0.86 0.85 0.82];    % stocks, REIT, bonds
n = numel(names);
nc = min(n, 3); nr = ceil(n / nc);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 560 * nc + 60, 430 * nr + 90]);
tl = tiledlayout(fig, nr, nc, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('DC fund mix by age (gains against `%s`)', R.reference), 'FontSize', st.font + 4, ...
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
    g = R.table.("gain_" + tenures(k))(strcmp(R.table.strategy, names(k)));
    lab = L.strategy.label; if ~isempty(opts.titles), lab = char(opts.titles(k)); end
    title(ax, {sprintf('%s: %s', capitalize(tenures(k)), names(k)), sprintf('%s (gain %+.2f%%)', lab, g)}, ...
        'FontWeight', 'normal', 'FontSize', st.font, 'Interpreter', 'none', 'Color', st.ink);
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
