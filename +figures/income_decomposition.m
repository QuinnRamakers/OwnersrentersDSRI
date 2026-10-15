function income_decomposition(ax, d, p, lfs)
%INCOME_DECOMPOSITION  Where income comes from and what housing costs take, means across households.
%
%   figures.income_decomposition(ax, d, p, lfs)
%
%   d from figures.panel_data, p the result's parameters, lfs the legend font
%   size. Stacked above zero: income received after tax and contributions
%   (wages, then the state pension) and the private pension payment after tax.
%   Stacked below zero: the owner's maintenance and mortgage payment, or the
%   renter's rent. Lines: net disposable income and gross income.

a = d.ages; sc = d.scale;
hold(ax, 'on');
ap = area(ax, a, [mean(d.takehome, 1); mean(d.annuity, 1)].' * sc);
ap(1).FaceColor = [0.35 0.62 0.42]; ap(2).FaceColor = [0.20 0.55 0.55];
set(ap, 'FaceAlpha', 0.80, 'EdgeColor', 'none');
ap(1).DisplayName = 'Income received after tax and contributions (wages, then state pension)';
ap(2).DisplayName = 'Private pension payment after tax';
if d.has_housing && p.is_owner
    an = area(ax, a, -[mean(d.maintenance, 1); mean(d.mortgage, 1)].' * sc);
    an(1).FaceColor = [0.90 0.55 0.20]; an(2).FaceColor = [0.65 0.15 0.15];
    set(an, 'FaceAlpha', 0.80, 'EdgeColor', 'none');
    an(1).DisplayName = 'Home maintenance cost'; an(2).DisplayName = 'Mortgage payment';
elseif d.has_housing
    an = area(ax, a, -mean(d.rent, 1).' * sc);
    set(an, 'FaceColor', [0.80 0.30 0.30], 'FaceAlpha', 0.80, 'EdgeColor', 'none', 'DisplayName', 'Rent payment');
end
plot(ax, a, mean(d.disp_inc, 1) * sc, 'k-', 'LineWidth', 2.0, 'DisplayName', 'Net disposable income');
plot(ax, a, mean(d.Y, 1) * sc, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2, ...
    'DisplayName', 'Gross income (before deductions, for reference)');
yline(ax, 0, 'k-', 'HandleVisibility', 'off', 'LineWidth', 0.5);
ylabel(ax, d.unit);
legend(ax, 'Location', 'best', 'FontSize', lfs);
end
