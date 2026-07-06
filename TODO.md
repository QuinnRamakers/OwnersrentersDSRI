# TODO — Calibration & Model Mechanics

Living list of calibration decisions and code changes needed before the model
is ready for the paper. Grouped by area. Check items off as they're resolved.

## Income process

- [x] CONFIRMED, no change needed: `bellman_step.m` (`Y_next_W = G_next * lam`)
      and `simulate/paths.m`
      (`Y_path(:,t+1) = Y_path(:,t) .* exp(mu_growth(t) + sigma_l_log(t)*eps_Y)`)
      already implement a geometric random walk with drift — shocks compound
      permanently onto the current income share, they are not reset to the
      deterministic age profile each period. This is the phi=1 formulation
      discussed; it's already in place in both the solver and the simulator.
      (Earlier note in this file incorrectly described the process as
      memoryless/transitory — corrected.)
- [ ] Partial persistence (0 < phi < 1, genuine mean reversion) is NOT free —
      unlike the phi=1 case already implemented, it requires a 4th state
      dimension (to track the persistent component separately from lambda)
      and would meaningfully increase solve time. Only pursue if there's a
      specific empirical reason (from the LISS GMM decomposition) to prefer
      partial persistence over a pure random walk.

## Stock–labor correlation (corr_SL)

- [ ] Currently dead: `p.corr_SL` is defined in `params.m` but `shock_grid.m`
      draws stock, income, and housing shocks as independent tensor-product
      nodes. Wire it in via Cholesky on the existing income/stock Hermite
      nodes:
      `z_S = z_1`, `z_L = rho*z_1 + sqrt(1-rho^2)*z_2`
      — same node/weight count, no increase in `gh_n^3`.
- [ ] Estimate rho from LISS: run the income regression (age profile +
      individual + year fixed effects), extract the year effects as the
      aggregate/common income shock series, correlate against contemporaneous
      Dutch/euro-area equity returns over the same window (2008–2025).
  - Sanity check only, not a substitute: CGM's cross-occupation estimates are
    near zero to mildly positive.

## Contribution rate (kappa)

- [ ] Use an aggregate, participant-weighted contribution rate across Dutch
      pension funds (DNB pension statistics or Pensioenfederatie aggregates),
      not ABP alone — ABP's rate reflects one fund's specific funding
      position, not a representative rate.

## delta (tax rate ambiguity)

- [ ] Resolve the double-counting risk: paper's Table 1 defines delta as the
      flat income tax rate, but the budget constraint code separately has
      `tau_inc = 0.30` under an EET-treatment comment. Check whether both are
      multiplying income in the same equation. If so, one needs to go.
- [ ] Once resolved: calibrate as the effective average tax rate applied
      *along the calibrated income profile* — apply the actual Box 1 bracket
      schedule to f(t) and average across working life — rather than a single
      national statistic disconnected from the model's own income path.

## Housing assignment (h_mult)

- [ ] Replace the fixed `h_mult = 4.0` scalar with an income-contingent
      function H_0 = h(Y_0):
  - Primary: estimate directly from LISS — regress log(house value at
    purchase) on log(income at purchase) + age/cohort controls. Use the
    fitted relationship (not necessarily unit-elastic) plus residual
    dispersion to assign H_0, rather than a single multiplier.
  - Cross-check: Nibud/AFM published loan-to-income affordability tables
    (financieringslastpercentage) give the regulatory *ceiling* given income
    and the prevailing mortgage rate — public, no microdata needed. Use as a
    feasibility bound on the LISS-fitted assignment, not the primary source
    (not everyone borrows to the ceiling).

## Code <-> paper audit (pre-calibration, July 2026)

