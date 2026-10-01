function p = build_state_grids(p, dims, gh_n)
%BUILD_STATE_GRIDS  Rebuild the state grid, anchors included.
%
%   p = utility.build_state_grids(p, dims)
%   p = utility.build_state_grids(p, dims, gh_n)
%   p = utility.build_state_grids(p)          % rebuild at the current sizes
%
%   Every run script that overrides the production grid does the same four
%   things: set the three sizes, rebuild the three linspaces, re-insert the
%   calibrated welfare anchors, and rely on the solver to catch it if the third
%   step was forgotten. This is the one place that happens.
%
%   Dispatches on p.grid_type:
%     'lna'  -> the (u1, u2, u3) cube,     dims = [N_u1 N_u2 N_u3]
%     else   -> the (lambda, s_A, s_H) simplex, dims = [N_lambda N_sA N_sH]
%
%   Anchor re-insertion is why the returned sizes can exceed dims by up to 2 on
%   two of the three axes: p.b0 and p.b_alt are forced on as exact nodes and the
%   counts are refreshed from the resulting vectors, never from dims. Read them
%   back off p. On the simplex that affects lambda and s_H; on the cube, u1 and
%   u2. The third axis (s_A, u3) is untouched -- the anchor sits at zero there,
%   already node 1 of any linspace.
%
%   The membership assert duplicates the solver's guard deliberately, so it
%   fires at the call site that rebuilt the grid rather than inside the solver
%   later. The solver's copy is the backstop for grids built any other way.

is_lna = isfield(p, 'grid_type') && strcmp(char(p.grid_type), 'lna');

if nargin >= 3 && ~isempty(gh_n)
    assert(isnumeric(gh_n) && isscalar(gh_n) && gh_n == round(gh_n) && gh_n >= 1, ...
        'build_state_grids:gh_n', 'gh_n must be a positive integer (got %s).', ...
        mat2str(gh_n));
    p.gh_n = gh_n;
end

if nargin < 2, dims = []; end
if ~isempty(dims)
    assert(isnumeric(dims) && numel(dims) == 3 && all(dims == round(dims)) ...
           && all(dims >= 2), 'build_state_grids:dims', ...
        'dims must be three integers >= 2 (got %s).', mat2str(dims));
end

% Income share lambda = Y/W is bounded away from both ends. It never reaches 0
% (income is always positive, and lambda = 0 is an absorbing no-income state
% that the solver cannot leave), and it is capped from above by housing wealth:
% W >= H + Y, so lambda <= 1/(1 + h_mult). We span [lam_lo, lam_hi] with margin
% for the housing and income shocks that push it around over the life cycle,
% rather than a full [0, 1] axis whose low end is unreachable and numerically
% unstable. Both coordinate systems use the same bounds.
[lam_lo, lam_hi] = lambda_bounds(p);

