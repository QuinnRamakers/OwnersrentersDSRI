function fig_decision_grid(out_dir)
%FIG_DECISION_GRID  The objective over (c, pi) at one state, by cube size.
%
%   The Bellman right hand side is not fixed by the model alone. The
%   continuation value inside it is an interpolant of the solved value
%   function, so the surface the household faces at a given state inherits the
%   cube's resolution. decision_by_grid solves the same model on a ladder of
%   cubes and dumps that surface at the state households of each age occupy;
%   this draws them.
%
%   S29: the surfaces themselves, rows = cube, columns = age, with the z axis
%        shared down each column so a change in shape is a change and not a
%        rescaling.
%   S31: the same objective sliced along each decision with the other held at
%        its best value, all cubes overlaid, which is where small movements are
%        readable.
%
%   The state is located in each cube by nearest node, so it drifts a little
%   between cubes; each panel reports the coordinates actually used.

if nargin < 1 || isempty(out_dir)
    out_dir = fileparts(mfilename('fullpath'));
end
fd = fullfile(out_dir, 'factorial_figs');
L  = load(fullfile(out_dir, 'decision_by_grid.mat')); G = L.G;
[~, o] = sort([G.n]); G = G(o);
nG = numel(G); TS = G(1).t;
col = [0.85 0.33 0.10; 0.95 0.70 0.15; 0.25 0.60 0.45; 0.15 0.35 0.70];
col = col(1:nG, :);

% ---- load every panel first, so the z axis can be shared down a column ----
P = cell(nG, numel(TS));
for i = 1:nG
    for a = 1:numel(TS)
        fn = fullfile(G(i).dir, sprintf('scan_t%03d_k%06d.mat', TS(a), G(i).node(a)));
        if ~isfile(fn), continue; end
        S = load(fn);
        Z = ((1-5)*S.rhs).^(1/(1-5)); Z(~isfinite(Z)) = 0; Z = max(Z, 0);
        [~, im] = max(Z(:)); [ig, jg] = ind2sub(size(Z), im);
        P{i, a} = struct('c', S.c, 'pi', S.pi, 'Z', Z, 'seed', S.seed, ...
                         'ig', ig, 'jg', jg, 'zmax', Z(ig, jg));
    end
end
% Each surface is drawn relative to its own peak. The level of z is not
% comparable across cubes -- the welfare number a cube reports is not the same
% object as the next cube's -- so plotting the raw height makes a change in
% level look like a change in shape. Dividing by the panel's own maximum leaves
% only the shape, which is what is being compared; the level stays in the title.

% ================= S29: the surfaces =====================================
f  = figure('Position', [10 10 460*nG 400*numel(TS)], 'Color', 'w', 'Visible', 'off');
tl = tiledlayout(f, numel(TS), nG, 'Padding', 'compact', 'TileSpacing', 'compact');
fprintf('\n=== objective over (c,pi) at the occupied state, by cube size ===\n');
fprintf('%-14s %6s %6s %8s %8s %10s %8s %8s %10s %10s\n', ...
    'cube', 'nodes', 'age', 'u1', 'u2', 'best z', 'c*', 'pi*', 'ruin %', 'pi swing');
for a = 1:numel(TS)
    for i = 1:nG
        ax = nexttile(tl, (a-1)*nG + i); hold(ax, 'on');
        q = P{i, a};
        if isempty(q)
            title(ax, 'not scanned', 'FontWeight', 'normal'); axis(ax, 'off'); continue;
        end
        Zn = q.Z / q.zmax;
        surf(ax, q.pi, q.c, Zn, 'EdgeColor', 'none', 'FaceColor', 'interp');
        colormap(ax, parula); clim(ax, [0 1]);
        plot3(ax, q.pi(q.jg), q.c(q.ig), 1.03, 'p', 'MarkerSize', 15, ...
            'MarkerFaceColor', [.98 .80 .15], 'MarkerEdgeColor', 'k', 'LineWidth', .9);
        [~, ics] = min(abs(q.c - q.seed(1))); [~, ips] = min(abs(q.pi - q.seed(2)));
        plot3(ax, q.seed(2), q.seed(1), Zn(ics, ips) + 0.03, 'o', 'MarkerSize', 8, ...
            'MarkerFaceColor', [1 1 1], 'MarkerEdgeColor', 'k', 'LineWidth', 1.1);
        view(ax, -40, 36); grid(ax, 'on'); zlim(ax, [0 1.08]);
        xlabel(ax, '\pi'); ylabel(ax, 'c'); zlabel(ax, 'z / best z');
        sl  = q.Z(q.ig, :);
        sw  = 100*(max(sl) - min(sl))/q.zmax;
        fr0 = 100*mean(q.Z(:) <= 0.02*q.zmax);
        title(ax, {sprintf('age %d,  %s = %d nodes', 24 + TS(a), mat2str(G(i).N), G(i).n), ...
                   sprintf('state u1 = %.3f, u2 = %.2f, u3 = %.2f', G(i).coord(a, :)), ...
                   sprintf('best z = %.4f at c=%.2f, \\pi=%.2f;  \\pi worth %.2g%% of z', ...
                           q.zmax, q.c(q.ig), q.pi(q.jg), sw)}, ...
                   'FontWeight', 'normal', 'FontSize', 9);
        fprintf('%-14s %6d %6d %8.3f %8.2f %10.4f %8.2f %8.2f %7.0f%% %9.2g%%\n', ...
            mat2str(G(i).N), G(i).n, 24 + TS(a), G(i).coord(a, 1), G(i).coord(a, 2), ...
            q.zmax, q.c(q.ig), q.pi(q.jg), fr0, sw);
    end
