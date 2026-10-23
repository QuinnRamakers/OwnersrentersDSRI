function absorbing_grid(c_min, opts)
%ABSORBING_GRID  Step 16 grid test with the absorbing floor, against the same test with the top-up.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       absorbing_grid                      % c_min = 8,000
%       absorbing_grid(8000, extra = '_exact')   % the solves with the exact trigger
%
%   The 20 October grid comparisons (maint_grid_compare, renter_grid_compare)
%   with every case solved again with the absorbing floor (suffix _cmin<n>).
%   Owner, maintenance on the current value: the summary grid (bunched 16x16,
%   q at 4, no sweep) and 24x24 (q at 4) against 32x32, and against 24x24 with
%   u3 at 20 points. Renter: the summary grid (16x16, u3 at 20) and 32x32
%   against 48x48, and the summary grid against 16x16 with u3 at 40. Gaps are
%   policy_gaps: each grid's policies at the reference's households, so the
%   wealth carried from younger ages is left out. Stop rule: 2% in
%   consumption and 0.02 in the liquid equity share. Writes, in
%   summary_step16/ next to the ladder results:
%     16_absorbing_grid_gaps.png           gaps by age, top-up dashed, absorbing solid
%     16_absorbing_owner_grid_ladder.png   the owner's grids overlaid, absorbing floor
%     16_absorbing_renter_grid_ladder.png  the renter's grids overlaid, absorbing floor
%     16_absorbing_<arm>_grids.png         the grids themselves (nodes on u1 as
%                                          W/Y, u2 and u3, against the band of
%                                          the households at four ages) and what
%                                          each changes in consumption, saving,
%                                          the equity share and bankruptcy
%   and prints the gaps by age band for both floors, and the main quantities.

arguments
    c_min (1,1) double = 8000
    opts.extra (1,:) char = ''
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'summary_step16');
if ~isfolder(out), mkdir(out); end
suf = sprintf('_cmin%d%s', c_min, opts.extra);       % opts.extra: more suffixes of the absorbing cases (_exact)
bands = {[26 39], [40 54], [55 66], [67 89], [90 95]};

% Cases: the grid, its label; then which grid is compared with which reference
O.arm = 'owner'; O.title = 'Owner, maintenance on the current value';
O.cases  = {'pow3_16x16_lim_u3p2_qn4_nosweep', 'pow3_24x24_lim_u3p2_qn4', 'pow3_32x32_lim_u3p2', ...
            'pow3_24x24_lim_u3p2_qn4_u3n20'};
O.labels = {'16x16 (summary)', '24x24', '32x32', '24x24, u3 at 20'};
O.pairs  = [1 3; 2 3; 1 4; 2 4];
Rt.arm = 'renter'; Rt.title = 'Renter';
Rt.cases  = {'pow3_16x16_lim_u3p2_u3n20', 'pow3_32x32_lim_u3p2', 'pow3_48x48_lim_u3p2', 'pow3_16x16_lim_u3p2_u3n40'};
Rt.labels = {'16x16, u3 at 20 (summary)', '32x32', '48x48', '16x16, u3 at 40'};
Rt.pairs  = [1 3; 2 3; 1 4];
A = {O, Rt};

for k = 1:2
    X = A{k};
    X.off = cellfun(@(c) case_load(16, X.arm, c), X.cases, 'UniformOutput', false);
    X.abs = cellfun(@(c) case_load(16, X.arm, [c suf]), X.cases, 'UniformOutput', false);
    assert(~any(cellfun(@isempty, [X.off, X.abs])), 'absorbing_grid:missing', 'a %s case is not solved.', X.arm);
    for i = 1:size(X.pairs, 1)
        X.G_off{i} = policy_gaps(X.off{X.pairs(i, 1)}, X.off{X.pairs(i, 2)}, bands);
        X.G_abs{i} = policy_gaps(X.abs{X.pairs(i, 1)}, X.abs{X.pairs(i, 2)}, bands);
    end
    A{k} = X;
end

% Gaps by age
cols = [0.85 0.45 0.10; 0.20 0.55 0.85; 0.60 0.15 0.55; 0.25 0.65 0.35];
fig = figure('Visible', 'off', 'Position', [30 30 2200 1100], 'Color', 'w');
tl  = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
how = ''; if contains(opts.extra, '_exact'), how = ', exact trigger at the quadrature nodes'; end
title(tl, {sprintf('Step 16: grid test with the absorbing floor at c_{min} = EUR %d%s (solid) and with the yearly top-up (dashed)', c_min, how), ...
    'Each grid''s policies at the reference''s households; stop rule 2% in consumption and 0.02 in the liquid equity share'}, ...
    'FontSize', 13, 'FontWeight', 'bold');
