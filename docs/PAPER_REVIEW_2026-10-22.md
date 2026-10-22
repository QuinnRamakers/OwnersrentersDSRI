# Paper version 15 against the code, 22 October 2026

This document compares the draft "Collective portfolio choice for homeowners and
renters" (`Owners_vs_renters_15.pdf`, dated 22 October 2026, 34 pages) with the
code and the production calibration on `main` at 7b5143d (20 October 2026). It
is meant as the input for a new draft.

Sources used:

1. The code: `+config`, `+solver`, `+simulate`, `+pension`, `+grids`, `+model`,
   `+ladder`. Production is `config.params()`, which equals ladder step 16
   (`nibud`).
2. CALIBRATION.md (every value and its source), TODO.md (open questions),
   README.md, GRIDS.md, `docs/SOLVER_BOUNDS.md`.
3. The HANDOFF.md log, 7 to 20 October, and its two summaries,
   `docs/HANDOFF_2026-10-15.md` and `docs/HANDOFF_2026-10-17.md`.
4. For the planner section only: the research branch `solver-active-set` (tag
   `research-2026-09`).

Status words used below: same (paper and code agree), changed (the code moved
on since the paper), new (in the code, missing from the paper), not in code (in
the paper, not implemented), wrong (the paper does not match its own model or
the code).

The draft's figures and result files are gitignored. They exist only on
Quinn's PC, under `ladder/standard_16x16x10x8_gh5/` and older
`ladder/standard_16x16x10_gh5/` folders. Every number quoted here comes from a
HANDOFF.md entry, which is named by its date.

---

## 1. Summary

### 1.1 What the paper describes, and what the code is now

The paper describes the model as it stood in September 2026. Since then the
calibration has been rebuilt one step at a time on a 16-step ladder, and the
model has changed in four places that the paper's results depend on.

| Block | Paper (version 15) | Production now (step 16) |
|---|---|---|
| Income profile | Been, Knoef and Vethaak (2026), men, 2001-2014, CPI to 2026 | DHS cubic, gross household-head income, 1993-2024, separate for owners and renters, 2025 euros |
| Income shock | Permanent, sd 0.1032 (CGM) | Permanent, sd 0.0816 owners, 0.0843 renters (DHS) |
| Market | r 1.1%, premium 4%, vol 16% (Hambel et al.; Yao and Zhang) | r 1.15% (NL interbank, 1982-2024), premium 4.56%, vol 21.61% (2000-2024), all real |
| Correlations | All zero | income-stock 0.04; H shock with income 0.09 (owners) / 0.06 (renters); with stocks 0.24 / 0.43 |
| House prices | BIS index, 2.77%, sd 3.64% | NVM repeat sales of individual houses, 3.73%, sd 8.35% |
| Rent | 0.97%, sd 1.8% (CBS) | 0.99%, sd 1.79% (CBS regulated rents, 1983-2025) |
| House at entry | 4 times income | Nibud 2026 maximum mortgage at entry income: 4.446 (owners), 4.155 (renters) |
| Rent share | 6% | 5.6% |
| Mortgage | Rate times the current house value (section 5.4) | Real 30-year annuity on the purchase price, with q = H0/H as a fourth state |
| Mortgage rate | 1.36% real (ECB MIR, May 2026) | 3.48% real (r plus the mean MIR-interbank spread, 2000-2024) |
| Consumption floor | Not mentioned | 1e-6 times gross income; the shortfall is written off |
| Solution method | Interior-point, then a local refinement | Global (c, pi) sweep, then interior-point in certainty-equivalent units |

Unchanged since the paper: ages 25, 67 and 100; CBS unisex mortality 2021-2026;
gamma 5; beta 0.96; chi 0; AOW replacement 30.7%; contributions of 18.6% above
the franchise; income tax 38.2%; box 3 at 36%; maintenance 1.5%; LTV 100%;
mortgage term 30 years; sale cost 2.5%; REIT off.

### 1.2 What the new draft can and cannot claim

CLAUDE.md lists the known limits. In short:

1. Steps 1-6 (no housing, no pension, no taxes) are converged. Their shapes and
   levels can be quoted.
2. Steps 9-12 (DC pension, no housing): the direction of every change holds on
   every grid. Sizes around retirement need the bunched 48x48 grid (HANDOFF, 16
   October). The ladder's standard grid overstates liquid saving at 60 by
   16-37%.
3. Housing with maintenance on the purchase price: converged for owners at step
   7b (bunched 16x16) and step 13 (bunched 24x24). Both were measured at the old
   mortgage rate of 1.36%; convergence at 3.48% is not checked (HANDOFF, 17
   October, "Parameters").
4. Production (step 16, maintenance on the current house value): owners are not
   converged at any age on any grid tried. Renters are converged only from about
   50, on the bunched 16x16 grid with 20 points on u3 (HANDOFF, 18 October,
   "Smallest accurate grid at step 16").
5. No welfare levels. At a floor of 1e-6 the value at entry is dominated by
   floor states. So the planner's certainty-equivalent ratios cannot be
   computed yet.
6. The REIT is off and its parameters are placeholders.

### 1.3 Decisions that block results

These are open in TODO.md. The draft cannot report production results until the
first is settled.

1. TODO item 1, the housing outflow. Owners face maintenance on a house that
   grows 3.73% a year in real terms, cannot sell or borrow against it, and are
   protected only by a floor of 1e-6 times income. That is a ruin cliff, and it
   is why owners do not converge. Charging maintenance on the purchase price
   removes it (HANDOFF, 15-16 October). Other options: equity release, housing
   benefit or downsizing for renters.
2. TODO item 4, the bequest. With chi = 0 the house has no use beyond saving
   rent, which contradicts the paper's stated reason for the bequest form.
3. TODO item 6 and `docs/HANDOFF_2026-10-17.md` section 3, the ladder's grid. The
   ladder's evenly spaced 16x16 grid is not converged for any step with housing
   or the pension.

---

## 2. Section by section

Each subsection gives what the paper says, what the code does now, and what the
draft should say. Coauthor comments (the XYZ and bracketed notes) that the code
now answers are listed under each section.

### 2.0 Front matter and the to-do list (PDF pages 1-2)

1. Abstract, key words and JEL codes are placeholders.
2. To-do "an optimal collective strategy that depends only on age". This is the
   design of section 4 and of the research branch (`strategy.menu`). Same.
3. To-do "rework the notation of income". The code keeps the two apart: Y is
   gross labour income, or the AOW in retirement; the annuity payout A/a_t is
   a separate term (`+solver/bellman_step_lna.m:287`). Suggest Y_t for gross
   income and P_t = A_t/a_t for the payout.
