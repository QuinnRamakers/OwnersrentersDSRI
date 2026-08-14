function [dims, gh_n] = production_grid(x)
%PRODUCTION_GRID  The state grid the production runners solve on.
%
%   [dims, gh_n] = utility.production_grid(p)         % from p.grid_type
%   [dims, gh_n] = utility.production_grid('lna')
%   [dims, gh_n] = utility.production_grid()          % active grid
%
%   run_combined, run_nodc and run_spline_strategies must all solve the same
%   arm sizes or their welfare numbers are not comparable, and
%   utility.param_fingerprint will correctly refuse to rank them together.
%   That agreement used to be three hardcoded copies of [25 15 15]; this is
%   the single definition, per coordinate system.
%
%   CGM_STATE_GRID / CGM_GH_N still override, for smoke runs only -- see
%   utility.grid_override. dims goes on to utility.build_state_grids, which
%   re-inserts the welfare anchors and can return two axes up to +2 larger, so
%   read the realised sizes off p afterwards, never off dims.
%
%   SIMPLEX [25 15 15], gh_n 5. Deliberately below config.params' 40^3/gh_n=7,
%   chosen so run_combined matches the spline sweep. Unchanged.
%
%   LNA [28 20 20], gh_n 7 -- config.params' cube defaults, which is what
%   run_combined's cube path has always solved. Every cube point is feasible,
%   so this is 11,200 live states against roughly 940 on the simplex sweep
%   grid (a 3-simplex fills about a sixth of its bounding cube). That ratio is
%   the thing to know before launching a sweep: it buys the cube's accuracy
%   near the liquid-wealth boundary and costs an order of magnitude in
%   runtime, which is why the overnight cube sweep ran at [14 11 11] with the
%   polish off instead. [14 11 11] is also the arm the convergence ladder
%   found biased (TODO section 8): uniform u2 cells interpolate across the
%   value cliff as liquid wealth goes to zero and overstate continuation
%   values there.
%
%   So do not quietly coarsen the cube to make a sweep fit. Grade the u2 axis
%   instead -- p.grid_pow > 1 clusters nodes toward u2 = 1, which is where the
%   cliff is -- and re-run the ladder to show the bias is gone. That
%   validation is the open gate on the cube being production for a full sweep;
%   it is recorded in TODO section 8.

if nargin < 1, x = []; end
if isstruct(x)
    assert(isfield(x, 'grid_type'), 'production_grid:no_grid_type', ...
        'p has no grid_type; config.params sets it.');
    g = char(x.grid_type);
elseif isempty(x)
    g = utility.active_grid();
else
    g = char(x);
end

switch g
    case 'simplex'
        dims_default = [25 15 15];
        gh_default   = 5;
    case 'lna'
        dims_default = [28 20 20];
        gh_default   = 7;
    otherwise
        error('production_grid:grid_type', ...
            'grid_type must be ''simplex'' or ''lna'', got ''%s''.', g);
end

[dims, gh_n] = utility.grid_override(dims_default, gh_default);
end
