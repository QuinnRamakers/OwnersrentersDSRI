function grid_map()
%GRID_MAP  Where the solver's grid points land in savings and house value per unit of income.
%   One page, grid_map.png, from the step-7 owner on the standard grid: the
%   grid in the solver's own coordinates, the same points per unit of income
%   with the households at 45 and the floor line, and the same on a log house axis.
pth = step07_paths();
cd(pth.repo);
S = load(fullfile(pth.res, '07_housing_owner.mat'));
p = S.p;
u1 = p.u1_grid(:); u2 = p.u2_grid(:);
[U1, U2] = ndgrid(u1, u2);
X = (1 - U1) .* (1 - U2) ./ U1; H = (1 - U1) .* U2 ./ U1;
sim = simulate.forward(p, S.profile, S.sol, S.ann_price, S.timing.N_sim, S.timing.seed, p.b0);
t = find(sim.ages == 45);
xs = sim.X(:, t) ./ sim.Y(:, t); hs = sim.H(:, t) ./ sim.Y(:, t);
k = p.theta + p.m_rate_path(t);

[~, i1] = min(abs(u1 - 0.08));                 % one income-share column
[~, i2] = min(abs(u2 - 0.75));                 % one house-share row
cA = [0.85 0.33 0.10]; cB = [0.20 0.45 0.75];
fig = figure('Visible', 'off', 'Position', [30 30 2100 700], 'Color', 'w');
tl = tiledlayout(fig, 1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'Why the grid points are not on a straight grid: the solver lays its grid out in its own scaled coordinates', ...
    ['A regular grid in "income as a share of total wealth" and "house as a share of savings plus house" ' ...
     'becomes a fan of rays and diagonals once everything is measured per unit of income']}, ...
    'FontSize', 13, 'FontWeight', 'bold');

ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
plot(ax, U1(:), U2(:), 'k.', 'MarkerSize', 12);
plot(ax, U1(i1, :), U2(i1, :), 'o', 'Color', cA, 'MarkerFaceColor', cA, 'MarkerSize', 6);
plot(ax, U1(:, i2), U2(:, i2), 'o', 'Color', cB, 'MarkerFaceColor', cB, 'MarkerSize', 6);
xlabel(ax, 'income as a share of total wealth (income + savings + house)');
ylabel(ax, 'house as a share of savings plus house');
xlim(ax, [-0.02 1.02]); ylim(ax, [-0.02 1.02]);
title(ax, {'(a)  The grid as the solver sees it: rows and columns', ...
    'orange: one column (same total wealth relative to income)', 'blue: one row (same house share)'});

for j = 1:2
    ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    scatter(ax, xs(1:4:end), hs(1:4:end), 4, [0.6 0.6 0.6], 'filled', 'MarkerFaceAlpha', 0.4);
    plot(ax, X(:), H(:), 'k.', 'MarkerSize', 12);
    plot(ax, X(i1, :), H(i1, :), 'o-', 'Color', cA, 'MarkerFaceColor', cA, 'MarkerSize', 6, 'LineWidth', 1.2);
    plot(ax, X(:, i2), H(:, i2), 'o-', 'Color', cB, 'MarkerFaceColor', cB, 'MarkerSize', 6, 'LineWidth', 1.2);
    xb = linspace(0, 30, 50);
    plot(ax, xb, (xb + 1 - p.phi_floor) / k, 'r-', 'LineWidth', 2);
    xlim(ax, [0 30]); xlabel(ax, 'savings relative to income');
    if j == 1
        ylim(ax, [0 30]); ylabel(ax, 'house value relative to income');
        title(ax, {'(b)  The same points per unit of income (age 45)', ...
            'columns become diagonals, rows become rays from the corner;', ...
            'the gaps widen fast as wealth grows relative to income'});
        text(ax, 12, 27, 'above the red line: bankrupt this year', 'Color', [0.7 0.1 0.1], 'FontSize', 10);
    else
        set(ax, 'YScale', 'log'); ylim(ax, [0.3 300]); ylabel(ax, 'house value relative to income (log scale)');
        title(ax, {'(c)  As in figure 3, with the house on a log scale', 'the straight rays and diagonals now bend'});
    end
    legend(ax, {'households at 45', 'grid points', 'one column', 'one row', 'bankruptcy line'}, ...
        'Location', 'southeast', 'FontSize', 9);
end
w = 1 ./ u1 - 1;
fprintf('total wealth / income on the columns: %s\n', mat2str(round(sort(w).', 1)));
exportgraphics(fig, fullfile(pth.out, 'grid_map.png'), 'Resolution', 120);
close(fig);
end
