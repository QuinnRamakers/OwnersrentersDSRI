function sol = solve(p, profile, shocks, ann_price)
%SOLVE  Backward induction on whichever coordinate system p declares.
%
%   sol = solver.solve(p, profile, shocks, ann_price)
%
%   Dispatches on p.grid_type:
%     'lna'      -> solver.solve_lifecycle_lna, the (u1,u2,u3) cube. Production.
%     'simplex'  -> solver.solve_lifecycle,     the (lambda,s_A,s_H) simplex.
%
%   The two are separate implementations of one model and stay that way -- the
%   cube is not a wrapper over the simplex, it is a second discretisation with
%   its own Bellman step, its own interpolant and no feasibility mask. This
%   only removes the if/else that every runner used to carry.
%
%   Both targets already assert that p.grid_type matches them, so a mislabelled
%   p fails inside the solver as before; this adds no new trust. What it does
%   add is that a runner cannot pick the wrong one by forgetting to branch.
%
%   sol.grid_type records what actually solved it, so downstream code reads
%   provenance off the solution rather than off the environment.
%
%   An absent grid_type means simplex, the same reading solve_lifecycle and
%   utility.build_state_grids already take: the tag was added after those
%   runs, so every p-struct old enough to lack it is from before the cube
%   existed as an option. Do NOT read it as "the current default" -- that
%   would silently re-point legacy files at the cube.

switch grid_of(p)
    case 'lna'
        sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);
    case 'simplex'
        sol = solver.solve_lifecycle(p, profile, shocks, ann_price);
    otherwise
        error('solve:grid_type', ...
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
