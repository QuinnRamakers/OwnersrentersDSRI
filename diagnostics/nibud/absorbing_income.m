function absorbing_income(c_min)
%ABSORBING_INCOME  Net income after housing costs at step 16, and that of the households who go bankrupt.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       absorbing_income                    % c_min = 8,000
%
%   Net income after housing costs is take-home income (wages after
%   contributions and tax, or the first pillar after tax), plus the annuity
%   after tax, less rent or maintenance and the mortgage payment (sim.disp_inc).
%   It depends on no choice: income, the pension pot, the house or rent index
%   and the mortgage follow their own processes. The two panels of an arm, with
%   the yearly top-up and with the absorbing floor, draw the same shocks, so the
%   top-up panel gives every household's net income, also in the years after
%   it went bankrupt in the other panel (where its income, pot and house are
%   gone). The script checks that the two agree wherever the household is
%   solvent. Uses the summary-grid solves of absorbing_economics. Writes, in
%   summary_step16/ next to the ladder results:
%     16_net_income_distribution.png   net income by age: mean, median and the
%                                      5-95, 10-90 and 25-75 percentile bands,
%                                      with the floor of the arm's median
%                                      household; below, the distribution of
%                                      net income over the household's own
%                                      floor (below zero, 0-1, 1-2, 2-4, over 4
%                                      times), with the share bankrupt by that
%                                      age under the absorbing floor
%     16_net_income_bankrupt.png       the households that go bankrupt: net
%                                      income and the floor in the years around
%                                      bankruptcy, the ratio of the two in the
%                                      year of bankruptcy, and net income by age
%                                      against the households that never do
%   and prints the main numbers. Euros of 2025.

arguments
    c_min (1,1) double = 8000
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'summary_step16');
if ~isfolder(out), mkdir(out); end

arms = struct('arm', {'owner', 'owner', 'renter'}, ...
    'base', {'pow3_16x16_lim_u3p2_qn4_nosweep', 'pow3_16x16_lim_u3p2_qn4_nosweep', 'pow3_16x16_lim_u3p2_u3n20'}, ...
    'mop', {'', '_mop', ''}, ...
    'label', {'Owner, maintenance on the current value', 'Owner, maintenance on the purchase price', 'Renter'}, ...
    'short', {'Owner, current value', 'Owner, purchase price', 'Renter'});
na = numel(arms);
sc = 1e-3;                                       % thousand euros
D = struct([]);
for a = 1:na
    A = arms(a);
    r0 = case_load(16, A.arm, [A.base A.mop]);
    r1 = case_load(16, A.arm, sprintf('%s_cmin%d%s', A.base, c_min, A.mop));
    assert(~isempty(r0) && ~isempty(r1), 'absorbing_income:missing', '%s is not solved at c_min %d.', A.label, c_min);
    s0 = figures.panel_data(r0).sim;
    s1 = figures.panel_data(r1).sim;
    solv = ~s1.absorbed;
    assert(isequal(s0.Y, s1.Y), 'absorbing_income:shocks', '%s: the two panels have different incomes.', A.label);
    dev = max(abs(s0.disp_inc(solv) - s1.disp_inc(solv)));
    assert(dev <= 1e-9 * max(abs(s0.disp_inc(:))), 'absorbing_income:net_income', ...
        '%s: net income differs between the panels in solvent years by %.3g.', A.label, dev);
    p = r1.p;
    ages = s1.ages(:).';
    NI = s0.disp_inc;                            % net income after housing, every household and year
    F  = p.phi_path(:).' .* s1.Y;                % the floor that applies to a solvent household
    Fb = F; Fb(s1.absorbed) = s1.C(s1.absorbed); % ... and the level a bankrupt household consumes
    Ybar = exp(config.income_profile(p)).';
    D(a).label = A.label; D(a).short = A.short; D(a).ages = ages; D(a).NI = NI; D(a).F = F; D(a).Fb = Fb;
    D(a).X = s1.X; D(a).abs_age = s1.abs_age; D(a).floor_med = p.phi_path(:).' .* Ybar;
    D(a).bankrupt = mean(s1.absorbed, 1);
end

% --- Figure 1: the distribution of net income after housing costs by age
fig = figure('Visible', 'off', 'Position', [30 30 2200 1150], 'Color', 'w');
tl  = tiledlayout(fig, 2, na, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'Step 16: net income after housing costs by age (every household, as if never bankrupt)', ...
    sprintf(['Take-home income and annuity after tax, less rent, maintenance and mortgage; thousand euros of 2025; ' ...
     'red: the absorbing floor at c_{min} = EUR %s for the arm''s median-income household'], group(c_min))}, ...
    'FontSize', 13, 'FontWeight', 'bold');
