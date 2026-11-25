function files = strategies(folders, opts)
%STRATEGIES  How the strategies saved in a folder differ, by age, beyond welfare.
%
%   figures.strategies(folder)                         % every strategy in the folder
%   figures.strategies(folder, only=["lifecycle", "no_dc", "age100", "free"])
%   files = figures.strategies(["night_medium", "extra"], out=folder)
%
%   Reads the solves that model.strategies saved (through
%   model.rank_strategies, so the same folders and the same checks) and draws
%   one figure per tenure, twelve panels by age, means or medians across the
%   simulated households:
%     (a) the fund's risky share, stocks plus REIT (the strategy itself; with
%         free choice the households' mean)
%     (b) the fund's stock share (the REIT share is (a) less (b))
%     (c) the mean equity share of the household's own liquid savings
%     (d) composite: the stock share of pension pot plus liquid savings
%     (e) private stocks, thousands of euros
%     (f) composite stocks, pension and private, thousands of euros
%     (g) composite risky share, stocks and REIT, of pot plus liquid savings
%     (h) median consumption, in percent above or below the reference's
%     (i) median liquid wealth, thousands of euros
%     (j) mean pension pot, thousands of euros
%     (k) mean pension payout before tax, thousands of euros a year
%     (l) the share bankrupt, percent
%   The summary keeps no household split of the holdings, so private stocks
%   are the mean equity share times mean liquid wealth and pension stocks the
%   fund's mean stock share times the mean pot (as figures.strategy_panel).
%   The reference (model.rank_strategies) is black and thick. The legend
%   lists the strategies best first: role, what the fund holds (for a knots
%   fund the risky share at each knot and the REIT part), and the welfare gain for both
%   tenures. Writes strategies_<tenure><suffix>.png in the first folder (or opts.out)
%   and returns the file names.
%
%   Options: only (names to draw, the reference always included), roles (one
%   short name per entry of only, shown in the legend), reference,
%   out (folder for the files), ages (default 25-100), suffix (added to the
%   file names), colors ("series", the default, or "rank": the drawn
%   strategies from green, the best by the max-min rule, through yellow to red,
%   numbered in the legend), legend ("full": role, holdings and welfare;
%   "short": one line each; "colorbar": the reference and the five best named,
%   a colour bar for the rank, for long lists with colors="rank").

