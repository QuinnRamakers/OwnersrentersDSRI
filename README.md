# Owners vs renters: life-cycle model with a DC pension

MATLAB solver for the *Owners vs Renters* paper (Balter, Koch, Ramakers,
Rodrigues, Schweizer). A partial-equilibrium life-cycle model of consumption
and portfolio choice, extended with a mandatory DC pension account and an
exogenously assigned housing tenure.

The question: a pension fund must pick one collective investment strategy for
participants whose risk capacity differs because some own their home and some
rent. How much does the one-size-fits-all strategy cost each type, and what
compromise strategy should the fund pick?

Requires MATLAB R2024b or later, plus the Optimization and Parallel Computing
toolboxes.

## The model in one page

A household enters at age 25, works until 67, and dies by 100 at the latest,
facing mortality risk throughout. It gets utility from non-durable consumption
only (CRRA, `gamma = 5`); housing is assigned, not chosen, so it enters as a
carrying cost and as bequeathable wealth rather than as a service flow.

Wealth sits in four places:

| | |
|---|---|
| `Y` | labour income, then AOW after retirement |
| `X` | liquid savings, split between a bond and equity |
| `A` | the DC pension account, annuitised at retirement |
| `H` | the house — owned or rented, but assigned either way |

The household chooses consumption and its liquid equity share each period. The
DC account's equity share is normally a fixed glide path set by the fund;
setting `p.choose_tau_S = true` hands that choice to the household instead,
which gives the upper bound the collective strategy is measured against.

Owners pay maintenance plus a mortgage rate on the current house value and
bequeath the house net of selling costs. Renters pay a rent-to-price fraction
and bequeath nothing from housing. Neither can move, sell, refinance, or
extract equity.

### Normalisation

The model is homothetic, so it is solved in shares of total wealth
`W = X + A + H + Y`:

```
lambda = Y/W     s_A = A/W     s_H = H/W     s_X = 1 - lambda - s_A - s_H
```

The state is the triple `(lambda, s_A, s_H)` on the simplex
`lambda + s_A + s_H <= 1`, and `V(W, state) = W^(1-gamma) * V_tilde(state)`.
That is what makes runs comparable without simulation noise: two runs starting
from the same normalised state are ranked exactly by `V_tilde` there.

One consequence worth remembering when writing up results: `W` includes the
rented house for renters, so it is a normaliser, not "wealth". Do not label it
as wealth in the paper or in plots.

### Solution method

Backward induction on the simplex grid. Each period:

1. Take the `z`-transform of the next period's value function,
   `z = ((1-gamma) V_tilde)^(1/(1-gamma))`, and build a trilinear interpolant
   on the full cube. Infeasible cube nodes are filled from their nearest
   feasible neighbour (`solver.build_fill_map`).
2. Grid-search consumption and equity share on a 41x41 grid over the joint
   Gauss-Hermite shock nodes, then polish with `fmincon` from the grid optimum.
3. Under free DC choice, the equity share becomes a third choice variable and
   the polish also runs pinned at the glide value, so free choice can never
   score below the glide.

The state loop is parallelised over feasible states.

## Running it

Set MATLAB's current folder to this directory, then:

```matlab
run_combined       % baseline: renter/owner x glide/free-DC, 4 solves
run_nodc           % kappa = 0 benchmark, same grid and calibration
```

`run_combined` writes `combined_{renter,owner}[_freetau].mat`; `run_nodc`
writes `combined_{renter,owner}_nodc.mat`. Each file carries the calibration
`p`, the profiles, the solved `sol`, 10,000 simulated paths `sim`, and a small
top-level `welfare0` struct so comparison scripts can read welfare without
loading the large arrays.

Both runners solve on a 25x15x15 state grid with `gh_n = 5`, deliberately
matching `run_spline_strategies` rather than the 40^3 / `gh_n = 7` grid in
`config.params`. Welfare values are only comparable across files solved on the
same grid at the same calibration, and this is the grid the strategy sweep
uses. Expect roughly ten minutes per scenario on 16 cores.

### Environment variables

| Variable | Effect |
|---|---|
| `CGM_OUTPUT_DIR` | Where `.mat`/`.png` outputs go. Defaults to `pwd`. Point it at a mounted volume on the cluster. |
| `CGM_N_WORKERS` | Force an n-worker process pool. Useful where the Threads profile is capped. |
| `CGM_STATE_GRID`, `CGM_GH_N` | Shrink the grid for smoke runs, e.g. `"12 10 12"` and `"3"`. Never set these for a production solve — the output is not welfare-comparable and the fingerprint will correctly refuse to rank it. |
| `CGM_GRID=lna` | Solve on the alternative `(u1,u2,u3)` cube grid instead of the simplex. Kept for cross-validation; the simplex grid is production. |

