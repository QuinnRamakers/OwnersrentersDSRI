function T = ruin_interp(step, arm, cases, ages, opts)
%RUIN_INTERP  Does the interpolated value function misprice the ruin corner?
%
%   From the repository root:
%       addpath diagnostics/pension_grid
%       T = ruin_interp(16, 'owner', {'pow3_24x24_lim_u3p2_qn4', 'pow3_24x24_lim_qn4_u3even'});
%       T = ruin_interp(16, 'owner', {'pow3_24x24_lim_u3p2_qn4'}, [45 60 70 85 90], force = true);
%
%   For each saved solve (case_load) and age, the value at states between the
%   grid points is computed twice from the same next-period value function:
%   interpolated from this age's nodes, as the household a year younger reads
%   it, and from the Bellman step at that exact state (solver.bellman_step_lna,
%   unchanged). The gap is the certainty equivalent of the interpolated value
%   over that of the Bellman value, minus 1, in %. Positive: the interpolation
%   prices the state as better than it is.
%
%   The states are cell centres: the midpoint of every u1 and every u2 interval,
%   plus the node u2 = 1 (no liquid saving, where floored households sit),
%   against the u3 nodes and the midpoint of every u3 interval, at the q nodes.
%   The step runs on them through the age grid: this age's u1 and u2 points
%   (p.u1_grid_age, p.u2_grid_age) are the test points, next age's are the
%   solved ones. The u3 midpoints are inserted in the u3 axis, with next age's
%   values interpolated onto them; with linear interpolation that leaves the
%   continuation exactly as solved, which the script checks. The step is also
%   run on the nodes themselves, which must give back the saved values.
%
%   Regions, all with u1 inside the band of the middle 90% of the panel's
%   households at that age and u3 at interval midpoints:
%     corner      u3 below 0.12, u2 = 1
%     corner_in   u3 below 0.12, u2 between nodes above 0.98
%     low_u3      u3 below 0.12, u2 inside the households' band, up to 0.98
%     mid_u2one   u3 in 0.3-0.8, u2 = 1
%     middle      u3 in 0.3-0.8, u2 inside the households' band, up to 0.98
%   While q is a state, the q nodes around the households' band. Each region
%   is summarised by the median, smallest and largest gap, the share of its
%   volume (cells weighted by their size) where the gap exceeds 1% and 100%,
%   and the share of its volume within ten times the floor's certainty
%   equivalent (floored or nearly so).
%
%   One result per case is saved in the grid study's folder as
%   ruin_interp_<NN>_<step>_<arm>_<case>.mat and reused when it holds the same
%   ages; opts.force recomputes. Prints the checks and the table, and with
%   opts.figure draws ruin_interp_<NN>_<step>_<arm>.png in the same folder: the
%   largest and median gap against u3, by age, on the three u2 sets.

arguments
    step
    arm (1,:) char
    cases (1,:) cell
    ages (1,:) double = [45 60 70 85 90]
    opts.force (1,1) logical = false
    opts.figure (1,1) logical = true
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'pension_grid');
S = ladder.steps(); k = ladder.index(step, S);
tag = sprintf('%s_%s_%s', ladder.number(k, S, true), S(k).name, arm);

res = cell(1, numel(cases));
for i = 1:numel(cases)
    file = fullfile(out, sprintf('ruin_interp_%s_%s.mat', tag, cases{i}));
    if ~opts.force && isfile(file)
        old = load(file);
        if isequal(old.ages, ages), res{i} = old; continue; end
    end
    res{i} = compute(step, arm, cases{i}, ages);
    r = res{i}; save(file, '-struct', 'r');
    fprintf('wrote %s\n', file);
end

print_checks(res);
T = region_table(res);
print_table(T);
if opts.figure
    draw(res, fullfile(out, sprintf('ruin_interp_%s.png', tag)), ...
        sprintf('%s, step %s', arm, string(step)));
end
end

