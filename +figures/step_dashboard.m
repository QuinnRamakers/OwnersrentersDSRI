function fig = step_dashboard(rA, rB, labels, ttl, file, opts)
%STEP_DASHBOARD  Two solved results on one twelve-panel page, each with its band.
%
%   figures.step_dashboard(r_prev, r_step, {'step 1', 'step 2'}, title, file)
%   figures.step_dashboard(rA, rB, labels, title, file, colours=[cA; cB], changes={...})
%
%   The page of the earlier renter-vs-owner comparison: lines are means across
%   simulated households and shaded bands their 10th-90th percentiles, for
%   both results. By default A is drawn in black with a grey band (the step
%   before) and B in the colour of its tenure. Panels: gross income,
%   consumption, disposable income, liquid savings, pension account, housing
%   cost, net worth, total wealth with human capital, the liquid equity share,
%   stock exposure relative to total wealth, B's change from A in consumption
%   and liquid savings, the cumulative share bankrupt (figures.bankruptcy;
%   with the yearly top-up, the share ever at the floor), and a box with what
%   changed and the checks of both.
%
%   Levels are in thousands of euros (or CGM units) when both results have the
%   same income units and entry income, and in multiples of each one's entry
%   income otherwise.

arguments
    rA (1,1) struct
    rB (1,1) struct
    labels (1,2) cell
    ttl (1,:) char
    file (1,:) char = ''
    opts.colours double = []
    opts.changes cell = {}
end

D = {figures.panel_data(rA), figures.panel_data(rB)};
R = {rA, rB};
same = strcmp(D{1}.unit, D{2}.unit) && abs(rA.summary.Y0 / rB.summary.Y0 - 1) < 1e-9;
if same
    scl = [D{1}.scale, D{2}.scale]; unit = D{1}.unit;
else
    scl = [1 / rA.summary.Y0, 1 / rB.summary.Y0]; unit = 'multiples of entry income';
end
col = opts.colours;
if isempty(col), col = [0 0 0; arm_colour(rB.tenure)]; end
bandcol = col;
if all(col(1, :) == 0)
    bandcol(1, :) = [0.55 0.55 0.55];
    how = sprintf('%s in black with a grey band, %s in colour with its own band.', labels{1}, labels{2});
else
    how = 'Each with its own band.';
end
sty = {'-', '-'};
FS = 10; FT = 11; LFS = 9; LWD = 1.9;
ret = unique([rA.p.retirement_age, rB.p.retirement_age]);

fig = figure('Visible', 'off', 'Position', [30 30 2750 1300], 'Color', 'w');
tl  = tiledlayout(fig, 3, 5, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {ttl, [how ' Lines are means across simulated households, bands the 10th-90th percentile range: consumption over all households, everything else over those not bankrupt at that age']}, ...
    'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');

panels = {
    '(a)  Gross income',                                 @(d) d.Y,             true
    '(b)  Consumption (all households)',                 @(d) d.C,             true
    '(c)  Disposable income (after tax, contributions and housing)', @(d) d.disp_inc, true
    '(d)  Liquid savings',                               @(d) d.X,             true
    '(e)  Pension account balance',                      @(d) d.A,             true
    '(f)  Housing cost (rent, or maintenance and mortgage)', @(d) d.housing_cost, true
    '(g)  Net worth (liquid + pension + net home equity)', @(d) d.net_worth,   true
    '(h)  Total wealth (net worth + human capital)',     @(d) d.net_worth + d.HC, true
    '(i)  Liquid equity share',                          @(d) d.pi,            false };

