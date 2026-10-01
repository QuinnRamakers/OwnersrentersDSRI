# Lever study — what moved, 13 September 2026

132 cells, renter and owner, eight levers. Design and reading guide in
`FACTORIAL_README.md`, figures in `factorial_figs/`, per-cell numbers in
`factorial_summary.txt`. Zero solver failures.

Numbers below are the renter at the centre point unless stated: designed grid,
2560 nodes, `b0 = 0.0791`, housing ×1.00, `phi_floor = 1e-6`, `c_floor_frac =
0.01`, `gh_n = 3`. The owner behaves the same way throughout except where noted.

---

## 1. Housing cost dominates, and it is not close

Spread across each lever as a percentage of its own mean, averaged over both
tenures (`F6_effect_sizes.png`):

| lever | consumption at 25 | % of years floored |
|---|---|---|
| **housing cost** | **150%** | **290%** |
| grid points | 128% | 25% |
| consumption floor | 127% | 130% |
| grid placement | 102% | 22% |
| entry wealth | 48% | 6% |
| floor mechanism | 43% | 20% |
| quadrature | 7% | ~0% |

Two of the top four are numerical. That is the problem in one table: the grid
and the floor move early-life consumption about as much as halving the rent
does.

## 2. The consumption floor only works when housing costs are high

The cleanest interaction in the study (`F2_int_renter_hc_x_phi.png`). Consumption
at 25 as `phi_floor` goes from 1e-6 to 0.20:

| housing cost | `phi` = 1e-6 | 0.05 | 0.10 | 0.20 | change |
|---|---|---|---|---|---|
| ×1.00 (calibrated) | 2573 | 7000 | 8908 | 11463 | **+345%** |
| ×0.50 | 12249 | 14335 | 15167 | 16444 | +34% |
| ×0.25 | 19537 | 20038 | 20321 | 20794 | **+6%** |

The floor is a safety net, so it only does anything where ruin is close. Halve
the committed outflow and it stops mattering. This is why the floor has looked
like such a powerful lever in past sessions — it was always being measured at the
one housing cost where it bites hardest.

## 3. The equity corner breaks in exactly one corner of the design

`pi` at 25 is **1.00 in every cell** except those combining the calibrated
housing cost with a near-zero floor: 0.56 at 2560 nodes, 0.00 at 8064, 0.00 at
`gh_n = 5`. Both conditions have to be present. Raise the floor to 0.05 or cut
housing costs by half and the corner comes straight back.

So the textbook corner is what this model produces almost everywhere. The
production calibration sits on the one combination that destroys it.

## 4. Refining anything makes early life more extreme, not less

From the renter centre point:

| change | C at 25 | `pi` at 25 | bound binds? |
|---|---|---|---|
| baseline, 2560 nodes | 2573 | 0.56 | no |
| 8064 nodes | 2228 | **0.00** | yes |
| `gh_n` = 5 | 2228 | **0.00** | yes |
| housing ×0.25 | 19537 | 1.00 | no |
| `phi` = 0.20 | 11463 | 1.00 | no |
| `b0` = 1.0 yr | 4647 | 0.24 | no |

Better numerics push consumption down onto the search bound and the equity share
to zero; easier economics restore both. Quadrature and node count act in the same
direction, which is the signature of resolving more of a region that has no
limit rather than of approaching one.

## 5. Convergence is bought with economics, not with numerics

Early-life drift between the two finest grids (`F5_convergence.png`):

| lever | drift, ages 25-39 |
|---|---|
| housing ×1.00 | 17.5% |
| housing ×0.50 | 10.6% |
| housing ×0.25 | **1.3%** |
| `phi` = 1e-6 | 17.5% |
| `phi` = 0.05 | 13.5% |
| `phi` = 0.10 | 8.8% |
| `phi` = 0.20 | **4.6%** |

Both real levers work and both work monotonically. Grid placement and node count
do not: drift stays between 15 and 26% however the nodes are arranged. Ages
40–69 sit at 2–3% in every cell, so this is an early-life property throughout.

## 6. The production grid clips owners, in every cell

Every owner cell on the **default** grid extrapolated exactly 100 household-years
off the axis; every cell on the designed grid, both tenures, extrapolated none.
`lambda_lo = 0.002` against an owner minimum of 0.0013. Pre-existing, silent, and
it affects the seven owner/default cells in this study and every production owner
run to date.

## 7. The consumption guard's effect has no stable sign

Relaxing `c_floor_frac` from 0.01 to 0.001, renter, across grid sizes:

| nodes | guard 0.01 | guard 0.001 | change |
|---|---|---|---|
| 1152 | 6767 | 7749 | +15% |
| 2560 | 2573 | 4382 | **+70%** |
| 4800 | 2228 | 1382 | **−38%** |
| 8064 | 2228 | 2255 | +1% |

The sign flips twice. A lever whose effect cannot even be signed consistently is
not measuring a property of the model; it is measuring how a particular grid
happens to interact with a bound. The guard also shapes the policy where it does
not bind at the simulated median — at 2560 nodes it is not binding and still
moves consumption at 25 by 70% and restores the equity corner.

At the finest grid the two coincide (2228 against 2255), which looks like
convergence but is not: the 4800 cell in between gives 1382, so the sequence is
non-monotone.

Treat `c_floor_frac` as a modelling choice needing a justification, not a
harmless numerical guard. And note what it is hiding: at the finest grid with the
guard relaxed, the owner's solved consumption at 25 is **EUR 223 a year**. That
is the model's own answer at this calibration once nothing is propping it up.

## 8. Entry wealth does not interact with anything

Raising `b0` from 0.079 to 1.0 year of income shifts consumption at 25 by a
roughly constant amount at every grid size (6767→8960, 2573→4647, 2228→2655,
2228→2655) and does not change the refinement behaviour: `pi` at 25 still
collapses to zero by the finest grid either way. It is a level shift on a
quantity that is not identified, which is the same verdict the standalone sweep
reached.

---

## What this adds up to

The accumulation phase is governed by the committed housing outflow, and every
other lever is either a way of damping that (the floor, and only when the outflow
is large) or a way of revealing more of it (nodes, quadrature, placement). Nothing
in the numerical set fixes it, and two numerical levers move it as much as real
economics do — which is the reason no early-life number from this model is
currently reportable.

Ages 40+ are stable across the whole design: 2–3% drift, and the levers move
consumption there by single-digit percentages. That half of the life cycle is
usable now, on the designed grid.

**Caveats.** All cells are `use_refine = false` (measured at 0.8% on consumption
at 25 and 0.02 on the equity share). The `phi = 0.20` cells floor 2.7–3.9% of
household-years for the renter and owner respectively, so the floor buys
convergence partly by making the transfer common — check `fl%` before quoting
one. And `phi` above about 0.05 is a different model, not a better solve of the
same one.
