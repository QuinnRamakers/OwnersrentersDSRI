function [g, info] = grid_from_occupancy(x, n, lo_hard, hi_hard, opt)
%GRID_FROM_OCCUPANCY  Place nodes on one axis where households actually are.
%
%   [g, info] = utility.grid_from_occupancy(x, n, lo_hard, hi_hard, opt)
%
%   x is the pooled sample of occupied values on this axis (from
%   utility.occupancy), n the number of nodes, and lo_hard/hi_hard the axis
%   ends that the model itself permits -- a node is never placed outside them.
%
%   The rule has two parts.
%
%   INSIDE the occupied band, nodes equidistribute a monitor function: the
%   spacing is chosen so that each cell carries the same share of
%
%       M(u) = density(u)^a * curvature(u)^b
%
%   where density is the occupancy density and curvature is the mean second
%   derivative of the solved value function along the axis, supplied in
%   opt.curv. Both matter and they are not the same thing. Density alone --
%   equal numbers of household-years per cell -- puts nodes where the mass is,
%   but interpolation error on a linear rule goes with the square of the
%   spacing times the second derivative, so it misses a thin tail where the
%   value function bends hard. On the income axis that tail is exactly where
%   the value falls away, and equal-probability spacing was measured to place
%   worse there than a hand-set power rule. Curvature alone would pile nodes on
%   a cliff nobody visits. opt.dens_pow and opt.curv_pow are a and b (defaults
%   0.5 and 0.5); with no curvature supplied the rule falls back to density
%   alone, which is the quantile spacing.
%
%   A monitor that is very uneven can leave a stretch with almost no nodes, so
%   the positions are blended with an even spread of the same band;
%   opt.weight sets the mix (1 = pure monitor, 0 = pure even, default 0.75).
%
%   OUTSIDE it, a few nodes carry on to the hard ends. These are not
%   decoration. Beyond the last node griddedInterpolant extrapolates 'nearest',
%   which is flat, so a household pushed past the end gets a continuation value
%   with no gradient; and the region just below the occupied band on the income
%   axis is where the value function falls away, so the grid has to represent
%   that fall rather than truncate it. opt.margin sets the share of nodes spent
%   this way (default 0.25).
%
%   Their spacing is set by the width of the occupied band, not by the room
%   left over. Distance from the band is what decides whether a node is useful
%   -- a household one or two band-widths outside might plausibly be pushed
%   there, one twenty widths out never will -- whereas room is an accident of
%   where the hard end happens to sit. Splitting by room spends five nodes on
%   an empty stretch above the band and one on the crowded stretch below it.
%   The hard end always gets a node, so the axis still spans what the model
%   permits.
%
%   Fields of opt, all optional:
%     band     percentile pair bounding the occupied band     [1 99]
%     weight   quantile-versus-even mix inside the band       0.75
%     margin   share of nodes spent outside the band          0.25
%     min_gap  smallest spacing, as a share of the full axis  0.002

if nargin < 5 || isempty(opt), opt = struct; end
band     = getf(opt, 'band',     [1 99]);
weight   = getf(opt, 'weight',   0.75);
margin   = getf(opt, 'margin',   0.25);
min_gap  = getf(opt, 'min_gap',  0.002);
pad      = getf(opt, 'pad',      0);
curv     = getf(opt, 'curv',     []);
dens_pow = getf(opt, 'dens_pow', 0.5);
curv_pow = getf(opt, 'curv_pow', 0.5);

x = x(isfinite(x));
assert(n >= 4, 'grid_from_occupancy:n', 'need at least 4 nodes (got %d).', n);
assert(hi_hard > lo_hard, 'grid_from_occupancy:bounds', ...
    'need lo_hard (%.6g) < hi_hard (%.6g).', lo_hard, hi_hard);

if isempty(x)                              % nothing measured: even spread
    g = linspace(lo_hard, hi_hard, n).';
    info = struct('band', [lo_hard hi_hard], 'n_in', n, 'n_lo', 0, 'n_hi', 0, ...
                  'fallback', true);
    return
end

b_lo = prctile(x, band(1));
b_hi = prctile(x, band(2));
% Optionally widen the band before placing anything, for a sample whose tails
% are not trusted -- a coarse pilot was measured to put the 1st percentile of
% the illiquid share two thirds of a band width above where a production panel
% puts it. It defaults to zero because it was tested and did not pay: padding a
% coarse pilot's band made the retirement equity share worse, not better
% (0.0395 against 0.0323 unpadded), since the resolution it costs inside the
% band is not bought back by covering a tail the pilot got wrong anyway. Fixing
% the sample beats padding it -- see opt.sim on utility.auto_state_grids.
if pad > 0 && b_hi > b_lo
    w = b_hi - b_lo;
    b_lo = b_lo - pad * w;
    b_hi = b_hi + pad * w;
end
b_lo = max(lo_hard, b_lo);
b_hi = min(hi_hard, b_hi);
if ~(b_hi > b_lo)                          % degenerate band: even spread
    g = linspace(lo_hard, hi_hard, n).';
    info = struct('band', [b_lo b_hi], 'n_in', n, 'n_lo', 0, 'n_hi', 0, ...
                  'fallback', true);
    return
end

