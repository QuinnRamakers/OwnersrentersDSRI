function T = maintenance_rule_page(c_min)
%MAINTENANCE_RULE_PAGE  The owner grid choices under both maintenance rules, as life cycles.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       T = maintenance_rule_page          % c_min = 5,000
%
%   Loads saved step-16 owner solves (case_load; nothing is solved). Top row:
%   maintenance on the current house value; bottom row: on the purchase
%   price (_mop). Each row: the chosen production grid (u1 32, u2 16, u3 40
%   bunched, q 4; thick black), the one-axis base (bunched 16x16, u3 10,
%   q 4; dashed grey), and the base with u1 at 32, with u3 at 40 and with q
%   at 8. Columns: median consumption (grey: median gross and net income),
%   mean liquid saving, the liquid equity share and the cumulative share
%   bankrupt. Solve minutes are in the legends. Writes
%   summary_step16/16_cmin<n>_owner_maintenance_rules.png and returns (and
%   prints) the runtime table with peak liquid saving, % bankrupt by 85 and
%   median consumption at 30 and at 70.

arguments
    c_min (1,1) double = 5000
end

num = ladder.numerics('standard');
f = sprintf('_cmin%d', c_min);
runs = {'pow3_32x16_lim_u3p2_qn4_u3n40%s_as_nc11', 'chosen: u1 32, u2 16, u3 40, q 4'
        'pow3_32x16_lim_u3p2_qn4%s_as_nc11', 'u1 32'
        'pow3_16x16_lim_u3p2_qn4_u3n40%s_as_nc11', 'u3 40'
        'pow3_16x16_lim_u3p2_qn8%s_as_nc11', 'q 8'
        'pow3_16x16_lim_u3p2_qn4%s_as_nc11', 'base: 16x16, u3 10, q 4'};
% On the current value the u3 40 run was solved with interior-point only
alt = containers.Map({'pow3_16x16_lim_u3p2_qn4_u3n40%s_as_nc11'}, {'pow3_16x16_lim_u3p2_qn4_u3n40%s'});
rules = {'', 'Maintenance on the current house value'; '_mop', 'Maintenance on the purchase price'};
cols = [0 0 0; 0.20 0.55 0.85; 0.85 0.45 0.10; 0.25 0.65 0.35; 0.55 0.55 0.55];
lws = [3.0 1.7 1.7 1.7 1.4];
lss = {'-', '-', '-', '-', '--'};
ttl = {'median consumption', 'mean liquid saving', 'liquid equity share', 'cumulative % bankrupt'};
fig = figure('Visible', 'off', 'Position', [30 30 2300 1100], 'Color', 'w');
tl  = tiledlayout(fig, 2, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('Owner: the grid choices under both maintenance rules (absorbing floor EUR %s; black: the chosen grid)', group(c_min)), ...
    'Step 16, active-set. Means over solvent households, medians for consumption; multiples of entry income; solve minutes in the legends'}, ...
    'FontSize', 13, 'FontWeight', 'bold');
T = table();
for k = 1:2
    rs = cell(1, size(runs, 1)); lab = runs(:, 2);
    for n = 1:size(runs, 1)
        name = [sprintf(runs{n, 1}, f) rules{k, 1}];
        rs{n} = case_load(16, 'owner', name);
        if isempty(rs{n}) && isempty(rules{k, 1}) && isKey(alt, runs{n, 1})
            rs{n} = case_load(16, 'owner', sprintf(alt(runs{n, 1}), f));
            lab{n} = [lab{n} ', interior-point'];
        end
    end
    base = rs{end};
    for q = 1:4
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9.5; ax.XLim = [25 100];
        if q == 1 && ~isempty(base)
            sm = base.summary;
            plot(ax, sm.ages, sm.Y.p50 / sm.Y0, '-', 'Color', [0.82 0.82 0.82], 'LineWidth', 1.1, 'DisplayName', 'gross income (median)');
            plot(ax, sm.ages, sm.net_income.p50 / sm.Y0, '--', 'Color', [0.68 0.68 0.68], 'LineWidth', 1.1, 'DisplayName', 'net income (median)');
        end
        for n = numel(rs):-1:1
            if isempty(rs{n}), continue; end
            sm = rs{n}.summary;
            switch q
                case 1, y = sm.C.p50 / sm.Y0;
                case 2, y = sm.X.mean / sm.Y0;
                case 3, y = sm.pi; y(end) = NaN;
                case 4, y = 100 * sm.floored;
            end
            plot(ax, sm.ages, y, lss{n}, 'Color', cols(n, :), 'LineWidth', lws(n), 'DisplayName', ...
                sprintf('%s (%.0f min)', lab{n}, rs{n}.timing.solve_sec / 60));
        end
        xline(ax, 67, 'k:', 'HandleVisibility', 'off');
        if q == 3, ylim(ax, [0 1]); end
        if q == 4, ylabel(ax, '% of households'); elseif q == 3, ylabel(ax, 'share'); else, ylabel(ax, 'times entry income'); end
        if q == 1, legend(ax, 'Location', 'best', 'FontSize', 8); end
        title(ax, sprintf('%s: %s', rules{k, 2}, ttl{q}), 'FontSize', 10.5);
        if k == 2, xlabel(ax, 'Age'); end
    end
    for n = 1:numel(rs)
        if isempty(rs{n}), continue; end
        s = rs{n}.summary; p = rs{n}.p; ag = s.ages;
        T = [T; table(string(rules{k, 2}), string(lab{n}), string(sprintf('%dx%dx%dx%d', p.N_u1, p.N_u2, p.N_u3, p.N_q)), ...
            rs{n}.timing.solve_sec / 60, max(s.X.mean) / s.Y0, 100 * s.floored(ag == 85), s.C.p50(ag == 30) / s.Y0, ...
            s.C.p50(ag == 70) / s.Y0, 'VariableNames', {'rule', 'run', 'nodes', 'minutes', 'peak_X', 'bkr85', 'C30', 'C70'})]; %#ok<AGROW>
    end
end
out = fullfile(num.dir, 'summary_step16', sprintf('16_cmin%d_owner_maintenance_rules.png', c_min));
exportgraphics(fig, out, 'Resolution', 125);
close(fig);
fprintf('Wrote %s\n\n', out);
fprintf('%-40s %-36s %-13s %8s %8s %8s %7s %7s\n', 'rule', 'run', 'grid points', 'minutes', 'peak X', 'bkr 85', 'C 30', 'C 70');
for i = 1:height(T)
    fprintf('%-40s %-36s %-13s %8.0f %8.2f %7.1f%% %7.3f %7.3f\n', T.rule(i), T.run(i), T.nodes(i), T.minutes(i), ...
        T.peak_X(i), T.bkr85(i), T.C30(i), T.C70(i));
end
end

function s = group(x)
s = regexprep(sprintf('%d', round(x)), '(\d)(?=(\d{3})+$)', '$1,');
end
