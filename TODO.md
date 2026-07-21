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

- [ ] income_coef / income_source: CURRENTLY 'table' -- DIRECT lookup of
      Been, Knoef & Vethaak (2026) semi-parametric age-effect estimates
      (config/income_table_bkv.m, Tables D.1/D.2, FT-selection column),
      no cubic-fitting step. Selected by p.sex (1=men, 2=women,
      3=pooled). Two open sub-decisions before this is final:
        (a) sex=3 pooling is currently a PLAIN MEAN of the men/women
            series -- should this instead be weighted by something
            (participation shares? household structure?), and does a
            single-earner household income process even want "pooled
            individual wages" as its target, or something else entirely
            (e.g. household total labor income)?
        (b) RESOLVED 2026-07-14: p.age0 moved 20 -> 25 (T shortened 81 ->
            76 to keep terminal age 100 unchanged), so work_ages now start
            exactly at the table's first non-baseline age (25) and the
            below-sample linear extrapolation for ages 20-23 is no longer
            exercised. The extrapolation code path stays in
            income_profile.m as a guard for any future p.age0 < 24.
      The 'poly' (CGM 2005 HS-group) option is retained in params.m for
      comparison/robustness but is no longer the active default.
- [ ] sigma_l_log: CURRENTLY the CGM (2005) HS-group PERMANENT-shock std
      (0.1032), matched to this model's pure-random-walk income process.
      Still needs Carroll-Samwick / GMM decomposition on LISS income
      residuals (and sigma_ι, phi if the AR(1) split is ever implemented).
      Note the transitory component (CGM std 0.2717) has no home in the
      current single-composite-shock structure and is simply omitted.
      Unaffected by the income_coef/income_source change above -- Been
      et al.'s reported standard errors are precision of the estimated
      MEAN age effect, not a measure of individual-level income risk,
      so they cannot be repurposed for sigma_l_log.
- [x] r = 0.011 (1.1%): (REAL) risk-free rate, MK estimate (mean 3-month
      bond interest rate minus inflation), calibration slide deck
      (2026-07). NOTE: r, mu_S_level, and r_m are now consistently REAL
      (inflation-adjusted) figures, not nominal — a change from the old
      unsourced nominal-ish placeholders.
- [x] mu_S_level = 0.04 (4%), sigma_S_level = 0.16 (16%): equity premium
      and vol, MK convention (see slide appendix), calibration slide deck
      (2026-07). Slide notation for vol was "sigma_S = sqrt(16)%",
      read per user direction as vol = 16% (close to the old 15.7%
      placeholder); flag if that reading turns out wrong.
- [x] alpha = 0.1 (10%): rent rate, user-set 2026-07-14 (not sourced from
      LISS rent / self-assessed home value yet — a placeholder pending
      that data, not a final estimate).
- [x] theta = 0.015 (1.5%): maintenance rate, COELO Atlas of Local
      Government Taxes, MK, calibration slide deck (2026-07) gave two
      candidate values (1.5%/1.6%); 1.5% chosen per user, 1.6% not used.
- [x] mu_H_level = 0.027 (2.7%), sigma_H_level = 0.037 (3.7%): house
      price growth/vol, BIS Real Residential Property Price Index, MK,
      calibration slide deck (2026-07).
- [x] r_m = 0.013 (1.3%, real): mortgage rate, ECB MIR series (nominal
      3.6% less inflation 2.3%), calibration slide deck (2026-07).
- [x] N_mort = 30: Dutch market convention, confirmed by calibration
      slide deck (2026-07).
- [x] retirement_age = 67: calibration slide deck (2026-07). Raising it
      from 65 to 67 pushes work_ages past the BKV table's max age (64) --
      ages 65-66 are now held FLAT at the age-64 growth value (zero
      further deterministic growth) per user decision, not linearly
      extrapolated; see income_profile.m.
- [ ] sex (=3 in params.m): confirm what this maps to in `config.survival`
      (pooled vs. sex-specific table). Unaffected by this round of
      calibration updates.
