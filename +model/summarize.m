function s = summarize(p, sim)
%SUMMARIZE  Per-age statistics of a simulated panel.
%
%   s = model.summarize(p, sim)
%
%   Levels are in the model's income units: euros of 2025 with the 'table'
%   income profile, unscaled CGM units with 'poly'. s.Y0, income at entry, is
%   the scale for comparing levels across calibrations.
%
%   Each level field is a struct of 1 x T rows: mean, p10, p50, p90.
%     C, Y, net_income (after tax and contributions, before housing),
%     housing_cost (sim.h_cost), X (liquid), A (DC pot), H, home_equity (owner:
%     house net of the outstanding mortgage; otherwise 0), net_worth =
%     X + A + home_equity, ann_pay (gross annuity payout)
%   Shares, 1 x T:
%     pi             mean liquid equity share (also pi_p10, pi_p50, pi_p90)
%     c_frac         mean share of liquid resources consumed
%     dc_share       the fund's stock share (the glide less its REIT part; 0 in
%                    the last period); dc_reit the fund's REIT share
%     equity_share   stocks in the liquid account and the fund over their sum,
%                    aggregated across households
%     burden         median housing cost over net income
%     floored        share of households whose resources were topped up to the
%                    floor; with the absorbing floor, the share bankrupt
%     abs_hazard     share going bankrupt among those not yet bankrupt (0
%                    without the absorbing floor)
%     at_c_bound     share consuming at the lower bound of the consumption search
%
%   With the absorbing floor, consumption and income are over all households;
%   everything else (wealth, housing, net income, the equity shares, c_frac,
%   burden) over the households not bankrupt at that age.

N = sim.N; T = p.T;
ages = sim.ages(:).';
Y0 = sim.Y(1, 1);
out = [];                                            % households left out of the solvent statistics
if model.floor_kind(p), out = sim.absorbed; end

hc  = sim.h_cost;
heq = zeros(N, T);
if p.h_mult > 0 && p.is_owner
    % The outstanding balance as a share of the loan's base: the purchase
    % price with the annuity, the current house value with the proportional
    % contract.
    n  = p.N_mort; rm = p.r_m;
    for t = 1:T
        e = t - 1;                                   % years since purchase
        if e < n
            owed = p.LTV * ((1 + rm)^n - (1 + rm)^e) / ((1 + rm)^n - 1);
        else
            owed = 0;
        end
        if strcmp(p.mortgage, 'annuity')
            heq(:, t) = sim.H(:, t) - owed * sim.H(:, 1);
        else
            heq(:, t) = (1 - owed) * sim.H(:, t);
        end
    end
end
net_income = sim.disp_inc + hc;

% Liquid saving and the fund balance on which this period's returns accrue.
kap   = config.kappa_path(p);                        % 1 x T, zero from retirement
X_sav = max(sim.LW - sim.C, 0);
A_pre = sim.A + kap .* sim.Y;
ret   = ages >= p.retirement_age;
A_pre(:, ret) = sim.A(:, ret) - sim.ann_pay(:, ret);
tau_full = [sim.tau_A, zeros(N, 1)];
stock = sim.pi .* X_sav + tau_full .* A_pre;
fin   = X_sav + A_pre;
if ~isempty(out)
    stock(out) = 0; fin(out) = 0;
end

s = struct();
s.ages   = ages;
s.Y0     = Y0;
s.units  = 'EUR 2025';
if strcmp(p.income_source, 'poly'), s.units = 'CGM income units'; end
s.tenure = model.tenure(p);
s.N      = N;

s.C            = stats(sim.C);
s.Y            = stats(sim.Y);
s.net_income   = stats(net_income, out);
s.housing_cost = stats(hc, out);
s.X            = stats(sim.X, out);
s.A            = stats(sim.A, out);
s.H            = stats(sim.H, out);
s.home_equity  = stats(heq, out);
s.net_worth    = stats(sim.X + sim.A + heq, out);
s.ann_pay      = stats(sim.ann_pay, out);

pis = stats(sim.pi, out);
s.pi      = pis.mean;
s.pi_p10  = pis.p10; s.pi_p50 = pis.p50; s.pi_p90 = pis.p90;
cfs = stats(sim.c_frac, out);
s.c_frac  = cfs.mean;
s.dc_share = [config.tau_effective(p).', 0];
s.dc_reit  = [config.reit_effective(p).', 0];
s.equity_share = sum(stock, 1) ./ max(sum(fin, 1), realmin);
burden = hc ./ max(net_income, realmin);
if ~isempty(out), burden(out) = NaN; end
s.burden  = median(burden, 1, 'omitnan');
s.floored = mean(sim.floored, 1);
s.abs_hazard = zeros(1, T);
if ~isempty(out)
    before = [false(N, 1), out(:, 1:end-1)];
    s.abs_hazard = sum(out & ~before, 1) ./ max(sum(~before, 1), 1);
end
s.at_c_bound = mean(~sim.floored & sim.c_frac <= 1.02 * sim.c_bound, 1);
s.bequest = struct('mean', mean(sim.bequest), 'p50', median(sim.bequest));
end

function st = stats(M, out)
% Mean and percentiles by age, leaving out the households marked in out.
if nargin > 1 && ~isempty(out)
    M(out) = NaN;
    mu = mean(M, 1, 'omitnan');
else
    mu = mean(M, 1);
end
q  = prctile(M, [10 50 90], 1);
st = struct('mean', mu, 'p10', q(1, :), 'p50', q(2, :), 'p90', q(3, :));
end
