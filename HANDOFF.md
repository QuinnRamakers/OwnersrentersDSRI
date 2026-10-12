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

### 2026-10-12 Step 1 expectation, written before the run (spec: Calibration ladder, part 1)
Step 1 (cgm) has no parent; the benchmark is CGM (2005) Figure 3. Expect consumption to track income until about 35 and then hump, and liquid wealth to build to a peak at 65 and run down after. The equity share should start at 1, leave the corner near 28 (CGM: about 38), bottom out near 0.37-0.40 around 58-62 (CGM: 0.50 at 65) and rise through retirement to about 0.55 (CGM: 0.65). Standard numerics change only the grid and quadrature, so the quick baseline (mean pi 0.47 at 45, 0.41 at 80; net worth 20.8 x entry income at 66) should move by a few percent at most.

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
Commit: pending (filled in by the next commit).
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