if is_lna
    if ~isempty(dims)
        p.N_u1 = dims(1); p.N_u2 = dims(2); p.N_u3 = dims(3);
    end
    assert(all(isfield(p, {'N_u1', 'N_u2', 'N_u3'})), 'build_state_grids:noN', ...
        'p has no N_u1/N_u2/N_u3 and no dims were supplied.');
    % u1 = lambda concentrates at the low end (it falls from ~0.20 at the
    % anchor to ~0.015 by retirement) and u2 = illiquid share of non-income
    % wealth concentrates at the HIGH end, because u2 -> 1 is no liquid wealth,
    % which is where the floor binds and where the two coordinate systems were
    % measured to disagree. u3 is used fairly evenly and stays uniform.
    % The first axis spans whatever p.coord1 put on it. For the default 'yw'
    % that is lambda and these are the bounds computed above; otherwise the
    % reachable image of [lam_lo, lam_hi] under the chart, over every age.
    [v_lo, v_hi] = coord1_bounds(p, lam_lo, lam_hi);
    % p.grid_nodes overrides the placement rules with the axes themselves, one
    % field per axis. utility.auto_state_grids fills it from measured
    % occupancy; set it by hand to pin an axis exactly. A field that is absent
    % or empty falls through to the rule below, so one axis can be pinned and
    % the others left alone. Anchors are still spliced in afterwards, so the
    % returned axis can be up to two nodes longer than what was handed in.
    given = node_override(p);
    if ~isempty(given.u1)
        p.u1_grid = given.u1; p.N_u1 = numel(given.u1);
    else
        switch grid_space(p)
            case 'logratio', p.u1_grid = ratio_nodes(p.N_u1, v_lo, v_hi);
            otherwise,       p.u1_grid = cluster_lo(p.N_u1, spacing_pow(p), v_lo, v_hi);
        end
    end
    if ~isempty(given.u2)
        p.u2_grid = given.u2; p.N_u2 = numel(given.u2);
    else
        switch grid_space(p)
            case 'logratio', p.u2_grid = ratio_nodes_unit(p.N_u2);
            otherwise,       p.u2_grid = cluster_hi(p.N_u2, spacing_pow_u2(p), u2_low(p));
        end
    end
    if ~isempty(given.u3)
        p.u3_grid = given.u3; p.N_u3 = numel(given.u3);
    else
        [u3lo, u3hi] = u3_range(p);
        p.u3_grid = linspace(u3lo, u3hi, p.N_u3).';
    end
    p = config.insert_anchor_nodes(p);
    c1 = config.coord1(p, 1, []);
    check_anchors(p, 'u1_grid', 'u2_grid', ...
                  @(b, hm) c1.fwd(1 ./ (1 + hm + b), hm ./ (hm + b), 0), ...
                  @(b, hm) hm ./ (hm + b), 'u1', 'u2');
else
    if ~isempty(dims)
        p.N_lambda = dims(1); p.N_sA = dims(2); p.N_sH = dims(3);
    end
    assert(all(isfield(p, {'N_lambda', 'N_sA', 'N_sH'})), 'build_state_grids:noN', ...
        'p has no N_lambda/N_sA/N_sH and no dims were supplied.');
    % Same idea on the simplex: lambda concentrates low, s_H high (large s_H
    % with small lambda is the small-s_X corner). s_A stays uniform.
    p.lambda_grid = cluster_lo(p.N_lambda, spacing_pow(p), lam_lo, lam_hi);
    p.sA_grid     = linspace(0, 1, p.N_sA).';
    p.sH_grid     = cluster_hi(p.N_sH, spacing_pow(p));
    p = config.insert_anchor_nodes(p);
    check_anchors(p, 'lambda_grid', 'sH_grid', @(b, hm) 1 ./ (1 + hm + b), ...
                  @(b, hm) hm ./ (1 + hm + b), 'lambda', 's_H');
end
end

function g = node_override(p)
%NODE_OVERRIDE  Axis vectors supplied on p.grid_nodes, validated.
%   Each field must be a sorted vector of at least two distinct finite nodes.
%   u1 is checked against the reachable income-share range only loosely -- the
%   caller may deliberately narrow it -- but u2 and u3 are shares and must lie
%   in the unit interval, since the solver clamps next period's coordinates
%   there and a node outside it could never be reached.
g = struct('u1', [], 'u2', [], 'u3', []);
if ~isfield(p, 'grid_nodes') || isempty(p.grid_nodes), return; end
gn = p.grid_nodes;
assert(isstruct(gn), 'build_state_grids:grid_nodes', ...
    'p.grid_nodes must be a struct with fields u1, u2 and/or u3.');
f = {'u1', 'u2', 'u3'};
for i = 1:numel(f)
    if ~isfield(gn, f{i}) || isempty(gn.(f{i})), continue; end
    v = double(gn.(f{i})(:));
    assert(numel(v) >= 2 && all(isfinite(v)), 'build_state_grids:grid_nodes', ...
        'p.grid_nodes.%s needs at least two finite nodes.', f{i});
    assert(all(diff(sort(v)) > 0), 'build_state_grids:grid_nodes', ...
        'p.grid_nodes.%s has repeated nodes.', f{i});
    if ismember(f{i}, {'u2', 'u3'})
        assert(min(v) >= 0 && max(v) <= 1, 'build_state_grids:grid_nodes', ...
            'p.grid_nodes.%s must lie in [0, 1] (got [%.4g, %.4g]).', ...
            f{i}, min(v), max(v));
    else
        assert(min(v) > 0, 'build_state_grids:grid_nodes', ...
            'p.grid_nodes.u1 must be strictly positive (got %.4g).', min(v));
    end
    g.(f{i}) = sort(v);
