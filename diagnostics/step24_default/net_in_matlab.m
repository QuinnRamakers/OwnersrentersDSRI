function net_in_matlab(tenure, tag, run, numerics)
%NET_IN_MATLAB  The step-24 network in MATLAB's simulator against its Julia panel.
%
%   net_in_matlab('renter', 'step24_renter', 'run1', 'quick')
%
%   Simulates the test set's households (seed 202, 20,000) with
%   simulate.paths_lna and the network as its policy (neural.net_policy, the
%   default decision included) and compares consumption, liquid wealth and
%   the defaults with the panel neural/scripts/net_panel.jl wrote from the
%   Julia year on the same draws. Needs solve_24_<tenure>_<numerics>.mat,
%   net_<tag>_<run>.mat (export_net.jl) and netpanel_<tag>_<run>.mat.

d = fullfile(pwd, 'neural', 'data');
r = load(fullfile(d, sprintf('solve_24_%s_%s.mat', tenure, numerics))).r;
net = load(fullfile(d, sprintf('net_%s_%s.mat', tag, run)));
J = load(fullfile(d, sprintf('netpanel_%s_%s.mat', tag, run)));
p = r.p;
fwd = neural.net_forward(net, net.check_in);
fprintf('network forward pass against Julia: largest gap %.2e\n', max(abs(fwd(:) - net.check_out(:))));
sol = struct('policy_fn', @(t, u1, u2, u3, q) neural.net_policy(net, p, t, u1, u2, u3, q));
sim = simulate.paths_lna(p, r.profile, sol, r.ann_price, size(J.C, 1), 202, p.b0);
Y0 = sim.Y(1, 1);
gap = @(a, b) max(abs(a(:) - b(:)) ./ max(abs(b(:)), Y0));
fprintf('MATLAB against Julia, largest gap relative to entry income: C %.2e, X %.2e, LW %.2e\n', ...
    gap(sim.C, J.C), gap(sim.X, J.X), gap(sim.LW, J.LW));
fprintf('defaulted households: MATLAB %d, Julia %d, disagreeing household-years %d\n', ...
    nnz(any(sim.absorbed, 2)), nnz(any(J.absorbed, 2)), nnz(sim.absorbed ~= (J.absorbed > 0.5)));
end
