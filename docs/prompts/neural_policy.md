# Prompt: policies from a neural network trained on simulated lifetime utility

Saved on 26 November 2026 on branch `work-2026-11-26`, cut from main at
8636a0d; training in Julia since 27 November 2026 (Quinn). Not started. An
experimental branch: nothing here goes to main without Quinn.

## To start

Open Claude Code in the repository checkout on branch `work-2026-11-26` and
paste:

"Read docs/prompts/neural_policy.md and follow it. Start with the
session-start skill. The decisions are taken; begin with part 0. Stop for me
at the end of each part."

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
the same draws. Both methods give a feasible policy, so the simulated value
of each at entry is a lower bound on the best attainable, up to sampling
error. On the same test draws, the higher one is closer to the optimum. The
comparison does not use the value function, so the gap between the value
function and simulated welfare does not enter it.

It does not replace the grid solver until it matches it on rungs where the
grid converges. Where the grid does not converge (production; renters when
young), it is a check on the grid solution, and possibly a better one.

## How the work is split

MATLAB stays the model's definition. Julia trains the network.

1. MATLAB derives every number (`config.derive`, the income profile, the
   annuity prices, the floor shares, survival) and exports it to a `.mat`
   file. Julia reads that file and derives nothing from primitives.
2. One year of the model (budget, taxes, contribution, housing cost,
   mortgage, returns, DC annuity, floor, bequest) is written a second time in
   Julia, for training. A replay test ties it to `simulate.paths_lna`
   (part 1).
3. The grid policy is simulated in MATLAB, by `simulate.paths_lna`; the
   network in Julia. Both on the same test draws, and both paths go through
   the same lifetime-utility function in Julia.

## What is known (27 November 2026)

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
4. The PC has Julia 1.11.2 with Flux, Zygote, Optimisers and ForwardDiff in
   the default environment, an NVIDIA GeForce RTX 2070 SUPER (8 GB, driver
   621.01) and 32 logical cores. CUDA.jl and MAT.jl are not installed. The
   DSRI image has no Julia.
5. Production makes default a choice (`default_choice`, step 24): a household
   defaults where the value of continuing is no more than the default value.
   The simulator reads that comparison from the solver's `sol.V_cont`. A
   policy network has no value function to compare with.
6. The paper's own example (one agent, consumption and saving, a borrowing
   constraint) trained with Adam at a learning rate of 0.001, 64 draws a step
   and 50,000 steps. This model has 76 years, up to five inputs and two to
   four choices, so expect many more draws a step.
7. Zygote cannot differentiate code that writes into an array in place. The
   Julia year has to return new arrays.
8. A GeForce card is fast in single precision and slow in double. Training
   runs in Float32 on the GPU; the replay test and the final evaluation run
   in Float64 on the CPU.

Found while running (27 November 2026):

9. A training step of the real model costs about 0.95 s on the GPU at
   16,384 households, alone. On the CPU it costs about 107 ms plus 0.08 ms a
   household (0.25 s at 2,048, about 0.75 s at 8,192), alone. The GPU's time
   is the launch of many small operations, not arithmetic, so it barely
   beats the CPU, and the CPU can run several trainings side by side.
10. Memory limits the PC through the Windows commit limit (about 70 GB),
    not RAM. Without a cap CUDA's memory pool grows past the 8 GB card into
    system memory, which Windows charges to the commit limit (one GPU job
    reached 19 GB in 25 minutes), and then any process that allocates dies
    (Julia out-of-memory, "OpenBLAS: malloc failed", ReadOnlyMemoryError in
    the compiler; MATLAB out of memory). Six step-1 runs were lost this way.
    With `JULIA_CUDA_HARD_MEMORY_LIMIT=6GiB` a GPU job holds about 10 GB of
    commit; a CPU job with `--heap-size-hint=2500M` about 3-4 GB
    (neural/README.md).
11. Seven CPU trainings of 8,192 households side by side take about 1.8 s a
    step each.

## Decisions

All taken by Quinn on 27 November 2026.

