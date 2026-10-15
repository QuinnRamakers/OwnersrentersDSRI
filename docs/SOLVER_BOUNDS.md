# Bounds in the solver and the simulation

The solver and the simulation contain limits that are not part of the
economics. This file lists each one: where it is in the code, what it does in
economic terms, how often it binds where that has been measured, and whether
it needs a decision. None of them has been changed. Line numbers refer to
`main` on 15 October 2026.

Measurements are from the step-7 solves of the grid study (standard numerics,
10,000 simulated households, starting savings b0 = 0.079 years of income):
the current grid as run (16x16) and the reference, log-wealth 128x96
(`diagnostics/grid_design/`).

## 1. The lower bound of the consumption search

**The rule.** `+solver/bellman_step_lna.m`, lines 249-251. At every grid
point the search over c, the share of liquid resources LW consumed, starts at

    c_floor = min( max(0.001, c_floor_frac * W / LW), 0.5 ),   c_floor_frac = 0.01

with W = X + A + H + Y (liquid savings, pension pot, house or rent index, and
this year's gross income) and LW = liquid resources after take-home income and
housing costs. The global sweep and `fmincon` both search c in
[c_floor, 1], so the lowest consumption the solver can choose is

    C_min = max( 0.1% of LW, min( 1% of W, 50% of LW ) ).

The simulation records the same bound (`+simulate/paths_lna.m`, line 174), and
`model.checks` reports the share of households aged 25-39 at it
(`c_bound_25_39`).

**Why it is there.** With gamma = 5, utility goes to minus infinity as
consumption goes to zero, and the search is kept away from that region.
`CALIBRATION.md` lists `c_floor_frac` as a numerical bound.

**What it means economically.**

1. The bound is a share of total wealth, and W includes the house. A young
   owner at entry (W = 5.08 years of income) must consume at least 5.1% of
   income, about EUR 2,000 a year. As the house appreciates, the minimum
   rises with it.
2. The 50% cap reverses the direction of the bound where the house is large
   relative to cash. When LW < 2% of W, the bound is "consume at least half
   of liquid resources". An owner at 45 with no savings and a house of 15
   years of income has LW = 0.16 and W = 16 years of income, so the solver
   cannot let them save more than half of their cash. These are the
   households closest to bankruptcy, who would save the most.
3. For renters, W includes the rent index (4 years of income at entry), which
   is not wealth. Their minimum consumption scales with their rent.
4. The 0.1% minimum only applies where LW is negative or near zero; those
   households are at the consumption floor anyway.

**How often it binds** (share of simulated household-years at the bound,
excluding households at the consumption floor):

| Solve | Ages 25-39 | 40-66 | 67+ | 50% cap in force, 67+ | At the cap |
|---|---|---|---|---|---|
| Owner, current 16x16 | 0% | 0% | 0% | 17.3% | 0% |
| Owner, log-wealth 128x96 | 100% | 99.3% | 48.1% | 0.16% | 0.07% |
| Renter, current 16x16 | 0% | 0% | 0% | 0.28% | 0.03% |
| Renter, log-wealth 128x96 | 78.1% | 3.6% | 0% | 0.01% | 0% |

**Consequence.** On the converged grids the owner's consumption is the bound,
1% of total wealth, for all of working life and half of retirement. The
consumption path in the step-7 dashboards (low, rising with the house value,
then a jump after 80) is therefore set by `c_floor_frac`, not chosen. The
young renter's consumption is the bound as well. On the current grid the
bound never binds, because that grid does not see the old-age bankruptcy risk
that makes households want to consume less. The 50% cap is in force for 17%
of the current-grid owners' retirement years but no one sits at it there.

**Decision needed.** Whether the household should be allowed to consume less
than 1% of total wealth, whether the bound should be a share of LW or of
income instead of W, and whether the 50% cap should go. Decide together with
the consumption floor (`TODO.md`, item 1): with a floor of 1e-6 times income,
the household wants to consume almost nothing to avoid later floor states,
so any lower bound will bind.

## 2. The sweep's step in consumption

**The rule.** `+solver/bellman_step_lna.m`, lines 346-355. The global sweep
first evaluates 21 values of c across [c_floor, 1), steps of about 0.05 of
LW, against 21 equity shares. Each later round searches a 9 x 9 window
around the best point, of half-width dc for consumption and dp for the
equity share, and shrinks it by four. For the equity share dp starts at 0.05,
the full round-1 step. For consumption dc starts at (1 - c_floor)/160, about
0.006, a quarter of the round-1 half-step.

**What it means.** Between 0.006 and 0.025 away from the best round-1 point
the sweep never looks. `fmincon` searches from the sweep's best point and
normally closes the gap, but where it fails, consumption can be off by up to
about 2.5% of liquid resources. Not measured.

**Decision needed.** None economic; set dc to the round-1 half-step.

## 3. The policy stored at grid points below the floor

**The rule.** `+solver/bellman_step_lna.m`, line 242. At grid points where
liquid resources are below the floor, the solver stores c = 1 and pi = 0 (the
household consumes the floor and saves nothing).

**What it means.** The simulation reads c and pi by linear interpolation
between grid points (`+simulate/paths_lna.m`, lines 160-163). A solvent
household in a cell next to a bankrupt grid point inherits part of
"consume everything", which can push it into bankruptcy the next year. Not
measured.

**Decision needed.** None economic. Either interpolate the policy as a share
of resources above the floor, or check how many simulated households are
affected.

## 4. The ends of the grid

**The rule.** The value function and the policies are read beyond the grid
by flat extrapolation from the nearest edge (`+solver/bellman_step_lna.m`,
lines 143-144). The simulation clamps the state to the grid and counts the
lookups that were outside (`+simulate/paths_lna.m`, lines 156-157;
`model.checks` reports `offgrid`). With housing the u1 axis runs from 0.0002
to 0.6, total wealth of 0.67 to 4,999 years of income; without housing from
0.0008 to 1.

**What it means.** A household richer than 4,999 years of income, or with
less than 0.67, is valued as if it sat on the edge. Off-grid lookups were 0
at step 7 and in its grid-study solves. Elsewhere: 24 and 31 of 760,000
household-years at step 10 (renter, owner; all-stock pension pots), and 65 and
70 in the constant-house-price variant of step 7.

**Decision needed.** None while `offgrid` stays at 0.

## 5. Non-finite values replaced by the worst value

**The rule.** `+solver/bellman_step_lna.m`, lines 133-140. Where next year's
value is not finite, the transformed value z is set to the smallest finite z
of that age.

**What it means.** Such points are treated as the worst state on the grid.
How often this happens is not counted.

**Decision needed.** None; add a counter to `model.checks`.

## 6. The limits of the local solver

**The rule.** `+solver/bellman_step_lna.m`, lines 152-178 and 286-292.
`fmincon` runs with at most 200 iterations and 500 objective evaluations
(central differences). A run that stops at the limit (exit flag 0) is still
accepted when it beats the sweep. The objective is divided by the median
absolute value of next year's value function, while that value spans about
25 orders of magnitude.

**What it means.** Where the objective is very flat or very steep relative to
the scaling, the tolerances are effectively loose or tight. This is how
interior-point came to differ from active-set by up to 0.005 in the equity
share at nodes where the share hardly matters (`HANDOFF.md`, 12 October).

**Decision needed.** None for now; the solver stop rule compares interior-point
with active-set at every ladder step.

## 7. Small technical bounds

1. Consumption at most all liquid resources (`bellman_step_lna.m`, lines 251
   and 280): no borrowing. Until 15 October the limit was 1 - 1e-6 of liquid
   resources.
2. The floor has a minimum of 1e-12 of W (`FLOOR_EPS`, line 69).
3. The survival probability in the pension fund's survival credit is bounded
   below by 1e-8 (`paths_lna.m`, line 202).
4. At age 100 the household consumes all liquid resources (lines 81-107).

None of these binds in a way that matters.

## 8. Economic limits, for completeness

1. The equity share is between 0 and 1: no leverage and no short sales, as in
   Cocco, Gomes and Maenhout (2005).
2. No borrowing against income, the house or the pension.
3. The consumption floor phi_floor times gross income, paid from outside when
   resources fall short, with the shortfall not carried as debt
   (`bellman_step_lna.m`, lines 224-244). Its level is `TODO.md`, item 1.