4. To-do "LW instead of X". The code uses both: X is liquid wealth at the start
   of the period, after returns; LW is cash on hand after take-home income and
   the housing cost (`bellman_step_lna.m:287-291`). Keep both symbols.
5. To-do "not a single male; borrowing capacity of about EUR 143k". Changed:
   income is now DHS gross household-head income, by tenure. The Nibud rule
   gives owners a house of EUR 176,786 (4.446 x 39,763) and renters a rent index
   of EUR 125,057 (4.155 x 30,098). The Nibud rule is applied as for a single
   earner (CALIBRATION.md, "House at entry"). Whether household-head income and
   a single-earner norm belong together is open.

### 2.1 Introduction and literature

Paper: preliminary results say renters hold substantially less equity than
owners of the same age and income, and that both groups adjust their private
equity when the collective allocation changes.

Code now: those results come from the August-September research (branches
`freetau-dc-choice` and `solver-active-set`), on the old calibration. On the
current calibration:

1. At step 6 (no housing) owners and renters hold the same equity share, within
   0.03 (HANDOFF, 12 October, steps 5-6).
2. At step 7 (housing, standard grid, not converged) renters held less: mean
   equity share 0.56 against 0.88 at 55 (HANDOFF, 12 October, step 7). Not
   quotable.
3. At step 16 owners are not converged at any age. No owner-renter comparison
   at production can be quoted.
4. The offset is shown cleanly on the pension branch without housing, steps
   9-12 (HANDOFF, 13 October). With an all-bond fund the liquid equity share
   rises to 1.00 from 66 (step 9). With an all-stock fund it falls to about 0.01
   at 66 (step 10, with `pi_nothing_saved = 'limit'`). The glide sits in
   between (step 11). The direction holds on every grid.

For the draft: rewrite the results paragraph around point 4 and the ladder.
Drop the owner-renter equity claim until TODO item 1 is settled. The max-min
motivation can stay.

Coauthor comments answered: none directly. "Absence of the collective or of the
other members" (the benchmark) is still open; see 2.10.

### 2.2 Section 1, model: timing, preferences, bequest

| Item | Paper | Code | Status |
|---|---|---|---|
| Ages | t = 0 at entry, T_R, T_D | t = 1..76, ages 25-100, `p.T = 76` | same |
| Survival | p_t, p_{T_D} = 0 | `config.survival`, CBS 37360ned, p_T = 0 | same |
| Utility | CRRA in C | CRRA in C; housing gives no utility | same |
| Bequest, eq (2) | chi (X + 1_owner H)^(1-gamma)/(1-gamma) | chi (X' + 1_owner (1 - 0.025) H')^(1-gamma)/(1-gamma), at next period's wealth after returns (`bellman_step_lna.m:479`) | changed in detail |
| chi | 0 | 0 (placeholder) | same |
| DC pot at death | not stated in section 1 | forfeited, funds the survival credit | new in section 1 |

For the draft:

1. Write the sale cost into eq (2) as (1 - c_sell) H, as the code does. The
   paper's section 5.5 writes rho_trans H, which reads as the share lost.
2. State that the bequest uses next period's wealth: death happens between t
   and t+1, after returns.
3. State that the bequest is not netted for an outstanding mortgage. The
   paper's insurance reading (section 5.5) fits the code.
4. "This form serves for there to be a use of housing wealth" does not hold at
   chi = 0 (TODO item 4). Either give chi a value or change the rationale.

### 2.3 Section 1.1, income

Paper: ln Y = f(t, Z) + u, u = eta + omega, eta an AR(1) aggregate shock,
omega idiosyncratic. Retirement income y_R + h_A(A).

Code (`+config/income_profile.m`):

1. Working years: ln Y_{t+1} = ln Y_t + Delta f_t + sigma_l eps_{t+1}. A random
   walk around the profile, one permanent shock, no transitory shock, no
   aggregate-idiosyncratic split, no AR(1) (`income_profile.m:54`,
   `bellman_step_lna.m:156`).
2. f is the DHS cubic log y = a0 + a1 age + a2 age^2/10 + a3 age^3/100,
   separately for owners and renters (`config.income_process`).
3. Retirement: Y_t = 0.307 Y_66 from 67, constant after. The step from 66 to 67
   has no shock (`income_profile.m:128, 138`).
4. Retirement income is Y_t (AOW) plus the annuity A_t/a_t, both taxed.

Status: section 1.1 is not in code. Section 5.2 is what the code does.

For the draft: describe the permanent-shock random walk as the model. Put the
AR(1) and the transitory shock under extensions (TODO item 5: partial
persistence needs a fourth state; a transitory shock needs retirement income
keyed to the permanent component). Say that the first pillar is a share of
final income, not a flat AOW. That keeps the model homothetic and removes the
floor a flat AOW would give households with bad permanent shocks
(CALIBRATION.md), which makes planner results somewhat pessimistic (TODO item
7).

Coauthor comments answered: "unclear why we do not need to keep track of the
first pillar": it is not an account; after 67 it is Y, which stays in the state
through u1 = Y/W.

### 2.4 Section 1.2, portfolio

| Item | Paper | Code | Status |
|---|---|---|---|
| Private account | bank, stock, REIT | bond and stock only, equity share pi in [0, 1] | REIT not in code |
| DC fund | bank, stock, REIT | bond and stock, plus a REIT leg that is off (`tau_REIT = 0`) | REIT off |
| Stock return, eq (7) | ln R^S = ln R_f + mu_S + eps, mean of eps +sigma^2/2 (eq 27) | ln R^S = ln(1 + r + mu) - sigma^2/2 + sigma z, so E[R^S] - R_f = mu (`+config/derive.m:20-21`) | wrong sign in the paper |
| DC return, eq (10) | ((1 - tau) R_f + tau R^S)/p_t | the same, from age 25 (`bellman_step_lna.m:159`) | same |
| Taxes on returns | only in section 3.4 | box 3 on the liquid account each year: 36% of the bond return and 36% of positive stock gains, no loss offset (`+config/after_tax_stock.m:37-40`, `bellman_step_lna.m:162`). The DC fund is untaxed | new in section 1 |

For the draft:

1. Define mu_S as the arithmetic equity premium, E[R^S] - R_f = mu_S, and write
   ln R^S = ln(R_f + mu_S) - sigma^2/2 + sigma eps, with
   sigma^2 = ln(1 + (sd/(R_f + mu_S))^2). The same mapping holds for the house
   and the rent index (`derive.m:22-26`).
