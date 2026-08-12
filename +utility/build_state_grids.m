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

if is_lna
    if ~isempty(dims)
        p.N_u1 = dims(1); p.N_u2 = dims(2); p.N_u3 = dims(3);
    end
    assert(all(isfield(p, {'N_u1', 'N_u2', 'N_u3'})), 'build_state_grids:noN', ...
        'p has no N_u1/N_u2/N_u3 and no dims were supplied.');
    p.u1_grid = linspace(0, 1, p.N_u1).';
    p.u2_grid = linspace(0, 1, p.N_u2).';
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
    p.lambda_grid = linspace(0, 1, p.N_lambda).';
    p.sA_grid     = linspace(0, 1, p.N_sA).';
    p.sH_grid     = linspace(0, 1, p.N_sH).';
    p = config.insert_anchor_nodes(p);
    check_anchors(p, 'lambda_grid', 'sH_grid', @(b, hm) 1 ./ (1 + hm + b), ...
                  @(b, hm) hm ./ (1 + hm + b), 'lambda', 's_H');
end
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