blue = [0.20 0.40 0.75];
rel_edges = [-Inf 0 1 2 4 Inf];
rel_names = {'below zero', '0-1 x floor', '1-2 x floor', '2-4 x floor', 'over 4 x floor'};
rel_cols  = [0.70 0.10 0.10; 0.95 0.55 0.35; 0.99 0.85 0.55; 0.70 0.82 0.92; 0.35 0.55 0.80];
for a = 1:na
    x = D(a).ages; M = D(a).NI * sc;
    q = prctile(M, [5 10 25 50 75 90 95], 1);
    ax = nexttile(tl, a); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 10; ax.XLim = [25 100];
    band(ax, x, q(1, :), q(7, :), blue, 0.12, '5th-95th percentile');
    band(ax, x, q(2, :), q(6, :), blue, 0.20, '10th-90th');
    band(ax, x, q(3, :), q(5, :), blue, 0.30, '25th-75th');
    plot(ax, x, mean(M, 1), '-', 'Color', blue * 0.7, 'LineWidth', 2.2, 'DisplayName', 'mean');
    plot(ax, x, q(4, :), '--', 'Color', blue * 0.7, 'LineWidth', 1.6, 'DisplayName', 'median');
    plot(ax, x, D(a).floor_med * sc, '-', 'Color', [0.80 0.15 0.15], 'LineWidth', 1.8, ...
        'DisplayName', 'floor, median-income household');
    yline(ax, 0, 'k-', 'HandleVisibility', 'off'); xline(ax, 67, 'k:', 'HandleVisibility', 'off');
    ylabel(ax, 'thousand EUR (2025)'); title(ax, D(a).label, 'FontSize', 11);
    if a == 1, legend(ax, 'Location', 'northwest', 'FontSize', 9); end

    % Net income relative to the household's own floor, phi_t Y_t: the whole
    % distribution, stacked, with the share already bankrupt on top
    ax = nexttile(tl, na + a); hold(ax, 'on'); box(ax, 'on'); ax.FontSize = 10; ax.XLim = [25 100];
    ratio = D(a).NI ./ D(a).F;
    sh = zeros(numel(rel_edges) - 1, numel(x));
    for b = 1:numel(rel_edges) - 1
        sh(b, :) = 100 * mean(ratio >= rel_edges(b) & ratio < rel_edges(b + 1), 1);
    end
    h = area(ax, x, sh.', 'EdgeColor', 'none');
    for b = 1:numel(h)
        h(b).FaceColor = rel_cols(b, :); h(b).DisplayName = rel_names{b};
    end
    plot(ax, x, 100 * D(a).bankrupt, 'k-', 'LineWidth', 2.4, ...
        'DisplayName', 'bankrupt by this age, absorbing floor (cumulative)');
    xline(ax, 67, 'k:', 'HandleVisibility', 'off');
    ylim(ax, [0 100]); ax.Layer = 'top'; grid(ax, 'on');
    ylabel(ax, '% of households'); xlabel(ax, 'Age');
    title(ax, sprintf('%s: net income after housing over own floor', D(a).short), 'FontSize', 11);
    if a == 1
        lg = legend(ax, 'Orientation', 'horizontal', 'FontSize', 10);
        lg.Layout.Tile = 'south';
    end
end
exportgraphics(fig, fullfile(out, '16_net_income_distribution.png'), 'Resolution', 140);
close(fig);

% --- Figure 2: the households that go bankrupt
K = -15:10;
fig = figure('Visible', 'off', 'Position', [30 30 2200 1500], 'Color', 'w');
tl  = tiledlayout(fig, na, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf(['Step 16, absorbing floor at c_{min} = EUR %s: net income after housing costs of the households ' ...
     'that go bankrupt'], group(c_min)), ...
    ['Net income as if never bankrupt; the floor is phi_t Y_t while solvent and the fixed consumption after ' ...
     'bankruptcy; thousand euros of 2025']}, 'FontSize', 13, 'FontWeight', 'bold');
