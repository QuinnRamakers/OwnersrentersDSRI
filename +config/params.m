function p = params()
%PARAMS  Calibration for the CGM life-cycle model with DC pension and housing.
%
%   State (lambda, s_A, s_H) with:
%     W      = X + A + H + Y         (total wealth incl. income, always > 0)
%     lambda = Y / W                       in [0, 1]
%     s_A    = A / W                       in [0, 1]   (DC pension share)
%     s_H    = H / W                       in [0, 1]   (housing share)
%     s_X    = X / W = 1 - lambda - s_A - s_H          (liquid wealth share)
%   Feasibility: lambda + s_A + s_H <= 1.
%
%   Choices: (c, pi)   c  = consumption fraction of liquid wealth
%                      pi = equity share of saved liquid wealth
%   Pension equity share tau_S is a (pre-determined) glide path.
%
%   Two scenarios via p.is_owner:
%     Renter (false): pays alpha * H_t per period; bequest base = X.
%     Owner  (true ): pays (theta + m_rate_t) * H_t per period; bequest = X + H.
%   (DC pension is never bequeathable -- standard CGM convention.)

% Time horizon
p.T              = 81;
p.age0           = 20;
p.retirement_age = 65;
p.sex            = 3;

% Preferences
p.gamma = 10;
p.beta  = 0.96;
p.chi   = 0.0;

% Labour income
p.sigma_l_log = 0.07380;
p.replacement = 0.35;       % AOW-only first-pillar replacement (Dutch)
p.income_coef = [-1.3672, 0.1046, -0.1905, 0.1165];

% Financial market
p.r             = 0.04;
p.mu_S_level    = 0.06;
p.sigma_S_level = 0.157;
p.corr_SL       = 0.0;

% Pension parameters
%   kappa targets total replacement of ~0.75 * Y_64 combined with AOW (0.35).
p.kappa     = 0.05;
p.delta     = 0.0;
% tau_S is a glide-path lifecycle fund: linear from 0.8 equity at age 30 down
% to 0.0 at retirement, 0.0 thereafter. (Vector built below, after t_ret.)

% Housing
p.is_owner      = false;     % flip true for owner scenario
p.alpha         = 0.06;      % rent rate (fraction of H_t / period)
p.theta         = 0.025;     % maintenance rate (fraction of H_t / period)
p.mu_H_level    = 0.01;      % real housing price drift (per period)
p.sigma_H_level = 0.10;      % housing price log-vol
p.h_mult        = 4.0;       % H_0 = h_mult * Y_0
p.r_m           = 0.05;      % mortgage rate (>= r_f)
p.N_mort        = 30;        % mortgage term (years)

% Numerical: 3D state grid (lambda, s_A, s_H) on the simplex lambda+s_A+s_H<=1.
% gh_n^3 = 343 joint Gauss-Hermite shock nodes per state.
p.gh_n     = 7;
p.N_lambda = 40;
p.N_sA     = 40;
p.N_sH     = 40;
p.lambda_grid = linspace(0, 1, p.N_lambda).';
p.sA_grid     = linspace(0, 1, p.N_sA).';
p.sH_grid     = linspace(0, 1, p.N_sH).';

% Inner (choice) grid that seeds the per-state fmincon polish in bellman_step.
%   N_c  : consumption-fraction grid. Must stay fine -- the objective is
%          multimodal in c, and a coarse grid seeds the wrong basin.
%   N_pi : equity-share grid. Keep at 41 for production; the objective is
%          flat in pi near the optimum, so coarsening biases the equity-share
%          policy low and noisy even though the value function barely moves.
p.N_c  = 41;
p.N_pi = 41;

% Taxes
%   Income tax (EET pension treatment): DC contributions kappa*Y are pre-tax
%   (deductible), the DC fund grows tax-free, and BOTH the annuity payout and
%   the first-pillar AOW are taxed as income on receipt. Working take-home is
%   therefore (1-kappa)*(1-tau_inc)*Y. The deferral + sheltering is what gives
%   the DC account a positive welfare value (without taxes the DC fund's only
%   edge is the mortality credit, which does not outweigh its illiquidity).
p.tau_inc      = 0.30;
%   Capital-gains tax on the LIQUID (taxable) account only -- the DC fund is
%   sheltered. Accrual basis, NO loss offset: only positive gains are taxed
%   (no credit when equity falls). Split by asset so bonds and stocks can be
%   taxed at different rates; both default to 0.25.
p.tau_cg_bond  = 0.25;
p.tau_cg_stock = 0.25;

% Derived
p.Rf      = 1 + p.r;
p.sigma_S = sqrt(log(1 + (p.sigma_S_level / (1 + p.mu_S_level))^2));
p.mu_S    = log(1 + p.mu_S_level) - 0.5 * p.sigma_S^2;
p.sigma_H = sqrt(log(1 + (p.sigma_H_level / (1 + p.mu_H_level))^2));
p.mu_H    = log(1 + p.mu_H_level) - 0.5 * p.sigma_H^2;
p.t_ret   = p.retirement_age - p.age0 + 1;

% Pension glide path tau_S: 0.8 at age 30 (t=11), linear ramp to 0.0 at
% retirement (t_ret), 0.0 thereafter. Length T-1 (transitions).
ages_grid   = (p.age0 : p.age0 + p.T - 2).';
glide       = max(0.0, min(0.8, (p.retirement_age - ages_grid) / 35));
glide(ages_grid >= p.retirement_age) = 0.0;
p.tau_S_raw = glide;
p.tau_S     = glide;

% Mortgage amortisation rate (homothetic approximation -- applied as a rate
% on current H_t for years 1..N_mort, zero thereafter).
amort_rate     = p.r_m * (1 + p.r_m)^p.N_mort / ((1 + p.r_m)^p.N_mort - 1);
p.m_rate_path  = zeros(p.T - 1, 1);
p.m_rate_path(1 : min(p.N_mort, p.T - 1)) = amort_rate;

end
