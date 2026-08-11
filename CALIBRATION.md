# Calibration

Sources and reasoning for every value in `+config/params.m`. The file itself
keeps one-line comments; the detail lives here.

## Price-year convention

All euro-denominated inputs are in **2025 euros** — the last complete calendar
year, so the CBS annual CPI is final and the statutory amounts are settled.

Only two inputs carry a price year: `income_price_factor` and `franchise`.
They must move together, because the contribution rate compares income to the
franchise and mixing years silently misstates it at every age. Everything else
in `params.m` is a real or unit-free rate and has no price year. `b0`/`b_alt`
are a ratio of same-year euros and so are price-level-free.

A 2026 base was tried and rejected: 2026 is still running, so its factor could
only come from a part-year CPI average that CBS will revise.

## Timing, mortality, preferences

| Parameter | Value | Source |
|---|---|---|
| `age0` | 25 | The BKV income table's first non-baseline age, so the working profile needs no below-sample extrapolation |
| `retirement_age` | 67 | Statutory AOW eligibility, 2026 |
| `T` | 76 | Set so the terminal age stays 100 |
| `p_surv` | age profile | CBS life table 2021–2026, sexes combined (`CBSunisexmortality21-26.csv`, StatLine 37360ned) |
| `sex` | 1 (men) | Selects the income profile only — the life table is unisex |
| `gamma` | 5 | Cocco, Gomes & Maenhout (2005) |
| `beta` | 0.96 | Larsen et al. (2023) |
| `chi` | 0 | Bequest motive off in the baseline |

## Labour income

The working-age profile is a direct lookup of the semi-parametric age effects
in Been, Knoef & Vethaak (2026, JBES 44(1):215–226), Online Appendix Tables
D.1 (men) and D.2 (women), "Full-time, Selection" column. No curve fitting or
smoothing: ages 24–64 each get their published coefficient.

Two edges are outside the estimation sample:

- Below 24 the series would be linearly extrapolated from the slope of ages
  24–27. With `age0 = 25` this path is never taken; it stays as a guard.
- Above 64, relevant because retirement is at 67, growth is held **flat** at
  the age-64 value. Extrapolating the pre-64 decline is unreliable this close
  to the sample edge.

| Parameter | Value | Source |
|---|---|---|
| Euro anchor | EUR 33,000 at age 25 (men), 2015 prices | BKV Section 3.2.3 descriptives |
| `income_price_factor` | 1.3456 | CPI(2025)/CPI(2015) = 134.56/100, CBS 83131NED. BKV express wages in 2015 euros (their Section 3.1) |
| `sigma_l_log` | 0.1032 | CGM (2005) high-school group, **permanent** shock std |
| `replacement` | 0.307 | DNB, *Toereikendheid van pensioenen*, Table 3, median first-pillar replacement rate |

`sigma_l_log` is the permanent component because this model's income process
is a pure random walk — every shock compounds forward. CGM's transitory
component (std 0.2717) has no home in a single-shock structure and is simply
omitted.

`income_coef` holds a CGM (2005) age cubic for the alternative
`income_source = 'poly'` path, retained for robustness comparisons. It is US
data and hump-shaped; some evidence suggests Continental-European profiles are
closer to monotone, so the shape itself is a live question if that path is ever
used.

## Pension

Contributions are levied on income above a franchise, so the effective rate on
gross income rises with income and is an age profile rather than a scalar:

```
kappa_t = kappa_base * max(Y_t - F, 0) / Y_t
```

giving roughly 10.9% at 25 rising to 14.6% around age 55.

| Parameter | Value | Source |
|---|---|---|
| `kappa_base` | 0.186 | OECD *Pensions at a Glance*: the 2022 country note gives 18.6% as the rate above the franchise; the 2025 edition (Table 3.4) repeats the number without restating that |
| `franchise` | EUR 18,475 | Minimum AOW-franchise per 1-1-2025, art. 18a lid 3 Wet LB, Belastingdienst CAP. The 2026 figure is EUR 19,172 and belongs only with a 2026 income factor |

