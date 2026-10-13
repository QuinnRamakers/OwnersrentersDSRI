function runtime_map(numerics)
%RUNTIME_MAP  How solve time grows with the grid, and what each refinement buys.
%
%   runtime_map()             % standard numerics
%
%   Run from the repository root after ladder.grid_axes(k) for k = 6, 9, 10, 11
%   and ladder.grid_axes(12, ladders=true). Reads every saved robustness run of
%   steps 6 and 9-12 and every saved ladder step, and draws
%   <numerics dir>/robustness/runtime_map.png:
%     (a) solve time against the number of state-grid points, default solver
%     (b) step 12: solve time as one axis is refined
%     (c) step 12: the largest gap in the equity share to the finest grid
%         against solve time
%     (d) the same for consumption
%     (e) solve time of each ladder step at standard numerics
%     (f) steps 9-12: solve time of the other solvers against the default
%   Times are wall-clock seconds of the backward solve on a thread pool.

if nargin < 1, numerics = 'standard'; end
num = ladder.numerics(numerics); S = ladder.steps(); d = fullfile(num.dir, 'robustness');
arms = {'nohousing_renter', 'nohousing_owner'};
st = figures.style(); cols = st.series;
mk = {'o', 's'};
FS = 10;

fig = figure('Visible', 'off', 'Position', [30 30 2100 1150], 'Color', 'w');
tl = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'Runtime of the solve: how it grows with the grid, and what each refinement changes', ...
    'Wall-clock seconds of the backward solve, 16 threads; circles renter, squares owner'}, ...
    'FontSize', 14, 'FontWeight', 'bold');

% (a) all default-solver runs: time against grid points
ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = FS;
steps = [6 9 10 11 12]; h = gobjects(1, numel(steps));
for i = 1:numel(steps)
    k = steps(i);
    for a = 1:2
        T = runs(num, d, S, k, arms{a});
        T = T(T.default, :);
        h(i) = scatter(ax, T.nodes, T.sec, 36, cols(i, :), mk{a}, 'filled', 'MarkerFaceAlpha', 0.75);
    end
end
set(ax, 'XScale', 'log', 'YScale', 'log');
xlabel(ax, 'state-grid points (u1 x u2 x u3)'); ylabel(ax, 'solve time, s');
legend(ax, h, arrayfun(@(k) sprintf('%d %s', k, S(k).name), steps, 'UniformOutput', false), ...
    'Location', 'northwest', 'Interpreter', 'none');
title(ax, '(a)  Solve time against grid points (default solver)');

% (b)-(d) step 12 ladders
k = 12; tags = struct();
tags.u1 = {[16 16 10], [24 16 10], [32 16 10], [48 16 10], [64 16 10]};
tags.u2 = {[16 16 10], [16 24 10], [16 32 10], [16 48 10]};
tags.both = {[16 16 10], [32 32 10], [64 32 10]};
ladders = {'u1', 'income-share axis u1 refined'; 'u2', 'pension-share axis u2 refined'; 'both', 'both refined'};
axb = nexttile(tl); hold(axb, 'on'); grid(axb, 'on'); box(axb, 'on'); axb.FontSize = FS;
axc = nexttile(tl); hold(axc, 'on'); grid(axc, 'on'); box(axc, 'on'); axc.FontSize = FS;
nexttile(tl, 4); axd = gca; hold(axd, 'on'); grid(axd, 'on'); box(axd, 'on'); axd.FontSize = FS;
hb = gobjects(1, 3);
for a = 1:2
    T = runs(num, d, S, k, arms{a});
    even = T.default & T.pow == 1 & T.pow2 == 1 & T.gh == 5;
    best = T(even & all(T.dims == [64 32 10], 2), :);
    if isempty(best), continue; end
    sb = best.summary{1}; w = sb.ages >= 26 & sb.ages <= 95;
    for l = 1:size(ladders, 1)
        dims = tags.(ladders{l, 1}); x = nan(size(dims)); y = x; gp = x; gc = x;
        for j = 1:numel(dims)
            row = T(even & all(T.dims == dims{j}, 2), :);
            if isempty(row), continue; end
            s = row.summary{1};
            x(j) = row.nodes(1); y(j) = row.sec(1);
            gp(j) = max(abs(s.pi(w) - sb.pi(w)));
            gc(j) = 100 * max(abs(s.C.mean(w) ./ sb.C.mean(w) - 1));
        end
        hb(l) = plot(axb, x, y, ['-' mk{a}], 'Color', cols(l, :), 'MarkerFaceColor', cols(l, :), 'LineWidth', 1.5);
        plot(axc, y, gp, ['-' mk{a}], 'Color', cols(l, :), 'MarkerFaceColor', cols(l, :), 'LineWidth', 1.5);
        plot(axd, y, gc, ['-' mk{a}], 'Color', cols(l, :), 'MarkerFaceColor', cols(l, :), 'LineWidth', 1.5);
    end
    % Same number of points, bunched where households are
    bunch = {[2 1], 'u1 low', [0 0 0]; [1 2], 'u2 high', [0.55 0.55 0.55]; [2 2], 'both', [0.75 0.10 0.10]};
    for j = 1:size(bunch, 1)
        row = T(T.default & T.pow == bunch{j, 1}(1) & T.pow2 == bunch{j, 1}(2) & all(T.dims == [16 16 10], 2), :);
        if isempty(row), continue; end
        s = row.summary{1}; x = row.sec(1);
        yp = max(abs(s.pi(w) - sb.pi(w))); yc = 100 * max(abs(s.C.mean(w) ./ sb.C.mean(w) - 1));
        plot(axc, x, yp, mk{a}, 'Color', bunch{j, 3}, 'MarkerSize', 10, 'LineWidth', 1.8);
        plot(axd, x, yc, mk{a}, 'Color', bunch{j, 3}, 'MarkerSize', 10, 'LineWidth', 1.8);
        if a == 1
            text(axc, x * 1.08, yp, bunch{j, 2}, 'Color', bunch{j, 3}, 'FontSize', 9);
            text(axd, x * 1.08, yc, bunch{j, 2}, 'Color', bunch{j, 3}, 'FontSize', 9);
        end
    end
