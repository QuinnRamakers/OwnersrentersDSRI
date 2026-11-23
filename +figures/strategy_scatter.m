function files = strategy_scatter(folders, opts)
%STRATEGY_SCATTER  Renter against owner gain, every strategy a numbered point, with an appendix.
%
%   figures.strategy_scatter(["knot_night", "spline_night", "night_medium"])
%   figures.strategy_scatter(folders, reference="best", exclude=["free", "no_dc"], window=[-0.8 -0.3])
%
%   Ranks the strategies saved in the folders (model.rank_strategies, with
%   reference and exclude) and numbers them by that ranking: 1 is the best
%   by the max-min rule. Each strategy is one point, renter gain across and
%   owner gain up, with its number beside it; the colour gives only the
%   family (knot funds, spline funds, other strategies). What every number
%   is goes in the appendix: the name, what the fund holds
%   (figures.describe_strategy) and the two gains.
%
%   Writes, in the first folder (or opts.out), with <tag> = opts.tag or
%   vs_<reference>:
%     scatter_<tag>.png          all strategies, each axis on its own scale
%     scatter_<tag>_zoom.png     only the window [lowest renter gain, lowest
%                                owner gain] (with opts.window)
%     scatter_<tag>_equal.png    all strategies, equal scales
%     scatter_<tag>_appendix.md  the numbered list
%     scatter_<tag>.pdf          the scatters and the list, A4 landscape, to print
%
%   Options: reference, exclude (passed to model.rank_strategies), window,
%   out, tag.

arguments
    folders {mustBeText}
    opts.reference (1,:) char = ''
    opts.exclude string = strings(1, 0)
    opts.window double = []
    opts.out (1,:) char = ''
    opts.tag (1,:) char = ''
end

R = model.rank_strategies(folders, reference = opts.reference, exclude = opts.exclude, write = false);
out = opts.out; if isempty(out), out = R.folders{1}; end
tag = opts.tag;
if isempty(tag)
    tag = ['vs_' regexprep(char(R.reference), '\s.*$', '')];
    if ~isempty(opts.exclude), tag = [tag '_without_' char(strjoin(opts.exclude, '_'))]; end
end
T = R.table; n = height(T);
fam = repmat("other", n, 1);
fam(startsWith(T.strategy, 'k') & ~cellfun(@isempty, regexp(T.strategy, '^k\d+_\d+_\d+[hz]_r\d+$', 'once'))) = "knot";
fam(~cellfun(@isempty, regexp(T.strategy, '^s\d+_\d+[hz]_r\d+$', 'once'))) = "spline";
desc = strings(n, 1);
for i = 1:n
    a = find(strcmp({R.arms.name}, T.strategy{i}), 1);
    L = load(R.arms(a).file, 'strategy');
    desc(i) = figures.describe_strategy(L.strategy);
end

st = figures.style();
files = {draw(T, fam, R, st, out, tag, false, []), draw(T, fam, R, st, out, tag, true, [])};
if ~isempty(opts.window), files{end+1} = draw(T, fam, R, st, out, [tag '_zoom'], false, opts.window); end

% The appendix: markdown, then pages of the PDF.
head = sprintf('Strategies numbered by the max-min rule against %s (1 = best); gains in %% of certainty-equivalent consumption at entry', ...
    R.reference);
md = {['# ' head], '', '| No. | Strategy | What the fund holds | Renters (%) | Owners (%) | Lower (%) |', '|---:|---|---|---:|---:|---:|'};
for i = 1:n
    md{end+1} = sprintf('| %d | `%s` | %s | %+.2f | %+.2f | %+.2f |', i, T.strategy{i}, desc(i), ...
        T.gain_renter(i), T.gain_owner(i), T.lowest_gain(i)); %#ok<AGROW>
end
fmd = fullfile(out, ['scatter_' tag '_appendix.md']);
fid = fopen(fmd, 'w'); fprintf(fid, '%s\n', md{:}); fclose(fid);
files{end+1} = fmd;

pdf = fullfile(out, ['scatter_' tag '.pdf']);
if isfile(pdf), delete(pdf); end
for k = 1:numel(files) - 1                            % the scatter images, one a page
    im = imread(files{k});
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', 'Position', [0 0 29.7 21]);
    ax = axes(fig, 'Units', 'normalized', 'Position', [0.02 0.02 0.96 0.96]);
    image(ax, im); axis(ax, 'image', 'off');
    exportgraphics(fig, pdf, 'ContentType', 'image', 'Resolution', 300, 'Append', k > 1);
    close(fig);
