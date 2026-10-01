# Calibration

Sources and reasoning for every value in `+config/params.m`. The file itself
keeps one-line comments; the detail lives here. `+ladder/steps.m` builds the
same calibration up from a CGM (2005) core; the values that core uses are at
the end.

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
| `gamma` | 5 | Production choice. CGM (2005) use 10; the ladder starts there |
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

The first pillar is `replacement` times final working income rather than a
flat AOW amount, which keeps the model homothetic. It removes the floor that a
flat AOW gives households with a bad history of permanent shocks.

`income_coef` holds a CGM (2005) age cubic for `income_source = 'poly'`, used
by the first ladder steps. It is US data and hump-shaped, and its level is not
in euros, so it cannot be combined with a DC pillar (the franchise is a euro
amount); `config.derive` refuses that combination.

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
premium on the liquid account from 4.0% to about 1.2% and the Merton share at
gamma = 5 from about 0.31 to 0.16. A symmetric tax at the same rate leaves the
Sharpe ratio unchanged and raises the Merton share to about 0.49. The
government becomes a silent partner (Domar-Musgrave). `cg_loss_offset = true`
switches to the symmetric tax.

Both instruments are kept rather than collapsed into one, because they
represent different regimes: the proposed box-3 successor is return-based with
loss carry-forward, which is a CGT, while the current deemed-return levy on the
balance is a wealth tax. Switching regimes should be a calibration change, not
a code change.

At the calibrated `tau_wealth = 0.0197` the liquid account's safe return turns
negative in real terms (`1.011 * 0.9803 - 1 = -0.89%`) against `+1.10%` inside
the sheltered fund.

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
| `mu_R_level` | 0.0097 | Real rent growth, mean — own estimate. Consistent with the regulated-sector cap formula (CPI or wage growth, plus about 1pp) |
| `sigma_R_level` | 0.018 | Real rent growth, vol — same estimate. See the caveat below |
| `corr_SL`, `corr_HL`, `corr_SH` | 0 | Not yet estimated |

The correlations are wired through a Cholesky factor in both `grids.shock_grid`
and `simulate.paths_lna`, so giving them values costs nothing in runtime or node
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
`(mu_R, sigma_R)` for renters and `(mu_H, sigma_H)` for owners.

`mu_R_level` and `sigma_R_level` must be **real** (CPI-deflated), on the same
footing as `mu_H_level`. Published Dutch rent-increase series are nominal, and
substituting one directly makes the renter's position worse rather than better.

The rent drift is the most consequential number for the renter arm. Rent
compounds for all 76 model years while retirement income is flat in real terms
after the replacement drop, so the renter's burden is governed by the growth
differential compounded over the retirement years. Setting `mu_R_level` to the
house-price drift of 0.027, which the model did before the processes were
separated, puts median rent at roughly 240% of net AOW at 67.

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
— 0.0097 against 0.027 implies the rent-to-price ratio falls from `alpha` = 6%
to about 1.7% over the horizon. Nothing in the model requires consistency,
because tenure is fixed at t = 1 and no household ever faces both processes.

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

For a renter, `alpha` and `h_mult` enter only as the product `alpha * h_mult`:
the rent at entry is 24% of gross income, about 44% of net income after tax
and contributions. That committed outflow, which the household cannot reduce,
is what makes early life ill-conditioned at this calibration (README). The
owner's equivalent is maintenance plus the mortgage payment.

The mortgage is a **homothetic approximation**: the annuity payment rate is
applied to the current house value rather than the original one, so there is no
mortgage-balance state. The payment therefore grows with the house price
instead of staying level. Correcting this needs a fourth state variable. In the
paper, present the institutional contract first and then state the
approximation — it attenuates the fixed-versus-floating hedging asymmetry, so
the owner/renter welfare gap is a lower bound along that dimension.

`LTV` is asserted equal to 1.00 because that is the only value consistent with
the rest of the model: the household is endowed with the house at `t = 1` with
`X_0 = b0 * Y_0` and services a mortgage on its full value. Anything below 1
needs a down-payment endowment the model does not have, so it fails loudly
rather than half-running.

`h_mult = 4.0` is a placeholder. The intended replacement is an
income-contingent assignment estimated from LISS (log house value at purchase
on log income plus age and cohort controls), with the Nibud loan-to-income
tables as a feasibility ceiling rather than the primary source — not everyone
borrows to the ceiling.

