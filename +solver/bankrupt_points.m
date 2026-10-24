function bk = bankrupt_points(V, p, t)
%BANKRUPT_POINTS  The grid points of period t that hold the bankrupt value.
%
%   bk = solver.bankrupt_points(V, p, t)
%
%   V is period t's value on its grid, N_u1 x N_u2 x N_u3 (x N_q). With the
%   absorbing floor, solver.bellman_step_lna stores the closed form
%   F^(1-gamma)/(1-gamma) * D_abs(t), F = max(phi_path(t) * u1, 1e-12), at
%   every grid point whose liquid resources fall short of the floor; bk is
%   true where V equals it to 1e-9 relative. All false without the absorbing
%   floor.

bk = false(size(V));
if ~(isfield(p, 'floor_absorbing') && p.floor_absorbing), return; end
g1 = utility.grid_at(p, t);
F  = max(p.phi_path(t) * g1(:), 1e-12);
Vb = F .^ (1 - p.gamma) / (1 - p.gamma) * p.D_abs(t);
bk = abs(V ./ Vb - 1) < 1e-9;
end
