function files = spline_menu(folders, opts)
%SPLINE_MENU  The welfare gains of a model.spline_menu run, in two figures.
%
%   figures.spline_menu("spline_night")
%   figures.spline_menu(["spline_night", "night_medium"], reference="free")
%   figures.spline_menu(["spline_night", "night_medium"], reference="best")
%   files = figures.spline_menu("spline_night", out=folder, top=5)
%
%   Reads the ranking (model.rank_strategies) of the folders and draws the
%   strategies named by model.spline_menu (s<young>_<at67><h|z>_r<reit>).
%   Other strategies in the folders (production, free choice, no pension
%   account, ...) can serve as the reference, or "best": each tenure against
%   its own best strategy.
%
%   spline_heatmaps<suffix>.png  the gain against the reference in percent,
%     one row of panels each for renters, owners and the lower of the two
%     (max-min), one column per REIT fraction. In a panel the rows are the
%     risky share to 39, the columns the share at 67 and the tail (h held to
%     100, z to 0 at 100). Blue above the reference, red below, grey at 0, one
%     colour scale per row; every cell is labelled. The best spline by the
%     max-min rule is outlined.
%   spline_scatter<suffix>.png   renter gain against owner gain, one point a
%     spline: colour the REIT fraction (light to dark), marker the share at
%     67, filled when held to 100 and open when it falls to 0. The reference
%     sits at the origin; the strategies named in `others` that are in the
%     folders are black crosses. The dashed corner marks the best spline's
%     lowest gain: a fund up and to the right of it would beat it. The top
%     splines are numbered at their points and named in the legend.
%   The scatter is written twice: as is, each axis scaled to its own range,
%   and with _equal, one point of gain as long on both axes. The suffix is
%   empty for the default reference and _vs_<reference>
%   otherwise.
%
%   Options: out (folder for the files; default the first folder), top
%   (splines named in the scatter, default 5), reference, exclude (names left
%   out of the ranking, passed to model.rank_strategies), others (the other
%   strategies drawn as crosses; default production and free choice, "all"
%   for every one in the folders), window ([lowest renter gain, lowest owner
%   gain]: also writes the scatter zoomed to that window, as _zoom and
%   _zoom_equal; the funds below it are counted, not drawn).

arguments
    folders {mustBeText}
    opts.out (1,:) char = ''
    opts.top (1,1) double = 5
    opts.reference (1,:) char = ''
    opts.others string = ["lifecycle", "free"]
    opts.exclude string = strings(1, 0)
    opts.window double = []
end

R = model.rank_strategies(folders, reference = opts.reference, exclude = opts.exclude, write = false);
out = opts.out; if isempty(out), out = R.folders{1}; end
suffix = ''; if ~isempty(opts.reference), suffix = ['_vs_' opts.reference]; end
if ~isempty(opts.exclude), suffix = [suffix '_without_' char(strjoin(opts.exclude, '_'))]; end
T = R.table;
% Splines (model.spline_menu, s...) and knot funds (model.knot_menu, k...);
% for a knot fund `young` is the share at 25 and `mid` the share at 46.
ts = regexp(T.strategy, '^s(\d+)_(\d+)([hz])_r(\d+)$', 'tokens', 'once');
tk = regexp(T.strategy, '^k(\d+)_(\d+)_(\d+)([hz])_r(\d+)$', 'tokens', 'once');
iss = ~cellfun(@isempty, ts); isk = ~cellfun(@isempty, tk);
is = iss | isk;
assert(any(is), 'figures:spline_menu', 'No strategies of model.spline_menu or model.knot_menu in %s.', strjoin(R.folders, ', '));
rows = find(is); n = numel(rows);
M = table(T.strategy(rows), nan(n, 1), nan(n, 1), nan(n, 1), strings(n, 1), nan(n, 1), strings(n, 1), ...
          T.gain_renter(rows), T.gain_owner(rows), T.lowest_gain(rows), ...
          'VariableNames', {'name', 'young', 'mid', 'at67', 'tail', 'reit', 'fam', 'renter', 'owner', 'lowest'});
for i = 1:n
    r = rows(i);
    if iss(r)
        t = ts{r}; M.young(i) = str2double(t{1}); M.at67(i) = str2double(t{2}); M.tail(i) = t{3}; M.reit(i) = str2double(t{4}); M.fam(i) = "s";
    else
        t = tk{r}; M.young(i) = str2double(t{1}); M.mid(i) = str2double(t{2}); M.at67(i) = str2double(t{3});
        M.tail(i) = t{4}; M.reit(i) = str2double(t{5}); M.fam(i) = "k";
    end
