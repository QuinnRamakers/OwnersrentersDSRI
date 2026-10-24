function optimiser_figure(files, labels, file_out)
%OPTIMISER_FIGURE  One page of optimiser_step results, one row per saved test.
%
%   From the repository root:
%       addpath diagnostics/pension_grid
%       optimiser_figure({'optimiser_step_16_owner_pow3_24x24_lim_u3p2_qn4_cmin5000.mat', ...
%                         'optimiser_step_16_renter_pow3_32x32_lim_u3p2_cmin5000.mat'}, ...
%                        {'Owner 24x24', 'Renter 32x32'}, '16_cmin5000_optimiser_step.png')
%
%   files are in <standard numerics dir>/pension_grid/, the page goes to
%   summary_step16/. Columns, by age, one line per search routine: the time
%   of the step; the share of the nodes where the household saves whose value
%   is short of the best routine's by more than 1e-4 in certainty-equivalent
%   units; the largest shortfall; mean consumption and the mean liquid equity
%   share at the simulated households against the best policy.

num = ladder.numerics('standard');
cols = [0 0 0; 0.85 0.45 0.10; 0.20 0.55 0.85; 0.60 0.15 0.55; 0.85 0.15 0.15; 0.25 0.65 0.35; 0.55 0.40 0.10];
mk = {'o', 's', 'd', '^', 'v', '>', 'p'};
n = numel(files);
fig = figure('Visible', 'off', 'Position', [30 30 2300 560 * n], 'Color', 'w');
tl  = tiledlayout(fig, n, 5, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'The per-node search routines on one Bellman step, from the same next-year value and warm start', ...
    'default: sweep, then fmincon interior-point on the certainty-equivalent objective; as / sqp: other fmincon algorithms; util: objective in utility units; nosweep: fmincon from the warm start; nc11: sweep with a wider second round'}, ...
    'FontSize', 12, 'FontWeight', 'bold');
ttl = {'seconds for the step', 'share of nodes short by > 1e-4 (CE)', 'largest shortfall (CE)', ...
       'mean consumption at households vs best, %', 'mean equity share at households vs best'};
for f = 1:n
    S = load(fullfile(num.dir, 'pension_grid', files{f}));
    for j = 1:5
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9;
        for k = 1:numel(S.names)
            switch j
                case 1, y = S.sec(k, :);
                case 2, y = 100 * S.loss_1e4(k, :);
                case 3, y = S.loss_max(k, :);
                case 4, y = 100 * S.C_hh(k, :);
                case 5, y = S.pi_hh(k, :);
            end
            nm = S.names{k};
            if strcmp(nm, 'default'), nm = 'default (interior-point)'; end   % 'default' is a reserved value
            plot(ax, S.ages, y, ['-' mk{k}], 'Color', cols(k, :), 'LineWidth', 1.4, 'MarkerSize', 5, ...
                'MarkerFaceColor', cols(k, :), 'DisplayName', nm);
        end
        if j == 2 || j == 3, set(ax, 'YScale', 'log'); end
        if j == 2, ylabel(ax, '% of nodes'); end
        if j >= 4, yline(ax, 0, 'k:', 'HandleVisibility', 'off'); end
        if j == 1, legend(ax, 'Location', 'best', 'FontSize', 8); ylabel(ax, sprintf('%s\nseconds', labels{f})); end
        xlabel(ax, 'Age'); title(ax, ttl{j}, 'FontSize', 10);
    end
end
out = fullfile(num.dir, 'summary_step16', file_out);
exportgraphics(fig, out, 'Resolution', 130);
close(fig);
fprintf('Wrote %s\n', out);
end
