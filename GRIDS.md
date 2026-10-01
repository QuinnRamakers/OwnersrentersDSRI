# Choosing the state grid

The cube is three axes in normalised coordinates:

| axis | meaning | runs over |
|------|---------|-----------|
| `u1` | `Y / W`, income as a share of wealth | a positive floor up to a cap set by housing |
| `u2` | `(A + H) / (W - Y)`, illiquid share of non-income wealth | `[0, 1]` |
| `u3` | `A / (A + H)`, pension share of the illiquid block | `[0, 1]` |

For a renter `H` is a rent index rather than a house. It has no resale and no
bequest value, and its only role is to set the rent `alpha * H`, but it sits
inside `W` like any other stock, because the rent obligation has to be a state
the household carries. That is a modelling choice, not an accident, and it has
a consequence for the grid: a state with a small `u1` and a large `u2` is a
household whose wealth is mostly an obligation and whose income is small beside
it. Those states are worth close to nothing, they form a region on the income
axis, and the upper edge of that region moves with the rent. Where it lands
relative to the population is what decides whether the early-life policies
converge, so the axes cannot be a set of constants carried between
calibrations.

There are three ways to set them, in increasing order of effort.

## 1. Automatic

```matlab
p = config.params();
p.is_owner = false;
[p, rep] = utility.auto_state_grids(p, [20 20 12], 5);
% ... solve as usual with p
```

`utility.auto_state_grids` measures where households end up and places the
nodes to equidistribute occupancy density against the curvature of the value
function, with a margin of nodes carrying on to the axis ends. It needs no
calibrated constants and follows the population wherever a new calibration puts
it.

It gets that measurement one of two ways, and the difference matters -- see
**What it was measured against** below. Hand it a panel you already trust and
it uses that:

```matlab
[p, rep] = utility.auto_state_grids(p, [20 20 12], 5, struct('sim', s));
```

With no panel it solves a small pilot cube of its own. That path is cheaper and
fully automatic, but on the production renter it placed worse than hand-set
values, because a coarse pilot mis-measures the illiquid axis.

The pilot costs one coarse solve. It is cached against the calibration in
`+utility/grid_cache.mat` and reused until something that moves the ergodic
distribution changes — grid sizes are deliberately not part of the key, so the
same pilot serves every cube size. Pass `struct('force', true)` to re-run it.

Options worth knowing (all optional, in the fourth argument):

| option | default | what it does |
|--------|---------|--------------|
| `band` | `[1 99]` | percentiles bounding the occupied band |
| `margin` | `0.25` | share of nodes spent outside the band |
| `weight` | `0.75` | monitor-versus-even mix inside the band |
| `dens_pow` | `0.5` | weight on occupancy density in the monitor |
| `curv_pow` | `0.5` | weight on value-function curvature in the monitor |
| `sim` | none | a panel to measure instead of running a pilot |
| `pad` | `0` | widen the band by this share of its width |
| `pilot_dims` | `[10 10 8]` | cube for the pilot |
| `pilot_gh` | `3` | quadrature nodes for the pilot |
| `n_sim` | `4000` | households simulated in the pilot |
| `force` | `false` | ignore a cached pilot |

Do not set `margin` to zero. Past the last node `griddedInterpolant`
extrapolates `nearest`, which is flat, so a household pushed off the end gets a
continuation value with no gradient and no warning. The margin nodes are also
what represents the fall in value below the occupied band on the income axis,
rather than truncating it.

## 2. Manual, one axis at a time

```matlab
p.grid_nodes.u1 = [0.02 0.05 0.08 0.11 0.14 0.17 0.21 0.26 0.34 0.44].';
p = utility.build_state_grids(p, [10 16 10], 5);
```

`p.grid_nodes` takes the axes themselves. A field that is absent or empty falls
through to the rule-based placement, so one axis can be pinned and the others
left alone. The welfare anchors are still spliced in afterwards, so an axis can
come back up to two nodes longer than what was handed in — read the sizes back
off `p.N_u1`, `p.N_u2`, `p.N_u3`, never off the `dims` you passed.

Nodes must be finite, distinct and sorted; `u2` and `u3` must lie in `[0, 1]`
and `u1` must be strictly positive. A violation is an error at the call site,
not a silent clamp later.

## 3. Manual, by rule

Primitives of `config.params`, all at their full-axis, uniform defaults except
`lambda_lo`:

| field | axis | default | effect |
|-------|------|---------|--------|
| `lambda_lo`, `lambda_hi` | `u1` | 0.0008, `[]` | ends of the income axis; `[]` is `min(0.9, 3/(1 + h_mult))`, or 1 without housing |
| `grid_pow` | `u1` | 1 | `> 1` bunches nodes toward the low end |
| `u2_lo` | `u2` | 0 | bottom of the illiquid axis |
| `grid_pow_u2` | `u2` | 1 | `> 1` bunches nodes toward 1 |
| `u3_lo`, `u3_hi` | `u3` | 0, 1 | ends of the pension-share axis |

