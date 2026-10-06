function sim = forward(p, profile, sol, ann_price, N, seed, X0_frac)
%FORWARD  Monte-Carlo simulation on the LNA cube coordinate system.
%
%   sim = simulate.forward(p, profile, sol, ann_price)
%   sim = simulate.forward(p, profile, sol, ann_price, N, seed, X0_frac)
%
%   Policies are read on the (u1,u2,u3) cube via simulate.paths_lna. p is what
%   the solver asserted against and carries the grid vectors the policies are
%   indexed by, so a sol/p vintage mismatch fails in the interpolant build.

if nargin < 5, N = []; end
if nargin < 6, seed = []; end
if nargin < 7, X0_frac = []; end

assert(isfield(p, 'grid_type') && strcmp(char(p.grid_type), 'lna'), ...
    'forward:grid_type', 'p.grid_type must be ''lna''.');

sim = simulate.paths_lna(p, profile, sol, ann_price, N, seed, X0_frac);
end
