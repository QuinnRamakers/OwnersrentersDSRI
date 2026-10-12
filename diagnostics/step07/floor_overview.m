function floor_overview()
%FLOOR_OVERVIEW  Step 7 owner at several floors: does a higher floor make the grids agree?
%   One page, floors_overview.png: stock share, savings and the share on the
%   floor by age for each floor on both grids, the largest gap between the
%   grids by floor, the stock share at 27 and the value at entry. Prints the
%   numbers. Needs step 7, its robustness solves and the solve_cases floor results.
pth = step07_paths();
cd(pth.repo);
fl = [1e-6 0.1 0.2 0.3 0.5];
R = cell(numel(fl), 2);
R{1, 1} = load(fullfile(pth.res, '07_housing_owner.mat'));
R{1, 2} = load(fullfile(pth.res, 'robustness', '07_housing_owner_dense_u1.mat'));
for i = 2:numel(fl)
    F = load(fullfile(pth.data, sprintf('owner_floor_%03d.mat', round(100 * fl(i)))));
    R{i, 1} = F.std; R{i, 2} = F.dense;
end
lab = {'floor 10^{-6} (as run)', 'floor 0.1', 'floor 0.2', 'floor 0.3', 'floor 0.5'};
col = [0 0 0; 0.80 0.25 0.15; 0.90 0.60 0.10; 0.25 0.60 0.30; 0.20 0.40 0.80];

fig = figure('Visible', 'off', 'Position', [30 30 2100 1150], 'Color', 'w');
tl = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'Step 7 owner at higher floors: does the answer stop depending on the grid?', ...
    'Solid: coarse grid. Dashed: fine grid (twice the points on the income axis). Same model otherwise'}, ...
    'FontSize', 13, 'FontWeight', 'bold');
axs = gobjects(1, 3);
for j = 1:3, axs(j) = nexttile(tl); hold(axs(j), 'on'); grid(axs(j), 'on'); box(axs(j), 'on'); end
gap = zeros(numel(fl), 3); at27 = zeros(numel(fl), 4); entry = zeros(numel(fl), 2);
h = gobjects(1, numel(fl));
for i = 1:numel(fl)
    for k = 1:2
        s = R{i, k}.summary; a = s.ages(:).'; w = 1:numel(a) - 1; ls = '-'; if k == 2, ls = '--'; end
        hh = plot(axs(1), a(w), 100 * s.pi(w), ls, 'Color', col(i, :), 'LineWidth', 2);
        plot(axs(2), a, s.X.mean(:).' ./ s.Y.mean(:).', ls, 'Color', col(i, :), 'LineWidth', 2);
        plot(axs(3), a, 100 * s.floored(:).', ls, 'Color', col(i, :), 'LineWidth', 2);
        if k == 1, h(i) = hh; end
        at27(i, 2 * k - 1) = 100 * s.pi(a == 27);
        at27(i, 2 * k) = 100 * s.C.mean(a == 27) / s.Y.mean(a == 27);
        entry(i, k) = R{i, k}.checks.ce_entry;
    end
    s0 = R{i, 1}.summary; s1 = R{i, 2}.summary; a = s0.ages(:).';
    ww = a > 25 & a <= 95; w2 = a(1:end-1) > 25 & a(1:end-1) <= 95;
    dpi = abs(s1.pi(1:end-1) - s0.pi(1:end-1));
    gap(i, :) = [100 * max(dpi(w2)), 100 * max(abs(s1.C.mean(ww) ./ s0.C.mean(ww) - 1)), ...
                 max(abs(s1.X.mean(ww) - s0.X.mean(ww)) ./ s0.Y.mean(ww))];
    fprintf('%-24s gap: stock share %.1f pp, consumption %.1f%%, savings %.2f x income; at 27 coarse/fine: stocks %.0f/%.0f%%, C/Y %.2f/%.2f; floored %.1f/%.1f%%; entry %.3f/%.3f\n', ...
        lab{i}, gap(i, 1), gap(i, 2), gap(i, 3), at27(i, 1), at27(i, 3), at27(i, 2) / 100, at27(i, 4) / 100, ...
        100 * R{i, 1}.checks.floored_share, 100 * R{i, 2}.checks.floored_share, entry(i, 1), entry(i, 2));
end
for j = 1:3, xlim(axs(j), [25 95]); xline(axs(j), 67, 'k:', 'HandleVisibility', 'off'); xlabel(axs(j), 'Age'); end
ylabel(axs(1), 'average share of savings in stocks (%)'); ylim(axs(1), [0 102]);
title(axs(1), '(a)  Stock share over life');
legend(axs(1), h, lab, 'Location', 'southwest', 'FontSize', 9);
ylabel(axs(2), 'average savings, relative to income');
title(axs(2), '(b)  Savings over life');
ylabel(axs(3), '% of households on the floor that year');
title(axs(3), {'(c)  How often households are on the floor', '(a higher floor also catches more households by definition)'});

ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
xc = 1:numel(fl);
plot(ax, xc, gap(:, 1), 'o-', 'Color', [0.2 0.2 0.2], 'MarkerFaceColor', [0.2 0.2 0.2], 'LineWidth', 2, 'MarkerSize', 8);
plot(ax, xc, gap(:, 2), 's-', 'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'LineWidth', 2, 'MarkerSize', 8);
yline(ax, 2, ':', 'our stop rule: 2', 'HandleVisibility', 'off');
set(ax, 'XTick', xc, 'XTickLabel', {'10^{-6}', '0.1', '0.2', '0.3', '0.5'});
xlabel(ax, 'floor, as a share of income'); ylabel(ax, 'largest gap between the grids, ages 26-95');
legend(ax, {'stock share (percentage points)', 'consumption (%)'}, 'Location', 'northeast');
title(ax, {'(d)  How far apart the two grids are', 'lower = the answer depends less on the grid'});

ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
b = bar(ax, xc, at27(:, [1 3]), 0.8, 'EdgeColor', 'none');
b(1).FaceColor = [0.15 0.15 0.15]; b(2).FaceColor = [0.85 0.33 0.10];
set(ax, 'XTick', xc, 'XTickLabel', {'10^{-6}', '0.1', '0.2', '0.3', '0.5'}); ylim(ax, [0 110]);
xlabel(ax, 'floor, as a share of income'); ylabel(ax, 'average share of savings in stocks at 27 (%)');
legend(ax, {'coarse grid', 'fine grid'}, 'Location', 'northwest');
title(ax, {'(e)  The young owner''s stock share at 27', 'equal bars = the grids agree'});

ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
b = bar(ax, xc, entry, 0.8, 'EdgeColor', 'none');
b(1).FaceColor = [0.15 0.15 0.15]; b(2).FaceColor = [0.85 0.33 0.10];
set(ax, 'XTick', xc, 'XTickLabel', {'10^{-6}', '0.1', '0.2', '0.3', '0.5'});
xlabel(ax, 'floor, as a share of income'); ylabel(ax, 'well-being at the start of life');
legend(ax, {'coarse grid', 'fine grid'}, 'Location', 'northwest');
title(ax, {'(f)  Well-being at the start of life', 'equal bars = the grids agree'});

axl = findall(fig, 'Type', 'axes');
for i = 1:numel(axl), if ~isempty(axl(i).Toolbar), axl(i).Toolbar.Visible = 'off'; end, end
exportgraphics(fig, fullfile(pth.out, 'floors_overview.png'), 'Resolution', 120);
close(fig);
end
