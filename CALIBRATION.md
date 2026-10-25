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
| `chi` | 0 | Placeholder. Bequest motive off in the baseline |

## Labour income

The working-age profile is a cubic in age estimated on gross income of the
household head in the DNB Household Survey (DHS), waves 1993–2024, heads aged
25–65, separately for owners and renters (Quinn's calibration notes, 12 Oct
2026, Table 3, gross):

```
log y = a0 + a1 age + a2 age^2/10 + a3 age^3/100
```

in log euros of 2025. The code's cubic divides by 100 and 1e4 instead, so the
code coefficients are `[a0, a1, 10 a2, 100 a3]`. Owners use `income_coef` and
`sigma_l_log`, renters `income_coef_rent` and `sigma_l_log_rent`
(`config.income_process`). A step without housing whose two sets differ is
solved for both tenures (`model.tenures_differ`).

| Parameter | Value | Source |
|---|---|---|
| `income_source` | `'dhs'` | The DHS cubic, in euros |
| `income_coef` | [7.7979, 0.17253, -0.2784, 0.1405] | Owners, Table 3. EUR 39,763 at 25, peak 74,656 at 50 |
| `income_coef_rent` | [7.5302, 0.17828, -0.3126, 0.1784] | Renters, Table 3. EUR 30,098 at 25, peak 52,013 at 49 |
| `dhs_price_factor` | 1.0 | The DHS euros are already in 2025 prices |
| `sigma_l_log` | 0.0816 | Owners, permanent shock std, Table 3 |
| `sigma_l_log_rent` | 0.0843 | Renters, permanent shock std, Table 3 |
| `replacement` | 0.307 | DNB, *Toereikendheid van pensioenen*, Table 3, median first-pillar replacement rate |

Table 3 reports 39,749 and 74,557 (owners) and 30,094 and 51,972 (renters);
the gap is coefficient rounding. The sample ends at 65, so age 66, the last
working year, is the cubic extrapolated one year.

`sigma_l_log` is the permanent component because this model's income process
is a pure random walk — every shock compounds forward. The transitory
component (DHS std 0.119 for owners and 0.138 for renters; CGM 0.2717) has no
home in a single-shock structure and is omitted.

Without a franchise the model is homothetic in income, so the owners' higher
level does not matter before the DC pillar enters; until then the tenures
differ through the shape of the profile and the shock std.

Planned (Quinn, 23 October 2026): owners and renters will use the same income
polynomial, a DHS cubic estimated on owners and renters pooled. The separate
cubics above are what the code uses until Quinn sends the pooled coefficients
and the change is implemented. Whether the shock std is shared too is open
(TODO.md, section 2).

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
| `glide_cap`, `glide_span` | 0.8, 35 | Fund equity share `min(0.8, years to retirement / 35)`: 0.8 until 39, linear to 0 at 67. A stylised lifecycle fund |
| `tau_decum` | `[]` | Fund equity share in retirement; empty keeps the glide's 0 (an all-bond fund) |

`kappa_t` is evaluated on the **deterministic** income profile, not each
household's realised income. A rate depending on realised `Y` would break the
normalised state space, since only `lambda = Y/W` is a state and the euro level
of `Y` is not. The calibration specifies `kappa_t` as an age profile, which is
exactly this object.

The DC pot earns the survival credit 1/p_t from age 25, not only in
retirement, and is converted at 67 into a variable annuity whose price `a_t`
keeps expected payouts level: `a_t = 1 + p_t a_{t+1} / E[R^A]`. Whatever
equity share the fund holds in retirement is priced in.

Open: `kappa_base` should be an aggregate participant-weighted rate across
Dutch funds (DNB or Pensioenfederatie), not a single OECD figure.

## REIT in the DC fund

A second risky asset held only inside the DC fund, with the stock and bond
legs; the bond leg is `1 - tau_S - tau_REIT`. It is a fourth lognormal shock,
and a zero share with zero correlations removes it from the quadrature
altogether, so the baseline pays nothing for it.

| Parameter | Value | Source |
|---|---|---|
| `tau_REIT` | 0 | Off in the baseline |
| `mu_REIT_level`, `sigma_REIT_level` | 0.03, 0.12 | Placeholders |
| `corr_RL`, `corr_RS`, `corr_RH` | 0 | Placeholders |

With these placeholders the REIT has the same Sharpe ratio as equity (0.25), so
the mean-variance split between the two is 57/43 whatever the correlations,
and the share is imposed rather than chosen. Real moments, and at least the
REIT-equity and REIT-housing correlations, are needed before the leg says
anything.

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
no household faces both processes, and the REIT is off.

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
| `maint_on_purchase` | false | true charges maintenance on the purchase price (a test, step 7b) |
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
`theta * H0`, instead of the current value. It is a test run as step 7b's
sensitivity, not the production setting.

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
| Income | gross household-head income at 25, single earner | DHS: EUR 39,763 owners, 30,098 renters |
| Increase | EUR 17,000 (`nibud_extra`) | The Tijdelijke regeling hypothecair krediet allows it for groups without personal unavoidable expenses; the workbook's calculator adds it by default for a single earner above the first income row |
| Energy-label amounts | none | The model has no energy label |

