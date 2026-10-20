function floored_by_age()
%FLOORED_BY_AGE  Step 16: share of households at the consumption floor, by age.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       floored_by_age
%
%   A household is floored in a year when its liquid resources fall below the
%   floor, phi_floor times income; the simulation then sets consumption to the
%   floor and the shortfall is forgiven (simulate.paths_lna). This is the
%   model's bankruptcy event. Reads the solves behind summary_step16: the
%   summary dashboards (maint_dashboards), the grid comparisons
%   (maint_grid_compare, renter_grid_compare) and the ladder's uniform 16x16
%   run. Writes summary_step16/16_floored_by_age.png and prints the share by
%   age band.

num = ladder.numerics('standard');
out = fullfile(num.dir, 'summary_step16');
if ~isfolder(out), mkdir(out); end
cO = [0.20 0.60 0.30]; cR = [0.45 0.20 0.55];

panels = {
    '(a) Summary dashboards', {
        'owner',  'pow3_16x16_lim_u3p2_qn4_nosweep',     'Owner, maintenance on current value', cO, '-'
        'owner',  'pow3_16x16_lim_u3p2_qn4_nosweep_mop', 'Owner, maintenance on purchase price', cO, '--'
        'renter', 'pow3_16x16_lim_u3p2_u3n20',           'Renter', cR, '-'}
    '(b) Owner, maintenance on current value, by grid', {
        'owner', 'pow3_16x16_lim_u3p2_qn4_nosweep', '16x16 (summary grid)', [0.00 0.45 0.74], '-'
        'owner', 'pow3_20x20_lim_u3p2',             '20x20', [0.85 0.33 0.10], '--'
        'owner', 'pow3_24x24_lim_u3p2_qn4',         '24x24', [0.00 0.60 0.50], '-.'
        'owner', 'pow3_32x32_lim_u3p2',             '32x32', [0 0 0], '-'
        'owner', 'pow3_24x24_lim_u3p2_qn4_u3n20',   '24x24, u3 at 20 points', [0.93 0.69 0.13], ':'}
    '(c) Renter, by grid', {
        'renter', 'pow3_16x16_lim_u3p2_u3n20', '16x16, u3 20 (summary grid)', [0.00 0.45 0.74], '-'
        'renter', 'pow3_16x16_lim_u3p2',       '16x16, u3 10', [0.85 0.33 0.10], '--'
        'renter', 'pow3_32x32_lim_u3p2',       '32x32', [0.00 0.60 0.50], '-.'
        'renter', 'pow3_48x48_lim_u3p2',       '48x48', [0 0 0], '-'
        'renter', 'pow3_16x16_lim_u3p2_u3n40', '16x16, u3 40', [0.93 0.69 0.13], ':'}
    '(d) Ladder''s uniform 16x16 grid (earlier step-16 dashboards)', {
        'owner',  'standard', 'Owner, maintenance on current value', cO, '-'
        'renter', 'standard', 'Renter', cR, '-'}};

fig = figure('Visible', 'off', 'Position', [50 50 1500 1000], 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'Step 16: share of households at the consumption floor (bankrupt), by age', ...
    'Liquid resources below 1e-6 times income; consumption set to the floor and the shortfall forgiven'}, ...
    'FontSize', 13, 'FontWeight', 'bold');
bands = [25 39; 40 66; 67 79; 80 89; 90 100];
fprintf('\n%-58s %7s', 'floored, % of households', 'all');
fprintf('  %3d-%-3d', bands');
fprintf('\n');
for k = 1:size(panels, 1)
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    L = panels{k, 2};
    fprintf('%s\n', panels{k, 1});
    for i = 1:size(L, 1)
        r = case_load(16, L{i, 1}, L{i, 2});
        assert(~isempty(r), 'floored_by_age:missing', '%s %s is not solved.', L{i, 1}, L{i, 2});
        a = r.summary.ages; f = 100 * r.summary.floored;
        plot(ax, a, f, 'Color', L{i, 4}, 'LineStyle', L{i, 5}, 'LineWidth', 2, ...
            'DisplayName', sprintf('%s (%.2f%% of years)', L{i, 3}, 100 * r.checks.floored_share));
        fprintf('  %-56s %6.2f%%', L{i, 3}, 100 * r.checks.floored_share);
        for b = 1:size(bands, 1)
            m = a >= bands(b, 1) & a <= bands(b, 2);
            fprintf('  %6.2f%%', mean(f(m)));
        end
        fprintf('\n');
    end
    xline(ax, 67, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
    xlim(ax, [25 100]); xlabel(ax, 'Age'); ylabel(ax, '% of households at the floor');
    title(ax, panels{k, 1}, 'FontSize', 11);
    legend(ax, 'Location', 'northwest', 'FontSize', 9);
end
ys = arrayfun(@(a) a.YLim(2), findobj(tl, 'Type', 'axes'));
set(findobj(tl, 'Type', 'axes'), 'YLim', [0 max(ys)]);
exportgraphics(fig, fullfile(out, '16_floored_by_age.png'), 'Resolution', 150);
close(fig);
end
