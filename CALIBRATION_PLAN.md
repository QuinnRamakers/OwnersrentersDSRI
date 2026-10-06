# Calibration ladder: plan of work

Copy of the Claude Doc at https://claude.ai/code/artifact/f90a2f02-9934-4efe-a81c-2b9f2adb6163, exported 2026-10-07. Re-export after edits in the doc so the two stay the same.

## Goal and working rules

We rebuild the calibration from a Cocco, Gomes and Maenhout (2005) model up to the full model, one change at a time, and you approve each step before the next one runs.

- **One change per step.** A step changes one block of parameters or switches on one feature, so whatever moves can be traced to it.
- **Each step names the step it builds on.** Most steps follow in a line; housing and the DC pension branch off the same baseline, and a later step combines them.
- **Predict, then run.** Before a step runs I write down what it should do to consumption, wealth and the equity share; afterwards we check the result against that.
- **Same numerics throughout** (standard: grid \[16 16 10\], 5 quadrature nodes), so differences between steps come from the calibration.
- **I stop after every step.** You comment, and we fix, rerun or move on. Nothing runs ahead.
- **Code changes come first and change nothing earlier.** Anything a step needs (a new income form, a new feature) is built and tested before that step, with earlier steps reproduced exactly.

Route of the ladder:

```
1 CGM → 2 preferences → 3 retirement age → 4 income → 5 market   (5 = baseline)
5 → 6 housing only
5 → 7 DC pension only
6 + 7 → 8 housing + DC → 9 income tax → 10 box 3 → 11 correlations → 12 housing level
13: a second ladder from today's full calibration to the new one
```

Steps 6 and 7 branch off the baseline and are checked separately before step 8 combines them.

## Step 1: CGM model, CGM calibration

Step 1 switches off housing, the DC pension, taxes and the REIT and uses CGM's own numbers, so the model should reproduce the shapes in CGM (2005).

| Parameter | Step 1 value | Source |
| --- | --- | --- |
| Risk aversion γ | 10 | CGM baseline |
| Discount factor β | 0.96 | CGM |
| Income profile | high-school cubic in age | CGM Table 1 |
| Permanent shock std | 0.103 (variance 0.0106) | CGM |
| Transitory shock | not in the model (CGM: variance 0.0738) | Question 2 |
| Retirement income | 68.2% of final income | CGM, high school |
| Retirement age | 65 | CGM |
| Risk-free rate, equity premium, equity vol | 2%, 4%, 15.7% | CGM |
| Housing, DC pension, taxes, REIT | off |  |

Kept from our model: entry at 25 instead of 20, a terminal age of 100, and Dutch unisex mortality instead of the US table.

What we check, against CGM's Figure 3 (life-cycle profiles) and Figure 2 (policy rules):

- Consumption tracks income while young, then humps; wealth builds up to retirement and runs down after.
- The equity share starts at 1 while human capital is large, falls through working life, and rises again in retirement.
- At a given age the equity share falls as cash on hand rises.

From the research: at γ = 10 this core reproduced the shape of CGM's Figure 3C, but households left the all-equity corner around 28 instead of 38 and bottomed out earlier and lower. The missing transitory shock is the likely cause.

## Steps 2–5: our numbers in the CGM model

Steps 2 to 5 replace CGM's numbers with ours one block at a time, keeping CGM's structure; step 5 is the baseline that every later step builds on.

| Step | Change | What should happen |
| --- | --- | --- |
| 2 Preferences | γ 10 → 5; β stays 0.96 | Less precautionary saving; equity share stays at 1 longer and is higher in retirement |
| 3 Retirement age | 65 → 67 | Small: two more working years, slightly more saving |
| 4 Income | CGM cubic and variance → your new polynomial and variance | Saving follows the profile's shape; a lower variance means less precautionary saving and more equity |
| 5 Market | CGM returns → your new series | The equity share moves with the new premium and volatility (the Merton share is reported at every step) |

Retirement income keeps CGM's 68.2% through step 5 unless you decide otherwise (question 4). With no DC pension yet, that number stands for all retirement income, not just the AOW.

## Steps 6–7: housing and the DC pension separately

Housing and the DC pension each enter the baseline on their own, so each mechanism is checked before they interact. Neither step has taxes yet.

**Step 6: housing only**, for a renter and an owner.

- Dynamics from your block-3 numbers; the level (house at 4× income, rent 6%, maintenance 1.5%, full mortgage) stays a placeholder until block 2 has values.
- Should show: rent or mortgage costs cut early consumption; owners build home equity and their costs drop when the mortgage ends at 55; the renter's rent burden grows through retirement.
- Expected flag: with a near-zero floor and a large committed housing cost, ages 25–39 did not converge in the research. The checks will show whether that appears here.

**Step 7: DC pension only**, no housing.

- Retirement income drops to the AOW (30.7% of final wage) and the DC account supplies the rest: 18.6% contributions above the franchise, the glide-path fund, an annuity from 67 (block 5, current values).
- Should show: liquid saving crowded out by the DC pot; the equity share of financial wealth following the glide; retirement income of AOW plus an annuity that is level in expectation.
- Needs income in euros, because the franchise is a euro amount (question 1).

## Steps 8–11: assembling the full model

