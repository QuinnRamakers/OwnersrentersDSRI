function ruin_figures(phi)
%RUIN_FIGURES  Step 7 owner: how the floor, ruin and the grid interact.
%   ruin_figures()     step 7 as run (floor 1e-6), constant house prices as the contrast
%   ruin_figures(phi)  step 7 at floor phi (0.1, 0.2, 0.3 or 0.5), step 7 as run as the contrast
%   Five figures, each comparing the standard grid with the income axis doubled:
%   ruin_1_why (bankruptcy rate by age), ruin_2_cliff, ruin_3_landscape,
%   ruin_4_cut and ruin_5_choice. Figures 2-4 share one linear range, house
%   value across and savings up, and mark the most exposed household (least
%   cash after the housing bill). Needs step 7 and its robustness solves and
%   the solve_cases results. "Well-being" is the certainty-equivalent
%   consumption stream in years of current income; the labels describe it in words.
pth = step07_paths();
cd(pth.repo);
out = pth.out;
S  = load(fullfile(pth.res, '07_housing_owner.mat'));
D  = load(fullfile(pth.res, 'robustness', '07_housing_owner_dense_u1.mat'));
if nargin < 1 || isempty(phi)
    FL = load(fullfile(pth.data, 'owner_flat_prices.mat'));
    R  = {S, D, FL.std, FL.dense};
    nm = {'coarse grid', 'fine grid', 'constant house prices, coarse grid', 'constant house prices, fine grid'};
    tag = ''; main = 'as run'; alt = 'constant house prices'; notes_on = true;
    zw = 'bankrupt'; zone_txt = 'Red: bankrupt (housing costs exceed income)';
else
    F = load(fullfile(pth.data, sprintf('owner_floor_%03d.mat', round(100 * phi))));
    R  = {F.std, F.dense, S, D};
    nm = {sprintf('coarse grid, floor %g', phi), sprintf('fine grid, floor %g', phi), ...
          'coarse grid, floor 10^{-6} (before)', 'fine grid, floor 10^{-6} (before)'};
    tag = sprintf('_floor%03d', round(100 * phi)); main = sprintf('floor %g', phi); alt = 'floor 10^{-6} (before)';
    notes_on = false; zw = 'on the floor';
    zone_txt = 'Red: on the floor this year (housing costs leave less than the floor)';
end
cS = [0 0 0]; cD = [0.85 0.33 0.10]; cF = [0.20 0.45 0.75];
col = {cS, cD, cF, cD}; sty = {'-', '-', '-', '--'};
YLO = 1e-7; YHI = 1e2;                                  % value axis in the cut figures
WB = 'well-being (log scale)';
HY = 'house value (years of household income)';
XY = 'savings (years of household income)';
P = cell(1, 4);
for i = 1:4, P{i} = panel(R{i}); end
ages = P{1}.ages; g = S.p.gamma;
clo = floor(log10(R{1}.p.phi_floor));                 % bottom of the colour scale in figure 3
show_ages = [27 45 85];
% The most exposed simulated household per solve and age: the one with the
% least cash left after the housing bill.
EH = zeros(4, numel(show_ages)); EX = EH;
for a = 1:numel(show_ages)
    t = find(ages == show_ages(a));
    for i = 1:4, [EH(i, a), EX(i, a)] = most_exposed(P{i}, R{i}.p, t); end
end
% One linear range for every panel of figures 2, 3 and 4: house value relative
% to income across, savings relative to income up. It covers the most exposed
% households and the point where each slice of figure 4 turns bankrupt.
hmx = max(EH(:)); xmx = 1;
for a = 1:numel(show_ages)
    t = find(ages == show_ages(a));
    for i = 1:4, xmx = max(xmx, 1.2 * prctile(P{i}.x(:, t), 95)); end
    for i = [1 3], hmx = max(hmx, (median(P{i}.x(:, t)) + 1 - R{i}.p.phi_floor) / cost_rate(R{i}.p, t)); end
end
HR = nice(1.03 * hmx); XR = nice(xmx);
cW = [1.00 0.85 0.10];                                  % marker fill for the most exposed household

%% 1. How often households go bankrupt
fig = figure('Visible', 'off', 'Position', [30 30 1300 650], 'Color', 'w');
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 11;
for i = 1:2
    plot(ax, ages, 100 * mean(P{i}.sim.floored, 1), '-', 'Color', col{i}, 'LineWidth', 2.5);
