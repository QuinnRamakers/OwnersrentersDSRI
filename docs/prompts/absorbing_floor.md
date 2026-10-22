# Prompt: the consumption floor as an absorbing state

Saved on 22 Oct 2026 against 7b5143d. Not started. The decisions marked open
below are Quinn's; the recommended choice is listed first. To start, open a
Claude Code session on this repo and point it to this file.

## Goal

Replace the yearly top-up at the floor with an absorbing state. A household
whose liquid resources fall below a higher floor goes bankrupt. From then on
it consumes the floor every year until it dies, and makes no further choices.

Quinn's request (22 Oct): "set a higher consumption floor and then force
people to consume this for the rest of their life".

## Why

1. Today the floor is 1e-6 of income. A floored state's certainty equivalent
   is of the order of the floor, four to five orders of magnitude below its
   neighbours. Linear interpolation in z fills in that trough and prices
   states next to ruin as too mild: by tens of percent in working life and by
   factors up to 1e6 in old age (HANDOFF.md, 18 Oct, "does the interpolation
   misprice the ruin corner?"). Refining the grid moves the trough but does
   not remove it.
2. A higher floor under today's rule is a different problem: the shortfall is
   forgiven every year and the household keeps its house, pot and income. The
   floor becomes free insurance that can be drawn every year. At step 7 the
   floor bound more often as it rose (45% of owners at 95 at a floor of 0.5;
   TODO.md, item 1).
3. An absorbing state makes ruin costly but bounded. Its value is known in
   closed form, so it adds no state variable, and the trough becomes shallow.
   A bankrupt household is worth a constant phi_abs * Y for life. A solvent
   renter at step 16 consumes about 0.4-0.7 of entry income (medians at 40,
   66 and 95, HANDOFF.md, 20 Oct). The trough in z is that ratio: a factor of
   3-7 at phi_abs = 0.10-0.15, against four to five orders of magnitude today.

## The model, formally

Notation as in README.md. LW_t is liquid resources before consumption:
X_t + take-home income + net annuity - housing cost, as now. Y_t is current
gross income (the AOW in retirement). B_t = 1 marks a bankrupt household.

1. Floor. F_t = phi_abs * Y_t, with phi_abs a new primitive.
2. Trigger. If B_t = 0 and LW_t < F_t, the household goes bankrupt in t:
   B_s = 1 for every s >= t. Call t* the year it enters.
3. Absorbing state. From t* on it consumes Cbar = phi_abs * Y_{t*} every year
   until it dies (open decision 1). It chooses nothing. Its liquid wealth,
   DC pot, house and later income go to creditors or the state. With chi = 0
   this is the same as keeping them unused, since they no longer affect
   utility.
4. Solvent households (B_t = 0, LW_t >= F_t) choose C_t and pi_t as now, with
   C_t in [F_t, LW_t] (open decision 2).
5. Value of the absorbing state, entered in t:
       V^B_t = u(Cbar) * D_t,   D_t = 1 + beta * p_t * D_{t+1},   D_T = 1,
   where p_t is one-year survival. D_t is deterministic: D = 22.3 at 25,
   16.8 at 55, 12.9 at 67, 4.1 at 90 (beta 0.96, CBS unisex table).
   Per unit of W^(1-gamma), with u1 = Y/W:
       V~^B_t(u) = (phi_abs * u1)^(1-gamma) / (1-gamma) * D_t.
   Homothety holds and no state is added.
6. Bellman equation for a solvent household:
       V_t(s) = max_{C, pi} u(C) + beta p_t E[ V_{t+1}(s') ],
   where V_{t+1}(s') = V^B_{t+1}(s') wherever LW_{t+1}(s') < F_{t+1}.
   Because LW_{t+1} depends only on next year's state, the household sees the
   trigger and can save to avoid it, or run its savings down into it.
7. Terminal period: unchanged in effect, since D_T = 1.
8. phi_abs = 0 switches the absorbing state off and gives today's model
   exactly: top-up at phi_floor = 1e-6, every year.

Homothety: the condition. Scaling X, A, H and Y by lambda must scale V by
lambda^(1-gamma). After bankruptcy V^B_t = Cbar^(1-gamma) / (1-gamma) * D_t,
which scales by lambda^(1-gamma) exactly when Cbar scales by lambda. So Cbar
may be any amount proportional to the household's own state at entry,
Cbar = W g(u, q, t), and it stays constant afterwards: once bankrupt there are
no choices, so the future needs no state. Constant over the remaining life is
not the difficulty. The level at entry is. A euro amount common to all
households does not scale with lambda, so it needs c_min / Y_t as a state
(option 2 below). Proportional to income at entry, Cbar = phi_t Y_{t*}, is
the natural homothetic choice (phi_t constant, or c_min / Ybar_t, option 1).

The continuation at a quadrature node, in the solver's units (per W_t, as in
`bellman_rhs`). With phi_{t+1} the floor share next year:
1. Next year's liquid resources:
   LW_n = X_next_W + y_{t+1} Y_next_W + a_{t+1} A_next_W - h_{t+1}(q_n) H_next_W,
   with y the take-home share of gross income next year
   ((1 - kappa_{t+1})(1 - tau_inc) working, 1 - tau_inc retired), a the net
   annuity rate ((1 - tau_inc) / ann_price(t+1) if retired at t+1, else 0),
   and h the housing cost rate at q_n.
2. If LW_n < phi_{t+1} Y_next_W, the node is bankrupt and its certainty
   equivalent is CE_n = phi_{t+1} Y_next_W D_{t+1}^(1/(1-gamma)), replacing
   W_growth * z_n. Otherwise the interpolated z as now.
3. LW_n depends on the choice (c, pi) through X_next_W, so the test runs inside
   `bellman_rhs`, for each candidate. It is a few vector operations.

What changes against today: today a household below the floor consumes
phi_floor * Y for that year only, saves nothing, keeps A, H and Y, and is back
in the ordinary problem next year. Under the new rule the first time is the
last.

## Decisions open

1. The consumption level after bankruptcy.
   a. Fixed at phi_abs * Y_{t*}, the income of the year it enters
      (recommended to start: Quinn's words, and D_t needs no expectation).
   b. Indexed to the household's own income, phi_abs * Y_s. It falls to
      phi_abs times the AOW at 67. Still closed form: D_t then carries
      E[(Y_{t+1}/Y_t)^(1-gamma)] each working year and replacement^(1-gamma)
      at 67.
   With (a), a household bankrupt at 60 keeps phi_abs times its wage, about
   3.3 times phi_abs times the AOW, for life. Check whether bankruptcy then
   bunches just before 67. If it does, (b) is the fix.
2. The lower bound of consumption for solvent households.
   a. phi_abs * Y_t (recommended: the floor is a floor, and the trigger, the
      bound and the absorbing level are one number).
   b. phi_floor * Y_t = 1e-6 Y_t, as now. Solvent households could then cut
      consumption below the floor to stay out of bankruptcy.
3. The trigger.
   a. Involuntary only, LW_t < F_t (recommended; Quinn's request).
   b. Also a choice to declare bankruptcy: V_t = max(solve, V^B_t). Larger
      change, not needed now.
4. The level of phi_abs, to be sourced and added to CALIBRATION.md. Upper
   limit: liquid resources at entry are about 0.33 Y for owners and 0.42 Y for
   renters at step 16 (by hand from config.params: take-home 0.556 and 0.574,
   housing cost 0.308 and 0.233, plus b0 = 0.079). Above about 0.2 young
   owners with no savings go bankrupt after one or two bad income shocks.
   Candidates 0.10, 0.15, 0.20. CALIBRATION.md already notes that floors of
   0.10-0.20 make early life well behaved under the top-up rule.
   Quinn (22 Oct): the floor should be a subsistence level, a constant euro
   amount. See "The floor in euros" below.
5. This reopens a settled decision. TODO.md item 1.4 and CALIBRATION.md
   ("Consumption floor") say the floor is a numerical bound at 1e-6 and not a
   calibration target (17 Oct). phi_abs is a model primitive, not a numerical
   bound. Both documents must say so once this is adopted.

## The floor in euros

Quinn (22 Oct): the floor should be a minimum subsistence level, which is a
constant euro amount. The model is homothetic: V(W, u) = W^(1-gamma) V~(u).
That removes one dimension, the scale. A euro amount brings the scale back, so
an exact euro floor always costs one state. The options trade that state
against accuracy.

Numbers by hand (Python, from the DHS cubics in config.params):
- Deterministic income Ybar, owners: EUR 39,763 at 25, 1.74 times that at 40,
  1.84 at 55, 1.66 at 66; first pillar 0.307 Ybar_66 = EUR 20,256. Renters:
  EUR 30,098, 1.63, 1.71, 1.64; first pillar EUR 15,182.
- Income is a random walk, so log(Y_t / Ybar_t) has sd sigma sqrt(t - 1):
  0.32 at 40, 0.45 at 55, 0.52 at 66 (owners; renters 0.33, 0.46, 0.54).
  The 10th and 90th percentiles of Y_t / Ybar_t are 0.67 and 1.50 at 40, and
  0.51 and 1.95 at 66 and through retirement.

Options:

1. A floor along the deterministic income profile (no new state). A new
   primitive `c_min` in 2025 euros. `config.derive` makes the path
   phi_t = c_min / Ybar_t for each tenure, with Ybar in retirement equal to
   replacement * Ybar_66. phi_t is deterministic, so homothety holds. The
   floor is c_min exactly for a household on the profile, and c_min * Y_t /
   Ybar_t for the others: 0.51 to 1.95 times c_min between the 10th and 90th
   percentiles from 66 on. It is too low for the households with bad income
   shocks, who are the ones nearest it. With the absorbing state (decision 1a)
   a household bankrupt at t* consumes c_min * Y_{t*} / Ybar_{t*} for life.
   That is c_min before and after 67 alike, which removes the problem in
   decision 1 of a wage-level floor locked in before 67. It also meets the
   objection in CALIBRATION.md that a proportional floor "guarantees 62% of a
   rising wage": phi_t falls as the profile rises.
   Variant: take Ybar_t from households below the median (for example the
   median income of households near the floor in a simulated panel). The floor
   is then closer to c_min where it binds and too high for everyone else. The
   path would depend on a solution, so it must be stored as a primitive
   vector with its source, not derived.
2. An exact floor, with one more state, f = c_min / Y_t. It moves as
   f' = f / G' in working life, f' = f / replacement at 67, and is constant
   after. Like q it does not depend on choices, so next year's f at each
   quadrature node is known; only the interpolation along f is approximate.
   V(W, u, q, f) = W^(1-gamma) V~(u, q, f); the absorbing value is
   (f u1)^(1-gamma) / (1-gamma) * D_t. Grid in log f, about 5-7 nodes, with
   the entry value c_min / Y_25 as an exact node. Run time times N_f.
   - Renters have one q node, so f can take the fourth axis. That generalises
     the q code; it adds no dimension.
   - Owners need a fifth axis while the mortgage runs (25-54). Every array and
     interpolant goes from 4D to 5D.
   - The same state allows a flat AOW in euros (TODO.md, item 7, "the first
     pillar is replacement * Y_66, not a flat AOW"). With a flat AOW, f is the
     same for every retiree, so it collapses to one node from 67, as q does
     after the mortgage.
3. Retirement is already close. Y is constant after 67, so phi * Y is a
   constant euro amount for each retiree. It differs across retirees only
   through Y_66, by the factors above. Option 1 uses this; option 2 with a
   flat AOW makes it exact.

Without a new state (Quinn, 22 Oct: no new state variable). Cbar must be
proportional to something already in the state: Y, H, A, X, or q H = H0 for
owners while q is live. Every household of a tenure enters with the same Y0,
so the same H0 = h_mult Y0, and H0 is a common euro amount. The question is
which of these stays closest to a fixed euro amount over life. 10th-90th
percentile of the variable over its median path (Python, from config.params):

| age | income Y | rent index (renters) | house value (owners) | q H = H0 (owners) |
|---|---|---|---|---|
| 40 | 0.66-1.52 | 0.92-1.09 | 0.67-1.49 | 1 |
| 66 | 0.50-2.00 | 0.86-1.16 | 0.52-1.93 | 1 |
| 100 | 0.50-2.00 | 0.82-1.22 | 0.41-2.44 | 1 |

(log sd: income 0.082-0.084 a year to 66; rent index 0.0177; house 0.0804.)

1. Income, Cbar = phi_t Y with phi_t = c_min / Ybar_t (option 1 above).
   Both tenures, all ages. V~^B = (phi_t u1)^(1-gamma)/(1-gamma) D_t.
2. Renters: the rent index, Cbar = phi^R_t H with phi^R_t = c_min / Hbar_t,
   Hbar_t = H0 exp(mu_R (t-1)), H0 = 4.16 x EUR 30,098 = EUR 125,208 at step
   16. V~^B = (phi^R_t s_H)^(1-gamma)/(1-gamma) D_t, s_H = u2 (1-u1)(1-u3).
   Rents have a small shock, so the floor stays within 0.82-1.22 of c_min to
   100, and it hardly depends on income luck (corr_HL_rent 0.06).
3. Owners: the purchase price, Cbar = (c_min / H0) q H, exactly c_min for
   every owner (H0 = 4.45 x EUR 39,763 = EUR 176,945 at step 16).
   V~^B = ((c_min/H0) q s_H)^(1-gamma)/(1-gamma) D_t. At a quadrature node
   q_n H_next_W = q s_H, so the floor in units of W_t is the same at every
   node, as a euro amount should be. q is a state only while the mortgage
   runs (25-54). After that, either:
   a. keep q live to 100. No new variable, the q axis is already there, but
      every owner period is solved on it: roughly twice the owner's run time
      (estimate from step 7b: 366 s with q for 30 years, 83 s without), or
   b. switch to option 1 from 55 (spread 0.55-1.81 at 55), or
   c. the house value, not recommended (wider than income in old age).
4. Any mix a_t Y + b_t H + c_t q H is also homothetic. The single best
   variable per tenure is simpler and already close.

The H-based floors are zero on the grid's edges where H = 0 (u2 = 0 or
u3 = 1). No household with housing reaches them, but their value would be
-inf. Those nodes need a fallback, for example the income-based floor.

A floor tied to H raises the bar for households whose housing cost is high
relative to their income, which is what a euro floor does too: the trigger is
X + y Y < (housing cost rate + floor rate) H.

Dutch policy basis (searched 22 Oct; secondary sources, the statute texts not
read line by line):
1. The level. The bijstand norm (Participatiewet art. 21) is 70% of the net
   minimum wage for a single adult and 100% for a couple. The minimum wage and
   the benefits tied to it move twice a year with average contract wages (the
   koppeling). So the Dutch floor is a common euro amount tied to economy-wide
   wages, not to the household's own income. The model has no aggregate wage
   growth, so the matching choice is c_min constant in real 2025 euros. The
   norm pays for housing, with huurtoeslag and zorgtoeslag on top, so the
   after-housing minimum is roughly the same whatever the rent. The
   rent-index floor (option 2) is a numerical stand-in for that fixed amount,
   not a policy feature.
2. Debtors. The beslagvrije voet (Wet vereenvoudiging beslagvrije voet, 2021;
   art. 475da ff. Rv) protects 95% of net income for incomes at or below the
   bijstand norm, rises with income for middle incomes (components that replace
   allowances a debtor no longer gets), and is capped (single without
   children EUR 2,208.48 a month from 1 July 2026). At the bottom it is a
   share of the debtor's own income, so it supports the income floor
   (option 1) for low-income households.
3. Bankruptcy. The Wsnp lasts 18 months as standard since 1 July 2023 (was 3
   years; extendable, at most 3.5 years at admission). The debtor lives on the
   protected amount, assets are sold, usually including the house, and the
   remaining debt is then discharged (schone lei). It is not absorbing.
   Occupational pension rights cannot be surrendered or pledged (Pensioenwet),
   so creditors do not get the DC pot; to be checked for the Wsnp. A closer
   version for renters without a new state: k years at the floor (k = 2 for
   18 months), then back in the ordinary problem with X = 0 and A, H and Y as
   they evolved. Its value is a no-choice backward recursion on the existing
   grid, k extra arrays per age, provided the floor each year is proportional
   to that year's state (rent index or income). Owners would leave the house,
   and the model has no move from owner to renter, so owners stay absorbing.
4. Owners on bijstand. Where home equity exceeds the exemption, bijstand is
   paid as a loan secured on the house (Participatiewet art. 50; the
   exemption is in art. 34 and municipal rules). Owners keep the house and
   draw on its equity. That is equity release, TODO.md item 1.1, not
   bankruptcy.
5. Retirees. The AOW is the minimum for those over 67, tied to the net minimum
   wage, with the AIO topping up an incomplete AOW. The model's first pillar
   is 0.307 Y_66 rather than flat, so a retirement floor at the household's
   own AOW is homothetic but inherits its spread across households.

Decision (Quinn, 22 Oct): the floor is linked to labour income. The
rent-index and purchase-price floors (options 2 and 3 without a new state) are
dropped: not defensible in a paper. No new state variable.

The labour-income floor. Income is a pure random walk with no transitory
shock, so current labour income is permanent labour income. Y^L_t is labour
income in working life and final labour income Y_66 in retirement. The
model's Y in retirement is the first pillar, 0.307 Y_66, so Y^L_t = Y_t / 0.307
from 67 on, and the floor stays a function of the state.
1. Floor: F_t = phi_t Y^L_t. Trigger: LW_t < F_t.
2. After bankruptcy at t*: Cbar = F_{t*} for life,
   V~^B_t = (phi_t u1 / r_t)^(1-gamma) / (1-gamma) * D_t, with r_t = 1 in
   working life and 0.307 in retirement.
3. Two ways to set phi_t:
   a. One share, phi_t = phi for all t. One primitive, the simplest to state:
      "the floor is phi times permanent labour income". For the median
      household the floor in euros moves with the profile: 1.74, 1.84 and
      1.66 times its entry value at 40, 55 and 66 for owners (renters 1.63,
      1.71, 1.64), and stays at the 66 value in retirement.
   b. A share by age, phi_t = c_min / Ybar^L_t, with c_min a primitive in
      2025 euros and Ybar^L_t the median labour income path of the tenure
      (frozen at 66 in retirement). The floor equals c_min for the median
      household at every age: "the floor is a share of permanent labour
      income, set by age so that it equals the social minimum at median
      income". phi_t relative to phi_25: 0.58, 0.54, 0.60 at 40, 55, 66 for
      owners (renters 0.61, 0.58, 0.61), and the 66 value in retirement.
4. In both, a household with income luck x = Y_t / Ybar_t gets x times the
   median's floor: 0.50-2.00 between the 10th and 90th percentiles from 66
   (the income figure of 22 Oct). That is the price of homothety. Defence: the
   standard treatment in models normalised by permanent income, and the
   beslagvrije voet, which protects 95% of the debtor's own net income at low
   incomes (Dutch policy basis, item 2).
5. Y > 0 everywhere on the grid (the u1 axis starts above 0), so no node has a
   floor of zero; the edge problem of the H-based floors does not arise.
6. Same c_min for both tenures (one policy); phi_t then differs by tenure
   only because the income profiles do. Alternative: the same phi.

Recommended: 3b with the same c_min for both tenures. It is still one primitive
(c_min) and it matches the euro minimum where most households are.

The euro amount. The floor in the model is consumption after housing costs.
The social minimum pays for housing too. The bijstand norm (Participatiewet,
21 to AOW age) on 1 January 2025 was EUR 1,345.45 a month for a single adult
and EUR 1,922.07 for a couple, including holiday allowance (the Rijk's
Normenbrief 2025, as reproduced by municipalities, for example Leeuwarden's
Geldgids). That is EUR 16,145 and EUR 23,065 a year, with huurtoeslag and
zorgtoeslag on top. Whether the model's household is a single or a couple is
open (TODO.md, item 2, `sex = 3` pooling). So c_min is what is left at
the social minimum after rent net of huurtoeslag and other fixed costs. Nibud's
minimum example budgets give this split; a source still has to be chosen.
Nibud's mortgage norm, which sets h_mult at step 16, is built from Nibud's own
spending budgets, so taking c_min from Nibud would keep the two consistent
(to be checked). Scale: the single bijstand norm is 0.41 of an owner's gross
income at 25 and 0.54 of a renter's (couple: 0.58 and 0.77). The model's cash after housing at entry
is 0.33 Y and 0.42 Y. Whatever c_min turns out to be, young households start
close to it. The model's first pillar for the median renter, EUR 15,182 gross,
is below the net single bijstand norm.

## Code changes, file by file

1. `+config/params.m`: one line, `p.phi_abs = 0;` (0 = off). `phi_floor`
   stays as the numerical guard and the top-up when `phi_abs = 0`.
2. `+config/derive.m`: assert `phi_abs == 0 || phi_abs > phi_floor`. Derive
   `p.D_abs` (T x 1) from `beta` and `config.survival(p)`. With decision 1b,
   also the income terms. `model.checks` computes the same sum for
   `ce_entry`; reuse it there.
3. `+solver/bellman_step_lna.m`:
   1. The floor used by the step: `phi_abs` when it is positive, else
      `phi_floor`. It sets `F_W`, so the trigger and the search's lower
      bound `c_floor` (decision 2a) move together.
   2. The floored branch (`if LW_W <= F_W`): with `phi_abs > 0`, the value is
      `F_W^(1-gamma)/(1-gamma) * p.D_abs(t)` and there is no continuation.
      Store c = 1 and pi = 1 as now.
   3. The terminal period needs only the floor in step 1.
   4. Optional, second stage: test the trigger exactly at each quadrature node
      in `bellman_rhs`. Next year's LW over W_t is
      `X_next_W + take-home(t+1) * Y_next_W + net annuity(t+1) - h_cost(t+1, q_n) * H_next_W`.
      Where it is below `phi_abs * Y_next_W`, use V^B_{t+1} directly instead
      of the interpolated z. Then the bankrupt side of the edge is exact, and
      only cells that straddle it on the solvent side are interpolated across
      it. This needs `kappa`, the retirement flag, `ann_price` and the
      housing cost of t+1 inside the step.
   5. The header comment.
4. `+simulate/paths_lna.m`: an absorbing flag per household. In the year of
   entry and every year after, C = phi_abs * Y_{t*}, no policy lookup, and
   X, A and H are 0 from the next year on. Skip bankrupt households in the
   off-grid counts (their u1 is 1 once W = Y, above the top of the u1 axis).
   New fields: `absorbed` (N x T, true from the year of entry) and
   `abs_age` (N x 1, age at entry, NaN if never). `floored` is true in every
   absorbed year, so `floored_by_age.m` (20 Oct) reads the share at the floor.
5. `+model/summarize.m`: `floored` stays the share at the floor; add
   `abs_hazard`, the entry rate among those not yet bankrupt, by age.
   Wealth and the equity share over solvent households only; consumption over
   all. `at_c_bound` already excludes floored households.
6. `+model/checks.m` and `print_checks.m`: the share bankrupt at 40, 67 and
   100; entry rates by phase; a note when bankruptcy bunches in the five years
   before 67 (decision 1). `ce_entry` keeps its formula.
7. `+figures/dashboard.m`, `step_dashboard.m`, `compare.m`, `robustness.m`,
   `+ladder/report.m`: the label "floored" becomes "bankrupt" when
   `phi_abs > 0`. Check that a NaN equity share for bankrupt households does
   not break a panel.
8. `+ladder`: no code change. First runs as a sensitivity of step 16,
   `ladder.sensitivity(16, vary=struct('phi_abs', [0.10 0.15 0.20]))`. If
   adopted: append step 17 `absorbing` with `struct('phi_abs', x)` and set
   `config.params` to the same x in the same commit (`run_tests` checks that
   the last step equals production).
9. `tests/run_tests.m`, new checks:
   1. `phi_abs = 0`: both tenures, small grid, V, policies and panel
      bit-identical to 7b5143d.
   2. `p.D_abs` equals the explicit discounted survival sum to 1e-12.
   3. At a node with LW < phi_abs Y, the solved V equals the closed form to
      1e-12.
   4. In the panel, a bankrupt household stays bankrupt, its consumption is
      constant from entry, and none is counted off the grid.
   5. `derive` rejects 0 < phi_abs <= phi_floor.
10. Documents: CALIBRATION.md, "Consumption floor" (phi_abs, its source and
   value); TODO.md item 1.4; README.md, "Each period" and "Reading the
   results"; `docs/SOLVER_BOUNDS.md`, the consumption bound;
   CLAUDE.md's known limits once the runs say what is converged.

## Checks that must pass

1. `run_tests(solve=false)`, then the full `run_tests`: 0 failures, with the
   new checks.
2. Every solve: `model.checks` read and reported (`c_bound_25_39`,
   `ce_entry`, `offgrid`, the bankrupt shares).

## Runs, one at a time, stopping for Quinn after each

Write the expectations in HANDOFF.md before each run.

1. Step 16, both tenures, `phi_abs` 0.10, 0.15 and 0.20, standard numerics
   and the summary grids of 20 Oct. Expect: `ce_entry` of the order of
   phi_abs or above (today far below 0.05); `c_bound_25_39` near 0; the
   bankrupt share at 100 for owners with maintenance on the current value at
   least the 36% floored at 100 today, since maintenance still outruns the
   AOW; renters far lower.
2. The 18 Oct grid comparison again, owner and renter, at the chosen
   phi_abs: summary grid against 24x24 and u3 at 20. This is the test of the
   change. It passes when the grids agree within the stop rule (2 points in
   the equity share, 2% in consumption) from 25 on.
3. `diagnostics/pension_grid/ruin_interp.m` at the chosen phi_abs: the
   corner's gap should fall from 1e4-1e6% to tens of percent at most.
4. If run 2 fails near the edge: implement change 3.4 (exact trigger at the
   quadrature nodes) and repeat runs 2 and 3.
