function ruin_figures(phi)
%RUIN_FIGURES  Step 7 owner: how the floor, ruin and the grid interact.
%   ruin_figures()     step 7 as run (floor 1e-6), constant house prices as the contrast
%   ruin_figures(phi)  step 7 at floor phi (0.1, 0.2, 0.3 or 0.5), step 7 as run as the contrast
%   Five figures, ruin_1_why to ruin_5_choice, each comparing the standard grid
%   with the income axis doubled. Needs step 7 and its robustness solves and
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
HY = 'house value relative to income (log scale)';
XY = 'savings relative to income';
P = cell(1, 4);
for i = 1:4, P{i} = panel(R{i}); end
ages = P{1}.ages; g = S.p.gamma;
clo = max(-4, floor(log10(R{1}.p.phi_floor)) - 1);   % bottom of the colour scale in figure 3

%% 1. Why bankruptcy dominates
fig = figure('Visible', 'off', 'Position', [30 30 2100 640], 'Color', 'w');
tl = tiledlayout(fig, 1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
if notes_on
    title(tl, {'1. Why bankruptcy dominates everything', ...
        'In the model, one year of bankruptcy hurts more than a whole lifetime of normal consumption'}, ...
        'FontSize', 13, 'FontWeight', 'bold');
else
    title(tl, {sprintf('1. A floor of %g x income: how much a year on the floor hurts, and how often households hit it', phi), ...
        sprintf('One year on the floor now hurts like %.0f normal years, instead of 10^{24}', phi^(1 - g))}, ...
        'FontSize', 13, 'FontWeight', 'bold');
end
ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
c = logspace(-7, 1, 400);
plot(ax, c, c.^(1 - g), 'k-', 'LineWidth', 2);
set(ax, 'XScale', 'log', 'YScale', 'log');
if notes_on
    pts = [1e-6 0.1 0.3 1];
    lab = {'  bankruptcy in the model: one year hurts like 10^{24} normal years', ...
           'a milder floor (10% of income): 10^4 normal years  ', 'a floor of 30% of income: 123 normal years  ', ...
           'a normal year  '};
    pc = [0.75 0.15 0.15; 0.85 0.45 0.15; 0.45 0.45 0.45; cF];
else
    pts = [1e-6 phi 1];
    lab = {'  old floor 10^{-6}: one year hurts like 10^{24} normal years', ...
           sprintf('floor %g: %.0f normal years  ', phi, phi^(1 - g)), 'a normal year  '};
    pc = [0.45 0.45 0.45; 0.75 0.15 0.15; cF];
end
for i = 1:numel(pts)
    plot(ax, pts(i), pts(i)^(1 - g), 'o', 'MarkerSize', 8, 'MarkerFaceColor', pc(i, :), 'MarkerEdgeColor', pc(i, :));
    ha = 'right'; if i == 1, ha = 'left'; end
    text(ax, pts(i), pts(i)^(1 - g), lab{i}, 'FontSize', 9.5, 'HorizontalAlignment', ha, 'Color', pc(i, :) * 0.85);
end
xlabel(ax, 'consumption this year, relative to income (log scale)');
ylabel(ax, 'how much it hurts, in normal years (log scale)');
title(ax, '(a)  The pain of very low consumption explodes');

ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
for i = 1:4
    ce = arrayfun(@(t) ce_at(R{i}, t, P{i}.xmed(t), P{i}.hmed(t)), 1:numel(ages) - 1);
    plot(ax, ages(1:end-1), ce, sty{i}, 'Color', col{i}, 'LineWidth', 2);
end
set(ax, 'YScale', 'log'); xlim(ax, [25 100]); xline(ax, 67, 'k--', 'HandleVisibility', 'off');
xlabel(ax, 'Age'); ylabel(ax, WB);
legend(ax, nm, 'Location', 'southwest', 'FontSize', 9);
title(ax, {'(b)  How well off the typical household is, by age', ...
    '(the jump at 67 only reflects income falling at retirement)'});

ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
for i = 1:4
    plot(ax, ages, 100 * mean(P{i}.sim.floored, 1), sty{i}, 'Color', col{i}, 'LineWidth', 2);
end
xlim(ax, [25 100]); xline(ax, 67, 'k--', 'HandleVisibility', 'off');
xlabel(ax, 'Age'); ylabel(ax, '% of households bankrupt that year');
legend(ax, nm, 'Location', 'northwest', 'FontSize', 9);
title(ax, '(c)  How often households go bankrupt');
save_fig(fig, fullfile(out, ['ruin_1_why' tag '.png']));

%% 2. The cliff along the no-savings line, grid point by grid point
fig = figure('Visible', 'off', 'Position', [30 30 2100 720], 'Color', 'w');
tl = tiledlayout(fig, 1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'2. What the computer sees: well-being of an owner without savings, as the house gets bigger relative to income', ...
    ['Dots: where the computer calculates. Lines: the straight lines it draws in between. ' ...
     zone_txt '. Grey bars: where households are']}, 'FontSize', 12, 'FontWeight', 'bold');