end
xlim(ax, [25 100]); xline(ax, 67, 'k--', 'retirement', 'LabelVerticalAlignment', 'middle', 'HandleVisibility', 'off');
xlabel(ax, 'Age'); ylabel(ax, sprintf('%% of simulated households %s that year', zw));
legend(ax, nm(1:2), 'Location', 'northwest');
if R{1}.p.phi_floor < 1e-3, fl = sprintf('10^{%d}', round(log10(R{1}.p.phi_floor))); else, fl = sprintf('%g', R{1}.p.phi_floor); end
title(ax, {sprintf('1. How often households are %s, by age (%s)', zw, main), ...
    sprintf('%s: savings plus income do not cover the housing bill, so the household consumes the floor (%s years of household income)', ...
    [upper(zw(1)) zw(2:end)], fl), ...
    sprintf('With %s: at most %.1f%% in any year', alt, 100 * max(mean(P{3}.sim.floored, 1)))}, 'FontSize', 12);
save_fig(fig, fullfile(out, ['ruin_1_why' tag '.png']));

%% 2. The cliff along the no-savings line, grid point by grid point
fig = figure('Visible', 'off', 'Position', [30 30 2100 720], 'Color', 'w');
tl = tiledlayout(fig, 1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'2. What the computer sees: well-being of an owner without savings, as the house gets bigger relative to income', ...
    ['Dots: where the computer calculates. Lines: the straight lines it draws in between. ' ...
     zone_txt '. Grey bars: where households are. Dashed: the most exposed household (least cash after the housing bill)']}, ...
    'FontSize', 12, 'FontWeight', 'bold');
cl_cases = {1, 45, main; 1, 85, main; 3, 85, alt};
short = {'coarse', 'fine', 'coarse', 'fine'};
note = {{'The fine grid finds well-being', 'collapsing well before bankruptcy:', ...
         'from there a run of bad years can', 'still push the household over.', ...
         'The coarse grid draws one straight', 'line across the whole fall.'}, ...
        {'Households here are bankrupt', 'this year, so their well-being', ...
         'should be near zero. But the next', 'calculation point is far away, so', 'the computer rates them as fine.'}, ...
        {'Same blind spot, but with', 'constant house prices no household', 'gets near it.'}};
