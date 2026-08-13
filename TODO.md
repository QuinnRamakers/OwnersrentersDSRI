# Open questions

What still has to be decided before the model is paper-ready. Resolved
decisions live in `CALIBRATION.md` and in git history; this file is only for
things that are still open.

---

## 1. Where welfare is read

**The biggest open item.** Everything downstream depends on it.

`V_tilde` is read at a single initial state, and the verdict on the DC pension
changes sign depending on which one. At the zero-liquid-wealth corner the
pension looks strongly negative; at a modest buffer it does not. The corner
number is an artefact of the `t = 0` liquidity cost of forced illiquid saving
under CRRA, not a verdict on the pension.

Current practice reads at `p.b0` (about 0.079 years of income), with `p.b_alt`
as a sensitivity. Both are forced onto the grid as exact nodes, so those two
values are solved rather than interpolated.

To decide:

- **Justify the anchor.** It has to be defensible on its own terms, not picked
  because of which sign it produces. The alternative worth considering is an
  ex-ante metric integrated over a plausible initial-wealth distribution rather
  than a single node.
- **Check convergence at whatever anchor is chosen.** Buffer curves other than
  `b0`/`b_alt` are interpolated and visibly ragged; the exact corner was still
  moving about 20% per grid refinement step when last checked.
- **Read differences, not levels.** Interpolation error is common-mode at a
  given buffer, so arm-versus-arm differences are far more robust than the
  level of any single curve. The write-up should say so.

Until this is settled, do not fold the free-DC arm into
`compare_spline_strategies` or `compare_strategy_vs_nopension` — they read the
same anchor and would inherit the problem.

## 2. Annuity pricing under free DC choice

Free choice and the glide arm share the grid and calibration, but in both the
annuity is priced off the fund's glide path, by provider convention. So a
household that picks its own equity share gets an annuity priced off a
different portfolio.

Decide which question the CEV is answering and say so explicitly:

- *(current)* the value of free accumulation choice under a fixed-priced
  annuity, or
- the value of free choice end to end, which means re-pricing the annuity off
  the chosen share.

Note the restriction that makes the current setup clean: free choice is
accumulation-only. After retirement the share is fixed by `p.tau_decum`, so
both arms behave identically post-retirement and the whole difference is
attributable to accumulation. Letting retirees re-pick would turn the draw rate
into a decumulation-speed lever; pinning at conversion would cost a fourth
state variable.

## 3. Bequest

- The baseline sets `chi = 0`, which contradicts the paper's stated rationale
  for housing wealth ("so there is a use for it"). With no bequest, no equity
  access and no sale, the owner's house is purely a cost-saving device. Pick
  one: give `chi` a value, or change the rationale.
- When `chi > 0` the bequest base is liquid wealth plus **gross** housing, with
  no mortgage netting, so a young decedent bequeaths an unencumbered house.
  This matches the paper's equation as written, but Cocco and Yao–Zhang net out
  the debt. Decide jointly with the mortgage-contract item — a real balance
  state fixes both.
- The terminal-period bequest is inconsistent with the recursion's: the
  recursion discounts by `beta` and applies one period of returns, the terminal
  step does neither. Dormant while `chi = 0`, wrong the moment it is switched
  on. See the code-audit note below.

## 4. Calibration inputs still missing

| Input | Status |
|---|---|
| `h_mult` | Placeholder 4.0. Replace with an income-contingent assignment fitted on LISS, with the Nibud loan-to-income tables as a feasibility ceiling |
| `kappa_base` | Single OECD figure. Want a participant-weighted aggregate across Dutch funds (DNB or Pensioenfederatie) |
| `sigma_l_log` | Borrowed from CGM. Needs a Carroll–Samwick or GMM decomposition on LISS income residuals |
| `corr_SL`, `corr_HL`, `corr_SH` | All zero. Estimable from LISS individual income and house-value growth against aggregate return series; the Cholesky plumbing is already in place, so this is pure calibration |
| `beta`, `chi` | No sourced value yet |
| `tau_wealth` | Calibrated at 0.0197 but currently switched off. Decide whether the baseline carries it |
| `tau_cg_bond`, `tau_cg_stock` | No rate. Both legs stay at zero until there is one |
| `sex = 3` pooling | Currently a plain mean of the men's and women's series. Should it be participation-weighted — and does a single-earner household process even want pooled individual wages, or household labour income? |

`tau_inc` should eventually be an effective average rate computed *along the
model's own income profile* (apply the Box 1 schedule to `f(t)` and average
over working life), not a single national statistic disconnected from the
modelled path.

## 5. Model features not implemented

- **REIT.** Absent from both portfolios despite being central to the
  housing-hedging story in the paper's Section 2. When added, treat `mu_Q` as
  an excess return like `mu_S`.
- **Income persistence.** The process is a pure random walk (`phi = 1`), which
  is free. Partial persistence is not: it needs a fourth state dimension to
  track the persistent component separately from `lambda`. Only pursue it if
  the LISS decomposition gives a specific empirical reason to prefer it.
- **Mortgage balance.** Deliberately not modelled; see `CALIBRATION.md`.

## 6. Paper write-up

The calibration section's headline numbers all match the code. These do not:

- **Taxes.** "Capital gains taxes in the DC account set to zero to make them
  tax-preferred" — CGT is zero in *both* accounts, so that sentence describes a
  mechanism doing no work. The DC advantage comes from EET, whose mechanics
  are not stated anywhere in the section.
- **Social planner section.** "No preferential tax treatment as income and
  capital gains are zero in this run" contradicts the calibration section,
  where `tau_inc = 0.382` is live. True of an older test run only.