end
end

function [lo, hi] = lambda_bounds(p)
%LAMBDA_BOUNDS  Reachable range of the income share lambda = Y/W.
%   lo: a small positive floor, below the smallest income share a wealthy old
%       household reaches, but strictly above the absorbing lambda = 0 node.
%   hi: the largest income share. Housing bounds it: W >= H + Y gives
%       lambda <= 1/(1+h_mult), with headroom for the housing-price and income
%       shocks that raise it over the life cycle.
%
%   With NO housing there is nothing to bound it. A household that runs its
%   liquid wealth down to zero has W = Y and lambda = 1 exactly, and old
%   households do exactly that. Capping below 1 then puts them off the grid,
%   where griddedInterpolant extrapolates 'nearest' and freezes the
%   continuation value -- which distorts the objective enough to move the
%   equity share by tens of points. Raising the cap short of 1 only relocates
%   the pile-up, because lambda -> 1 is where wealth -> 0 lands whatever the
%   cap is. So the no-housing case spans the full axis. lambda = 1 is a
%   well-posed state: liquid wealth is zero and the household consumes out of
%   income.
lo = 0.002;
if isfield(p, 'h_mult') && isscalar(p.h_mult)
    if p.h_mult > 0
        hi = min(0.9, 3 / (1 + p.h_mult));
    else
        hi = 1.0;
    end
else
    hi = 0.6;      % no h_mult on the struct: leave the legacy default alone
end
if isfield(p, 'lambda_lo') && isscalar(p.lambda_lo), lo = p.lambda_lo; end
if isfield(p, 'lambda_hi') && isscalar(p.lambda_hi), hi = p.lambda_hi; end
assert(lo > 0 && hi > lo, 'build_state_grids:lambda_bounds', ...
    'need 0 < lambda_lo (%.4g) < lambda_hi (%.4g).', lo, hi);
end

function check_anchors(p, f1, f2, a1_fun, a2_fun, n1, n2)
% Both calibrated buffers must be exact members of the two anchored axes.
if ~all(isfield(p, {'b0', 'b_alt', 'h_mult'})), return; end
b_a  = [p.b0, p.b_alt];
name = {'b0', 'b_alt'};
for a = 1:2
    a1 = a1_fun(b_a(a), p.h_mult);
    a2 = a2_fun(b_a(a), p.h_mult);
    assert(min(abs(p.(f1) - a1)) == 0, 'build_state_grids:anchor_missing', ...
        ['%s anchor %.17g (buffer %s = %.6g) is not an exact node after the ' ...
         'rebuild -- config.insert_anchor_nodes did not take.'], n1, a1, name{a}, b_a(a));
    assert(min(abs(p.(f2) - a2)) == 0, 'build_state_grids:anchor_missing', ...
        ['%s anchor %.17g (buffer %s = %.6g) is not an exact node after the ' ...
         'rebuild -- config.insert_anchor_nodes did not take.'], n2, a2, name{a}, b_a(a));
end
end

function q = spacing_pow_u2(p)
%SPACING_POW_U2  Clustering exponent for u2 alone. Defaults to grid_pow, which
%   is what every solve before this option did, since one exponent drove both
%   axes.
%
%   They want different things. u1 falls through the life cycle and wants nodes
%   bunched low. u2 does not fall: the occupied band slides from 0.98 at entry
%   down to about 0.70 in midlife and back up past 0.95 in old age, so it wants
%   even coverage of [u2_lo, 1] rather than a pile-up at either end. Clustering
%   u2 toward 1 at grid_pow 2 puts six of fourteen nodes above 0.94 and leaves
%   the 0.80-0.87 band, where the thirty-somethings are, with one.
q = spacing_pow(p);
if isfield(p, 'grid_pow_u2') && isnumeric(p.grid_pow_u2) && isscalar(p.grid_pow_u2)
    q = max(1, double(p.grid_pow_u2));