for j = 1:size(panels, 1)
    ax = tile(tl, ret, FS);
    title(ax, panels{j, 1}, 'FontSize', FT);
    if j == 5 && ~(D{1}.has_pension || D{2}.has_pension)
        none(ax, 'No DC pension in either step'); continue
    end
    if j == 6 && ~(D{1}.has_housing || D{2}.has_housing)
        none(ax, 'No housing in either step'); continue
    end
    h = gobjects(1, 2);
    for i = 1:2
        a = D{i}.ages; M = panels{j, 2}(D{i});
        if panels{j, 3}
            M = M * scl(i);
        else
            a = a(1:end-1); M = M(:, 1:end-1);           % nothing is held in the last period
        end
        h(i) = band(ax, a, M, col(i, :), bandcol(i, :), sty{i}, LWD);
    end
    if panels{j, 3}, ylabel(ax, unit); else, ylabel(ax, 'Stock share [0-1]'); ylim(ax, [0 1.02]); end
    if j == 2, legend(ax, h, labels, 'Location', 'northwest', 'FontSize', LFS, 'Interpreter', 'none'); end
end

% (j) stock exposure relative to total wealth, with each Merton share
ax = tile(tl, ret, FS);
for i = 1:2
    d = D{i}; Wt = max(d.net_worth + d.HC, 1e-10);
    band(ax, d.ages(1:end-1), (d.eq_liquid(:, 1:end-1) + d.eq_pension(:, 1:end-1)) ./ Wt(:, 1:end-1), ...
        col(i, :), bandcol(i, :), sty{i}, LWD);
    yline(ax, R{i}.checks.merton_liquid, ':', 'Color', col(i, :), 'LineWidth', 1.4, 'HandleVisibility', 'off');
end
ylim(ax, [0 1]); ylabel(ax, 'Share of total wealth [0-1]');
title(ax, '(j)  Stock exposure relative to total wealth (dotted: Merton share)', 'FontSize', FT);