% ------------------------------------------------------------------------
function res = compute(step, arm, name, ages)
r = case_load(step, arm, name);
assert(~isempty(r), 'ruin_interp:case', 'the case %s (%s) is not solved.', name, arm);
p = r.p;
assert(~isfield(p, 'u1_grid_age') || isempty(p.u1_grid_age), 'ruin_interp:age_grid', ...
    'the case %s has points that follow age; the test needs fixed axes.', name);
assert(strcmp(p.interp_method, 'linear'), 'ruin_interp:interp', ...
    'the inserted u3 points reproduce the continuation only with linear interpolation.');
[profile, shocks, ann_price] = config.model_inputs(p);
inputs_equal = isequaln(profile, r.profile) && isequal(ann_price, r.ann_price);
s = figures.panel_data(r).sim;

if isempty(gcp('nocreate')), utility.start_pool(); end
nthreads = maxNumCompThreads(1);              % as model.run: BLAS on one thread while the parfor runs
restore  = onCleanup(@() maxNumCompThreads(nthreads));

g1 = p.u1_grid(:); g2 = p.u2_grid(:); g3 = p.u3_grid(:); gq = p.q_grid(:);
N1 = numel(g1); N2 = numel(g2); N3 = numel(g3); Nq = numel(gq);
mid = @(g) (g(1:end-1) + g(2:end)) / 2;
t1 = [mid(g1); g1(end)];                      % N1 points: every u1 midpoint and the top node
t2 = [mid(g2); g2(end)];                      % N2 points: every u2 midpoint and u2 = 1
m3 = mid(g3);
U3 = sort([g3; m3]);
is_mid3 = ismember(U3, m3);
zfun = @(V) ((1 - p.gamma) * V) .^ (1 / (1 - p.gamma));

pt = p;
pt.u1_grid_age = repmat(g1, 1, p.T);
pt.u2_grid_age = repmat(g2, 1, p.T);
pt.u3_grid = U3;
[A1, A2, A3, Aq] = ndgrid(t1, t2, U3, gq);
grid0 = {g1, g2, g3, gq};

res = struct('case_name', name, 'arm', arm, 'step', step, 'ages', ages, ...
    'gamma', p.gamma, 'phi_floor', p.phi_floor, 'inputs_equal', inputs_equal, ...
    'u1_grid', g1, 'u2_grid', g2, 'u3_grid', g3, 'q_grid', gq, ...
    't1', t1, 't2', t2, 'U3', U3, 'is_mid3', is_mid3);
