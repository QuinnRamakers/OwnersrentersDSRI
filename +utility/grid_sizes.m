function n = grid_sizes(p)
%GRID_SIZES  Realised state-grid sizes, whichever coordinate system p is on.
%
%   n = utility.grid_sizes(p)   % [N_u1 N_u2 N_u3] or [N_lambda N_sA N_sH]
%
%   For logging the grid a run actually got. Read AFTER
%   utility.build_state_grids, never before: it re-inserts the welfare anchors
%   and two of the three axes come back up to +2 longer than requested, so the
%   requested dims and the realised sizes are different numbers and the
%   realised ones are what the run is.
%
%   Counts come off the axis vectors rather than the N_* fields, so they are
%   right even for a p whose N_* were left stale by hand-editing the grids.

assert(isfield(p, 'grid_type'), 'grid_sizes:no_grid_type', ...
    'p has no grid_type; config.params sets it.');

switch char(p.grid_type)
    case 'lna'
        n = [numel(p.u1_grid), numel(p.u2_grid), numel(p.u3_grid)];
    case 'simplex'
        n = [numel(p.lambda_grid), numel(p.sA_grid), numel(p.sH_grid)];
    otherwise
        error('grid_sizes:grid_type', ...
            'grid_type must be ''simplex'' or ''lna'', got ''%s''.', ...
            char(p.grid_type));
end
end
