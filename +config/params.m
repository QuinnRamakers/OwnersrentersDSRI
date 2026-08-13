function p = params()
%PARAMS  Calibration for the CGM life-cycle model with DC pension and housing.
%
%   Sources, derivations and open questions for every value here are in
%   CALIBRATION.md. This file keeps one-line comments.
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
%
%   Every euro-denominated input is in 2025 prices. Only income_price_factor
%   and franchise carry a price year and they must move together; see
%   CALIBRATION.md.

% Time horizon. age0 = 25 is where the BKV income table starts, so the working
% profile needs no below-sample extrapolation; T = 76 keeps the terminal age
% at 100.
p.T              = 76;
p.age0           = 25;
p.retirement_age = 67;      % statutory AOW eligibility age (2026)
p.sex            = 1;       % INCOME profile only (1=men, 2=women, 3=pooled); mortality is unisex

% Preferences
p.gamma = 5;         % risk aversion (CRRA): Cocco, Gomes & Maenhout (2005)
p.beta  = 0.96;       % time discount factor: Larsen et al. (2023)
p.chi   = 0.0;        % bequest intensity: off in the baseline

% Labour income
%   'table' is the direct Been-Knoef-Vethaak (2026) age-effect lookup
%   (config.income_table_bkv); 'poly' falls back to the CGM cubic below.
p.income_source = 'table';
p.income_coef = [0.530339, 0.16818, -0.323371, 0.19704];   % CGM (2005) HS-group cubic, used only by 'poly'
p.sigma_l_log = 0.1032;     % CGM (2005) HS-group PERMANENT shock std; the process here is a pure random walk
p.replacement = 0.307;      % AOW-only first-pillar replacement: DNB "Toereikendheid van pensioenen" Table 3
p.income_price_factor = 1.3456;   % CPI(2025)/CPI(2015), CBS 83131NED -- rescales the BKV 2015-euro anchor

% Financial market
p.r             = 0.011;   % real risk-free rate
p.mu_S_level    = 0.04;    % equity EXCESS return level (over r_f)
p.sigma_S_level = 0.16;    % equity return vol
% Shock correlations (income L, stock S, housing H). Wired through a Cholesky
% factor in grids.shock_grid and simulate.paths, so setting them costs nothing.
p.corr_SL       = 0.0;     % corr(stock return, income shock)
p.corr_HL       = 0.0;     % corr(housing return, income shock)
p.corr_SH       = 0.0;     % corr(stock return, housing return)

% Pension parameters
%   Contributions are levied on gross income above a franchise:
%       kappa_t = kappa_base * max(Y_t - F, 0) / Y_t
%   so the effective rate on gross income is an AGE PROFILE, not a scalar.
%   p.kappa is built below as a T x 1 vector; solver and simulator index it as
%   p.kappa(min(t, numel(p.kappa))), which keeps legacy scalar-kappa p-structs
%   and the p.kappa = 0 overrides in run_nodc / run_dc_strategies working.
%
%   kappa_t is evaluated on the DETERMINISTIC income profile, not realised Y_t:
%   the model is homothetic in W (only lambda = Y/W is a state), so a rate
%   depending on realised Y would break the normalised state space.
p.kappa_base = 0.186;    % contribution rate above the franchise (OECD)
p.franchise  = 18475;    % minimum AOW-franchise, 1-1-2025 (Belastingdienst CAP)
p.delta     = 0.0;       % legacy proportional wedge on gross income; NOT the paper's delta (that is p.tau_inc)
% tau_S is a glide-path lifecycle fund: 0.8 equity while (retirement_age - age)
% exceeds 28 years (so flat through age 39), then linear down to 0 at
% retirement, 0 thereafter. Vector built below, after t_ret.
%
% Free DC investment choice: when choose_tau_S is true the DC equity share
% becomes a THIRD choice variable (c, pi, tau) in solver.bellman_step (simplex
% solver only). The annuity is still priced off the plan's glide path. N_tau
% sizes the tau seed grid; the glide value is appended to it.
p.choose_tau_S = false;
p.N_tau        = 11;

