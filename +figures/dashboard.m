function fig = dashboard(r, file)
%DASHBOARD  Life-cycle profiles of one solved tenure, on one page.
%
%   figures.dashboard(r)          % r from model.run or a saved ladder result
%   figures.dashboard(r, file)    % also write a PNG
%
%   Panels: income, consumption and housing cost; wealth; equity shares;
%   housing cost over net income; households not choosing their consumption
%   freely (floored, or at the search bound); and the calibration with the
%   checks from model.checks. Bands are the 10th-90th percentiles across
%   households.

st = figures.style();
s  = r.summary; p = r.p; a = s.ages;
eur = strcmp(s.units, 'EUR 2025');
if eur, scale = 1e-3; ylab = 'EUR 2025, thousands';
else,   scale = 1;    ylab = s.units;
end
ret = p.retirement_age;

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1500 860]);
tl  = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, title_text(r), 'FontSize', 13, 'Color', st.ink);

% (a) income, consumption, housing cost
ax = nexttile(tl); prep(ax, st, ret);
band(ax, a, s.C.p10 * scale, s.C.p90 * scale, st.series(2, :), st);
h1 = plot(ax, a, s.net_income.mean * scale, 'Color', st.series(1, :), 'LineWidth', st.lw);
h2 = plot(ax, a, s.C.p50 * scale, 'Color', st.series(2, :), 'LineWidth', st.lw);
hs = [h1 h2]; names = {'net income (mean)', 'consumption (median, 10-90 band)'};
if p.h_mult > 0
    hs(end+1) = plot(ax, a, s.housing_cost.mean * scale, 'Color', st.series(3, :), 'LineWidth', st.lw);
    names{end+1} = 'housing cost (mean)';
end
legend(ax, hs, names, 'Location', 'northwest', 'Box', 'off', 'TextColor', st.ink2);
ylabel(ax, ylab); title(ax, 'Income and spending', 'Color', st.ink);

% (b) wealth
ax = nexttile(tl); prep(ax, st, ret);
hs = plot(ax, a, s.X.mean * scale, 'Color', st.series(1, :), 'LineWidth', st.lw);
names = {'liquid'};
if any(s.A.mean > 0)
    hs(end+1) = plot(ax, a, s.A.mean * scale, 'Color', st.series(2, :), 'LineWidth', st.lw);
    names{end+1} = 'DC pot';
end
if p.is_owner && p.h_mult > 0
    hs(end+1) = plot(ax, a, s.home_equity.mean * scale, 'Color', st.series(3, :), 'LineWidth', st.lw);
    names{end+1} = 'home equity';
end
if numel(hs) > 1
    legend(ax, hs, names, 'Location', 'northwest', 'Box', 'off', 'TextColor', st.ink2);
end
ylabel(ax, ylab); title(ax, 'Wealth (means)', 'Color', st.ink);

% (c) equity shares
ax = nexttile(tl); prep(ax, st, ret);
w = a < a(end);                                   % the last period holds nothing
band(ax, a(w), s.pi_p10(w), s.pi_p90(w), st.series(1, :), st);
hs = plot(ax, a(w), s.pi(w), 'Color', st.series(1, :), 'LineWidth', st.lw);
names = {'liquid account (mean, 10-90 band)'};
if any(s.A.mean > 0)
    hs(end+1) = plot(ax, a(w), s.dc_share(w), 'Color', st.series(2, :), 'LineWidth', st.lw);
    hs(end+1) = plot(ax, a(w), s.equity_share(w), 'Color', st.series(3, :), 'LineWidth', st.lw);
    names = [names, {'DC fund (glide)', 'all financial wealth'}];
end
legend(ax, hs, names, 'Location', 'southwest', 'Box', 'off', 'TextColor', st.ink2);
ylim(ax, [0 1]); ylabel(ax, 'equity share'); title(ax, 'Equity shares', 'Color', st.ink);

% (d) housing burden
ax = nexttile(tl); prep(ax, st, ret);
if p.h_mult > 0
    plot(ax, a, 100 * s.burden, 'Color', st.series(1, :), 'LineWidth', st.lw);
    ylabel(ax, '% of net income');
    title(ax, 'Housing cost over net income (median)', 'Color', st.ink);
else
    text(ax, 0.5, 0.5, 'no housing at this calibration', 'Units', 'normalized', ...
        'HorizontalAlignment', 'center', 'Color', st.muted);
    title(ax, 'Housing cost over net income', 'Color', st.ink);
end

% (e) constrained households
ax = nexttile(tl); prep(ax, st, ret);
h1 = plot(ax, a, 100 * s.floored, 'Color', st.series(1, :), 'LineWidth', st.lw);
h2 = plot(ax, a, 100 * s.at_c_bound, 'Color', st.series(2, :), 'LineWidth', st.lw);
legend(ax, [h1 h2], {'topped up to the floor', 'at the consumption-search bound'}, ...
    'Location', 'northeast', 'Box', 'off', 'TextColor', st.ink2);
