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
p.retirement_age = 67;      % statutory AOW eligibility age (2026), calibration table
% p.sex now drives the INCOME profile only (1=men, 2=women, 3=pooled).
% Mortality is unisex from 2026-07 onward: config.survival reads the CBS
% "totaal mannen en vrouwen" life table, which has no sex dimension.
% Calibration table specifies Been-Knoef-Vethaak Table D.1, MEN -> p.sex = 1.
p.sex            = 1;

% Preferences
p.gamma = 5;         % risk aversion (CRRA): Cocco, Gomes & Maenhout (2005), calibration table
p.beta  = 0.96;       % time discount factor: Larsen et al. (2023), calibration table
p.chi   = 0.0;        % bequest intensity: switched off in the baseline (calibration table)

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
p.replacement = 0.307;      % AOW-only first-pillar replacement: DNB "Toereikendheid van pensioenen" Table 3, median first-pillar replacement rate
%   PRICE-YEAR CONVENTION: every euro-denominated input in this file is in
%   2025 EUROS. 2025 is the most recent COMPLETE calendar year -- its CBS
%   annual CPI is final and its statutory pension amounts are settled --
%   whereas any 2026 figure rests on a part-year CPI average that CBS will
%   revise. Only two inputs actually carry a price year (this factor and
%   p.franchise); b0/b_alt are a ratio of same-year euros and so are
%   price-level-free (see below), and every rate in the file (r, r_m,
%   mu_H_level, tau_inc, ...) is real or unit-free and therefore has no
%   price year at all. Change the two together or not at all: pairing a
%   rescaled income with a franchise from another year silently misstates
%   kappa_t at every age.
%
%   income_price_factor: CPI rescaling of the Been-Knoef-Vethaak euro anchor
%   (config.income_profile, EUR 33k men / 30k women at age 25, the paper's
%   Section 3.2.3 / Figure 4 descriptives) to 2025 prices. BKV express all
%   wages in 2015 euros (Section 3.1: "full-time equivalent (before tax)
%   wage expressed in (log) 2015 euros"), so the factor is CPI(2025)/CPI(2015)
%   = 134.56 / 100.00 = 1.3456, straight off CBS 83131NED (CPI 2015=100,
%   annual figures, series closed at 2025 when CBS rebased to 2025=100).
%   Single-table, single-step, final -- no chaining through the successor
%   table 86141NED and no provisional part-year average.
%   This factor ONLY matters because the contribution rate is franchise-based
%   (kappa_t below); everything else in the model is scale-free.
p.income_price_factor = 1.3456;

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
%   DC contributions are levied on gross income ABOVE a franchise (the AOW
%   offset), per the calibration table:
%       kappa_t = kappa_base * max(Y_t - F, 0) / Y_t
%   so the EFFECTIVE contribution rate on gross income rises with income and
%   is therefore an AGE PROFILE, not a scalar. p.kappa is built below (after
%   t_ret / the income profile are available) as a T x 1 vector; solver and
%   simulator index it as p.kappa(min(t, numel(p.kappa))), which keeps
%   legacy scalar-kappa p-structs (and p.kappa = 0 overrides in run_nodc /
%   run_dc_strategies) working unchanged.
%
%   IMPORTANT APPROXIMATION: kappa_t is evaluated on the DETERMINISTIC income
%   profile, not on each household's realised Y_t. The model is homothetic in
%   W (only lambda = Y/W is a state, the euro level of Y is not), so a
%   contribution rate that depended on realised Y would break the normalised
%   state space entirely. The calibration table itself specifies kappa_t as an
%   "age profile", which is exactly this object.
p.kappa_base = 0.186;    % contribution rate above the franchise: OECD Pensions at a Glance (2022 country note; 2025 Table 3.4)
%   franchise: minimum AOW-franchise (art. 18a lid 3 Wet LB) per 1-1-2025,
%   EUR 18,475: Belastingdienst Centraal Aanspreekpunt Pensioenen, "Overzicht
%   AOW-inbouwbedragen en AOW-franchises". 2025 to match the 2025-euro income
%   anchor above, per the price-year convention. (The 2026 figure on the same
%   page is EUR 19,172; use it only together with a 2026 income factor.)
p.franchise  = 18475;
%   p.delta is NOT the calibration table's delta. The table's delta (0.382,
%   average income tax rate) is this file's p.tau_inc, in the Taxes block
%   below. p.delta is a separate legacy proportional wedge on gross income
%   ((1-delta) multiplies Y in the budget constraint everywhere) and stays 0.
p.delta     = 0.0;
% tau_S is a glide-path lifecycle fund: linear from 0.8 equity at age 30 down
% to 0.0 at retirement, 0.0 thereafter. (Vector built below, after t_ret.)
% Free DC investment choice: when choose_tau_S is true, the DC equity share
% tau becomes a THIRD choice variable (c, pi, tau) in solver.bellman_step
% (simplex solver only -- bellman_step_lna asserts against it). The annuity
% is still priced off the plan's tau_S glide path (provider convention).
% N_tau sizes the tau seed grid for the grid search (the glide value is
% appended so the free search always contains the glide slice).
p.choose_tau_S = false;
p.N_tau        = 11;

% Housing
p.is_owner      = false;     % flip true for owner scenario
p.alpha         = 0.06;      % rent-to-price ratio (fraction of H_t / period): Yao & Zhang (2005), calibration table
p.theta         = 0.015;     % maintenance cost fraction: Yao & Zhang (2005); Nibud (1% maintenance) plus taxes
p.mu_H_level    = 0.027;     % real house-price drift: BIS Real Residential Property Price Index (NL), CPI-deflated
p.sigma_H_level = 0.037;     % house-price return vol: BIS Real Residential Property Price Index (NL), CPI-deflated
p.h_mult        = 4.0;       % b_H: H_0 = h_mult * Y_0 -- placeholder, to be replaced by the binding Nibud loan-to-income norm
p.r_m           = 0.0136;    % real mortgage rate (>= r_f): ECB MIR, NL cost of borrowing for house purchase, May 2026 (3.66 - 2.3)
p.N_mort        = 30;        % mortgage term (years): standard Dutch annuity mortgage term
%   LTV: loan-to-value at purchase. Only 1.00 is currently CONSISTENT with the
%   rest of the model -- the household is endowed with the house outright at
%   t=1 (X_0 = 0, H_0 = h_mult*Y_0) and services a mortgage on its full value,
%   i.e. a 100% loan. LTV < 1 would additionally require modelling the down
%   payment (a negative initial X), which is not implemented, so the assert
%   below fails loudly rather than silently producing a half-calibrated run.
%   The field is wired into the amortisation rate so the mortgage payment
%   scales with the borrowed fraction once that endowment is added.
p.LTV           = 1.00;
%   Seller transaction cost charged on the house when it is BEQUEATHED (the
%   estate sells): the bequest base becomes X + (1 - sell_cost)*H for owners.
%   Hambel et al. (2026). Inert in the baseline, where chi = 0.
p.sell_cost     = 0.025;

% Numerical: 3D state grid (lambda, s_A, s_H) on the simplex lambda+s_A+s_H<=1.
% gh_n^3 = 343 joint Gauss-Hermite shock nodes per state.
p.gh_n     = 7;
p.N_lambda = 40;
p.N_sA     = 40;
p.N_sH     = 40;
p.lambda_grid = linspace(0, 1, p.N_lambda).';
p.sA_grid     = linspace(0, 1, p.N_sA).';
p.sH_grid     = linspace(0, 1, p.N_sH).';

% Calibrated initial liquid buffer (welfare anchor), in YEARS of the model's
% own age-25 gross income.
% b0 = median bank & savings deposits, households with main earner < 25
%      (CBS StatLine 83834NED, component 1.1.1 "bank- en spaartegoeden",
%      mediaan, stock 1-1-2024, the latest published year: EUR 3,400)
%      / the MEN's BKV age-25 full-time wage in 2024 euros
%      (EUR 33,000 in 2015 prices x CPI 2015->2024 = 130.31/100 = 1.3031,
%      CBS 83131NED, = EUR 43,002).
% b_alt = same with the 25-35 median deposits cell (EUR 9,800), upper
%      sensitivity.
% Euro-year consistency: numerator and denominator are BOTH in 2024 euros, so
% the ratio is PRICE-LEVEL-FREE and needs no rebasing when the file's price
% year moves. Restating both sides in 2025 euros gives the same number --
% 3,400 * (134.56/130.31) / (33,000 * 1.3456) = 3,510.9 / 44,404.8 = 0.0791 --
% which is why b0/b_alt are exempt from the price-year convention above.
% 1-1-2024 is the latest deposits stock CBS publishes (checked 2026-08-04);
% a 2025 stock would replace the numerator, not merely reprice it.
% (Dividing the 2024-euro deposits by a 2025- or 2026-euro wage, i.e. by
% 33,000 * income_price_factor, would UNDERSTATE the buffer by ~3-5%.)
% Was 3400/(31500*1.303) = 0.0828 and 9800/(31500*1.303) = 0.2388: the old
% denominator used the POOLED men/women wage while production runs the men's
% profile (p.sex = 1) -- the buffer is measured in years of the modeled
% agent's income, so the men's wage is the consistent denominator.
% config.insert_anchor_nodes (called at the end of this file) puts the
% corresponding (lambda, s_H) coordinates onto the grids as EXACT nodes, so
% the welfare read at t=1 is a solved value rather than a trilinear blend.
p.b0    = 3400 / (33000 * 1.3031);    % = 0.0791 years of entry income
p.b_alt = 9800 / (33000 * 1.3031);    % = 0.2279

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
%   whether to target LISS gross or net income. This field IS the calibration
%   table's delta ("average income tax rate"); do not confuse it with the
%   code's p.delta, which is a separate wedge fixed at 0.
p.tau_inc      = 0.382;    % CBS, average tax burden on income, 2019
%   DECISION 2026-08-04: KEEP BOTH tax instruments (accrual CGT below and the
%   box-3-style wealth tax further down) wired into the model. They are not
%   alternatives to be collapsed into one: the proposed Dutch box-3 successor
%   is return-based with loss carry-forward (a CGT), while the current regime
%   is a deemed-return levy on the balance (a wealth tax), and a court ruling
%   lets taxpayers already elect realised returns when those are lower. Only
%   the wealth-tax LEG is calibrated (tau_wealth = 0.0197); the CGT legs stay
%   at 0 pending a rate, so today the liquid account's tax disadvantage runs
%   entirely through tau_wealth plus the EET treatment above. Keeping the CGT
%   fields live means switching regimes later is a calibration change, not a
%   code change.
%
%   Capital-gains tax on the LIQUID (taxable) account only -- the DC fund is
%   sheltered. Accrual basis, NO loss offset: only positive gains are taxed
%   (no credit when equity falls). Split by asset so bonds and stocks can be
%   taxed at different rates. Set to 0 for now -- Dutch box 3 (wealth tax,
%   not a true capital-gains tax) is under active legislative change and
%   difficult to map cleanly onto this accrual-CGT structure; calibration
%   slide deck (2026-07) punts to 0 pending a resolution.
p.tau_cg_bond  = 0.0;
p.tau_cg_stock = 0.0;
%   Box-3-style WEALTH tax on the LIQUID (taxable) account only, levied on
%   the end-of-period balance: the bond and stock after-CGT return factors
%   are scaled by (1 - tau_wealth) in the solver and simulator. Housing and
%   the DC fund are exempt. User-set 2026-07-16 (deemed-return box-3 proxy).
%
%   SET TO 0 (2026-08-04, user decision, "for now"). At the calibrated
%   0.0197 the liquid account's safe return was
%       (1 + r(1 - tau_cg_bond))(1 - tau_wealth) = 1.011 * 0.9803 - 1 = -0.892%
%   i.e. NEGATIVE in real terms, against +1.100% for the same asset inside
%   the sheltered DC fund -- a 1.99pp/yr wedge on the safe leg (2.07pp on
%   equity), compounding to 2.31x over the 42 working years. With tau_cg_bond
%   and tau_cg_stock both still 0, tau_wealth WAS the liquid account's entire
%   tax disadvantage. It drove the no-DC benchmark to hoard ~9x peak income
%   and consume ~26% of net income at 25, which in turn inflated the DC-vs-
%   no-DC CEV to ~+319% (renter) / ~+82% (owner) at the b=1 anchor.
%   Restore by putting 0.0197 back here; nothing else needs to change.
p.tau_wealth   = 0.0;      % was 0.0197 (box-3 deemed-return proxy)

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

% DECUMULATION strategy: the DC equity share held from t_ret onward. Free
% investment choice (p.choose_tau_S) is an ACCUMULATION-phase feature -- the
% solver never re-picks tau after retirement, in either regime -- so this is
% the single knob controlling the retired fund, and config.tau_effective
% splices it onto the glide above.
%
% [] (default) keeps the glide's own retirement values, which are 0: an
% all-bond decumulation fund. Set a scalar for a constant share, or a vector
% for a path (see config.tau_effective for the accepted lengths), e.g.
%     p.tau_decum = 0.3;                       % constant 30% equity
%     p.tau_decum = linspace(0.3, 0, p.T - p.t_ret);   % taper to zero
%
% Whatever is set here is PRICED: pension.annuity_price reads the same
% effective path, so the annuity and the portfolio can never disagree. a_t
% falls as the share rises (a higher-return fund sustains a bigger level
% payout), so this materially moves the retired budget -- 0.3 buys a ~12%
% bigger payout per unit of stock than 0. It is in the fingerprint gate.
p.tau_decum = [];

% Effective DC contribution rate on GROSS income, kappa_t (T x 1). Built from
% the franchise rule kappa_t = kappa_base * max(Y_t - F, 0) / Y_t evaluated on
% the DETERMINISTIC income profile (see the Pension block above), and zero
% from retirement on (contributions stop; the solver/simulator branch on
% is_retired anyway, so the zeros are belt-and-braces).
assert(p.LTV == 1.00, 'params:LTV', ...
    ['LTV = %.4f: only 1.00 is implemented. LTV < 1 needs a down-payment ' ...
     'endowment (negative initial X) that the simulator does not model.'], p.LTV);
logY_det       = config.income_profile(p);
Y_det          = exp(logY_det);
p.kappa        = zeros(p.T, 1);
work_t         = 1 : (p.t_ret - 1);
p.kappa(work_t) = p.kappa_base .* max(Y_det(work_t) - p.franchise, 0) ./ Y_det(work_t);

% Mortgage amortisation rate (homothetic approximation -- applied as a rate
% on current H_t for years 1..N_mort, zero thereafter). Scaled by LTV: the
% annuity payment is on the BORROWED fraction of the house value.
amort_rate     = p.LTV * p.r_m * (1 + p.r_m)^p.N_mort / ((1 + p.r_m)^p.N_mort - 1);
p.m_rate_path  = zeros(p.T - 1, 1);
p.m_rate_path(1 : min(p.N_mort, p.T - 1)) = amort_rate;

% Put the calibrated welfare anchors (b0, b_alt) on the lambda / s_H grids as
% exact nodes. Last, because it depends on h_mult, b0, b_alt and the grid
% vectors all being set. Any script that REBUILDS the grids after this must
% call config.insert_anchor_nodes again -- solver.solve_lifecycle asserts it.
p = config.insert_anchor_nodes(p);

end
