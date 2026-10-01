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
%     housing_cost, X (liquid), A (DC pot), H, home_equity (owner: house net of
%     the outstanding mortgage; otherwise 0), net_worth = X + A + home_equity,
%     ann_pay (gross annuity payout)
%   Shares, 1 x T:
%     pi             mean liquid equity share (also pi_p10, pi_p50, pi_p90)
%     c_frac         mean share of liquid resources consumed
%     dc_share       the fund's equity share (the glide; 0 in the last period)
%     equity_share   stocks in the liquid account and the fund over their sum,
%                    aggregated across households
%     burden         median housing cost over net income
%     floored        share of households whose resources were topped up to the floor
%     at_c_bound     share consuming at the lower bound of the consumption search

N = sim.N; T = p.T;
ages = sim.ages(:).';
Y0 = sim.Y(1, 1);

hc  = zeros(N, T);
heq = zeros(N, T);
if p.h_mult > 0
    if p.is_owner
        n  = p.N_mort; rm = p.r_m;
        for t = 1:T
            m_rate = 0;
            if t <= numel(p.m_rate_path), m_rate = p.m_rate_path(t); end
            hc(:, t) = (p.theta + m_rate) * sim.H(:, t);
            e = t - 1;                                   % years since purchase
            if e < n
                owed = p.LTV * ((1 + rm)^n - (1 + rm)^e) / ((1 + rm)^n - 1);
            else
                owed = 0;
            end
            heq(:, t) = (1 - owed) * sim.H(:, t);
        end
    else
        hc = p.alpha * sim.H;
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

s = struct();
s.ages   = ages;
s.Y0     = Y0;
s.units  = 'EUR 2025';
if strcmp(p.income_source, 'poly'), s.units = 'CGM income units'; end
s.tenure = model.tenure(p);
s.N      = N;

s.C            = stats(sim.C);
s.Y            = stats(sim.Y);
s.net_income   = stats(net_income);
s.housing_cost = stats(hc);
s.X            = stats(sim.X);
s.A            = stats(sim.A);
s.H            = stats(sim.H);
s.home_equity  = stats(heq);
s.net_worth    = stats(sim.X + sim.A + heq);
s.ann_pay      = stats(sim.ann_pay);

q = prctile(sim.pi, [10 50 90], 1);
s.pi      = mean(sim.pi, 1);
s.pi_p10  = q(1, :); s.pi_p50 = q(2, :); s.pi_p90 = q(3, :);
s.c_frac  = mean(sim.c_frac, 1);
s.dc_share = [config.tau_effective(p).', 0];
s.equity_share = sum(stock, 1) ./ max(sum(fin, 1), realmin);
s.burden  = median(hc ./ max(net_income, realmin), 1);
s.floored = mean(sim.floored, 1);
s.at_c_bound = mean(~sim.floored & sim.c_frac <= 1.02 * sim.c_bound, 1);
s.bequest = struct('mean', mean(sim.bequest), 'p50', median(sim.bequest));
end

function st = stats(M)
q  = prctile(M, [10 50 90], 1);
st = struct('mean', mean(M, 1), 'p10', q(1, :), 'p50', q(2, :), 'p90', q(3, :));
end
