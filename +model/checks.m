function c = checks(p, sol, sim, s, profile, shocks)
%CHECKS  What to look at before reading a solve.
%
%   c = model.checks(p, sol, sim, summary, profile, shocks)
%
%   offgrid          policy lookups past the end of an axis (u1, u2, u3, q);
%                    those households were given another state's policy
%   floored_share    household-years whose resources were topped up to the floor;
%   floored_by_phase   ... at ages 25-39, 40 to retirement, and in retirement
%   c_bound_25_39    share of households aged 25-39 consuming at the lower
%                    bound of the consumption search, the consumption floor
%                    phi_floor * Y, without being short of resources
%   ce_entry         the constant consumption, in multiples of entry income,
%                    worth as much as the value at entry. A small number means
%                    the value function is dominated by the floor states
%   burden_25, burden_30   median housing cost over net income
%   premium_after_tax, merton_liquid   after-tax equity premium and Merton
%                    share of the liquid account
%   corr_SL_nodes, corr_SL_sim   correlation of the income shock with the log
%                    stock return, on the quadrature nodes and in the panel's
%                    working years; both should equal corr_SL
%   corr_HL_nodes, corr_HL_sim, corr_SH_nodes, corr_SH_sim   the same for the
%                    log H growth with the income shock and with the log stock
%                    return; both should equal the tenure's pair (config.h_corr).
%                    NaN without housing
%   cov_u1, cov_u2   grid nodes inside the 1-99 percentile band of simulated
%                    households, by age (NaN at the first two ages and the last)
%   thin_u1_40       share of ages from 40 on with fewer than two u1 nodes in
%                    that band, where policies come from a single cell
%   notes            the checks above that call for attention, in words

ages = s.ages;
d = sim.diagnostics;
c = struct();
c.offgrid = [d.n_offgrid_u1, d.n_offgrid_u2, d.n_offgrid_u3, d.n_offgrid_q];
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
Vt = utility.welfare_anchor(p, sol.V(:,:,:,:,1), p.b0);
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

c.corr_SL_nodes = weighted_corr(shocks.joint.eps_Y_unit(:), log(shocks.joint.R_S(:)), shocks.joint.w(:));
c.corr_SL_sim   = panel_corr(sim, profile);
[c.corr_HL_nodes, c.corr_SH_nodes, c.corr_HL_sim, c.corr_SH_sim] = deal(NaN);
if p.h_mult > 0
    lH = log(shocks.joint.R_H(:));
    c.corr_HL_nodes = weighted_corr(shocks.joint.eps_Y_unit(:), lH, shocks.joint.w(:));
    c.corr_SH_nodes = weighted_corr(log(shocks.joint.R_S(:)), lH, shocks.joint.w(:));
    [c.corr_HL_sim, c.corr_SH_sim] = panel_corr_h(sim, profile);
end

[c.cov_u1, c.cov_u2] = coverage(p, sim);
m40 = ages >= 40 & ~isnan(c.cov_u1);
c.thin_u1_40 = mean(c.cov_u1(m40) < 2);

c.notes = {};
if any(c.offgrid > 0)
    c.notes{end+1} = sprintf(['%d policy lookups fell off the grid (u1 %d, u2 %d, u3 %d, q %d); ' ...
        'widen that axis (GRIDS.md).'], sum(c.offgrid), c.offgrid);
end
if c.c_bound_25_39 > 0.05
    c.notes{end+1} = sprintf(['%.0f%% of households aged 25-39 choose to consume only the floor ' ...
        '(phi_floor x income) although they could afford more.'], 100 * c.c_bound_25_39);
end
if c.floored_share > 0.01
    c.notes{end+1} = sprintf('The consumption floor binds in %.1f%% of household-years.', ...
        100 * c.floored_share);
end
if c.ce_entry < 0.05
    c.notes{end+1} = sprintf(['The value at entry is worth a constant %.2g x entry income: it is ' ...
        'dominated by floor states, so read behaviour, not welfare.'], c.ce_entry);
end
if abs(c.corr_SL_sim - p.corr_SL) > 0.01 || abs(c.corr_SL_nodes - p.corr_SL) > 0.01
    c.notes{end+1} = sprintf(['The income-stock correlation is %.3f on the nodes and %.3f in ' ...
        'the panel, against corr_SL = %.3f.'], c.corr_SL_nodes, c.corr_SL_sim, p.corr_SL);
end
[cHL, cSH] = config.h_corr(p);
if p.h_mult > 0 && max(abs([c.corr_HL_nodes, c.corr_HL_sim] - cHL)) > 0.01
    c.notes{end+1} = sprintf(['The income-H correlation is %.3f on the nodes and %.3f in the ' ...
        'panel, against %.3f.'], c.corr_HL_nodes, c.corr_HL_sim, cHL);
end
if p.h_mult > 0 && max(abs([c.corr_SH_nodes, c.corr_SH_sim] - cSH)) > 0.01
    c.notes{end+1} = sprintf(['The stock-H correlation is %.3f on the nodes and %.3f in the ' ...
        'panel, against %.3f.'], c.corr_SH_nodes, c.corr_SH_sim, cSH);
end
if c.thin_u1_40 > 0.25
    c.notes{end+1} = sprintf(['From 40 on, the occupied band holds fewer than two u1 nodes at ' ...
        '%.0f%% of ages, so policies there come from a single cell. A finer or ' ...
        'placed grid helps (GRIDS.md).'], 100 * c.thin_u1_40);
end
end

function rho = weighted_corr(x, y, w)
w = w / sum(w);
x = x - sum(w .* x);
y = y - sum(w .* y);
rho = sum(w .* x .* y) / sqrt(sum(w .* x.^2) * sum(w .* y.^2));
end

function rho = panel_corr(sim, profile)
% The income shock at t is log income growth less its deterministic part; it
% is drawn only in working years, where sigma_l_log > 0.
m = find(profile.sigma_l_log > 0).';
if isempty(m), rho = NaN; return; end
g = log(sim.Y(:, m + 1) ./ sim.Y(:, m)) - profile.mu_growth(m).';
s = log(sim.R_S(:, m));
r = corrcoef(g(:), s(:));
rho = r(1, 2);
end

function [rHL, rSH] = panel_corr_h(sim, profile)
% Log H growth against the income shock (working years) and the log stock
% return (every year). H_{t+1} = R_H H_t, so the growth is the H shock itself.
h = log(sim.H(:, 2:end) ./ sim.H(:, 1:end-1));
m = find(profile.sigma_l_log > 0).';
g = log(sim.Y(:, m + 1) ./ sim.Y(:, m)) - profile.mu_growth(m).';
r = corrcoef(g(:), reshape(h(:, m), [], 1));
rHL = r(1, 2);
r = corrcoef(reshape(log(sim.R_S), [], 1), h(:));
rSH = r(1, 2);
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