end
end

function lo = u2_low(p)
%U2_LOW  Bottom of the u2 = (A+H)/(X+A+H) axis. Default 0, which is the full
%   unit axis every solve before this option used.
%
%   u2 is one minus the liquid share, so u2 = 0 is a household whose wealth is
%   entirely liquid. A renter carrying a rent index worth several years of income
%   never comes close: measured over 608,000 simulated household-years at the
%   production calibration the smallest u2 was 0.63, and nothing at all fell
%   below 0.60. Half the axis is therefore unreachable, and the nodes spent on it
%   are nodes not spent on ages 25-35, where the population sits inside a single
%   cell. Raising the floor of the axis moves them.
%
%   Set it only from a measured occupancy range, and leave margin: below the
%   bottom node griddedInterpolant extrapolates 'nearest', which is flat, so a
%   household pushed under it gets a continuation value with no gradient.
lo = 0;
if isfield(p, 'u2_lo') && isnumeric(p.u2_lo) && isscalar(p.u2_lo)
    lo = max(0, min(0.9, double(p.u2_lo)));
end
end

function q = spacing_pow(p)
%SPACING_POW  Node-clustering exponent. 1 = uniform (the default, and what
%   every solve before this used, so behaviour is unchanged unless asked for).
%   q > 1 concentrates nodes toward the end of the axis the caller cares about.
q = 1;
if isfield(p, 'grid_pow') && isnumeric(p.grid_pow) && isscalar(p.grid_pow)
    q = max(1, double(p.grid_pow));
end
end

function s = grid_space(p)
%GRID_SPACE  How the nodes are placed on u1 and u2.
%   'uniform'  (default) even steps in the coordinate itself, which is what
%              every solve before this option existed used.
%   'logratio' even steps in the RATIO each coordinate encodes.
%
%   Both coordinates are of the form c = 1/(1+x) for a ratio x: u1 = lambda
%   encodes x = (X+A+H)/Y, and u2 encodes x = X/(A+H). That map squashes both
%   ends of x into the ends of c, so an even grid in c spends most of its nodes
%   where x is middling and almost none where x is small or large. Households
%   live at the ends: a young owner has almost no liquid wealth, an old one has
%   spent it, and a wealthy one has a house many times its income. Even steps in
%   log(x) put the nodes where the households are, and because utility is CRRA
%   it is proportional changes in x that decisions respond to.
%
%   This only moves the nodes. Both coordinates keep their meaning, the
%   interpolation is still linear in them, and nothing outside this file needs
%   to know -- the grids were already irregular, since insert_anchor_nodes
%   splices the welfare anchors in wherever they fall.
s = 'uniform';
if isfield(p, 'grid_space') && ~isempty(p.grid_space)
    s = char(p.grid_space);
end
if ~ismember(s, {'uniform', 'logratio'})
    error('build_state_grids:grid_space', ...
        'p.grid_space must be uniform or logratio (got %s).', s);
end
end

function g = ratio_nodes(n, lo, hi)
% Nodes on [lo, hi] geometric in the ratio x = (1-c)/c that c encodes.
%   RATIO_FLOOR is needed because hi = 1 means a ratio of exactly zero (no
%   wealth at all beyond current income), which has no logarithm. Flooring the
%   ratio there still places nodes arbitrarily close to the corner -- 1e-4 is a
%   hundredth of a percent of a year's income, far below anything the household
%   distinguishes -- while keeping the spacing well defined.
RATIO_FLOOR = 1e-4;
x_hi = max((1 - lo) / lo, RATIO_FLOOR);   % lo in c is the LARGE ratio
x_lo = max((1 - hi) / hi, RATIO_FLOOR);
if x_hi <= x_lo, g = linspace(lo, hi, n).'; return; end
x = logspace(log10(x_lo), log10(x_hi), n).';
g = sort(1 ./ (1 + x));
g([1 end]) = [lo; hi];         % pin the endpoints exactly
g = unique(g);
end

