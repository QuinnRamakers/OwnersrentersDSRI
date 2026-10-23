# Prompt: the consumption floor as an absorbing state, linked to labour income

Saved on 23 Oct 2026 against 031e081 (branch claude/dreamy-edison-1814gg; the
last code commit is 7b5143d, the same as main). Not started. This replaces the
exploratory version of 22 Oct. That history is in git (39c869c to 031e081) and
in the HANDOFF.md log entries of 22 Oct.

## To start

1. Bring this file onto main (cherry-pick, as with `mortgage_state.md`).
2. Open Claude Code on the repo where MATLAB runs, and paste:
   "Read docs/prompts/absorbing_floor.md and implement it. Start with the
   session-start skill. Copy the spec into HANDOFF.md under Specs in short, as
   on 15 Oct. Stop for me after the code and tests, and after each run."
3. Before the runs, ask Quinn the open decisions below. The code does not
   depend on them, except decision 4.

## Goal

Replace the yearly top-up at the consumption floor with an absorbing state.
A household whose liquid resources fall below the floor goes bankrupt. From
then on it consumes the floor every year until it dies and makes no further
choices. The floor is a share of permanent labour income. No new state
variable.

## Decisions taken (Quinn, 22 Oct)

1. Absorbing. Once below the floor, bankrupt for the rest of life. Lifetime
   utility from then on is the discounted, survival-weighted sum of utility
   at the floor.
2. The level is fixed in the year of bankruptcy and stays constant.
3. No new state variable.
4. The floor is linked to labour income. Floors tied to the rent index or to
   the purchase price were considered and dropped: not defensible in a paper.
5. The floor stands for the social minimum net of housing costs. The Dutch
   bijstand norm is a common euro amount, which a homothetic model cannot
   carry without a state. So the floor is a share of permanent labour income,
   set to match a euro amount at median income (open decision 1).

## Decisions open (default in brackets)

1. How the share is set. [(b) by age, phi_t = c_min / Ybar_t, so the floor is
   c_min for the median household at every age] or (a) one share phi at all
   ages. The code supports both.
2. [The same c_min for both tenures: one policy, so phi_t differs only because
   the income profiles do] or the same phi.
3. The value and source of c_min. Suggested source: the Nibud minimum example
   budgets, spending after housing at the bijstand level. That also settles
   single or couple (TODO.md, item 2). Until it is set, the runs use
   6,000, 8,000 and 10,000 euros a year.
4. Lowest consumption of a solvent household. [The floor: one number for the
   trigger, the search bound and the bankrupt level] or phi_floor * Y, as now.
5. The trigger. [Involuntary only.] Voluntary bankruptcy is not implemented.
6. Not needed now: with chi > 0 and gamma > 1 a bankrupt household that
   leaves nothing has a bequest utility of -inf. It needs a rule before chi
   is switched on (TODO.md, item 4).

## Why