end
rows = 36;
for p = 1:ceil(n / rows)
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', 'Position', [0 0 29.7 21]);
    ax = axes(fig, 'Units', 'normalized', 'Position', [0.03 0.03 0.94 0.94]); axis(ax, 'off');
    ax.XLim = [0 1]; ax.YLim = [0 1];
    txt = {sprintf('Appendix (page %d of %d). %s.', p, ceil(n / rows), head), '', ...
           sprintf('%4s  %-17s %8s %8s %8s  %s', 'No.', 'Strategy', 'Renters', 'Owners', 'Lower', 'What the fund holds')};
    for i = (p - 1) * rows + 1 : min(p * rows, n)
        txt{end+1} = sprintf('%4d  %-17s %+8.2f %+8.2f %+8.2f  %s', i, T.strategy{i}, T.gain_renter(i), ...
            T.gain_owner(i), T.lowest_gain(i), desc(i)); %#ok<AGROW>
    end
    text(ax, 0, 1, txt, 'FontName', 'Courier New', 'FontSize', 8.5, 'VerticalAlignment', 'top', 'Interpreter', 'none');
    exportgraphics(fig, pdf, 'ContentType', 'vector', 'Append', true);
    close(fig);
end
files{end+1} = pdf;
end

% ------------------------------------------------------------------------
function f = draw(T, fam, R, st, out, tag, equal, window)
col = struct('knot', st.series(1, :), 'spline', st.series(2, :), 'other', st.ink);
x = T.gain_renter; y = T.gain_owner; n = numel(x);
show = true(n, 1); n_out = 0;
if ~isempty(window)
    show = x >= window(1) & y >= window(2); n_out = sum(~show);
end
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1500 950]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on');
set(ax, 'FontSize', st.font + 1, 'GridColor', st.grid, 'GridAlpha', 1, 'XColor', st.ink2, 'YColor', st.ink2);
xs = [x(show); 0]; ys = [y(show); 0];
sx = max(max(xs) - min(xs), 1e-6); sy = max(max(ys) - min(ys), 1e-6);
xl = [min(xs) - 0.04 * sx, max(xs) + 0.06 * sx]; yl = [min(ys) - 0.05 * sy, max(ys) + 0.07 * sy];
if ~isempty(window), xl(1) = window(1); yl(1) = window(2); end
xline(ax, 0, 'Color', st.muted); yline(ax, 0, 'Color', st.muted);
m = T.lowest_gain(1);                                % the max-min choice's lowest gain
plot(ax, [m m xl(2)], [yl(2) m m], '--', 'Color', st.ink2, 'LineWidth', 1.1);
h = gobjects(0); lab = {};
names = ["knot", "spline", "other"]; words = ["knot funds (model.knot_menu)", "spline funds (model.spline_menu)", "other strategies"];
mk = struct('knot', 'o', 'spline', 's', 'other', 'd');
for k = 1:3
    j = fam == names(k) & show;
    if ~any(j), continue, end
    c = col.(names(k));
    h(end+1) = plot(ax, x(j), y(j), mk.(names(k)), 'MarkerSize', 6, 'LineWidth', 1.2, 'MarkerEdgeColor', c, ...
        'MarkerFaceColor', 'w'); %#ok<AGROW>
    lab{end+1} = words(k); %#ok<AGROW>
end
for i = find(show).'
    text(ax, x(i), y(i), sprintf(' %d', i), 'FontSize', 7, 'Color', st.ink, 'VerticalAlignment', 'bottom', ...
        'Clipping', 'on', 'FontWeight', ternary(i <= 5, 'bold', 'normal'));
end
if ~startsWith(R.reference, 'best')
    plot(ax, 0, 0, 'kx', 'MarkerSize', 12, 'LineWidth', 2.2);
    h(end+1) = plot(ax, nan, nan, 'kx', 'MarkerSize', 12, 'LineWidth', 2.2); lab{end+1} = sprintf('%s (reference)', R.reference);
end
xlim(ax, xl); ylim(ax, yl);
if equal, daspect(ax, [1 1 1]); end
xlabel(ax, 'Renter gain (%)', 'Color', st.ink); ylabel(ax, 'Owner gain (%)', 'Color', st.ink);
scale = 'each axis on its own scale'; if equal, scale = 'equal scales'; end
title(ax, sprintf('Renter against owner gain, against %s (%s)', R.reference, scale), 'Interpreter', 'none', ...
    'FontWeight', 'normal', 'FontSize', st.font + 4, 'Color', st.ink);
sub = sprintf(['Numbers: rank by the max-min rule (1 = best, bold to 5); the appendix lists every number. ' ...
    'Dashed corner: the lowest gain of no. 1, %+.2f%%.'], m);
if n_out > 0, sub = sprintf('%s %d strategies lie below the window.', sub, n_out); end
subtitle(ax, sub, 'Color', st.ink2, 'FontSize', st.font);
legend(ax, h, lab, 'Location', 'southeast', 'Box', 'off', 'FontSize', st.font, 'Interpreter', 'none');
f = fullfile(out, ['scatter_' tag ternary(equal, '_equal', '') '.png']);
exportgraphics(fig, f, 'Resolution', 130);
close(fig);
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