ylabel(ax, '% of households'); title(ax, 'Consumption not freely chosen', 'Color', st.ink);

% (f) calibration and checks
ax = nexttile(tl); axis(ax, 'off');
text(ax, 0, 1, info_text(r), 'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'FontName', 'Consolas', 'FontSize', 8.5, 'Color', st.ink, 'Interpreter', 'none');

if nargin > 1 && ~isempty(file)
    exportgraphics(fig, file, 'Resolution', 130);
    close(fig);
end
end

% ------------------------------------------------------------------------
function prep(ax, st, ret)
hold(ax, 'on'); box(ax, 'off'); grid(ax, 'on');
ax.GridColor = st.grid; ax.GridAlpha = 1;
ax.XColor = st.muted; ax.YColor = st.muted; ax.FontSize = st.font;
ax.XLim = [25 100];
xline(ax, ret, 'Color', st.grid, 'LineWidth', 1, 'HandleVisibility', 'off');
xlabel(ax, 'age');
end

function band(ax, x, lo, hi, col, st)
fill(ax, [x, fliplr(x)], [lo, fliplr(hi)], col, 'FaceAlpha', st.band_alpha, ...
    'EdgeColor', 'none', 'HandleVisibility', 'off');
end

function t = title_text(r)
t = r.tenure;
if isfield(r, 'step')
    t = sprintf('Step %d, %s: %s', r.step.index, r.step.label, r.tenure);
end
end

function t = info_text(r)
p = r.p; c = r.checks; s = r.summary;
kap = config.kappa_path(p);
L = {};
L{end+1} = sprintf('gamma %.3g   beta %.3g   retire at %d', p.gamma, p.beta, p.retirement_age);
L{end+1} = sprintf('income %s   replacement %.3f   sigma_l %.4f', p.income_source, p.replacement, p.sigma_l_log);
L{end+1} = sprintf('r %.4f   premium %.3f   equity vol %.3f', p.r, p.mu_S_level, p.sigma_S_level);
if p.h_mult > 0
    L{end+1} = sprintf('h_mult %.2f   rent %.3f   maint %.3f   mortgage %.4f/%dy', ...
        p.h_mult, p.alpha, p.theta, p.r_m, p.N_mort);
else
    L{end+1} = 'no housing';
end
if p.kappa_base > 0
    L{end+1} = sprintf('DC: kappa %.1f%%-%.1f%%   glide %.2f   REIT %.2f', ...
        100 * min(kap(1:p.t_ret-1)), 100 * max(kap(1:p.t_ret-1)), p.glide_cap, max(config.reit_effective(p)));
else
    L{end+1} = 'no DC pillar';
end
L{end+1} = sprintf('tax: income %.3f   box-3 %.2f/%.2f   loss offset %d', ...
    p.tau_inc, p.tau_cg_bond, p.tau_cg_stock, p.cg_loss_offset);
L{end+1} = sprintf('floor %.3g x Y   search bound %.3g x W   entry buffer %.3f', ...
    p.phi_floor, p.c_floor_frac, p.b0);
L{end+1} = sprintf('grid %d x %d x %d   gh_n %d   %d households', ...
    p.N_u1, p.N_u2, p.N_u3, p.gh_n, s.N);
L{end+1} = '';
L{end+1} = sprintf('after-tax premium %.2f%%   liquid Merton %.2f', ...
    100 * c.premium_after_tax, c.merton_liquid);
L{end+1} = sprintf('entry value = constant %.3g x entry income', c.ce_entry);
L{end+1} = sprintf('floored %.1f%% of years; at search bound, 25-39: %.0f%%', ...
    100 * c.floored_share, 100 * c.c_bound_25_39);
L{end+1} = sprintf('off-grid lookups %d; u1 thin at %.0f%% of ages 40+', sum(c.offgrid), 100 * c.thin_u1_40);
L{end+1} = sprintf('solve %.0f s', r.timing.solve_sec);
for i = 1:numel(c.notes)
    L{end+1} = ''; %#ok<AGROW>
    L = [L, wrap(['Note: ' c.notes{i}], 70)]; %#ok<AGROW>
end
t = strjoin(L, newline);
end

function lines = wrap(s, n)
words = strsplit(s, ' '); lines = {}; cur = '';
for i = 1:numel(words)
    if numel(cur) + numel(words{i}) + 1 > n
        lines{end+1} = cur; cur = words{i}; %#ok<AGROW>
    elseif isempty(cur)
        cur = words{i};
    else
        cur = [cur ' ' words{i}]; %#ok<AGROW>
    end
end
if ~isempty(cur), lines{end+1} = cur; end
end
