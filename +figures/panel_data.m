function d = panel_data(r)
%PANEL_DATA  The simulated panel of a result and the series the figures plot.
%
%   d = figures.panel_data(r)      % r from model.run or a saved ladder result
%
%   Uses r.sim when it was kept, and otherwise simulates the solved policies
%   again with the run's own N_sim and seed, which gives the same panel.
%   Levels are in thousands of euros (2025) with a euro income profile and in
%   CGM income units with 'poly'; d.scale and d.unit say which.
%
%   N x T fields: Y, C, X, A, H, c_frac, pi, disp_inc, ann_pay (gross),
%   takehome (wages or AOW after contributions and tax), annuity (after tax),
%   rent, maintenance, mortgage (the model's payment, sim.m_pay), M_balance
%   and H_net (a fixed-payment mortgage on the house at
%   entry, for the wealth panels), HC (human capital: the expected present
%   value of future income), net_worth = X + A + H_net, eq_liquid and eq_pension
%   (stock held in the liquid account after consumption and in the DC fund),
%   fin (liquid saving plus the fund balance those stock holdings sit in).
%
%   With the absorbing floor, every field except C is NaN for a household
%   from the age it is bankrupt (d.solvent is false there), so the figures,
%   which average with 'omitnan', show income, housing costs, the pension,
%   wealth and the shares over households not bankrupt at that age, and
%   consumption over all households (the bankrupt consume the floor). d.sim
%   is the panel as simulated, unchanged.

p = r.p;
if isfield(r, 'sim')
    sim = r.sim;
else
    sim = simulate.forward(p, r.profile, r.sol, r.ann_price, r.timing.N_sim, r.timing.seed, p.b0);
end
[N, T] = size(sim.Y);

d = struct();
d.sim  = sim;
d.ages = sim.ages(:).';
if strcmp(p.income_source, 'poly')
    d.scale = 1;    d.unit = 'CGM income units';
else
    d.scale = 1e-3; d.unit = 'thousand EUR (2025)';
end
d.has_housing = p.h_mult > 0;
d.has_pension = any(config.kappa_path(p) > 0);

f = {'Y', 'C', 'X', 'A', 'H', 'c_frac', 'pi', 'disp_inc', 'ann_pay'};
for i = 1:numel(f), d.(f{i}) = sim.(f{i}); end

% Income actually received and housing outflows
is_ret  = (1:T) >= p.t_ret;
net_inc = 1 - p.tau_inc;
kap     = config.kappa_path(p);
factor  = repmat(net_inc, 1, T);
factor(~is_ret) = (1 - kap(~is_ret)) * net_inc;
d.takehome    = factor .* sim.Y;
d.annuity     = net_inc .* sim.ann_pay;
d.rent        = zeros(N, T);
d.maintenance = zeros(N, T);
d.mortgage    = zeros(N, T);
if d.has_housing
    if p.is_owner
        d.maintenance = sim.h_cost - sim.m_pay;
        d.mortgage    = sim.m_pay;
    else
        d.rent = p.alpha .* sim.H;
    end
end
d.housing_cost = d.rent + d.maintenance + d.mortgage;

% Fixed-payment mortgage on the house at entry, for the wealth panels
d.M_balance = zeros(N, T);
if d.has_housing && p.is_owner && p.m_rate_path(1) > 0
    H0  = sim.H(:, 1);
    pmt = p.LTV * H0 * p.m_rate_path(1);
    M   = p.LTV * H0;
    d.M_balance(:, 1) = M;
    for t = 1:T-1
        M = max(0, M * (1 + p.r_m) - pmt);
        d.M_balance(:, t+1) = M;
    end
end
d.H_net = zeros(N, T);
if d.has_housing && p.is_owner
    d.H_net = sim.H - d.M_balance;
end
d.net_worth = sim.X + sim.A + d.H_net;

% Human capital: expected present value of future income at the risk-free rate,
% survival-weighted. HC = Y_t * g_t.
log_step = r.profile.mu_growth(:) + 0.5 * r.profile.sigma_l_log(:).^2;
cum_log  = [0; cumsum(log_step)];
ps = r.profile.p_surv(:);
g  = zeros(1, T);
for t = 1:T
    cs = 1; pv = 0;
    for s = t+1:T
        cs = cs * ps(s-1);
        pv = pv + exp(cum_log(s) - cum_log(t)) * cs / (1 + p.r)^(s - t);
    end
    g(t) = pv;
end
d.HC = sim.Y .* g;

% Stock holdings, as in model.summarize
X_sav = max(sim.LW - sim.C, 0);
A_pre = sim.A + kap .* sim.Y;
A_pre(:, is_ret) = sim.A(:, is_ret) - sim.ann_pay(:, is_ret);
tau_full = [sim.tau_A, zeros(N, 1)];
d.eq_liquid  = sim.pi .* X_sav;
d.eq_pension = tau_full .* A_pre;
d.fin        = X_sav + A_pre;
d.tau_path   = mean(tau_full, 1);

% Households not bankrupt at each age; the others leave every average but
% consumption.
d.solvent = true(N, T);
if isfield(sim, 'absorbed'), d.solvent = ~sim.absorbed; end
gone = ~d.solvent;
if any(gone(:))
    f = {'Y', 'X', 'A', 'H', 'c_frac', 'pi', 'disp_inc', 'ann_pay', 'takehome', 'annuity', 'rent', ...
         'maintenance', 'mortgage', 'housing_cost', 'M_balance', 'H_net', 'net_worth', 'HC', ...
         'eq_liquid', 'eq_pension', 'fin'};
    for i = 1:numel(f), d.(f{i})(gone) = NaN; end
end
end
