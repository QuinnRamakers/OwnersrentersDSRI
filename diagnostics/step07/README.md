# Step 7 diagnosis

Why step 7 (housing) does not converge on the grid, and what a higher
consumption floor does about it. The findings are in HANDOFF.md (entries of
2026-10-12) and TODO.md item 1; this folder holds the scripts that produced
them. None of it changes the model.

## What each script does

1. `solve_cases.m` solves the step-7 variants: constant house prices, no
   maintenance, house-price risk without growth, owner floors of 0.1, 0.2, 0.3
   and 0.5 times income, a renter floor of 0.1, and two renter grid
   refinements. Each two-grid case is solved on the standard grid
   [16 16 10] and with the income axis doubled [32 16 10]. About 25 minutes.
2. `ruin_figures.m` draws five figures for the step-7 owner: why one year at
   the floor dominates, what the solver sees along the no-savings grid line,
   the value over savings and house value, slices at the typical household's
   savings with a map of the grid points each slice is interpolated from, and
   the 27-year-old's choice. `ruin_figures()` uses step 7 as run
   with constant house prices as the contrast; `ruin_figures(0.3)` uses a
   floor of 0.3 with step 7 as run as the contrast.
3. `floor_overview.m` puts all floors on one page and prints the largest gap
   between the grids for each.
4. `grid_map.m` shows where the solver's grid points lie per unit of income.
5. `dashboards_pdf.m` draws every test as twelve-panel dashboards, against
   step 7 as run and as its own coarse against fine grid, and collects them
   with the step-7 robustness pages in one PDF.

## Running them

From the repository root, after `ladder.run(7)` and `ladder.robustness(7)` at
standard numerics:

```matlab
addpath diagnostics/step07
solve_cases
ruin_figures; for f = [0.1 0.2 0.3 0.5], ruin_figures(f); end
floor_overview; grid_map; dashboards_pdf
```

Results go to `ladder/standard_16x16x10_gh5/diagnosis/data/` and figures to
`ladder/standard_16x16x10_gh5/diagnosis/`. Both are gitignored, so they exist
only on the machine that ran them.
