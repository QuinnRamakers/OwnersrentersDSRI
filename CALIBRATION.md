# Calibration

Sources and reasoning for every value in `+config/params.m`. The file itself
keeps one-line comments; the detail lives here. `+ladder/steps.m` builds the
same calibration up from a CGM (2005) core; the values that core uses are at
the end.

## Price-year convention

All euro-denominated inputs are in **2025 euros** — the last complete calendar
year, so the CBS annual CPI is final and the statutory amounts are settled.

Two inputs carry a price year: the income profile's price factor
(`dhs_price_factor` for the production DHS profile, `income_price_factor` for
the BKV table) and `franchise`. They must move together, because the
contribution rate compares income to the franchise and mixing years silently
misstates it at every age. Everything else in `params.m` is a real or
unit-free rate and has no price year. `b0`/`b_alt` are a ratio of same-year
euros and so are price-level-free.

A 2026 base was tried and rejected: 2026 is still running, so its factor could
only come from a part-year CPI average that CBS will revise.

## Timing, mortality, preferences

| Parameter | Value | Source |
|---|---|---|
| `age0` | 25 | First age of the DHS income sample (heads aged 25–65), so the working profile needs no below-sample extrapolation |
| `retirement_age` | 67 | Statutory AOW eligibility, 2026 |
| `T` | 76 | Set so the terminal age stays 100 |
| `p_surv` | age profile | CBS life table 2021–2026, sexes combined (`CBSunisexmortality21-26.csv`, StatLine 37360ned) |
| `sex` | 1 (men) | Selects the BKV income table (`'table'`) only; unused by the DHS profile. The life table is unisex |
| `gamma` | 5 | Production choice. CGM (2005) use 10; the ladder starts there |
| `beta` | 0.96 | Placeholder. Larsen et al. (2023) is a candidate source, not checked |
| `chi` | 0 | Placeholder. Bequest motive off in the baseline. Form (Quinn, 26 October 2026): chi B^(1-gamma)/(1-gamma), B liquid wealth after the year's returns plus, for owners, the house net of `sell_cost`. In the last period the household dies for certain and chooses c and pi against the bequest alone. Tests across the ladder hold b = chi^(1/gamma), about the bequest over the last year's consumption, fixed: chi = b^gamma at each step's gamma (`case_params` suffix `_beqb`) |
| `beq_bankrupt` | 1 | Placeholder (Quinn, 27 October 2026). A bankrupt household (absorbing floor) is valued as leaving this many years of its floor consumption at its death, so under the paper's form bankruptcy carries a large but finite bequest penalty instead of none: its value is u(F) [D_t + chi beq_bankrupt^(1-gamma) G_t], G_t the discounted chance of dying (`config.derive`). Inert while `chi = 0` or without the absorbing floor |

## Labour income

The working-age profile is a cubic in age estimated on gross income (labour
income and transfers: DHS gross without capital income, student support and
inheritance) in the DNB Household Survey (DHS), ages 25–65, owners and renters
pooled (calibration notes, `calibration_notes (2).pdf`, Table 2, gross income,
column All):

```
log y = a0 + a1 age + a2 age^2/10 + a3 age^3/100
```

in log euros of 2020. The code's cubic divides by 100 and 1e4 instead, so the
code coefficients are `[a0, a1, 10 a2, 100 a3]`. Owners and renters use the
same cubic and the same permanent shock std (Quinn, 29 October 2026): owners
and renters differ in tenure, not in income. The code keeps the renter fields
(`income_coef_rent`, `sigma_l_log_rent`, read by `config.income_process`) and
sets them equal to the owner fields, so a step without housing has one arm
(`model.tenures_differ`).

| Parameter | Value | Source |
|---|---|---|
| `income_source` | `'dhs'` | The DHS cubic, in euros |
| `income_coef` | [6.9733, 0.20986, -0.3776, 0.2207] | Table 2, gross, All: a0 6.9733, a1 0.20986, a2 -0.03776, a3 0.002207. EUR 33,829 at 25 and a peak of 60,589 at 48, in 2025 euros |
| `income_coef_rent` | the same | Owners and renters pooled |
| `dhs_price_factor` | 1.2516 | CPI(2025)/CPI(2020) = 134.56/107.51, CBS 83131NED, all items, annual averages (2015 = 100) |
| `sigma_l_log` | 0.0675 | Table 2, gross, All, permanent shock std |
| `sigma_l_log_rent` | the same | Table 2 does not identify a renter value (negative slope in the variance regression) and its note says the model uses the all-household value |
| `replacement` | 0.307 | DNB, *Toereikendheid van pensioenen*, Table 3, median first-pillar replacement rate |

In 2020 euros the coefficients give 27,028 at 25 and 48,409 at the peak;
Table 2 reports 27,022 and 48,366, and the gap is coefficient rounding. The
sample ends at 65, so age 66, the last working year, is the cubic extrapolated
one year.

`sigma_l_log` is the permanent component because this model's income process
is a pure random walk — every shock compounds forward. The transitory
component (Table 2, gross, All: 0.2954; CGM 0.2717) has no home in a
single-shock structure and is omitted.

