# Life-cycle consumption and portfolio choice with a DC pension and housing

A Cocco, Gomes and Maenhout (2005) life-cycle model, calibrated to the
Netherlands, with a defined-contribution pension pillar and housing. A household
lives from 25 to at most 100, works until 67 and chooses each year how much to
consume and what share of its liquid saving to hold in equity. Labour income
follows a random walk around a deterministic age profile. Retirement income is
the state pension (AOW), a fixed share of final income, plus an annuity paid out
of the DC pot. The DC fund follows a glide path. A renter pays rent on a rent
index that grows on its own process; an owner holds a house financed by a
30-year annuity mortgage and pays maintenance. Housing is a passive asset: it
costs money each year and, for owners, can be bequeathed, but it is not chosen
and does not enter utility.

This branch is the working version for calibration. It keeps the model, the
solver configuration the research validated, and a ladder for changing the
calibration one step at a time. The research behind it is on the
`solver-active-set` branch (tag `research-2026-09`); see **History** below.

## Running it

MATLAB R2021a or later with the Optimization Toolbox. The Parallel Computing
Toolbox is optional: without it the solver runs serially and gives the same
numbers.

```matlab
run_model                          % production calibration, renter and owner
r = model.run(config.params());    % one tenure, results returned rather than saved
ladder.run('all', numerics='quick')
ladder.compare('housing', 'quick')
ladder.report('quick')
```

`run_model` writes `results_<tenure>.mat` and a dashboard PNG per tenure to
the output directory: `CGM_OUTPUT_DIR` if set, otherwise the current folder.
At the default grid (`p.grid_dims = [20 20 12]`, `gh_n = 5`) a tenure takes
about 8 minutes on 16 cores. For a quick look, shrink the grid through the
environment and clear it afterwards:

```matlab
setenv('CGM_STATE_GRID', '8 6 6'); setenv('CGM_GH_N', '3');
run_model
setenv('CGM_STATE_GRID', ''); setenv('CGM_GH_N', '');
```

Tests: `addpath tests; run_tests` (a few minutes).

## Changing the calibration

`config.params` holds the primitive inputs, one line each, and
`config.derive` builds everything that follows from them: return moments, the
retirement period, the glide path, the contribution profile, the mortgage
schedule and the state grid. Change a primitive, then derive:

```matlab
p = config.params();
p.phi_floor = 0.10;
p = config.derive(p);
run_model(p, tag='floor010')
```

Sources for every value are in [CALIBRATION.md](CALIBRATION.md).

### The calibration ladder

`ladder.steps` lists a sequence of calibrations. Each step changes a few
primitives on top of the steps before it:

| step | name | change |
|---|---|---|
| 1 | `cgm` | CGM core: gamma 10, CGM income cubic, 68% replacement at 65, r 2%, equity vol 15.7%; no housing, pension or taxes |
| 2 | `gamma5` | risk aversion 5 |
| 3 | `retire67` | retirement at 67 |
| 4 | `income` | Dutch income profile (BKV), in euros |
| 5 | `market` | Dutch real rate 1.1%, equity vol 16% |
| 6 | `housing` | housing at 4x entry income: renter and owner from here on |
| 7 | `pension` | AOW at 30.7% of final wage, DC contributions, glide, annuity |
| 8 | `inctax` | EET income tax at 38.2% |
| 9 | `box3` | box-3 tax at 36% on the liquid account, no loss offset |

Step 9 is `config.params()` exactly; `run_tests` checks this. To change the
calibration, edit a value in a step or append a step after `box3` (a floor
level, a housing multiple from data, the REIT leg). `ladder.params(k)`
returns the calibration at step k, and an override that names a field that is
not a primitive is an error.

`ladder.run` solves a step for each tenure it has, at numerics held fixed
along the ladder so that differences between steps come from the calibration:

| numerics | grid | gh_n | households | step with housing and DC, per tenure (16 cores) |
|---|---|---|---|---|
| `quick` | [12 12 8] | 3 | 4,000 | under a minute; the whole ladder in 6 minutes |
| `standard` | [16 16 10] | 5 | 10,000 | about 4 minutes |
| `fine` | [20 20 12] | 5 | 10,000 | about 8 minutes |

Steps 1-5 have no housing. Their u2 and u3 axes cannot move, so they collapse
to two nodes and solve in seconds; step 6 has no DC pillar yet and collapses
u3. Results are saved under
`<output dir>/ladder/<numerics>/` as `NN_<name>_<tenure>.mat`, each with a
dashboard. A saved step is reused until its calibration changes; editing a
step re-solves it and every step after it on the next `ladder.run`.
`ladder.compare(k)` overlays step k on step k-1 and prints the main
quantities. `ladder.report` tabulates every saved step. Levels in both are in
multiples of entry income, because step 1 uses CGM's income units.

## Reading the results

The research behind this branch established the following, and the checks in
`model.checks` report the relevant numbers for every run (`r.checks`, printed
after each solve and shown on the dashboard).

