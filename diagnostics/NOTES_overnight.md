# Overnight diagnosis: why the answer moves with the grid

Rung 6 production model, renter, gamma 5, unless stated otherwise. Every number
comes from a saved solve. Figures are in this folder; scripts are in the session
scratchpad. A consolidated version with the figures inline was published as an
artifact.

This file was rewritten at the end of the run, so it reflects the final state of
each question rather than the order things were found in. Where a conclusion
reversed during the night, the reversal is recorded, because two of them matter.

## Summary

The grid sensitivity is two problems with different answers.

**Ages 25 to about 35 are broken, and the consumption floor is why.** At
`phi_floor = 1e-6` the floored consumption at the lowest lambda node is 2e-9, so
one floored year is worth -1.56e34 at gamma 5. The renter's rent obligation makes
that state reachable. Refining the grid resolves the region more sharply instead
of smoothing it, so the entry value diverges: -1.1e7 at 2520 nodes, -6.4e17 at
9856, -7.1e24 at 20160. Every household enters at the same state, so whether
age 25 is inside the poisoned region is a property of the grid, not of the
household: at 2520 nodes none of them are (entry V = -1.1e7), at 9856 nodes all
of them are (entry V = -6.4e17). The share of GRID NODES below -1e12 at age 25
is 4.2% and 7.0% respectively -- refining the grid resolves more of the region,
it does not dilute it.

**The solver's error falls steeply with age but does not vanish.** Measured at
matched liquid wealth, the consumption policy differs between the 2520- and
9856-node grids by 41% at age 25, 12% at 40, 4.1% at 50 and 1.8% at 60. A second
channel runs alongside: the finer grid's young household consumes 34% less over
25-35 and arrives at 50 with 28% more liquid wealth. The two pull opposite ways,
which is why the net gap in midlife reads as a modest 3.7% while both components
are several times that.

**The equity share is a flat direction and no tax change fixes that.** From age 40
every value between 0 and 1 is within 1% of the optimum in certainty-equivalent
consumption. Solved with the capital-gains loss offset restored, and again with no
capital-gains tax at all, the band is still 1.00. The cause is that liquid wealth
never exceeds 11.8% of total wealth.

**Raising the floor works; nothing else tested does.** At `phi_floor = 0.20` the
entry value stops running away, no age-25 household is left in the poisoned
region, and consumption movement between grids falls from 0.085 to 0.036.

## Two reversals

**The midlife policy is not converged.** I first read the policy panels as
coincident in midlife and said the whole midlife gap came from inherited wealth.
Measuring rather than eyeballing says otherwise: 4.1% mean difference at 50, 1.8%
at 60. Small beside 41% at age 25, but not zero. Curves 4% apart look identical on
a 0-to-1 axis.

**The binding grid axis is lambda, not u2.** I built an argument that the uniform
u2 grid's top cell was the under-resolved region, since it spans every
liquid-wealth level from a two-percent buffer down to nothing. The arithmetic is
right but it is not where the error is. Refining one axis at a time from the
baseline, at matched node counts:

| grid | nodes | C/disposable at 25 | move |
|------|-------|--------------------|------|
| baseline [16 12 10] | 2,520 | 0.388 | - |
| u1 (lambda) fine [32 12 10] | 4,760 | 0.163 | -0.225 |
| u3 fine [16 12 20] | 5,040 | 0.281 | -0.107 |
| u2 fine [16 24 10] | 4,680 | 0.353 | -0.036 |
| log-ratio [16 12 10] | 2,520 | 0.331 | -0.057 |

Refining lambda moves the answer six times further than refining u2. The cliff
runs diagonally in (lambda, u2) and its position is resolved mainly along lambda.
The practical recommendation survives for the opposite reason: `p.grid_pow`
clusters u1 toward its low end and u2 toward 1 at the same time.

## Where the extreme values come from

Terminal condition `V_T = (c*LW)^(1-gamma)/(1-gamma)` with c = 1 and LW floored at
`max(phi_floor*lambda, 1e-12)`. At the lowest lambda node that floor is 2e-9, so
the worst terminal node is -1.56e34, matching the closed form. Backward induction
accumulates it: the worst grid node equals the present value of consuming the
floor forever to within 5% at the terminal end, and reaches -4.5e35 by age 60.

`fig_trace_V.png`, `fig_origin.png`

## Why ruin is reachable at all

In CGM cash on hand is always positive, so consumption is always positive and the
value function is finite. Here the renter owes `alpha*H` every year while
retirement income is frozen in real terms.

For a renter H is a rent index and `config.h_process` gives it `(mu_R, sigma_R)`:
0.97% real drift, 1.8% volatility. The 2.7% figure is `mu_H`, the owner's
house-price process, and does not apply. Over 33 retirement years 0.97% still
compounds to a 38% rise against an income that does not move: rent goes from 98%
of net labour income at 67 to 134% at 100.

