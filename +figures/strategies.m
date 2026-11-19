function files = strategies(folders, opts)
%STRATEGIES  How the strategies saved in a folder differ, by age, beyond welfare.
%
%   figures.strategies(folder)                         % every strategy in the folder
%   figures.strategies(folder, only=["lifecycle", "no_dc", "age100", "free"])
%   files = figures.strategies(["night_medium", "extra"], out=folder)
%
%   Reads the solves that model.strategies saved (through
%   model.rank_strategies, so the same folders and the same checks) and draws
%   one figure per tenure, six panels by age, means or medians across the
%   simulated households:
%     (a) the fund's risky share, stocks plus REIT (the strategy itself; with
%         free choice the households' mean)
%     (b) median consumption, in percent above or below the reference's
%     (c) median liquid wealth, thousands of euros
%     (d) mean pension pot, thousands of euros
%     (e) mean pension payout before tax, thousands of euros a year
%     (f) the share bankrupt, percent
%   The reference (model.rank_strategies) is black and thick. The legend
%   lists the strategies best first, with each one's welfare gain for both
%   tenures. Writes strategies_<tenure><suffix>.png in the first folder (or opts.out)
%   and returns the file names.
%
%   Options: only (names to draw, the reference always included), reference,
%   out (folder for the files), ages (default 25-100), suffix (added to the
%   file names).

arguments
    folders {mustBeText}
    opts.only string = strings(1, 0)
    opts.reference (1,:) char = ''
    opts.out (1,:) char = ''
    opts.ages (1,2) double = [25 100]
    opts.suffix (1,:) char = ''
end

R = model.rank_strategies(folders, reference = opts.reference, write = false);
out = opts.out;
if isempty(out), out = R.folders{1}; end
names = R.table.strategy.';                              % best first
if ~isempty(opts.only)
    names = names(ismember(names, cellstr([opts.only, string(R.reference)])));
end
st = figures.style();
cols = [st.series; st.series(1:4, :) * 0.6];             % twelve before the colours repeat
dash = {'-', '--', ':', '-.'};
files = {};

for ten = R.tenures
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1750 820]);
    tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('DC fund strategies: %ss, by age (reference `%s` in black)', ten, R.reference), ...
        'FontSize', st.font + 3, 'Interpreter', 'none');
    ax = gobjects(1, 6);
    tiles = 1:6;
    for k = 1:6
        ax(k) = nexttile(tl, tiles(k)); hold(ax(k), 'on'); grid(ax(k), 'on');
        set(ax(k), 'FontSize', st.font, 'GridColor', st.grid, 'XLim', opts.ages);
    end
    ttl = {'(a) Fund risky share (stocks + REIT)', '(b) Median consumption vs reference (%)', ...
           '(c) Median liquid wealth (EUR 1,000)', '(d) Mean pension pot (EUR 1,000)', ...
           '(e) Mean pension payout, before tax (EUR 1,000 a year)', '(f) Share bankrupt (%)'};
    for k = 1:6, title(ax(k), ttl{k}, 'FontWeight', 'normal'); end
    xlabel(ax(4:6), 'Age');

    ref = load_summary(R, R.reference, ten);
    h = gobjects(0); lab = {};
    c = 0;
    for n = names
        s = load_summary(R, n{1}, ten);
        if isempty(s), continue, end
        isref = strcmp(n{1}, R.reference);
        if isref
            col = [0 0 0]; ls = '-'; lw = 2.6;
        else
            c = c + 1;
            col = cols(mod(c - 1, size(cols, 1)) + 1, :); ls = dash{mod(floor((c - 1) / 4), 4) + 1}; lw = st.lw;
            if c > size(cols, 1), ls = ':'; end
        end
        a = s.ages;
        args = {'Color', col, 'LineStyle', ls, 'LineWidth', lw};
        hh = plot(ax(1), a(1:end-1), s.dc_share(1:end-1) + s.dc_reit(1:end-1), args{:});   % none is held after the last age
        plot(ax(2), a, 100 * (s.C.p50 ./ ref.C.p50 - 1), args{:});
        plot(ax(3), a, s.X.p50 / 1e3, args{:});
        plot(ax(4), a, s.A.mean / 1e3, args{:});
        plot(ax(5), a, s.ann_pay.mean / 1e3, args{:});
        plot(ax(6), a, 100 * s.floored, args{:});
        h(end+1) = hh; %#ok<AGROW>
        gg = arrayfun(@(t) R.table.("gain_" + t)(strcmp(R.table.strategy, n{1})), R.tenures);
        lab{end+1} = sprintf('%s  (%s)', label_of(R, n{1}), strjoin(compose('%ss %+.2f%%', R.tenures(:), gg(:)), ', ')); %#ok<AGROW>
    end
    yline(ax(2), 0, 'Color', st.muted);
    ylim(ax(1), [0 1]);
    lg = legend(ax(1), h, lab, 'Interpreter', 'none', 'FontSize', st.font - 1, 'Box', 'off');
    lg.Layout.Tile = 'east';
    title(lg, sprintf('Best first (max-min); welfare gain against %s, both tenures', R.reference), ...
        'FontWeight', 'normal', 'Interpreter', 'none');
    f = fullfile(out, sprintf('strategies_%s%s.png', ten, opts.suffix));
    exportgraphics(fig, f, 'Resolution', 120);
    close(fig);
    files{end+1} = f; %#ok<AGROW>
end
end

function s = load_summary(R, name, ten)
i = find(strcmp({R.arms.name}, name) & strcmp({R.arms.tenure}, ten), 1);
s = [];
if isempty(i), return, end
L = load(R.arms(i).file, 'summary');
s = L.summary;
end

function l = label_of(R, name)
l = R.table.label{strcmp(R.table.strategy, name)};
end
