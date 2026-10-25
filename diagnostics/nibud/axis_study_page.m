function T = axis_study_page(arm, c_min)
%AXIS_STUDY_PAGE  Each grid axis doubled on its own, as life cycles, and what each doubling costs.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       T = axis_study_page('renter')        % c_min = 5,000
%
%   Loads saved step-16 solves (case_load; nothing is solved). One row of
%   panels per axis, each starting from the same base: u1 (income over total
%   resources), u2 (pension and house over non-income wealth), u3 (pension
%   against house or rent index), q for owners (purchase price over house
%   value), and a last row with every axis doubled at once next to the single
%   doublings. Columns: median consumption (grey: median gross and net income),
%   mean liquid saving, the liquid equity share and the cumulative share
%   bankrupt. The base is the thick black line in every row; solve minutes are
%   in the legends. Writes summary_step16/16_cmin<n>_<arm>_axis_study.png and
%   returns (and prints) a table: each run's grid points, solve minutes, and
%   what it changes against the base (peak liquid saving, % bankrupt by 85,
%   median consumption at 30 and at 70).

arguments
    arm (1,:) char {mustBeMember(arm, {'owner', 'renter'})}
    c_min (1,1) double = 5000
end

num = ladder.numerics('standard');
suf = sprintf('_cmin%d_as_nc11', c_min);
if strcmp(arm, 'renter')
    base = 'pow3_16x16_lim_u3even_u3n10';
    rows = {
      'u1 (income over total resources)', {'pow3_32x16_lim_u3even_u3n10', 'u1 32'; 'pow3_64x16_lim_u3even_u3n10', 'u1 64'}
      'u2 (pension and rent index over non-income wealth)', {'pow3_16x32_lim_u3even_u3n10', 'u2 32'; 'pow3_16x64_lim_u3even_u3n10', 'u2 64'}
      'u3 (pension against rent index), evenly spaced', {'pow3_16x16_lim_u3even_u3n20', 'u3 20'; 'pow3_16x16_lim_u3even_u3n40', 'u3 40'; 'pow3_16x16_lim_u3even_u3n80', 'u3 80'}
      'Every axis doubled at once, next to each single doubling', {'pow3_32x16_lim_u3even_u3n10', 'u1 32'; 'pow3_16x32_lim_u3even_u3n10', 'u2 32'; ...
                                                                   'pow3_16x16_lim_u3even_u3n20', 'u3 20'; 'pow3_32x32_lim_u3even_u3n20', 'all doubled'}};
    base_label = 'base: 16x16, u3 10 even';
else
    base = 'pow3_16x16_lim_u3p2_qn4';
    rows = {
      'u1 (income over total resources)', {'pow3_32x16_lim_u3p2_qn4', 'u1 32'; 'pow3_64x16_lim_u3p2_qn4', 'u1 64'}
      'u2 (pension and house over non-income wealth)', {'pow3_16x32_lim_u3p2_qn4', 'u2 32'; 'pow3_16x64_lim_u3p2_qn4', 'u2 64'}
      'u3 (pension against house), bunched toward 0', {'pow3_16x16_lim_u3p2_qn4_u3n20', 'u3 20'; 'pow3_16x16_lim_u3p2_qn4_u3n40', 'u3 40'; 'pow3_16x16_lim_u3p2_qn4_u3n80', 'u3 80'}
      'q (purchase price over house value)', {'pow3_16x16_lim_u3p2_qn8', 'q 8'; 'pow3_16x16_lim_u3p2_qn16', 'q 16'}
      'Every axis doubled at once, next to each single doubling', {'pow3_32x16_lim_u3p2_qn4', 'u1 32'; 'pow3_16x32_lim_u3p2_qn4', 'u2 32'; ...
                                                                   'pow3_16x16_lim_u3p2_qn4_u3n20', 'u3 20'; 'pow3_16x16_lim_u3p2_qn8', 'q 8'; ...
                                                                   'pow3_32x32_lim_u3p2_qn8_u3n20', 'all doubled'}};
    base_label = 'base: 16x16, u3 10, q 4';
end
R0 = case_load(16, arm, [base suf]);
assert(~isempty(R0), 'axis_study_page:missing', 'the base %s is not solved.', [base suf]);