for k = 1:2
    X = A{k};
    for col = 1:3
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9; ax.XLim = [25 100];
        for i = 1:size(X.pairs, 1)
            nm = sprintf('%s vs %s', X.labels{X.pairs(i, 1)}, X.labels{X.pairs(i, 2)});
            for f = 1:2
                if f == 1, G = X.G_off{i}; ls = '--'; lw = 1.1; hv = 'off';
                else, G = X.G_abs{i}; ls = '-'; lw = 1.9; hv = 'on'; end
                switch col
                    case 1, y = 100 * G.C_age;
                    case 2, y = G.pi_age;
                    case 3, y = [];
                end
                if ~isempty(y)
                    y(y <= 0) = NaN;
                    plot(ax, G.ages, y, ls, 'Color', cols(i, :), 'LineWidth', lw, 'DisplayName', nm, ...
                        'HandleVisibility', hv);
                end
            end
        end
        switch col
            case 1
                set(ax, 'YScale', 'log'); yline(ax, 2, 'k:', 'HandleVisibility', 'off');
                ylabel(ax, '|mean C / reference - 1|, %'); t = 'consumption gap';
                legend(ax, 'Location', 'northeast', 'FontSize', 8);
            case 2
                set(ax, 'YScale', 'log'); yline(ax, 0.02, 'k:', 'HandleVisibility', 'off');
                ylabel(ax, '|difference in mean share|'); t = 'liquid equity share gap';
            case 3
                for i = 1:numel(X.cases)
                    s = X.abs{i}.summary; s0 = X.off{i}.summary;
                    plot(ax, s.ages, s.C.p50 / s.Y0, '-', 'Color', cols(i, :), 'LineWidth', 1.8, ...
                        'DisplayName', X.labels{i});
                    plot(ax, s0.ages, s0.C.p50 / s0.Y0, '--', 'Color', cols(i, :), 'LineWidth', 1.0, ...
                        'HandleVisibility', 'off');
                end
                ylabel(ax, 'times entry income'); t = 'median consumption in each grid''s panel';
                legend(ax, 'Location', 'northwest', 'FontSize', 8);
        end
        title(ax, sprintf('%s: %s', X.title, t), 'FontSize', 10);
        if k == 2, xlabel(ax, 'Age'); end
    end
end
exportgraphics(fig, fullfile(out, ['16_absorbing_grid_gaps' opts.extra '.png']), 'Resolution', 150);
close(fig);

for k = 1:2
    X = A{k};
    figures.compare(X.abs, X.labels, sprintf('Step 16, %s, absorbing floor at c_min = EUR %d: grids', ...
        lower(X.title), c_min), fullfile(out, sprintf('16_absorbing_%s_grid_ladder%s.png', X.arm, opts.extra)));
    close all
    grid_page(X, c_min, fullfile(out, sprintf('16_absorbing_%s_grids%s.png', X.arm, opts.extra)));
end

