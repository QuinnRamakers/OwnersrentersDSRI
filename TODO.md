# Open questions

What still has to be decided before the model is paper-ready. Resolved
decisions live in `CALIBRATION.md` and in git history; this file is only for
things that are still open. The research evidence referred to is on the
`solver-active-set` branch, in `diagnostics/`.

---

## 1. The consumption floor and the committed housing outflow

The decision everything else waits on. The calibration ladder stopped here, at
step 7 (housing).

At the production calibration a 25-year-old renter pays rent of about 41% of
net income, 25% without the income tax (owners: maintenance and mortgage of a similar order), cannot reduce
it, and is protected by a floor of 1e-6 times income. With gamma = 5 that
leaves the early-life value function without a limit: refining the grid, the
quadrature or the node placement moves consumption and the equity share at
25-39 by factors of two to three, and the value at entry diverges. Scaling the
rent down to 11% of net income makes the model converge outright, so the cause
is the outflow, not the numerics. From 40 on, behaviour is stable.

Step 7 shows the same problem without taxes or DC (HANDOFF.md, 2026-10-12;
scripts in `diagnostics/step07/`):

- Neither tenure is grid-converged. Doubling the income axis moves the owner's
  mean equity share by up to 0.88 and consumption by 79% (renter 0.19 and 20%).
  With constant house prices the owner converges (0.02 and 0.3%), so the cause
  is a housing outflow tied to the house-price shock that the household cannot
  adjust, combined with the near-zero floor.
- The owner's mortgage is charged on the current house value. In present value
  it costs 1.71 times the loan on average, against 1.00 for a real annuity, and
  28% of gross income at 54 against 10%. Maintenance of 1.5% on a house that
  grows 3.73% a year outruns the flat pension: 12% of owner household-years
  from 67 are at the floor.
- The grid knows the value only at its points, and along the income axis it
  has none between 24 and 4999 times income. Floor states are valued as
  comfortable in old age, and in early life each refinement finds more of them.
- Raising the owner's floor to 0.1-0.5 times income removes the early-life
  collapse, but the grids still differ by 13-21 points in the equity share and
  11-22% in consumption, in mid-life and retirement, and the floor binds more
  often as it rises (45% of owners at 95 at a floor of 0.5). A floor is needed
  but does not fix the grid dependence.

Decisions open, to be settled before step 7 is rerun:

1. **Owners' access to housing equity.** Let owners sell part of the house, or
   release equity, when cash runs short. This removes owner ruin while equity
   is positive and keeps three states.
2. **The mortgage payment.** Settled for this contract on 15 October 2026: a
   real annuity on the purchase price, with q = H0/H as a fourth state, from
   ladder step 7b on (CALIBRATION.md). Measured on 16-17 October with
   maintenance on the purchase price: for owners the grid dependence is gone
   (bunched 16x16 converged at step 7b, 24x24 at step 13, at every age);
   renters still do not converge before 40 at either step
   (`docs/HANDOFF_2026-10-17.md`).
3. **Renters.** Cap the rent burden with housing benefit (huurtoeslag), at a
   share of income to be sourced, or let renters downsize as in Yao and Zhang
   (2005).
4. **The floor.** Settled on 17 October 2026: not a calibration target.
   `phi_floor` stays a numerical bound at 1e-6, with 1e-4 admissible, and is
   not set to the social minimum (CALIBRATION.md). The early-life problem has
   to be met through the housing outflow (1, 3 and 6).
   Since 23 October an absorbing floor is implemented and off by default
   (`c_min`, CALIBRATION.md, "The absorbing floor"; results in HANDOFF.md,
   23 October). Open before it is adopted: the value and source of `c_min`
   (Nibud minimum example budgets, single or couple), and a bequest rule for
   bankrupt households before `chi` is switched on. If adopted, the floor
   becomes a model primitive and this item is rewritten.
5. **What the house is for.** A bequest (`chi > 0`, see 4) or equity release.
6. **The outflow from data.** `h_mult` now follows the Nibud maximum mortgage
   (see 2), a ceiling rather than an estimate, and the owner's 100% LTV with
   almost no liquid wealth at entry is the starkest version of the same
   problem.

Then rerun step 7 on the standard and the doubled grid; it passes when they
agree within the stop rule (2 points in the equity share, 2% in consumption).
If none of this is taken up, report ages 40+ only and state that accumulation
is not identified.