- **From age 40 on, behaviour is reliable.** Consumption, wealth and portfolio
  choices moved by 2-3% across every grid, quadrature and placement setting
  tried.
- **The retirement equity share needs the global search.** With a local solve
  from the warm start alone, fmincon settles on the wrong local peak at about
  8% of retirement nodes, and the simulated share falls through retirement when
  it should rise. `p.use_refine = true` (the default) sweeps (c, pi) before
  fmincon at every node.
- **At the production calibration, ages 25-39 are not converged.** Rent of
  about 44% of net income at 25 (owners: maintenance and mortgage of about
  41%), a floor of 1e-6 times income, and gamma = 5 leave
  the early-life value function with no limit to converge to. The cause is
  the committed housing outflow: at an 11% rent burden the model converges. No
  numerical setting fixes this. Two checks flag it. `c_bound_25_39` is the
  share of young households consuming at the lower bound of the consumption
  search, which then sets their consumption. `ce_entry` is the value at entry
  as a constant consumption stream; values far below one entry income mean
  the value is dominated by floor states.
- **Welfare levels at a floor of 1e-6 are not converged**, so report
  behaviour rather than welfare until the floor is set.
- **The REIT parameters are placeholders**, with the same risk-return ratio
  as equity, so the REIT leg (off by default) cannot yet answer anything.

## The model in brief

State and normalisation. Total wealth is W = X + A + H + Y: liquid wealth,
the DC pot, the house or rent index, and current income. The value function
is homothetic, V(W, u) = W^(1-gamma) V_tilde(u), and is solved on the cube

    u1 = Y/W,   u2 = (A+H)/(W-Y),   u3 = A/(A+H),

on which every point is a feasible state. The continuation is interpolated
linearly in its certainty equivalent z = ((1-gamma) V_tilde)^(1/(1-gamma)).

Each period. Working: take-home income is (1 - kappa_t)(1 - tau_inc) Y, the
contribution kappa_t Y goes to the DC pot (EET), and the housing cost (rent
alpha*H, or maintenance plus mortgage (theta + m_t) H) is paid out of liquid
resources. Retired: AOW and the annuity A/a_t are taxed as income. If
resources fall below phi_floor * Y the household consumes that floor and saves
nothing. The liquid account earns the risk-free rate and equity, after box-3
tax; the DC fund holds the glide path's equity share pre-tax and earns the
survival credit 1/p_t. The annuity price a_t is set so that expected payouts
are level.

Solution. Backward induction over 76 periods, Gauss-Hermite quadrature over
the income, equity and housing shocks, and at each node a search over c and pi:
a global (c, pi) sweep from the warm start, then fmincon (active-set). The
simulation draws continuous shocks and reads the policies off the cube.

## Layout

| folder | contents |
|---|---|
| `+config` | `params` (primitives), `derive`, income profile, survival, glide and REIT shares, after-tax returns, `model_inputs` |
| `+grids`, `+pension` | shock quadrature; annuity prices |
| `+solver` | `solve`, the backward induction and the Bellman step |
| `+simulate` | `forward` and the panel simulation |
| `+model` | `run` (solve, simulate, summarise), `summarize`, `checks` |
| `+ladder` | the calibration ladder: `steps`, `params`, `run`, `compare`, `report` |
| `+figures` | per-run dashboard, step comparison |
| `+utility` | state grid, automatic grid placement, entry value, pool, output folder |
| `tests` | `run_tests`, `verify_income_profile` |
| root | `run_model`; cluster setup (`bootstrap_pod.m`, `setup_cluster.sh`, `install_matlab.sh`) |

[GRIDS.md](GRIDS.md) explains how to choose the state grid from where
households actually live. [TODO.md](TODO.md) lists the open questions.
[CALIBRATION_PLAN.md](CALIBRATION_PLAN.md) is the step-by-step plan for the
new calibration.

## History

This branch was built from the research state of September 2026 and
reproduces it exactly: on a test grid, both tenures, the value function,
policies and simulated paths match the research solver to the last bit when
that solver is run with the same settings.

What it leaves out is on other branches and recoverable with git:

- `solver-active-set`, tag `research-2026-09`: the September diagnostics
  (`diagnostics/`, with `HANDOVER.md`, `FACTORIAL_FINDINGS.md` and the
  `NOTES_*` files carrying the evidence for the statements above), the
  alternative coordinate charts and interpolation schemes, the simplex solver,
  free DC investment choice, the glide-path sweep and its welfare comparison,
  and the earlier dashboards (`make_plots.m`).
- `freetau-dc-choice` and older branches on GitHub: the August welfare work.

Changes from the research defaults, all recorded in CALIBRATION.md: the REIT
share is 0 (it was a 10% placeholder); the search sweeps (c, pi) before
fmincon instead of pi after it; the u1 axis starts at 0.0008 instead of 0.002,
because owners reach 0.0013; the default grid is [20 20 12] with gh_n = 5
instead of [28 20 20] with gh_n = 7; and simulations start from the entry
buffer p.b0 instead of zero liquid wealth, so they start where the entry value
is read.