end
show = ismember(T.strategy, cellstr(opts.others)); if isequal(opts.others, "all"), show = true(height(T), 1); end
O = T(show & ~is, {'strategy', 'gain_renter', 'gain_owner'});
best = M.name{find(M.lowest == max(M.lowest), 1)};
st = figures.style();
% The heatmaps lay out the spline menu only; with knot funds in the folders
% the scatter draws the knots in colour and the splines in grey.
files = {};
Ms = M(M.fam == "s", :);
if ~isempty(Ms)
    bs = Ms.name{find(Ms.lowest == max(Ms.lowest), 1)};
    files = {heatmaps(Ms, bs, R.reference, st, out, suffix)};
end
files = [files, {scatter_gains(M, O, best, R.reference, st, out, opts.top, suffix, false, []), ...
         scatter_gains(M, O, best, R.reference, st, out, opts.top, suffix, true, [])}];
if ~isempty(opts.window)
    files = [files, {scatter_gains(M, O, best, R.reference, st, out, opts.top, suffix, false, opts.window), ...
                     scatter_gains(M, O, best, R.reference, st, out, opts.top, suffix, true, opts.window)}];
end
end

% ------------------------------------------------------------------------
function f = heatmaps(M, best, ref, st, out, suffix)
young = sort(unique(M.young), 'descend');
reit  = sort(unique(M.reit)).';
% Columns: at67 ascending, held before falling; at67 = 0 has one column.
cols = unique(M(:, {'at67', 'tail'}), 'rows');
cols = sortrows(cols, {'at67', 'tail'});
clab = arrayfun(@(a, t) col_label(a, t), cols.at67, cols.tail, 'UniformOutput', false);
what = {'renter', 'owner', 'lowest'};
ttl  = {'Renters', 'Owners', 'Lower of the two (max-min)'};
cmap = diverging();

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1900 1080]);
tl = tiledlayout(fig, 3, numel(reit), 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Welfare gain against `%s` (%% of certainty-equivalent consumption at entry), by spline fund', ref), ...
    'FontSize', st.font + 4, 'Interpreter', 'none', 'Color', st.ink);
subtitle(tl, ['Rows of each panel: risky share to 39. Columns: risky share at 67, then h = held to 100, ' ...
    'z = falling to 0 at 100. Box: the max-min choice.'], 'FontSize', st.font + 1, 'Color', st.ink2);
for w = 1:3
    v = M.(what{w});
    lim = max(abs(v));
    for k = 1:numel(reit)
        ax = nexttile(tl);
        G = nan(numel(young), height(cols));
        for i = 1:numel(young)
            for j = 1:height(cols)
                r = M.young == young(i) & M.at67 == cols.at67(j) & M.tail == cols.tail(j) & M.reit == reit(k);
                if any(r), G(i, j) = v(r); end
            end
        end
        imagesc(ax, G, 'AlphaData', ~isnan(G));
        colormap(ax, cmap); clim(ax, [-lim lim]);
        set(ax, 'XTick', 1:height(cols), 'XTickLabel', clab, 'YTick', 1:numel(young), ...
            'YTickLabel', compose('%d%%', young), 'FontSize', st.font, 'TickLength', [0 0], ...
            'XColor', st.ink2, 'YColor', st.ink2, 'Box', 'off');
        hold(ax, 'on');
        for i = 1:numel(young)
            for j = 1:height(cols)
                if isnan(G(i, j)), continue, end
                ink = st.ink; if abs(G(i, j)) > 0.55 * lim, ink = [1 1 1]; end
                text(ax, j, i, sprintf('%+.2f', G(i, j)), 'HorizontalAlignment', 'center', ...
                    'FontSize', st.font - 1, 'Color', ink);
                r = M.young == young(i) & M.at67 == cols.at67(j) & M.tail == cols.tail(j) & M.reit == reit(k);
                if strcmp(M.name{r}, best)
                    rectangle(ax, 'Position', [j - 0.48, i - 0.48, 0.96, 0.96], 'EdgeColor', st.ink, 'LineWidth', 2.2);
                end
            end
        end
        if w == 1, title(ax, sprintf('%d%% of risky in REIT', reit(k)), 'FontWeight', 'normal', 'Color', st.ink); end
        if k == 1, ylabel(ax, {ttl{w}, 'risky to 39'}, 'Color', st.ink); end
        if w == 3, xlabel(ax, 'risky at 67, tail', 'Color', st.ink2); end
        if k == numel(reit)
            cb = colorbar(ax); cb.Label.String = 'gain (%)'; cb.Color = st.ink2;
        end
    end
end
f = fullfile(out, ['spline_heatmaps' suffix '.png']);
exportgraphics(fig, f, 'Resolution', 130);
close(fig);
end