arguments
    folders {mustBeText}
    opts.only string = strings(1, 0)
    opts.roles string = strings(1, 0)
    opts.reference (1,:) char = ''
    opts.out (1,:) char = ''
    opts.ages (1,2) double = [25 100]
    opts.suffix (1,:) char = ''
    opts.colors (1,1) string {mustBeMember(opts.colors, ["series", "rank"])} = "series"
    opts.legend (1,1) string {mustBeMember(opts.legend, ["full", "short", "colorbar"])} = "full"
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
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 2150 1200]);
    tl = tiledlayout(fig, 3, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('DC fund strategies: %ss, by age (reference `%s` in black)', ten, R.reference), ...
        'FontSize', st.font + 3, 'Interpreter', 'none');
    np = 12;
    ax = gobjects(1, np);
    for k = 1:np
        ax(k) = nexttile(tl, k); hold(ax(k), 'on'); grid(ax(k), 'on');
        set(ax(k), 'FontSize', st.font, 'GridColor', st.grid, 'XLim', opts.ages);
    end
    ttl = {'(a) Fund risky share (stocks + REIT)', '(b) Fund stock share', ...
           '(c) Private: equity share of liquid savings', '(d) Composite: stock share of pot + liquid savings', ...
           '(e) Private stocks, mean (EUR 1,000)', '(f) Composite stocks, pension + private (EUR 1,000)', ...
           '(g) Composite: stocks + REIT share of pot + liquid savings', '(h) Median consumption vs reference (%)', ...
           '(i) Median liquid wealth (EUR 1,000)', '(j) Mean pension pot (EUR 1,000)', ...
           '(k) Mean pension payout, before tax (EUR 1,000 a year)', '(l) Share bankrupt (%)'};
    for k = 1:np, title(ax(k), ttl{k}, 'FontWeight', 'normal'); end
    xlabel(ax(9:12), 'Age');

    ref = load_summary(R, R.reference, ten);
    h = gobjects(0); lab = {}; isr = false(1, 0); rk = zeros(1, 0);
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
            if opts.colors == "rank"                  % green best, through yellow, to red worst
                nn = max(numel(names) - 1, 1); x = (c - 1) / max(nn - 1, 1);
                col = interp1([0 0.5 1], [0.10 0.60 0.25; 0.93 0.72 0.10; 0.80 0.15 0.15], x); ls = '-';
            end
        end
        a = s.ages;
        args = {'Color', col, 'LineStyle', ls, 'LineWidth', lw};
        hh = plot(ax(1), a(1:end-1), s.dc_share(1:end-1) + s.dc_reit(1:end-1), args{:});   % none is held after the last age
        plot(ax(2), a(1:end-1), s.dc_share(1:end-1), args{:});
        plot(ax(3), a, s.pi, args{:});
        X = s.X.mean(:).'; A = s.A.mean(:).'; W = max(X + A, realmin);
        pis = s.pi(:).'; pis(isnan(pis)) = 0;
        Sp = pis .* X; Sf = s.dc_share(:).' .* A; Rf = s.dc_reit(:).' .* A;   % private stocks, pension stocks, pension REIT
        Sf(end) = NaN; Rf(end) = NaN;                    % the fund holds nothing after the last age
        plot(ax(4), a, (Sp + Sf) ./ W, args{:});
        plot(ax(5), a, Sp / 1e3, args{:});
        plot(ax(6), a, (Sp + Sf) / 1e3, args{:});
        plot(ax(7), a, (Sp + Sf + Rf) ./ W, args{:});
        plot(ax(8), a, 100 * (s.C.p50 ./ ref.C.p50 - 1), args{:});
        plot(ax(9), a, s.X.p50 / 1e3, args{:});
        plot(ax(10), a, s.A.mean / 1e3, args{:});
        plot(ax(11), a, s.ann_pay.mean / 1e3, args{:});
        plot(ax(12), a, 100 * s.floored, args{:});
        h(end+1) = hh; %#ok<AGROW>
        gg = arrayfun(@(t) R.table.("gain_" + t)(strcmp(R.table.strategy, n{1})), R.tenures);
        role = n{1}; j = find(opts.only == n{1}, 1);
        if ~isempty(opts.roles) && ~isempty(j), role = sprintf('%s  [%s]', opts.roles(j), n{1}); end
        if opts.colors == "rank" && ~isref, role = sprintf('%d. %s', c, role); end
        if isref, role = sprintf('Reference strategy  [%s]', n{1}); end
        if opts.legend == "full"
            lab{end+1} = sprintf('%s\n   %s\n   welfare vs %s: %s', role, describe(R, n{1}), R.reference, ...
                strjoin(compose('%ss %+.2f%%', R.tenures(:), gg(:)), ', ')); %#ok<AGROW>
        else
            short = n{1}; if opts.colors == "rank" && ~isref, short = sprintf('%d. %s', c, n{1}); end
            if isref, short = sprintf('%s (reference strategy)', n{1}); end
            lab{end+1} = sprintf('%s  (%s)', short, strjoin(compose('%s %+.2f%%', extractBefore(R.tenures(:), 2), gg(:)), ', ')); %#ok<AGROW>
        end
        isr(end+1) = isref; rk(end+1) = c; %#ok<AGROW>
    end
    if opts.colors == "rank"
        for k = 1:np, ax(k).Children = flipud(ax(k).Children); end   % the best drawn on top
    end
    yline(ax(8), 0, 'Color', st.muted);
    for k = [1:4, 7], ylim(ax(k), [0 1]); end
    keep = true(size(h));
    if opts.legend == "colorbar"
        % Only the reference and the five best are named; the colour bar gives the rank.
        keep = isr | (rk >= 1 & rk <= 5);
        colormap(ax(1), interp1([0 0.5 1], [0.10 0.60 0.25; 0.93 0.72 0.10; 0.80 0.15 0.15], linspace(0, 1, 256)));
        cb = colorbar(ax(1)); cb.Layout.Tile = 'south'; cb.Orientation = 'horizontal';
        clim(ax(1), [1 max(c, 2)]); cb.Label.String = sprintf('Rank by max-min against %s (1 = best, %d drawn)', R.reference, c);
        cb.Label.Interpreter = 'none';
    end
    lg = legend(ax(1), h(keep), lab(keep), 'Interpreter', 'none', 'FontSize', st.font - 1, 'Box', 'off');
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

function d = describe(R, name)
% What a strategy's fund holds, in words: for a knots fund the risky share at
% each knot and the REIT part of it; otherwise its label.
i = find(strcmp({R.arms.name}, name), 1);
L = load(R.arms(i).file, 'strategy');
s = L.strategy.set;
d = label_of(R, name);
if isempty(s) || ~isfield(s, 'glide_knots') || isempty(s.glide_knots), return, end
K = s.glide_knots; risky = K(:, 2) + K(:, 3);
pts = strjoin(compose('%.0f%% at %d', 100 * risky, K(:, 1)), ' -> ');
f = K(:, 3) ./ max(risky, eps); f = f(risky > 0);
mix = 'no risky part';
if ~isempty(f)
    if max(f) - min(f) < 1e-9
        mix = sprintf('risky part %.0f%% REIT, %.0f%% stocks', 100 * f(1), 100 * (1 - f(1)));
    else
        mix = 'REIT part of risky varies by age';
    end
end
d = sprintf('risky share %s; %s', pts, mix);
end
