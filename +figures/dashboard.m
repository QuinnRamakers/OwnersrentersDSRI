function fig = dashboard(r, file)
%DASHBOARD  Twelve-panel life-cycle dashboard of one solved arm.
%
%   figures.dashboard(r)          % r from model.run or a saved ladder result
%   figures.dashboard(r, file)    % also write a PNG
%
%   The layout of the earlier make_plots dashboards: income and housing costs,
%   consumption, disposable income, net worth, the DC account, housing, total
%   wealth with human capital, the share of resources consumed, the equity
%   shares, total stock exposure, the stock share of savings and pension, and
%   the calibration with the checks of model.checks. Lines are means across
%   simulated households; bands the 10th-90th percentiles.

d = figures.panel_data(r);
p = r.p; c = r.checks; a = d.ages; sc = d.scale; ret = p.retirement_age;
col = arm_colour(r.tenure);
FS = 10; FT = 11; LFS = 9; LWD = 1.9;

fig = figure('Visible', 'off', 'Position', [30 30 2200 1240], 'Color', 'w');
tl  = tiledlayout(fig, 3, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {['Dashboard — ' title_text(r)], ...
    'Lines show the average across simulated households; shaded bands show the 10th-90th percentile range'}, ...
    'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');

% (a) Income and housing costs
ax = tile(tl, ret, FS);
band(ax, a, d.Y * sc, [0.25 0.45 0.75], 'Gross income (before any deductions)', LWD);
band(ax, a, d.disp_inc * sc, [0.85 0.50 0.20], 'Disposable income (after tax, contributions and housing)', LWD);
if d.has_pension
    band(ax, a, d.ann_pay * sc, [0.25 0.65 0.35], 'Pension annuity payment', LWD);
end
if d.has_housing
    if p.is_owner, lbl = 'Housing cost (maintenance + mortgage payment)';
    else, lbl = 'Housing cost (rent payment)'; end
    band(ax, a, d.housing_cost * sc, [0.80 0.25 0.25], lbl, LWD);
end
ylabel(ax, d.unit); title(ax, '(a)  Income and housing costs over the lifecycle', 'FontSize', FT);
legend(ax, 'Location', 'northwest', 'FontSize', LFS);

% (b) Consumption
ax = tile(tl, ret, FS);
band(ax, a, d.C * sc, col, 'Consumption spending', LWD);
ylabel(ax, d.unit); title(ax, '(b)  Consumption spending over the lifecycle', 'FontSize', FT);

% (c) Disposable income: where it comes from, where it goes
ax = tile(tl, ret, FS);
figures.income_decomposition(ax, d, p, LFS - 2);
title(ax, '(c)  Disposable income', 'FontSize', FT);

