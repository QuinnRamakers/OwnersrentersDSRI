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
| `beta` | 0.96 | Larsen et al. (2023) |
| `chi` | 0 | Bequest motive off in the baseline |

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
| `r` | 0.0115 | Real NL 3-month interbank rate (FRED IR3TIB01NLM156N) deflated by the CBS CPI, mean 1982–2024. Calibration notes, Table 2 |
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
| `alpha` | 0.06 | Rent-to-price ratio, Yao & Zhang (2005) and Fischer |
| `theta` | 0.015 | Maintenance, Yao & Zhang (2005); Nibud's 1% plus local taxes |
| `h_mult` | 4.0 | `H_0 = h_mult * Y_0`. Placeholder |
| `r_m` | 0.0136 | ECB MIR, NL cost of borrowing for house purchase, May 2026: 3.66% nominal less 2.3% inflation |
| `N_mort` | 30 | Standard Dutch annuity mortgage term |
| `LTV` | 1.00 | Asserted — see below |
| `sell_cost` | 0.025 | Seller transaction cost at bequest, Hambel et al. (2026). Inert while `chi = 0` |

For a renter, `alpha` and `h_mult` enter only as the product `alpha * h_mult`:
the rent at entry is 24% of gross income, about 42% of net income after tax
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
binds in 60% of household-years. The floor is the first calibration decision
the research points to; see TODO.md.

Until 15 October 2026 the lower bound of the consumption search was
`c_floor_frac` = 1% of total wealth (house or rent index included), capped at
half of liquid resources. On the converged step-7 grids it set the owner's
consumption for most of the life cycle; `docs/SOLVER_BOUNDS.md` has the
measurements. `r.checks.c_bound_25_39` now reports the share of households
aged 25-39 who choose to consume only the floor.

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
| `income_source` | `'poly'` | CGM income units |
| `income_coef`, `income_coef_rent` | [0.530339, 0.16818, -0.323371, 0.19704] for both | CGM (2005) Table 1, high-school group (age terms; the level is not used) |
| `sigma_l_log`, `sigma_l_log_rent` | 0.1032 for both | CGM (2005) high-school group, permanent shock std |
| `replacement` | 0.68212 | CGM (2005), high-school group |
| `retirement_age` | 65 | CGM (2005) |
| `r` | 0.02 | CGM (2005) |
| `mu_S_level`, `sigma_S_level` | 0.04, 0.157 | CGM (2005) |
| `corr_SL` | 0 | CGM (2005) baseline |
| `corr_HL`, `corr_HL_rent`, `corr_SH`, `corr_SH_rent` | 0 | No housing correlations until step 8 |
| `h_mult`, `kappa_base` | 0 | No housing, no DC pillar |
| taxes | 0 | None |

Renters and owners share this income process until the income step (4), so
steps 1–3 have one no-housing arm. Deviations kept throughout the ladder:
entry at 25 rather than 20, a terminal age of 100, Dutch unisex mortality, and
no transitory income shock.

The rest of the ladder: 4 income (the DHS values above), 5 market (`r`,
`mu_S_level`, `sigma_S_level` above), 6 `corr_SL` = 0.04. From step 6 it
branches. Housing: 7 housing (`h_mult` 4 and the housing dynamics above, no
housing correlations), 8 the housing correlations above. DC pension, without
housing: 9 `kappa_base` 0.186 with an all-bond fund (`glide_cap` 0), 10 an
all-stock fund (`glide_cap` 1, `glide_span` 1, `tau_decum` 1), 11 the
production glide above, 12 `replacement` 0.307. Retirement income stays at
CGM's 68.2% of final income through step 11. Step 13 puts housing (step 8)
together with the AOW and the DC pension; 14 and 15 add the taxes.

Around step 12, `ladder.sensitivity` moves `replacement` to 0.20 and 0.40 and
`kappa_base` to 0.10 and 0.30, one at a time. These are illustrative values for
a sensitivity, not calibration.

## Numerics

Not calibration targets; accuracy choices, justified by convergence checks.

| Parameter | Value | Note |
|---|---|---|
| `grid_dims` | [20 20 12] | Base nodes on (u1, u2, u3); the entry anchors add up to two on u1 and u2 |
| `gh_n` | 5 | Gauss-Hermite nodes per shock; 3 and 5 gave the same policies wherever compared |
| `use_refine` | true | Global (c, pi) sweep before fmincon at every node. Without it the local solve lands on the wrong peak: at step 2 the equity share at 93-99 was up to 0.09 too low, and at the production calibration (quick numerics) the mean liquid equity share was off by up to 0.24 |
| `fmincon_algorithm` | `'interior-point'` | Local solve after the sweep (Quinn's choice). With the sweep, interior-point and active-set agree to 0.001 in the mean equity share at steps 1-2; at the production calibration they differed by up to 0.10 with neither reaching the higher value everywhere. `'active-set'` and `'sqp'` are robustness checks (`ladder.robustness`). Active-set and interior-point give the same answer on a thread pool and a process pool; sqp did not at step 1 |
| `N_c`, `N_pi` | 41 | Set the step sizes of the sweep's shrinking rounds |
| `interp_method` | `'linear'` | Linear in z. `'makima'` serves as a structural error check |
| `lambda_lo` | `[]` | 0.0008, or 0.0002 with housing. With house prices at 3.73% real and 8.35% vol, owners reach u1 = 0.0005 at 85+; 0.0008 clipped 0.02% of their household-years |
| `lambda_hi` | `[]` | `min(0.9, 3/(1 + h_mult))`, or 1 without housing |
| `grid_pow`, `grid_pow_u2`, `u2_lo`, `u3_lo`, `u3_hi`, `grid_nodes` | uniform, full axes | Placement; see GRIDS.md |

At the default grid, behaviour from 40 on is stable to a few percent. Early
life at the production calibration is not converged at any grid tried (README).
