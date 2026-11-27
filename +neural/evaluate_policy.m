function ev = evaluate_policy(p, policy)
%EVALUATE_POLICY  The solver's value of a fixed policy: a network's or a grid's.
%
%   net = load('neural/data/net_step18_renter_k3000_run1.mat');
%   ev  = neural.evaluate_policy(r.p, net)                  % a trained network
%   ev  = neural.evaluate_policy(p_fine, neural.grid_policy_fn(r))   % a grid policy on another grid
%
%   Backward induction on p's grid (p as config.derive leaves it) with the
%   policy's choices at every node instead of the search
%   (solver.bellman_step_lna with a fixed policy): the same budget,
%   quadrature, interpolation of next year's value and bankruptcy rule as a
%   grid solve on that grid, so the value at entry is what the solver's own
%   machinery says the policy is worth there. policy is an exported network
%   (neural.net_policy), or a struct with fn, a function [x, pi] = fn(t, u1,
%   u2, u3, q), and kind: 's' when x is the share of resources above the floor
%   consumed, 'c' when it is the share of resources (a grid policy, which
%   then consumes at least the floor). Returns ev.V (as sol.V), ev.c_pol and
%   ev.pi_pol at the nodes, and ev.V_entry and ev.ce_entry at the welfare
%   anchor (as model.checks).

if isfield(policy, 'W1')
    net = policy;
    fixed = @(t, u1, u2, u3, q) neural.net_policy(net, p, t, u1, u2, u3, q);
else
    fixed = policy;
end
[profile, shocks, ann_price] = config.model_inputs(p);
sz = [numel(p.u1_grid), numel(p.u2_grid), numel(p.u3_grid), numel(p.q_grid), p.T];
V = zeros(sz); c_pol = zeros(sz); pi_pol = zeros(sz);
if isempty(gcp('nocreate')), utility.start_pool(); end
nthreads = maxNumCompThreads(1);              % as model.run: BLAS on one thread while the parfor runs
restore  = onCleanup(@() maxNumCompThreads(nthreads));
t0 = tic;
for t = p.T : -1 : 1
    if t == p.T, V_next = []; else, V_next = V(:, :, :, :, t + 1); end
    [V(:, :, :, :, t), c_pol(:, :, :, :, t), pi_pol(:, :, :, :, t)] = ...
        solver.bellman_step_lna(t, V_next, p, profile, shocks, ann_price, [], fixed);
end
g = p.gamma;
ev.V = V; ev.c_pol = c_pol; ev.pi_pol = pi_pol;
ev.V_entry = utility.welfare_anchor(p, V(:, :, :, :, 1), p.b0);
ev.ce_entry = ((1 - g) * ev.V_entry)^(1 / (1 - g)) * (1 + p.h_mult + p.b0) * p.D_abs(1)^(1 / (g - 1));
ev.sec = toc(t0);
end
