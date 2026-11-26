# Prompt: policies from a neural network trained on simulated lifetime utility

Saved on 26 November 2026 on branch `work-2026-11-26`, cut from main at
8636a0d. Not started. An experimental branch: nothing here goes to main
without Quinn.

## To start

Open Claude Code in the repository checkout on branch `work-2026-11-26` and
paste:

"Read docs/prompts/neural_policy.md and follow it. Start with the
session-start skill. Settle the decisions with me before any code. Stop for
me at the end of each part."

## The idea

The method Quinn's coauthor described on 26 November 2026. In the literature
it is the lifetime-reward objective of Maliar, Maliar and Winant (2021),
Section 2.2, equation 6.

1. One network maps age and the normalised state (u1, u2, u3, q) to the
   choices: `c_frac`, consumption as a share of liquid resources
   (C = c_frac * LW, as in the simulator), and `pi`, the liquid equity share.
   Under `dc_choice` it also gives the fund's stock and REIT shares. The
   output layer enforces the bounds (a sigmoid), so every output is feasible.
2. Every household starts from the entry state that `utility.welfare_anchor`
   reads: liquid wealth b0 * Y0, the house or rent index h_mult * Y0 and no
   DC pot, so u1 = 1/(1 + h_mult + b0), u2 = h_mult/(h_mult + b0), u3 = 0,
   q = 1.
3. Only the innovations are drawn: standard normals for income, stocks, the
   house or rent index and the REIT, one per household and year, correlated
   as in `simulate.paths_lna`. The levels follow from the entry state, the
   draws and the network's choices.
4. Given the network and a draw, the path is fixed, so realised lifetime
   utility is computed exactly: the sum of beta^t S_t u(C_t) plus the bequest
   term, with the survival probabilities S_t as weights, not drawn deaths.
5. Training maximises the mean over households by gradient ascent (Adam).
   The gradient comes from automatic differentiation through all 76 years.
   Each step uses fresh draws. A fixed test set of draws, never used in
   training, measures the result.

The model is homothetic, V(W, u) = W^(1-gamma) V_tilde(u), and the house, the
floor, the contribution and the entry buffer are all tied to income. So the
network sees no euro amount. Y0 only sets the units: doubling it multiplies
lifetime utility by 2^(1-gamma) and changes no choice.

## What it is for

A second solution method for the same model, set against the grid solver on
the same simulator. Both methods give a feasible policy, so the simulated
value of each at entry is a lower bound on the best attainable, up to
sampling error. On the same test draws, the higher one is closer to the
optimum. The comparison does not use the value function, so the gap between
the value function and simulated welfare does not enter it.

It does not replace the grid solver until it matches it on rungs where the
grid converges. Where the grid does not converge (production; renters when
young), it is a check on the grid solution, and possibly a better one.

## What is known (26 November 2026)

1. `simulate.paths_lna` draws independent normals after `rng(seed)`,
   correlates them with a Cholesky factor in the order income, stock, house,
   REIT, and builds Y, X, A, H and W from the entry state. It reads the
   policies off the grid at (u1, u2, u3, q).
2. The repository has no function for simulated lifetime utility. Welfare is
   read off the value function at the entry state (`utility.welfare_anchor`,
   `ce_entry` in `model.checks`).
3. In October, under the calibration of that time, the grid converged on the
   CGM rungs (steps 1-6), on the DC rungs 9-12 with power-3 placement at
   48x48, for owners at step 7b at 16x16 and at step 13 at 24x24. It did not
   converge for owners at step 16, and renters did not converge when young at
   any step with housing.
4. MATLAB R2025b on the PC has the Optimization and Parallel Computing
   toolboxes only, and `install_matlab.sh` installs the same two on the DSRI.
   There is no Deep Learning Toolbox, and no Python on the PC. Whether the pod
   can have a GPU is not checked.
5. Production makes default a choice (`default_choice`, step 24): a household
   defaults where the value of continuing is no more than the default value.
   The simulator reads that comparison from the solver's `sol.V_cont`. A
   policy network has no value function to compare with.
6. The paper's own example (one agent, consumption and saving, a borrowing
   constraint) trained with Adam at a learning rate of 0.001, 64 draws a step
   and 50,000 steps. This model has 76 years, up to five inputs and two to
   four choices, so expect many more draws a step.

## Decisions for Quinn, before code

1. The tool.
   (a) MATLAB with the Deep Learning Toolbox (`dlarray`, `dlgradient`,
   `adamupdate`). One implementation of the model: training uses the same
   `config.derive`, income profile, annuity prices and budget rules as the
   grid solver. It needs the toolbox licensed on the PC and added to
   `PRODUCTS` in `install_matlab.sh` for the DSRI.
   (b) Python with PyTorch or JAX. Faster automatic differentiation, GPUs,
   and possibly the coauthor's code as a start. But the budget, taxes,
   annuity, mortgage and floor would exist twice and have to be kept
   identical, and every parameter exported from MATLAB.
   Recommended: (a), unless the coauthor's code is to be the starting point.