cols = [0.20 0.55 0.85; 0.85 0.45 0.10; 0.60 0.15 0.55; 0.25 0.65 0.35; 0.85 0.15 0.15];
ttl = {'median consumption', 'mean liquid saving', 'liquid equity share', 'cumulative % bankrupt'};
nr = size(rows, 1);
fig = figure('Visible', 'off', 'Position', [30 30 2300 500 * nr + 80], 'Color', 'w');
tl  = tiledlayout(fig, nr, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
name = 'Renter'; if strcmp(arm, 'owner'), name = 'Owner, maintenance on the current value'; end
title(tl, {sprintf('%s: each grid axis doubled on its own (absorbing floor EUR %s; black: %s)', name, group(c_min), base_label), ...
    'Step 16, active-set. Means over solvent households, medians for consumption; multiples of entry income; solve minutes in the legends'}, ...
    'FontSize', 13, 'FontWeight', 'bold');
seen = {};
T = table();
T = [T; row_of(R0, base_label, R0)];
for i = 1:nr
    runs = rows{i, 2};
    rs = cellfun(@(c) case_load(16, arm, [c suf]), runs(:, 1), 'UniformOutput', false);
    for n = 1:numel(rs)
        if ~isempty(rs{n}) && ~any(strcmp(seen, runs{n, 1}))
            T = [T; row_of(rs{n}, runs{n, 2}, R0)]; %#ok<AGROW>
            seen{end+1} = runs{n, 1}; %#ok<AGROW>
        end
    end
    for q = 1:4
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9.5; ax.XLim = [25 100];
        if q == 1
            sm = R0.summary;
            plot(ax, sm.ages, sm.Y.p50 / sm.Y0, '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 1.1, 'DisplayName', 'gross income (median)');
            plot(ax, sm.ages, sm.net_income.p50 / sm.Y0, '--', 'Color', [0.65 0.65 0.65], 'LineWidth', 1.1, 'DisplayName', 'net income (median)');
        end
        draw(ax, R0, q, [0 0 0], 3.0, sprintf('%s (%.0f min)', base_label, R0.timing.solve_sec / 60));
        for n = 1:numel(rs)
            if isempty(rs{n}), continue; end
            draw(ax, rs{n}, q, cols(n, :), 1.7, sprintf('%s (%.0f min)', runs{n, 2}, rs{n}.timing.solve_sec / 60));
        end
        xline(ax, 67, 'k:', 'HandleVisibility', 'off');
        if q == 3, ylim(ax, [0 1]); end
        if q == 4, ylabel(ax, '% of households'); elseif q == 3, ylabel(ax, 'share'); else, ylabel(ax, 'times entry income'); end
        if q == 1, legend(ax, 'Location', 'best', 'FontSize', 8); end
        title(ax, sprintf('%s: %s', rows{i, 1}, ttl{q}), 'FontSize', 10);
        if i == nr, xlabel(ax, 'Age'); end
    end
end
out = fullfile(num.dir, 'summary_step16', sprintf('16_cmin%d_%s_axis_study.png', c_min, arm));
exportgraphics(fig, out, 'Resolution', 120);
close(fig);
fprintf('Wrote %s\n\n', out);
fprintf('%-16s %-14s %8s %14s %14s %12s %12s\n', 'run', 'grid points', 'minutes', 'peak saving', 'bankrupt 85', 'C at 30', 'C at 70');
for i = 1:height(T)
    fprintf('%-16s %-14s %8.0f %8.2f (%+5.1f%%) %6.1f%% (%+5.1f) %6.3f (%+5.1f%%) %6.3f (%+5.1f%%)\n', T.run(i), T.nodes(i), T.minutes(i), ...
        T.peak_X(i), T.peak_X_pct(i), T.bkr85(i), T.bkr85_pts(i), T.C30(i), T.C30_pct(i), T.C70(i), T.C70_pct(i));
end
end

% ------------------------------------------------------------------------
function r = row_of(R, label, R0)
s = R.summary; s0 = R0.summary; p = R.p;
a = s.ages;
pk = max(s.X.mean) / s.Y0; pk0 = max(s0.X.mean) / s0.Y0;
b = 100 * s.floored(a == 85); b0 = 100 * s0.floored(a == 85);
c30 = s.C.p50(a == 30) / s.Y0; c300 = s0.C.p50(a == 30) / s0.Y0;
c70 = s.C.p50(a == 70) / s.Y0; c700 = s0.C.p50(a == 70) / s0.Y0;
r = table(string(label), string(sprintf('%dx%dx%dx%d', p.N_u1, p.N_u2, p.N_u3, p.N_q)), R.timing.solve_sec / 60, ...
    pk, 100 * (pk / pk0 - 1), b, b - b0, c30, 100 * (c30 / c300 - 1), c70, 100 * (c70 / c700 - 1), ...
    'VariableNames', {'run', 'nodes', 'minutes', 'peak_X', 'peak_X_pct', 'bkr85', 'bkr85_pts', 'C30', 'C30_pct', 'C70', 'C70_pct'});
end

function draw(ax, r, q, col, lw, label)
sm = r.summary;
switch q
    case 1, y = sm.C.p50 / sm.Y0;
    case 2, y = sm.X.mean / sm.Y0;
    case 3, y = sm.pi; y(end) = NaN;
    case 4, y = 100 * sm.floored;
end
plot(ax, sm.ages, y, '-', 'Color', col, 'LineWidth', lw, 'DisplayName', label);
end

function s = group(x)
s = regexprep(sprintf('%d', round(x)), '(\d)(?=(\d{3})+$)', '$1,');
end
