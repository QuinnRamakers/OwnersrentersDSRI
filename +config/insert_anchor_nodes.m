function p = insert_anchor_nodes(p)
%INSERT_ANCHOR_NODES  Force the calibrated welfare-anchor states onto the grid.
%
%   The buffered initial node for a household starting with b years of income
%   in liquid wealth is
%       W0 = (1 + h_mult + b) * Y0
%       lambda0 = 1/(1 + h_mult + b),  sH0 = h_mult/(1 + h_mult + b),  sA0 = 0
%   and the welfare metric (welfare0.Vt0, welfare_dc_vs_nodc.m,
%   plot_welfare_vs_buffer.m) is read exactly there. Unless those coordinates
%   ARE grid nodes, the headline number is a trilinear blend of surrounding
%   nodes, which both smears the corner the CEV is most sensitive to and makes
%   the number move with grid resolution. This inserts the anchors for the
%   calibrated buffer p.b0 and the sensitivity buffer p.b_alt exactly, and
%   refreshes p.N_lambda / p.N_sH.
%
%   sA is untouched: the anchor sits at sA0 = 0, which is already node 1 of
%   every linspace(0,1,N) grid.
%
%   Call this at the end of config.params AND again after any script rebuilds
%   the grid vectors (run_combined, run_nodc, run_spline_strategies,
%   proto_lna_*) -- solver.solve_lifecycle asserts the anchors are exact
%   members, so a rebuild that drops them fails loudly instead of silently
%   reverting to interpolated welfare.
%
%   Idempotent: re-running on an already-anchored grid is a no-op.
%   Non-uniform grid vectors are safe here -- downstream code only ever reads
%   the grids through griddedInterpolant and numel-derived sizes, never
%   through uniform-spacing arithmetic.

if ~all(isfield(p, {'b0', 'b_alt', 'h_mult', 'lambda_grid', 'sH_grid'}))
    return
end

den        = 1 + p.h_mult + [p.b0, p.b_alt];
lam_anchor = 1 ./ den;
sH_anchor  = p.h_mult ./ den;

p.lambda_grid = merge_nodes(p.lambda_grid, lam_anchor);
p.sH_grid     = merge_nodes(p.sH_grid,     sH_anchor);
p.N_lambda    = numel(p.lambda_grid);
p.N_sH        = numel(p.sH_grid);
end

function g = merge_nodes(g, anchors)
% uniquetol keeps the FIRST-listed element of each tolerance cluster, so the
% anchors are listed first: when an anchor lands within tol of an existing
% linspace node it is the anchor that survives, bit-exact, and the guard in
% solve_lifecycle (min |difference| == 0) holds. DataScale 1 makes the
% tolerance absolute rather than relative to max|A|.
g = sort(uniquetol([anchors(:); g(:)], 1e-12, 'DataScale', 1));
end