The annuity covers most of it on the mean path, so 1.9% of household-years have
rent exceeding the whole income flow and 1.2% hit the floor. The worst window is
ages 60 to 66, where the income profile has turned down and the pension has not
started: 7.2% of households are short there.

The sweep confirms it from the other side: halving the rent index gives 0.3% of
household-years at the floor, the lowest of any configuration tested.

`fig_structural.png`

## Which rung breaks what

| rung | feature | % of years at the floor | C/disposable at 25 | pi at 30 |
|------|---------|------------------------|--------------------|----------|
| 0 | cgm      | 0.000 | 0.870 | 1.000 |
| 1 | income   | 0.000 | 0.967 | 1.000 |
| 2 | housing  | 0.602 | 0.644 | 0.999 |
| 3 | dc       | 0.155 | 0.757 | 0.999 |
| 4 | inctax   | 1.863 | 0.404 | 0.794 |
| 5 | cgt      | 1.964 | 0.378 | 0.228 |
| 6 | reit     | 1.534 | 0.388 | 0.230 |

Rungs 0 and 1 reproduce CGM. Ruin first becomes possible at rung 2, when rent
arrives. Consumption breaks at rung 4, the income tax. The portfolio breaks at
rung 5, the capital-gains tax. The owner has roughly half the renter's ruin
exposure at rung 6 but is no less sensitive to the grid spacing.

`fig_ladder_ruin.png`, `fig_owner_vs_renter.png`

## The floor: how high

All at 2520 nodes and gamma 5, so only `phi_floor` differs.

| phi_floor | C/disp at 25 | pi at 30 | % floored | V(entry) |
|-----------|--------------|----------|-----------|----------|
| 1e-6 | 0.388 | 0.234 | 1.5 | -1.13e7 |
| 0.01 | 0.530 | 0.314 | 1.7 | - |
| 0.05 | 0.680 | 0.671 | 1.9 | - |
| 0.10 | 0.767 | 0.794 | 2.3 | -1.45e6 |
| **0.20** | **0.906** | **0.939** | **3.7** | - |
| 0.30 | 1.125 | 0.774 | 9.3 | -6.20e5 |
| 0.618 (net AOW) | 1.988 | 0.000 | 60.2 | -1.49e5 |

`config/params.m` names 1 as the AOW value. Two things complicate it. The floor is
proportional to current income, so it is a level floor only in retirement. And it
is a share of GROSS income while liquid resources are after tax, so `phi_floor = 1`
is the gross AOW and the net-AOW value is `1 - tau_inc = 0.618`. An earlier session
had identified 0.618 as the decisive run.

Solved, 0.618 is unusable: the floor binds in 60% of household-years, consumption
at 25 reaches twice disposable income, and the equity share goes to zero. A
household living on a transfer has no reason to care about returns. The
proportionality is what defeats it — 0.618 guarantees 62% of a rising wage during
working life.

**Use 0.10 to 0.20.** At 0.20 consumption at 25 is inside the 0.87-0.97 the CGM
rungs produce, the equity share is at the CGM-like corner, and the floor still
binds under 4% of the time. The floored fraction is flat from 1e-6 to 0.05 and then
turns almost vertical, so it is the statistic to check when choosing.

`fig_floor_ladder.png`

## Does any candidate survive a refinement

Movement between 2520 and 9856 nodes.

| configuration | mean abs dpi | mean abs dC / C | V(entry) ratio | poisoned at 25, 9856 |
|---------------|--------------|-----------------|----------------|----------------|
| baseline, floor 1e-6 | 0.079 | 0.085 | 5.6e10 | 100% |
| entry buffer b0 = 1y | 0.062 | 0.081 | 1.5e7 | 100% |
| floor 0.10 | 0.088 | 0.055 | 5.4 | 0% |
| floor 0.10 + buffer 1y | 0.075 | 0.045 | 4.1 | 0% |
| **floor 0.20 alone** | 0.064 | **0.036** | - | 0% |

Only the floor works, and better the higher it goes within the usable band. The
entry buffer fails on its own: it puts the household off the cliff on the coarse
grid and the fine grid puts it straight back. Combined with floor 0.10 it improves
consumption stability from 0.055 to 0.045, but raising the floor to 0.20 does better
at 0.036 with one parameter instead of two.

No floor makes early-life consumption grid-independent. At 0.20 it still falls 14%
under refinement, against 56% in the baseline.

`fig_fixes.png`

## Grid design: clustering beats refining

`p.grid_pow` clusters u1 toward its low end and u2 toward 1, and reproduces the
uniform grid exactly at grid_pow = 1. It had never been used in a solve. Taking the
uniform 9856-node solve as the reference — not as truth, since nothing here has
converged, but as the direction refinement moves in:

| 2520-node solve | mean abs dC / C | mean abs dpi | gap closed |
|-----------------|-----------------|--------------|------------|
| uniform | 0.151 | 0.079 | - |
| **grid_pow 2** | **0.044** | 0.058 | **71%** |
| grid_pow 3 | 0.060 | 0.061 | 60% |