2. Put the after-tax liquid returns into the model section. The missing loss
   offset cuts the after-tax premium on the liquid account from 4.56% to about
   1.0%, and the Merton share at gamma 5 from 0.195 to 0.077 (CALIBRATION.md,
   Taxes; HANDOFF, 12 October, code work).
3. Use a symbol other than tau for the fund's equity share (coauthor). The code
   calls it `tau_S`, but the paper uses tau for taxes too.
4. The REIT: decide whether it stays in the paper. If it stays, it is a DC-fund
   asset only in the code, with placeholder moments.

### 2.5 Section 1.3, housing

The paper's section 1.3 describes the mortgage the code now has. Section 5.4
describes the one it had.

| Item | Paper 1.3 | Paper 5.4 | Code now | Status |
|---|---|---|---|---|
| Tenure | fixed | fixed | fixed (`p.is_owner`) | same |
| House at entry | from the mortgage constraint at entry income | b_H = 4 times income | Nibud 2026 maximum mortgage at the tenure's income at 25 and r_m (`derive.m:77`, `+config/nibud_lti.m`) | changed (now as in 1.3) |
| Mortgage | fixed payment m(r_m, H_0, N) on H_0 | rate times the current value | real annuity on H_0: payment m H_0 = m q H_t, q = H_0/H_t a state (`derive.m:88`, `bellman_step_lna.m:86`) | changed (now as in 1.3) |
| Payment periods | 0 <= t <= N (N + 1 payments) | | ages 25-54, N = 30 payments | off by one in eq (13) |
| Maintenance | theta H_t | theta H_t | theta H_t; option theta H_0 (`maint_on_purchase`, off) | same, but see TODO item 1 |
| Rent | alpha H_t on the house price | alpha H_t on a rent process | alpha H_t on a rent index with its own process | changed |
| House-price shock, eq (12) | upsilon_t + zeta_{i,t} | one shock | one shock per household, correlated with income and stocks | not in code |
| Default, refinance, prepay, sale, equity release | none | none | none | same |

Numbers at entry (owners at EUR 39,763, renters at EUR 30,098):

1. Owner: house EUR 176,786; payment 5.42% of the purchase price, EUR 9,588 a
   year for 30 years; maintenance EUR 2,652. Together 30.8% of gross income, 55%
   of income after contributions and tax.
2. Renter: rent index EUR 125,057, rent EUR 7,003 (5.6%), 23.3% of gross
   income, 41% after contributions and tax.

For the draft:

1. Section 1.3's mortgage is now the model. State that it is a real annuity (a
   constant real payment). A Dutch annuity mortgage fixes the nominal payment
   instead (CALIBRATION.md; chosen 15 October 2026).
2. Explain q = H_0/H_t: the payment is fixed while the house value moves, so the
   owner carries the ratio. q = 1 at entry and q_{t+1} = q_t / R^H_{t+1}. It is
   a state only while it enters the budget (ages 25-54).
3. The renter's H is a rent index, not a house. It starts at the house the
   renter could have bought under the same Nibud rule and grows at the rent
   process. It has no resale or bequest value. Use its own symbol.
