function T = confirm_grid_page(c_min)
%CONFIRM_GRID_PAGE  The confirming grid of each tenure against the finest single-axis runs.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       T = confirm_grid_page          % c_min = 5,000
%
%   Loads saved step-16 solves (case_load; nothing is solved). One row per
%   tenure: the confirming grid (thick black), the finest u1 run, the finest
%   u3 runs, the run with every axis doubled, the one-axis base, and for
%   renters the 24 October candidate (32x32, u3 40 evenly spaced). Columns:
%   median consumption (grey: median gross and net income), mean liquid
%   saving, the liquid equity share and the cumulative share bankrupt. Solve
%   minutes are in the legends. Writes
%   summary_step16/16_cmin<n>_confirm_grids.png and returns (and prints) the
%   runtime table with each run's peak liquid saving, % bankrupt by 85 and
%   median consumption at 30 and at 70.

arguments
    c_min (1,1) double = 5000
end

num = ladder.numerics('standard');
f = sprintf('_cmin%d', c_min);
A = struct('arm', {'renter', 'owner'}, 'title', {'Renter', 'Owner, maintenance on the current value'}, 'runs', { ...
    {['pow3_64x16_lim_u3even_u3n40' f '_as_nc11'], 'confirming: u1 64, u2 16, u3 40 even'
     ['pow3_64x16_lim_u3even_u3n10' f '_as_nc11'], 'u1 64 (u3 10)'
     ['pow3_16x16_lim_u3even_u3n40' f '_as_nc11'], 'u3 40 even (u1 16)'
     ['pow3_16x16_lim_u3even_u3n80' f '_as_nc11'], 'u3 80 even (u1 16)'
     ['pow3_32x32_lim_u3even_u3n40' f '_as_nc11'], 'candidate 24 Oct: 32x32, u3 40 even'
     ['pow3_16x16_lim_u3even_u3n10' f '_as_nc11'], 'base: 16x16, u3 10 even'}, ...
    {['pow3_32x16_lim_u3p2_qn4_u3n40' f '_as_nc11'], 'confirming: u1 32, u2 16, u3 40, q 4'
     ['pow3_64x16_lim_u3p2_qn4' f '_as_nc11'], 'u1 64 (u3 10)'
     ['pow3_16x16_lim_u3p2_qn4_u3n40' f], 'u3 40 (u1 16, interior-point)'
     ['pow3_16x16_lim_u3p2_qn4_u3n80' f '_as_nc11'], 'u3 80 (u1 16)'
     ['pow3_32x32_lim_u3p2_qn8_u3n20' f '_as_nc11'], 'all doubled: 32x32, u3 20, q 8'
     ['pow3_16x16_lim_u3p2_qn4' f '_as_nc11'], 'base: 16x16, u3 10, q 4'}});
cols = [0 0 0; 0.20 0.55 0.85; 0.85 0.45 0.10; 0.60 0.15 0.55; 0.25 0.65 0.35; 0.6 0.6 0.6];
lws = [3.0 1.7 1.7 1.7 1.7 1.3];
ttl = {'median consumption', 'mean liquid saving', 'liquid equity share', 'cumulative % bankrupt'};
fig = figure('Visible', 'off', 'Position', [30 30 2300 1100], 'Color', 'w');
tl  = tiledlayout(fig, 2, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('The confirming grid of each tenure (black) against the finest single-axis runs (absorbing floor EUR %s)', group(c_min)), ...
    'Step 16. Means over solvent households, medians for consumption; multiples of entry income; solve minutes in the legends'}, ...
    'FontSize', 13, 'FontWeight', 'bold');
T = table();
for a = 1:2
    runs = A(a).runs;
    rs = cellfun(@(c) case_load(16, A(a).arm, c), runs(:, 1), 'UniformOutput', false);
    ref = find(~cellfun(@isempty, rs), 1, 'last');            % the base, for the income lines
    for q = 1:4
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9.5; ax.XLim = [25 100];
        if q == 1 && ~isempty(ref)
            sm = rs{ref}.summary;
            plot(ax, sm.ages, sm.Y.p50 / sm.Y0, '-', 'Color', [0.82 0.82 0.82], 'LineWidth', 1.1, 'DisplayName', 'gross income (median)');
            plot(ax, sm.ages, sm.net_income.p50 / sm.Y0, '--', 'Color', [0.68 0.68 0.68], 'LineWidth', 1.1, 'DisplayName', 'net income (median)');
        end
        for n = numel(rs):-1:1                                  % confirming grid drawn last, on top
            if isempty(rs{n}), continue; end
            sm = rs{n}.summary;
            switch q
                case 1, y = sm.C.p50 / sm.Y0;
                case 2, y = sm.X.mean / sm.Y0;
                case 3, y = sm.pi; y(end) = NaN;
                case 4, y = 100 * sm.floored;
            end
            ls = '-'; if n == numel(rs), ls = '--'; end
            plot(ax, sm.ages, y, ls, 'Color', cols(n, :), 'LineWidth', lws(n), 'DisplayName', ...
                sprintf('%s (%.0f min)', runs{n, 2}, rs{n}.timing.solve_sec / 60));
        end
        xline(ax, 67, 'k:', 'HandleVisibility', 'off');
        if q == 3, ylim(ax, [0 1]); end
        if q == 4, ylabel(ax, '% of households'); elseif q == 3, ylabel(ax, 'share'); else, ylabel(ax, 'times entry income'); end
        if q == 1, legend(ax, 'Location', 'best', 'FontSize', 8); end
        title(ax, sprintf('%s: %s', A(a).title, ttl{q}), 'FontSize', 10.5);
        if a == 2, xlabel(ax, 'Age'); end
    end
    for n = 1:numel(rs)
        if isempty(rs{n}), continue; end
        s = rs{n}.summary; p = rs{n}.p; ag = s.ages;
        T = [T; table(string(A(a).arm), string(runs{n, 2}), string(sprintf('%dx%dx%dx%d', p.N_u1, p.N_u2, p.N_u3, p.N_q)), ...
            rs{n}.timing.solve_sec / 60, max(s.X.mean) / s.Y0, 100 * s.floored(ag == 85), s.C.p50(ag == 30) / s.Y0, ...
            s.C.p50(ag == 70) / s.Y0, 'VariableNames', {'tenure', 'run', 'nodes', 'minutes', 'peak_X', 'bkr85', 'C30', 'C70'})]; %#ok<AGROW>
    end
end
out = fullfile(num.dir, 'summary_step16', sprintf('16_cmin%d_confirm_grids.png', c_min));
exportgraphics(fig, out, 'Resolution', 125);
close(fig);
fprintf('Wrote %s\n\n', out);
fprintf('%-7s %-40s %-13s %8s %8s %8s %7s %7s\n', 'tenure', 'run', 'grid points', 'minutes', 'peak X', 'bkr 85', 'C 30', 'C 70');
for i = 1:height(T)
    fprintf('%-7s %-40s %-13s %8.0f %8.2f %7.1f%% %7.3f %7.3f\n', T.tenure(i), T.run(i), T.nodes(i), T.minutes(i), ...
        T.peak_X(i), T.bkr85(i), T.C30(i), T.C70(i));
end
end

function s = group(x)
s = regexprep(sprintf('%d', round(x)), '(\d)(?=(\d{3})+$)', '$1,');
end