fprintf('\nHouseholds that go bankrupt, c_min = %d\n', c_min);
for a = 1:na
    T = numel(D(a).ages);
    ib = find(~isnan(D(a).abs_age)); t0 = D(a).abs_age(ib) - D(a).ages(1) + 1;
    [EN, EF, EX] = deal(nan(numel(ib), numel(K)));
    for j = 1:numel(K)
        t = t0 + K(j); ok = t >= 1 & t <= T;
        k = sub2ind(size(D(a).NI), ib(ok), t(ok));
        EN(ok, j) = D(a).NI(k); EF(ok, j) = D(a).Fb(k); EX(ok, j) = D(a).X(k);
    end
    kk = sub2ind(size(D(a).NI), ib, t0);
    ratio = D(a).NI(kk) ./ D(a).F(kk);

    % (a) around the year of bankruptcy
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 10;
    if ~isempty(ib)
        qn = prctile(EN * sc, [10 50 90], 1);
        band(ax, K, qn(1, :), qn(3, :), blue, 0.20, 'net income, 10th-90th');
        plot(ax, K, qn(2, :), '-', 'Color', blue * 0.7, 'LineWidth', 2.2, 'DisplayName', 'net income, median');
        plot(ax, K, median(EF * sc, 1, 'omitnan'), '-', 'Color', [0.80 0.15 0.15], 'LineWidth', 2.2, ...
            'DisplayName', 'floor, median');
        plot(ax, K, median(EX * sc, 1, 'omitnan'), '-', 'Color', [0.30 0.60 0.30], 'LineWidth', 1.8, ...
            'DisplayName', 'liquid wealth, median');
    end
    xline(ax, 0, 'k--', 'HandleVisibility', 'off'); yline(ax, 0, 'k-', 'HandleVisibility', 'off');
    xlabel(ax, 'Years from bankruptcy'); ylabel(ax, 'thousand EUR (2025)');
    title(ax, sprintf('%s: %d of %d bankrupt', D(a).label, numel(ib), size(D(a).NI, 1)), 'FontSize', 10);
    legend(ax, 'Location', 'northwest', 'FontSize', 8);

    % (b) net income over the floor in the year of bankruptcy
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 10;
    if ~isempty(ib)
        histogram(ax, min(max(ratio, -2), 4), -2:0.1:4, 'Normalization', 'percentage', ...
            'FaceColor', blue, 'EdgeColor', 'none');
    end
    xline(ax, 1, 'r-', 'LineWidth', 1.8, 'HandleVisibility', 'off'); xline(ax, 0, 'k-', 'HandleVisibility', 'off');
    xlabel(ax, 'net income after housing / floor, year of bankruptcy (clipped to [-2, 4])');
    ylabel(ax, '% of bankrupt households');
    title(ax, sprintf('Below the floor %.0f%%, below zero %.0f%%; median ratio %.2f', ...
        100 * mean(ratio < 1), 100 * mean(ratio < 0), median(ratio)), 'FontSize', 10);

    % (c) by age, the households that ever go bankrupt against those that never do
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 10; ax.XLim = [25 100];
    x = D(a).ages; never = isnan(D(a).abs_age);
    plot(ax, x, median(D(a).NI(never, :), 1) * sc, '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 2, ...
        'DisplayName', 'net income, never bankrupt (median)');
    if ~isempty(ib)
        plot(ax, x, median(D(a).NI(ib, :), 1) * sc, '-', 'Color', blue * 0.7, 'LineWidth', 2, ...
            'DisplayName', 'net income, bankrupt at some age (median)');
        plot(ax, x, median(D(a).F(ib, :), 1) * sc, '-', 'Color', [0.80 0.15 0.15], 'LineWidth', 1.8, ...
            'DisplayName', 'their floor phi_t Y_t (median)');
    end
    yline(ax, 0, 'k-', 'HandleVisibility', 'off'); xline(ax, 67, 'k:', 'HandleVisibility', 'off');
    xlabel(ax, 'Age'); ylabel(ax, 'thousand EUR (2025)');
    title(ax, 'By age: households that go bankrupt and those that never do', 'FontSize', 10);
    legend(ax, 'Location', 'best', 'FontSize', 8);

    if isempty(ib), continue; end
    fprintf('%-42s %5d bankrupt, median age %d; in the year of bankruptcy: net income / floor median %.2f, below 1 %.0f%%, below 0 %.0f%%\n', ...
        D(a).label, numel(ib), round(median(D(a).abs_age(ib))), median(ratio), 100 * mean(ratio < 1), 100 * mean(ratio < 0));
    fprintf('%-42s median net income (kEUR) at -10 / -5 / -1 / 0 / +5: %s; floor %s; liquid wealth %s\n', '', ...
        mat2str(round(median(EN(:, ismember(K, [-10 -5 -1 0 5])) * sc, 1, 'omitnan'), 1)), ...
        mat2str(round(median(EF(:, ismember(K, [-10 -5 -1 0 5])) * sc, 1, 'omitnan'), 1)), ...
        mat2str(round(median(EX(:, ismember(K, [-10 -5 -1 0 5])) * sc, 1, 'omitnan'), 1)));
end
exportgraphics(fig, fullfile(out, '16_net_income_bankrupt.png'), 'Resolution', 140);
close(fig);

% Distribution by age, printed
fprintf('\nNet income after housing (kEUR): mean, p10 / p50 / p90; %% below own floor\n');
for a = 1:na
    x = D(a).ages; M = D(a).NI * sc; q = prctile(M, [10 50 90], 1);
    for age = [25 35 45 55 66 67 75 85 95]
        m = x == age;
        fprintf('  %-42s %3d  %6.1f   %6.1f / %6.1f / %6.1f   %5.1f%%\n', D(a).label, age, mean(M(:, m)), q(:, m), ...
            100 * mean(D(a).NI(:, m) < D(a).F(:, m)));
    end
end
end

function band(ax, x, lo, hi, col, alpha, name)
fill(ax, [x, fliplr(x)], [lo, fliplr(hi)], col, 'FaceAlpha', alpha, 'EdgeColor', 'none', 'DisplayName', name);
end

function s = group(x)
s = regexprep(sprintf('%d', round(x)), '(\d)(?=(\d{3})+$)', '$1,');
end
