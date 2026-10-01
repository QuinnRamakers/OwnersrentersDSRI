# Interpolation and coordinates — 12 September 2026

Brief: find an interpolation that behaves at the `-inf` edge, and look at
coordinate systems better suited to this model. Written against `HANDOVER.md`,
which settles the calibration question and is not revisited here.

> **Status after testing: `interp_object = 'kappa'` is NOT adopted.** It passes
> on consumption and fails a known-answer test on the portfolio rule. Sections 1
> and 2 stand; section 3's claims are superseded by section 3.2. Read that before
> using the switch.

The short version: the cliff is not a property of the value function that has to
be interpolated through. It has a closed form, and dividing it out demonstrably
improves the interpolation of a function with that boundary behaviour and makes
consumption converge under refinement where it previously did not. But the same
change moves the equity share by 0.3-0.5 in a region where there is no cliff, so
it is doing something besides fixing the cliff, and that something is not
identified. The coordinate question is second order either way.

---

## 1. What the cliff actually is

CRRA pins the boundary behaviour exactly. Write `m` for next period's liquid
resources per unit of wealth, which is what the solver calls `LW_W`:

```
m = s_X + cf_t * lambda + ann_t * s_A - hc_t * s_H
```

As `m -> 0` the household consumes `m`, `u(m)` diverges, and it swamps a
continuation value that stays finite because income and the pension are still
there. So

```
z(m) = m * (1 + o(1))          as m -> 0,
```

where `z = ((1-gamma) V)^(1/(1-gamma))` is the certainty equivalent the solver
already interpolates. The certainty equivalent does not merely fall near ruin;
it converges onto current resources with slope one. That is a boundary
condition, not an approximation, and nothing in the code uses it.

Two facts about the current chart follow from the budget identity alone.

**`m` is exactly affine in `u2`.** Substituting the cube coordinates,

```
m(u1,u2,u3) = (1-u1)(1-u2) + cf*u1 + ann*u2(1-u1)u3 - hc*u2(1-u1)(1-u3)
```

is affine in `u2` at fixed `(u1,u3)`. At the 2520-node grid, `u1 = 0.0419`:

| u2 | 0.818 | 0.909 | 0.946 | 0.981 | 1.000 |
|---|---|---|---|---|---|
| m | 0.149 | 0.057 | 0.019 | -0.016 | -0.035 |

So the `u2` axis already is a linear resource axis, and linear-in-`z` on a
linear-in-`m` axis is the right pairing. This is why `interp_space = 'logz'`
failed: `log z` is roughly `log m` near the boundary, which is concave in `u2`
and diverges at the zero, so a straight line between nodes sits far below the
function and pushes `V` down. The retraction in `HANDOVER.md` is correct and the
mechanism is a mismatched pair, not a defect of logarithms.

**The ruin surface is oblique and only exists at low `u1`.** Setting `m = 0` for
the renter gives `u2* = (1 + cf*u1/(1-u1)) / (1 + alpha)`:

| u1 | 0.002 | 0.042 | 0.082 | 0.122 | 0.197 (entry) |
|---|---|---|---|---|---|
| u2* | 0.944 | 0.965 | 0.988 | off axis | off axis |

Above `u1 ~ 0.10` at working-age rates, and `u1 ~ 0.09` once the contribution
stops, income alone covers the rent and ruin cannot happen at any liquid
balance. Below it, the surface crosses the top three `u2` cells at a
`u1`-dependent height, and about 1% of cube nodes sit past it. Those nodes are
reachable — they are the renter ruin states, where rent plus outgoings exceed the
liquid balance plus net income — so this is not a feasibility problem. It is a
regime boundary, between the free branch and the floored branch, that falls
inside a cell at an angle to the grid.

The defect is a mislocation rather than a smoothing error. Between the last free
node and the first floored one, linear-in-`z` draws a secant from `z ~ 0.019` down
to the floored value `1e-6 * lambda`. The true `z` reaches zero at `u2* = 0.965`;
the secant reaches it at `u2 = 0.981`. The interpolant therefore places the ruin
boundary about half a cell too far out and hands the household resources it does
not have, which is the overstatement `+config/params.m` already warns about in
its `grid_pow` note.

---

## 2. Six schemes, measured

The comparison needs a reference the solver cannot supply, so it is run against
a manufactured solution: `z(m) = (m^(1-g) + w*(m+h)^(1-g))^(1/(1-g))`, exact at
both ends, with `m(u2)` the model's own affine budget line, the real `u2` grid,
and the real floored value at dead nodes. Only the `m -> 0` asymptote is
imposed, and that is forced by CRRA rather than chosen.

