function T = check_networks(r, net_files, opts)
%CHECK_NETWORKS  Trained networks against the grid policy, entirely in MATLAB.
%
%   r = load('neural/data/solve_18_renter_standard.mat').r;
%   T = neural.check_networks(r, {'net_step18_renter_k3000_run1.mat'}, N=20000, seed=202)
%
%   For the grid solve r and each network: the network's raw outputs against
%   Julia's on its check inputs; the grid policy and the network simulated by
%   simulate.paths_lna on the same draws (the network through
%   sol.policy_fn), scored by neural.sim_utility (paired difference and its
%   standard error); years bankrupt; and, with value=true, the solver's value
%   of the network's policy (neural.evaluate_policy) beside the grid's.
%   One row per network in table T; the panels are not kept.

arguments
    r struct
    net_files cell
    opts.N (1,1) double = 20000
    opts.seed (1,1) double = 202
    opts.value (1,1) logical = true
    opts.data char = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'neural', 'data')
end

p = r.p;
g = p.gamma;
sim_g = simulate.paths_lna(p, r.profile, r.sol, r.ann_price, opts.N, opts.seed, p.b0);
[U_g, ce_g, se_g] = neural.sim_utility(p, r.profile, sim_g);
fprintf('%s, grid %s: grid policy simulated ce %.4f (s.e. %.4f), value function %.4f, years bankrupt %.4f\n', ...
    r.tenure, mat2str(size(r.sol.V, 1:4)), ce_g, se_g, r.checks.ce_entry, mean(sim_g.absorbed, 'all'));

rows = {};
for i = 1:numel(net_files)
    net = load(fullfile(opts.data, net_files{i}));
    gap_fwd = max(abs(neural.net_forward(net, net.check_in) - net.check_out), [], 'all');
    sol = struct('policy_fn', @(t, u1, u2, u3, q) neural.net_policy(net, p, t, u1, u2, u3, q));
    sim_n = simulate.paths_lna(p, r.profile, sol, r.ann_price, opts.N, opts.seed, p.b0);
    [U_n, ce_n, se_n] = neural.sim_utility(p, r.profile, sim_n);
    EUn = mean(U_n); EUg = mean(U_g);
    h = ce_n / ((1 - g) * EUn) * U_n - ce_g / ((1 - g) * EUg) * U_g;
    ce_solver = NaN; sec = NaN;
    if opts.value
        ev = neural.evaluate_policy(p, net);
        ce_solver = ev.ce_entry; sec = ev.sec;
    end
    rows(end+1, :) = {string(net_files{i}), gap_fwd, ce_n, se_n, ce_g, ce_n - ce_g, std(h) / sqrt(numel(h)), ...
        mean(sim_n.absorbed, 'all'), mean(sim_g.absorbed, 'all'), ce_solver, r.checks.ce_entry, sec}; %#ok<AGROW>
    fprintf(['%s: forward gap %.1e; simulated ce %.4f against grid %.4f, diff %+.4f (s.e. %.4f); ' ...
             'bankrupt %.4f / %.4f; solver value %.4f against grid %.4f\n'], net_files{i}, gap_fwd, ce_n, ce_g, ...
             ce_n - ce_g, std(h) / sqrt(numel(h)), mean(sim_n.absorbed, 'all'), mean(sim_g.absorbed, 'all'), ...
             ce_solver, r.checks.ce_entry);
end
T = cell2table(rows, 'VariableNames', {'net', 'forward_gap', 'ce_net_sim', 'se_net', 'ce_grid_sim', 'diff', ...
    'se_diff', 'bankrupt_net', 'bankrupt_grid', 'ce_net_solver', 'ce_grid_solver', 'eval_sec'});
end
