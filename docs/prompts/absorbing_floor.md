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
5. This reopens a settled decision. TODO.md item 1.4 and CALIBRATION.md
   ("Consumption floor") say the floor is a numerical bound at 1e-6 and not a
   calibration target (17 Oct). phi_abs is a model primitive, not a numerical
   bound. Both documents must say so once this is adopted.

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