Error is `|dV|/V` at 400 points across the occupied top of the axis, renter,
working-age coefficients.

| scheme | p99 at u1=0.042 | p99 at u1=0.082 |
|---|---|---|
| A linear-`z` (current default) | 74.2% | 100.0% |
| B makima-`z` | 59.3% | 99.9% |
| C linear-`log z` | 7.2e6 % | 1.2e5 % |
| D linear-`z`, dead nodes dropped, exact cliff spliced | 10.8% | 0.37% |
| E linear-`kappa`, `z = kappa * m` | 2.5% | 0.19% |
| F makima-`kappa`, `z = kappa * m` | 0.67% | 0.07% |

Over 54 configurations varying the surrogate's continuation weight and human
capital, the `u2` node count and its clustering exponent:

| scheme | median p99 | worst |
|---|---|---|
| A linear-`z` | 35.2% | 79.4% |
| B makima-`z` | 58.8% | 124.0% |
| C linear-`log z` | 1.9e6 % | 3.5e10 % |
| D exact cliff | 1.8% | 45.0% |
| E linear-`kappa` | 0.78% | 21.6% |
| F makima-`kappa` | 0.43% | 340.0% |

E beats A in 98% of configurations, F in 96%, and the median ratio A/F is 68x.

Two things there are worth more than the ranking. Smoothness helps on `kappa`
and hurts on `z` — makima is the worst scheme in the first table and the best in
the second, on identical nodes. The interpolation structure is only a meaningful
choice once the interpolated object is the right one, which sharpens the
three-axis distinction in `interp-axes-distinct` into four. And F's worst case is
340% against E's 21.6%: makima still overshoots occasionally, so linear on
`kappa` is the safe default and makima the option.

---

## 3. What is implemented

`p.interp_object` in `+solver/bellman_step_lna.m`, default `'z'`, which is the
existing path bit for bit.

```matlab
p.interp_object = 'kappa';                          % scheme E
p.interp_object = 'kappa'; p.interp_method = 'makima';   % scheme F
```

`p.interp_space` applies to the `z` object only; `kappa` has no logarithmic
variant because it does not span orders of magnitude.

Next period's `m` is an exact affine function of the cube coordinates, so the
scheme needs no extra arguments at any call site:

```
F     = max(phi_floor * u1, eps)
kappa = z / m        at every node with m > F,  clamped to [0, max]
kappa = 1            at nodes with m <= F,      the m -> 0 limit
z(u)  = max( kappa_hat(u) * max(m(u), 0),  F(u) )
```

Nodes at or below the floor are excluded from `kappa` rather than only those at
or below zero, because there the state tops the household up: `z` is the floor
rather than a multiple of the household's own resources, so `kappa = F/m` would
grow without bound as `m` falls.

`m(u)` is evaluated, never interpolated, from the same identity the main loop
uses, at next period's coefficients — a new local `budget_coeffs` supplies the
retired and working branches. Consequences:

- `z = 0` exactly where `m = 0`, so the ruin surface sits where the budget puts
  it, in three dimensions, at any grid density. There is no cell in which its
  position is an artefact of node placement.
- the interpolated object is O(1) and bounded. `z` runs from `phi_floor*lambda`
  to about 1, some nine orders of magnitude at the production floor, and `V` runs
  over four times that in logs; `kappa` stays in `(0, 1]`. A smooth scheme is
  therefore usable, and the sign is carried by `m` rather than by a clamp.
- outside the grid it degrades better. `griddedInterpolant` extrapolates
  `nearest`, which on `z` is flat and leaves a household pushed off the axis
  with no gradient — the failure `build_state_grids` warns about when it
  discusses where to put `u2_lo`. On `kappa` the flat part is the propensity,
  and `m` still varies, so the resource gradient survives.
- `-inf` is representable as `z = 0` and needs no sentinel. With the floor on,
  the clamp reproduces the model's own floor rule at the right place instead of
  wherever the last floored node happens to be. The clamp is the leading term of
  the floored branch rather than a fudge: consuming the floor and saving nothing
  gives `z = F * (1 + beta*(F/CE)^(gamma-1))^(1/(1-gamma))`, so the correction is
  of order `(F/CE)^(gamma-1)` — about 1e-20 at `phi_floor = 1e-6` and about 2e-5
  at 0.2.
- floored nodes stop contaminating free ones. They keep `kappa = 1`, the correct
  limit, so a cell straddling the boundary blends toward the asymptote instead of
  toward a value that belongs to the other regime.

Cost is one interpolant of the same size and a handful of flops per quadrature
node.