% (d) Net worth
ax = tile(tl, ret, FS);
ha = area(ax, a, [mean(d.X, 1); mean(d.A, 1); mean(d.H_net, 1)].' * sc);
ha(1).FaceColor = [0.50 0.68 0.84]; ha(2).FaceColor = [0.95 0.75 0.28]; ha(3).FaceColor = [0.42 0.76 0.48];
set(ha, 'FaceAlpha', 0.85);
ha(1).DisplayName = 'Liquid savings';
ha(2).DisplayName = 'Pension account balance';
ha(3).DisplayName = 'Net housing equity (home value minus mortgage owed)';
ylabel(ax, d.unit); title(ax, '(d)  Net worth: savings, pension and housing equity combined', 'FontSize', FT);
legend(ax, 'Location', 'northwest', 'FontSize', LFS);

% (e) Pension account
ax = tile(tl, ret, FS);
if d.has_pension
    band(ax, a, d.A * sc, [0.85 0.60 0.15], 'Account balance', LWD);
    band(ax, a, d.ann_pay * sc, [0.25 0.65 0.35], 'Annuity payments after retirement', LWD);
    legend(ax, 'Location', 'best', 'FontSize', LFS);
    title(ax, '(e)  Pension account balance and payouts', 'FontSize', FT);
else
    none(ax, 'No DC pension at this step');
    title(ax, '(e)  Pension account (not in this step)', 'FontSize', FT);
end
ylabel(ax, d.unit);

% (f) Housing
ax = tile(tl, ret, FS);
if d.has_housing && p.is_owner
    band(ax, a, d.H * sc, [0.60 0.82 0.58], 'Home value', LWD);
    band(ax, a, d.M_balance * sc, [0.82 0.25 0.25], 'Mortgage balance owed', LWD);
    band(ax, a, d.H_net * sc, [0.15 0.52 0.25], 'Net home equity (value minus mortgage owed)', LWD);
    legend(ax, 'Location', 'best', 'FontSize', LFS);
    title(ax, '(f)  Home value, mortgage balance and net equity', 'FontSize', FT);
elseif d.has_housing
    band(ax, a, d.H * sc, [0.55 0.55 0.55], sprintf('Rent index (rent = %.1f%% of it)', 100 * p.alpha), LWD);
    legend(ax, 'Location', 'best', 'FontSize', LFS);
    title(ax, '(f)  Rent index (renters build no housing equity)', 'FontSize', FT);
else
    none(ax, 'No housing at this step');
    title(ax, '(f)  Housing (not in this step)', 'FontSize', FT);
end
ylabel(ax, d.unit);

% (g) Total wealth
ax = tile(tl, ret, FS);
m = @(M) mean(M, 1) * sc;
plot(ax, a, m(d.HC), '-', 'Color', [0.55 0.35 0.65], 'LineWidth', LWD, 'DisplayName', 'Value of future income (human capital)');
plot(ax, a, m(d.X), '-', 'Color', [0.30 0.50 0.75], 'LineWidth', LWD, 'DisplayName', 'Liquid savings');
if d.has_pension
    plot(ax, a, m(d.A), '-', 'Color', [0.85 0.60 0.15], 'LineWidth', LWD, 'DisplayName', 'Pension account balance');
end
if d.has_housing && p.is_owner
    plot(ax, a, m(d.H_net), '-', 'Color', [0.30 0.65 0.35], 'LineWidth', LWD, 'DisplayName', 'Net housing equity');
end
plot(ax, a, m(d.net_worth + d.HC), 'k-', 'LineWidth', 2.4, 'DisplayName', 'Total wealth (all components combined)');
ylabel(ax, d.unit); title(ax, '(g)  Total wealth (net worth + human capital)', 'FontSize', FT);
legend(ax, 'Location', 'best', 'FontSize', LFS - 1);

% (h) Share of resources consumed
ax = tile(tl, ret, FS);
band(ax, a, d.c_frac, col, 'Consumption share', LWD);
ylim(ax, [0 1]); ylabel(ax, 'Share of resources spent [0-1]');
title(ax, '(h)  Share of available resources spent on consumption', 'FontSize', FT);

% (i) Stock shares
w = a < a(end);                                   % nothing is held in the last period
ax = tile(tl, ret, FS);
band(ax, a(w), d.pi(:, w), col, 'Liquid savings: stock share chosen by the household', LWD);
if d.has_pension
    plot(ax, a(w), d.tau_path(w), '--', 'Color', [0.75 0.25 0.25], 'LineWidth', LWD, ...
        'DisplayName', 'Pension fund: stock share set by the plan''s glide path');
end
yline(ax, c.merton_liquid, ':', 'Color', [0.80 0.20 0.20], 'LineWidth', 1.4, ...
    'DisplayName', sprintf('Merton share of the liquid account (%.2f)', c.merton_liquid));
ylim(ax, [-0.02 1.02]); ylabel(ax, 'Stock share [0-1]');
title(ax, '(i)  Stock share: household savings vs. the pension fund', 'FontSize', FT);
legend(ax, 'Location', 'best', 'FontSize', LFS - 1);

% (j) Total stock exposure relative to total wealth
ax = tile(tl, ret, FS);
Wt = max(d.net_worth + d.HC, 1e-10);
aj = area(ax, a, [mean(d.eq_liquid ./ Wt, 1, 'omitnan'); mean(d.eq_pension ./ Wt, 1, 'omitnan')].');
aj(1).FaceColor = [0.30 0.55 0.80]; aj(2).FaceColor = [0.85 0.60 0.20];
set(aj, 'FaceAlpha', 0.85, 'EdgeColor', 'none');
aj(1).DisplayName = 'Liquid savings invested in stocks';
aj(2).DisplayName = 'Pension invested in stocks';
yline(ax, c.merton_liquid, 'r--', 'Merton fraction', 'LabelHorizontalAlignment', 'left', ...
    'LineWidth', 1.5, 'FontSize', FS - 1, 'HandleVisibility', 'off');
ylim(ax, [0 1]); ylabel(ax, 'Share of total wealth [0-1]');
title(ax, '(j)  Total stock exposure: liquid and pension holdings combined', 'FontSize', FT);
legend(ax, 'Location', 'best', 'FontSize', LFS - 1);

% (k) Stock share of savings and pension
ax = tile(tl, ret, FS);
ef = (d.eq_liquid + d.eq_pension) ./ d.fin;
ef(d.fin < 1e-6) = NaN;
band(ax, a(w), ef(:, w), [0.55 0.22 0.65], 'Stock share of savings and pension', LWD);
ylim(ax, [0 1]); ylabel(ax, 'Stock share [0-1]');
title(ax, '(k)  Stock exposure relative to savings and pension only', 'FontSize', FT);

% (l) Calibration and checks
ax = nexttile(tl); axis(ax, 'off');
text(ax, 0.0, 1.0, info_text(r, d), 'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'FontSize', FS - 0.5, 'Interpreter', 'tex');
title(ax, '(l)  Calibration and checks', 'FontSize', FT);

if d.has_housing && p.is_owner
    if strcmp(p.mortgage, 'annuity')
        note = ['The mortgage is a real annuity on the purchase price; panels (d), (f) and (g) use its ' ...
                'balance. Maintenance is charged on the ' maint_base(p) '.'];
    else
        note = ['Panels (a) and (c) use the model''s mortgage payment, a rate on the current home value. ' ...
                'Panels (d), (f) and (g) use a fixed-payment schedule on the house at entry.'];
    end
    annotation(fig, 'textbox', [0.01 0.00 0.98 0.02], 'String', note, ...
        'FontSize', 7, 'EdgeColor', 'none', 'Color', [0.4 0.4 0.4], 'HorizontalAlignment', 'center');
end

if nargin > 1 && ~isempty(file)
    hide_toolbars(fig);
    exportgraphics(fig, file, 'Resolution', 150);
    close(fig);
end
end

% ------------------------------------------------------------------------
function ax = tile(tl, ret, FS)
ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
ax.FontSize = FS; ax.XLim = [20 100];
xline(ax, ret, 'k--', 'HandleVisibility', 'off');
xlabel(ax, 'Age');
end

function band(ax, x, M, color, name, lwd)
% Mean line and 10th-90th percentile band of an N x T matrix.
mu = mean(M, 1, 'omitnan');
lo = quantile(M, 0.10, 1);
hi = quantile(M, 0.90, 1);
fill(ax, [x, fliplr(x)], [lo, fliplr(hi)], min(1, color * 0.5 + 0.5), 'EdgeColor', 'none', ...
    'FaceAlpha', 0.25, 'HandleVisibility', 'off');
plot(ax, x, mu, '-', 'Color', color, 'LineWidth', lwd, 'DisplayName', name);
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

function s = maint_base(p)
if p.maint_on_purchase, s = 'purchase price'; else, s = 'current value'; end
end

function t = title_text(r)
t = r.tenure;
if isfield(r, 'step')
    t = sprintf('Step %s, %s: %s', r.step.number, r.step.label, r.tenure);
end
end

function L = info_text(r, d)
p = r.p; c = r.checks;
kap = config.kappa_path(p); kapw = kap(1 : p.t_ret - 1);
[~, sigma_l] = config.income_process(p);
L = {'\bfCalibration\rm'};
L{end+1} = sprintf('CRRA \\gamma=%.3g   |   \\beta=%.2f   |   bequest \\chi=%.2f   |   retire at %d', ...
    p.gamma, p.beta, p.chi, p.retirement_age);
L{end+1} = sprintf('Income %s, permanent shock std %.4f, replacement %.1f%%', ...
    p.income_source, sigma_l, 100 * p.replacement);
L{end+1} = sprintf('r=%.2f%%   |   equity premium %.2f%%   |   equity vol %.2f%%   |   corr_{SL}=%.2f', ...
    100 * p.r, 100 * p.mu_S_level, 100 * p.sigma_S_level, p.corr_SL);
if d.has_pension
    L{end+1} = sprintf('DC: \\kappa_t=%.1f-%.1f%% of gross (franchise-based), glide %.2f', ...
        100 * min(kapw), 100 * max(kapw), p.glide_cap);
else
    L{end+1} = 'No DC pension';
end
L{end+1} = sprintf('Income tax %.1f%%   |   box 3 bond/stock %.0f%%/%.0f%%, loss offset %d', ...
    100 * p.tau_inc, 100 * p.tau_cg_bond, 100 * p.tau_cg_stock, p.cg_loss_offset);
if d.has_housing && p.is_owner
    L{end+1} = sprintf('Owner: house %.1f\\times income, LTV %.0f%%, r_m %.2f%%, %s mortgage', ...
        p.h_mult, 100 * p.LTV, 100 * p.r_m, p.mortgage);
    L{end+1} = sprintf('Maintenance %.1f%% of the %s', 100 * p.theta, maint_base(p));
elseif d.has_housing
    L{end+1} = sprintf('Renter: rent %.1f%% of a rent index at %.1f\\times income', 100 * p.alpha, p.h_mult);
else
    L{end+1} = 'No housing';
end
if d.has_housing
    [mu_h, s_h] = deal(p.mu_H_level, p.sigma_H_level);
    if ~p.is_owner, [mu_h, s_h] = deal(p.mu_R_level, p.sigma_R_level); end
    [cHL, cSH] = config.h_corr(p);
    L{end+1} = sprintf('H growth %.2f%%, vol %.2f%%   |   corr(income, H) %.2f, corr(stock, H) %.2f', ...
        100 * mu_h, 100 * s_h, cHL, cSH);
end
algo = 'active-set';
if isfield(p, 'fmincon_algorithm'), algo = p.fmincon_algorithm; end
sweep = 'on'; if ~p.use_refine, sweep = 'off'; end
L{end+1} = sprintf('Grid %d\\times%d\\times%d, %d nodes per shock, fmincon %s, sweep %s, N = %d', ...
    p.N_u1, p.N_u2, p.N_u3, p.gh_n, algo, sweep, d.sim.N);
L{end+1} = '';
L{end+1} = '\bfChecks\rm';
L{end+1} = sprintf('At the search bound, ages 25-39: %.1f%%   |   floored: %.2f%% of years', ...
    100 * c.c_bound_25_39, 100 * c.floored_share);
L{end+1} = sprintf('Entry value = constant %.3g \\times entry income   |   off-grid lookups %d', ...
    c.ce_entry, sum(c.offgrid));
if isfield(c, 'corr_SL_nodes')
    L{end+1} = sprintf('Liquid Merton share %.3f   |   corr(income, stock): nodes %.3f, panel %.3f', ...
        c.merton_liquid, c.corr_SL_nodes, c.corr_SL_sim);
else
    L{end+1} = sprintf('Liquid Merton share %.3f', c.merton_liquid);
end
L{end+1} = sprintf('Solve %.0f s', r.timing.solve_sec);
for i = 1:numel(c.notes)
    L = [L, wrap(['Note: ' strrep(c.notes{i}, '_', '\_')], 95)]; %#ok<AGROW>
end
end

function lines = wrap(s, n)
words = strsplit(s, ' '); lines = {}; cur = '';
for i = 1:numel(words)
    if isempty(cur)
        cur = words{i};
    elseif numel(cur) + numel(words{i}) + 1 > n
        lines{end+1} = cur; cur = words{i}; %#ok<AGROW>
    else
        cur = [cur ' ' words{i}]; %#ok<AGROW>
    end
end
if ~isempty(cur), lines{end+1} = cur; end
end

function hide_toolbars(fig)
axs = findall(fig, 'Type', 'axes');
for i = 1:numel(axs)
    if ~isempty(axs(i).Toolbar), axs(i).Toolbar.Visible = 'off'; end
end
end