res.age = struct([]);
for a = ages
    t = a - p.age0 + 1;
    assert(t >= 1 && t < p.T, 'ruin_interp:age', 'age %d has no next period.', a);
    tic_a = tic;
    V_next   = r.sol.V(:, :, :, :, t + 1);
    pol_next = struct('c', r.sol.c_pol(:, :, :, :, t + 1), 'pi', r.sol.pi_pol(:, :, :, :, t + 1));

    % 1. The step on the nodes gives back the saved values.
    [Vn, cn, pn] = solver.bellman_step_lna(t, V_next, p, r.profile, shocks, r.ann_price, pol_next);
    z_saved = zfun(r.sol.V(:, :, :, :, t));
    node = struct('dz', max(abs(zfun(Vn(:)) ./ z_saved(:) - 1)), ...
        'dc', max(abs(cn(:) - reshape(r.sol.c_pol(:, :, :, :, t), [], 1))), ...
        'dpi', max(abs(pn(:) - reshape(r.sol.pi_pol(:, :, :, :, t), [], 1))));

    % 2. Next age's value with the u3 midpoints inserted, and the check that
    %    the continuation is unchanged.
    Zn = zfun(V_next);
    Zr = permute(Zn, [3 1 2 4]);
    Zr = interp1(g3, reshape(Zr, N3, []), U3, 'linear');
    Zr = permute(reshape(Zr, numel(U3), N1, N2, Nq), [2 3 1 4]);
    V_next_r = Zr .^ (1 - p.gamma) / (1 - p.gamma);
    rng(1);
    Q = [rand(2e5, 3), gq(1) + (gq(end) - gq(1)) * rand(2e5, 1)];
    Q(1:2:end, 2) = 1 - 1e-3 * rand(1e5, 1);  % half the checks next to u2 = 1
    Q(1:4:end, 3) = 0.15 * rand(5e4, 1);      % and a quarter next to u3 = 0
    F0 = griddedInterpolant(grid0, Zn, 'linear', 'nearest');
    F1 = griddedInterpolant({g1, g2, U3, gq}, zfun(V_next_r), 'linear', 'nearest');
    cont_dz = max(abs(F1(Q) ./ F0(Q) - 1));

    % 3. The step at the test states, warm-started from next age's policy there.
    pol_t = struct('c', interpn4(grid0, pol_next.c, A1, A2, A3, Aq), ...
                   'pi', interpn4(grid0, pol_next.pi, A1, A2, A3, Aq));
    [Vb, cb] = solver.bellman_step_lna(t, V_next_r, pt, r.profile, shocks, r.ann_price, pol_t);
    z_bell = zfun(Vb);
    z_int  = interpn4(grid0, z_saved, A1, A2, A3, Aq);
    gap = z_int ./ z_bell - 1;

    % The households at this age
    lam = s.lambda(:, t);
    u2h = (s.sA(:, t) + s.sH(:, t)) ./ max(1 - lam, 1e-12);
    band = struct('u1', prctile(lam, [5 95]), 'u2', prctile(u2h, [5 95]), ...
                  'q', prctile(s.q(:, t), [5 95]), 'q_live', any(p.q_live(t:end)));

    e = struct('age', a, 't', t, 'node', node, 'cont_dz', cont_dz, ...
        'z_int', z_int, 'z_bell', z_bell, 'gap', gap, 'c_bell', cb, ...
        'floor_ce', p.phi_floor * A1, 'band', band, 'sec', toc(tic_a));
    res.age = [res.age, e];
    fprintf('%s age %d: nodes dz %.1e dc %.1e dpi %.1e, continuation dz %.1e, %d test states, %.0f s\n', ...
        name, a, node.dz, node.dc, node.dpi, cont_dz, numel(gap), e.sec);
end
end

% ------------------------------------------------------------------------
function v = interpn4(grid0, F, A1, A2, A3, Aq)
%INTERPN4  Linear interpolation on the (u1, u2, u3, q) grid, flat outside, as the solver.
if numel(grid0{4}) == 1
    G = griddedInterpolant(grid0(1:3), F, 'linear', 'nearest');
    v = G(A1, A2, A3);
else
    G = griddedInterpolant(grid0, F, 'linear', 'nearest');
    v = G(A1, A2, A3, Aq);
end
end

% ------------------------------------------------------------------------
function M = region_masks(res, e)
%REGION_MASKS  The test states of each region, and the volume of each cell.
t1 = res.t1; t2 = res.t2; U3 = res.U3; gq = res.q_grid;
g1 = res.u1_grid; g2 = res.u2_grid; g3 = res.u3_grid;
n1 = numel(t1); n2 = numel(t2);
% u1: midpoints of the intervals that overlap the households' band
in1 = false(n1, 1);
in1(1:n1-1) = g1(2:end) >= e.band.u1(1) & g1(1:end-1) <= e.band.u1(2);
w1 = [diff(g1); 0];
% u2: midpoints in the band up to 0.98, midpoints above 0.98, and u2 = 1
ov2 = false(n2, 1);
ov2(1:n2-1) = g2(2:end) >= e.band.u2(1) & g2(1:end-1) <= e.band.u2(2);
is_mid2 = (1:n2).' < n2;
mid2 = ov2 & t2 <= 0.98 & is_mid2;
hi2  = t2 > 0.98 & is_mid2;
one2 = ~is_mid2;
w2 = [diff(g2); 1];
% u3: midpoints only
w3 = zeros(numel(U3), 1);
[~, j] = ismember(U3(res.is_mid3), (g3(1:end-1) + g3(2:end)) / 2);
d3 = diff(g3); w3(res.is_mid3) = d3(j);
low3 = res.is_mid3 & U3 < 0.12;
mid3 = res.is_mid3 & U3 >= 0.3 & U3 <= 0.8;
% q: the nodes around the households' band while q is a state, otherwise q = 1
if e.band.q_live
    lo = find(gq <= e.band.q(1), 1, 'last'); if isempty(lo), lo = 1; end
    hi = find(gq >= e.band.q(2), 1, 'first'); if isempty(hi), hi = numel(gq); end
    inq = false(numel(gq), 1); inq(lo:hi) = true;
