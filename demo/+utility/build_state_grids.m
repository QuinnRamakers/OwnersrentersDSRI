function p = build_state_grids(p, dims, gh_n)
%Build grid

assert(isfield(p, 'grid_type') && strcmp(char(p.grid_type), 'lna'), ...
    'build_state_grids:grid_type', 'p.grid_type must be ''lna''.');

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
    p.N_u1 = dims(1); p.N_u2 = dims(2); p.N_u3 = dims(3);
end
assert(all(isfield(p, {'N_u1', 'N_u2', 'N_u3'})), 'build_state_grids:noN', ...
    'p has no N_u1/N_u2/N_u3 and no dims were supplied.');

% u1 = lambda concentrates at the low end due to low income to total wealth
%  u2 = illiquid share of non-income wealth at the high end due to limited
%  liquid savings so these two are not distirbutes uniformly over the grid
[lam_lo, lam_hi] = lambda_bounds(p);
p.u1_grid = cluster_lo(p.N_u1, spacing_pow(p), lam_lo, lam_hi);
p.u2_grid = cluster_hi(p.N_u2, spacing_pow(p));
p.u3_grid = linspace(0, 1, p.N_u3).';
%manually insert the welfare calculation points
p = config.insert_anchor_nodes(p);
check_anchors(p, 'u1_grid', 'u2_grid', @(b, hm) 1 ./ (1 + hm + b), ...
              @(b, hm) hm ./ (hm + b), 'u1', 'u2');
end

function [lo, hi] = lambda_bounds(p)
%calculating reasonable bounds for labor income grid.
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
% check to see if the welfare caclculation point is on the grid
if ~all(isfield(p, {'b0', 'b_alt', 'h_mult'})), return; end
b_a  = [p.b0, p.b_alt];
name = {'b0', 'b_alt'};
for a = 1:2
    a1 = a1_fun(b_a(a), p.h_mult);
    a2 = a2_fun(b_a(a), p.h_mult);
    assert(min(abs(p.(f1) - a1)) == 0, 'build_state_grids:anchor_missing', ...
        '%s anchor for buffer %s is not an exact node after the rebuild.', n1, name{a});
    assert(min(abs(p.(f2) - a2)) == 0, 'build_state_grids:anchor_missing', ...
        '%s anchor for buffer %s is not an exact node after the rebuild.', n2, name{a});
end
end

function q = spacing_pow(p)
% exponent for the grid construction
q = 1;
if isfield(p, 'grid_pow') && isnumeric(p.grid_pow) && isscalar(p.grid_pow)
    q = max(1, double(p.grid_pow));
end
end

function g = cluster_lo(n, q, lo, hi)
% Nodes on [lo, hi] bunched toward lower bound
if nargin < 3, lo = 0; end
if nargin < 4, hi = 1; end
g = lo + (hi - lo) * (linspace(0, 1, n).' .^ q);
end

function g = cluster_hi(n, q)
% Nodes on [0,1] bunched toward 1. 
g = 1 - (1 - linspace(0, 1, n).') .^ q;
g = sort(g);
end