for k = 1:3
    i0 = cl_cases{k, 1}; t = find(ages == cl_cases{k, 2}); a = find(show_ages == cl_cases{k, 2});
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    hb = (1 - R{i0}.p.phi_floor) / cost_rate(R{i0}.p, t);
    patch(ax, [hb HR HR hb], [YLO YLO YHI YHI], [0.9 0.3 0.3], 'FaceAlpha', 0.12, 'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
    hist_strip(ax, linspace(0, HR, 81), P{i0}.h(:, t), YLO, 2);
    hh = linspace(0, HR, 4000);
    lines = gobjects(1, 2); txt = {}; nxt = 0;
    for j = 0:1
        r = R{i0 + j}; cc = col{i0 + j};
        F = z_interp(r, t); Dh = horizon(r, t)^(1 / (g - 1));
        u1 = 1 ./ (1 + hh);
        ce = F(u1, ones(size(u1)), zeros(size(u1))) ./ u1 * Dh;
        lines(j + 1) = plot(ax, hh, ce, sty{i0 + j}, 'Color', cc, 'LineWidth', 1.8);
        u1n = r.p.u1_grid(:); hn = 1 ./ u1n - 1;
        zn = z_nodes(r, t); zn = zn(:, end, 1);          % u2 = 1 (no liquid savings), u3 = 0
        cen = zn ./ u1n * Dh;
        plot(ax, hn, cen, 'o', 'Color', cc, 'MarkerFaceColor', cc, 'MarkerSize', 5, 'HandleVisibility', 'off');
        plot(ax, EH(i0 + j, a) * [1 1], [YLO YHI], '--', 'Color', cc, 'LineWidth', 1.4, 'HandleVisibility', 'off');
        txt{end+1} = sprintf('%s grid: last point outside the red zone at %.0f years of household income, next at %.0f', ...
            short{i0 + j}, max(hn(hn < hb)), min(hn(hn >= hb))); %#ok<AGROW>
        txt{end+1} = sprintf('   most exposed household: house %.0f years of household income, savings %.1f', EH(i0 + j, a), EX(i0 + j, a)); %#ok<AGROW>
        if ~any(hn > hb & hn <= HR), nxt = max(nxt, min(hn(hn > HR))); end
    end
    set(ax, 'YScale', 'log'); xlim(ax, [0 HR]); ylim(ax, [YLO YHI]);
    xlabel(ax, HY); ylabel(ax, WB);
    legend(ax, lines, nm(i0 + [0 1]), 'Location', 'northeast', 'FontSize', 9);
    title(ax, sprintf('(%s)  %s, age %d: %s above %.0f years of household income', char('a' + k - 1), cl_cases{k, 3}, cl_cases{k, 2}, zw, hb));
    text(ax, 0.08, 0.87, txt, 'Units', 'normalized', 'FontSize', 9, 'VerticalAlignment', 'top');
    if nxt > 0
        text(ax, 0.99, 0.55, sprintf('next grid point at %.0f years of household income, off the chart \\rightarrow', nxt), 'Units', 'normalized', ...
            'HorizontalAlignment', 'right', 'FontSize', 9, 'Color', [0.55 0.1 0.1]);
    end
    if notes_on, text(ax, 0.30, 0.45, note{k}, 'Units', 'normalized', 'FontSize', 9.5, 'VerticalAlignment', 'top', ...
            'Color', [0.55 0.1 0.1]); end
end
save_fig(fig, fullfile(out, ['ruin_2_cliff' tag '.png']));

%% 3. The value landscape over house value and savings
fig = figure('Visible', 'off', 'Position', [30 30 1900 1800], 'Color', 'w');
tl = tiledlayout(fig, 3, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
Dage = arrayfun(@(age) horizon(R{1}, find(ages == age)), show_ages);
title(tl, {'3. Well-being in every situation: house value (across) and savings (up), both in years of household income', ...
    ['Colour: well-being, the constant yearly consumption (in years of household income) worth as much as the situation. In brackets the value ' ...
     'function V = -D x well-being^{-4}, in units where a year of consuming one''s income is -1,'], ...
    [sprintf('with D the remaining discounted, survival-weighted years (%.1f at 27, %.1f at 45, %.1f at 85). ', Dage) ...
     'Black dots: grid points. Pink dots: households. Star: the most exposed household. Right of the red line: ' zw]}, ...
    'FontSize', 12, 'FontWeight', 'bold');
[Hg, Xg] = meshgrid(linspace(0, HR, 400), linspace(0, XR, 300));
for k = 1:numel(show_ages)
    t = find(ages == show_ages(k)); kr = cost_rate(R{1}.p, t);
    hb = linspace((1 - R{1}.p.phi_floor) / kr, HR, 100); xb = kr * hb - 1 + R{1}.p.phi_floor;   % the bankruptcy line
    for i = 1:2
        ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on');
        pcolor(ax, Hg, Xg, log10(ce_at(R{i}, t, Xg, Hg))); shading(ax, 'flat');
        colormap(ax, blue_map()); clim(ax, [clo, 1]);
        cb = colorbar(ax); cb.Ticks = clo:1;
        cb.TickLabels = arrayfun(@(e) v_label(e, Dage(k), g), clo:1, 'UniformOutput', false);
        cb.Label.String = 'well-being   [value function V]';
        [xn, hn] = nodes_xh(R{i}.p);
        in = xn <= XR & hn <= HR;
        plot(ax, hn(in), xn(in), 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w', 'LineWidth', 0.4);
        scatter(ax, P{i}.h(1:5:end, t), P{i}.x(1:5:end, t), 4, [0.90 0.20 0.65], 'filled', 'MarkerFaceAlpha', 0.45);
        m = xb <= XR;
        plot(ax, hb(m), xb(m), 'r-', 'LineWidth', 2);
        plot(ax, EH(i, k), EX(i, k), 'p', 'MarkerSize', 16, 'MarkerFaceColor', cW, 'MarkerEdgeColor', 'k', 'LineWidth', 1);
        set(ax, 'Layer', 'top'); xlim(ax, [0 HR]); ylim(ax, [0 XR]);
        xlabel(ax, HY); ylabel(ax, XY);
        title(ax, sprintf('(%s)  age %d, %s', char('a' + 2 * (k - 1) + i - 1), show_ages(k), nm{i}));
        if show_ages(k) == 85 && notes_on
            text(ax, 0.97, 0.95, {'Households right of the red line are bankrupt this year,', ...
                'yet they look comfortable: no grid point lies there'}, 'Units', 'normalized', ...
                'FontSize', 9.5, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'Color', [0.55 0.1 0.1], 'BackgroundColor', 'w', 'Margin', 2);
        end
    end
end
save_fig(fig, fullfile(out, ['ruin_3_landscape' tag '.png']));

%% 4. Cuts through the occupied region, with the grid each cut passes through
fig = figure('Visible', 'off', 'Position', [30 30 2100 1900], 'Color', 'w');
tl = tiledlayout(fig, 6, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'4. A slice through figure 3 at the typical household''s savings: well-being as the house gets bigger, and the grid the slice runs through', ...
    ['Rows 1 and 3: ' main ' and ' alt '. Dots on the lines: where the slice crosses a grid line; ' ...
     'between dots the computer interpolates. Grey bars: households. Red: ' zw '. Dashed: the most exposed household'], ...
    ['Rows 2 and 4: the same slice (purple) on the grid, house value across and savings up as in figure 3. The grid is regular in the solver''s own variables ' ...
     '(income as a share of wealth, house as a share of savings plus house),'], ...
    ['so per unit of income its lines are straight: diagonals (same total wealth) and rays from the origin (same house share). ' ...
     'Large dots: the grid points whose values the slice is interpolated from']}, ...
    'FontSize', 12, 'FontWeight', 'bold');
for row = 1:2
    for k = 1:3
        t = find(ages == show_ages(k));
        if row == 1, ii = [1 2]; lab = main; else, ii = [3 4]; lab = alt; end
        base = R{ii(1)};
        x0 = median(P{ii(1)}.x(:, t));
        hs = [P{ii(1)}.h(:, t); P{ii(2)}.h(:, t)];
        hb = (x0 + 1 - base.p.phi_floor) / cost_rate(base.p, t);
        hh = linspace(0, HR, 4000);
        ax = nexttile(tl, 9 * (row - 1) + k, [2 1]); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        patch(ax, [hb HR HR hb], [YLO YLO YHI YHI], [0.9 0.3 0.3], 'FaceAlpha', 0.12, 'EdgeColor', 'none', ...
            'HandleVisibility', 'off');
        hist_strip(ax, linspace(0, HR, 81), hs, YLO, 2);
        lines = gobjects(1, 2);
        for j = 1:2
            ce = ce_at(R{ii(j)}, t, x0 * ones(size(hh)), hh);
            lines(j) = plot(ax, hh, ce, sty{ii(j)}, 'Color', col{ii(j)}, 'LineWidth', 2);
            [hx1, hx2] = crossings(R{ii(j)}.p, x0, 0, HR);
            hc = sort([hx1, hx2]);
            plot(ax, hc, ce_at(R{ii(j)}, t, x0 * ones(size(hc)), hc), 'o', 'Color', col{ii(j)}, ...
                'MarkerFaceColor', col{ii(j)}, 'MarkerSize', 4, 'HandleVisibility', 'off');
            plot(ax, EH(ii(j), k) * [1 1], [YLO YHI], '--', 'Color', col{ii(j)}, 'LineWidth', 1.4, 'HandleVisibility', 'off');
        end
        set(ax, 'YScale', 'log'); ylim(ax, [YLO YHI]); xlim(ax, [0 HR]);
        xlabel(ax, HY); ylabel(ax, WB);
        title(ax, sprintf('(%s)  %s, age %d, savings %.1f years of household income', char('a' + 6 * (row - 1) + k - 1), lab, show_ages(k), x0));
        legend(ax, lines, nm(ii), 'Location', 'southwest', 'FontSize', 9);
        if row == 1 && k == 3 && notes_on
            text(ax, 0.35, 0.45, {'Households in the red zone are bankrupt this year,', ...
                'so their well-being should be near zero. The computer', ...
                'has no calculation point there, so it carries over', ...
                'the value from the safe side.'}, 'Units', 'normalized', 'FontSize', 9.5, ...
                'Color', [0.55 0.1 0.1]);
        end
        ax = nexttile(tl, 9 * (row - 1) + 6 + k); hold(ax, 'on'); box(ax, 'on');
        grid_slice(ax, R(ii), col(ii), P{ii(1)}, t, x0, HR, XR, k == 1, EH(ii, k), EX(ii, k), cW);
        xlabel(ax, HY); ylabel(ax, XY);
        title(ax, sprintf('(%s)  the slice on the grid, age %d', char('a' + 6 * (row - 1) + 3 + k - 1), show_ages(k)));
    end
end
save_fig(fig, fullfile(out, ['ruin_4_cut' tag '.png']));

%% 5. The young owner's choice
t = find(ages == 27);
x0 = median(P{1}.x(:, t)); h0 = median(P{1}.h(:, t));
fig = figure('Visible', 'off', 'Position', [30 30 2100 1150], 'Color', 'w');
tl = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf(['5. The young owner''s decisions (%s): the same 27-year-old (house %.1fx income, savings ' ...
    '%.2fx income), the same model, two grids'], main, h0, x0), ...
    'What they invest and spend, how good each choice looks, and how much the worst outcomes weigh'}, ...
    'FontSize', 13, 'FontWeight', 'bold');
