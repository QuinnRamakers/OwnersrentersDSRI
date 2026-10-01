function fig_axis_channel(out_dir)
%FIG_AXIS_CHANNEL  Which of the three axes carries the early-life collapse.
%
%   Four solves at roughly equal node count: a 1568-node baseline and three
%   arms that refine one axis and leave the other two alone. If the objective
%   along c collapses in the u2 arm and not in the u1 or u3 arms, the channel
%   is the interpolation of the continuation value along the illiquid share --
%   which is the axis a high consumption choice moves the household along.
%
%   Node counts are matched so that "more nodes" cannot be the explanation.

if nargin < 1 || isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
fd = fullfile(out_dir, 'factorial_figs');
L  = load(fullfile(out_dir, 'axis_channel.mat')); G = L.G;
nA = numel(G); g = 5;
col = [0.20 0.20 0.20; 0.85 0.33 0.10; 0.15 0.45 0.75; 0.30 0.65 0.45];
col = col(1:nA, :);
AGES = 24 + G(1).t;

f  = figure('Position', [10 10 1640 900], 'Color', 'w', 'Visible', 'off');
tl = tiledlayout(f, 2, numel(AGES), 'Padding', 'compact', 'TileSpacing', 'compact');
h  = gobjects(nA, 1);
D  = cell(nA, numel(AGES));
for ai = 1:numel(AGES)
    for i = 1:nA
        fn = fullfile(G(i).dir, sprintf('scan_t%03d_k%06d.mat', G(i).t(ai), G(i).node(ai)));
        if isfile(fn), D{i, ai} = hm_decomp(load(fn), g, G(i).bud(ai)); end
    end

    ax = nexttile(tl, ai); hold(ax, 'on'); grid(ax, 'on'); ax.GridAlpha = .12;
    for i = 1:nA
        d = D{i, ai}; if isempty(d), continue; end
        hh = plot(ax, d.c, d.z/max(d.z), 'Color', col(i, :), 'LineWidth', 2);
        if ai == 1, h(i) = hh; end
    end
    xlabel(ax, 'c'); ylabel(ax, 'z / best z');
    title(ax, sprintf('age %d: the objective along c', AGES(ai)), 'FontWeight', 'normal');

    ax = nexttile(tl, numel(AGES) + ai); hold(ax, 'on'); grid(ax, 'on'); ax.GridAlpha = .12;
    for i = 1:nA
        d = D{i, ai}; if isempty(d), continue; end
        plot(ax, d.c, d.ce_cont/max(d.ce_cont), 'Color', col(i, :), 'LineWidth', 2);
    end
    xlabel(ax, 'c'); ylabel(ax, 'CE of the continuation / its own best');
    title(ax, sprintf('age %d: the continuation term', AGES(ai)), 'FontWeight', 'normal');
end
ok = find(isgraphics(h)).';
lg = legend(h(ok), arrayfun(@(q) sprintf('%s  %s = %d nodes', q.arm, mat2str(q.N), q.n), ...
    G(ok), 'uni', 0), 'Box', 'off', 'NumColumns', numel(ok));
lg.Layout.Tile = 'south';
sgtitle(f, sprintf(['One axis refined at a time, at matched node count, so "more nodes" cannot be the explanation.\n' ...
    'The collapse follows u1, the income axis. Refining u2 changes almost nothing; refining u3 is intermediate.']), ...
    'FontWeight', 'normal', 'FontSize', 11, 'Interpreter', 'tex');
exportgraphics(f, fullfile(fd, 'S33_axis_channel.png'), 'Resolution', 120); close(f);
fprintf('S33 written\n');

for ai = 1:numel(AGES)
    fprintf('\n=== age %d ===\n', AGES(ai));
    fprintf('%-14s %-14s %6s %10s %12s %14s %12s\n', 'arm', 'cube', 'nodes', 'LW at node', ...
        'c: z halves', 'z at c=0.8', "u2' at c=0.8");
    for i = 1:nA
        d = D{i, ai}; if isempty(d), continue; end
        fprintf('%-14s %-14s %6d %10.4f %12.3f %14.3f %12.3f\n', G(i).arm, mat2str(G(i).N), G(i).n, ...
            d.LW_W, chalf(d), interp1(d.c, d.z/max(d.z), 0.8), interp1(d.c, d.u2_med, 0.8));
    end
end
end

% ------------------------------------------------------------------------
function x = chalf(d)
%CHALF  The consumption share at which the objective has lost half its peak.
y = d.z/max(d.z);
k = find(y <= 0.5, 1);
if isempty(k) || k == 1, x = NaN; return; end
x = d.c(k-1) + (0.5 - y(k-1))/(y(k) - y(k-1))*(d.c(k) - d.c(k-1));
end