## Consumption floor

| Parameter | Value | Source |
|---|---|---|
| `phi_floor` | 1e-6 | Placeholder for the social minimum |
| `c_floor_frac` | 0.01 | Lower bound of the consumption search, as a share of total wealth |

When a household's liquid resources fall short of `phi_floor * Y_t`, the
shortfall is paid from outside: it consumes the floor and saves nothing. The
floor is a guarantee, not a mandate — a household that can afford it may still
consume less. It is a share of current gross income so that the model stays
homothetic; in retirement Y is constant, so it is a level floor where it binds.

Utility is unbounded below at gamma > 1, so the floor has to be positive. At
1e-6 ruin stays nearly catastrophic: one floored year outweighs a lifetime of
ordinary consumption in double precision, so expected utility counts floored
years, the early-life value function does not converge, and welfare levels
should not be read. Floors of 0.10–0.20 of income make early life well
behaved at production housing costs but are a different model, and they bind
in a few percent of household-years. A floor proportional to gross income
cannot represent a level social minimum: setting it to the net AOW
(`1 - tau_inc` = 0.618) guarantees 62% of a rising wage in working life and
binds in 60% of household-years. The floor is the first calibration decision
the research points to; see TODO.md.

`c_floor_frac` is a numerical bound, but where households would consume less
than 1% of total wealth, which is early life at this calibration, it is the
bound that sets consumption. `r.checks.c_bound_25_39` reports how often.

## Entry state

| Parameter | Value | Derivation |
|---|---|---|
| `b0` | 0.0791 | EUR 3,400 median deposits (main earner under 25) / EUR 43,002 men's age-25 wage in 2024 euros |
| `b_alt` | 0.2279 | Same with the 25–35 deposits cell, EUR 9,800 |

Deposits are CBS 83834NED component 1.1.1, stock at 1-1-2024, the latest
published year. Both sides are in 2024 euros deliberately: CPI scaling cancels
in the ratio. The denominator is the men's wage because the model runs
`sex = 1`, and the buffer is measured in years of the modelled agent's income.

Simulated households enter with `b0` years of income in liquid wealth, and the
value at entry is read there (`utility.welfare_anchor`); both entry states are
exact grid nodes.

## CGM core (ladder step 1)

| Parameter | Value | Source |
|---|---|---|
| `gamma` | 10 | CGM (2005) baseline |
| `income_source`, `income_coef` | `'poly'`, cubic above | CGM (2005) Table 1, high-school group (age terms; the level is not used) |
| `replacement` | 0.68212 | CGM (2005), high-school group |
| `retirement_age` | 65 | CGM (2005) |
| `r` | 0.02 | CGM (2005) |
| `mu_S_level`, `sigma_S_level` | 0.04, 0.157 | CGM (2005) |
| `h_mult`, `kappa_base` | 0 | No housing, no DC pillar |
| taxes | 0 | None |

Deviations kept throughout the ladder: entry at 25 rather than 20, a terminal
age of 100, Dutch unisex mortality, and no transitory income shock.

## Numerics

Not calibration targets; accuracy choices, justified by convergence checks.

| Parameter | Value | Note |
|---|---|---|
| `grid_dims` | [20 20 12] | Base nodes on (u1, u2, u3); the entry anchors add up to two on u1 and u2 |
| `gh_n` | 5 | Gauss-Hermite nodes per shock; 3 and 5 gave the same policies wherever compared |
| `use_refine` | true | Global (c, pi) sweep before fmincon at every node |
| `N_c`, `N_pi` | 41 | Set the step sizes of the sweep's shrinking rounds |
| `interp_method` | `'linear'` | Linear in z. `'makima'` serves as a structural error check |
| `lambda_lo` | 0.0008 | Owners reach u1 = 0.0013; 0.002 clipped them |
| `lambda_hi` | `[]` | `min(0.9, 3/(1 + h_mult))`, or 1 without housing |
| `grid_pow`, `grid_pow_u2`, `u2_lo`, `u3_lo`, `u3_hi`, `grid_nodes` | uniform, full axes | Placement; see GRIDS.md |

At the default grid, behaviour from 40 on is stable to a few percent. Early
life at the production calibration is not converged at any grid tried (README).