xx = linspace(0, max(prctile(P{1}.x(:, t), 99) * 1.3, 1), 400);
ax1 = nexttile(tl); hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');
ax2 = nexttile(tl); hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');
for i = 1:2
    [pi_x, c_x] = policy_at(R{i}, t, xx, h0 * ones(size(xx)));
    LWY = xx + 1 - cost_rate(R{i}.p, t) * h0;
    plot(ax1, xx, pi_x, '-', 'Color', col{i}, 'LineWidth', 2);
    plot(ax2, xx, c_x .* LWY, '-', 'Color', col{i}, 'LineWidth', 2);
end
for ax = [ax1 ax2]
    xline(ax, x0, ':', 'typical household', 'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
    xlabel(ax, XY);
end
ylabel(ax1, 'share of savings in stocks'); ylim(ax1, [0 1.02]);
legend(ax1, nm(1:2), 'Location', 'east');
title(ax1, '(a)  How much goes into stocks');
ylabel(ax2, 'spending relative to income'); title(ax2, '(b)  How much they spend');
legend(ax2, nm(1:2), 'Location', 'northwest');

ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
pis = linspace(0, 1, 81);
best = zeros(2, 2);
for i = 1:2
    [ob, cbest] = objective_pi(R{i}, t, x0, h0, pis);
    ce = ((1 - g) * ob).^(1 / (1 - g));
    plot(ax, pis, 100 * (ce / max(ce) - 1), '-', 'Color', col{i}, 'LineWidth', 2);
    [~, j] = max(ce); best(i, :) = [pis(j), cbest(j)];
    plot(ax, pis(j), 0, 'o', 'Color', col{i}, 'MarkerSize', 9, 'LineWidth', 2, 'HandleVisibility', 'off');
    pi_s = policy_at(R{i}, t, x0, h0);
    plot(ax, pi_s, interp1(pis, 100 * (ce / max(ce) - 1), pi_s), 'x', 'Color', col{i}, 'MarkerSize', 13, ...
        'LineWidth', 2.5, 'HandleVisibility', 'off');
end
xlabel(ax, 'share of savings in stocks (spending re-chosen each time)');
ylabel(ax, 'loss compared with the best choice (%)');
legend(ax, nm(1:2), 'Location', 'southwest'); xlim(ax, [-0.02 1.02]); ylim(ax, [-12 0.5]);
title(ax, {'(c)  How good each stock share looks', 'circle: best choice; cross: what the solver picked'});

ax4 = nexttile(tl); hold(ax4, 'on'); grid(ax4, 'on'); box(ax4, 'on');
ax5 = nexttile(tl); hold(ax5, 'on'); grid(ax5, 'on'); box(ax5, 'on');
plot(ax5, [0 1], [0 1], ':', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
L6 = {sprintf('Typical owner at 27: house %.1fx income, savings %.2fx income', h0, x0), ''};
for i = 1:2
    [ceN, w, ~, Vn] = next_ce(R{i}, t, x0, h0, best(i, 1), best(i, 2));
    [srt, o] = sort(ceN);
    plot(ax4, cumsum(w(o)), srt, '-', 'Color', col{i}, 'LineWidth', 2);
    dis = -w .* Vn; [~, o2] = sort(Vn);                % worst (most negative) first
    cp = cumsum(w(o2)); cs = cumsum(dis(o2)) / sum(dis);
    plot(ax5, [0; cp], [0; cs], '-', 'Color', col{i}, 'LineWidth', 2);
    s5 = interp1([0; cp], [0; cs], 0.05); s20 = interp1([0; cp], [0; cs], 0.20);
    [pi_s, c_s] = policy_at(R{i}, t, x0, h0);
    L6 = [L6, {[upper(nm{i}(1)) nm{i}(2:end)], ...
        sprintf('  puts %.0f%% of savings in stocks, spends %.0f%% of the money available', 100 * pi_s, 100 * c_s), ...
        sprintf('  worst possible next year: well-being %.3f (best %.2f)', min(ceN), max(ceN)), ...
        sprintf('  the worst 5%% of outcomes carry %.0f%% of the weight in the decision,', 100 * s5), ...
        sprintf('  the worst 20%% carry %.0f%%', 100 * s20), ...
        sprintf('  well-being at the start of life: %.3f', R{i}.checks.ce_entry), ''}]; %#ok<AGROW>
end
set(ax4, 'YScale', 'log');
xlabel(ax4, 'share of possible outcomes next year, worst first');
ylabel(ax4, 'next year''s well-being (log scale)');
legend(ax4, nm(1:2), 'Location', 'southeast');
title(ax4, '(d)  How good next year could turn out');
xlabel(ax5, 'share of possible outcomes next year, worst first');
ylabel(ax5, 'share of the weight in the decision');
legend(ax5, nm(1:2), 'Location', 'southeast');
title(ax5, {'(e)  How much the worst outcomes weigh', '(diagonal: every outcome weighs the same)'});
ax = nexttile(tl); axis(ax, 'off');
text(ax, 0, 1, L6, 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 10.5, 'Interpreter', 'none');
title(ax, '(f)  In numbers');
save_fig(fig, fullfile(out, ['ruin_5_choice' tag '.png']));
cellfun(@(s) fprintf('%s\n', s), L6);
end

% ------------------------------------------------------------------------
function P = panel(r)
sim = simulate.forward(r.p, r.profile, r.sol, r.ann_price, r.timing.N_sim, r.timing.seed, r.p.b0);
P.sim = sim; P.ages = sim.ages(:).';
P.x = sim.X ./ sim.Y; P.h = sim.H ./ sim.Y;
P.xmed = median(P.x, 1); P.hmed = median(P.h, 1);
end

function k = cost_rate(p, t)
m = 0; if t <= numel(p.m_rate_path), m = p.m_rate_path(t); end
k = p.theta + m;
end

function ce = ce_at(r, t, x, h)
% CE consumption stream (years of current income) at liquid savings x and
% house h relative to income, for an owner without a DC pot.
p = r.p; g = p.gamma;
F = z_interp(r, t);
u1 = 1 ./ (1 + x + h); u2 = h ./ max(x + h, 1e-12);
zq = F(u1, u2, zeros(size(u1)));
ce = zq ./ u1 * horizon(r, t)^(1 / (g - 1));
end

function z = z_nodes(r, t)
g = r.p.gamma;
arg = (1 - g) * r.sol.V(:, :, :, t); arg(arg <= 0 | ~isfinite(arg)) = NaN;
z = arg .^ (1 / (1 - g));
z(isnan(z)) = min(z(:), [], 'omitnan');            % as the solver does
end

function F = z_interp(r, t)
p = r.p;
F = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, z_nodes(r, t), 'linear', 'nearest');
end

function D = horizon(r, t)
ps = r.profile.p_surv(:); T = r.p.T; b = r.p.beta;
D = 0; s = 1;
for k = t:T
    D = D + b^(k - t) * s;
    if k < T, s = s * ps(k); end
end
end

function [pi_x, c_x] = policy_at(r, t, x, h)
p = r.p;
u1 = 1 ./ (1 + x + h); u2 = h ./ max(x + h, 1e-12); u3 = zeros(size(u1));
Fp = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, r.sol.pi_pol(:, :, :, t), 'linear', 'nearest');
Fc = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, r.sol.c_pol(:, :, :, t), 'linear', 'nearest');
pi_x = min(max(Fp(u1, u2, u3), 0), 1); c_x = min(max(Fc(u1, u2, u3), 0), 1);
end