Until 29 October 2026 the model used separate cubics in 2025 euros (calibration
notes of 12 October, Table 3: owners [7.7979, 0.17253, -0.2784, 0.1405], EUR
39,763 at 25; renters [7.5302, 0.17828, -0.3126, 0.1784], EUR 30,098 at 25)
and shock stds of 0.0816 and 0.0843. With them owners' DC pensions were 1.66
times renters', because contributions are paid above the franchise.

The first pillar is `replacement` times final working income rather than a
flat AOW amount, which keeps the model homothetic. It removes the floor that a
flat AOW gives households with a bad history of permanent shocks.

Two other income sources stay in the code. `'poly'` is the same cubic in CGM
(2005) income units, used by the first ladder steps; its level is not in
euros, so `config.derive` refuses it together with a DC pillar (the franchise
is a euro amount). `'table'` looks up the semi-parametric age effects of Been,
Knoef & Vethaak (2026, JBES 44(1):215–226), Online Appendix Tables D.1 (men)
and D.2 (women), "Full-time, Selection" column, for the sex in `sex`. It is
anchored at EUR 33,000 at age 25 (men; BKV Section 3.2.3), in 2015 prices,
rescaled by `income_price_factor` = 1.3456 = CPI(2025)/CPI(2015) (CBS
83131NED). Below 24 it is extrapolated linearly from ages 24–27; above 64 it
is held flat at the age-64 value.

## Pension

Contributions are levied on income above a franchise, so the effective rate on
gross income rises with income and is an age profile rather than a scalar:

```
kappa_t = kappa_base * max(Y_t - F, 0) / Y_t
```

giving about 10.0% at 25 rising to 14.0% at 50 on the owners' DHS profile, and
7.2% rising to 12.0% at 49 on the renters'.

| Parameter | Value | Source |
|---|---|---|
| `kappa_base` | 0.186 | Placeholder. OECD *Pensions at a Glance*: the 2022 country note gives 18.6% as the rate above the franchise; the 2025 edition (Table 3.4) repeats the number without restating that |
| `franchise` | EUR 18,475 | Minimum AOW-franchise per 1-1-2025, art. 18a lid 3 Wet LB, Belastingdienst CAP. The 2026 figure is EUR 19,172 and belongs only with a 2026 income factor |
| `glide_cap`, `glide_span` | 0.8, 35 | Fund risky share `min(0.8, years to retirement / 35)`: 0.8 until 39, linear to 0 at 67. A stylised lifecycle fund. Since 29 October 2026 half of it is in the REIT and half in stocks (`reit_risky`, below) |
| `tau_decum` | `[]` | Fund equity share in retirement; empty keeps the glide's 0 (an all-bond fund) |
| `dc_choice` | false | Off in production: the fund runs its own shares. True (case suffix `_dcfree`) lets the household pick the fund's stock and REIT shares at every age, retirement included (Quinn, 29 October 2026). A modelling switch, no data source |

`kappa_t` is evaluated on the **deterministic** income profile, not each
household's realised income. A rate depending on realised `Y` would break the
normalised state space, since only `lambda = Y/W` is a state and the euro level
of `Y` is not. The calibration specifies `kappa_t` as an age profile, which is
exactly this object.

The DC pot earns the survival credit 1/p_t from age 25, not only in
retirement, and is converted at 67 into a variable annuity whose price `a_t`
keeps expected payouts level: `a_t = 1 + p_t a_{t+1} / E[R^A]`. Whatever
equity share the fund holds in retirement is priced in.

With `dc_choice` the household picks the stock share `tau_S` and the REIT
share `tau_R` of its own pot each year, with `tau_S, tau_R >= 0` and
`tau_S + tau_R <= 1` (the REIT share is 0 when the REIT is off). The fund's
shares (the glide, all bonds from 67) are always one of its options. The
annuity is still priced off the fund's shares, so the payout rule `A/a_t` does
not change: a household that holds more risk in retirement gets payouts that
are riskier and rise in expectation, instead of level ones.

Open: `kappa_base` should be an aggregate participant-weighted rate across
Dutch funds (DNB or Pensioenfederatie), not a single OECD figure.

## REIT in the DC fund

A second risky asset held only inside the DC fund, beside the stock and bond
legs; the bond leg is `1 - tau_S - tau_REIT`. It is a fourth lognormal shock.
The REIT is the NASDAQ Eurozone Real Estate Total Return Index in euros, real.

Production holds it since 29 October 2026 (ladder step 19; steps 1-18 hold
none). The glide's risky share, min(0.8, years to retirement / 35) and 0 from
67, is split: stocks hold (1 - `reit_risky`) of it and the REIT `reit_risky`
of it. The bond leg and the all-bond fund in retirement are as without the
REIT, so the annuity prices from 67 do not move.

