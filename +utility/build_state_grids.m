function p = build_state_grids(p, dims, gh_n)
%BUILD_STATE_GRIDS  Build the (u1, u2, u3, q) state grid, entry anchors included.
%
%   p = utility.build_state_grids(p, dims)
%   p = utility.build_state_grids(p, dims, gh_n)
%   p = utility.build_state_grids(p)          % rebuild at p.grid_dims
%
%   dims are four BASE node counts. The two entry-state anchors (p.b0, p.b_alt)
%   are spliced into u1 and u2 as exact nodes afterwards, and the entry q = 1
%   into q, so those axes can come back longer: read the realised sizes off
%   p.N_u1, p.N_u2, p.N_u3, p.N_q. A third argument sets p.gh_n.
%
%   Placement, per axis, unless p.grid_nodes supplies the axis outright:
%     u1  [lambda_lo, lambda_hi], bunched toward the bottom when grid_pow > 1.
%         The bottom defaults to 0.0008, or 0.0002 with housing.
%         The top defaults to min(0.9, 3/(1+h_mult)), since W >= H + Y caps the
%         income share, and to 1 without housing, where a household that spends
%         its liquid wealth down reaches lambda = 1 exactly.
%     u2  [u2_lo, 1], bunched toward 1 when grid_pow_u2 > 1.
%     u3  [u3_lo, u3_hi], uniform.
%     q   [0, q_hi], bunched toward 0 when grid_pow_q > 1.
%
%   Axes that the model cannot move along are collapsed to the two nodes
%   {0, 1}. Without housing and without a DC pillar A = H = 0, so u2 = u3 = 0
%   always. Without housing u3 = A/(A+H) is 0 or 1; without a DC pillar it is
%   0. The solve on the occupied line does not depend on the nodes removed, so
%   this changes nothing but the runtime. The q axis is the single node q = 1
%   when q is a state in no period (p.q_live, config.derive), and the solver
%   then works on the (u1, u2, u3) cube alone.
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
assert(isnumeric(dims) && numel(dims) == 4 && all(dims == round(dims)) && all(dims >= 2), ...
    'build_state_grids:dims', ['dims must be four integers >= 2, base nodes on (u1, u2, u3, q) ' ...
    '(got %s).'], mat2str(dims));
N1 = dims(1); N2 = dims(2); N3 = dims(3); Nq = dims(4);

no_housing = field_or(p, 'h_mult', 0) == 0;
no_dc      = field_or(p, 'kappa_base', 0) == 0;
collapse_u2 = no_housing && no_dc;
collapse_u3 = no_housing || no_dc;
collapse_q  = ~any(field_or(p, 'q_live', false));

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

if collapse_q
    p.q_grid = 1;
elseif ~isempty(given.q)
    p.q_grid = given.q;
else
    q_hi = field_or(p, 'q_hi', 2.5);
    assert(q_hi >= 1, 'build_state_grids:q_hi', ...
        'q_hi must be at least 1, the entry state (got %.4g).', q_hi);
    q = max(1, field_or(p, 'grid_pow_q', 1));
    p.q_grid = q_hi * linspace(0, 1, Nq).' .^ q;
end

p.N_u1 = numel(p.u1_grid);
p.N_u2 = numel(p.u2_grid);
p.N_u3 = numel(p.u3_grid);
p.N_q  = numel(p.q_grid);

p = config.insert_anchor_nodes(p);
check_anchors(p);
p = age_grids(p, collapse_u2);
end