Clustering closes 71% of the consumption gap at the same node count, and all of the
saving is in the entry region: at age 25 uniform-2520 sits 126% from the fine solve
and clustered-2520 sits 5%; from age 40 both are within a few percent. More
clustering is not monotonically better — grid_pow 3 closes 60% — so 2 is the
setting.

`fig_gridpow.png`

## Ranking the calibration levers

19 configurations at 2520 nodes, one change each from the baseline's 0.388.

| configuration | C/disp at 25 | pi at 30 | change | % floored |
|---------------|--------------|----------|--------|-----------|
| gamma 2 | 1.136 | 0.999 | +0.748 | 2.3 |
| gamma 3 | 0.917 | 0.975 | +0.528 | 2.0 |
| phi_floor 0.20 | 0.906 | 0.939 | +0.518 | 3.7 |
| h_mult 2 (half the rent) | 0.853 | 0.944 | +0.465 | **0.3** |
| phi_floor 0.05 | 0.680 | 0.671 | +0.292 | 1.9 |
| h_mult 3 | 0.671 | 0.669 | +0.282 | 0.6 |
| entry buffer 1.0Y | 0.596 | 0.213 | +0.208 | 1.5 |
| tau_inc 0.25 | 0.579 | 0.527 | +0.191 | 0.6 |
| phi_floor 0.01 | 0.530 | 0.314 | +0.141 | 1.7 |
| tau_inc 0.30 | 0.513 | 0.418 | +0.125 | 0.8 |
| entry buffer 0.5Y | 0.482 | 0.210 | +0.094 | 1.5 |
| no CGT at all | 0.414 | 0.809 | +0.026 | 1.4 |
| baseline | 0.388 | 0.235 | - | 1.5 |
| kappa_base 0.10 | 0.335 | 0.209 | -0.053 | **4.4** |
| gamma 10 | 0.163 | 0.000 | -0.225 | 1.2 |

Among levers that do not touch preferences, the floor is largest and the rent
level second. Every configuration converges to C/disposable near 1 by age 50, so
the anomaly is purely early-life. The higher floors restore a declining equity
glide in accumulation, which is the CGM shape.

Cutting the DC contribution rate runs the other way: it *lowers* consumption at 25
despite raising disposable income, because a smaller pension means more private
self-insurance, and it pushes ruin exposure to 4.4%.

Gamma and the floor are not independent knobs. The floored state's utility scales
as `phi_floor^(1-gamma)` — one floored year is worth -1.25e17 at gamma 3 and
-1.56e34 at gamma 5. Lowering gamma works partly by making the floor shallow.

`fig_sweep.png`

## The calibration at age 25

| item | amount | share of gross |
|------|--------|----------------|
| gross income | 44,405 | 1.000 |
| DC contribution | 4,823 | 0.109 |
| income tax | 15,120 | 0.341 |
| rent | 10,657 | 0.240 |
| disposable | 13,804 | 0.311 |
| consumption | 5,579 | 0.126 |

`tau_inc = 0.382` is applied flat to wages, AOW and the annuity. For a 44k earner
the effective average rate after the algemene heffingskorting and arbeidskorting is
closer to 18-20%, and AOW income sits in a lower bracket. Worth checking against
the CBS source. Rent at 24% of gross is 39% of net, above the usual Dutch
affordability norm.

## The equity share is not identified

| age | pi* | within 0.1% CE | within 1% CE | cost of being 0.07 off |
|-----|-----|----------------|--------------|------------------------|
| 30 | 0.00 | [0.00, 0.09] | [0.00, 0.36] | 0.070% |
| 40 | 0.00 | [0.00, 0.30] | [0.00, 1.00] | 0.013% |
| 50 | 0.00 | [0.00, 0.42] | [0.00, 1.00] | 0.002% |
| 60 | 0.05 | [0.00, 0.71] | [0.00, 1.00] | 0.001% |

Not an artefact of reading at the median: across the whole liquid-wealth dimension
the equity share is sharply identified only for young households with very little
liquid wealth, where equity genuinely risks ruin. At ages 50 and 60 the band is the
full unit interval at every wealth level tested, and simulated households at 40
hold 1.6 to 3.4 years of income.

Consumption is the opposite: its 0.1%-CE band is 8 to 17% of its optimum, and the
3% gap between grids costs at most 0.03%.

`fig_flatpi.png`, `fig_identify.png`, `fig_flat_robust.png`

### It is the missing loss offset, not the tax

Three treatments of the same 36% rate, and the solved policy for each:

| treatment | premium | sd | Sharpe | Merton | pi@30 | pi@50 | 1%-CE band at 40 |
|-----------|---------|-----|--------|--------|-------|-------|------------------|
| box 3 as modelled | 1.20% | 12.2% | 0.098 | 0.160 | 0.234 | 0.164 | 1.00 |
| none | 4.00% | 16.0% | 0.250 | 0.313 | 0.653 | 0.521 | 1.00 |
| symmetric, deductible | 2.56% | 10.2% | 0.250 | 0.488 | 0.796 | 0.701 | 1.00 |