The research branch also has `grid_space = 'logratio'`; it lost to uniform
spacing on accuracy at working resolution and is not carried here.

Set these only from a measured occupancy range. The values that suit one
calibration do not transfer: `lambda_hi = 0.26` and `u2_lo = 0.55` were
measured on the production renter and are wrong for a different rent.

## Checking a grid

```matlab
occ = utility.occupancy(p, s);            % s from simulate.forward
```

returns the pooled sample and quantiles per axis, plus the per-age 5-95 band.
Two things are worth looking at before trusting a solve:

- **Coverage.** How many nodes fall inside the occupied 1-99 band. A handful
  means the population is living inside one or two cells and the policies will
  move with every refinement.
- **Waste.** How many nodes fall outside it. Those are not free; they are nodes
  not spent where the households are.

`model.checks` reports the coverage of u1 and u2 for every run
(`r.checks.cov_u1_min`, `cov_u2_min`), and the research branch's
`diagnostics/fig_occupancy.m` draws both.

## What this does not fix

The automatic grid puts nodes where the population is. It does not remove the
low-`u1` region where the value function collapses, because that region is the
rent obligation and the obligation is part of the model. On the production
renter calibration, at 5808 nodes, the upper edge of that region reaches into
the band 34-year-olds occupy, and it has not stopped moving with resolution.
Early-life equity shares should not be quoted until that is resolved, whichever
grid is used. `diagnostics/NOTES_optimiser_local_optima.md` on the research
branch (`solver-active-set`) has the evidence.

## Axes that collapse

Without housing and without a DC pillar the household never holds A or H, so
u2 = u3 = 0 on every path; without housing u3 is 0 or 1; without a DC pillar
it is 0. `utility.build_state_grids` gives such axes the two nodes {0, 1}
whatever the requested size, since the solve on the occupied line does not
depend on the nodes removed. This is why the first steps of the calibration
ladder solve in seconds.

## What it was measured against

All arms at 3,240 nodes, production solver settings, distance from the
8,064-node reference on simulated paths. Levels of welfare are not comparable
across grids, so the comparison is on the decisions.

| arm | dpi accumulation | dpi retirement | dC/C | off-grid lookups |
|-----|-----|-----|-----|-----|
| baseline (wide defaults) | 0.1460 | 0.0372 | 0.3763 | 0 |
| hand-set values | 0.1445 | **0.0249** | **0.1265** | 98 |
| automatic, from a trusted panel | **0.1252** | 0.0284 | 0.1979 | 4845 |
| automatic, from the pilot | 0.1637 | 0.0323 | 0.2769 | 0 |
| automatic, pilot + padded band | 0.1600 | 0.0395 | 0.3064 | 0 |

Read it as follows.

**From a trusted panel the automatic grid is worth using.** It has the smallest
accumulation error of any arm, beating values tuned by hand for this exact
calibration, and it is close on the other two. It needs no constants.

**From the pilot it is not yet a replacement for tuning.** The rule is not the
problem; the input is. A pilot on 1152 nodes puts the 1st percentile of the
illiquid share at 0.75 where a production panel puts it at 0.59, so the axis
starts two thirds of a band width too high and the young renters, who sit
lowest on that axis, end up in the margin. Both placement rules tried --
equal-probability and curvature-weighted -- give the same answer when fed the
same wrong band, which is what identified the input as the culprit.

**Padding the pilot's band does not rescue it.** It was tried and made the
retirement share worse, so `pad` defaults to zero.

So the workflow that pays is two solves:

```matlab
p = config.params(); p.is_owner = false;
p = utility.build_state_grids(p, [16 16 10], 5);     % any reasonable grid
% ... solve, simulate -> s ...

p2 = config.params(); p2.is_owner = false;
p2 = utility.auto_state_grids(p2, [16 16 10], 5, struct('sim', s));
% ... solve again on p2 ...
```

which is what hand-tuning is, without the human in the loop, and it carries to
a new calibration unchanged.

## About the off-grid column

Liquid wealth never goes negative. The simulator carries `X_post = max(LW - C, 0)`
and floors consumption at `phi_floor * Y` when resources fall short, so `s_X >= 0`
and `u2 <= 1` by construction; measured over the production panel the largest
`u2` is 1 + 2.2e-16, one unit in the last place.

The off-grid counts are excursions on the income axis instead, and they are a
property of how wide the axis was made rather than of the model. The automatic
grid sets its hard ends from the sample it measured, and the ends of a sample
are where its own noise lives, so the headroom has to be generous: a version
that used 0.8 times the observed minimum left three per cent of room and a
fresh draw went off the bottom. Headroom costs almost nothing, since the tail
nodes are placed by distance from the occupied band and only the outermost node
moves.
