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
    p.u1_grid = cluster_lo(p.N_u1, spacing_pow(p), lam_lo, lam_hi);
    p.u2_grid = cluster_hi(p.N_u2, spacing_pow(p));
    p.u3_grid = linspace(0, 1, p.N_u3).';
    p = config.insert_anchor_nodes(p);
    check_anchors(p, 'u1_grid', 'u2_grid', @(b, hm) 1 ./ (1 + hm + b), ...
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

function [lo, hi] = lambda_bounds(p)
%LAMBDA_BOUNDS  Reachable range of the income share lambda = Y/W.
%   lo: a small positive floor, below the smallest income share a wealthy old
%       household reaches, but strictly above the absorbing lambda = 0 node.
%   hi: the largest income share, set by housing wealth (W >= H + Y gives
%       lambda <= 1/(1+h_mult) at entry) with headroom for the housing-price
%       and income shocks that raise it over the life cycle.
lo = 0.002;
if isfield(p, 'h_mult') && isscalar(p.h_mult) && p.h_mult > 0
    hi = min(0.9, 3 / (1 + p.h_mult));
else
    hi = 0.6;
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

function q = spacing_pow(p)
%SPACING_POW  Node-clustering exponent. 1 = uniform (the default, and what
%   every solve before this used, so behaviour is unchanged unless asked for).
%   q > 1 concentrates nodes toward the end of the axis the caller cares about.
q = 1;
if isfield(p, 'grid_pow') && isnumeric(p.grid_pow) && isscalar(p.grid_pow)
    q = max(1, double(p.grid_pow));
end
end

function g = cluster_lo(n, q, lo, hi)
% Nodes on [lo, hi] bunched toward lo. q = 1 spaces them uniformly.
if nargin < 3, lo = 0; end
if nargin < 4, hi = 1; end
g = lo + (hi - lo) * (linspace(0, 1, n).' .^ q);
end

function g = cluster_hi(n, q)
% Nodes on [0,1] bunched toward 1. q = 1 reproduces linspace exactly.
g = 1 - (1 - linspace(0, 1, n).') .^ q;
g = sort(g);
end
