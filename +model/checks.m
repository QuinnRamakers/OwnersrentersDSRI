function c = checks(p, sol, sim, s, profile, shocks)
%CHECKS  What to look at before reading a solve.
%
%   c = model.checks(p, sol, sim, summary, profile, shocks)
%
%   offgrid          policy lookups past the end of an axis (u1, u2, u3);
%                    those households were given another state's policy
%   floored_share    household-years whose resources were topped up to the floor;
%   floored_by_phase   ... at ages 25-39, 40 to retirement, and in retirement
%   c_bound_25_39    share of households aged 25-39 consuming at the lower
%                    bound of the consumption search (c_floor_frac). Where this
%                    is large, early-life consumption is set by the bound
%   ce_entry         the constant consumption, in multiples of entry income,
%                    worth as much as the value at entry. A small number means
%                    the value function is dominated by the floor states
%   burden_25, burden_30   median housing cost over net income
%   premium_after_tax, merton_liquid   after-tax equity premium and Merton
%                    share of the liquid account
%   cov_u1, cov_u2   grid nodes inside the 1-99 percentile band of simulated
%                    households, by age (NaN at the first two ages and the last)
%   thin_u1_40       share of ages from 40 on with fewer than two u1 nodes in
%                    that band, where policies come from a single cell
%   notes            the checks above that call for attention, in words

ages = s.ages;
d = sim.diagnostics;
c = struct();
c.offgrid = [d.n_offgrid_u1, d.n_offgrid_u2, d.n_offgrid_u3];
c.floored_share = mean(sim.floored(:));
young = ages <= 39;
mid   = ages >= 40 & ages < p.retirement_age;
old   = ages >= p.retirement_age;
c.floored_by_phase = [mean(s.floored(young)), mean(s.floored(mid)), mean(s.floored(old))];
c.c_bound_25_39 = mean(s.at_c_bound(young));

% Value at entry and its constant-consumption equivalent. V = W^(1-g) V_tilde
% and a constant stream c_bar is worth u(c_bar) * D, with D the discounted
% survival-weighted horizon, so c_bar = W0 * z * D^(1/(g-1)).
g  = p.gamma;
Vt = utility.welfare_anchor(p, sol.V(:,:,:,1), p.b0);
z  = ((1 - g) * Vt)^(1 / (1 - g));
S  = cumprod([1; profile.p_surv(1:end-1)]);
D  = sum(p.beta .^ (0:p.T-1).' .* S);
c.V_entry  = Vt;
c.ce_entry = z * (1 + p.h_mult + p.b0) * D^(1 / (g - 1));

c.burden_25 = s.burden(1);
c.burden_30 = s.burden(ages == 30);

Rf_at = (1 + p.r * (1 - p.tau_cg_bond)) * (1 - p.tau_wealth);
RS_at = config.after_tax_stock(p, shocks.R_S(:));
w     = shocks.w_S(:);
ER    = sum(w .* RS_at);
VR    = sum(w .* (RS_at - ER).^2);
c.premium_after_tax = ER - Rf_at;
c.merton_liquid     = c.premium_after_tax / (g * VR);

[c.cov_u1, c.cov_u2] = coverage(p, sim);
m40 = ages >= 40 & ~isnan(c.cov_u1);
c.thin_u1_40 = mean(c.cov_u1(m40) < 2);

c.notes = {};
if any(c.offgrid > 0)
    c.notes{end+1} = sprintf(['%d policy lookups fell off the grid (u1 %d, u2 %d, u3 %d); ' ...
        'widen that axis (GRIDS.md).'], sum(c.offgrid), c.offgrid);
end
if c.c_bound_25_39 > 0.05
    c.notes{end+1} = sprintf(['%.0f%% of households aged 25-39 consume at the search bound: ' ...
        'early-life consumption there is set by c_floor_frac, not chosen.'], 100 * c.c_bound_25_39);
end
if c.floored_share > 0.01
    c.notes{end+1} = sprintf('The consumption floor binds in %.1f%% of household-years.', ...
        100 * c.floored_share);
end
if c.ce_entry < 0.05
    c.notes{end+1} = sprintf(['The value at entry is worth a constant %.2g x entry income: it is ' ...
        'dominated by floor states, so read behaviour, not welfare.'], c.ce_entry);
end
if c.thin_u1_40 > 0.25
    c.notes{end+1} = sprintf(['From 40 on, the occupied band holds fewer than two u1 nodes at ' ...
        '%.0f%% of ages, so policies there come from a single cell. A finer or ' ...
        'placed grid helps (GRIDS.md).'], 100 * c.thin_u1_40);
end
end

function [n1, n2] = coverage(p, sim)
% Nodes inside the per-age 1-99 percentile band. The first two ages are left
% out because every household enters at one state, the last because nothing
% is decided there.
T  = p.T;
u1 = sim.lambda;
u2 = (sim.sA + sim.sH) ./ max(1 - sim.lambda, 1e-12);
n1 = nan(1, T); n2 = nan(1, T);
for t = 3 : T - 1
    b1 = prctile(u1(:, t), [1 99]);
    b2 = prctile(u2(:, t), [1 99]);
    n1(t) = sum(p.u1_grid >= b1(1) & p.u1_grid <= b1(2));
    n2(t) = sum(p.u2_grid >= b2(1) & p.u2_grid <= b2(2));
end
end
