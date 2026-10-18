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
%   Two sets of test states, at the q nodes:
%     u3 only      the u1 and u2 nodes against the u3 nodes and the midpoint
%                  of every u3 interval: the error along u3 alone. Its states
%                  on the nodes must give back the saved values.
%     centres      the midpoint of every u1 and every u2 interval, plus the
%                  node u2 = 1 (no liquid saving, where floored households
%                  sit), against the same u3 points: cell centres, and at the
%                  u3 nodes the error along u1 and u2 alone.
%   The step runs on them through the age grid: this age's u1 and u2 points
%   (p.u1_grid_age, p.u2_grid_age) are the test points, next age's are the
%   solved ones. The u3 midpoints are inserted in the u3 axis, with next age's
%   values interpolated onto them. Inside the grid that leaves the linear
%   continuation exactly as solved. Outside it, griddedInterpolant's 'nearest'
%   extrapolation returns the value at the nearest node in every coordinate,
%   and the inserted points are nodes too. So the centres are also run on the
%   solved u3 axis, and the two runs must agree at the u3 nodes.
%
%   Regions, with u1 inside the band of the middle 90% of the panel's
%   households at that age, u3 at midpoints unless named:
%     corner         centres, u3 below 0.12, u2 = 1
%     corner_in      centres, u3 below 0.12, u2 midpoints above 0.98
%     low_u3         centres, u3 below 0.12, u2 in the households' band, to 0.98
%     mid_u2one      centres, u3 in 0.3-0.8, u2 = 1
%     middle         centres, u3 in 0.3-0.8, u2 in the band: the control
%     corner_u12, low_u12, middle_u12   as corner, low_u3 and middle, at the
%                    u3 nodes (below 0.12, 0.3-0.8): u1 and u2 alone
%     corner_u3      u3 only, u3 below 0.12, u2 = 1
%     low_u3only     u3 only, u3 below 0.12, u2 nodes in the band
%     middle_u3      u3 only, u3 in 0.3-0.8, u2 nodes in the band
%   While q is a state, the q nodes around the households' band. Each region
%   is summarised by the median, smallest and largest gap, the share of its
%   volume (cells weighted by their size) where |gap| exceeds 1% and where the
%   gap exceeds 100%, and the share of its volume where the Bellman value is
%   within ten times the floor's certainty equivalent (floored or nearly so).
%
%   The band is the 5th to 95th percentile of each case's own panel with
%   opts.band = 'own'. By default ('union') it is the union of the cases'
%   bands at each age, so that every grid is read at the same states: the
%   grids' households sit in different places.
%
%   One result per case is saved in the grid study's folder as
%   ruin_interp_<NN>_<step>_<arm>_<case>.mat and reused when it holds the same
%   ages; opts.force recomputes. Prints the checks, the bands and the table,
%   and with opts.figure draws ruin_interp_<NN>_<step>_<arm>_<band>.png in the
%   same folder.

arguments
    step
    arm (1,:) char
    cases (1,:) cell
    ages (1,:) double = [45 60 70 85 90]
    opts.force (1,1) logical = false
    opts.figure (1,1) logical = true
    opts.band (1,:) char {mustBeMember(opts.band, {'union', 'own'})} = 'union'
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
        if isfield(old, 'version') && old.version == 3 && isequal(old.ages, ages)
            res{i} = old; continue
        end
    end
    res{i} = compute(step, arm, cases{i}, ages);
    r = res{i}; save(file, '-struct', 'r');
    fprintf('wrote %s\n', file);
end

if strcmp(opts.band, 'union')
    res = union_band(res);
end
print_checks(res);
print_bands(res);
T = region_table(res);
print_table(T);
if opts.figure
    draw(res, fullfile(out, sprintf('ruin_interp_%s_%s.png', tag, opts.band)), ...
        sprintf('%s, step %s', arm, string(step)), opts.band);
end
end

% ------------------------------------------------------------------------
function res = union_band(res)
%UNION_BAND  Every case's band at each age set to the union of the cases'
%   bands, so that the grids are compared at the same states.
for ia = 1:numel(res{1}.ages)
    b = arrayfun(@(i) res{i}.age(ia).band, 1:numel(res));
    u = b(1);
    for f = {'u1', 'u2', 'q'}
        v = vertcat(b.(f{1}));
        u.(f{1}) = [min(v(:, 1)), max(v(:, 2))];
    end
    for i = 1:numel(res), res{i}.age(ia).band = u; end
end
end