function g = ratio_nodes_unit(n)
% As ratio_nodes on the closed unit interval, where the ratio runs to 0 and to
% infinity, so the two endpoints are added rather than derived.
x = logspace(-3, 3, max(n - 2, 2)).';
g = unique([0; sort(1 ./ (1 + x)); 1]);
end

function g = cluster_lo(n, q, lo, hi)
% Nodes on [lo, hi] bunched toward lo. q = 1 spaces them uniformly.
if nargin < 3, lo = 0; end
if nargin < 4, hi = 1; end
g = lo + (hi - lo) * (linspace(0, 1, n).' .^ q);
end

function g = cluster_hi(n, q, lo)
% Nodes on [lo, 1] bunched toward 1. q = 1 reproduces linspace exactly, and
% lo = 0 (the default) is the full unit axis every earlier solve used.
if nargin < 3 || isempty(lo), lo = 0; end
g = lo + (1 - lo) * (1 - (1 - linspace(0, 1, n).') .^ q);
g = sort(g);
end

function [v_lo, v_hi] = coord1_bounds(p, lam_lo, lam_hi)
%COORD1_BOUNDS  Reachable range of the first axis under p.coord1.
%   'yw' returns the lambda bounds unchanged, so the default grid is untouched.
%   Otherwise the chart's forward map is swept over the lambda range, the unit
%   square of (u2, u3) and every age. Both alternative maps are monotone in
%   lambda and in their age coefficient, so a coarse sweep finds the extremes.
%
%   The annuity price is not available here, and it only enters 'yann' through
%   the payout factor (1 - tau_inc)/a(t), which is largest at a(t) = 1. Using
%   that bound widens the axis a little rather than clipping it.
v_lo = lam_lo; v_hi = lam_hi;
if ~isfield(p, 'coord1') || isempty(p.coord1) || strcmp(char(p.coord1), 'yw')
    return
end
q = p;
if strcmp(char(p.coord1), 'hk') && ~isfield(q, 'hk_phi')
    q.hk_phi = config.hk_factor(p);          % cache: coord1 is called T times
end
ann = ones(p.T, 1);
lam = linspace(lam_lo, lam_hi, 41).';
uu  = linspace(0, 1, 11);
[UA, UB] = ndgrid(uu, uu);
lo = inf; hi = -inf;
for t = 1 : p.T
    c = config.coord1(q, t, ann);
    for k = 1:numel(UA)
        v  = c.fwd(lam, UA(k), UB(k));
        lo = min(lo, min(v)); hi = max(hi, max(v));
    end
end
c0   = config.coord1(q, 1, ann);
v_lo = max(lo, 1e-4);
if isfinite(c0.range_hi)
    v_hi = min(hi * 1.02, c0.range_hi - 1e-6);
else
    v_hi = hi * 1.02;                 % ratio charts are unbounded above
end
assert(v_hi > v_lo, 'build_state_grids:coord1_bounds', ...
    'empty first-axis range under p.coord1 = %s.', char(p.coord1));
end

function [lo, hi] = u3_range(p)
%U3_RANGE  Ends of the u3 = A/(A+H) axis. Default [0, 1], the full unit axis
%   every solve before these options used.
%
%   Unlike u1 and u2 the occupied band on u3 slides monotonically -- about
%   0.04-0.08 at 27, 0.54-0.91 at 67, 0.20-0.68 at 90 -- so it wants even
%   coverage of the reachable range rather than clustering at either end. What
%   it does not want is the dead margin: measured over 438,000 household-years
%   u3 never left [0.035, 0.951], so the first and last cells of a unit axis are
%   never visited.
%
%   Set these only from a measured occupancy range, and leave margin. Below the
%   bottom node and above the top one griddedInterpolant extrapolates 'nearest',
%   which is flat, so a household pushed outside gets a continuation value with
%   no gradient and no warning.
lo = 0; hi = 1;
if isfield(p, 'u3_lo') && isnumeric(p.u3_lo) && isscalar(p.u3_lo)
    lo = max(0, min(0.5, double(p.u3_lo)));
end
if isfield(p, 'u3_hi') && isnumeric(p.u3_hi) && isscalar(p.u3_hi)
    hi = min(1, max(lo + 0.1, double(p.u3_hi)));
end
end