`kappa_t` is evaluated on the **deterministic** income profile, not each
household's realised income. A rate depending on realised `Y` would break the
normalised state space, since only `lambda = Y/W` is a state and the euro level
of `Y` is not. The calibration specifies `kappa_t` as an age profile, which is
exactly this object.

Open: this should really be an aggregate participant-weighted rate across Dutch
funds (DNB or Pensioenfederatie), not a single OECD figure.

## Taxes

The DC account gets EET treatment: contributions are deductible, the fund grows
untaxed, and both the annuity payout and AOW are taxed as income on receipt.
Working take-home is therefore `(1 - kappa)(1 - tau_inc) Y`.

| Parameter | Value | Source |
|---|---|---|
| `tau_inc` | 0.382 | CBS, average tax burden on income, 2019. This is the paper's `delta` |
| `tau_cg_bond`, `tau_cg_stock` | 0 | Accrual CGT on the liquid account, no loss offset. No rate yet |
| `tau_wealth` | 0 | Box-3-style levy on the liquid account balance. Calibrated value is 0.0197 (Hambel et al. 2026), currently switched off |
| `delta` | 0 | A separate legacy wedge on gross income, distinct from the paper's `delta`. Dead |

Both tax instruments are kept wired in rather than collapsed into one, because
they represent different regimes: the proposed box-3 successor is return-based
with loss carry-forward, which is a CGT, while the current deemed-return levy
on the balance is a wealth tax, and a court ruling already lets taxpayers elect
realised returns when those are lower. Switching regimes should be a
calibration change, not a code change.

With `tau_wealth = 0` and both CGT legs at 0, the DC account's tax advantage
today comes entirely from EET, not from any capital-gains differential.

At the calibrated `tau_wealth = 0.0197` the liquid account's safe return turns
negative in real terms (`1.011 * 0.9803 - 1 = -0.89%`) against `+1.10%` inside
the sheltered fund. That wedge drove the no-DC benchmark to hoard savings and
inflated the DC-versus-no-DC comparison substantially, which is why it is
currently off. Restoring it needs nothing but the value.

## Financial markets

`mu_S_level` is the **excess** return over the risk-free rate; the housing
drift `mu_H_level` is the house's own return, not excess.

| Parameter | Value | Source |
|---|---|---|
| `r` | 0.011 | Mean 3-month Dutch T-bill rate less mean inflation, real |
| `mu_S_level` | 0.04 | Equity premium |
| `sigma_S_level` | 0.16 | Equity return volatility |
| `mu_H_level` | 0.027 | BIS Real Residential Property Price Index (NL), CPI-deflated |
| `sigma_H_level` | 0.037 | Same |
| `mu_R_level` | *(placeholder: `mu_H_level`)* | Real rent growth, mean — to be filled from the rent estimate |
| `sigma_R_level` | *(placeholder: `sigma_H_level`)* | Real rent growth, vol — same |
| `corr_SL`, `corr_HL`, `corr_SH` | 0 | Not yet estimated |

The correlations are wired through a Cholesky factor in both `grids.shock_grid`
and `simulate.paths`, so giving them values costs nothing in runtime or node
count. Each represents the covariance of a single composite income shock: with
no aggregate/idiosyncratic split, one number absorbs both channels. `corr_HL`
is the third shock's correlation with income, so it means corr(house return,
income) for an owner and corr(rent growth, income) for a renter.

## The rent process

The `H` state carries a different object in each scenario. For an owner it is
the house, and its growth factor is the house-price return. For a renter it has
no resale or bequest value — its only role is to set the rent `alpha * H_t` —
so it is a rent index, and its growth factor is the rent increase. Those are
distinct processes and are calibrated separately: `config.h_process` returns
`(mu_R, sigma_R)` for renters and `(mu_H, sigma_H)` for owners, and both
`grids.shock_grid` and the simulators draw from whichever pair it hands back.