A symmetric tax leaves the Sharpe ratio untouched and RAISES the optimal share to
0.313/(1-tau) = 0.488 to three decimals — Domar-Musgrave, the government as silent
partner. Denying the loss offset cuts the Sharpe ratio to 0.098. It is the
asymmetry, not the tax, that suppresses equity.

And the band is 1.00 in all three. Tripling the premium moves the level by 0.56 and
does nothing for identification.

`fig_cgt.png`

## The retirement kink is a composition effect

| age | liquid share | imposed DC share | liquid + pension |
|-----|--------------|------------------|------------------|
| 40 | 0.073 | 0.771 | 0.411 |
| 50 | 0.096 | 0.486 | 0.342 |
| 60 | 0.126 | 0.200 | 0.182 |
| 66 | 0.676 | 0.029 | 0.131 |
| 67 | 0.808 | 0.000 | 0.115 |
| 80 | 0.791 | 0.000 | 0.080 |

Over the decade to retirement the liquid share rises by 0.725 while total exposure
falls by 0.114; across the annuitisation date the liquid share jumps +0.133 while
total exposure moves -0.016. Risk-taking declines smoothly the whole way. The
liquid share rises only because the glide path is handing its equity over.

This is the same conclusion an earlier session reached from the welfare side:
compare total exposure to CGM, never the liquid share.

`fig_kink.png`

## The final ten years

Median liquid wealth falls from about 2.5 years of income at 65 to 1e-5 years by
100, and the share with essentially no liquid wealth goes from 7% at 67 to
effectively all of them. The equity share reported for those ages is the
composition of an account with almost nothing in it. Weighting by liquid wealth
removes about a third of the post-retirement roughness, from 0.026 to 0.016 in mean
absolute second difference, so the empty-account effect is real but not the whole
of it.

The poisoned region has three zones, not one: entry, a pre-retirement window at 60
to 66, and late life.

`fig_latelife.png`

## Quadrature: the one-period error is nil, the full test did not run

Holding the solved continuation value fixed and redoing only the expectation on a
9x9x9x5 grid instead of 5x5x5x3, which takes the effective node count from 35.5 to
107.8, moves optimal consumption by 0.00% at every age tested. That bounds the
ONE-PERIOD integration error at essentially zero. It cannot see an error already
baked into V, so it is a bound and not an answer.

The full re-solve at gh_n = 7 and 9 was meant to settle it and did not run: the
driver passed a hard-coded `utility.build_state_grids(p, dims, 5)`, and that third
argument sets `p.gh_n`, so both configurations solved at 5. Their outputs are
identical to four significant figures and their runtimes differ by one second.

What moved in those runs was the state grid — the same driver passed `[18 14 10]`
as BASE counts, which the anchor splice turns into 20x16x10 = 3,200 nodes rather
than the 2,520 the label said. So C/disposable at 25 going 0.388 -> 0.273 is a
2,520 -> 3,200 refinement. A useful extra point on the grid sequence, silent on
quadrature.

**Two traps in this codebase, both hit in one night.** `dims` is a base count and
the anchor splice adds two nodes each to u1 and u2. And `build_state_grids`' third
argument silently overwrites `gh_n` — pass `[]` unless you mean to set it.

## The REIT leg is not yet calibrated

| asset | E[R] | sd | premium | Sharpe |
|-------|------|-----|---------|--------|
| risk-free | 1.10% | - | - | - |
| stocks | 5.10% | 16.0% | 4.00% | 0.250 |
| REIT | 4.10% | 12.0% | 3.00% | 0.250 |
| rent index | 0.97% | 1.8% | -0.13% | -0.072 |

The two Sharpe ratios are identical to three decimals, so the REIT is a scaled
equity. When two assets share a Sharpe ratio the tangency weights go as the
reciprocals of their volatilities: the risky sleeve is 57% REIT and 43% stocks, and
that split is invariant to their correlation (checked at 0, 0.2, 0.4, 0.6, 0.8,
0.9). "The REIT deserves a large share" follows from the parameters, not from the
model.

Every correlation is exactly zero: `corr_SL`, `corr_HL`, `corr_SH`, `corr_RL`,
`corr_RS`, `corr_RH`. Zero stock-income is defensible and is CGM's benchmark. Zero
REIT-equity and zero REIT-housing are not, in a paper about adding a REIT sleeve,
and those two are where a REIT result would come from.

The pot's REIT share is imposed at 10% with `choose_tau_S` off, so nothing
optimises it. As configured the model cannot answer how much REIT a DC pot should
hold.

`fig_reit.png`

## What to change

