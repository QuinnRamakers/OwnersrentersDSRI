function fig_decision_states(sp, out_dir)
%FIG_DECISION_STATES  The objective over (c, pi) at states across the cube.
%
%   S24 shows the Bellman right hand side over the two decisions at one state
%   per age: the one households of that age actually occupy. Those surfaces are
%   benign. This sweeps the state instead -- income share u1 down the rows,
%   illiquid share u2 across the columns, at mid u3 -- so the surfaces the
%   solver meets in the rest of the cube can be seen next to them.
%
%   Height is z = ((1-gamma) RHS)^(1/(1-gamma)), the lifetime certainty
%   equivalent per unit of wealth under that (c, pi). Zero is ruin. Each panel
%   is scaled to its own maximum, because the level varies by an order of
%   magnitude across the cube and a shared axis would flatten the poor states;
%   the level is reported in the title instead.
%
%   Panels are labelled by whether the state lies inside the 5-95 percentile of
%   where households of that age actually are.
%
%   Reads scans_full (every node, 8 ages) and occupancy_src.

if nargin < 1 || isempty(sp)
    sp = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad';
end
if nargin < 2 || isempty(out_dir)
    out_dir = 'C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics';
end
fd = fullfile(out_dir, 'factorial_figs');
sd = fullfile(sp, 'scans_full');
if ~isfolder(sd), fprintf('no scans_full\n'); return; end
M  = load(fullfile(sp, 'landscape_meta.mat'), 'N', 'p');
N  = M.N; pg = M.p;

Q = load(fullfile(out_dir, 'occupancy_src.mat')); s = Q.s;
lam = s.lambda; sA = s.sA; sH = s.sH;

FIGNO = containers.Map({54, 84}, {27, 28});
for AG = [54 84]
    t = AG - 24;
    [q1, q2] = occrange(lam, sA, sH, t);
    % The sweep is built around the state households of that age occupy, so one
    % panel is exactly the node S24 shows and the rest are its neighbours out
    % into the empty part of the cube.
    [i1o, i2o, i3] = occnode(pg, lam, sA, sH, t);
    I1 = spread(i1o, numel(pg.u1_grid));
    I2 = spread(i2o, numel(pg.u2_grid));
    f  = figure('Position', [10 10 440*numel(I2) 400*numel(I1)], 'Color', 'w', 'Visible', 'off');
    tl = tiledlayout(f, numel(I1), numel(I2), 'Padding', 'compact', 'TileSpacing', 'compact');
    fprintf('\n=== age %d, objective over (c,pi) across states (u3 = %.2f) ===\n', AG, pg.u3_grid(i3));
    fprintf('%8s %8s %10s %8s %8s %8s %10s %10s  %s\n', 'u1', 'u2', 'best z', 'c*', 'pi*', 'ruin %', 'peaks pi', 'pi swing', 'where');
    for a = 1:numel(I1)
        for b = 1:numel(I2)
            k  = sub2ind(N, I1(a), I2(b), i3);
            fn = fullfile(sd, sprintf('scan_t%03d_k%06d.mat', t, k));
            ax = nexttile(tl, (a-1)*numel(I2) + b); hold(ax, 'on');
            if ~isfile(fn)
                title(ax, 'not scanned', 'FontWeight', 'normal'); axis(ax, 'off'); continue;
            end
            [Z, S, zmax, ig, jg] = surf_panel(ax, fn);
            u1v = pg.u1_grid(I1(a)); u2v = pg.u2_grid(I2(b));
            inocc = u1v >= q1(1) && u1v <= q1(2) && u2v >= q2(1) && u2v <= q2(2);
            fr0 = 100*mean(Z(:) <= 0.02*zmax);
            sl  = Z(ig, :);
            nb  = npeaks(sl);
            sw  = 100*(max(sl) - min(sl))/zmax;   % what pi is worth at the best c
            title(ax, {sprintf('u1 = %.3f, u2 = %.2f%s', u1v, u2v, tern(inocc, '   [occupied]', '')), ...
                       sprintf('best z = %.4f at c=%.2f, \\pi=%.2f', zmax, S.c(ig), S.pi(jg)), ...
                       sprintf('%.0f%% ruin, %s along \\pi worth %.2g%% of z', fr0, plural(nb, 'peak'), sw)}, ...
                       'FontWeight', 'normal', 'FontSize', 9);
            if inocc, ax.Title.Color = [0.75 0.25 0.05]; end
            fprintf('%8.3f %8.2f %10.4f %8.2f %8.2f %7.0f%% %10d %9.2g%%  %s\n', ...
                u1v, u2v, zmax, S.c(ig), S.pi(jg), fr0, nb, sw, tern(inocc, 'occupied', 'empty'));
        end
    end
    sgtitle(f, sprintf(['Age %d: the objective over the two DECISIONS, at states across the cube.\n' ...
        'Rows = u1, income as a share of wealth (wealth-rich at the top, almost no wealth at the bottom). ' ...
        'Columns = u2, the illiquid share (liquid on the left, nothing liquid on the right). u3 held at %.2f.\n' ...
        'Orange = states this age actually occupies. Star = best (c, \\pi), circle = the warm start.'], ...
        AG, pg.u3_grid(i3)), 'FontWeight', 'normal', 'FontSize', 11, 'Interpreter', 'tex');
    nm = sprintf('S%d_decisions_across_states_age%d.png', FIGNO(AG), AG);
    exportgraphics(f, fullfile(fd, nm), 'Resolution', 110); close(f);
    fprintf('%s written\n', nm);