cl_cases = {1, 45, main; 1, 85, main; 3, 85, alt};
short = {'coarse', 'fine', 'coarse', 'fine'};
note = {{'The fine grid finds well-being', 'collapsing well before bankruptcy:', ...
         'from there a run of bad years can', 'still push the household over.', ...
         'The coarse grid draws one straight', 'line across the whole fall.'}, ...
        {'Households here are bankrupt', 'this year, so their well-being', ...
         'should be near zero. But the next', 'calculation point is far away, so', 'the computer rates them as fine.'}, ...
        {'Same blind spot, but with', 'constant house prices no household', 'gets near it.'}};
for k = 1:3
    i0 = cl_cases{k, 1}; t = find(ages == cl_cases{k, 2});
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    hb = (1 - R{i0}.p.phi_floor) / cost_rate(R{i0}.p, t);
    patch(ax, [hb 1e4 1e4 hb], [YLO YLO YHI YHI], [0.9 0.3 0.3], 'FaceAlpha', 0.12, 'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
    hist_strip(ax, logspace(log10(0.3), log10(6000), 61), P{i0}.h(:, t), YLO, 2);
    hh = logspace(log10(0.3), log10(6000), 1500);
    lines = gobjects(1, 2); txt = {};
    for j = 0:1
        r = R{i0 + j}; cc = cS * (j == 0) + cD * (j == 1);
        if i0 == 3 && j == 0, cc = cF; end
        F = z_interp(r, t); Dh = horizon(r, t)^(1 / (g - 1));
        u1 = 1 ./ (1 + hh);
        ce = F(u1, ones(size(u1)), zeros(size(u1))) ./ u1 * Dh;
        lines(j + 1) = plot(ax, hh, ce, '-', 'Color', cc, 'LineWidth', 1.8);
        u1n = r.p.u1_grid(:); hn = 1 ./ u1n - 1;
        zn = z_nodes(r, t); zn = zn(:, end, 1);          % u2 = 1 (no liquid savings), u3 = 0
        cen = zn ./ u1n * Dh;
        plot(ax, hn, cen, 'o', 'Color', cc, 'MarkerFaceColor', cc, 'MarkerSize', 5, 'HandleVisibility', 'off');
        txt{end+1} = sprintf('%s grid: last point outside the red zone at %.0fx income, next at %.0fx', ...
            short{i0 + j}, max(hn(hn < hb)), min(hn(hn >= hb))); %#ok<AGROW>
    end
    set(ax, 'XScale', 'log', 'YScale', 'log'); xlim(ax, [0.3 6000]); ylim(ax, [YLO YHI]);
    xlabel(ax, HY); ylabel(ax, WB);
    legend(ax, lines, nm(i0 + [0 1]), 'Location', 'northeast', 'FontSize', 9);
    title(ax, sprintf('(%s)  %s, age %d: %s above %.0fx income', char('a' + k - 1), cl_cases{k, 3}, cl_cases{k, 2}, zw, hb));
    text(ax, 0.02, 0.97, txt, 'Units', 'normalized', 'FontSize', 9, 'VerticalAlignment', 'top');
    if notes_on, text(ax, max(hb * 1.25, 30), 3e-2, note{k}, 'FontSize', 9.5, 'VerticalAlignment', 'top', 'Color', [0.55 0.1 0.1]); end
end
save_fig(fig, fullfile(out, ['ruin_2_cliff' tag '.png']));

%% 3. The value landscape over liquid savings and house value
fig = figure('Visible', 'off', 'Position', [30 30 2100 1500], 'Color', 'w');
tl = tiledlayout(fig, 3, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'3. Well-being in every situation: savings (left to right) and house value (bottom to top)', ...
    ['Dark = close to bankruptcy, light = comfortable. Black dots: where the computer calculates. ' ...
     'Grey dots: households. Above the red line the household is ' zw ' this year']}, 'FontSize', 12, 'FontWeight', 'bold');