4. The old contract (section 5.4) survives only as ladder step 7. In present
   value it cost 1.71 times the loan (median 1.64) against 1.00 for the annuity
   (HANDOFF, 12 October, "The model's mortgage against a real annuity
   mortgage").
5. Fix eq (13) to 1 <= t <= N (or 0 <= t <= N - 1).
6. State that housing returns keep the trend (3.73% real drift). The paper's
   "Cocco de-trends; we keep the trend" holds.

Coauthor comments answered:

1. "Explain the mortgage constraint; what age at the start": the Nibud norm caps
   the monthly payment of a 30-year annuity at a share of gross income, read
   from a table by income and test rate (21.6% for owners, 19.3% for renters at
   their entry incomes), plus the EUR 17,000 increase for a single earner. Age
   25 at entry.
2. "What about the mortgage constraint, what determines what one can afford?":
   the same Nibud rule.
3. Section 5.4, "I don't understand this. Mortgage payments increase ...": the
   proportional contract is gone from production; the question no longer
   arises.

### 2.6 Section 1.4, DC account dynamics

| Item | Paper | Code | Status |
|---|---|---|---|
| Accumulation, eq (15) | A' = R^A (A + kappa y) | A' = R^A (A + kappa_t Y), kappa_t an age profile (`bellman_step_lna.m:292, 297`) | same, kappa_t new |
| Decumulation, eq (16) | A' = R^A (A - h_A(A)) | the same, h = A/a_t (`bellman_step_lna.m:289`) | same |
| Annuity price, eq (17) | a_t = E[sum_s s_p_t prod 1/R^A] | a_t = 1 + p_t a_{t+1} / E[(1 - tau) R_f + tau R^S] (`+pension/annuity_price.m:45-47`) | changed (eq 38 is right) |
| Payout, eq (18) | h = A/a_t | the same | same |

What the recursion does: with a_t - 1 = a_{t+1}/E[R^A] (R^A with the survival
credit), A_{t+1} = (R^A/E[R^A]) A_t a_{t+1}/a_t, so h_{t+1} = (R^A/E[R^A]) h_t
and E[h_{t+1}] = h_t. Expected payouts are level. Eq (17) with E[prod 1/R]
would make them drift upward, by Jensen's inequality. That is the "Jensen"
remark in section 5.3.

For the draft:

1. Replace eq (17) by the recursion (eq 38). Frame it as a variable annuity
   whose assumed interest rate is the fund's expected return (TODO item 7).
2. In production the fund holds no equity from 67 (`tau_decum = []`), so the
   annuity is a fixed real life annuity at r = 1.15%. The annuity factor at 67
   is 16.95 (HANDOFF, 12 October, steps 9-12).
3. State that the survival credit 1/p_t applies from age 25, not only in
   retirement, and that the pot is forfeited at death.
4. The contribution rate: kappa_t = kappa_base max(Y_t^det - F, 0)/Y_t^det,
   evaluated on the deterministic profile, not the household's own income
   (`derive.m:58`). Table 2 writes kappa_base E[max(Y_t - F, 0)/Y_t], which is
   not what the code does. A rate on realised income would break the normalised
   state (CALIBRATION.md, Pension).

Coauthor comment answered: "What type of annuity? variable or fixed?": a
variable annuity priced off the fund's expected return; at the production fund
it is a fixed real annuity.

### 2.7 Section 1.5, the household problem

| Item | Paper | Code | Status |
|---|---|---|---|
| Renter budget, eq (19) | X' = ((1 - delta)(1 - 1_{t<=T_R} kappa) y - alpha H + X - C) R^X | the same, with y including the annuity in retirement (`bellman_step_lna.m:287-291`) | same |
| Contribution indicator | t <= T_R | t < T_R: the last contribution is at 66 | off by one |
| Owner budget, eq (24) | ... - theta H - m_{i,t} ... | ... - theta H - m q H ... | same in substance |
| Bellman, eq (20) | V(X, H, A, eta) | V(W, u1, u2, u3, q) = W^(1-gamma) V~(u, q) | changed (state) |
| C >= 0, eq (21) | yes | C >= phi Y, phi = 1e-6 | changed |
| Borrowing, eq (22) | cash on hand >= C | the same, except below the floor | changed |
| Portfolio, eq (23) | two shares, sum <= 1 | one share pi in [0, 1] | changed (no REIT) |

The consumption floor is the largest omission in the paper. In the code
(`bellman_step_lna.m:298-317`, `+simulate/paths_lna.m:200-206`):

1. If cash on hand falls below phi Y, with phi = 1e-6 and Y gross income (the
   AOW in retirement), the household consumes phi Y, saves nothing, and the
   shortfall is written off. This is the model's bankruptcy event.
2. The floor is also the lower bound of the consumption search, C >= phi Y
   (since 15 October; before, 1% of total wealth).
3. It is a numerical bound, not a calibration target (Quinn, 17 October). At
   gamma 5 one floored year at 1e-6 weighs as much as 1e24 ordinary years.
4. How often it binds at production, step 16 (HANDOFF, 20 October, floored by
   age), % of household-years, all years / 67-79 / 80-89 / 90-100: owners with
   maintenance on the current value 3.10 / 0.38 / 2.69 / 18.46; with
   maintenance on the purchase price 0.02 / 0 / 0 / 0; renters 0.64 / 0.10 /
   0.71 / 3.67. These rates fall with every grid refinement and have not
   settled.

For the draft: write the floor into the budget constraint, with its
interpretation. Say that results are reported as behaviour, not welfare, while
phi = 1e-6.

### 2.8 Section 2, dependence structures

Paper: four systematic innovations (income, stock, REIT, housing), two
idiosyncratic ones (income, own house), an AR(1) aggregate income shock, a mean
vector Xi (eq 27) and the stacked system (eq 28).

Code (`+grids/shock_grid.m:102`, `+simulate/paths_lna.m`):

1. Three standard normals per year: income, stock, and the H shock (house price
   for owners, rent for renters), correlated through one Cholesky factor. A
   fourth, the REIT, only when its leg is on.
2. Correlations: income-stock 0.04 (both tenures); H with income 0.09 owners,
   0.06 renters; H with stocks 0.24 owners, 0.43 renters. Each is the
   correlation with one composite income shock; there is no aggregate and
   idiosyncratic split (CALIBRATION.md, Financial markets).
3. The solver uses Gauss-Hermite quadrature, 5 nodes per shock, 125 joint
   nodes. The simulation draws continuous shocks.
4. In the simulation every household draws its own stock return. The panel is a
   set of independent life histories, not a cohort facing one market path.
5. `model.checks` reports each correlation on the nodes and in the panel; both
   are within 0.01 of the inputs.

Status: eq (25)-(28) are not in code. Eq (27) has the wrong sign for the code's
convention (2.4).

For the draft: replace section 2 by a 3x3 correlation matrix of (income shock,
stock return, H shock), with the H shock's meaning by tenure. Move the
aggregate-idiosyncratic structure to extensions. State point 4.

Coauthor comment answered: "What I am totally missing is any form of dependence
structure": estimated and on in production. Sources: calibration notes Table 4
(income-stock: gross income, pooled over all DHS households, 2002-2023, T = 22)
and calibration tables Table 3 (housing correlations, same window). Note:
step 8 (the housing correlations on their own) is coded but has never been run,
so their effect on housing households has not been isolated.

### 2.9 Section 3, calibration

Section 3 of this review has the full parameter table. Per subsection:

3.1 Timing, mortality, preferences.

1. Entry at 25: now justified as the first age of the DHS sample, so the
   profile needs no extrapolation below it. Answers the coauthor's "why 25?".
2. Mortality: same (CBS 2021-2026, unisex). With household-head income instead
   of men's wages, unisex mortality is less at odds with the income source.
   The coauthor's "why not the AG table" is still open.
3. gamma 5: the text cites Cocco, Gomes and Maenhout (2005), whose baseline is
   10; Table 2 cites Cocco (2005). CALIBRATION.md calls 5 a production choice.
   Fix the citation.
4. beta 0.96: a placeholder. Larsen and Munk (2023) is a candidate source, not
   checked (CALIBRATION.md).
5. Drop the sentence on moment matching (coauthor).

3.2 Labour income. Replace entirely: DHS 1993-2024, gross household-head
income, heads 25-65, cubic by tenure in 2025 euros (owners EUR 39,763 at 25,
peak 74,656 at 50; renters 30,098 at 25, peak 52,013 at 49). Permanent sd
0.0816 / 0.0843 from the same data. The cubic is extrapolated one year to 66,
the last working year. Answers the coauthor's three comments (old data, US
volatility on a Dutch profile, broad CGM income). Still to say: whether the
DHS gross income includes benefits, and that the transitory component (DHS sd
0.119 owners, 0.138 renters) is left out.

3.3 Pension system. Give the numbers the coauthors asked for:

1. AOW: 30.7% of final gross income (DNB, Toereikendheid van pensioenen, Table
   3, median first-pillar replacement rate).
2. Contributions: 18.6% of income above the franchise of EUR 18,475 (1-1-2025,
   art. 18a lid 3 Wet LB). On the deterministic profile this is 10.0% of gross
   income at 25 rising to 14.0% at 50 for owners, 7.2% to 12.0% at 49 for
   renters. kappa_base is a placeholder (OECD); a participant-weighted Dutch
   rate is wanted (TODO item 2).
3. The fund: 80% equity until 39, linear to 0 at 67, all bonds in retirement
   (`glide_cap` 0.8, `glide_span` 35). A stylised lifecycle fund.
4. Implied retirement income, deterministic path, gross: AOW 0.307 plus an
   expected annuity of 0.55 (renters) or 0.69 (owners) of final income, so 0.86
   and 0.99 of final income (HANDOFF, 12 October, steps 9-12).