Tier 1 — DECIDED (co-author decisions, July 2026):
- [ ] Mortgage contract — DECISION: keep the proportional approximation
      (m_rate_t * H_t), no mortgage balance state, due to runtime.
      CORRECTION to earlier audit note: solver and simulation budgets are
      already consistent (paths.m also uses h_cost_rate = theta + m_rate_t);
      the exact M_balance schedule exists only in make_plots display panels.
      Remaining work is paper-side: present eqs (13)-(14) as the
      institutional contract, then state the homothetic approximation
      explicitly and note it attenuates the fixed-vs-floating hedging
      asymmetry -> owner/renter welfare gap is a LOWER BOUND along this
      dimension.
- [ ] Equity premium — DECISION: mu_S is the excess return; code changes.
      Fix in params.m (mu_S_level reinterpreted as level premium, CGM use 4%):
        p.sigma_S = sqrt(log(1 + (p.sigma_S_level/(1 + p.r + p.mu_S_level))^2));
        p.mu_S    = log(1 + p.r + p.mu_S_level) - 0.5*p.sigma_S^2;
      All existing results were solved at an effective 2% premium — expect
      higher pi after the fix, not a bug. Also fix paper eq (27): draft has
      +0.5*sigma_eps^2 as the mean of eps (inflates E[R_S] to
      Rf*exp(mu_S + sigma^2)); standard correction is -0.5*sigma^2. Housing
      mu_H is the house's own log drift (not excess) — code already matches.
      Same excess treatment applies to mu_Q when REIT is added.
- [ ] Annuity pricing — DECISION: code's 1/E[R] level-expected-payout
      recursion is the intended design; the PAPER/PRESENTATION change.
      Replace the E[sum sp * prod 1/R] slide formula with
      a_t = 1 + p_t*a_{t+1}/E[R^A]; frame as a variable annuity with
      assumed interest rate (AIR) = E[R^A], the AIR that makes expected
      payouts level — a recognized convention, not ad hoc.
- [ ] Shock correlations — DECISION: implement the capability. Zero runtime
      cost: keep the gh_n^3 tensor grid of independent nodes, add a 3x3
      correlation matrix to params.m, map through its Cholesky factor
      identically in shock_grid.m and paths.m. Calibration principle: with a
      single composite income shock (no aggregate/idiosyncratic split),
      target pairwise COVARIANCES — cov(dy_i, r_S), cov(dh_i, dy_i),
      cov(dh_i, r_S) — which are estimable from LISS + aggregate return
      series and invariant to the split the paper's Section 2 describes.
      Document the conflation explicitly (single corr per pair absorbs both
      aggregate and idiosyncratic channels).
- [ ] First pillar — DECISION: keep replacement * Y_64 as a calibration
      approximation to flat AOW. Calibrate replacement = statutory AOW
      amount / mean calibrated Y_64 of the reference individual (right on
      average, earnings-linked household-by-household). Carry into the
      WELFARE section (not a footnote): the approximation removes the
      risk-free AOW floor for households with bad permanent-shock histories
      — exactly the households the soft-Rawlsian outer criterion weights
      most. Max-min results are somewhat pessimistic vs a flat-AOW world.

Tier 2 — code structure absent from the paper:
- [ ] Taxes: EET income tax (tau_inc = 0.30) + accrual CGT 25% with NO loss
      offset — paper has only flat delta. Needs a taxes subsection; the
      no-loss-offset asymmetry is nonstandard (option-like drag on equity)
      and needs explicit defense. delta/tau_inc redundancy: budget applies
      (1-delta)(1-kappa)(1-tau_inc); delta = 0 is a dead knob — code's
      tau_inc IS the paper's delta. Rename or delete p.delta.
- [ ] Pre-retirement mortality credit: R_A divides by p_t during
      accumulation (tontine from age 20). "Including longevity insurance"
      in the paper does not communicate this; Dutch practice (partner
      pension) differs. State explicitly.
- [ ] Bequest: (a) baseline chi = 0 contradicts the paper's stated rationale
      ("a use of housing wealth"); with chi = 0 + no equity access + no
      sale, the owner's H is purely a cost-saving device. (b) When chi > 0,
      bequest base is X + GROSS H, no mortgage netting — a young decedent
      bequeaths an unencumbered house. Matches paper eq (2) as written but
      Cocco / Yao-Zhang net out debt. Decide jointly with the mortgage-
      contract item (a real balance state fixes both).