- [x] kappa = 0.2 (20%): DC contribution rate, user-set 2026-07-14 (not
      yet the aggregate participant-weighted DNB/Pensioenfederatie figure
      described in "Contribution rate (kappa)" above — a placeholder
      pending that data, not a final estimate). `run_combined.m` now also
      runs a kappa=0 (no-DC-pension) benchmark alongside the p.kappa=0.2
      baseline, crossed with renter/owner, so the pension's welfare
      contribution can be read off directly.
- [ ] tau_inc (income tax rate): still TBD, calibration slide deck
      (2026-07) raises an open question (LISS gross vs net income as the
      target) but gives no value.
- [ ] beta (discount rate): still TBD, calibration slide deck (2026-07)
      suggests "moment matching or literature" but gives no value.
- [ ] chi (bequest intensity): still TBD, calibration slide deck (2026-07)
      marks it "?" with no value. See Tier 2 note above: baseline chi = 0
      already sits awkwardly against the paper's bequest rationale.
- [ ] h_mult (house-price-to-income at purchase): still TBD, calibration
      slide deck (2026-07) marks it "?" with no value — see "Housing
      assignment (h_mult)" section above for the sourcing approach.
- [ ] corr_SL, corr_HL, corr_SH: still TBD, calibration slide deck
      (2026-07) confirms the sourcing approach (LISS individual
      income/house growth x aggregate return series) but gives no
      numbers — see "Stock-labor correlation (corr_SL)" section above.
- [x] tau_cg_bond = tau_cg_stock = 0.0 (was 0.25 each): calibration slide
      deck (2026-07), "difficult due to box 3 changes, 0 for now" — see
      the existing Box 3 mismatch note above (Known open flags).

## Spline strategy menu sizing (July 2026)