| Parameter | Value | Source |
|---|---|---|
| `reit_risky` | 0.5 | Quinn, 29 October 2026, from the small-grid runs at 25%, 50% and 100% of the risky share (HANDOFF, 29 October): 50% raised the entry value of both tenures, renters by 0.38% and owners by 0.06%. No data source |
| `tau_REIT` | 0 | A further REIT share at every age, retirement included; only `_reit<n>` sets it |
| `reit_decum` | [] | No REIT in retirement |
| `mu_REIT_level` | 0.0543 | Real return in euros less `r`, 2002–2024. Calibration tables, Table 1 |
| `sigma_REIT_level` | 0.2448 | Same series, standard deviation. Table 1 |
| `corr_RL` | 0.09 | REIT with the gross income shock, pooled, 2002–2023. Table 3 |
| `corr_RS` | 0.76 | REIT with the stock return. Table 3 |
| `corr_RH` | 0.17 | Owners: REIT with the house price. Table 3 |
| `corr_RH_rent` | 0.59 | Renters: REIT with the rent. Table 3 |

With these values the REIT's Sharpe ratio is 0.22 against 0.21 for stocks, at
a correlation of 0.76 between the two. Table 5 gives the income correlations
by tenure (REIT: owners 0.14, renters −0.22); the model uses the pooled values
for every shock. The REIT shock takes `gh_n_reit` quadrature nodes (Numerics).

The REIT's moments are production's on every ladder step. With no share and no
correlations nothing reads them, and the fourth shock is left out of the
quadrature altogether, so steps 1-18 pay nothing for it. `ladder.same_calibration`
does not compare the REIT fields when the REIT is off in both results, so the
REIT-off solves saved before 29 October, with the old placeholder moments
(0.03 and 0.12, the same Sharpe ratio as equity), are still the same
calibration.

Case suffixes (`diagnostics/pension_grid/case_params.m`):
`_rr<n>` sets `reit_risky` to n/100 (production is `_rr50`); `_reit<n>` holds
the REIT at n/100 of the fund at every age, retirement included, in place of
the split (the 28 October rule; 10% was the old placeholder share, with no
source); `_rh<n>` sets the REIT's correlation with the H shock to n/100 for
both tenures; `_rgh<n>` sets `gh_n_reit`. The `_reit` and `_rr` solves saved
before 29 October set the correlation by tenure in `corr_RH` and the split
through `glide_cap`, `glide_span` and a `tau_REIT` path. They are the same
model, but a different calibration for `ladder.same_calibration`, and re-solve
when run again.

## Taxes

The DC account gets EET treatment: contributions are deductible, the fund grows
untaxed, and both the annuity payout and AOW are taxed as income on receipt.
Working take-home is therefore `(1 - kappa)(1 - tau_inc) Y`.

| Parameter | Value | Source |
|---|---|---|
| `tau_inc` | 0.382 | CBS, average tax burden on income, 2019. This is the paper's `delta` |
| `tau_cg_bond`, `tau_cg_stock` | 0.36 | Box-3 rate (2025), applied to the liquid account's actual return each year |
| `cg_loss_offset` | false | Stock losses are not rebated |
| `tau_wealth` | 0 | Box-3-style levy on the liquid balance. Calibrated value 0.0197 (Hambel et al. 2026), switched off |

The DC fund is sheltered from both, which is its tax advantage.

The missing loss offset matters more than the rate. With it, the tax keeps
0.64 of every gain and none of any loss, which cuts the after-tax equity
premium on the liquid account from 4.6% to about 1.0% and the Merton share at
gamma = 5 from about 0.20 to 0.08. A symmetric tax at the same rate leaves the
Sharpe ratio unchanged and raises the Merton share to about 0.31. The
government becomes a silent partner (Domar-Musgrave). `cg_loss_offset = true`
switches to the symmetric tax.

Both instruments are kept rather than collapsed into one, because they
represent different regimes: the proposed box-3 successor is return-based with
loss carry-forward, which is a CGT, while the current deemed-return levy on the
balance is a wealth tax. Switching regimes should be a calibration change, not
a code change.

At the calibrated `tau_wealth = 0.0197` the liquid account's safe return turns
negative in real terms (`1.0115 * 0.9803 - 1 = -0.84%`) against `+1.15%` inside
the sheltered fund.

## Financial markets

`mu_S_level` is the **excess** return over the risk-free rate; the housing
drift `mu_H_level` is the house's own return, not excess. The market series
are real, and the correlations come from the same pipeline as the moments.

| Parameter | Value | Source |
|---|---|---|
| `r` | 0.0115 | Real NL 3-month interbank rate (FRED IR3TIB01NLM156N, monthly) deflated by the CBS CPI, mean 1982–2024. Calibration notes, Table 2 |
| `mu_S_level` | 0.0456 | Real stock return less `r`, mean 2000–2024. Calibration notes, Table 2 |
| `sigma_S_level` | 0.2161 | Standard deviation of real stock returns, 2000–2024. An arithmetic std, as `sigma_S_level` is. Calibration notes, Table 2 |
| `mu_H_level` | 0.0373 | Real house-price growth, mean, NVM repeat sales of individual houses, 1996–2024. Calibration tables, Table 1 |
| `sigma_H_level` | 0.0835 | Same series, standard deviation |
| `mu_R_level` | 0.0099 | Real rent growth, mean, CBS regulated rent increase, 1983–2025. Calibration tables, Table 1 |
| `sigma_R_level` | 0.0179 | Same series, standard deviation. See the caveat below |
| `corr_SL` | 0.04 | Correlation of the permanent income shock with the stock return: gross income, pooled over all DHS households, 2002–2023 (T = 22). Calibration notes, Table 4. One value for both tenures |
| `corr_HL`, `corr_HL_rent` | 0.09, 0.06 | Correlation of the H shock with income: house price for owners, rent for renters. Gross income, annual shocks 2002–2023 (T = 22). Calibration tables, Table 3 |
| `corr_SH`, `corr_SH_rent` | 0.24, 0.43 | Correlation of the H shock with the stock return: house price for owners, rent for renters. Same source |