Step 8 combines housing and the DC pension; taxes and correlations then enter one at a time on the combined model.

| Step | Change | What should happen |
| --- | --- | --- |
| 8 Housing + DC | Both on, renter and owner; compared with steps 6 and 7 | Close to the sum of the two separately, plus the squeeze of a forced contribution on top of housing costs |
| 9 Income tax | EET at 38.2%: contributions deductible, AOW and annuity taxed | Lower net income, so housing takes a larger share and early consumption falls |
| 10 Box 3 | 36% on the liquid account's returns, no loss offset | Liquid equity share falls sharply (after-tax premium about 4% → 1.2%); the DC fund is sheltered |
| 11 Correlations | stock–income, house or rent–income, stock–house, from your series where available | Small, unless a correlation is large |

Side checks, off the main line and a minute each, if you want them (question 5):

- **Income tax on the baseline.** With no housing or pension, a flat income tax only rescales income, so ratios to net income should not move. A clean test of the tax code.
- **Box 3 on the baseline.** Its effect on the equity share alone.
- **Income tax on the DC-only model.** The EET mechanics alone.

The REIT stays off throughout.

## Steps 12–13: after the full model

Two steps remain once step 11 is approved: real housing levels, and the path from today's calibration to the new one.

- **Step 12: housing level (block 2).** House value against income, rent level, maintenance, the mortgage share and the entry buffer, switched in once you have values. A mortgage below 100% of the house needs a code change first: a down payment the model does not have yet.
- **Step 13: today versus new.** A second ladder that starts at today's full calibration, frozen before any value changes, and moves block by block to the new one. It shows what each recalibration does to the model as it stands today.

## Parameter status

Three blocks need numbers from you before their step (3, 4, 7); the rest keep their current values for now.

| Block | Parameters (current value) | Status | Enters at step |
| --- | --- | --- | --- |
| 1 Floor | floor 1e-6 × income; search bound 1% of wealth | Keep: numerical constraint | throughout |
| 2 Housing level | house 4× income, rent 6%, maintenance 1.5%, full mortgage, entry buffer 0.079 yr | No values yet; placeholder, switched on and off | 6 (placeholder), 12 |
| 3 Housing dynamics | house price 2.7% / vol 3.7%; rent 0.97% / vol 1.8%; mortgage 1.36%, 30 years | New numbers from you | 6 |
| 4 Income | polynomial, shock variance | New estimates from you | 4 |
| 5 Pension | 18.6% above €18,475, glide 0.8 → 0 | Keep for now, not final | 7 |
| 6 Taxes | income 38.2%; box 3 36%, no loss offset | Keep for now | 9, 10 |
| 7 Market | real rate 1.1%, premium 4%, vol 16%, correlations 0 | New series from you | 5, 11 |
| 8 Preferences | γ 5, β 0.96, no bequest | Keep | 2 |
| 9 REIT | off | Keep | not used |

## How each step runs

Every step goes through the same six stages and ends with your review.

1. You confirm the step's values or send new ones.
2. I make any code change the step needs, test it, and confirm the earlier steps still give the same results.
3. I write down the expected direction of consumption, wealth and the equity share.
4. I run the step (minutes) and send a dashboard per tenure, a comparison with the step it builds on, a table at ages 25–85, and the checks: floor, search bound, off-grid lookups, grid coverage.
5. I say whether the result matches the expectation, and where it does not, what I think explains it.
6. You review: approve and we move on, or we fix and rerun this step.

Each approved step is committed with its values and sources in CALIBRATION.md and pushed to GitHub.

## Code work before step 1

Four changes come before step 1; none of them changes today's results.

- [ ] **Branching ladder.** Each step names the step it builds on, so the two branches and the combined step can be written down; comparisons run against that parent (step 8 against both). Today's ladder is a single line.
- [ ] **Freeze today's calibration.** A git tag and a frozen copy in the code, for step 13.
- [ ] **Income in your form.** A polynomial in your form and units, usable with the DC pension. Today the code refuses a polynomial together with a DC pillar, because the CGM cubic is not in euros.
- [ ] **Market moments.** Typed in, or computed from the series by a small script if you send the data.

## Questions

Answers to 1–4 are needed before the code work; 5–8 can wait until their step.

1. **Income polynomial.** Its exact form (powers of age, any scaling), units (log euros, which price year), whose income (men, pooled, household), and the age range it was estimated on?
2. **Variance estimate.** Permanent only, or permanent and transitory? The model has only a permanent shock. CGM have both, and the research suspects the missing transitory shock is why step 1 misses CGM's timing. Add it (a code change), or keep permanent only?
3. **Market series.** Real or nominal, which period, which assets? Should it also give the correlations for step 11?
4. **Retirement income before the pension enters.** Keep CGM's 68.2% through step 6, then switch to the AOW's 30.7% plus the DC account at step 7? Or another number?
5. **Side checks.** All three in steps 9–11, some, or none?
6. **Numerics.** Standard for every step (about 4 minutes per tenure), with quick runs only for reruns?
7. **Search bound.** Keep consumption's lower search bound at 1% of wealth? At the full calibration it, not the household, sets consumption at 25.
8. **Step 1 deviations.** Are entry at 25 and Dutch mortality acceptable, or should step 1 follow CGM more closely? Entry at 20 needs an income profile from 20.
