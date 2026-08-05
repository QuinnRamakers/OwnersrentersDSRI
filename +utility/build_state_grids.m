function p = build_state_grids(p, dims, gh_n)
%BUILD_STATE_GRIDS  Rebuild the simplex state grid, anchors included.
%
%   p = utility.build_state_grids(p, [N_lambda N_sA N_sH])
%   p = utility.build_state_grids(p, dims, gh_n)
%   p = utility.build_state_grids(p)          % rebuild at the current N_*
%
%   Every run script that overrides the production grid does the same four
%   things: set N_lambda/N_sA/N_sH, rebuild the three linspaces, re-insert the
%   calibrated welfare anchors, and rely on solve_lifecycle to catch it if the
%   third step was forgotten. This is the one place that happens.
%
%   Anchor re-insertion is why the returned N_lambda / N_sH can exceed dims(1)
%   / dims(3) by up to 2: p.b0 and p.b_alt are forced on as exact nodes and
%   the counts are refreshed from the resulting vectors, never from dims. Read
%   them back off p.
%
%   The membership assert below duplicates solver.solve_lifecycle's guard
%   deliberately, so it fires at the call site that rebuilt the grid rather
%   than inside the solver later. The solver's copy is the backstop for grids
%   built any other way.
%
%   lna cube grids are not handled here -- they have no simplex feasibility
%   boundary and no anchors.

if nargin >= 2 && ~isempty(dims)
    assert(isnumeric(dims) && numel(dims) == 3 && all(dims == round(dims)) ...
           && all(dims >= 2), 'build_state_grids:dims', ...
        'dims must be [N_lambda N_sA N_sH], integers >= 2 (got %s).', mat2str(dims));
    p.N_lambda = dims(1);
    p.N_sA     = dims(2);
    p.N_sH     = dims(3);
end
assert(all(isfield(p, {'N_lambda', 'N_sA', 'N_sH'})), 'build_state_grids:noN', ...
    'p has no N_lambda/N_sA/N_sH and no dims were supplied.');

if nargin >= 3 && ~isempty(gh_n)
    assert(isnumeric(gh_n) && isscalar(gh_n) && gh_n == round(gh_n) && gh_n >= 1, ...
        'build_state_grids:gh_n', 'gh_n must be a positive integer (got %s).', ...
        mat2str(gh_n));
    p.gh_n = gh_n;
end

p.lambda_grid = linspace(0, 1, p.N_lambda).';
p.sA_grid     = linspace(0, 1, p.N_sA).';
p.sH_grid     = linspace(0, 1, p.N_sH).';

% Restores p.b0 / p.b_alt as bit-exact nodes and refreshes N_lambda / N_sH.
% No-op on a p-struct that predates the anchors (it returns early).
p = config.insert_anchor_nodes(p);

if all(isfield(p, {'b0', 'b_alt', 'h_mult'}))
    b_a  = [p.b0, p.b_alt];
    name = {'b0', 'b_alt'};
    for a = 1:2
        den = 1 + p.h_mult + b_a(a);
        assert(min(abs(p.lambda_grid - 1/den)) == 0, ...
            'build_state_grids:anchor_missing', ...
            ['lambda anchor %.17g (buffer %s = %.6g) is not an exact node after ' ...
             'the rebuild -- config.insert_anchor_nodes did not take.'], ...
            1/den, name{a}, b_a(a));
        assert(min(abs(p.sH_grid - p.h_mult/den)) == 0, ...
            'build_state_grids:anchor_missing', ...
            ['s_H anchor %.17g (buffer %s = %.6g) is not an exact node after ' ...
             'the rebuild -- config.insert_anchor_nodes did not take.'], ...
            p.h_mult/den, name{a}, b_a(a));
    end
end
end
