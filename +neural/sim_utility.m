function [U, ce, se] = sim_utility(p, profile, sim)
%SIM_UTILITY  Realised lifetime utility of a simulated panel, in MATLAB.
%
%   [U, ce, se] = neural.sim_utility(p, profile, sim)
%
%   U (N x 1) is each household's sum over years of beta^(t-1) S_t u(C_t / Y0),
%   with S_t the probability of being alive at t and Y0 entry income, read
%   straight off the panel's consumption: a bankrupt household consumes its
%   floor every year after, which sums to u(F) D_abs(t) at entry, the value the
%   solver gives it (no bequest motive; chi > 0 is refused). ce is the constant
%   consumption, in multiples of entry income, worth mean(U), as
%   model.checks' ce_entry, and se its Monte Carlo standard error (delta
%   method). Written apart from the Julia lifetime utility, as a check on it.

assert(p.chi <= 0, 'sim_utility:chi', 'The bequest motive is not covered.');
g = p.gamma;
Y0 = sim.Y(1, 1);
disc = ones(1, p.T);
for t = 2:p.T
    disc(t) = disc(t - 1) * p.beta * profile.p_surv(t - 1);
end
U = ((sim.C / Y0) .^ (1 - g) / (1 - g)) * disc(:);
EU = mean(U);
ce = ((1 - g) * EU / p.D_abs(1))^(1 / (1 - g));
se = ce * (std(U) / sqrt(numel(U))) / abs((1 - g) * EU);
end
