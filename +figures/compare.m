function fig = compare(rs, labels, ttl, file, opts)
%COMPARE  Overlay several solved results on the same panels.
%
%   figures.compare({r_ref, r1, r2}, {'reference', 'one', 'two'})
%   figures.compare(rs, labels, title, file)
%   figures.compare(rs, labels, title, file, view='pension')
%
%   The first result is the reference: drawn in black with its 10th-90th
%   percentile band, and the one the third row measures differences from.
%   The others are drawn in colour, up to five. Lines are means across
%   simulated households.
%     Row 1, where income comes from and what housing takes, for every
%     result: income received after tax and contributions (wages, then the
%     state pension), the private pension payment after tax, maintenance
%     (owners) or rent (renters), the mortgage payment, and net disposable
%     income.
%     Row 2: consumption (with the reference's gross income and income after
%     tax, contributions and housing), liquid savings, net worth, the liquid
%     equity share, and the cumulative share bankrupt (figures.bankruptcy;
%     with the yearly top-up, the share ever at the floor).
%     Row 3: the first four of row 2 as differences from the reference, and
%     housing costs over income after tax and contributions for every result.
%     Row 4: the equity share policy at ages 30, 55 and 75 as the solver
%     returned it, against resources over income, each at its own households'
%     median pension and housing shares, with markers on each result's own
%     grid nodes, and a box with each result's settings and checks.
%
%   view='pension' shows the DC pension account in place of net worth, and in
%   place of the policy at 30 the stock share of financial wealth (stock in
%   the liquid account and the DC fund over liquid saving plus the fund).
%
%   Levels are in thousands of euros (or CGM units) when every result has the
%   same income units and entry income, and in multiples of entry income
%   otherwise, so steps with different income units still line up.

arguments
    rs cell
    labels cell
    ttl = ''
    file = ''
    opts.view (1,:) char {mustBeMember(opts.view, {'default', 'pension'})} = 'default'
end

n = numel(rs);
assert(n >= 2 && n <= 6, 'figures:compare', 'compare takes two to six results.');
if isempty(ttl), ttl = 'Comparison'; end
D = cellfun(@figures.panel_data, rs, 'UniformOutput', false);
pension_view = strcmp(opts.view, 'pension');

same_units = all(cellfun(@(d) strcmp(d.unit, D{1}.unit), D)) && ...
             all(cellfun(@(r) abs(r.summary.Y0 / rs{1}.summary.Y0 - 1) < 1e-9, rs));
if same_units
    scl = cellfun(@(d) d.scale, D); unit = D{1}.unit;
else
    scl = cellfun(@(r) 1 / r.summary.Y0, rs); unit = 'multiples of entry income';
end

st = figures.style();
cols = [0 0 0; st.series(1:5, :)];
styles = {'-', '-', '--', '-.', ':', '-'};
lw = [2.4, 1.7 * ones(1, 5)];
FS = 10; FT = 11; LFS = 9;
ret = rs{1}.p.retirement_age;
k = 0;                                           % panel letter counter

