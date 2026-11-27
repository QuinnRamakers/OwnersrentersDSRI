function fig = plot_refinement(T, sim_grid, sim_net, opts)
%PLOT_REFINEMENT  The solver's value of two fixed policies as the grid refines.
%
%   neural.plot_refinement(T, 0.2161, 0.2438, title='Step 18 renters', file='step18_renter_refinement.png')
%
%   T is the table of neural.eval_refinement. One point per grid, in the
%   order of the table, for the grid policy (grey) and the network (blue);
%   the dashed lines are what each policy delivers in simulation
%   (neural.sim_utility), where the solver's values should end up.

arguments
    T table
    sim_grid (1,1) double
    sim_net (1,1) double
    opts.title char = ''
    opts.file char = 'refinement.png'
end

grey = [0.45 0.45 0.45]; blue = [42 120 214] / 255; ink2 = [82 81 78] / 255;
fig = figure('Color', [252 252 251] / 255, 'Position', [100 100 1000 520], 'Visible', 'off');
ax = axes(fig); hold(ax, 'on');
x = 1:height(T);
yline(ax, sim_grid, '--', 'Color', grey, 'LineWidth', 1.2, 'HandleVisibility', 'off');
yline(ax, sim_net, '--', 'Color', blue, 'LineWidth', 1.2, 'HandleVisibility', 'off');
plot(ax, x, T.ce_grid_policy, '-o', 'Color', grey, 'MarkerFaceColor', grey, 'MarkerEdgeColor', 'w', ...
    'MarkerSize', 8, 'LineWidth', 1.6, 'DisplayName', 'grid policy (standard-grid solve), solver''s value');
plot(ax, x, T.ce_network, '-o', 'Color', blue, 'MarkerFaceColor', blue, 'MarkerEdgeColor', 'w', ...
    'MarkerSize', 8, 'LineWidth', 1.6, 'DisplayName', 'network, solver''s value');
text(ax, x(end) + 0.15, sim_grid, sprintf('grid policy in simulation, %.4f', sim_grid), 'Color', grey, 'FontSize', 9, 'VerticalAlignment', 'bottom');
text(ax, x(end) + 0.15, sim_net, sprintf('network in simulation, %.4f', sim_net), 'Color', blue, 'FontSize', 9, 'VerticalAlignment', 'bottom');
labels = strcat(string(T.nodes), " gh", string(T.gh_n));
set(ax, 'XTick', x, 'XTickLabel', labels, 'XLim', [0.5 x(end) + 2.2], 'FontSize', 9, 'XColor', ink2, 'YColor', ink2, ...
    'YGrid', 'on', 'GridColor', [0.88 0.88 0.87], 'GridAlpha', 1, 'Box', 'off');
xtickangle(ax, 30);
xlabel(ax, 'evaluation grid (nodes on u1 x u2 x u3 x q, Gauss-Hermite nodes per shock)', 'Color', ink2);
ylabel(ax, 'certainty-equivalent consumption at entry (entry income)', 'Color', ink2);
legend(ax, 'Location', 'northeast', 'Box', 'off', 'FontSize', 9);
if ~isempty(opts.title), title(ax, opts.title, 'FontWeight', 'normal', 'FontSize', 12, 'Interpreter', 'none'); end
out = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'neural', 'data', 'figures');
if ~isfolder(out), mkdir(out); end
exportgraphics(fig, fullfile(out, opts.file), 'Resolution', 140);
end