At production this gives `h_mult` = 4.446 for owners (share 21.6%) and 4.155
for renters (share 19.3%); without the increase, 4.018 and 3.591. The renter
follows the same rule on its own income, so its rent is `alpha` times the house
it could have bought.

What to keep in mind:

- The renter's entry income sits just above the first row, where the share
  rises fastest with income and where the increase starts.
- The table is in 2026 euros and income in 2025 euros. Raising both entry
  incomes by 3% moves the owner's multiple to 4.434 and the renter's to 4.306.
  The 2025 tables would match the price year.
- The box-1 shares assume the interest is deducted, which the model does not
  do. The box-3 table (no deduction) gives 3.57 for owners and 3.34 for
  renters.
- The norm tests the contract's nominal rate; `r_m` is real.
- The norm is a ceiling, and not everyone borrows to it. The intended
  assignment is still an income-contingent estimate from LISS (log house value
  at purchase on log income plus age and cohort controls), with this rule as
  its upper bound.

## Consumption floor

| Parameter | Value | Source |
|---|---|---|
| `phi_floor` | 1e-6 | A numerical bound, not a calibration target. 1e-4 is an admissible alternative |
| `c_min` | 0 (off) | The absorbing floor, euros a year (2025) at median labour income. Source open (Nibud minimum example budgets, spending after housing at the bijstand level); trial values 6,000, 8,000 and 10,000 |
| `phi_abs` | 0 (off) | The absorbing floor as one share of permanent labour income, the alternative to `c_min` |

### The absorbing floor (`c_min`, `phi_abs`)

Added on 23 October 2026 (`docs/prompts/absorbing_floor.md`); off until the
level is chosen. With `c_min > 0` or `phi_abs > 0` the floor is an absorbing
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
  included: the same share of income for owners and renters. Once both
  tenures use the pooled income cubic (Labour income, above), the owners'
  profile is the common one.
- `phi_abs`: phi_t = phi_abs to 66 and phi_abs / replacement from 67, that is
  phi_abs times permanent labour income, final labour income in retirement.

At most one of the two is positive, and `c_min` needs income in euros.
Both 0 gives the yearly top-up at `phi_floor` below. The floor stands for the
social minimum net of housing costs; the Dutch policy background and the
sources considered are in the prompt.

Decided (Quinn, 23 October 2026): the share by age, phi_t = c_min / Ybar_t;
the same share for both tenures, set on the owners' profile; the floor is
also the lowest consumption of a solvent household; bankruptcy is
involuntary only. Open: the value and source of c_min, and a bequest rule for
bankrupt households before `chi` is switched on (a household that leaves
nothing has a bequest utility of minus infinity at gamma > 1).

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
profile is now DHS household-head income (EUR 39,763 for owners and 30,098 for
renters at 25), so both values stay placeholders until the buffer is measured
against the DHS income, possibly by tenure (TODO.md, section 2).

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
by the Nibud rule.

Around step 12, `ladder.sensitivity` moves `replacement` to 0.20 and 0.40 and
`kappa_base` to 0.10 and 0.30, one at a time. These are illustrative values for
a sensitivity, not calibration.

## Numerics

Not calibration targets; accuracy choices, justified by convergence checks.