Table 1 reports means and standard deviations of annual real arithmetic growth
rates, which is what the `_level` inputs take; `config.derive` turns them into
the log-normal parameters. Table 3 also gives the house price–rent correlation
(0.21) and the REIT's correlations; the first has no place in the model, since
no household faces both processes; the REIT's are in the REIT section.

The correlations are wired through a Cholesky factor in both `grids.shock_grid`
and `simulate.paths_lna`, so giving them values costs nothing in runtime or node
count. Each represents the covariance of a single composite income shock: with
no aggregate/idiosyncratic split, one number absorbs both channels. The third
shock is the house-price return for an owner and the rent increase for a
renter, so its correlations come in pairs and `config.h_corr` picks the
tenure's. Without housing the H shock is degenerate and the housing cost is
zero, so a step without housing does not depend on any housing parameter.

## The rent process

The `H` state carries a different object in each scenario. For an owner it is
the house, and its growth factor is the house-price return. For a renter it has
no resale or bequest value — its only role is to set the rent `alpha * H_t` —
so it is a rent index, and its growth factor is the rent increase. Those are
distinct processes and are calibrated separately: `config.h_process` returns
`(mu_R, sigma_R)` for renters and `(mu_H, sigma_H)` for owners.

`mu_R_level` and `sigma_R_level` must be **real** (CPI-deflated), on the same
footing as `mu_H_level`. Published Dutch rent-increase series are nominal, and
substituting one directly makes the renter's position worse rather than better.

The rent drift is the most consequential number for the renter arm. Rent
compounds for all 76 model years while retirement income is flat in real terms
after the replacement drop, so the renter's burden is governed by the growth
differential compounded over the retirement years. Setting `mu_R_level` to the
house-price drift, as the model did before the processes were separated (then
0.027), put median rent at roughly 240% of net AOW at 67.

Two caveats on `sigma_R_level`. Real rent growth is nominal less CPI, and the
nominal increase is a capped policy number in a narrow band, so nearly all of
the estimated variance is inflation surprise rather than rent-policy variation
— an estimation window that excludes 2022-23 will understate it. And the model
treats the shock as permanent, since log rent is a random walk, whereas the
real-rent effect of an inflation surprise is largely clawed back the following
year through the cap formula. Neither is worth much effort at this value: the
implied 90% band on the rent level after 75 years is only 0.78x to 1.29x, so
the drift does essentially all the work.

The rent and house-price processes are not jointly consistent when extrapolated
— 0.0099 against 0.0373 implies the rent-to-price ratio falls from `alpha` = 6%
to about 0.8% over the horizon. Nothing in the model requires consistency,
because tenure is fixed at t = 1 and no household ever faces both processes.

## Housing

| Parameter | Value | Source |
|---|---|---|
| `alpha` | 0.056 | Rent-to-price ratio. Government report (reference to add) |
| `theta` | 0.015 | Placeholder. Maintenance, Yao & Zhang (2005); Nibud's 1% plus local taxes |
| `h_rule` | `'nibud'` | How `H_0 = h_mult * Y_0` is set: `'nibud'` the Nibud 2026 maximum mortgage at entry income (below), `'fixed'` `h_fixed`, `'none'` no housing |
| `h_fixed` | 4.0 | `h_mult` under `h_rule = 'fixed'` (ladder steps 7–15). Placeholder |
| `nibud_extra` | true | The Nibud EUR 17,000 increase is included, see below |

`h_mult`, the house (owner) or rent index (renter) at entry as a multiple of
income, is derived from these three by `config.derive`, separately for each
tenure; the rest of the model reads it, and `h_mult = 0` means no housing.
| `r_m` | 0.0348 | The total real mortgage rate, not a spread: `r` plus the mean spread between the MIR home-purchase lending rate and the 3-month interbank rate, 2000–2024 |
| `N_mort` | 30 | Standard Dutch annuity mortgage term |
| `LTV` | 1.00 | Asserted — see below |
| `mortgage` | `'annuity'` | The contract, see below. `'proportional'` at ladder step 7 |
| `maint_on_purchase` | true | Maintenance on the purchase price (Quinn, 26 October 2026, for now; ladder step 17). false charges it on the current house value, as at ladder steps 7-16 |
| `sell_cost` | 0.025 | Seller transaction cost at bequest, Hambel et al. (2026). Inert while `chi = 0` |

For a renter, `alpha` and `h_mult` enter only as the product `alpha * h_mult`:
under the Nibud rule the rent at entry is 23.3% of gross income, about 25% of
pay after contributions and 41% after the income tax as well. That committed
outflow, which the household cannot reduce, is what makes early life
ill-conditioned at this calibration (README). The owner's equivalent is
maintenance plus the mortgage payment, 30.8% of gross income at entry.