function print_bands(res)
fprintf('\nBands used (5th-95th percentile of the households): u1, u2, q\n');
fprintf('| case | age | u1 | u2 | q |\n|---|---|---|---|---|\n');
for i = 1:numel(res)
    for e = res{i}.age
        b = e.band;
        fprintf('| %s | %d | %.4f-%.4f | %.4f-%.4f | %.3f-%.3f |\n', res{i}.case_name, e.age, b.u1, b.u2, b.q);
    end
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
U3 = sort([g3; mid(g3)]);
zfun = @(V) ((1 - p.gamma) * V) .^ (1 / (1 - p.gamma));
grid0 = {g1, g2, g3, gq};

% The axes of each set of test states: the points and whether each is a node
ax.U = struct('t1', g1, 't2', g2, 'U3', U3, 'node1', true(N1, 1), 'node2', true(N2, 1));
ax.C = struct('t1', [mid(g1); g1(end)], 't2', [mid(g2); g2(end)], 'U3', U3, ...
              'node1', [false(N1 - 1, 1); true], 'node2', [false(N2 - 1, 1); true]);
node3 = ismember(U3, g3);

res = struct('version', 3, 'case_name', name, 'arm', arm, 'step', step, 'ages', ages, ...
    'gamma', p.gamma, 'phi_floor', p.phi_floor, 'inputs_equal', inputs_equal, ...
    'u1_grid', g1, 'u2_grid', g2, 'u3_grid', g3, 'q_grid', gq, 'ax', ax, 'node3', node3);
res.age = struct([]);
for a = ages
    t = a - p.age0 + 1;
    assert(t >= 1 && t < p.T, 'ruin_interp:age', 'age %d has no next period.', a);
    tic_a = tic;
    V_next   = r.sol.V(:, :, :, :, t + 1);
    pol_next = struct('c', r.sol.c_pol(:, :, :, :, t + 1), 'pi', r.sol.pi_pol(:, :, :, :, t + 1));
    z_saved  = zfun(r.sol.V(:, :, :, :, t));

    % Next age's value with the u3 midpoints inserted, and the check that the
    % continuation is unchanged inside the grid.
    Zn = zfun(V_next);
    Zr = permute(Zn, [3 1 2 4]);
    Zr = interp1(g3, reshape(Zr, N3, []), U3, 'linear');
    Zr = permute(reshape(Zr, numel(U3), N1, N2, Nq), [2 3 1 4]);
    V_next_r = Zr .^ (1 - p.gamma) / (1 - p.gamma);
    rng(1);
    Q = [g1(1) + (g1(end) - g1(1)) * rand(2e5, 1), rand(2e5, 2), gq(1) + (gq(end) - gq(1)) * rand(2e5, 1)];
    Q(1:2:end, 2) = 1 - 1e-3 * rand(1e5, 1);  % half the checks next to u2 = 1
    Q(1:4:end, 3) = 0.15 * rand(5e4, 1);      % and a quarter next to u3 = 0
    F0 = griddedInterpolant(grid0, Zn, 'linear', 'nearest');
    F1 = griddedInterpolant({g1, g2, U3, gq}, zfun(V_next_r), 'linear', 'nearest');
    cont_dz = max(abs(F1(Q) ./ F0(Q) - 1));

    % The households at this age
    lam = s.lambda(:, t);
    u2h = (s.sA(:, t) + s.sH(:, t)) ./ max(1 - lam, 1e-12);
    band = struct('u1', prctile(lam, [5 95]), 'u2', prctile(u2h, [5 95]), ...
                  'q', prctile(s.q(:, t), [5 95]), 'q_live', any(p.q_live(t:end)));

    % u3 only, and the centres, on the axis with the midpoints inserted
    U = run_set(t, p, r, shocks, ax.U, V_next_r, pol_next, z_saved, grid0, zfun);
    C = run_set(t, p, r, shocks, ax.C, V_next_r, pol_next, z_saved, grid0, zfun);
    % The centres on the solved u3 axis, to compare at the u3 nodes
    ax0 = ax.C; ax0.U3 = g3;
    C0 = run_set(t, p, r, shocks, ax0, V_next, pol_next, z_saved, grid0, zfun);

    zn = U.z_bell(:, :, node3, :);
    chk = struct('cont_dz', cont_dz, 'nodes_dz', max(abs(zn(:) ./ z_saved(:) - 1)), ...
        'nodes_dc', max(abs(reshape(U.c_bell(:, :, node3, :), [], 1) - reshape(r.sol.c_pol(:, :, :, :, t), [], 1))), ...
        'axis_dz', max(abs(reshape(C.z_bell(:, :, node3, :), [], 1) ./ C0.z_bell(:) - 1)));
    M = region_masks(ax.C, g1, g2, g3, gq, node3, band);
    d = abs(C.z_bell(:, :, node3, :) ./ C0.z_bell - 1);
    chk.axis_dz_band = max(d(M.in1 & reshape(M.inq, 1, 1, 1, []) & true(size(d))));
    M = region_masks(ax.U, g1, g2, g3, gq, node3, band);
    d = abs(zn ./ z_saved - 1);
    chk.nodes_dz_band = max(d(M.in1 & reshape(M.inq, 1, 1, 1, []) & true(size(d))));

    U = rmfield(U, 'c_bell'); C = rmfield(C, 'c_bell');
    e = struct('age', a, 't', t, 'chk', chk, 'band', band, 'U', U, 'C', C, 'sec', toc(tic_a));
    res.age = [res.age, e];
    fprintf('%s age %d: continuation %.1e, nodes CE %.1e (band %.1e) c %.1e, inserted axis %.1e (band %.1e), %.0f s\n', ...
        name, a, chk.cont_dz, chk.nodes_dz, chk.nodes_dz_band, chk.nodes_dc, chk.axis_dz, chk.axis_dz_band, e.sec);
