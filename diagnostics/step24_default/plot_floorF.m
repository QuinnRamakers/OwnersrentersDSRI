function plot_floorF(file, out)
%PLOT_FLOORF  Step 24 renters, bequest shifter 1: the grid policy and the
%networks of one train_rung.jl run, by age, on the same 20,000 households.
%
%   plot_floorF('neural/data/results_step24shift1_floorF_renter.mat', ...
%               'diagnostics/step24_default/floorF_by_age.png')
%
%   Means by age of consumption, liquid wealth and income (in entry incomes),
%   the equity share of the solvent households and the share bankrupt.

r = load(file);
runs = fieldnames(r);
runs = runs(startsWith(runs, 'run'));
panels = {'C', 'consumption'; 'X', 'liquid wealth'; 'pi', 'equity share (solvent)'; 'absorbed', 'share bankrupt'};
fig = figure('Visible', 'off', 'Position', [100 100 1100 750]);
tl = tiledlayout(2, 2, 'TileSpacing', 'compact');
cols = [0.15 0.15 0.15; 0.00 0.45 0.74; 0.85 0.33 0.10];
for k = 1:size(panels, 1)
    nexttile; hold on;
    g = r.(runs{1}).grid;
    plot(g.ages, g.(panels{k, 1}), 'Color', cols(1, :), 'LineWidth', 2, 'DisplayName', 'grid (fine)');
    for j = 1:numel(runs)
        n = r.(runs{j}).net;
        plot(n.ages, n.(panels{k, 1}), 'Color', cols(1 + j, :), 'LineWidth', 1.5, ...
            'DisplayName', strrep(r.(runs{j}).variant, '_', '\_'));
    end
    if strcmp(panels{k, 1}, 'C')
        plot(g.ages, g.Y, ':', 'Color', cols(1, :), 'DisplayName', 'income (grid)');
    end
    title(panels{k, 2}); xlabel('age'); grid on; box off;
    if k == 1, legend('Location', 'best'); end
end
title(tl, 'Step 24 renters, beq\_shift 1, floor at F when continuing: grid against network');
exportgraphics(fig, out, 'Resolution', 150);
close(fig);
end
