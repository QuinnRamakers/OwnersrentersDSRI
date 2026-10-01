# The per-node optimiser and the retirement equity share

The equity share in retirement depends on whether the per-node solver searches
pi globally. Optimiser settings cannot repair it, and it is not a quadrature
question: the retirement answer is unchanged at gh_n 3 and 5 and at every cube
resolution tested. This note records what was measured.

The accumulation phase is a separate problem with the same symptom. There the
optimal pi is still moving when the cube is refined from 384 to 4800 nodes, so
the early-life equity share is not converged and no search fixes it. Retirement
is a search problem; early life is a resolution problem. Both are set out
below.

## What the solver does at each node

`bellman_step_lna` has three stages, and the production configuration runs only
the middle one.

| stage | switch | production |
|---|---|---|
| brute-force 41x41x11 tensor grid search for the seed | `grid_mode` | off (`'none'`) |
| fmincon polish from that seed | `polish_ver` | on (active-set) |
| derivative-free search after the polish | `use_refine` | off |

`skip_tensor` is `grid_mode == 'none' && ~optimise_tau && use_warm`, so with the
imposed glide and `polish_ver = 2` the tensor is skipped and the seed is next
period's policy at the same node. That leaves a single fmincon call from a
single seed.

`refine_cpi_u` is misnamed. Its first round is

    p_loc = unique([linspace(0, 1, 21), p0]);

which sweeps pi across the whole unit interval. It is a global search in pi, not
a local refinement. So `use_refine` off vs on is not "polish vs extra polish" —
it is "no search in pi" vs "global search in pi".

## The two arms disagree about retirement

Renter, calibrated housing, redesigned grid, 4800 nodes, gh_n = 5, 6000 paths.

| | production | with refinement |
|---|---|---|
| equity share at 67 | 0.72 | 0.78 |
| equity share at 80 | 0.65 | 0.83 |
| equity share at 92 | 0.43 | 0.91 |
| direction through retirement | falling | rising |
| solve time | 357 s | 1900 s |

Consumption and wealth agree to 0.15% at every age, so the disagreement is
confined to the portfolio, which is the object of interest.

The refinement arm is the one to believe. A third arm using the full tensor grid
search reproduced it at the diagnostic node (pi = 0.4918 / 0.9051 / 1.000 vs
0.4918 / 0.9048 / 1.000), so two independent global searches agree and only the
single-seed arm dissents.

Comparing the two value functions in certainty-equivalent units, the refinement
arm is weakly better at 94% of nodes and worse at 1.8%. This is an optimisation
failure, not a tie.

## Where the failure is, and how expensive it is

CE shortfall of the production arm against the refinement arm:

| region | median | p90 | share of nodes above 1% |
|---|---|---|---|
| age 25 | 1.79% | 10.8% | 61% |
| age 44 | 0.26% | 5.1% | 29% |
| age 69 | 0.05% | 1.6% | 15% |
| age 89 | 0.01% | 0.5% | 7% |

The welfare cost is concentrated in early life; the typical retirement node
loses 0.02%, about sixty times less. Retirement is where the solver is wrong
cheaply, which is what makes the retirement share numerically fragile rather
than economically determined: a 30-48pp change in pi moves welfare by
hundredths of a percent. The direction is robust across the global searches;
the level should not be quoted precisely.

## It is basin trapping, measured directly

`bellman_step_lna` takes an optional `p.scan` that dumps the objective on a
dense (c, pi) grid at chosen ages and nodes, together with the seed, the grid
maximum, and where each optimiser lands. Every node was scanned at six
retirement ages, 9301 node-ages on a 14x14x8 cube.

Measure the problem on the profile that is actually left in pi once consumption
is optimised out,

    prof(pi) = max_c rhs(c, pi),

expressed as percent of certainty equivalent below the best pi at that node.
Distance in pi on its own is the wrong measure: it counts a node where the
profile is flat and the maximum happens to sit at a corner as a total failure.

| | share of node-ages |
|---|---|
| profile has more than one peak in pi | 24.8% |
| production solve loses more than 0.1% CE | 7.9% |
| production solve loses more than 1% CE | 2.3% |
| pi worth less than 0.01% CE, i.e. a tie | 10.6% |

The association with multimodality is almost exact: among the nodes where the
solve loses more than 0.1% CE, 99.1% have a multi-peaked profile; among the
rest, 18.5%. Where the profile has one peak the solver finds it.

These are measured on an 81 x 61 (c, pi) scan. A first pass at 21 x 41 gave
22.2%, 7.4%, 2.3% and 10.7%, so the structure is not an artefact of how finely
the objective is sampled. The solvers search c continuously and can therefore
beat the scan's own envelope; they do so at 88% of nodes but by a median of
0.001%, which is why the envelope is still usable as a reference.

