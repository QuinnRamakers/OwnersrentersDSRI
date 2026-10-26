function fig = mortgage(r, file, opts)
%MORTGAGE  The model's mortgage against two real annuity contracts, per household.
%
%   figures.mortgage(r_owner)
%   figures.mortgage(r_owner, file, inflation=0.023)
%   figures.mortgage(r_owner, file, panels='payment', nominal=false)
%
%   The model's contract is p.mortgage. With 'annuity' it charges the annuity
%   rate of an N_mort-year loan at r_m on the purchase price, so its line lies
%   on the real annuity. With 'proportional' (ladder step 7) it charges that
%   rate on the current house value, so the payment grows and varies with
%   house prices. Two real contracts on the same loan (LTV times the house at
%   entry) are drawn against it:
%     real annuity      the same rate and term on the price at entry: a payment
%                       constant in real terms
%     nominal annuity   the Dutch fixed-payment annuity at the nominal rate
%                       r_m + inflation, whose fixed euro payment falls in real
%                       terms with inflation (default 2.3%, the inflation that
%                       turns the ECB rate of 3.66% into r_m; CALIBRATION.md)
%   Panels: the payment, the payment over gross income, the outstanding
%   balance, cumulative payments, the present value of all payments at r_m
%   against the loan, and the numbers. Model lines are means across simulated
%   households with 10th-90th percentile bands; the real contracts are the
%   same for every household. panels='payment' draws only the payment panel;
%   nominal=false leaves out the nominal annuity.

arguments
    r (1,1) struct
    file (1,:) char = ''
    opts.inflation (1,1) double = 0.023
    opts.panels (1,:) char {mustBeMember(opts.panels, {'all', 'payment'})} = 'all'
    opts.nominal (1,1) logical = true
end

p = r.p;
assert(p.is_owner && p.h_mult > 0, 'figures:mortgage', 'needs an owner result with housing');
d  = figures.panel_data(r);
a  = d.ages; sc = d.scale; T = numel(a);
n  = p.N_mort; rm = p.r_m; pin = opts.inflation; rn = (1 + rm) * (1 + pin) - 1;
H0 = d.sim.H(1, 1); L = p.LTV * H0;                 % every household enters with the same house
assert(all(abs(d.sim.H(:, 1) - H0) < 1e-9 * H0), 'figures:mortgage', 'households enter with different houses');
ann  = @(i) i * (1 + i)^n / ((1 + i)^n - 1);
owed = @(i, e) (e < n) .* ((1 + i)^n - (1 + i).^e) / ((1 + i)^n - 1);   % balance share after e payments

e = 0:T-1;                                      % years since purchase
on = e < n;                                     % paying years
annuity = strcmp(p.mortgage, 'annuity');
% Payments, real euros
pay_model = d.sim.m_pay;                          % from the simulation
pay_real  = (L * ann(rm)) .* on;
pay_nom   = (L * ann(rn)) .* on ./ (1 + pin).^(e + 1);   % paid at the end of each year
% Balances at the start of each year, real euros
bal_real  = L .* owed(rm, e);
if annuity
    bal_model = repmat(bal_real, size(d.sim.H, 1), 1);
else
    bal_model = owed(rm, e) .* d.sim.H * p.LTV;      % a share of the current house
end
bal_nom   = L .* owed(rn, e) ./ (1 + pin).^e;
% Present value at entry of all payments, at r_m, each paid at the end of its year
disc = (1 + rm).^(-(e + 1));                     % payments at the end of each year
pv_model = sum(pay_model .* disc, 2);
pv_real  = sum(pay_real(1, :) .* disc);
pv_nom   = sum(pay_nom(1, :) .* disc);

st = figures.style();
cm = [0.65 0.15 0.15]; cr = st.series(1, :); cn = st.series(2, :);
FS = 10; FT = 11; LWD = 2;
nom = opts.nominal;
step = ''; if isfield(r, 'step'), step = sprintf('Step %s, %s: ', r.step.number, r.step.label); end
if annuity
    base = 'purchase price'; model_leg = 'model: real annuity on the purchase price';
else
    base = 'current house value'; model_leg = 'model: rate x current house value';
end
key = sprintf('Red = model (mean, 10-90 band); blue = real annuity at %.2f%% real', 100 * rm);
if nom
    key = [key sprintf('; orange = nominal annuity at %.2f%% with %.1f%% inflation, in real euros', 100 * rn, 100 * pin)];
