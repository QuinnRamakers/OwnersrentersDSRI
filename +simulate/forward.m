function sim = forward(p, profile, sol, ann_price, N, seed, X0_frac)
%FORWARD  Monte-Carlo simulation on whichever coordinate system solved sol.
%
%   sim = simulate.forward(p, profile, sol, ann_price)
%   sim = simulate.forward(p, profile, sol, ann_price, N, seed, X0_frac)
%
%   Dispatches on p.grid_type:
%     'lna'      -> simulate.paths_lna, policies read on the (u1,u2,u3) cube.
%     'simplex'  -> simulate.paths,     policies read on the simplex, with the
%                   nearest-feasible NaN fill the mask makes necessary.
%
%   Both return the same fields, including tau_A, so plotting and welfare code
%   downstream never has to know which grid it is looking at.
%
%   Dispatching on p, not on sol, is deliberate: p is what the solver asserted
%   against and what carries the grid vectors the policies are indexed by. A
%   sol from one grid handed to a p from the other is a vintage mismatch, and
%   the simulators' interpolant construction fails on the size disagreement.

%   An absent grid_type means simplex, matching solver.solve and
%   solve_lifecycle: a p old enough to lack the tag predates the cube being an
%   option, so it is a simplex run. Reading it as the current default would
%   silently re-point legacy files at the wrong simulator.

if nargin < 5, N = []; end
if nargin < 6, seed = []; end
if nargin < 7, X0_frac = []; end

switch grid_of(p)
    case 'lna'
        sim = simulate.paths_lna(p, profile, sol, ann_price, N, seed, X0_frac);
    case 'simplex'
        sim = simulate.paths(p, profile, sol, ann_price, N, seed, X0_frac);
    otherwise
        error('forward:grid_type', ...
            'p.grid_type must be ''simplex'' or ''lna'', got ''%s''.', ...
            grid_of(p));
end
end

function g = grid_of(p)
if isfield(p, 'grid_type') && ~isempty(p.grid_type)
    g = char(p.grid_type);
else
    g = 'simplex';
end
end