% ------------------------------------------------------------------------
function f = scatter_gains(M, O, best, ref, st, out, top, suffix, equal, window)
hex = @(h) sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;
ramp = [hex('#86b6ef'); hex('#3987e5'); hex('#1c5cab'); hex('#0d366b')];   % ordinal, light to dark
enc = true(height(M), 1); if any(M.fam == "k"), enc = M.fam == "k"; end   % the family drawn in colour
reit = sort(unique(M.reit(enc))).';
if numel(reit) > size(ramp, 1), ramp = interp1(linspace(0, 1, 4), ramp, linspace(0, 1, numel(reit))); end
a67 = sort(unique(M.at67(enc))).';
mk = {'o', 's', '^', 'd', 'v', 'p'};

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1500 950]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on');
set(ax, 'FontSize', st.font + 1, 'GridColor', st.grid, 'GridAlpha', 1, 'XColor', st.ink2, 'YColor', st.ink2);
m = M.lowest(strcmp(M.name, best));
isbest = startsWith(ref, 'best');                  % each tenure against its own best: no fund sits at (0, 0)
xs = [M.renter; O.gain_renter; 0]; ys = [M.owner; O.gain_owner; 0];
if ~isempty(window)
    % Only the window is drawn; the funds below it are counted in the subtitle.
    keep = xs >= window(1) & ys >= window(2);
    n_out = sum(~(M.renter >= window(1) & M.owner >= window(2))) + ...
            sum(~(O.gain_renter >= window(1) & O.gain_owner >= window(2)));
    xs = xs(keep); ys = ys(keep);
end
span = max(xs) - min(xs); yspan = max(ys) - min(ys);
xl = [min(xs) - 0.05 * span, max(xs) + 0.08 * span]; yl = [min(ys) - 0.06 * yspan, max(ys) + 0.08 * yspan];
if ~isempty(window), xl(1) = window(1); yl(1) = window(2); end
set(ax, 'XTick', nice_ticks(xl), 'YTick', nice_ticks(yl));
xline(ax, 0, 'Color', st.muted); yline(ax, 0, 'Color', st.muted);
plot(ax, [m m xl(2)], [yl(2) m m], '--', 'Color', st.ink2, 'LineWidth', 1.2);
grey = [0.80 0.80 0.78];
for i = find(~enc).'                              % the other family, behind, in grey
    plot(ax, M.renter(i), M.owner(i), 'o', 'MarkerSize', 6, 'MarkerEdgeColor', grey, 'MarkerFaceColor', grey);
end
for i = find(enc).'
    c = ramp(reit == M.reit(i), :);
    face = c; if M.tail(i) == "z", face = [1 1 1]; end
    plot(ax, M.renter(i), M.owner(i), mk{a67 == M.at67(i)}, 'MarkerSize', 9, 'LineWidth', 1.6, ...
        'MarkerEdgeColor', c, 'MarkerFaceColor', face);