end

% ---- the u3 dimension, at the occupied (u1, u2) -------------------------
I3 = [1 3 5 8]; AGS = [54 84];
f  = figure('Position', [10 10 440*numel(I3) 400*numel(AGS)], 'Color', 'w', 'Visible', 'off');
tl = tiledlayout(f, numel(AGS), numel(I3), 'Padding', 'compact', 'TileSpacing', 'compact');
fprintf('\n=== the u3 dimension (DC pot as a share of illiquid wealth), at the occupied (u1,u2) ===\n');
fprintf('%6s %8s %10s %8s %8s %8s %10s\n', 'age', 'u3', 'best z', 'c*', 'pi*', 'ruin %', 'pi swing');
for a = 1:numel(AGS)
    t = AGS(a) - 24;
    [i1, i2] = occnode(pg, lam, sA, sH, t);
    for b = 1:numel(I3)
        k  = sub2ind(N, i1, i2, I3(b));
        fn = fullfile(sd, sprintf('scan_t%03d_k%06d.mat', t, k));
        ax = nexttile(tl, (a-1)*numel(I3) + b); hold(ax, 'on');
        if ~isfile(fn)
            title(ax, 'not scanned', 'FontWeight', 'normal'); axis(ax, 'off'); continue;
        end
        [Z, S, zmax, ig, jg] = surf_panel(ax, fn);
        fr0 = 100*mean(Z(:) <= 0.02*zmax);
        sl  = Z(ig, :);
        sw  = 100*(max(sl) - min(sl))/zmax;
        title(ax, {sprintf('age %d,  u3 = %.2f', AGS(a), pg.u3_grid(I3(b))), ...
                   sprintf('best z = %.4f at c=%.2f, \\pi=%.2f', zmax, S.c(ig), S.pi(jg)), ...
                   sprintf('%.0f%% ruin, \\pi worth %.2g%% of z', fr0, sw)}, ...
                   'FontWeight', 'normal', 'FontSize', 9);
        fprintf('%6d %8.2f %10.4f %8.2f %8.2f %7.0f%% %9.2g%%\n', ...
            AGS(a), pg.u3_grid(I3(b)), zmax, S.c(ig), S.pi(jg), fr0, sw);
    end
end
sgtitle(f, ['The third state dimension: u3, the DC pot as a share of illiquid wealth, ' ...
    'at the (u1, u2) households occupy. Star = best (c, \pi), circle = the warm start.'], ...
    'FontWeight', 'normal', 'FontSize', 11, 'Interpreter', 'tex');
exportgraphics(f, fullfile(fd, 'S30_decisions_across_u3.png'), 'Resolution', 110); close(f);
fprintf('S30 written\n');
end

