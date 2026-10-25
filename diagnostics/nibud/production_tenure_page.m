function production_tenure_page(arm, c_min)
%PRODUCTION_TENURE_PAGE  Every grid of one tenure at c_min as life cycles, one row per group.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       production_tenure_page('renter')        % c_min = 5,000
%
%   Loads the saved step-16 solves (case_load; nothing is solved). Rows: the
%   wealth grid (u1 x u2), the pension-against-housing axis (u3), the search
%   routine and quadrature, and today's production numerics. Columns: median
%   consumption (grey: median gross and net income), mean liquid saving, the
%   liquid equity share and the cumulative share bankrupt. The reference
%   (the candidate grid where one is solved, else the finest wealth grid) is
%   the thick black line in every row. Solve minutes are in the legends.
%   Writes summary_step16/16_cmin<n>_<arm>_all_grids.png.

arguments
    arm (1,:) char {mustBeMember(arm, {'owner', 'renter'})}
    c_min (1,1) double = 5000
end

num = ladder.numerics('standard');
suf = sprintf('_cmin%d', c_min);
if strcmp(arm, 'renter')
    ref = {'pow3_32x32_lim_u3even_u3n40%s_as_nc11', 'candidate: 32x32, u3 40 even, active-set'};
    rows = {
      'Wealth grid (u1 x u2), u3 at 10', ...
        {'pow3_16x16_lim_u3p2%s', '16x16'; 'pow3_32x32_lim_u3p2%s', '32x32'; 'pow3_48x48_lim_u3p2%s', '48x48'}
      'Pension-against-rent axis (u3), on the 16x16 wealth grid', ...
        {'pow3_16x16_lim_u3p2%s', 'u3 10'; 'pow3_16x16_lim_u3p2_u3n20%s', 'u3 20'; ...
         'pow3_16x16_lim_u3p2_u3n40%s', 'u3 40'; 'pow3_16x16_lim_u3p2_u3n80%s', 'u3 80'; ...
         'pow3_16x16_lim_u3even_u3n20%s_as_nc11', 'u3 20 even'; 'pow3_16x16_lim_u3even_u3n40%s_as_nc11', 'u3 40 even'}
      'Search routine (32x32) and quadrature (16x16)', ...
        {'pow3_32x32_lim_u3p2%s', '32x32, interior-point'; 'pow3_32x32_lim_u3p2%s_as_nc11', '32x32, active-set'; ...
         'pow3_16x16_lim_u3p2%s', '16x16, 5 nodes'; 'pow3_16x16_lim_u3p2_gh7%s', '16x16, 7 nodes'}
      'Today''s production numerics', ...
        {'uniform_20x20_u3n12%s', 'uniform 20x20, u3 12'}};
else
    ref = {'pow3_32x32_lim_u3p2_qn4%s', '32x32 (finest wealth grid)'};
    rows = {
      'Wealth grid (u1 x u2), u3 at 10', ...
        {'pow3_16x16_lim_u3p2_qn4%s', '16x16'; 'pow3_24x24_lim_u3p2_qn4%s', '24x24'}
      'Pension-against-housing axis (u3), on the 16x16 wealth grid', ...
        {'pow3_16x16_lim_u3p2_qn4%s', 'u3 10'; 'pow3_16x16_lim_u3p2_qn4_u3n20%s', 'u3 20'; ...
         'pow3_16x16_lim_u3p2_qn4_u3n40%s', 'u3 40'; 'pow3_16x16_lim_u3p2_qn4_u3n80%s_as_nc11', 'u3 80'; ...
         'pow3_16x16_lim_u3even_qn4_u3n20%s_as_nc11', 'u3 20 even'}
      'Search routine (24x24) and quadrature (16x16)', ...
        {'pow3_24x24_lim_u3p2_qn4%s', '24x24, interior-point'; 'pow3_24x24_lim_u3p2_qn4%s_as_nc11', '24x24, active-set'; ...
         'pow3_16x16_lim_u3p2_qn4%s', '16x16, 5 nodes'; 'pow3_16x16_lim_u3p2_qn4_gh7%s', '16x16, 7 nodes'}
      'Today''s production numerics', ...
        {'uniform_20x20_u3n12%s', 'uniform 20x20, u3 12, q 8'}};
end
R0 = case_load(16, arm, sprintf(ref{1}, suf));
assert(~isempty(R0), 'production_tenure_page:missing', 'the reference %s is not solved.', ref{2});

cols = [0.20 0.55 0.85; 0.85 0.45 0.10; 0.60 0.15 0.55; 0.25 0.65 0.35; 0.85 0.15 0.15; 0.55 0.40 0.10];
ttl = {'median consumption', 'mean liquid saving', 'liquid equity share', 'cumulative % bankrupt'};
nr = size(rows, 1);
fig = figure('Visible', 'off', 'Position', [30 30 2300 520 * nr + 80], 'Color', 'w');
tl  = tiledlayout(fig, nr, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
name = 'Renter'; if strcmp(arm, 'owner'), name = 'Owner, maintenance on the current value'; end
title(tl, {sprintf('%s: every grid at the absorbing floor of EUR %s, as life cycles (black: %s)', name, group(c_min), ref{2}), ...
    'Step 16. Means over solvent households, medians for consumption; multiples of entry income; solve minutes in the legends'}, ...
    'FontSize', 13, 'FontWeight', 'bold');
for i = 1:nr
    runs = rows{i, 2};
    rs = cellfun(@(c) case_load(16, arm, sprintf(c, suf)), runs(:, 1), 'UniformOutput', false);
    for q = 1:4
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9.5; ax.XLim = [25 100];
        if q == 1
            sm = R0.summary;
            plot(ax, sm.ages, sm.Y.p50 / sm.Y0, '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 1.1, 'DisplayName', 'gross income (median)');
            plot(ax, sm.ages, sm.net_income.p50 / sm.Y0, '--', 'Color', [0.65 0.65 0.65], 'LineWidth', 1.1, 'DisplayName', 'net income (median)');
        end
        draw(ax, R0, q, [0 0 0], 3.0, sprintf('%s (%.0f min)', ref{2}, R0.timing.solve_sec / 60));
        for n = 1:numel(rs)
            if isempty(rs{n}), continue; end
            draw(ax, rs{n}, q, cols(n, :), 1.6, sprintf('%s (%.0f min)', runs{n, 2}, rs{n}.timing.solve_sec / 60));
        end
        xline(ax, 67, 'k:', 'HandleVisibility', 'off');
        if q == 3, ylim(ax, [0 1]); end
        if q == 4, ylabel(ax, '% of households'); elseif q == 3, ylabel(ax, 'share'); else, ylabel(ax, 'times entry income'); end
        if q == 1, legend(ax, 'Location', 'best', 'FontSize', 8); end
        title(ax, sprintf('%s: %s', rows{i, 1}, ttl{q}), 'FontSize', 10);
        if i == nr, xlabel(ax, 'Age'); end
    end
end
out = fullfile(num.dir, 'summary_step16', sprintf('16_cmin%d_%s_all_grids.png', c_min, arm));
exportgraphics(fig, out, 'Resolution', 120);
close(fig);
fprintf('Wrote %s\n', out);
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
