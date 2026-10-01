# Overnight lever study — how to read it

Eight levers, a centre point, every lever swept from it one at a time, and ten
pairwise slices. 114 cells, renter and owner. Run with `factorial_run.m`,
plotted with `factorial_plots.m`, figures in `factorial_figs/`, per-cell numbers
in `factorial_summary.txt`, progress in `factorial_log.txt`.

## The centre point

Everything is read against this, and it is drawn thicker in the main-effect
panels:

| lever | baseline | other levels |
|---|---|---|
| grid placement | designed (trimmed, graded axes) | default (production axes) |
| grid points | 2560 | 1152, 4800, 8064 |
| entry wealth `b0` | 0.0791 yr of income | 0.5, 1.0 |
| housing cost | ×1.00 calibrated | ×0.50, ×0.25 |
| consumption floor `phi_floor` | 1e-6 | 0.05, 0.10, 0.20 |
| floor mechanism `c_floor_frac` | 0.01 (production guard) | 0.001 (relaxed) |
| quadrature `gh_n` | 3 | 5 |
| tenure | renter | owner |

Housing cost is scaled through the carrying rate only — `alpha` for the renter,
`theta` and the amortisation for the owner — so it moves the committed outflow
and nothing else. `c_floor_frac` is the solver's lower bound on the consumption
search, `c >= cff/LW_W`, i.e. "consume at least `cff` of total wealth". At the
production value it binds in early life, so consumption at 25 is the guard's
number rather than the household's; the relaxed level shows what the model
actually wants.

## The figures

| file | what it answers |
|---|---|
| `F1_main_<tenure>_C.png` | one panel per lever: what does the consumption profile do as that lever alone moves |
| `F1_main_<tenure>_pi.png` | the same for the equity share |
| `F2_int_<tenure>_<a>_x_<b>.png` | interactions. Columns are levels of lever `a`, colours are levels of lever `b`, top row consumption and bottom row equity share. If the colour spread changes across columns, the two levers interact |
| `F3_policy_pi_<tenure>.png` | the policy itself: equity share against liquid wealth at age 50. Right edge is no liquid wealth, which is where the ruin surface sits |
| `F4_policy_c_<tenure>.png` | the same for the consumption share |
| `F5_convergence.png` | early-life drift between successive grid sizes, under each lever. Falling with nodes means converging; flat or rising means not. Solid renter, dashed owner |
| `F6_effect_sizes.png` | which lever moves consumption at 25, floor incidence and retirement roughness the most |

## Reading the interaction panels

Each `F2` figure is one pair. Within a column, the spread of the coloured lines
is the effect of lever `b` at that level of lever `a`. Compare that spread
between columns:

- spread roughly the same in every column → the two levers are additive
- spread collapses in one column → that level of `a` switches lever `b` off
- lines cross in one column and not another → the sign of `b`'s effect depends
  on `a`, which is the interaction worth writing about

## Things to check before believing a number

- **`off` in `factorial_summary.txt`** is the count of simulated household-years
  whose state fell outside the grid and was nearest-extrapolated, silently. Any
  cell with a nonzero count is clipping and its policies are suspect there.
- **`cbnd`** is 1 where the consumption search bound binds at 25. In those cells
  consumption at 25 is `c_floor_frac × W`, not a solved quantity.
- **ages 25–39 are not identified** at the production housing cost, on any grid,
  at any node count. That is the standing result this study is mapping, not
  something it is expected to fix. Read the early-life panels as "how far does
  this lever move a number that has no limit", not as a converged answer.
- Everything is `use_refine = false` for runtime. It was measured to move
  consumption at 25 by 0.8% and the equity share by 0.02.