3.4 Taxes. The text holds, with three additions. The bond return on the liquid
account is taxed as well as stock gains. Losses are not offset, which is the
largest effect (2.4). The deemed-return wealth tax (1.97%, Hambel et al. 2026)
is coded and off. The coauthor's concern about mixed years (tax 2019,
contributions 2025) is still open; DHS net over gross income at 25 implies an
average tax of about 23% (owners) and 25% (renters) against 38.2% (TODO item
2).

3.5 Financial markets and housing. Replace: r 1.15% (FRED IR3TIB01NLM156N
deflated by the CBS CPI, 1982-2024); premium 4.56% and vol 21.61% (real,
2000-2024); house prices 3.73%, sd 8.35% (NVM repeat sales, 1996-2024); rents
0.99%, sd 1.79% (CBS regulated rent increases, 1983-2025); r_m 3.48%; alpha
5.6% (government report, reference still to add); house at entry by the Nibud
rule. Answers the coauthor's comments on which source (one pipeline now), on
real versus nominal (everything is real), and on the May 2026 rate (r_m is now r
plus a 2000-2024 mean spread).

Still open from the coauthors:

1. "Housing has a higher Sharpe ratio than equity": still true gross,
   (3.73 - 1.15)/8.35 = 0.31 against 4.56/21.61 = 0.21. Net of 1.5% maintenance
   it is 0.13. The house cannot be traded, so there is no arbitrage; say so.
2. "Initial wealth of owners against renters": both enter with b0 = 0.079 years
   of income in liquid wealth (EUR 3,145 owners, 2,381 renters), no DC pot, and
   the house or rent index. No down payment, no purchase costs. b0 is a
   placeholder whose denominator is still the BKV men's wage (TODO item 2).
3. "Rules and caps on rent increases": the rent process is estimated on
   regulated increases, so the cap is in the data; there is no housing benefit.
4. "Is there a European source for the rent share?": alpha 5.6% now comes from a
   Dutch government report; the reference is missing.

### 2.10 Section 4, the social planner

Paper: tau* = argmax min_i phi_i(tau, kappa), phi a CE ratio against a
benchmark, tau an age-only path set by four PCHIP knots at 25, 46, 67, 100;
Omega a reference owner and a reference renter.

Code: none of this is on `main`. It is on `solver-active-set`:

1. `+strategy/spline_tau.m`: PCHIP (Fritsch-Carlson) through the knots, flat
   outside them, clipped to [0, 1].
2. `+strategy/menu.m`: knots at 25, 46, 67 and 99 (the last transition age,
   not 100), fractions on 0:0.125:1, non-increasing paths only: 495
   strategies.
3. `+utility/welfare_summary.m`: V~ at the entry state for b0 and b_alt, and a
   buffer curve.

On `main` the glide is built from `glide_cap` and `glide_span` (`derive.m:32`)
and `tau_S` is a derived field. A PCHIP path needs its knots as primitives in
`config.params` (CLAUDE.md, calibration rules).

Before the planner can produce numbers:

1. Welfare levels must converge (TODO items 1 and 3). At step 16 the value at
   entry, as a constant consumption stream, is 0.000-0.012 times entry income
   for owners on the bunched grids and moves by orders of magnitude with the
   grid for renters (HANDOFF, 18 October).
2. Fund comparisons with stock-heavy funds need `pi_nothing_saved = 'limit'`.
   With the default `'one'`, the step-10 liquid equity share at 66 came out at
   0.37/0.45 instead of 0.01 (HANDOFF, 16 October).
3. The welfare anchor: V~ is read at one entry state; earlier work found the
   sign of the DC verdict changing with the entry buffer (TODO item 3).

For the draft: keep section 4 as method. Define tau_bench (coauthors). Write
phi_i(tau, kappa) throughout (not phi_{i,t}). Say the fund holds stocks and
bonds only, which is what makes a single PCHIP path enough. Use the knot ages
the code uses, or change the code. State the entry state at which V_0 is read:
u1 = 1/(1 + h + b0), u2 = h/(h + b0), u3 = 0, q = 1
(`+utility/welfare_anchor.m`). Report no planner results yet.

### 2.11 Section 5, the implemented model

5.1 Assets and shocks. Eq (32)-(33) hold with the mapping in 2.4. The renter's
process now has its own parameters (mu_R, sigma_R); give it its own symbol, as
the coauthor suggests. "The dependence structure is largely switched off" is
out of date (2.8). "Expectations on a Gauss-Hermite grid" holds (5 nodes per
shock).

5.2 Income, retirement income, taxes. Eq (34)-(35) hold, with sigma_l by
tenure and the DHS profile. Net income Y* = (1 - delta)(1 - kappa_t) Y in
working years and (1 - delta)(Y + A/a_t) in retirement.

5.3 DC account. Eq (36): production is min(0.8, (67 - age)/35) before 67 and 0
after, not the PCHIP family; that family is the planner's (2.10). Eq (37) and
(38) match the code. "Survival-credit return" is fine as a term if defined once.

5.4 Housing. Replace with 2.5: Nibud house, annuity mortgage with q,
maintenance on the current value (production) with the purchase-price
alternative, rent index.

5.5 Bequest and terminal condition. chi = 0; the sale cost as (1 - 0.025) H;
the mortgage is not netted. At age 100 the household consumes all cash on
hand. With chi > 0 the terminal-period bequest is inconsistent with the
recursion's (no discounting, no returns) (TODO item 4); dormant at chi = 0.

5.6 Normalisation and state space. Changed, and eq (46) is wrong. See 4.3.

5.7 Bellman problem and numerical method. Changed. See 4.4 and section 6.

5.8 Summary of deviations. Update to:

1. No REIT in the private account; the DC REIT leg is off.
2. One permanent income shock; no AR(1) aggregate component, no transitory
   shock.
3. One housing shock per household, no aggregate component.
4. The first pillar is a share of final income.
5. A real, not nominal, annuity mortgage.
6. No equity release, sale, default or tenure change.
7. A consumption floor of 1e-6 times income with the shortfall written off.

Coauthor comment: "two model sections". The gap has narrowed: the mortgage of
section 1.3 is now implemented and correlations are on. One model section is
now possible; see section 8.

### 2.12 Section 6, notation and Tables 1-2

Table 1, to add: q (purchase price over current house value), phi (floor), b0
(entry buffer), F (franchise), kappa_t, the fund equity share (a new symbol),
h (house at entry over income), the rent index and its process, c_sell,
separate tax symbols (income, box 3), LW (cash on hand), and the cube
coordinates in the appendix.

Table 1, to drop unless the extensions return: A^N, B, S, Q, eta, the AR
coefficient, iota, upsilon, zeta, Xi, Sigma^idiosyncratic.