% Tables
head = sprintf('%-44s', 'consumption % / share');
for b = bands, head = [head sprintf('  %5d-%-5d', b{1}(1), b{1}(2))]; end %#ok<AGROW>
for k = 1:2
    X = A{k};
    fprintf('\n%s: policies at the reference''s households\n%s\n', X.title, head);
    for i = 1:size(X.pairs, 1)
        nm = sprintf('%s vs %s', X.labels{X.pairs(i, 1)}, X.labels{X.pairs(i, 2)});
        fprintf('%-44s%s\n', [nm ', top-up'], gap_row(X.G_off{i}));
        fprintf('%-44s%s\n', [nm ', absorbing'], gap_row(X.G_abs{i}));
    end
    % The share weighted by liquid saving (case_load's piw), each grid's own
    % panel: households with almost nothing saved carry no weight
    fprintf('\n%s: largest gap in the equity share weighted by liquid saving, each grid''s own panel\n', X.title);
    for i = 1:size(X.pairs, 1)
        nm = sprintf('%s vs %s', X.labels{X.pairs(i, 1)}, X.labels{X.pairs(i, 2)});
        for f = 1:2
            if f == 1, Q = X.off; tag = 'top-up'; else, Q = X.abs; tag = 'absorbing'; end
            a = Q{X.pairs(i, 2)}.summary.ages;
            d = abs(Q{X.pairs(i, 1)}.piw - Q{X.pairs(i, 2)}.piw);
            v = cellfun(@(b) max([d(a >= b(1) & a <= b(2)), NaN], [], 'omitnan'), bands);
            fprintf('%-44s%s\n', [nm ', ' tag], sprintf('  %11.3f', v));
        end
    end
    fprintf('\n%-36s %5s %8s %8s %6s %8s\n', '', 'age', 'C/Y0', 'X/Y0', 'pi', 'fl/bkr');
    for i = 1:numel(X.cases)
        for f = 1:2
            if f == 1, r = X.off{i}; tag = 'top-up'; else, r = X.abs{i}; tag = 'absorbing'; end
            s = r.summary;
            for age = [30 40 55 66 80 95]
                m = s.ages == age;
                fprintf('%-36s %5d %8.2f %8.2f %6.2f %7.1f%%\n', [X.labels{i} ', ' tag], age, ...
                    s.C.p50(m) / s.Y0, s.X.mean(m) / s.Y0, s.pi(m), 100 * s.floored(m));
            end
        end
    end
    for i = 1:numel(X.cases)
        for f = 1:2
            if f == 1, r = X.off{i}; tag = 'top-up'; else, r = X.abs{i}; tag = 'absorbing'; end
            c = r.checks;
            fprintf('%-36s fl/bkr %.2f%%  entry %.3f  bound 25-39 %.1f%%  off-grid %s  solve %.0f s\n', ...
                [X.labels{i} ', ' tag], 100 * c.floored_share, c.ce_entry, 100 * c.c_bound_25_39, ...
                mat2str(c.offgrid), r.timing.solve_sec);
        end
    end
end
end

function grid_page(X, c_min, file)
%GRID_PAGE  One tenure's grids and what each changes. Top: the nodes of each
%   grid on u1 (as total resources over income, W/Y = 1/u1), u2 and u3, and
%   the 5th-95th percentile of the solvent households at four ages on the
%   finest u1 x u2 grid with the floor. Bottom: by age, each grid with the
%   absorbing floor (solid) and the top-up (dashed).
n = numel(X.cases);
cols = [0.85 0.45 0.10; 0.20 0.55 0.85; 0.60 0.15 0.55; 0.25 0.65 0.35];
acol = [0.55 0.55 0.55; 0.35 0.35 0.35; 0.20 0.20 0.20; 0.05 0.05 0.05];
band_ages = [30 45 65 85];
iref = 3;                                        % the finest u1 x u2 grid
s = figures.panel_data(X.abs{iref}).sim;
t = band_ages - s.ages(1) + 1;
ok = ~s.absorbed(:, t);
sAH = s.sA(:, t) + s.sH(:, t);
coord = {1 ./ s.lambda(:, t), sAH ./ max(1 - s.lambda(:, t), 1e-12), s.sA(:, t) ./ max(sAH, 1e-12)};
ever = cell(1, n);                               % top-up: share ever floored by each age
for i = 1:n
    d = figures.panel_data(X.off{i}).sim;
    ever{i} = mean(cummax(d.floored, 2), 1);
end

fig = figure('Visible', 'off', 'Position', [30 30 2300 1250], 'Color', 'w');
tl  = tiledlayout(fig, 2, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('Step 16, %s: the grids and what they change (absorbing floor at c_{min} = EUR %d solid, yearly top-up dashed)', ...
    lower(X.title), c_min), ...
    sprintf(['Top: nodes of each grid; grey bars: 5th-95th percentile of the solvent households at ages %s ' ...
     '(%s grid, with the floor). Bottom: by age, in multiples of entry income'], ...
     strjoin(arrayfun(@num2str, band_ages, 'UniformOutput', false), ', '), X.labels{iref})}, ...
    'FontSize', 13, 'FontWeight', 'bold');
names = {'u1 as total resources / income, W/Y (log scale)', 'u2 = (pot + housing) / (W - Y)', ...
         'u3 = pot / (pot + housing)'};
