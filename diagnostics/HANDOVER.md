# Handover — grid and convergence work, 11–12 September 2026

Renter, ablation rung 6, gamma 5, branch `solver-active-set`, everything
uncommitted. Roughly forty solves. Detail and working in `NOTES_overnight.md`;
this is the part worth carrying forward.

---

## The conclusion

The model at `phi_floor = 1e-6` is **arithmetically finite and not representable
in double precision.** `u(floor)` exceeds `u(30,000)` by 8.1e41 while the whole
discount-and-survival factor spans 1.5e3, so `u(F) + 75*u(30k) == u(F)` exactly.
Expected utility is a pure count of floored years; nothing else survives the
addition.

That was already in the August notes as a conjecture. This session tested it
directly and it held. `alpha` and `h_mult` enter the renter's budget only as a
product, so scaling `alpha` scales the committed rent outflow and nothing else:

| rent, % of net income at 25 | ages 25-39, 2520 vs 9856 nodes | V(entry) across a 4x refinement |
|---|---|---|
| 44 (production) | 64.7% | 5.6e10 |
| 22 | 9.9% | 2.63 |
| 11 | **1.1%** | **1.07** |

At an 11% burden the model converges outright and behaves like an ordinary
life-cycle model. Nothing numerical changed between those rows.

**So no grid, coordinate or interpolation choice can fix this.** Every numerical
lever tested — density, node placement, axis range, interpolation transform,
interpolation structure — moves early-life consumption by a factor of two to
three, and all of them act through one channel: how much of the unrepresentable
region the discretisation resolves. Plotting all 32 solves against `|V(entry)|`
collapses them onto a single curve that saturates at `C/disp@25 = 0.163`
(`fig_saturation.png`). Refining *anything* makes the entry value worse, because
it resolves the bad region more sharply.

**What the model returns when solved as specified**, best numerics available:
`C/disp@25 = 0.163`, `V(entry) = -8.2e14`. That is the correct output of an
ill-conditioned problem, not a solver bug.

---

## Two separate defects, at opposite ends of life

They do not interact. Backward induction has exactly one channel from retirement
into working life — the value function at the handover — so it was grafted: the
coarse grid run over working life starting from the *fine* grid's V at age 68.
It closed 1.2% of the consumption gap and moved the entry value 4.6%. The
retirement error does not propagate (`fig_graft.png`).

**Retirement — portfolio roughness, caused by node starvation on u1.**
`u1 = lambda = Y/W`. At 67 the wage stops, Y falls 3.26x, W moves 2.5%, so lambda
falls 3.18x in one year. The three lowest u1 nodes are 0.002, 0.0419, 0.0817, so
the entire retired population lives inside the first cell for about fifteen years
and every policy there is one interpolation between the same two nodes. Node
count inside the population: 6 at age 30, 3 at 66, **0 at 67**, 1 at 70–80.
`|d2 pi|` is 11–19x the midlife level and gets **worse** with refinement.

The household is not discontinuous — the DC pot starts paying 59,069 against a
wage loss of 59,946, so resources go 86.5k to 85.6k. The jump is in the
coordinate, which excludes the annuity's flow from the numerator while its
capital value sits in the denominator (`fig_plain_retirement.png`).

**Early life — consumption, caused by the committed outflow.** Ages 25–39
disagree 45–130% between interpolants at any floor. u2 is also starved there
(one node under the population at 25–35) but fixing it does not close the gap.

**Only 17.1% of the 2520-node cube is ever visited by any household at any age,
and 17.0% of the 9856-node cube.** Four times the nodes, identical coverage. That
is the mechanical reason a refinement sequence cannot converge.

---

## Three retractions

1. **log-z is broken, not a rival scheme.** I used the linear-z / log-z gap as an
   error bar throughout, including to argue that raising the floor "buys
   grid-insensitivity, not convergence". At quarter rent burden, where linear-z
   converges cleanly (V(entry) -7.3e4, nothing floored), log-z returns
   **-1.16e21** and poisons 6.7% of nodes. Interpolating linearly in log z
   underestimates a convex function, pushes V down and tips nodes over the cliff.
   It manufactures the pathology it is used to measure. Keep it as a conditioning
   diagnostic; **use linear vs makima as the structural error proxy.**

2. **"100% of age-25 households are in the poisoned region"** is a property of the
   grid, not the households. All households enter at one state, so the share is 0
   or 100 by construction: 0% at 2520 nodes, 100% at 9856. The informative number
   is the share of *grid nodes* below -1e12 at age 25, which rises with refinement
   (4.2% to 7.0%).

3. **`phi_floor` 0.10–0.20 fixes less than I first said.** It fixes the ruin
   blow-up and the grid sensitivity, both real. With the grid fixes on it gets
   ages 40+ to 1–5% across grids and interpolants — usable. It does not reach
   ages 25–39.

---

## Code changes — all opt-in, every default bitwise unchanged

Verified against the stored production grids and value functions
(`isequal(V) = 1, max|dV| = 0`). Nothing in `+config/params.m` was touched;
`alpha = 0.06` and `tau_inc = 0.382` are as they were.

