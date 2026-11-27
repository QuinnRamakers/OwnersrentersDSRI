function [num, den] = slack_terms(p, t, u1, u3, q, ann_price)
%SLACK_TERMS  Liquid resources above the edge of bankruptcy, affine in u2.
%
%   [num, den] = utility.slack_terms(p, t, u1, u3, q, ann_price)
%
%   Liquid resources per unit of W at period t, as solver.bellman_step_lna
%   forms them, less the floor share phi u1 (phi_path(t), or phi_floor with
%   default as a choice):
%       LW/W - phi u1 = num - den u2,
%       num = (1 - u1) + (y - phi) u1,
%       den = (1 - u1) (1 - a u3 + h (1 - u3)),
%   with y the take-home share of income, a the net annuity rate in
%   retirement and h the housing cost rate (rent; maintenance and the
%   mortgage payment, by q). utility.u2_max is num / den; utility.cont_z
%   extends the value of continuing past the edge with num - den u2. u1, u3
%   and q are arrays of one size (q a scalar or empty where it plays no
%   part); ann_price is needed only in retirement.
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
end