| Parameter | Value | Note |
|---|---|---|
| `grid_dims` | [20 20 12 8] | Base nodes on (u1, u2, u3, q); the entry anchors add up to two on u1 and u2, and q = 1 one on q. Where q is not a state the q axis is the single node 1 |
| `gh_n` | 5 | Gauss-Hermite nodes per shock; 3 and 5 gave the same policies wherever compared |
| `use_refine` | true | Global (c, pi) sweep before fmincon at every node. Without it the local solve lands on the wrong peak: at step 2 the equity share at 93-99 was up to 0.09 too low, and at the production calibration (quick numerics) the mean liquid equity share was off by up to 0.24 |
| `fmincon_algorithm` | `'active-set'` | Local solve after the sweep (Quinn, 24 October 2026; `'interior-point'` before). At step 16 with the absorbing floor at EUR 5,000, sweep plus active-set (with `N_c` 11) gave the same life cycles as sweep plus interior-point (owner 24x24, renter 32x32: consumption within 0.05%, liquid equity share within 0.012 through 95), solved in 27 and 16 minutes instead of 44 and 28, and settled for a worse choice than another routine found at fewer grid points (one-step test: owner 1.2% against 1.7%, renter 0.3% against 0.5%). `'interior-point'` stays an option and is the robustness check (`ladder.robustness`); `'sqp'` settled for a worse choice at up to a third of the grid points at 66. Active-set and interior-point give the same answer on a thread pool and a process pool; sqp did not at step 1 (HANDOFF, 24 October) |
| `fmincon_objective` | `'ce'` | What the local solve minimises. `'ce'`: the Bellman objective in certainty-equivalent units relative to the seed, `-(rhs/rhs_seed)^(1/(1-gamma))`, a monotone transform with the same optimum, equal to -1 at the seed at every node and finite as consumption goes to zero (suggested by the coauthor, 15 October 2026). `'utility'`: the objective in utility units divided by the median absolute value of next period's V, as before 15 October 2026 |
| `N_c` | 11 | Sets the consumption step of the sweep's shrinking rounds: the second round searches (1 - c_floor)/(4(N_c - 1)) on either side of the first round's best point. 11 makes that the first round's half-step, so the rounds leave no gap (docs/SOLVER_BOUNDS.md, section 2); with 41 (before 24 October 2026) they left points 0.006-0.025 of liquid resources away unsearched. With active-set, 11 cut the grid points settling for a worse choice further at no cost in time |
| `N_pi` | 41 | Sets the equity-share step of the sweep's shrinking rounds (the second round starts at the first round's full step, 0.05) |
| `interp_method` | `'linear'` | Linear in z. `'makima'` serves as a structural error check |
| `abs_node_test` | true | With the absorbing floor only. The value jumps at the edge of bankruptcy (just above it a household keeps its pot, house and income; just below it loses them), and interpolating across the jump misprices the states next to it. True: next year's liquid resources are formed at every quadrature node, and where they fall below next year's floor the node takes the bankrupt value exactly; only the solvent side is interpolated. Without the absorbing floor it changes nothing. On by default since 24 October 2026 (Quinn): at c_min 8,000 on the step-16 grid set it left consumption, bankruptcy and the entry value within half a point, about halved the old-age equity-share gaps between grids, and cut the largest ruin-corner error by a fifth (HANDOFF, 24 October) |
| `abs_fill` | `'none'` | With the absorbing floor and `abs_node_test` only (`derive` refuses it without the test). A quadrature node just above next year's floor sits in a grid cell with bankrupt corners, and interpolating there mixes the bankrupt value into a solvent state. `'nearest'`: in the continuation's interpolant each bankrupt grid point takes the certainty equivalent of its nearest solvent neighbour along the axes (the mean where there are several); `'linear'`: the straight line through the two nearest solvent points along an axis, extended to it, kept between the bankrupt value and the solvent neighbour's (`solver.fill_bankrupt`). The same fill is applied to the policies the simulation reads (kept between 0 and 1). The stored V keeps the bankrupt value, and the nodes below the floor still take it from the exact test. `'none'` is the setting of every solve before 24 October 2026 (evening). At step 16 (renter, c_min 5,000, bunched 16x16 with 10, 20 and 40 evenly spaced u3 points) `'nearest'` moved the life cycles further from 32x32 with 40 u3 points, not closer: less saving, bankruptcy by 85 at 9-12% against 1.8-2.3% on 32x32, where the fill changed little (HANDOFF, 25 October 2026, branch `edge-fix`). `'linear'` is untested |
| `pi_nothing_saved` | `'one'` | The equity share stored at grid points where nothing is saved (c = 1), where it has no effect on the value. `'one'`: 100% in equity (Quinn, 15 October 2026). `'limit'`: the share the household would choose for a vanishing saving, as the solver found it before 15 October with the upper bound 1 - 1e-6. It matters through interpolation: a household that does save, in a cell next to such a point, takes part of its share |
| `lambda_lo` | `[]` | 0.0008, or 0.0002 with housing. With house prices at 3.73% real and 8.35% vol, owners reach u1 = 0.0005 at 85+; 0.0008 clipped 0.02% of their household-years |
| `lambda_hi` | `[]` | `min(0.9, 3/(1 + h_mult))`, or 1 without housing |
| `grid_pow`, `grid_pow_u2`, `u2_lo`, `u3_lo`, `u3_hi`, `grid_nodes` | uniform, full axes | Placement; see GRIDS.md |
| `grid_pow_u3` | 1 | The u3 axis: nodes `u3_lo + (u3_hi - u3_lo) * s^grid_pow_u3` for s uniform on [0, 1]; above 1 the nodes bunch toward u3 = 0, where the oldest owners' pension pot is small beside the house. 1 is evenly spaced. See GRIDS.md |
| `q_hi`, `grid_pow_q` | 2.5, 2 | The q axis: nodes `q_hi * s^grid_pow_q` for s uniform on [0, 1]. Owners' q from the house-price process, 0.1th-99.9th percentile: 0.53-1.44 at 29, 0.10-1.45 at 54; the most extreme quadrature node takes q = 1.6-1.95. `q_hi` was 2 at first; in the simulator's own draws at standard numerics (10,000 owners, ages 25-54, steps 7b and 8) q passed 2 in 2 of 300,000 household-years (largest 2.04-2.06) and never passed 2.5 (Quinn, 15 October 2026). `grid_pow_q` is a starting value, to be checked by refinement |

At the default grid, behaviour from 40 on is stable to a few percent. Early
life at the production calibration is not converged at any grid tried (README).