### Verified

Three backward steps from a common terminal `V`, renter, 10x10x6, gh_n=3, which
isolates the interpolant from everything else:

- default against explicit `'z'`: `isequal(V) = 1`, `max|dV| = 0`, `max|dc| = 0`.
- `'kappa'` solves, every value finite.
- at `t = 42`, the last working year and the step whose continuation is the
  retired value function, the worst node moves from `-3.36e34` to `-1.69e36` and
  the median `|dpi|` is 0.018. The direction is the predicted one: linear-`z` was
  overstating the continuation value next to the cliff.

### On full solves: grid density crossed with the object

Four life cycles, renter, gamma 5, production calibration, `phi_floor = 1e-6`,
`grid_mode = 'none'`, `use_refine = false`, `gh_n = 3`, grids of 600 and 2560
nodes. Everything is read at the entry anchor, an exact node on both grids. This
is a controlled A/B at a deliberately cheap configuration, so the levels are not
comparable with the `phase*` files; only the columns are.

| object | \|V(entry)\| ratio, 600 -> 2560 | d c25 | d pi25 | d pi30 |
|---|---|---|---|---|
| `z` | 6.19 | -0.220 | 0.000 | 0.000 |
| `kappa` | **2.37** | -0.242 | 0.144 | 0.199 |

Three readings, and the second and third matter as much as the first.

**The welfare number gets less grid-dependent.** Entry-value drift across a 4.3x
refinement falls from 6.19x to 2.37x. That is the metric every earlier session
used and it is the intended effect.

**Early-life consumption does not improve.** `c25` drifts by the same amount
either way, slightly worse under `kappa`. This is the handover's result holding:
ages 25-39 are driven by the committed rent outflow, not by the interpolant, and
nothing in this note reaches them. Do not present the change as a fix for the
accumulation phase.

**The portfolio rule changes qualitatively and is the thing to look at next.**
Under `z`, `pi` is exactly 1.000 at the anchor on both grids at both ages — it is
not stable, it is pinned at the upper bound, which is what a flat-then-saturating
objective looks like. Under `kappa` it is interior, 0.103 at 600 nodes and 0.247
at 2560 for age 25. So the accurate interpolant un-pins a policy the old one was
holding at the corner, and the un-pinned policy is itself still grid-sensitive.
That is a change in what the model says, not a numerical detail, and nothing here
establishes that `kappa`'s `pi` is right — only that `z`'s was at the bound.

Runtime is a wash: 25s against 51s at 600 nodes, 82s against 72s at 2560.

### 3.1 Convergence: kappa converges, z does not

Three grids (1152, 2560, 4800 nodes), both objects, renter, 4000 simulated
households, common seed. Mean `|dC|/C` between successive refinements:

| scheme | 1152 -> 2560 | 2560 -> 4800 | `pi` drift, second step |
|---|---|---|---|
| `z` | 14.4% | **15.3%** | 0.240 |
| `kappa` | 8.9% | **4.5%** | 0.063 |

`z`'s consumption at 25 runs 10045 -> 7566 -> 4440 and keeps falling; `kappa`'s
runs 15600 -> 11232 -> 11123 and settles. The gap *between* the schemes grows
(25% -> 45% -> 72% in early life) because one of them is running away.

### 3.2 Known-answer test: it fails on the portfolio rule

`alpha` and `h_mult` enter the renter's budget only as a product, so scaling
`alpha` shrinks the committed outflow and nothing else. At a quarter of the
production burden the ruin surface is on the axis for 6% of `u1` nodes instead of
19%, and the model is known to converge cleanly there. With no cliff to fix, the
two schemes must agree. Three burdens, same everything else:

| rent, % of disposable at 25 | mean \|dC\|/C, 25-39 | mean \|d pi\|, 25-39 | pi at 25, z / kappa |
|---|---|---|---|
| 77 (production) | 44.7% | 0.288 | 1.00 / 0.25 |
| 28 | 16.3% | 0.497 | 1.00 / 0.46 |
| 12 | **9.6%** | **0.346** | 1.00 / 0.62 |

Consumption behaves exactly as the scheme predicts: the disagreement shrinks with
the cliff, 45% to 10%. The equity share does not — the gap is 0.29, 0.50, 0.35
with no trend, and `kappa` still returns 0.62 at 25 where the textbook answer,
and `z`'s answer, is the corner at 1.00.

So `kappa` changes the portfolio choice through a channel that is not the cliff.
Two candidate explanations were ruled out and one is open:

