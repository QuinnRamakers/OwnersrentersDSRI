# The retirement-transition kink in pi(age)

Status: **working hypothesis, not established.** The mechanism below is
consistent with everything measured so far, but the central claim -- that risk
aversion is what makes the kink visible in our figures and invisible in CGM's --
rests on a comparison between two models that differ in more than risk aversion.
Read section "What is not settled" before relying on this.

Tested on ablation rung 0 (the CGM core) only. Rungs 2-6 have not been checked.

## The observation

Mean pi(age) reverses direction twice around retirement instead of turning once.
At gamma = 5, rung 0:

    age      64      65      66      67      68
    pi    0.8297  0.8220  0.8241  0.8099  0.8100
                          up      down     up

The largest reversal is -0.0142, about 1.7% of the level.

## The mechanism (hypothesis)

Two discontinuities land one year apart, and they push pi in opposite
directions.

At age 66, the last working year, all remaining income risk disappears:
`config.income_profile` sets `sigma_l_log(t_ret-1:end) = 0`, because retirement
income is a fixed multiple of realised age-66 income. Human capital turns from a
risky asset into a bond in one step, which pushes pi up.

At age 67, income falls by the replacement rate (a 32% drop). The state is
lambda = Y/W, measured in current income, so every household's position in the
state space jumps at the same instant: PDV of future income measured in years of
current income rises 41.8%, even though in levels it falls smoothly. That pushes
pi down.

Separating or merging the two removes the zigzag; it is their adjacency that
produces it. Sign flips in ages 62-72:

    both one year apart (as shipped)            3 flips, reversal -0.0147
    risk step moved onto the income drop        1 flip,  reversal -0.0090
    risk step moved to age 61                   1 flip,  reversal -0.0153
    income drop removed (replacement = 1)       reversal -0.0008

## The specification is faithful to CGM

Checked against the paper, not inferred. CGM section 1.1.1: the investor "works
the first K" periods. Equation (2) holds for t <= K, so K is a working year and
carries a permanent shock. Equation (3) makes v_it a random walk, and equation
(5) sets retirement income to a function of v_iK. The shock u_iK is realised at
K, so once the household observes its period-K income its whole remaining income
stream is known -- income risk vanishes at the last working year, one period
before the first pension payment.

That is what `sigma_l_log(t_ret-1) = 0` implements. The alternative (keeping the
shock on the last step) would make the replacement rate itself stochastic, which
neither specification intends.

## Why it is visible here and not in CGM Figure 3C (the unproven part)

At CGM's own risk aversion the same mechanism is far smaller:

    gamma = 5     reversal at 67   -0.0142   (1.73% of level)
    gamma = 10    reversal at 67   -0.0006   (0.17% of level)

At gamma = 10 the retirement dip is smaller than ordinary year-to-year variation
elsewhere in the same age window, so it would not be visible at the resolution of
a published figure.

## What is not settled

- Risk aversion is not the only difference. Our gamma = 10 run does not
  reproduce CGM Figure 3C's timing or level: households leave the pi = 1 corner
  around age 28 rather than 38, the trough sits at 58-60 rather than 65, and its
  level is 0.375 rather than 0.49. Attributing the difference in visibility to
  gamma alone is therefore not airtight.
- The model has no transitory income shock and cannot take one without a new
  state variable (see the CGM fidelity notes). A transitory shock changes
  precautionary saving and how long households stay cornered, so it could affect
  the size of the kink independently of gamma.
- Only rung 0 has been tested. Whether the kink in rungs 2-6 is this same
  mechanism, or something the DC annuity adds on top, is unknown.
- The magnitude is small (1.7% of the level at gamma = 5). Nothing here has been
  shown to affect welfare or any reported number; it is a shape artefact in
  pi(age).

## What would settle it

Run the same decomposition on rungs 2-6 and check the reversal scales with
gamma there too. If a transitory shock is ever added, repeat at gamma = 10 with
it on, which is the only configuration that is genuinely comparable to CGM. Note
that adding a transitory shock also requires fixing the retirement rule: CGM key
retirement income off the permanent component only, while this model would pass
a one-off transitory blip into the pension for life.

Reproduce with `diagnostics/plot_gamma_transition.m`; figure in
`diagnostics/fig_gamma_transition.png`.
