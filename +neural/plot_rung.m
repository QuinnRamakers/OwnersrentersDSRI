function fig = plot_rung(tags, opts)
%PLOT_RUNG  Life cycles of the trained networks against the grid policy.
%
%   neural.plot_rung({'step1_ret', 'step1_age'})
%   neural.plot_rung(tags, title='Step 1, CGM core', file='step1.png')
%
%   Reads neural/data/results_<tag>.mat (written by
%   neural/scripts/train_rung.jl) and draws, by age, mean consumption, the
%   mean liquid equity share of solvent households and mean wealth (liquid,
%   pot and house), in units of entry income, one line per network and the
%   grid policy dashed; and the training curves. The legend gives each
%   network's certainty equivalent on the test set against the grid's, with
%   the standard error of the difference. Saved as a PNG in
%   neural/data/figures.

arguments
    tags cell
    opts.title char = ''
    opts.file char = ''
end

data = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'neural', 'data');
runs = {};
for i = 1:numel(tags)
    r = load(fullfile(data, ['results_' tags{i} '.mat']));
    f = fieldnames(r);
    for k = 1:numel(f)
        if startsWith(f{k}, 'run'), runs{end+1} = r.(f{k}); end %#ok<AGROW>
    end
end
assert(~isempty(runs), 'plot_rung:none', 'No runs in the results files.');

fig = figure('Color', 'w', 'Position', [100 100 1200 800], 'Visible', 'off');
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
cols = lines(numel(runs));
panels = {'C', 'Consumption (entry income)'; 'pi', 'Liquid equity share, solvent'; ...
          'W', 'Wealth: liquid, pot and house (entry income)'};
for j = 1:3
    ax = nexttile(tl);
    hold(ax, 'on');
    g = runs{1}.grid;
    plot(ax, g.ages, g.(panels{j, 1}), 'k--', 'LineWidth', 1.5, 'DisplayName', ...
        sprintf('grid policy, ce %.4f', runs{1}.ce_grid));
    for i = 1:numel(runs)
        n = runs{i}.net;
        plot(ax, n.ages, n.(panels{j, 1}), 'Color', cols(i, :), 'LineWidth', 1.2, 'DisplayName', ...
            sprintf('%s, ce %.4f (%+.4f, s.e. %.4f)', runs{i}.variant, runs{i}.ce_net, ...
            runs{i}.diff, runs{i}.se_diff));
    end
    title(ax, panels{j, 2});
    xlabel(ax, 'age');
    grid(ax, 'on');
    if j == 1, legend(ax, 'Location', 'best', 'Interpreter', 'none', 'FontSize', 7); end
end
ax = nexttile(tl);
for i = 1:numel(runs)
    semilogy(ax, runs{i}.curve_step, -runs{i}.curve_value, 'Color', cols(i, :), 'LineWidth', 1.2, ...
        'DisplayName', runs{i}.variant);
    hold(ax, 'on');
end
yline(ax, 1, 'k--', 'grid policy');
title(ax, 'Training: minus mean utility over that of the grid policy');
xlabel(ax, 'step');
grid(ax, 'on');
legend(ax, 'Location', 'northeast', 'Interpreter', 'none', 'FontSize', 7);
if ~isempty(opts.title), title(tl, opts.title, 'Interpreter', 'none'); end

if isempty(opts.file), opts.file = [strjoin(tags, '+') '.png']; end
out = fullfile(data, 'figures');
if ~isfolder(out), mkdir(out); end
exportgraphics(fig, fullfile(out, opts.file), 'Resolution', 130);
end