fld = {'u1_grid', 'u2_grid', 'u3_grid'};
for j = 1:3
    ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on'); ax.FontSize = 9;
    for i = 1:n
        g = X.abs{i}.p.(fld{j})(:);
        if j == 1, g = 1 ./ g; end
        plot(ax, g, i * ones(size(g)), '|', 'Color', cols(i, :), 'MarkerSize', 14, 'LineWidth', 1.5);
    end
    for k = 1:numel(band_ages)
        v = coord{j}(ok(:, k), k);
        b = prctile(v, [5 95]);
        y = n + 0.6 + 0.35 * k;
        plot(ax, b, [y y], '-', 'Color', acol(k, :), 'LineWidth', 5);
        text(ax, b(2), y, sprintf('  %d', band_ages(k)), 'FontSize', 8, 'VerticalAlignment', 'middle');
    end
    set(ax, 'YDir', 'reverse', 'YTick', 1:n, 'YTickLabel', X.labels, 'YLim', [0.4, n + 0.9 + 0.35 * numel(band_ages)]);
    if j == 1, set(ax, 'XScale', 'log'); xlim(ax, [1 1e4]); else, xlim(ax, [0 1]); end
    grid(ax, 'on'); xlabel(ax, names{j}); title(ax, sprintf('(%s) %s nodes', char('a' + j - 1), ...
        extractBefore(names{j}, ' ')), 'FontSize', 10);
end
ax = nexttile(tl); axis(ax, 'off');
L = {'\bfGrid: nodes (u1 x u2 x u3 x q); solve minutes, top-up / floor\rm'};
for i = 1:n
    p = X.abs{i}.p;
    L{end+1} = sprintf('%s: %d x %d x %d x %d; %.0f / %.0f min', strrep(X.labels{i}, '_', '\_'), ...
        p.N_u1, p.N_u2, p.N_u3, p.N_q, X.off{i}.timing.solve_sec / 60, X.abs{i}.timing.solve_sec / 60); %#ok<AGROW>
end
L{end+1} = ''; L{end+1} = '\bfEntry value (x entry income), top-up / floor\rm';
for i = 1:n
    L{end+1} = sprintf('%s: %.3f / %.3f', strrep(X.labels{i}, '_', '\_'), X.off{i}.checks.ce_entry, ...
        X.abs{i}.checks.ce_entry); %#ok<AGROW>
end
L{end+1} = ''; L{end+1} = '\bfHousehold-years floored (top-up) / bankrupt (floor)\rm';
for i = 1:n
    L{end+1} = sprintf('%s: %.2f%% / %.2f%%', strrep(X.labels{i}, '_', '\_'), 100 * X.off{i}.checks.floored_share, ...
        100 * X.abs{i}.checks.floored_share); %#ok<AGROW>
end
L{end+1} = ''; L{end+1} = 'Off-grid lookups 0 in every solve';
text(ax, 0, 1, L, 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 9, 'Interpreter', 'tex');
title(ax, '(d) Settings and checks', 'FontSize', 10);

ttl = {'(e) median consumption', '(f) mean liquid saving (solvent)', '(g) liquid equity share (solvent)', ...
       '(h) cumulative % bankrupt (top-up: % ever floored)'};
for k = 1:4
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9; ax.XLim = [25 100];
    for i = 1:n
        for f = 1:2
            if f == 1, r = X.off{i}; ls = '--'; lw = 1.1; hv = 'off'; else, r = X.abs{i}; ls = '-'; lw = 1.9; hv = 'on'; end
            sm = r.summary; a = sm.ages;
            switch k
                case 1, y = sm.C.p50 / sm.Y0;
                case 2, y = sm.X.mean / sm.Y0;
                case 3, y = sm.pi; y(end) = NaN;
                case 4
                    y = 100 * sm.floored;
                    if f == 1, y = 100 * ever{i}; end
            end
            plot(ax, a, y, ls, 'Color', cols(i, :), 'LineWidth', lw, 'DisplayName', X.labels{i}, 'HandleVisibility', hv);
        end
    end
    xline(ax, 67, 'k:', 'HandleVisibility', 'off');
    if k == 3, ylim(ax, [0 1]); end
    if k == 4, ylabel(ax, '% of households'); elseif k < 3, ylabel(ax, 'times entry income'); else, ylabel(ax, 'share'); end
    xlabel(ax, 'Age'); title(ax, ttl{k}, 'FontSize', 10);
    if k == 1, legend(ax, 'Location', 'best', 'FontSize', 8); end
end
exportgraphics(fig, file, 'Resolution', 140);
close(fig);
end

function s = gap_row(G)
s = '';
for k = 1:numel(G.C)
    s = [s sprintf('  %5.1f/%5.3f', 100 * G.C(k), G.pi(k))]; %#ok<AGROW>
end
end
