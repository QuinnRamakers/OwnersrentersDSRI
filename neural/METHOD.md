# The neural-network policy: a formal description

What was run for the step-18 networks on branch `work-2026-11-26`. The code is
`neural/src/model.jl` (the simulated year and lifetime utility),
`neural/src/policy.jl` (the network and its training) and
`neural/scripts/train_rung.jl` (the runs). README.md in this folder says how
to run it.

## 1. The household problem as the network sees it

Years t = 1, ..., T with T = 76 (ages 25 to 100); retirement at t_R = 43
(age 67). The state at the start of year t is

    s_t = (X_t, A_t, H_t, Y_t, q_t, b_t, Cbar)

with liquid wealth X, DC pot A, house value (owners) or rent index (renters)
H, gross income Y, q = H_1 / H_t (owners), the bankrupt flag b_t in {0, 1},
and Cbar the consumption fixed at bankruptcy. Every household starts from the
same state, that of `simulate.paths_lna`:

    s_1 = (b0 Y_1, 0, h Y_1, Y_1, 1, 0, 0),   b0 = 0.079,  h = 4.52.

Liquid resources in year t:

    working:  L_t = X_t + (1 - kappa_t)(1 - tau) Y_t             - k_t H_t
    retired:  L_t = X_t + (1 - tau)(Y_t + A_t / a_t)              - k_t H_t

with k_t the housing cost per unit of H (alpha for renters; (theta + m_t) q_t
for owners, maintenance and the annuity mortgage both on the purchase price)
and a_t the annuity price.

The floor is F_t = phi_t Y_t with phi_t = c_min / Ybar_t, c_min = EUR 5,000
and Ybar_t the owners' median income at t. A solvent household (b_t = 0) with
L_t < F_t goes bankrupt: b_s = 1 and C_s = Cbar = F_t for all s >= t, and X,
A and H are zero from t + 1.

A solvent household chooses (s_t, pi_t) in (0, 1)^2:

    C_t = F_t + s_t (L_t - F_t),     pi_t = stock share of the saving L_t - C_t,

and s_T = 1 (no bequest motive at step 18). Liquid wealth next year is

    X_{t+1} = [(1 - pi_t) Rf + pi_t R_S,t+1] (L_t - C_t),

both returns after the box-3 tax. A, H, Y and q move as in `simulate.paths_lna`:
the pot earns the glide-path fund's return with contributions while working
and annuity payments out in retirement; H_{t+1} = R_H,t+1 H_t;
Y_{t+1} = Y_t exp(g_t + sigma_Y eps_Y,t+1) while working, the replacement
rate times Y at t_R, constant after; q_{t+1} = q_t / R_H,t+1. The shocks
eps_t = (eps_Y, eps_S, eps_H) are iid N(0, Sigma), Sigma the calibrated
correlation matrix.

The reward in year t, in units of entry income Y_1, with u(c) = c^(1-gamma) / (1-gamma), gamma = 5:

    r_t = u(C_t / Y_1)              solvent,
    r_t = u(F_t / Y_1) D_t          in the year of bankruptcy,
    r_t = 0                         after,