- [x] `strategy.menu()` default widened 2026-07-14: levels 0:0.25:1 (35
      strategies) -> 0:0.125:1 (165 strategies), same 3 knots
      (age0/retirement_age/age0+T-2 = 25/67/99). Purpose: fill a ~12h
      cluster window at the observed cluster speed (~1.8-2 min/job from
      spline_strategies_log.txt) -- 165 strategies x housing="both" = 330
      jobs x ~2 min = ~11h. If that leaves too much headroom, go finer
      (0:0.1:1 -> 286 strategies, ~19h) rather than adding knots (which
      changes what's being compared, not just how many runs).
      Assumed housing="both" for this sizing -- if a run only covers one
      housing type, halve the expected wall time (or double the strategy
      count to compensate).
- [x] BUG FOUND & FIXED 2026-07-15: `run_spline_strategies.m`'s per-job
      diagnostic line hardcoded `p.tau_S(idx(20))` etc. (ages 20/40/64/66)
      -- broke with a negative-index error once age0 moved 20->25 (age 20
      fell before the modeled range), which would have killed the whole
      cluster sweep on strategy #1. Never triggered until this file was
      actually run again post-calibration-overhaul. Fixed to derive
      diagnostic ages from p.age0/p.retirement_age instead of literals.
      Lesson: hardcoded age literals anywhere in this codebase are a
      silent landmine after age0/retirement_age changes -- grep for
      literal ages when touching either parameter again.

## No-pension benchmark in strategy comparisons (July 2026)

- [x] `compare_spline_strategies.m` now folds `combined_{housing}_kappa0.mat`
      (run_combined.m's no-DC-pension benchmark) into the SAME ranking as
      the spline sweep, so its rank position and CEV vs the best strategy
      read off directly (excluded only from the tau_S glide-path plot,
      since tau_S is meaningless when A=0 for life). Requires
      run_combined.m to have been run with the `welfare0` field (added
      2026-07-15) for the fast matfile-read path; falls back to computing
      from sol.V for older files, same as the existing spl_* loader.
- [x] New `compare_strategy_vs_nopension.m`: per housing type, finds the
      best-ranked spline strategy and compares it against the kappa=0
      benchmark on a 12-panel overlay dashboard (adapted from make_plots.m's
      renter-vs-owner layout). Includes explicit sanity-check assertions
      (no NaN/Inf, A=0 for no-pension, matching tenure and H_0, housing
      panels should overlap exactly since kappa doesn't affect housing) --
      designed as a first-look "does this look sane" check on real cluster
      output, not a replacement for compare_spline_strategies.m's full
      ranking.
- [x] FRAMING FIX 2026-07-15 (both files above): welfare gain is always
      measured against NO_PENSION as the fixed reference (CEV vs no
      pension, not CEV vs whichever entry ranks best), and no pension
      beating every strategy is reported as a plain signed number with no
      "WARNING"/"check calibration" language -- it's a normal, expected
      possible outcome per explicit user direction, not an error state.
- [x] BUG FOUND & FIXED 2026-07-15 (pod run): `compare_spline_strategies.m`
      used the legacy `print(fig, fig_file, '-dpng', '-r140')` to save its
      figure -- the only figure-saving call left on that path in this
      repo, every other one (make_plots.m, compare_strategy_vs_nopension.m,
      analyze_dc_strategies_timing.m) already uses `exportgraphics`. `print`
      hit a graphics-timeout error on the cluster pod (no display); switched
      to `exportgraphics(fig, fig_file, 'Resolution', 140)`, matching the
      rest of the codebase. NOTE: `proto_spline_strategy.m` still has the
      same `print(...,'-dpng',...)` pattern -- not part of any pipeline
      (nothing calls it), left as-is, but would hit the same issue if ever
      run headless.
- [x] INCIDENT & FIX 2026-07-15 (pod run): stale spl_* files from the
      OLD calibration (35-strategy menu, age0=20, kappa=0.05 era) were
      still on /data and got silently ranked against a freshly-solved
      kappa0 benchmark at the NEW calibration, producing garbage CEVs
      (+792% renter / -91.9% owner) that looked like real output. Both
      comparison scripts now verify every file in a ranking shares one
      grid AND one calibration (param_fingerprint over grid dims + all
      key params, kappa excluded since the benchmark differs by design;
      kappa uniformity of the strategy files checked separately) and
      ERROR with a per-group file listing on mismatch. Ranking table
      reformatted (aligned columns, explicit "verified to share one
      grid + calibration" header line). ACTION on the pod: delete the
      stale /data/spl_*.mat files and re-run the sweep at the current
      calibration before comparing anything.

## Grid reparametrization (lambda, n-tilde, a) — July 2026

Implemented (commits 6aafa51..e9460ea) as `_lna` copies selectable via
CGM_GRID=lna: u1 = Y/W, u2 = (A+H)/(W-Y), u3 = A/(A+H) map the whole cube
[0,1]^3 to feasible states (paper Sec. 3 coordinates, with u1 a bounded
compactification of the paper's unbounded Y/(W-Y)). 28x20x20 = 11,200
states matches the 40^3 simplex grid's 11,480 feasible points.

VERDICT (2026-07-14 overnight z0-ladder arbiter, pod, renter, current
calibration; arms lna 28x20x20 / 40x28x28 / 56x40x40 vs simplex 40^3 /
52^3, results in proto_lna_overnight_results.mat + proto_on_*.mat):
- KEEP SIMPLEX 40^3 AS PRODUCTION. The lna ladder converges DOWN onto the
  simplex values (z0 0.0124 -> 0.0050 -> 0.0032 vs simplex 0.0027 ->
  0.0022); at the finest lna grid the simulated lifecycle reproduces
  simplex-40^3 moments to a few percent. Production-size lna (28x20x20)
  is badly biased: coarse UNIFORM u2 cells linearly interpolate across
  the convex value cliff at u2 -> 1 (liquid wealth -> 0), OVERestimating
  near-boundary continuation values -> under-saving, ~2x consumption
  rate, half the wealth. (An earlier 2026-07-13 session concluded the
  opposite — that simplex's z_min fill was the polluted side; that was
  wrong: smoke-scale lna refinements were plateau stability, not
  convergence.) Existing simplex results stand, now independently
  verified by a second discretization at 2.9x the state count.
- [ ] Welfare caution (unchanged in substance): z0 at the EXACT initial
      corner state (X=A=0) is unconverged on every arm tested (simplex
      still -20% per step 40^3 -> 52^3). CEVs read sol.V(:,:,:,1) there.
      Cross-check the CEV table on 52^3 (proto_on_simplex_52.mat already
      solved, pure post-processing) and/or move the welfare anchor
      slightly interior via the X0_frac buffer in simulate.paths.
- [ ] Optional lna revival: grade the u2 grid toward 1 (e.g.
      u2 = 1-(1-v).^2) — one-line change; if the cliff explanation is
      right its z0 ladder should hit simplex values at low state counts.
      Only worth it for the ~5.7x memory saving; not needed for results.
- [ ] Paper Sec. 3 follow-ups: eq (33) liquid-share term appears to use
      A/(A+H) where (A+H)/W-tilde is meant, and the housing-cost term is
      missing; the "reasonable upper bound" discussion for Y/W can be
      replaced by the bounded u1 = Y/W convention.

## Full-choice vs fixed-path DC welfare — comparison methodology (July 2026)

Open question, flagged 2026-07-21: **we need to think more about how to compare
the free-DC-investment-choice welfare (`choose_tau_S = true`, individually
optimal tau) against the fixed glide-path welfare, and against the no-DC
benchmark.** The per-state dominance property is settled; the scalar welfare
*number* is not.

Context / what is and isn't resolved:
- [x] Per-state DOMINANCE of free choice over the glide holds at the production
      grid (`test_freetau_dominance_prod.m`): over ~70-76k states, min CEV
      -5.6e-5 (numerical noise), median +1.1%, zero states losing >1e-4.
      Free choice weakly dominates the glide everywhere, as theory requires.
      The solver fix that guarantees this (glide-pinned + derivative-free
      ridge-proof polish in `bellman_step.m`) is in place.
- [ ] The scalar welfare comparison is NOT trustworthy as currently reported.
      Both the free-vs-glide CEV and the DC-vs-no-DC CEV are read from
      `sol.V(:,:,:,1)` at the initial corner node (X0=0, A0=0, H0=h_mult*Y0),
      which is (a) the SAME unconverged corner already flagged in the grid-
      reparametrization "Welfare caution" above, and (b) dominated by the t=0
      liquidity cost of the mandatory kappa contribution: at that corner the
      DC pension scores -29% (renter) / -48% (owner) CEV vs no-DC even though
      it raises consumption at nearly every later age. A buffer sweep
      (`welfare_dc_vs_nodc.m`, `welfare_dc_vs_nodc_by_buffer.png`) flips the
      sign to positive at ~1.1 yrs of income (renter) / ~5.7 yrs (owner) and
      reaches +75% / +10% at 10 yrs. So the headline number is an artifact of
      WHERE welfare is anchored, not a verdict on the pension.
- [ ] Decisions still needed before any full-choice-vs-fixed-path welfare
      number goes in the paper:
  - Anchor: move the welfare evaluation off the X0=0 corner (X0_frac buffer in
    simulate.paths, already supported) to a converged, economically defensible
    initial condition — and justify the buffer level rather than picking one
    that flips the sign. Alternatively report an ex-ante lifetime-utility
    metric integrated over a plausible initial-wealth distribution instead of a
    single node.
  - Comparability of the two regimes: the free-choice and glide solves share
    grid + calibration (good), but the annuity in BOTH is priced off the glide
    tau_S by provider convention — so the free household's chosen tau and its
    annuity pricing are inconsistent. Decide whether the welfare comparison
    should (i) keep that provider convention (current), or (ii) re-price the
    annuity off the individually chosen tau, and state which question the CEV
    is answering ("value of free accumulation choice under a fixed-priced
    annuity" vs "value of free choice end to end").
  - Grid convergence: re-check whichever welfare anchor is chosen at a finer
    grid (the buffer curves are visibly jagged from coarse-grid nearest-
    neighbour boundary interpolation; the initial corner is still ~-20%/step on
    simplex refinement per the note above).
  - Do NOT fold the freetau benchmark into `compare_spline_strategies.m` /
    `compare_strategy_vs_nopension.m` until the anchor is settled — those
    scripts also read Vt0 at the same corner and would inherit the artifact.

## Explicitly not calibration targets

gh_n, N_lambda, N_sA, N_sH, N_c, N_pi — solver accuracy/convergence choices,
justified via convergence checks (grid refinement, Euler-equation error), not
estimated from data.
