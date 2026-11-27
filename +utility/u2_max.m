function m = u2_max(p, t, u1, u3, q, ann_price)
%U2_MAX  The largest u2 at which a household is still solvent this year.
%
%   m = utility.u2_max(p, t, u1, u3, q, ann_price)
%
%   With p.u2_coord = 'edge' the second grid coordinate is v = u2 / m, so
%   that v = 1 is the edge of bankruptcy at every (u1, u3, q) and age, and
%   the grid's nodes on v in [0, 1] cover the solvent states only (a state
%   with v > 1 is bankrupt, or with default as a choice has no resources, and
%   its value is known exactly). Liquid resources per unit of W are affine in
%   u2 at given u1, u3 and q, as solver.bellman_step_lna forms them:
%       LW/W = (1 - u1) + y u1 - (1 - u1) u2 (1 - a u3 + h (1 - u3)),
%   with y the take-home share of income, a the net annuity rate in
%   retirement and h the housing cost rate (rent; maintenance and the
%   mortgage payment, by q). The edge is LW/W = phi u1, with phi the floor
%   share phi_path(t), or phi_floor with default as a choice, so
%       m = min(1, (1 - 1e-9) ((1 - u1) + (y - phi) u1) / ((1 - u1) (1 - a u3 + h (1 - u3)))).
%   The factor 1 - 1e-9 keeps the node at v = 1 just inside, where the
%   household consumes the floor and saves nothing. u1, u3 and q are arrays
%   of one size (q a scalar or empty where it plays no part); ann_price is
%   needed only in retirement.
net_inc = 1 - p.tau_inc;
if t >= p.t_ret
    y = net_inc; a = net_inc / ann_price(t);
else
    y = (1 - p.kappa(min(t, numel(p.kappa)))) * net_inc; a = 0;
end
if isempty(q), q = 1; end
if p.h_mult == 0
    h = 0;
elseif p.is_owner
    if t <= numel(p.m_rate_path), mr = p.m_rate_path(t); else, mr = 0; end
    hm = mr; ht = p.theta;
    if strcmp(p.mortgage, 'annuity'), hm = mr .* q; end
    if p.maint_on_purchase, ht = p.theta .* q; end
    h = ht + hm;
else
    h = p.alpha;
end
phi = p.phi_path(t);
if p.floor_absorbing && isfield(p, 'default_choice') && p.default_choice, phi = p.phi_floor; end
num = (1 - u1) + (y - phi) .* u1;
den = (1 - u1) .* (1 - a .* u3 + h .* (1 - u3));
m = min(1, (1 - 1e-9) * num ./ den);
m(~(den > 0)) = 1;                  % u1 = 1: nothing but income, never short
m = max(m, 1e-9);
end