- **Ruled out: the derivative-free refinement.** It was off in every A/B for
  speed, and `kappa` changes the objective's shape, so it might have penalised
  `kappa` specifically. Turning it on moves `C` at 25 by 0.8%, `pi` at 25 from
  0.25 to 0.27, and leaves `kappa`'s profile 3.6x rougher than `z`'s either way.
- **Ruled out: that it is a cliff effect at all.** That is this test.
- **Open, untested.** Within a cell, `z` mode is multilinear. `kappa` mode
  returns a product of two multilinear functions, which is quadratic along each
  axis. The portfolio share responds to the curvature of the continuation value,
  so `kappa` mode introduces curvature everywhere, not only at the boundary. If
  that is the channel it is a property of the construction, not a bug, and it
  would need a separate argument for which curvature is right. Cheapest probe:
  build both interpolants from one stored `V` and compare second differences
  along the liquid-wealth direction, away from the cliff. No solve needed.

**So: consumption yes, portfolio no.** Do not turn the switch on for a production
run until the portfolio channel is identified.

---

## 4. Coordinates and spacing, measured

Everything in this section is measured on one production-default solve and 6000
simulated households, not argued. Two questions, and they have different answers:
the chart is close to the best available, the node placement is not.

### 4.1 Where the households are, and where the nodes are

Occupied 1st-99th percentile band by age. Ages 25-26 are excluded throughout:
every household enters at one state, so the band has zero width there by
construction and any per-age statistic including it is meaningless.

| age | `u1 = Y/W` | `u2` illiquid share | `u3` DC share |
|---|---|---|---|
| 27 | 0.145 - 0.249 | 0.899 - 0.944 | 0.041 - 0.077 |
| 45 | 0.052 - 0.219 | 0.703 - 0.889 | 0.322 - 0.759 |
| 67 | **0.005 - 0.040** | 0.741 - 1.000 | 0.538 - 0.906 |
| 90 | 0.009 - 0.108 | 0.923 - 1.000 | 0.197 - 0.683 |

`u1` collapses into a sliver at the bottom of its axis and comes partway back.
`u2` starts high, dips through mid-life and returns to the ceiling, and it
genuinely reaches 1.000 from 55 on, so `u2_lo` is safe to raise but the top of
that axis cannot be trimmed. `u3` sweeps nearly the whole unit interval.

Nodes under the population, mean across ages and at the leanest age, and how many
of the 73 ages carry fewer than two nodes on an axis:

| placement | `u1` | `u2` | `u3` | starved ages |
|---|---|---|---|---|
| production default | 3.0 / 0 | 3.5 / 1 | 3.5 / 0 | **20 / 11 / 5** |
| HANDOVER settings | 5.1 / 2 | 6.9 / 1 | 3.5 / 0 | 0 / 5 / 5 |
| nodes at measured quantiles, anchors spliced | 8.9 / 5 | 10.3 / 1 | 4.9 / 0 | 0 / 1 / 6 |

`u3` is the axis quantile placement does not fix, and it gets marginally worse:
its band is 0.04-0.08 at 27 and 0.54-0.91 at 67, and one pooled placement cannot
serve both. That axis wants clustering near zero on top of a quantile rule, or an
age-varying grid.

### 4.2 The chart: six candidates, one metric

A fixed tensor grid must cover the union of the occupied bands over the whole
life cycle. The sweep factor is the width of that union divided by the median
per-age width: 1 means one grid fits every age, 10 means nine tenths of the nodes
are idle at any given age.

| chart | axis 1 | axis 2 | axis 3 | product |
|---|---|---|---|---|
| current `(Y/W, illiq share, DC share)` | 2.1 | 1.6 | 2.1 | 7.0 |
| resource share `(m/W, Y/W, DC share)` | 1.5 | 2.1 | 2.1 | 6.8 |
| **`((Y+annuity)/W, illiq, DC)`** | **1.8** | 1.6 | 2.1 | **6.1** |
| human capital `(HK/(HK+wealth), illiq, DC)` | 3.0 | 1.6 | 2.1 | 9.8 |
| income-normalised, CGM style `(X/Y, A/Y, H/Y)` | 1.7 | 4.0 | 2.3 | 15.8 |
| resources over income `(m/Y, A/Y, H/Y)` | 1.2 | 4.0 | 2.3 | 10.7 |

The CGM-style chart is the one to bet against here, and it loses by more than a
factor of two: `A/Y` sweeps from nothing to many years of income as the pot fills,
and `H/Y` steps at 67. Normalising by wealth already absorbs both.

### 4.3 The retirement step, and what removes it

Measured household by household on the simulated panel, the 67-over-66 ratio of
the first coordinate:

| first coordinate | median | 10-90% |
|---|---|---|
| `Y/W` (current) | 0.314 | 0.307 - 0.322 |
| `(Y+annuity)/W` | 0.790 | 0.582 - 1.248 |
| `HK/(HK+wealth)` | **0.957** | **0.942 - 0.973** |

Human capital walks through the handover almost untouched, and for a reason that
is not a coincidence. `HK` is the present value of everything still to be
received. At the switch the composition of that stream changes -- wage out, AOW
in -- but no payment is made, so the present value does not step. The measured
factor `phi = HK/Y` runs 57.2 at 25, 21.5 at 45, **5.12 at 66 and 16.03 at 67**,
and that 3.13x jump is exactly what cancels income's 3.26x fall.

The cost is in 4.2: `HK/(HK+wealth)` drifts monotonically across the life cycle,
so its sweep is 3.0 against 1.8, and 16 quantile-placed nodes put 5.2 under the
population against 10.2 for `(Y+annuity)/W`. It trades a discontinuity for a
drift. A drift is the easier problem -- it is what an age-varying grid is for, and
that is cheap here, since the solver already evaluates the continuation at
arbitrary points and only the storage nodes would change per age.

`(Y+annuity)/W` is the better bargain if the grid must stay fixed: best sweep of
the six, most nodes under the population, and it more than halves the step. But
the step it leaves is household-specific -- 0.58 to 1.25 -- because it depends on
how much pot there is to annuitise. It smears the discontinuity rather than
removing it.

### 4.4 Should labour income be inside `W`?

It makes no difference to the chart, and the algebra says why. With
`F = X + A + H` and `x = Y/F`,

```
u1 = Y/W = Y/(F+Y) = x/(1+x)
```

verified on the panel to 1.1e-16. The income-to-wealth ratio and the income share
of wealth are the same coordinate under a monotone map, so choosing between them
is choosing where to put nodes, not what to model.

And that choice matters a great deal. The same 16 nodes on the same axis:

| placement | mean nodes under the population | worst age | starved ages |
|---|---|---|---|
| uniform in `u1 = Y/W` (current) | 2.8 | 0 | **17** |
| geometric in `x = Y/F` | 7.6 | 3 | **0** |
| quantile-placed from the panel | 8.2 | 3 | 0 |

Spacing evenly in the ratio captures most of what an empirically optimal
placement achieves and needs no simulation to calibrate. It is already
implemented -- `p.grid_space = 'logratio'` in `build_state_grids` -- and off by
default.

The one place the choice is not innocuous is the homogeneity scale, since
`V = (scale * z)^(1-gamma)` and `F` can in principle reach zero while
`W = F + Y` cannot. Empirically it does not bite: the smallest `F/Y` over all
households and ages is 1.60. But that floor is held up by `H`, which for a renter
is a rent index with no resale or bequest value. Strip it out and `(X+A)/Y` has a
minimum of 0.28, with 0.44% of household-years under half a year of income, and
at 27 the median household holds 0.55 years of income in `X+A` against a rent
index worth four.

Which is worth knowing on its own account. For the renter, `H` is 70% of `W` at
27 and 56% at 90. The homogeneity is still exactly right -- rent is `alpha*H`, so
`H` must scale with everything else and must be in the normaliser -- but `u2`,
described as the illiquid share of non-income wealth, is mostly a price index,
and that is why it never leaves `[0.70, 1.00]`.

### 4.5 Does placement fix the early-life divergence? No.

Every convergence result on record, section 3.1 included, was produced on a
placement that starves a quarter of the life cycle, which is a confound rather
than a detail. Three placements, three sizes each, production-default
interpolant, nine solves. Mean `|dC|/C` between successive refinements:

| placement | refinement | 25-39 | 40-69 | 70+ |
|---|---|---|---|---|
| default | 1152 -> 2560 | 14.4% | 3.8% | 2.0% |
| default | 2560 -> 4800 | **15.3%** | 2.0% | 1.3% |
| logratio | 1152 -> 2560 | 19.7% | 4.3% | 5.4% |
| logratio | 2560 -> 4800 | **16.3%** | 1.8% | 2.7% |
| HANDOVER | 1152 -> 2560 | 28.3% | 3.6% | 1.3% |
| HANDOVER | 2560 -> 4800 | **23.5%** | 2.3% | 0.8% |

Consumption at 25 falls monotonically with refinement under all three:
10045 / 7566 / 4440 on the default, 8696 / 6008 / 3951 on logratio, 6533 / 2255 /
2255 on HANDOVER. **The confound is cleared and it was not the explanation.** The
early-life divergence is structural, it is the committed rent outflow, and no
node placement reaches it -- the same verdict `HANDOVER.md` reached from the rent
sweep, now confirmed against the one lever that had not been ruled out.

