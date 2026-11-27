function fig = plot_lifecycles(runs, opts)
%PLOT_LIFECYCLES  Simulated life cycles of grid policies and networks, by age.
%
%   runs = {'grid, standard', cmp_std.grid, 'grid_std'; 'network', cmp_std.net, 'net'; ...};
%   neural.plot_lifecycles(runs, title='Step 18 renters', file='step18_renter_lifecycles.png')
%
%   runs has one row per policy: a label, a profiles struct of
%   neural.compare_panels (out.grid or out.net) and a style: 'grid_std'
%   (grey, dashed), 'grid_fine' (black), or 'net1' to 'net4' (the
%   categorical colours in order). Six panels by age, in multiples of entry
%   income: mean consumption, median consumption with the 10th and 90th
%   percentiles shaded for the first network and the last grid, mean liquid
%   wealth, mean pension pot, mean equity share of the solvent, and the
%   share bankrupt. Saved as a PNG in neural/data/figures.

arguments
    runs cell
    opts.title char = ''
    opts.file char = 'lifecycles.png'
end

col = struct('grid_std', [0.55 0.55 0.55], 'grid_fine', [0.05 0.05 0.05], ...
    'net1', [42 120 214] / 255, 'net2', [235 104 52] / 255, 'net3', [27 175 122] / 255, 'net4', [237 161 0] / 255);
sty = struct('grid_std', '--', 'grid_fine', '-', 'net1', '-', 'net2', '-', 'net3', '-', 'net4', '-');
ink2 = [82 81 78] / 255;
ages = 25 : 25 + numel(runs{1, 2}.C) - 1;
panels = {'C', 'Mean consumption'; 'C_p50', 'Median consumption, 10th-90th percentile shaded'; ...
          'X', 'Mean liquid wealth'; 'A', 'Mean pension pot'; ...
          'pi', 'Mean liquid equity share, solvent households'; 'absorbed', 'Share bankrupt'};
fig = figure('Color', [252 252 251] / 255, 'Position', [50 50 1500 900], 'Visible', 'off');
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for j = 1:size(panels, 1)
    ax = nexttile(tl);
    hold(ax, 'on');
    f = panels{j, 1};
    if strcmp(f, 'C_p50')
        shade = [find(startsWith(runs(:, 3), 'net'), 1), find(startsWith(runs(:, 3), 'grid'), 1, 'last')];
        for k = shade
            pr = runs{k, 2};
            a1 = ages(1:end-1);   % the last year spends what is left
            fill(ax, [a1, fliplr(a1)], [pr.C_p10(1:end-1).', fliplr(pr.C_p90(1:end-1).')], col.(runs{k, 3}), ...
                'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
    end
    for k = 1:size(runs, 1)
        y = runs{k, 2}.(f);
        x = ages;
        if any(strcmp(f, {'C', 'C_p50'})), x = ages(1:end-1); y = y(1:end-1); end   % the last year spends what is left
        plot(ax, x, y, sty.(runs{k, 3}), 'Color', col.(runs{k, 3}), 'LineWidth', 1.6, 'DisplayName', runs{k, 1});
    end
    title(ax, panels{j, 2}, 'FontWeight', 'normal', 'FontSize', 11);
    xlabel(ax, 'age', 'Color', ink2);
    if ~any(strcmp(f, {'pi', 'absorbed'})), ylabel(ax, 'multiples of entry income', 'Color', ink2); end
    set(ax, 'XGrid', 'on', 'YGrid', 'on', 'GridColor', [0.88 0.88 0.87], 'GridAlpha', 1, 'Box', 'off', ...
        'XColor', ink2, 'YColor', ink2, 'FontSize', 10, 'XLim', [25 100]);
    xline(ax, 67, ':', 'Color', ink2, 'HandleVisibility', 'off');
    if j == 1, legend(ax, 'Location', 'best', 'Interpreter', 'none', 'FontSize', 9, 'Box', 'off'); end
end
if ~isempty(opts.title), title(tl, opts.title, 'FontSize', 13, 'Interpreter', 'none'); end
out = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'neural', 'data', 'figures');
if ~isfolder(out), mkdir(out); end
exportgraphics(fig, fullfile(out, opts.file), 'Resolution', 130);
end
