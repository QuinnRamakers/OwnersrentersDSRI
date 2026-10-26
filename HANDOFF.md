# Handoff

The shared log between chat (Claude on claude.ai) and Claude Code. Newest entry first in each section.

Rules:
1. Chat writes only under "Specs". Claude Code writes only under "Log".
2. A spec is marked done by adding one line under it, "Done: <date of the log entry>". Nothing else is edited.
3. A log entry is not complete without the commit hash and the numbers the checks printed.
4. If this file and chat disagree, this file wins.

## Specs (from chat)

### 2026-10-23 The consumption floor as an absorbing state, linked to labour income
Written in Claude Code on 22-23 Oct as `docs/prompts/absorbing_floor.md` (branch claude/dreamy-edison-1814gg, c710366; brought onto main with this entry); Quinn pasted it into Claude Code, which copied it here in short.
Change: a household whose liquid resources fall below the floor F_t = phi_t Y_t goes bankrupt and consumes F_{t*} for the rest of its life, with no choices: V~^B_t = (phi_t u1)^(1-gamma)/(1-gamma) D_t, D_t = 1 + beta p_t D_{t+1}, D_T = 1. No new state. New primitives `c_min` (euros at median income; phi_t = c_min / Ybar_t, tied to final labour income in retirement) and `phi_abs` (one share of permanent labour income); derived `phi_path`, `D_abs`, `floor_absorbing`. Both 0 is today's model. The floor is also the search's lower bound for solvent households. Simulation: an absorbing flag, `absorbed` and `abs_age`; summaries over solvent households for wealth and shares; `abs_hazard`; bankrupt shares in the checks; labels "bankrupt" in the figures; `_cmin<euros>` in `case_params`.
Why: the 1e-6 floor's certainty equivalent is orders of magnitude below its neighbours, and interpolation misprices the states next to ruin (HANDOFF, 18 Oct); a higher top-up floor is free insurance.
Checks that must pass: `run_tests(solve=false)` and the full `run_tests`, 0 failures, with the new checks (off: step 16 both tenures on the small grid bit-identical to 7b5143d; `D_abs` against the explicit sum to 1e-12; `phi_path` for (a) and (b); the closed form at a bankrupt node to 1e-12; a bankrupt household stays bankrupt at a constant consumption and is never off the grid; `derive` refuses bad inputs). Then the runs one at a time on the 20 Oct summary grids, with expectations written first and `model.checks` read after: c_min 8,000 (both tenures, both maintenance rules), c_min 6,000 and 10,000, the grid test at 8,000, `ruin_interp` at 8,000.
Done: 2026-10-23

