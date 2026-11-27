# neural: policies from a network trained on simulated lifetime utility

The plan is [docs/prompts/neural_policy.md](../docs/prompts/neural_policy.md).
Results are logged in [HANDOFF.md](../HANDOFF.md). This file describes the
code and how to run it.

## The method

One network maps age and the normalised state (u1 = Y/W, u2 = (A+H)/(W-Y),
u3 = A/(A+H), q) to the choices: the share of resources above the floor that
is consumed, and the liquid equity share, both through a sigmoid. Every
household starts from the welfare anchor's entry state. Only the
innovations are drawn. Given the network and a draw the whole life is
fixed, so lifetime utility is computed exactly on every path, with survival
probabilities as weights. Training maximises the mean over households by
Adam, with the gradient taken by Zygote through all 76 years and fresh
draws every step. This is the lifetime-reward method of Maliar, Maliar and
Winant (2021), equation 6.

## Who does what

1. MATLAB is the model's definition. `+neural/export_model.m` writes every
   number the year needs (after `config.derive`); Julia derives nothing.
2. `neural/src/model.jl` is the year of `simulate.paths_lna` written again
   for all households at once. It returns new arrays every year, so Zygote
   can differentiate it, and runs on CPU or GPU arrays in Float32 or
   Float64.
3. The replay test ties the two: fed MATLAB's draws and the choices the grid
   policy applied, the Julia year reproduces the panel.
4. The grid policy is simulated by MATLAB; the network by Julia; both on the
   same test draws, and both scored by the same lifetime-utility function
   (`lifetime` and `panel` in model.jl).

Not in the Julia year yet: default as a choice (step 24); `check_supported`
refuses it for training. The bequest motive (chi > 0, step 23) is in: a
solvent household gets beta (1 - p_t) chi u(bequest) each year, the bequest
being liquid wealth and the house net of the sale cost after a year of
returns, bounded below by 1e-12 of wealth, as in the solver. The last
year's bequest needs one more year of draws than MATLAB's panel has; it is
drawn in Julia (`draws_from_matlab`, seed 777), the same for every policy
scored on those draws. The check: on the fine grid at step 12 the grid
policy's simulated value is 0.63% above its value function without the
bequest and 0.65% with chi = 32.

## Files

| file | contents |
|---|---|
| `src/NeuralPolicy.jl` | the module |
| `src/model.jl` | `Model` (one exported calibration), the draws, the entry state, `year`, `lifetime`, `panel`, `certainty_equivalent`, `worst_share` |
| `src/policy.jl` | `Spec` (which inputs), `features`, `policy_net`, `choices`, `replay_choices`, `train`, `evaluate` |
| `src/toy.jl` | a 76-year toy problem for part 0: timings and gradient checks |
| `test/runtests.jl` | toy checks, the replay against MATLAB's panels, a gradient check through the model year, homotheticity, bounds, CPU against GPU |
| `scripts/part0_timing.jl` | the time of one training step by batch size, CPU and GPU |
| `scripts/part1_report.jl` | the grid policy's simulated value against its value function, by panel |
| `scripts/train_rung.jl` | training at one rung and the comparison with the grid policy |
| `../+neural/*.m` | MATLAB: `export_model`, `draw_shocks`, `export_replay`, `make_replays`, `make_testsets` |
| `../tests/neural_tests.m` | MATLAB: the draws equal those of `simulate.paths_lna` in every bit |

Exported panels, test sets and results go to `neural/data/`, which git
ignores.

## Running

From the repository root, in this order the first time:

1. MATLAB: `matlab -batch "addpath tests; neural_tests; neural.make_replays()"`
   (about 12 minutes on the PC, mostly the step-23 owner solve).
2. Julia tests: `julia --project=neural -e "using Pkg; Pkg.test()"`
   (about 2 minutes after the first precompile).
3. `julia --project=neural neural/scripts/part1_report.jl`.
4. A rung: `matlab -batch "neural.make_testsets({1}, numerics={'standard','fine'})"`,
   then `julia --project=neural neural/scripts/train_rung.jl step1 testset_1_nohousing_fine.mat variants=age,ret`.
   A variant is `age` or `ret` with suffixes (`_w128`, `_d3`, `_s2`,
   `_n8192`, `_k2000`, `_lr3e-3`, `_joint`; see the script's header);
   `device=cpu` trains on the CPU.
5. Many trainings: a job list in `neural/jobs/` (one line per training, the
   arguments of `train_rung.jl`) and
   `OPENBLAS_NUM_THREADS=3 bash neural/scripts/queue.sh neural/jobs/<name>.jobs 7`.
   Logs go to `neural/data/logs/`, results to `neural/data/results_<tag>.mat`.
6. Figures: `matlab -batch "neural.plot_rung({'<tag>', ...}, title='...')"`,
   PNGs in `neural/data/figures/`.

Where to train: on this PC a step at 16,384 households takes about 0.95 s
on the GPU and a step at 8,192 about 0.75 s on the CPU, alone. Two GPU
trainings at a time fit in its 8 GB; more spill into system memory and die.
The CPU runs seven side by side at about 1.8 s a step each.

The first `using NeuralPolicy` in a new environment precompiles Flux and
CUDA (about 3 minutes). CUDA.jl downloads its own runtime; it needs only the
NVIDIA driver. Flux warns that cuDNN is missing; the dense layers here do
not use it.

## Numerical choices

1. Training runs in Float32 on the GPU, evaluation in Float64 on the CPU.
2. Utility is of consumption in units of entry income, so that gamma = 10
   does not underflow in Float32; the model is homothetic, so this changes
   no choice. Consumption is bounded below by 1e-3 of entry income inside
   the training utility only (`guard`), so that Float32 cannot overflow:
   by default 10^(-30/(gamma-1)) of entry income, 4.6e-4 at gamma 10 and
   3e-8 at gamma 5 (below the yearly top-up, so it never binds there). The
   step-1 runs of 27 November used 1e-3.
   Evaluation has no guard.
3. Consumption is the floor plus a share of the resources above it, the
   search domain of the grid solver. In the last year without a bequest
   motive everything is consumed, as in the solver.
4. The learning rate falls by ten after two thirds of the steps.
