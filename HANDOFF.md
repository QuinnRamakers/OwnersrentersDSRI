# Handoff

The shared log between chat (Claude on claude.ai) and Claude Code. Newest entry first in each section.

Rules:
1. Chat writes only under "Specs". Claude Code writes only under "Log".
2. A spec is marked done by adding one line under it, "Done: <date of the log entry>". Nothing else is edited.
3. A log entry is not complete without the commit hash and the numbers the checks printed.
4. If this file and chat disagree, this file wins.

## Specs (from chat)

### 2026-10-12 Calibration ladder, part 1: CGM core, DHS income, market, income-stock correlation
Written by chat on 12 Oct against d8efb70; Quinn pasted it into Claude Code, which copied it here in short. Values from calibration_notes.pdf (12 Oct 2026), Tables 2-4.
Answers to the plan's questions 1-4:
1. Income: log y = a0 + a1 age + a2 age^2/10 + a3 age^3/100, gross income of the household head, DHS waves 1993-2024, heads aged 25-65, separate owner and renter estimates, 2025 euros. Code coefficients [a0, a1, 10 a2, 100 a3]: owner [7.7979, 0.17253, -0.2784, 0.1405], sigma 0.0816; renter [7.5302, 0.17828, -0.3126, 0.1784], sigma 0.0843.
2. Variance: permanent shock only for now (DHS transitory sd 0.119 owner, 0.138 renter; CGM 0.272).
3. Market: real. r 0.0115 (NL 3-month interbank, FRED IR3TIB01NLM156N, CBS CPI, 1982-2024); premium 0.0456 and vol 0.2161 (real, 2000-2024). Correlations from the same pipeline; corr_SL 0.04 for both groups (gross, pooled, all households, 2002-2023, T = 22).
4. Retirement income: CGM's 68.2% of final income until the pension step.
Change: ladder steps 1-3 unchanged; 4 income (DHS, owner and renter), 5 market, 6 corr_SL (new); housing, pension, inctax, box3 follow unchanged. Code first: an income source 'dhs' with a price factor, usable with a DC pillar; renter income primitives; two no-housing arms (nohousing_owner, nohousing_renter) when the renter fields differ; config.params equal to the last step; correlation check on the nodes and in the panel. Then run one step at a time at standard numerics, stopping after each for review, with a written expectation before each run.
Why: first block of the calibration ladder (CALIBRATION_PLAN.md); no housing, DC, taxes or REIT in it.
Checks that must pass: after the code work, steps 1-3 reproduce the baseline; full `run_tests` 0 failures; both correlations within about 0.01 of corr_SL for each arm.
Done: 2026-10-12

### 2026-10-07 Record a baseline
Change: no code change. Run the full test suite and the quick ladder once, and log the results.
Why: everything later is compared against this.
Checks that must pass: `run_tests` reports 0 failures. `ladder.run('all', numerics='quick')` finishes; log the `model.checks` values (`c_bound_25_39`, `ce_entry`) for steps 6 to 9, both tenures.
Done: 2026-10-12

## Log (from Claude Code)

### 2026-10-15 Solver comparison with the coauthor's housing model (spec: none, asked by Quinn in Claude Code)
Quinn shared a coauthor's separate model (`cons_savings_housing_MK.zip`: Epstein-Zin, rent/buy/stay choice, two ratio states) and asked what numerical choices in its solver might be smarter than ours, for example the objective and the fmincon settings.
Changed: `docs/SOLVER_COMPARISON_MK.md` (new): the two solvers side by side, what to take over, where ours already matches or does better, and small points in the MK code. `docs/SOLVER_BOUNDS.md` sections 1 and 6 point to it. No code changed.
Checks run: none in MATLAB (this cloud container has no MATLAB). A one-node toy in Python, with an interior optimum near c = 0.52: the proposed objective transform keeps the maximiser for gamma 5, 10 and 0.5, equals -1 at the seed and is increasing in the objective; for gamma 5 the objective spans -3.1e25 to -814 over c in (0, 1), the transformed one -4.4 to -1e-5.
Reading: the one real difference is the objective given to fmincon. MK's is in certainty-equivalent units (homogeneous of degree 1); ours is V_tilde in utility units, spanning about 25 orders of magnitude across nodes with one median scale per period. The CE transform is monotone, so the sweep is unchanged and only fmincon's view improves; it also stays finite as c goes to 0, which removes the numerical reason for `c_floor_frac`. Second, our 500-evaluation cap stops fmincon at about 100 iterations, before the 200-iteration cap; how often is not measured. FunctionTolerance has no effect under interior-point or sqp, in either code. Quadrature (5 Gauss-Hermite nodes per shock, Cholesky) and linear interpolation of a CE-type value are the same in both. MK has no global search, no exit-flag check, and a uniform 25 x 24 grid with the same gap above 24 times income that our grid study found.
Commit: this entry, pushed to branch `claude/ecstatic-cray-71jg7e`, not to main: this session may push only to that branch. It equalled main before this commit, so main can fast-forward to it.
Open: whether to try the CE objective (test plan in the new file, section 1: step 7 and step 11, old against new, then `ladder.robustness(7)` and the full `run_tests`), and whether to count fmincon exit flags in `model.checks`.

### 2026-10-15 The solver's numerical bounds, documented (spec: none, asked by Quinn in Claude Code)
Quinn was worried by the consumption-search bound and asked for it, and any other unexpected bounds, to be documented.
Changed: `docs/SOLVER_BOUNDS.md` (new): every limit in the solver and the simulation that is not economics, with file and line, what it does in economic terms, measurements, and whether it needs a decision. `TODO.md` items 1 and 6 and `CALIBRATION.md` (the `c_floor_frac` paragraph) point to it. No code changed.
Checks run: simulated the step-7 solves on the current grid (16x16) and the reference (log-wealth 128x96), both tenures, and counted household-years at the consumption bound (not at the floor): owner 16x16 0% at every age; owner 128x96 100% at 25-39, 99.3% at 40-66, 48.1% from 67; renter 16x16 0%; renter 128x96 78.1%, 3.6%, 0%. The 50% cap (LW < 2% of W) is in force for 17.3% of the current-grid owners' household-years from 67, but no one sits at it; in the reference for 0.16%, with 0.07% at it.
Reading: on the converged grids the owner's consumption is the bound, 1% of total wealth including the house, for all of working life and half of retirement, so the step-7 consumption path on those grids is set by `c_floor_frac`. Also documented: the sweep searches consumption only within 0.006 of the best first-round point while the first round steps by 0.05 (fmincon closes the gap); grid points below the floor store c = 1, pi = 0, which the simulation interpolates into neighbouring solvent states; flat extrapolation at the grid ends (off-grid 0 at step 7); non-finite values set to the worst value without a counter; the fmincon limits and objective scaling.
Commit: this entry, pushed to main.

