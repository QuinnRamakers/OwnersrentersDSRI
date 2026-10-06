function p = params()
%PARAMS  Calibration 
%
% 
%   Every euro-denominated input is in 2025 prices.

% Time horizon. age0 = 25 is whereincome data starts; T = 76 keeps
% the terminal age at 100.
p.T              = 76;
p.age0           = 25;
p.retirement_age = 67;      % AOW age
p.sex            = 1;       % INCOME profile only (1=men, 2=women, 3=pooled); mortality is unisex

% Preferences
p.gamma = 5;          % risk aversion (CRRA)
p.beta  = 0.96;       % time discount factor
p.chi   = 0.0;        % bequest intensity: off

% Labour income
%   'table' is the Been et al (2026)
%   (config.income_table_bkv); 'poly' uses Cocco Gomes Maenhoutc.
p.income_source = 'table';
p.income_coef = [0.530339, 0.16818, -0.323371, 0.19704];   % CGM (2005)
p.sigma_l_log = 0.1032;     % CGM (2005) HS-group PERMANENT shock std; pure random walk
p.replacement = 0.307;      % AOW-only first-pillar replacement
p.income_price_factor = 1.3456;   % CPI(2025)/CPI(2015) correction

% Financial market
p.r             = 0.011;   % real risk-free rate
p.mu_S_level    = 0.04;    % equity EXCESS return level (over r_f)
p.sigma_S_level = 0.16;    % equity return vol
% Shock correlations (income L, stock S, housing H)
p.corr_SL       = 0.0;     % corr(stock return, income shock)
p.corr_HL       = 0.0;     % corr(housing return, income shock)
p.corr_SH       = 0.0;     % corr(stock return, housing return)

% Pension parameters
%   Contributions are levied on gross income above a franchise:
%       kappa_t = kappa_base * max(Y_t - F, 0) / Y_t
%   so the effective rate on gross income is age varying.
%   p.kappa is built as vector.. It is calculated based on on the expected
%   income ex ante
p.kappa_base = 0.186;    % contribution rate above the franchise (OECD)
p.franchise  = 18475;    %  AOW-franchise, 1-1-2025 (Belastingdienst CAP)
p.delta     = 0.0;       % legacy

% Housing
p.is_owner      = false;     % flip true for owner scenario
p.alpha         = 0.06;      % rent-to-price ratio (fraction of H_t / period)
p.theta         = 0.015;     % maintenance cost fraction
p.mu_H_level    = 0.027;     % real house-price drift (own return, not excess)
p.sigma_H_level = 0.037;     % house-price return vol
p.h_mult        = 4.0;       % initial housing assignment
p.r_m           = 0.0136;    % real mortgage rate (>= r_f)
p.N_mort        = 30;        % mortgage term (years)
%   LTV not yet used
p.LTV           = 1.00;
p.sell_cost     = 0.025;     % seller transaction cost at bequest

% Rent process (renters only). 
p.mu_R_level    = 0.0097;    % real rent growth, mean
p.sigma_R_level = 0.018;     % real rent growth, vol

% Consumption floor 
p.phi_floor = 1e-6;

% Legacy
p.grid_type = utility.active_grid();

% Grid parameters
p.gh_n = 7;                                  % gh_n^3 joint Gauss-Hermite shock nodes
p.N_u1 = 28; p.N_u2 = 20; p.N_u3 = 20;
p.u1_grid = linspace(0, 1, p.N_u1).';
p.u2_grid = linspace(0, 1, p.N_u2).';
p.u3_grid = linspace(0, 1, p.N_u3).';

% Taxes
%   Contributions are tax free and DC account capital gains, all others are
%   taxed according to these values
p.tau_inc      = 0.382;    % income tax on wages, AOW and annuity payout (CBS, 2019)
p.tau_cg_bond  = 0.36;     %  rate on the private account's bond return
p.tau_cg_stock = 0.36;     %  rate on the private account's stock gains
p.tau_wealth   = 0.0;      % wealth tax private savings

% Derived helpers
p.Rf      = 1 + p.r;
% corrections to log parameters
p.sigma_S = sqrt(log(1 + (p.sigma_S_level / (1 + p.r + p.mu_S_level))^2));
p.mu_S    = log(1 + p.r + p.mu_S_level) - 0.5 * p.sigma_S^2;
% mu_H_level is the house's OWN log return (not excess).
p.sigma_H = sqrt(log(1 + (p.sigma_H_level / (1 + p.mu_H_level))^2));
p.mu_H    = log(1 + p.mu_H_level) - 0.5 * p.sigma_H^2;
% Rent-index growth, same level-to-log conversion as the house.
p.sigma_R = sqrt(log(1 + (p.sigma_R_level / (1 + p.mu_R_level))^2));
p.mu_R    = log(1 + p.mu_R_level) - 0.5 * p.sigma_R^2;
p.t_ret   = p.retirement_age - p.age0 + 1;

% default investment strategy
ages_grid   = (p.age0 : p.age0 + p.T - 2).';
glide       = max(0.0, min(0.8, (p.retirement_age - ages_grid) / 35));
glide(ages_grid >= p.retirement_age) = 0.0;
p.tau_S_raw = glide;
p.tau_S     = glide;

% decumulation strategy for free dc choice (not in this demo)
p.tau_decum = [];

% Create contribution rates
assert(p.LTV == 1.00, 'params:LTV', ...
    'LTV = %.4f: only 1.00 is implemented.', p.LTV);
logY_det       = config.income_profile(p);
Y_det          = exp(logY_det);
p.kappa        = zeros(p.T, 1);
work_t         = 1 : (p.t_ret - 1);
p.kappa(work_t) = p.kappa_base .* max(Y_det(work_t) - p.franchise, 0) ./ Y_det(work_t);

% Approximate mortgage payments
amort_rate     = p.LTV * p.r_m * (1 + p.r_m)^p.N_mort / ((1 + p.r_m)^p.N_mort - 1);
p.m_rate_path  = zeros(p.T - 1, 1);
p.m_rate_path(1 : min(p.N_mort, p.T - 1)) = amort_rate;

end