% ------------------------------------------------------------------------
function [Z, S, zmax, ig, jg] = surf_panel(ax, fn)
%SURF_PANEL  One (c, pi) relief panel with the best pair and the warm start.
%   The surface is drawn relative to its own peak. z varies by an order of
%   magnitude across the cube, so a raw height would make the level differences
%   between states swamp the shape differences that are the point. The level is
%   returned and goes in the panel title instead.
g = 5;
S = load(fn);
Z = ((1-g)*S.rhs).^(1/(1-g));
Z(~isfinite(Z)) = 0; Z = max(Z, 0);
zmax = max(Z(:)); if zmax <= 0, zmax = eps; end
Zn = Z / zmax;
surf(ax, S.pi, S.c, Zn, 'EdgeColor', 'none', 'FaceColor', 'interp');
colormap(ax, parula); clim(ax, [0 1]);
[~, im] = max(Z(:)); [ig, jg] = ind2sub(size(Z), im);
plot3(ax, S.pi(jg), S.c(ig), 1.03, 'p', 'MarkerSize', 15, ...
    'MarkerFaceColor', [.98 .80 .15], 'MarkerEdgeColor', 'k', 'LineWidth', .9);
[~, ics] = min(abs(S.c - S.seed(1)));
[~, ips] = min(abs(S.pi - S.seed(2)));
plot3(ax, S.seed(2), S.seed(1), Zn(ics, ips) + 0.03, 'o', 'MarkerSize', 8, ...
    'MarkerFaceColor', [1 1 1], 'MarkerEdgeColor', 'k', 'LineWidth', 1.1);
view(ax, -40, 36); grid(ax, 'on'); zlim(ax, [0 1.08]);
xlabel(ax, '\pi'); ylabel(ax, 'c'); zlabel(ax, 'z / best z');
end

% ------------------------------------------------------------------------
function [i1, i2, i3] = occnode(pg, lam, sA, sH, t)
%OCCNODE  The cube node nearest the occupancy median at age 24 + t.
tt = min(t, size(lam, 2));
u2v = (sA(:, tt) + sH(:, tt)) ./ max(1 - lam(:, tt), 1e-12);
u3v = sA(:, tt) ./ max(sA(:, tt) + sH(:, tt), 1e-12);
[~, i1] = min(abs(pg.u1_grid(:) - median(lam(:, tt), 'omitnan')));
[~, i2] = min(abs(pg.u2_grid(:) - median(u2v, 'omitnan')));
[~, i3] = min(abs(pg.u3_grid(:) - median(u3v, 'omitnan')));
end

% ------------------------------------------------------------------------
function I = spread(i0, n)
%SPREAD  Four indices spanning the axis, one of which is forced to be i0.
I = round(linspace(2, n, 4));
[~, j] = min(abs(I - i0));
I(j) = i0;
I = unique(I);
end

% ------------------------------------------------------------------------
function [q1, q2] = occrange(lam, sA, sH, t)
tt = min(t, size(lam, 2));
u1 = lam(:, tt);
u2 = (sA(:, tt) + sH(:, tt)) ./ max(1 - lam(:, tt), 1e-12);
q1 = prctile(u1(isfinite(u1)), [5 95]);
q2 = prctile(u2(isfinite(u2)), [5 95]);
end

% ------------------------------------------------------------------------
function n = npeaks(v)
%NPEAKS  Interior maxima along pi, with the ripple guard used elsewhere: a
%   turning point counts only when it stands 1e-4 of the range above the
%   troughs either side, two orders of magnitude above this objective's
%   numerical ripple.
v = v(:).';
r = max(v) - min(v);
if r <= 0, n = 1; return; end
pk = find(diff(sign(diff(v))) < 0) + 1;
keep = false(size(pk));
for i = 1:numel(pk)
    keep(i) = (v(pk(i)) - min(v(1:pk(i)))) > 1e-4*r && ...
              (v(pk(i)) - min(v(pk(i):end))) > 1e-4*r;
end
n = max(1, sum(keep));
end

% ------------------------------------------------------------------------
function s = plural(n, word)
if n == 1, s = sprintf('%d %s', n, word); else, s = sprintf('%d %ss', n, word); end
end

% ------------------------------------------------------------------------
function o = tern(c, a, b)
if c, o = a; else, o = b; end
end