end
end

% ------------------------------------------------------------------------
function out = run_set(t, p, r, shocks, ax, V_next, pol_next, z_saved, grid0, zfun)
%RUN_SET  The Bellman step at one tensor of test states, and the value
%   interpolated from the saved nodes at the same states.
pt = p;
pt.u1_grid_age = repmat(grid0{1}, 1, p.T); pt.u1_grid_age(:, t) = ax.t1;
pt.u2_grid_age = repmat(grid0{2}, 1, p.T); pt.u2_grid_age(:, t) = ax.t2;
pt.u3_grid = ax.U3;
[A1, A2, A3, Aq] = ndgrid(ax.t1, ax.t2, ax.U3, grid0{4});
pol_t = struct('c', interpn4(grid0, pol_next.c, A1, A2, A3, Aq), ...
               'pi', interpn4(grid0, pol_next.pi, A1, A2, A3, Aq));
[Vb, cb] = solver.bellman_step_lna(t, V_next, pt, r.profile, shocks, r.ann_price, pol_t);
out.z_bell = zfun(Vb);
out.c_bell = cb;
out.z_int  = interpn4(grid0, z_saved, A1, A2, A3, Aq);
out.gap    = out.z_int ./ out.z_bell - 1;
end

function v = interpn4(grid0, F, A1, A2, A3, Aq)
%INTERPN4  Linear interpolation on the (u1, u2, u3, q) grid, 'nearest' outside, as the solver.
if isscalar(grid0{4})
    G = griddedInterpolant(grid0(1:3), F, 'linear', 'nearest');
    v = G(A1, A2, A3);
else
    G = griddedInterpolant(grid0, F, 'linear', 'nearest');
    v = G(A1, A2, A3, Aq);
end
end

% ------------------------------------------------------------------------
function M = region_masks(a, g1, g2, g3, gq, node3, band)
%REGION_MASKS  Which test states of one set fall in each u1, u2, u3 and q
%   group, and the volume each one stands for.
vor = @(g) [diff(g(1:2)) / 2; (g(3:end) - g(1:end-2)) / 2; diff(g(end-1:end)) / 2];
% u1: midpoints of the intervals that overlap the households' band, or the
% nodes inside it with one more on each side
[in1, w1] = axis_group(a.t1, a.node1, g1, band.u1, vor);
% u2
[inb2, w2] = axis_group(a.t2, a.node2, g2, band.u2, vor);
one2 = a.t2 == 1;
hi2  = a.t2 > 0.98 & ~one2;
mid2 = inb2 & a.t2 <= 0.98;
% u3
U3 = a.U3; mids3 = (g3(1:end-1) + g3(2:end)) / 2;
w3 = zeros(numel(U3), 1);
[im, j] = ismember(U3, mids3); d3 = diff(g3); w3(im) = d3(j(im));
v3 = vor(g3); [in3, j3] = ismember(U3, g3); w3(in3) = v3(j3(in3));
low3 = ~node3 & U3 < 0.12;
mid3 = ~node3 & U3 >= 0.3 & U3 <= 0.8;
nlow3 = node3 & U3 < 0.12;
nmid3 = node3 & U3 >= 0.3 & U3 <= 0.8;
% q: the nodes around the households' band while q is a state, otherwise q = 1
if band.q_live
    lo = find(gq <= band.q(1), 1, 'last');  if isempty(lo), lo = 1; end
    hi = find(gq >= band.q(2), 1, 'first'); if isempty(hi), hi = numel(gq); end
    inq = false(numel(gq), 1); inq(lo:hi) = true;
