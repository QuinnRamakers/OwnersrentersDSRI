function [u1, u2] = grid_at(p, t)
%GRID_AT  The u1 and u2 grid points at period t.
%
%   [u1, u2] = utility.grid_at(p, t)
%
%   With a grid that follows age (p.u1_grid_age and p.u2_grid_age, one column
%   per period, set through p.grid_nodes.u1_age and u2_age), the period's own
%   points; otherwise the fixed axes p.u1_grid and p.u2_grid. Periods past the
%   last column take the last column.

if isfield(p, 'u1_grid_age') && ~isempty(p.u1_grid_age)
    t  = min(max(t, 1), size(p.u1_grid_age, 2));
    u1 = p.u1_grid_age(:, t);
    u2 = p.u2_grid_age(:, t);
else
    u1 = p.u1_grid;
    u2 = p.u2_grid;
end
end