% Housing
p.is_owner      = false;     % flip true for owner scenario
p.alpha         = 0.06;      % rent-to-price ratio (fraction of H_t / period)
p.theta         = 0.015;     % maintenance cost fraction
p.mu_H_level    = 0.027;     % real house-price drift (own return, not excess)
p.sigma_H_level = 0.037;     % house-price return vol
p.h_mult        = 4.0;       % H_0 = h_mult * Y_0 -- placeholder, see CALIBRATION.md
p.r_m           = 0.0136;    % real mortgage rate (>= r_f)
p.N_mort        = 30;        % mortgage term (years)
%   LTV: only 1.00 is implemented. The household is endowed with the house at
%   t=1 (X_0 = 0, H_0 = h_mult*Y_0) and services a mortgage on its full value.
%   LTV < 1 needs a down-payment endowment (negative initial X) the simulator
%   does not model, so the assert below fails loudly. The field is wired into
%   the amortisation rate so the payment scales once that endowment exists.
p.LTV           = 1.00;
p.sell_cost     = 0.025;     % seller transaction cost at bequest; inert while chi = 0

% Rent process (renters only). The renter's H state is a rent index rather than
% a house: it has no resale or bequest value, and its only role is to set the
% rent alpha*H_t. Rent increases are therefore their own process, calibrated on
% rent data, not the house-price return. See config.h_process.
%
% Both figures must be real (CPI-deflated), on the same footing as
% mu_H_level -- published Dutch rent-increase series are nominal.
%
% Setting these to the housing pair reproduces the pre-split model, which is
% how the old/new comparison runs are configured.
p.mu_R_level    = 0.0097;    % real rent growth, mean
p.sigma_R_level = 0.018;     % real rent growth, vol

% Consumption floor, as a fraction of CURRENT GROSS INCOME Y_t. When a
% household's own liquid resources fall short of phi_floor * Y_t the shortfall
% is paid from outside, it consumes the floor and saves nothing that period.
% It is a guarantee, not a mandate: a household that can already afford the
% floor is free to consume below it and save the difference.
%
% phi_floor = 0 switches the floor off and restores the pre-floor sentinel
% (V = -1e15 where outgoings exceed resources), so old calibrations rerun
% unchanged. Any positive value removes the sentinel entirely.
%
% Expressed against income rather than as a euro level so the model stays
% homothetic: normalised, the floor is phi_floor * lambda, a function of the
% existing state, so no fourth state variable is needed. In retirement Y is
% constant in real terms, so it is a level floor exactly where it binds.
%
% Its job is to make C = 0 unreachable. Utility is unbounded below at
% gamma > 1, so a state consuming exactly zero carries u = -inf, and any arm
% that can reach one has E[U] = -inf and cannot be ranked against another.
%
% At 1e-6 the floor is barely above zero, which is deliberate: ruin stays
% catastrophic. Be aware of what that implies for welfare. u(1e-6) exceeds
% u(30000) by 8e41 while the whole beta-and-survival discount spans 1.5e3, so
% in double precision a single floored year annihilates an entire lifetime of
% ordinary consumption. E[U] then ranks arms purely by how often the floor
% binds. That is a legitimate criterion, and it is the one in force at this
% value -- it is not a criterion that can separate arms differing only in
% their consumption paths. Raising phi_floor is the only change needed:
% phi_floor = 1 puts it at the AOW, the Dutch social minimum.
p.phi_floor = 1e-6;

% Which coordinate system a run is solved on. The simplex and the LNA cube are
% different discretisations of one model and a p-struct carries both sets of
% grid vectors, so nothing else distinguishes them and
% utility.param_fingerprint would rate a simplex file and a cube file
% comparable. Scripts solving on the cube must set this to 'lna'; the LNA
% solvers assert it.
p.grid_type = 'simplex';

