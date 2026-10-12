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

### 2026-10-07 Record a baseline
Change: no code change. Run the full test suite and the quick ladder once, and log the results.
Why: everything later is compared against this.
Checks that must pass: `run_tests` reports 0 failures. `ladder.run('all', numerics='quick')` finishes; log the `model.checks` values (`c_bound_25_39`, `ce_entry`) for steps 6 to 9, both tenures.
Done: 2026-10-12

## Log (from Claude Code)

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
