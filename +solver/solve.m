function sol = solve(p, profile, shocks, ann_price, verbose)
%SOLVE  Solve the household problem by backward induction.
%
%   sol = solver.solve(p, profile, shocks, ann_price)
%   sol = solver.solve(..., verbose)
%
%   profile, shocks and ann_price come from config.model_inputs(p). The solve
%   runs on the (u1, u2, u3) cube; see solver.bellman_step_lna.

if nargin < 5, verbose = []; end
sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price, verbose);
end
