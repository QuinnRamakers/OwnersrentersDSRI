function f = u2_scale_fn(p, t, ann_price)
%U2_SCALE_FN  The u2 that the second grid axis maps to v = 1, as a function.
%
%   f = utility.u2_scale_fn(p, t, ann_price);   m = f(u1, u3, q);   v = u2 ./ m
%
%   p.u2_coord = 'edge': m = utility.u2_max(p, t, u1, u3, q, ann_price), the
%   edge of bankruptcy. p.u2_coord = 'boundary': m is the default boundary,
%   found on each (u1, u3, q) line of period t's grid before t is solved
%   (solver.find_boundary) and held in p.u2_bnd (N_u1 x N_u3 x N_q x T;
%   solver.solve_lifecycle_lna fills it, sol.u2_bnd keeps it, and model.run
%   and simulate.paths_lna copy it into p) as rho = s_b / z_def, the
%   resources above the edge at the boundary (utility.slack_terms) over the
%   default value's certainty equivalent per unit of W, phi_t u1
%   D_t^(1/(1-gamma)). Between lines rho is interpolated linearly, held flat
%   past the axes' ends, and the boundary is where the state's own
%   resources above the edge equal rho z_def:
%       m = (num - rho z_def) / den,   within [1e-3 u2_max, u2_max],
%   and u2_max where den <= 0. At a line's own node this is the boundary
%   found there. rho changes little along u1 (both s_b and z_def go with
%   it), which a share of u2_max does not: for owners the boundary sits just
%   below u2_max, and blending the share 1 of a line that never defaults
%   with that of one that does put solvent owners past it. Without
%   p.u2_bnd, m = u2_max (as config.insert_anchor_nodes places the entry
%   anchors, before any solve). q is a scalar, an array of the size of u1,
%   or empty (q = 1). The handle carries only what it reads, not all of p.
pe = struct();
fl = {'tau_inc', 't_ret', 'kappa', 'h_mult', 'is_owner', 'm_rate_path', 'theta', ...
      'mortgage', 'maint_on_purchase', 'alpha', 'phi_path', 'phi_floor', 'floor_absorbing', 'default_choice'};
for i = 1:numel(fl)
    if isfield(p, fl{i}), pe.(fl{i}) = p.(fl{i}); end
end
bnd = isfield(p, 'u2_coord') && strcmp(p.u2_coord, 'boundary') && isfield(p, 'u2_bnd') && ~isempty(p.u2_bnd);
if ~bnd
    f = @(u1, u3, q) utility.u2_max(pe, t, u1, u3, q, ann_price);
    return
end
g1 = utility.grid_at(p, t);
P = p.u2_bnd(:, :, :, min(t, size(p.u2_bnd, 4)));
q_grid = p.q_grid(:);
Dfac = p.D_beq(t) ^ (1 / (1 - p.gamma));    % z_def = max(phi_t u1, 1e-12) Dfac, as find_boundary
if numel(q_grid) > 1
    F = griddedInterpolant({g1(:), p.u3_grid(:), q_grid}, P, 'linear', 'nearest');
    f = @(u1, u3, q) place(pe, t, u1, u3, q, ann_price, F(u1, u3, qfill(q, u1)), Dfac);
else
    F = griddedInterpolant({g1(:), p.u3_grid(:)}, P(:, :, 1), 'linear', 'nearest');
    f = @(u1, u3, q) place(pe, t, u1, u3, q, ann_price, F(u1, u3), Dfac);
end
end

function m = place(pe, t, u1, u3, q, ann_price, rho, Dfac)
% the boundary's u2 from rho at the states
[num, den] = utility.slack_terms(pe, t, u1, u3, q, ann_price);
u2m = utility.u2_max(pe, t, u1, u3, q, ann_price);
zd  = max(pe.phi_path(t) * u1, 1e-12) * Dfac;
m   = (num - rho .* zd) ./ den;
m   = min(max(m, 1e-3 * u2m), u2m);
flat = ~(den > 0);
m(flat) = u2m(flat);
end

function q = qfill(q, u1)
if isempty(q), q = 1; end
if isscalar(q), q = q + zeros(size(u1)); end
end
