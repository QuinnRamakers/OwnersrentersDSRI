function sweep_lifecycles(cases, tag)
%SWEEP_LIFECYCLES  Saved solves with and without the sweep, as life cycles by age.
%
%   From the repository root:
%       addpath diagnostics/pension_grid
%       sweep_lifecycles({13, 'owner', 'pow3_16x16_lim_mop'; 13, 'renter', 'pow3_16x16_lim_mop'; ...
%                         13, 'renter', 'pow3_32x32_lim_mop'}, '13')
%
%   For each row of cases (step, arm, numerics name) loads the saved solve
%   and its twin with _nosweep (case_load; nothing is solved). One row of
%   panels per case: median consumption (grey: median gross and net income),
%   mean liquid saving, the liquid equity share and the share of households
%   at the floor. Writes two pages to <standard numerics dir>/pension_grid/:
%     <tag>_sweep_lifecycles.png    both solves overlaid, solve minutes in
%                                   the legend
%     <tag>_sweep_differences.png   without the sweep minus with it, by age

num = ladder.numerics('standard');
n = size(cases, 1);
P = cell(n, 2);
for i = 1:n
    P{i, 1} = case_load(cases{i, 1}, cases{i, 2}, cases{i, 3});
    P{i, 2} = case_load(cases{i, 1}, cases{i, 2}, [cases{i, 3} '_nosweep']);
    assert(~isempty(P{i, 1}) && ~isempty(P{i, 2}), 'sweep_lifecycles:missing', ...
        'step %d %s %s or its _nosweep twin is not saved.', cases{i, 1}, cases{i, 2}, cases{i, 3});
end
ttl = {'median consumption', 'mean liquid saving', 'liquid equity share', '% of households at the floor'};
for diff_page = [false true]
    fig = figure('Visible', 'off', 'Position', [30 30 2300 520 * n + 80], 'Color', 'w');
    tl  = tiledlayout(fig, n, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
    if diff_page
        head = 'Without the sweep minus with it, by age (saved solves, nothing re-solved)';
    else
        head = 'With the sweep before the optimiser (black) and without it (orange): saved solves, nothing re-solved';
    end
    title(tl, {head, 'Means over households, medians for consumption; multiples of entry income'}, ...
        'FontSize', 13, 'FontWeight', 'bold');
    for i = 1:n
        rs = P(i, :);
        lab = sprintf('Step %d %s %s', cases{i, 1}, cases{i, 2}, strrep(cases{i, 3}, '_', ' '));
        for q = 1:4
            ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9.5; ax.XLim = [25 100];
            y = cell(1, 2);
            for k = 1:2
                sm = rs{k}.summary;
                switch q
                    case 1, y{k} = sm.C.p50 / sm.Y0;
                    case 2, y{k} = sm.X.mean / sm.Y0;
                    case 3, y{k} = sm.pi; y{k}(end) = NaN;
                    case 4, y{k} = 100 * sm.floored;
                end
            end
            a = rs{1}.summary.ages;
            if diff_page
                plot(ax, a, y{2} - y{1}, '-', 'Color', [0.85 0.45 0.10], 'LineWidth', 1.8);
                yline(ax, 0, 'k-', 'HandleVisibility', 'off');
            else
                if q == 1
                    sm = rs{1}.summary;
                    plot(ax, a, sm.Y.p50 / sm.Y0, '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 1.2, 'DisplayName', 'gross income (median)');
                    plot(ax, a, sm.net_income.p50 / sm.Y0, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.2, 'DisplayName', 'net income (median)');
                end
                plot(ax, a, y{1}, '-', 'Color', [0 0 0], 'LineWidth', 2.4, 'DisplayName', ...
                    sprintf('sweep, then optimiser (%.0f min)', rs{1}.timing.solve_sec / 60));
                plot(ax, a, y{2}, '-', 'Color', [0.85 0.45 0.10], 'LineWidth', 1.6, 'DisplayName', ...
                    sprintf('optimiser only (%.0f min)', rs{2}.timing.solve_sec / 60));
                if q == 1, legend(ax, 'Location', 'best', 'FontSize', 8.5); end
                if q == 3, ylim(ax, [0 1]); end
            end
            xline(ax, 67, 'k:', 'HandleVisibility', 'off');
            if q == 4, ylabel(ax, '% of households'); elseif q == 3, ylabel(ax, 'share'); else, ylabel(ax, 'times entry income'); end
            title(ax, sprintf('%s: %s', lab, ttl{q}), 'FontSize', 10);
            if i == n, xlabel(ax, 'Age'); end
        end
    end
    if diff_page, nm = 'differences'; else, nm = 'lifecycles'; end
    out = fullfile(num.dir, 'pension_grid', sprintf('%s_sweep_%s.png', tag, nm));
    exportgraphics(fig, out, 'Resolution', 130);
    close(fig);
    fprintf('Wrote %s\n', out);
end
for i = 1:n
    fprintf('%-40s solve with sweep %5.0f min, without %5.0f min\n', sprintf('step %d %s %s', cases{i, :}), ...
        P{i, 1}.timing.solve_sec / 60, P{i, 2}.timing.solve_sec / 60);
end
end