Two cautions from the same table. HANDOVER's identical `C25` at two different
grid sizes is not convergence -- a value that repeats to the euro across a 1.9x
refinement is more likely pinned against the consumption search bound, and its
`pi25` goes 0.54 to 0.00 across the same step. And `u2_lo = 0.60` clips: 106 of
304,000 policy lookups fell off that axis and were nearest-extrapolated.

### 4.6 Where placement does pay: retirement

The same nine solves, roughness of the simulated equity share over ages 65-84,
mean second difference relative to level:

| placement | 1152 | 2560 | 4800 |
|---|---|---|---|
| default | 6.32% | 4.38% | **4.38%** |
| logratio | 3.99% | 1.64% | **1.47%** |
| HANDOVER | 2.73% | 2.44% | 2.09% |

The default plateaus at 4.38% and stops improving; logratio is three times
smoother and still falling at the finest grid. That is the retirement roughness
`HANDOVER.md` attributes to node starvation, and spacing evenly in the ratio is
most of the cure.

Note a conflict with the record: an earlier session found uniform spacing beat
logratio on an accuracy measure, 0.055 against 0.111. That is a different metric
on a different quantity and this does not overturn it, but the two do not point
the same way and one of them is measuring something other than what it claims.

### 4.7 What to do

1. **Turn on `p.grid_space = 'logratio'`** for the retirement half. Already
   implemented, costs nothing, three times smoother `pi` in retirement and still
   improving under refinement where the default has stopped.
2. **Do not expect it to touch accumulation.** 4.5 is the test; it does not.
3. **Do not adopt the HANDOVER bundle as a bundle.** It is worse on early-life
   drift than either alternative, it clips `u2`, and its apparent stability at
   the two finer grids looks like a bound rather than a limit. Take `grid_pow_u2`
   and leave `u2_lo` and `lambda_hi` until each is tested alone.
4. **`(Y+annuity)/W` if the retirement step still matters** after 1, and the grid
   must stay fixed. `HK/(HK+wealth)` if an age-varying grid is acceptable, which
   is less work here than it sounds.
5. **Do not go to income normalisation.** It is the intuitive move and it is
   twice as bad on this model.

## 5. Not done, and one thing not worth doing

The Bellman recursion could be run in certainty-equivalent units throughout
rather than in utils — `C_t = (c^(1-g) + beta*CE^(1-g))^(1/(1-g))`, scaled by the
smallest term so the bracket stays O(1). It is exact, it cannot overflow, it
removes the `obj_scale` median-of-`|V|` heuristic whose own comment says it is
right for a typical node and wrong for an extreme one, and it would let one
fmincon tolerance mean the same thing everywhere. Worth doing for conditioning
and for `gamma = 10`, and it is a contained change.

It will not recover the annihilation. `u(F) + 75*u(30k) == u(F)` is a property of
the sum, not of its units: a monotone transform of both sides cannot restore
digits that the addition destroyed. Anyone proposing it as a fix for the flat
`pi` objective should be told this first.

Not attempted: the owner. The budget identity is the same shape with
`hc = theta + m_rate_t` and no `alpha`, so `interp_object = 'kappa'` applies
unchanged, but nothing here was measured on it.

---

## Reproduction

Scripts are in `diagnostics/` this time rather than in a session scratchpad.
Each is standalone and adds the repo to the path itself.

| script | what it produces |
|---|---|
| `geom2.m` | the budget geometry in section 1: cliff location by `u1`, `m` at each `u2` node |
| `interp_test.m` | the six-scheme table, three values of `u1` |
| `interp_robust.m` | the same over 54 surrogate and grid configurations |
| `verify_steps.m` | the bit-identity check and the three-step comparison |
| `grid_x_object.m` | the 2x2 full solves; writes `grid_x_object.mat` |
| `coord_jump.m` | the 66-to-67 ratios for the three candidate first coordinates |

---

## 6. The charts, actually solved in

Sections 4.2 to 4.4 measured where households sit when one simulated panel is
re-expressed in different algebra. That is geometry, not evidence: it says
nothing about whether solving in a chart gives a better answer. This section
solves in them.

### 6.1 What was built

`p.coord1` in `+config/coord1.m`, default `'yw'`:

| value | first axis |
|---|---|
| `'yw'` | `lambda = Y/W` — the existing coordinate, bit-identical |
| `'yann'` | `(Y + net annuity payout)/W = lambda + af_t * s_A` |
| `'hk'` | `HK/(HK + financial wealth)`, `HK = (1 + phi_t) * Y` |

