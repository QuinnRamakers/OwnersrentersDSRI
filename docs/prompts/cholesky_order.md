# Prompt: the order of the correlated draws, and retired ages without the income draw

Saved on 13 November 2026 on main, after `fast_power`. Not started.
Background: `docs/RUNTIME_2026-11-13.md` and the three log entries of
12 November in `HANDOFF.md`.

## To start

Open Claude Code in the repository checkout, with the UM VPN on and `oc`
logged in, and paste:

"Read docs/prompts/cholesky_order.md and follow it. Start with the
session-start skill. Run solves and timings on the DSRI, not on this PC. Stop
for me after the measurements of part 1, before any change to production."

## The problem

`grids.shock_grid` builds four correlated draws from four independent sets of
Gauss-Hermite nodes with a Cholesky factor, in the order income, stock, house,
REIT. The first draw enters all the others:

    income = Z1
    stock  = corr_SL * Z1 + ... * Z2
    house  = (Z1, Z2, Z3)
    REIT   = (Z1, Z2, Z3, Z4)

After 66 income has no shock (`sigma_l_log` is zero from the transition 66 to
67 on), so a retired age reads the stock, house and REIT draws only. But the
income node is inside those three, so all 625 joint nodes differ and all are
evaluated. Two consequences:

1. Retired ages cost 5 times what three draws would (625 nodes for 125).
2. Retired ages depend on the income correlations through the quadrature
   points. Between the correlations before and after 9 November
   (`corr_SL` 0.04 and 0.34) the median node moves by 2e-5 to 5e-5 in the
   certainty equivalent and 0.01 to 0.02 in the equity share.

The model does not change in anything below: the same joint normal
distribution, the same correlations. Only the points at which it is evaluated
change, so results move by a quadrature-level amount and are not identical in
every bit.

## What is known (12 November, one-step replay, retired ages)

Rules at 5 nodes a draw. A5: the repo's. B5: three draws, order stock, house,
REIT. B5hrs: three draws, order house, REIT, stock. Reference: three draws at
15 nodes.

1. The correlations between stock, house and REIT on the nodes are 0.24,
   0.76, 0.17 to 12 digits under every rule.
2. Median gap to the reference in the certainty equivalent per unit of
   wealth: A5 and B5 1.7e-5 to 1.0e-4; B5hrs 0.6e-5 to 2.6e-5. The 99th
   percentiles are alike (1e-2 to 5e-2).
3. B5 against A5: 1e-6 with the old income correlations, 2e-5 to 5e-5 with
   those of 9 November.
4. Time per node with stocks and the REIT in the fund: B5 3.4 to 4 times
   lower than A5.
5. Three draws in the order (stock, house, REIT) are the same points as four
   draws with income last, once the nodes that differ only in the income node
   are evaluated once.

## Decisions for Quinn, before code

1. Which ages change. (a) From the transition 66 to 67 on only: ages 25-65
   keep today's points. (b) One rule at every age with income last: simpler,
   but the working ages move too. Not measured.
2. The order of the other three. Stock last was closest to the reference in
   retirement. Not measured at working ages.
3. Whether equal nodes are evaluated once (identical in every bit, entry of
   12 November, item 5). It makes (b) cheap after 66 without a second rule,
   and gives 25 nodes for 125 where the fund holds no REIT.

## Part 1: measure, no production change

Extend the replay of `runs/perf_probe3.m` (not committed; on Quinn's PC in the
worktree's `runs/perf_probe/`, and on the pod in
`/Solutionstorage/OwnersrentersDSRI_perf/runs/`):

1. Working ages (25, 34, 44, 54, 64), four draws, the orders: today's
   (income, stock, house, REIT); income last with (stock, house, REIT);
   income last with (house, REIT, stock). Reference: four draws at 9 nodes
   each on a smaller sample of nodes. Report the gap of each to the reference
   and to today's rule, as on 12 November.
2. Use solves under the calibration of 9 November if they exist by then;
   otherwise replay the saved solves with the income correlations of
   9 November, as `perf_probe3n.sh` did.
3. Both tenures. Renters have other correlations with the H shock (rent).
4. Time per node under each rule.

Stop and report to Quinn.

## Part 2: the change, as a numerics switch

1. A primitive in `config.params` for the rule (for example `shock_order`,
   with today's order as one value), its source in CALIBRATION.md.
   `ladder.same_calibration` reads a missing field as today's order. A case
   suffix in `diagnostics/pension_grid/case_params.m`.
2. `grids.shock_grid` builds the joint nodes in the chosen order. If (a): a
   second set of joint nodes for the ages without an income shock, and
   `solver.bellman_step_lna` picks it where `profile.sigma_l_log(t) == 0`.
   `pension.annuity_price` and the simulator read the marginals and their own
   draws; check that nothing else reads `shocks.joint`
   (`model.checks` does, for the node correlations).
3. If decided: evaluate equal joint nodes once and copy back before the
   weighted sums. The copy of `runs/perf_probe2.m` shows the lines.
4. With today's order selected the code must reproduce a saved solve in every
   bit (with `_mpow` for solves saved before 13 November).

## Checks that must pass

1. `run_tests(solve=false)` and the full `run_tests`, with new checks: the
   correlations and the moments of the log returns on the nodes equal their
   inputs to 1e-12 under every order and for both tenures; with today's order
   the shock grid is unchanged in every bit; after 66 the nodes do not depend
   on the income correlations under the new rule.
2. On the pod: with today's order, a saved solve reproduced in every bit.
3. Full solves under each rule on `pow3_32x8_lim_u3n40_qn4_as_nc11_gh5_beqb25`,
   owners and renters, for the production fund and for a fund that holds
   stocks and the REIT after 67 (`_g100`): solve time by age, the simulated
   age profiles side by side, the entry value, `model.checks`, and the gaps
   node by node. `runs/pow_check/pow_check.m` prints this table for
   `fast_power` and can be adapted.
4. Report behaviour, not welfare levels (CLAUDE.md).

## Limits

1. Do not change `gh_n`, the grid, the sweep or fmincon here.
2. Compare rules only inside one MATLAB run: the pod's speed varies by 30-50%
   between days.
3. The one-step replay shows single ages on grid nodes. The effect on the age
   profiles needs the full solves of check 3.
