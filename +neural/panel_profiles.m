function pr = panel_profiles(sim, p)
%PANEL_PROFILES  Means and percentiles by age of a simulated panel, in entry income.
%
%   pr = neural.panel_profiles(sim, p)
%
%   sim is a panel of simulate.paths_lna. Consumption, liquid wealth, the
%   pot, the house or rent index, income and resources: mean and the 10th,
%   50th and 90th percentiles by age (fields C, C_p10, ...). The equity share
%   and the consumption share of the solvent, the share bankrupt (or
%   defaulted), consumption over income, and the medians of the solvent's
%   coordinates for the policy figures. Used by neural.compare_panels and
%   neural.plot_lifecycles.

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