end
ttl = {sprintf('%sthe model''s mortgage against a real annuity mortgage (owner)', step), ...
    sprintf('Loan %.0f%% of the house at entry (EUR %.0fk), %d years. Model: %.2f%% of the %s each year.', ...
    100 * p.LTV, H0 * sc, n, 100 * ann(rm), base), key};
leg = {model_leg, 'real annuity on the price at entry', 'nominal annuity, in real euros'};
if ~nom, leg = leg(1:2); end

if strcmp(opts.panels, 'payment')
    fig = figure('Visible', 'off', 'Position', [30 30 1300 700], 'Color', 'w');
    ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = FS + 1;
    xlabel(ax, 'Age');
    leg(1:2) = {sprintf('Model (rate x %s)', base), 'Fixed rate mortgage'};
    payment_panel(ax, a, pay_model, pay_real, pay_nom, sc, nom, cm, cr, cn, LWD, d.unit, leg);
    title(ax, 'Annual mortgage payment', 'FontSize', FT + 2);
else
    fig = figure('Visible', 'off', 'Position', [30 30 2100 1150], 'Color', 'w');
    tl  = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    title(tl, ttl, 'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');

    ax = tile(tl, FS);
    payment_panel(ax, a, pay_model, pay_real, pay_nom, sc, nom, cm, cr, cn, LWD, d.unit, leg);
    title(ax, '(a)  Annual mortgage payment', 'FontSize', FT);

    ax = tile(tl, FS);
    band(ax, a, 100 * pay_model ./ d.sim.Y, cm, LWD);
    band(ax, a, 100 * pay_real ./ d.sim.Y, cr, LWD);
    if nom, band(ax, a, 100 * pay_nom ./ d.sim.Y, cn, LWD); end
    xlim(ax, [25 60]); ylabel(ax, '% of gross income');
    title(ax, '(b)  Payment over gross income (each with its 10-90 band)', 'FontSize', FT);

    ax = tile(tl, FS);
    band(ax, a, bal_model * sc, cm, LWD);
    plot(ax, a, bal_real * sc, '-', 'Color', cr, 'LineWidth', LWD);
    if nom, plot(ax, a, bal_nom * sc, '-', 'Color', cn, 'LineWidth', LWD); end
    xlim(ax, [25 60]); ylabel(ax, d.unit);
    title(ax, sprintf('(c)  Outstanding balance (model: its share of the %s)', base), 'FontSize', FT);

    ax = tile(tl, FS);
    band(ax, a, cumsum(pay_model, 2) * sc, cm, LWD);
    plot(ax, a, cumsum(pay_real) * sc, '-', 'Color', cr, 'LineWidth', LWD);
    if nom, plot(ax, a, cumsum(pay_nom) * sc, '-', 'Color', cn, 'LineWidth', LWD); end
    yline(ax, L * sc, 'k:', 'loan', 'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
    xlim(ax, [25 60]); ylabel(ax, d.unit);
    title(ax, '(d)  Cumulative payments, real euros, undiscounted', 'FontSize', FT);

    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = FS;
    histogram(ax, pv_model / L, 60, 'FaceColor', cm, 'EdgeColor', 'none', 'FaceAlpha', 0.6, ...
        'Normalization', 'probability');
    xline(ax, pv_real / L, '-', 'Color', cr, 'LineWidth', LWD);
    if nom, xline(ax, pv_nom / L, '--', 'Color', cn, 'LineWidth', LWD); end
    xline(ax, mean(pv_model) / L, '-', 'Color', cm, 'LineWidth', LWD);
    xlabel(ax, 'present value of all payments at r_m, multiples of the loan');
    ylabel(ax, 'share of households');
    lg = {'model, per household', 'real annuity', 'nominal annuity', 'model, mean'};
    if ~nom, lg(3) = []; end
    legend(ax, lg, 'FontSize', 9);
    title(ax, '(e)  What the mortgage costs, in present value at entry', 'FontSize', FT);

    ax = nexttile(tl); axis(ax, 'off');
    q  = @(x, k) prctile(x, k);
    at = @(M, age) M(:, a == age);
    nv = @(fmt, v) nom_part(nom, fmt, v);              % the nominal contract's figure, when shown
    Lt = {
        sprintf('Loan at entry: EUR %.0fk (%.0f%% of a house of %.1f x entry income)', L * sc, 100 * p.LTV, p.h_mult)
        [sprintf('Annuity rate: %.2f%% real (model and real annuity)', 100 * ann(rm)) nv(', %.2f%% nominal', 100 * ann(rn))]
        ''
        'Annual payment, EUR thousand (2025):'
        [sprintf('  age 25: model %.1f; real annuity %.1f', mean(at(pay_model, 25)) * sc, pay_real(1) * sc) ...
            nv('; nominal annuity %.1f', pay_nom(1) * sc)]
        [sprintf('  age 40: model mean %.1f (p10 %.1f, p90 %.1f); real %.1f', mean(at(pay_model, 40)) * sc, ...
            q(at(pay_model, 40), 10) * sc, q(at(pay_model, 40), 90) * sc, pay_real(a == 40) * sc) nv('; nominal %.1f', pay_nom(a == 40) * sc)]
        [sprintf('  age 54: model mean %.1f (p10 %.1f, p90 %.1f); real %.1f', mean(at(pay_model, 54)) * sc, ...
            q(at(pay_model, 54), 10) * sc, q(at(pay_model, 54), 90) * sc, pay_real(a == 54) * sc) nv('; nominal %.1f', pay_nom(a == 54) * sc)]
        ''
        'Payment over gross income, mean:'
        [sprintf('  age 25: model %.1f%%, real %.1f%%', 100 * mean(at(pay_model ./ d.sim.Y, 25)), ...
            100 * mean(at(pay_real ./ d.sim.Y, 25))) nv(', nominal %.1f%%', 100 * mean(at(pay_nom ./ d.sim.Y, 25)))]
        [sprintf('  age 45: model %.1f%%, real %.1f%%', 100 * mean(at(pay_model ./ d.sim.Y, 45)), ...
            100 * mean(at(pay_real ./ d.sim.Y, 45))) nv(', nominal %.1f%%', 100 * mean(at(pay_nom ./ d.sim.Y, 45)))]
        [sprintf('  age 54: model %.1f%%, real %.1f%%', 100 * mean(at(pay_model ./ d.sim.Y, 54)), ...
            100 * mean(at(pay_real ./ d.sim.Y, 54))) nv(', nominal %.1f%%', 100 * mean(at(pay_nom ./ d.sim.Y, 54)))]
        ''
        'Total paid over the term, real, undiscounted (multiples of the loan):'
        [sprintf('  model mean %.2f (p10 %.2f, p90 %.2f); real %.2f', mean(sum(pay_model, 2)) / L, ...
            q(sum(pay_model, 2), 10) / L, q(sum(pay_model, 2), 90) / L, sum(pay_real) / L) nv('; nominal %.2f', sum(pay_nom) / L)]
        'Present value at r_m (multiples of the loan):'
        [sprintf('  model mean %.2f (p10 %.2f, median %.2f, p90 %.2f); real %.2f', mean(pv_model) / L, ...
            q(pv_model, 10) / L, q(pv_model, 50) / L, q(pv_model, 90) / L, pv_real / L) nv('; nominal %.2f', pv_nom / L)]
        sprintf('  households paying more than the loan in PV: %.0f%%', 100 * mean(pv_model > L * 1.0001))
        };
    text(ax, 0, 1, Lt, 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', FS - 0.5, ...
        'Interpreter', 'none', 'FontName', 'Consolas');
    title(ax, '(f)  Numbers', 'FontSize', FT);
end

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
function ax = tile(tl, FS)
ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
ax.FontSize = FS; xlabel(ax, 'Age');
end

function band(ax, x, M, col, lwd)
if size(M, 1) == 1, M = repmat(M, 2, 1); end
lo = prctile(M, 10, 1); hi = prctile(M, 90, 1);
fill(ax, [x, fliplr(x)], [lo, fliplr(hi)], min(1, col * 0.5 + 0.5), 'EdgeColor', 'none', ...
    'FaceAlpha', 0.3, 'HandleVisibility', 'off');
plot(ax, x, mean(M, 1), '-', 'Color', col, 'LineWidth', lwd);
end

function payment_panel(ax, a, pay_model, pay_real, pay_nom, sc, nom, cm, cr, cn, lwd, unit, leg)
band(ax, a, pay_model * sc, cm, lwd);
plot(ax, a, pay_real * sc, '-', 'Color', cr, 'LineWidth', lwd);
if nom, plot(ax, a, pay_nom * sc, '-', 'Color', cn, 'LineWidth', lwd); end
xlim(ax, [25 60]); ylabel(ax, unit);
legend(ax, leg, 'Location', 'northwest', 'FontSize', 9);
end

function s = nom_part(nom, fmt, v)
% The nominal contract's part of a numbers line, or nothing when it is not shown.
s = '';
if nom, s = sprintf(fmt, v); end
end
