# Grid design for step 7

Step 7 (housing) does not converge on the current state grid. The u1 axis
(income over total wealth) is evenly spaced between 0.0002 and 0.6, so in
wealth over income its points jump from 11.5 to 23.9 to 4,999 (16 base nodes),
and the u2 axis (house over savings plus house) has no regular point between
0.933 and 1. Young owners' value falls by four to five orders of magnitude
between wealth of about 4 and 25 years of income, and retired owners go
bankrupt at houses above 67 years of income, where the only point is at 4,999.

This folder tests other placements through `p.grid_nodes`, without changing
the production grid. Nothing here changes the model.

## Scripts

1. `grid_rule.m` returns the nodes of a named rule at N1 x N2 base nodes.
   `uniform` is the current placement. `logwealth` spaces u1 evenly in a
   stretched log of wealth over income, three times denser between 2 and 60
   than below 2 or above 60, and puts half the u2 nodes evenly on [0, 0.9] and
   half evenly in the log of savings over house value from 0.11 to 0.0005,
   then u2 = 1. `edge` is `logwealth` with grid points on the bankruptcy
   edge, s = k - u1 (1 + k): the u1 nodes nearest its two corners (wealth
   17.9 and 66.7 years of income at zero savings) move onto them, and the u2
   nodes near 1 move onto the edge's values at the u1 nodes.
2. `solve_grids.m` solves step 7 (owner by default) on each case named
   `<rule>_<N1>x<N2>` and saves it under
   `ladder/standard_16x16x10_gh5/grid_design/`.
3. `compare_grids.m` prints each grid's largest gap to a dense reference and
   draws the robustness page and the overlay dashboard.
4. Figures 1-3 for any pair of solves come from
   `diagnostics/step07/ruin_figures([], files=..., figures=1:3)`.

## Running them

From the repository root, after `ladder.run(7)` and `ladder.robustness(7)` at
standard numerics:

```matlab
addpath diagnostics/grid_design diagnostics/step07
solve_grids
compare_grids
```