Tier 3 — consistent but must be documented deliberately:
- [ ] Renter's normalizing aggregate W includes the (non-owned) rented
      house's value. Fine as state-space engineering; never label W
      "wealth" for renters in paper or plots.
- [ ] Glide-path comment wrong: tau_S is 0.8 flat from age 20 to 37 (cap
      binds), then linear to 0 at 65 — not "0.8 at age 30, linear down".
      Fix comment; don't let the paper inherit it.
- [ ] Retirement-transition income shock zeroed at t_ret-1 (deterministic
      conversion) — solver and sim agree; state in paper.
- Audit coverage caveat: based on retrievable snippets of params,
  income_profile, shock_grid, bellman_step, paths, annuity_price,
  make_plots, run_dc_strategies, welfare_dc_strategies. NOT audited:
  solve_lifecycle.m, config.survival, run_combined.m internals.

## Known open flags (from parameter audit)

- [ ] LTV: paper text states 100% LTV / no down payment, but downstream
      analysis code (`make_plots.m`) defaults to 0.80 for files lacking a
      `p.LTV` field — implying a `p.LTV` parameter may have been added to a
      newer version of `params.m` not visible in this audit. Confirm current
      value/role directly against the live file.
- [ ] Capital gains tax (tau_cg_bond, tau_cg_stock): known institutional
      mismatch — the Netherlands taxes a deemed/presumptive return on wealth
      (Box 3), not realized capital gains. **Decision: keep current
      accrual-basis implementation as-is for now.** Revisit if a referee
      flags it.
- [ ] REIT asset: absent from both private and pension portfolios despite
      being central to the housing-hedging story (per paper Section 2).
- [ ] `bellman_step_fmincon_wip.m`: untested, not wired into the solver.
- [ ] Annuity pricing convention: code uses `1/E[R]`, proposed alternative is
      `E[1/R]` (actuarially fair PV convention) — needs a decision one way or
      the other before results are finalized.

## Calibration targets — data sourcing (no code change, just inputs)

- [ ] income_coef: own LISS regression (age cubic + cohort effects + Heckman
      selection correction on full-time employment), replacing dependence on
      unpublished Been-Knoef-Vethaak coefficients.
- [ ] sigma_l_log (and sigma_ι, phi if the AR(1) split is ever implemented):
      Carroll-Samwick / GMM decomposition on LISS income residuals.
- [ ] r: long-run real return on short Dutch/euro-area government paper
      (DNB/ECB).
- [ ] mu_S_level, sigma_S_level: long-run real equity premium/vol from a
      macrohistory source (Jordà-Schularick-Taylor or Dimson-Marsh-Staunton).
- [ ] alpha (rent rate): LISS rent / self-assessed home value, by age/region.
- [ ] theta (maintenance): LISS self-reports, cross-checked against
      Vereniging Eigen Huis published maintenance-cost norms.
- [ ] mu_H_level, sigma_H_level: public CBS/Kadaster house price index for
      the systematic component; LISS panel dispersion around that index for
      the idiosyncratic piece.
- [ ] r_m: DNB/CBS published mortgage rate series.
- [ ] N_mort: Dutch market convention (30-year term), institutional fact.
- [ ] retirement_age: confirm current statutory AOW eligibility age
      (SVB/Rijksoverheid) — it's indexed to life expectancy and has been
      rising past 65.
- [ ] sex (=3 in params.m): confirm what this maps to in `config.survival`
      (pooled vs. sex-specific table).

## Explicitly not calibration targets

gh_n, N_lambda, N_sA, N_sH, N_c, N_pi — solver accuracy/convergence choices,
justified via convergence checks (grid refinement, Euler-equation error), not
estimated from data.
