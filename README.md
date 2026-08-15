# Owners vs renters: life-cycle model with a DC pension

MATLAB solver for the *Owners vs Renters* paper (Balter, Koch, Ramakers,
Rodrigues, Schweizer). A partial-equilibrium life-cycle model of consumption and
portfolio choice, extended with a mandatory DC pension account and an
exogenously assigned housing tenure.

The question: a pension fund must pick one collective investment strategy for
participants whose risk capacity differs because some own their home and some
rent. How much does the one-size-fits-all strategy cost each type, and what
compromise strategy should the fund pick?

Requires MATLAB R2024b or later, plus the Optimization and Parallel Computing
toolboxes.

## The model in one page

A household enters at age 25, works until 67, and dies by 100 at the latest,
facing mortality risk throughout. Utility is from non-durable consumption only
(CRRA, `gamma = 5`); housing is assigned, not chosen, so it enters as a carrying
cost and as bequeathable wealth rather than a service flow. Wealth sits in
labour income `Y` (AOW after retirement), liquid savings `X` (bond + equity),
the DC account `A` (annuitised at retirement), and the house `H`.

The household chooses consumption and its liquid equity share each period. The
DC account's equity share is a fixed glide path set by the fund; setting
`p.choose_tau_S = true` hands that choice to the household instead, giving the
upper bound the collective strategy is measured against.

### Normalisation and state

Homothetic, so solved in shares of total wealth `W = X + A + H + Y`, with
`V(W, state) = W^(1-gamma) * V_tilde(state)`. Two runs from the same normalised
state are ranked exactly by `V_tilde`, without simulation noise.

## Solver

Backward induction. The **LNA cube** `(u1,u2,u3)` is the default coordinate
system: `u1 = lambda`, `u2 = (A+H)/(W-Y)`, `u3 = A/(A+H)`, every point of
`[0,1]^3` feasible, so no feasibility mask or infeasible-node fill is needed.
The `(lambda, s_A, s_H)` **simplex** is a maintained alternative, selected with
`setenv('CGM_GRID','simplex')`.

Each period z-transforms the next value function and optimises per state. The
default inner method (`p.polish_ver = 2`, `p.grid_mode = 'none'`) is
**warm-start + objective-scaling + fmincon**, with no grid search: the fmincon
polish is seeded from the `t+1` policy at the same node, and the objective is
scaled by the inverse median `|V|` so it sits inside the optimiser's tolerances.
Free DC choice (`choose_tau_S`) keeps a small equity-share grid so the free arm
can never score below the glide arm for the same continuation — the dominance
`tests/smoke_freetau_dominance_lna` checks. `p.grid_mode = 'full'` restores the
full `(c,pi)` tensor grid search. The state loop is parallelised.

## The pipeline

Solve a model given a strategy, then plot and compare the solved runs.

```matlab
run_combined      % renter/owner x glide/free-DC, 4 solves + sims
run_nodc          % kappa = 0 no-pension benchmark, same grid/calibration
```

Both write `combined_*[_lna].mat` carrying the calibration `p`, profiles, solved
`sol`, simulated `sim`, and a small `welfare0` struct so comparisons can read
welfare without loading the big arrays.

### Strategy sweeps

`run_spline_strategies` solves a list of glide paths, each a monotone PCHIP
spline through three knot ages (25 / 67 / 99). `strategy.menu` builds the default
family; `strategy.make_grid` builds an arbitrary one. Files land as
`spl_<k1>_<k2>_<k3>_{renter,owner}[_lna].mat`.

`compare_spline_strategies` ranks everything on disk — the no-pension benchmark,
the free-DC arm, and every swept glide path — in one table per tenure, with
consumption-equivalent variations measured against no pension.

### Plots

| Script | Produces |
|---|---|
| `make_plots` | Per-scenario dashboards + renter-vs-owner comparison from a solved arm (`CGM_ARM` = glide / freetau / nodc) |
| `final_summary_plots` | Life-cycle, equity-share and welfare-vs-buffer review figures across the no-DC / glide / free-DC arms |
| `plot_dc_equity_share` | The DC equity-share figure from the free-DC arm |

### Environment variables

| Variable | Effect |
|---|---|
| `CGM_GRID` | `lna` (default cube) or `simplex`. |
| `CGM_OUTPUT_DIR` | Where `.mat`/`.png` outputs go. Defaults to `pwd`; point it at a mounted volume on the cluster. |
| `CGM_N_WORKERS` | Force an n-worker process pool (useful where the Threads profile is capped). |
| `CGM_STATE_GRID`, `CGM_GH_N` | Shrink the grid for smoke runs (e.g. `"12 10 12"`, `"3"`). Never for a production solve — the fingerprint will refuse to rank it. |

## Comparability

`utility.param_fingerprint` builds a string from the grid dimensions and every
calibrated parameter; the comparison scripts refuse to rank files whose
fingerprints disagree, and record the coordinate system so cube and simplex runs
never rate as comparable to each other.

## Tests

`addpath tests; run_all` runs the fast acceptance checks; `run_all(slow=true)`
adds the solving checks (`smoke_freetau_dominance_lna`, `smoke_fill_fix`,
`smoke_rent_process`). Failure is signalled as a raised error, so
`matlab -batch "addpath tests; run_all(slow=true)"` exits non-zero on failure.

## Layout

```
+config/     calibration, income profile, survival, contribution/decumulation paths, grid anchors
+grids/      Gauss-Hermite shock nodes
+pension/    unit-annuity price
+solver/     Bellman step + backward induction, cube (_lna) and simplex
+simulate/   forward Monte-Carlo paths
+strategy/   spline glide paths and the strategy menu
+figures/    shared figure drawing
+utility/    welfare anchor and summary, fingerprint, grid helpers
tests/       acceptance checks + run_all
```