show_ages = [27 45 85];
for k = 1:numel(show_ages)
    t = find(ages == show_ages(k)); kr = cost_rate(S.p, t);
    xs = [P{1}.x(:, t); P{2}.x(:, t)]; hs = [P{1}.h(:, t); P{2}.h(:, t)];
    xr = [0, max(prctile(xs, 99.5) * 1.3, 1)];
    hr = [max(0.3, prctile(hs, 0.5) * 0.6), max(1.6 * (1 - S.p.phi_floor) / kr, prctile(hs, 99.5) * 1.5)];
    [Xg, Hg] = meshgrid(linspace(xr(1), xr(2), 260), logspace(log10(hr(1)), log10(hr(2)), 260));
    xb = linspace(xr(1), xr(2), 50);
    L = cell(1, 2);
    for i = 1:2
        L{i} = log10(ce_at(R{i}, t, Xg, Hg));
        ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on');
        pcolor(ax, Xg, Hg, L{i}); shading(ax, 'flat');
        colormap(ax, seq_map()); clim(ax, [clo, 1]);
        cb = colorbar(ax); cb.Label.String = 'well-being';
        cb.Ticks = clo:1; cb.TickLabels = [{'near the floor'}, repmat({''}, 1, numel(clo:1) - 2), {'comfortable'}];
        scatter(ax, P{i}.x(1:5:end, t), P{i}.h(1:5:end, t), 3, [0.45 0.45 0.45], 'filled', 'MarkerFaceAlpha', 0.35);
        [xn, hn] = nodes_xh(R{i}.p);
        in = xn >= xr(1) & xn <= xr(2) & hn >= hr(1) & hn <= hr(2);
        plot(ax, xn(in), hn(in), 'k.', 'MarkerSize', 10);
        plot(ax, xb, (xb + 1 - S.p.phi_floor) / kr, 'r-', 'LineWidth', 2);
        set(ax, 'YScale', 'log', 'Layer', 'top'); xlim(ax, xr); ylim(ax, hr);
        xlabel(ax, XY); ylabel(ax, HY);
        title(ax, sprintf('(%s)  age %d, %s', char('a' + 3 * (k - 1) + i - 1), show_ages(k), nm{i}));
        if show_ages(k) == 85 && notes_on
            text(ax, 0.12 * xr(2), hr(2) * 0.7, {'Households above the red line are bankrupt this year,', ...
                'yet they look comfortable: no calculation point lies there'}, 'FontSize', 9.5, ...
                'VerticalAlignment', 'top', 'Color', [0.55 0.1 0.1], 'BackgroundColor', 'w', 'Margin', 2);
        end
    end
    ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on');
    pcolor(ax, Xg, Hg, L{2} - L{1}); shading(ax, 'flat');
    colormap(ax, div_map()); clim(ax, [-2 2]);
    cb = colorbar(ax); cb.Label.String = 'fine grid compared with coarse grid';
    cb.Ticks = -2:2; cb.TickLabels = {'100x worse', '10x worse', 'same', '10x better', '100x better'};
    scatter(ax, P{2}.x(1:5:end, t), P{2}.h(1:5:end, t), 3, [0.3 0.3 0.3], 'filled', 'MarkerFaceAlpha', 0.3);
    plot(ax, xb, (xb + 1 - S.p.phi_floor) / kr, 'r-', 'LineWidth', 2);
    set(ax, 'YScale', 'log', 'Layer', 'top'); xlim(ax, xr); ylim(ax, hr);
    xlabel(ax, XY); ylabel(ax, HY);
    title(ax, sprintf('(%s)  age %d: where the fine grid sees things as worse (blue)', char('a' + 3 * k - 1), show_ages(k)));
end
save_fig(fig, fullfile(out, ['ruin_3_landscape' tag '.png']));

%% 4. Cuts through the occupied region
fig = figure('Visible', 'off', 'Position', [30 30 2100 1150], 'Color', 'w');
tl = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'4. A slice through figure 3 at the typical household''s savings: well-being as the house gets bigger', ...
    ['Top: ' main '. Bottom: ' alt '. Tick marks at the top: where the computer calculates ' ...
     '(black coarse, orange fine). Grey bars: households. Red: ' zw]}, ...
    'FontSize', 12, 'FontWeight', 'bold');