% Outside first. The tails are built at their natural spacing and collapsed,
% so a side with almost no room costs almost nothing and the nodes it would
% have taken go back to the band.
W     = b_hi - b_lo;
n_out = min(n - 2, round(margin * n));
k_side = max(1, ceil(n_out / 2));
g_lo = tail_nodes(b_lo, lo_hard, k_side, W, min_gap * (hi_hard - lo_hard));
g_hi = tail_nodes(b_hi, hi_hard, k_side, W, min_gap * (hi_hard - lo_hard));

n_in = n - numel(g_lo) - numel(g_hi);
if n_in < 2
    keep = max(1, floor((n - 2) / 2));
    g_lo = g_lo(max(1, end-keep+1):end);
    g_hi = g_hi(1:min(keep, end));
    n_in = max(2, n - numel(g_lo) - numel(g_hi));
end

% Inside: equidistribute the monitor, blended toward an even spread.
gm  = monitor_nodes(x, b_lo, b_hi, n_in, curv, dens_pow, curv_pow);
gu  = linspace(b_lo, b_hi, n_in).';
g_in = weight * gm + (1 - weight) * gu;
g_in([1 end]) = [b_lo; b_hi];

g = sort([g_lo; g_in; g_hi]);
g = dedupe(g, min_gap * (hi_hard - lo_hard), lo_hard, hi_hard);

info = struct('band', [b_lo b_hi], 'n_in', n_in, ...
              'n_lo', numel(g_lo), 'n_hi', numel(g_hi), ...
              'fallback', false, 'n_total', numel(g));
end

% ------------------------------------------------------------------------
function g = monitor_nodes(x, lo, hi, n, curv, a, b)
%MONITOR_NODES  n nodes on [lo, hi] equidistributing density^a * curvature^b.
%   Both factors are evaluated on a fine auxiliary mesh, normalised to unit
%   mean so the exponents are the only thing setting their relative weight,
%   and floored so neither can drive the monitor to zero and strand a stretch
%   of the axis with no nodes at all. The nodes are then the inverse of the
%   monitor's cumulative integral at equally spaced levels, which is the
%   standard equidistribution construction.
NM = 512;
u  = linspace(lo, hi, NM).';

d = density(x, u);
d = norml(d);
M = d .^ a;

if ~isempty(curv) && isfield(curv, 'x') && numel(curv.x) >= 3
    c = interp1(curv.x(:), max(curv.m(:), 0), u, 'linear', 'extrap');
    c = norml(max(c, 0));
    M = M .* (c .^ b);
end
M = max(M, 1e-3 * mean(M));

C = cumtrapz(u, M);
if C(end) <= 0, g = linspace(lo, hi, n).'; return; end
C = C / C(end);
[Cu, iu] = unique(C);
g = interp1(Cu, u(iu), linspace(0, 1, n).', 'linear');
g(1) = lo; g(end) = hi;
g = sort(g);
end

% ------------------------------------------------------------------------
function d = density(x, u)
%DENSITY  Occupancy density on the mesh u, by histogram with a light smooth.
%   A kernel estimate would need a toolbox; a histogram over the mesh with a
%   short moving average is enough to steer node placement.
e = [u(1) - (u(2)-u(1))/2; (u(1:end-1) + u(2:end))/2; u(end) + (u(end)-u(end-1))/2];
d = histcounts(x, e).';
k = max(3, round(numel(u)/32));
d = movmean(d, k);
end

% ------------------------------------------------------------------------
function v = norml(v)
m = mean(v(isfinite(v)));
if ~isfinite(m) || m <= 0, v = ones(size(v)); return; end
v = max(v, 0) / m;
v(~isfinite(v)) = 0;
end

% ------------------------------------------------------------------------
function g = tail_nodes(b_edge, hard, k, W, gap)
%TAIL_NODES  Up to k nodes outside the band, placed by distance from its edge.
%   Offsets grow like 0.3, 1.2, 3.9 ... band widths, so the first node sits
%   just outside where the population is and the rest thin out quickly. Every
%   offset is clipped to the hard end, and the hard end itself is always
%   included, so a side with little room collapses to a single node instead of
%   crowding several into a stretch nothing occupies.
g = zeros(0, 1);
if ~isfinite(hard) || hard == b_edge, return; end
s    = sign(hard - b_edge);
room = abs(hard - b_edge);
d = 0.3 * W * (3 .^ (0 : max(k, 1) - 1).');    % 0.3, 0.9, 2.7, ... band widths
d = [min(d, room); room];                      % and always the hard end itself
if gap > 0, d = round(d / gap) * gap; end
d = unique(min(d(d > 0), room));
g = sort(b_edge + s * d);
end

% ------------------------------------------------------------------------
function g = dedupe(g, gap, lo, hi)
%DEDUPE  Drop nodes closer than gap, keeping the ends, then top back up.
g = sort(g(:));
keep = true(size(g));
last = g(1);
for i = 2:numel(g)
    if g(i) - last < gap, keep(i) = false; else, last = g(i); end
end
keep(1) = true; keep(end) = true;
n_want = numel(g);
g = g(keep);
if numel(g) < n_want                       % refill the gaps left behind
    extra = setdiff(linspace(lo, hi, n_want).', g);
    need  = n_want - numel(g);
    g = sort([g; extra(1:min(need, numel(extra)))]);
end
g = min(max(g, lo), hi);
g = unique(g);
end

% ------------------------------------------------------------------------
function v = getf(s, f, d)
if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