end
sgtitle(f, sprintf(['The objective over the two DECISIONS at the state households occupy, solved on cubes of different size.\n' ...
    'Rows = age, columns = cube, refining left to right. Each surface is divided by its own peak, so the level -- which is not ' ...
    'comparable across cubes -- is out of the picture and only the shape is left; the level is in the panel title. ' ...
    'Star = best (c, \\pi), circle = the warm start.']), ...
    'FontWeight', 'normal', 'FontSize', 11, 'Interpreter', 'tex');
exportgraphics(f, fullfile(fd, 'S29_decisions_by_grid.png'), 'Resolution', 110); close(f);
fprintf('S29 written\n');

% ================= S31: the slices, overlaid ============================
f  = figure('Position', [10 10 460*numel(TS) 760], 'Color', 'w', 'Visible', 'off');
tl = tiledlayout(f, 2, numel(TS), 'Padding', 'compact', 'TileSpacing', 'compact');
h  = gobjects(nG, 1);
for a = 1:numel(TS)
    ax = nexttile(tl, a); hold(ax, 'on'); grid(ax, 'on'); ax.GridAlpha = .12;
    for i = 1:nG
        q = P{i, a}; if isempty(q), continue; end
        hh = plot(ax, q.pi, q.Z(q.ig, :)/q.zmax, 'Color', col(i, :), 'LineWidth', 1.8);
        plot(ax, q.pi(q.jg), 1, 'p', 'MarkerSize', 12, ...
            'MarkerFaceColor', col(i, :), 'MarkerEdgeColor', 'k', 'LineWidth', .6);
        if a == 1, h(i) = hh; end
    end
    xlabel(ax, '\pi  (equity share)'); ylabel(ax, 'z / best z');
    title(ax, sprintf('age %d: objective along \\pi at the best c', 24 + TS(a)), 'FontWeight', 'normal');

    ax = nexttile(tl, numel(TS) + a); hold(ax, 'on'); grid(ax, 'on'); ax.GridAlpha = .12;
    for i = 1:nG
        q = P{i, a}; if isempty(q), continue; end
        plot(ax, q.c, q.Z(:, q.jg)/q.zmax, 'Color', col(i, :), 'LineWidth', 1.8);
        plot(ax, q.c(q.ig), 1, 'p', 'MarkerSize', 12, ...
            'MarkerFaceColor', col(i, :), 'MarkerEdgeColor', 'k', 'LineWidth', .6);
    end
    xlabel(ax, 'c  (consumption share)'); ylabel(ax, 'z / best z');
    title(ax, sprintf('age %d: objective along c at the best \\pi', 24 + TS(a)), 'FontWeight', 'normal');
end
ok = find(isgraphics(h)).';
lg = legend(h(ok), arrayfun(@(g) sprintf('%s = %d nodes', mat2str(g.N), g.n), ...
    G(ok), 'uni', 0), 'Box', 'off', 'NumColumns', numel(ok));
lg.Layout.Tile = 'south';
sgtitle(f, sprintf(['The objective sliced along one decision at a time, all cubes overlaid, each divided by its own peak,\n' ...
    'so the curves compare in shape and not in level. Top: along \\pi at the best c. Bottom: along c at the best \\pi. ' ...
    'Every cube''s optimum sits at 1 by construction.']), ...
    'FontWeight', 'normal', 'FontSize', 11, 'Interpreter', 'tex');
exportgraphics(f, fullfile(fd, 'S31_decision_slices_by_grid.png'), 'Resolution', 120); close(f);
fprintf('S31 written\n');

% ---- how far the optimum moves as the cube is refined -------------------
fprintf('\n=== how far the chosen decision moves between consecutive cubes ===\n');
fprintf('%-6s %-30s %10s %10s\n', 'age', 'refinement', 'd c*', 'd pi*');
for a = 1:numel(TS)
    for i = 2:nG
        q0 = P{i-1, a}; q1 = P{i, a};
        if isempty(q0) || isempty(q1), continue; end
        fprintf('%-6d %-30s %10.3f %10.3f\n', 24 + TS(a), ...
            sprintf('%d -> %d nodes', G(i-1).n, G(i).n), ...
            q1.c(q1.ig) - q0.c(q0.ig), q1.pi(q1.jg) - q0.pi(q0.jg));
    end
end
end