fig = figure('Visible', 'off', 'Position', [30 30 2750 1720], 'Color', 'w');
tl  = tiledlayout(fig, 4, 5, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {ttl, ['Black = ' labels{1} ' (the reference, with its 10th-90th percentile band); ' ...
    'lines are means across simulated households: consumption over all of them, everything else over those not bankrupt at that age']}, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');

% Row 1: where income comes from and what housing takes, every result
owner = cellfun(@(r, d) d.has_housing && r.p.is_owner, rs, D);
renter = cellfun(@(r, d) d.has_housing && ~r.p.is_owner, rs, D);
if all(owner(owner | renter)) && any(owner)
    hname = 'Home maintenance';
elseif ~any(owner) && any(renter)
    hname = 'Rent';
else
    hname = 'Home maintenance (owners) or rent (renters)';
end
parts = {
    'Income received after tax and contributions (wages, then state pension)', @(d) d.takehome, true
    'Private pension payment after tax', @(d) d.annuity, any(cellfun(@(d) d.has_pension, D))
    hname, @(d) d.maintenance + d.rent, any(owner | renter)
    'Mortgage payment', @(d) d.mortgage, any(owner)
    'Net disposable income (after tax, contributions and housing)', @(d) d.disp_inc, true };
for j = 1:size(parts, 1)
    ax = tile(tl, ret, FS); k = k + 1;
    title(ax, sprintf('(%s)  %s', letter(k), parts{j, 1}), 'FontSize', FT);
    if ~parts{j, 3}
        none(ax, sprintf('No %s in these results', lower(parts{j, 1}))); continue
    end
    h = runs_panel(ax, D, parts{j, 2}, scl, cols, styles, lw);
    ylabel(ax, unit);
    if j == 1
        legend(ax, h, labels, 'Location', 'northwest', 'FontSize', LFS, 'Interpreter', 'none');
    end
end

% Row 2: the outcomes, then bankruptcy
series = {
    'Consumption',          @(d) d.C,         unit,                false, 'Consumption'
    'Liquid savings',       @(d) d.X,         unit,                false, 'Liquid savings'
    'Net worth (liquid + pension + net home equity)', @(d) d.net_worth, unit, false, 'Net worth'
    'Liquid equity share',  @(d) d.pi,        'Stock share [0-1]', true,  'Liquid equity share' };
if pension_view
    series(3, :) = {'Pension account (DC)', @(d) d.A, unit, false, 'Pension account'};
end
for j = 1:4
    ax = tile(tl, ret, FS); k = k + 1;
    if series{j, 4}
        h = runs_panel(ax, D, series{j, 2}, ones(1, n), cols, styles, lw, true);
        ylim(ax, [0 1]);
    else
        h = runs_panel(ax, D, series{j, 2}, scl, cols, styles, lw);
    end
    ylabel(ax, series{j, 3});
    title(ax, sprintf('(%s)  %s', letter(k), series{j, 1}), 'FontSize', FT);
    if j == 1
        hy = income_lines(ax, D{1}, scl(1));
        title(ax, sprintf('(%s)  Consumption (all households) and income (black''s households)', letter(k)), 'FontSize', FT);
        legend(ax, [h(1), hy], [labels(1), {'gross income', 'income after tax, contributions and housing'}], ...
            'Location', 'northwest', 'FontSize', LFS, 'Interpreter', 'none');
    end
end
ax = tile(tl, ret, FS); k = k + 1;
absorbing = false(1, n);
for i = n:-1:1
    B = figures.bankruptcy(D{i}, rs{i}.p);
    absorbing(i) = strcmp(B.label, 'bankrupt');
    plot(ax, D{i}.ages, B.cum, styles{i}, 'Color', cols(i, :), 'LineWidth', lw(i));
end
ylabel(ax, '% of households');
if all(absorbing)
    what = 'Cumulative % bankrupt';
elseif ~any(absorbing)
    what = 'Cumulative % ever at the floor (yearly top-up)';
else
    what = 'Cumulative % bankrupt (top-up runs: ever at the floor)';
end
title(ax, sprintf('(%s)  %s', letter(k), what), 'FontSize', FT);

% Row 3: differences from the reference, then housing costs over income
for j = 1:4
    ax = tile(tl, ret, FS); k = k + 1;
    yline(ax, 0, 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
    a = D{1}.ages; ref = mean(series{j, 2}(D{1}), 1, 'omitnan');
    if series{j, 4}, a = a(1:end-1); ref = ref(1:end-1); end
    absolute = pension_view && j == 3;      % the reference may have no pension account
    for i = 2:n
        v = mean(series{j, 2}(D{i}), 1, 'omitnan');
        if series{j, 4}
            v = v(1:end-1);
            dv = v - ref;
        elseif absolute
            dv = v * scl(i) - ref * scl(1);
        else
            dv = 100 * (v * scl(i) ./ (ref * scl(1)) - 1);
            dv(abs(ref) < 0.01 * max(abs(ref))) = NaN;    % % gaps on near-zero levels say nothing
        end
        plot(ax, a, dv, styles{i}, 'Color', cols(i, :), 'LineWidth', lw(i));
    end
    if series{j, 4}
        ylabel(ax, 'difference in share');
    elseif absolute
        ylabel(ax, ['difference, ' unit]);
    else
        ylabel(ax, '% difference from reference');
    end
    title(ax, sprintf('(%s)  %s: difference from black', letter(k), series{j, 5}), 'FontSize', FT);
end
ax = tile(tl, ret, FS); k = k + 1;
if any(owner | renter)
    burden = @(d) 100 * d.housing_cost ./ max(d.takehome + d.annuity, 1e-12);
    runs_panel(ax, D, burden, ones(1, n), cols, styles, lw);
    yline(ax, 100, 'k:', 'all income', 'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
    ylabel(ax, '% of income after tax and contributions');
else
    none(ax, 'No housing in these results');
end
title(ax, sprintf('(%s)  Housing costs over income after tax and contributions', letter(k)), 'FontSize', FT);

% Row 4: the equity share policy at three ages, or in the pension view the
% stock share of financial wealth and the policy at two
ages = [30 55 75];
if pension_view
    ax = tile(tl, ret, FS); k = k + 1;
    for i = n:-1:1
        d = D{i}; a = d.ages(1:end-1);
        M = (d.eq_liquid + d.eq_pension) ./ max(d.fin, 1e-12);
        M = M(:, 1:end-1);
        if i == 1
            uistack(fill(ax, [a, fliplr(a)], [quantile(M, 0.1, 1), fliplr(quantile(M, 0.9, 1))], ...
                [0.85 0.85 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off'), 'bottom');
        end
        plot(ax, a, mean(M, 1, 'omitnan'), styles{i}, 'Color', cols(i, :), 'LineWidth', lw(i));
    end
    ylim(ax, [0 1]); ylabel(ax, 'Stock share [0-1]');
    title(ax, sprintf('(%s)  Stock share of liquid saving plus pension account', letter(k)), 'FontSize', FT);
    ages = ages(2:3);
end
for j = 1:numel(ages)
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = FS; k = k + 1;
    policy_panel(ax, rs, D, ages(j), cols, styles, lw);
    title(ax, sprintf('(%s)  Equity share policy at age %d', letter(k), ages(j)), 'FontSize', FT);
end

% Settings and checks
ax = nexttile(tl, [1 2]); axis(ax, 'off'); k = k + 1;
text(ax, 0, 1, info_lines(rs, labels), 'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'FontSize', FS - 1.5, 'Interpreter', 'none', 'FontName', 'Consolas');
title(ax, sprintf('(%s)  Settings and checks', letter(k)), 'FontSize', FT);

if ~isempty(file)
    axs = findall(fig, 'Type', 'axes');
    for i = 1:numel(axs)
        if ~isempty(axs(i).Toolbar), axs(i).Toolbar.Visible = 'off'; end
    end
    exportgraphics(fig, file, 'Resolution', 120);
    close(fig);
end
end

% ------------------------------------------------------------------------
function h = runs_panel(ax, D, f, scl, cols, styles, lw, drop_last)
% Mean of f(d) for every result, the reference's 10th-90th percentile band
% behind it. drop_last leaves out the last age (shares: nothing is held then).
if nargin < 8, drop_last = false; end
n = numel(D);
h = gobjects(1, n);
for i = n:-1:1
    a = D{i}.ages; M = f(D{i}) * scl(i);
    if drop_last, a = a(1:end-1); M = M(:, 1:end-1); end
    if i == 1
        uistack(fill(ax, [a, fliplr(a)], [quantile(M, 0.1, 1), fliplr(quantile(M, 0.9, 1))], ...
            [0.85 0.85 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off'), 'bottom');
    end
    h(i) = plot(ax, a, mean(M, 1, 'omitnan'), styles{i}, 'Color', cols(i, :), 'LineWidth', lw(i));
end
uistack(h(1), 'top');
end

function none(ax, msg)
text(ax, 0.5, 0.5, msg, 'Units', 'normalized', 'HorizontalAlignment', 'center', ...
    'FontSize', 11, 'Color', [0.55 0.55 0.55]);
end

function s = letter(k)
% a, b, ..., z, then aa, ab, ...
if k <= 26, s = char('a' + k - 1); else, s = [char('a' + floor((k - 1) / 26) - 1), char('a' + mod(k - 1, 26))]; end
end

% ------------------------------------------------------------------------
function ax = tile(tl, ret, FS)
ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
ax.FontSize = FS; ax.XLim = [25 100];
xline(ax, ret, 'k--', 'HandleVisibility', 'off');
xlabel(ax, 'Age');
end

function policy_panel(ax, rs, D, age, cols, styles, lw)
% pi(u1) at this age, drawn against W/Y = 1/u1 over the u1 range the
% households occupy. Each result is read off its own grid with the
% interpolant the simulator uses, at its own households' median (u2, u3) and
% at q = 1, so that steps with and without a pension or a house are each shown
% where their households are; dotted lines mark each result's median
% household.
t = age - rs{1}.p.age0 + 1;
lo = inf; hi = 0; sl = zeros(numel(rs), 3);
for i = 1:numel(rs)
    s = D{i}.sim; u1 = s.lambda(:, t);
    sl(i, :) = [median(u1), median((s.sA(:, t) + s.sH(:, t)) ./ max(1 - u1, 1e-12)), ...
                median(min(max(s.sA(:, t) ./ max(s.sA(:, t) + s.sH(:, t), 1e-12), 0), 1))];
    lo = min(lo, prctile(u1, 1) / 1.5); hi = max(hi, min(1, prctile(u1, 99) * 1.5));
end
uq = exp(linspace(log(lo), log(hi), 200)).';
for i = numel(rs):-1:1
    p = rs{i}.p; u2 = sl(i, 2); u3 = sl(i, 3);
    [g1, g2] = utility.grid_at(p, t);
    F = griddedInterpolant({g1, g2, p.u3_grid}, rs{i}.sol.pi_pol(:, :, :, p.q_grid == 1, t), ...
        'linear', 'nearest');
    plot(ax, 1 ./ uq, F(uq, u2 * ones(size(uq)), u3 * ones(size(uq))), styles{i}, ...
        'Color', cols(i, :), 'LineWidth', lw(i));
    nodes = g1(g1 >= lo & g1 <= hi);
    plot(ax, 1 ./ nodes, F(nodes, u2 * ones(size(nodes)), u3 * ones(size(nodes))), 'o', ...
        'Color', cols(i, :), 'MarkerSize', 4, 'MarkerFaceColor', 'w', 'HandleVisibility', 'off');
    xline(ax, 1 / sl(i, 1), ':', 'Color', cols(i, :), 'LineWidth', 1, 'HandleVisibility', 'off');
end
set(ax, 'XScale', 'log'); xlim(ax, [1 / hi, 1 / lo]); ylim(ax, [-0.02 1.02]);
xlabel(ax, 'Total resources / income (W/Y = 1/u_1), log scale');
ylabel(ax, 'Stock share [0-1]');
if any(cellfun(@(d) d.has_housing || d.has_pension, D))
    txt = sprintf('each at its households'' median u_2 (%s)', ...
        strjoin(arrayfun(@(v) sprintf('%.2f', v), sl(:, 2).', 'UniformOutput', false), ', '));
    text(ax, 0.02, 0.04, txt, 'Units', 'normalized', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);
end
end

function L = info_lines(rs, labels)
L = {};
ref = rs{1}.summary;
for i = 1:numel(rs)
    p = rs{i}.p; c = rs{i}.checks; s = rs{i}.summary;
    algo = 'active-set';
    if isfield(p, 'fmincon_algorithm'), algo = p.fmincon_algorithm; end
    pool = 'serial';
    if isfield(rs{i}.timing, 'pool') && isfield(rs{i}.timing.pool, 'type')
        if contains(rs{i}.timing.pool.type, 'Thread'), pool = 'threads';
        elseif contains(rs{i}.timing.pool.type, 'Process'), pool = 'processes'; end
    end
    L{end+1} = labels{i}; %#ok<AGROW>
    L{end+1} = sprintf('  grid %dx%dx%d, gh %d, fmincon %s, sweep %d, %s, %.0f s', ...
        p.N_u1, p.N_u2, p.N_u3, p.gh_n, algo, p.use_refine, pool, rs{i}.timing.solve_sec); %#ok<AGROW>
    [~, fl] = model.floor_kind(p);
    L{end+1} = sprintf('  bound 25-39 %.1f%%  %s %.2f%%  off-grid %d  entry value %.3g', ...
        100 * c.c_bound_25_39, fl, 100 * c.floored_share, sum(c.offgrid), c.ce_entry); %#ok<AGROW>
    if i > 1
        w = 1:numel(s.pi) - 1;
        wx = ref.X.mean >= 0.01 * max(ref.X.mean);      % leave out near-zero savings
        L{end+1} = sprintf('  max |d pi| %.3f   max |dC/C| %.1f%%   max |dX/X| %.1f%%', ...
            max(abs(s.pi(w) - ref.pi(w))), 100 * max(abs(s.C.mean ./ ref.C.mean - 1)), ...
            100 * max(abs(s.X.mean(wx) ./ ref.X.mean(wx) - 1))); %#ok<AGROW>
    end
end
end

function h = income_lines(ax, d, sc)
% Mean gross income and income after tax, contributions and housing costs of
% the reference households, as thin grey lines behind consumption.
c = [0.45 0.45 0.45];
h(1) = plot(ax, d.ages, mean(d.Y, 1, 'omitnan') * sc, '--', 'Color', c, 'LineWidth', 1.3);
h(2) = plot(ax, d.ages, mean(d.disp_inc, 1, 'omitnan') * sc, ':', 'Color', c, 'LineWidth', 1.6);
end