else
    inq = gq == 1;
end
along = @(v, d) reshape(v, [ones(1, d - 1), numel(v), 1]);
M.w = w1 .* along(w2, 2) .* along(w3, 3) .* ones(1, 1, 1, numel(gq));
sel = @(m2, m3) in1 & along(m2, 2) & along(m3, 3) & along(inq, 4);
M.names = {'corner', 'corner_in', 'low_u3', 'mid_u2one', 'middle'};
M.mask = {sel(one2, low3), sel(hi2, low3), sel(mid2, low3), sel(one2, mid3), sel(mid2, mid3)};
M.u2sets = {one2, hi2, mid2};
M.in1 = in1; M.inq = inq;
end

% ------------------------------------------------------------------------
function T = region_table(res)
rows = {};
for i = 1:numel(res)
    for e = res{i}.age
        M = region_masks(res{i}, e);
        near = e.z_bell < 10 * e.floor_ce;
        for k = 1:numel(M.names)
            m = M.mask{k};
            g = e.gap(m); w = M.w(m);
            if isempty(g)
                st = [0 NaN NaN NaN NaN NaN NaN];
            else
                st = [numel(g), 100 * median(g), 100 * min(g), 100 * max(g), ...
                      sum(w .* (abs(g) > 0.01)) / sum(w), sum(w .* (g > 1)) / sum(w), ...
                      sum(w .* near(m)) / sum(w)];
            end
            rows(end+1, :) = {string(res{i}.case_name), e.age, string(M.names{k}), ...
                st(1), st(2), st(3), st(4), st(5), st(6), st(7)}; %#ok<AGROW>
        end
    end
end
T = cell2table(rows, 'VariableNames', {'case_name', 'age', 'region', 'cells', 'median_pct', ...
    'min_pct', 'max_pct', 'vol_over_1pct', 'vol_over_100pct', 'vol_near_floor'});
end

function print_checks(res)
fprintf('\nChecks: the step on the nodes against the saved values (largest CE gap, c, pi);\n');
fprintf('the continuation with the u3 midpoints inserted against the solved one (largest CE gap).\n');
fprintf('| case | inputs equal | age | nodes CE | nodes c | nodes pi | continuation CE | seconds |\n|---|---|---|---|---|---|---|---|\n');
for i = 1:numel(res)
    for e = res{i}.age
        fprintf('| %s | %d | %d | %.1e | %.1e | %.1e | %.1e | %.0f |\n', res{i}.case_name, ...
            res{i}.inputs_equal, e.age, e.node.dz, e.node.dc, e.node.dpi, e.cont_dz, e.sec);
    end
end
end

function print_table(T)
fprintf('\nInterpolated over Bellman value at the same state, certainty-equivalent gap (%%), by region.\n');
fprintf('vol: share of the region''s volume with |gap| > 1%%, with gap > 100%%, and within 10x the floor CE.\n');
fprintf('| case | age | region | cells | median %% | min %% | max %% | vol >1%% | vol >100%% | vol near floor |\n');
fprintf('|---|---|---|---|---|---|---|---|---|---|\n');
for j = 1:height(T)
    fprintf('| %s | %d | %s | %d | %s | %s | %s | %.3f | %.3f | %.3f |\n', T.case_name(j), T.age(j), ...
        T.region(j), T.cells(j), fmt(T.median_pct(j)), fmt(T.min_pct(j)), fmt(T.max_pct(j)), ...
        T.vol_over_1pct(j), T.vol_over_100pct(j), T.vol_near_floor(j));