where D_t = 1 + beta p_t D_{t+1}, D_T = 1, is the survival-weighted
discounted horizon (the solver's value of the bankrupt). A household's
lifetime utility along a shock path eps = (eps_2, ..., eps_T) is

    U(theta; eps) = sum_{t=1}^{T} beta^(t-1) S_t r_t,     S_t = p_1 ... p_{t-1}.

Mortality enters only through the survival weights S_t; deaths are not drawn.

## 2. The network

The input at year t (seven numbers for one tenure, eight for the joint
network):

    x_t = ( (t - 1)/(T - 1),  u1,  u2,  u3,  q,  max(t_R - t, 0)/(t_R - 1),  1[t >= t_R],  [1[owner]] )

with W = X + A + H + Y, u1 = Y/W, u2 = (A + H)/(W - Y), u3 = A/(A + H), the
solver's cube; q for owners and 1 for renters. The floor and the bankrupt
flag are not inputs. The floor relative to wealth is F_t / W = phi_t u1, a
function of age and u1.

The network f_theta maps x_t to two numbers:

    h1  = tanh(W1 x_t + b1),       W1: 64 x 7
    h2  = tanh(W2 h1 + b2),        W2: 64 x 64
    o   = W3 h2 + b3,              W3: 2 x 64
    s_t = sigmoid(o_1),  pi_t = sigmoid(o_2).

theta = (W1, b1, W2, b2, W3, b3) has 4,802 parameters (4,866 joint). One
network covers all ages; age is an input. The weights start Glorot-uniform,
the hidden biases at zero and the output biases at (logit 0.5, 0) = (0, 0),
so the household starts by consuming about half of its resources above the
floor and holding about half its saving in stocks.

## 3. The objective

    J(theta) = E_eps[ U(theta; eps) ],   theta* = argmax J(theta),

from the one entry state s_1, over the states the policy itself reaches. This
is the lifetime-reward method of Maliar, Maliar and Winant (2021, eq. 6):
the policy is optimised directly on expected lifetime utility. No value
function, Bellman equation or Euler equation is used.

In training J is multiplied by w = 1/|EU_ref|, with EU_ref = u(ce_VF) D_1 and
ce_VF the quick-grid value function's certainty equivalent at entry, so the
objective is about -1 at the grid's value. The scale does not change the
maximiser. The joint network maximises w_R J_R + w_O J_O with the owner
indicator as an input; the weights make each tenure about -1 at its own grid
value, so both count alike.

## 4. Estimator and optimiser

Each step k = 1, ..., K:

1. Draw N = 8,192 new shock paths eps^(i), 75 years of three correlated
   normals each (for the joint network, N per tenure). There is no fixed
   training sample.
2. Simulate the N lives from s_1 under f_theta, in Float32.
3. Jhat(theta) = w (1/N) sum_i U(theta; eps^(i)).
4. Take the gradient of Jhat by reverse-mode automatic differentiation
   (Zygote) through all 76 years of the simulation: backpropagation through
   time, the pathwise (reparameterisation) gradient.
5. Take an Adam step on -Jhat: learning rate 3e-3 until step 2K/3, then 3e-4;
   beta1 = 0.9, beta2 = 0.999, epsilon = 1e-8. No weight decay, gradient
   clipping, other regularisation or early stopping.

K is 1,000 or 3,000. In training, utility bounds consumption below at
10^(-30/(gamma-1)) = 3.2e-8 of entry income, against Float32 overflow; it
never binds above the floor. Evaluation has no bound and runs in Float64.
Every number of the model (calibration, phi_t, D_t, annuity prices, the
Cholesky factor of Sigma) is exported from MATLAB after `config.derive`;
Julia derives none.

What the gradient does not see. The bankruptcy test is a jump: the indicator
1[L_t < F_t] has derivative zero almost everywhere. The gradient therefore
contains the effect of theta on utility within the solvent branch and within
the bankrupt branch, but nothing for the change in the probability of
crossing into bankruptcy. A pathwise gradient of a discontinuous objective is
biased in this way. The network learns to keep a buffer only through the
smooth part: at gamma 5, consumption just above the floor is already very
costly.

## 5. Evaluation

Test draws not used in training: the draws of `simulate.paths_lna`'s
generator, 20,000 households (seed 202) or 100,000 (seed 303). The network
and the grid policy are simulated on the same draws, in Float64. Welfare is

    CE = ((1 - gamma) Ubar / D_1)^(1/(1-gamma)),

Ubar the mean lifetime utility. The difference CE_net - CE_grid has the
delta-method standard error of a paired difference: sd(h)/sqrt(N), with
h_i = CE_net / ((1-gamma) Ubar_net) U_net,i - CE_grid / ((1-gamma) Ubar_grid) U_grid,i.

Two checks in MATLAB. With the network as the policy, MATLAB's simulator and
a separate utility sum (`neural.sim_utility`) reproduce Julia's CE to four
digits. The solver values the network as a fixed policy (policy evaluation,
`neural.evaluate_policy`) on grids of increasing size.

## 6. The step-18 runs

All on the model exported from the quick-grid solve (the same calibration as
the standard and production grids; the annuity prices differ by 1.6e-4).

| run | inputs | households a step | steps | learning rate | device |
|---|---|---|---|---|---|
| renters, owners, seed 1 | 7 | 8,192 | 1,000 | 3e-3, then 3e-4 | CPU |
| renters, owners, seeds 2 and 3 | 7 | 8,192 | 1,000 | 3e-3, then 3e-4 | GPU, 9-12 minutes each |
| renters, owners | 7 | 8,192 | 3,000 | 3e-3, then 3e-4 | CPU, 88 minutes, two side by side |
| joint | 8 | 8,192 a tenure | 1,000 | 3e-3, then 3e-4 | GPU |
| joint | 8 | 8,192 a tenure | 3,000 | 3e-3, then 3e-4 | GPU, 63 minutes |

## 7. Limits

1. The network is trained only on the states its own households reach from
   one entry state. Off that support nothing disciplines it: consumption
   that falls with wealth (renters at 45) and arbitrary owner equity shares
   (0.7 against 0.01 at the same welfare).
2. The gradient does not see the bankruptcy jump (section 4).
3. Nothing certifies an optimum. The method maximises J over one function
   class with a fixed budget of steps. Consumption drops at 67 and jumps at
   55 (owners), which an optimal policy with liquid wealth would smooth, so
   it is not the optimum.
4. The objective is dominated by its tail. At gamma 5 the owners' mean
   utility is set by about 0.1-0.3% of households, a few to a few dozen of
   the 8,192 in a step, so the owner gradient is noisy.
5. Training noise: three seeds at 1,000 steps differ by about 0.3% of
   consumption for renters against the production grid; 3,000 against 1,000
   steps moves the result by about 2%.