function [ob, cbest] = objective_pi(r, t, x, h, pis)
% Bellman objective at (x, h), written as solver.bellman_step_lna does, with
% consumption re-optimised for each equity share. Owner, no DC, no taxes.
ob = zeros(size(pis)); cbest = ob;
lw = state_w(r, t, x, h);
cfl = min(max(1e-3, r.p.c_floor_frac / lw), 0.5);
for k = 1:numel(pis)
    f = @(c) -objective(r, t, x, h, c, pis(k));
    cg = linspace(cfl, 1 - 1e-6, 120);
    v = arrayfun(@(c) -f(c), cg); [~, j] = max(v);
    lo = cg(max(j - 1, 1)); hi = cg(min(j + 1, numel(cg)));
    [cb, fv] = fminbnd(f, lo, hi, optimset('TolX', 1e-10));
    if -fv < v(j), cb = cg(j); fv = -v(j); end
    ob(k) = -fv; cbest(k) = cb;
end
end

function [lw, s] = state_w(r, t, x, h)
p = r.p;
W = 1 + x + h;                                   % in units of income
s.lam = 1 / W; s.sX = x / W; s.sH = h / W;
lw = s.sX + s.lam - cost_rate(p, t) * s.sH;      % no tax, no DC at this step
end

function v = objective(r, t, x, h, c, pv)
[~, ~, v] = next_ce(r, t, x, h, pv, c);
end