1. The tool: Julia, with Flux, Zygote and Optimisers, CUDA.jl for the GPU and
   MAT.jl to read MATLAB's exports.
2. The entry state: fixed at the welfare anchor, as the coauthor does (the
   paper's equation 6), so the result is welfare at 25 from that state.
   Drawing the buffer over a range (the paper's equation 7) is the way to pin
   the policy down on more states, or to read welfare at other buffers
   without retraining, if that is wanted later.
3. The inputs: (u1, u2, u3, q) and age scaled to [0, 1]. At the first rung,
   train two versions, age alone and age with years to retirement and a
   retired indicator (so that one network can turn sharply at 67), and keep
   the one that does better on the test set.
4. Default as a choice (production only): stop at step 23, the forced rule,
   until part 3 is done. Then add a further output, the probability of
   default, trained with a smoothed rule and evaluated with the hard rule. If
   that fails, the alternative is a value network next to the policy, so the
   values can be compared as in the solver.

## Layout

1. `neural/`: a Julia project with its own `Project.toml` and
   `Manifest.toml`, both committed, so the package versions are fixed. Code in
   `neural/src/`, tests in `neural/test/runtests.jl`. Run from the repository
   root: `julia --project=neural -e "using Pkg; Pkg.test()"`.
2. `+neural/`: the MATLAB side, exports only. Nothing else in MATLAB
   changes. Its options are a struct of its own, not primitives in
   `config.params`, so `ladder.same_calibration` and the ladder do not see
   them.
3. Exported `.mat` files and trained networks are gitignored, like every
   other result. Notes go in `.md` files.

## Part 0: setup

1. Create the `neural/` project with Flux, Zygote, Optimisers, CUDA, MAT,
   Statistics and Test.
2. Check that CUDA.jl finds the RTX 2070 SUPER (`CUDA.functional()`).
3. A smoke test: a small network fitted to a toy problem on the CPU and on
   the GPU, with Zygote's gradient checked against central finite
   differences.
4. Time one training step of a dummy 76-year loop with a two-layer network,
   at 1,024, 4,096 and 16,384 households, on the CPU and the GPU, as a table.
5. Stop and report.

## Part 1: the Julia year, no training

1. `neural.export_model(p, file)` (MATLAB) writes `p` after `config.derive`
   and everything `simulate.paths_lna` reads: the income profile, the annuity
   prices, `phi_path`, `D_abs`, survival, tax rates, return moments and the
   Cholesky factor.
2. `neural.draw_shocks(p, N, seed)` (MATLAB) makes the draws of
   `simulate.paths_lna` for the same seed, in the same order. Check first that
   `paths_lna` draws nothing else.
3. `neural.export_replay(...)` (MATLAB) runs `simulate.paths_lna` on a
   quick-grid solve and writes the draws, the choices it applied (`c_frac`,
   `pi`, the fund shares, the defaults) and the paths.
4. In Julia, one year as a function that returns new arrays: the same code
   for CPU and GPU arrays, in Float32 or Float64.
5. In Julia, lifetime utility from the paths of C and the bequests, with
   survival weights, and the certainty equivalent of the mean.
6. Stop and report: the tests below; the share of mean utility that comes
   from the worst 1% of paths at steps 1, 6, 12, 18 and 23; and the gap between
   the grid policy's simulated value and its value function at entry, with
   the Monte Carlo standard error.

## Verification at every rung

Asked by Quinn on 27 November 2026: verify the architecture and the
intermediate results from the CGM core on. At each rung, before the next:

1. Architecture: the outputs stay inside their bounds; the inputs are scaled
   to order one over the states the households reach; the training curve
   flattens; the result does not move when the network is made wider (64 to
   128) or deeper (two to three hidden layers), or when it is trained from
   another seed.
2. Against the grid: the test-set certainty equivalent of both methods, with
   standard errors; consumption, the liquid equity share and wealth by age,
   one line per method.
3. Intermediate quantities by age: the share of households at the floor or
   bankrupt, the mean and spread of the inputs the network sees, and the
   share of mean utility from the worst 1% of paths.
4. Each rung's report goes in the log before the next rung starts.

## Tenures: separate and joint networks

Asked by Quinn on 27 November 2026. At every rung where the tenures differ
(from step 7, housing):

1. Separate: one network per tenure, each trained on its own households.
2. Joint: one network with a tenure indicator as a further input, trained on
   owners and renters together. Each tenure's mean utility is divided by the
   absolute value of the grid policy's on the same test draws before the two
   are added, so both count equally whatever their levels.
3. Report both tenures' test-set certainty equivalents under each, against
   the grid. A flexible enough joint network should match the separate ones.

At steps 1-6 the two tenures are the same model (no housing, pooled income).
There the joint network must give the same choices for both values of the
indicator, which checks the joint set-up before housing makes them differ.

## Part 2: training at the first rung

Step 1 (`cgm`), the CGM core: gamma 10, no housing, no pension, no taxes, so
the state inputs are age and u1.

1. A network of two hidden layers of 64 with sigmoid outputs, in the two
   versions of decision 3. Adam, fresh draws each step (Julia's own random
   numbers, fixed seed), Float32 on the GPU.
2. A fixed test set of 20,000 households, drawn by `neural.draw_shocks` and
   exported, so the grid policy can be simulated on the same draws by
   `simulate.paths_lna`. Evaluation in Float64 on the CPU.
3. The checks of "Verification at every rung", and the time per training
   step and in total, as a table.
4. The network passes when its test-set certainty equivalent is above the
   grid policy's or within two standard errors of it, and the age profiles
   agree. Quinn decides.
5. Then steps 2-6 in order (gamma 5, retirement at 67, the DHS income, the
   market, the income-stock correlation), each with the same checks.

## Part 3: up the ladder

In this order, each with the checks of "Verification at every rung" and the
tenures separate and joint:

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

After part 3.

1. Step 24, with the probability of default as a further output
   (decision 4).
2. Fund strategies: one network per strategy, or the strategy's knots as
   inputs so that one network covers a menu. Decide from the training times
   of part 3.

## Checks that must pass

1. `run_tests(solve=false)` and the full `run_tests`, unchanged: nothing in
   MATLAB outside `+neural` changes.
2. MATLAB, in `tests/neural_tests.m`, apart from `run_tests`: the draws of
   `neural.draw_shocks` reproduce the Y, H and stock-return paths of
   `simulate.paths_lna` for the same seed, in every bit.
3. Julia, in `neural/test/runtests.jl`:
   1. replay: fed the exported draws and choices, the Julia year reproduces
      C, X, A, H, Y, LW and q at every age to 1e-12 of the larger of the
      value and entry income (Float64, CPU), on the quick grid, at steps 1,
      6, 12, 13, 18 and 23, both tenures where they differ. Measured against
      the value alone the largest gap was 1.1e-11 (27 November 2026): where
      liquid wealth is a few euros, LW - C cancels two numbers of the order
      of income, and the two languages' last-digit rounding is 1e-16 of
      income. A, H, Y and q agree to 3e-15 at every age;
   2. Zygote's gradient matches central finite differences on a small
      network to 1e-6 relative (Float64);
   3. doubling Y0 leaves every choice unchanged and multiplies lifetime
      utility by 2^(1-gamma), to 1e-12;
   4. every output is inside its bounds at random inputs, including inputs
      far outside the states seen in training;
   5. the CPU and the GPU give the same loss to 1e-5 relative (Float32);
   6. the same seed gives the same training run on the CPU.
4. Every comparison of the two methods uses the same test draws and the same
   lifetime-utility function.

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
6. When main is merged into this branch, or the model's year changes in
   MATLAB, rerun the replay test before training again. A failure means the
   Julia year is out of date.
7. Keep smoke runs small: the fewest households and steps that test the
   code. Long runs are logged like any other run, with the commit, the
   device and the wall time.

## Reference

Maliar, L., Maliar, S. and Winant, P. (2021). Deep learning for solving
dynamic economic models. Journal of Monetary Economics 122, 76-101. The
lifetime-reward method is Section 2.2; its consumption-saving application is
Sections 4.2-4.3.
