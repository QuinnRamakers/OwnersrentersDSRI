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

## 1. The bounds of the consumption search

**The rule.** `+solver/bellman_step_lna.m`, lines 249-251 and 279-280. The
choice c is the share of liquid resources LW consumed. LW is liquid savings
plus take-home income (in retirement, plus the net annuity) less the housing
cost. W = X + A + H + Y is total wealth: liquid savings, pension pot, house or
rent index, and this year's gross income. At every grid point where LW is
above the consumption floor, the sweep (lines 349-353) and `fmincon` both
search c in

    [c_floor, 1 - 1e-6],   c_floor = min( max(0.001, c_floor_frac * W / LW), 0.5 ),   c_floor_frac = 0.01

In euros, consumption C = c * LW is searched in

    C_min = min( 1% of W, 50% of LW )   to   C_max = (1 - 1e-6) * LW.

The 0.001 inside c_floor never binds, so it is left out of C_min. LW is at
most W at every state (take-home income is at most gross income, the annuity
price is at least 1, housing costs are not negative), so 1% of W is at least
1% of LW. Grid points with LW at or below the floor never reach this line
(line 226). An earlier version of this file said the 0.1% applied where LW is
near zero; it does not apply anywhere.

The lower bound is a numerical choice (`c_floor_frac`). The upper bound is
economics: the no-borrowing constraint of Cocco, Gomes and Maenhout (2005).
The household cannot consume more than its liquid resources, and cannot
borrow against income, the house or the pension pot. The margin of 1e-6
keeps next year's liquid wealth positive.

Where the solver does not search:

1. Below the floor, consumption is the floor, phi_floor times gross income;
   the solver stores c = 1 and pi = 0 (section 3).
2. At 100, the household consumes all of LW (c = 1, lines 81-107). With a
   bequest motive (chi > 0, not used) c has a closed form, clamped to
   [1e-6, 1].

In the simulation (`+simulate/paths_lna.m`, lines 160-174), c is read by
linear interpolation between grid points and clamped to [0, 1], not to the
search range. Consumption is c * max(LW, 0), or the floor where LW is below it.
A simulated household can therefore sit slightly below the bound at its own
state, or consume all of LW. The simulation records the lower bound at each
household's state (line 174). `model.checks` counts a household-year as at
the bound when it is not floored and c is at most 1.02 times that bound
(`+model/summarize.m`, line 89), and reports the share at ages 25-39
(`c_bound_25_39`). How often households sit at the upper bound is not
counted anywhere.

**Why the lower bound is there.** With gamma = 5, utility goes to minus infinity as
consumption goes to zero, and the search is kept away from that region.
`CALIBRATION.md` lists `c_floor_frac` as a numerical bound. In
certainty-equivalent units the objective stays finite as consumption goes to
zero, so this reason would go away (`docs/SOLVER_COMPARISON_MK.md`, section 1).

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
   is not wealth. Their minimum consumption scales with their rent. A renter
   at entry must also consume at least 5.1% of income, about EUR 1,500.
4. W also includes the DC pot, so once the DC pillar is on the minimum grows
   with the pot, which cannot be spent before 67.

**How often the lower bound binds** (share of simulated household-years at the bound,
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

**The coauthor's model (MK).** There c is a share of total wealth W (which
also includes the house and this year's income), with bounds 1e-4 <= c <= 1
(`main_jmp.m`, lines 80-81). The lower bound is 100 times smaller than ours,
a fixed share of W, and has no cap. Its objective is in certainty-equivalent
units, which stay finite as consumption goes to zero, so there the bound is
only a guard. The budget and loan-to-value constraints set a tighter upper
bound (`opt_rent_buy.m`, lines 17-18 and 52-55; `main_jmp.m`, lines 325-328):

1. Renter: c <= 0.8 of W. The rent is tied to consumption, so consumption
   plus rent can take all of W.
2. Buyer: c <= 1 - 0.275 q, with q >= 0.1 the new house as a share of W.
3. Stayer: c <= 1 - 0.215 q, with q the current house.

The 0.275 and 0.215 are the house's price, purchase cost (6%) and maintenance
(1.5%) less the 80% the household may borrow against it. The mortgage can be
raised to 80% of the house every year, so MK's owners can consume their home
equity down to 20% of the house. That is option 1 under `TODO.md` item 1
(owners' access to housing equity), built in. Ours cannot touch the house.
How often MK's bounds bind is not measured (no MATLAB in this container).
With an EIS of 0.1, a lower bound of 1e-4 of W is unlikely to bind.

**Decision needed.**

1. The lower bound: whether the household may consume less than 1% of total
   wealth, whether the bound should be a share of LW or of income instead of
   W (W holds the house, the rent index and the DC pot), and whether the 50%
   cap should go. Decide together with the consumption floor (`TODO.md`,
   item 1): with a floor of 1e-6 times income, the household wants to
   consume almost nothing to avoid later floor states, so any lower bound
   will bind. If the bound is lowered, give `fmincon` the objective in
   certainty-equivalent units first (`docs/SOLVER_COMPARISON_MK.md`,
   section 1), so that a bound near zero is numerically safe.
2. The upper bound: keep no borrowing, as in Cocco, Gomes and Maenhout,
   unless owners get access to their housing equity. Then the owner's upper
   bound rises above LW, as in MK.
3. Either way, count the household-years at the upper bound (c >= 0.999,
   not floored) in `model.checks`, alongside `c_bound_25_39`.

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
with active-set at every ladder step. `docs/SOLVER_COMPARISON_MK.md` proposes
giving fmincon the objective in certainty-equivalent units instead, as the
coauthor's code does, which removes the scaling problem; not yet tried.

## 7. Small technical bounds

1. Consumption at most 1 - 1e-6 of liquid resources (`bellman_step_lna.m`,
   line 251): no borrowing, with a margin (section 1).
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