function [ceN, w, val, Vn] = next_ce(r, t, x, h, pv, c)
% Next year's state at every shock node, its CE (years of next year's income),
% its value, and the Bellman objective.
p = r.p; g = p.gamma;
persistent cache
fp = [t; r.p.u1_grid(:); r.sol.V(end, end, end, t + 1)];
if isempty(cache) || ~isequal(cache.fp, fp)
    cache = struct('fp', fp, 'sk', grids.shock_grid(p), 'F', z_interp(r, t + 1), 'D', horizon(r, t + 1));
end
sk = cache.sk;
[lw, s] = state_w(r, t, x, h);
G  = exp(r.profile.mu_growth(t) + r.profile.sigma_l_log(t) .* sk.joint.eps_Y_unit(:));
RS = config.after_tax_stock(p, sk.joint.R_S(:));
Rf = (1 + p.r * (1 - p.tau_cg_bond)) * (1 - p.tau_wealth);
RX = (1 - pv) * Rf + pv * RS;
Xn = RX * (1 - c) * lw; Hn = s.sH * sk.joint.R_H(:); Yn = G * s.lam;
Wn = Xn + Hn + Yn;
u1 = Yn ./ Wn; u2 = Hn ./ max(Xn + Hn, 1e-12);
zn = cache.F(min(max(u1, 0), 1), min(max(u2, 0), 1), zeros(size(u1)));
Vn = (Wn .* zn).^(1 - g) / (1 - g);
w = sk.joint.w(:);
val = (c * lw)^(1 - g) / (1 - g) + p.beta * r.profile.p_surv(t) * sum(w .* Vn);
ceN = zn ./ u1 * cache.D^(1 / (g - 1));
end

