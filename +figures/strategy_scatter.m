function files = strategy_scatter(folders, opts)
%STRATEGY_SCATTER  Renter against owner gain, every strategy a numbered point, with an appendix.
%
%   figures.strategy_scatter(["knot_night", "spline_night", "night_medium"])
%   figures.strategy_scatter(folders, reference="best", exclude=["free", "no_dc"], window=[-0.8 -0.3])
%
%   Ranks the strategies saved in the folders (model.rank_strategies, with
%   reference and exclude) and numbers them by that ranking: 1 is the best
%   by the max-min rule. Each strategy is one point, renter gain across and
%   owner gain up, with its number beside it; the colour gives the REIT part of the risky share and the
%   marker the risky share in retirement (constant, changing, none, chosen by the household). What every number
%   is goes in the appendix: the name, what the fund holds
%   (figures.describe_strategy) and the two gains.
%
%   Writes, in the first folder (or opts.out), with <tag> = opts.tag or
%   vs_<reference>:
%     scatter_<tag>.png          all strategies, each axis on its own scale
%     scatter_<tag>_zoom.png     only the window [lowest renter gain, lowest
%                                owner gain] (with opts.window); _zoom_equal
%                                the same on equal scales
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
% What each fund does, from its own age path (config.derive): the risky share
% in retirement (constant, changing, none, or chosen by the household) and
% the REIT part of the risky share (one value when it is fixed; the mean
% over the ages with risk otherwise; NaN with free choice).
ret = strings(n, 1); reitf = nan(n, 1); desc = strings(n, 1);
for i = 1:n
    a = find(strcmp({R.arms.name}, T.strategy{i}), 1);
    L = load(R.arms(a).file, 'strategy', 'p');
    desc(i) = figures.describe_strategy(L.strategy);
    p = L.p;
    if isfield(p, 'dc_choice') && p.dc_choice, ret(i) = "chosen"; continue, end
    Sx = config.tau_effective(p); Ex = config.reit_effective(p); risky = Sx(:) + Ex(:);
    ages = p.age0 + (0:numel(risky) - 1).';
    rr = risky(ages >= p.retirement_age);
    if max(rr) < 1e-9, ret(i) = "none";
    elseif max(rr) - min(rr) < 1e-6, ret(i) = "constant";
    else, ret(i) = "changing";
    end
    k = risky > 1e-9;
    if any(k), reitf(i) = round(100 * mean(Ex(k) ./ risky(k))) / 100; end
end

st = figures.style();
files = {draw(T, ret, reitf, R, st, out, tag, false, []), draw(T, ret, reitf, R, st, out, tag, true, [])};
if ~isempty(opts.window)
    files{end+1} = draw(T, ret, reitf, R, st, out, [tag '_zoom'], false, opts.window);
    files{end+1} = draw(T, ret, reitf, R, st, out, [tag '_zoom'], true, opts.window);
end

% The appendix: markdown, then pages of the PDF.
head = sprintf('Strategies numbered by the max-min rule against %s (1 = best); welfare change in %% of certainty-equivalent consumption', ...
    refword(R.reference));
md = {['# ' head], '', '| No. | What the fund holds | Renters (%) | Owners (%) | Lower (%) |', '|---:|---|---:|---:|---:|'};
for i = 1:n
    md{end+1} = sprintf('| %d | %s | %+.2f | %+.2f | %+.2f |', i, desc(i), ...
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
           sprintf('%4s %8s %8s %8s  %s', 'No.', 'Renters', 'Owners', 'Lower', 'What the fund holds')};
    for i = (p - 1) * rows + 1 : min(p * rows, n)
        txt{end+1} = sprintf('%4d %+8.2f %+8.2f %+8.2f  %s', i, T.gain_renter(i), ...
            T.gain_owner(i), T.lowest_gain(i), desc(i)); %#ok<AGROW>
    end
    text(ax, 0, 1, txt, 'FontName', 'Courier New', 'FontSize', 8.5, 'VerticalAlignment', 'top', 'Interpreter', 'none');
    exportgraphics(fig, pdf, 'ContentType', 'vector', 'Append', true);
    close(fig);
end
files{end+1} = pdf;
end

