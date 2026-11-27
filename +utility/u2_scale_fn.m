function f = u2_scale_fn(p, t, ann_price)
%U2_SCALE_FN  The u2 that the second grid axis maps to v = 1, as a function.
%
%   f = utility.u2_scale_fn(p, t, ann_price);   m = f(u1, u3, q);   v = u2 ./ m
%
%   p.u2_coord = 'edge': m = utility.u2_max(p, t, u1, u3, q, ann_price), the
%   edge of bankruptcy. p.u2_coord = 'boundary': m = r u2_max, with r in
%   (0, 1] the default boundary as a share of the edge, found on each
%   (u1, u3, q) line of period t's grid before t is solved
%   (solver.find_boundary) and held in p.u2_bnd (N_u1 x N_u3 x N_q x T;
%   solver.solve_lifecycle_lna fills it, sol.u2_bnd keeps it, and model.run
%   and simulate.paths_lna copy it into p). Between lines r is interpolated
%   linearly, held flat past the axes' ends. Without p.u2_bnd, r = 1 (as
%   config.insert_anchor_nodes places the entry anchors, before any solve).
%   q is a scalar, an array of the size of u1, or empty (q = 1).
%   The handle carries only what it reads, not all of p.
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
R = p.u2_bnd(:, :, :, min(t, size(p.u2_bnd, 4)));
q_grid = p.q_grid(:);
if numel(q_grid) > 1
    F = griddedInterpolant({g1(:), p.u3_grid(:), q_grid}, R, 'linear', 'nearest');
    f = @(u1, u3, q) utility.u2_max(pe, t, u1, u3, q, ann_price) .* F(u1, u3, qfill(q, u1));
else
    F = griddedInterpolant({g1(:), p.u3_grid(:)}, R(:, :, 1), 'linear', 'nearest');
    f = @(u1, u3, q) utility.u2_max(pe, t, u1, u3, q, ann_price) .* F(u1, u3);
end
end

function q = qfill(q, u1)
if isempty(q), q = 1; end
if isscalar(q), q = q + zeros(size(u1)); end
end