Related: since 15 October the lower bound of the consumption search is the
floor itself, C >= phi_floor * Y (`docs/SOLVER_BOUNDS.md`, section 1), so
setting the floor also sets the search bound.

## 2. Calibration inputs still missing

| Input | Status |
|---|---|
| Income polynomial by tenure | Decided (Quinn, 23 October 2026): owners and renters will use the same polynomial, a DHS cubic estimated on both tenures pooled. Not implemented; the code still has separate DHS cubics (`income_coef`, `income_coef_rent`). Waiting on the pooled coefficients from Quinn. To decide: whether `sigma_l_log` is shared too. With one polynomial the entry income is the same for both tenures, so the Nibud `h_mult`, the contribution-rate profile and the entry incomes in the `b0` and `tau_inc` rows below no longer differ by tenure. If the shock std is shared as well, the steps without housing are solved once instead of for each tenure (`model.tenures_differ`) |
| `h_mult` | Production uses the Nibud 2026 maximum mortgage at entry income (`h_rule = 'nibud'`, ladder step 16): 4.45 owners, 4.16 renters; `h_fixed` 4.0 at steps 7-15 is a placeholder. To decide: the test rate (`r_m` is real, the norm's rate nominal); box 1 or box 3 (the model has no interest deduction); the 2025 tables for the price year; the EUR 17,000 increase; whether renters follow the rule. Still wanted: an income-contingent assignment fitted on LISS, with the Nibud rule as its ceiling |
| `kappa_base` | Single OECD figure. Want a participant-weighted aggregate across Dutch funds (DNB or Pensioenfederatie) |
| Housing level | `theta` 1.5% is a placeholder; `h_mult`, see above. `alpha` is 5.6% from a government report whose reference is still to be added; the mortgage rate is 3.48% (CALIBRATION.md). The housing dynamics and correlations are calibrated (Tables 1 and 3) |
| `b0`, `b_alt` | Placeholders. The entry buffer divides deposits by the BKV men's wage at 25. The income profile is now DHS household-head income (EUR 39,763 owners, 30,098 renters at 25), so the denominator, and possibly a buffer by tenure, should follow |
| REIT moments and correlations | The leg is off and the code still has placeholders; the calibration tables give 5.43% excess return, 24.48% vol (Table 1) and the correlations in Table 3 |
| `beta`, `chi` | Placeholders, no sourced value yet |
| Box-3 regime | 36% on actual returns with no loss offset is in force; the wealth-tax alternative (`tau_wealth`) is off. Decide which regime the baseline represents |
| `sex = 3` pooling | Currently a plain mean of the men's and women's series. Participation-weighted? Does a single-earner household want pooled individual wages, or household labour income? |
| `tau_inc` | Should eventually be an effective average rate computed along the model's own income profile, not a single national statistic. DHS net over gross income at 25 (calibration notes, Table 3: 30,563 / 39,749 owners, 22,474 / 30,094 renters) implies about 23% for owners and 25% for renters, against the 38.2% the income-tax step applies |

## 3. Where welfare is read

`V_tilde` is read at a single entry state, `b0` years of income in liquid
wealth. Earlier work found the verdict on the DC pension changing sign with the
entry buffer, and at `phi_floor = 1e-6` welfare levels do not converge. This
waits on 1. When it is taken up again: justify the anchor on its own terms
(or integrate over an initial-wealth distribution), and read arm-versus-arm
differences rather than levels.

## 4. Bequest

- The baseline sets `chi = 0`, which contradicts the paper's stated rationale
  for housing wealth. With no bequest, no equity access and no sale, the
  owner's house is purely a cost-saving device. Pick one: give `chi` a value,
  or change the rationale.
- When `chi > 0` the bequest base is liquid wealth plus gross housing, with no
  mortgage netting. Cocco and Yao–Zhang net out the debt. With the annuity the
  balance is known from q, so the netting can be added with `chi > 0`.
- The terminal-period bequest is inconsistent with the recursion's: the
  recursion discounts by `beta` and applies one period of returns, the terminal
  step does neither. Dormant while `chi = 0`, wrong the moment it is switched
  on.

## 5. Model features not implemented

- **Income persistence.** The process is a pure random walk, and there is no
  transitory shock. Partial persistence needs a fourth state dimension. If a
  transitory shock is added, retirement income must be keyed to the permanent
  component, as in CGM.
- **Free DC investment choice and glide-path comparisons.** Implemented on the
  research branch, parked until 1 is settled. The annuity there is priced off
  the plan's glide, not the chosen share; say which question a comparison
  answers.

## 6. Numerics

Parked (Quinn, 18 October 2026): all grid and interpolation work waits on
item 1. At step 16 no owner grid converges at any age, since refining u3 makes
owners hoard into retirement, and the error near the floor sits in the
interpolation or the model rather than the grid (HANDOFF.md, 18 October).

- `docs/SOLVER_BOUNDS.md` lists every limit in the solver and the simulation
  that is not part of the economics. Open there: the sweep's consumption
  step; the policy stored at grid points below the floor; a counter for
  non-finite values. (The consumption-search bound is now the floor, see
  item 1.)
- Early-life convergence waits on 1; no numerical lever fixes it.
- The retirement equity share needs nodes where retirees live, at low u1.
  `utility.auto_state_grids` places them from a simulated panel (GRIDS.md);
  from a trusted panel it beat hand-set values, from its own coarse pilot it
  did not. Not yet the default. For the DC steps see the next item.
- The DC steps 9-12 are not converged on the ladder's standard grid
  (HANDOFF.md, 16 October 2026): liquid saving 16-37% too high at 60
  (about double at 66 at steps 10-11), consumption 3-11% too high at 66, while step 6 is
  converged on the same grid.
  Points bunched toward low u1 and u2 near 1 (`grid_pow` 3, `grid_pow_u2` 3)
  with `pi_nothing_saved = 'limit'` converge: 32x32 is within about 1% in
  consumption, 48x48 within the stop rule. The same placement converges the
  owner at housing step 7b (16x16) and at step 13 (24x24); there u3 also
  needs points near zero (`grid_pow_u3 = 2`) for the oldest owners
  (`docs/HANDOFF_2026-10-17.md`). To decide: the defaults of
  `pi_nothing_saved` and `grid_pow_u3`; whether `ladder.numerics` carries the
  placement (every saved ladder result would re-solve); whether points that
  follow age (`grid_nodes.u1_age`, tried at step 12 only) stay as an option.
- The global (c, pi) sweep is most of the solve time. A cheaper search that
  keeps its accuracy would make the fine grid routine. At step 13 dropping it
  (`use_refine = false`) keeps the answer within the stop rule and halves the
  time; at the DC steps (12 October) it moved the equity share by up to 0.4.
  To decide: keep it everywhere or drop it per step. Kept for production
  (Quinn, 24 October 2026): at step 16 with the absorbing floor, dropping it
  lands on the wrong choice at 1-10% of grid points and moves the mean
  equity share by about 0.04 at 66 and 90 (one-step test, HANDOFF 24 October).

## 7. Paper write-up

- **Taxes.** The DC advantage is EET plus the box-3 shelter; state the
  mechanics, including the missing loss offset on the liquid account.
- **Franchise.** Never stated, although `kappa_t` depends on it: EUR 18,475
  (1-1-2025, art. 18a lid 3 Wet LB).
- **Price year.** 2025: the DHS income cubic is in 2025 euros, as is the
  franchise.
- **Entry state.** The initial liquid buffer is unstated and drives results.
- **Off-by-ones.** The DHS sample ends at 65, so the cubic is extrapolated one
  year to 66, the last working year; `tau` has `T-1` transitions.
- **Equation (27).** The mean of `eps` is written `+0.5 sigma^2`; the code uses
  `-0.5 sigma^2`.
- **Annuity formula.** Use the recursion the code uses,
  `a_t = 1 + p_t a_{t+1} / E[R^A]`, framed as a variable annuity with assumed
  interest rate `E[R^A]`.
- **Coordinates.** State the cube the model is solved on, and never call `W`
  wealth for renters, whose `W` includes the rent index.
- **Behaviour to state.** The DC return carries a survival credit from 25; the
  retirement-transition income shock is zero; the mortgage is a real annuity,
  not the Dutch fixed nominal payment; the first pillar is `replacement * Y_66`, not a flat
  AOW, which makes planner results somewhat pessimistic.
- **Minor.** Housing volatility "3.7^2%" should be 3.7%; the wealth tax "1.97"
  is missing a percent sign; the ECB MIR series is the all-mortgages
  cost-of-borrowing indicator. Typos: morality, piller, dditionally, perioding,
  yiels.
