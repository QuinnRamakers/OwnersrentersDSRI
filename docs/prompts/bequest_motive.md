# Prompt: testing the bequest motive (chi > 0), on the university cluster

Saved on 26 October 2026 on main, after the absorbing floor was adopted
(ladder step 18). Not started.

## To start

1. On the cluster pod (DSRI OpenShift), set the two environment variables and
   fetch the code, as in `bootstrap_pod.m` (from the MATLAB console) or
   `setup_cluster.sh` (from a terminal):
   `CGM_OUTPUT_DIR` is the mounted persistent volume (for example
   `/Solutionstorage`), `GITHUB_TOKEN` a GitHub token with read access to
   QuinnRamakers/OwnersrentersDSRI, kept in an OpenShift Secret, never in a file.
2. Open Claude Code in the repository checkout and paste:
   "Read docs/prompts/bequest_motive.md and follow it. Start with the
   session-start skill. Ask me before every test run or solve. Stop for me
   after the code and tests, and after each set of runs."
3. Before writing code, ask Quinn the open decisions below.

## Where production stands

`config.params` equals ladder step 18 (`floor`):

1. Owners pay maintenance of 1.5% of the purchase price (step 17; steps 7-16
   use the current house value).
2. The absorbing consumption floor at c_min = EUR 5,000 (step 18; steps 1-17
   have the yearly top-up at 1e-6 of income).
3. Grid `[32 16 40 4]`: u1 and u2 bunched (`grid_pow = 3`, `grid_pow_u2 = 3`),
   u3 evenly spaced, q at 4 base points, `pi_nothing_saved = 'limit'`,
   `gh_n = 5`.
4. Search: the (c, pi) sweep, then fmincon active-set with `N_c = 11`.
5. `chi = 0`: no bequest motive.

The grid was chosen with `chi = 0` (`docs/HANDOFF_2026-10-26.md`): u2 and q
change nothing, u3 matters most, u1 moves young households, and nothing
settles before about 35-40. A bequest motive raises old-age wealth, so the u3
and u1 axes may need a second look once it is on.

Saved solves (`*.mat`) are gitignored and are not on the cluster: every result
is solved fresh there.

## Goal

Switch on a bequest motive and see what it does to both tenures: consumption
and saving into old age, the house, the equity share and bankruptcy, shown as
life cycles. Settle the functional form and the rule for bankrupt households
first; then find what `chi` does across a range of values; the value itself
needs a source.

## What the code does now

1. The bequest is a warm glow, `chi * b^(1-gamma)/(1-gamma)`, on the wealth
   left at death. In `+solver/bellman_step_lna.m` it enters each period as
   `beq_eff = beta * (1 - p_t) * chi` (in `bellman_rhs`, `sweep_cpi` and the
   top-up branch), and in the terminal period as a closed-form split between
   consumption and the bequest.
2. The bequest base `b` is liquid saving after consumption plus
   `(1 - sell_cost) * H` for owners (`sell_cost = 0.025`); renters bequeath
   liquid wealth only. The DC pot is not bequeathed: its return carries the
   survival credit.
3. `+simulate/paths_lna.m` records `sim.bequest`; `model.summarize` reports its
   mean and median.
4. A bankrupt household (absorbing floor) has no bequest term at all: its
   value is `u(F) * D_t`.

Known problems, all dormant while `chi = 0` (TODO.md, item 4):

1. The bequest base is not netted for the outstanding mortgage. With the
   annuity the balance is known from q and the years since purchase.
2. The terminal-period bequest is inconsistent with the recursion's: the
   recursion discounts by `beta` and applies one period of returns, the
   terminal step does neither.
3. With `gamma > 1`, a bequest of zero is worth minus infinity. Solvent
   households near zero are clamped at a tiny base (a huge penalty), while
   bankrupt households get no bequest term, which makes bankruptcy look
   relatively attractive once `chi > 0`.

## Decisions open (default in brackets)

1. The form. [A luxury-good warm glow as in De Nardi (2004),
   `chi * (b + b_bar)^(1-gamma)/(1-gamma)`, with the shifter `b_bar` a share
   of permanent labour income so the model stays homothetic, as the floor
   does] or the pure form without a shifter.
2. Bankrupt households. [They leave nothing and get the bequest utility of
   zero wealth, `chi * b_bar^(1-gamma)/(1-gamma)`, at each death probability:
   a closed form like `D_t`, no new state] or no bequest term, as now.
3. The values of `chi` and `b_bar`: from the literature, with Quinn. Until
   then, a range for the tests.
4. Mortgage netting. [Net the outstanding balance from the house.]
5. The DC pot at death before retirement. [Not bequeathed, as now.]

## Plan, stopping for Quinn after each step

1. Read HANDOFF.md, `docs/HANDOFF_2026-10-26.md`, CALIBRATION.md (Timing, mortality, preferences;
   Housing, Consumption floor) and TODO.md item 4. Add a log entry; any new
   input is a primitive in `config.params` with a row in CALIBRATION.md.
2. Before changing code, save a small-grid solve of the current production
   (both tenures, for example `p.grid_dims = [8 6 6 4]; p.gh_n = 3;`) at the
   starting commit as a baseline file outside the repository, and add a test
   that `chi = 0` reproduces it bit for bit (as `floor_off_identical` does).
3. Implement the chosen form, the bankrupt households' bequest, the mortgage
   netting and a consistent terminal step, all inert at `chi = 0`. Tests:
   the terminal split and the bankrupt value against their closed forms, the
   netted base against the balance from q, `chi = 0` identical. Run
   `run_tests(solve=false)` and the full `run_tests`.
4. Small-grid runs at a few values of `chi`, both tenures, to check the code
   does what it should. Then runs on the production grid on the cluster.
5. Before each set of runs, write the expectations into HANDOFF.md; after,
   the results with the numbers.
6. If old-age saving moves a lot, recheck u3 and u1 one axis at a time at
   the chosen `chi`, as in `diagnostics/nibud/axis_study_page.m`.

## Quinn's working rules

1. Ask before every run (tests and solves): the run list, the grid and the
   expected time. Wait for the OK.
2. Show results as life cycles by age, one line per run: `figures.compare`
   (income and housing costs for every run, bankruptcy by age) and
   `figures.dashboard`. Not gap-by-age plots or node-level diagnostics. Give a
   runtime table: run, grid points, solve minutes, search routine, how many
   solves shared the machine. Averages are over households not bankrupt,
   except consumption.
3. Plain, short sentences; numbered lists for plans.
4. Commit by naming files, never `git add .`; push to main.

## Cluster notes

1. `utility.cpu_quota` sizes the parallel pool to the pod's CPU quota, not the
   cores MATLAB sees; a pool sized to 128 cores on a pod capped at 32 ran
   about 7 times slower. `CGM_N_WORKERS` overrides it.
2. Results go under `CGM_OUTPUT_DIR` (`utility.output_dir`).
3. `floor_off_identical` reports SKIP on the cluster: its baseline file
   (`CGM_FLOOR_BASELINE`) is on Quinn's PC.
4. Run times on Quinn's PC (16 cores, two solves side by side), production
   grid at step 16 with the floor: owner about 4 hours with maintenance on
   the purchase price (about 100 minutes on the current value), renter about
   half an hour (estimated).
5. The grid-study scripts take a step number: `solve_cases` with
   `"18:owner:<case>"` builds on production (`case_params` suffixes in
   `diagnostics/pension_grid/case_params.m`; a `_chi<n>` suffix would need to
   be added).