- **Franchise.** Never stated, although `kappa_t` now depends on it. It is
  EUR 18,475 (1-1-2025, art. 18a lid 3 Wet LB).
- **Price year.** "CPI data to 2026 purchasing power" should read 2025, and
  needs the arithmetic to be reproducible: BKV amounts are 2015 euros, factor
  = CPI(2025)/CPI(2015) = 1.3456 (CBS 83131NED).
- **Welfare anchor.** The initial state is unstated and it drives the results.
  The planner section's "over-saving / welfare losses" reading is anchored at
  the old corner.
- **Off-by-ones.** BKV's last observed age is 64, not 65, and the code holds it
  flat over 65–66 only. Spline knots are at ages 25/67/99 (the last transition
  age), not `[T_0, T_R, T_D]`, and `tau` has `T-1` transitions, not `T_D`. The
  sentence describing `phi` is reversed relative to the formula — the ratio is
  exposed over benchmark.
- **Equation (27).** The mean of `eps` is written `+0.5 sigma^2`, which
  inflates `E[R_S]`. The standard correction is `-0.5 sigma^2`, which is what
  the code does.
- **Annuity formula.** Replace the `E[sum sp * prod 1/R]` expression with the
  recursion the code actually uses, `a_t = 1 + p_t a_{t+1} / E[R^A]`, and frame
  it as a variable annuity with assumed interest rate equal to `E[R^A]` — the
  AIR that makes expected payouts level. That is a recognised convention, not
  an ad hoc choice.
- **Section 3 coordinates.** Equation (33)'s liquid-share term appears to use
  `A/(A+H)` where `(A+H)/W-tilde` is meant, and the housing-cost term is
  missing. The "reasonable upper bound" discussion for `Y/W` can be replaced by
  the bounded convention the code uses.
- **Minor.** Housing volatility "3.7^2%" should be 3.7%; the wealth tax "1.97"
  is missing a percent sign; the cited ECB MIR series is the all-mortgages
  cost-of-borrowing indicator, not 30-year-fixed specifically — say so in the
  text rather than in a margin note. Typos: morality, piller, dditionally,
  perioding, yiels.

Three code behaviours are consistent but need stating rather than fixing:

- The renter's normalising aggregate `W` includes the rented house's value.
  Fine as state-space engineering; never label `W` "wealth" for renters.
- The DC return divides by survival probability during **accumulation**, i.e.
  a mortality credit from age 25. "Including longevity insurance" does not
  communicate this, and Dutch practice with partner pensions differs.
- The retirement-transition income shock is zeroed: AOW is a deterministic
  fraction of final working income. Solver and simulator agree.

And two approximations to carry into the text:

- The mortgage is proportional to the current house value, not level. Present
  the institutional contract, then state the approximation, and note it
  attenuates the fixed-versus-floating hedging asymmetry, so the owner/renter
  welfare gap is a lower bound along that dimension.
- The first pillar is `replacement * Y_64`, not a flat AOW amount. This belongs
  in the welfare section, not a footnote: it removes the risk-free floor for
  households with bad permanent-shock histories — exactly the households a
  max-min criterion weights most, so the planner results are somewhat
  pessimistic relative to a flat-AOW world.

## 7. Code audit, August 2026

Small and mostly cosmetic, but worth clearing.

- **Terminal bequest.** `solver.bellman_step` at `t = T` computes the bequest
  from current post-consumption wealth with no discount factor; the recursion
  at every other age uses `beta * (1 - p_t) * chi` on *next*-period wealth.
  Inert at `chi = 0`, wrong when it is turned on. `simulate.paths` matches the
  terminal step, so the two are at least consistent with each other.
- **LTV fallback contradicts the model.** `make_plots.m:128` and
  `compare_strategy_vs_nopension.m:418` backfill `p.LTV = 0.80` for files
  lacking the field, but `config.params` asserts `LTV == 1.00`. Legacy files
  get home-equity panels drawn against a mortgage the model never had. Change
  the fallback to 1.00.
- **Dead helpers.** `+utility/crra.m` and `+utility/bequest.m` are not called
  from anywhere. Delete or wire them into the solver, which currently inlines
  both.
- **Dead plotting branch.** About 230 lines of `make_plots.m` sit behind
  `RUN_ALL_SCENARIOS`, hardcoded false. Enabling it needs five `diag_*.mat`
  files that no run script in the repo produces. Delete the branch or restore
  the pipeline.
- **`parfor` broadcast.** `solver.bellman_step` reads `p.Rf` inside the
  parallel loop, which broadcasts the whole `p` struct — including the fill
  map — to every worker. Hoisting it into a local is behaviour-preserving.
- **Stale docstrings.** `simulate/paths.m` says the initial state is at age 20
  (it is 25). `run_nodc.m` cites `tau_inc = 0.376` and `tau_wealth = 0.0197`
  (now 0.382 and 0). `plot_nodc_vs_dcchoice.m` and `welfare_dc_vs_nodc.m` cite
  `kappa = 0.2`, which is now an age profile.
- **`verify_income_profile.m`** still warns that it has never been run against
  the real MATLAB code. It has, and it passes.

## 8. Optional

The alternative `(u1, u2, u3)` cube grid converges down onto the simplex
values, so the simplex results stand and are independently verified by a second
discretisation. At production size the cube grid is biased — uniform `u2` cells
interpolate across the value cliff as liquid wealth goes to zero, overstating
near-boundary continuation values.

Grading the `u2` grid toward 1 (`u2 = 1-(1-v)^2`) is a one-line change and
would test that explanation directly. Worth it only for the memory saving; not
needed for results.
