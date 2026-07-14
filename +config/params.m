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
%   age0 = 25: model starts exactly where the BKV(2026) income table starts
%   (age 24 is the omitted reference age, age 25 the first non-baseline
%   estimate), so the working-age income path needs no below-sample
%   extrapolation. T shortened to 76 to keep the terminal modeled age at
%   100 (unchanged) despite the later start.
p.T              = 76;
p.age0           = 25;
p.retirement_age = 67;      % statutory AOW eligibility age, calibration slide deck (2026-07)
p.sex            = 3;

% Preferences
p.gamma = 5;         % risk aversion: confirmed by calibration slide deck (2026-07)
p.beta  = 0.96;       % discount rate -- TBD (moment matching or literature), calibration slide deck (2026-07); unsourced placeholder
p.chi   = 0.0;        % bequest intensity -- TBD, calibration slide deck (2026-07); unsourced placeholder

% Labour income
%   income_source: 'table' uses the direct Been-Knoef-Vethaak (2026)
%   lookup (config.income_table_bkv, see income_profile.m) -- Dutch,
%   selection-corrected, no fitting. 'poly' falls back to the CGM (2005)
%   cubic below. income_coef is kept either way so p.income_source can
%   be flipped for comparison without touching anything else.
p.income_source = 'table';
%   income_coef: Cocco-Gomes-Maenhout (2005, RFS) high-school-education
%   group, third-order-in-age log-income profile. Source: a=-2.170042+
%   2.700381, b1=0.16818, b2=-0.0323371/10, b3=0.0019704/100 (age in
%   levels, ages 21-65), taken from a public MATLAB replication of CGM's
%   Figure 2 (R. Jappelli, https://github.com/ruggerojapp/
%   CGM-2005-RFS-Matlab-Octave, itself built off F. Gomes' original
%   FORTRAN). Rescaled here to this file's age^2/100, age^3/1e4
%   convention: a3 = b2*100, a4 = b3*1e4. Placeholder pending the LISS
%   Heckman-corrected age-cubic regression (TODO.md, Tier A) -- flags:
%   (1) US data, hump-shaped; some evidence Continental-Europe age-income
%   profiles are closer to monotonically increasing rather than
%   hump-shaped, so the qualitative shape itself is a live calibration
%   question, not just the levels. (2) Peak age ~43 here.
p.income_coef = [0.530339, 0.16818, -0.323371, 0.19704];
%   sigma_l_log: CGM (2005) HS-group shock std, PERMANENT component only.
%   CGM decompose income risk into a permanent (random-walk) shock,
%   variance 0.01065 (std 0.1032), and a transitory (iid, non-compounding)
%   shock, variance 0.0738 (std 0.2717). This model's income process,
%   Y_{t+1} = Y_t * exp(mu_g + sigma_l_log*eps), is a pure random walk --
%   any shock here compounds forward permanently -- so the CGM-consistent
%   choice is the PERMANENT std (0.1032), not the transitory one. The
%   previous placeholder (0.0738) was the transitory VARIANCE reused
%   directly as a std, conflating both the wrong component and the wrong
%   units; corrected here. Transitory risk is not represented in this
%   single-composite-shock structure (see TODO.md, "Code <-> paper
%   audit") -- a known simplification, not fixed by this change.
p.sigma_l_log = 0.1032;
p.replacement = 0.307;      % AOW-only first-pillar replacement: median replacement rate (DNB), calibration slide deck (2026-07)

% Financial market
%   r: real risk-free rate, MK estimate (mean 3-month bond interest rate
%   minus inflation), calibration slide deck (2026-07). Was 0.04
%   (unsourced placeholder); the whole rate block below (r, mu_S_level,
%   r_m) is now consistently REAL (inflation-adjusted), not nominal.
p.r             = 0.011;
p.mu_S_level    = 0.04;    % equity EXCESS return level (over r_f); MK convention, see appendix (calibration slide deck, 2026-07)
p.sigma_S_level = 0.16;    % equity return vol; MK convention, see appendix (calibration slide deck, 2026-07 -- slide notation "sigma_S=sqrt(16)%" read as vol=16%, per user; close to old 15.7% placeholder)
% Shock correlation structure (income L, stock S, housing H). Each pairwise
% corr represents the covariance of a single COMPOSITE income shock -- the
% model has no aggregate/idiosyncratic income split, so corr_SL/corr_HL
% conflate both channels into one number (see TODO.md, "Code <-> paper
% audit"). Values TBD: calibration slide deck (2026-07) specifies the
% approach (LISS individual income/house growth x aggregate return series)
% but not numbers yet; default to 0 (independent) until that lands.
p.corr_SL       = 0.0;     % corr(stock return, income shock)
p.corr_HL       = 0.0;     % corr(housing return, income shock)
p.corr_SH       = 0.0;     % corr(stock return, housing return)

% Pension parameters
%   kappa (DC contribution rate) targets total replacement of ~0.75 * Y_64
%   combined with AOW. User-set 2026-07-14 (slide deck left this TBD).
p.kappa     = 0.2;
p.delta     = 0.0;
% tau_S is a glide-path lifecycle fund: linear from 0.8 equity at age 30 down
% to 0.0 at retirement, 0.0 thereafter. (Vector built below, after t_ret.)

% Housing
p.is_owner      = false;     % flip true for owner scenario
p.alpha         = 0.1;       % rent rate (fraction of H_t / period): user-set 2026-07-14, slide deck left this TBD
p.theta         = 0.015;     % maintenance rate: COELO Atlas of Local Government Taxes, MK, calibration slide deck (2026-07) gave 1.5%/1.6%; 1.5% chosen
p.mu_H_level    = 0.027;     % real housing price drift: BIS Real Residential Property Price Index, MK, calibration slide deck (2026-07)
p.sigma_H_level = 0.037;     % housing price log-vol: BIS Real Residential Property Price Index, MK, calibration slide deck (2026-07)
p.h_mult        = 4.0;       % H_0 = h_mult * Y_0 -- house-price-to-income at purchase, TBD, calibration slide deck (2026-07)
p.r_m           = 0.013;     % real mortgage rate (>= r_f): ECB MIR series, nominal 3.6% less inflation 2.3%, calibration slide deck (2026-07)
p.N_mort        = 30;        % mortgage term (years) -- convention, confirmed by calibration slide deck (2026-07)

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

% Alternative cube state grid (lambda, n-tilde, a) -- see solver.bellman_step_lna:
%   u1 = lambda, u2 = (A+H)/(W-Y), u3 = A/(A+H). Every point of [0,1]^3 is
%   feasible (the simplex grid above wastes ~82% of its cube on infeasible
%   points), so 28x20x20 = 11,200 states matches the 40^3 grid's 11,480
%   feasible points at ~5.7x less memory. lambda is empirically the steepest
%   policy axis (mean |finite-diff slope| of c/pi is 1.5-2x that of s_A/s_H),
%   hence the upweighted u1 resolution. Selected via CGM_GRID=lna in
%   run_combined; the simplex grid stays the production default.
p.N_u1 = 28; p.N_u2 = 20; p.N_u3 = 20;
p.u1_grid = linspace(0, 1, p.N_u1).';
p.u2_grid = linspace(0, 1, p.N_u2).';
p.u3_grid = linspace(0, 1, p.N_u3).';
% skip_polish = true skips the lna solver's fmincon polish (grid-search
% only). Measured at coarse grids the polish adds only ~15% runtime (the
% 343x41x41 grid-search tensor dominates), so full fidelity is the default.
p.skip_polish = false;

% Taxes
%   Income tax (EET pension treatment): DC contributions kappa*Y are pre-tax
%   (deductible), the DC fund grows tax-free, and BOTH the annuity payout and
%   the first-pillar AOW are taxed as income on receipt. Working take-home is
%   therefore (1-kappa)*(1-tau_inc)*Y. The deferral + sheltering is what gives
%   the DC account a positive welfare value (without taxes the DC fund's only
%   edge is the mortality credit, which does not outweigh its illiquidity).
%   Still TBD per calibration slide deck (2026-07) -- open question is
%   whether to target LISS gross or net income; value below is an
%   unsourced placeholder pending a real number.
p.tau_inc      = 0.30;
%   Capital-gains tax on the LIQUID (taxable) account only -- the DC fund is
%   sheltered. Accrual basis, NO loss offset: only positive gains are taxed
%   (no credit when equity falls). Split by asset so bonds and stocks can be
%   taxed at different rates. Set to 0 for now -- Dutch box 3 (wealth tax,
%   not a true capital-gains tax) is under active legislative change and
%   difficult to map cleanly onto this accrual-CGT structure; calibration
%   slide deck (2026-07) punts to 0 pending a resolution.
p.tau_cg_bond  = 0.0;
p.tau_cg_stock = 0.0;

% Derived
p.Rf      = 1 + p.r;
% mu_S_level is the EXCESS return level (over r_f): ln(R_S) = ln(R_f) + mu_S + eps.
% Total expected gross level return is (1 + r + mu_S_level).
p.sigma_S = sqrt(log(1 + (p.sigma_S_level / (1 + p.r + p.mu_S_level))^2));
p.mu_S    = log(1 + p.r + p.mu_S_level) - 0.5 * p.sigma_S^2;
% mu_H_level is the house's OWN log return (not excess) -- unchanged.
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
