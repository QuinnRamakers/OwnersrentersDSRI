function files = spline_menu(folders, opts)
%SPLINE_MENU  The welfare gains of a model.spline_menu run, in two figures.
%
%   figures.spline_menu("spline_night")
%   files = figures.spline_menu("spline_night", out=folder, top=5)
%
%   Reads the ranking (model.rank_strategies) of the folders and draws the
%   strategies named by model.spline_menu (s<young>_<at67><h|z>_r<reit>):
%
%   spline_heatmaps.png  the gain against the reference in percent, one row
%     of panels each for renters, owners and the lower of the two (max-min),
%     one column per REIT fraction. In a panel the rows are the risky share
%     to 39, the columns the share at 67 and the tail (h held to 100, z to 0
%     at 100). Blue above the reference, red below, grey at 0, one colour
%     scale per row; every cell is labelled. The max-min choice is outlined.
%   spline_scatter.png   renter gain against owner gain, one point a
%     strategy: colour the REIT fraction (light to dark), marker the share at
%     67, filled when held to 100 and open when it falls to 0. The reference
%     sits at the origin. The dashed corner marks the max-min choice's lowest
%     gain: strategies up and to the right of it would beat it. The top
%     strategies are named.
%
%   Options: out (folder for the files; default the first folder), top
%   (strategies named in the scatter, default 5), reference.

arguments
    folders {mustBeText}
    opts.out (1,:) char = ''
    opts.top (1,1) double = 5
    opts.reference (1,:) char = ''
end

R = model.rank_strategies(folders, reference = opts.reference, write = false);
out = opts.out; if isempty(out), out = R.folders{1}; end
T = R.table;
tok = regexp(T.strategy, '^s(\d+)_(\d+)([hz])_r(\d+)$', 'tokens', 'once');
is = ~cellfun(@isempty, tok);
assert(any(is), 'figures:spline_menu', 'No strategies of model.spline_menu in %s.', strjoin(R.folders, ', '));
tok = vertcat(tok{is});
M = table(T.strategy(is), str2double(tok(:, 1)), str2double(tok(:, 2)), string(tok(:, 3)), str2double(tok(:, 4)), ...
          T.gain_renter(is), T.gain_owner(is), T.lowest_gain(is), ...
          'VariableNames', {'name', 'young', 'at67', 'tail', 'reit', 'renter', 'owner', 'lowest'});
best = M.name{find(M.lowest == max(M.lowest), 1)};
st = figures.style();
files = {heatmaps(M, best, R.reference, st, out), scatter_gains(M, best, R.reference, st, out, opts.top)};
end

% ------------------------------------------------------------------------
function f = heatmaps(M, best, ref, st, out)
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
f = fullfile(out, 'spline_heatmaps.png');
exportgraphics(fig, f, 'Resolution', 130);
close(fig);
end

% ------------------------------------------------------------------------
function f = scatter_gains(M, best, ref, st, out, top)
hex = @(h) sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;
ramp = [hex('#86b6ef'); hex('#3987e5'); hex('#1c5cab'); hex('#0d366b')];   % ordinal, light to dark
reit = sort(unique(M.reit)).';
if numel(reit) > size(ramp, 1), ramp = interp1(linspace(0, 1, 4), ramp, linspace(0, 1, numel(reit))); end
a67 = sort(unique(M.at67)).';
mk = {'o', 's', '^', 'd', 'v', 'p'};

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1300 950]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on');
set(ax, 'FontSize', st.font + 1, 'GridColor', st.grid, 'GridAlpha', 1, 'XColor', st.ink2, 'YColor', st.ink2);
m = M.lowest(strcmp(M.name, best));
span = max(M.renter) - min(M.renter);
xlab = max(M.renter) + 0.08 * span;                  % the column of names, right of every point
xl = [min(M.renter) - 0.05 * span, xlab + 0.32 * span]; yl = [min(M.owner) - 0.05, max(M.owner) + 0.06];
xline(ax, 0, 'Color', st.muted); yline(ax, 0, 'Color', st.muted);
plot(ax, [m m xlab], [yl(2) m m], '--', 'Color', st.ink2, 'LineWidth', 1.2);
for i = 1:height(M)
    c = ramp(reit == M.reit(i), :);
    face = c; if M.tail(i) == "z", face = [1 1 1]; end
    plot(ax, M.renter(i), M.owner(i), mk{a67 == M.at67(i)}, 'MarkerSize', 9, 'LineWidth', 1.6, ...
        'MarkerEdgeColor', c, 'MarkerFaceColor', face);
end
plot(ax, 0, 0, 'kx', 'MarkerSize', 13, 'LineWidth', 2.4);
text(ax, 0, 0, sprintf('  %s (reference)', ref), 'FontSize', st.font, 'Color', st.ink, ...
    'VerticalAlignment', 'top', 'Interpreter', 'none');
% The top strategies named in a column right of the points, best at the top,
% each joined to its point by a thin leader.
[~, o] = sort(M.lowest, 'descend');
o = o(1:min(top, height(M)));
ylab = yl(2) - 0.03 - (0:numel(o) - 1) * 0.045 * diff(yl) / 0.5;
for k = 1:numel(o)
    i = o(k);
    plot(ax, [M.renter(i), xlab], [M.owner(i), ylab(k)], '-', 'Color', st.muted, 'LineWidth', 0.6);
    text(ax, xlab, ylab(k), sprintf(' %d. %s  (%+.2f, %+.2f)', k, M.name{i}, M.renter(i), M.owner(i)), ...
        'FontSize', st.font, 'Color', st.ink, 'Interpreter', 'none', ...
        'FontWeight', ternary(strcmp(M.name{i}, best), 'bold', 'normal'));
end
xlim(ax, xl); ylim(ax, yl);
xlabel(ax, 'Renter gain (%)', 'Color', st.ink); ylabel(ax, 'Owner gain (%)', 'Color', st.ink);
title(ax, sprintf('Spline funds: renter against owner gain, against `%s`', ref), 'Interpreter', 'none', ...
    'FontWeight', 'normal', 'FontSize', st.font + 4, 'Color', st.ink);
subtitle(ax, sprintf(['Dashed corner: the max-min choice''s lowest gain, %+.2f%%; a fund up and to the ' ...
    'right of it would beat it. Named: the top %d by lowest gain (renter, owner).'], m, numel(o)), ...
    'Color', st.ink2, 'FontSize', st.font + 1);
% Legend: one entry per REIT fraction (colour), share at 67 (marker), tail (fill).
h = gobjects(0); lab = {};
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
legend(ax, h, lab, 'Location', 'southeast', 'Box', 'off', 'FontSize', st.font, 'TextColor', st.ink);
f = fullfile(out, 'spline_scatter.png');
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
