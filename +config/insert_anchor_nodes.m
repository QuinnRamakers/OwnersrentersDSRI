function p = insert_anchor_nodes(p)
%INSERT_ANCHOR_NODES  Put the entry states for p.b0 and p.b_alt on the grid.
%
%   A household entering with b years of income in liquid wealth, a house or
%   rent index of h_mult years and no DC pot sits at
%       u1 = 1/(1 + h_mult + b),   u2 = h_mult/(h_mult + b),   u3 = 0.
%   Splicing these in as exact nodes makes the value at entry a solved number
%   rather than an interpolation, which is what utility.welfare_anchor reads.
%   u3 = 0 is already the first node of every u3 axis.
%
%   Idempotent. The grids become non-uniform, which is harmless: everything
%   downstream reads them through griddedInterpolant.

if ~all(isfield(p, {'b0', 'b_alt', 'h_mult', 'u1_grid', 'u2_grid'}))
    return
end
b = [p.b0, p.b_alt];
p.u1_grid = merge_nodes(p.u1_grid, 1 ./ (1 + p.h_mult + b));
p.u2_grid = merge_nodes(p.u2_grid, p.h_mult ./ (p.h_mult + b));
p.N_u1    = numel(p.u1_grid);
p.N_u2    = numel(p.u2_grid);
end

function g = merge_nodes(g, anchors)
% uniquetol keeps the first element of each tolerance cluster, so listing the
% anchors first makes an anchor, not a nearby grid node, the one that survives.
g = sort(uniquetol([anchors(:); g(:)], 1e-12, 'DataScale', 1));
end