1. **Raise the consumption floor to 0.10-0.20.** Origin of the extreme values and
   of the entry-region divergence. Solved at 0.10 and 0.20 on both grids: the entry
   value stops running away, the poisoned region empties, consumption movement
   falls from 0.085 to 0.036. Not 0.618, and not 1.
2. **Check `tau_inc`.** Cutting it to 0.25 moves consumption at 25 from 39% of
   disposable income to 58%, second only to the floor and the rent level among
   non-preference levers.
3. **Report total equity exposure, not the liquid share.** Liquid wealth is at most
   11.8% of total wealth and the pension's share is imposed.
4. **Report the equity share as a band, and name what moves it.** From age 40 every
   value in [0,1] is within 1% of the optimum. What moves the level is the
   capital-gains asymmetry, not the rate.
5. **Look again at the rent level, and at whether the renter can move.** Halving
   the rent index gives the lowest ruin exposure of anything tested. 24% of gross
   is 39% of net.
6. **Try the floor before buying more resolution.** The solver's error is
   concentrated where the floor made the value function hard to represent. If more
   resolution is bought, spend it on lambda, or use `p.grid_pow` to cluster both
   axes at once.

## Final results, after the 7am mark

Two solves landed late and both sharpen the floor recommendation.

Adding floor 0.30 to the refinement table:

| configuration | mean abs dpi | mean abs dC / C | V(entry) ratio |
|---------------|--------------|-----------------|----------------|
| baseline, floor 1e-6 | 0.079 | 0.085 | 5.6e10 |
| entry buffer b0 = 1y | 0.062 | 0.081 | 1.5e7 |
| floor 0.10 | 0.088 | 0.055 | 5.4 |
| floor 0.10 + buffer 1y | 0.075 | 0.045 | 4.1 |
| floor 0.20 | 0.064 | 0.036 | - |
| floor 0.30 | 0.069 | **0.026** | **2.2** |

Grid stability improves monotonically with the floor, all the way to 0.30. But 0.30
floors 7.4% of household-years and puts consumption at 25 ABOVE disposable income
(1.041 at 9856, 1.125 at 2520). **0.20 remains the recommendation**: it gives up a
third of the stability to keep the floored fraction under 4% and consumption inside
the 0.87-0.97 the CGM rungs produce.

And a caveat on "grid-independent". phi_floor = 0.20 solved twice at 9,856 nodes,
uniform and grid_pow 2, gives C/disposable at 25 of 0.783 and 0.711 — 9% apart at
identical node counts. Node PLACEMENT still matters at the recommended floor. Four
times better than the baseline, not finished.

### grid_pow is an efficiency gain, not a cure

Solving the clustered grid at 9,856 nodes as well separates two things that the
"71% of the gap" number runs together. Clustering gets to the fine-grid answer more
cheaply; it does not make that answer stop moving.

| family | mean abs dC / C, 2520 -> 9856 | V(entry) ratio |
|--------|-------------------------------|----------------|
| uniform | 0.085 | 5.6e10 |
| grid_pow 2 | 0.077 | 9.9e14 |
| grid_pow 3 | 0.081 | 1.1e16 |

Within the clustered family the entry value still runs away, by fifteen orders of
magnitude. So set grid_pow = 2 for the fourfold node saving, and do not read it as
a fix. No arrangement of nodes substitutes for the floor — the same conclusion the
refinement sequence reached, from a third angle.

## How big is the numerical error, measured against a known-zero truth

Every other measurement here compares one discretisation against another, which
shows the answer moving but never how far it has to go. This one has a known
answer.

For a renter H enters in two places only: the rent bill alpha*H and the state
normalisation W = X + A + H + Y. It is not bequeathed (h_beq_fac = is_owner *
(1 - sell_cost) = 0), not sold, not consumed, and its growth factor is the same
process whatever its scale. So in LEVELS the problem depends on the product
alpha * h_mult and never on the two separately. Holding that product at 0.24 and
varying the split gives four solves of ONE model.

| h_mult, alpha | entry lambda | entry u2 | C@25 | C@50 | V(entry) |
|---------------|--------------|----------|------|------|----------|
| 1, 0.240 | 0.481 | 0.927 | 3,998 | 35,192 | -5.4e5 |
| 2, 0.120 | 0.325 | 0.962 | 5,507 | 34,673 | -1.2e6 |
| 4, 0.060 (current) | 0.197 | 0.981 | 3,767 | 35,279 | -3.8e7 |
| 8, 0.030 | 0.110 | 0.990 | 4,032 | 36,026 | -3.4e11 |

Error against the current calibration: **3.6 to 4.5% on mean consumption, up to
46% at its worst age, up to 0.22 in the equity share.** The true difference is
zero.

Two consequences. The grid-refinement differences reported above (0.036 to 0.085
on consumption) are the same order as the model's own numerical noise — real, and
not a separate phenomenon. And the uniform-versus-logratio disagreement in pi of
about 0.07 sits comfortably INSIDE a numerical error of 0.22; it was never worth
chasing.