The mortgage is a real annuity on the purchase price: a constant real payment
of `LTV * H0` times the annuity factor of an `N_mort`-year loan at `r_m`, so its
present value at `r_m` is the loan. A Dutch annuity mortgage fixes the nominal
payment instead; the real contract was chosen on 15 October 2026. Because the
payment is fixed while the house value moves, the owner carries a fourth state,
`q = H0/H_t`, the purchase price over the current house value: `q = 1` at
entry and `q_{t+1} = q_t / R_H`. The payment is `m * q * H_t`, so the model stays
homothetic in wealth. `q` is a state only while it enters the budget: during
the `N_mort` paying years, or at every age when `maint_on_purchase` is true.

Ladder step 7 keeps the earlier contract, `mortgage = 'proportional'`: the same
rate applied to the current house value, with no fourth state. That payment
grows with the house price; at step 7, with a mortgage rate of 1.36%, its
present value at `r_m` was 1.71 times the loan. Step 7b switches to the annuity and every step built on it inherits
it. The bequest is not netted for the outstanding balance, which waits for
`chi > 0` (TODO.md, item 4).

`maint_on_purchase = true` charges maintenance on the purchase price,
`theta * H0`, instead of the current value. It is the production setting
since 26 October 2026, for now (Quinn), appended as ladder step 17 so that
steps 7-16 keep the current value; step 7b still varies it as a sensitivity.
With the absorbing floor at EUR 5,000 at step 16, owners on the current value
went bankrupt mostly in old age (7-14% by 85, depending on the grid), as
maintenance on a house whose real price grows 3.73% a year outruns the first
pillar; on the purchase price about 1% went bankrupt, all while the mortgage
ran (`docs/HANDOFF_2026-10-26.md`). With it, `q` is an owner's state at every
age, and an owner solve takes about 2-2.5 times as long.

`LTV` is asserted equal to 1.00 because that is the only value consistent with
the rest of the model: the household is endowed with the house at `t = 1` with
`X_0 = b0 * Y_0` and services a mortgage on its full value. Anything below 1
needs a down-payment endowment the model does not have, so it fails loudly
rather than half-running.

### House at entry: the Nibud rule

With `h_rule = 'nibud'` the house at entry is the largest mortgage a lender
may grant under the Nibud financing-cost norms for 2026 (Nibud,
*Financieringslastnormen 2026*, bijlage, version 251110; `config.nibud_lti`).
With `LTV` = 1 the loan is the house, so `config.derive` sets `h_mult` to that
loan over the tenure's deterministic gross income at 25.

The norm caps the monthly payment of a 30-year annuity at a share of gross
income, the financieringslastpercentage, read from a table by income and test
rate `i`:

```
M = flp(Y, i) * Y / 12 / a,   a = (i/12) (1 + i/12)^360 / ((1 + i/12)^360 - 1)
```

The row is the last income at or below `Y` (EUR 30,000 to 125,000 in steps of
1,000; lower incomes use the first row) and the column the rate bracket. This
is the workbook's own calculator: run in Excel, the calculator agrees with the
code to rounding, including incomes off the table and rates on bracket
boundaries, and the code reproduces the workbook's maximum-mortgage table. One
cell of that table disagrees with the workbook's share table; the share is
used.

| Choice | Value | Reason |
|---|---|---|
| Table | below AOW age, box 1 | The household buys at 25 with an annuity mortgage, whose interest is deductible |
| Test rate | `r_m`, bracket 3.001–3.5% | The model's own mortgage rate, so the payment at entry is the norm's share of income apart from the increase |
| Income | gross income at 25, single earner | DHS, owners and renters pooled: EUR 33,829 (2025 euros) |
| Increase | EUR 17,000 (`nibud_extra`) | The Tijdelijke regeling hypothecair krediet allows it for groups without personal unavoidable expenses; the workbook's calculator adds it by default for a single earner above the first income row |
| Energy-label amounts | none | The model has no energy label |

At production this gives `h_mult` = 4.521 for both tenures (4.018 without the
increase), since owners and renters share one income process. The renter
follows the same rule, so its rent is `alpha` times the house it could have
bought. With the separate income cubics used until 29 October 2026 it was
4.446 for owners and 4.155 for renters.

What to keep in mind:

- The table is in 2026 euros and income in 2025 euros. The 2025 tables would
  match the price year. (At the separate cubics, raising both entry incomes by
  3% moved the multiples to 4.434 and 4.306.)
- The box-1 shares assume the interest is deducted, which the model does not
  do. At the separate cubics the box-3 table (no deduction) gave 3.57 for
  owners and 3.34 for renters.
- The norm tests the contract's nominal rate; `r_m` is real.
- The norm is a ceiling, and not everyone borrows to it. The intended
  assignment is still an income-contingent estimate from LISS (log house value
  at purchase on log income plus age and cohort controls), with this rule as
  its upper bound.

## Consumption floor