% ------------------------------------------------------------------------
function f = draw(T, ret, reitf, R, st, out, tag, equal, window)
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
% Dashed lines through no. 1, the max-min (optimal) compromise.
plot(ax, [x(1) x(1) xl(2)], [yl(2) y(1) y(1)], '--', 'Color', st.ink2, 'LineWidth', 1.1);   % through the optimal compromise (no. 1)
h = gobjects(0); lab = {};
% Colour: the REIT part of the risky share (light to dark); grey where the
% household chooses. Marker: the risky share in retirement.
hex = @(s) sscanf(s(2:end), '%2x%2x%2x', [1 3]) / 255;
ramp = [hex('#b7d3f6'); hex('#6da7ec'); hex('#2a78d6'); hex('#1c5cab'); hex('#0d366b')];
lev = unique(reitf(~isnan(reitf))).';
if numel(lev) ~= size(ramp, 1), ramp = interp1(linspace(0, 1, 5), ramp, linspace(0, 1, max(numel(lev), 2))); end
mk = struct('constant', 'o', 'changing', 'o', 'none', 's', 'chosen', 'd');
for i = find(show).'
    if isnan(reitf(i)), c = st.muted; else, c = ramp(find(lev == reitf(i), 1), :); end
    face = c; if ret(i) == "changing", face = 'w'; end
    plot(ax, x(i), y(i), mk.(ret(i)), 'MarkerSize', 7, 'LineWidth', 1.3, 'MarkerEdgeColor', c, 'MarkerFaceColor', face);
end
for k = 1:numel(lev)
    h(end+1) = plot(ax, nan, nan, 's', 'MarkerSize', 9, 'MarkerEdgeColor', ramp(k, :), 'MarkerFaceColor', ramp(k, :)); %#ok<AGROW>
    lab{end+1} = sprintf('%.0f%% of the risky share in REIT', 100 * lev(k)); %#ok<AGROW>
end
kinds = ["constant", "changing", "none", "chosen"];
kw = ["filled circle: constant risky share in retirement", "open circle: risky share changes in retirement", ...
      "square: no risky assets in retirement", "grey diamond: the household chooses its own shares"];
for k = 1:4
    if ~any(ret(show) == kinds(k)), continue, end
    face = st.ink2; if kinds(k) == "changing", face = 'w'; end
    cc = st.ink2; if kinds(k) == "chosen", cc = st.muted; face = st.muted; end
    h(end+1) = plot(ax, nan, nan, mk.(kinds(k)), 'MarkerSize', 7, 'LineWidth', 1.3, 'MarkerEdgeColor', cc, 'MarkerFaceColor', face); %#ok<AGROW>
    lab{end+1} = kw(k); %#ok<AGROW>
end
for i = find(show).'
    text(ax, x(i), y(i), sprintf(' %d', i), 'FontSize', 7, 'Color', st.ink, 'VerticalAlignment', 'bottom', ...
        'Clipping', 'on', 'FontWeight', ternary(i <= 5, 'bold', 'normal'));
end
if ~startsWith(R.reference, 'best')
    plot(ax, 0, 0, 'kx', 'MarkerSize', 12, 'LineWidth', 2.2);
    h(end+1) = plot(ax, nan, nan, 'kx', 'MarkerSize', 12, 'LineWidth', 2.2); lab{end+1} = sprintf('%s (reference)', refword(R.reference));
end
xlim(ax, xl); ylim(ax, yl);
if equal, daspect(ax, [1 1 1]); end
xlabel(ax, 'Renter gain (%)', 'Color', st.ink); ylabel(ax, 'Owner gain (%)', 'Color', st.ink);
scale = ''; if equal, scale = ' (equal scales)'; end
title(ax, sprintf('Welfare changes for owners and renters, with respect to %s%s', refword(R.reference), scale), 'Interpreter', 'none', ...
    'FontWeight', 'normal', 'FontSize', st.font + 4, 'Color', st.ink);
sub = 'Numbered by ranking according to max-min (1 being the optimal compromise); dashed lines are at the optimal compromise.';
if n_out > 0, sub = sprintf('%s %d strategies lie below the window.', sub, n_out); end
subtitle(ax, sub, 'Color', st.ink2, 'FontSize', st.font);
legend(ax, h, lab, 'Location', 'eastoutside', 'Box', 'off', 'FontSize', st.font, 'Interpreter', 'none');
f = fullfile(out, ['scatter_' tag ternary(equal, '_equal', '') '.png']);
exportgraphics(fig, f, 'Resolution', 130);
close(fig);
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end

function w = refword(ref)
% The reference in words, without internal names.
w = char(ref);
if startsWith(w, 'best'), w = 'the per-type optimal unconditional strategy';
elseif strcmp(w, 'lifecycle'), w = 'the current default fund';
elseif strcmp(w, 'free'), w = 'free choice';
end
end
