function gn = age_grid(r, N1, N2, opts)
%AGE_GRID  Grid points that follow the households age by age, from a solved panel.
%
%   gn = age_grid(r, 16, 16)                 % p.grid_nodes = gn
%   gn = age_grid(r, 16, 16, share_in=0.6, band=[0.5 99.5], pad=0.3)
%
%   r is a solved result of the same step (the pilot); its panel says where
%   households are at each age. For every period the u1 points are placed in
%   x = log(W/Y) = -log(u1), on [0, -log(u1_min)]: a share share_in of them
%   evenly inside the band where households live at that age (the band
%   percentiles of the pilot's panel, widened by pad on each side, at least
%   0.5 wide), the rest evenly over the two stretches of the axis outside it,
%   in proportion to their lengths, always including both ends. The u2 points
%   likewise in y = -log(1 - u2 + d), d = 1e-5, so that points crowd toward
%   u2 = 1 (little liquid saving beside the pot) where households are; u2 = 0
%   and u2 = 1 are always points. Returns grid_nodes fields u1_age (N1 x T)
%   and u2_age (N2 x T). The axis ends are the pilot's.

arguments
    r (1,1) struct
    N1 (1,1) double
    N2 (1,1) double
    opts.share_in (1,1) double = 0.6
    opts.band (1,2) double = [0.5 99.5]
    opts.pad (1,1) double = 0.3
end

p = r.p; T = p.T;
s = figures.panel_data(r).sim;
u1 = s.lambda; u2 = (s.sA + s.sH) ./ max(1 - u1, 1e-12);
d = 1e-5;
L1 = -log(min(p.u1_grid)); top1 = -log(max(p.u1_grid));
L2 = -log(d);
U1 = zeros(N1, T); U2 = zeros(N2, T);
for t = 1:T
    x = -log(max(u1(:, t), 1e-12));
    y = -log(max(1 - u2(:, t), 0) + d);
    U1(:, t) = sort(exp(-place(x, N1, top1, L1, opts)));
    yy = place(y, N2, 0, L2, opts);
    v = 1 + d - exp(-yy);
    v(yy <= 0) = 0; v(yy >= L2) = 1;
    U2(:, t) = sort(min(max(v, 0), 1));
end
gn = struct('u1_age', U1, 'u2_age', U2);
end

function z = place(x, N, lo, hi, opts)
% N points on [lo, hi]: share_in inside the padded band of x, the rest outside.
b = prctile(x, opts.band);
b = [b(1) - opts.pad, b(2) + opts.pad];
if diff(b) < 0.5, b = mean(b) + [-0.25 0.25]; end
b = [max(b(1), lo), min(b(2), hi)];
n_in = max(2, round(opts.share_in * N));
l_lo = b(1) - lo; l_hi = hi - b(2);
n_out = N - n_in;
% each stretch outside the band that has length gets its end point at least
k_lo = 0; k_hi = 0;
if l_lo > 1e-9, k_lo = 1; end
if l_hi > 1e-9, k_hi = 1; end
rest = n_out - k_lo - k_hi;
if rest < 0, n_in = n_in + rest; rest = 0; end
if l_lo + l_hi > 0
    e_lo = round(rest * l_lo / (l_lo + l_hi));
else
    e_lo = 0;
end
k_lo = k_lo + e_lo * (l_lo > 1e-9); k_hi = k_hi + (rest - e_lo) * (l_hi > 1e-9);
n_in = N - k_lo - k_hi;
z_in = linspace(b(1), b(2), n_in);
z_lo = linspace(lo, b(1), k_lo + 1); z_lo = z_lo(1:end-1);
z_hi = linspace(b(2), hi, k_hi + 1); z_hi = z_hi(2:end);
z = [z_lo, z_in, z_hi].';
assert(numel(z) == N && numel(unique(z)) == N, 'age_grid:place', 'placement produced %d distinct points, not %d.', numel(unique(z)), N);
end