function [xn, hn] = nodes_xh(p)
[U1, U2] = ndgrid(p.u1_grid, p.u2_grid);
xn = (1 - U1) .* (1 - U2) ./ U1; hn = (1 - U1) .* U2 ./ U1;
xn = xn(:); hn = hn(:);
end

function [h1, h2] = crossings(p, x0, hlo, hmax)
% Values of h along the cut x = x0 where u1 or u2 equals a grid node.
h1 = 1 ./ p.u1_grid(:) - 1 - x0; h1 = h1(h1 > hlo & h1 < hmax).';
u2 = p.u2_grid(p.u2_grid < 1); u2 = u2(:);
h2 = u2 .* x0 ./ (1 - u2); h2 = h2(h2 > hlo & h2 < hmax).';
end

function grid_slice(ax, Rp, cols, Pb, t, x0, hmax, xtop, with_legend, eh, ex, cW)
% The slice x = x0 on both grids, house value per unit of income across and
% savings per unit of income up, both linear. A grid line of constant u1 is
% the diagonal x + h = 1/u1 - 1; a line of constant u2 is the ray x = h (1 - u2) / u2.
% Stars: each solve's most exposed household (eh, ex).
cP = [0.45 0.15 0.60];
p1 = Rp{1}.p; k = cost_rate(p1, t);
hz = linspace(0, hmax, 400);
xz = min(max(k * hz - 1 + p1.phi_floor, 0), xtop);           % bankrupt below this line
patch(ax, [hz, fliplr(hz)], [zeros(size(hz)), fliplr(xz)], [0.9 0.3 0.3], 'FaceAlpha', 0.12, ...
    'EdgeColor', 'none', 'HandleVisibility', 'off');
hd = scatter(ax, Pb.h(1:4:end, t), Pb.x(1:4:end, t), 3, [0.6 0.6 0.6], 'filled', 'MarkerFaceAlpha', 0.25);
hl = linspace(0, hmax, 4000);
hu = gobjects(1, 2); far = 0;
for j = 2:-1:1                                                % fine grid first, coarse on top
    p = Rp{j}.p; c = cols{j}; cl = 0.45 * c + 0.55;
    u1 = p.u1_grid(:); u2 = p.u2_grid(:);
    for a = 1:numel(u1)
        plot(ax, hl, 1 / u1(a) - 1 - hl, '-', 'Color', cl, 'LineWidth', 0.6, 'HandleVisibility', 'off');
    end
    for b = find(u2 > 0).'
        plot(ax, hl, hl * (1 - u2(b)) / u2(b), '-', 'Color', cl, 'LineWidth', 0.6, 'HandleVisibility', 'off');
    end
    [U1, U2] = ndgrid(u1, u2);
    xn = (1 - U1) .* (1 - U2) ./ U1; hn = (1 - U1) .* U2 ./ U1;
    plot(ax, hn(:), xn(:), '.', 'Color', c, 'MarkerSize', 7, 'HandleVisibility', 'off');
    used = slice_nodes(p, x0, hl);
    hu(j) = plot(ax, hn(used), xn(used), 'o', 'Color', c, 'MarkerFaceColor', c, 'MarkerSize', 6);
    far = max(far, max(hn(used)));
end
hs = plot(ax, [0 hmax], [x0 x0], '-', 'Color', cP, 'LineWidth', 2.5);
hw = gobjects(1, 2);
for j = 1:2
    hw(j) = plot(ax, eh(j), ex(j), 'p', 'MarkerSize', 15, 'MarkerFaceColor', cW, 'MarkerEdgeColor', cols{j}, 'LineWidth', 1.8);
end
set(ax, 'Layer', 'top'); xlim(ax, [0 hmax]); ylim(ax, [-0.02 * xtop, xtop]);
if far > hmax
    text(ax, 0.99, 0.93, sprintf('the slice also draws on grid points off the chart, out to %.0f years of household income \\rightarrow', far), ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 9, ...
        'Color', [0.55 0.1 0.1], 'BackgroundColor', 'w', 'Margin', 1);
end
if with_legend
    legend(ax, [hu, hs, hd, hw(1)], {'coarse grid points used', 'fine grid points used', 'the slice', 'households', ...
        'most exposed household'}, 'Location', 'northwest', 'FontSize', 8);
end
end

