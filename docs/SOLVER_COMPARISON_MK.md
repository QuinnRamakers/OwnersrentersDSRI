# Solver comparison with the coauthor's housing model (MK)

Quinn shared a separate model from a coauthor (`cons_savings_housing_MK.zip`,
files dated 22 January 2026; `main_jmp.m` is headed "March 20, 2023"). This file
compares how the two codes solve their models and lists what is worth taking
over. Nothing in our code was changed and nothing was run: this container has
no MATLAB. Line numbers for our code refer to `main` at 83351bb.

## The two models

MK. Epstein-Zin preferences (gamma 5, EIS 0.1, beta 0.96) over a Cobb-Douglas
bundle of consumption and housing services. Each year a household chooses to
rent, buy, or (if it owns) stay in its house. The choices are shares of total
wealth W, which includes this year's labour income: consumption c, bonds b
(negative is a mortgage, at most 80% of the house), house size q, and stocks s
as the residual. Two states: L/W, and home equity over non-labour wealth. Ages
20-100, nominal returns deflated by inflation.

Ours. CRRA (gamma 5), housing passive, a DC pot. Choices: c, the share of
liquid resources LW consumed, and pi, the equity share of saving. Three states
(u1 = Y/W, u2, u3). W = X + A + H + Y, so the normalisation by total wealth
including current income is the same as MK's.

Both value functions are homothetic in W, both are solved by backward induction
on ratio states with fmincon at each node, and both use the same shock
quadrature. The codes differ mainly in what fmincon is given to minimise and in
how the search is protected against local peaks.

## Side by side

| | MK | Ours |
|---|---|---|
| Value stored | v, the value per unit of W in certainty-equivalent (CE) units. Epstein-Zin makes it homogeneous of degree 1 | V_tilde = V / W^(1-gamma), in utility units. Converted to z = ((1-gamma) V_tilde)^(1/(1-gamma)) for interpolation (`bellman_step_lna.m` 133-140) |
| Interpolated object | v, linear (`interp2 '*linear'`, `interp1`) | z, linear (`griddedInterpolant`). Same object as MK's |
| Off the grid | next state clamped to the grid ends before interpolating | `'nearest'` extrapolation. Same effect |
| Objective given to fmincon | minus the Epstein-Zin aggregator, in CE units, times a scale | minus V_tilde in utility units, times a scale (281-283) |
| Objective scale | 1e6 / (smallest v of the period just solved) | 1 / median abs(V_tilde) of next period (154-159) |
| Choice variables | renter (c, b), buyer (c, b, q), stayer (c, b); s is the residual | (c, pi) |
| Constraints | linear inequalities A x <= b for s >= 0 and the LTV limit, with the right-hand side moved in by TolCon (1e-8) so fmincon's allowed violation cannot make s negative | box only: c in [c_floor, 1 - 1e-6], pi in [0, 1]. Every point is feasible |
| Lowest consumption | c >= 1e-4 of W | c >= 1e-2 of W, but at least 0.1% and at most 50% of LW (249-250) |
| Guard against negative wealth | next-period wealth growth clamped at 1e-4 inside the objective | not needed: every part of next-period wealth is non-negative; explicit floor phi_floor |
| fmincon algorithm | interior-point | interior-point (active-set and sqp as checks) |
| Tolerances | TolX 1e-8, TolCon 1e-8, TolFun 1e-8; OptimalityTolerance at its default 1e-6 | StepTolerance 1e-9, OptimalityTolerance 1e-8, FunctionTolerance 1e-10 |
| Iteration limits | defaults for interior-point: 1000 iterations, 3000 evaluations | 200 iterations, 500 evaluations |
| Finite differences | forward (default) | central |
| Exit flag | not checked; fmincon's answer is always used | used only if the exit flag is 0 or positive and it beats the sweep (286-297) |
| Global search | none. Each regime (rent, buy, stay) is solved locally and the best is kept | 21 x 21 sweep over (c, pi), three shrinking rounds, then fmincon from the best point |
| Warm start | rent and buy: last period's solution of the same sub-problem at the same node, kept even when that regime was not chosen. Stay: always (0.02, 0) | last period's policy at the same node |
| Shock quadrature | Gauss-Hermite, 5 nodes per shock, 125 joint nodes, Cholesky-correlated (`qnwnorm`) | the same (`grids.shock_grid`, gh_n = 5) |
| State grid | uniform on [0, 1], 25 x 24 | 16 x 16 x 10 or 20 x 20 x 12, with power, log-wealth and anchor options |
| Simulation shocks | drawn from the 125 quadrature nodes | continuous draws |