Table 2: see section 3. It lists alpha twice and gives the rent drift the
symbol mu_H.

---

## 3. Calibration: paper Table 2 against production

| Parameter | Paper | Production | Source now | Status |
|---|---|---|---|---|
| Entry age | 25 | 25 | First age of the DHS sample | same, new reason |
| Retirement age | 67 | 67 | Statutory AOW age, 2026 | same |
| Terminal age | 100 | 100 | Convention | same |
| Survival | CBS 2021-2026, unisex | same | CBS 37360ned | same |
| gamma | 5 | 5 | Production choice (CGM use 10) | same, citation wrong |
| beta | 0.96 | 0.96 | Placeholder | same |
| chi | 0 | 0 | Placeholder | same |
| Income profile | Been et al., men | DHS cubic, owners [7.7979, 0.17253, -0.2784, 0.1405], renters [7.5302, 0.17828, -0.3126, 0.1784] in code form | Calibration notes, Table 3 | changed |
| Permanent shock sd | 0.1032 | 0.0816 owners, 0.0843 renters | Same | changed |
| AOW replacement | 0.307 | 0.307 | DNB, Table 3 | same |
| kappa_base | 0.186 | 0.186 | OECD (placeholder) | same |
| Franchise | "Euro" (no number) | EUR 18,475 | Art. 18a lid 3 Wet LB, 1-1-2025 | new number |
| kappa_t | kappa_base E[max(Y - F, 0)/Y] | kappa_base max(Y^det - F, 0)/Y^det | Derived | wrong in the paper |
| Fund glide | PCHIP, 4 knots (text) | 0.8 to 39, linear to 0 at 67, 0 after | Stylised | changed |
| Income tax delta | 0.382 | 0.382 | CBS 2019 | same |
| DC capital-gains tax | 0 | 0 | | same |
| Box 3 on the liquid account | 0.36 | 0.36 on the bond return and on positive stock gains, no loss offset | Box 3 rate 2025 | same rate, details new |
| Wealth tax | not listed | 0 (0.0197 coded, off) | Hambel et al. (2026) | new |
| r | 0.011 | 0.0115 | NL 3-month interbank, CPI-deflated, 1982-2024 | changed |
| Equity premium | 0.04 | 0.0456 | Real, 2000-2024 | changed |
| Equity vol | 0.16 | 0.2161 | Real, 2000-2024 | changed |
| House-price drift | 0.0277 | 0.0373 | NVM repeat sales, 1996-2024 | changed |
| House-price vol | 0.0364 | 0.0835 | Same | changed |
| House at entry | 4.0 | 4.446 owners, 4.155 renters | Nibud 2026 norm, box 1, below AOW age, at r_m, with EUR 17,000 | changed |
| alpha | 0.06 | 0.056 | Government report (reference missing) | changed |
| theta | 0.015 | 0.015, on the current value | Placeholder | same |
| r_m | 0.0136 | 0.0348 | r plus the mean MIR-interbank spread, 2000-2024 | changed |
| Mortgage term | 30 | 30 | | same |
| Mortgage contract | rate on current value (5.4) | real annuity on the purchase price | Chosen 15 October | changed |
| LTV | 1.00 | 1.00 | Asserted; anything else fails | same |
| Sale cost at bequest | 2.5% | 2.5% | Hambel et al. (2026); inert at chi = 0 | same |
| Rent drift | 0.0097 | 0.0099 | CBS regulated rents, 1983-2025 | changed |
| Rent vol | 0.018 | 0.0179 | Same | changed |
| corr income-stock | 0 | 0.04 | DHS, 2002-2023 | changed |
| corr income-H | 0 | 0.09 owners, 0.06 renters | Calibration tables, Table 3 | changed |
| corr stock-H | 0 | 0.24 owners, 0.43 renters | Same | changed |
| Consumption floor | not listed | 1e-6 times gross income | Numerical bound | new |
| Entry buffer b0 | not listed | 0.0791 years of income | CBS deposits over the BKV wage (placeholder) | new |
| Price year | 2026 (CPI) | 2025 euros | Last complete CPI year | changed |
| REIT | in the model | DC leg only, off; 3% / 12% placeholders | | not in code |

CALIBRATION.md and `+config/params.m` agree on every value above.

---

## 4. Equations to correct or add

### 4.1 Returns, eq (7), (8), (27), (32)-(33)

The code: E[R^S] = R_f + mu_S, sd(R^S) = sigma_S^level, and

    ln R^S = ln(R_f + mu_S) - sigma^2/2 + sigma eps,   sigma^2 = ln(1 + (sigma_S^level / (R_f + mu_S))^2).

The house and the rent index use the same form with their own drift, which is
their own return, not an excess return. Eq (27)'s +sigma^2/2 should be
-sigma^2/2 under the paper's eq (7) (TODO item 7).

### 4.2 Mortgage and housing cost, eq (13)-(14), (40)-(41)

    m = r_m (1 + r_m)^N / ((1 + r_m)^N - 1) = 0.05424 at r_m = 3.48%, N = 30
    owner housing cost_t = theta H_t + 1{t <= N} m H_0 = (theta + 1{t <= N} m q_t) H_t,   t = 1..N
    q_1 = 1,   q_{t+1} = q_t / R^H_{t+1}
    renter housing cost_t = alpha R_t,   R_t the rent index, R_1 = h_renter Y_1

Eq (40) should read "per year, per euro borrowed", not "monthly, per dollar".

### 4.3 Normalisation, eq (42)-(46)

