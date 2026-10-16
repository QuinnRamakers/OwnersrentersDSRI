# Prompt: grid test at step 13, housing with the pension

Saved on 16 Oct 2026. Not started. To start, open a Claude Code session on
this repo (branch main) and point it to this file.

## Goal

Find out whether the grid fix of 16 October converges at step 13 (housing
with AOW and the DC pension), and how long each grid takes. Then, if time is
left, check how much the answer depends on the global grid search that runs
before fmincon.

Quinn asked for three things:
1. Convergence stability at step 13 on the bunched grid.
2. The run time of every grid size.
3. If time is left: stability with and without the grid search (the global
   (c, pi) sweep before fmincon, `use_refine`).

The quadrature stays at 5 nodes per shock in every run (`gh_n = 5`).

## Read first

1. CLAUDE.md (the working rules).
2. HANDOFF.md, the 16 October log entries: the grid study of the DC branch
   (overnight), the five-page summary, and the step-7b housing test (code,
   expectations, results).
3. GRIDS.md, sections "The DC steps" and "Axes that collapse".

## What is known

1. Pension steps 9-12 (no housing): the ladder's standard grid (evenly spaced
   16x16) is not converged. Two numerical fixes, merged but not defaults:
   points bunched by a cube on both axes (`grid_pow = 3`, `grid_pow_u2 = 3`)
   and `pi_nothing_saved = 'limit'`. With them 48x48 is within the stop rule.
2. Step 7b (housing, no pension), with maintenance on the purchase price:
   the same fix works. The owner is within the stop rule already at 16x16
   (bunched 64x64 is the reference; log-wealth 64x48 agrees with it). The
   renter converges slowly on every grid rule, because young renters hoard
   against the rent (TODO.md item 1); that is economics, not the grid.
3. Without the grid search the equity share lands in the wrong basin at some
   nodes. On 12 October, at the DC steps, it was off by 0.28-0.43 at ages
   26-28 and up to 1.0 at 95 (HANDOFF.md, "Retirement steps 9-12").

## Why step 13 is different

With both housing and a pension, u3 (the pension pot against the house) is a
live axis. It has 10 base points, and owners also carry the mortgage axis q
(9 points). Neither of the exact speed-ups of 16 October applies: they skip
grid points that only exist when there is no house or no pension.

Grid points per solve, at 16x16: renter 18 x 18 x 10 = 3,240; owner
18 x 18 x 10 x 9 = 29,160 (step 7b owner: 2,916 solved). Doubling u3 doubles
these.

Rough solve times, one process alone, scaled from step 7b:
- renter: 16x16 about 8 min, 24x24 about 15, 32x32 about 30, 48x48 about 65;
- owner: 16x16 about 1 h, 24x24 about 2 h, 32x32 about 3.5 h;
- u3 doubled at 16x16: renter about 16 min, owner about 2 h;
- without the grid search: about a third shorter.
Running two processes at once gave about 1.4 times the throughput on this
16-core PC; more than two did not help. Measure, and report the real times.

## Runs

Step 13 is `ladder.params('pension')`. Use maintenance on the purchase price
(the variant without the ruin cliff) and the limit share in every run. Case
names follow `diagnostics/pension_grid/case_params.m`:
`<rule>_<N1>x<N2>` plus suffixes `_lim` (limit share), `_mop`
(maintenance on the purchase price), `_u3x2` (u3 doubled) and `_nosweep`
(`use_refine = false`). Every case keeps `gh_n = 5`.

In this order, smallest first, so early answers come quickly:
1. Renter: `pow3_16x16_lim_mop`, `pow3_24x24_lim_mop`, `pow3_32x32_lim_mop`,
   `pow3_48x48_lim_mop`.
2. Owner: `pow3_16x16_lim_mop`, `pow3_24x24_lim_mop`, `pow3_32x32_lim_mop`.
3. The u3 check, both households: `pow3_16x16_lim_mop_u3x2`.
4. If time is left, the grid search, both households: `pow3_16x16_lim_mop_nosweep`
   against `pow3_16x16_lim_mop`; for the renter also at 32x32.

How to run (it is how the step-7b test ran):
- `diagnostics/pension_grid/solve_cases.m` takes strings
  `"13:<arm>:<case>"` and saves each result to
  `ladder/standard_16x16x10x8_gh5/pension_grid/13_pension_<arm>_<case>.mat`,
  skipping cases already saved for the same calibration.
- Run two MATLAB `-batch` processes in the background, each with a list of
  cases, with `CGM_OUTPUT_DIR` set to the repo root and both
  `diagnostics/pension_grid` and `diagnostics/grid_design` on the path.
  For example, process A: owner 16, 24, 32; process B: renter 16, 24, 32,
  48, then the u3 and grid-search checks.
- Read `model.checks` on every solve (floored share, off-grid, entry value).

## What to report

1. For each household, the largest gap of each grid to the finest one solved,
   by age band (26-39, 40-66, 67-95): mean consumption (%), the equity share
   of liquid saving (savings-weighted, `case_load` adds it as `piw`) and
   liquid savings in years of income (`case_gaps`). Compare with the stop
   rule (2% in consumption, 0.02 in the share). Say which grid is the
   smallest that passes, per household.
2. The solve time of every run, and whether it ran alone or beside another.
3. u3 doubled against u3 at 10 points: does the pension-against-house axis
   need more points?
4. With and without the grid search: the largest gaps, and where (ages).
5. Pages in the house style, as for step 7b
   (`diagnostics/pension_grid/housing_pdf.m`). That script is written for
   step 7b ("7b" and the case lists are fixed in it); give it a step
   argument rather than copying it. Quinn wants interim pages as runs land,
   so send an updated PDF after each batch.

## Rules for the session

1. Write the expectation into HANDOFF.md before the runs (the repo's
   custom), commit and push; write the results entry after, with the numbers
   and the commit hash.
2. Do not change any default (`pi_nothing_saved`, the ladder's grid, `gh_n`).
3. Figures first, plain short sentences, no tables where a figure will do.
4. Commit by naming files; never `git add .`; push to main.
