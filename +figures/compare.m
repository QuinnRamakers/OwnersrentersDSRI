function fig = compare(rs, labels, ttl, file)
%COMPARE  Overlay the life-cycle profiles of several solved results.
%
%   figures.compare({r1, r2}, {'before', 'after'})
%   figures.compare(rs, labels, title, file)
%
%   Levels are divided by each result's entry income, so calibrations in
%   different income units still line up. With two results the first is drawn
%   in grey and the second in blue; with three, in the fixed series order.

st = figures.style();
n  = numel(rs);
assert(n >= 2 && n <= 3, 'figures:compare', 'compare takes two or three results.');
if n == 2
    cols = [st.previous; st.series(1, :)];
else
    cols = st.series(1:n, :);
end
if nargin < 3 || isempty(ttl), ttl = 'Comparison'; end

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1500 820]);
tl  = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, ttl, 'FontSize', 13, 'Color', st.ink);

panels = {
    'Consumption (median)',             'multiples of entry income', @(s) s.C.p50 / s.Y0
    'Net worth (mean)',                 'multiples of entry income', @(s) s.net_worth.mean / s.Y0
    'DC pot (mean)',                    'multiples of entry income', @(s) s.A.mean / s.Y0
    'Liquid equity share (mean)',       'equity share',              @(s) s.pi
    'Equity share of financial wealth', 'equity share',              @(s) s.equity_share
    'Consumption not freely chosen',    '% of households',           @(s) 100 * (s.floored + s.at_c_bound)
    };
for k = 1:size(panels, 1)
    ax = nexttile(tl);
    hold(ax, 'on'); box(ax, 'off'); grid(ax, 'on');
    ax.GridColor = st.grid; ax.GridAlpha = 1;
    ax.XColor = st.muted; ax.YColor = st.muted; ax.FontSize = st.font;
    ax.XLim = [25 100];
    hs = gobjects(1, n);
    for i = 1:n
        s = rs{i}.summary; a = s.ages; y = panels{k, 3}(s);
        if k == 4 || k == 5, a = a(1:end-1); y = y(1:end-1); end   % nothing is held in the last period
        hs(i) = plot(ax, a, y, 'Color', cols(i, :), 'LineWidth', st.lw);
        xline(ax, rs{i}.p.retirement_age, 'Color', st.grid, 'HandleVisibility', 'off');
    end
    if k == 4 || k == 5, ylim(ax, [0 1]); else, ylim(ax, [0 inf]); end
    title(ax, panels{k, 1}, 'Color', st.ink);
    ylabel(ax, panels{k, 2}); xlabel(ax, 'age');
    if k == 1
        legend(ax, hs, labels, 'Location', 'northwest', 'Box', 'off', ...
            'TextColor', st.ink2, 'Interpreter', 'none');
    end
end

if nargin > 3 && ~isempty(file)
    exportgraphics(fig, file, 'Resolution', 130);
    close(fig);
end
end