% (k) B's change from A
ax = tile(tl, ret, FS);
yline(ax, 0, 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
a = D{2}.ages; w = 2:numel(a);
cA = mean(D{1}.C, 1) * scl(1); cB = mean(D{2}.C, 1) * scl(2);
xA = mean(D{1}.X, 1, 'omitnan') * scl(1); xB = mean(D{2}.X, 1, 'omitnan') * scl(2);
dx = 100 * (xB ./ xA - 1); dx(xA < 0.01 * max(xA)) = NaN;      % % gaps on near-zero savings say nothing
plot(ax, a, 100 * (cB ./ cA - 1), '-', 'Color', col(2, :), 'LineWidth', LWD, 'DisplayName', 'consumption (mean)');
plot(ax, a(w), dx(w), '-.', 'Color', col(2, :), 'LineWidth', LWD, 'DisplayName', 'liquid savings (mean)');
ylabel(ax, '% change (coloured against black)');
legend(ax, 'Location', 'best', 'FontSize', LFS);
title(ax, sprintf('(k)  Change from %s', labels{1}), 'FontSize', FT, 'Interpreter', 'none');

% (l) bankruptcy by age
ax = tile(tl, ret, FS);
absorbing = false(1, 2);
for i = 1:2
    B = figures.bankruptcy(D{i}, R{i}.p);
    absorbing(i) = strcmp(B.label, 'bankrupt');
    plot(ax, D{i}.ages, B.cum, sty{i}, 'Color', col(i, :), 'LineWidth', LWD, 'DisplayName', labels{i});
end
ylabel(ax, '% of households');
legend(ax, 'Location', 'northwest', 'FontSize', LFS, 'Interpreter', 'none');
if all(absorbing)
    title(ax, '(l)  Cumulative % bankrupt', 'FontSize', FT);
elseif ~any(absorbing)
    title(ax, '(l)  Cumulative % ever at the floor (yearly top-up)', 'FontSize', FT);
else
    title(ax, '(l)  Cumulative % bankrupt (top-up: ever at the floor)', 'FontSize', FT);
end

% (m) what changed, and the checks
ax = nexttile(tl, [1 3]); axis(ax, 'off');
L = {};
if ~isempty(opts.changes)
    L = [{'What changes'}, strcat({'  '}, opts.changes(:).'), {''}];
end
for i = 1:2
    c = R{i}.checks; p = R{i}.p;
    L{end+1} = labels{i}; %#ok<AGROW>
    L{end+1} = sprintf('  %s, %s; grid %dx%dx%d, gh %d, %s, sweep %d, %.0f s', R{i}.tenure, D{i}.unit, ...
        p.N_u1, p.N_u2, p.N_u3, p.gh_n, p.fmincon_algorithm, p.use_refine, R{i}.timing.solve_sec); %#ok<AGROW>
    [~, fl] = model.floor_kind(p);
    L{end+1} = sprintf('  bound 25-39 %.1f%%  %s %.2f%%  off-grid %d  entry value %.3g  Merton %.3f', ...
        100 * c.c_bound_25_39, fl, 100 * c.floored_share, sum(c.offgrid), c.ce_entry, c.merton_liquid); %#ok<AGROW>
    if isfield(c, 'corr_SL_nodes')
        L{end+1} = sprintf('  corr(income, stock) %.2f: nodes %.3f, panel %.3f', p.corr_SL, c.corr_SL_nodes, c.corr_SL_sim); %#ok<AGROW>
    end
    if p.h_mult > 0 && isfield(c, 'corr_HL_nodes')
        [cHL, cSH] = config.h_corr(p);
        L{end+1} = sprintf('  corr(income, H) %.2f: nodes %.3f, panel %.3f', cHL, c.corr_HL_nodes, c.corr_HL_sim); %#ok<AGROW>
        L{end+1} = sprintf('  corr(stock, H) %.2f: nodes %.3f, panel %.3f', cSH, c.corr_SH_nodes, c.corr_SH_sim); %#ok<AGROW>
    end
end
L = cellfun(@(s) wrap(s, 70), L, 'UniformOutput', false);
L = [L{:}];
text(ax, 0, 1, L, 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', FS - 1.5, ...
    'Interpreter', 'none', 'FontName', 'Consolas');
title(ax, '(m)  What changes, and checks', 'FontSize', FT);

if ~isempty(file)
    axs = findall(fig, 'Type', 'axes');
    for i = 1:numel(axs)
        if ~isempty(axs(i).Toolbar), axs(i).Toolbar.Visible = 'off'; end
    end
    exportgraphics(fig, file, 'Resolution', 130);
    close(fig);
end
end

% ------------------------------------------------------------------------
function ax = tile(tl, ret, FS)
ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
ax.FontSize = FS; ax.XLim = [25 100];
for r = ret, xline(ax, r, 'k--', 'HandleVisibility', 'off'); end
xlabel(ax, 'Age');
end

function h = band(ax, x, M, col, bcol, sty, lwd)
lo = quantile(M, 0.10, 1); hi = quantile(M, 0.90, 1);
fill(ax, [x, fliplr(x)], [lo, fliplr(hi)], min(1, bcol * 0.5 + 0.5), 'EdgeColor', 'none', ...
    'FaceAlpha', 0.30, 'HandleVisibility', 'off');
h = plot(ax, x, mean(M, 1, 'omitnan'), sty, 'Color', col, 'LineWidth', lwd);
end

function lines = wrap(s, n)
% Break a line into pieces of at most n characters, continuation indented.
lines = {};
while numel(s) > n
    cut = find(s(1:n) == ' ', 1, 'last');
    if isempty(cut) || cut < 10, cut = n; end
    lines{end+1} = s(1:cut); %#ok<AGROW>
    s = ['      ' strtrim(s(cut+1:end))];
end
lines{end+1} = s;
end

function none(ax, msg)
text(ax, 0.5, 0.5, msg, 'Units', 'normalized', 'HorizontalAlignment', 'center', ...
    'FontSize', 11, 'Color', [0.55 0.55 0.55]);
end

function c = arm_colour(tenure)
if endsWith(tenure, 'owner'),      c = [0.20 0.60 0.30];
elseif endsWith(tenure, 'renter'), c = [0.45 0.20 0.55];
else,                              c = [0.25 0.45 0.75];
end
end