end
if isbest
    % The best fund of each tenure, where it lies: 0 on its own axis.
    for w = ["renter", "owner"]
        g = [M.(w); O.("gain_" + w)]; nm = [M.name; O.strategy]; gx = [M.renter; O.gain_renter]; gy = [M.owner; O.gain_owner];
        i = find(g == 0, 1);
        plot(ax, gx(i), gy(i), 'o', 'MarkerSize', 20, 'LineWidth', 1.8, 'Color', st.ink);
        va = 'bottom'; if w == "owner", va = 'top'; end
        text(ax, gx(i), gy(i), sprintf('best for %ss: %s   ', w, nm{i}), 'FontSize', st.font, 'Color', st.ink, ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', va, 'Interpreter', 'none', 'FontWeight', 'bold');
    end
else
    plot(ax, 0, 0, 'kx', 'MarkerSize', 13, 'LineWidth', 2.4);
    ha = 'left'; lab0 = sprintf('  %s (reference)', ref);
    if 0 > xl(1) + 0.8 * diff(xl), ha = 'right'; lab0 = sprintf('%s (reference)  ', ref); end   % origin at the right edge
    text(ax, 0, 0, lab0, 'FontSize', st.font, 'Color', st.ink, 'HorizontalAlignment', ha, ...
        'VerticalAlignment', 'bottom', 'Interpreter', 'none');
end
for i = 1:height(O)
    if O.gain_renter(i) == 0 && O.gain_owner(i) == 0, continue, end   % the reference itself
    plot(ax, O.gain_renter(i), O.gain_owner(i), 'kx', 'MarkerSize', 11, 'LineWidth', 2);
    text(ax, O.gain_renter(i), O.gain_owner(i), sprintf('  %s', O.strategy{i}), 'FontSize', st.font, ...
        'Color', st.ink, 'VerticalAlignment', 'top', 'Interpreter', 'none', 'Clipping', 'on');
end
% The top splines get a number at their point; the legend names them.
[~, o] = sort(M.lowest, 'descend');
o = o(1:min(top, height(M)));
for k = 1:numel(o)
    i = o(k);
    text(ax, M.renter(i), M.owner(i), sprintf('%d ', k), 'FontSize', st.font, 'FontWeight', 'bold', ...
        'Color', st.ink, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Clipping', 'on');
end
xlim(ax, xl); ylim(ax, yl);
if equal
    daspect(ax, [1 1 1]);                            % a point of gain is as long on both axes
end
xlabel(ax, 'Renter gain (%)', 'Color', st.ink); ylabel(ax, 'Owner gain (%)', 'Color', st.ink);
scale = 'each axis on its own scale'; if equal, scale = 'equal scales'; end
fam = 'Spline funds'; if any(M.fam == "k"), fam = 'Knot funds (spline funds in grey)'; end
title(ax, sprintf('%s: renter against owner gain, against `%s` (%s)', fam, ref, scale), 'Interpreter', 'none', ...
    'FontWeight', 'normal', 'FontSize', st.font + 4, 'Color', st.ink);
txt = sprintf(['Dashed corner: the best spline''s lowest gain, %+.2f%%; a fund up and to the ' ...
    'right of it would beat it. Numbered: the top %d splines by lowest gain.'], m, numel(o));
if ~isempty(window), txt = sprintf('%s %d funds lie below the window and are not drawn.', txt, n_out); end
subtitle(ax, txt, 'Color', st.ink2, 'FontSize', st.font + 1);
% Legend, outside the box: the top splines, then one entry per REIT fraction
% (colour), share at 67 (marker), tail (fill).
h = gobjects(0); lab = {};
for k = 1:numel(o)
    i = o(k);
    h(end+1) = plot(ax, nan, nan, 'LineStyle', 'none', 'Marker', 'none'); %#ok<AGROW>
    lab{end+1} = sprintf('%d. %s  (%+.2f, %+.2f)', k, M.name{i}, M.renter(i), M.owner(i)); %#ok<AGROW>
end
h(end+1) = plot(ax, nan, nan, 'LineStyle', 'none', 'Marker', 'none'); lab{end+1} = ' ';
for k = 1:numel(reit)
    h(end+1) = plot(ax, nan, nan, 's', 'MarkerSize', 10, 'MarkerEdgeColor', ramp(k, :), 'MarkerFaceColor', ramp(k, :)); %#ok<AGROW>
    lab{end+1} = sprintf('%d%% of risky in REIT', reit(k)); %#ok<AGROW>
end
for k = 1:numel(a67)
    h(end+1) = plot(ax, nan, nan, mk{k}, 'MarkerSize', 9, 'Color', st.ink2, 'MarkerFaceColor', st.ink2); %#ok<AGROW>
    lab{end+1} = sprintf('%d%% risky at 67', a67(k)); %#ok<AGROW>
end
h(end+1) = plot(ax, nan, nan, 'o', 'MarkerSize', 9, 'Color', st.ink2, 'MarkerFaceColor', st.ink2);
lab{end+1} = 'filled: held to 100';
h(end+1) = plot(ax, nan, nan, 'o', 'MarkerSize', 9, 'Color', st.ink2, 'MarkerFaceColor', [1 1 1]);
lab{end+1} = 'open: falling to 0 at 100';
if any(~enc)
    h(end+1) = plot(ax, nan, nan, 'o', 'MarkerSize', 6, 'MarkerEdgeColor', grey, 'MarkerFaceColor', grey);
    lab{end+1} = 'grey: spline funds (flat to 39)';
end
lg = legend(ax, h, lab, 'Location', 'eastoutside', 'Box', 'off', 'FontSize', st.font, 'TextColor', st.ink, ...
    'Interpreter', 'none');
title(lg, 'Top splines (renter, owner gain %)', 'FontWeight', 'normal');
tail = ''; if ~isempty(window), tail = '_zoom'; end
if equal, tail = [tail '_equal']; end
f = fullfile(out, ['spline_scatter' suffix tail '.png']);
exportgraphics(fig, f, 'Resolution', 130);
close(fig);
end

% ------------------------------------------------------------------------
function s = col_label(a, t)
if a == 0, s = '0'; else, s = sprintf('%d %s', a, t); end
end

function c = diverging()
% Red below 0, grey at 0, blue above: equal steps per arm.
hex = @(h) sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;
red = hex('#b42a2a'); mid = hex('#f0efec'); blue = hex('#1c5cab');
n = 128; t = linspace(0, 1, n).';
c = [red + (mid - red) .* t; mid + (blue - mid) .* t(2:end)];
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end

function t = nice_ticks(lim)
% About six to ten ticks on a 1-2-2.5-5 step.
steps = [0.01 0.02 0.025 0.05 0.1 0.2 0.25 0.5 1 2 2.5 5 10];
s = steps(find(diff(lim) ./ steps <= 10, 1));
t = ceil(lim(1) / s) * s : s : lim(2);
t = round(t / s) * s;
end
