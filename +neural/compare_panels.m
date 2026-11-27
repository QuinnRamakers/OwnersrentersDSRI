function out = compare_panels(r, net_file, opts)
%COMPARE_PANELS  Where a network gains on the grid policy: households and ages.
%
%   r = load('neural/data/solve_18_renter_standard.mat').r;
%   out = neural.compare_panels(r, 'net_step18_renter_k3000_run1.mat', N=20000, seed=202)
%
%   Simulates the grid policy and the network on the same draws
%   (simulate.paths_lna) and splits the difference in mean lifetime utility
%   (neural.sim_utility) over four groups of households: bankrupt under
%   neither policy, under both, only under the grid policy, only under the
%   network. Returns the groups' shares and shares of the difference, the
%   certainty equivalents, the age of bankruptcy, and means and percentiles
%   by age of consumption, liquid wealth, the pot, the house or rent index
%   and income (in entry income), the equity share of the solvent and the
%   share bankrupt, for both policies (out.grid, out.net).

arguments
    r struct
    net_file char
    opts.N (1,1) double = 20000
    opts.seed (1,1) double = 202
    opts.data char = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'neural', 'data')
end

p = r.p;
net = load(fullfile(opts.data, net_file));
sim_g = simulate.paths_lna(p, r.profile, r.sol, r.ann_price, opts.N, opts.seed, p.b0);
sol_n = struct('policy_fn', @(t, u1, u2, u3, q) neural.net_policy(net, p, t, u1, u2, u3, q));
sim_n = simulate.paths_lna(p, r.profile, sol_n, r.ann_price, opts.N, opts.seed, p.b0);
[U_g, ce_g] = neural.sim_utility(p, r.profile, sim_g);
[U_n, ce_n] = neural.sim_utility(p, r.profile, sim_n);

bg = any(sim_g.absorbed, 2); bn = any(sim_n.absorbed, 2);
groups = {'neither', ~bg & ~bn; 'both', bg & bn; 'grid only', bg & ~bn; 'network only', ~bg & bn};
dU = U_n - U_g;
tot = sum(dU);
out.groups = table(string(groups(:, 1)), cellfun(@(m) mean(m), groups(:, 2)), ...
    cellfun(@(m) sum(dU(m)) / tot, groups(:, 2)), cellfun(@(m) mean(U_g(m)), groups(:, 2)), ...
    cellfun(@(m) mean(U_n(m)), groups(:, 2)), ...
    'VariableNames', {'group', 'share_households', 'share_of_gain', 'mean_U_grid', 'mean_U_net'});
out.ce_grid = ce_g; out.ce_net = ce_n;
out.worst1_grid = worst_share(U_g); out.worst1_net = worst_share(U_n);
out.abs_age_grid = sim_g.abs_age; out.abs_age_net = sim_n.abs_age;
out.grid = profiles(sim_g, p);
out.net = profiles(sim_n, p);
out.U_grid = U_g; out.U_net = U_n;
out.ages = sim_g.ages;
out.tenure = r.tenure;
out.net_file = net_file;
end

function s = worst_share(U)
u = sort(U);
k = max(1, round(0.01 * numel(u)));
s = sum(u(1:k)) / sum(u);
end

function pr = profiles(sim, p)
Y0 = sim.Y(1, 1);
solvent = ~sim.absorbed;
f = struct('C', sim.C, 'X', sim.X, 'A', sim.A, 'H', sim.H, 'Y', sim.Y, 'LW', sim.LW);
names = fieldnames(f);
for i = 1:numel(names)
    M = f.(names{i}) / Y0;
    pr.(names{i}) = mean(M, 1).';
    pr.([names{i} '_p10']) = prctile(M, 10, 1).';
    pr.([names{i} '_p50']) = prctile(M, 50, 1).';
    pr.([names{i} '_p90']) = prctile(M, 90, 1).';
end
pi_ = sim.pi; pi_(~solvent) = NaN;
pr.pi = mean(pi_, 1, 'omitnan').';
pr.pi_p10 = prctile(pi_, 10, 1).'; pr.pi_p90 = prctile(pi_, 90, 1).';
c = sim.c_frac; c(~solvent) = NaN;
pr.c_frac = mean(c, 1, 'omitnan').';
pr.absorbed = mean(sim.absorbed, 1).';
pr.C_over_Y = mean(sim.C ./ sim.Y, 1).';
% The coordinates of the solvent, for the policy-function figures: medians by age
W = sim.X + sim.A + sim.H + sim.Y;
pr.XY_med = median_solvent(sim.X ./ sim.Y, solvent);
pr.AY_med = median_solvent(sim.A ./ sim.Y, solvent);
pr.HY_med = median_solvent(sim.H ./ sim.Y, solvent);
pr.q_med  = median_solvent(sim.q, solvent);
pr.XY_p05 = prctile_solvent(sim.X ./ sim.Y, solvent, 5);
pr.XY_p95 = prctile_solvent(sim.X ./ sim.Y, solvent, 95);
pr.u1_med = median_solvent(sim.Y ./ W, solvent);
pr.T = p.T;
end

function m = median_solvent(M, solvent)
M(~solvent) = NaN;
m = median(M, 1, 'omitnan').';
end

function m = prctile_solvent(M, solvent, k)
M(~solvent) = NaN;
m = prctile(M, k, 1).';
end