By the raw pi-distance measure 30.6% of node-ages look like failures, but only
29.6% of those lose more than 0.1% CE. Roughly seven in ten are ties. The
honest failure rate is the 7.9% above, not 30.6%.

CE lost by each method against the same node optimum:

| method | median | p90 | loses more than 0.1% |
|---|---|---|---|
| active-set | 0 | 1.20e-3 | 10.5% |
| sqp | 0 | 1.30e-3 | 10.6% |
| interior-point | 0 | 1.99e-3 | 11.9% |
| active-set, FD step 1e-2 | 0 | 8.09e-4 | 9.5% |
| pi multistart from 5 seeds | 0 | 4.79e-4 | 8.1% |

## What does not work

Widening fmincon's finite-difference step from the default 1.5e-8 to 1e-2, a
full grid cell, changes the retirement share by 0.1pp and the failure rate by
0.7pp. The gradient is not the problem; a method that cannot leave its starting
basin stays put however well it measures the local slope.

Changing algorithm does not work either. sqp is indistinguishable from
active-set. Interior-point loses the most CE of the five, 11.9% of nodes above
the 0.1% threshold, while emitting `RCOND ~ 1e-18` singular-KKT warnings
throughout. Its close agreement with the refinement arm in the aggregate pi path
is large node-level errors partly cancelling, not accuracy, so it should not be
used.

Multistart over pi is the best of the local-start methods and still loses more
than 0.1% CE at 8.1% of nodes against the refinement arm's 0. It is a
mitigation, not a substitute, and at 435 s it costs more than the refinement it
fails to match.

Which method escapes a given trap is not stable. In the examples in
`S3_objective_landscape.png` the peak is found by the wide finite-difference
step at one node, by sqp at another, and by none of them at a third. No local
method is reliable; they differ in which nodes they happen to get right.

## How the refinement actually works, and where it stops

`refine_cpi_u` is four rounds. Round 1 evaluates pi at 21 points spanning the
whole interval while holding c near the seed; rounds 2 to 4 shrink a window by
a factor of four each time. The trajectory recorded inside the solver
(`S4_refinement_mechanism.png`) shows round 1 doing all the work: at nodes where
the seed is materially poor it accounts for a median 98.5% of everything the
four rounds recover, and rounds 2 to 4 move the answer by hundredths of a
percent.

It does not rescue everything. Taking the nodes where the seed sits more than
1% CE below the best pi, 5.8% of all node-ages:

| | share of those nodes |
|---|---|
| refinement recovers more than 90% of the gap | 68.0% |
| refinement recovers less than 10% of it | 15.4% |

The failures are the limit of the design: the sweep is global in pi but c stays
local to the seed, so a node whose seed has a bad c is not reached. That is the
case to keep in mind before treating the refinement arm as exact.

## Sweep before the local solve, not after

The shipped order runs fmincon from the warm start and sweeps afterwards, which
is backwards: the sweep is what locates the basin, so fmincon's work is done
from a seed that may be in the wrong one and is then discarded. Six arms on a
12x12x8 cube, gh_n = 3, 2000 paths, measured against the best arm at each node:

| arm | sec | median CE gap | pi@80 | pi@90 |
|---|---|---|---|---|
| A no sweep | 72 | -3.98e-3 | 0.662 | 0.391 |
| B sweep pi after (ships today) | 233 | -1.02e-3 | 0.913 | 0.956 |
| C sweep pi and c after | 278 | -5.21e-5 | 0.914 | 0.956 |
| D sweep pi before | 225 | -1.28e-3 | 0.913 | 0.956 |
| E sweep pi and c before | 274 | -7.7e-14 | 0.914 | 0.956 |
| F sweep c before | 213 | -3.59e-4 | 0.913 | 0.956 |

Reordering saves only 1-3% of runtime, because fmincon was never the expensive
part. What it buys is accuracy: E is exact to machine precision where C, the
same sweep run afterwards, leaves 5e-5. Sweeping first lets fmincon polish the
right basin; sweeping afterwards leaves the sweep's 21-point resolution as the
final answer.

Every arm that sweeps agrees on the policy to three decimals. Only A dissents.

F matters for the diagnosis: sweeping consumption alone, never pi globally,
recovers the whole retirement path and beats B. The basins are joint, so a wide
enough sweep in either variable escapes them. "pi is the trapped dimension" was
too specific.

## Widening the sweep to consumption

With c held within one grid cell of the seed the sweep misses nodes whose seed
has a bad c. On the 544 node-ages where the seed is more than 1% CE below the
best pi:

