function [s, pi_, d] = net_policy(net, p, t, u1, u2, u3, q)
%NET_POLICY  A trained policy network's choices in MATLAB.
%
%   net = load('neural/data/net_step18_renter_k3000_run1.mat');
%   [s, pi_, d] = neural.net_policy(net, p, t, u1, u2, u3, q)
%
%   The network of neural/src/policy.jl, written by
%   neural/scripts/export_net.jl: tanh hidden layers, two outputs through a
%   sigmoid. s is the share of liquid resources above the floor consumed
%   (consumption = F + s (LW - F)), pi_ the liquid equity share. u1, u2, u3
%   and q are the household's coordinates on the solver's cube, column vectors
%   of one length; t is the period. The inputs are built as in the Julia
%   features(): age scaled to [0, 1], u1, u2, u3, q only for owners whose
%   budget depends on it (1 elsewhere), then years to retirement and a retired
%   indicator (net.retire), then an owner indicator (net.tenure). In the last
%   period without a bequest motive s = 1, as in the solver. A network with a
%   third output (default as a choice, step 24) gives d, the decision to
%   default this year (its probability above one half); without one d is
%   false. With default as a choice consumption is phi_floor Y + s (LW -
%   phi_floor Y) instead (simulate.paths_lna).

u1 = u1(:); u2 = u2(:); u3 = u3(:); q = q(:);
n = numel(u1);
q_on = p.is_owner && (strcmp(p.mortgage, 'annuity') || p.maint_on_purchase);
if ~q_on, q = ones(n, 1); end
X = [repmat((t - 1) / (p.T - 1), 1, n); u1.'; u2.'; u3.'; q.'];
if net.retire
    X = [X; repmat(max(p.t_ret - t, 0) / (p.t_ret - 1), 1, n); repmat(double(t >= p.t_ret), 1, n)];
end
if net.tenure
    X = [X; repmat(double(p.is_owner), 1, n)];
end
out = neural.net_forward(net, X);
s   = 1 ./ (1 + exp(-out(1, :).'));
pi_ = 1 ./ (1 + exp(-out(2, :).'));
if t == p.T && p.chi <= 0
    s = ones(n, 1);
end
d = false(n, 1);
if size(out, 1) >= 3
    d = out(3, :).' > 0;          % sigmoid above one half
end
end