### Strategy sweeps

`run_spline_strategies` solves a list of glide paths, each defined by equity
fractions at three knot ages (25 / 67 / 99) joined by a monotone PCHIP spline.
`strategy.menu` builds the default family; files land as
`spl_<k1>_<k2>_<k3>_{renter,owner}.mat`.

`compare_spline_strategies` ranks everything on disk — the no-pension
benchmark, the free-DC arm, and every swept glide path — in one table per
tenure, with consumption-equivalent variations measured against no pension.

## Where welfare is read, and why it matters

`V_tilde` is read at a specific initial state, and the answer depends heavily
on which one. The natural-looking choice, a household with zero liquid wealth
at 25, turns out to be the worst one: with `gamma = 5` the mandatory
contribution cuts an already near-zero consumption level, and CRRA marginal
utility at near-zero consumption swamps everything that happens later. At that
corner the DC pension scores negative even in runs where it clearly raises
consumption at almost every subsequent age.

So the model reads welfare at a calibrated liquid buffer instead:

- `p.b0` — median bank and savings deposits of households whose main earner is
  under 25, divided by the age-25 wage. About 0.079 years of income.
- `p.b_alt` — the same using the 25–35 deposits cell, as a sensitivity. About
  0.228.

`config.insert_anchor_nodes` forces both onto the `lambda` and `s_H` grids as
exact nodes, so the headline number is a solved value rather than a trilinear
blend that drifts with grid resolution. `solver.solve_lifecycle` asserts this,
so a script that rebuilds the grids and forgets to re-anchor fails loudly.
Every other buffer in the sweep is interpolated and the curves through them are
visibly ragged; read differences between arms at a fixed buffer, where the
interpolation error is common-mode, rather than levels.

The choice of anchor is still an open question — see `TODO.md`.

## Comparability

`utility.param_fingerprint` builds a string from the grid dimensions and every
calibrated parameter. Two files are welfare-comparable only if their
fingerprints match, and the comparison scripts refuse to rank files that
disagree. This is not defensive decoration: a sweep once mixed stale
pre-calibration files with fresh ones and produced a plausible-looking, wholly
fictional result.

Contribution rate and DC-choice regime are deliberately excluded from the
fingerprint and returned separately, since those are exactly what the
comparisons vary.

## Layout

```
+config/     calibration, income profile, survival, contribution and
             decumulation paths, grid anchors
+grids/      Gauss-Hermite shock nodes
+pension/    unit-annuity price
+solver/     Bellman step, backward induction, infeasible-node fill map
+simulate/   forward Monte-Carlo paths
+strategy/   spline glide paths and the strategy menu
+utility/    welfare anchor and summary, fingerprint, grid helpers
tests/       acceptance checks
```

Anything ending `_lna` is the alternative cube-grid implementation.

### Scripts

| Script | Purpose |
|---|---|
| `run_combined` | Baseline four scenarios |
| `run_nodc` | No-DC benchmark |
| `run_spline_strategies` | Glide-path sweep |
| `run_dc_strategies` | Older fixed-rule sweep, superseded by the spline sweep |
| `compare_spline_strategies` | Rank all arms by welfare |
| `compare_strategy_vs_nopension` | Best glide path vs no pension, 12-panel check |
| `make_plots` | Per-scenario and renter-vs-owner dashboards |
| `final_summary_plots` | Review figures at a one-year buffer |
| `welfare_dc_vs_nodc`, `plot_welfare_vs_buffer` | Welfare against the initial buffer |
| `test_freetau_dominance_prod` | Free DC choice must weakly dominate the glide, per state |
| `tests/smoke_fill_fix` | Acceptance checks for the continuation-fill behaviour |
| `verify_income_profile` | Checks the BKV income table path against expected values |

### Data

`CBSunisexmortality21-26.csv` holds CBS one-year death probabilities for
2021–2026, sexes combined. `Coefficients_probability_survival.xlsx` is the
older sex-specific table, kept only to reproduce pre-2026-07 runs.

## Cluster notes

`bootstrap_pod.m` installs MATLAB onto the persistent volume and fetches the
code into ephemeral storage, so a restarted pod can be brought back from the
MATLAB console alone. `setup_cluster.sh` and `install_matlab.sh` are the
shell equivalents. Set `CGM_OUTPUT_DIR` to the mounted volume before launching,
or results are lost when the pod restarts.