| | pi only | pi and c |
|---|---|---|
| recovers more than 90% of the gap | 68.0% | 76.7% |
| recovers less than 10% of the gap | 15.4% | 0.9% |

Of the 84 nodes the shipped sweep fails outright, adding c rescues 63% fully and
leaves none still failing.

## What to use

`use_refine = true`, `refine_stage = 'pre'`, `refine_c_global = true` — arm E.
Sweep both variables, before the local solve. `outcomes_solverfix.m` runs the
four production cells this way.

## Is the structure real? Two convergence tests

Both the cliffs and the basins come through an interpolated continuation value
computed with a finite quadrature, so either could be an artefact.

Cube resolution, gh_n held at 3, same physical state (0.20, 0.75, 0.33):

| cube | nodes | age 34: best pi / c | age 74: best pi / c |
|---|---|---|---|
| 8x8x6 | 384 | 0.458 / 0.244 | 1.000 / 0.427 |
| 12x12x8 | 1152 | 0.342 / 0.186 | 1.000 / 0.402 |
| 16x16x10 | 2560 | 0.183 / 0.181 | 1.000 / 0.436 |
| 20x20x12 | 4800 | 0.025 / 0.172 | 1.000 / 0.427 |

Retirement is converged: pi = 1.000 at every resolution. Early life is not: the
optimal pi walks from 0.458 to 0.025 with no sign of settling, while c converges
cleanly. So the accumulation-phase equity share is resolution-dependent
independently of any search question, and should not be quoted from these runs.

Quadrature, cube held fixed:

| cube | gh_n | best pi | best c | sec |
|---|---|---|---|---|
| 12x12x8 | 3 | 1.000 | 0.402 | 157 |
| 12x12x8 | 5 | 1.000 | 0.402 | 201 |
| 20x20x12 | 3 | 1.000 | 0.427 | 418 |
| 20x20x12 | 5 | 1.000 | 0.427 | 594 |

Identical to three decimals. Integration error is not the source, and the extra
40% of runtime buys nothing here.

## The corrected production runs

`outcomes_solverfix.m` re-solved the four cells with arm E at production
resolution (4800 nodes, gh_n = 5, 6000 paths), writing `outcomes_fixed.mat` and
leaving `outcomes.mat` untouched.

| cell | pi@80 | pi@90 | sec |
|---|---|---|---|
| renter x1.00 | 0.913 | 0.956 | 2500 |
| renter x0.25 | 0.998 | 1.000 | 2518 |
| owner x1.00 | 0.955 | 0.977 | 2456 |
| owner x0.25 | 0.998 | 0.998 | 2576 |

All four rise through retirement; the old runs had the renter falling from
about 0.65 to 0.39. Cheaper housing pushes the share to essentially one, which
matches the buffer-stock reading: a smaller committed bill needs less of a bond
holding against it.

## Consequence for the existing figures

`outcomes.m` sets `use_refine = false`, and the stored grid and housing runs
carry `refine = 0`. Every H1 sheet therefore shows the production arm, so the
row-3 equity panels are the trapped answer in retirement. The income,
consumption and wealth rows are unaffected. Re-solving the four `outcomes.m`
cases with refinement on is roughly two hours at production resolution.

## Files

Scripts, all taking an output directory and resuming from their `.mat`:

- `solver_compare.m` — production vs refinement vs full tensor, at production
  resolution
- `optimiser_study.m` — seven optimiser settings on a 12x12x8 cube
- `landscape_scan.m` — the scanning solve
- `ordering_study.m`, `ordering_dashboards.m` — sweep ordering
- `outcomes_solverfix.m` — the corrected production re-solve
- `resolution_objective.m`, `gh_robustness.m` — the convergence tests
- `fig_gradient.m`, `fig_surface_full.m`, `fig_earlylife.m` — the diagnostic figures
- `redraw_landscape.m` — the pi-profile figure
- `fig_refinement.m` — the refinement-trajectory figure

Figures in `factorial_figs/`:

- `S1_refine_vs_production.png`
- `S2_optimiser_sweep.png`
- `S3_objective_landscape.png`
- `S4_refinement_mechanism.png` -- how the refinement searches
- `S5_search_ordering.png` -- sweep before vs after
- `S6_gradient_and_basins.png` -- slope and basin map
- `S7_surface_unclipped.png` -- surfaces across ages, method landings
- `S8_early_life_search.png` -- the accumulation phase
- `S9_resolution_objective.png` -- objective vs cube resolution
- `S10_gh_robustness.png` -- objective vs quadrature
- `H1_fixed_*.png`, `H1_compare_*.png` -- corrected dashboards
- `H1_search_*.png` -- one dashboard per search routine

Solver hooks added for this work, all inert at their defaults: `p.fd_step`,
`p.pi_starts`, `p.scan`.
