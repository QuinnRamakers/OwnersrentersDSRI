function m = u2_scale(p, t, u1, u3, q, ann_price)
%U2_SCALE  The u2 at v = 1 of the second grid axis (utility.u2_scale_fn).
%
%   m = utility.u2_scale(p, t, u1, u3, q, ann_price)
%
%   u2_max with p.u2_coord = 'edge'; the default boundary with 'boundary'.
%   Builds the interpolant on every call: in a hot loop build the handle once
%   with utility.u2_scale_fn.
f = utility.u2_scale_fn(p, t, ann_price);
m = f(u1, u3, q);
end