| parameter | file | default | what it does |
|---|---|---|---|
| `p.interp_space` | `+solver/bellman_step_lna.m` | `'z'` | `'logz'` interpolates log z. Diagnostic only — see retraction 1 |
| `p.interp_method` | `+solver/bellman_step_lna.m` | `'linear'` | `'makima'`, `'spline'` |
| `p.u2_lo` | `+utility/build_state_grids.m` | `0` | bottom of the u2 axis. u2 never fell below 0.63 in 608,000 household-years, so half that axis was dead |
| `p.grid_pow_u2` | `+utility/build_state_grids.m` | `grid_pow` | u2 clustering alone. One exponent drove both axes and they want opposite things: u1 falls through life, u2's occupied band slides 0.98 → 0.70 → 0.95 |

`'cubic'` is deliberately not offered: the anchor splice makes the grid
non-uniform and `griddedInterpolant` silently downgrades it to `spline`.

**The grid configuration worth turning on** (moves nodes, changes no economics):

```matlab
p.lambda_hi   = 0.42;   % lambda never exceeds 0.4048; the axis ran to 0.6
p.grid_pow    = 2;      % lambda falls through life, bunch its nodes low
p.grid_pow_u2 = 1;      % u2 does not fall, it wants even coverage
p.u2_lo       = 0.60;
```

Worst year of the life cycle goes from 0 u1 nodes to 3 and 0 u2 nodes to 1, with
nothing clipped on either axis. At `phi_floor = 0.20` this gives density 1.9%
(ages 40–59) and 1.2% (60+), linear-vs-makima 5.3% and 3.3%. Early life stays at
10.8% and 34.6%.

---

## Open, and yours rather than mine

I twice proposed changing a calibrated parameter — the rent burden, then
`tau_inc` — as a *fix*. That is tuning the economics until the solver behaves and
it is the wrong way round. The rent sweep was legitimate as a diagnostic; the tax
proposal was not, and that run was killed.

One parameter is different in kind. **`phi_floor = 1e-6` is a placeholder, not a
calibration** — it stands in for the social minimum, which the model otherwise
has no representation of. Setting it to the Dutch bijstand level is *specifying*
the model, and the answer is a data question that does not depend on the solver.
That is the decision the whole session points at.

The alternatives, none of which are mine to take:

- **Make the outflow avoidable** — let the renter downsize. Removes the cause
  rather than damping it, and is why Yao & Zhang (2005) have no such pathology.
- **Report ages 40+ only** at the current specification, with the grid fixes on,
  stating that accumulation is not identified.

Also analysed and **not implemented**: two alternative first coordinates,
`(Y + annuity)/W` and `HK/(F + HK)`. Both remove the retirement jump (ratio 0.90
and 1.04 against 3.18) and both reach 100% axis coverage. Roughly a day's work
including verification, since u1's definition enters the budget, the transition
map and the simulator. Note they target the **retirement** half only — the graft
result says they will do nothing for ages 25–39.

---

## Traps in this codebase, all hit at least once

- `dims` is a **base** count. `config.insert_anchor_nodes` adds two nodes each to
  u1 and u2, so `[16 12 10]` is 18x14x10 = 2520, not 1920.
- `build_state_grids(p, dims, gh_n)` — the third argument **silently overwrites
  `p.gh_n`**. Pass `[]` unless you mean to set it. A whole quadrature experiment
  was invalidated by this.
- `p.tau_effective` has 75 elements against `T = 76`. Index with
  `min(t, numel(...))`.
- The "% floored" diagnostic counts **top-up events**, not household-years spent
  below the floor level. At `phi_floor = 0.20` a 25-year-old consumes 6,548 while
  `phi_floor * Y` is 8,881 — the floor guarantees *resources*, and the household
  may save out of the top-up. Do not read it as "nobody consumes less than this".
- The poisoned region is ~7% of the grid, so a **median** error statistic is blind
  to it by construction. A median reconstruction error reads 0.0% where the p99
  reads 4,000–22,000%.
- For the renter, `alpha` and `h_mult` enter only as a product — which makes a
  free known-zero test. **The owner has no equivalent**: H is real wealth, is
  bequeathed, and carries a mortgage scaled to it.

---

## On disk

`diagnostics/` — 42 `.mat` files and ~70 figures. The ones that carry the
argument:

| figure | shows |
|---|---|
| `fig_verdict.png` | the cause, demonstrated by removing it |
| `fig_plain_retirement.png` | the household is continuous at 67, the coordinate is not |
| `fig_plain_grid.png` | grid lines against the population, ages 40 / 67 / 80 |
| `fig_saturation.png` | all 32 solves collapse onto one curve |
| `fig_graft.png` | retirement error does not propagate back |
| `fig_node_starve.png` | nodes spanning the population, by age |
| `fig_axes.png` | the four levers side by side, in euros |

Solve data: `phase15.mat` (rent burden), `phase16.mat` (combined grid fix),
`phase13/14.mat` (placement at each floor), `phase9.mat` (interpolation
structure), `phase8/10.mat` (owner), `dash_1..4.mat` (full solves with `sol`).
Scripts are in the session scratchpad and are not preserved — the `.mat` files
are.

Relevant memory: `consumption-floor`, `retirement_roughness_is_grid`,
`interp-axes-distinct`.