V(entry) spans a factor of **620,000** across four solves of the identical model,
ordered monotonically by how far into the u2 corner the normalisation puts the
household. It is not a property of the economics.

**Free reparameterisation:** h_mult = 1 with alpha = 0.24 leaves every budget
constraint untouched, moves entry from u2 0.981 to 0.927 and lambda 0.197 to 0.481,
and improves the entry value's conditioning by two orders of magnitude. Renter
only — for an owner H is genuine wealth and h_mult is a real parameter.

`fig_invariance.png`

## The owner, and what it does to the floor recommendation

Five owner solves matched to the renter on every other setting (rung 6, gamma 5,
uniform, gh_n 5, 8000 households, seed 12345), plus one more for the missing
cell: `phase8.mat` and `phase10.mat`.

The renter's invariance test has no owner counterpart and cannot be built. It
works because `alpha` and `h_mult` enter the renter's budget only as a product --
H is a rent index, never sold, never bequeathed. For an owner H is the house:
real wealth, bequeathed at `(1 - sell_cost) x H`, carrying a mortgage scaled to
its value. Doubling H and halving the carrying rate leaves the owner strictly
better off, so there is no known-zero to measure against. Everything that needs
only two solves to compare does carry over.

### The owner is not the safe case

| configuration | renter pi@30 | owner pi@30 | renter C/disp@25 | owner C/disp@25 |
|---|---|---|---|---|
| floor 1e-6, 2520 | 0.234 | 0.274 | 0.388 | 0.320 |
| floor 1e-6, 9856 | 0.007 | 0.028 | 0.172 | 0.155 |
| floor 0.20, 2520 | 0.939 | 0.977 | 0.906 | 0.984 |
| floor 0.20, 9856 | 0.691 | 0.991 | 0.783 | 0.943 |

Same direction and same order of magnitude in both tenures. Measured like for
like, the share of household-years in the `V < -1e12` region is 14.2% for the
owner against 11.1% for the renter, and both profiles peak just before 67 (owner
37%, renter 25%) then collapse when the annuity starts.

So the rent index is a route into the poisoned region, not the cause of it. The
owner's route is the mortgage and carrying cost, which scale with H and do not
retire when wage income does. Untested as a mechanism; the timing is consistent
with it and nothing more.

### Raising the floor does not converge the model

The floor recommendation was made on grid sensitivity alone. Completing the same
2x2 on the interpolation rule changes what it is worth.

| lever | renter abs dC/C | owner abs dC/C | renter abs dpi | owner abs dpi |
|---|---|---|---|---|
| grid 2520 vs 9856, floor 1e-6 | 15.1% | 12.6% | 0.078 | 0.121 |
| grid 2520 vs 9856, floor 0.20 | 3.9% | 1.7% | 0.064 | 0.052 |
| rule z vs log-z, floor 1e-6 | 87.3% | 68.1% | 0.364 | 0.381 |
| rule z vs log-z, floor 0.20 | 42.5% | 33.4% | 0.259 | 0.293 |

At `phi_floor = 0.20` refining the grid moves consumption by 2 to 4 percent and
changing what the interpolant is linear in moves it by 33 to 42. A convergence
test built on refinement alone reports success here. It is measuring the
stability of one rule, not the accuracy of the answer: both rules are close to
stable under refinement, around different answers.

`phi_floor` 0.10 to 0.20 still fixes the ruin blow-up and the grid sensitivity,
which are real. It does not deliver a converged model, and the earlier write-up
presented it as if it did.

`fig_owner_policies.png`, `fig_owner_cliff.png`, `fig_levers.png`
(`fig_owner_levers.png` is deleted: three levers and a title the fourth refutes)

## The interpolation structure, and one number that is still unexplained

`p.interp_method` added to `+solver/bellman_step_lna.m` alongside `p.interp_space`:
`linear` (default, bitwise unchanged), `makima`, `spline`. `cubic` is deliberately
not offered -- the anchor splice makes the grid non-uniform and griddedInterpolant
silently downgrades `cubic` to `spline` in that case, answering a different
question than the one asked.

Four solves, renter, 2520 nodes, both floors: `phase9.mat`.

### It splits by life phase, not by scheme

Pairwise mean abs dC/C at `phi_floor = 0.20`:

| pair | 25-39 | 40-64 | 65+ |
|---|---|---|---|
| linear vs makima | 51.0% | 6.5% | 3.0% |
| linear vs spline | 129.9% | 9.6% | 3.7% |
| makima vs spline | 45.1% | 3.9% | 0.8% |

Equity share, same cells, share points: 0.402/0.110/0.031, 0.476/0.107/0.049,
0.142/0.019/0.018.

From 40 onward three structurally different interpolants land within 1-10% of each
other. Ages 25-39 are 45-130% apart under every pairing, so that phase is not
solved at this resolution by any of them and choosing between the rules does not
help.