| Parameter | Value | Source |
|---|---|---|
| `phi_floor` | 1e-6 | A numerical bound, not a calibration target. 1e-4 is an admissible alternative |
| `c_min` | 5,000 | The absorbing floor, euros a year (2025) at median labour income (Quinn, 26 October 2026; ladder step 18, steps 1-17 have 0, the yearly top-up). The level the grid and search-routine studies of 24-26 October were run at (`docs/HANDOFF_2026-10-26.md`). Source still open (Nibud minimum example budgets, spending after housing at the bijstand level); 12,000 was too high (most owners bankrupt by 30) |
| `phi_abs` | 0 (off) | The absorbing floor as one share of permanent labour income, the alternative to `c_min` |

### The absorbing floor (`c_min`, `phi_abs`)

Added on 23 October 2026 (`docs/prompts/absorbing_floor.md`); in production at
c_min = EUR 5,000 since 26 October 2026 (ladder step 18). With `c_min > 0` or
`phi_abs > 0` the floor is an absorbing
state. A household whose liquid resources fall below F_t = phi_t Y_t goes
bankrupt: it consumes F_{t*} every year until it dies and makes no further
choices, and its liquid wealth, DC pot, house and later income are gone. Its
value is u(F_{t*}) D_t, with D_t = 1 + beta p_t D_{t+1} and D_T = 1
(`p.D_abs`). F_t is also the lowest consumption a solvent household can
choose. No state is added: the floor is proportional to income, so the value
stays homothetic.

`config.derive` builds `p.phi_path`:

- `c_min`: phi_t = c_min / Ybar_t, with Ybar_t the owners' deterministic
  income profile (in retirement 0.307 Ybar_66, so the floor is tied to final
  labour income), for both tenures. The floor is c_min for the median owner at
  every age and c_min Y_t / Ybar_t for every other household, renters
  included: the same share of income for owners and renters. Since 29
  October 2026 both tenures use the pooled income cubic (Labour income,
  above), so the owners' profile is the common one.
- `phi_abs`: phi_t = phi_abs to 66 and phi_abs / replacement from 67, that is
  phi_abs times permanent labour income, final labour income in retirement.

At most one of the two is positive, and `c_min` needs income in euros.
Both 0 gives the yearly top-up at `phi_floor` below. The floor stands for the
social minimum net of housing costs; the Dutch policy background and the
sources considered are in the prompt.

Decided (Quinn, 23 October 2026): the share by age, phi_t = c_min / Ybar_t;
the same share for both tenures, set on the owners' profile; the floor is
also the lowest consumption of a solvent household; bankruptcy is
involuntary only. Decided (Quinn, 26 October 2026): adopted in production at
c_min = 5,000, as ladder step 18. At step 16 with it, about 1% of owners with
maintenance on the purchase price went bankrupt, all while the mortgage ran,
and 15-17% of renters by 100 (`docs/HANDOFF_2026-10-26.md`). Open: the source
of c_min. With a bequest motive a bankrupt household is valued as leaving
`beq_bankrupt` years of its floor consumption (Quinn, 27 October 2026): a
household that leaves nothing has a bequest utility of minus infinity at
gamma > 1, and with no bequest term at all bankruptcy would escape the
bequest penalty.

### The top-up floor (`phi_floor`, used when the absorbing floor is off)

When a household's liquid resources fall short of `phi_floor * Y_t`, the
shortfall is paid from outside: it consumes the floor and saves nothing. The
floor is also the lowest consumption a household can choose when it can afford
more: the consumption search runs from the floor up to all liquid resources.
It is a share of current gross income so that the model stays homothetic; in
retirement Y is constant, so it is a level floor where it binds.

Utility is unbounded below at gamma > 1, so the floor has to be positive. At
1e-6 ruin stays nearly catastrophic: one floored year outweighs a lifetime of
ordinary consumption in double precision, so expected utility counts floored
years, the early-life value function does not converge, and welfare levels
should not be read. Floors of 0.10–0.20 of income make early life well
behaved at production housing costs but are a different model, and they bind
in a few percent of household-years. A floor proportional to gross income
cannot represent a level social minimum: setting it to the net AOW
(`1 - tau_inc` = 0.618) guarantees 62% of a rising wage in working life and
binds in 60% of household-years. The floor is not set to the social minimum.
It stays a numerical device, and the early-life problem is left to the
housing outflow (TODO.md, item 1).

Until 15 October 2026 the lower bound of the consumption search was
`c_floor_frac` = 1% of total wealth (house or rent index included), capped at
half of liquid resources. On the converged step-7 grids it set the owner's
consumption for most of the life cycle; `docs/SOLVER_BOUNDS.md` has the
measurements. `r.checks.c_bound_25_39` now reports the share of households
aged 25-39 who choose to consume only the floor.

## Entry state

| Parameter | Value | Derivation |
|---|---|---|
| `b0` | 0.0791 | Placeholder. EUR 3,400 median deposits (main earner under 25) / EUR 43,002 men's age-25 wage in 2024 euros |
| `b_alt` | 0.2279 | Placeholder. Same with the 25–35 deposits cell, EUR 9,800 |

Deposits are CBS 83834NED component 1.1.1, stock at 1-1-2024, the latest
published year. Both sides are in 2024 euros deliberately: CPI scaling cancels
in the ratio. The denominator is the men's wage because the model runs
`sex = 1`, and the buffer is measured in years of the modelled agent's income.