Both are lognormal growth factors, so log rent is a random walk with drift
under either tenure and no state variable is added. A p-struct predating the
split has no rent fields and falls back to the housing pair, which is what
every earlier solve assumed.

`mu_R_level` and `sigma_R_level` must be **real** (CPI-deflated), on the same
footing as `mu_H_level`. Published Dutch rent-increase series are nominal, and
substituting one directly makes the renter's position worse rather than better.

The rent drift is the single most consequential number for the renter arm. Rent
compounds for all 76 model years while retirement income is flat in real terms
after the 0.307 replacement drop, so the renter's burden is governed by the
growth differential compounded over the 33 retirement years. At `mu_R_level =
mu_H_level = 0.027` the median rent reaches roughly 240% of net retirement
income at 67 and 570% at 100, which is what drives the zero-consumption
incidence in the renter arms.

## Housing

| Parameter | Value | Source |
|---|---|---|
| `alpha` | 0.06 | Rent-to-price ratio, Yao & Zhang (2005) and Fischer |
| `theta` | 0.015 | Maintenance, Yao & Zhang (2005); Nibud's 1% plus local taxes |
| `h_mult` | 4.0 | `H_0 = h_mult * Y_0`. Placeholder |
| `r_m` | 0.0136 | ECB MIR, NL cost of borrowing for house purchase, May 2026: 3.66% nominal less 2.3% inflation |
| `N_mort` | 30 | Standard Dutch annuity mortgage term |
| `LTV` | 1.00 | Asserted — see below |
| `sell_cost` | 0.025 | Seller transaction cost at bequest, Hambel et al. (2026). Inert while `chi = 0` |

The mortgage is a **homothetic approximation**: the annuity payment rate is
applied to the current house value rather than the original one, so there is no
mortgage-balance state. The payment therefore grows with the house price
instead of staying level. Correcting this needs a fourth state variable, and
the runtime cost was judged not worth it. In the paper, present the
institutional contract first and then state the approximation — it attenuates
the fixed-versus-floating hedging asymmetry, so the owner/renter welfare gap is
a lower bound along that dimension.

`LTV` is asserted equal to 1.00 because that is the only value consistent with
the rest of the model: the household is endowed with the house at `t = 1` with
`X_0 = 0` and services a mortgage on its full value. Anything below 1 needs a
down-payment endowment (a negative initial `X`) that the simulator does not
model, so it fails loudly rather than half-running.

`h_mult = 4.0` is a placeholder. The intended replacement is an
income-contingent assignment estimated from LISS (log house value at purchase
on log income plus age and cohort controls), with the Nibud loan-to-income
tables as a feasibility ceiling rather than the primary source — not everyone
borrows to the ceiling.

## Welfare anchors

| Parameter | Value | Derivation |
|---|---|---|
| `b0` | 0.0791 | EUR 3,400 median deposits (main earner under 25) / EUR 43,002 men's age-25 wage in 2024 euros |
| `b_alt` | 0.2279 | Same with the 25–35 deposits cell, EUR 9,800 |

Deposits are CBS 83834NED component 1.1.1, stock at 1-1-2024, the latest
published year. Both sides are in 2024 euros deliberately: CPI scaling cancels
in the ratio, so no rebasing is needed when the file's price year moves.

The denominator is the **men's** wage because production runs `sex = 1`, and
the buffer is measured in years of the modelled agent's income.

## Grids

Not calibration targets. `gh_n`, `N_lambda`, `N_sA`, `N_sH`, `N_c`, `N_pi` are
solver accuracy choices, justified by convergence checks rather than estimated
from data.

`N_c` must stay fine — the objective is multimodal in consumption and a coarse
grid seeds the wrong basin. `N_pi` looks coarsenable because the objective is
flat in the equity share near the optimum, but coarsening it makes the equity
policy noisy and biased low even while the value function barely moves. Keep
both at 41.