Two facts about fmincon matter for the table. FunctionTolerance (TolFun in
optimset) is used only by the active-set and trust-region-reflective
algorithms; interior-point and sqp ignore it
([MATLAB Answers](https://www.mathworks.com/matlabcentral/answers/285132-functiontolerance-parameter-has-no-effect-on-fmincon-is-it-a-bug),
[Tolerance Details](https://www.mathworks.com/help/optim/ug/tolerance-details.html)).
So MK's TolFun and our FunctionTolerance have no effect in either production
solve; ours applies only in the active-set robustness runs. And for
interior-point the default StepTolerance is 1e-10 and the default
MaxFunctionEvaluations is 3000, so both codes loosen the step tolerance and we
lower the evaluation cap.

## What is worth taking over

### 1. Give fmincon the objective in certainty-equivalent units

This is the one real difference, and it is shared ground: our CRRA problem is
the Epstein-Zin problem with EIS = 1/gamma, so MK's units are available to us
at no cost.

MK's objective is homogeneous of degree 1 in wealth. It is in the same units
as consumption, at every node. Ours is V_tilde in utility units, which with
gamma = 5 behaves like CE^-4. Across the nodes of one period it spans about 25
orders of magnitude (`docs/SOLVER_BOUNDS.md`, section 6), and one scale per
period, the median, cannot make it well scaled everywhere. Where the objective
is tiny or huge relative to the scale, fmincon's tolerances are loose or tight
in effect. The evidence that this costs accuracy:

1. At the production calibration, interior-point and active-set, both after
   the sweep, differed by up to 0.10 in the mean equity share, with neither
   reaching the higher value everywhere (`CALIBRATION.md`, Numerics).
2. Interior-point and active-set differ by up to 0.005 in the equity share at
   nodes where the share hardly matters (`docs/SOLVER_BOUNDS.md`, section 6).
3. At step 2, interior-point without the sweep reached a lower value than
   active-set with the sweep at 88% of node-ages, by at most 4.6e-4 relative
   (`HANDOFF.md`, 12 October). The large policy gaps there came from the
   missing sweep, but small shortfalls at most nodes are what loose effective
   tolerances produce.

The change is a monotone transform of the objective, so the maximiser is the
same and the sweep (which only compares values) is untouched. Only what fmincon
sees changes. In stage 3 of `bellman_step_lna.m`, with `maxval` the best value
from the seed and sweep:

```matlab
% Local solve in certainty-equivalent units, relative to the seed: the
% objective is -1 at the seed at every node, whatever the level of V.
rhs = @(x) bellman_rhs(x(1), x(2), LW_W, Rf_at, R_S_at, A_next_W, H_next_W, ...
                       Y_next_W, w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);
obj_cpi = @(x) -(rhs(x) / maxval) ^ inv_omg;
[x_try, ~, exitflag] = fmincon(obj_cpi, x0, [], [], [], [], lb2, ub2, [], opts_opt);
V_try = rhs(x_try);          % back in utility units, exactly
```

rhs and maxval have the same sign (that of 1 - gamma), so the ratio is
positive, and x -> x^(1/(1-gamma)) makes the transform increasing in rhs for
gamma above or below 1. `obj_scale` is then no longer needed.

Checked on a one-node toy in Python (not our model): utility of c times
liquid resources 0.3 plus a discounted continuation in the saving, c on a fine
grid over (0, 1), seed at c = 0.1. For gamma 5, 10 and 0.5 the transform has
the same maximiser as rhs (c = 0.523, 0.522, 0.538), equals -1 at the seed, and
is strictly increasing in rhs. For gamma 5, rhs runs from -3.1e25 to -814 over
the c range; the transformed objective runs from -4.4 to -1e-5.

A second gain. As consumption goes to zero, V_tilde goes to minus infinity, but
the CE goes to zero and stays smooth. The reason given for `c_floor_frac` in
`docs/SOLVER_BOUNDS.md` (section 1, "Why it is there") is that the search must
be kept away from minus infinity. In CE units that reason goes away, and the
bound could be set as low as MK's 1e-4 of W without numerical trouble. This
does not decide item 1 of `TODO.md`: there the bound binds because the
household wants to consume almost nothing with a floor of 1e-6, which is
economics. It only means the decision on the bound can be made on economic
grounds.

How to check it, in order:

1. `run_tests(solve=false)`.
2. Step 7 and step 11 at standard numerics, both tenures, old and new
   objective: largest node-by-node gap in V, c and pi by age; the simulated
   means of the dashboard; the share of fmincon exit flags 0 and negative.
3. `ladder.robustness(7)`: the interior-point against active-set gap in mean pi
   should shrink, and the solve time should not rise.
4. The full `run_tests`.

### 2. The evaluation cap of fmincon

With central differences on two variables, each fmincon iteration costs at
least five objective evaluations, so our cap of 500 evaluations stops a run at
about 100 iterations, before the cap of 200 iterations. A run stopped at the
cap (exit flag 0) is accepted if it beats the sweep. MK uses the
interior-point defaults, 1000 iterations and 3000 evaluations. How often our
cap binds is not measured. Count the exit flags per period (cheap; it can go
into `model.checks`) before changing anything. If flag 0 is common, raise
MaxFunctionEvaluations to about 1000, or try the CE objective first, which
should need fewer iterations.

### 3. Ideas for later, if housing becomes a choice

TODO.md item 1 lists equity release and downsizing (Yao and Zhang 2005), which
would make housing a choice. MK's code then has three useful patterns:

1. The renter's house size is not searched. The Cobb-Douglas first-order
   condition gives it from consumption, q = c theta / ((1 - theta) l), which
   removes one choice variable.
2. Each discrete option (rent, buy, stay) is solved as its own continuous
   problem and the best value is kept. This is a cheap multi-start.
3. Each option keeps its own warm start from last period, even where it was
   not chosen, so a switch of regime does not spoil the next start.

## Where we already match or do better

1. Same quadrature: 5 Gauss-Hermite nodes per shock, 125 joint nodes,
   Cholesky-correlated, in both codes.
2. Same interpolated object: a CE-type value per unit of wealth, linear, flat
   beyond the grid.
3. Our box parametrisation makes every point feasible. MK needs linear
   constraints with a TolCon margin to keep s non-negative.
4. We need no clamp on wealth growth. MK's clamp at 1e-4 sits inside the
   objective and makes it flat where the household would be wiped out, so
   fmincon sees zero gradient there.
5. Our global sweep protects against local peaks; MK has no protection within
   a regime. Without the sweep, our solve lands on the wrong peak at about 8%
   of retirement nodes (README).
6. We check the exit flag and keep fmincon's answer only if it beats the
   sweep. MK uses whatever fmincon returns.
7. We build the interpolant once per period. MK's `interp2` builds it again at
   every objective evaluation, which is slower but gives the same numbers.
8. MK's stay problem always starts from (0.02, 0); ours always starts from the
   warm start.

MK's uniform grid on L/W has the gap our grid study found. Between L/W = 0
(infinite wealth) and its first node, L/W = 1/24 (total wealth of 24 times
income), there is nothing. Our 16 x 16 grid has the same gap between 24 and
4,999 times income (`TODO.md`, item 1). MK's model may suffer less from it,
because its EIS of 0.1 smooths consumption and an owner can always sell, so no
housing cost is committed. It is still the same weakness.

## Small points in the MK code, for the coauthor

1. `opt_rent_buy.m`, lines 31 and 68, refer to `initital_guess_rent` and
   `initital_guess_buy`, which do not exist. The branch can never run (it needs
   `lb > x` with `lb = -Inf`), so it is harmless.
2. TolFun has no effect with interior-point.
3. In `main_jmp.m`, lines 350-358, both branches of the stay warm start set the
   same fixed value, so the stay problem is never warm-started.
4. Exit flags are not checked, so a failed solve (negative flag) can be stored
   as the policy.
5. The wealth-growth clamp at 1e-4 (see 4 above) gives fmincon a flat
   objective in the region it most needs to avoid.