The denominator is out of date. It is the BKV men's wage, while the income
profile is now the pooled DHS cubic (EUR 33,829 at 25 for both tenures, 2025
euros), so both values stay placeholders until the buffer is measured against
the DHS income (TODO.md, section 2).

Simulated households enter with `b0` years of income in liquid wealth, and the
value at entry is read there (`utility.welfare_anchor`); both entry states are
exact grid nodes.

## CGM core (ladder step 1)

| Parameter | Value | Source |
|---|---|---|
| `gamma` | 10 | CGM (2005) baseline |
| `income_source` | `'poly'` | CGM income units |
| `income_coef`, `income_coef_rent` | [0.530339, 0.16818, -0.323371, 0.19704] for both | CGM (2005) Table 1, high-school group (age terms; the level is not used) |
| `sigma_l_log`, `sigma_l_log_rent` | 0.1032 for both | CGM (2005) high-school group, permanent shock std |
| `replacement` | 0.68212 | CGM (2005), high-school group |
| `retirement_age` | 65 | CGM (2005) |
| `r` | 0.02 | CGM (2005) |
| `mu_S_level`, `sigma_S_level` | 0.04, 0.157 | CGM (2005) |
| `corr_SL` | 0 | CGM (2005) baseline |
| `corr_HL`, `corr_HL_rent`, `corr_SH`, `corr_SH_rent` | 0 | No housing correlations until step 8 |
| `h_rule`, `kappa_base` | `'none'`, 0 | No housing, no DC pillar |
| `reit_risky`, `tau_REIT`, `corr_RL`, `corr_RS`, `corr_RH`, `corr_RH_rent` | 0 | No REIT until step 19 |
| taxes | 0 | None |

Renters and owners share this income process until the income step (4), so
steps 1–3 have one no-housing arm. Deviations kept throughout the ladder:
entry at 25 rather than 20, a terminal age of 100, Dutch unisex mortality, and
no transitory income shock.

The rest of the ladder: 4 income (the DHS values above), 5 market (`r`,
`mu_S_level`, `sigma_S_level` above), 6 `corr_SL` = 0.04. From step 6 it
branches. Housing: 7 housing (`h_fixed` 4 and the housing dynamics above, no
housing correlations), 8 the housing correlations above. DC pension, without
housing: 9 `kappa_base` 0.186 with an all-bond fund (`glide_cap` 0), 10 an
all-stock fund (`glide_cap` 1, `glide_span` 1, `tau_decum` 1), 11 the
production glide above, 12 `replacement` 0.307. Retirement income stays at
CGM's 68.2% of final income through step 11. Step 13 puts housing (step 8)
together with the AOW and the DC pension; 14 and 15 add the taxes. Steps
7–15 keep the house at 4 times entry income (`h_rule = 'fixed'`); 16 sets it
by the Nibud rule, 17 charges owners' maintenance on the purchase price, 18
adds the absorbing floor, and 19 puts half the glide's risky share in the REIT
(REIT section above).

Around step 12, `ladder.sensitivity` moves `replacement` to 0.20 and 0.40 and
`kappa_base` to 0.10 and 0.30, one at a time. These are illustrative values for
a sensitivity, not calibration.

## Numerics

Not calibration targets; accuracy choices, justified by convergence checks.

