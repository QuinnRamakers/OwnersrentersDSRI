function p = params(do_derive)
%PARAMS  Production calibration: the primitive inputs of the model.
%
%   p = config.params()          % primitives plus everything derived from them
%   p = config.params(false)     % primitives only
%
%   Everything set here is an input. What follows from the inputs -- the
%   log-return moments, the retirement period, the DC glide path, the
%   contribution-rate profile, the mortgage schedule and the state grid -- is
%   built by config.derive, which this calls last. To change the calibration,
%   override fields on p and call config.derive(p) again; the calibration
%   ladder (+ladder) does exactly that. Sources are in CALIBRATION.md.
%
%   The model is solved on a cube of normalised coordinates,
%       u1 = Y/W,   u2 = (A+H)/(W-Y),   u3 = A/(A+H),   W = X + A + H + Y,
%   with liquid wealth X, DC pot A, housing (owner) or rent index (renter) H
%   and income Y. Choices: c, the share of liquid resources consumed, and pi,
%   the equity share of liquid saving. The DC fund follows a glide path.
%
%   Euro amounts are in 2025 prices.

% Time
p.T              = 76;        % periods, ages 25-100
p.age0           = 25;        % first age of the BKV income table
p.retirement_age = 67;        % statutory AOW age
p.sex            = 1;         % income profile: 1 men, 2 women, 3 pooled (mortality is unisex)

% Preferences
p.gamma = 5;                  % relative risk aversion
p.beta  = 0.96;               % time discount factor
p.chi   = 0;                  % bequest intensity

% Labour income
p.income_source       = 'table';   % 'table': BKV age effects in euros; 'poly': CGM cubic, not in euros
p.income_coef         = [0.530339, 0.16818, -0.323371, 0.19704];   % CGM (2005) high-school cubic, 'poly' only
p.sigma_l_log         = 0.1032;    % permanent income shock std; log income is a random walk
p.replacement         = 0.307;     % first-pillar (AOW) income as a share of final wage
p.income_price_factor = 1.3456;    % CPI(2025)/CPI(2015), rescales the BKV euro anchor

% Financial market
p.r             = 0.011;      % real risk-free rate
p.mu_S_level    = 0.04;       % equity excess return
p.sigma_S_level = 0.16;       % equity return volatility
p.corr_SL       = 0;          % corr(stock return, income shock)
p.corr_HL       = 0;          % corr(H growth, income shock)
p.corr_SH       = 0;          % corr(stock return, H growth)

% DC pension
p.kappa_base = 0.186;         % contribution rate on income above the franchise; 0 removes the DC pillar
p.franchise  = 18475;         % AOW franchise, euros
p.glide_cap  = 0.8;           % fund equity share far from retirement
p.glide_span = 35;            % fund equity share = min(glide_cap, years to retirement / glide_span)
p.tau_decum  = [];            % fund equity share in retirement; [] keeps the glide's zero

% REIT leg of the DC fund. A zero share and zero correlations remove the fourth shock.
p.tau_REIT         = 0;       % REIT share of the fund, scalar or T-1 path
p.reit_decum       = [];      % REIT share in retirement; [] keeps tau_REIT
p.mu_REIT_level    = 0.03;    % REIT excess return (placeholder)
p.sigma_REIT_level = 0.12;    % REIT return volatility (placeholder)
p.corr_RL          = 0;       % corr(REIT return, income shock)
p.corr_RS          = 0;       % corr(REIT return, stock return)
p.corr_RH          = 0;       % corr(REIT return, H growth)

% Housing. Renters pay alpha*H on a rent index H; owners pay (theta + mortgage)*H.
p.is_owner      = false;      % tenure
p.h_mult        = 4.0;        % H at entry as a multiple of income (placeholder); 0 removes housing
p.alpha         = 0.06;       % rent as a share of the rent index
p.theta         = 0.015;      % owner maintenance, share of H
p.mu_H_level    = 0.027;      % real house-price growth
p.sigma_H_level = 0.037;      % house-price volatility
p.mu_R_level    = 0.0097;     % real rent growth (the renter's H)
p.sigma_R_level = 0.018;      % rent growth volatility
p.r_m           = 0.0136;     % real mortgage rate
p.N_mort        = 30;         % mortgage term, years
p.LTV           = 1.00;       % only 1.00 is implemented
p.sell_cost     = 0.025;      % sale cost when the house is bequeathed

% Taxes. EET on the DC pillar; box 3 on the liquid account only.
p.tau_inc        = 0.382;     % income tax on wages, AOW and annuity payouts
p.tau_cg_bond    = 0.36;      % tax on the liquid account's bond return
p.tau_cg_stock   = 0.36;      % tax on the liquid account's stock gains
p.cg_loss_offset = false;     % true rebates stock losses at the same rate
p.tau_wealth     = 0;         % alternative box-3 levy on the liquid balance

% Consumption floor and search guard
p.phi_floor    = 1e-6;        % resources guaranteed each period, share of current gross income
p.c_floor_frac = 0.01;        % lower bound of the consumption search, share of W

% Entry state: liquid wealth at 25 in years of income
p.b0    = 3400 / (33000 * 1.3031);   % median deposits under 25 over the age-25 wage
p.b_alt = 9800 / (33000 * 1.3031);   % same for ages 25-35

% Numerics
p.grid_dims     = [20 20 12]; % base nodes on (u1, u2, u3); the entry anchors add up to two on u1 and u2
p.gh_n          = 5;          % Gauss-Hermite nodes per shock
p.gh_n_reit     = [];         % nodes for the REIT shock; [] uses gh_n
p.N_c           = 41;         % sets the consumption step of the per-node search
p.N_pi          = 41;         % sets the equity-share step of the per-node search
p.use_refine    = true;       % global (c, pi) sweep before fmincon at every node
p.interp_method = 'linear';   % continuation interpolant: 'linear', 'makima' or 'spline'
p.lambda_lo     = 0.0008;     % bottom of the u1 axis
p.lambda_hi     = [];         % top of the u1 axis; [] = min(0.9, 3/(1+h_mult)), or 1 without housing
p.grid_pow      = 1;          % > 1 bunches u1 nodes toward the bottom
p.grid_pow_u2   = 1;          % > 1 bunches u2 nodes toward 1
p.u2_lo         = 0;          % bottom of the u2 axis
p.u3_lo         = 0;          % bottom of the u3 axis
p.u3_hi         = 1;          % top of the u3 axis
p.grid_nodes    = [];         % explicit axis nodes, overriding the rules above

if nargin < 1 || do_derive
    p = config.derive(p);
end
end