end
end

function s = fmt(v)
if isnan(v), s = '-'; elseif abs(v) >= 1e4, s = sprintf('%.2g', v); else, s = sprintf('%.3g', v); end
end

% ------------------------------------------------------------------------
function draw(res, file, what)
%DRAW  Largest (solid) and median (dashed) |gap| over the u1 band, against u3,
%   by age (rows) and u2 set (columns); filled markers where the largest gap
%   is positive (interpolation above the Bellman value).
hex = @(h) sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;
col = {hex('#0b0b0b'), hex('#eb6834'), hex('#1baf7a'), hex('#256abf'), hex('#e87ba4')};
ages = res{1}.ages; na = numel(ages);
setn = {'u2 = 1 (no liquid saving)', 'u2 between nodes above 0.98', 'u2 inside the households'' band'};
fig = figure('Visible', 'off', 'Position', [20 20 1500, 260 * na + 90], 'Color', 'w');
tl = tiledlayout(fig, na, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('%s: interpolated value against the Bellman value at the same state, between grid points', what), ...
    'Certainty-equivalent gap |interpolated / Bellman - 1| over the u1 band of the households; solid: largest, dashed: median; filled: interpolation above'}, ...
    'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
h = gobjects(1, numel(res));
for ia = 1:na
    for js = 1:3
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        set(ax, 'YScale', 'log', 'FontSize', 8.5);
        for i = 1:numel(res)
            e = res{i}.age(ia); M = region_masks(res{i}, e);
            x = res{i}.U3(res{i}.is_mid3);
            G = e.gap(:, :, res{i}.is_mid3, :);
            G = G(M.in1, M.u2sets{js}, :, M.inq);
            G = permute(G, [3 1 2 4]); G = reshape(G, numel(x), []);
            if isempty(G), continue; end
            [mx, im] = max(abs(G), [], 2);
            sg = G(sub2ind(size(G), (1:numel(x)).', im));
            md = median(abs(G), 2);
            mx = max(mx, 1e-8); md = max(md, 1e-8);
            h(i) = plot(ax, x, 100 * mx, '-', 'Color', col{i}, 'LineWidth', 1.5);
            plot(ax, x, 100 * md, '--', 'Color', col{i}, 'LineWidth', 1);
            pos = sg > 0;
            plot(ax, x(pos), 100 * mx(pos), 'o', 'Color', col{i}, 'MarkerFaceColor', col{i}, 'MarkerSize', 4);
            plot(ax, x(~pos), 100 * mx(~pos), 'o', 'Color', col{i}, 'MarkerFaceColor', 'w', 'MarkerSize', 4);
        end
        yline(ax, 1, 'k:'); xline(ax, 0.12, ':', 'Color', [0.5 0.5 0.5]);
        xlim(ax, [0 1]); ylim(ax, [1e-6 1e10]);
        set(ax, 'YTick', 10 .^ (-6:2:10), 'YTickLabel', arrayfun(@(v) sprintf('%g%%', v), 10 .^ (-6:2:10), 'UniformOutput', false));
        title(ax, sprintf('age %d: %s', ages(ia), setn{js}), 'FontSize', 9.5, 'Interpreter', 'none');
        if ia == na, xlabel(ax, 'u3 = pot / (pot + house), midpoints between u3 points'); end
    end
end
ok = isgraphics(h);
legend(nexttile(tl, 1), h(ok), cellfun(@(r) r.case_name, res(ok), 'UniformOutput', false), ...
    'Location', 'northeast', 'Interpreter', 'none', 'FontSize', 7.5);
exportgraphics(fig, file, 'Resolution', 100);
close(fig);
fprintf('wrote %s\n', file);
end