| Parameter | Value | Note |
|---|---|---|
| `grid_dims` | [32 16 40 4] | Base nodes on (u1, u2, u3, q); the entry anchors add up to two on u1 and u2, and q = 1 one on q. Where q is not a state the q axis is the single node 1. Quinn, 26 October 2026 ([20 20 12 8] before), from refining each axis on its own at step 16 with the absorbing floor at EUR 5,000 (`docs/HANDOFF_2026-10-26.md`): u2 and q change nothing at 32 and 64 or 8 and 16 points; u3 matters most and settles between 40 and 80; u1 moves young households and is still moving at 64. Nothing settles before about 35-40. One owner solve takes about 100 minutes with maintenance on the current value and about 4 hours on the purchase price (two solves side by side, 16 cores) |
| `gh_n` | 5 | Gauss-Hermite nodes per shock; 3 and 5 gave the same policies wherever compared, and 5 and 7 at step 16 with the absorbing floor |
| `gh_n_reit` | `[]` | Nodes for the REIT shock; `[]` takes `gh_n`, so 5 (Quinn, 29 October 2026). The joint quadrature then has 625 nodes against 125 without the REIT. The 28 October full-grid REIT solves used 3 (375 nodes) and took 2.65 times (renter) and about 3.1 times (owner) the time without the REIT; 3 against 5 has not been compared |
| `use_refine` | true | Global (c, pi) sweep before fmincon at every node. Without it the local solve lands on the wrong peak: at step 2 the equity share at 93-99 was up to 0.09 too low, and at the production calibration (quick numerics) the mean liquid equity share was off by up to 0.24 |
| `fmincon_algorithm` | `'active-set'` | Local solve after the sweep (Quinn, 24 October 2026; `'interior-point'` before). At step 16 with the absorbing floor at EUR 5,000, sweep plus active-set (with `N_c` 11) gave the same life cycles as sweep plus interior-point (owner 24x24, renter 32x32: consumption within 0.05%, liquid equity share within 0.012 through 95), solved in 27 and 16 minutes instead of 44 and 28, and settled for a worse choice than another routine found at fewer grid points (one-step test: owner 1.2% against 1.7%, renter 0.3% against 0.5%). `'interior-point'` stays an option and is the robustness check (`ladder.robustness`); `'sqp'` settled for a worse choice at up to a third of the grid points at 66. Active-set and interior-point give the same answer on a thread pool and a process pool; sqp did not at step 1 (HANDOFF, 24 October) |
| `fmincon_objective` | `'ce'` | What the local solve minimises. `'ce'`: the Bellman objective in certainty-equivalent units relative to the seed, `-(rhs/rhs_seed)^(1/(1-gamma))`, a monotone transform with the same optimum, equal to -1 at the seed at every node and finite as consumption goes to zero (suggested by the coauthor, 15 October 2026). `'utility'`: the objective in utility units divided by the median absolute value of next period's V, as before 15 October 2026 |
| `N_c` | 11 | Sets the consumption step of the sweep's shrinking rounds: the second round searches (1 - c_floor)/(4(N_c - 1)) on either side of the first round's best point. 11 makes that the first round's half-step, so the rounds leave no gap (docs/SOLVER_BOUNDS.md, section 2); with 41 (before 24 October 2026) they left points 0.006-0.025 of liquid resources away unsearched. With active-set, 11 cut the grid points settling for a worse choice further at no cost in time |
| `N_pi` | 41 | Sets the equity-share step of the sweep's shrinking rounds (the second round starts at the first round's full step, 0.05) |
| `interp_method` | `'linear'` | Linear in z. `'makima'` serves as a structural error check |
| `abs_node_test` | true | With the absorbing floor only. The value jumps at the edge of bankruptcy (just above it a household keeps its pot, house and income; just below it loses them), and interpolating across the jump misprices the states next to it. True: next year's liquid resources are formed at every quadrature node, and where they fall below next year's floor the node takes the bankrupt value exactly; only the solvent side is interpolated. Without the absorbing floor it changes nothing. On by default since 24 October 2026 (Quinn): at c_min 8,000 on the step-16 grid set it left consumption, bankruptcy and the entry value within half a point, about halved the old-age equity-share gaps between grids, and cut the largest ruin-corner error by a fifth (HANDOFF, 24 October) |
| `pi_nothing_saved` | `'limit'` | The equity share stored at grid points where nothing is saved (c = 1), where it has no effect on the value. `'limit'`: the share the household would choose for a vanishing saving (Quinn, 26 October 2026, with the bunched grid it was tested on; at ladder step 10 `'one'` put an equity share of 0.37-0.45 on savers at 66 whose true share was about 0.01, HANDOFF 16 October). `'one'`: 100% in equity (the default from 15 to 26 October 2026). It matters through interpolation: a household that does save, in a cell next to such a point, takes part of its share |
| `lambda_lo` | `[]` | 0.0008, or 0.0002 with housing. With house prices at 3.73% real and 8.35% vol, owners reach u1 = 0.0005 at 85+; 0.0008 clipped 0.02% of their household-years |
| `lambda_hi` | `[]` | `min(0.9, 3/(1 + h_mult))`, or 1 without housing |
| `grid_pow`, `grid_pow_u2` | 3, 3 | u1 nodes bunched toward its bottom (large resources over income) and u2 nodes toward 1 (little liquid saving beside the pot and house); on u1 close to even spacing in the log of resources over income (Quinn, 26 October 2026; 1, evenly spaced, before). The uniform 20x20 grid was 6-14% off in owner consumption at step 16 with the absorbing floor. See GRIDS.md |
| `u2_lo`, `u3_lo`, `u3_hi`, `grid_nodes` | full axes | Placement; see GRIDS.md |
| `grid_pow_u3` | 1 | The u3 axis: nodes `u3_lo + (u3_hi - u3_lo) * s^grid_pow_u3` for s uniform on [0, 1]; above 1 the nodes bunch toward u3 = 0. 1, evenly spaced (Quinn, 26 October 2026): at 40 points it is closest to 80 points for renters (within 1% in consumption), whose households sit at u3 0.07-0.83; owners on the current value do better bunched (power 2, old owners at u3 0.04-0.2), but with maintenance on the purchase price u3 hardly changes owner results. See GRIDS.md |
| `q_hi`, `grid_pow_q` | 2.5, 2 | The q axis: nodes `q_hi * s^grid_pow_q` for s uniform on [0, 1]. Owners' q from the house-price process, 0.1th-99.9th percentile: 0.53-1.44 at 29, 0.10-1.45 at 54; the most extreme quadrature node takes q = 1.6-1.95. `q_hi` was 2 at first; in the simulator's own draws at standard numerics (10,000 owners, ages 25-54, steps 7b and 8) q passed 2 in 2 of 300,000 household-years (largest 2.04-2.06) and never passed 2.5 (Quinn, 15 October 2026). `grid_pow_q` is a starting value, to be checked by refinement |

At the default grid, behaviour from about 40 on changes by under 2% in
consumption when any one axis is refined further (step 16, absorbing floor at
EUR 5,000). Early life is not converged at any grid tried, and welfare levels
(the entry value) still move with every refinement (`docs/HANDOFF_2026-10-26.md`).