% ------------------------------------------------------------------------
function p = age_grids(p, collapse_u2)
%AGE_GRIDS  Grid points that follow age, from p.grid_nodes.u1_age and u2_age:
%   one column of base points per period (T columns). The entry anchors are
%   spliced into every column, so every column must come back the same length.
%   The first column becomes p.u1_grid and p.u2_grid, which is the grid at
%   entry that utility.welfare_anchor reads. Without these fields
%   p.u1_grid_age and p.u2_grid_age are empty and the grid is fixed.
p.u1_grid_age = []; p.u2_grid_age = [];
if ~isfield(p, 'grid_nodes') || ~isstruct(p.grid_nodes), return; end
gn = p.grid_nodes;
has1 = isfield(gn, 'u1_age') && ~isempty(gn.u1_age);
has2 = isfield(gn, 'u2_age') && ~isempty(gn.u2_age) && ~collapse_u2;
if ~has1 && ~has2, return; end
T = p.T;
if has1, A1 = gn.u1_age; else, A1 = repmat(p.u1_grid, 1, T); end
if has2, A2 = gn.u2_age; else, A2 = repmat(p.u2_grid, 1, T); end
assert(size(A1, 2) == T && size(A2, 2) == T, 'build_state_grids:age_grid', ...
    'grid_nodes.u1_age and u2_age need one column per period (%d).', T);
b = [p.b0, p.b_alt];
G1 = cell(1, T); G2 = cell(1, T);
for t = 1:T
    G1{t} = sort(uniquetol([1 ./ (1 + p.h_mult + b(:)); A1(:, t)], 1e-12, 'DataScale', 1));
    G2{t} = sort(uniquetol([p.h_mult ./ max(p.h_mult + b(:), realmin); A2(:, t)], 1e-12, 'DataScale', 1));
end
n1 = cellfun(@numel, G1); n2 = cellfun(@numel, G2);
assert(all(n1 == n1(1)) && all(n2 == n2(1)), 'build_state_grids:age_grid', ...
    'after the entry anchors the age columns differ in length (u1 %d-%d, u2 %d-%d).', ...
    min(n1), max(n1), min(n2), max(n2));
assert(all(cellfun(@(g) g(1) > 0, G1)) && all(cellfun(@(g) g(1) >= 0 && g(end) <= 1, G2)), ...
    'build_state_grids:age_grid', 'u1_age must be positive and u2_age in [0, 1].');
p.u1_grid_age = [G1{:}]; p.u2_grid_age = [G2{:}];
p.u1_grid = p.u1_grid_age(:, 1); p.u2_grid = p.u2_grid_age(:, 1);
p.N_u1 = n1(1); p.N_u2 = n2(1);
end

% ------------------------------------------------------------------------
function [lo, hi] = lambda_bounds(p)
%LAMBDA_BOUNDS  Ends of the u1 = Y/W axis.
% Owners whose house grows large against their income sit at very low u1 late
% in life, so the axis reaches further down with housing.
if field_or(p, 'h_mult', 0) > 0, lo_default = 0.0002; else, lo_default = 0.0008; end
lo = field_or(p, 'lambda_lo', lo_default);
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
g = struct('u1', [], 'u2', [], 'u3', [], 'q', []);
if ~isfield(p, 'grid_nodes') || isempty(p.grid_nodes), return; end
gn = p.grid_nodes;
assert(isstruct(gn), 'build_state_grids:grid_nodes', ...
    'p.grid_nodes must be a struct with fields u1, u2, u3 and/or q.');
f = {'u1', 'u2', 'u3', 'q'};
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
    elseif strcmp(f{i}, 'q')
        assert(min(v) >= 0, 'build_state_grids:grid_nodes', ...
            'p.grid_nodes.q must be non-negative (got %.4g).', min(v));
    else
        assert(min(v) >= 0 && max(v) <= 1, 'build_state_grids:grid_nodes', ...
            'p.grid_nodes.%s must lie in [0, 1] (got [%.4g, %.4g]).', f{i}, min(v), max(v));
    end
    g.(f{i}) = sort(v);
end
end

% ------------------------------------------------------------------------
function check_anchors(p)
%CHECK_ANCHORS  Both entry anchors must be exact nodes of u1 and u2, and q = 1 of q.
assert(any(p.q_grid == 1), 'build_state_grids:anchor_missing', ...
    'the entry state q = 1 is not an exact node of the q axis.');
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