The incumbent is the outlier: makima against spline is the smallest gap in all six
cells. A shape-preserving cubic and a non-shape-preserving one agreeing with each
other and diverging from the piecewise-linear scheme is what curvature being
flattened looks like. Not proof that multilinear is wrong, but it removes "linear
is the safe default" as an argument.

### The 2255 euro question, half answered

Four runs (log-z, makima-z and spline-z at floor 1e-6, spline-z at floor 0.20)
return consumption at 25 of 2255 euro to the euro -- `c_frac = 0.130231` -- while
disagreeing everywhere else. That is not the consumption floor under either
setting and not a node of the 41-point control grid.

Re-solved makima at floor 0.20 keeping the policy arrays (`phase11.mat`):

    SOLVER c_pol at entry = 0.378160  ->  6548 euro
    SIM    c_frac at 25   = 0.378160  ->  6548 euro   (difference 6.3e-15)

So `simulate.forward` reproduces the solver's policy exactly and is not
overriding anything at t = 1. The recurring 0.130231 is therefore the solver's own
policy at the entry node under those four schemes, not a simulator artifact.

Why four schemes land on the same interior value to six digits is unresolved. The
plausible story is that a CRRA period utility against a continuation value that has
locally collapsed to a pure power of wealth gives a constant consumption share
independent of the interpolant's details, and that those four schemes produce that
collapse at the entry node while multilinear does not. Untested.

### A caution about reading "% floored"

Under makima at `phi_floor = 0.20` the age-25 household consumes 6548 euro while
`phi_floor * Y = 8881`. That is not a bug: the floor is a guarantee on RESOURCES,
paid when own resources fall short, and the household may then save out of it. So
`phi_floor = 0.20` does not mean consumption is at least 20% of gross income, and
the floored fraction (2.48% of household-years here) counts top-up events, not
household-years spent below the floor level. A diagnostic written as
`C <= phi_floor * Y` counts the second and will report 100% at age 25.

`fig_structure.png`

## Where the non-smoothness is, and whether retirement causes it

Two questions, separate answers. Scripts: `where_rough.m`, `node_starve.m`,
`phase12.m`, `graft_fig.m`. Nothing re-solved except the graft.

### It is two defects at opposite ends of the life cycle

Mean absolute second difference of the simulated age profile:

| | early 25-39 | midlife 40-59 | late 60+ | late / midlife |
|---|---|---|---|---|
| equity share, 2520 | 0.0172 | 0.0045 | 0.0497 | 10.9 |
| equity share, 9856 | 0.0262 | 0.0022 | 0.0419 | 19.2 |
| consumption, 2520 | 0.56% | 0.19% | 0.21% | 1.1 |
| consumption, 9856 | 3.73% | 0.21% | 0.28% | 1.3 |

The portfolio is rough in retirement, 11 to 19 times the midlife level, and it
gets worse with refinement. Consumption is not: its roughness is an early-life
problem, 3x midlife at 2520 nodes and 18x at 9856. Midlife is clean in both.

### The retirement half is node starvation, not noise

`u1 = lambda = Y/W`. At 67 the wage stops and Y becomes the AOW, so lambda falls
an order of magnitude in one year -- from 0.016-0.128 at 66 to 0.0049-0.041 at 67
-- while the grid stays where it was put. Count of u1 nodes inside the 1st-99th
percentile of the population:

| age | 30 | 50 | 60 | 66 | 67 | 70 | 80 | 90 |
|---|---|---|---|---|---|---|---|---|
| 2520 | 6 | 6 | 3 | 3 | **0** | 1 | 1 | 2 |
| 9856 | 8 | 7 | 6 | 5 | 1 | 1 | 2 | 4 |

The three lowest u1 nodes are 0.002, 0.0419, 0.0817, so the entire retired
population lives inside the single cell [0.002, 0.0419] for about fifteen years.
Every policy there is one linear interpolation between the same two nodes. A
sawtooth is what that produces. (The single node at 25 is different and benign:
all households enter at one point.)

Only **17.1%** of the 2520-node cube is ever visited by any household at any age,
and **17.0%** of the 9856-node cube. Four times the nodes, the same coverage, one
extra node where the retired actually are. That is the mechanical reason the grid
sequence does not converge -- the refinement is spent where nobody lives.

Ruin: households at 30 sit clear of the `V < -1e12` set, from about 60 they are
inside it. Share of households in it: 0.0% at 30, 0.9% at 50, 4.1% at 66, 6.7% at
80. The share of NODES ruined falls over the same span, 4.4% to 0.9%. The set
shrinks and the population migrates into it, so counting nodes understates it.

### The propagation hypothesis is refuted

Backward induction has exactly one channel from retirement into working life: the
value function at the handover. So graft it. Coarse grid over working life,
started at age 68 from the FINE grid's value function mapped across in z space.

Share of the coarse-to-fine working-life gap that the graft closes:

| phase | consumption | equity share |
|---|---|---|
| 25-39 | 1.2% | 6.5% |
| 40-54 | -9.4% | 21.1% |
| 55-66 | -20.1% | 12.9% |

Handing the coarse working life a four-times-finer retirement value function
closes essentially none of the consumption gap and at most a fifth of the
portfolio gap, with two cells going the wrong way. V at the entry anchor moves
from -1.127e7 to -1.179e7, a 4.6% change, against the fine grid's -6.354e17.

So the working-life error is manufactured in working life, on the working-life
grid, and the retirement error stays in retirement. The two defects are
independent, which is inconvenient as a story and convenient in practice: they
can be attacked separately, and fixing retirement will not fix ages 25-39.

`fig_roughness.png`, `fig_grid_cloud.png`, `fig_node_starve.png`, `fig_graft.png`

## The cause, established by removing it

Everything above measures discretisation sensitivity. None of it establishes a
cause. This does. `alpha` and `h_mult` enter the renter's budget only as a
product, so scaling `alpha` scales the committed rent outflow and changes nothing
else about the model. Same solver, same grids, same floor, same interpolant.
`phase15.mat`.

| rent, % of net income at 25 | ages 25-39, 2520 vs 9856 | V(entry) ratio across the refinement | floored | poisoned |
|---|---|---|---|---|
| 44 (production) | 64.7% | 5.6e10 | 1.54% | 4.2% |
| 22 | 9.9% | 2.63 | 0.06% | 1.5% |
| 11 | **1.1%** | **1.07** | 0.00% | 0.6% |

At an 11% rent burden the model converges outright. Two grids differing fourfold
agree on consumption to 1.1%, the entry value moves 7%, no household-year is ever
floored. It behaves like an ordinary life-cycle model.

So the answer to "what is actually wrong" is: at a 44% committed outflow with
gamma = 5 and a floor near zero, there is no value function to converge to. Every
numerical lever tested this session -- density, placement, range, transform,
structure -- was measuring that one fact through a different window, which is why
they all gave the same answer and why none of them fixed it.

This confirms the August diagnosis rather than adding to it. That diagnosis had
never been tested directly; it has now.

### RETRACTION: log-z is broken, not an alternative

I used the linear-z against log-z gap as an error bar throughout this session,
including to argue that raising the floor "buys grid-insensitivity, not a
converged answer". That argument was largely measuring log-z's own defect.

At quarter rent burden, where linear-z demonstrably converges (V(entry) -7.3e4
coarse against -7.8e4 fine, nothing floored, 0.6% of nodes poisoned), log-z on the
identical problem returns V(entry) = -1.16e21 and poisons 6.7% of nodes. Sixteen
orders of magnitude on a well-posed problem. At half burden the same pair is
-2.3e5 against -4.5e25, with 1.5% against 11.6% poisoned.

The mechanism is straightforward: interpolating linearly in log z underestimates a
convex function, which pushes V down and tips nodes over the cliff, which poisons
more of the grid, which pushes V down further. log-z manufactures the pathology it
is being used to measure.

`p.interp_space = 'logz'` stays in the code as a conditioning diagnostic, but it
must not be read as a rival scheme whose disagreement bounds the error. The honest
structural error proxy is linear against makima.

### The grid fixes: real, and capped

`phase16.mat`: phi_floor 0.20, lambda_hi 0.42, grid_pow 2 on u1, uniform u2 over
[0.60, 1]. Mean abs dC/C:

| test | 25-39 | 40-59 | 60+ |
|---|---|---|---|
| density 2520 vs 9856 | 10.8% | 1.9% | 1.2% |
| structure linear vs makima | 34.6% | 5.3% | 3.3% |
| transform z vs log-z (not an error bar, see above) | 47.5% | 8.8% | 9.8% |

against 15.1% / 87.3% / 51.0% in early life for production. Midlife and retirement
are now usable: 1-5% across grids and interpolants is ordinary solver error. Ages
25-39 are not, and the rent-burden result says grid work cannot make them so.

### New parameters, all defaulting to existing behaviour

Verified bitwise against the stored production grids and value functions.

    p.u2_lo         bottom of the u2 axis (default 0). u2 never fell below 0.63
                    in 608,000 household-years, so half that axis was unreachable.
    p.grid_pow_u2   clustering exponent for u2 alone (default: grid_pow). One
                    exponent drove both axes and they want opposite things.
    p.interp_space  'z' (default) | 'logz'   -- diagnostic only, see the retraction
    p.interp_method 'linear' (default) | 'makima' | 'spline'

### What to do

1. Make the outflow avoidable -- let the renter downsize. Removes the cause
   rather than damping it, and is what Yao & Zhang do.
2. phi_floor 0.10-0.20. Damps the cause; needed anyway; does not remove it.
3. At the current calibration, report ages 40+ with the grid fixes applied and
   state that the accumulation phase is not identified.

`fig_verdict.png`