2. The entry state.
   (a) Fixed at the welfare anchor (the coauthor's method, the paper's
   equation 6). Right for welfare at 25.
   (b) The buffer drawn over a range (the paper's equation 7). The policy is
   pinned down on more states, and welfare at other buffers needs no
   retraining.
   Recommended: (a) first.
3. The inputs besides (u1, u2, u3, q): age scaled to [0, 1], and possibly
   years to retirement and a retired indicator, so that one network can turn
   sharply at 67. Recommended: try age alone and age with the retirement
   inputs at the first rung, and keep what does better on the test set.
4. Default as a choice (production only).
   (a) A further output, the probability of default, trained with a smoothed
   rule and evaluated with the hard rule.
   (b) A value network next to the policy, so the values can be compared as
   in the solver.
   (c) Stop at step 23, the forced rule, for now.
   Recommended: (c) until part 3 is done, then (a).

## Part 0: setup

1. Install the chosen tool on the PC and the DSRI. For (a), check
   `license('test', 'Neural_Network_Toolbox')` (the Deep Learning Toolbox's
   licence name) in both places.
2. A smoke test: a small network fitted to a toy problem with `dlgradient`,
   on the PC and on the pod.

## Part 1: a differentiable simulator, no training

1. A new package `+neural`. Nothing outside it changes. Its options are a
   struct of its own, not primitives in `config.params`, so
   `ladder.same_calibration` and the ladder do not see them.
2. `neural.draw_shocks(p, N, seed)` returns the correlated draws in the same
   order as `simulate.paths_lna`, so the same seed gives the same draws.
3. `neural.simulate(p, profile, ann_price, policy, shocks)` runs the
   households forward. One year's budget, taxes, contribution, housing cost,
   returns, annuity and floor are written once, for ordinary arrays and for
   `dlarray`. `policy` is a function handle: the network, or the grid
   solver's policy read off the cube as `simulate.paths_lna` reads it.
4. `neural.lifetime_utility(p, sim)` returns each household's realised
   discounted utility, with survival weights and the bequest term, and the
   certainty equivalent of their mean.
5. Stop and report: the equality tests below; the share of mean utility that
   comes from the worst 1% of paths at steps 6, 12, 18 and 23; and the gap
   between the grid policy's simulated value and its value function at
   entry, with the Monte Carlo standard error.

## Part 2: training at the first rung

Step 6 (`corr_SL`): no housing and no DC pension, so the inputs are age and
u1.

1. A network of two hidden layers of 64 with sigmoid outputs. Adam, fresh
   draws each step, a fixed test set of 20,000 households.
2. Report: the training curve; the test-set certainty equivalent of the
   network and of the grid policy (solved at standard numerics), with
   standard errors; consumption, the equity share and wealth by age along the
   simulated paths, one line per method; the time per training step and in
   total, as a table.
3. The network passes when its test-set certainty equivalent is above the
   grid policy's or within two standard errors of it, and the age profiles
   agree. Quinn decides.
4. Stop and report.

## Part 3: up the ladder

In this order, each with the report of part 2, one step and tenure at a time,
stopping after each:

1. Step 12 (`aow`): the DC pot, the glide and the annuity, no housing.
2. Step 7b (`annuity`), then step 13 (`pension`): housing and the mortgage
   state q, owners and renters.
3. Step 18 (`floor`): the absorbing floor. Bankruptcy is a jump in the path
   that the gradient does not see. Smooth the switch during training (a
   sigmoid in resources minus the floor, its width shrunk to zero over
   training) and evaluate with the hard rule.
4. Step 23 (`bequest`): the bequest motive, the last step before default as a
   choice.

## Part 4: production and strategies

After decision 4.

1. Step 24 with the chosen treatment of default.
2. Fund strategies: one network per strategy, or the strategy's knots as
   inputs so that one network covers a menu. Decide from the training times
   of part 3.

## Checks that must pass

1. `run_tests(solve=false)` and the full `run_tests`, unchanged: nothing
   outside `+neural` and its tests changes.
2. New tests in `tests/neural_tests.m`, apart from `run_tests`:
   1. with the grid policy, `neural.simulate` reproduces `simulate.paths_lna`
      for C, X, A, H and Y at every age to 1e-12 relative, on the quick grid,
      at steps 6, 12, 18 and 23, both tenures;
   2. the gradient from `dlgradient` matches central finite differences on a
      small network to 1e-6 relative;
   3. doubling Y0 leaves every choice unchanged and multiplies lifetime
      utility by 2^(1-gamma), to 1e-12;
   4. every output is inside its bounds at random inputs, including inputs
      far outside the states seen in training;
   5. the same seed gives the same training run.
3. Every comparison of the two methods uses the same simulator and the same
   test draws.

## Limits

1. Report behaviour, not welfare levels, wherever the grid does not converge
   (CLAUDE.md). Where it does, the two methods' certainty equivalents can be
   compared.
2. The network is pinned down only on states the simulated households reach.
   Plot its policies along simulated paths, not over the grid.
3. Train from several seeds before reading a result: the objective is not
   concave in the network's weights.
4. At gamma = 5 utility near the floor is very large in magnitude. In August,
   before the absorbing floor, 58-68% of simulated E[U] came from the worst
   1% of paths. Large batches and the fixed test set help; part 1 measures
   the share now.
5. Gradients through 76 years can explode or vanish. Scaled inputs and
   gradient clipping are the usual remedies.
6. Keep smoke runs small: the fewest households and steps that test the
   code. Long training runs go on the DSRI and are logged like any other run.

## Reference

Maliar, L., Maliar, S. and Winant, P. (2021). Deep learning for solving
dynamic economic models. Journal of Monetary Economics 122, 76-101. The
lifetime-reward method is Section 2.2; its consumption-saving application is
Sections 4.2-4.3.