Each is a monotone reparametrisation of `lambda` at fixed `(u2, u3)` with a
closed-form inverse, so no state is added. The DC balance `'yann'` needs is
recoverable from the coordinates as `s_A = u2 (1-lambda) u3`, which is why the
forward map takes `(lambda, u2, u3)` like the inverse and why no call site in the
solver changed: one wrapper on `pp_z` reconciles axis coordinates with the
lambda-style state every call site already computes. Touched:
`+config/coord1.m` and `+config/hk_factor.m` (new), the grid construction and
anchor splice in `+solver/bellman_step_lna.m`, `+utility/build_state_grids.m`,
`+config/insert_anchor_nodes.m`, and the policy lookup in `+simulate/paths_lna.m`.

### 6.2 Verified before anything was quoted

- **Round trip.** `inv(fwd(lambda))` over the lambda range, the unit square of
  `(u2, u3)` and every age: max error 0 / 2.5e-16 / 5.7e-15.
- **`'yw'` is bit-identical** to a value function solved before the refactor
  existed: `isequal(V) = 1`, `max|dV| = 0`, `max|dc| = 0`, `max|dpi| = 0`.
- **No off-grid extrapolation** in any of the nine solves below.

The round trip earned its place. The first version defined `HK` as the present
value of income **still to come**, which goes to zero at the end of life, so the
map became constant in `lambda` and destroyed the income state exactly where the
retired population lives. It still built a grid, still solved, still simulated,
and still returned entirely plausible numbers — `pi` at 25 of 0.41 against the
0.71-1.00 every other configuration gives. Only the round trip caught it.
Counting the current payment, `HK = (1 + phi_t) Y`, keeps `P >= 1` so the chart
stays invertible and degenerates to `'yw'` rather than to a point.

### 6.3 Do the charts agree? Yes after 40, no before

Three charts, three grid sizes, 4000 simulated households, common seed. Three
relabellings of one model must agree in the limit, so the gap between them is a
test of both the implementation and the model.

Mean `|dC|/C` between charts, and the equity-share gap in midlife:

| pair | 1152 | 2560 | 4800 |
|---|---|---|---|
| `yw` vs `yann`, ages 25-39 | 17.0% | 17.5% | **26.0%** |
| `yw` vs `hk`, ages 25-39 | 31.7% | 39.9% | **43.8%** |
| `yw` vs `yann`, ages 40-69 | 3.0% | 3.0% | **2.1%** |
| `yw` vs `hk`, ages 40-69 | 8.0% | 6.4% | **2.9%** |
| `yw` vs `hk`, ages 70+ | 4.7% | 3.5% | **1.9%** |
| `|d pi|` 40-69, `yw` vs `hk` | 0.145 | 0.050 | **0.033** |

From 40 on, three independently implemented coordinate systems converge on each
other — consumption to within 2-3% and the equity share to 0.03. That is the
strongest check available that the algebra is right in all three, and it is the
check none of the earlier coordinate work had.

Before 40 they diverge, and diverge *faster* the finer the grid. That is the
accumulation-phase non-identification, now shown by a third independent lever
after grid density and node placement. No chart rescues it: within-chart drift
across the last refinement is 15.3% for `yw`, 11.0% for `yann`, 23.7% for `hk`.

### 6.4 Retirement: `hk` is the best of the three

Roughness of the simulated equity share, ages 65-84:

| chart | 1152 | 2560 | 4800 |
|---|---|---|---|
| `yw` | 6.32% | 4.38% | **4.38%** — plateaued |
| `yann` | 13.19% | 6.19% | 4.32% |
| `hk` | 6.98% | 3.59% | **3.06%** — still falling |

Which is what the continuity argument predicted: `hk` is the only chart whose
first coordinate does not step at 67, and it is the only one still improving at
the finest grid where the default has stopped. `yann` starts far worse and ends
level with `yw`, so halving the step is not enough to buy anything.

The cost is midlife. `hk`'s own drift at 40-69 is 9.7% then 6.1% against `yw`'s
3.8% then 2.0%, and its `C45` wanders 24391 / 22812 / 24386 rather than settling.
It is the better chart in retirement and the worse one in the middle.

### 6.5 What this does and does not support

Supported: the implementation is correct, by three checks. The accumulation
phase is not identified, by a third independent route. `hk` is measurably better
in retirement and still improving under refinement.

