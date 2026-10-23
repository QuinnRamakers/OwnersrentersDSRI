function absorbing_grid(c_min)
%ABSORBING_GRID  Step 16 grid test with the absorbing floor, against the same test with the top-up.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       absorbing_grid                      % c_min = 8,000
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
%   and prints the gaps by age band for both floors, and the main quantities.

arguments
    c_min (1,1) double = 8000
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'summary_step16');
if ~isfolder(out), mkdir(out); end
suf = sprintf('_cmin%d', c_min);
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
title(tl, {sprintf('Step 16: grid test with the absorbing floor at c_{min} = EUR %d (solid) and with the yearly top-up (dashed)', c_min), ...
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
exportgraphics(fig, fullfile(out, '16_absorbing_grid_gaps.png'), 'Resolution', 150);
close(fig);

for k = 1:2
    X = A{k};
    figures.compare(X.abs, X.labels, sprintf('Step 16, %s, absorbing floor at c_min = EUR %d: grids', ...
        lower(X.title), c_min), fullfile(out, sprintf('16_absorbing_%s_grid_ladder.png', X.arm)));
    close all
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

function s = gap_row(G)
s = '';
for k = 1:numel(G.C)
    s = [s sprintf('  %5.1f/%5.3f', 100 * G.C(k), G.pi(k))]; %#ok<AGROW>
end
end
