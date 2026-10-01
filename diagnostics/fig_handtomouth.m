function fig_handtomouth(out_dir, AGE)
%FIG_HANDTOMOUTH  Taking the early-life objective apart along the consumption
%   axis, cube by cube.
%
%   The Bellman right hand side at a node is
%       rhs(c) = u(c LW) + beta E[V'] + bequest
%   with everything here expressed as a certainty equivalent per unit of
%   wealth, so the three terms are in the same readable units:
%       current consumption      c * LW,        exactly linear in c
%       the continuation         ((1-gamma) E[V'])^(1/(1-gamma))
%       the whole objective      ((1-gamma) rhs)^(1/(1-gamma))
%
%   The landing state (u1', u2') is arithmetic on the budget and carries no
%   dependence on the cube. The value attached to it is an interpolant of the
%   solved value function and carries all of it. Separating the two is the
%   point of the figure.
%
%   The last panel compares where the objective actually collapses with where
%   next period's liquid resources fall below the consumption floor, which is
%   the model's own ruin boundary and is likewise grid-independent.

if nargin < 1 || isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
if nargin < 2 || isempty(AGE), AGE = 34; end
fd = fullfile(out_dir, 'factorial_figs');
L  = load(fullfile(out_dir, 'handtomouth.mat')); G = L.G;
[~, o] = sort([G.n]); G = G(o);
nG = numel(G); g = 5;
col = [0.85 0.33 0.10; 0.95 0.70 0.15; 0.25 0.60 0.45; 0.15 0.35 0.70];
col = col(1:nG, :);

ai = find(24 + G(1).t == AGE, 1);
if isempty(ai), error('age %d was not scanned', AGE); end

D = cell(1, nG);
for i = 1:nG
    fn = fullfile(G(i).dir, sprintf('scan_t%03d_k%06d.mat', G(i).t(ai), G(i).node(ai)));
    if isfile(fn), D{i} = hm_decomp(load(fn), g, G(i).bud(ai)); end
end

f  = figure('Position', [10 10 1680 940], 'Color', 'w', 'Visible', 'off');
tl = tiledlayout(f, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
h  = gobjects(nG, 1);

% (1) the objective itself
ax = nexttile(tl, 1); hold(ax, 'on'); grid(ax, 'on'); ax.GridAlpha = .12;
for i = 1:nG
    d = D{i}; if isempty(d), continue; end
    h(i) = plot(ax, d.c, d.z/max(d.z), 'Color', col(i, :), 'LineWidth', 2);
end
xlabel(ax, 'c  (share of liquid resources consumed)'); ylabel(ax, 'z / best z');
title(ax, 'what has to be explained: the objective along c', 'FontWeight', 'normal');

% (2) the continuation
ax = nexttile(tl, 2); hold(ax, 'on'); grid(ax, 'on'); ax.GridAlpha = .12;
for i = 1:nG
    d = D{i}; if isempty(d), continue; end
    plot(ax, d.c, d.ce_cont/max(d.ce_cont), 'Color', col(i, :), 'LineWidth', 2);
end
xlabel(ax, 'c'); ylabel(ax, 'CE of the continuation / its own best');
title(ax, 'the continuation term -- this is where the collapse is', 'FontWeight', 'normal');

% (3) current consumption
ax = nexttile(tl, 3); hold(ax, 'on'); grid(ax, 'on'); ax.GridAlpha = .12;
for i = 1:nG
    d = D{i}; if isempty(d), continue; end
    plot(ax, d.c, d.ce_now, 'Color', col(i, :), 'LineWidth', 2);
end
xlabel(ax, 'c'); ylabel(ax, 'c \times LW   (consumption, share of wealth)');
title(ax, 'the current-utility term: rising in c at every cube', 'FontWeight', 'normal');

% (4) the landing state
ax = nexttile(tl, 4); hold(ax, 'on'); grid(ax, 'on'); ax.GridAlpha = .12;
for i = 1:nG
    d = D{i}; if isempty(d), continue; end
    plot(ax, d.c, d.u2_med, 'Color', col(i, :), 'LineWidth', 2);
end
yline(ax, 1, '-', 'Color', [.4 .4 .4]);
xlabel(ax, 'c'); ylabel(ax, "u2' at the median shock");
title(ax, 'where the choice lands: same in every cube', 'FontWeight', 'normal');

% (5) next period's liquid resources against the floor
ax = nexttile(tl, 5); hold(ax, 'on'); grid(ax, 'on'); ax.GridAlpha = .12;
d = D{end};
if ~isempty(d)
    qs = [0.1 0.5 0.9]; sh = gobjects(numel(qs), 1);
    for q = 1:numel(qs)
        sh(q) = plot(ax, d.c, d.LW2_q(q, :), 'Color', [.15 .15 .15] + 0.28*(q-1), 'LineWidth', 1.8);
    end
    plot(ax, d.c, d.F2_med, '--', 'Color', [.85 .33 .10], 'LineWidth', 1.8);
    yline(ax, 0, '-', 'Color', [.5 .5 .5]);
    legend(ax, [sh; gobjects(0)], arrayfun(@(q) sprintf('%g percentile shock', 100*q), qs, 'uni', 0), ...
        'Box', 'off', 'Location', 'southwest', 'FontSize', 8);
end
xlabel(ax, 'c'); ylabel(ax, "LW' / W'   (next period's liquid resources)");
title(ax, "next period's budget, finest cube; dashed = the consumption floor", 'FontWeight', 'normal');

% (6) probability of landing in ruin, against where each cube collapses
ax = nexttile(tl, 6); hold(ax, 'on'); grid(ax, 'on'); ax.GridAlpha = .12;
for i = 1:nG
    d = D{i}; if isempty(d), continue; end
    plot(ax, d.c, 100*d.p_floor, 'Color', col(i, :), 'LineWidth', 2);
    ch = chalf(d);
    if ~isnan(ch)
        xline(ax, ch, '--', 'Color', col(i, :), 'LineWidth', 1.6);
    end
end
xlabel(ax, 'c'); ylabel(ax, "chance of landing below next period's floor, %");
title(ax, 'the model''s own ruin boundary; dashed = where each cube''s objective halves', ...
    'FontWeight', 'normal');

lg = legend(h(isgraphics(h)), arrayfun(@(q) sprintf('%s = %d nodes', mat2str(q.N), q.n), ...
    G(find(isgraphics(h)).'), 'uni', 0), 'Box', 'off', 'NumColumns', nG);
lg.Layout.Tile = 'south';
sgtitle(f, sprintf(['Age %d, at the state households of that age occupy: the objective along the consumption axis, ' ...
    'taken apart term by term.\nEverything is a certainty equivalent per unit of wealth. ' ...
    'Panels 4 and 5 are arithmetic on the budget and do not depend on the cube; panel 2 is an interpolant and does.'], AGE), ...
    'FontWeight', 'normal', 'FontSize', 11, 'Interpreter', 'tex');
exportgraphics(f, fullfile(fd, sprintf('S32_handtomouth_age%d.png', AGE)), 'Resolution', 120);
close(f);
fprintf('S32 (age %d) written\n', AGE);

fprintf('\n=== age %d: where the objective collapses vs where the budget fails ===\n', AGE);
fprintf('%-14s %6s %10s %12s %12s %12s %12s\n', 'cube', 'nodes', 'LW at node', ...
    'c: z halves', 'c: 10%% ruin', 'c: 50%% ruin', "u2' at c=0.5");
for i = 1:nG
    d = D{i}; if isempty(d), continue; end
    fprintf('%-14s %6d %10.4f %12.3f %12.3f %12.3f %12.3f\n', mat2str(G(i).N), G(i).n, ...
        d.LW_W, chalf(d), cross(d.c, d.p_floor, 0.10), cross(d.c, d.p_floor, 0.50), ...
        interp1(d.c, d.u2_med, 0.5));
end
end
% ------------------------------------------------------------------------
function x = chalf(d)
%CHALF  The consumption share at which the objective has lost half its peak.
x = cross(d.c, d.z/max(d.z), 0.5, true);
end

% ------------------------------------------------------------------------
function x = cross(xv, yv, lvl, falling)
%CROSS  First crossing of lvl, linearly interpolated; NaN when it never happens.
if nargin < 4, falling = false; end
if falling, k = find(yv <= lvl, 1); else, k = find(yv >= lvl, 1); end
if isempty(k) || k == 1, x = NaN; return; end
y0 = yv(k-1); y1 = yv(k);
if y1 == y0, x = xv(k); else, x = xv(k-1) + (lvl - y0)/(y1 - y0)*(xv(k) - xv(k-1)); end
end