1. Today the floor is 1e-6 of income. A floored state's certainty equivalent
   is four to five orders of magnitude below its neighbours. Linear
   interpolation in z fills that trough in and prices states next to ruin as
   too mild: by tens of percent in working life, by factors up to 1e6 in old
   age (HANDOFF.md, 18 Oct, "does the interpolation misprice the ruin
   corner?"). Refining the grid moves the trough but does not remove it.
2. A higher floor under today's rule is free insurance: the shortfall is
   forgiven every year and the household keeps its house, pot and income. At
   step 7 the floor bound more often as it rose (TODO.md, item 1).
3. An absorbing floor makes ruin costly but bounded, its value is a closed
   form with no new state, and the trough becomes a factor of a few: a
   bankrupt household is worth phi_t Y for life, a solvent renter at step 16
   consumes about 0.4-0.7 of entry income.

## The model

Notation. Y_t is the model's gross income: labour income to 66, the first
pillar 0.307 Y_66 from 67 (`p.replacement`). LW_t is liquid resources before
consumption: X + take-home income + net annuity - housing cost, as now.
Ybar_t is the deterministic profile, exp of `config.income_profile`, the
median household's Y.

1. Floor. F_t = phi_t Y_t, with phi_t from `config.derive`:
   - (b) phi_t = c_min / Ybar_t. In retirement Ybar_t = 0.307 Ybar_66, so the
     floor is tied to final labour income: c_min for the median retiree,
     c_min Y_66 / Ybar_66 for the others.
   - (a) phi_t = phi_abs to 66 and phi_abs / replacement from 67, that is
     phi_abs times final labour income.
   Like the contribution rate kappa, phi_t uses the deterministic profile,
   because only Y/W is a state.
2. Trigger. LW_t < F_t: the household goes bankrupt in t. Call it t*.
3. Bankrupt. It consumes Cbar = F_{t*} every year until it dies. Its liquid
   wealth, DC pot, house and later income are gone. With chi = 0 this changes
   no value.
4. Value of bankruptcy:
       V^B_t = Cbar^(1-gamma) / (1-gamma) * D_t,
       D_t = 1 + beta p_t D_{t+1},  D_T = 1,
   with p_t from `config.survival`. Per unit of W^(1-gamma), u1 = Y/W:
       V~^B_t(u) = (phi_t u1)^(1-gamma) / (1-gamma) * D_t.
   Homothetic, because Cbar is proportional to Y at entry. D_t is 22.3 at 25,
   16.8 at 55, 12.9 at 67 and 4.1 at 90 (beta 0.96).
5. Solvent (LW_t >= F_t): c and pi as now, with C_t in [F_t, LW_t]
   (decision 4).
6. Continuation: V_{t+1}(s') = V^B_{t+1}(s') wherever LW_{t+1}(s') < F_{t+1}.
7. Off: c_min = 0 and phi_abs = 0 give today's model exactly, the yearly
   top-up at phi_floor.

Paper wording, for (b): "A household whose cash on hand falls below a floor
goes bankrupt and consumes the floor for the rest of its life. The floor is a
share of permanent labour income, of final labour income in retirement, set by
age so that it equals the social minimum net of housing costs at median
income."

What it implies. A household with income luck x = Y/Ybar gets x times the
median's floor: 0.50 to 2.00 between the 10th and 90th percentiles from 66.
That is the price of homothety. Defence: the standard treatment in models
normalised by permanent income, and the Dutch beslagvrije voet, which protects
95% of the debtor's own net income at low incomes. Because the retirement
floor is tied to final labour income, not to the first pillar, the floor does
not drop at 67, in (a) or (b).

## Numbers to keep in mind

By hand (Python, from `config.params`), not model output.

1. Ybar, owners: EUR 39,763 at 25, 74,656 at the peak (50), 65,979 at 66;
   first pillar 20,256. Renters: 30,098, 52,013 (49), 49,452; 15,182.
2. Cash after housing at entry, with b0 = 0.079: owners 0.327 Y (EUR 13,003),
   renters 0.420 Y (EUR 12,641). c_min must stay well below EUR 12,600, or
   the median entrant is bankrupt in its first year.
3. phi_25 at c_min 6,000 / 8,000 / 10,000: owners 0.151 / 0.201 / 0.251,
   renters 0.199 / 0.266 / 0.332. In retirement, over the median's first
   pillar: owners 0.30 / 0.39 / 0.49, renters 0.39 / 0.53 / 0.66.
4. Renters at 67, median path: rent about EUR 10,500, net first pillar
   0.618 x 15,182 = EUR 9,382. The median renter's rent exceeds its net first
   pillar, so solvency in retirement rests on the DC annuity.
5. Owners with maintenance on the current value: 36% at the floor at 100
   under today's rule (HANDOFF.md, 20 Oct).

## Code changes, file by file

1. `+config/params.m`, in the floor block, one line each:
   - `p.c_min = 0;` floor after bankruptcy, 2025 euros a year at median
     labour income; 0 = off.
   - `p.phi_abs = 0;` the alternative: the floor as one share of permanent
     labour income; 0 = off.
2. `+config/derive.m`:
   - Assert c_min >= 0, phi_abs >= 0, not both positive. c_min > 0 needs
     income in euros, so refuse it with `income_source = 'poly'`, as
     `derive:poly_dc` does.
   - `p.floor_absorbing = p.c_min > 0 || p.phi_abs > 0`.
   - `p.phi_path` (T x 1): `c_min ./ Y_det`, or `phi_abs` with
     `/ replacement` from `t_ret`; with the absorbing floor off,
     `phi_floor * ones(T, 1)`. Where it is on, assert `phi_path > phi_floor`.
   - `p.D_abs` (T x 1) from `beta` and `config.survival(p)`.
   - The profile is the tenure's, so derive again after changing `is_owner`,
     as for kappa.
3. `+solver/bellman_step_lna.m`:
   - `p.phi_path(t)` replaces `phi_floor` in `F_W`, so the trigger and the
     search's lower bound `c_floor` move together.
   - The floored branch (`if LW_W <= F_W`) with the absorbing floor on: the
     value is `F_W^(1-gamma)/(1-gamma) * p.D_abs(t)`, with no continuation and
     no bequest. Store c = 1 and pi = 1, as now.
   - The terminal period: the floor from `phi_path(T)`. D_abs(T) = 1, so the
     value keeps its form.
   - The header comment.
   - With the floor off the arithmetic must stay the same, so that results
     are bit-identical.
4. `+simulate/paths_lna.m`:
   - An absorbing flag per household. In the year of entry C = F_t; after it,
     the same level every year. X, A and H are 0 from the next year on, and
     the bequest is 0.
   - No policy lookup for bankrupt households, and none counted off the grid
     (with W = Y their u1 is 1, above the top of the axis).
   - `F_t` from `p.phi_path(t)`.
   - New fields: `absorbed` (N x T), `abs_age` (N x 1, NaN if never).
     `floored` is true in every bankrupt year.
   - With the floor off: unchanged.
5. `+model/summarize.m`: `floored` is the share bankrupt; add `abs_hazard`,
   the entry rate among those not yet bankrupt, by age. Wealth, the equity
   share and `c_frac` over solvent households; consumption over all.
6. `+model/checks.m`, `print_checks.m`: the share bankrupt at 40, 67 and 100,
   and entry rates by five-year band. `ce_entry` keeps its formula; take D
   from `p.D_abs(1)`.
7. `+figures/dashboard.m`, `step_dashboard.m`, `compare.m`, `robustness.m`,
   `+ladder/report.m`: "floored" reads "bankrupt" when `p.floor_absorbing`.
   Check that a NaN equity share for bankrupt households breaks no panel.
8. `diagnostics/pension_grid/case_params.m`: a suffix `_cmin<euros>` (for
   example `_cmin8000`) that sets `p.c_min`, as `_mop` sets
   `maint_on_purchase`.
9. `tests/run_tests.m`, new checks:
   1. Off: step 16, both tenures, small grid (`CGM_STATE_GRID '8 6 6 4'`,
      `CGM_GH_N 3`): V, policies and panel bit-identical to 7b5143d. Solve
      at 7b5143d first and keep the result outside the repo.
   2. `p.D_abs` equals the explicit discounted survival sum to 1e-12.
   3. (b) `phi_path .* Y_det` equals c_min at every t to 1e-12 relative;
      (a) `phi_path` is phi_abs to 66 and phi_abs / replacement after.
   4. At a node with LW < F, the solved V equals the closed form to 1e-12
      relative.
   5. In the panel, a bankrupt household stays bankrupt, its consumption is
      constant from entry, and none is counted off the grid.
   6. `derive` rejects both positive, c_min > 0 with 'poly', and negative
      values.
10. Documents, in the same commits: CALIBRATION.md, "Consumption floor"
    (c_min, phi_abs, D_abs; the source of c_min once set); README.md, "Each
    period" and "Reading the results"; `docs/SOLVER_BOUNDS.md`, the
    consumption bound. When adopted: TODO.md item 1.4 (the floor becomes a
    model primitive), and CLAUDE.md's known limits once the runs say what
    is converged.

## Ladder

No code change. The runs are overrides of step 16. If Quinn adopts the floor,
append step 17 `absorbing` with `struct('c_min', x)` and set `c_min = x` in
`config.params` in the same commit; `run_tests` checks that the last step
equals production. On the ladder's own grid the sensitivity is
`ladder.sensitivity(16, vary=struct('c_min', [6000 8000 10000]))`.

## Checks that must pass

1. `run_tests(solve=false)`, then the full `run_tests`: 0 failures, with the
   new checks.
2. Every solve: read and report `model.checks` (`c_bound_25_39`, `ce_entry`,
   `offgrid`, the bankrupt shares).

## Runs

One at a time. Write the expectations in HANDOFF.md before each run, and stop
for Quinn after each. Grids: the 20 Oct summary grids, with `solve_cases`:
owner `pow3_16x16_lim_u3p2_qn4_nosweep` (maintenance on the current value) and
the same with `_mop`; renter `pow3_16x16_lim_u3p2_u3n20`. On 20 Oct the owner
took 649 s and 1,206 s with `_mop`.

1. c_min = 8,000, both tenures, both maintenance rules for the owner.
   Expectations:
   - `ce_entry` of the order of phi_25 (0.20 owners, 0.27 renters) or above;
     today 0.022 (owner, current value), 0.277 (owner, purchase price),
     0.174 (renter).
   - `c_bound_25_39` rises for owners with maintenance on the current value:
     today they consume 0.03-0.25 of entry income at 25-35, below the new
     floor.
   - Bankrupt share: owner, current value, large in old age, at least the
     18% at the floor at 90-100 today; owner, purchase price, small; renter,
     rising from 67 (number 4 above).
   - `offgrid` 0.
2. c_min = 6,000 and 10,000. Expect more bankruptcy, a higher `ce_entry`
   and less precautionary saving as c_min rises.
3. The grid test at c_min = 8,000, the test of the change, with the cases of
   the 20 Oct comparisons solved again at this c_min. Owner: the summary grid
   against 32x32 and against 24x24 with u3 at 20 points
   (`diagnostics/nibud/maint_grid_compare.m`). Renter: against 48x48 and
   against 16x16 with u3 at 40 (`diagnostics/nibud/renter_grid_compare.m`). It passes when the grids agree within
   the stop rule (2 points in the equity share, 2% in consumption) from 25 on.
4. `diagnostics/pension_grid/ruin_interp.m` at c_min = 8,000: the corner's
   gap should fall from 1e4-1e6% to tens of percent at most.
5. If run 3 fails near the floor's edge: the exact trigger below, then runs
   3 and 4 again.

## Later, if needed: the exact trigger at the quadrature nodes

In `bellman_rhs`, per unit of W_t:
1. Next year's liquid resources:
   LW_n = X_next_W + y_{t+1} Y_next_W + a_{t+1} A_next_W - h_{t+1}(q_n) H_next_W,
   with y the take-home share of gross income next year ((1 - kappa_{t+1})
   (1 - tau_inc) working, 1 - tau_inc retired), a the net annuity rate
   ((1 - tau_inc) / ann_price(t+1) if retired at t+1, else 0), and h the
   housing cost rate at q_n.
2. Where LW_n < phi_path(t+1) Y_next_W, the node is bankrupt:
   CE_n = phi_path(t+1) Y_next_W D_abs(t+1)^(1/(1-gamma)), in place of
   W_growth * z_n. Elsewhere the interpolated z, as now.
3. LW_n depends on (c, pi) through X_next_W, so the test runs for each
   candidate. It changes results, so it needs its own primitive (for example
   `abs_node_test = false`) for `ladder.same_calibration` to see it.

## Background: Dutch policy

Searched on 22 Oct; secondary sources, the statute texts not read line by
line.
1. The bijstand norm (Participatiewet art. 21) is 70% of the net minimum wage
   for a single adult and 100% for a couple, EUR 1,345.45 and 1,922.07 a month
   including holiday allowance on 1 Jan 2025. It moves twice a year with
   average contract wages (the koppeling), so it is a common euro amount. The
   model has no aggregate wage growth, so c_min is constant in real euros. The
   norm pays for housing too, with huurtoeslag and zorgtoeslag on top, so
   c_min is the part left after housing.
2. The beslagvrije voet (art. 475da ff. Rv, since 2021) protects 95% of net
   income at or below the bijstand norm, rises with income above it, and is
   capped (EUR 2,208.48 a month for a single without children from 1 July
   2026).
3. The Wsnp lasts 18 months as standard since 1 July 2023, then the remaining
   debt is discharged (schone lei). It is not absorbing, so a lifelong
   bankruptcy is a simplification. Pension rights cannot be surrendered or
   pledged under the Pensioenwet (to be checked for the Wsnp).
4. Owners on bijstand with home equity above the exemption get the benefit as
   a loan secured on the house (Participatiewet art. 50): equity release,
   TODO.md item 1.1.
5. The AOW is the minimum after 67. The model's first pillar is 0.307 Y_66,
   not flat.

Sources: Leeuwarden Geldgids 2025
(https://www.leeuwarden.nl/wp-content/uploads/2025/03/Inlegvel-Geldgids.pdf);
ESB on the koppeling (https://esb.nu/alsi27-0vvojtwklqymyjtwinze); rendement.nl
on the beslagvrije voet
(https://www.rendement.nl/loonbeslag/nieuws/hogere-maximumbedragen-beslagvrije-voet-per-1-juli-2026.html);
Bureau Wsnp on the 2023 change
(https://www.bureauwsnp.nl/publish/pages/10940/ingrijpende_wijzigingen_in_de_wsnp_vanaf_1_juli_2023.pdf);
Nibud minimum example budgets, July 2025
(https://www.nvvk.nl/l/library/download/urn:uuid:a0154979-3659-4407-8462-4009aab6144c/nibud+minimumvoorbeeldbegrotingen+juli+2025%5B13%5D.pdf).

## Limits

1. At step 16 the owner is not converged on any grid tried (CLAUDE.md, known
   limits). Report behaviour, not welfare, until run 3 passes.
2. The floor in euros moves with the household's income luck (0.5-2 times the
   median's from 66).
3. Nothing in this prompt has been run. It was written in a container without
   MATLAB.
