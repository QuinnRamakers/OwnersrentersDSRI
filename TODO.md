# Open questions

What still has to be decided before the model is paper-ready. Resolved
decisions live in `CALIBRATION.md` and in git history; this file is only for
things that are still open. The research evidence referred to is on the
`solver-active-set` branch, in `diagnostics/`.

---

## 1. The consumption floor and the committed housing outflow

The decision everything else waits on.

At the production calibration a 25-year-old renter pays rent of about 44% of
net income (owners: maintenance and mortgage of a similar order), cannot reduce
it, and is protected by a floor of 1e-6 times income. With gamma = 5 that
leaves the early-life value function without a limit: refining the grid, the
quadrature or the node placement moves consumption and the equity share at
25-39 by factors of two to three, and the value at entry diverges. Scaling the
rent down to 11% of net income makes the model converge outright, so the cause
is the outflow, not the numerics. From 40 on, behaviour is stable.

Options, not mutually exclusive:

- **Set the floor to the social minimum.** `phi_floor` is a placeholder. A
  floor proportional to gross income cannot represent a level minimum
  (`phi_floor = 0.618` guarantees 62% of a rising wage and binds in 60% of
  household-years); 0.10-0.20 makes early life well behaved but binds in a few
  percent of years. A level floor in euros needs W as a state (about 40x the
  solve cost). Decide which floor the paper wants.
- **Make the outflow avoidable.** Let renters downsize, as in Yao and Zhang
  (2005), whose model has no such pathology. A modelling change.
- **Calibrate the outflow from data.** `h_mult` is a placeholder (see 2), and
  the owner's 100% LTV with almost no liquid wealth at entry is the starkest
  version of the same problem.
- **Report ages 40+ only** at the current specification, stating that
  accumulation is not identified.

Related: `c_floor_frac`, the lower bound of the consumption search, binds in
early life at this calibration and its effect changes sign across grids. It is
a modelling choice in disguise; decide it together with the floor.

## 2. Calibration inputs still missing

| Input | Status |
|---|---|
| `h_mult` | Placeholder 4.0. Replace with an income-contingent assignment fitted on LISS, with the Nibud loan-to-income tables as a feasibility ceiling |
| `kappa_base` | Single OECD figure. Want a participant-weighted aggregate across Dutch funds (DNB or Pensioenfederatie) |
| `sigma_l_log` | Borrowed from CGM. Needs a Carroll–Samwick or GMM decomposition on LISS income residuals |
| `corr_SL`, `corr_HL`, `corr_SH` | All zero. Estimable from LISS individual income and house-value growth against aggregate return series; the Cholesky plumbing is in place, so this is pure calibration |
| REIT moments and correlations | Placeholders with the same Sharpe ratio as equity; the leg is off |
| `beta`, `chi` | No sourced value yet |
| Box-3 regime | 36% on actual returns with no loss offset is in force; the wealth-tax alternative (`tau_wealth`) is off. Decide which regime the baseline represents |
| `sex = 3` pooling | Currently a plain mean of the men's and women's series. Participation-weighted? Does a single-earner household want pooled individual wages, or household labour income? |
| `tau_inc` | Should eventually be an effective average rate computed along the model's own income profile, not a single national statistic |

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
  mortgage netting. Cocco and Yao–Zhang net out the debt. Decide jointly with
  the mortgage contract.
- The terminal-period bequest is inconsistent with the recursion's: the
  recursion discounts by `beta` and applies one period of returns, the terminal
  step does neither. Dormant while `chi = 0`, wrong the moment it is switched
  on.

## 5. Model features not implemented

- **Income persistence.** The process is a pure random walk, and there is no
  transitory shock. Partial persistence needs a fourth state dimension. If a
  transitory shock is added, retirement income must be keyed to the permanent
  component, as in CGM.
- **Mortgage balance.** Deliberately not modelled; see `CALIBRATION.md`.
- **Free DC investment choice and glide-path comparisons.** Implemented on the
  research branch, parked until 1 is settled. The annuity there is priced off
  the plan's glide, not the chosen share; say which question a comparison
  answers.

## 6. Numerics

- Early-life convergence waits on 1; no numerical lever fixes it.
- The retirement equity share needs nodes where retirees live, at low u1.
  `utility.auto_state_grids` places them from a simulated panel (GRIDS.md);
  from a trusted panel it beat hand-set values, from its own coarse pilot it
  did not. Not yet the default.
- The global (c, pi) sweep is most of the solve time. A cheaper search that
  keeps its accuracy would make the fine grid routine.

## 7. Paper write-up

- **Taxes.** The DC advantage is EET plus the box-3 shelter; state the
  mechanics, including the missing loss offset on the liquid account.
- **Franchise.** Never stated, although `kappa_t` depends on it: EUR 18,475
  (1-1-2025, art. 18a lid 3 Wet LB).
- **Price year.** 2025: BKV amounts are 2015 euros, factor CPI(2025)/CPI(2015)
  = 1.3456 (CBS 83131NED).
- **Entry state.** The initial liquid buffer is unstated and drives results.
- **Off-by-ones.** BKV's last observed age is 64, not 65, and the code holds it
  flat over 65–66 only; `tau` has `T-1` transitions.
- **Equation (27).** The mean of `eps` is written `+0.5 sigma^2`; the code uses
  `-0.5 sigma^2`.
- **Annuity formula.** Use the recursion the code uses,
  `a_t = 1 + p_t a_{t+1} / E[R^A]`, framed as a variable annuity with assumed
  interest rate `E[R^A]`.
- **Coordinates.** State the cube the model is solved on, and never call `W`
  wealth for renters, whose `W` includes the rent index.
- **Behaviour to state.** The DC return carries a survival credit from 25; the
  retirement-transition income shock is zero; the mortgage is proportional to
  the current house value; the first pillar is `replacement * Y_66`, not a flat
  AOW, which makes planner results somewhat pessimistic.
- **Minor.** Housing volatility "3.7^2%" should be 3.7%; the wealth tax "1.97"
  is missing a percent sign; the ECB MIR series is the all-mortgages
  cost-of-borrowing indicator. Typos: morality, piller, dditionally, perioding,
  yiels.
