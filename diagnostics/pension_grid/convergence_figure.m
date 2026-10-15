function T = convergence_figure(steps, arm, refs, families, file)
%CONVERGENCE_FIGURE  Gap to a reference grid against grid size, per step and family.
%
%   T = convergence_figure([6 9 10 11 12], 'owner', refs, families, 'conv_owner.png')
%
%   refs is a cell with one reference case name per step (case_load names).
%   families is a struct array with fields name (legend) and cases (a cell of
%   case names, coarse to fine). One column per step. Rows: the largest gap in
%   the equity share of liquid saving (savings-weighted, so households that
%   save nothing carry no weight) at ages 40-66 and 67-95, in mean consumption
%   (share of the reference) at 40-66 and 67-95, and in mean liquid savings
%   (years of income) at 40-66 and 67-95, each against the number of (u1, u2)
%   grid points, log axes. The dashed line is the ladder's stop rule (0.02 in
%   the share, 2% in consumption; 0.1 years of income for savings, which the
%   ladder does not set). Cases not solved are skipped. Returns the points.

cols = [0 0 0; 0.85 0.33 0.10; 0 0.45 0.74; 0.47 0.67 0.19; 0.49 0.18 0.56];
mk = {'o-', 's-', 'd-', '^-', 'v-'};
rows = {'piw', 2, {'equity share of liquid saving', 'ages 40-66'}, 0.02; ...
        'piw', 3, {'equity share of liquid saving', 'ages 67-95'}, 0.02; ...
        'C', 2, {'consumption (share)', 'ages 40-66'}, 0.02; ...
        'C', 3, {'consumption (share)', 'ages 67-95'}, 0.02; ...
        'X', 2, {'liquid savings (years of income)', 'ages 40-66'}, 0.1; ...
        'X', 3, {'liquid savings (years of income)', 'ages 67-95'}, 0.1};
S = ladder.steps();
nr = size(rows, 1);
fig = figure('Visible', 'off', 'Position', [20 20 430 * numel(steps), 290 * nr], 'Color', 'w');
tl = tiledlayout(fig, nr, numel(steps), 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('Grid convergence of the DC steps, %s: largest gap to the reference against the number of grid points', arm), ...
    'Means over the same 10,000 simulated households. Dashed: the stop rule. Reference per column in its title'}, ...
    'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
T = table();
for j = 1:numel(steps)
    k = ladder.index(steps(j), S);
    ref = case_load(steps(j), arm, refs{j});
    R = cell(size(families));
    for q = 1:numel(families)
        R{q} = cellfun(@(c) case_load(steps(j), arm, c), families(q).cases, 'UniformOutput', false);
    end
    for i = 1:nr
        ax = nexttile(tl, (i - 1) * numel(steps) + j); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        set(ax, 'XScale', 'log', 'YScale', 'log', 'FontSize', 9);
        if i == 1
            title(ax, {sprintf('Step %s %s', ladder.number(k, S), S(k).name), ['reference ' refs{j}]}, ...
                'Interpreter', 'none', 'FontSize', 10);
        end
        if j == 1, ylabel(ax, rows{i, 3}); end
        if i == nr, xlabel(ax, 'grid points (u1 x u2)'); end
        if isempty(ref), continue; end
        yline(ax, rows{i, 4}, 'k--', 'HandleVisibility', 'off');
        h = gobjects(0); lab = {};
        for q = 1:numel(families)
            x = []; y = [];
            for c = 1:numel(R{q})
                r = R{q}{c};
                if isempty(r) || strcmp(families(q).cases{c}, refs{j}), continue; end
                g = case_gaps(r, ref);
                x(end+1) = r.p.N_u1 * r.p.N_u2; %#ok<AGROW>
                y(end+1) = max(g.(rows{i, 1})(rows{i, 2}), 1e-4); %#ok<AGROW>
                if i == 1
                    T = [T; table(string(ladder.number(k, S)), string(families(q).cases{c}), x(end), ...
                        r.timing.solve_sec, g.piw(2), g.piw(3), g.pi(2), g.pi(3), g.C(1), g.C(2), g.C(3), g.X(2), g.X(3), ...
                        'VariableNames', {'step', 'case', 'points', 'solve_s', 'piw_40_66', 'piw_67_95', ...
                        'pi_40_66', 'pi_67_95', 'C_26_39', 'C_40_66', 'C_67_95', 'X_40_66', 'X_67_95'})]; %#ok<AGROW>
                end
            end
            if isempty(x), continue; end
            h(end+1) = plot(ax, x, y, mk{q}, 'Color', cols(q, :), 'LineWidth', 1.6, 'MarkerFaceColor', 'w'); %#ok<AGROW>
            lab{end+1} = families(q).name; %#ok<AGROW>
        end
        ylim(ax, [1e-4 2]); xlim(ax, [100 2e4]);
        if i == 1 && j == 1 && ~isempty(h), legend(ax, h, lab, 'Location', 'southwest', 'Interpreter', 'none', 'FontSize', 8); end
    end
end
exportgraphics(fig, file, 'Resolution', 110);
close(fig);
end