else
    inq = gq == 1;
end
along = @(v, d) reshape(v, [ones(1, d - 1), numel(v), 1]);
M.w = w1 .* along(w2, 2) .* along(w3, 3) .* ones(1, 1, 1, numel(gq));
M.sel = @(m2, m3) in1 & along(m2, 2) & along(m3, 3) & along(inq, 4);
M.u2 = struct('one', one2, 'hi', hi2, 'mid', mid2);
M.u3 = struct('low', low3, 'mid', mid3, 'nlow', nlow3, 'nmid', nmid3);
M.in1 = in1; M.inq = inq;
end

function [in, w] = axis_group(tp, is_node, g, b, vor)
%AXIS_GROUP  Test points of one axis inside a band, and their weights.
in = false(numel(tp), 1); w = zeros(numel(tp), 1);
d = diff(g); v = vor(g);
for i = 1:numel(tp)
    if is_node(i)
        j = find(g == tp(i), 1);
        lo = find(g <= b(1), 1, 'last'); if isempty(lo), lo = 1; end
        hi = find(g >= b(2), 1, 'first'); if isempty(hi), hi = numel(g); end
        in(i) = j >= lo && j <= hi; w(i) = v(j);
    else
        j = find(g < tp(i), 1, 'last');
        in(i) = g(j + 1) >= b(1) && g(j) <= b(2); w(i) = d(j);
    end
end
end

function R = regions()
%REGIONS  name, set of test states, u2 group, u3 group.
R = {'corner',     'C', 'one', 'low'
     'corner_in',  'C', 'hi',  'low'
     'low_u3',     'C', 'mid', 'low'
     'mid_u2one',  'C', 'one', 'mid'
     'middle',     'C', 'mid', 'mid'
     'corner_u12', 'C', 'one', 'nlow'
     'low_u12',    'C', 'mid', 'nlow'
     'middle_u12', 'C', 'mid', 'nmid'
     'corner_u3',  'U', 'one', 'low'
     'low_u3only', 'U', 'mid', 'low'
     'middle_u3',  'U', 'mid', 'mid'};
end

% ------------------------------------------------------------------------
function T = region_table(res)
R = regions();
rows = {};
for i = 1:numel(res)
    x = res{i};
    for e = x.age
        for k = 1:size(R, 1)
            M = region_masks(x.ax.(R{k, 2}), x.u1_grid, x.u2_grid, x.u3_grid, x.q_grid, x.node3, e.band);
            m = M.sel(M.u2.(R{k, 3}), M.u3.(R{k, 4}));
            P = e.(R{k, 2});
            floor_ce = x.phi_floor * x.ax.(R{k, 2}).t1 .* ones(size(m));   % the floor's z, phi_floor u1
            g = P.gap(m); w = M.w(m); near = P.z_bell(m) < 10 * floor_ce(m);
            if isempty(g)
                st = [0 NaN NaN NaN NaN NaN NaN];
            else
                st = [numel(g), 100 * median(g), 100 * min(g), 100 * max(g), ...
                      sum(w .* (abs(g) > 0.01)) / sum(w), sum(w .* (g > 1)) / sum(w), ...
                      sum(w .* near) / sum(w)];
            end
            rows(end+1, :) = {string(x.case_name), e.age, string(R{k, 1}), ...
                st(1), st(2), st(3), st(4), st(5), st(6), st(7)}; %#ok<AGROW>
        end
    end
end
T = cell2table(rows, 'VariableNames', {'case_name', 'age', 'region', 'cells', 'median_pct', ...
    'min_pct', 'max_pct', 'vol_over_1pct', 'vol_over_100pct', 'vol_near_floor'});
end