### 2026-10-15 Step-7 PDF with starting savings of 1 year of income (spec: none, asked by Quinn in Claude Code)
Quinn asked for the same PDF with a higher starting wealth (thought the simulations started from zero; they start from b0 = 0.079 years of gross income, about EUR 3,100 for owners and 2,400 for renters). Chosen: 1 year of gross income.
Changed: `diagnostics/step07/restart_sim.m` (new): a saved result simulated again from other starting savings, summary and checks recomputed, solution unchanged. `ruin_figures` and `compare_grids` take `b0=`; `compare_grids` takes `out=` and reports the share aged 25-39 at the consumption bound; `recent_pdf` takes the folders, the cover's starting-savings line and the gap tables; `diagnostics/grid_design/report_b0.m` (new) draws every page and the PDF: `ladder/standard_16x16x10_gh5/grid_design/b1/step7_grid_study_b1.pdf` (gitignored). Figure 3's household dots are now solid with a white edge, so they show on dark blue (Quinn asked whether households sat at different house values on the two grids: they do not; at 85 the house-to-income ratios are identical, max difference 0, and the finer grid's households with big houses hold more savings and sat on dark blue where the old semi-transparent dots vanished).
Checks run: `checkcode` on the five scripts, no messages. Gaps to log-wealth 128x96 (b0 = 1 against 0.079):
- Owner: reference bankrupt household-years 0.32% (0.35%), owners 25-39 at the bound 100% (100%), entry value 3.0e-6 (2.9e-6). power 2 64x48: pi gap 0.12 (0.12), floored 0.33% (0.36%). current 16x16: 0.71 (0.72), 5.5% (5.5%), entry 0.69 (0.66).
- Renter: reference at the bound 75% (78%). Largest pi gap at 64x48 0.32-0.43 (0.57-0.72); at the bound 23-35% (29-40%).
Reading: a starting buffer of one year of income changes almost nothing. Young owners still all consume at the bound, and the renters' early life still moves with the grid. The corner is driven by the old-age housing cost (owners) and the rent obligation (renters), not by starting with little cash.
Commit: this entry, pushed to main.

### 2026-10-15 Grid study for the step-7 renter; income-decomposition panels; one PDF of the recent plots (spec: none, asked by Quinn in Claude Code)
Quinn: run the renter on the grids that make sense; redraw the owner pages with a separate income-decomposition panel with the housing costs; a PDF of all recent plots.
Changed: `+figures/income_decomposition.m` (new, the twelve-panel dashboard's panel (c) as a function); `+figures/compare.m`: five columns, (a) income and housing costs and (f) housing costs over income after tax and contributions (mean, 10-90 band), both for the reference's households; `+figures/dashboard.m` uses the new function; `diagnostics/grid_design/recent_pdf.m` (new): `ladder/standard_16x16x10_gh5/grid_design/step7_grid_study.pdf` (22 MiB, gitignored). Figures 1-3 for the log-wealth and dense pairs redrawn with the current script.
Checks run: `run_tests(solve=false)`: 0 of 8 checks failed. Renter solves (step 7, standard numerics) and gaps to renter log-wealth 128x96 over ages 26-95 (mean pi; mean C %; liquid savings in years of income; renters 25-39 at the consumption bound; floored %; entry value; solve s):
- current 16x16 (as run): 0.94; 1061%; 5.5; 0%; 0.36%; 0.67; 79 s. current 64x48: 0.72; 393%; 2.7; 29%; 0.002%; 8.9e-5; 620 s.
- log-wealth 32x32: 0.54; 479%; 3.4; 0.1%; 0.01%; 0.017; 206 s. log-wealth 64x48: 0.64; 319%; 2.4; 32%; 0.0005%; 3.5e-5; 569 s.
- power 2, 32x32: 0.72; 460%; 3.1; 11%; 0.005%; 6.4e-4; 246 s. power 2, 64x48: 0.57; 247%; 2.0; 40%; 0.0003%; 1.8e-5; 618 s.
- log-wealth 128x96: reference; 78% at the bound; 0 floored; 7.1e-6; 2,206 s.
Reading: renters almost never go bankrupt, and from about 40 on every grid agrees (consumption within a few percent, the equity share from about 55, the policies at 55 and 75 on top of each other); the gaps are at 25-40 and in the level of liquid savings (10-25% below the reference). Young renters do not converge: the share at the consumption bound rises with every refinement (0% at 16x16, 11-32% at 32x32, 29-40% at 64x48, 78% at 128x96). This is the early-life rent-obligation problem of TODO.md item 1 (rent 24% of income at 25), not old-age bankruptcy, and no grid placement fixes it. The owner's converged corner and the renter's moving early life both say the housing outflow with a 1e-6 floor has no interior answer for the young.
Commit: this entry, pushed to main.

### 2026-10-15 Handoff: step 7, the state grid, and what waits on Quinn (spec: none, asked by Quinn in Claude Code)
A standalone handoff for chat and the next session: `docs/HANDOFF_2026-10-15.md`. It covers 12-15 October: where the ladder stands, the step-7 mechanism, the grid study (current, log-wealth, edge-aligned and power grids against log-wealth 128x96), the converged corner for young owners, the open decisions in order, how to reproduce everything, where the scripts and results are, and how Quinn wants results shown. No code changed.
Checks run: none needed (a document).
Commit: this entry, pushed to main.

### 2026-10-15 Grid design for step 7: the power grid, and income on the comparison pages (spec: none, asked by Quinn in Claude Code)
Quinn asked about the runtimes and the earlier power grid, and to plot income on the dashboards from now on.
Changed: `diagnostics/grid_design/grid_rule.m`: rules `power` and `power3`, the existing primitives `grid_pow` and `grid_pow_u2` at 2 (or 3) written out as nodes. `diagnostics/grid_design/compare_grids.m`: a power-grid row. `+figures/compare.m`, `+figures/robustness.m`: the consumption panel also draws the reference households' mean gross income and income after tax, contributions and housing (grey); panel letters run on past z (aa, ab, ...).
Runtimes: `solve_sec` is the whole backward induction over the 76 ages for one tenure, without the simulation; about 0.1 s per state-grid point (u1 x u2 x 2) for the full model, whatever the placement (current 16x16 64 s, 64x48 649 s; log-wealth 128x96 2,062 s).
Checks run (gaps to log-wealth 128x96 over ages 26-95: mean pi, mean C %, mean liquid savings in years of income; floored %; entry value; solve s):
- power 2: 16x16 0.95, 338%, 47; 2.5%; 0.0029; 86 s. 32x32 0.47, 251%, 38; 3.8%; 8.1e-6; 223 s. 64x48 0.12, 28%, 8.4; 0.36%; 3.2e-6; 616 s.
- power 3: 16x16 0.94, 303%, 47; 1.8%; 0.0036; 67 s. 32x32 0.56, 178%, 34; 2.4%; 6.4e-6; 212 s.
- For comparison, log-wealth 64x48: 0.13, 55%, 12; 0.37%; 3.2e-6; 658 s.
- `run_tests(solve=false)`: 0 of 8 checks failed.
Reading: power 2 at 64x48 is the closest of all grids to the reference, and it reaches it from a different placement, which supports the reference as the model's answer. At 32x32 the power grids under-resolve old-age bankruptcy (3.8% and 2.4% of household-years against 0.35%; 17% of households at 100 with power 2) where log-wealth 32x32 does not (0.59%). Power 2 needs no new primitive, only grid_pow = grid_pow_u2 = 2 and a 64x48 base grid (about 10 minutes per tenure per step).
Commit: this entry, pushed to main.

### 2026-10-15 Grid design for step 7: a log-wealth grid converges, and shows the young owners' answer is a corner (spec: none, asked by Quinn in Claude Code)
Quinn: come up with a more appropriate grid; show figures 1-3 and the dashboards. Floor kept at 1e-6 (Quinn: no other floors).
Changed: `diagnostics/grid_design/` (new: `grid_rule.m`, `solve_grids.m`, `compare_grids.m`, README), `diagnostics/step07/ruin_figures.m` (takes any four saved solves, draws a chosen subset of figures). No model code; grids set through the existing primitive `p.grid_nodes`; the production grid is unchanged. Results and figures under `ladder/standard_16x16x10_gh5/grid_design/` (gitignored).
Grids (step 7 owner, standard numerics, gh_n 5, N_sim 10000):
- current: u1 (income over total wealth) evenly spaced on [0.0002, 0.6]; in wealth over income the points run ... 11.5, 23.9, 4,999 at 16 base nodes.
- log-wealth: u1 evenly spaced in log(1 + wealth/income), three times denser between 2 and 60 than below 2 or above 60, same ends; u2 half evenly on [0, 0.9], half evenly in log(savings/house) from 0.11 to 0.0005, then 1.
- edge-aligned: log-wealth with points moved onto the bankruptcy edge s = k - u1 (1 + k) (Quinn's suggestion).
Checks run (largest gap to log-wealth 128x96 over ages 26-95: mean pi, mean C %, mean liquid savings in years of income; then floored % of household-years, young at the consumption bound, entry value):
- current 16x16 (as run): 0.72, 1012%, 56; 5.5%, 0%, 0.66. 32x16: 0.88, 500%, 52; 3.9%, 7%, 0.034. 32x32: 0.88, 441%, 52; 3.8%, 53%, 1.2e-4. 64x48: 0.69, 192%, 43; 2.3%, 95%, 1.5e-5.
- log-wealth 16x16: 0.84, 396%, 50; 2.0%, 0%, 0.13. 32x32: 0.58, 174%, 39; 0.59%, 96%, 6.5e-6. 64x48: 0.13, 55%, 12; 0.37%, 100%, 3.2e-6. 128x96: reference; 0.35%, 100%, 2.9e-6 (solve 2,062 s).
- edge 16x16: 0.81, 392%, 49; 1.7%, 0%, 0.15. 32x32: 0.60, 170%, 39; 0.58%, 96%, 6.1e-6.
- Against the current grid's own 64x48, log-wealth 32x32 is closer (0.26, 53%, 4.4) than the current 32x32 (0.52, 429%, 11).
Reading: the log-wealth grid converges and the current grid does not: from 64x48 to 128x96 the bankruptcy rate by age, the value function along the no-savings line and the equity share agree closely; the remaining gap is late-life consumption (ages 80-95) and savings around 80. The current grid at 64x48 still has 2.3% of household-years bankrupt against 0.35%. Aligning points with the edge adds nothing beyond log-wealth spacing, since the value has already collapsed well before the edge. The converged answer is a corner: every owner aged 25-39 consumes at the solver's lower bound (c_floor_frac, 1% of total wealth, about EUR 3-5k a year), savings reach EUR 3.2M at 80, and consumption peaks at EUR 275k at 90. Households hoard to avoid old-age bankruptcy: maintenance on a house that grows 3.73% a year outruns a flat pension and the house cannot be sold, and with a 1e-6 floor that risk outweighs everything. The coarse grid hid this; the economics is the issue, not the grid.
Commit: this entry, pushed to main.
Open: (1) whether to make log-wealth the default placement (a new primitive selecting the rule; every saved result goes stale and steps 1-7 re-solve); (2) the owner's housing cost or a way to tap the house in retirement, which decides whether the corner is the model's answer (TODO.md item 1).

### 2026-10-14 Step-7 figure 2 without the constant-price panel (spec: none, asked by Quinn in Claude Code)
Changed: `diagnostics/step07/ruin_figures.m`: figure 2 (value function along the no-savings line) shows only step 7 as run at 45 and 85; the constant-house-price panel is gone. Redrawn.
Checks run: `checkcode` on the script, no messages.
Commit: this entry, pushed to main.

### 2026-10-14 Mortgage payment figure: Quinn's labels (spec: none, asked by Quinn in Claude Code)
Changed: `+figures/mortgage.m`, payment-only figure: title "Annual mortgage payment" only; legend "Model approximation (rate*current house value)" and "Fixed rate mortgage". The six-panel figure keeps its labels. Redrawn `mortgage_07_owner_payment.png`.
Checks run: `checkcode` on the function, no messages.
Commit: this entry, pushed to main.

### 2026-10-14 Mortgage figure: payment panel only, without the nominal annuity (spec: none, asked by Quinn in Claude Code)
Quinn: rerun the mortgage plot with only panel (a) and without the nominal mortgage.
Changed: `+figures/mortgage.m`: options `panels` ('all' or 'payment') and `nominal` (true or false); without the nominal annuity its lines, legend entries and numbers are left out in every panel. The defaults draw the figure as before. Drawn for step 7: `ladder/standard_16x16x10_gh5/mortgage_07_owner_payment.png` (gitignored), the model's payment (mean EUR 6.5k at 25, 18.6k at 54, p10-p90 9.9k-29.4k) against the real annuity (EUR 6.5k every year to 54).
Checks run: `run_tests(solve=false)`: 0 of 8 checks failed. `checkcode` on the function, no messages. The default figure redrawn and compared by eye with the earlier one: unchanged.
Commit: this entry, pushed to main.

### 2026-10-14 Step-7 figures 1-4: Quinn's wording, value-function axes, zoomed figure 3 (spec: none, asked by Quinn in Claude Code)
Quinn rewrote the titles of figures 1-3, removed the notes in figures 2 and 3, renamed the axes and colour bar to "value function", and asked for a second figure 3 zoomed to houses up to 100 years of household income with its own colour scale.
Changed: `diagnostics/step07/ruin_figures.m`, `diagnostics/step07/README.md`.
- Figure 1 title, figure 2 titles and panel titles, figure 3 title and colour-bar label as Quinn wrote them ("redline" spelled "red line").
- Figure 2: notes removed; the dashed line is now the highest house-to-income ratio among simulated households, as its caption says (29 at 45, 394 at 85, 24 at 85 with constant prices; the same on both grids, since nobody chooses the house). Its y axis and figure 4's are labelled "value function (log scale)" with ticks like figure 3's colour bar: the certainty-equivalent consumption and, in brackets, V.
- Figure 3: note removed. New `ruin_3_landscape_zoom100.png`: house value 0-100, savings 0-20, colour range set per age from the values in that window and shared by both grids (age 85: 0.18 to 3.2, where the full version uses 10^-6 to 10). The age-85 most exposed household (house 394) lies outside the zoom.
- Figure 4: "well-being" replaced by "value function"; otherwise unchanged. `save_fig` retries when a viewer holds the old file open.
Checks run: `checkcode` on the script, no messages. Only figure code changed.
Commit: this entry, pushed to main.

### 2026-10-14 Step-7 figures: income units in words, text written out for review (spec: none, asked by Quinn in Claude Code)
Quinn: replace "x income" with "years of household income" in figures 1-4, and list all text in the plots for review.
Changed: `diagnostics/step07/ruin_figures.m`. Every "Nx income" and the axis labels ("relative to income") now read "years of household income". Saving a figure also writes all its text, panel by panel, to a .txt file next to the .png (gitignored), which is the list Quinn reviews.
Checks run: `checkcode` on the script, no messages.
Commit: this entry, pushed to main.

### 2026-10-14 Step-7 figures 1-4: one range for all panels, the most exposed household, a value scale (spec: none, asked by Quinn in Claude Code)
Quinn: focus on figures 1-4; figure 1 only the bankruptcy rate of the two grids; figure 3 without the difference column, a colour scheme where the households show, and numbers on the colour scale including the value function; the same range in every panel; mark the most extreme simulated household.
Changed: `diagnostics/step07/ruin_figures.m`.
- Figure 1 is one panel: the share of simulated households bankrupt each year, coarse and fine grid.
- Figures 2-4 use one linear range in every panel: house value 0-450 and savings 0-20, relative to income. It is set by the most exposed household (house 394x income at 85) and by where each slice of figure 4 turns bankrupt.
- Each panel marks the most exposed simulated household: the one with the least cash left after the housing bill (savings + income - housing costs). Coarse grid: house 5.3x / savings 0.19x at 27, 26x / 0.0x at 45 (bankrupt), 394x / 0.0x at 85 (bankrupt, short by 4.9x income). Fine grid: 2.2x / 0.83x at 27, 2.6x / 0.90x at 45, 394x / 0.0x at 85. House value over income does not depend on the grid; savings do.
- Figure 3 is two columns (coarse, fine), dark blue for near the floor to white for comfortable, pink households drawn above the grid points. The colour bar shows well-being from 10^-6 to 10 and, in brackets, the value function V = -D x well-being^-4 in units where a year of consuming one's income is -1 (D = 22.1 at 27, 19.3 at 45, 5.8 at 85).
- Figure 5 is unchanged.
What it shows: at 85 the most exposed household is bankrupt, yet both value functions rate its situation as comfortable (light blue). The cost of one range for all ages is that the age-27 and age-45 panels squeeze the region that matters at those ages into the left tenth.
Checks run: `checkcode` on the script, no messages. Only a figure script changed.
Commit: this entry, pushed to main.

### 2026-10-14 Step-7 figures: one axis convention (spec: none, asked by Quinn in Claude Code)
Quinn: the grid graphs scaled their axes inconsistently; wanted both axes linear in every grid graph, and the figures for the 1e-6 floor only.
Changed: `diagnostics/step07/ruin_figures.m`. Figures 2, 3 and 4 now put house value relative to income across and savings relative to income up, both linear, with one range per age shared by all three (age 27: house 0-30, savings 0-2; 45: 0-90, 0-10; 85: 0-300, 0-20). The house range reaches past the point where both slices of figure 4 turn bankrupt; the savings range covers 95% of households, so the richest 5% are off the top. Figure 3 swapped its axes to match figure 4. On linear axes the grid lines in figure 4 are straight: diagonals of equal total wealth and rays of equal house share. Figure 2 says where the next grid point lies when it is off the chart (4,999x income at 85). The bankruptcy line in figure 3 now uses the floor of the case shown (it used the 1e-6 floor in the floor variants). Redrawn for step 7 as run only; the `_floorNNN` figures on disk predate this.
Checks run: `checkcode` on the script, no messages. Only a figure script changed.
Commit: this entry, pushed to main.

### 2026-10-14 Step-7 slice figure: the grid the slice runs through (spec: none, asked by Quinn in Claude Code)
Quinn: in the slice figure (ruin_4_cut) show which points are on the grid, since its house-value axis is built from the solver's own state variables.
Changed: `diagnostics/step07/ruin_figures.m`, figure 4 only. Under each slice a map in savings and house value per unit of income shows both grids: lines of constant u1 are the diagonals x + h = 1/u1 - 1, lines of constant u2 the rays x = h (1 - u2)/u2, grid points at their crossings, the slice as a horizontal line, the bankrupt region and the households. Large dots mark the grid points that carry at least 1% of the interpolation weight somewhere along the slice; a note gives the furthest such point when it lies off the chart. On the slices themselves, dots mark where the slice crosses a grid line (the tick marks are gone). Redrawn for step 7 as run and the floors 0.1, 0.2, 0.3 and 0.5 (gitignored figures).
What it shows: the slice passes between grid points, not through them, except at zero savings, where it runs along the u2 = 1 line. At every age shown, as run and with constant house prices, the slice's values near and inside the bankrupt region come partly from a grid point at about 4,900-5,000 times income (the bottom of the u1 axis), far off the chart.
Checks run: none of the model (only a figure script changed).
Commit: this entry, pushed to main.

### 2026-10-14 Where households live on the grid, by age (spec: none, asked by Quinn in Claude Code)
Quinn: where households live moves over the life cycle, so show where they actually are on the grids over the years.
Changed: `diagnostics/grid_axes/occupancy.m` (new). From the saved results of steps 6 and 9-12 (standard numerics, both arms), no new solves. `robustness/occupancy_<arm>.png`: per step, the households' density on u1 (log scale, labelled in years of income) and on u2 by age, with the standard grid's points (black) and the bunched grid's (red dashes), and the number of grid points inside the middle-90% band per age. `robustness/occupancy_joint_<arm>.png`: steps 9-12 at ages 35, 50, 62, 66 and 75, 1,500 households on (u1, u2) with both lattices, each panel zoomed to its households.
What the pages show (owner; renter alike):
- The occupied band is a path that moves with age: u1 falls from about 1 at 25 to about 0.1 (10 years of income) at 66 as wealth builds, jumps down at 67 when income becomes the pension, and rises again as wealth is spent. u2 starts at 1 (the first contributions with no liquid savings), falls to 0.7-0.8 in mid-life and returns towards 1 by 66 and in retirement.
- At each age the band covers only a small part of each axis. One fixed set of points serves every age, so most points are idle at any one age, and the occupied cells change with age and with the step.
- Step 6: 3-5 u1 points inside the band in working life and 5-15 in retirement. Steps 9-12: 1-2 u1 points from about 45 to 66; at step 12 no standard u1 point at all inside the band from 67 to about 85 (median at 0.02, 50 years of income, below the lowest interior point at 0.067). u2: everyone lives above 0.5 after 30, where the even grid has 8 of its 16 points; at 35 the whole cloud sits in one cell (0.93-1).
- Step 10 (all-stock fund) spreads retirees over two decades of u1 (0.003-0.3) because the pot's outcome varies so much.
- The bunched grid raises the count to about 2-4 per axis in the same places, but does not follow the band either.
Checks run: `checkcode` on the script, no messages. No code outside `diagnostics/` changed.
Commit: this entry, pushed to main.
Open: how to follow the moving band. A fixed grid placed by occupancy over all ages (`utility.auto_state_grids` from the step's own panel, or the bunched grid) spends points on the union of the path; a grid that changes with age (each age its own points, with next year's value read on next year's grid) would follow it, but the solver uses one grid for all ages, so that is a code change. Quinn to choose.

### 2026-10-13 Which grid axis matters, and runtime: results (spec: none, asked by Quinn in Claude Code)
Changed: `+ladder/grid_axes.m`: after step 9 showed u2 mattering more than expected, two variants at the standard number of points were added to the ladders: u2 bunched toward 1 (`grid_pow_u2` 2) and both axes bunched (`grid_pow` 2, `grid_pow_u2` 2); a fourth row 'Both axes'. `diagnostics/grid_axes/runtime_map.m`: the bunched runs, axis limits. `diagnostics/grid_axes/axes_pdf.m` (new): `robustness/grid_axes.pdf` (12 pages: the gap table, the runtime map, the axis page of steps 12, 11, 10, 9, 6 per arm). Figures and runs gitignored under `ladder/standard_16x16x10_gh5/robustness/` (`robust_axes_*`, `runtime_map.png`, `*_g*x*x*_gh*.mat`).
Checks run: `ladder.grid_axes(k)` for k = 6, 9, 10, 11 and `ladder.grid_axes(12, ladders=true)`, 6,204 s, nothing else running; then the bunched variants and `runtime_map` (5 min). `run_tests` (full): 0 of 13 checks failed (198 s).
One axis doubled, largest gap to the step as solved over ages 26-95 (renter/owner; equity share, consumption):
- u3 (pension against house): exactly 0 at steps 9-12; u2 and u3 exactly 0 at step 6 (collapsed axes), as expected.
- Step 6: u1 0.033/0.034, 1.4/1.6%; 7 quadrature nodes 0.008/0.009.
- Step 9: u1 0.036/0.064, 1.7/2.7%; u2 0.077/0.184 (at 65), 1.5/2.2%; quadrature 0.016/0.034.
- Step 10: u1 0.108/0.112, 10.1/11.2% (at 66), liquid savings 0.8/0.9 years of income (at 79); u2 0.080/0.099, 5.2/9.7%; quadrature 0.047/0.047.
- Step 11: u1 0.058/0.082, 4.0/5.4%; u2 0.269/0.381 (at 65), 2.7/3.0%; quadrature 0.032/0.038.
- Step 12: u1 0.105/0.139, 2.2/3.3%; u2 0.078/0.078, 1.5/2.2%; quadrature 0.034/0.028.
Step 12 against the finest grid run, u1 x4 with u2 x2 ([64 32 10], 491/486 s) (renter/owner; largest equity-share gap, consumption gap, liquid savings at 66, solve s):
- standard [16 16 10]: 0.139/0.192, 4.5/5.9%, +21/+32%, 56/57 s
- u1 x1.5: 0.056/0.079, 3.1/3.7%, +14/+23%, 98 s; u1 x3: 0.032/0.056, 1.9/2.8%, +5.5/+7.6%, 185 s; u1 x4: 0.033/0.056, 1.7/2.4%, +3.3/+3.7%, 245 s
- u2 x1.5, x2, x3: 0.10-0.14, 3.8-5.1%, +16 to +28%, 100-200 s (little better than standard)
- 7 quadrature nodes: 0.123/0.163, 4.7/6.4%, 131 s (no better)
- u1 bunched low: 0.058/0.080, 3.3/4.3%, +15/+22%, 70 s; u2 bunched toward 1: 0.107/0.140, 3.3/4.9%, +16/+26%, 85/71 s
- both bunched: 0.049/0.059, 1.7/2.2%, +6.4/+8.5%, 72/69 s; u1 x2 with u2 x2: 0.035/0.045, 0.9/1.4%, +5.3/+8.3%, 249/251 s
Runtime (`runtime_map.png`): solve time is proportional to the number of state-grid points and does not depend on which axis carries them (about 0.1 s per point: 57 s at 576 points, 490 s at 4,224); 7 quadrature nodes cost 2.3 times as much (131 s). The global sweep costs about 20 s per solve at standard (interior-point 57 s with it, 36 s without); active-set with the sweep 41 s. Ladder steps: 10 s without housing or DC, 57-80 s with the DC state, 64-79 s with housing.
Against the expectations: u3 and the collapsed axes as expected; quadrature small (up to 0.047 at step 10, where the whole pot rides on the stock shock). Wrong: I expected u1 to dominate at every DC step. It dominates at step 12 and for retirement liquid savings and consumption everywhere, but at steps 9 and 11 (first pillar at 68.2%) u2 dominates the equity share in the last working years (63-66), when households run liquid savings down and u2 approaches 1, where the axis has two points. Doubling u2 does not help at step 12, where the gap is in u1.
Reading: the standard grid's error is mostly placement, not the number of points. With the DC account the occupied region moves to large total resources over income (low u1, retirees at 15-40 years of AOW income) and to u2 near 1, both at the ends of evenly spaced axes. Refining u1 moves step 12 in one direction (liquid savings down 7-20% at every age from 35, the pre-retirement equity-share dip filled in by up to 0.2) and is still moving liquid savings by about 3% between x3 and x4, so even the finest run is not fully settled. Bunching both axes gets most of the way at no extra cost.
Commit: this entry, with the changed files, pushed to main.
Open: whether to make the bunched grid the default for the DC steps. Before that: check it at steps 9-11, where u2 matters (it was only run at step 12), and at steps 1-6, where bunching u1 low thins the points the young use; then re-run steps 9-12 and redo the comparisons. The step-12 ladders are not converged in liquid savings at x4.

### 2026-10-13 Which grid axis matters, and runtime: code, and expectations written before the runs (spec: none, asked by Quinn in Claude Code)
Quinn asked for the grid robustness in more detail: whether adding points on one axis matters more than another (the housing axis should not matter in the current specification; it might be liquid savings), what the other axes mean, and a map of how runtime develops.
The axes: u1 = Y/W, income over total resources (liquid savings, pension account, house and this year's income), so 1/u1 is total resources in years of income; u2 = (A+H)/(W-Y), the share of wealth held in the pension account and house rather than liquid savings (without housing: the pension account against liquid savings); u3 = A/(A+H), the pension account against the house; and the quadrature, 5 nodes per shock. Without housing u3 is collapsed to two nodes, and without housing or DC so is u2. u1 is evenly spaced in Y/W: at standard its points sit at total resources of 1, ..., 3, 3.7, 5, 7.5, 14.8 and 1,250 years of income, nothing between the last two.
Changed: `+ladder/grid_axes.m` (new): re-solves a step with one axis refined at a time (u1, u2, u3 doubled; 7 quadrature nodes), and with `ladders=true` u1 at 1.5, 2, 3, 4 times its base points and bunched low (`grid_pow` 2), u2 at 1.5, 2, 3 times, both doubled, and u1 x4 with u2 x2; reuses any saved run of the same calibration; draws `robust_axes_NN_<step>_<arm>.png` (figures.robustness, one row per set) and prints the largest gaps. `diagnostics/grid_axes/runtime_map.m` (new): solve time against grid points, step 12's ladders as time against accuracy, solve time per ladder step and per solver, in `robustness/runtime_map.png`.
Checks run: `run_tests` (full): 0 of 13 checks failed (198 s). Smoke on [8 6 6], gh 3 (separate folder): u2 and u3 doubled at step 6 and u3 doubled at step 12 give gaps of exactly 0; the rest ran.
Where households sit (standard results, owner): at step 12 the share of households in the lowest u1 cell (total resources above 14.8 years of income) is 0.11 at 55, 0.28 at 62, 0.39 at 66, 1.00 at 70 and 0.87 at 80; at step 6 it is at most 0.21 (70). At step 12 u2 lies between 0.67 and 1.00 (p10-p90), where the axis has six points.
Expectations:
- u3 doubled: no change at all at steps 9-12 (collapsed); u2 and u3 doubled: none at step 6.
- u1 is the axis that matters at steps 9-12, because retirees at step 12 (and near-retirees at 9-11) sit in the lowest u1 cell. Doubling u1 alone gives most of the gap of the earlier [32 16 10] run (it is that run). The u1 ladder settles from about x3 on; bunching the base points low (grid_pow 2) gets much of the way at no extra cost.
- u2 (pension account against liquid savings): smaller, mostly at 55-66 where the equity share is below 1.
- 7 quadrature nodes: small, under 0.01 in the equity share, as at earlier steps.
- At step 6 u1 doubling moves the equity share by about 0.04 at most, as in the robustness pages.
- Runtime about proportional to the u1 x u2 points: about 1 minute at the standard grid, 2 doubling either axis, 4 doubling both, 8 at u1 x4 with u2 x2; 7 quadrature nodes about twice the time (49 against 25 joint nodes).
Runs, in order, nothing else running so the times are clean: `ladder.grid_axes(k)` for k = 6, 9, 10, 11, then `ladder.grid_axes(12, ladders=true)`, then `runtime_map`.
Commit: this entry, with the two new files, pushed to main before the runs.

### 2026-10-13 Retirement steps 9-12 and sensitivities at standard numerics (spec: none, asked by Quinn in Claude Code)
Changed: `+figures/compare.m` (37b5a98): the reference band no longer covers the other lines; the policy panels read each result at its own households' median pension and housing shares (at the reference's, a DC step was read with an empty pot and drew on top of step 6); % gaps and the settings box leave out near-zero levels. `diagnostics/retirement/report_pdf.m` (new): every page below with an intro page per section, in two PDFs under 30 MiB so they can be sent. Results and figures, gitignored, under `ladder/standard_16x16x10_gh5/`: `09_*` to `12_*`, `compare_06_09_*`, `compare_09_10_*`, `compare_10_11_*`, `compare_09_11_*`, `compare_11_12_*`, `owner_renter_09..12`, `overlay_retirement_*`, `overlay_dc_funds_*`, `sensitivity/`, `robustness/robust_09..12_*`, and `retirement_dashboards_part1.pdf` (overview, steps 9-10; 22 pages, 18 MiB) and `_part2.pdf` (steps 11-12, sensitivities; 32 pages, 26 MiB).
Checks run:
- `ladder.run(9:12)`, thread pool, interior-point with the sweep, 18 x 16 x 2 nodes (u3 collapses without housing), 57-80 s per arm. Every arm: c_bound_25_39 0, floored 0, Merton 0.195, income-stock correlation 0.0400 on the nodes and 0.0415 in the panel. Off-grid lookups 0, except step 10: 24 (renter) and 31 (owner) of 760,000 household-years below the u1 axis, from 1 renter and 2 owners whose all-stock pot reached 500-665 x final income (median 12-15 x); flat extrapolation at the edge, no visible effect on the means. Entry value 1.07/1.10 (9), 1.07/1.11 (10), 1.08/1.11 (11), 1.05/1.09 (12), renter/owner.
- Solver stop rule (default against active-set with the sweep, ages 26-95), renter/owner: max |d mean pi| 0.003/0.004 (9), 0.001/0.001 (10), 0.006/0.009 (11), 0.002/0.002 (12); consumption 0.01/0.33%, 0.76/0.92%, 0.18/0.05%, 0.17/0.11%; liquid savings within 0.03 years of income. Passes at every step. Without the sweep the equity share breaks as before (0.28-0.43 at 26-28, up to 1.0 at 95).
- `run_tests(solve=false)` after the figure change: 0 of 8 checks failed.
Results (ages 25/35/45/55/66/75/85, renter/owner; C median over entry income Y0, X mean liquid savings over Y0, pi mean liquid equity share):
- Step 9 dc_bonds against 6: C 0.98/0.96 1.24/1.28 1.45/1.51 1.64/1.70 1.89/2.00 1.86/1.99 1.79/1.94 (step 6: 1.07/1.07 1.33/1.40 1.55/1.63 1.73/1.81 1.89/1.97 1.82/1.89 1.66/1.71). X at 66 2.13/1.83 (11.85/13.07); DC pot at 66 10.5/13.1; net worth at 66 12.6/15.0 (11.9/13.1). pi at 55 0.96/0.96 (0.90/0.90), 1.00 from 66 on (0.73-0.86). Stock share of liquid plus DC wealth at 45: 0.35/0.26 (1.00).
- Step 10 dc_stocks against 9: DC pot at 66 29.0/36.5 (2.8 times); X at 66 0.94/0.94, then rising to 6.3/8.5 at 75 (lucky retirees save part of large annuity payouts; the mean is carried by the tail). C at 66 2.07/2.08, 75 2.74/3.09, 85 2.84/3.25, with a jump at 67 and a much wider band. pi at 55 0.90/0.90 (0.96), at 66 0.02/0.01, 0.07/0.04 at 75. Stock share of liquid plus DC wealth 0.97-1.00 until 66.
- Step 11 dc_glide against 10: between the two. DC pot at 66 15.8/19.9; C at 75 2.08/2.31; X at 66 1.26/1.19; pi at 55 0.91/0.89, at 60 0.86/0.83, 1.00 from 66 on.
- Step 12 aow against 11: X at 66 5.01/3.97 (1.26/1.19), peak 5.07 at 62 / 4.59 at 60; C 0.98/0.96 1.22/1.27 1.43/1.49 1.59/1.66 1.80/1.95 1.71/1.87 1.59/1.76; pi at 55 0.85/0.83 (0.91/0.89), at 60 0.76/0.71 (0.86/0.83), at 70 0.89/0.94 (1.00). Against step 6: liquid savings at 66 less than half (5.0/4.0 against 11.9/13.1), net worth at 66 higher (20.8/23.8), retirement consumption 2-6% lower at 75 and 4% lower / 3% higher at 85, equity share in retirement 0.89-0.99 against 0.71-0.86.
- Against the expectations: directions as written at every step. Misses: (9) consumption fell nearly as much in mid-life as at 25 (-7% at 35, -5% at 55), not much less; (10) the liquid equity share barely moved before 66 (0.90 against 0.96 at 55) and then dropped to 0.02 in the last working year, not gradually; liquid savings rising again after 67 was not predicted; (12) the retirement equity share fell only slightly (0.89-0.97 at 70-75), not clearly; (kappa 0.30) households are not held at the borrowing limit: they still save liquid until 57 and then run it down to bridge to 67. Owners are crowded out more than renters at every step (higher contribution rate on the franchise).
- Sensitivities around step 12 (renter/owner; at 66 unless noted): replacement 0.20: X 6.79/5.42, C at 75 1.62/1.77, pi 0.88/0.95; replacement 0.40: X 3.71/2.97, C at 75 1.79/1.97, pi 0.99/1.00. kappa_base 0.10: C at 25 1.01/1.01, at 35 1.27/1.33, X 10.57/9.72, C at 75 1.59/1.68, pi 0.69/0.76; kappa_base 0.30: C at 25 0.93/0.89, at 35 1.14/1.16, X peak 3.26/3.09 at 57 then 1.85/1.29 at 66, C at 75 2.02/2.34, pi 1.00 in retirement. All as expected in direction; floored 0 and off-grid 0 in all eight runs.
Grid (the robustness pages; max over ages 26-95 against the step as run): step 9 [20 20 12] pi 0.014/0.042, C 0.8/1.2%; [32 16 10] 0.036/0.064, 1.7/2.7%. Step 10 [32 16 10] 0.109/0.112, 10.1/11.2% (consumption at 66), liquid savings 0.8/0.9 years of income at 79. Step 11 [32 16 10] 0.058/0.083, 4.0/5.4%. Step 12 [20 20 12] 0.102/0.141, 1.4/1.5%; [32 16 10] 0.105/0.139, 2.2/3.3%, liquid savings 0.74/0.78 years of income. The gaps sit at 55-70. Step 6 on the same grids moves pi by at most 0.04. The equity share before retirement rises as the grid is refined (step 12 owner at 60: 0.71 standard, 0.84 on both finer grids, which agree there), and liquid savings around retirement fall (step 12 at 66: 5.01, 4.76, 4.55 renter). Every direction between steps holds on both finer grids; the sizes around 55-66 roughly halve (step 11 to 12 at 60, renter: -0.10 standard, -0.05 fine, -0.07 dense).
Reading: turning the DC account on with CGM's 68.2% first pillar gives retirement income above final income (1.05-1.13 x with bonds), so liquid saving is crowded out almost completely by 67 and the liquid account moves to the all-equity corner beside the bond-like pension. An all-stock fund makes retirement income equity-like, and the liquid account goes to bonds from the last working year. My reading of the drop at 66, not tested: the pot is locked until 67, so before 66 the liquid account mostly pays for consumption before retirement, which the pot does not cover; at 66 what is left is saved for retirement, where the stock-linked annuity already carries the risk. The AOW step brings liquid saving back to about 40% of step 6's peak. The standard grid is not fine enough once the DC state is live: the thin-u1 note at step 12 (fewer than two u1 nodes in the occupied band at 27-30% of ages from 40) points the same way.
Stop: no stop rule fired (solver rule passes; the step-10 off-grid flag is three households in the tail). The grid gaps at 55-70 are above anything seen at steps 1-6 and should be settled before the DC steps are read for sizes.
Commit: this entry, with `diagnostics/retirement/report_pdf.m`, pushed to main.
Open: Quinn's review. Rerun steps 9-12 on the fine grid [20 20 12] (or with nodes placed by `utility.auto_state_grids`) before quoting sizes around retirement. The sensitivity values (replacement 0.20/0.40, kappa_base 0.10/0.30) are my choice; a constant 50% fund was not run as an alternative "in between". `lambda_lo` for all-stock DC pots, if the tail matters.

### 2026-10-12 Retirement steps 9-12 and sensitivities: code, and expectations written before the runs (spec: none, asked by Quinn in Claude Code)
Quinn: housing is tabled; move on to the retirement steps, built on step 6 without housing ("it should be based on the step without the housing, not added to the housing"). First the DC account back on with an all-bond fund, then all stocks, then something in between; only after that the lower first-pillar replacement rate; and, around that end point, a lower and a higher replacement rate and contribution rate. Taxes and the REIT stay off. Same reporting as steps 1-7. The fund "in between" is the production glide (0.8 until 39, to 0 at 67, bonds in retirement), so the branch ends at the pension calibration without housing. The sensitivity values are illustrative: replacement 0.20 and 0.40, kappa_base 0.10 and 0.30.
Changed:
- `+ladder/steps.m`: steps get a `parent` (the step built on; empty = the step before) and a `vary` field. New branch off step 6: 9 `dc_bonds` (kappa_base 0.186, glide_cap 0; first pillar stays 0.682), 10 `dc_stocks` (glide_cap 1, glide_span 1, tau_decum 1), 11 `dc_glide` (glide_cap 0.8, glide_span 35, tau_decum []), 12 `aow` (replacement 0.307; vary replacement [0.20 0.40], kappa_base [0.10 0.30]). The old step 9 `pension` is now 13 and builds on 8; `inctax` 14, `box3` 15. Steps 1-8 and their saved results are unchanged (ladder.load(6) and (7) load without a stale warning); the last step still equals config.params.
- `+ladder/params.m`: applies the overrides along the step's line of parents only. `+ladder/parent.m` (new). `+ladder/compare.m`: compares with the parent by default. `+ladder/matching_arm.m` (new, moved out of compare).
- `+ladder/overlay.m` (new): several saved steps on one `figures.compare` page per arm. `+ladder/sensitivity.m` (new): re-solves a step with one primitive at a time moved, saves under `<numerics>/sensitivity/`, draws a step dashboard per variant and one overlay per primitive.
- `+figures/compare.m`: `view='pension'` shows the DC account in place of net worth, and the stock share of liquid saving plus the DC account in place of the policy at 30.
- `tests/run_tests.m`: `ladder_branches` (parents; DC steps without housing, housing steps without DC; the three funds are all bonds, all stocks and the production glide). README, CALIBRATION.md, CALIBRATION_PLAN.md, CLAUDE.md: the branch.
Checks run:
- `run_tests(solve=false)`: 0 of 8 checks failed. `run_tests` (full): 0 of 13 checks failed (209 s).
- Smoke of steps 6 and 9-12 with compare, overlay and sensitivity on [8 6 6], gh 3 (separate results folder): everything ran (395 s); every arm offgrid 0, c_bound_25_39 0, floored 0, except dc_stocks with 1 (renter) and 4 (owner) of 304,000 lookups off the u1 axis.
Mechanical numbers (deterministic median income path, expected fund returns, before any choice; final income = income at 66), renter / owner:
- Contribution rate: 7.2% / 10.0% of income at 25, 11.9% / 13.9% at 45, 11.7% / 13.4% at 66.
- Expected pot at 67 over final income: all bonds 6.2 / 7.7, all stocks 17.7 / 22.1, glide 9.3 / 11.6 (the survival credit from 25 adds about 8%). Annuity factor at 67: 16.95 with a bond fund, 11.42 with an all-stock fund (priced off its expected return).
- Expected annuity over final income: bonds 0.36 / 0.45, stocks 1.55 / 1.94 (risky), glide 0.55 / 0.69. With the first pillar at 0.682, expected retirement income over final income is 1.05 / 1.13 (bonds), 2.23 / 2.62 (stocks), 1.23 / 1.37 (glide); at step 12, 0.86 / 0.99. At step 6 it is 0.682 plus what liquid wealth pays.
Expectations, standard numerics, both arms:
- Step 9 `dc_bonds` against 6: liquid saving is crowded out. The expected pot at 67 (about 10 / 13 x entry income) is close to step 6's liquid peak (12 / 13), so liquid wealth at 67 falls by more than half; net worth (liquid plus DC) at 67 about the same or higher. Consumption lower when young by about the contribution (7% / 10% at 25), since households are near the borrowing limit; from about 35 to 66 by less, as liquid saving falls instead; higher in retirement, where income now exceeds final income. The liquid equity share rises wherever it was below 1 (from about 50, and in retirement towards 1): the bond fund and the safe annuity are bond-like wealth beside a small liquid account. The stock share of liquid plus DC wealth falls. Owners are crowded out more than renters (higher contribution rate).
- Step 10 `dc_stocks` against 9: the expected pot is about 2.9 times as large, with a wide band. Liquid saving lower still before 67. Mean consumption in retirement much higher, with a much wider band, and a jump at 67, since households cannot borrow against the pot before it pays out. The liquid equity share falls, most in retirement (well below 0.5): the variable annuity is stock exposure, so the liquid account holds bonds. In working life it leaves 1 earlier. The stock share of liquid plus DC wealth is near 1 until 67.
- Step 11 `dc_glide` against 10: between steps 9 and 10. A smaller, safer pot and a bond annuity: the retirement liquid equity share back up to about step 9's level, a smaller jump at 67, the working-life liquid share between steps 9 and 10.
- Step 12 `aow` against 11: expected retirement income falls by 0.375 x final income. Liquid saving much higher (fully replacing it would take about 6 x final income at 67), consumption lower at every age, and the liquid equity share lower from mid-life on and in retirement (less bond-like income beside more liquid wealth).
- Sensitivities around step 12, each against the step: replacement 0.20 / 0.40: more / less liquid saving (up to about 1.7 x final income at 67 either way), consumption slightly lower / higher, retirement equity share lower / higher. kappa_base 0.10 / 0.30: the pot scales with the rate (expected 5.0 / 15.0 x final income for renters); the lower rate raises liquid saving and young consumption; the higher rate crowds out more liquid saving, may hold households at the borrowing limit for much of working life, lowers working-life consumption and raises retirement consumption and the liquid equity share.
Stop rules as for steps 2-7: off-grid lookups, c_bound_25_39 above 5%, floored above 1%, a result against the direction above, or the default against active-set with the sweep more than 0.02 in mean pi or 2% in consumption or liquid wealth (measured against income where savings are near zero). New to watch: large all-stock pots push u1 towards the bottom of its axis.
Order: `ladder.run(9:12)` and `ladder.compare(9:12)` (each against its parent, so step 9 against step 6), `ladder.overlay([6 9 10 11 12], view='pension')`, `ladder.sensitivity('aow')`; then `ladder.robustness(k)` for 9-12.
Commit: 8bf217c, pushed to main before the runs.

### 2026-10-12 Handoff: where the calibration ladder stands (spec: Calibration ladder, part 1, and Quinn's requests in Claude Code)
A summary of the session of 12 October for Quinn and the next session. The numbers are in the entries below; the open decisions are in TODO.md item 1.

Where things stand:
1. Steps 1-6 (cgm, gamma5, retire67, income, market, corr_SL) are run at standard numerics and accepted by Quinn. The no-housing baseline is closed and the spec "Calibration ladder, part 1" is done. For every step the results, dashboard, comparison with the step before, owner-against-renter page (from step 4) and robustness runs are saved under `ladder/standard_16x16x10_gh5/`. They are gitignored, so they exist only on Quinn's PC.
2. Step 7 (housing: Table 1 dynamics, mortgage and level placeholders, no correlations) is run and stopped: the owner is at the floor in 5.5% of household-years (rule: 1%), and neither tenure is grid-converged. Step 8 (housing correlations, Table 3) is coded and not run. Steps 9-11 (pension, inctax, box3) are untouched.
3. The step-7 diagnosis is finished. Nothing more is run until Quinn decides TODO.md item 1 (Quinn is meeting a coauthor on it).

Decisions Quinn made:
- Income: the DHS household-head cubic for owners and renters, 2025 euros, extrapolated from 65 to 66; retirement income 68.2% of final income until the pension step.
- Market: r 0.0115 (NL interbank), equity premium 0.0456, volatility 0.2161; income-stock correlation 0.04.
- Order: housing first with taxes off, split into step 7 (dynamics) and step 8 (correlations); the pension comes later as its own step.
- Solver default: interior-point with the global (c, pi) sweep on (`p.fmincon_algorithm`, `p.use_refine`).
- Reporting: results as figures, not tables. Per step a twelve-panel dashboard, a comparison with the step before showing both 10-90 bands, and a robustness page with the reference drawn in black and levels beside the differences. Explanatory figures use plain words, not model notation.
- Steps 1-6 accepted; the step-7 diagnosis scripts are kept in the repo.

What changed on main (all pushed): c7bf0f2 ladder part 1 (DHS income source, renter income primitives, two no-housing arms, correlation checks); 989db7f twelve-panel dashboards, overlays and `ladder.robustness`; 2042985 sweep back on, step and robustness dashboards; 8f93670 levels on the robustness page; 4f6ccac near-zero savings left out of the % gaps; 72560c9 housing steps 7 and 8 (Table 1 dynamics, tenure-specific H correlations, no housing parameters reaching steps without housing, `lambda_lo` 0.0002 with housing); 4f73211 `figures.mortgage`; and 56244b8, `diagnostics/step07/`.

What the step-7 diagnosis found:
- One mechanism: a housing outflow the household cannot adjust, tied to the house-price shock, with a floor of 1e-6 times income, at which one floored year weighs as much as 1e24 normal years. With constant house prices the owner converges.
- The owner's mortgage is a rate times the current house value: 1.71 times the loan in present value against 1.00 for a real annuity. Maintenance on a house growing 3.73% a year outruns the flat pension late in life.
- The grid knows the value only at its points, and along the income axis it has none between 24 and 4999 times income. Ruin is hidden there in old age, and in early life each refinement finds more of it: on the doubled grid the 27-year-old holds 7% in equities instead of 100%.
- Floors of 0.1-0.5 remove the early-life collapse but leave gaps of 13-21 points in the equity share between the grids. The fix is the housing cost (equity access, the mortgage payment, a rent cap), with a sourced floor as the backstop.

Next, once Quinn has decided:
1. Write the expectations here, implement the TODO item 1 choices, and rerun step 7 on the standard and the doubled grid. It passes when they agree within the stop rule (2 points in the equity share, 2% in consumption).
2. Run step 8, then the pension step (DC only), then the tax steps.
3. Still open from part 1: the entry buffer's denominator, `tau_inc` against DHS net over gross, and the housing level placeholders (TODO.md item 2).

Where things are: `diagnostics/step07/README.md` lists the scripts and how to rerun them. Their results are in `ladder/standard_16x16x10_gh5/diagnosis/data/`, the figures and `step07_robustness_dashboards.pdf` in `ladder/standard_16x16x10_gh5/diagnosis/` (gitignored). TODO.md item 1 now holds the step-7 evidence and the decisions in order.
Checks run: `run_tests(solve=false)`: 0 of 7 checks failed. `checkcode` on `diagnostics/step07`: no messages. `solve_cases(cases="owner_floor_020", grids={[8 6 6], [10 6 6]}, gh_n=3, out=tempdir)`: both solves ran in 45 s (offgrid 0, c_bound 0). All diagnosis figures and the PDF redrawn from the repo scripts and the moved data: 47 files, the same numbers as before (for example the floor overview gaps 87.7, 20.6, 21.1, 19.8, 13.5 points).
Commit: 56244b8, pushed to main.

### 2026-10-12 All step-7 robustness and diagnosis dashboards in one PDF (spec: none, asked by Quinn in Claude Code)
No code changed. The round-2 diagnosis cases (owner without maintenance, owner with house-price risk but no growth, renter with the second axis or both axes doubled) were re-solved with full results so they can be drawn; the numbers match the diagnosis entry (no maintenance: floored 0.01% / 0%, entry 0.884 / 0.708; no growth: about 2,200 off-grid lookups on both grids, entry 0.900 / 0.637; renter [16 32 10] entry 0.663, [32 32 10] entry 0.488). Every test is drawn with `figures.step_dashboard`, against step 7 as run and as its own coarse against fine grid, and collected with an intro page per section in `ladder/standard_16x16x10_gh5/diagnosis/step07_robustness_dashboards.pdf` (29 pages, gitignored); the single pages are `effect_*` and `grid_*` in the same folder.
Commit: 37ee951, pushed to main.

### 2026-10-12 Step 7 owner at higher consumption floors (spec: none, asked by Quinn in Claude Code)
Quinn asked for the ruin figures at higher floors. Scratch solves of the step-7 owner (standard numerics, interior-point with the sweep) at phi_floor 0.2, 0.3 and 0.5, each on [16 16 10] and [32 16 10]; 0.1 from the diagnosis entry. No code changed. Figures, gitignored, in `ladder/standard_16x16x10_gh5/diagnosis/`: `floors_overview.png`, `ruin_*_floor010/020/030/050.png`, and `grid_map.png` (where the solver's grid points lie per unit of income: the u1 columns sit at total wealth 0.7 ... 7.3, 11.5, 23.9 and 4999 times income, nothing in between).
Checks run (coarse / fine): offgrid 0 and c_bound_25_39 0 in every solve. Floored household-years 5.5/3.9% (1e-6), 5.9/3.7% (0.1), 7.0/4.0% (0.2), 8.3/4.7% (0.3), 11.8/8.2% (0.5); entry value 0.660/0.034, 0.733/0.618, 0.762/0.661, 0.784/0.689, 0.815/0.747.
Largest gap between the grids, ages 26-95 (stock share in points, consumption in %, liquid savings in years of income): 1e-6 87.7, 79.2, 4.13; 0.1 20.6, 21.5, 2.77; 0.2 21.1, 20.2, 2.76; 0.3 19.8, 17.9, 2.64; 0.5 13.5, 11.1, 1.86. At 27 both grids hold 100% stocks from a floor of 0.1 on (12% on the fine grid at 1e-6).
Reading: any floor of 0.1 or more removes the cliff, and with it the early-life collapse on the fine grid. The grids still disagree by 13-21 points in the stock share and 11-22% in consumption, in mid-life (40-66) and retirement, far above the 2-point stop rule. The floor binds more often as it rises (partly by definition, partly less precaution), mostly from 70 on, up to 45% of owners at 95 at a floor of 0.5. A floor is needed but does not fix the grid dependence; the remaining driver is the housing cost on an unsellable, appreciating house.
Commit: 35ccef1, pushed to main.

### 2026-10-12 Plain-language version of the ruin figures (spec: none, asked by Quinn in Claude Code)
Quinn found the five ruin figures too technical. Redrawn as two figures with linear axes and plain labels: `ladder/standard_16x16x10_gh5/diagnosis/simple_1_what_goes_wrong.png` and `simple_2_what_it_does.png` (gitignored). No code changed.
Numbers the script printed:
- Age 27, no liquid savings, well-being (CE, years of income) at a house of 4.2 x income: 0.59 (standard grid) against 0.03 (doubled); at 5.5 x: 0.49 (standard, at 5.2) against 0.003. The typical 27-year-old owner's house is 3.8 x income, so on the doubled grid the typical young owner sits on the cliff.
- Age 85: bankrupt this year 11.8% (standard) and 6.9% (doubled) of owners; the value function rates them at a median of 0.65 and 0.27, against 0.91 and 1.09 for the rest. They should be near 0.
Commit: cae11a1, pushed to main.

### 2026-10-12 How the floor, ruin and the grid move step 7, in figures (spec: none, asked by Quinn in Claude Code)
Quinn asked for intuitive pictures of how the grid and the possibility of ruin change the value and policy functions. No code changed. A scratch script drew five figures from the saved step-7 owner solves ([16 16 10] and the doubled income axis [32 16 10]) and the flat-house-price runs of the diagnosis entry below: `ladder/standard_16x16x10_gh5/diagnosis/ruin_1_why.png` to `ruin_5_choice.png` (gitignored). Values are shown as a certainty-equivalent consumption stream (CE): the constant consumption, in years of current income, worth as much as the state over the remaining expected lifetime.
Checks run: none needed (no code changed). The numbers the script printed:
- Utility: with gamma 5, u(c)/u(1) = c^-4, so one year at the 1e-6 floor weighs as much as 1e24 years of consuming one's income; at a floor of 0.1, 1e4 years; at 0.3, 123.
- Ruin zone: an owner is at the floor this year when x + 1 - k h <= phi, with x liquid savings and h the house, both over income, and k = 1.5% maintenance plus the 4.08% annuity rate up to 54, 1.5% after. With no liquid savings that is h >= 17.9 at 45 and h >= 66.7 at 85.
- Along the no-savings grid line at 45, node h (CE): standard 7.3 (0.37), 11.5 (0.20), 23.9 (1.5e-6, in the zone). Doubled 6.4 (0.24), 7.6 (0.029), 9.3 (0.0033), 11.9 (2.2e-5), 16.2 (5.2e-6), 24.7 (1.4e-6). The doubled grid finds the value collapsing well before the zone; the standard grid has one interval for the whole fall and interpolates through it.
- At 85 the last node outside the zone is at h = 23.9 (CE 0.66, standard) or 50.2 (0.27, doubled) and the first inside at 4999 (1.3e-6). Linear interpolation in z between them keeps CE at 0.25-0.65 across the zone, since z is close to linear in u1 with z near 0 at the corner and CE = z/u1. Floored owners at 85: 11.8% (standard), 6.9% (doubled); at 95: 23.0%, 19.1%. The value function does not see them.
- Young owner at 27 (house 3.81, liquid savings 0.36, both over income): standard pi 1.00, consumes 55% of liquid resources; doubled pi 0.07, 9%. Next year's worst shock combination is worth 0.44 against 0.020 years of income. The worst 5% of next year's shock combinations carry 14% of expected disutility on the standard grid and 88% on the doubled grid (worst 20%: 40% and 96%). On the doubled grid all-equity costs 11% of CE against the best share; on the standard grid the objective is flat within 0.2% over all shares. Entry value 0.660 against 0.034.
- Flat house prices: the same zone and the same interpolation error, but households stay far from it (floored 0% at every age) and the two grids agree.
Reading: the near-zero floor makes any reachable ruin state dominate expected utility (V proportional to CE^-4). The ruin zone is a cliff in the value function that the solver knows only at grid points; between them linear interpolation smooths the cliff away. Refining the u1 axis puts points on the slope before the cliff, so states near it lose orders of magnitude of value and young owners respond by saving most of their income in bonds. Neither grid is right at a floor of 1e-6, and the answer keeps moving as the grid refines. This supports the diagnosis entry: remove or make adjustable the house-linked outflow, or raise the floor; a floor of 0.1 still counts one floored year as 1e4 normal years.
Commit: 614c8f7, pushed to main.
Open: as in the diagnosis entry.

### 2026-10-12 Diagnosis: what drives step 7's grid sensitivity (spec: none, asked by Quinn in Claude Code)
Quinn asked whether the mortgage problem and the grid non-convergence are related. Scratch runs of step 7 (standard numerics, interior-point with the sweep), each solved on [16 16 10] and on a refined grid; the gap is the largest difference over ages 26-95 in mean pi, mean consumption (%) and mean liquid wealth (years of income). No code changed. Dashboards, gitignored: `ladder/standard_16x16x10_gh5/diagnosis/` (grid_* = standard against refined, effect_* = against step 7 as run) and `diag_convergence_07.png`.
Checks run:
- Owner as run, [32 16 10]: 0.877, 79%, 4.1 (floored 5.5%). Renter as run: 0.186, 19.7%, 0.9.
- Owner, flat house prices (mu_H 0, sigma_H 0.001): 0.018, 0.3%, 0.04, floor never binds. With flat prices the model's mortgage equals a real annuity and maintenance is constant.
- Owner, no maintenance (mortgage approximation only): 0.108, 20.8%, 0.74, floor binds in 0.01% of years.
- Owner, house-price risk without drift: 0.354, 25%, 0.77 (about 2,200 off-grid lookups; rough).
- Floor 0.1 x income: owner 0.206, 21.5%, 2.8 (floored 5.9%); renter 0.139, 11.7%, 0.77.
- Renter, second axis: [16 16 10] against [16 32 10] 0.021, 1.7%, 0.27; [32 16 10] against [32 32 10] 0.091, 9.4%, 0.39; [16 16 10] against [32 32 10] 0.243, 27%, 1.3.
Reading: one mechanism, a housing outflow the household cannot adjust, tied to the H shock, with a near-zero floor. For owners the mortgage approximation (a payment proportional to an appreciating, volatile house) makes it large and risky in early life, and maintenance on the same house causes the retirement floor states; with the house price held flat both disappear and the owner converges. Renters have the same mechanism in milder form, not caused by the mortgage: a floor of 0.1 removes only part of it, and the solution keeps moving in early life as either axis is refined. This is the early-life problem of TODO.md item 1.
Commit: fe5f1b6, pushed to main.
Open: Quinn's choice of owner cost structure and of how to handle the renters' early life before step 7 is rerun.

### 2026-10-12 The model's mortgage against a real annuity mortgage (spec: none, asked by Quinn in Claude Code)
Changed: `+figures/mortgage.m` (new): for an owner result, the model's payment (annuity rate times the current house value) against two contracts on the same loan, a real annuity at r_m (constant real payment) and the nominal annuity at r_m plus 2.3% inflation (fixed euro payment, falling in real terms); payment, payment over income, balance, cumulative payments, present value at r_m per household. Drawn for step 7: `ladder/standard_16x16x10_gh5/mortgage_07_owner.png` (gitignored).
Checks run: `run_tests(solve=false)`: 0 of 7 checks failed. Both real contracts have a present value of exactly 1.00 times the loan (payments at the end of each year).
Numbers (step 7 owner, loan EUR 159k): the annual payment is EUR 6.5k at 25 in every contract; at 54 the model charges EUR 18.6k on average (p10 9.9k, p90 29.4k) against 6.5k (real annuity) and 4.5k (nominal, in real euros). Over gross income at 45: model 19.5%, real 9.4%, nominal 8.0%; at 54: 27.9%, 9.7%, 6.7%. Total paid over the term: model 2.18 times the loan on average (p10 1.47, p90 3.01), real 1.22, nominal 1.20. Present value at r_m: model 1.71 times the loan on average (p10 1.18, median 1.64, p90 2.34) against 1.00 for both contracts; 98% of owners pay more than the loan. The model's balance also stays near the full loan until about 40 instead of falling from the start, since it is a share of a rising house.
Commit: 4f73211, pushed to main.
Open: whether to model the mortgage as a real contract (needs a balance state, or a payment fixed at entry carried in another way); Quinn's decisions on step 7 still open.

### 2026-10-12 Step 7 housing at standard numerics; stopped before step 8 (spec: none, asked by Quinn in Claude Code)
Changed: no code. Results, gitignored, under `ladder/standard_16x16x10_gh5/` (07_*, compare_06_07_*, owner_renter_07, robustness/robust_07_*).
Checks run: `ladder.robustness(7)`, `ladder.compare(7)`, thread pool, interior-point with the sweep; solve 79 s (renter), 64 s (owner).
- Renter: offgrid 0, c_bound_25_39 0, floored 0.4% (0.8% from 67); entry value 0.674. Correlations: income-stock nodes 0.040, panel 0.042; housing 0 as set.
- Owner: offgrid 0, c_bound_25_39 0, floored 5.5% of household-years (12.2% from 67: 3.8% at 75, 11.8% at 85); entry value 0.660.
- Against step 6 (ages 25/35/45/55/65/75/85), renter / owner: median C/Y0 0.65/0.63 0.95/1.01 1.21/1.35 1.43/1.55 1.64/1.69 1.58/1.59 1.45/1.20 (step 6: 1.07/1.07 1.33/1.40 1.55/1.63 1.73/1.81 1.89/1.96 1.82/1.89 1.66/1.71); mean X/Y0 at 65 16.7/14.6 (11.6/12.9), peak 17.0/15.1 at 67 (12.1/13.3); mean pi 1/1 0.956/0.899 0.72/0.824 0.555/0.876 0.465/0.611 0.503/0.637 0.559/0.652 (1 1 0.996/0.999 0.898/0.896 0.717/0.687 0.772/0.746 0.863/0.846); pi below 0.99 from 33 / 31 (47 / 48). Median housing cost over net income, renter 0.24 0.18 0.17 0.19 0.21 0.34 0.38; owner 0.22 0.20 0.23 0.09 0.13 0.28 0.39.
- Against the expectation: consumption lower, liquid wealth at 67 higher (renter +40%, owner +13%), the equity share lower and the corner left 14-17 years earlier, housing-cost burdens as computed: as written. Consumption at 25 falls by more than the rent (39-41%): households also save more from the start. The owner floor flag came true.
- Solver: default against active-set with the sweep, max |d mean pi| 0.0009 / 0.0006, consumption 0.05% / 0.44%, liquid wealth 0.03% / 0.53% of income.
- Grid (max over ages 26-95; |dX| in years of income), renter: [9 9 6] pi 0.18, C 13%, X 1.5; [12 12 8] 0.075, 5.5%, 0.6; [20 20 12] 0.060, 5.4%, 0.4; [32 16 10] 0.186 (age 36), 19.7% (age 26), 0.9. Owner: [9 9 6] 0.18, 25%, 3.7; [12 12 8] 0.086, 22%, 2.2; [20 20 12] 0.061, 9.0%, 1.3; [32 16 10] 0.877 (age 27), 79% (age 26), 4.1, with 7% of young owners at the consumption search bound. Step 7 is not grid-converged for either tenure, worst for owners and in early life; the owners' consumption spike at 67 also changes sign across grids.
Stop: the owner's floor share (5.5%) is above the 1% rule. Step 8 not run.
Reading: maintenance is 1.5% of a house that appreciates 3.73% a year while the pension is flat, and the owner can neither sell nor borrow against the house, so in house-price booms maintenance outruns the pension (mean maintenance about EUR 37k a year at 100 against a EUR 52k pension; disposable income negative for the bottom decile). The grid sensitivity is the early-life problem of the research (a committed outflow of 22-24% of income with a floor of 1e-6), here without taxes, plus the owners' late-life low-u1 region.
Commit: c99d9f4, pushed to main.
Open: Quinn's decisions on the owner's housing costs in retirement and on the floor and grid before step 7 is rerun and step 8 runs.

### 2026-10-12 Housing steps 7-8: code, and expectations written before the runs (spec: none, asked by Quinn in Claude Code)
Quinn: housing first, taxes off; step 7 housing with the calibration tables (Table 1: house prices 3.73% real, vol 8.35%, NVM repeat sales 1996-2024; rents 0.99%, vol 1.79%, CBS regulated rents 1983-2025) and the earlier mortgage placeholders (1.36% real, 30 years, LTV 100%; h_mult 4, rent 6%, maintenance 1.5%), no housing correlations; step 8 adds the correlations (Table 3, gross income, 2002-2023): owners house price with income 0.09 and stocks 0.24, renters rent with income 0.06 and stocks 0.43. Defaults kept for the open decisions: entry buffer 0.079, interior-point with the sweep, the full robustness set, check-in after step 8 unless a stop rule fires. The savings stop rule is now measured against income.
Changed:
- `+config/params.m`: Table 1 housing dynamics; new primitives `corr_HL_rent`, `corr_SH_rent`; production corr_HL 0.09, corr_SH 0.24; `lambda_lo = []`.
- `+config/h_corr.m` (new): the H shock's correlations by tenure. `+grids/shock_grid.m`, `+simulate/paths_lna.m` use it.
- `+grids/shock_grid.m`, `+solver/bellman_step_lna.m`: without housing the H shock is degenerate and the housing cost and bequest are zero, so steps without housing no longer depend on housing parameters through nodes no one occupies. Before this, the new housing values moved steps 1-6 slightly through the objective scaling.
- `+utility/build_state_grids.m`: the bottom of the u1 axis defaults to 0.0008, or 0.0002 with housing: under the new house-price process owners reach u1 = 0.0005 at 85+, and 0.0008 put 0.02% of their household-years off the grid.
- `+simulate/paths_lna.m`: the off-grid warning passed a vector to `warning` and errored; it had never fired before.
- `+model/checks.m`, `print_checks.m`, `+figures/dashboard.m`, `step_dashboard.m`: the H shock's correlations with income and stocks on the nodes and in the panel. `+ladder/steps.m`: step 1 sets the housing correlations to 0; step 7 `housing` sets h_mult and the dynamics; new step 8 `housing_corr`. `+ladder/compare.m`: the step's note in the "what changes" box.
- `tests/run_tests.m`: `housing_corr_by_tenure` (node correlations by tenure, none at step 7) and `nohousing_ignores_housing` (changing every housing parameter leaves a solve without housing bit-identical).
- CALIBRATION.md, GRIDS.md, README.md, TODO.md, CALIBRATION_PLAN.md: the new values with sources, the new steps and defaults.
Checks run:
- `run_tests` (full): 0 of 12 checks failed.
- Steps 1-6 re-solved (`ladder.run(1:6, force=true)`) against the results reviewed this morning: on the occupied line values within 5.6e-5 relative and policies within 0.038 at single nodes; in the panel mean pi within 0.001, mean consumption within 0.06%, mean liquid wealth within 0.14% (3.1% once, at near-zero savings). Interior-point's tolerance moves slightly with the objective scaling, which the housing fix changed. The robustness pages for steps 1-6 predate this.
Expectations, step 7 housing against step 6, both tenures:
- Consumption lower at every age, since housing costs come out of the budget and give no utility. Renters by about the rent: 24% of income at 25, falling relative to income in mid-career, then rising in retirement to about 28% of the pension at 67 and a third at 85 (rent grows 0.99% a year, the pension is flat). Owners by about 22% at 25, rising to about a third of income by 54 (the mortgage payment is a rate on a house growing 3.73% a year), dropping when the mortgage ends at 55, then rising again with maintenance on the growing house (about 21% of the pension at 67, 41% at 85 on the mean path).
- Liquid wealth at 67 higher than at step 6, more for owners: retirement housing costs are larger relative to the pension than working-life costs are to income. Owners save hard between 55 and 67.
- The equity share lower at every age where it is below 1, and the all-equity corner left earlier: the housing cost is a liability that shrinks the bond-like net income, and for owners it is risky (8.35% vol) and uncorrelated with stocks at this step.
- Flags: the committed outflow of 22-24% of income at 25 sits between the 11% that converged and the 44% that did not in the research, so c_bound_25_39 may flag; owners in house-price booms may not cover maintenance late in life, so the floor may bind for more than 1% of household-years. Either stops the run.
Expectations, step 8 housing correlations against step 7:
- Owners: stocks partly hedge the house-linked costs (0.24) and income moves a little with them (0.09), so the equity share rises slightly; consumption and wealth move by under 2%.
- Renters: the same direction, smaller, since rent volatility is only 1.79% although the stock correlation is 0.43.
- The correlations on the nodes equal the inputs and in the panel lie within 0.01.
Commit: 72560c9, pushed to main before the runs.

### 2026-10-12 Steps 5 market and 6 corr_SL at standard numerics; the no-housing block is complete (spec: Calibration ladder, part 1)
Changed: `+figures/robustness.m`, `+figures/step_dashboard.m`: % gaps in liquid savings are left out where the reference's savings are below 1% of their peak (they were a few euros at ages 26-30 and dominated the axes). Pages for steps 1-6 redrawn; no numbers changed. Results, gitignored, under `ladder/standard_16x16x10_gh5/`.
Checks run:
- Wealth over final income (the review note above): step 3 liquid wealth at 67 = 10.6 x final income (15.6 x the pension); step 4 renter 7.0 (10.2), owner 7.6 (11.2); at 45: 4.9 against 2.1 / 2.0 x final income. Saving starts later and ends lower relative to income.
- `ladder.robustness(k)` and `ladder.compare(k)`, k = 5, 6, thread pool, interior-point with the sweep. Every arm: offgrid 0, c_bound_25_39 0, floored 0. Entry value 1.12 / 1.18 (step 5) and 1.12 / 1.18 (step 6), renter / owner. Merton 0.195. Correlation at step 6: nodes 0.0400, panel 0.0415, both arms.
- Default against active-set with the sweep, max |d mean pi|: step 5 0.0002 / 0.0003, step 6 0.0003 / 0.0005; consumption within 0.01%.
- Step 5 against step 4, renter / owner (ages 25/35/45/55/65/75/85): mean pi 1 1 0.997/0.999 0.911/0.909 0.75/0.72 0.77/0.744 0.86/0.843 (step 4: 1 1 1 0.984/0.986 0.925/0.911 0.90/0.885 0.944/0.935); mean X/Y0 0.079 0.67/0.43 3.82/3.67 8.17/8.81 11.7/13.0 8.86/9.76 4.13/4.62 (0.079 0.74/0.47 3.95/3.76 8.43/8.99 12.7/13.9 10.7/11.8 5.84/6.51); median C/Y0 at 65 1.89/1.97 (1.98/2.06), at 85 1.66/1.72 (1.83/1.91). Peak X/Y0 12.21 / 13.39 at 67 (13.39 / 14.64); pi below 0.99 from 48 (54).
- Step 5 against the expectation: the equity share falls wherever it is below 1 and households leave the corner six years earlier, as expected, but the retirement share falls to 0.72-0.77, not 0.5-0.6. The saving prediction was wrong: consumption over income in working life is about 1% lower (slightly more saving), but liquid wealth at 67 is 9% lower and retirement consumption 5-10% lower, because the portfolio earns about a point less (lower safe rate, lower equity share).
- Step 6 against step 5, renter / owner: mean pi at 55 0.898/0.896 (0.911/0.909), at 65 0.717/0.687 (0.75/0.72), unchanged from 75 on; X/Y0 and C/Y0 within 1% from 35 on. Against the expectation: the direction is right but the fall is up to 0.033 at 65, not under 0.02, and it is not among the young, who are at the all-equity corner until about 47; it sits at 50-66, where the share is below 1 and income risk remains.
- Stop check: step 6 renter triggered the solver rule on liquid wealth (3.24%), at age 29, where mean savings are 107 euros: 4 euros. The largest absolute gap over ages 26-95 is 7 euros (0.014% of income). Not a solver problem; the rule should measure the savings gap against income or leave out near-zero savings, as the figures now do.
- Owner against renter at step 6: equity share within 0.03, consumption within 6% in multiples of each one's entry income.
- `run_tests(solve=false)`: 0 of 6 checks failed (only figure files changed since the last full run).
Commit: 4f6ccac, pushed to main.
Open: Quinn's review of steps 5-6, which closes the no-housing block (the baseline). Before the housing step: interior-point against active-set in the full model, the entry buffer's denominator, the housing placeholders, and tau_inc against DHS net/gross (later, at the tax step).

### 2026-10-12 Review of steps 1-4, and expectations for steps 5-6, written before the runs (spec: Calibration ladder, part 1)
Quinn reviewed steps 1-4 ("these look good") and agreed with the expectations below. On the step-4 misses, Quinn's reading: lower income risk makes labour income more bond-like, and less liquid saving is needed. Claude Code's note: in retirement neither step has income risk, so the first works through wealth (less precautionary saving leaves less wealth beside the same pension, which raises the retirement equity share); steps 3 and 4 both retire at 67 with the same mortality, so the number of retirement years is the same, and the lower wealth at 67 comes from less precautionary saving and the later, higher income peak. Wealth over final income is checked in the step-5 run.
Same numerics, solver and stop rules as for steps 2-4. Check-in after step 6.
- Step 5 market (r 2% -> 1.15%, premium 4% -> 4.56%, vol 15.7% -> 21.61%), against step 4, both arms: the Merton share falls from 0.325 to 0.195, so the liquid equity share falls wherever it is below 1; households leave the all-equity corner well before 54, and the retirement share falls from about 0.9 towards 0.5-0.6. The lower safe rate and lower risk-adjusted return should, at gamma 5 (EIS 0.2), make households save somewhat more: liquid wealth somewhat higher at 67 and consumption slightly lower when young. Less sure of the saving direction than of the equity share. Renter and owner move alike.
- Step 6 corr_SL (0 -> 0.04), against step 5: human capital becomes slightly equity-like, so the equity share falls a little, mostly where it is below 1 before retirement, by under 0.02; consumption and wealth move by under 1%. The correlation on the quadrature nodes should be 0.0400 and in the panel within 0.01 of it.
Commit: c6bb736, pushed to main before the runs.

### 2026-10-12 Robustness page: levels beside the differences, reference named (spec: none, asked by Quinn in Claude Code)
Changed: `+figures/robustness.m`: each row now shows consumption, liquid savings and the liquid equity share as levels (the reference in black with its band, the variants drawn on top) beside their differences; the title, every legend, every zero line and the settings box name the black line as the step as solved in the ladder with its settings. `+ladder/robustness.m`: the reference label states the solver and grid. Pages for steps 1-4 redrawn from the saved runs; no numbers changed.
Checks run: `run_tests` (full): 0 of 10 checks failed.
Commit: 8f93670, pushed to main.
Open: steps 5 and 6 wait for Quinn's review of steps 1-4.

### 2026-10-12 Sweep back on; step and robustness dashboards; steps 1-4 at standard numerics (spec: Calibration ladder, part 1)
Quinn: turn the sweep back on (interior-point kept as the local solver), and two dashboards per step, one for the change from the previous step with both 10-90 bands, one for the robustness within the step.
Changed:
- `+config/params.m`: `use_refine = true`. CALIBRATION.md, README.md, TODO.md follow.
- `+figures/step_dashboard.m` (new): two results on the twelve-panel page, each with its band (gross income, consumption, disposable income, liquid savings, DC account, housing cost, net worth, total wealth with human capital, liquid equity share, stock exposure over total wealth with each Merton share, % change in consumption and liquid savings, and a box with the parameters that differ and both runs' checks). `+ladder/compare.m` draws it per arm, plus `owner_renter_KK.png` when a step has both tenures.
- `+figures/robustness.m` (new): one page per arm, rows local optimiser / global search / grid, columns consumption and liquid savings as % differences, the equity share and its difference, and a settings-and-checks box. `+ladder/robustness.m` draws it (`robust_KK_<step>_<arm>.png`) instead of three separate figures.
- `tests/run_tests.m`: `figures_render` also draws both new pages.
Checks run:
- `run_tests` (full): 0 of 10 checks failed.
- Steps 1-4 at standard, thread pool, default interior-point with the sweep, each with `ladder.robustness(k)` and `ladder.compare(k)`. No stop check triggered. model.checks for every arm: offgrid 0, c_bound_25_39 0, floored 0; corr nodes 0.000, panel within 0.002 of 0. Default against active-set with the sweep, max |d mean pi|: 0.0001, 0.0011, 0.0012, 0.0006 (renter) / 0.0013 (owner); consumption and liquid wealth within 0.2% (ages 26-95). Entry value: 0.643, 0.903, 0.904, 1.14 (renter) / 1.20 (owner).
- Step 3 against step 2 (ages 25/35/45/55/65/75/85): median C/Y0 0.87 1.12 1.34 1.55 1.75 1.75 1.66 (0.869 1.12 1.34 1.55 1.72 1.72 1.62); mean X/Y0 0.079 2.72 7.43 12.4 15.7 13.1 7.6 (0.079 2.73 7.47 12.5 15.9 12.5 7.22); mean pi 1 1 0.979 0.886 0.807 0.796 0.862 (1 1 0.979 0.884 0.789 0.807 0.87). Peak X/Y0 16.13 at 67 (15.95 at 65). As expected.
- Step 4 against step 3, renter / owner: median C/Y0 1.06/1.07 1.33/1.40 1.57/1.65 1.77/1.86 1.98/2.06 1.96/2.04 1.83/1.91; mean X/Y0 0.079 0.74/0.47 3.95/3.76 8.43/8.99 12.7/13.9 10.7/11.8 5.84/6.51; mean pi 1 1 1 0.984/0.986 0.925/0.911 0.90/0.885 0.944/0.935. Peak X/Y0 13.39 / 14.64 at 67 (16.13); pi below 0.99 from 54 (44).
- Step 4 against the expectation: less saving when young, wealth lower before 50 and the equity share at 1 for ten more years, as expected. Two misses: wealth at 67 is lower, not unchanged (by 17% renter, 9% owner, in multiples of entry income), and the retirement equity share is about 0.1 higher, not unchanged (0.91-0.93 at 65 against 0.81): with less wealth beside the same 68.2% pension, the pension is a larger part of total wealth. Renter against owner: the renter saves more until about 45 and less after (in multiples of its own entry income; the owner's profile rises more), consumption within about 6%, and the renter's equity share is up to 0.016 higher, not lower.
- Robustness at step 4 (owner page): active-set with the sweep within 0.001 in mean pi; sqp with the sweep within 0.001 in pi and 1.1% in consumption (its liquid-savings gap of 57% is at age 31, where savings are near zero). Without the sweep both algorithms go wrong: interior-point's equity share drops to about 0.55 at 26-29 and both fall late in life (active-set by 0.74 at 99). Grids: consumption within 1.6% and liquid savings within 6% ([9 9 6]) or 3% (the others); mean pi within 0.02 on [12 12 8] and [20 20 12], 0.034 on [32 16 10] and 0.079 on [9 9 6], largest around retirement at 67.
Commit: 2042985, pushed to main.
Open: steps 5 (market) and 6 (corr_SL) wait for Quinn's review of steps 1-4.

### 2026-10-12 Step 2 gamma5 at standard numerics; stopped before step 3 on the solver check (spec: Calibration ladder, part 1)
Changed: no code. Results, gitignored, under `ladder/standard_16x16x10_gh5/`: `02_gamma5_nohousing.mat` and dashboard, `compare_01_02_nohousing.png`, `robustness/robust_02_gamma5_nohousing_{optimisers,search,grids}.png`.
Checks run: `ladder.robustness(2)` and `ladder.compare(2)`, thread pool. Default solver (interior-point, no sweep), solve 13.2 s. model.checks: offgrid 0, c_bound_25_39 0, floored 0, ce_entry 0.9035, Merton 0.3246, corr nodes 0.000, panel 0.002.
Against step 1 (ages 25/35/45/55/65/75/85): median C/Y0 0.869 1.12 1.34 1.55 1.72 1.72 1.62 (step 1: 0.64 0.961 1.27 1.55 1.81 1.82 1.76); mean X/Y0 0.079 2.73 7.47 12.5 15.9 12.5 7.22 (0.079 5.47 12.4 18.1 20.9 16.4 10.4); mean pi 1 1 0.979 0.884 0.789 0.807 0.87 (1 0.736 0.469 0.386 0.385 0.4 0.438). Peak liquid wealth 15.95 x entry income at 65 (20.90); pi below 0.99 from 43 (30).
Against the expectation: as written. Consumption 36% higher at 25 and 20% lower at 100; liquid wealth lower at every age, peak 24% lower; pi at 1 until 43 and about twice as high in retirement. Close to the quick prior.
Stop: the solver check failed. The default's mean pi is up to 0.090 below active-set with the sweep, at ages 93-99 only (0.878 against 0.968 at 99); consumption and liquid wealth agree within 0.06% (ages 26-95). Interior-point with the sweep agrees with active-set with the sweep to 0.001, so the gap is the missing sweep, not the algorithm. On the occupied line the default reaches a lower value than active-set with the sweep at 88% of node-ages (by at most 4.6e-4, relative), and its policy differs by more than 0.05 at 46 node-ages, ages 66-99, at u1 >= 0.93. Solve times: default 13 s, interior-point with sweep 11 s, active-set with sweep 7 s. Steps 3 and 4 not run; waiting for Quinn on the sweep.
Commit: 718757f, pushed to main.

### 2026-10-12 Expectations for steps 2-4, written before the runs (spec: Calibration ladder, part 1)
Quinn: run steps 2-4 without stopping in between, check in after step 4; follow the cubic to 66. Standard numerics, default solver (interior-point, no sweep). I stop early if a check flags (off-grid lookups, c_bound_25_39 > 5%, floored > 1%, a correlation off by > 0.01), if a result goes against the direction below, or if the default moves more than 0.02 in mean pi or 2% in consumption or liquid wealth (ages 25-95) from active-set with the sweep. This morning's quick baseline (old solver, same calibration for steps 2-3) is the prior quoted below.
- Step 2 gamma5 (gamma 10 -> 5), against step 1: the precautionary motive roughly halves and the Merton share doubles (0.162 -> 0.325). Consumption higher when young (C/Y0 at 25 up by about a third) and lower late in retirement; liquid wealth lower at every age, the peak about a quarter lower; the equity share stays at 1 into the 40s and roughly doubles in retirement. Quick baseline: median C/Y0 at 25 0.87 against 0.64, net worth at 66 15.6 against 20.8 x entry income, mean pi 0.97 at 45 and 0.82 at 80.
- Step 3 retire67 (65 -> 67), against step 2: small. Two more working years and a shorter retirement: consumption slightly higher, the wealth peak moves to 67 at about the same level, the equity share almost unchanged and slightly lower in retirement. Income at 66 is the CGM cubic one year past its sample. Quick baseline: changes under 2%.
- Step 4 income (DHS, a renter and an owner arm), against step 3: the permanent std falls from 0.1032 to 0.0816 / 0.0843, and the profile rises more (peak over entry 1.88 owners, 1.73 renters, against about 1.55 for CGM) and peaks later (50 / 49, against about 43 for the CGM cubic). Expect less saving when young: consumption higher relative to income and liquid wealth lower before 50 in multiples of entry income; at 67 roughly unchanged, since a higher final income raises retirement saving while less risk lowers it. The equity share stays at 1 longer (less income risk, more human capital ahead); in retirement about unchanged (same Merton share and replacement rule). Renters, with a slightly higher std and a flatter profile, save a little more relative to income and hold a little less equity; the arms should differ by a few percent at most. Their income levels differ by about a quarter, which cannot matter here because the model is homothetic without a franchise.
Commit: 28ce196, pushed to main before the runs.

### 2026-10-12 Default solver: interior-point without the global sweep (spec: none, decided by Quinn in Claude Code)
Decision (Quinn, "for now"): `fmincon_algorithm = 'interior-point'`, `use_refine = false`. The evidence from the entry below stands: this matches the sweep at step 1 but not at the production calibration, so `ladder.robustness(k)` should be read at every step, and the sweep should be reconsidered before the housing step (TODO.md, 6).
Changed: `+config/params.m` (the two defaults); `+solver/bellman_step_lna.m` (docstring); `+ladder/robustness.m`: variants now relative to the defaults: 'optimisers' = the other two algorithms with the reference's sweep setting, 'search' = the sweep switched for the reference's algorithm and for active-set; grids use the reference's solver. `tests/run_tests.m`: `collapsed_axes_exact` pinned to active-set with the sweep; under interior-point it failed (max d pi 0.0047 against 1e-3, max |dV/V| 1.4e-5 against 4.6e-8 for active-set, largest gap at u1 = 1, age 65, c = 1.000, where pi does not matter), which is the optimiser's tolerance and the different objective scaling of the two cubes, not the axes. CALIBRATION.md, README.md, TODO.md: the new defaults and the evidence.
Checks run:
- `run_tests` (full): 0 of 10 checks failed (after pinning; 1 of 10 before, as above).
- Step 1 re-solved at standard with the new default (`ladder.run(1)` via `ladder.robustness(1)`): solve 14.6 s on a thread pool; c_bound_25_39 0, ce_entry 0.6427, offgrid 0, floored 0.
- `ladder.robustness(1)` against it (max |d mean pi|, |dC/C|, |dX/X|): interior-point with sweep 0.001, 0.0%, 0.0%; active-set with sweep 0.001, 0.0%, 0.0%; active-set without 0.205, 152%, 491%; sqp without 1.000, 69%, 100% (stays at its seed: pi 0, no saving); grids [9 9 6] 0.028, 2.9%, 9.0%, [12 12 8] 0.012, 1.1%, 3.5%, [20 20 12] 0.010, 0.6%, 1.8%, [32 16 10] 0.012, 1.2%, 3.7%.
Commit: 0edb2c5, pushed to main.
Open: step 2 waits for review of step 1.

### 2026-10-12 Does interior-point need the global sweep? (spec: none, asked by Quinn in Claude Code)
Quinn asked whether interior-point uses the global sweep, and to make it the default if it does not need it. The sweep runs before fmincon whatever the algorithm, so the interior-point run of the previous entry had it. Tested without it. Decision: it needs the sweep at the production calibration and is slower, so the default stays active-set with the sweep.
Changed: `+ladder/robustness.m`: the 'search' set also solves interior-point without the sweep.
Checks run:
- Step 1, standard, thread pool, against active-set with the sweep (7.1 s): interior-point without the sweep (14.9 s) gives the same panel (max |d mean pi| 0.001, consumption and savings 0.0%). Its policy differs by up to 1.0 at 681 of 5,472 node-ages, 638 of them off the occupied u2 = u3 = 0 line and the rest at poor retirees (u1 0.53-1) who consume most of their resources. Figure `robustness/robust_01_cgm_nohousing_search.png`.
- Production calibration (step 10), quick numerics, thread pool, renter and owner; solve s; max |d mean pi|; max |dX/X|: active-set with sweep 54 / 39 (reference); interior-point with sweep 96 / 89, 0.038 / 0.097, 0.4% / 1.5%; interior-point without 67 / 69, 0.133 / 0.236, 4.3% / 96.6%; active-set without 25 / 24, 0.270 / 0.267, 4.7% / 95.6%. Without the sweep both algorithms lose value against the reference at about 90% (interior-point) and 84% (active-set) of node-ages. With the sweep neither algorithm dominates: interior-point is higher at 52% of renter node-ages and lower at 59% of owner node-ages. Each solve's values rest on its own continuation, so this ranks tendencies, not node by node. Figures `ladder/quick_12x12x8_gh3/robustness/robust_10_box3_<arm>_interior_point.png` (scratch script, not in the repo; `ladder.robustness(10, numerics='quick')` reproduces the same runs plus the grid set).
- `run_tests` (full): 0 of 10 checks failed.
Commit: 1000075, pushed to main.
Open: step 2 waits for review of step 1.

### 2026-10-12 Old-style dashboards, overlay figures, ladder.robustness (spec: none, asked by Quinn in Claude Code)
Quinn asked for the earlier make_plots dashboards back and for the optimiser and grid checks to be drawn on the same panels instead of tabulated. Step 1 is CGM's calibration in this model; Quinn's calibration enters at steps 4-6, which have not run.
Changed:
- `+figures/dashboard.m`: the twelve-panel layout of demo/make_plots.m (income and housing costs, consumption, disposable income, net worth, DC account, housing, total wealth with human capital, share consumed, stock shares, total stock exposure, stock share of savings and pension, calibration), in thousands of 2025 euros (CGM units at steps 1-3), with the step in the title and model.checks in the calibration panel. `+figures/panel_data.m` (new) rebuilds the panel from a saved result with the run's N_sim and seed.
- `+figures/compare.m`: overlay of two to six results, the first as a black reference with its 10-90 band. Rows: levels (consumption, liquid savings, net worth, liquid equity share); differences from the reference; the equity-share policy at 30, 55 and 75 read off each result's own grid, with its nodes marked; settings and checks, including the parallel pool. Used by ladder.compare and ladder.robustness. `+figures/style.m`: all eight palette slots.
- `+config/params.m`, `+solver/bellman_step_lna.m`: new numerics primitive `fmincon_algorithm` ('active-set', unchanged default). `+ladder/robustness.m` (new): re-solves a step with sqp and interior-point, without the global sweep, and on grids [9 9 6] gh 3, [12 12 8] gh 3, [20 20 12] gh 5 and [32 16 10] gh 5, saves them under `<numerics>/robustness/` and draws one overlay per set.
- `tests/run_tests.m`: `figures_render` draws both figures for a no-housing step and an owner with housing and DC. CALIBRATION.md: `fmincon_algorithm`. README.md: dashboards and robustness. TODO.md: DHS net/gross at 25 implies an average tax of about 23% (owners) and 25% (renters), against the 38.2% of the income-tax step.
Checks run:
- `run_tests` (full): 0 of 10 checks failed.
- Step 1 re-solved after adding the primitive: V, c_pol, pi_pol and summary identical to the earlier run (`isequaln`).
- `ladder.robustness(1)`, all on a thread pool, against the reference (max over ages of |d mean pi|, |dC/C| mean, |dX/X| mean): sqp 0.014, 6.1%, 4.7%; interior-point 0.000, 0.0%, 0.0%; no global sweep 0.205, 152%, 491% (pi at 65 drops to 0.18; consumption and savings diverge after 90); grid [9 9 6] 0.028, 2.9%, 9.0%; [12 12 8] 0.012, 1.1%, 3.5%; [20 20 12] 0.006, 0.6%, 1.8%; [32 16 10] 0.012, 1.2%, 3.7%.
- Pool dependence: sqp on a process pool equals the reference to 1e-5 in the policies, on a thread pool it differs by up to 0.069 in pi_pol (largest gap in mean pi at age 98). Active-set and interior-point give the same results on both pools. The sqp figures in the entry below were on a thread pool. Figure: `robustness/robust_01_cgm_nohousing_pool.png`.
Commit: 989db7f, pushed to main.
Open: step 2 waits for review of step 1.

### 2026-10-12 Step 1 cgm at standard numerics, and robustness checks (spec: Calibration ladder, part 1)
Changed: no code. Result saved, gitignored, under `ladder/standard_16x16x10_gh5/` (`01_cgm_nohousing.mat`, its dashboard, and `cgm_compare_01.png`, the result laid out like CGM's Figures 2 and 3).
Checks run: `ladder.run(1)`: one arm (nohousing), 18 x 2 x 2 nodes, gh_n 5, 10,000 households, solve 13 s. CGM income units (Y0 = 20.5):
  age 25: income 20.5, median C 13.1, mean liquid 1.6, mean pi 1.000
  age 35: income 28.7, C 19.7, liquid 112, pi 0.736
  age 45: income 31.8, C 26.0, liquid 255, pi 0.469
  age 55: income 31.2, C 31.8, liquid 372, pi 0.386
  age 65: income 21.0, C 37.1, liquid 429, pi 0.385
  age 75: income 21.0, C 37.3, liquid 337, pi 0.400
  age 85: income 21.0, C 36.2, liquid 213, pi 0.438
  Merton share 0.162. model.checks: c_bound_25_39 0, ce_entry 0.643, offgrid [0 0 0], floored 0, thin_u1_40 0.10; corr nodes 0.000, panel 0.002 (corr_SL 0).
Against the expectation: the equity share and wealth are as expected. Mean pi leaves 0.99 at 30, bottoms out at 0.379 at 59 and rises to 0.54 at 95; liquid wealth peaks at 65 (20.9 x entry income, against 20.8 at quick); the largest gap to the quick run is 0.012 in pi. Consumption humps, but the expectation was wrong that it tracks income until 35: it is 64% of income at 25.
Against CGM (2005), read off their figures: the shapes of Figure 3A and 3C and all three panels of Figure 2 are reproduced (pi decreasing in cash on hand at every age; the age-99 rule at 1 below about 1.5 x income and falling towards the Merton share of 0.16; consumption concave and rising with age). Levels differ, and the difference starts with saving when young: median consumption is 64% of income at 25 and 69% at 35, where CGM's households consume about their income until 35; mean liquid wealth is about 3.7 times CGM's at 35 and about 2 times at 65 (429 against about 220). With more wealth relative to human capital, households move down the decreasing pi rule earlier: they leave the all-equity corner at 30 (CGM about 38) and bottom out at 0.38 at 59 (CGM 0.50 at 65); the retirement rise is weaker (0.54 at 95 against 0.65). Our reading, not tested: at gamma 10 and a permanent std of 0.103, the precautionary term of a second-order Euler approximation is about (gamma/2) sigma^2 = 5.3% a year of consumption growth, against income growth of 4.3% at 25 and 1.5% at 35, so the model saves from the start; entry at 25 (a flatter part of the profile than CGM's 20) with a 0.08-year buffer, and Dutch 2021-26 mortality (longer retirement, slower decumulation) push the same way. A transitory shock would by the same logic add precautionary saving and lower pi, so on its own it should widen the gap, not close it; worth a test before it is cited as the cause. The terminal age of 100 is CGM's own.
Robustness of step 1 (scratch runs, nothing saved), against the standard active-set run, max over ages of |d pi|, |dC/C| (median C), |dX/X| (mean liquid):
  grid [12 12 8] gh 3: 0.012, 1.3%, 3.5%. [20 20 12] gh 5: 0.006, 0.7%, 1.8%. [40 2 2] gh 5 (42 u1 nodes): 0.014, 1.6%, 4.3%. [9 2 2] gh 3: 0.029, 3.2%, 9.1%.
  fmincon sqp instead of active-set: 0.014, 6.1%, 4.7% (within 0.003 in pi and 0.3% in C at ages 25-85). fmincon interior-point: 0.0001, 0.0%, 0.0%, 20 s instead of 13 s.
  No global sweep (use_refine = false, fmincon from the warm start only): 0.21, 62%, 491%. pi at 65 falls to 0.19. This is the known basin-trapping failure; the default keeps the sweep.
  Smoke solves of the new code under all three algorithms (steps 4 and 6 with two no-housing arms on [7 5 4] and [10 8 6], production with housing and DC on [8 6 5]): all finite and in range, no off-grid lookups, correlation 0.0400 on the nodes and 0.0390 in the panel at corr_SL 0.04. interior-point printed 380 "matrix is singular" warnings from inside fmincon on the production smoke solve, with results matching active-set (pi at 45: 0.027 against 0.028 for renters, 0.135 against 0.135 for owners).
Commit: 6b127ea, pushed to main.
Open: step 2 (gamma5) waits for review of step 1.

### 2026-10-12 Step 1 expectation, written before the run (spec: Calibration ladder, part 1)
Step 1 (cgm) has no parent; the benchmark is CGM (2005) Figure 3. Expect consumption to track income until about 35 and then hump, and liquid wealth to build to a peak at 65 and run down after. The equity share should start at 1, leave the corner near 28 (CGM: about 38), bottom out near 0.37-0.40 around 58-62 (CGM: 0.50 at 65) and rise through retirement to about 0.55 (CGM: 0.65). Standard numerics change only the grid and quadrature, so the quick baseline (mean pi 0.47 at 45, 0.41 at 80; net worth 20.8 x entry income at 66) should move by a few percent at most.
Commit: c7bf0f2, pushed to main before step 1 ran.

### 2026-10-12 Calibration ladder part 1: code work (spec: Calibration ladder, part 1, items 3b-f)
Changed:
- `+config/params.m`: production income is the DHS owner cubic and sigma (`income_source = 'dhs'`); new primitives `income_coef_rent`, `sigma_l_log_rent`, `dhs_price_factor` (1.0); market r 0.0115, mu_S_level 0.0456, sigma_S_level 0.2161, corr_SL 0.04. `income_price_factor` now applies to the BKV table only.
- `+config/income_process.m` (new): the tenure's cubic and shock std. `+config/income_profile.m`: case 'dhs' (the 'poly' cubic plus log of the price factor); both cubic sources and the shock std read the tenure's fields. `+config/derive.m`: the DC guard still blocks only 'poly'; note that kappa depends on tenure.
- `+model/tenures_differ.m` (new), `+model/tenure.m`: labels nohousing_renter and nohousing_owner when the renter fields differ. `+model/run.m`: refuses a p whose kappa was derived for the other tenure. `+model/checks.m`, `+model/print_checks.m`: `corr_SL_nodes` and `corr_SL_sim`, with a note if either is more than 0.01 from corr_SL. `+simulate/paths_lna.m`: keeps the stock return draws (`sim.R_S`).
- `+ladder/steps.m`: step 1 sets the CGM income cubic, sigma 0.1032 and corr_SL 0 for both tenures explicitly; step 4 DHS income; step 5 market; new step 6 `corr_SL`. `+ladder/run.m`, `run_model.m`: two arms when the tenures differ, each derived after setting is_owner. `+ladder/load.m`, `report.m`, `compare.m`: the new arm names; compare matches each arm to the same tenure of the other step.
- `+figures/dashboard.m`: shows the tenure's sigma_l and corr_SL.
- `tests/run_tests.m`: the BKV anchor test replaced by DHS checks (level at 25 and at the peak, peak age, sigma, replacement step, both tenures); new `tenure_arms` (no solve) and `nohousing_arms_corr` (both arms of step 6 on a small grid, correlation on the nodes within 1e-10 and in the panel within 0.01).
- CALIBRATION.md: DHS income, market and corr_SL lines with sources; r relabelled as interbank, not T-bill; CGM core table; premium, Merton and kappa numbers recomputed at the new values. CALIBRATION_PLAN.md: renumbered (corr_SL is step 6, later steps up by one); the Claude Doc still has the old numbers. README.md: ladder table. TODO.md: sigma_l_log and corr_SL rows removed; new row on the entry buffer's denominator.
Checks run:
- `run_tests(solve=false)`: 0 of 6 checks failed.
- Steps 1-3, `ladder.run(1:3, numerics='quick', force=true)` against the baseline files: V, c_pol, pi_pol, summary and every common checks field identical (`isequaln`), max |dV| = 0 for all three. `ladder.same_calibration(old.p, new.p)` is false for all three only because the baseline files lack the three new primitives; every primitive the baseline has is equal.
- `run_tests` (full): 0 of 9 checks failed (39 s).
- Liquid Merton share by step (gamma, after tax): 1 cgm 0.162; 2-4 0.325; 5-9 0.195; 10 box3 0.077 (was 0.180 at the old market values: the higher volatility deepens the no-loss-offset cut).
Commit: c7bf0f2, pushed to main.
Open: the entry buffer b0 still divides by the BKV men's wage at 25 (TODO.md).

### 2026-10-12 Baseline on d8efb70 (spec: Record a baseline)
Changed: no code. Results saved, gitignored, under `baseline_d8efb70/ladder/quick_12x12x8_gh3/`.
Checks run:
- `run_tests` (full): 0 of 7 checks failed (55 s).
- `ladder.run('all', numerics='quick', force=true)`: finished in 308 s, 16 thread workers. model.checks per arm (c_bound_25_39, ce_entry, offgrid, floored share, liquid Merton, solve s):
  1 cgm nohousing 0.0000, 0.6365, [0 0 0], 0.0000, 0.1623, 4
  2 gamma5 nohousing 0.0000, 0.8992, [0 0 0], 0.0000, 0.3246, 4
  3 retire67 nohousing 0.0000, 0.9001, [0 0 0], 0.0000, 0.3246, 4
  4 income nohousing 0.0000, 1.067, [0 0 0], 0.0000, 0.3246, 4
  5 market nohousing 0.0000, 1.038, [0 0 0], 0.0000, 0.3126, 4
  6 housing renter 0.0000, 0.6282, [0 0 0], 0.0076, 0.3126, 13
  6 housing owner 0.0000, 0.6897, [0 0 0], 0.0171, 0.3126, 13
  7 pension renter 0.0000, 0.5885, [0 0 0], 0.0031, 0.3126, 40
  7 pension owner 0.0000, 0.6007, [0 0 0], 0.0015, 0.3126, 38
  8 inctax renter 0.0000, 0.2140, [0 0 0], 0.0216, 0.3126, 38
  8 inctax owner 0.0001, 0.2079, [0 0 0], 0.0116, 0.3126, 38
  9 box3 renter 0.0000, 0.1988, [0 0 0], 0.0231, 0.1799, 39
  9 box3 owner 0.0001, 0.1924, [0 0 0], 0.0123, 0.1799, 40
- The fresh results are bit-identical (V, policies, summaries, all 13 arms) to the 1 Oct quick results in `ladder/quick_12x12x8_gh3/`.
Commit: no code change; logged together with the code work above.
Open: none.

### 2026-10-07 Calibration plan and working setup into git (spec: none, asked by Quinn in Claude Code)
Changed: added CALIBRATION_PLAN.md, the step-by-step plan for the new calibration, exported from the Claude Doc at https://claude.ai/code/artifact/f90a2f02-9934-4efe-a81c-2b9f2adb6163 (the doc's route widget is written out as text). README.md points to it. Committed CLAUDE.md, HANDOFF.md and .claude/ (skills and hooks) as they were on disk. `claude_setup/` is an identical copy of `.claude/` and was not committed. Earlier today: pushed main (lean core), solver-active-set, tag research-2026-09 and chore/prune-and-group-scripts, and committed demo/ (9fa84ac). No .m files changed.
Checks run: `matlab -batch "addpath tests; run_tests(solve=false)"` printed 0 of 5 checks failed.
Commit: 0011a63, pushed to main.
Open: the plan's questions 1 to 4 (income polynomial form and units, permanent vs transitory variance, market series, retirement income before the DC pension) block the code work before step 1. The "Record a baseline" spec is not started.

### 2026-10-07 Starting state (checked from chat, not a Claude Code run)
Repo: main at 9fa84ac, equal to github/main. Untracked: `demo - Copy/`, `demo - Copy.zip`.
The ladder, `run_tests` and `model.checks` are in main. The old `param_fingerprint` gate is gone; `ladder.same_calibration` replaces it.
Checks run: none.
Open: baseline spec above.

## Entry formats

Spec:

    ### <date> <short title>
    Change: what to change.
    Why: one line.
    Checks that must pass: what to run and what result counts.

Log:

    ### <date> <short title> (spec: <title or none>)
    Changed: files and what.
    Checks run: command, then the numbers it printed.
    Commit: <hash>, pushed to main.
    Open: what is left, or "none".
