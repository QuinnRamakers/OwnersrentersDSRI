function T = convergence_figure(steps, arm, ref_name, rules, file)
%CONVERGENCE_FIGURE  Gap to a reference grid against grid size, per step and rule.
%
%   T = convergence_figure([6 9 10 11 12], 'owner', 'pow3_128x128', ...
%                          {'uniform', 'pow2', 'pow3'}, 'conv_owner.png')
%
%   One column per step. Rows: the largest gap in the mean liquid equity share
%   at ages 40-66 and at 67-95, and in mean consumption (% of the reference)
%   at 40-66 and 67-95, each against the number of (u1, u2) grid points on a
%   log axis. One line per rule, through its sizes NxN (16, 24, 32, 48, 64,
%   96, 128; the ladder's standard result stands for uniform 16x16). The
%   dashed line is the ladder's stop rule (0.02, 2%). The reference is the
%   named case of each step; a step without it is left blank. Returns the
%   points as a table.

sizes = [16 24 32 48 64 96 128];
cols = [0 0 0; 0.85 0.33 0.10; 0 0.45 0.74; 0.47 0.67 0.19; 0.49 0.18 0.56];
mk = {'o-', 's-', 'd-', '^-', 'v-'};
rows = {'pi', 2, 'equity share, ages 40-66'; 'pi', 3, 'equity share, ages 67-95'; ...
        'C', 2, 'consumption, ages 40-66'; 'C', 3, 'consumption, ages 67-95'};
S = ladder.steps();
fig = figure('Visible', 'off', 'Position', [20 20 420 * numel(steps), 330 * size(rows, 1)], 'Color', 'w');
tl = tiledlayout(fig, size(rows, 1), numel(steps), 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('Grid convergence of the DC steps, %s arm: largest gap to %s against the number of grid points', arm, ref_name), ...
    'Means over the same 10,000 simulated households. Dashed: the ladder''s stop rule (0.02 in the equity share, 2% in consumption)'}, ...
    'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
T = table();
for j = 1:numel(steps)
    k = ladder.index(steps(j), S);
    ref = case_load(steps(j), arm, ref_name);
    for i = 1:size(rows, 1)
        ax = nexttile(tl, (i - 1) * numel(steps) + j); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        set(ax, 'XScale', 'log', 'YScale', 'log', 'FontSize', 9);
        if i == 1, title(ax, sprintf('Step %s %s', ladder.number(k, S), S(k).name), 'Interpreter', 'none'); end
        if j == 1, ylabel(ax, rows{i, 3}); end
        if i == size(rows, 1), xlabel(ax, 'grid points (u1 x u2)'); end
        if isempty(ref), continue; end
        tol = 0.02;
        yline(ax, tol, 'k--', 'HandleVisibility', 'off');
        h = gobjects(0); lab = {};
        for q = 1:numel(rules)
            x = []; y = [];
            for n = sizes
                nm = sprintf('%s_%dx%d', rules{q}, n, n);
                if strcmp(nm, ref_name), continue; end
                r = case_load(steps(j), arm, nm);
                if isempty(r) && strcmp(nm, 'uniform_16x16'), r = case_load(steps(j), arm, 'standard'); end
                if isempty(r), continue; end
                g = case_gaps(r, ref);
                x(end+1) = r.p.N_u1 * r.p.N_u2; %#ok<AGROW>
                y(end+1) = max(g.(rows{i, 1})(rows{i, 2}), 1e-4); %#ok<AGROW>
                if i == 1
                    T = [T; table(string(ladder.number(k, S)), string(nm), x(end), r.timing.solve_sec, ...
                        g.pi(1), g.pi(2), g.pi(3), g.C(1), g.C(2), g.C(3), g.X(2), g.X(3), ...
                        'VariableNames', {'step', 'case', 'points', 'solve_s', 'pi_26_39', 'pi_40_66', ...
                        'pi_67_95', 'C_26_39', 'C_40_66', 'C_67_95', 'X_40_66', 'X_67_95'})]; %#ok<AGROW>
                end
            end
            if isempty(x), continue; end
            h(end+1) = plot(ax, x, y, mk{q}, 'Color', cols(q, :), 'LineWidth', 1.6, 'MarkerFaceColor', 'w'); %#ok<AGROW>
            lab{end+1} = rules{q}; %#ok<AGROW>
        end
        ylim(ax, [1e-4 1.5]);
        if i == 1 && j == 1 && ~isempty(h), legend(ax, h, lab, 'Location', 'southwest', 'Interpreter', 'none'); end
    end
end
exportgraphics(fig, file, 'Resolution', 110);
close(fig);
end