function [h, x] = most_exposed(Pi, p, t)
% The simulated household with the least cash left after the housing bill.
cash = Pi.x(:, t) + 1 - cost_rate(p, t) * Pi.h(:, t);
[~, j] = min(cash);
h = Pi.h(j, t); x = Pi.x(j, t);
end

function s = v_label(e, D, g)
% Colour-bar tick: well-being 10^e and the value function in units where a
% year of consuming one's income is -1.
if e == 0, c = '1'; elseif e == 1, c = '10'; else, c = sprintf('10^{%d}', e); end
v = D * 10^((1 - g) * e); ex = floor(log10(v));
if abs(ex) <= 2, vs = sprintf('%.3g', v); else, vs = sprintf('%.1f\\cdot10^{%d}', v / 10^ex, ex); end
s = sprintf('%s   [V = -%s]', c, vs);
end

function m = blue_map()
% dark navy (near the floor) to almost white (comfortable)
k = [0 0.35 0.7 1];
c = [0.03 0.10 0.28; 0.10 0.32 0.62; 0.45 0.68 0.88; 0.96 0.98 1.00];
m = interp1(k, c, linspace(0, 1, 256));
end

function used = slice_nodes(p, x0, hl)
% Grid points (u3 = 0 layer) that carry at least 1% of the weight somewhere along the slice.
u1g = p.u1_grid(:); u2g = p.u2_grid(:);
used = false(numel(u1g), numel(u2g));
[l1, w1] = bracket(u1g, 1 ./ (1 + x0 + hl));
[l2, w2] = bracket(u2g, hl ./ max(x0 + hl, 1e-12));
for s = 1:numel(hl)
    for a = 0:1
        for b = 0:1
            wt = (a * w1(s) + (1 - a) * (1 - w1(s))) * (b * w2(s) + (1 - b) * (1 - w2(s)));
            if wt >= 0.01, used(l1(s) + a, l2(s) + b) = true; end
        end
    end
end
end

function [lo, w] = bracket(g, v)
% Lower bracketing node and the weight on the upper one; flat beyond the ends.
v = min(max(v(:), g(1)), g(end));
lo = discretize(v, g);
w = (v - g(lo)) ./ (g(lo + 1) - g(lo));
end

function v = nice(v)
% Round up to a half step of the leading digit (17.8 -> 20, 268 -> 300).
s = 10^floor(log10(v));
v = ceil(v / s * 2) / 2 * s;
end

function hist_strip(ax, e, v, ylo, dec)
% Household histogram drawn as grey bars along the bottom of a log value axis,
% the tallest bar spanning dec decades.
hc = histcounts(v, e); hc = hc / max(max(hc), 1);
e = e(:).';
X = [e(1:end-1); e(2:end); e(2:end); e(1:end-1)];
Y = ylo * [ones(2, numel(hc)); repmat(10.^(dec * hc), 2, 1)];
patch(ax, X, Y, [0.72 0.72 0.72], 'EdgeColor', 'none', 'FaceAlpha', 0.8, 'HandleVisibility', 'off');
end

function save_fig(fig, file)
axs = findall(fig, 'Type', 'axes');
for i = 1:numel(axs)
    if ~isempty(axs(i).Toolbar), axs(i).Toolbar.Visible = 'off'; end
end
exportgraphics(fig, file, 'Resolution', 120);
dump_text(fig, [file(1:end-4) '.txt']);
close(fig);
fprintf('wrote %s\n', file);
end

function dump_text(fig, file)
% Every piece of text in a figure, panel by panel in reading order, for review.
fid = fopen(file, 'w'); cl = onCleanup(@() fclose(fid));
tl = findall(fig, 'Type', 'tiledlayout');
axs = findall(fig, 'Type', 'axes');
if ~isempty(tl)
    put(fid, 'figure title', tl(1).Title.String);
    [~, o] = sort(arrayfun(@(a) a.Layout.Tile, axs)); axs = axs(o);
end
for i = 1:numel(axs)
    ax = axs(i);
    fprintf(fid, '\n');
    put(fid, 'panel title', ax.Title.String);
    put(fid, 'x axis', ax.XLabel.String);
    put(fid, 'y axis', ax.YLabel.String);
    for tx = findobj(ax, 'Type', 'text').', put(fid, 'note', tx.String); end
    for ln = findobj(ax, 'Type', 'constantline').', put(fid, 'line label', ln.Label); end
    if ~isempty(ax.Legend), put(fid, 'legend', ax.Legend.String); end
    if ~isempty(ax.Colorbar)
        put(fid, 'colour bar', ax.Colorbar.Label.String);
        put(fid, 'colour bar ticks', ax.Colorbar.TickLabels);
    end
end
end

function put(fid, what, s)
if isempty(s), return; end
s = cellstr(s);
fprintf(fid, '%s: %s\n', what, strjoin(s(:).', ' / '));
end