Not supported: that any chart is ready to replace `'yw'` in production. `hk`
trades midlife accuracy for retirement smoothness and nothing here says that
trade is worth making. All nine solves are `gh_n = 3`, `use_refine = false`,
1152-4800 nodes against a production cube of about 11,200, renter only.

---

## 7. A grid for the current coordinates

Current chart, no alternative charts. The brief: wide enough to clip nothing,
dense where households actually are.

### 7.1 How much of the cube is dead

Over 438,000 simulated household-years, ages 27+:

| axis | min | max | current axis |
|---|---|---|---|
| `u1 = Y/W` | 0.0022 | **0.3852** | [0.0020, 0.6000] |
| `u2` illiquid share | **0.5869** | 1.0000 | [0.0000, 1.0000] |
| `u3` DC share | 0.0350 | 0.9509 | [0.0000, 1.0000] |

The top 36% of the `u1` axis and the bottom 59% of `u2` are never visited by any
household at any age. Roughly half the cube is nodes spent on states that cannot
occur.

### 7.2 The design

Trimming the axes to the measured range and bunching `u1` low does as well as
laying the interior out by measured quantiles, and it is four numbers rather than
a stored table:

```matlab
p.lambda_hi   = 0.42;    % u1 never exceeded 0.385
p.grid_pow    = 1.6;     % u1 falls through life, bunch its nodes low
p.u2_lo       = 0.45;    % see 7.4 -- NOT 0.55, and NOT the 0.60 in HANDOVER.md
p.grid_pow_u2 = 1;       % u2 slides rather than falling, it wants even coverage
p.u3_lo       = 0.03;    % u3 never left [0.035, 0.951]
p.u3_hi       = 0.96;
```

`p.u3_lo` and `p.u3_hi` are new in `+utility/build_state_grids.m`; default
`[0, 1]`, so nothing changes unless they are set. Nodes under the population,
mean across ages / worst age / ages with fewer than two:

| | `u1` | `u2` | `u3` |
|---|---|---|---|
| default | 3.0 / 0 / **20** | 3.5 / 1 / 11 | 3.5 / 0 / 5 |
| designed | **6.2 / 3 / 0** | **9.1 / 1 / 2** | **4.8 / 0 / 3** |

### 7.3 What it buys, and what it costs

Six solves, three sizes each. Roughness of the simulated equity share, and
consumption drift between successive refinements:

| | 1152 | 2560 | 4800 |
|---|---|---|---|
| `|d2 pi|` retirement, default | 6.32% | 4.38% | **4.38%** — plateaued |
| `|d2 pi|` retirement, designed | 3.66% | 2.59% | **2.37%** — still falling |
| drift 70+, default | | 2.0% | 1.3% |
| drift 70+, designed | | 1.6% | **1.0%** |
| drift 25-39, default | | 14.4% | 15.3% |
| drift 25-39, designed | | 27.1% | **25.4%** |

Retirement and old age are clearly better and, unlike the default, still
improving at the finest grid. **Early life is clearly worse**, and consumption at
25 collapses: 6564 / 2520 / 2214 with `pi` at 25 going 1.00 / 0.01 / 0.00.

### 7.4 Two things the follow-ups caught

**The occupancy is endogenous, and designing against the wrong one clips.**
`u2_lo = 0.55` was set from the default grid's occupancy. On the designed grid
the policies moved and `u2` reached 0.4884, so five lookups were silently
nearest-extrapolated. At `u2_lo = 0.45` the minimum observed is 0.537-0.545 and
nothing falls off at any of the three sizes. `HANDOVER.md`'s 0.60 clips harder
for the same reason. Any axis trimmed from measured occupancy needs one
iteration and a margin.

**The early-life regression is not a design error.** Isolating it at 2560 nodes:

| grid | `C` at 25 | `pi` at 25 |
|---|---|---|
| default | 7566 | 1.00 |
| `u1` and `u3` trimmed, `u2` left alone | 3231 | 0.56 |
| all three trimmed | 2520 | 0.01 |

Both trims push the same way, so it is not the `u2` density specifically. The
ruin surface lives at low `u1` -- below about 0.10, from section 1 -- and that is
also where the retired population lives. **Bunching `u1` low is simultaneously
the right thing for retirement and the thing that resolves more of the poisoned
region.** The two goals collide on one axis, and no placement can serve both
while the accumulation phase has no limit to converge to.

### 7.5 Use

Turn the six settings on and read ages 40+ from them: retirement roughness
roughly halves and keeps improving, old-age drift falls, and nothing clips. Do
not read accumulation-phase numbers off this grid -- they are worse than the
default's, for a reason that is understood and is not fixable by node placement.