function print_checks(res)
fprintf('\nChecks, largest relative CE difference: the continuation with the u3 midpoints inserted against\n');
fprintf('the solved one inside the grid; the step on the nodes against the saved values (CE and c);\n');
fprintf('the centres on the inserted u3 axis against the solved axis at the u3 nodes (all, and in the u1 and q bands).\n');
fprintf('| case | inputs equal | age | continuation | nodes CE | in band | nodes c | inserted axis | in band | seconds |\n|---|---|---|---|---|---|---|---|---|---|\n');
for i = 1:numel(res)
    for e = res{i}.age
        c = e.chk;
        fprintf('| %s | %d | %d | %.1e | %.1e | %.1e | %.1e | %.1e | %.1e | %.0f |\n', res{i}.case_name, ...
            res{i}.inputs_equal, e.age, c.cont_dz, c.nodes_dz, c.nodes_dz_band, c.nodes_dc, c.axis_dz, c.axis_dz_band, e.sec);
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
function draw(res, file, what, band)
%DRAW  Largest (solid) and median (dashed) |gap| over the u1 band and the
%   u2 group, against u3, by age (rows); filled markers where the largest gap
%   is positive (interpolation above the Bellman value).
hex = @(h) sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;
col = {hex('#0b0b0b'), hex('#eb6834'), hex('#1baf7a'), hex('#256abf'), hex('#e87ba4')};
ages = res{1}.ages; na = numel(ages);
cols = {'U', 'one', 'u3 only, u2 = 1'
        'U', 'mid', 'u3 only, u2 nodes in the households'' band'
        'C', 'one', 'cell centres, u2 = 1'
        'C', 'mid', 'cell centres, u2 in the households'' band'};
fig = figure('Visible', 'off', 'Position', [20 20 1800, 250 * na + 90], 'Color', 'w');
tl = tiledlayout(fig, na, size(cols, 1), 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('%s: interpolated value against the Bellman value at the same state, between grid points', what), ...
    sprintf(['Certainty-equivalent gap |interpolated / Bellman - 1| at u3 midpoints, over the households'' u1 band ' ...
             '(%s); solid: largest, dashed: median; filled: interpolation above'], ...
            strrep(strrep(band, 'union', 'union of the cases'' bands'), 'own', 'each case''s own panel'))}, ...
    'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
h = gobjects(1, numel(res));
for ia = 1:na
    for jc = 1:size(cols, 1)
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        set(ax, 'YScale', 'log', 'FontSize', 8.5);
        for i = 1:numel(res)
            x = res{i}; e = x.age(ia); a = x.ax.(cols{jc, 1});
            M = region_masks(a, x.u1_grid, x.u2_grid, x.u3_grid, x.q_grid, x.node3, e.band);
            m3 = ~x.node3; u3 = a.U3(m3);
            G = e.(cols{jc, 1}).gap(M.in1, M.u2.(cols{jc, 2}), m3, M.inq);
            if isempty(G), continue; end
            G = reshape(permute(G, [3 1 2 4]), numel(u3), []);
            [mx, im] = max(abs(G), [], 2);
            sg = G(sub2ind(size(G), (1:numel(u3)).', im));
            md = median(abs(G), 2);
            mx = max(mx, 1e-8); md = max(md, 1e-8);
            h(i) = plot(ax, u3, 100 * mx, '-', 'Color', col{i}, 'LineWidth', 1.5);
            plot(ax, u3, 100 * md, '--', 'Color', col{i}, 'LineWidth', 1);
            pos = sg > 0;
            plot(ax, u3(pos), 100 * mx(pos), 'o', 'Color', col{i}, 'MarkerFaceColor', col{i}, 'MarkerSize', 4);
            plot(ax, u3(~pos), 100 * mx(~pos), 'o', 'Color', col{i}, 'MarkerFaceColor', 'w', 'MarkerSize', 4);
        end
        yline(ax, 1, 'k:'); xline(ax, 0.12, ':', 'Color', [0.5 0.5 0.5]);
        xlim(ax, [0 1]); ylim(ax, [1e-3 1e7]);
        set(ax, 'YTick', 10 .^ (-3:2:7), 'YTickLabel', arrayfun(@(v) sprintf('%g%%', v), 10 .^ (-3:2:7), 'UniformOutput', false));
        title(ax, sprintf('age %d: %s', ages(ia), cols{jc, 3}), 'FontSize', 9.5, 'Interpreter', 'none');
        if ia == na, xlabel(ax, 'u3 = pot / (pot + house)'); end
    end
end
ok = isgraphics(h);
legend(nexttile(tl, 1), h(ok), cellfun(@(r) r.case_name, res(ok), 'UniformOutput', false), ...
    'Location', 'northeast', 'Interpreter', 'none', 'FontSize', 7.5);
exportgraphics(fig, file, 'Resolution', 100);
close(fig);
fprintf('wrote %s\n', file);
end