### 2026-10-15 The mortgage as a state variable, q = H0/H
Written in Claude Code on 15 Oct as `docs/prompts/mortgage_state.md` (against e87d7d2, cherry-picked onto main as ab313ee); Quinn pasted the start instructions into Claude Code, which copied the spec here in short.
Change: replace the proportional mortgage with a real annuity on the purchase price, carrying q = H0/H as a fourth state (axis q_hi * s^grid_pow_q, 8 base nodes, q = 1 spliced in; a single node where q is not a state). Step 7 keeps the proportional contract; a new step `annuity` directly after it, shown as 7b (Quinn's choice, 15 Oct: later steps keep their numbers), switches to the annuity, and production inherits it. Test: maintenance on the purchase price (`maint_on_purchase`), as 7b's sensitivity. No bequest netting yet.
Why: the payment tied to the house price is one of the two causes of step 7's grid dependence (HANDOFF, 12 Oct).
Checks that must pass: full `run_tests` 0 failures, with the new checks (flat prices: annuity = proportional at q = 1 within 1e-10; N_q by arm; payment m LTV H0 to N_mort with present value 1.00 times the loan to 1e-12; the step's parents). Step 7, both tenures, small grid, bit-identical to 6f61c85 (Quinn, 15 Oct: 6f61c85 instead of e87d7d2, since main moved on). Then the plan's runs one at a time at standard numerics, with an expectation before each and `model.checks` read after, stopping for Quinn after each.

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

### 2026-10-26 Maintenance on the purchase price the default, for now; the findings documented (spec: none, asked by Quinn in Claude Code)
Quinn: document what was found, set maintenance on the purchase price as the default for now (keep the current value as an option), and push everything.
Changed: `+config/params.m`, `maint_on_purchase = true`. `+ladder/steps.m`: step 1 sets `maint_on_purchase = false`, so steps 1-16 keep their calibration; new last step 17 `maint_purchase` sets it true, so the last step equals `config.params`. `tests/run_tests.m`, `ladder_branches`: step 17 is the last, step 16 on the current value and step 17 on the purchase price. CALIBRATION.md (`maint_on_purchase` row and the paragraph on it), README.md (ladder table, step 17 is `config.params`), CLAUDE.md (the known limit on grids, rewritten from the 24-26 October work), TODO.md (Numerics). New `docs/HANDOFF_2026-10-26.md`: the figures to look at, what was decided (search routine, edge fix rejected, the grid u1 32 / u2 16 / u3 40 / q 4, the maintenance default), what was found, run times, decisions open, how to reproduce, commits.
Not changed: the grid in `config.params` (still uniform 20x20x12x8; the chosen grid and the u3 spacing are open, docs/HANDOFF_2026-10-26.md section 5); c_min (still 0). The grid-study case names build on `ladder.params(16)`, which keeps the current value; `_mop` gives the purchase price.
Checks run: `run_tests(solve=false)` 0 of 11 failed. Saved step-16 owner solves (with and without `_mop`) are still the same calibration as `case_params` builds now (`ladder.same_calibration` 1 and 1); `ladder.params(17).maint_on_purchase` and `config.params().maint_on_purchase` both 1. The full `run_tests` was not run.
Commit: this entry with the code and documents, pushed to main.
Open: as in docs/HANDOFF_2026-10-26.md, section 5.

### 2026-10-25 Owner grid with maintenance on the purchase price: results (spec: none, asked by Quinn in Claude Code)
Follows the expectations entry below (e4d1b85). Ran the five `_mop` solves, two at a time, then the new `diagnostics/nibud/maintenance_rule_page.m`. Output (gitignored): `summary_step16/16_cmin5000_owner_maintenance_rules.png`.
Peak mean liquid saving / bankrupt by 85 / median consumption at 30 / at 70 (times entry income), solve minutes, purchase price (current value in brackets):
- Base (16x16, u3 10, q 4): 1.12 / 1.1% / 0.384 / 1.020, 30 min (2.72 / 14.3% / 0.332 / 0.770, 13 min).
- u1 32: 0.97 / 1.0% / 0.379 / 1.008, 55 min (2.81 / 13.6% / 0.305 / 0.774, 25 min).
- u3 40: 1.07 / 1.1% / 0.386 / 1.016, 168 min (4.35 / 8.0% / 0.309 / 0.705, 100 min).
- q 8: 1.09 / 0.9% / 0.380 / 1.018, 60 min (2.67 / 14.1% / 0.332 / 0.768, 23 min).
- Chosen grid (u1 32, u2 16, u3 40, q 4): 0.97 / 1.0% / 0.378 / 1.005, 246 min (4.79 / 6.7% / 0.274 / 0.726, 100 min).
Results: on the purchase price the grid matters little. Consumption agrees across all five grids within about 2% at every age; owners save about a fifth as much as on the current value; all bankruptcy (about 1%) happens while the mortgage runs, none after 54; the retirement equity share is about 1. u3 makes no visible difference (it mattered through old-age bankruptcy, which this rule removes). u1 at 32 lowers liquid saving around 60 (second peak 1.1 to 0.9). q at 8 changes bankruptcy by 0.2 points and the young equity share. Solves take about 2-2.5 times as long, since q enters the budget in every year. The chosen grid is safe under both rules; on the purchase price its u3 points cost time without changing the answer.
Against the expectations: as expected (bankruptcy, u3, u1); q mattered a little more than on the current value, as expected, and 8 points stay close to 4.
Checks run: none (no code in `+solver`, `+config`, `+ladder` or `+model` changed).
Commit: this entry with `maintenance_rule_page.m`, pushed to main.
Open: the maintenance rule for production (Quinn); then the u3 spacing and putting the grid into `config.params`; c_min.

### 2026-10-25 Owner grid with maintenance on the purchase price; expectations before the runs (spec: none, asked by Quinn in Claude Code)
Quinn chose the production grid u1 32, u2 16, u3 40, q 4 (placement of u3 still to decide; bunched used here), asked whether the owner runs used maintenance on the current or the initial house value (all 19 owner solves at c_min 5,000 used the current value, read from the saved files), and asked to rerun the owner results with maintenance on the purchase price.
Runs (step 16 owner, c_min 5,000, active-set, `_mop`), two at a time: base `pow3_16x16_lim_u3p2_qn4_cmin5000_as_nc11_mop`; u1 32 (`pow3_32x16_...`); u3 40 (`..._qn4_u3n40_...`); q 8 (`..._qn8_...`); the chosen grid `pow3_32x16_lim_u3p2_qn4_u3n40_cmin5000_as_nc11_mop`. Compared with the same runs on the current value. No code change.
Expectations: old-age bankruptcy almost disappears (at 8,000 on 23 October owners on the purchase price went bankrupt only while the mortgage ran, 3% by 67), so u3 matters much less than on the current value; u1 still moves young consumption; q matters more than on the current value, since it sets the maintenance bill for life, but 8 points stay close to 4; the chosen grid lies close to the u3 40 and u1 32 runs.
Checks run: none (no code changed).
Commit: this entry, pushed to main.
Open: the runs.

### 2026-10-25 Confirming grid per tenure: results (spec: none, asked by Quinn in Claude Code)
Follows the expectations entry below (e5e8343). Ran the two solves side by side, then the new `diagnostics/nibud/confirm_grid_page.m`. Output (gitignored): `summary_step16/16_cmin5000_confirm_grids.png`.
Peak mean liquid saving / bankrupt by 85 / median consumption at 30 / at 70 (times entry income), solve minutes:
- Renter confirming grid (u1 64, u2 16, u3 40 even; 66x18x40): 4.65 / 1.7% / 0.272 / 0.720, 68 min. The 24 October candidate (32x32, u3 40 even; 34x34x40): 4.58 / 1.8% / 0.283 / 0.715, 85 min (shared with two other solves). Finest single-axis runs: u3 80 even 4.23 / 2.5% / 0.327 / 0.708; u1 64 3.86 / 5.3% / 0.316 / 0.700.
- Owner confirming grid (u1 32, u2 16, u3 40 bunched, q 4; 34x18x40x5): 4.79 / 6.7% / 0.274 / 0.726, 100 min. Finest single-axis runs: u3 80 4.60 / 7.8% / 0.307 / 0.701; u1 64 2.85 / 13.2% / 0.295 / 0.774; all doubled (32x32, u3 20, q 8) 3.90 / 7.6% / 0.283 / 0.737, 150 min.
Results: renter, the confirming grid and the candidate are two different grids of about the same size, one spending its points on u1 and one on u2, and their life cycles lie on top of each other from about 40 on; they differ only in young consumption and the young equity share (u1 64 against 32: consumption at 30 4% lower). Owner, the confirming grid matches u3 at 80 in retirement (saving, consumption, equity share 0.6-0.7) and adds the u1 effect in working life (saving at 55 3.8 against 3.3); it has the least bankruptcy of all owner runs. The owner was not checked against a grid finer in both u1 and u3 at once.
Against the expectations: renter as expected (peak 4.65, bankrupt by 85 1.7%); owner as expected (peak 4.79, bankrupt by 85 6.7%, below the 7-7.5% expected).
Checks run: none (no code in `+solver`, `+config`, `+ladder` or `+model` changed).
Commit: this entry with `confirm_grid_page.m`, pushed to main.
Open: adopting the grids. `config.params` holds one `grid_dims` for both tenures; per-tenure grids need new primitives. Optional owner check: u1 64 with u3 40 (66x18x40x5, about 3.5 hours).

### 2026-10-25 Confirming grid per tenure; expectations before the runs (spec: none, asked by Quinn in Claude Code)
Quinn: solve one confirming grid per tenure, with the points where the one-axis studies found they matter, and show it against the finest single-axis runs. Renter: u1 64, u2 16, u3 40 evenly spaced (`pow3_64x16_lim_u3even_u3n40_cmin5000_as_nc11`, 66x18x40). Owner: u1 32, u2 16, u3 40 bunched toward 0, q 4 (`pow3_32x16_lim_u3p2_qn4_u3n40_cmin5000_as_nc11`, 34x18x40x5). Step 16, c_min 5,000, active-set; the two side by side. No code change.
Expectations: each confirming grid lies close to the finest u3 run in retirement (saving, old-age consumption, bankruptcy) and close to the finest u1 run when young, and moves past each of them a little where the axes add up. Renter: peak liquid saving above 4.2 (u3 80) and about 4.5-4.7 times entry income; bankrupt by 85 under 2.5%. Owner: peak saving above 4.35 (u3 40) and about 4.5-4.8; bankrupt by 85 about 7-7.5%. Rough solve times: renter about 70 minutes, owner about 130.
Checks run: none (no code changed).
Commit: this entry, pushed to main.
Open: the runs.

### 2026-10-25 Owner grid, one axis at a time: results (spec: none, asked by Quinn in Claude Code)
Follows the expectations entry below (ab04d48). Ran the eight solves, two at a time (axis_o1: base, all doubled; axis_o2: u1 32, u2 32, q 8, u1 64, u2 64, q 16), then `axis_study_page('owner')` (it now reads the reused interior-point u3 runs). Output (gitignored): `summary_step16/16_cmin5000_owner_axis_study.png`.
The base with active-set matches the interior-point base of 24 October (bankrupt household-years 9.13% against 9.13%, entry value 0.2542 against 0.2542).
Against the base (bunched 16x16, u3 at 10 bunched, q at 4; 13 min): peak mean liquid saving / bankrupt by 85 / median consumption at 30 / at 70, and solve minutes:
- u1 32: +3.2% / -0.7 points / -8.0% / +0.5%, 25 min. u1 64: +4.6% / -1.1 / -11.0% / +0.6%, 60 min.
- u2 32: +0.7% / -0.3 / +0.4% / -0.5%, 25 min. u2 64: +0.6% / -0.4 / +0.4% / -0.6%, 58 min.
- u3 20: +33.1% / -5.0 / -4.4% / -5.6%, 43 min. u3 40: +59.7% / -6.3 / -6.8% / -8.4%, 100 min (both interior-point, 24 October). u3 80: +68.8% / -6.5 / -7.5% / -8.9%, 151 min.
- q 8: -1.8% / -0.2 / +0.1% / -0.2%, 23 min. q 16: -2.5% / -0.2 / +0.5% / -0.3%, 46 min.
- All doubled (u1 32, u2 32, u3 20, q 8): +43.0% / -6.6 / -14.8% / -4.2%, 150 min; the single doublings add up to +35.2% / -6.2 / -11.9% / -5.8%.
Results: as for renters, u2 changes nothing; q changes nothing either (4 points are enough with the floor). u3 dominates: saving in retirement, old-age consumption and bankruptcy, and the retirement equity share (0.85 at 10 points, 0.6-0.75 at 40-80); it settles between 40 and 80 points (40 to 80: saving +6%, bankrupt by 85 -0.2 points, consumption at 70 -0.5%). u1 moves young consumption and is still moving at 64 (-3% at 30 from 32 to 64). All doubled moves saving and young consumption somewhat more than the sum of the single doublings.
Against the expectations: u3 most, u1 young, q enough at 4: as expected; u2 does nothing for owners too (expected a little more than for renters).
Checks run: none (no code in `+solver`, `+config`, `+ladder` or `+model` changed).
Commit: this entry with `axis_study_page.m`, pushed to main.
Open: the production grid per tenure (u2 at 16, q at 4; u1 32-64; u3 40-80), one solve on it per tenure to confirm, then `config.params` (one grid for both tenures today).

### 2026-10-25 Owner grid, one axis at a time; expectations before the runs (spec: none, asked by Quinn in Claude Code)
Quinn: run the owner one-axis study (u1, u2, u3, q each doubled alone, plus all doubled), two at a time, reusing the interior-point u3 runs.
Base: step 16 owner, maintenance on the current value, c_min 5,000, bunched u1 and u2 at 16, u3 at 10 bunched toward 0 (power 2), q at 4, gh_n 5, active-set with N_c 11 (`pow3_16x16_lim_u3p2_qn4_cmin5000_as_nc11`). New solves with `solve_cases`, all with `_as_nc11`: the base; u1 at 32 and 64 (`pow3_32x16_...`, `pow3_64x16_...`); u2 at 32 and 64; q at 8 and 16 (`_qn8`, `_qn16`); all doubled (`pow3_32x32_lim_u3p2_qn8_u3n20_cmin5000_as_nc11`). Reused: u3 at 20 and 40 (interior-point, 24 October) and u3 at 80 (active-set). No code change.
Expectations: u3 moves the owner life cycle most (24 October: peak saving 2.7, 3.6, 4.3 times entry income and bankrupt by 100 49, 45, 37% at 10, 20, 40 points; 80 close to 40); u1 moves young consumption, as for renters; u2 moves little, though more than for renters because owners hold the house in u2; q at 4 is enough (it matched 8 on 18 October without the floor); all doubled is close to the sum of the single doublings.
Checks run: none (no code changed).
Commit: this entry, pushed to main.
Open: the runs.

### 2026-10-25 Renter grid, one axis at a time: results (spec: none, asked by Quinn in Claude Code)
Follows the expectations entry below (ad3cfcb). Ran the six solves, two at a time (axis_r1: u1 32, u2 32, u3 80; axis_r2: u1 64, u2 64, all doubled), then the new `diagnostics/nibud/axis_study_page.m` ('renter'). Output (gitignored): `summary_step16/16_cmin5000_renter_axis_study.png`. Also new and committed: `diagnostics/nibud/production_tenure_page.m` (every grid of a tenure as life cycles, 24 October).
Against the base (bunched 16x16, u3 at 10 evenly spaced; 5 min): peak mean liquid saving / bankrupt by 85 / median consumption at 30 / at 70, and solve minutes:
- u1 32: +6.9% / -0.8 points / -8.8% / +1.0%, 9 min. u1 64: +9.3% / -1.1 / -11.8% / +1.3%, 17 min.
- u2 32: +0.4% / -0.1 / -0.4% / -0.3%, 9 min. u2 64: +0.3% / -0.1 / -0.4% / -0.5%, 17 min.
- u3 20: +10.0% / -2.4 / -4.8% / +1.0%, 16 min. u3 40: +16.7% / -3.7 / -7.5% / +1.9%, 32 min. u3 80: +19.6% / -3.9 / -8.5% / +2.4%, 38 min. (u3 20 and 40 were solved on 24 October three at a time.)
- All doubled (u1 32, u2 32, u3 20): +20.1% / -3.5 / -17.0% / +2.1%, 32 min; the single doublings add up to +17.3% / -3.3 / -14.0% / +1.7%.
Results: u2 changes nothing (16 points are enough for renters). u3 moves saving and old-age bankruptcy most, and settles between 40 and 80 points. u1 moves young consumption and the young equity share and is still moving at 64 (-3% in consumption at 30 from 32 to 64). The axes add up roughly, a little more than additively for young consumption. So the 24 October candidate (32x32, u3 40) spent half its points on u2.
Against the expectations: u1 against u2 as expected, more starkly (u2 does nothing); u3 as expected; all doubled moved a little more than the sum, not much more.
Checks run: none (no code in `+solver`, `+config`, `+ladder` or `+model` changed).
Commit: this entry with the two scripts, pushed to main.
Open: the owner one-axis study (u1, u2, u3, q) waits for Quinn; the renter production grid.

### 2026-10-25 Renter grid, one axis at a time; expectations before the runs (spec: none, asked by Quinn in Claude Code)
Quinn: u1 and u2 were always refined together (square grids) while u3 was refined alone and q hardly at all, so it is not known which axis matters most. Run each axis doubled on its own from one base, plus all doubled at once; renters first, owners after Quinn has seen the renter results.
Base: step 16 renter, c_min 5,000, bunched u1 and u2 at 16 points, 10 evenly spaced u3 points, gh_n 5, sweep then active-set with N_c 11 (`pow3_16x16_lim_u3even_u3n10_cmin5000_as_nc11`, solved on branch edge-fix with the fill off, which is bit-identical to main; file copied into the main checkout). Runs with `solve_cases`, two processes at a time: u1 at 32 and 64 (`pow3_32x16_...`, `pow3_64x16_...`), u2 at 32 and 64 (`pow3_16x32_...`, `pow3_16x64_...`), u3 at 80 evenly spaced (u3 at 20 and 40 evenly spaced exist from 24 October), and all doubled (`pow3_32x32_lim_u3even_u3n20_cmin5000_as_nc11`). No code change.
Expectations: doubling u1 moves the life cycle more than doubling u2 (at the pension steps on 16 October, 64x32 matched 48x48); each u3 doubling keeps raising saving and lowering bankruptcy, by less each time; all doubled moves the life cycle by more than the single-axis moves added up (the candidate grid on 24 October did).
Checks run: none (no code changed).
Commit: this entry, pushed to main.
Open: the runs.

### 2026-10-25 The edge fix tested on branch edge-fix and rejected (spec: none, asked by Quinn in Claude Code)
A separate session built `abs_fill` (grid points below the floor filled from the solvent side, for the continuation and the stored policies) on branch edge-fix (e0e3d36 code, 6fbe6c3 results, af6b0fe rejection; pushed, not merged). With 'nearest', the renter 16x16 grids at u3 10, 20 and 40 moved away from 32x32 with u3 at 40 instead of toward it (bankrupt by 85: 11.9, 8.8, 9.8% with the fill against 6.4, 4.0, 2.7% without and 1.8% on 32x32); on 32x32 it changed consumption by about 1%. Quinn rejected the fill (25 October): it does not improve the results. The cause of the slow convergence at c_min 5,000 is open. Main is unchanged; the record is the branch's HANDOFF and CALIBRATION.
Checks run: on the branch, full `run_tests` 0 of 24 failed (with the fill off it is bit-identical to 448c0a3).
Commit: this entry, pushed to main.
Open: none for the fill.

### 2026-10-24 Production at c_min 5,000: results so far, and the search routine decided (spec: none, asked by Quinn in Claude Code)
Follows the expectations entry below (5b4b5f0). All runs: step 16, owners with maintenance on the current value (checked in every saved owner file, Quinn asked), absorbing floor at EUR 5,000, exact bankruptcy test on.
Quinn's decision: production uses the sweep followed by active-set, with the sweep's second round widened (N_c 11). Interior-point stays an option and the robustness check (`ladder.robustness` already swaps to it when active-set is the default).
Changed: `+config/params.m` (`fmincon_algorithm = 'active-set'`, `N_c = 11`); CALIBRATION.md, Numerics (the two rows, with the evidence); `docs/SOLVER_BOUNDS.md` sections 2 and 6 decided; TODO.md, the interior-point against active-set item closed and the sweep kept; README.md names the default; `tests/run_tests.m`, `floor_off_identical` pins its baseline's routine (interior-point, N_c 41); `case_params` takes `_ip`. New diagnostics: `diagnostics/nibud/production_grid.m` (gaps by axis), `diagnostics/nibud/production_lifecycles.m` (the study as life cycles, and the runtime table), `diagnostics/pension_grid/optimiser_figure.m`, `diagnostics/pension_grid/sweep_lifecycles.m` (saved step-13 solves with and without the sweep).
Trap: every saved ladder result and every case solved before this commit without a routine suffix was made with interior-point and N_c 41. The same names now build active-set, so `solve_cases` would re-solve them under the same file names; reproduce them with `_ip_nc41`.
Output (gitignored), `summary_step16/`: `16_cmin5000_life_density.png`, `_life_u3.png`, `_life_quadrature.png`, `_life_search.png`, `_life_production.png` (Quinn reads these: life cycles by age, one line per run), `16_cmin5000_grid_lifecycles.png`; also `16_cmin5000_grid_gaps.png` and `16_cmin5000_optimiser_step.png`. `pension_grid/13_sweep_lifecycles.png`, `13_sweep_differences.png`.
Search routine (one-step test from the same next-year value at 30-90, owner 24x24 and renter 32x32; then full solves):
- The sweep is needed: without it 1-10% of grid points settle on the wrong peak (largest shortfall 25-92% in certainty-equivalent terms) and the households' mean equity share moves by about 0.04 at 66 and 90. sqp settles for less at up to a third of the grid points at 66 (consumption at the households off by up to 0.9%).
- Sweep with active-set and N_c 11 against sweep with interior-point, full solves: consumption within 0.05% and equity share within 0.012 through 95 at the same households; bankruptcy and entry value the same; owner 24x24 27 min against 44, renter 32x32 16 against 28. Grid points settling for a worse choice than another routine found: owner 1.2% against 1.7%, renter 0.3% against 0.5%.
- Saved step-13 solves (no floor, maintenance on the purchase price): without the sweep the life cycles match within 0.3% in consumption, except the young owners' equity share (0.65 against 0.82-1.0 at 26-29), in half the time.
Grid, one axis at a time from bunched 16x16 (policies at the reference's households, consumption % / equity share by band 26-39, 40-54, 55-66, 67-89, 90-95):
- u1 x u2. Renter 32x32 against 48x48: 4.6/0.163, 0.7/0.002, 0.3/0.011, 0.1/0.014, 0.1/0.016 (passes from 40). Owner 24x24 against 32x32: 3.0/0.067, 1.8/0.017, 0.5/0.044, 0.2/0.042, 0.1/0.020.
- u3 (bunched toward 0). Renter 40 against 80: 1.9/0.043, 1.8/0.004, 0.9/0.003, 0.6/0.003, 0.2/0.006; 40 evenly spaced against 80 bunched: 0.9/0.029, 0.9/0.003, 0.5/0.003, 0.4/0.005, 0.3/0.007. Owner 20 against 40: 4.5/0.052, 5.5/0.016, 6.3/0.042, 6.5/0.007, 5.1/0.012, a level shift at every age; peak liquid saving 2.7, 3.6, 4.3 times entry income at 10, 20, 40 points; bankrupt by 100 48.9, 45.3, 37.2%. Owner 20 evenly spaced is worse than 20 bunched (bankrupt household-years 7.6% against 6.6%): old owners sit at u3 0.04-0.2.
- Quadrature, gh_n 5 against 7: consumption within 0.4% for both tenures.
- Today's production numerics (uniform 20x20, u3 12, q 8, pi 1 where nothing is saved) against the finest grid: owner 11.7/0.474, 9.8/0.034, 5.9/0.241, 8.3/0.416, 14.4/0.156; renter 14.8/0.130, 3.1/0.010, 3.8/0.046, 1.3/0.048, 0.5/0.029.
- Before 40 nothing converges, and the equity share before 40 is not pinned down by any grid, quadrature or routine (0.1-0.2). The entry value moves 4-13% per refinement.
- Bankrupt at 40 / 67 / 100: owner 0.37 / 4.05 / 48.9% (16x16), 0.21 / 2.89 / 48.7% (32x32), 0.30 / 3.17 / 37.2% (u3 40); renter 0 / 2.02 / 17.2% (16x16), 0 / 0.89 / 16.8% (48x48), 0 / 0.72 / 14.8% (u3 80). Off-grid lookups 0 in every solve.
- Why u3 converges slowly (gaps fall about 1.6-1.8 times per doubling): grid points below the floor hold the bankrupt value and solvent states next to them interpolate across that jump. Share of solvent renters at 90 in a cell with a bankrupt corner: 19.9% at 10 u3 points, 0.8% at 40, 0.2% at 80 (owners at 30-50: 2-5% on 16x16). Proposed, not built: fill those grid points from their solvent neighbours and let the exact test decide bankruptcy.
Solve minutes (two processes side by side, three for the evenly spaced renter runs): owner 16x16 22, 24x24 44, 32x32 80, u3 20 43, u3 40 100, gh 7 41, production numerics 76; renter 16x16 8, 32x32 28, 48x48 61, u3 20 15, u3 40 30, u3 80 69, gh 7 15, production numerics 15.
Against the expectations: bankruptcy as expected; renter grid as expected from 40; owner u3 worse than expected (20 against 40 not half of 10 against 20); routines as expected; production numerics worse than expected for owners.
Checks run: `run_tests(solve=false)` 0 of 11 failed. The full `run_tests` was not run (Quinn: the fast check only), so `floor_off_identical` with the pinned routine is untested.
Commit: this entry with the code, pushed to main.
Open: owner u3 at 80 and the renter candidate (32x32, 40 evenly spaced u3 points, active-set) still running; the owner grid; the maintenance rule for owners; the interpolation fix at the bankruptcy edge; adopting c_min 5,000 and the production grid.

### 2026-10-24 Production at c_min 5,000: which grid and which search routine; expectations before the runs (spec: none, asked by Quinn in Claude Code)
Quinn: run the full code with the consumption floor at 5,000 euros; find the grid size production needs and the optimiser routine.
Changed: `diagnostics/pension_grid/case_params.m` takes `_as`, `_sqp` (fmincon algorithm), `_util` (objective in utility units) and `_nc<n>` (N_c; `_nc11` starts the sweep's later rounds at the first round's half-step in consumption, docs/SOLVER_BOUNDS.md section 2). New `diagnostics/pension_grid/optimiser_step.m`: one Bellman step solved once per routine from the same next-year value and warm start; each node's value against the best of all routines, in certainty-equivalent units, and each routine's policies at the simulated households. No change to `+solver`, `+config`, `+ladder` or `+model`; production stays at c_min 0.
Runs, step 16, maintenance on the current value, all `_cmin5000` with the exact test, two processes side by side. One axis at a time:
1. Owner (q at 4): bunched 16x16, 24x24, 32x32 (u1 x u2); 16x16 with u3 at 20 and 40 (u3); 16x16 with gh_n 7 (quadrature).
2. Renter: bunched 16x16, 32x32, 48x48; 16x16 with u3 at 20 and 40; 16x16 with gh_n 7.
3. Both tenures on the production numerics as they are, `uniform_20x20_u3n12` (config.params with c_min 5,000; checked equal by `ladder.same_calibration`).
4. `optimiser_step` on owner 24x24 and renter 32x32 at ages 30, 40, 50, 60, 66, 70, 80, 90: default (sweep, interior-point, 'ce'), `_as`, `_sqp`, `_util`, `_nosweep`, `_nc11`. Then full solves for the routines that matter.
Expectations, written before the runs:
- Bankruptcy between the 4,000 and 6,000 runs: owner about 0.4 / 4 / 49% bankrupt at 40 / 67 / 100, renter about 0 / 1 / 17%.
- Consumption: closer to ruin than at 8,000, so slightly larger grid gaps than at 8,000, but within 2-3% from 40 for owner 24x24 against 32x32 and renter 32x32 against 48x48. Owner u3 10 against 20 as at 8,000 (5-8%); 20 against 40 about half that.
- The equity share does not meet 0.02 between grids. In the one-step test, the routines with the sweep reach the same value to 1e-6 at almost every node, yet their equity shares differ by more than 0.05 at some of those nodes: the share is flat there and not pinned down by any search. Without the sweep the value is short by more than 1e-4 at a few per cent of retirement nodes. Active-set faster than interior-point.
- The production numerics (uniform, pi 1 where nothing is saved) are off by more than the stop rule for owners in working life.
Checks run: `run_tests(solve=false)` 0 of 11 failed. `case_params` builds the production calibration with c_min 5,000 for both tenures (`ladder.same_calibration` 1, nodes 22x22x12x9 owner, 22x22x12 renter). Smoke test of `optimiser_step` on the saved renter summary solve at 8,000, age 70: the default routine reproduces the solved step bit for bit.
Commit: this entry with the two scripts, pushed to main.
Open: the runs.

### 2026-10-24 The absorbing floor documented (spec: none, asked by Quinn in Claude Code)
Quinn: document what we did.
Changed: new `docs/HANDOFF_2026-10-24.md`, in the form of the 17 October one: the figures in the order to read them; what was built and Quinn's decisions; what was found (behaviour, cumulative bankruptcy by floor level, owner bankruptcy as illiquidity, net income after housing, the numerical behaviour, the bugs looked for, run time); decisions open; what can be quoted; how to reproduce, with two traps; where things are, with the commits. `docs/prompts/absorbing_floor.md`: marked implemented, pointing to it. CLAUDE.md: a known limit for the absorbing floor; the note on small grids corrected (`CGM_STATE_GRID` does not reach `ladder.params` or `config.derive`; set `p.grid_dims` and `p.gh_n` instead).
Checks run: `run_tests(solve=false)` 0 of 11 failed. No code changed.
Commit: this entry with the three documents, pushed to main.
Open: as in `docs/HANDOFF_2026-10-24.md`, section 4.

### 2026-10-24 The exact bankruptcy test on by default (spec: 2026-10-23 The consumption floor as an absorbing state, linked to labour income)
Quinn: set `abs_node_test = true` by default (it only acts with the absorbing floor); asked what it costs in run time.
Changed: `+config/params.m`, `abs_node_test` true. CALIBRATION.md, Numerics: the value and why. `tests/run_tests.m`, `floor_node_test` checks the default and compares against the test switched off. `case_params` takes `_interp` for the old setting; the `_cmin` solves of 23 October without `_exact` were made with the test off, and the same names now build it on, so `solve_cases` would re-solve them (reproduce them with `_interp`). With `c_min = 0` in production nothing changes (`floor_off_identical`).
Run time, measured in one MATLAB process on an idle machine, step 16, c_min 8,000, gh_n 5, the same solve off then on: renter 14x14x8 213.6 s -> 227.8 s (+6.6%); owner 12x12x6x5 (on first) 338.9 s -> 351.2 s (+3.6%). The solve times in the grid-set entries are not comparable, since those runs shared the machine.
Checks run: `run_tests(solve=false)` 0 of 11 failed; full `run_tests` with CGM_FLOOR_BASELINE 0 of 21 failed, 0 skipped (floor_off_identical 157 s, floor_node_test 200 s).
Commit: this entry with the code, pushed to main.
Open: none for this change.

### 2026-10-24 The absorbing floor: results with the exact trigger at the quadrature nodes (spec: 2026-10-23 The consumption floor as an absorbing state, linked to labour income)
Follows the expectations entry below (a55a951).
Ran: `solve_cases` on the eight grid cases with `_cmin8000_exact` (two processes side by side, 777-7,442 s), `absorbing_grid(8000, extra = '_exact')`, and `ruin_interp(16, 'owner', {'pow3_24x24_lim_u3p2_qn4', 'pow3_24x24_lim_u3p2_qn4_cmin8000', 'pow3_24x24_lim_u3p2_qn4_cmin8000_exact'})`.
Output (gitignored), `summary_step16/`: `16_absorbing_grid_gaps_exact.png`, `16_absorbing_<arm>_grid_ladder_exact.png`, `16_absorbing_<arm>_grids_exact.png`, `16_absorbing_ruin_interp_exact.png` (copy of `pension_grid/ruin_interp_16_nibud_owner_union.png`, now the three cases).
`model.checks`, without -> with the test: off-grid 0 everywhere. Entry value: owner 16x16 0.288 -> 0.285, 24x24 0.274 -> 0.271, 32x32 0.263 -> 0.261, u3 at 20 0.261 -> 0.259; renter 16x16 0.289 -> 0.288, 32x32 0.275 -> 0.275, 48x48 0.266 -> 0.266, u3 at 40 0.281 -> 0.281. Bankrupt household-years: owner 13.8 -> 13.6, 12.9 -> 12.7, 12.4 -> 12.0, 10.8 -> 10.6%; renter 5.10 -> 5.11, 5.64 -> 5.68, 5.53 -> 5.54, 4.32 -> 4.29%.
Results:
- The entry value drifts with the grid as much as before (owner -4.8% from 16x16 to 24x24, -3.8% from 24x24 to 32x32), so that drift does not come from the jump at the edge of bankruptcy.
- Ruin corner, owner 24x24, largest gap at 45 / 60 / 70 / 85 / 90: 7.9 / 0.9 / 0 / 14.0 / 104% without, 7.2 / 0.9 / 0 / 11.7 / 86% with; `corner_u3` at 90 140% -> 102%; medians unchanged, under 1%. The rest of the error is on the solvent side, along u3 for old owners with almost no pot.
- Grid test, consumption % / mean liquid equity share, bands 26-39, 40-54, 55-66, 67-89, 90-95: consumption gaps move by at most 0.6 points; the equity-share gaps after 67 fall: owner 16x16 against 32x32 0.101 -> 0.042 and 0.138 -> 0.096, 24x24 against 32x32 0.050 -> 0.048 and 0.029 -> 0.031; renter 32x32 against 48x48 0.033 -> 0.013 and 0.054 -> 0.039, summary against 48x48 0.093 -> 0.052 and 0.064 -> 0.042. Renter 32x32 against 48x48 now passes the stop rule from 40 to 89 (0.7/0.004, 0.4/0.012, 0.2/0.013).
Against the expectations: bankruptcy as expected; the entry value's drift did not shrink; the corner's largest gap fell by a fifth, not to a few percent; the old-age equity-share gaps did shrink.
Checks run: none new (no code changed since a55a951; `run_tests` 0 of 21 there).
Commit: this entry, pushed to main.
Open: whether `abs_node_test` should be on whenever the absorbing floor is; the u3 axis for old owners.

### 2026-10-23 The absorbing floor: exact trigger at the quadrature nodes; expectations (spec: 2026-10-23 The consumption floor as an absorbing state, linked to labour income)
Quinn: agreed to fix the jump at the edge of bankruptcy (the prompt's "exact trigger at the quadrature nodes"). On the policy stored at bankrupt nodes, Quinn asked why not plot conditional on not being bankrupt; the plotted shares already are, and the leak is into solvent households next to bankrupt nodes (re-simulated, stored policy against nearest solvent node, owner 32x32 share at 95: 0.999 -> 0.876 over the solvent, 0.976 -> 0.970 over households saving at least 1% of entry income). Quinn does not want the plots weighted by saving; a weighted share was added and taken out again before any commit. The plots and the stored policy stay as they are.
Changed: new primitive `abs_node_test` (false; with the absorbing floor, true tests every quadrature node against next year's floor and takes the bankrupt value there, in `bellman_rhs` and the sweep, with next year's take-home income, net annuity and housing cost per q node); `absorbing_grid` takes `extra = '_exact'`; `case_params` takes `_exact`; CALIBRATION.md, Numerics. New test `floor_node_test`.
Runs: the grid set of 23 Oct at c_min 8,000 with `_exact`: owner summary 16x16, 24x24 (q 4), 32x32, 24x24 with u3 at 20; renter summary 16x16 (u3 20), 32x32, 48x48, 16x16 with u3 at 40. Then `absorbing_grid(8000, extra = '_exact')` and `ruin_interp` on owner 24x24 with and without.
Expectations: bankruptcy shares within a point of the runs without the test (the trigger itself was already exact at the grid nodes); the entry value drifts less across grids than 0.288 / 0.274 / 0.263 (owner) and 0.289 / 0.275 / 0.266 (renter); the corner's largest gap at 85-90 (14% and 104-140%) falls to a few percent; consumption gaps between grids shrink further; the equity share is not expected to converge.
Checks run: `run_tests(solve=false)` 0 of 11 failed; full `run_tests` with CGM_FLOOR_BASELINE 0 of 21 failed, 0 skipped (floor_node_test 199 s).
Commit: this entry with the code, pushed to main.
Open: the runs.

### 2026-10-23 The absorbing floor: two checks for bugs (spec: none, asked by Quinn in Claude Code)
Quinn: are there numerical problems or bugs? Two checks without new solves, on the saved c_min 8,000 solves (scripts in the session's scratchpad, not committed).
1. Owner trigger. At every node of the owner summary grid, both maintenance rules, liquid resources from the owner budget written out independently (q-dependent maintenance and annuity payment, the annuity payout in retirement) against the nodes the solver valued at the closed form: 0 mismatches over 80,006 and 93,556 node-years below the floor (the renter is covered by `run_tests`, `floor_absorbing`).
2. Policy leakage. The solver stores c = 1 and pi = 1 at bankrupt nodes, and solvent households next to them read interpolated policies. Re-simulated with those nodes' policies replaced by the nearest solvent node (along u2, then u1), same households and seed. Bankruptcy, consumption and saving barely move: owner 16x16 bankrupt at 67 8.7% -> 7.8%, at 85 23.2% -> 21.5%; owner 32x32 6.1% -> 6.0% and 21.7% -> 21.5%; renters unchanged to 0.1 point. The old-age liquid equity share does move: owner 32x32 0.999 -> 0.876 at 95 and 0.893 -> 0.876 at 85; renter 48x48 0.833 -> 0.799 at 85. Those households hold almost no liquid saving (mean 0.006 of entry income at 95), so the effect is on the plotted share, not on wealth, but it is part of the larger equity-share gaps after 67 in the grid test.
Checks run: none in the repo (no code changed).
Commit: this entry, pushed to main.
Open: whether to store a solvent neighbour's policy (or the limit share) at bankrupt nodes; the exact trigger at the quadrature nodes (prompt, "Later, if needed").

### 2026-10-23 Net income figure: the bottom row redrawn (spec: none, asked by Quinn in Claude Code)
Quinn: the second row of `16_net_income_distribution.png` needs work. It showed two shares on a fixed 0-100% axis, nearly flat at the bottom and empty for the purchase-price owner.
Changed: `diagnostics/nibud/absorbing_income.m`. The bottom row now stacks every household's net income after housing over its own floor phi_t Y_t (below zero, 0-1, 1-2, 2-4, over 4 times) by age, with the share bankrupt by that age under the absorbing floor as a line, and one legend below the row. No new solve.
What it shows (c_min 8,000): at 25 every household is at 1-2 times its floor. Owners on the current value: the share below its floor rises from about 10% at 70 to about half at 100, most of it below zero, and the share bankrupt follows it from 80 on. Owners on the purchase price: no one below the floor after the mortgage ends at 54. Renters: below the floor rises to about a quarter at 100, with the bankrupt share just under it.
Checks run: `run_tests(solve=false)` 0 of 11 failed.
Commit: this entry with the script, pushed to main.
Open: none for the figure.

### 2026-10-23 The absorbing floor: net income after housing, and the grids (spec: none, asked by Quinn in Claude Code)
Quinn: plot the distribution of net income after housing costs by age; the net income of households that go bankrupt against the floor; and the grids and what they change.
No new solve. New `diagnostics/nibud/absorbing_income.m`; `diagnostics/nibud/absorbing_grid.m` draws a page per tenure with the grids. Net income after housing (`sim.disp_inc`) depends on no choice, so it is read from the top-up panel, which draws the same shocks; the script checks that the two panels agree in every solvent year (they do, to 1e-9 relative).
Output (gitignored), `summary_step16/`: `16_net_income_distribution.png`, `16_net_income_bankrupt.png`, `16_absorbing_owner_grids.png`, `16_absorbing_renter_grids.png`.
Results, c_min 8,000, thousand euros of 2025:
- Net income after housing, p10 / median / p90: owner, current value 10.5 / 19.8 / 32.8 at 35, 5.4 / 25.2 / 54.3 at 75, -23.5 / 12.0 / 42.3 at 95; owner, purchase price 20.6 / 37.7 / 67.7 from 67 (flat); renter 9.8 / 16.9 / 27.0 at 35, 3.8 / 14.9 / 34.5 at 75, 1.2 / 12.4 / 32.1 at 95. Below the household's own floor at 95: 42% (owner, current value), 0 (owner, purchase price), 20% (renter); below zero: up to 38% of owners on the current value at 100.
- Households that go bankrupt: in the year of bankruptcy net income after housing is below the floor for all of them (it must be, with liquid wealth near zero), median 0.63 of the floor (owner, current value), 0.77 (purchase price), 0.76 (renter); below zero for 16%, 1% and 15%. Owners on the current value: median net income 15.4 ten years before, 6.4 the year before, 3.8 in the year, against a floor of about 7; liquid wealth 24.3, 1.1, 0.2. Renters: net income 4.2, 2.8, 2.6 against a floor of 3.7; liquid wealth 28, 1.7, 0.2. Households run their savings down and fall through once net income no longer covers the floor. Renters who go bankrupt have low incomes all their life (median net income about 12 at 30-45, against about 15 at 30 and 21 at 45 for the rest, read off the figure), so their floor in euros is low too (3.7).
- Grids: the top row shows each grid's nodes on u1 (as W/Y), u2 and u3 against the 5th-95th percentile of solvent households at 30, 45, 65 and 85; the bottom row the four grids by age with both floors. With the floor the grids' consumption, saving and bankruptcy lines nearly coincide; with the top-up they spread, most with u3 at 20 points (owner saving 25 times entry income at 70). Solve times on these pages are not comparable across floors: the runs shared the machine with up to three others.
Checks run: `run_tests(solve=false)` 0 of 11 failed. No code in `+config`, `+ladder`, `+model` or `+solver` changed.
Commit: this entry with the two scripts, pushed to main.
Open: as in the entry below.

### 2026-10-23 The absorbing floor: runs 3-4, grid test and ruin corner at c_min 8,000 (spec: 2026-10-23 The consumption floor as an absorbing state, linked to labour income)
Ran: `solve_cases` on the 20 Oct comparison grids with `_cmin8000`: owner (maintenance on the current value) `pow3_24x24_lim_u3p2_qn4`, `pow3_32x32_lim_u3p2`, `pow3_24x24_lim_u3p2_qn4_u3n20`; renter `pow3_32x32_lim_u3p2`, `pow3_48x48_lim_u3p2`, `pow3_16x16_lim_u3p2_u3n40` (1,686-10,692 s, up to four processes side by side). Then the new `diagnostics/nibud/absorbing_grid.m`, and `ruin_interp(16, 'owner', {'pow3_24x24_lim_u3p2_qn4', 'pow3_24x24_lim_u3p2_qn4_cmin8000'})`.
Output (gitignored), `summary_step16/`: `16_absorbing_grid_gaps.png` (policy gaps by age, both floors, and each grid's median consumption), `16_absorbing_owner_grid_ladder.png`, `16_absorbing_renter_grid_ladder.png`, `16_absorbing_ruin_interp.png` (copy of `pension_grid/ruin_interp_16_nibud_owner_union.png`, which now holds this pair instead of the 18 Oct pair; the 18 Oct results are saved and redraw with their own case list).
`model.checks`: off-grid 0 everywhere. Entry value with the floor: owner 0.288 / 0.274 / 0.263 at 16x16 / 24x24 / 32x32, 0.261 with u3 at 20 (top-up 0.022 / 0.000 / 0.000 / 0.000); renter 0.289 / 0.275 / 0.266 at 16x16 / 32x32 / 48x48, 0.281 with u3 at 40 (top-up 0.174 / 0.001 / 0.000 / 0.156). Bankrupt household-years: owner 13.8 / 12.9 / 12.4%, 10.8% with u3 at 20; renter 5.1 / 5.6 / 5.5%, 4.3% with u3 at 40. Cumulative % bankrupt at 95: owner 45.8 / 45.4 / 45.1%, 39.4% with u3 at 20; renter 20.3 / 20.9 / 20.9%, 18.0% with u3 at 40.
Run 3, policies at the reference's households, consumption % / mean liquid equity share, bands 26-39, 40-54, 55-66, 67-89, 90-95 (top-up in brackets):
- Owner, 24x24 against 32x32: 2.8/0.097, 1.7/0.068, 0.6/0.055, 0.3/0.050, 0.4/0.029 (890/0.046, 70.1/0.034, 0.6/0.010, 0.7/0.006, 0.6/0.011). 16x16 against 32x32: 6.5/0.204, 4.8/0.098, 1.7/0.071, 0.6/0.101, 0.2/0.138 (53,200/0.049, 145/0.035, 1.8/0.033, 2.5/0.018, 1.7/0.024).
- Owner, u3 at 10 against 20 (24x24): 4.4/0.081, 5.0/0.043, 7.5/0.097, 8.1/0.057, 6.7/0.070 (22,549/0.565, 9,044/0.017, 497/0.087, 110/0.053, 2.3/0.004). The hoarding with 20 u3 points is gone: median consumption 0.65 at 55 and 0.68 at 80 (top-up 0.01 and 1.58); the four owner grids' median consumption paths lie within 0.05 of entry income of each other at every age.
- Renter, 32x32 against 48x48: 2.7/0.177, 0.7/0.004, 0.4/0.011, 0.1/0.033, 0.1/0.054 (1,452/0.061, 5.3/0.004, 0.2/0.009, 0.2/0.007, 0.1/0.005). Summary grid against 48x48: 7.0/0.100, 3.6/0.036, 3.7/0.029, 1.9/0.093, 0.3/0.064 (10,032/0.455, 6.2/0.003, 2.7/0.012, 0.9/0.030, 0.4/0.028). Summary grid against u3 at 40: 2.8/0.042, 2.8/0.021, 1.7/0.012, 1.6/0.030, 0.6/0.019 (11.3/0.035, 5.3/0.002, 1.9/0.003, 1.3/0.003, 0.7/0.007).
- The equity share weighted by liquid saving (each grid's own panel) is off by about as much with the floor as without: owner 24x24 against 32x32 0.087, 0.056, 0.017, 0.042, 0.044 (0.057, 0.032, 0.035, 0.040, 0.027); renter 32x32 against 48x48 0.138, 0.007, 0.006, 0.026, 0.010 (0.057, 0.002, 0.011, 0.025, 0.044).
So run 3 does not pass the stop rule from 25 on. Consumption passes from 40 on for owner 24x24 against 32x32 and for renter 32x32 against 48x48, and is within 2-8% elsewhere, against gaps of 100% to 1e5% under the top-up. The equity share passes nowhere, as under the top-up; with the floor the young hold equities (0.3-0.9 at 30-40) where under the top-up they held none, so the share now has room to differ. u3 for owners is not converged (5-8% in consumption) but no longer changes the solution's character.
Run 4, `ruin_interp`, gap of the interpolated certainty equivalent over the Bellman one, owner 24x24, ages 45 / 60 / 70 / 85 / 90, corner (u3 below 0.12, u2 = 1): median 0.7 / 0.5 / 0 / 0 / 0%, largest 7.9 / 0.9 / 0 / 14 / 104% (top-up: median 20 / 25 / 4 / 17 / 6%, largest 67 / 129 / 116,195 / 8.2e6 / 2.4e6%). Every region with the floor has a median under 1%; the largest gaps, 104-140% at 90 in `corner` and `corner_u3`, cover 2-4% of the corner's volume. The checks inside the households' band hold (nodes 2e-6 to 9e-6, inserted axis 5e-8 to 8e-6). "Near the floor" is now 100% of every region, since the bankrupt value is no longer orders of magnitude below its neighbours.
Owner bankruptcy is illiquidity, not insolvency (summary grid, c_min 8,000, panel re-simulated): of the 5,506 owners (maintenance on the current value) who go bankrupt, 99.9% hold positive home equity in the year they do, median 50.5 times entry income (10th percentile 13.2), at a median age of 88. With maintenance on the purchase price, 305 go bankrupt, at a median age of 45, 96.1% with positive equity, median 5.3. The model lets no one sell the house or borrow against it, so a bankrupt owner gives up a house worth decades of income for the floor. Equity release (TODO.md, item 1.1, and the 21 Oct "sold, renting for life" proposal) is what would change this.
Against the expectations: run 4 as expected. Run 3: the renter passes consumption from 40 on 32x32 (expected from about 30; before 40 it is 2.7%), and the owner's u3 problem did not survive in consumption, contrary to the expectation; the equity share fails for both.
Checks run: `run_tests(solve=false)` 0 of 11 failed; full `run_tests` with CGM_FLOOR_BASELINE 0 of 20 failed, 0 skipped (floor_off_identical 142 s, floor_absorbing 47 s).
Commit: this entry with `diagnostics/nibud/absorbing_grid.m` and TODO.md, pushed to main.
Open: Quinn: adopt the floor or not, the value and source of c_min, the bequest rule; the equity-share convergence, with or without the floor.

### 2026-10-23 The absorbing floor: runs 1-2, the economics at c_min 4,000-12,000 (spec: 2026-10-23 The consumption floor as an absorbing state, linked to labour income)
Quinn, during the runs: add maintenance on the purchase price (already planned), a lower and a higher floor (4,000 and 12,000 added), plots of consumption, saving, the equity share, housing cost against income and bankruptcy, and the cumulative bankruptcy rate.
Ran: `solve_cases` on 15 cases, step 16 summary grids, three or four MATLAB processes side by side (620-2,312 s each): owner `pow3_16x16_lim_u3p2_qn4_nosweep_cmin<n>` and `..._cmin<n>_mop`, renter `pow3_16x16_lim_u3p2_u3n20_cmin<n>`, n = 4,000, 6,000, 8,000, 10,000, 12,000. Then `diagnostics/nibud/absorbing_economics.m`.
Output (gitignored), `summary_step16/`: `16_absorbing_economics.png` (every arm and level by age: median consumption; mean liquid saving, liquid equity share and median housing cost over net income of the solvent; cumulative % bankrupt; one-year rate), `16_absorbing_<arm>_cmin<n>.png` (15 dashboards), `16_absorbing_<arm>_compare.png` (each arm's floors over the top-up).
`model.checks`: off-grid 0 in all 15. Entry value (top-up / 4k / 6k / 8k / 10k / 12k): owner, current value 0.022 / 0.246 / 0.267 / 0.288 / 0.306 / 0.314; owner, purchase price 0.277 / 0.318 / 0.325 / 0.337 / 0.343 / 0.328; renter 0.174 / 0.252 / 0.271 / 0.289 / 0.306 / 0.326. c-bound 25-39 0-0.1% up to 8,000, 7-10% for owners at 10,000 and 12,000, 0 for renters.
Cumulative % bankrupt at 40 / 67 / 100, of households alive at that age (the panel has no deaths; top-up: % ever floored):
- Owner, current value: top-up 0.0 / 0.2 / 36.8; 4k 0.2 / 3.3 / 47.3; 6k 0.7 / 5.3 / 50.9; 8k 2.2 / 8.7 / 55.1; 10k 6.2 / 14.0 / 60.0; 12k 59.1 / 62.3 / 81.9.
- Owner, purchase price: top-up 0.0 / 0.4 / 0.4; 4k 0.1 / 0.9 / 0.9; 6k 0.2 / 1.6 / 1.6; 8k 1.3 / 3.0 / 3.0; 10k 4.0 / 6.3 / 6.3; 12k 54.4 / 55.3 / 55.3. No bankruptcy after the mortgage ends at 54.
- Renter: top-up 0.0 / 0.1 / 7.4; 4k 0.0 / 0.7 / 14.6; 6k 0.0 / 1.5 / 18.9; 8k 0.1 / 2.7 / 24.3; 10k 0.3 / 4.6 / 31.5; 12k 1.6 / 8.4 / 40.7.
Behaviour, multiples of entry income (median consumption; mean liquid saving of the solvent):
- Young households consume more and save less: consumption at 25 0.03 -> 0.23-0.30 (owner, current value), 0.25 -> 0.26-0.30 (owner, purchase price), 0.17 -> 0.27-0.38 (renter). Liquid saving at 40: 3.84 -> 1.23-0.57 (owner, current value), 2.91 -> 2.15-1.14 (renter), falling as c_min rises.
- The liquid equity share of the young rises: owner, current value, 0.01-0.03 at 30-55 under the top-up against 0.1-0.9 with the floor; renter 0.15 at 30 against 0.52-0.98.
- At 12,000 the floor (0.30 of income at 25) sits just under the owner's cash after housing at entry (0.33): 58% of owners on the current value and 54% on the purchase price are bankrupt by 30, and median consumption is flat at the floor, 0.30, for life.
Against the expectations: 1 (off-grid 0) and 2 (entry value about 0.2 or above) held. 3 did not: young consumption rose far above the floor instead of sitting on it, c-bound 25-39 stayed at 0-0.1% to 8,000, because a bounded loss at ruin removes the motive to starve now to avoid it. 4 held for owners on the current value (55% at 100 against 15.8% floored at 95 under the top-up) and on the purchase price (3%), not for renters: 24% at 100 at 8,000 against "a few percent". Retired renters run their savings down into the floor; one-year rates 1-1.5% after 85. Run 2: bankruptcy and entry value rise with c_min, liquid saving falls, as expected; the purchase-price owner's entry value falls again at 12,000 (0.328 against 0.343).
Limits: summary grids, not converged for owners (CLAUDE.md); run 3 tests the grids with the floor.
Checks run: `run_tests(solve=false)` 0 of 11 failed (after the diagnostics change).
Commit: this entry with `diagnostics/nibud/absorbing_economics.m`, pushed to main.
Open: runs 3-4; the value of c_min (decision 3).

### 2026-10-23 The absorbing floor: Quinn's decisions, and expectations for runs 1-4 (spec: 2026-10-23 The consumption floor as an absorbing state, linked to labour income)
Quinn's answers to the prompt's open decisions: 1 (b), phi_t = c_min / Ybar_t; 2 the same share for both tenures (not the same c_min), set on the owners' profile until the pooled income cubic is in; 4 the floor is the solvent household's lowest consumption (as coded); 5 involuntary only. 3 (the value of c_min) and 6 (bequest rule) stay open. Quinn asked for all runs in one go, reported at the end, rather than a stop after each.
Changed: `+config/derive.m`: with `c_min`, phi_path = c_min / Ybar_t on the owners' profile for both tenures. Test `floor_derive` checks the share is equal across tenures. CALIBRATION.md records the decisions.
Numbers (derive, not model output): phi_t at c_min 6,000 / 8,000 / 10,000: 0.151 / 0.201 / 0.251 at 25, 0.091 / 0.121 / 0.152 at 66, 0.296 / 0.395 / 0.494 of the first pillar from 67, for both tenures. In euros the median owner's floor is c_min at every age; the median renter's is 0.757 c_min at 25 (EUR 6,055 at 8,000) and 0.750 c_min from 67. D_abs 22.32 at 25, 12.90 at 67.
Runs, on the 20 Oct summary grids, two MATLAB processes side by side, with `solve_cases`: owner `pow3_16x16_lim_u3p2_qn4_nosweep_cmin<n>` and the same with `_mop`; renter `pow3_16x16_lim_u3p2_u3n20_cmin<n>`.
Expectations, run 1 (c_min 8,000):
1. `offgrid` 0 in all three.
2. `ce_entry` about 0.2 or above in all three (bankruptcy at entry would be worth phi_25 = 0.20); today 0.022 (owner, current value), 0.277 (owner, purchase price), 0.174 (renter). The owner on the current value rises most.
3. Young consumption at least the floor: owners on the current value consumed a median 0.03-0.25 of entry income at 25-35 and renters 0.17 at 25, below 0.20, so `c_bound_25_39` rises for both, to tens of percent.
4. Bankrupt share: owner, current value, large in old age, at least the 15.8% at the floor at 95 today, since maintenance on the current value outruns the first pillar; owner, purchase price, under 2%; renter, rising from 67 to a few percent at 100 (the renter's floor is 0.75 of the owner's in euros).
Expectations, run 2 (c_min 6,000 and 10,000): bankrupt shares and `ce_entry` rise with c_min, liquid saving falls.
Expectations, run 3 (grid test at 8,000; owner against 24x24 and 32x32 with u3 at 10, and 24x24 with u3 at 20; renter against 32x32 and 48x48 with u3 at 10, and 16x16 with u3 at 40; policies at the reference's households, stop rule 2% in consumption and 0.02 in the equity share): renter within the rule from about 30 (today from 55); owner much closer than today before 55 (today 70-145% off at 40-54), but the u3 problem (hoarding into retirement with 20 u3 points) may survive, since it comes from the housing outflow and not the floor.
Expectations, run 4 (`ruin_interp`, owner 24x24 q 4 at 8,000 against the same grid without the floor): the corner's gap falls from 1e4-1e6% to tens of percent at most.
Checks run: `run_tests(solve=false)` 0 of 11 failed after the change; full `run_tests` (with CGM_FLOOR_BASELINE) 0 of 20 failed.
Commit: 7dba69a, pushed to main.
Open: the runs.

### 2026-10-23 The absorbing floor: code and tests (spec: 2026-10-23 The consumption floor as an absorbing state, linked to labour income)
Changed: `+config/params.m` (`c_min`, `phi_abs`, both 0 = off); `+config/derive.m` (`phi_path`, `D_abs`, `floor_absorbing`; refusals `derive:floor_negative`, `floor_both`, `poly_cmin`, `floor_low`); `+solver/bellman_step_lna.m` (floor from `phi_path(t)`; bankrupt nodes valued at u(F) D_t, no continuation or bequest, c = 1, pi = 1; terminal period likewise); `+simulate/paths_lna.m` (`absorbed`, `abs_age`; consumption fixed at entry; X, A, H zero after; c_frac and pi NaN; no bequest; solvent households consume at least the floor; bankrupt households not counted off the grid; old results without `phi_path` still re-simulate with phi_floor); `+model/summarize.m` (wealth, housing, shares and c_frac over solvent households, `abs_hazard`); `+model/checks.m` and `print_checks.m` (`abs_share` at 40, 67, 100; `abs_hazard_5y`; `ce_entry` from `D_abs(1)`); new `+model/floor_kind.m`; figures and `+ladder/compare.m`, `report.m` read "bankrupt"; `case_params` takes `_cmin<n>`; CALIBRATION.md, README.md, docs/SOLVER_BOUNDS.md.
Baseline for the bit-identical test: step 16, both tenures, `grid_dims [8 6 6 4]`, `gh_n 3`, N 500, solved at 47e3af2 (code = 7b5143d) before any edit; kept outside the repo at `C:\Users\Quinn\Desktop\claudecodetest\floor_baseline_7b5143d.mat`, read through `CGM_FLOOR_BASELINE`. Renter 50 s, owner 99 s. Note: `CGM_STATE_GRID` and `CGM_GH_N` reach only `ladder.numerics` and `run_model`, not `ladder.params` plus `config.derive`, so the small grid has to be set on `p` (a first attempt through the environment solved the production grid and was stopped).
Checks run: `run_tests(solve=false)` 0 of 11 failed. `matlab -batch "setenv('CGM_FLOOR_BASELINE', ...); addpath tests; run_tests"`: 0 of 20 checks failed, 0 skipped (floor_derive 0.0 s, floor_off_identical 140 s, floor_absorbing 45 s).
Commit: faf47f5, pushed to main.
Open: Quinn's open decisions 1-6 of the prompt; then the runs, each with an expectation first.

### 2026-10-23 Prompt for the absorbing floor linked to labour income, saved as a handover, not started (spec: none, asked by Quinn in Claude Code)
Quinn: a prompt for this as a handover.
Changed: `docs/prompts/absorbing_floor.md` rewritten as one clean prompt; the exploration of 22 Oct is in git (39c869c to 031e081) and the entries below. Contents: start instructions; the decisions taken (absorbing for life, level fixed at bankruptcy, no new state, linked to labour income); six open decisions with defaults ((b) phi_t = c_min / Ybar_t, the same c_min for both tenures, c_min from Nibud, the floor as the search bound, involuntary trigger, the bequest rule for later); the model with V~^B_t = (phi_t u1)^(1-gamma)/(1-gamma) D_t; the code changes file by file (primitives `c_min` and `phi_abs`, derived `phi_path` and `D_abs`); six new tests, including bit-identical to 7b5143d with the floor off; five runs with expectations on the 20 Oct summary grids; the exact node test for later; the Dutch policy background with sources.
Numbers, by hand (Python, from config.params): cash after housing at entry EUR 13,003 owners, 12,641 renters; phi_25 at c_min 6,000 / 8,000 / 10,000: 0.151 / 0.201 / 0.251 owners, 0.199 / 0.266 / 0.332 renters; the median renter's rent at 67 about EUR 10,500 against a net first pillar of EUR 9,382.
Checks run: none. No code changed.
Commit: this entry with `docs/prompts/absorbing_floor.md`, pushed to claude/dreamy-edison-1814gg (not main: this session may push only to that branch).
Open: bring the prompt onto main; Quinn's open decisions 1-5; then the implementation.

### 2026-10-22 The absorbing floor linked to labour income (spec: none, asked by Quinn in Claude Code)
Quinn: the rent-index and purchase-price floors are not defensible in a paper; link the floor to labour income. No new state variable.
Changed: `docs/prompts/absorbing_floor.md`: the decision recorded; options 2 and 3 without a state dropped. New "The labour-income floor": F_t = phi_t Y^L_t, with Y^L_t labour income in working life and final labour income (Y_t / 0.307) in retirement; after bankruptcy Cbar = F_{t*} for life, V~^B_t = (phi_t u1 / r_t)^(1-gamma)/(1-gamma) D_t. Two ways to set phi_t: (a) one share for all ages; (b) phi_t = c_min / Ybar^L_t, equal to c_min for the median household at every age. Recommended: (b), same c_min for both tenures.
Numbers, by hand (Python, DHS cubics): (a) the median's floor at 40 / 55 / 66 is 1.74 / 1.84 / 1.66 times its entry value (owners), 1.63 / 1.71 / 1.64 (renters). (b) phi_t over phi_25: 0.58 / 0.54 / 0.60 (owners), 0.61 / 0.58 / 0.61 (renters). Spread across households 0.50-2.00 of the median's floor from 66 in both.
Checks run: none. No code changed.
Commit: this entry with `docs/prompts/absorbing_floor.md`, pushed to claude/dreamy-edison-1814gg.
Open: Quinn: (a) or (b); same c_min or same phi for both tenures; the source and value of c_min; decisions 2 and 3 of the prompt (the lower bound of consumption, an involuntary trigger).

### 2026-10-22 The absorbing floor: a basis in Dutch policy (spec: none, asked by Quinn in Claude Code)
Quinn: is there anything in Dutch policy design to base the floor on?
Changed: `docs/prompts/absorbing_floor.md`, "Dutch policy basis" under "The floor in euros": the bijstand norm (70% / 100% of the net minimum wage, indexed with contract wages: a common euro amount, so c_min constant in real euros); the beslagvrije voet (95% of own net income at the bottom, a cap above); the Wsnp (18 months since 1 July 2023, then a clean slate, so not absorbing; pension rights not available to creditors, to be checked); bijstand to owners as a loan on the house (equity release, TODO 1.1); the AOW as the retirees' minimum. Added a temporary-bankruptcy variant for renters (k years at the floor, then back with X = 0), computable on the existing grid without a new state.
Sources: web search, secondary sources (municipal tables, ESB, rendement.nl, bureauwsnp.nl); statute texts not read line by line.
Checks run: none. No code changed.
Commit: this entry with `docs/prompts/absorbing_floor.md`, pushed to claude/dreamy-edison-1814gg.
Open: Quinn's choices: absorbing or temporary for renters; owners after 54; the source for c_min, single or couple.

### 2026-10-22 The absorbing floor without a new state (spec: none, asked by Quinn in Claude Code)
Quinn: no new state variable; what are the options?
Changed: `docs/prompts/absorbing_floor.md`, "Without a new state" under "The floor in euros". The floor must be proportional to something in the state. Every household of a tenure enters with the same Y0 and H0, so H0 is a common euro amount. Options: (1) income, phi_t = c_min/Ybar_t; (2) renters, the rent index, phi^R_t = c_min/Hbar_t; (3) owners, the purchase price q H = H0, exact while q is live (25-54), then (a) keep q live to 100, (b) switch to income, or (c) house value. Recommended: renters 2, owners 3a if the run time is acceptable, else 3b. The H-based floors need a fallback on the grid edges where H = 0.
Numbers, by hand (Python, from config.params): 10th-90th percentile over the median path at 40 / 66 / 100: income 0.66-1.52 / 0.50-2.00 / 0.50-2.00; rent index 0.92-1.09 / 0.86-1.16 / 0.82-1.22; house value 0.67-1.49 / 0.52-1.93 / 0.41-2.44. H0 at step 16: owners EUR 176,945, renters EUR 125,208. Owner run time with q to 100 roughly twice (estimate from step 7b: 366 s and 83 s); not measured.
Checks run: none. No code changed.
Commit: this entry with `docs/prompts/absorbing_floor.md`, pushed to claude/dreamy-edison-1814gg.
Open: Quinn's choice; the source for c_min; decisions 1-3 and 5 of the prompt.

### 2026-10-22 The absorbing floor: the homothety condition and the continuation at a node (spec: none, asked by Quinn in Claude Code)
Quinn: the floor after bankruptcy is constant, and lifetime utility from then on is the discounted sum of u at that level; it has to fit the model's homothety.
Changed: `docs/prompts/absorbing_floor.md`, two paragraphs under "The model, formally". (1) The condition: V^B_t = Cbar^(1-gamma)/(1-gamma) D_t is homothetic exactly when Cbar is proportional to the household's state at entry, Cbar = W g(u, q, t); constant afterwards needs no state. A euro amount common to all needs c_min/Y as a state. (2) The continuation at a quadrature node in `bellman_rhs` units: bankrupt where LW_n < phi_{t+1} Y_next_W, with CE_n = phi_{t+1} Y_next_W D_{t+1}^(1/(1-gamma)).
Also drawn, not committed (Python, from the DHS cubics; scratchpad of this session): gross income by age, median, mean and 10th-90th percentile, owners and renters, with the 2025 bijstand norms. Median at 25 / peak / 66 / first pillar: owners EUR 39.8k / 74.7k at 50 / 66.0k / 20.3k; renters 30.1k / 52.0k at 49 / 49.5k / 15.2k.
Checks run: none. No code changed.
Commit: this entry with `docs/prompts/absorbing_floor.md`, pushed to claude/dreamy-edison-1814gg.
Open: as in the entries below.

### 2026-10-22 The absorbing floor in euros: options (spec: none, asked by Quinn in Claude Code)
Quinn: the floor should be a minimum subsistence level, a constant euro amount, which is hard in a homothetic model; asked for suggestions.
Changed: `docs/prompts/absorbing_floor.md`, new section "The floor in euros". An exact euro floor costs one state, the scale homothety removes. Options: (1) phi_t = c_min / Ybar_t along the deterministic profile, no new state, exact for a household on the profile; (2) a state f = c_min / Y_t, exogenous like q, exact; renters can use the fourth axis, owners need a fifth while the mortgage runs; the same state allows a flat AOW; (3) retirement is already a constant euro amount per household. Recommended: (1) with the absorbing state for both tenures, then (2) for renters only to measure (1)'s error, owners on a fifth axis only if that error is outside the stop rule. Decision 4 points to the section.
Numbers, by hand (Python, from the DHS cubics): Ybar_t / Ybar_25 1.74, 1.84, 1.66 at 40, 55, 66 (owners); 1.63, 1.71, 1.64 (renters). 10th-90th percentile of Y_t / Ybar_t: 0.67-1.50 at 40, 0.51-1.95 from 66. Bijstand norm 1 Jan 2025, incl. holiday allowance: EUR 1,345.45 a month single, EUR 1,922.07 couple (Normenbrief 2025 via municipal tables), 0.41 and 0.58 of an owner's gross income at 25, 0.54 and 0.77 of a renter's. The norm pays for housing; c_min must be the minimum net of housing, source to choose (Nibud minimum budgets).
Checks run: none. No code changed.
Commit: this entry with `docs/prompts/absorbing_floor.md`, pushed to claude/dreamy-edison-1814gg.
Open: Quinn's choice among the options and of the source for c_min; decisions 1-3 and 5 of the prompt.

### 2026-10-22 Prompt for the consumption floor as an absorbing state, saved, not started (spec: none, asked by Quinn in Claude Code)
Quinn: start work on an absorbing state. The idea is a higher consumption floor that a household, once below it, consumes for the rest of its life. Asked what has to change in the code and for a formal statement of the request.
Changed: `docs/prompts/absorbing_floor.md` (new): the model stated formally (trigger LW_t < phi_abs Y_t; bankrupt from then on at Cbar = phi_abs Y at entry; value u(Cbar) D_t with D_t = 1 + beta p_t D_{t+1}, D_T = 1, so no new state and homothety holds; phi_abs = 0 is today's model). Five open decisions with a recommendation each. The code changes file by file, the new tests, and the runs with expectations. No code changed.
Numbers, by hand (Python, from config.params and the CBS table): D = 22.3 at 25, 16.8 at 55, 12.9 at 67, 4.1 at 90. Liquid resources at entry, step 16: 0.327 Y owners (take-home 0.556, housing 0.308), 0.420 Y renters (0.574, 0.233), with b0 = 0.079. This caps phi_abs at about 0.2.
Conflict: the request reopens TODO.md item 1.4 and CALIBRATION.md ("Consumption floor", 17 Oct), which settle the floor as a numerical bound at 1e-6. Both need changing if this is adopted.
Checks run: none. MATLAB is not installed in this session's container. No code in `+config`, `+ladder`, `+model` or `+solver` changed.
Commit: this entry with `docs/prompts/absorbing_floor.md`, pushed to claude/dreamy-edison-1814gg (not main: this session may push only to that branch).
Open: Quinn's decisions 1-5 in the prompt; then the implementation.

### 2026-10-23 Same income polynomial for owners and renters, recorded as planned (spec: none, asked by Quinn in Claude Code)
Quinn: document that in the future owners and renters will use the same polynomial.
Changed: CALIBRATION.md, Labour income, a paragraph saying the separate cubics stay until the change is implemented. TODO.md, section 2, a row with the open details (which polynomial, whether the shock std is shared) and what follows from it (`h_mult`, `kappa`, the entry incomes behind `b0` and `tau_inc` stop differing by tenure). No code or parameter changed.
Checks run: none, documentation only.
Commit: this entry with CALIBRATION.md and TODO.md, pushed to main.
Open: whether `sigma_l_log` is shared; then the code change in `config.params` and `+ladder/steps.m` (step 4 on).
Update, same day: Quinn chose a DHS cubic estimated on owners and renters pooled, and will send the coefficients. CALIBRATION.md and TODO.md say so.

### 2026-10-20 Step 16: share at the consumption floor by age, for the summary plots (spec: none, asked by Quinn in Claude Code)
Quinn: the bankruptcy rates for the summary plots. The model's bankruptcy event is a floored household-year (liquid resources below phi_floor times income; consumption set to the floor, the shortfall forgiven). The dashboards print only the total.
No new solve. New `diagnostics/nibud/floored_by_age.m`: the floored share by age for every solve behind `summary_step16/`. Output (gitignored): `summary_step16/16_floored_by_age.png`. Also drawn without a script: `summary_step16/income_profile_owner_renter.png`, the owner and renter income cubics of `config.params`.
Results, % of households at the floor, all years / 67-79 / 80-89 / 90-100:
- Summary grids: owner, maintenance on current value 3.10 / 0.38 / 2.69 / 18.46 (36% at 100); on purchase price 0.02 / 0 / 0 / 0 (above 0.05% only at 46-54, the last mortgage years, peak 0.32% at 54); renter 0.64 / 0.10 / 0.71 / 3.67.
- Owner, current value, by grid: 2.68% of years at 20x20, 2.48% at 24x24, 2.27% at 32x32, 0.44% with u3 at 20 (2.16% at 90-100). Renter: 1.21% with u3 at 10, 0.92% at 32x32, 0.79% at 48x48, 0.23% with u3 at 40. The rate falls with every refinement and has not settled, most along u3.
- Ladder's uniform 16x16 (the earlier dashboards): owner 6.65% (30.0% at 90-100), renter 1.69%.
The panel keeps all households alive to 100 (survival enters through the annuity), so a rate at an age is among those who reach it, and the all-years total weights old ages more than a survival-weighted population would.
Checks run: `run_tests(solve=false)` 0 of 10 failed. No code in `+config`, `+ladder`, `+model` or `+solver` changed.
Commit: this entry with `diagnostics/nibud/floored_by_age.m`, pushed to main.
Open: TODO item 1.

### 2026-10-20 Step 16 renter: the summary grid against larger grids (spec: none, asked by Quinn in Claude Code)
Quinn: a renter dashboard as well. The renter dashboard of the summary is `summary_step16/16_renter.png` (entry "Step 16 dashboards" below); added the renter's grid check, as for the owner.
No new solve: the 18 October study's renter solves. New `diagnostics/nibud/renter_grid_compare.m`: the summary grid (bunched 16x16, u3 at 20) against 48x48 and 32x32 (u3 at 10) and 16x16 with u3 at 10 and 40, all with the sweep.
Output (gitignored), `summary_step16/`: `16_renter_grid_vs_48x48.png`, `16_renter_grid_ladder.png`.
Results. Policies, consumption % / liquid equity share, bands 40-54, 55-66, 67-89, 90-95:
- Against 48x48 (finer u1 and u2, u3 at 10): summary grid 6.2/0.003, 2.7/0.012, 0.9/0.030, 0.4/0.028; 16x16 u3 10 11.0/0.007, 1.1/0.012, 1.0/0.016, 0.2/0.011; 32x32 5.3/0.004, 0.2/0.009, 0.2/0.007, 0.1/0.005.
- Against 16x16 with u3 at 40 (finer u3): summary grid 5.3/0.002, 1.9/0.003, 1.3/0.003, 0.7/0.007; u3 10 10.6/0.009, 4.0/0.007, 3.2/0.027, 1.7/0.024. These rows and 32x32's equal the 18 October table.
- The summary grid's gaps to 48x48 after 67 are mostly 48x48's own u3 at 10. Before 40 no renter grid agrees (consumption at 30: 0.28 times entry income on the summary grid, 0.14 on 48x48).
- Levels, summary grid against 48x48: median consumption 0.47 against 0.49 at 40, 0.73 against 0.76 at 66, 0.44 against 0.44 at 95; liquid saving 4.6 against 5.4 at 55; floored 0.64% against 0.79%.
Checks run: `run_tests(solve=false)` 0 of 10 failed. No code in `+config`, `+ladder`, `+model` or `+solver` changed.
Commit: this entry with `diagnostics/nibud/renter_grid_compare.m`, pushed to main.
Open: TODO item 1.

### 2026-10-20 Step 16 owner, maintenance on the current value: the summary grid against larger grids (spec: none, asked by Quinn in Claude Code)
Quinn: the grid of the summary dashboards (entry below) against a larger grid, maintenance on the current value only.
No new solve: the larger grids are the 18 October study's. A 20x20 run with maintenance on the purchase price was started and stopped after about a minute when Quinn said it was not needed; nothing was saved.
Ran: new `diagnostics/nibud/maint_grid_compare.m`: the summary grid (bunched 16x16, q at 4, no sweep) against 20x20, 24x24 (q at 4), 32x32 and 24x24 with u3 at 20 points, all with the sweep.
Output (gitignored), `summary_step16/`: `16_owner_grid_vs_32x32.png` (the two with their bands), `16_owner_grid_ladder.png` (all five, 32x32 the reference).
Results. Policies at 32x32's households, consumption % / liquid equity share, bands 40-54, 55-66, 67-89, 90-95:
- 16x16: 144.6/0.035, 1.8/0.033, 2.5/0.018, 1.7/0.024. 20x20: 106.5/0.036, 1.1/0.022, 1.6/0.010, 1.2/0.013. 24x24: 70.1/0.034, 0.6/0.010, 0.7/0.006, 0.6/0.011. The last two rows equal the 18 October table.
- Before 40, 32x32 owners consume about 0 (median 0.00 times entry income at 30, 0.07 at 40), so percentages there are of nothing.
- Levels, 16x16 against 32x32: median consumption 0.39 against 0.07 at 40, 0.82 against 0.90 at 66, 0.48 against 0.56 at 95; liquid saving 5.1 against 8.5 at 55; retirement equity share 0.62 against 0.49 at 66; floored at 95 15.8% against 10.8%. Each finer grid moves the same way: less consumption young, more saving, lower retirement share, fewer floored.
- u3 at 20 points (24x24) against 32x32 at u3 10: 89.4/0.317 at 55-66, 61.3/0.091 at 67-89; median consumption 0.01 at 55, liquid saving 24 times entry income at 66. Against it the summary grid is 506%/0.094 off at 55-66.
So the summary grid is near 32x32 from 55 on in consumption (within 2.5%) but outside the 0.02 share rule at 55-66 and 90-95, and far off before 55; and 32x32 is itself not converged in u3.
Checks run: `run_tests(solve=false)` 0 of 10 failed. No code in `+config`, `+ladder`, `+model` or `+solver` changed.
Commit: this entry with `diagnostics/nibud/maint_grid_compare.m`, pushed to main.
Open: TODO item 1.

### 2026-10-20 Step 16 dashboards: maintenance on the current value and on the purchase price (spec: none, asked by Quinn in Claude Code)
Quinn: to summarise the past weeks, the dashboards of the new calibration with the Nibud mortgage, with and without maintenance on the purchase price (constant house value). Use new runs only where needed, at most 30 minutes per run.
Step 16 with maintenance on the purchase price had never been solved. It changes the owner only (renters pay rent, no maintenance), so the owner was solved twice on one grid that fits the budget, and the renter is an existing solve.
Ran: `solve_cases('16:owner:pow3_16x16_lim_u3p2_qn4_nosweep')` and the same with `_mop`, two processes side by side: 649 s and 1,206 s. Then the new `diagnostics/nibud/maint_dashboards.m`. Renter: `16_nibud_renter_pow3_16x16_lim_u3p2_u3n20` (18 October, the grid on which the renter passes from 55).
Output (gitignored), `ladder/standard_16x16x10x8_gh5/summary_step16/`: `16_owner_maint_current.png`, `16_owner_maint_purchase.png`, `16_renter.png`, `16_owner_current_vs_purchase.png`, `16_renter_vs_owner_current.png`, `16_renter_vs_owner_purchase.png`; copies of the ladder's uniform-grid step-16 figures as `ladder_uniform_*.png`. Solves in `pension_grid/`.
`model.checks`: off-grid 0 and c-bound 25-39 0% in all three. Floored: owner current value 3.10%, purchase price 0.02%, renter 0.64%. Entry value 0.022, 0.277, 0.174. One "matrix close to singular" warning in the purchase-price run, as at steps 13 and 15.
Results (multiples of entry income; consumption median, saving mean):
- Owner, current value: consumption 0.03 at 25, 0.25 at 35, 0.82 at 66, 0.48 at 95; liquid saving 5.1-5.2 at 55-66; equity share of liquid saving 0.00-0.02 from 35 to 55; floored 15.8% of owners at 95. The hoarding corner of the 18 October study.
- Owner, purchase price: consumption 0.25 at 25, 0.45 at 35, 0.98 at 66, 0.95 from 85; liquid saving about 1 at 45-66 and 0 from 85; equity share 0.28-0.40 at 35-55, about 1 from 75; no one floored after 75. Housing cost after the mortgage is a flat 0.07 instead of rising to 1.0 times entry income at 100.
- Renter: consumption 0.17 at 25, 0.73 at 66, 0.44 at 95; liquid saving 4.6 at 55; floored 3.2% at 95.
Limits: the owner on this grid is not converged at step 16 with maintenance on the current value (18 October). Without the sweep, step 13 moved consumption within 0.2% and the share of liquid saving by 0.03 at 26-39. q at 4 points was checked at step 16 only with maintenance on the current value, where q is a state to 54, not at every age. Bunched 16x16 missed 24x24 by 2.3% in consumption at 66 at step 13. Read behaviour, not welfare.
Checks run: `run_tests(solve=false)` 0 of 10 failed. No code in `+config`, `+ladder`, `+model` or `+solver` changed.
Commit: this entry with `diagnostics/nibud/maint_dashboards.m`, pushed to main.
Open: TODO item 1.

### 2026-10-18 CLAUDE.md known limit corrected (spec: none, asked by Quinn in Claude Code)
Quinn: update CLAUDE.md's known limit to say owners at step 16 are not converged at any age and renters only from about 50, citing the 18 October grid study.
Changed: CLAUDE.md, the first known limit. "Behaviour from age 40 is reliable" is replaced by: owners at step 16 not converged at any age on any grid tried (refining u3 makes them hoard into retirement); renters converged only from about 50, on the bunched grid with 20 u3 points. Source: the entry "Smallest accurate grid at step 16" below.
Checks run: none (documents only).
Commit: this entry with CLAUDE.md, pushed to main.
Open: TODO item 1.

### 2026-10-18 Grid and interpolation work parked (spec: none, asked by Quinn in Claude Code)
Quinn: leave the grid question until TODO item 1 is settled; stop the solver-extrapolation session and park all grid and interpolation work. Declined for now: a test of whether maintenance on the purchase price makes the step-16 owner converge.
Done: the session "Solver extrapolation snaps all coordinates: measure it" stopped after about 90 seconds, with nothing committed and no solves left running. TODO.md, section 6: the parking note.
Not done: CLAUDE.md's known limit ("behaviour from age 40 is reliable") no longer holds for owners at step 16, nor for renters before about 50 (entry "Smallest accurate grid at step 16", 18 October); left for Quinn.
Checks run: none (documents only).
Commit: this entry with TODO.md, pushed to main.
Open: TODO item 1.

### 2026-10-18 Step 16: does the interpolation misprice the ruin corner? Results (spec: none, asked by Quinn in Claude Code)
Follows the expectations entry below (e84e344).
Ran: two smoke runs at age 60, then `ruin_interp(16, 'owner', {'pow3_24x24_lim_u3p2_qn4', 'pow3_24x24_lim_qn4_u3even'}, figure = false)` and `ruin_interp(16, 'owner', {'pow3_24x24_lim_u3p2_qn4_u3n20'}, figure = false)` side by side (19 and 21 minutes). Then `ruin_interp` on all three with `band = 'union'` (the default) and `band = 'own'`, which reuses the saved results and prints the tables and figures.
Changed (diagnostics only): `ruin_interp.m` revised after the smoke runs, before the full runs. (1) The first smoke run never set this age's test points, so it compared node values with interpolated midpoints; fixed. (2) Outside the grid, `griddedInterpolant` with 'nearest' extrapolation returns the value at the nearest node in every coordinate, not the value flat along the one axis that is off the grid. So inserting u3 points changes the continuation for next-year states past the top of u1 or q. The continuation check now runs inside the grid only, and the centres are run a second time on the solved u3 axis and compared at the u3 nodes. (3) Added a set of test states with u1 and u2 on the nodes (the error along u3 alone) and regions at the u3 nodes (the error along u1 and u2 alone). (4) The band is by default the union of the three panels' bands, because the grids' households sit in different places. Output, gitignored: `pension_grid/ruin_interp_16_nibud_owner_<case>.mat`, `ruin_interp_16_nibud_owner_union.png` and `_own.png`. The full tables are in the shared notes folder of these sessions (`ruin_interp_tables.md`).
Checks: the continuation with the inserted points against the solved one, inside the grid: at most 7.8e-16. The step on the nodes against the saved values, inside the households' u1 and q bands: at most 4.1e-5 in CE, on every grid and age. The inserted u3 axis against the solved one at the u3 nodes, inside the bands: at most 1.0e-5. Outside the bands (u1 near its top, W/Y under about 2, and the q = 2.5 slice) both differ by up to a factor of 2,600, because next year's states leave the grid there and the snapping decides their value. Every region lies inside the bands.
Results, union band. Gap = CE interpolated over CE Bellman, minus 1: median / largest, and the share of the region's volume above 100%. Grids in the order u3 even at 10, power 2 at 10, power 2 at 20.
1. Middle (the control, u3 0.3-0.8, u2 in the band) on the 10-point grids: median -0.5% to 0.1% at every age. Largest 72% and 197% at 45 (a few cells), at most 4.5% from 60 on.
2. Corner (u3 below 0.12, u2 = 1) on the 10-point grids: positive and large. At 45: 28.7/167% and 13.5/67%. At 60: 45/162% and 21/75%. From 70 on the largest gaps are CE ratios of 1e3 to 1e6 (70: 6.1e5% and 1.2e5%; 85: 1.4e7% and 8.2e6%; 90: 6.9e7% and 6.0e7%), with 0.14 to 0.36 of the corner above 100%. They sit at u3 0.03-0.25 on all three grids. In the figures nearly every large gap is positive: the interpolation prices states next to ruin as better than they are.
3. Along u3 alone (u1 and u2 on the nodes, u2 = 1, u3 below 0.12), the error falls with every point added near u3 = 0, at every age. Median at 45: 4.2%, 0.39%, 0.10%. At 60: 8.4%, 1.4%, 0.18%. Largest at 85: 1.3e7%, 6.6e6%, 1.8e5%; at 90: 9.6e7%, 8.4e7%, 2.0e6%.
4. At the cell centres the corner falls in working life. At 45, 28.7%, 13.5%, 4.1% median and 167%, 67%, 8.6% largest; at 60, 45%, 21%, 7.1% and 162%, 75%, 14%. In retirement the largest gap falls by one to two orders of magnitude but stays at 1e4% to 1e6%, and the share above 100% does not fall: 0.19, 0.36, 0.63 at 70; 0.30, 0.18, 0.26 at 85; 0.33, 0.14, 0.16 at 90. The part along u1 and u2 (the same points on all three grids) carries it: at the u3 nodes below 0.12 the share above 100% at 70 is 0.24, 0.38, 0.57.
5. The 20-point grid is mispriced in the middle of working life, at the same states where the 10-point grids are within 0.5%. Middle median 39.5% at 45 and 45.8% at 60, largest 2.9e3% and 2.2e3%, with 0.97 and 0.94 of the volume above 1%; 4.7% median at 70. Its own households sit there: its u2 band at 45 is 0.44-0.75, against 0.57-0.79 and 0.61-0.80 on the 10-point grids. On that grid 8% of the middle's volume at 45 has a Bellman value within 10 times the floor's CE; on the 10-point grids none does. These states are not floored now, but in that grid's continuation next year's worst shock takes them to the floor.
What it means:
- The error has one source: the floor. With phi_floor = 1e-6 and gamma = 5, a state from which one quadrature node of next year's shocks lands at the floor has a CE of the order of the floor itself, 1e-6 of income, four to five orders of magnitude below its neighbours. So z has a deep, narrow trough along that edge. Linear interpolation in z fills the trough in, and every cell the edge crosses is priced too high: by tens of % in working life, by factors up to 1e6 in old age.
- Quinn's reading holds in this sense: the interpolation does not price bankruptcy risk properly, and the error always has the same sign, too mild. A household that reads the ruin corner as too mild saves less, which fits the coarse grids' owners saving less and flooring more.
- It explains part of why the owner answer follows the points near u3 = 0. In working life the corner's error falls in the order even 10, power 2 at 10, power 2 at 20, the order in which saving at 66 rises (5.2, 6.8 and 24.2 years of entry income) and the floored share falls. Along u3 alone it falls at every age.
- It does not point to a grid that converges. Refinement moves the trough rather than removing it. On the 20-point grid the trough appears in the middle of working life, where that grid's hoarding households sit. From 70 on the corner stays at 1e4% to 1e6% on every grid. Points near u3 = 0 shrink the cells the edge crosses, but the trough is as deep on any grid, so the policy keeps moving with the points. The fix is in the model (the floor and the housing outflow, TODO item 1) or in an interpolation that handles the floor's edge, not in where the u3 points go.
Against the expectations:
- Right: the checks pass inside the bands. The middle is small on the 10-point grids. The corner is positive and large, and its share above 1% is at least 10 times the middle's, except power 2 at 10 at age 45 (1.00 against 0.17). In working life the corner's median and largest gap fall from even 10 to power 2 at 20.
- Wrong: the share of the corner above 1% does not fall (0.9 to 1.0 on every grid in working life). On the 20-point grid the middle is not small. In retirement the corner does not fall with u3 points at the cell centres; only the part along u3 alone does. In working life the largest gaps on the 10-point grids are not near u3 = 0: at u2 = 1 they peak at u3 0.3-0.6 (mid_u2one, 5.2e4% to 4.8e5%), and on the 20-point grid at 0.75.
- Not foreseen: the solver's 'nearest' extrapolation snaps every coordinate to the nearest node. bellman_step_lna's comments say flat extrapolation, but past the top of u1 or q the value is nearest-node in u2 and u3 as well. Inserting u3 points changed the step's values at nodes near the u1 top by up to a factor of 2,600.
Limits: five ages. The regions are cell centres inside the 5th-95th percentile band, not the households' own states. Off the nodes, the Bellman value comes from the solver's own search; a search that missed the best choice would also show up as a positive gap. On the nodes the same search reproduces the saved values. The 20-point grid's middle errors are not traced further.
Checks run: `run_tests(solve=false)` 0 of 10 failed. No code in `+config`, `+ladder`, `+model` or `+solver` changed.
Commit: 0e451c6 (this entry with `ruin_interp.m`), pushed to main.
Open: (1) TODO item 1 first. (2) The 'nearest' extrapolation: how often the solver's quadrature leaves the grid, and whether extrapolation flat along each axis changes the answer. That is a `+solver` change and Quinn's call. (3) If the floor stays at 1e-6: an interpolation that handles the trough (for example one that locates the floor's edge), tested with this script.

### 2026-10-18 Step 16: does the interpolation misprice the ruin corner? Expectations before the runs (spec: none, asked by Quinn in Claude Code)
Follows "grid points where households sit: results" below, whose open item this is. Question: is the value function's interpolation error large near u3 = 0 and u2 = 1 (pot gone, no liquid saving, the house's carrying costs left), small in the occupied middle, and smaller with more points near u3 = 0? That would explain why each grid's owner answer follows its points near u3 = 0.
How the solver stores it (`+solver/bellman_step_lna.m`): V is stored per unit of W^(1-gamma). The continuation is interpolated in z = ((1-gamma) V)^(1/(1-gamma)), the certainty equivalent per unit of wealth, with `griddedInterpolant`, linear (p.interp_method) on (u1, u2, u3) and q while q is a state, flat outside the grid. Where liquid resources fall short of phi_floor Y (phi_floor = 1e-6) the household consumes the floor and saves nothing; with gamma = 5 a floored state's z is about the floor itself, 1e-6 u1, so z drops by orders of magnitude across the floor's edge.
Changed (diagnostics only): new `diagnostics/pension_grid/ruin_interp.m`. For each saved solve and age it runs the solver's own step (`solver.bellman_step_lna`, unchanged) at cell centres between the grid points, with the same next-period value function, and compares the result with the value interpolated from the saved nodes. The gap is CE interpolated over CE Bellman, minus 1. The test states go in through the age grid (this age's u1 and u2 points are the test points, next age's the solved ones), and the u3 midpoints are inserted in the u3 axis with next age's values interpolated onto them; with linear interpolation that leaves the continuation exactly as solved. Two checks: the step on the nodes must give back the saved V, c and pi, and the continuation with the inserted points must equal the solved one. Regions, u1 in the households' middle-90% band: corner (u3 < 0.12, u2 = 1), corner_in (u3 < 0.12, u2 between nodes above 0.98), low_u3 (u3 < 0.12, u2 in the households' band), mid_u2one (u3 0.3-0.8, u2 = 1), middle (u3 0.3-0.8, u2 in the band; the control). Ages 45, 60, 70, 85, 90.
Plan, two MATLAB processes, no new solves of the life cycle:
1. A: `ruin_interp(16, 'owner', {'pow3_24x24_lim_u3p2_qn4', 'pow3_24x24_lim_qn4_u3even'})` (about 6 minutes each).
2. B: `ruin_interp(16, 'owner', {'pow3_24x24_lim_u3p2_qn4_u3n20'})` (about 11 minutes).
3. Then `ruin_interp(16, 'owner', {all three})` for the joint table and figure (no recomputation).
Expectations:
1. Checks: the step on the nodes reproduces the saved values to rounding (CE gap under 1e-10, c and pi equal), and the continuation is unchanged to under 1e-12. Otherwise the test is void.
2. Middle: small. Median |gap| under 0.1% and largest under 1%, at every age and grid. Mostly negative (z concave between nodes, so the line between nodes lies below).
3. Corner and corner_in: positive gaps (the interpolation prices the state as better than it is), because the line between a floored node and one above the floor lies far above the floor's value in the cells the edge crosses. The largest gap above 100% at the ages where the floor's edge runs through the households' u1 band. The share of the region's volume with a gap above 1% at least 10 times the middle's.
4. Across grids: in the corner, the volume share above 1% and the median gap fall from u3 even at 10 (one u3 interval below 0.12) to power 2 at 10 (three) to power 2 at 20 (seven). The largest gap need not fall: some cell always straddles the floor's edge.
5. mid_u2one and low_u3 say which axis carries it. If mid_u2one (u3 in the middle, u2 = 1) is as bad as the corner, the error is the floor's edge along u1 and u2, not u3 = 0. If low_u3 is bad with u2 in the middle, it is u3 = 0 itself.
Quinn's reading predicts 3 and 4. If the corner's gap is as small as the middle's, or does not fall from even 10 to power 2 at 20, then the interpolation of the corner does not explain why the owner answer follows the points near u3 = 0.

### 2026-10-18 Step 16: grid points where households sit: results (spec: none, asked by Quinn in Claude Code)
Follows the expectations entry below (71c0361).
Ran: `solve_cases` on 9 step-16 cases, two MATLAB processes side by side. Owner (bunched 24x24, q at 4): u3 even at 10 and at 20 points, each with and without lambda_hi 0.3 and q_hi 1.3, and u3 even at 10 with lambda_hi 0.2 (the probe). Renter (bunched 16x16): u3 even at 10 and 20, with and without lambda_hi 0.3. Then the new `step16_placement`, which prints `size_table` (panel and `policy_gaps`) against the 20- and 40-point u3 cases and the bounded cases, plus a few life-cycle points per case, and draws the figures.
Changed (diagnostics only): new `diagnostics/pension_grid/step16_placement.m`; `grid_lifecycles.m` gives each column one vertical scale across rows. Output, gitignored: `pension_grid/lifecycles_16_owner_placement.png`, `lifecycles_16_renter_placement.png`, `occupancy_16_owner_even10.png`, `_even20.png`, `occupancy_16_renter_even10.png`, `_even20.png`. The full tables are in the shared notes folder of these sessions (`step16_placement_tables.md`).
`model.checks`: thin u1 0 everywhere. Off-grid lookups: 0 without bounds; owner 1,583 on q with q_hi 1.3 and 2,702 on u1 at lambda_hi 0.2; renter 30 and 24 on u1 at 0.3. Floored: owner 4.67% (even 10), 4.65% (with bounds), 4.63% (probe), 1.60% (even 20, with or without bounds), against 2.48% and 0.44% at power 2 with 10 and 20 points; renter 1.18% and 1.10% at 10, 0.67% and 0.57% at 20, against 1.21%, 0.64% and 0.23% at power 2 with 10, 20 and 40 points. Owner solves took 49-50 minutes at 10 points and 101 at 20, renter 8-9 and 17.
Gaps are consumption % / mean liquid equity share on policies (`policy_gaps`, each case's policies on the reference's households), bands 55-66, 67-89 and 90-95.
Owner, u3 placement:
1. Evenly spaced u3 at 10 points is further from u3 at 20 than power 2 at 10 is, against both 20-point grids. Against power 2 at 20: even 553.5/0.114, 130.1/0.092, 1.4/0.023; power 2 497/0.087, 110/0.053, 2.3/0.004. Against even at 20: even 64.2/0.037, 18.3/0.037, 6.1/0.022; power 2 49.7/0.046, 7.0/0.034, 8.2/0.045.
2. Even at 20 is far from power 2 at 20 (349.5/0.094, 106.4/0.087, 5.9/0.009), so u3 is not converged at 20 points and placement still matters there.
3. The four cases line up by the points near u3 = 0 and the total count. Points below 0.12: even 10 has 2, power 2 10 has 4, even 20 has 3, power 2 20 has 7. Mean liquid saving at 66, in years of entry income: 5.2, 6.8, 13.5 and 24.2. Floored at 95: 28.0%, 12.3%, 4.5% and 1.9%. Mean consumption at 50: 0.785, 0.755, 0.437 and 0.081. At a given count, moving points from near 0 to the middle, where households sit from 40 to 80, makes owners save less and floor more. Adding points, at either placement, makes them save more and floor less.
Bounds (lambda_hi 0.3 and q_hi 1.3 together):
4. From 55 on they change nothing at u3 10 (no bounds against bounds: 0.1/0.003, 0.3/0.003, 0.8/0.004). At u3 20 they move 55-66 by 5.9% (0.1 and 0.4 after), where mean consumption is still rising (0.754 against 0.736 at 55).
5. Before 55 they move young owners the way a finer u1 grid does: less consumption and more saving (at u3 10, consumption at 40 0.418 to 0.392, saving at 50 6.5 to 6.9; 10.8% at 40-54). With grid_pow 3 the lower top moves every u1 point to a higher W/Y, so the band gets more points (owner 3-5 to 5-6 at 40-60). The trims are partly a refinement.
6. The probe at lambda_hi 0.2 against 0.3: 5.3% at 40-54, at most 0.3% from 55. Young owners save a little more (consumption at 40 0.379, saving at 50 7.1), not less. The flat value past W/Y 5 for the 5% of owners at 26-28 above it does not show; the extra u1 points do.
Renter:
7. Against u3 at 40: even 10 is 3.4/0.009, 2.7/0.025, 2.4/0.038; power 2 10 is 4.0/0.007, 3.2/0.027, 1.7/0.024. Even 20 is 1.5/0.003, 1.2/0.006, 1.2/0.009; power 2 20 is 1.9/0.003, 1.3/0.003, 0.7/0.007. Even spacing is a little closer from 40 to 89 and further at 90-95, where floored renters sit (median u3 about 0.1). The count matters far more than the placement: at 55-66 even spacing closes 0.6 of the 2.1-point gap between power 2 at 10 and at 20. The floored share depends on the count only (95: 6.2% and 6.3% at 10, 3.2% and 3.2% at 20, 1.0% at 40).
8. Lambda_hi 0.3 changes nothing from 55 on (at most 0.2%), moves 40-54 by 1.9% and 2.3%, and moves 25-39 by 30% and 66%, toward the finer u1 x u2 answer: consumption at 30 0.320 to 0.300 and 0.293 to 0.266 (48x48 at u3 10: 0.168); entry value 0.2055 to 0.1675 and 0.1742 to 0.1167. Even 20 with top 0.3 is the only 18x18 renter case so far within the rule on policies from 40 on (2.0/0.002, 1.6/0.002, 1.2/0.007, 1.2/0.012 against u3 40).
Against the expectations:
- Right: renter even spacing a little closer from 55 to 89, still outside at 55-66; bounds change nothing from 55 at u3 10; off-grid counts as expected.
- Wrong: owner even at 10 moved away from u3 at 20, not toward it. Even and power 2 at 20 are far apart, not close. At u3 20 the bounds move 55-66 by 5.9%. The probe's young owners save more, not less. Renter bounds move 40-54 by about 2%, not under 1%.
- Not foreseen: renter even spacing is worse at 90-95.
What it means: the occupancy reading fails for owners. The points that steer the owner's answer are the ones near u3 = 0, where only floored and very old households sit, not the ones where households live. That fits Quinn's note: the grid problem is how the interpolation prices the ruin corner (pot gone, carrying costs on the house), not where households sit. Placing points by occupancy is the wrong rule for owners at step 16. For renters it helps a little in working life and costs a little at the end. Nothing here settles the owner. Every added point makes owners save more, and the answer has not stopped moving.
Limits: one seed, 10,000 households. The u1 and q trims ran together. The references are not converged themselves. "Points near 0" and "total count" are read off four cases, not varied one at a time.
Checks run: `run_tests(solve=false)` 0 of 10 failed. No code in `+config`, `+ladder`, `+model` or `+solver` changed.
Commit: 1808b68 (this entry with `step16_placement.m` and `grid_lifecycles.m`), pushed to main.
Open: a direct test of how the interpolation prices the ruin corner (the continuation value near u3 = 0 and u2 near 1, interpolated against evaluated at the same states) instead of more occupancy-based placement. TODO item 1 (the floor and the housing outflow) still comes first for the owner.

### 2026-10-18 Step 16: grid points where households sit: expectations before the runs (spec: none, asked by Quinn in Claude Code)
Follows "is the bunching in the right place?" below. Question: does putting the points where step-16 households sit (u3 evenly spaced, a lower top on u1, q on [0, 1.3]) change or steady the answer?
Changed (diagnostics only): `case_params.m` takes `_u3even` (grid_pow_u3 = 1, the default, written into the name), `_lhi<n>` (lambda_hi = n/100) and `_qhi<n>` (q_hi = n/10). No new primitives.
Bound on u1, checked on the saved panels before choosing: at lambda_hi 0.2 (W/Y 5, just under the entry anchors at 5.5-5.7) 5-6% of owners at 26-28 and 24-28% of renters at 26-33 sit above the top (income grows faster than the house or rent index); at 0.3 no owner does and 0.01% of renter household-years. So the trimmed cases use 0.3, and one owner case at 0.2 is a probe (Quinn's choice). q above 1.3 holds about 1% of owners at 30-40 (price falls, highest 1.9). Above the top of an axis the solver and the panel use the flat value at the top node. With grid_pow 3 the lower top moves every u1 point, not only the top ones: 24x24 at 0.3 has 6 points between W/Y 6 and 20 and 5 between 50 and 300, against 5 and 4 now.
Plan, two MATLAB processes:
1. A: owner `pow3_24x24_lim_qn4_u3even_lhi30_qhi13`, then `pow3_24x24_lim_qn4_u3even`, then the probe `pow3_24x24_lim_qn4_u3even_lhi20_qhi13` (about 40 minutes each), then renter `pow3_16x16_lim_u3even_lhi30`, `_u3n20_u3even_lhi30`, `_u3even`, `_u3n20_u3even` (7, 14, 7, 14).
2. B: owner `pow3_24x24_lim_qn4_u3n20_u3even_lhi30_qhi13`, then `pow3_24x24_lim_qn4_u3n20_u3even` (about 80 each).
3. `size_table` and `policy_gaps` against owner `pow3_24x24_lim_u3p2_qn4` and `_qn4_u3n20`, and renter `pow3_16x16_lim_u3p2`, `_u3n20`, `_u3n40`; `axis_occupancy` and `grid_lifecycles` for the new cases.
Two readings, which the runs can tell apart:
- Occupancy: what matters is points where households sit. Then u3 even at 10 is closer to u3 at 20 than power 2 at 10 is, and the bounds change little from 55 on.
- Ruin pricing (Quinn's note): what matters is how well the interpolation prices the states a bad shock can reach, near u3 = 0 (median floored owner at 0.02) and past the trimmed tops, even where nobody sits. Then u3 even at 10, with 2 points below 0.12 instead of 4, floors more people and moves away from u3 at 20; and the flat value past a trimmed top hides the ruin, so young owners save less.
Expectations:
1. Renter, u3 at 10: even spacing is closer to u3 at 40 than power 2 from 55 on (power 2 at 4.0/0.027 at 55-66 and 67-89, power 3 worse at 4.6/0.035, so the trend runs toward even). It still fails the 2% rule at 55-66. The floored share falls a little (1.21% at power 2, 1.35% at power 3). This is the occupancy reading, and the renter result so far supports it.
2. Owner, u3 at 10 even: moves toward u3 at 20 (more saving from 45 to 66, a lower floored share than 2.48%), but not far: u3 at 20 has 7 points in 0.3-0.8, even at 10 has 5, power 2 at 10 has 4. If it instead floors more and moves away from u3 at 20, that is the ruin-pricing reading.
3. Owner, u3 at 20, even against power 2: close, within a few % from 55, because both have enough points in the middle. A large gap would mean placement still matters at 20 points, so u3 is not converged at 20.
4. lambda_hi 0.3 with q_hi 1.3, against the same case without: within 1% and 0.01 from 55 on (q is not a state there and nobody is near the u1 top). Before 55 a few % at most. offgrid: u1 0, q above 0 (the 1% of owners at 30-40).
5. Probe at lambda_hi 0.2: offgrid on u1 in the thousands, at 26-35. Young owners (25-35) move by more than at 0.3. My guess is that they save less, because the flat value above W/Y 5 hides the cost of falling there. From 45 on it is close to the 0.3 case.
6. Renter, lambda_hi 0.3 against none: under 1% from 40 on.
Not tested: the bounds on u2 (the floor corner at u2 near 1, where Quinn's reading would put the cliff). The q and u1 trims run together, so their separate effects are not split.

### 2026-10-18 Step 16: is the bunching in the right place? (spec: none, asked by Quinn in Claude Code)
Quinn: is the bunching happening in the correct place here?
Changed (diagnostics only): new `diagnostics/pension_grid/axis_occupancy.m`: per axis (W/Y = 1/u1, 1 - u2, u3, q), the simulated households by age against each grid's points, and the points inside the middle-90% band by age. Output, gitignored: `pension_grid/occupancy_16_owner.png` (panel of owner 32x32), `occupancy_16_renter.png` (renter 48x48). No new solves.
Results, points inside the middle-90% band (ages 30 / 40 / 50 / 60 / 67 / 75 / 85 / 95):
- u1: bunched owner 24x24 5/3/4/5/3/4/4/6, ladder grid 4/2/3/2/0/0/0/0; bunched renter 16x16 4/3/3/3/2/2/3/4. Right direction: retirees (W/Y 50-300 owners, 20-60 renters) get points, which the evenly spaced grid does not give them. But the top of the axis is empty: households start at W/Y of about 5.5 (a house or rent index of 4.2-4.4 years plus a year's income) and almost none fall below 3.5, while 5 of the owner's 26 points (u1 0.31-0.55, W/Y 1.8-3.2) and 3 of the renter's 18 (u1 0.38-0.58) lie there; 2 owner points lie past W/Y 4,000 and 3 renter points past W/Y 600. Counting the nearest point on each side of the 0.5-99.5 band as used, 7 of 26 owner and 6 of 18 renter points are never used at any age.
- u2: bunched owner 3/4/4/6/13/12/13/12, renter 1/2/3/4/10/10/11/7; young renters at 31-37 have no point inside the band. Retirement gets 10-13 points, working life 1-6. The points near u2 = 1 (no liquid saving) sit where floored households are (median 1 - u2 about 0), so that end is the floor corner, not wasted.
- u3: power 2 at 10 points puts 2-4 points in the band (owner 3-4 from 40 to 85, renter 2), fewer than evenly spaced (owner 4 at 55-75, renter 3), because households sit at 0.3-0.8 from 45 to 80 and power 2 moves points toward 0. Only owners past about 85 and floored households (median u3 0.02 owners, 0.11 renters) live near 0. u3 at 20 points: owner 5-8 in the band from 40, renter 4-5.
- q (owners, to 54): households sit between about 0.3 and 1 (prices rise); the points above 1 (1.28, 1.84, 2.5) are not used, and q at 4 points has 1 point in the band (none at 41-44). The answers did not change with q at 4, so the policy is close to linear in q.
So: on u1 and u2 the bunching is in the right direction for retirement and the floor corner, but the young households, the part that does not converge, get the fewest points (1-5 on u1 and u2), and the top of u1 is spent on states no one reaches. On u3 it is in the wrong place for most of life. That fits the u3 results (10 points at power 3 worse than power 2; 20 points change the owner's answer). Whether better placement makes the young owner converge is not tested; the refinements so far all move the answer the same way.
Checks run: `run_tests(solve=false)` 0 of 10 failed.
Commit: this entry with `axis_occupancy.m`, pushed to main.
Open: tighter u1 bounds (lambda_hi near 0.2 with housing, the bottom near 0.002), u3 evenly spaced or bunched to the middle, q on [0, 1.3]. Each is a grid option or primitive already (`lambda_hi`, `lambda_lo`, `grid_pow_u3`, `u3_lo`/`u3_hi`, `q_hi`); not run.

### 2026-10-18 Step 16: the grid life cycles from a higher starting wealth (spec: none, asked by Quinn in Claude Code)
Quinn: the same graphs with a higher starting wealth.
Changed (diagnostics only): `grid_lifecycles.m` takes X0, liquid wealth at entry in years of income, and simulates every saved solution again from it (same seed and panel; the solutions are unchanged); it now computes the equity share of liquid saving from the panel it draws. `step16_lifecycles(X0)` passes it on and appends `_b<X0>` to the file names. Ran `step16_lifecycles(1)` and `step16_lifecycles` (the default figures again, same content, new title line). Output, gitignored: `pension_grid/lifecycles_16_owner_b1p00.png`, `lifecycles_16_renter_b1p00.png`.
Results, 1 year of income at entry against b0 = 0.08 (mean consumption, times mean income at 25):
- Owner: still about 0 until 33 on every grid. 24x24 0.003 against 0.004 at 30, 0.345 against 0.370 at 40, 0.969 against 0.986 at 66; 32x32 0.218 against 0.239 at 40; u3 at 20 0.004 against 0.006 at 40. Liquid saving at 40 rises by 0.9-1.0 years of income (24x24 6.04 to 6.93, 32x32 6.66 to 7.64): the extra year is saved almost whole. Floored share 2.48% to 2.30% (24x24). The grid sequences look as from b0: the young-age hoarding is the policy at these states, not a starting-wealth corner.
- Renter: consumption at 25 0.045 to 0.133 (24x24) and 0.000 to 0.002 (48x48); at 30 0.277 to 0.315 and 0.168 to 0.232; within 2-4% from 40. The grid lines still spread before 45.
Checks run: `run_tests(solve=false)` 0 of 10 failed.
Commit: this entry with the two scripts, pushed to main.
Open: as in the grid-size results entry below.

### 2026-10-18 Step 16: life cycles as the grid is refined (spec: none, asked by Quinn in Claude Code)
Quinn: show the simulated life cycles for the development of the grids.
Changed (diagnostics only): new `diagnostics/pension_grid/grid_lifecycles.m` (one row of panels per refinement sequence: mean and median consumption, mean liquid saving, mean liquid equity share, equity share of liquid saving, share at the floor; coarse grids light, fine dark) and `step16_lifecycles.m` (the cases of the grid-size study below, one figure per tenure). Output, gitignored: `ladder/standard_16x16x10x8_gh5/pension_grid/lifecycles_16_owner.png` and `lifecycles_16_renter.png`. No new solves.
What the figures show (numbers in the entry below): the owner's consumption start moves later with every refinement of u1 x u2, and with u3 at 20 points the whole life cycle changes (hoarding to about 60, saving 24 years of entry income at 70, consumption 1.7 times entry income at 85, almost no floor). The renter's sequence moves the same way but converges: from about 50 the u1 x u2 lines lie on top of each other, and u3 moves consumption by a few percent and the old-age equity share and floor more.
Checks run: `run_tests(solve=false)` 0 of 10 failed.
Commit: this entry with the two scripts, pushed to main.
Open: as in the entry below.

### 2026-10-18 Smallest accurate grid at step 16, per axis: results (spec: none; open decision 2 of docs/HANDOFF_2026-10-17.md, asked by Quinn in Claude Code)
Follows the expectations entry below (dc478a5).
Ran: `solve_cases` on 20 new step-16 cases, two MATLAB processes side by side. Owner: pow3 32x32, 32x16, 20x20, 24x16, 16x24 (all `_lim_u3p2`); 24x24 with `_u3n6`, `_qn4`, `_qn4_u3n8`, `_qn4_u3n20`. Renter: pow3 48x48, 48x24, 32x32, 24x24, 20x20, 16x16; 16x16 with `_u3n6`, `_u3n20`, `_u3n40`, and `pow3_16x16_lim_u3p3`. The owner u3 cases at 8 and 20 points and the renter cases at 20x20, 16x16 and their u3 variants were added during the session, each after the result before it, with the expectation written down first. Then `size_table` for each comparison.
Changed (diagnostics only): new `diagnostics/pension_grid/policy_gaps.m`, which reads one solve's policies at the reference's simulated households, age by age. It leaves out the wealth households bring to an age from earlier, unconverged years. `size_table.m` prints it as a block, measures consumption roughness against income instead of consumption, and skips a case equal to the reference.
Output (gitignored): the solves in `ladder/standard_16x16x10x8_gh5/pension_grid/16_nibud_<arm>_<case>.mat`; the full tables in the shared notes folder of these sessions (`step16_grid_tables.md`), reproduced by `size_table` with the cases below.
`model.checks`: off-grid [0 0 0 0] and thin u1 0 in every case. Floored, owner: 2.27% at 32x32, 2.48% at 24x24 (q at 8 or 4), 2.68-2.98% at the smaller shapes; 4.54%, 3.61% and 0.44% with u3 at 6, 8 and 20. Renter: 0.79% at 48x48 up to 1.21% at 16x16; at 16x16 1.58%, 1.21%, 0.64% and 0.23% with u3 at 6, 10, 20 and 40, 1.35% with u3 at power 3. Entry value: renter 0.0001 at 48x48, 0.0013 at 32x32 and 48x24, 0.056, 0.152 and 0.204 at 24, 20 and 16; owner 0.000-0.012 everywhere. "Matrix close to singular" warnings in the owner 32x32, 24x16, 16x24 and u3-at-8 solves.
Gaps below are consumption % / mean liquid equity share, stop rule 2% and 0.02. "Panel" is the simulated means, as `case_gaps`; "policies" is `policy_gaps`, each case's policies on the reference's households.
Results, owner:
1. No owner grid passes from 40 on. Against 32x32 the panel is outside at every band for every grid (24x24: 58.0/0.033 at 40-54, then 4.2/0.046, 4.2/0.046, 4.5/0.045). Before about 52 the owner does not converge: each finer grid makes young owners consume less and save more. Mean consumption at 40, times entry income, 0.403, 0.345 and 0.218 at 20x20, 24x24 and 32x32; liquid saving at 50 6.8, 7.7 and 9.0. The panel carries that wealth to 95. On policies, 24x24 against 32x32 is 69% off at 40, 17% at 45, 4% at 50, 0.9% at 54.
2. On policies from 55 on, among the u1 x u2 shapes only 24x24 passes (0.6/0.010, 0.7/0.006, 0.6/0.011). The others miss on the share: 32x16 0.023 at 67-89, 20x20 0.022 at 55-66, 16x24 0.023, 24x16 2.2% and 0.021. u1-heavy shapes do not save points for owners.
3. q at 4 base points (0, 0.28, 1, 1.11, 2.5) equals 8 from 40 on: on 24x24 the policies are within 0.5% at 40-54 and identical after 54, where q is not a state; panel 0.3/0.001. The solve halves, 80 to 41 minutes. Before 40, 10-13% on consumption near zero.
4. u3 at 10 points is not converged, and refining it changes the owner's solution. With u3 at 20 (24x24, q at 4), median consumption is 0.009 times entry income at 55 and 0.05 at 60 (0.78 and 0.85 with 10 points), mean liquid saving 24 years of entry income at 66 (6.8), mean consumption 1.57 at 80 (0.89), floored at 95 1.9% (12.3%). On policies u3 at 10 is 497%/0.087 off at 55-66 and 110%/0.053 at 67-89. Fewer points go the other way: 6 and 8 points are 11.8/0.048 and 6.8/0.020 off 32x32 at 55-66, with more floored households (14.3% and 8.6% at 90, against 5.0%).
5. So no owner grid at step 16 is converged at any age. 24x24 looked converged from 55 on only because the 32x32 reference has the same 10 u3 points.
Results, renter:
6. No renter grid passes from 40 on in the panel either (48x24 against 48x48: 2.8/0.002 at 40-54, 2.7/0.022, 1.6/0.035, 1.4/0.018). Before 45 the renter does not converge: consumption at 30 0.277, 0.238 and 0.168 at 24x24, 32x32 and 48x48; on policies every bunched grid is within 1% by 50.
7. On policies from 55 on, against 48x48 at u3 10, every bunched shape passes down to 16x16 (1.1/0.012, 1.0/0.016, 0.2/0.011). The ladder's evenly spaced 16x16, the same number of points, does not (2.2/0.024, 1.9/0.051, 1.7/0.017). 48x24 is no closer than 32x32.
8. u3, against 40 points on 16x16: 20 points pass from 55 on, just (1.9/0.003, 1.3/0.003, 0.7/0.007); 10 do not (4.0/0.007, 3.2/0.027, 1.7/0.024); 10 at power 3 are worse than at power 2 (4.6/0.006, 3.7/0.035, 1.7/0.033); 6 worse still. Retirees sit in the middle of the axis (median u3 0.6-0.7 at 55-67 and 0.33 at 90; owners 0.5 and 0.11), where the power-2 points are widest apart. The floored share halves with each doubling of u3 and has not settled.
9. Smallest renter grid that passes from 55 on: bunched 16x16 with u3 at 20 (18x18x20, 6,480 nodes per age, 14 minutes side by side). The u1 x u2 part was judged at u3 10 and the u3 part on 16x16; the two were not crossed.
Roughness (Quinn's check, the largest second difference over age inside a band): it flags some bad grids and misses others. It catches the ladder's evenly spaced grid at 67-89 (26.4% of income against 0.69% at 32x32), the owner's u3 at 6 at 90-95 (1.17 against 0.34), and the owner's u3 at 20 is the roughest bunched case at 67-89 (2.27). It misses that the ladder's grid is 139% off at 40-54 while smoother there than 32x32 (0.19 against 0.30), and it does not separate the bunched u1 x u2 shapes.
Table, owner (nodes realised on u1 x u2 x u3 x q; nodes per age while q is a state / after; minutes side by side; largest gap on policies by band from 55 on, against 32x32):
    case               nodes        per age          min   55-66       67-89       90-95       from 55
    32x32              34x34x10x9   104,040/11,560   116   reference
    24x24              26x26x10x9    60,840/6,760     80   0.6/0.010   0.7/0.006   0.6/0.011   yes
    24x24, q 4         26x26x10x5    33,800/6,760     41   0.6/0.010   0.7/0.006   0.6/0.011   yes
    32x16              34x18x10x9    55,080/6,120     60   1.6/0.012   1.9/0.023   1.4/0.020   no
    20x20              22x22x10x9    43,560/4,840     48   1.1/0.022   1.6/0.010   1.2/0.013   no
    24x16              26x18x10x9    42,120/4,680     46   1.7/0.018   2.2/0.020   1.5/0.021   no
    16x24              18x26x10x9    42,120/4,680     47   0.9/0.023   1.2/0.010   1.1/0.013   no
    24x24, u3 6        26x26x6x9     36,504/4,056     40   11.8/0.048  10.9/0.058  1.6/0.058   no
    24x24, q 4, u3 8   26x26x8x5     27,040/5,408     33   6.8/0.020   5.5/0.035   3.2/0.025   no
    24x24, q 4, u3 20  26x26x20x5    67,600/13,520    80   89.4/0.317  61.3/0.091  12.2/0.029  no
    ladder 16x16       18x18x10x9    29,160/3,240     42   13.9/0.183  40.4/0.292  40.6/0.144  no
  Before 55 every owner case is outside (bunched cases' policies 69-137% off at 40-54).
Table, renter (q is not a state; against 48x48, the u3 rows against 16x16 with u3 at 40):
    case               nodes        per age   min   55-66       67-89       90-95       from 55
    48x48              50x50x10     25,000     55   reference
    48x24              50x26x10     13,000     28   0.3/0.013   0.3/0.008   0.1/0.011   yes
    32x32              34x34x10     11,560     27   0.2/0.009   0.2/0.007   0.1/0.005   yes
    24x24              26x26x10      6,760     16   0.4/0.011   0.4/0.009   0.1/0.015   yes
    20x20              22x22x10      4,840     11   0.7/0.010   0.6/0.019   0.2/0.018   yes
    16x16              18x18x10      3,240      7   1.1/0.012   1.0/0.016   0.2/0.011   yes
    ladder 16x16       18x18x10      3,240     10   2.2/0.024   1.9/0.051   1.7/0.017   no
    16x16, u3 40       18x18x40     12,960     28   reference for the u3 rows
    16x16, u3 20       18x18x20      6,480     14   1.9/0.003   1.3/0.003   0.7/0.007   yes
    16x16, u3 10       18x18x10      3,240      7   4.0/0.007   3.2/0.027   1.7/0.024   no
    16x16, u3 10 p3    18x18x10      3,240      7   4.6/0.006   3.7/0.035   1.7/0.033   no
    16x16, u3 6        18x18x6       1,944      5   5.8/0.010   4.8/0.052   2.8/0.054   no
Against the expectations:
- Right: q at 4 points is enough. 32x16 is closer than 24x16. The renter does not converge before 40 and 24x24 is outside in the panel. Roughness is no pass rule.
- Wrong: 24x24 is not within the rule of 32x32 from 40 on (expected, as at step 13); the owner's non-convergence reaches about 52. 32x16 does not pass: u1 does not dominate for owners. u3 at 6 fails from 55, not only past 90. Renters need far fewer u1 x u2 points than expected, and u3 at 10 is not enough for either tenure.
- Not foreseen: refining u3 changes the owner qualitatively (hoarding to about 60); the renter's floored share halves with each doubling of u3.
Limits: "passes from 55" is judged on policies at the reference's households, not on the panel the plan named; on the panel every case fails from 40 on, through wealth carried in from younger ages. The u1 x u2 references use u3 at 10. Solve times are side by side. One seed, 10,000 households.
What it means for decision 2: for the owner no grid settles step 16. The answer moves with u1, u2 and u3 in the same direction: finer grids make the owner hoard more, and in the u3 case far into retirement. That is consistent with the old-age floor (maintenance on the current house value, floor 1e-6 times income, gamma 5) acting as a ruin cliff that each finer grid resolves more sharply; step 13, with maintenance on the purchase price, converged at 24x24. Not tested here. A grid chosen now would be chosen again once TODO item 1 is settled. For the renter, from 55 on: bunched 16x16 with u3 at 20 (power 2). For both, q at 4 base points.
Checks run: `run_tests(solve=false)` 0 of 10 failed. No code in `+config`, `+ladder`, `+model` or `+solver` changed.
Commit: this entry with `diagnostics/pension_grid/policy_gaps.m` and `size_table.m`, pushed to main.
Open: TODO item 1 first, then this study again on the owner, with u3 among the axes refined. CLAUDE.md's known limit ("behaviour from age 40 is reliable") does not hold for owners at step 16, and for renters only from about 50; not edited here (this session was limited to diagnostics/ and HANDOFF.md).

### 2026-10-18 Smallest accurate grid at step 16, per axis: expectations before the runs (spec: none; open decision 2 of docs/HANDOFF_2026-10-17.md, asked by Quinn in Claude Code)
Quinn wants the cheapest grid that is still accurate at production (step 16), per axis and per tenure, to set the ladder's numerics. With housing only square u1 x u2 sizes were tested, and u3 and q only by doubling, so the minimum per axis is unknown.
Changed (diagnostics only): `diagnostics/pension_grid/case_params.m` takes `_u3n<n>` and `_qn<n>` (base points on u3 and q). `case_gaps.m` takes the age bands as an optional third argument. New `size_table.m`: per case the realised nodes, the nodes per age while q is a state and after, solve time, entry value, floored share; the largest gap to a reference in mean consumption and the mean liquid equity share in the bands 25-39, 40-54, 55-66, 67-89 and 90-95 (stop rule 2% and 0.02); the same for the equity share of liquid saving; and the roughness, the largest second difference over age inside each band of mean consumption (% of income) and of the equity share (Quinn: a bad grid also shows as a non-smooth profile).
Plan. Every case is `pow3_<N1>x<N2>_lim_u3p2` (grid_pow 3, grid_pow_u2 3, the limit share, u3 at power 2), two MATLAB processes side by side:
1. A: owner 32x32 (reference), then 32x16. B: owner 20x20, 24x16, 16x24, then renter 24x24 and 32x32.
2. On the smallest u1 x u2 shape that passes from 40 on: the owner with u3 at 6 points (power 2: 0, 0.04, 0.16, 0.36, 0.64, 1) and with q at 4 base points (0, 0.28, 1.11, 2.5, with 1 spliced in), each against the same shape at full u3 and q and against the reference. Renter 48x48 (reference) and 48x24.
3. `size_table` for each tenure.
Times, scaled by nodes from 80 minutes at 24x24 (60,840 nodes per age to 54, 6,760 after): owner 32x32 about 140 minutes, 32x16 about 70, 20x20, 24x16 and 16x24 about 55 each; u3 at 6 points and q at 4 points each about 0.6 of the shape's time (q is a state to 54 and its stage is most of the solve). Renter about 14, 24 and 53 minutes at 24, 32 and 48 (as at step 13), 48x24 about 30. About 5 hours in all.
Expectations:
1. Owner 24x24 against 32x32: within the stop rule from 40 on, as at step 13. Outside at 25-39, where owners consume about 0 before 33.
2. Owner shapes: u1 is the axis that pays (at the DC steps 64x32 matched 48x48 and 32x64 was no better than 32x32). So 32x16 passes from 40 on; 24x16 close, perhaps just outside in the share at 55-66; 16x24 fails at 55-66 (step 13 at 16x16 missed by 2.3% in consumption at 66 and 0.06 in the share at 55-62); 20x20 marginal.
3. u3 at 6 points: within the rule to 89, perhaps outside in the share at 90-95 (at step 13 the owner's share past 88 was the part that moved with u3).
4. q at 4 points: q is a state only to 54 and the payment is linear in it, so within the rule from 40 on, any gap at 40-54. Not sure: the axis has no point between 1.11 and 2.5.
5. Renter: no convergence before 40 (the entry value falls with each refinement). From 40 on, 32x32 within 2% in consumption of 48x48, the share perhaps outside at 40-66 (0.05 at step 13); 24x24 outside; 48x24 close to 48x48 if u1 dominates as for owners.
6. Roughness flags a bad grid but is not a pass rule. On the two step-16 owner solves already saved, the ladder's 16x16 grid is 51% off the bunched 24x24 in consumption at 40-54 and is smoother there (largest second difference 0.19% of income against 0.21%); it is rougher only at 67-89 (26.4% against 0.50%). On 10 September a smoothness ranking put grids in the wrong order.

### 2026-10-17 Owner, steps 15 and 16 on the bunched grid: results (spec: none, asked by Quinn in Claude Code)
Follows the expectations entry below (0b445fe).
Ran: `solve_cases('15:owner:pow3_24x24_lim_u3p2')` and the same for 16, two MATLAB processes side by side (the first launch failed on Windows quoting of the string argument; relaunched with char): 82 and 80 minutes. `start_vs_grid('pow3_24x24_lim_u3p2', {'owner'})`; the script now takes a grid-study case and also draws step 16 on the ladder's grid against the case (`levels_16_owner_<case>.png`).
Output (gitignored): solves `ladder/standard_16x16x10x8_gh5/pension_grid/15_box3_owner_pow3_24x24_lim_u3p2.mat` and `16_nibud_owner_...`; figures in `nibud/`: `start_15_owner_<case>.png`, `start_16_owner_<case>.png`, `grid_4p00x_owner_<case>.png`, `grid_4p45x_owner_<case>.png`, `levels_16_owner_<case>.png`.
`model.checks`: off-grid 0, thin u1 0 (55% on the ladder's grid), floored 1.96% (15) and 2.48% (16), against 5.60% and 6.65%; entry value 0.0001 and 0.0000 (0.274 and 0.226 on the ladder's grid). One "matrix close to singular" warning in step 15, as at step 13.
Results:
- Grid effect (solution 16 against 15, same start), largest by band: 25-39 consumption 15.6%, equity share 0.76 (outside the stop rule); 40-54 1.3% and 0.001; 55-66 0.3% and 0.004; 67-89 0.2% and 0.005; 90-95 0.5% and 0.015 (within). On the ladder's grid the owner is outside the stop rule in every band: consumption 4.6%, 4.9%, 9.3%, 23.2%, 2.7%; equity share 0.13, 0.11, 0.29, 0.15, 0.018.
- Starting house 4.45x against 4.00x, mean consumption (the two solutions agree within 0.7 points): -18% at 40, -6.6% at 50, -4.8% at 55, -3.9% at 60, -3.4% from 66 on. In levels, 0.42 to 0.35 times entry income at 40, 1.00 to 0.97 at 66. Liquid saving 9% lower at 30, 3% higher at 50, 7% at 66, 10% at 80 (saving for maintenance on the larger house). Equity share within 0.02 at every age. Floored at 90: 3.7% to 5.0%.
- Before 40 the percentages are of almost nothing: on this grid owners consume about 0 until 33 (mean 0.000 at 25, 0.003-0.005 at 30, 0.09-0.14 at 35 times entry income) and save the rest, the hoarding corner of the step-7 grid study.
- Levels, step 16, this grid against the ladder's (multiples of entry income): liquid saving 6.0 against 1.3 at 40, 7.3 against 2.4 at 55, 6.8 against 3.9 at 66; median consumption 0.25 against 0.48 at 40, 0.88 against 0.62 at 66; equity share of liquid saving 0.00-0.01 from 30 to 60 against 0.16-0.46, then 0.54-0.67 in retirement; floored at 90 5% against 21%. The ladder's grid gets the owner's levels wrong at this step at every age, not only the step-to-step comparison.
Against the expectations:
- Right: within the stop rule from 40 on, outside before 40; no jump in the equity share at 55; the starting-house effect from 55 on within 1-2 points of the standard grid's.
- Wrong: at 40-50 the starting-house effect is much larger than on the standard grid (-18% against -6% at 40). Levels against the standard grid go the other way from the DC steps: liquid saving 2-5 times higher, consumption at 66 about 40% higher, not lower.
- Not foreseen: an equity share of liquid saving of about 0 through working life.
Limits: the two grids compared differ only in the top of u1 and the entry nodes, so agreement between them is a weak convergence test; step 13 (maintenance on the purchase price) was within the stop rule of 32x32 at 24x24, this calibration has not been run at 32x32. Entry values are not readable (floor 1e-6).
Checks run: `run_tests(solve=false)` 0 of 10 failed; `start_vs_grid` on the ladder's results reproduces the numbers of the entry "Steps 15 and 16 (Nibud house): results". No code in `+config`, `+ladder`, `+model` or `+solver` changed.
Commit: this entry with `diagnostics/nibud/start_vs_grid.m`, pushed to main.
Open: whether the ladder's grid carries the bunched placement (decision 2 in docs/HANDOFF_2026-10-17.md); with it, what the owner does before 40 (TODO item 1).

### 2026-10-17 Owner, steps 15 and 16 on the bunched grid: expectations before the runs (spec: none, asked by Quinn in Claude Code)
Quinn: do the converged owner comparison of steps 15 and 16 here.
Plan: `solve_cases(["15:owner:pow3_24x24_lim_u3p2", "16:owner:pow3_24x24_lim_u3p2"])` (diagnostics/pension_grid), two MATLAB processes side by side: grid_pow 3, grid_pow_u2 3, pi_nothing_saved 'limit', grid_pow_u3 2, 24x24 on (u1, u2), u3 10, q 8, gh_n 5. Then the start-against-grid split of `diagnostics/nibud/start_vs_grid.m` on these two solutions. About 1.5 hours per solve: step 13 took 151 minutes at 24x24 with maintenance on the purchase price, where q is a state at every age; here q is a state only to 54, and the standard solves took 60% of step 13's time.
Expectations:
1. Grid effect (solution 16 against 15 from the same start): within the stop rule (2 points in the equity share, 2% in consumption) from 40 on. Possibly outside it before 40 or after 90: step 13 converged at 24x24 with maintenance on the purchase price, and these steps charge it on the current value, which leaves the old-age floor risk in place.
2. Starting-house effect on consumption as on the standard grid within 1-2 points (-9% at 30, -6% at 40, -4 to -5% from 50 on), since there it already agreed between the two solutions.
3. Levels against the standard grid: liquid saving lower at 55-75, consumption at 66 lower by 3-11% (the standard grid's error at the DC steps); no jump in the equity share at 55.

### 2026-10-17 Steps 15 and 16 (Nibud house): results (spec: none, asked by Quinn in Claude Code)
Follows the expectations entry below (1a86291).
Ran: `ladder.run(15)` and `ladder.run(16)` at standard numerics, two MATLAB processes side by side: step 15 52 minutes (renter 575 s, owner 2,518 s), step 16 the same (581 s, 2,536 s). `ladder.compare(16)`. New `diagnostics/nibud/start_vs_grid.m`: h_mult enters the solve only through the grid, so it simulates each saved solution again from both starting houses (same seed and panel; the re-simulation on its own solution and start reproduces the saved panel exactly). Within one solution the gap is the starting house; from one start the gap between solutions is the grid.
Output (gitignored, `ladder/standard_16x16x10x8_gh5/`): `compare_15_16_owner.png`, `compare_15_16_renter.png`, `owner_renter_16.png`; in `nibud/`: `start_15_*.png`, `start_16_*.png`, `grid_4p00x_*.png`, `grid_4p45x_*.png` (renter `grid_4p16x`).
`model.checks`: off-grid 0 and c-bound 25-39 0% in all four arms. Floored: renter 1.43% (15) and 1.69% (16); owner 5.60% and 6.65%. Entry value: renter 0.262 and 0.247; owner 0.274 and 0.226. Owner thin-u1 warning at 55% of ages from 40 on, both steps.
Results, mean consumption, step 16 against 15 (start effect = same solution, the two starts; it agrees between the two solutions within about 1 point):
- Renter: start effect -3.0% at 30, -2.1% at 40, -1.5% from 50 on; grid effect under 1% at every age. Liquid saving +2-5%. Equity share unchanged (0.02 lower at 30).
- Owner: start effect -9% at 30, -6% at 40, -4 to -5% from 50 on (-15% at 25); equity share 0.10 lower at 30, within 0.03 from 40. Liquid saving +6% at 25-30, -5% at 55, about 0 after.
- Owner grid effect, same households and start: consumption -3 to -11% at 30-70 and +22% at 75; liquid saving +20% young, up to +90% at 75; equity share +0.24 to +0.29 at 55-56 and +0.18 at 60-66. The step-to-step owner dashboard is mostly this. The ladder's uniform 16x16 grid is not converged for the owner at this step (as at the DC steps and step 13, docs/HANDOFF_2026-10-17.md).
Against the expectations:
- Right: lower consumption for both, renters about a third of owners; owners' equity share within 0.05 from 40 as a start effect; higher owner net worth; slightly lower retirement consumption (-4 to -5%); lower entry value in every comparison.
- Wrong: liquid saving rises, not falls, while young (both tenures): a larger committed outflow brings more precautionary saving. The owner's consumption fall at 25-30 (9-15%) is larger than the 5-6% written down.
- Not foreseen: the grid effect on the owner is as large as the start effect before 55 and much larger after.
Checks run: `run_tests(solve=false)` 0 of 10 failed. No code in `+config`, `+ladder`, `+model` or `+solver` changed.
Commit: this entry with `diagnostics/nibud/start_vs_grid.m`, pushed to main.
Open: an owner comparison that can be read past 55 needs the bunched grid (grid_pow 3, grid_pow_u2 3, pi_nothing_saved 'limit', grid_pow_u3 2; step 13 converged at 24x24, about 2.5 hours per owner solve), which waits on open decision 2 (the ladder's grid).

### 2026-10-17 Steps 15 and 16 (Nibud house): expectations before the runs (spec: none, asked by Quinn in Claude Code)
Quinn: a dashboard of old against new results with the starting house. Neither step has been solved. Plan: `ladder.run(15)` and `ladder.run(16)` at standard numerics, two MATLAB processes side by side, then `ladder.compare(16)` (step 16 against 15, per tenure). About 1.5 hours.
What differs (arithmetic): owners' house at entry 4.446 times income against 4.0, so mortgage plus maintenance 30.8% of gross income against 27.7% (55% of net against 50%); renters' rent index 4.155 against 4.0, rent 23.3% of gross against 22.4%. h_mult enters the solve only through the grid (the top of u1 falls from 0.600 to 0.551 owners, 0.582 renters, and the entry nodes move); the Bellman problem on the cube is otherwise the same, so the difference is mostly where households start.
Expectations:
1. Owners: lower consumption and liquid saving at 25-55, by roughly the extra outflow (3% of gross income, about 5-6% of consumption), and more households near the floor before 40. Higher net worth from the larger house throughout, most visibly after the mortgage ends at 55. Slightly lower consumption in retirement (maintenance on a larger house) offset by more housing wealth; equity share of liquid saving within 0.05 from 40 on.
2. Renters: the same in the same direction but about a third as large (1% of gross income); within the noise before 40, where the renter does not converge at this grid.
3. Both: a lower value at entry. Differences before 40 are not reliable at this calibration (TODO item 1); read 40+.

### 2026-10-17 Nibud rule: tested against the workbook, and h_mult made a derived field (spec: none, asked by Quinn in Claude Code)
Quinn asked whether the Nibud rule (88b2e28) had been tested properly. It had not been tested enough, and testing found a bug.
Bug: in 88b2e28 `config.derive` overwrote the primitive `h_mult` with the Nibud multiple. `ladder.load` and `ladder.report` switch tenure without deriving again before `ladder.same_calibration`, so a saved step-16 owner result would have been reported as stale (the renter's 4.155 against the owner's 4.446). Switching `h_rule` to 'fixed' on a derived p kept the Nibud multiple instead of 4.
Changed: `h_mult` is now derived, like `kappa`. New primitives `h_rule` ('none', 'fixed' or 'nibud') and `h_fixed` (the multiple under 'fixed'); `nibud_extra` as before. Every reader of `h_mult` is unchanged, and `h_mult = 0` still means no housing. `+config/params.m`, `+config/derive.m`; `+ladder/steps.m` (step 1 `h_rule` 'none', step 7 'fixed' with `h_fixed` 4); `+model/run.m` refuses a p whose `h_mult` does not match its tenure (before, only `kappa` was checked, which is the same for both tenures without a DC pillar); `tests/run_tests.m`; CALIBRATION.md, TODO.md.
Checks run:
- The share table in `config.nibud_lti` is identical to the workbook's (96 x 12). Against the workbook's maximum-mortgage table, 1,151 of 1,152 cells agree to 5.4e-14; the other is the workbook cell at odds with its own share.
- The workbook's calculator run in Excel (copy, read-only, macros off), 360 cases: incomes 15,000-160,000 including 29,999.99, 30,000, 30,000.01, 30,098, 39,763 and 125,000; rates 0.5%-9% including 1.5%, 1.500999%, 1.501%, 3.5% and 3.501%; the increase on and off. Largest gap to the code 8.9e-14. At the model's entry incomes Excel gives factors 4.4460 and 4.1554.
- Steps 1-15, both tenures: every derived field equal (isequaln) to the pre-Nibud commit f96f576, 0 of 30 structs differ.
- `run_tests(solve=false)` 0 of 10 failed; full `run_tests` 0 of 17 failed (`smoke_both_tenures` 82 s). New in it: the tenure switch, the rule switch, 'none', the refusals, and in the production smoke solve that every simulated household enters with H0 = h_mult * Y0 at an exact grid node and the owner's first payment is the annuity on that house.
Not tested: no ladder step solved at standard numerics; behaviour at step 16 is unknown.
Commit: this entry with the eight files, pushed to main.
Open: the choices in the entry below.

### 2026-10-17 House at entry from the Nibud 2026 norms (spec: none, asked by Quinn in Claude Code)
Quinn: add the mortgage loan-to-income assignment from the Nibud workbook (Bijlage financieringslastnormen 2026, version 251110).
Changed:
- `+config/nibud_lti.m` (new): the workbook's box-1 table for borrowers below AOW age (shares by income, EUR 30,000-125,000, and rate bracket) and its calculator: the largest mortgage is the loan whose 30-year monthly annuity costs the share of gross income, plus EUR 17,000 for a single earner above the first row.
- `+config/params.m`: primitives `h_rule` ('nibud') and `nibud_extra` (true). `h_mult` keeps 4.0 for `h_rule = 'fixed'`; 0 still removes housing.
- `+config/derive.m`: under 'nibud', `h_mult` becomes `config.nibud_lti` at the tenure's income at 25 and `r_m`. Refuses 'poly' income.
- `+ladder/steps.m`: step 7 sets `h_rule = 'fixed'`, so steps 7-15 keep 4 times income; new last step 16 `nibud`.
- `tests/run_tests.m`: new check `nibud_rule` (four workbook cells to 1e-12, the increase, each tenure's multiple, steps 7 and 15 at 4, 'poly' refused); `params_derive` sets 'fixed' for its h_mult = 9 case; the step count is 16.
- CALIBRATION.md (new subsection on the rule and its choices), README.md (ladder table), TODO.md (the h_mult row with the open choices; item 1's burden).
What it does at entry (arithmetic, no solve): owners 4.446 times income (share 21.6%), renters 4.155 (share 19.3%); without the increase 4.018 and 3.591. Owner mortgage plus maintenance 30.8% of gross income (27.7% at 4 times); renter rent 23.3% of gross (22.4%), 41% of net.
Verified against the workbook: the formula reproduces 1,151 of the 1,152 cells of its box-1 maximum-mortgage table exactly; the remaining cell (33,000 at up to 1.5%) disagrees with the workbook's own share table, and the code uses the share. Its box-3 table is reproduced exactly as well.
Checks run: `run_tests(solve=false)` 0 of 10 failed; full `run_tests` 0 of 17 failed, about 7 minutes (`smoke_both_tenures` solves production with the Nibud multiples, both tenures). No ladder step solved.
Stale: production changed at step 16 only. Saved results with housing were already stale after the parameter change earlier today.
Commit: this entry with the nine files, pushed to main.
Open, Quinn's call: where the rule enters the ladder (last step, or step 7 in place of the 4); the test rate (`r_m` is real, the norm's rate nominal); box 1 or box 3 (the model deducts no interest: 3.57 owners, 3.34 renters); the 2025 tables, to match the price year; the EUR 17,000 increase; whether renters follow the rule.

### 2026-10-17 beta marked as a placeholder (spec: none, asked by Quinn in Claude Code)
Quinn: mark beta = 0.96 as a placeholder, like the other unsourced inputs.
Changed: CALIBRATION.md, the `beta` row (Larsen et al. 2023 kept as a candidate source, not checked); `+config/params.m`, the comment; TODO.md, section 2, the `beta`, `chi` row. No value changed. This settles the disagreement between CALIBRATION.md and TODO.md noted in the parameters entry below.
Checks run: `run_tests(solve=false)` 0 of 9 failed. Full suite not rerun: comments only in `+config`.
Commit: this entry with the three files, pushed to main.
Open: the reference for `alpha`.

### 2026-10-17 b0 and b_alt marked as placeholders (spec: none, asked by Quinn in Claude Code)
Quinn: keep b0 and b_alt as they are, mark them as placeholders, and note the stale wage divisor.
Changed: CALIBRATION.md, entry state: both rows marked as placeholders, and a paragraph on the divisor (the BKV men's wage, while income is now DHS household-head income, EUR 39,763 owners and 30,098 renters at 25). `+config/params.m`: the two comments. TODO.md, section 2: the row says placeholders. No value changed.
Checks run: `run_tests(solve=false)` 0 of 9 failed. The full suite was not rerun: only comments changed in `+config` (it passed 0 of 16 on the values entry below).
Commit: this entry with the three files, pushed to main.

### 2026-10-17 Parameters: mortgage rate 3.48%, rent share 5.6%, the floor is not calibrated (spec: none, asked by Quinn in Claude Code)
Quinn: taxes off for now; work on the parameters. The mortgage rate is 3.48% in total, not a spread: r (1.15%, NL 3-month interbank, 1982-2024, monthly) plus the mean spread between the MIR home-purchase series and the 3-month interbank rate, 2000-2024. `alpha` is 5.6%, from a government report. `phi_floor` is not a placeholder: it is a numerical bound (1e-4 would also do), not a calibration exercise. All other open inputs are placeholders for now.
Changed: `+config/params.m`: `r_m` 0.0136 to 0.0348, `alpha` 0.06 to 0.056; the comments mark `chi`, `kappa_base` and `theta` as placeholders and `phi_floor` as a numerical bound. `+ladder/steps.m`: the notes of steps 7 and 7b. CALIBRATION.md: the rows of `alpha`, `r_m`, `theta`, `chi`, `kappa_base` and `phi_floor`; the rent burden at entry; the floor paragraph. TODO.md: item 1 (the burden; the floor settled); section 2, the housing row. CLAUDE.md: the known limits wait on the housing outflow, not on a floor.
What it does at entry (arithmetic, no solve): the renter's rent falls from 24.0% to 22.4% of gross income. The owner's annuity payment rises from 4.08% to 5.42% of the purchase price a year, so mortgage plus maintenance goes from 22.3% to 27.7% of gross income. Owners now carry the larger committed outflow.
Stale: every saved result with housing (steps 7 and 7b, and the step-13 grid study) is for the old calibration and has to re-solve. The owner convergence found at 7b (16x16) and 13 (24x24) was measured at 1.36% and is not guaranteed at 3.48%. Steps 1-6 and 9-12 are not affected (the test `nohousing_ignores_housing`: housing parameters leave a solve without housing bit-identical), but `ladder.same_calibration` compares every primitive and calls them stale as well.
Checks run: `run_tests(solve=false)` 0 of 9 failed; full `run_tests` 0 of 16 failed.
Commit: this entry with the five files, pushed to main.
Open, Quinn's call: the reference for `alpha`; `beta` (CALIBRATION.md cites Larsen et al. 2023, TODO.md says it has no source); `b0` and `b_alt` (the divisor is still the BKV wage); whether `same_calibration` skips the housing primitives when `h_mult = 0`, or the saved results without housing get the new values written in.

### 2026-10-17 The grid work of 16-17 October in one document (spec: none, asked by Quinn in Claude Code)
Quinn: document what was found these two days, then start a new session.
Changed: `docs/HANDOFF_2026-10-17.md` (new): where the ladder stands, what was found (the pension steps, housing at 7b and 13, the u3 axis, the grid search, the renter, run times), the decisions open in order, what can be quoted, how to reproduce, where things are. TODO.md: item 1 records what the step-7b and step-13 runs measured; the stale note on `c_floor_frac` (gone since 15 October) is replaced; section 6 adds steps 7b and 13, `grid_pow_u3` and the grid search per step.
Checks run: none (documents only).
Commit: this entry with the two files, pushed to main.
Open, Quinn's call: the six decisions in section 3 of the new document, item 1 (the floor and the rent burden) first.

### 2026-10-17 u3 bunched toward zero at step 13: results (spec: none, asked by Quinn in Claude Code)
Follows the entry below (code and expectations, ab720bb).
Changed: `diagnostics/pension_grid/housing_pdf.m`: the check pages split into one for the u3 axis (rows u3 doubled and u3 power 2, against u3 at 10 evenly spaced points) and one without the grid search; the grid-points page draws the power-2 u3 points beside the base and doubled ones. GRIDS.md: the step-13 paragraph. Output, gitignored: `ladder/standard_16x16x10x8_gh5/pension_grid/housing_13/grid_study_housing_13.pdf` (u3 pages: `housing_5.png` owner, `housing_7.png` renter); solves `pension_grid/13_pension_<arm>_pow3_16x16_lim_mop_u3p2.mat`.
Checks run:
- Full `run_tests`: 0 of 16 failed, 7.9 minutes beside the owner solve.
- Step 13 at 16x16 with u3 at power 2. `model.checks`: owner offgrid [0 0 0 0], floored 0, c_bound_25_39 0, thin_u1_40 0, entry value 0.8132 (0.8145 evenly spaced, 0.8150 doubled), one "matrix close to singular" warning; renter offgrid [0 0 0 0], floored 0.06%, c_bound_25_39 0, entry value 0.5986 (0.6011, 0.5814).
- Solve times: owner 73 minutes (4,369 s), beside the renter solve and the tests for its first 16 minutes, alone after; renter 8 minutes beside the owner. Evenly spaced 16x16: 70 and 7.4 minutes.
- Owner, gap to u3 doubled, equity share of liquid saving: power 2 within 0.010 up to 92, then 0.011 at 93, 0.014 at 94, 0.024 at 95. Evenly spaced: 0.019 at 88, 0.081 at 93, 0.138 at 95. Consumption within 0.62% at every age (evenly spaced 0.40%).
- Owner, liquid savings: power 2 holds 2-5% more than u3 doubled at 40-80 (0.19 years of income at 67), evenly spaced 1-4% (0.10 years). At 88-95 power 2 is within 9%, evenly spaced 16-213% (small levels: under 0.07 years of income either way).
- Renter, gap to u3 doubled: power 2 like evenly spaced at 26-66 (share 0.064 at 38 against 0.062; consumption 3.1% at 26 with either); closer in retirement (share 0.011 against 0.025 at 95; consumption 0.2% against 0.7%; savings within 2% against up to 11% from 50 on).
- Against the expectations:
  - Right: the owner's share at 88-94 is within 0.02 of u3 doubled; at 95 it is 0.024, inside the 0.02-0.04 written down; 26-87 within the stop rule; the same solve time.
  - Wrong: power 2 is not worse for renters. Their gap to u3 doubled at 38-42 is the number of points between 0.1 and 0.5, which neither 10-point grid changes. Not foreseen: power 2 moves the owners' liquid savings at 40-80 more than even spacing does.
Reading:
- Power 2 at 10 points passes the stop rule against u3 doubled at every age but 95, where it misses by 0.004. There u3 doubled is the coarser of the two near zero: 30% of owners at 95 sit below 0.05, where u3 doubled has no point and power 2 has two. The share at 95 rises as the first point above zero falls: 0.77 at 0.111 (evenly spaced), 0.91 at 0.053 (doubled), 0.93 at 0.012 (power 2). The steps shrink from 0.14 to 0.02, so power 2 is probably the closer one.
- The price is in the middle of the axis, where owners sit from 40 to 80: liquid savings move about twice as much as with even spacing, though consumption and the share stay within the stop rule.
- Power 2 at 20 points (`_u3x2_u3p2`, owner about 2.5 hours) would show whether that is enough at both ends.
Commit: this entry, pushed to main.
Open, Quinn's call:
- Whether to use `grid_pow_u3` = 2 at step 13 and after (the default stays 1).
- Whether to run power 2 at 20 points as the reference.
- Saved results carry no `grid_pow_u3`, so `ladder.same_calibration` now calls every saved result a different calibration: steps 6 and 9-12 at standard numerics, current before this change, now draw the `ladder:stale` warning, and `ladder.run` would re-solve them (7 and 7b were already stale, without `pi_nothing_saved`). Adding `grid_pow_u3 = 1` to the `p` of those saved files would be exact, since 1 gives the old grid bit for bit and u3 collapses without housing. Not done.

### 2026-10-17 u3 bunched toward zero at step 13: code, and expectations written before the runs (spec: none, asked by Quinn in Claude Code)
Follows the step-13 results below: u3 at 10 evenly spaced points misses the equity share of the oldest owners, whose pot falls below the first point above zero (0.11).
Changed:
- `+config/params.m`, `+utility/build_state_grids.m`: new primitive `grid_pow_u3` (default 1). u3 is placed at lo + (hi - lo) * s^grid_pow_u3 for s evenly spaced on [0, 1]; above 1 the points bunch toward u3 = 0. At 1 the axis is the old one bit for bit. The collapsed axes ({0, 1} without housing or without a DC pillar) are untouched. CALIBRATION.md (numerics table) and GRIDS.md (placement table), one line each.
- `+utility/auto_state_grids.m`: `grid_pow_u3` joins the placement fields left out of the pilot's cache key, as `grid_pow` and `grid_pow_u2` are.
- `diagnostics/pension_grid/case_params.m`: suffix `_u3p<n>` (grid_pow_u3 = n).
Checked before the runs: at power 2 the 10 points are 0, 0.012, 0.049, 0.111, 0.198, 0.309, 0.444, 0.605, 0.790, 1. `ladder.same_calibration` tells power 1 from power 2. `run_tests(solve=false)`: 0 of 9 failed.
Where households sit on u3 (u3 doubled, 16x16): owners 0.02 at 26, 0.3-0.75 (5th-95th) at 40-67, then falling: below 0.11 for 32% at 88, 63% at 93 and 73% at 95; below 0.05 for 20% at 93 and 30% at 95. Renters 0.2-0.85 from 40 on, below 0.11 for 2% at 95.
Runs: step 13 with maintenance on the purchase price, limit share, power 3 on u1 and u2 at 16x16, u3 at 10 points with power 2 (`pow3_16x16_lim_mop_u3p2`), gh_n 5, standard numerics otherwise. Owner, then renter beside it. Compared with u3 evenly spaced at 10 points (`pow3_16x16_lim_mop`) and at 20 (`_u3x2`).
Expectations:
- Owner, 88-95: within 0.02 of u3 doubled in the equity share of liquid saving, where evenly spaced 10 points were 0.02-0.14 off. Below 0.11 power 2 has three intervals and u3 doubled two, with nearly the same points at 0.05 and 0.11. A gap of 0.02-0.04 is possible at 93-95 for the fifth to third of owners below 0.05, where u3 doubled has no point and power 2 has two; it would not say which of the two is closer to the answer.
- Owner, 26-87: within the stop rule of u3 doubled (0.02 in the share, 2% in consumption). From 40 to 80 owners sit at 0.3-0.75, where power 2 has points 0.14-0.19 apart against 0.11, but evenly spaced 10 points were already within 0.4% and 0.007 of u3 doubled there.
- Renter: not better than evenly spaced. From 40 on renters sit at 0.2-0.85, where power 2 is coarser. The share gap to u3 doubled 0.05-0.10 at 40-66 (0.056 evenly spaced), consumption within 1% from 40. Before 40 nothing converges (the rent obligation, TODO item 1).
- Solve time as the evenly spaced 16x16, since the number of points is the same: owner about 70 minutes, renter about 7, beside a second process.

### 2026-10-17 Grid test at step 13, housing with the pension: results (spec: none, asked by Quinn in Claude Code)
Follows the entry below (expectations).
Changed: `diagnostics/pension_grid/housing_pdf.m` takes a step (`housing_pdf(cover, 13)`); for step 13 it adds a u3 row to the grid-points page and a page per check (u3 doubled, no grid search) against the same grid; the 7b pages rebuilt with it are unchanged. GRIDS.md: a section on housing and housing with the pension. Output, gitignored: `ladder/standard_16x16x10x8_gh5/pension_grid/housing_13/grid_study_housing_13.pdf`; solves `pension_grid/13_pension_<arm>_<case>.mat`. Interim versions were sent to Quinn as runs landed.
Checks run:
- Step 13, maintenance on the purchase price, limit share, bunched (power 3 on both axes), gh_n 5, standard numerics otherwise. `model.checks` on every solve: offgrid [0 0 0 0]; floored 0 for the owner, 0.03-0.07% of renter household-years. MATLAB printed a few "matrix close to singular" warnings per solve (15 in all), as in one 7b solve; source not traced.
- Owner, largest gaps to 32x32 by age band 26-39 / 40-66 / 67-95 (consumption; equity share of liquid saving; liquid savings in years of income):
  - 16x16: 1.2 / 2.3 / 1.3%; 0.003 / 0.055 / 0.009; 0.05 / 0.14 / 0.30.
  - 24x24: 0.7 / 0.8 / 0.4%; 0.008 / 0.013 / 0.005; 0.03 / 0.05 / 0.11. Within the stop rule at every age.
  - Entry value 0.815, 0.807, 0.802 at 16, 24, 32.
- Renter, largest gaps to 48x48:
  - 16x16: 77 / 4.7 / 2.1%; 0.54 / 0.16 / 0.03; 0.8-0.9 years.
  - 24x24: 57 / 3.0 / 1.1%; 0.54 / 0.09 / 0.02.
  - 32x32: 37 / 1.7 / 0.7%; 0.47 / 0.05 / 0.01; 0.3-0.4 years.
  - Entry value 0.60, 0.54, 0.47, 0.27 at 16, 24, 32, 48. On each finer grid young renters consume less and save more.
- u3 at 20 points against 10, on 16x16:
  - Owner: consumption within 0.4%, savings within 0.10 years. Share within 0.01 up to 86, then 0.02 at 88, 0.08 at 93 and 0.14 at 95 (the pot is under a tenth of pot plus house there, below the first u3 point above zero, 0.11).
  - Renter: 3.0 / 0.2 / 0.7%; share 0.06 at 38-40, within 0.02 from 50, in the same direction as a finer grid on u1 and u2.
- Without the grid search before fmincon, against the same grid with it:
  - Renter: within the stop rule at 16x16 (0.3%, 0.009, 0.08 years) and at 32x32 (0.1%, 0.006, 0.02 years).
  - Owner at 16x16: consumption within 0.2%, savings within 0.01 years, share of liquid saving 0.03 at 26-39 and within 0.004 after. The mean share (savers or not) is 0.35 off at 27. Entry value 0.812 against 0.815.
- Solve times, two processes at a time (the owner's 32x32 alone for its last 2.5 hours):
  - Renter 16, 24, 32, 48: 7, 14, 24, 53 minutes.
  - Owner 16, 24, 32: 70, 151, 236 minutes.
  - u3 doubled: renter 13, owner 143.
  - No grid search: renter 3.8 (16x16) and 13 (32x32), owner 37.
- Against the expectations:
  - Right: the owner's smallest passing grid is 24x24; the renter behaves as at 7b; u3 doubled takes about twice as long.
  - Wrong: u3 at 10 points is not enough for the share of the oldest owners. Without the grid search the gap is smaller than expected (only the mean share of young owners who barely save) and the time saving larger (half, not a third). The owner solves were faster than expected (1.2, 2.5, 3.9 h against 1.5, 3, 5 h).
Reading:
- The bunched grid carries over to step 13 for the owner: 24x24 is converged, between step 7b (16x16) and the DC steps without housing (48x48).
- The renter waits on TODO item 1, as at step 7b. The pension does not change that.
- Two numerical options are worth a decision before the ladder's numerics are set:
  1. Bunch u3 toward zero (not built; u3 is always evenly spaced).
  2. Drop the grid search at step 13, which halves the time at almost no cost in the answer here. That differs from the DC steps on 12 October, so it is step-specific.
Commit: this entry, pushed to main.
Open, Quinn's call:
- The defaults of `pi_nothing_saved` and the ladder's grid placement (as before).
- Whether to add a power option for u3.
- Whether the ladder keeps the grid search.

### 2026-10-16 Grid test at step 13, housing with the pension: expectations written before the runs (spec: none, asked by Quinn in Claude Code)
Quinn: run step 13 now; report the convergence and the run time of each grid; quadrature always 5 nodes; if time is left, the stability with and without the grid search before fmincon. The plan is `docs/prompts/step13_grid_test.md` (6d5dd58).
Changed: nothing in the model or the solver. The page script of the 7b test gets a step argument (next entry).
Runs: step 13 (`pension`) with maintenance on the purchase price and the limit share, power 3 on both axes, gh_n 5, standard numerics otherwise (10,000 households, the ladder's seed). Two processes. A: owner 16x16, 24x24, 32x32. B: renter 16x16, 24x24, 32x32, 48x48; u3 doubled at 16x16, renter then owner; without the grid search at 16x16, renter then owner, and renter 32x32. Reference per household: the finest grid solved.
Expectations:
- Owner: from 40 on, 24x24 or 32x32 is the smallest grid within the stop rule (0.02 in the equity share, 2% in consumption) of the finest. That is between step 7b (16x16 passed) and the DC steps without housing (48x48 needed): the house moves owners away from the corner where the pension made the DC steps hard, but the pot's share of pension plus house now varies across owners. Before 40 within 2% at 24x24.
- Renter: as at 7b. From 40 on consumption converges slowly (a few percent between 16x16 and 48x48, falling with the grid); the equity share and liquid savings do not reach the stop rule by 48x48. Before 40 nothing converges (the rent obligation, TODO item 1).
- u3 doubled: within the stop rule of u3 at 10 points for both households. The pot's share of pot plus house moves slowly along a life, and the value is smooth in it.
- Without the grid search: consumption within 1%; the equity share off by 0.1 or more at a few ages, most at 26-30 and in the last years, as at the DC steps on 12 October.
- Solve times, beside a second process: owner 16x16 about 1.5 h, 24x24 about 3 h, 32x32 about 5 h; renter 16x16 about 10 min, 48x48 about 1.5 h; u3 doubled about twice the 16x16 time; without the grid search about a third shorter.

### 2026-10-16 Does the bunched grid work with housing? Step 7b: results (spec: none, asked by Quinn in Claude Code)
Follows the entry below (code and expectations).
Changed: `diagnostics/pension_grid/housing_pdf.m` (new): the pages of this test (a robustness page per household with rows for the ladder's grid, the bunched grids and the log-wealth grids; the largest gap to the finest grid and the solve time against grid size; the 7b owner against the grid points). Interim versions were sent to Quinn as runs landed. Output, gitignored: `ladder/standard_16x16x10x8_gh5/pension_grid/housing/grid_study_housing.pdf`; solves `pension_grid/07b_annuity_<arm>_<case>_lim_mop.mat`.
Checks run:
- The no-DC speed-up: identical answers (entry value 0.68036960878573 renter, 0.95109216285305 owner); `run_tests` (full) 0 of 16 failed.
- Step 7b, maintenance on the purchase price, limit share, standard numerics otherwise. Reference bunched 64x64; for the owner log-wealth 64x48 lies within 0.4% in consumption, 0.004 in the equity share of liquid saving and 0.03 years of income in liquid savings of it. Largest gaps to the reference, ages 26-39 / 40-66 / 67-95 (consumption; share; savings in years of income):
  - Owner, the ladder's grid (evenly spaced 16x16, 100% stored, the 15 October sensitivity run): 3.1 / 1.6 / 5.1%; 0.001 / 0.027 / 0.128; 0.19 / 0.52 / 0.76.
  - Owner, bunched 16x16: 1.6 / 0.4 / 0.3%; at most 0.008; at most 0.06. 24x24: 0.8 / 0.2 / 0.1%. 32x32: 0.6 / 0.2 / 0.1%. 48x48: 0.3 / 0.1 / 0.1%.
  - Owner, log-wealth 16x16: 0.8 / 0.6 / 2.6%; 0.010 in retirement; 0.30 in retirement. 32x32: 0.4 / 0.1 / 0.5%.
  - Renter, from 40 on (before 40 the consumption gap is in the thousands of percent on every grid: young renters on fine grids consume almost nothing): bunched 16 / 24 / 32 / 48: 6.7 / 5.1 / 3.7 / 1.6% at 40-66, share 0.35 / 0.20 / 0.13 / 0.05; log-wealth 16 / 32 / 64x48: 6.3 / 3.4 / 1.0%, share 0.32 / 0.14 / 0.06; liquid savings still 0.4 years of income off at 48x48 and 64x48. The ladder's grid: 8.0%, 0.45.
- Solve times, two or three runs at a time (alone about a third shorter), owner: bunched 16, 24, 32, 48, 64: 10, 16, 30, 77, 133 minutes; log-wealth 16, 32, 64x48: 7, 27, 117 minutes. Renter: 1.5, 2, 3, 5, 9 minutes; log-wealth 1, 2.6, 6 minutes.
- Against the expectations: speed-up identical and about half, as expected; the two rules converge to the same answer, as expected. Wrong: the owner's smallest passing bunched grid is 16x16, not 32x32; log-wealth is worse, not better, in old age at 16x16 (2.6% against 0.3%); the renter does not agree across grids from 40 on, because the savings built by hoarding young renters carry into mid-life.
Reading: the bunching carries over to housing. Power 3 on both axes with the limit share works for the pension steps and for the housing step that converges, and at small grids it beats the log-wealth rule. What no grid rule fixes is economics: the renter's rent obligation with the near-zero floor (TODO item 1), and, at step 7 as calibrated, maintenance on a growing house. Step 13 (housing with the pension) is not run: it waits on the housing decision, and its grid is about ten times larger than 7b's (the pension-against-house axis is live; owner 16x16 has 29,160 points, about an hour per solve).
Commit: this entry with the page script, pushed to main.
Open: whether to run the step-13 grid test (maintenance on the purchase price) overnight, Quinn's call; the defaults of `pi_nothing_saved` and the ladder's grid placement, as in the entries of the overnight results.

### 2026-10-16 Does the bunched grid work with housing? Step 7b: code, and expectations written before the runs (spec: none, asked by Quinn in Claude Code)
Quinn: will the pension steps' grid fix keep working when housing and later features come back, or does the bunching need to change, since a log-wealth grid worked for housing; run the test now, and also the smaller grids, with how long they take.
Changed:
- `+solver/bellman_step_lna.m`: the exact speed-up of the DC steps gets its mirror case. Without a DC pillar A = 0 on every path, so u3 = 0, and the u3 = 1 nodes with u2 > 0 (a pension pot the household cannot have) are copied from u3 = 0 instead of solved. Steps 7, 7b and 8 should solve in about half the time with unchanged answers.
- `diagnostics/pension_grid/case_params.m`: rule `logw` (the step-7 study's log-wealth rule) and the suffix `_mop` (maint_on_purchase); `case_load.m`: 'standard' for housing steps and 'standard_mop' (the saved sensitivity run).
Runs: step 7b with maintenance on the purchase price (the variant without the ruin cliff), standard numerics otherwise (gh_n 5, 10,000 households, the ladder's seed), limit share, renter and owner: power 3 on both axes at 16x16, 24x24, 32x32, 48x48 and 64x64; log-wealth at 16x16, 32x32 and 64x48. Reference: power-3 64x64, with its gap to log-wealth 64x48 as the uncertainty. Two processes, smallest grids first.
Expectations:
- The speed-up: V on the solved nodes, the simulated summary and the entry value identical to the 15 October solves of this variant; owner solve time about half. Checked before the runs: identical for both (entry value 0.68036960878573 renter, 0.95109216285305 owner); 50 s against 79 s (renter), 350 s against 617 s (owner).
- Power 3 and log-wealth converge to the same answer from 40 on; their finest grids within the stop rule (0.02 in the equity share, 2% in consumption) of each other.
- Owner: the smallest power-3 grid within the stop rule from 40 on is 32x32. Log-wealth is at least as good in old age, where house-rich retirees sit at 50-5,000 years of income and log-wealth has more points. Before 40 the owners' answer moves more (the 16 October comparison of the uniform 16x16 grid with log-wealth 32x32 showed 2.9% in consumption at 26-39).
- Renter: from 40 on every grid agrees within the stop rule, as in the step-7 renter study; before 40 no grid need converge (the rent obligation, TODO.md item 1).
- Owner solve times with the speed-up, one process alone: about 5, 10, 20, 40 and 75 minutes at 16, 24, 32, 48 and 64 points per axis; renters a few minutes each.

### 2026-10-16 The grid study of the pension steps in five pages (spec: none, asked by Quinn in Claude Code)
Quinn asked for the essence of the grid study in clear, familiar graphs.
Changed: `diagnostics/pension_grid/essence_pdf.m` (new) draws a summary page and five pages in the comparison-page style (black = the finest grid with its 10th-90th band): (1) step 12 owner, figures.robustness with a row before the fix (evenly spaced 16, 32, 64) and a row after (bunched 16, 32, 48, limit share); (2-3) steps 12, 11, 10, 9 and 6 for owner and renter, liquid savings, consumption with income, and the equity share of liquid saving, the ladder's standard grid against the finest and the fixed grid (bunched 48x48); (4) step 10 at 55-80, the equity share stored where nothing is saved, 100% against the limit share on the same grid; (5) step 12 owner, households against the grid points on both axes, evenly spaced and bunched at 16 points each. `+figures/robustness.m`: optional sixth argument naming the black reference (default, as before, the step as solved in the ladder). Output, gitignored: `ladder/standard_16x16x10x8_gh5/pension_grid/essence/grid_study_essence.pdf`.
Checks run: the pages were looked at; `run_tests(solve=false)`: 0 of 9 failed. Figures printed on the pages, owner: liquid savings at 60 on the standard grid +37% (step 12), +23% (11), +16% (10), +23% (9), +0% (6); consumption at 66 +9.0%, +10.0%, +9.2%, +5.1%, -0.3%; at step 12, 0-1 grid points of the standard grid and 2-3 of the bunched one where the middle 90% of retirees are (67-85) on the u1 axis, 4-5 against 9-10 on u2; step 10 savers' equity share at 66, 0.36/0.39 (renter/owner) with 100% stored against 0.03/0.01 with the limit share.
Commit: this entry with the script, pushed to main.
Open: as in the entry of the overnight results below.

### 2026-10-16 An interactive dashboard of the pension grid study (spec: none, asked by Quinn in Claude Code)
Quinn asked what was actually done overnight and for a more intuitive dashboard, mainly to see how grid size changes the results before and after the fix, and what the fix is.
Changed: `diagnostics/pension_grid/export_dashboard.m` (new): writes the grid study's numbers from the saved solves as four JSON row files (life-cycle paths by step, household, grid and age; gaps to each step's finest grid; where households sit by age; the grid points). The dashboard is a private claude.ai artifact, "Pension grid study" (https://claude.ai/artifact/3oYdyKJHjfTPUkHKxBBMdP), built on those files: pick a step (6, 9-12), a household and a measure (liquid savings, consumption, equity share of liquid saving); one line per grid size before the fix and after it on the same scale; the answer at one age against grid size, before and after; where the grid points sit against where households are, old and bunched grid at 16 points each; the step-10 stored equity share with 1 and with the limit share on the same grid; what was done overnight. No model or solver code changed.
Checks run: the repo script reproduces the four uploaded files byte for byte. Headline figures it shows, renter/owner, liquid savings at 60 and consumption at 66 against the finest grid: old grid +29.1/+36.5% and +6.2/+9.0% at step 12, fix at 32x32 +3.4/+4.7% and +0.8/+1.1%; step 6 within 0.3%. `run_tests(solve=false)`: 0 of 9 failed.
Commit: this entry with the script, pushed to main.
Open: as in the entry below.

### 2026-10-16 Grid study of step 7b with maintenance on the purchase price (spec: none, asked by Quinn in Claude Code)
Quinn asked for the grid study with maintenance on the purchase price, to show the owner is now roughly grid-invariant. Owner only (maintenance does not reach renters).
Changed: no code. Solves in `ladder/standard_16x16x10x8_gh5/grid_design/maint_on_purchase_study/` with the pages `robust_maint_on_purchase.png`, `compare_grids_maint_on_purchase.png` and `ruin_1-3_*_maint_study.png` (gitignored). Scripts in the session scratchpad (not kept).
Checks run (standard numerics: gh_n 5, 10,000 households, same draws; reference log-wealth 32x32 of the entry below; largest gaps in the mean equity share and mean consumption):
- current 16x16 (run 4): entry 0.951; 26-39 pi 0.002, C 2.9%; 40-66 0.015, 1.6%; 67-95 0.146, 4.9%.
- log-wealth 16x16 (814 s): entry 0.921; 0.002, 0.6%; 0.009, 0.6%; 0.016, 2.1%.
- power 2 16x16 (1,387 s): entry 0.933; 0.002, 1.5%; 0.004, 0.5%; 0.014, 0.6%. Within the stop rule at every age.
- current 32x16 (5,336 s): entry 0.940; 0.003, 2.1%; 0.010, 1.0%; 0.011, 2.3%.
- q axis: current 16x16 with 16 base q nodes against 8 (5,563 s): consumption within 0.26% at every age, equity share within 0.021 (one point at 40-66; 0.008 elsewhere), entry 0.95112 against 0.95109, no q lookups off the grid.
- Floored 0, `c_bound_25_39` 0 and off-grid 0 on every grid; the reference's entry value is 0.918.
- Not run to the end: power 2 32x32. Another session's MATLAB jobs shared the machine from 00:35 (the solves ran at a third to a half of full speed), and the merge of its work into this checkout at about 04:00 changed solver files while that solve was running, so it was stopped. The four solves above finished before the merge; the merged code keeps their behaviour by default (`pi_nothing_saved = 'one'`, no age-following grid).
Reading: with maintenance on the purchase price the owner is roughly grid-invariant. Three grid systems at 16x16 agree with log-wealth 32x32 within about 2% in consumption and 0.02 in the equity share at every age, except the coarse current grid after 67, and refining that grid (32x16) brings it within 0.011 and 2.3%. Under maintenance on the current value the same grids differed by 0.9 in the equity share and a factor of 2,000 in the entry value.
Commit: this entry, pushed to main.
Open: a second fine grid (power 2 32x32) to confirm the reference; whether maintenance on the purchase price becomes the model (TODO.md item 1).

### 2026-10-16 Pension steps 9-12 again and the grid study of the DC branch: results, and numerical fixes (spec: none, asked by Quinn in Claude Code)
Follows the entry below (code and expectations). Overnight run, until 7 am.
Changed (on top of cdb2ddf):
- `+config/params.m`, `+solver/bellman_step_lna.m`: new primitive `pi_nothing_saved`, 'one' (the default, the rule of 15 October) or 'limit': where nothing is saved (c = 1) the solver stores the share of a vanishing saving (`limit_share`: the best share when 1e-6 of liquid resources is saved) instead of 1. The value is the same either way. CALIBRATION.md (numerics table), `docs/SOLVER_BOUNDS.md` section 7.
- Points that follow age, opt-in: `p.grid_nodes.u1_age` and `u2_age`, one column per period. `+utility/grid_at.m` (new) returns a period's points; `+utility/build_state_grids.m` builds them; `+solver/bellman_step_lna.m` solves period t on its points and reads next year's value on period t+1's; `+simulate/paths_lna.m`, `+solver/solve_lifecycle_lna.m`, `+model/checks.m` (coverage) and `+figures/compare.m` read each year's points. With fixed grids nothing changes. GRIDS.md (new sections: the DC steps; points that follow age), TODO.md section 6.
- `diagnostics/pension_grid/`: rules u1only, u2only, age, ageq, age32 (`age_grid`), suffixes `_lim` and `_gh7`; `case_load` adds the equity share of liquid saving weighted by saving (households that save nothing carry no weight); `report.m` draws every page and the PDF.
Checks run:
- Identity. The u3 speed-up (main code, steps 6, 9 and 10 at standard): every solved node and the simulated panel identical, `ce_entry` equal to 17 digits. The age-grid code with fixed grids (steps 12 owner and 10 renter): identical. After the merge, `ladder.run` of steps 6 and 9-12 at standard again (so the saved results carry the new primitive): summaries and `ce_entry` identical to the baseline for all ten arms; V differs only at the unreachable u3 = 0 nodes; solve time 35-41 s per DC arm, against 73-80 s before the speed-up.
- `run_tests` (full): 0 of 16 failed, on the fix branch and again on the age-grid branch (which contains it). `run_tests(solve=false)` on the merged main (de2f294): 0 of 9 failed.
- Baseline, `ladder.run` of steps 6 and 9-12, standard numerics (uniform 16x16, gh_n 5, 10,000 households): against 13 October, within 0.015 in the mean equity share (0.005 at steps 6, 9 and 11) and 0.3% in consumption from 40 on at steps 6, 9, 11 and 12; floored 0; off-grid 0 except step 10 (24 renter, 31 owner of 760,000 household-years below the u1 axis, as on 13 October); `ce_entry` renter/owner 1.115/1.175 (6), 1.070/1.103 (9), 1.073/1.105 (10), 1.075/1.108 (11), 1.046/1.086 (12), unchanged. Step 10 differs: the mean equity share at 66 is 0.37/0.45 instead of 0.02/0.01. Cause: a 66-year-old with no liquid wealth (the grid corner u2 = 1) consumes everything; the 15 October rule stores pi = 1 there, while the share their first euro would take is 0, since the annuity is all stock; savers at u2 about 0.97 interpolate the 1. With the limit share, same grid: 0.01 at 66; consumption and savings change by 0.1%. At step 12 the rule changes nothing (0.001). Under uniform refinement the artefact grows (0.97 at 66 on uniform 32x32 and 64x64).
- Grid study: every DC step and arm on uniform 32x32 and 64x64 as is, and with the limit share on power-3 grids (`grid_pow` 3, `grid_pow_u2` 3) at 16x16, 32x32, 48x48 and 64x64; same households and seed. Largest gaps to power-3 64x64 (renter/owner), ages 40-66 | 67-95; consumption, liquid savings in years of income, equity share of liquid saving:
  - Step 9: standard grid C 3.3/5.1% | 2.6/3.5%, X 0.29/0.33 | 0.36/0.40, share 0.045/0.081. Uniform 64x64 C 0.2/0.4%. Power-3 32x32 C 0.4/0.6% | 0.2%, X 0.03 | 0.03, share 0.002/0.009.
  - Step 10: standard C 10.7/9.2% | 5.6/6.9%, X 0.29/0.26 | 1.03/1.27, share 0.09. Uniform 64x64 C 1.2% | 0.7/0.9%. Power-3 32x32 C 0.6/0.5% | 0.2%, X 0.02 | 0.03, share 0.063/0.043 (at 63-66).
  - Step 11: standard C 8.1/10.0% | 4.1/3.9%, X 0.34/0.34 | 0.36/0.32, share 0.06/0.11. Uniform 64x64 C 0.6/0.8% | 0.2%, share 0.09/0.15 at 65. Power-3 32x32 C 0.6/0.7% | 0.1%, X 0.03 | 0.01, share 0.03/0.04. Power-3 48x48 (owner) C 0.3% | 0.0%, X 0.01, share 0.009.
  - Step 12: standard C 6.2/9.0% | 3.4/4.5%, X 0.59/0.64 | 1.65/1.77, share 0.14/0.19 | 0.16/0.14. Uniform 64x64 C 0.7/1.1% | 0.3/0.4%, X 0.06/0.07 | 0.13/0.15. Power-3 32x32 C 0.7/1.1% | 0.4/0.5%, X 0.07/0.08 | 0.14/0.16, share 0.03/0.04. Power-3 48x48 C 0.2/0.3% | 0.1%, X 0.02 | 0.04, share 0.007/0.007. Power-3 16x16 C 2.8/3.8%.
  - In percent of the converged level, the standard grid's liquid savings at 60 are 16-37% too high at steps 9-12 (about double at 66 at steps 10 and 11); step 12 owner, in multiples of entry income: standard 4.60, power-3 16/32/48/64: 3.93/3.52/3.41/3.37, uniform 64x64 3.51. Consumption at 66 is 3-11% too high.
  - Step 10 against power-3 96x96 (renter/owner): power-3 16/32/48/64 give C 2.8/2.7%, 0.7/0.6%, 0.4/0.3%, 0.2/0.2% at 40-66 and share 0.15, 0.060/0.042, 0.027/0.016, 0.004/0.004; X within 0.01 at 64x64. The standard grid: C 10.8/9.2% | 5.7/6.9%, X 1.04/1.28 in retirement. Uniform 64x64: C 1.3/1.2%, X 0.12/0.16.
  - Power-3 48x48 against 64x64 at steps 9 and 11 (renter/owner): C 0.2/0.2% and 0.2/0.3% at 40-66, 0.0% in retirement; X 0.01; share 0.002/0.004 and 0.007/0.009.
- Control, step 6 (no pension) against uniform 128: standard grid C 1.2/1.3% at 26, 0.3% at 40-66, 0.6% in retirement; X at most 0.09; share 0.03. Power-3 32x32 the same or closer (C 0.1% at 40-66, share 0.011). Converged either way.
- Which axis. Step 12 owner, 32x32 against power-3 64x64: power 3 on u1 only C 3.0% | 1.4%, on u2 only 3.1% | 1.2%, on both 1.1% | 0.5%. Step 10 owner against power-3 32x32: u1 only fixes retirement savings (X 0.03), u2 only the 63-66 share (0.041); each alone leaves 4.4-4.5% at 66. With power 3 on both, the points are needed on u1: 64x32 C 0.2% | 0.1%, share 0.019; 32x64 C 1.1%, the same as 32x32.
- Quadrature, 7 against 5 nodes on power-3 32x32: C at most 0.2%, share at most 0.027 (step 10 owner, step 12 both).
- Points that follow age (step 12, a power-3 16x16 pilot places 60% of each age's points in the band where households live that year): with even spacing in log(1 - u2) C 5.9/9.6% off at 67 (points crowd at u2 above 0.98); halfway to the households' percentiles (`ageq`) at 16x16 C 1.9% | 1.5%, share 0.024 | 0.027 (owner), better than power-3 16x16 in working life, but late-retirement liquid savings fall 80-100% too fast at 24x24. Not ready.
Reading: the standard grid is not converged at any DC step, and the pension is the cause: the same grid is converged at step 6. With the pension, households hold 15-60 years of income in total resources in retirement and little liquid saving beside the pot (u2 near 1); the uniform axes have no point between 14.8 and 1,250 years of income and two above u2 = 0.93 (`occ_<arm>.png`). The coarse grid makes liquid saving too attractive: too much saved at every age, too much consumed at 66, and a dip in the pre-retirement equity share that is not there. Directions between steps survive, sizes around retirement do not. Two numerical fixes, neither touching the model: the limit share (removes the step-10 artefact) and points bunched toward low u1 and u2 near 1. With both, refinement is monotone at every DC step; 32x32 is within the stop rule in consumption everywhere (largest 1.1%) and within 0.03-0.06 in the share at 62-66; 48x48 is within it in consumption and savings at every DC step, and in the share everywhere except step 10 renter (0.027 against 96x96). Once both axes are bunched, extra points pay most on u1 (64x32 about as good as 48x48).
Pages (gitignored), `ladder/standard_16x16x10x8_gh5/pension_grid/`: `pension_grid_study.pdf` (cover, convergence per arm, occupancy per arm, a robustness page per DC step and arm and for step 6, the steps overlaid as solved and on power-3 64x64, each DC step against its parent on power-3 64x64); the solves are `NN_<step>_<arm>_<case>.mat` beside it.
Commit: this entry, with the code and scripts above, merged into main and pushed.
Open, for Quinn:
1. `pi_nothing_saved`: make 'limit' the default. Recommended: it differs from 'one' only where the first euro would not go to stocks, which happens with a stock-heavy pot.
2. Numerics for the DC steps: power 3 on both axes, 48x48 (or 64x32) to quote numbers, 32x32 for working runs. `ladder.numerics` sets only `grid_dims` and `gh_n`, so carrying the placement there is a code change, and every saved ladder result would re-solve.
3. Points that follow age: keep as an option or remove.
4. The new primitive makes `ladder.same_calibration` flag every result saved before it as stale (the field is missing), so `ladder.run` re-solves them and `ladder.load` warns.

### 2026-10-16 Pension steps 9-12 again, and a grid study of the DC branch: code, and expectations written before the runs (spec: none, asked by Quinn in Claude Code)
Quinn: run the pension steps again; on 13 October they were not grid-converged around retirement. Do a full grid study to see whether problems remain, and if the pension fund is what makes the grid unstable, look overnight (until 7 am) for fixes that do not change the economics.
Changed:
- `+solver/bellman_step_lna.m`: without housing the u3 = 0 nodes with u2 > 0 are copied from u3 = 1 instead of solved. They describe a house the household cannot have; u3 = 0 is reached only with A = H = 0, where u2 = 0. Every reachable node and the simulated panel are unchanged; the DC steps solve in about half the time. GRIDS.md says so.
- `diagnostics/pension_grid/` (new): `case_params` (a step on a named grid: `<rule>_<N1>x<N2>[_gh<n>][_makima]`, rules uniform, pow2, pow3, u1pow3 through the existing primitives `grid_pow` and `grid_pow_u2`), `solve_cases`, `case_load`, `case_gaps` (largest gaps by age band, 26-39, 40-66, 67-95), `convergence_figure` (gap to a reference against grid points, per step and rule), `occupancy_figure` (where households live on u1 and u2 by age, against each grid's points).
Expectations:
- Steps 6 and 9-12 re-run at standard numerics on today's code (consumption search from the floor to all liquid resources, the CE objective, pi = 1 where nothing is saved): within about 0.01 in the mean equity share and 1% in consumption of the 13 October results. Without housing the old 1%-of-W consumption bound did not bind.
- Uniform refinement (32x32, 64x64) moves the DC steps by more than the stop rule (0.02 in pi, 2% in C) at 55-70: the pre-retirement liquid equity share rises and retirement liquid savings fall, as on 13 October. Step 6 stays within the stop rule. That would make the pension what breaks convergence.
- Grids bunched toward low u1 and u2 near 1 (pow2, pow3) converge faster than uniform ones: at 32x32 within the stop rule of their 64x64 solves, and the uniform 64x64 close to them.
Order: baseline (`ladder.run` 6, 9-12, compare, overlay); identity check of the solver change on steps 6, 9, 10; then the grid cases, step 12 first, both arms, then 10, 11, 9 and 6.
Commit: cdb2ddf, pushed to main before the runs.

### 2026-10-16 Old and new mortgage, and maintenance on the purchase price, on log-wealth 32x32 (spec: none, asked by Quinn in Claude Code)
Quinn asked for the old against the new mortgage, and the new mortgage against maintenance on the house value at purchase, on the larger log-wealth grid of the step-7 grid study (34 x 34 points), with dashboards, bankruptcy, value functions and the income decomposition.
Changed: `+figures/dashboard.m`: the footnote and panel (l) name the mortgage contract and the base of maintenance (the old footnote said the payment is a rate on the current value). Results and pages in `ladder/standard_16x16x10x8_gh5/grid_design/log32_mortgage_maintenance/` (gitignored): three dashboards, two step dashboards, `overview_log32.png`, `ruin_1-3_*_7_vs_7b` and `ruin_1-3_*_maint`. The step-7 solve is the one of 15/16 October on today's code (`grid_design/07_housing/owner_logwealth_32x32.mat`); it reproduces the 15 October dashboard (floored 0.06%, entry 1.78e-5).
Checks run (owner, log-wealth 32x32, standard numerics, 10,000 households, same draws):
- 7, old mortgage: 258 s, floored 0.062% (67+ 0.138%), entry 1.78e-5. Consumption at 25/30/35/40: EUR 5 / 45 / 3.0k / 18.3k; liquid savings 194k at 30, 944k at 45, 1.37M at 66.
- 7b, real annuity, maintenance on the current value: 966 s, 9 q nodes, floored 0.029% (0.065%), entry 2.9e-4, off-grid 0. Consumption EUR 42 / 583 / 7.4k / 25.4k; savings 193k at 30, 936k at 45, 1.42M at 66. Housing cost at 45 11.4k (7: 18.4k).
- 7b with maintenance on the purchase price: 2,542 s, floored 0 at every age, entry 0.918, off-grid 0. Consumption EUR 33.1k / 41.7k / 49.3k / 56.4k; savings 1.5k at 30, 136k at 45, 476k at 66; liquid equity share about 1 to 50, 0.71 at 66.
- Convergence, from saved solves (current 16x16 against log-wealth 32x32, standard numerics): with maintenance on the purchase price the largest gaps are pi 0.002, C 2.9% at 26-39; pi 0.015, C 1.6% at 40-66; pi 0.15, C 4.9% at 67-95; entry 0.951 against 0.918. With maintenance on the current value: pi 0.93, C over 500 times at 26-39; pi 0.91, C 108% at 40-66; pi 0.56, C 52% at 67-95; entry 0.839 against 2.9e-4.
Reading: on the fine grid the new mortgage changes little; young owners still hoard and consume almost nothing until 35. Charging maintenance on the purchase price removes the hoarding corner and every floor state, and the answer then barely moves between the coarse uniform grid and log-wealth 32x32: within the stop rule at 40-66, close at 26-39, 0.15 in the equity share after 67. Maintenance proportional to an appreciating house that cannot be sold is what makes step 7 and 7b non-convergent; the mortgage contract is not.
Commit: this entry, pushed to main.
Open: whether maintenance on the purchase price (or another way out, such as equity release) becomes the model (TODO.md item 1); the q refinement for maintenance on the purchase price; the old-age equity-share gap with maintenance on the purchase price.

### 2026-10-15 Mortgage state, run 4: maintenance on the purchase price (spec: The mortgage as a state variable, q = H0/H)
Changed: no code. `ladder.sensitivity('annuity')`, standard numerics (16x16x10x8, gh_n 5, 10,000 households, the reference's seed): step 7b with `maint_on_purchase = true`. Files and pages in `ladder/standard_16x16x10x8_gh5/sensitivity/` (gitignored): `07b_annuity_<arm>_maint_on_purchase_1.mat`, `sens_07b_annuity_<arm>_maint_on_purchase_1.png` and `sens_07b_annuity_<arm>_maint_on_purchase.png`.
Expected: renter bit-identical; owner maintenance a constant EUR 2.4k; floor states mostly gone (4.64%, 67+ 10.35%); more consumption in retirement, less saving for old age; entry value above 0.84; off-grid 0; 13-15 minutes; the spike at 67 smaller or gone.
Checks run:
- Renter: bit-identical to 7b (V, c_pol, pi_pol, summary); 79 s.
- Owner: 18 x 18 x 2 x 9 nodes, q a state at every age, 617 s. Housing cost EUR 8.9k a year to 54 (maintenance 2.4k plus the annuity 6.5k), 2.4k from 55 (7b: 13.3k at 54, 21.3k at 85, 30.9k at 95). Floored 0.0000 at every age (7b 4.64%; 67+ 10.35%). `c_bound_25_39` 0. `ce_entry` 0.951 (0.839). Off-grid [0 0 0 0].
- Owner means against 7b: consumption +3% at 25, +9% at 30, +8% at 40, +7% at 66, +9% at 75, +19% at 85, +55% at 95; liquid savings EUR 18 against 5.8k at 30, 54k against 100k at 40, 438k against 593k at 66, 145k against 207k at 85; liquid equity share 0.82 against 0.76 at 60, 0.75 against 0.81 at 85. Consumption at 65-69 76.5k-81.5k-81.5k-81.2k-80.9k: the spike at 67 is gone (7b 76.9k, 97.2k, 80.4k at 66-68).
Reading: all as expected. Maintenance growing with the house is what produces the old-age floor states at steps 7 and 7b; with it fixed on the purchase price no owner reaches the floor, they save a quarter to a third less for old age and consume more at every age, most in late retirement. The spike at 67 goes with the floor states, which fits the grid explanation of the run-3 entry (the corner nodes are no longer degenerate when a house alone is no longer ruinous).
Commit: this entry, pushed to main.
Open: the plan's q refinement for this test (8 against 16 base nodes; q is a state at every age and the median q at 85 is 0.13, between the nodes 0.051 and 0.204), not run. Whether maintenance belongs on the purchase price is Quinn's modelling choice (TODO.md item 1).

### 2026-10-15 Part of the grid study again with the real annuity; old against new mortgage on the same grids (spec: none, asked by Quinn in Claude Code)
Quinn asked to rerun part of the step-7 grid study with the new mortgage, to see the convergence and whether the value-function problems go away; then, within ten minutes, the best grid system at a smaller and a larger size and one solve of each other grid system; then a comparison of the old and new mortgage on the same grids from saved solves. Maintenance is on the current house value throughout (7b as in the ladder).
Changed: `diagnostics/grid_design/solve_grids.m` (option `step`), `compare_grids.m` (options `step`, `res`, `gd`; titles carry the step's number), `diagnostics/step07/ruin_figures.m` (figures 1-3 handle q: the value and the housing bill at the median simulated q per age, each solve's own bankruptcy line; figures 4-5 stop with an error when q is a state). Results under `ladder/standard_16x16x10x8_gh5/grid_design/` (gitignored); scripts for the runs in the session scratchpad (not kept).
Checks run:
- A standard-numerics batch (gh_n 5, 8 q nodes, 10,000 households) was stopped at Quinn's request after five solves: 7b log-wealth 16x16 (376 s, floored 0.53%, entry 0.657); step 7 log-wealth 16x16 (84 s, 0.61%, 0.313), current 32x16 (162 s, 3.00%, 0.323), log-wealth 32x32 (258 s, 0.06%, about 1e-5), log-wealth 64x48 (680 s, 0.03%, about 1e-5). Off-grid 0 and `c_bound_25_39` 0 in all.
- Step-7b owner, quick numerics (gh_n 3, 4 base q nodes), against log-wealth 32x32: log-wealth 16x16 108 s, floored 0.53% (67+ 1.18%), entry 0.66; log-wealth 32x32 315 s, 0.05% (0.11%), 0.0011; current 16x16 100 s, 4.44% (9.92%), 0.87; power 2 16x16 100 s, 0.34% (0.76%), 0.58; edge-aligned 16x16 97 s, 0.50% (1.12%), 0.65. Largest gaps to log-wealth 32x32 at 67-95 (pi, C): power 2 0.09, 18%; edge 0.11, 24%; log-wealth 0.12, 25%; current 0.53, 48%. At 40-66: 0.54-0.57 and 28-32% for the three, 0.80 and 45% for current. At 26-39 all are far off (pi 0.92, consumption 100 times the reference's, whose young owners consume almost nothing). No spike at 67 on any of them.
- Old against new on the same grid, standard numerics (floored, 67+, entry; mean liquid savings at 45; mean equity share at 45): current 16x16: 7 4.78%, 10.6%, 0.68, 263k, 0.84; 7b 4.64%, 10.4%, 0.84, 189k, 0.99. Current 32x16: 7 3.00%, 6.7%, 0.32, 385k, 0.72; 7b 2.92%, 6.5%, 0.76, 278k, 0.90. Log-wealth 16x16: 7 0.61%, 1.35%, 0.31, 448k, 0.52; 7b 0.53%, 1.18%, 0.66, 372k, 0.65. Consumption at 30: 34k against 40k, 29k against 37k, 25k against 33k.
Reading: on every grid the new mortgage raises early consumption, lowers saving before 55, raises the equity share before 55, and leaves old age and bankruptcy almost unchanged; the two coincide from 55. The entry value is two times higher on the finer grids. It does not remove the value-function problem: with the finer log-wealth grid the young owners still hoard and the entry value collapses (7b 0.66 to 0.0011, step 7 0.31 to about 1e-5), and the coarse grid still values old-age ruin as comfortable beyond the edge. The q axis converges; the income axis does not. The retirement spike is gone on log-wealth, power and edge grids. Among grid systems at 16x16, power 2 is closest to log-wealth 32x32, as in the step-7 study.
Commit: this entry, pushed to main.
Open: run 4 (maintenance on the purchase price); the grid placement and the owner's housing economics (TODO.md item 1).

### 2026-10-15 Mortgage state, run 3: grid check of the step-7b owner; the consumption spike at 67 (spec: The mortgage as a state variable, q = H0/H)
Quinn chose the run: the 7b owner on [32 16 10 8] and on [16 16 10 16], standard otherwise (gh_n 5, the reference's 10,000 households and seed), against the saved 7b owner on the stop rule (2 points in the mean equity share, 2% in mean consumption). The 7b renter is bit-identical to step 7, so it was not re-run. Quinn also asked why consumption spikes at 67.
Changed: no code. Solves saved as `ladder/standard_16x16x10x8_gh5/robustness/07b_annuity_owner_g32x16x10x8_gh5.mat` and `..._g16x16x10x16_gh5.mat`, page `robust_grid_07b_annuity_owner.png` there (gitignored). Scripts in the session scratchpad (not kept).
Checks run:
- Reference [16 16 10 8]: 366 s, floored 4.64% (67+ 10.35%), `c_bound_25_39` 0, `ce_entry` 0.839, off-grid [0 0 0 0].
- q axis doubled, 18 x 18 x 2 x 17 nodes, 655 s: floored 4.65% (67+ 10.38%), `c_bound_25_39` 0, `ce_entry` 0.842, off-grid [0 0 0 0]. Largest gaps: 25-39 pi 0.001, C 0.48%; 40-66 pi 0.004, C 0.26%; 67-95 pi 0.002, C 0.62%. Passes the stop rule at every age, as expected: 8 base q nodes are enough.
- Income axis doubled, 34 x 18 x 2 x 9 nodes, 744 s: floored 2.92% (67+ 6.52%), `c_bound_25_39` 0, `ce_entry` 0.758, off-grid [0 0 0 0]. Largest gaps: 25-39 pi 0.012, C 8.5% (age 25); 40-66 pi 0.21 (57), C 4.3% (40); 67-95 pi 0.25 (86), C 27% (95). Liquid savings 61% higher at 40 and 26% at 66. Fails the stop rule at every age band. Expected: smaller early-life gaps than at step 7 (pi yes, consumption no) and a pass from 40 to about 70 (no: the equity share already differs by 0.21 at 57); the floored share and the entry value fell, as expected.
- The spike at 67, owners only (renters flat: 57.8k, 57.3k, 57.2k at 66-68): mean consumption 76.9k, 97.2k, 80.4k at 66-68 at 7b (step 7 the same). The 18% of owners with c_frac above 0.25 at 67 are house-rich (house 68% of total wealth, against 48%): c_frac 0.14, 0.42, 0.24 and consumption 49k, 164k, 61k at 66-68; the other 82% are flat (83.0k, 82.7k, 84.7k). Retirement cuts income by a third and moves most owners into the first u1 cell, 0.0002-0.0402, total wealth of 5,000 to 25 times income (88% of the spikers at 67). At the node u1 = 0.0002, from 67 on, the stored c is 1 at u2 = 0.667 and 0.733 and about 0 at the neighbouring u2 nodes (at 66: about 0). The spikers sit at u2 = 0.715 and take about 0.4 of their policy from those c = 1 nodes; a year later their liquid wealth is spent, u2 is 0.81 and they are past them. With the income axis doubled the jump from 66 to 67 falls from 26% to 11% (79.4k to 88.5k).
Reading: the q axis is converged; the owner is not converged on the income axis, as at step 7, and in old age that is the same weakness: no grid points between 25 and 5,000 times income. The spike at 67 is that weakness, not economics. Why the solver stores c = 1 at those corner nodes is not shown; the likely reason is that linear interpolation over the wide cell overvalues being left with only a house. The log-wealth grid from the step-7 grid study should remove it (not run).
Commit: this entry, pushed to main.
Open: run 4 (maintenance on the purchase price, `ladder.sensitivity('annuity')`), after Quinn; the u1 grid (TODO.md item 1, docs/HANDOFF_2026-10-15.md).

### 2026-10-15 Mortgage state, run 2: step 7b against step 7 (spec: The mortgage as a state variable, q = H0/H)
Quinn set `q_hi` to 2.5 (the tail numbers of the entry below).
Changed: `+config/params.m` (`q_hi` 2.5), `+utility/build_state_grids.m` (its fallback), CALIBRATION.md (numerics table, with the tail numbers), `docs/SOLVER_BOUNDS.md` section 4, README (7b owner's solve time).
Checks run:
- `run_tests` (full): 0 of 16 checks failed (`smoke_both_tenures` now passes).
- `ladder.run(7)` again, since `q_hi` is a primitive and the saved step 7 was flagged stale: V, c_pol, pi_pol, summary and `ce_entry` bit-identical to the run with `q_hi` 2, both tenures.
- Run 2, `ladder.run('annuity')` and `ladder.compare('annuity')`, standard numerics (16x16x10x8, gh_n 5, 10,000 households). Pages in `ladder/standard_16x16x10x8_gh5/` (gitignored): `compare_07_07b_owner.png`, `compare_07_07b_renter.png`, `owner_renter_07b.png`, `mortgage_07_owner.png`, `mortgage_07b_owner.png`.
- Renter: bit-identical to step 7 (V, c_pol, pi_pol, summary); floored 0.22%, `ce_entry` 0.680, off-grid 0, 99 s.
- Owner: 18 x 18 x 2 x 9 nodes, 366 s (step 7: 83 s). Mortgage payment EUR 6.49k at every age 25-54 for every household, 0 from 55; present value 1.0000 times the loan (step 7: mean 18.64k at 54, p10 9.87k, p90 29.42k; present value 1.71). Floored 4.64% (step 7 4.78%): 25-39 0, 40-66 0.02% (0.08%), 67+ 10.35% (10.63%). `c_bound_25_39` 0. `ce_entry` 0.839 (0.680). Off-grid [0 0 0 0].
- Owner, means, 7b against 7: consumption +27% at 25, +16% at 30, +9% at 35, +5% at 40, +1% at 50, equal from 54 (largest gap 23.4% at 26); liquid savings EUR 5.8k against 40.3k at 30, 99.9k against 177.4k at 40, 376k against 388k at 54, equal at 60 (510k), 1-3% lower at 75-95; housing cost 13.3k against 25.5k at 54, equal from 55; home equity 186.7k against 123.3k at 40, equal from 55; liquid equity share 0.997 against 0.841 at 40 (largest gap 0.16 at 43), equal from about 55.
- Against the expectation: payment, present value, renter, old-age floor states (near step 7), entry value (up), bound and off-grid as expected. Not as expected: the consumption gain is at 25-45, not 40-54, and liquid savings before 55 are lower, not higher, and only equal after. Not foreseen: the liquid equity share stays near 1 to about 50 instead of falling to 0.84.
Reading: with the payment tied to the house price, owners saved early against payments that rise with house prices and held less equity against that risk. With a fixed real payment both motives go: they consume more when young, save less until 55, hold more equity, and from 55, when the mortgage is paid off, the two steps coincide. The old-age floor states are untouched, as they come from maintenance on a growing house.
Commit: this entry, pushed to main.
Open: run 3 (grid check of the 7b owner, with the q refinement 8 against 16 base nodes) and run 4 (maintenance on the purchase price), each after Quinn.

### 2026-10-15 The mortgage as a state variable: code, tests, regression, run 1 (spec: The mortgage as a state variable, q = H0/H)
Changed, in the plan's order:
- `+config/params.m`, CALIBRATION.md: primitives `mortgage` ('annuity'), `maint_on_purchase` (false), a fourth `grid_dims` entry (8), `q_hi` (2), `grid_pow_q` (2); the "homothetic approximation" paragraph replaced by the contract and the q state.
- `+config/derive.m`: checks the two switches, derives `p.q_live`. `+utility/build_state_grids.m`: the q axis, a single node q = 1 where q is never a state, `grid_nodes.q`; `+config/insert_anchor_nodes.m` splices q = 1; `+utility/welfare_anchor.m` reads at q = 1; `+utility/grid_override.m` takes four numbers, and three is an error that says so.
- `+solver/bellman_step_lna.m`: housing cost per q node; q' = q/R_H at each shock node; 4D interpolation where the continuation depends on q, 3D on one slice otherwise; one slice solved and copied where q enters neither this year nor later; the terminal period loops over q. `+solver/solve_lifecycle_lna.m`: N1 x N2 x N3 x N_q x T, warm start per slice, probe at q = 1.
- `+simulate/paths_lna.m`: `sim.q`, `sim.h_cost`, payment m q H (= m H0), maintenance by the switch, 4D lookups where the solution depends on q, `n_offgrid_q`. `+model/summarize.m` (housing cost from `sim.h_cost`; home equity H - owed LTV H0 for the annuity), `+model/checks.m` (`offgrid` has four entries; entry value at q = 1), `+model/run.m`.
- Ladder: step 7 sets `mortgage = 'proportional'`; new step `annuity`, shown as 7b (step field `num`, `ladder.number`), varying `maint_on_purchase`. Numbers given to `ladder.run(8)` and the like, and in file names and titles, are the shown numbers; `ladder.index` maps them to positions, and internal calls go by name. Numerics have four dims; folders are `<numerics>_16x16x10x8_gh5`. Grid variants in `robustness` and `grid_axes` have four entries; `grid_axes` adds 'q x2' when the owner has q.
- Figures: `compare` (policy panel at q = 1), `mortgage` (labelled by contract; the annuity lies on the real annuity), `panel_data` (maintenance from `h_cost`), `dashboard` (step number). `utility.occupancy` and `auto_state_grids` stop with an error when q is a state; `grid_from_occupancy` needs nothing (it places one axis). `diagnostics/step07/solve_cases.m`, `diagnostics/grid_design/solve_grids.m`: four-entry grids.
- Tests: four-entry grids, step loops by name; new `q_axis_where_live`, `annuity_flat_prices`, `annuity_payment_pv`; `ladder_branches` checks 7b's parents, numbers and contracts; `nohousing_ignores_housing` also changes `mortgage` and `maint_on_purchase`; `figures_render` draws the mortgage figure.
- Docs: README, TODO.md (item 1 decision 2 settled for this contract; the mortgage-balance item removed; bequest netting; paper note), GRIDS.md, `docs/SOLVER_BOUNDS.md` section 4, CLAUDE.md.
Checks run:
- `run_tests(solve=false)`: 0 of 9 checks failed.
- `run_tests` (full): 1 of 16 checks failed, `smoke_both_tenures`: the production owner (grid [6 5 4 3], gh_n 3, 500 households) had 1 of 38,000 policy lookups with q above q_hi = 2 (off-grid [0 0 0 1]). The first run reported it as "Formatted arguments must be scalar", a bug in the off-grid warning, fixed. All new checks passed: flat prices within 1e-10, payment and its present value within 1e-12.
- How often q passes q_hi at standard numerics, from the simulator's own draws (10,000 households, ages 25-54, no solve): step 7b owner 2 of 300,000 household-years above 2 (max 2.037), none above 2.5; step 8 the same (max 2.061).
- Regression against 6f61c85 (a git worktree), step 7, both tenures, grid [8 6 6] (new code [8 6 6 4]), gh_n 3, 2,000 households: V, c_pol and pi_pol bit-identical (the new arrays carry a singleton q dimension), all 26 numeric panel fields, the summary, `ce_entry` (renter 0.79687019074520726, owner 0.8752164955205356) and `c_bound_25_39` identical; off-grid 0.
- Run 1, `ladder.run(7)`, standard numerics (16x16x10x8, gh_n 5, 10,000 households). Expected: owner floored 4.8%, entry 0.68; renter 0.36%, 0.67 (15 Oct, before the CE objective and the equity-share rule). Got: renter floored 0.22% (67+: 0.49%), `c_bound_25_39` 0, `ce_entry` 0.680, off-grid 0, 99 s; owner floored 4.78% (40-66: 0.08%, 67+: 10.6%), `c_bound_25_39` 0, `ce_entry` 0.680, off-grid 0, 83 s.
Commit: this entry, pushed to main.
Open: `q_hi` (2 leaves 2 q lookups off the grid at step 7b, 2.5 none), Quinn's choice before run 2; then runs 2-4. The scripts in `diagnostics/grid_axes`, `diagnostics/objective` and `diagnostics/retirement` index the steps by number as positions; they need `ladder.index` before they are run again.

### 2026-10-15 Prompt for the mortgage as a state variable, saved, not started (spec: none, asked by Quinn in Claude Code)
Quinn asked for a proposal to replace the proportional mortgage with a proper state, the ratio of the purchase price to the current house value, q = H0/H_t, and then to save it as a prompt for later. Decisions taken: a real annuity on the purchase price; step 7 keeps the proportional mortgage and a new step directly after it ("7b", step 8 by position) switches to the annuity, so production inherits it; a test with maintenance on the purchase price, run as the new step's sensitivity; no bequest netting yet.
Changed: `docs/prompts/mortgage_state.md` (new): the model change, the q axis, new primitives (`mortgage`, `maint_on_purchase`, a fourth `grid_dims` entry, `q_hi`, `grid_pow_q`), the ladder change, the code changes file by file, checks, the runs with expectations and runtime estimates. No code changed.
Checks run: none. MATLAB is not installed in this session's container. Range of q from the house-price process (0.1th-99.9th percentile): 0.53-1.44 at 29, 0.25-1.59 at 39, 0.10-1.45 at 54, 0.01-0.70 at 100; annuity factor 0.0408, payment 0.163 times entry income.
Commit: this entry, pushed to claude/exciting-cori-8r29np, then cherry-picked onto main.
Open: the implementation, and whether the new step keeps the number 8 or shows as 7b.

### 2026-10-15 Nothing saved: 100% in equity (spec: Quinn in Claude Code)
Fixes the equity-share spikes of the entry below while keeping the consumption upper bound at 1.
Changed: `+solver/bellman_step_lna.m`: wherever the chosen c is 1, and at grid points below the floor, the stored equity share is 1 instead of whatever the search returned (0). The value is unchanged, since with nothing saved the share has no effect. `docs/SOLVER_BOUNDS.md` sections 3 and 7.
Checks run: `run_tests`: 0 of 13 checks failed. Steps 1-6, every arm, standard numerics, today's defaults ('ce' objective), against 12 October: largest gap in the mean equity share 0.0000-0.0022 (it was 0.03-1.00 without the rule); mean consumption within 0.06%. At every grid point where c = 1 before the last age, the 12 October share was at least 0.99, except one grid corner no household reaches at these steps (no liquid savings, all wealth in a pension pot that steps 1-6 do not have), where it was 0. PDF: `ladder/standard_16x16x10_gh5/zero_savings/zero_savings.pdf` (gitignored).
Not re-run: step 7 and steps 9-12. Their saved solves since this morning (objective comparison, step-7 new-bounds PDF) still have the spikes.

### 2026-10-15 Equity-share spikes at steps 1-6: the upper bound of 1 on consumption (diagnosis only, asked by Quinn in Claude Code)
Quinn saw the equity share jump between 0 and 1 at steps 1-6 in the objective comparison.
Cause: a0ae181, the consumption search's upper bound raised from 1 - 1e-6 to 1 of liquid resources. Where the household is borrowing-constrained it now consumes everything and saves nothing, so the equity share affects nothing and the search returns 0, the first point it tries. Before, it saved 1e-6 of its resources and the share took the limit as savings go to zero, 100% at these nodes. At steps 1-6 the nodes at exactly c = 1 went from 1.3% (only the last age) to 27-31% of the grid, and every grid point whose share moved by more than 0.1 is one of them. Interpolating between them passes the 0 on to simulated households, including some who do save (step 2, age 99: mean share 0.97 before, 0.41 now). Ages 26-29 and 88-99 are hit.
Check run: step 5 owner, standard numerics, today's code with only the upper bound back at 1 - 1e-6 (new lower bound kept): mean equity share within 0.0002 of 12 October at every age (0.0089 at grid points), against gaps up to 1.0 with the bound at 1. Consumption within 0.004% and values within 3e-6 in certainty-equivalent terms either way. Figure: `ladder/standard_16x16x10_gh5/upper_bound/compare_05_owner_upper_bound.png` (gitignored). The grid at steps 1-6 is unchanged since 12 October (18x2x2) and the new lower bound does not move the share.
Not changed: the code. Every solve since a0ae181 carries this, including the objective comparison and the step-7 new-bounds PDF.
Open: Quinn's choice: put the upper bound back at 1 - 1e-6 (recommended), or keep 1 and pick the share at c = 1 from c = 1 - 1e-6.

### 2026-10-15 The fmincon objective in certainty-equivalent units (spec: none, suggested by the coauthor, asked by Quinn in Claude Code)
The suggestion: minimise -(rhs/rhs_seed)^(1/(1-gamma)) instead of -rhs divided by the median |V| of next period. A monotone transform, so the same optimum, on a scale of order one at every node (-1 at the seed) and finite as consumption goes to zero.
Changed: `+solver/bellman_step_lna.m`: primitive `fmincon_objective`, 'ce' (new, default) or 'utility' (as before); after fmincon the Bellman value is recomputed at its answer and kept only if it beats the sweep, as before. `+config/params.m`, CALIBRATION.md. `diagnostics/objective/compare_objective.m` (new): every ladder step run in this chat (1-7, 9-12), each arm, solved with both objectives at standard numerics, everything else equal (including the consumption bounds of 15 October); an overlay per arm, a summary page and `ladder/standard_16x16x10_gh5/objective/objective_comparison.pdf` (gitignored).
Checks run: `run_tests(solve=false)`: 0 of 8 checks failed (the full suite was not run, at Quinn's request). Largest gaps over ages 26-95, ce against utility:
- Mean liquid equity share where mean liquid savings are at least 0.05 years of income: at most 0.001 at steps 1-6, 0.006 at step 7, 0.007-0.018 at steps 9, 11, 12, 0.06-0.08 at step 10 (all-stock pot, at 75 and 88-90). Over all ages the gap reaches 0.4-1.0 at several steps, always at 26-31 where liquid savings are about zero and the equity share applies to nothing.
- Mean consumption: at most 0.1% at steps 1-6, 0.01% (renter) and 0.9% (owner, at 88) at step 7, 0.02-0.5% at steps 9-12.
- Grid points whose value differs by more than 0.1% in certainty-equivalent terms: none at steps 1-6; at step 7 0.64% higher and 0.23% lower (renter), 0.18% higher and 0.75% lower (owner); at steps 9-12 at most 0.3% higher and 0.78% lower. Where the two differ, the new objective more often ends at the lower value. The median difference is 1e-8 to 1e-6.
- Solve time unchanged (step 1 19 -> 11 s; steps 7 and 9-12 66-75 s either way).
- The first run crashed MATLAB (access violation) while drawing an overlay, after its solves were saved; the script now solves first and draws in a separate session.
Reading: the change makes no material difference at these steps, and where it does differ it is slightly more often worse. The scaling the suggestion targets is not what moves the answers here. Whether it explains the interior-point against active-set gap at the production calibration has not been tested.
Commit: this entry, pushed to main.
Open: Quinn's choice of the default ('ce' now, or back to 'utility').

### 2026-10-15 Step-7 diagnostics with the new consumption bounds, in one PDF (spec: none, asked by Quinn in Claude Code)
Changed: `diagnostics/grid_design/report_bounds.m` (new): figures 1-3 for the current grid coarse (16x16) against fine (32x16), figures 1-4 for the current against the log-wealth grid, figures 1-3 for the new against the old bounds, the overlay and robustness pages and two dashboards, in `ladder/standard_16x16x10_gh5/grid_design/lbfloor/step7_new_bounds.pdf` (11.7 MiB, gitignored). `ruin_figures` takes `fig1_pair=true` to draw only the first pair in figure 1.
Checks run: step-7 owner solves with the new bounds (consumption from the floor to all liquid resources), standard numerics: current 16x16 89 s, floored 4.8% (5.5% with the old bounds), entry 0.68 (0.66); current 32x16 140 s, 3.0% (3.9%), 0.32 (0.034); log-wealth 16x16 76 s, 0.61% (2.0%), 0.31 (0.13); log-wealth 32x32 277 s, 0.06% (0.59%); power 2 32x32 283 s, 0.72% (3.8%). No household at the lower bound in any of them. The first PDF build stopped on a graphics timeout while a second MATLAB session was drawing; rebuilt alone.
Reading: with the new bounds the current grid still does not converge (coarse and fine differ in the bankruptcy rate by age and the value at entry), and its old-age blind spot is unchanged, since the bounds change choices, not where the grid has points. Log-wealth 64x48 and 128x96 and the renter have not been re-solved with the new bounds.
Commit: this entry, pushed to main.

### 2026-10-15 Consumption search: the consumption floor as the lower bound (spec: none, asked by Quinn in Claude Code)
Changed: `+solver/bellman_step_lna.m`: the search runs from c = phi_floor * Y / LW (consuming the floor) to 1; the old bound, 1% of total wealth capped at half of liquid resources, is gone with its primitive `c_floor_frac` (`+config/params.m`, CALIBRATION.md). `+simulate/paths_lna.m` records the new bound; `model.checks` `c_bound_25_39` is now the share of 25-39 who choose to consume only the floor. `diagnostics/step07/ruin_figures.m` reads either bound. Saved ladder results predate this and the upper-bound change.
Checks run: `run_tests(solve=false)`: 0 of 8 checks failed. Step-7 owner on log-wealth 32x32 (277 s) against the run with the old lower bound and the new upper bound (ages 25/30/35/45/55/66/75/85/95, mean consumption in thousand EUR): 2.0/4.3/7.3/20.9/50.9/99.6/109.4/109.7/90.4 before, 0.0/0.0/3.0/41.5/74.9/94.1/96.2/94.1/75.5 now. Median consumption over income at 25-30: 0.012-0.037% (EUR 5-20 a year), all households below 1% of income until 30, 22% still below it at 40; median liquid savings 3.7 years of income at 30 and 10.2 at 40. Mean liquid savings at 66 EUR 1.37M (1.70M). Mean liquid equity share at 30 0.09 (0.32), at 55 0.27 (0.09). Floored household-years 0.06% (0.59%); at 95, 0.30% (2.77%). At the bound 25-39: 0% (96.3%). Entry value 1.8e-5 (6.6e-6).
Reading: without the 1%-of-wealth bound the owner at a floor of 1e-6 consumes almost nothing for the first five to ten years and saves everything to build a buffer against old-age bankruptcy; consumption then rises above the old path in mid-life and the old-age floor states almost disappear. This is the model's own answer at this floor, which the old bound hid. It is not a plausible life cycle, which puts the floor level (TODO.md item 1) first.
Commit: this entry, pushed to main.

### 2026-10-15 Consumption search: upper bound 1 instead of 1 - 1e-6 (spec: none, asked by Quinn in Claude Code)
Changed: `+solver/bellman_step_lna.m`: the consumption share c may now reach 1 (all liquid resources) in the per-node grid, the sweep and fmincon; it was capped at 1 - 1e-6. `docs/SOLVER_BOUNDS.md` updated.
Checks run: `run_tests` (full): 0 of 13 checks failed. Step-7 owner on log-wealth 32x32 (258 s) against the saved solve with the old cap: mean consumption within 0.004%, mean liquid savings within 2e-5 years of income, floored share 0.59%, share of 25-39 at the lower bound 96.3% and entry value 6.55e-6 all unchanged. On the grid, c moved by more than 0.01 at 70 of 175,712 points; pi moved by more than 0.05 at 9,585 points, 8,520 of which consume everything, where pi applies to nothing. The largest gap in the mean equity share, 0.041 at age 99, comes from those households. 26,712 points now consume everything, against 26,632 at 1 - 2e-6 before.
Reading: the change does not matter economically. Where nothing is saved the equity share is undetermined, which moves the mean equity share at very old ages; it would be cleaner to report the share only for households that save.
Commit: this entry, pushed to main.

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
