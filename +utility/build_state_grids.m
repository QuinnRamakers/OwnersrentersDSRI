function p = build_state_grids(p, dims, gh_n)
%BUILD_STATE_GRIDS  Build the (u1, u2, u3) state grid, entry anchors included.
%
%   p = utility.build_state_grids(p, dims)
%   p = utility.build_state_grids(p, dims, gh_n)
%   p = utility.build_state_grids(p)          % rebuild at p.grid_dims
%
%   dims are BASE node counts. The two entry-state anchors (p.b0, p.b_alt) are
%   spliced into u1 and u2 as exact nodes afterwards, so those axes can come
%   back up to two nodes longer: read the realised sizes off p.N_u1, p.N_u2,
%   p.N_u3. A third argument sets p.gh_n.
%
%   Placement, per axis, unless p.grid_nodes supplies the axis outright:
%     u1  [lambda_lo, lambda_hi], bunched toward the bottom when grid_pow > 1.
%         The top defaults to min(0.9, 3/(1+h_mult)), since W >= H + Y caps the
%         income share, and to 1 without housing, where a household that spends
%         its liquid wealth down reaches lambda = 1 exactly.
%     u2  [u2_lo, 1], bunched toward 1 when grid_pow_u2 > 1.
%     u3  [u3_lo, u3_hi], uniform.
%
%   Axes that the model cannot move along are collapsed to the two nodes
%   {0, 1}. Without housing and without a DC pillar A = H = 0, so u2 = u3 = 0
%   always. Without housing u3 = A/(A+H) is 0 or 1; without a DC pillar it is
%   0. The solve on the occupied line does not depend on the nodes removed, so
%   this changes nothing but the runtime.
%
%   Beyond the last node griddedInterpolant extrapolates 'nearest', which is
%   flat: a household pushed off an axis gets a continuation value with no
%   gradient. simulate.paths_lna counts such lookups and warns. GRIDS.md has
%   the procedure for choosing the axes from measured occupancy.

if nargin >= 3 && ~isempty(gh_n)
    assert(isnumeric(gh_n) && isscalar(gh_n) && gh_n == round(gh_n) && gh_n >= 1, ...
        'build_state_grids:gh_n', 'gh_n must be a positive integer (got %s).', mat2str(gh_n));
    p.gh_n = gh_n;
end
if nargin < 2 || isempty(dims)
    dims = p.grid_dims;
end
assert(isnumeric(dims) && numel(dims) == 3 && all(dims == round(dims)) && all(dims >= 2), ...
    'build_state_grids:dims', 'dims must be three integers >= 2 (got %s).', mat2str(dims));
N1 = dims(1); N2 = dims(2); N3 = dims(3);

no_housing = field_or(p, 'h_mult', 0) == 0;
no_dc      = field_or(p, 'kappa_base', 0) == 0;
collapse_u2 = no_housing && no_dc;
collapse_u3 = no_housing || no_dc;

[lam_lo, lam_hi] = lambda_bounds(p);
given = node_override(p);

if ~isempty(given.u1)
    p.u1_grid = given.u1;
else
    q = max(1, field_or(p, 'grid_pow', 1));
    p.u1_grid = lam_lo + (lam_hi - lam_lo) * (linspace(0, 1, N1).' .^ q);
end

if collapse_u2
    p.u2_grid = [0; 1];
elseif ~isempty(given.u2)
    p.u2_grid = given.u2;
else
    q  = max(1, field_or(p, 'grid_pow_u2', 1));
    lo = max(0, min(0.9, field_or(p, 'u2_lo', 0)));
    p.u2_grid = sort(lo + (1 - lo) * (1 - (1 - linspace(0, 1, N2).') .^ q));
end

if collapse_u3
    p.u3_grid = [0; 1];
elseif ~isempty(given.u3)
    p.u3_grid = given.u3;
else
    lo = max(0, min(0.5, field_or(p, 'u3_lo', 0)));
    hi = min(1, max(lo + 0.1, field_or(p, 'u3_hi', 1)));
    p.u3_grid = linspace(lo, hi, N3).';
end

p.N_u1 = numel(p.u1_grid);
p.N_u2 = numel(p.u2_grid);
p.N_u3 = numel(p.u3_grid);

p = config.insert_anchor_nodes(p);
check_anchors(p);
end

% ------------------------------------------------------------------------
function [lo, hi] = lambda_bounds(p)
%LAMBDA_BOUNDS  Ends of the u1 = Y/W axis.
lo = field_or(p, 'lambda_lo', 0.0008);
if field_or(p, 'h_mult', 0) > 0
    hi = min(0.9, 3 / (1 + p.h_mult));
else
    hi = 1.0;
end
if isfield(p, 'lambda_hi') && isscalar(p.lambda_hi), hi = p.lambda_hi; end
assert(lo > 0 && hi > lo, 'build_state_grids:lambda_bounds', ...
    'need 0 < lambda_lo (%.4g) < lambda_hi (%.4g).', lo, hi);
end

% ------------------------------------------------------------------------
function g = node_override(p)
%NODE_OVERRIDE  Axis vectors supplied on p.grid_nodes, validated.
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
    if strcmp(f{i}, 'u1')
        assert(min(v) > 0, 'build_state_grids:grid_nodes', ...
            'p.grid_nodes.u1 must be strictly positive (got %.4g).', min(v));
    else
        assert(min(v) >= 0 && max(v) <= 1, 'build_state_grids:grid_nodes', ...
            'p.grid_nodes.%s must lie in [0, 1] (got [%.4g, %.4g]).', f{i}, min(v), max(v));
    end
    g.(f{i}) = sort(v);
end
end

% ------------------------------------------------------------------------
function check_anchors(p)
%CHECK_ANCHORS  Both entry anchors must be exact nodes of u1 and u2.
if ~all(isfield(p, {'b0', 'b_alt', 'h_mult'})), return; end
b = [p.b0, p.b_alt];
for a = 1:2
    a1 = 1 / (1 + p.h_mult + b(a));
    a2 = p.h_mult / (p.h_mult + b(a));
    assert(min(abs(p.u1_grid - a1)) == 0 && min(abs(p.u2_grid - a2)) == 0, ...
        'build_state_grids:anchor_missing', ...
        'entry anchor for b = %.6g is not an exact node after the rebuild.', b(a));
end
end

% ------------------------------------------------------------------------
function v = field_or(p, f, default)
if isfield(p, f) && ~isempty(p.(f)), v = p.(f); else, v = default; end
end