% Polish version in solver.bellman_step. 2 scales the fmincon objective by a
% per-period factor and seeds it from the t+1 policy at the same node; 1 is the
% original polish and is bit-identical to every solve before this.
%
% Adopted knowing it is a null result on output: measured over full solves at
% [25 15 15]/gh_n=5, both tenures, version 2 reproduced version 1 on every
% digit of Vt0, floor incidence, consumption and the equity share. What it buys
% is a polish that actually moves (unscaled, the objective sat nine orders
% below fmincon's FunctionTolerance, so it converged without iterating), the
% derivative-free refinement that the glide branch never had, and an end to the
% singular-KKT warnings. What it costs is runtime.
%
% It is in param_fingerprint, so files solved under the two versions do not
% rate as welfare-comparable even though they agree.
p.polish_ver = 2;

% Seed search for the polish. 'none' drops the NC x NP tensor entirely and
% relies on the warm start plus two fixed points, which is the architecture the
% coauthor's solver uses -- one fmincon per state from a guess, no grid search.
% 'full' keeps the tensor. Only the glide branch honours this; free-tau always
% keeps the tensor, since its dominance guarantee rests on the glide slice's
% grid maximum.
p.grid_mode = 'none';

% Numerical: 3D state grid (lambda, s_A, s_H) on the simplex lambda+s_A+s_H<=1.
% gh_n^3 = 343 joint Gauss-Hermite shock nodes per state.
p.gh_n     = 7;
p.N_lambda = 40;
p.N_sA     = 40;
p.N_sH     = 40;
p.lambda_grid = linspace(0, 1, p.N_lambda).';
p.sA_grid     = linspace(0, 1, p.N_sA).';
p.sH_grid     = linspace(0, 1, p.N_sH).';

% Welfare anchors: initial liquid buffer in YEARS of the model's own age-25
% gross income. b0 is the calibrated value, b_alt an upper sensitivity. Both
% sides of each ratio are in 2024 euros, so they are price-level-free.
% config.insert_anchor_nodes (end of this file) puts the corresponding
% (lambda, s_H) coordinates on the grids as EXACT nodes, so welfare at t=1 is
% a solved value rather than a trilinear blend.
p.b0    = 3400 / (33000 * 1.3031);    % = 0.0791 years of entry income
p.b_alt = 9800 / (33000 * 1.3031);    % = 0.2279

% Inner (choice) grid seeding the per-state fmincon polish in bellman_step.
%   N_c  : must stay fine -- the objective is multimodal in c and a coarse
%          grid seeds the wrong basin.
%   N_pi : keep at 41 -- the objective is flat in pi near the optimum, so
%          coarsening biases the equity-share policy low and noisy even though
%          the value function barely moves.
p.N_c  = 41;
p.N_pi = 41;

% Alternative cube state grid (lambda, n-tilde, a) -- see bellman_step_lna:
% u1 = lambda, u2 = (A+H)/(W-Y), u3 = A/(A+H). Every point of [0,1]^3 is
% feasible, so 28x20x20 matches the 40^3 grid's feasible-point count at much
% less memory. lambda gets the extra resolution because it is empirically the
% steepest policy axis. Selected via CGM_GRID=lna; simplex stays production.
p.N_u1 = 28; p.N_u2 = 20; p.N_u3 = 20;
p.u1_grid = linspace(0, 1, p.N_u1).';
p.u2_grid = linspace(0, 1, p.N_u2).';
p.u3_grid = linspace(0, 1, p.N_u3).';
p.skip_polish = false;      % lna only: grid-search without the fmincon polish

% Taxes
%   EET pension treatment: contributions are deductible, the fund grows
%   tax-free, and both the annuity payout and AOW are taxed on receipt, so
%   working take-home is (1-kappa)*(1-tau_inc)*Y. With both CGT legs and the
%   wealth tax at zero, EET is the whole of the DC account's tax advantage.
%   Both instruments stay wired in rather than collapsed into one -- they
%   represent different regimes, so switching is a calibration change.
p.tau_inc      = 0.382;    % CBS, average tax burden on income, 2019 -- this IS the paper's delta
p.tau_cg_bond  = 0.0;      % accrual CGT on the liquid account, no loss offset; DC fund sheltered
p.tau_cg_stock = 0.0;
p.tau_wealth   = 0.0;      % box-3-style levy on the liquid balance; calibrated value 0.0197, currently off

% Derived
p.Rf      = 1 + p.r;
% mu_S_level is the EXCESS return level (over r_f): ln(R_S) = ln(R_f) + mu_S + eps.
% Total expected gross level return is (1 + r + mu_S_level).
p.sigma_S = sqrt(log(1 + (p.sigma_S_level / (1 + p.r + p.mu_S_level))^2));
p.mu_S    = log(1 + p.r + p.mu_S_level) - 0.5 * p.sigma_S^2;
% mu_H_level is the house's OWN log return (not excess).
p.sigma_H = sqrt(log(1 + (p.sigma_H_level / (1 + p.mu_H_level))^2));
p.mu_H    = log(1 + p.mu_H_level) - 0.5 * p.sigma_H^2;
% Rent-index growth, same level-to-log conversion as the house.
p.sigma_R = sqrt(log(1 + (p.sigma_R_level / (1 + p.mu_R_level))^2));
p.mu_R    = log(1 + p.mu_R_level) - 0.5 * p.sigma_R^2;
p.t_ret   = p.retirement_age - p.age0 + 1;

% Pension glide path tau_S, length T-1 (transitions).
ages_grid   = (p.age0 : p.age0 + p.T - 2).';
glide       = max(0.0, min(0.8, (p.retirement_age - ages_grid) / 35));
glide(ages_grid >= p.retirement_age) = 0.0;
p.tau_S_raw = glide;
p.tau_S     = glide;

% DECUMULATION strategy: the DC equity share held from t_ret onward. Free
% investment choice is accumulation-only -- the solver never re-picks tau after
% retirement -- so this is the single knob controlling the retired fund, and
% config.tau_effective splices it onto the glide above.
%
% [] keeps the glide's own retirement values, which are 0 (all-bond fund). Set
% a scalar for a constant share or a vector for a path; see config.tau_effective
% for the accepted lengths.
%
% Whatever is set here is PRICED: pension.annuity_price reads the same path, so
% the annuity and the portfolio can never disagree. a_t falls as the share
% rises, so this materially moves the retired budget.
p.tau_decum = [];

% Effective DC contribution rate on GROSS income, kappa_t (T x 1), from the
% franchise rule evaluated on the deterministic income profile. Zero from
% retirement on (the solver and simulator branch on is_retired anyway).
assert(p.LTV == 1.00, 'params:LTV', ...
    ['LTV = %.4f: only 1.00 is implemented. LTV < 1 needs a down-payment ' ...
     'endowment (negative initial X) that the simulator does not model.'], p.LTV);
logY_det       = config.income_profile(p);
Y_det          = exp(logY_det);
p.kappa        = zeros(p.T, 1);
work_t         = 1 : (p.t_ret - 1);
p.kappa(work_t) = p.kappa_base .* max(Y_det(work_t) - p.franchise, 0) ./ Y_det(work_t);

% Mortgage amortisation rate. Homothetic approximation: applied as a rate on
% the CURRENT H_t for years 1..N_mort, zero thereafter, so the payment tracks
% the house price rather than staying level. Scaled by LTV -- the annuity
% payment is on the borrowed fraction.
amort_rate     = p.LTV * p.r_m * (1 + p.r_m)^p.N_mort / ((1 + p.r_m)^p.N_mort - 1);
p.m_rate_path  = zeros(p.T - 1, 1);
p.m_rate_path(1 : min(p.N_mort, p.T - 1)) = amort_rate;

% Put the calibrated welfare anchors on the lambda / s_H grids as exact nodes.
% Last, because it depends on h_mult, b0, b_alt and the grid vectors all being
% set. Any script that REBUILDS the grids after this must call
% config.insert_anchor_nodes again -- solver.solve_lifecycle asserts it.
p = config.insert_anchor_nodes(p);

end
