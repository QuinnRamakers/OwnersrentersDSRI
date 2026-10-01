function occ = occupancy(p, s, ages, sol)
%OCCUPANCY  Where simulated households actually sit on the three cube axes.
%
%   occ = utility.occupancy(p, s)
%   occ = utility.occupancy(p, s, ages)
%
%   s is a simulated panel from simulate.forward, carrying lambda, sA and sH as
%   household-by-age matrices. The cube coordinates follow from them:
%
%       u1 = lambda                       income share of wealth
%       u2 = (sA + sH) / (1 - lambda)     illiquid share of non-income wealth
%       u3 = sA / (sA + sH)               pension share of the illiquid block
%
%   ages restricts the pooled sample to a set of model ages (1-based, so 1 is
%   the entry age); the default pools every age, which is what the grid should
%   cover since one grid has to serve the whole life cycle.
%
%   Returns, per axis, the pooled sample and its quantiles, plus the per-age
%   5-95 band. The sample is what utility.grid_from_occupancy places nodes on;
%   the rest is for reporting.
%
%   Household-years where the coordinates are not finite -- a household with no
%   non-income wealth leaves u2 and u3 undefined -- are dropped per axis rather
%   than for the whole row, so one bad coordinate does not discard the other
%   two.

lam = s.lambda; sA = s.sA; sH = s.sH;
T = size(lam, 2);
if nargin < 3 || isempty(ages), ages = 1:T; end
ages = ages(ages >= 1 & ages <= T);

U1 = lam(:, ages);
U2 = (sA(:, ages) + sH(:, ages)) ./ max(1 - lam(:, ages), 1e-12);
U3 = sA(:, ages) ./ max(sA(:, ages) + sH(:, ages), 1e-12);

Q = [0.1 0.5 1 2.5 5 25 50 75 95 97.5 99 99.5 99.9];
CAP = 2e5;                   % kept sample size per axis; see axis_stats
occ = struct('q_levels', Q, 'ages', ages);
occ.u1 = axis_stats(U1, Q, CAP);
occ.u2 = axis_stats(U2, Q, CAP);
occ.u3 = axis_stats(U3, Q, CAP);

% Per-age bands, so a caller can see an axis the population sweeps along rather
% than sits on -- u3 does that, and a pooled quantile hides it.
occ.by_age = struct('t', ages(:).', ...
                    'u1', band(U1), 'u2', band(U2), 'u3', band(U3));
occ.n_obs = [numel(occ.u1.x) numel(occ.u2.x) numel(occ.u3.x)];
if isfield(p, 'is_owner'), occ.is_owner = p.is_owner; end

% Curvature of the solved value function along each axis, when a solution is
% supplied. Where households are and where the value function bends are
% different questions, and node placement needs both: interpolation error on a
% linear rule goes with the square of the spacing times the second derivative,
% so a stretch that curves hard needs nodes whether or not many households sit
% on it. utility.grid_from_occupancy combines the two.
occ.curv = [];
if nargin >= 4 && ~isempty(sol) && isfield(sol, 'V')
    occ.curv = curvature(p, sol);
end
end

% ------------------------------------------------------------------------
function c = curvature(p, sol)
%CURVATURE  Mean |d2 z / du2| along each axis of the solved value function.
%   z = ((1-gamma) V)^(1/(1-gamma)) is the certainty equivalent per unit of
%   wealth, which is the object the solver interpolates, so its curvature is
%   the one that matters. Averaged over the other two axes and over age, since
%   one grid serves all of them.
g = p.gamma;
Z = real(((1 - g) * sol.V) .^ (1/(1 - g)));
Z(~isfinite(Z)) = 0;
ax = {p.u1_grid(:), p.u2_grid(:), p.u3_grid(:)};
c = struct('u1', [], 'u2', [], 'u3', []);
nm = {'u1', 'u2', 'u3'};
for d = 1:3
    x = ax{d};
    if numel(x) < 3, c.(nm{d}) = struct('x', x, 'm', ones(size(x))); continue; end
    M = permute(Z, [d setdiff(1:3, d) 4]);          % axis d first
    M = reshape(M, numel(x), []);
    d2 = zeros(numel(x), size(M, 2));
    for i = 2:numel(x)-1
        h1 = x(i) - x(i-1); h2 = x(i+1) - x(i);
        d2(i, :) = 2 * ((M(i+1,:) - M(i,:))/h2 - (M(i,:) - M(i-1,:))/h1) / (h1 + h2);
    end
    d2([1 end], :) = d2([2 end-1], :);
    m = mean(abs(d2), 2, 'omitnan');
    c.(nm{d}) = struct('x', x, 'm', m);
end
end

% ------------------------------------------------------------------------
function a = axis_stats(M, Q, cap)
%AXIS_STATS  Quantiles, ends, and a bounded copy of the sample.
%   The quantiles and the two ends come from every observation. The sample kept
%   alongside them is thinned to cap points on a fixed stride, because it is
%   what gets cached and a full panel runs to several million values per axis;
%   200,000 is far more than quantile placement can distinguish. The stride is
%   deterministic, so the same panel always yields the same grid.
x = M(:);
x = x(isfinite(x));
if isempty(x)
    a.x = x; a.q = nan(size(Q)); a.lo = NaN; a.hi = NaN; return
end
a.q  = prctile(x, Q);
a.lo = min(x);
a.hi = max(x);
a.n  = numel(x);
if numel(x) > cap
    a.x = x(round(linspace(1, numel(x), cap)));
else
    a.x = x;
end
end

% ------------------------------------------------------------------------
function b = band(M)
b = nan(2, size(M, 2));
for j = 1:size(M, 2)
    x = M(:, j); x = x(isfinite(x));
    if isempty(x), continue; end
    b(:, j) = prctile(x, [5 95]).';
end
end