The code's total wealth includes this year's income and, for renters, the rent
index: W = X + A + H + Y (TODO item 7: never call W wealth for renters). The
coordinates (`bellman_step_lna.m` header):

    u1 = Y/W in [lambda_lo, lambda_hi]   (0.0002 to 3/(1 + h), capped at 0.9: 0.551 owners, 0.582 renters)
    u2 = (A + H)/(W - Y) in [0, 1]       (the paper's eq 43 divides by W)
    u3 = A/(A + H) in [0, 1]
    q  = H_0/H in [0, 2.5]               (owners, ages 25-54)

    s_X = (1 - u1)(1 - u2),   s_A = u2 (1 - u1) u3,   s_H = u2 (1 - u1)(1 - u3)

Every point of the cube is a feasible state. Eq (46) should be replaced by

    LW/W = s_X + (1 - delta)(1 - kappa_t) u1 - c_t s_H                     (working)
    LW/W = s_X + (1 - delta) u1 + (1 - delta) s_A / a_t - c_t s_H          (retired)

with c_t the housing cost rate: alpha for renters, theta + 1{t <= N} m q for
owners. The paper's eq (46) has no housing cost, applies the annuity in working
years, leaves it untaxed, and starts with (1 - A/(A + H)), which is not the
liquid share. The upper bound of u1 is no longer "1 as an educated guess".

### 4.4 Bellman equation, eq (47)

    V~_t(u, q) = max_{c, pi} (c LW/W)^(1-gamma)/(1-gamma)
                 + beta p_t E[ G^(1-gamma) V~_{t+1}(u', q') ]
                 + beta (1 - p_t) chi E[ (B'/W)^(1-gamma) ] / (1-gamma)

    G = (X' + A' + H' + Y')/W,   X' = R^X (1 - c) LW,   R^X = (1 - pi) R_f^at + pi R^S,at
    B' = X' + 1_owner (1 - c_sell) H'

The state is (u1, u2, u3, q), not (lambda, s^A, s^H). The continuation is
interpolated linearly in z = ((1 - gamma) V~)^(1/(1 - gamma)). c is the share of
cash on hand consumed, in [phi Y/LW, 1]; below the floor see 2.7.

### 4.5 Contribution rate (Table 2)

    kappa_t = kappa_base max(Y_t^det - F, 0) / Y_t^det,   t < T_R

with Y^det the deterministic profile (`derive.m:58`).

---

## 5. What the ladder found: results available for the draft

The ladder (`+ladder/steps.m`, README table) is a natural results structure: a
CGM core, then Dutch numbers one block at a time, then housing and the pension
on separate branches, then both, then taxes, then the Nibud house. Every step
was predicted in writing before it ran (HANDOFF.md).

### 5.1 Steps 1-6, no housing: converged

1. Step 1, CGM core (gamma 10): reproduces the shapes of CGM Figures 2, 3A and
   3C. Levels differ: median consumption is 64% of income at 25, and households
   leave the all-equity corner at 30 (CGM about 38), bottom out at 0.38 at 59
   (CGM 0.50 at 65), and rise to 0.54 at 95 (CGM 0.65). Grid gaps at most 0.03
   in the equity share (HANDOFF, 12 October, step 1).
2. Step 2, gamma 5: equity share at 1 until 43, about twice as high in
   retirement; the wealth peak 24% lower.
3. Step 3, retirement at 67: small.
4. Step 4, DHS income: less saving young; liquid wealth at 67 lower by 17%
   (renters) and 9% (owners) in multiples of entry income; the retirement
   equity share about 0.1 higher.
5. Step 5, Dutch market: Merton share 0.325 to 0.195; households leave the
   corner six years earlier; retirement equity share 0.72-0.77; liquid wealth
   at 67 9% lower.
6. Step 6, income-stock correlation 0.04: equity share down by up to 0.033 at
   50-66. Owners and renters within 0.03 in the equity share and 6% in
   consumption.

### 5.2 Steps 9-12, the DC pension without housing: directions robust

From HANDOFF, 13 October (standard grid) and 16 October (bunched grids):

1. Step 9 (all-bond fund, first pillar still 68.2%): liquid saving crowded out
   (liquid wealth at 66 2.1 renters / 1.8 owners times entry income, against
   11.9 / 13.1 at step 6); liquid equity share 1.00 from 66.
2. Step 10 (all-stock fund): DC pot at 66 2.8 times step 9's; the liquid
   equity share falls to about 0.01 at 66; retirement consumption much higher,
   with a wide band.
3. Step 11 (the glide): between the two.
4. Step 12 (AOW at 30.7%): liquid saving at 66 5.0 / 4.0 times entry income
   (1.3 / 1.2 at step 11); retirement equity share 0.89-0.99.
5. Sizes: on the standard grid liquid saving at 60 is 16-37% too high and
   consumption at 66 3-11% too high. Points bunched toward low u1 and u2 near 1
   (`grid_pow` 3, `grid_pow_u2` 3) with `pi_nothing_saved = 'limit'` converge:
   48x48 within the stop rule at every DC step. The bunched-grid solves are on
   Quinn's PC (`pension_grid/`).

This is the paper's offset mechanism: the liquid equity share moves against
the fund's equity share.

### 5.3 Housing: what drives the owner's problem

1. Step 7 (house at 4 times income, the old mortgage, maintenance on the current
   value): owners at the floor in 5.5% of household-years, 12.2% from 67. Not
   grid-converged for either tenure. With constant house prices the owner
   converges (HANDOFF, 12 October, diagnosis).
2. The mechanism: maintenance of 1.5% on a house that grows 3.73% a year, with
   a flat pension, no sale and no borrowing, and a floor of 1e-6. On a fine
   grid the answer is a corner: young owners consume almost nothing and hoard
   against old-age ruin (HANDOFF, 15 October, grid design).
3. Step 7b (the real annuity): raises early consumption and the equity share
   before 55, and leaves old age unchanged; the old-age floor states remain
   (HANDOFF, 15 October, run 2).
4. Maintenance on the purchase price removes every floor state and the hoarding
   corner; the owner then converges (bunched 16x16 at 7b, 24x24 at step 13).
   Measured at r_m 1.36% and alpha 6% (HANDOFF, 15-17 October).
5. Renters: from about 40-50 every grid agrees; before 40 no grid converges
   (rent of about 41% of net income at 25, a floor of 1e-6).

### 5.4 Steps 15-16 and production

1. The Nibud house against 4 times income (same solution, two starts,
   standard grid): owner consumption -9% at 30, -6% at 40, -4 to -5% from 50;
   renters about a third of that. Young households save more, not less, against
   the larger committed outflow (HANDOFF, 17 October, steps 15-16).
2. On the bunched grid, owners at step 16 do not converge at any age: each finer
   grid makes them hoard more, and 20 points on u3 make them hoard into
   retirement. Renters converge from about 50-55 on bunched 16x16 with 20 points
   on u3 (HANDOFF, 18 October).
3. The cause, measured directly: near the floor's edge the value function has a
   deep, narrow trough in z, and linear interpolation prices states near ruin as
   too mild, by tens of percent in working life and by factors up to 1e6 in old
   age. Refinement moves the trough rather than removing it (HANDOFF, 18
   October, interpolation).
4. Summary dashboards at step 16 (HANDOFF, 20 October; multiples of entry
   income, median consumption):
   - Owner, maintenance on the current value: 0.03 at 25, 0.25 at 35, 0.82 at
     66, 0.48 at 95; 15.8% floored at 95. The hoarding corner; not converged.
   - Owner, maintenance on the purchase price: 0.25 at 25, 0.45 at 35, 0.98 at
     66, 0.95 from 85; liquid equity share 0.28-0.40 at 35-55, about 1 from 75;
     no one floored after 75. Not checked for convergence at step 16.
   - Renter: 0.17 at 25, 0.73 at 66, 0.44 at 95; liquid saving 4.6 at 55; 3.2%
     floored at 95. Converged from about 50.

For the draft: the housing results that can be reported are the mechanism
(5.3) and, once TODO item 1 is decided, the owner with whichever outflow is
chosen. If maintenance on the purchase price becomes the model, the
convergence check at step 16 has to be run first.

---

## 6. In the code, missing from the paper

Each of these changes results and should be stated in the model, calibration
or appendix:

1. The consumption floor and the written-off shortfall (2.7).
2. The entry state: b0 = 0.079 years of income in liquid wealth, no pot, the
   house or rent index at h times income, q = 1.
3. The survival credit on the DC pot from age 25.
4. No income shock in the retirement transition; the first pillar 0.307 Y_66.
5. Box 3 without loss offset, and the tax on the bond return.
6. kappa_t on the deterministic profile.
7. The price year, 2025, for income and the franchise; the Nibud table is in
   2026 euros (CALIBRATION.md lists the effect: raising both entry incomes by 3%
   moves the multiples to 4.434 and 4.306).
8. The Nibud details: box 1 table (interest deductible, which the model does not
   model; box 3 would give 3.57 and 3.34), the test rate r_m is real while the
   norm's is nominal, the EUR 17,000 increase, renters on the same rule.
9. The q state and its grid (8 base nodes on [0, 2.5]; 4 are enough).
10. The simulated panel keeps every household alive to 100; statistics at an age
    are among those who reach it and are not survival-weighted.
11. Each simulated household draws its own market returns (2.8).
12. Numerics for the appendix: Gauss-Hermite 5 nodes per shock; the global
    (c, pi) sweep (21 x 21, then three shrinking rounds) before fmincon
    interior-point, on the objective in certainty-equivalent units, kept only if
    it beats the sweep; consumption searched on [phi Y/LW, 1]; at grid points
    where nothing is saved the stored equity share is 1 (`'one'`); linear
    interpolation in z with nearest-node extrapolation outside the grid (which
    snaps every coordinate, not only the one off the grid; HANDOFF, 18 October);
    the default grid [20 20 12 8], the ladder's [16 16 10 8], and the bunched
    grids the convergence evidence needs (GRIDS.md). The checks in
    `model.checks`: off-grid lookups, `c_bound_25_39`, `ce_entry`, the floored
    share, the correlations.
13. The section 5.7 text on the method is out of date: the code does not scale
    by the minimum value and has no post-optimiser refinement; the sweep comes
    first. Without it the local solve lands on the wrong peak at about 8% of
    retirement nodes (README); at the DC steps the equity share was 0.28-0.43
    off at 26-28 and up to 1.0 at 95 (HANDOFF, 13 October); at step 13 it
    barely matters (HANDOFF, 17 October).

---

## 7. Inconsistencies in the repo found during this review

Not changed here, except item 4.

1. README, "Reading the results": "From age 40 on, behaviour is reliable"
   contradicts CLAUDE.md's known limits (owners at step 16 not converged at any
   age; renters from about 50). The rent burden quoted there ("about 44% of net
   income at 25, owners about 41%") predates 17 October: now 41% for renters and
   55% for owners.
2. CALIBRATION.md, numerics, last line: "At the default grid, behaviour from 40
   on is stable to a few percent", the same contradiction.
3. TODO.md item 1, first paragraph: "The calibration ladder stopped here, at
   step 7" and "owners: maintenance and mortgage of a similar order" are out of
   date (steps 7b, 13, 15 and 16 have run; owners now carry 55% of net income).
4. The annuity recursion in CALIBRATION.md (Pension) and TODO.md item 7 read
   a_t = 1 + p_t a_{t+1}/E[R^A]. With R^A as in the paper's eq (10), including
   the survival credit, that counts p_t twice. The code divides by the fund's
   expected return before the credit. Both lines now say so.
5. The research branch's last PCHIP knot is at 99; the paper says 100.
6. Step 8 has never been run; step 14 has never been run on its own.

---

## 8. A structure for the new draft

1. Introduction. Motivation and literature as now. Replace the preliminary
   results with what the ladder established (5.1, 5.2, 5.3) and say what waits
   on the housing outflow.
2. Model, one section, the implemented model:
   1. Timing, preferences, bequest (2.2).
   2. Labour and retirement income (2.3).
   3. Assets and taxes: bond and stock, box 3 without loss offset, the EET DC
      fund (2.4).
   4. Housing: the renter's rent index; the owner's real annuity mortgage with
      q; maintenance (2.5).
   5. The DC pension: contributions above the franchise, the glide, the
      survival credit, the variable annuity (2.6).
   6. The budget, the floor, the household's problem (2.7, 4.4).
   7. Shocks and their correlations (2.8).
   8. One paragraph on what is not modelled (2.11, 5.8).
3. Calibration: one table (section 3 of this review) in 2025 euros, real, and
   short text per block (2.9), as the coauthors asked.
4. Results, along the ladder: the CGM core and Dutch numbers (5.1); the DC
   pension and the offset (5.2); housing and the owner's problem (5.3); taxes
   and the Nibud house (5.4). Behaviour only, no welfare levels.
5. The collective strategy: section 4 as method (2.10); results once TODO items
   1 and 3 are settled.
6. Appendix: normalisation (4.3), the Bellman equation (4.4), numerics and the
   convergence evidence (section 6, item 12; GRIDS.md;
   `docs/HANDOFF_2026-10-17.md`).

Figures that exist for the draft (gitignored, on Quinn's PC, under
`ladder/standard_16x16x10x8_gh5/` unless noted):

1. `summary_step16/`: the step-16 dashboards (`16_owner_maint_current.png`,
   `16_owner_maint_purchase.png`, `16_renter.png`, the three comparisons),
   `16_floored_by_age.png`, `income_profile_owner_renter.png`, and the grid
   checks.
2. `pension_grid/essence/grid_study_essence.pdf`: the DC grid study in five
   pages.
3. `ladder/standard_16x16x10_gh5/`: the dashboards of steps 1-12, and
   `diagnosis/` with the step-7 ruin figures.
4. `ladder/standard_16x16x10_gh5/mortgage_07_owner_payment.png`: the old
   mortgage against the real annuity.