end
set(axb, 'XScale', 'log', 'YScale', 'log'); xlim(axb, [400 6000]); xlabel(axb, 'state-grid points'); ylabel(axb, 'solve time, s');
legend(axb, hb, ladders(:, 2), 'Location', 'northwest');
title(axb, '(b)  Step 12: solve time as one axis is refined');
for ax = [axc axd]
    set(ax, 'XScale', 'log'); xlabel(ax, 'solve time, s');
end
ylabel(axc, 'largest gap in the equity share'); ylabel(axd, 'largest gap in consumption, %');
title(axc, {'(c)  Step 12: equity-share gap to the finest grid [64 32 10]', ...
    'colours as in (b); open markers: the standard points, bunched where households are'});
title(axd, {'(d)  Step 12: consumption gap to the finest grid [64 32 10]', 'ages 26-95, colours as in (b); lower is closer'});

% (e) ladder steps
ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = FS;
for k = 1:numel(S)
    for t = {'nohousing', 'nohousing_renter', 'nohousing_owner', 'renter', 'owner'}
        f = ladder.result_file(num, k, S(k).name, t{1});
        if ~isfile(f), continue; end
        r = load(f, 'timing');
        m = 'o'; if endsWith(t{1}, 'owner'), m = 's'; end
        scatter(ax, k, r.timing.solve_sec, 40, cols(1, :), m, 'filled');
    end
end
xticks(ax, 1:numel(S)); xticklabels(ax, {S.name}); xtickangle(ax, 45); ax.TickLabelInterpreter = 'none';
ylabel(ax, 'solve time, s'); title(ax, '(e)  Each ladder step at standard numerics [16 16 10]');

% (f) solvers
ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = FS;
sv = {'default', 'interior-point + sweep'; 'as_sweep', 'active-set + sweep'; 'sqp_sweep', 'sqp + sweep'; ...
      'ip_nosweep', 'interior-point, no sweep'; 'as_nosweep', 'active-set, no sweep'};
for i = 1:size(sv, 1)
    for k = 9:12
        for a = 1:2
            if i == 1
                f = ladder.result_file(num, k, S(k).name, arms{a});
            else
                f = fullfile(d, sprintf('%02d_%s_%s_%s.mat', k, S(k).name, arms{a}, sv{i, 1}));
            end
            if ~isfile(f), continue; end
            r = load(f, 'timing');
            scatter(ax, i + 0.15 * (k - 10.5), r.timing.solve_sec, 36, cols(k - 8, :), mk{a}, 'filled');
        end
    end
end
xticks(ax, 1:size(sv, 1)); xticklabels(ax, sv(:, 2)); xtickangle(ax, 30);
ylabel(ax, 'solve time, s'); ylim(ax, [0 inf]);
title(ax, '(f)  Steps 9-12 (colour by step): solve time by solver, grid [16 16 10]');

out = fullfile(d, 'runtime_map.png');
exportgraphics(fig, out, 'Resolution', 130); close(fig);
fprintf('wrote %s\n', out);
end

% ------------------------------------------------------------------------
function T = runs(num, d, S, k, arm)
% Every saved run of step k and this arm: the step itself and its robustness runs.
files = [{ladder.result_file(num, k, S(k).name, arm)}, ...
         fullfile(d, {builtin('dir', fullfile(d, sprintf('%02d_%s_%s_*.mat', k, S(k).name, arm))).name})];
files = files(cellfun(@isfile, files));
n = numel(files);
nodes = zeros(n, 1); sec = nodes; gh = nodes; pow = nodes; pow2 = nodes; dims = zeros(n, 3); default = false(n, 1);
summary = cell(n, 1);
for i = 1:n
    r = load(files{i}, 'p', 'timing', 'summary');
    nodes(i) = r.p.N_u1 * r.p.N_u2 * r.p.N_u3; sec(i) = r.timing.solve_sec;
    gh(i) = r.p.gh_n; pow(i) = r.p.grid_pow; pow2(i) = r.p.grid_pow_u2; dims(i, :) = r.p.grid_dims;
    default(i) = strcmp(r.p.fmincon_algorithm, 'interior-point') && r.p.use_refine;
    summary{i} = r.summary;
end
T = table(nodes, sec, gh, pow, pow2, dims, default, summary);
end