cut_ages = [27 45 85];
for row = 1:2
    for k = 1:3
        t = find(ages == cut_ages(k));
        if row == 1, ii = [1 2]; else, ii = [3 4]; end
        base = R{ii(1)};
        x0 = median(P{ii(1)}.x(:, t));
        hs = [P{ii(1)}.h(:, t); P{ii(2)}.h(:, t)];
        hb = (x0 + 1 - base.p.phi_floor) / cost_rate(base.p, t);
        hlo = max(0.2, prctile(hs, 0.5) * 0.5); hmax = max(prctile(hs, 99.5) * 2, hb * 2);
        hh = logspace(log10(hlo), log10(hmax), 2000);
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        patch(ax, [hb hmax hmax hb], [YLO YLO YHI YHI], [0.9 0.3 0.3], 'FaceAlpha', 0.12, 'EdgeColor', 'none', ...
            'HandleVisibility', 'off');
        hist_strip(ax, logspace(log10(hlo), log10(hmax), 61), hs, YLO, 2);
        lines = gobjects(1, 2);
        for j = 1:2
            ce = ce_at(R{ii(j)}, t, x0 * ones(size(hh)), hh);
            lines(j) = plot(ax, hh, ce, sty{ii(j)}, 'Color', col{ii(j)}, 'LineWidth', 2);
            [hx1, hx2] = crossings(R{ii(j)}.p, x0, hlo, hmax);
            tick_col = cS * (j == 1) + cD * (j == 2);
            for v = [hx1, hx2]
                plot(ax, [v v], YHI * [0.25^j, 0.25^(j - 1)], '-', 'Color', tick_col, 'LineWidth', 1.2, ...
                    'HandleVisibility', 'off');
            end
        end
        set(ax, 'XScale', 'log', 'YScale', 'log'); ylim(ax, [YLO YHI]); xlim(ax, [hlo hmax]);
        xlabel(ax, HY); ylabel(ax, WB);
        if row == 1
            ttl = sprintf('(%s)  %s, age %d, savings %.1fx income', char('a' + k - 1), main, cut_ages(k), x0);
        else
            ttl = sprintf('(%s)  %s, age %d, savings %.1fx income', char('d' + k - 1), alt, cut_ages(k), x0);
        end
        title(ax, ttl);
        legend(ax, lines, nm(ii), 'Location', 'southwest', 'FontSize', 9);
        if row == 1 && k == 3 && notes_on
            text(ax, 0.35, 0.45, {'Households in the red zone are bankrupt this year,', ...
                'so their well-being should be near zero. The computer', ...
                'has no calculation point there, so it carries over', ...
                'the value from the safe side.'}, 'Units', 'normalized', 'FontSize', 9.5, ...
                'Color', [0.55 0.1 0.1]);
        end
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

function hist_strip(ax, e, v, ylo, dec)
% Household histogram drawn as grey bars along the bottom of a log value axis,
% the tallest bar spanning dec decades.
hc = histcounts(v, e); hc = hc / max(max(hc), 1);
e = e(:).';
X = [e(1:end-1); e(2:end); e(2:end); e(1:end-1)];
Y = ylo * [ones(2, numel(hc)); repmat(10.^(dec * hc), 2, 1)];
patch(ax, X, Y, [0.72 0.72 0.72], 'EdgeColor', 'none', 'FaceAlpha', 0.8, 'HandleVisibility', 'off');
end

function m = seq_map()
% dark red (ruin) to pale yellow (comfortable)
k = [0 0.25 0.5 0.75 1];
c = [0.35 0.00 0.05; 0.75 0.15 0.10; 0.95 0.55 0.20; 0.99 0.85 0.45; 1.00 0.98 0.85];
m = interp1(k, c, linspace(0, 1, 256));
end

function m = div_map()
k = [0 0.5 1];
c = [0.15 0.35 0.75; 0.95 0.95 0.95; 0.80 0.25 0.15];
m = interp1(k, c, linspace(0, 1, 256));
end

function save_fig(fig, file)
axs = findall(fig, 'Type', 'axes');
for i = 1:numel(axs)
    if ~isempty(axs(i).Toolbar), axs(i).Toolbar.Visible = 'off'; end
end
exportgraphics(fig, file, 'Resolution', 120);
close(fig);
fprintf('wrote %s\n', file);
end
