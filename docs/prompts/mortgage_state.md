# Prompt: the mortgage as a state variable

Saved on 15 Oct 2026 against e87d7d2. Not started. To start, open a Claude
Code session on this repo and point it to this file.

## Goal

Replace the proportional mortgage approximation with a real annuity on the
purchase price. To do this, carry the ratio of the purchase price to the
current house value, q = H0 / H_t, as a fourth state. Add the change to the
ladder as its own step after step 7. Add a test in which maintenance is
charged on the purchase price.

## Decisions already taken (Quinn, 15 Oct)

1. The contract is a real annuity: a constant real payment m * LTV * H0 for
   N_mort years at the real rate r_m. No nominal or linear contract for now.
2. The state is q = H0 / H_t.
3. Step 7 keeps today's proportional mortgage. A new step directly after it
   ("7b") switches to the annuity. Every step built on it inherits the
   annuity, so production uses it.
4. Maintenance on the purchase price, theta * H0 instead of theta * H_t, is a
   test on step 7b, not production.
5. The bequest is not netted for the outstanding balance. That waits for
   chi > 0 (TODO.md item 4).

## Why

From HANDOFF.md, 12 Oct, step-7 owner at standard numerics:
- Today the payment is a rate times the current house value. It is EUR 6.5k
  at 25 and EUR 18.6k on average at 54 (p10 9.9k, p90 29.4k). Its present
  value at r_m is 1.71 times the loan; for a real annuity it is 1.00.
- With flat house prices the owner converges on the grid (gaps 0.018 in the
  equity share, 0.3% in consumption). With today's housing it does not
  (0.877, 79%). The payment tied to the house price is one of the two causes.
  The other is maintenance on the same house, which drives the old-age floor
  states.

## The model change

1. Payment in period t: m_t * q_t * H_t = m_t * H0. `p.m_rate_path(t)` is
   already the payment per euro of purchase price (LTV times the annuity
   factor, zero after N_mort), so `config.derive` keeps it as it is.
2. Maintenance: theta * H_t as now, or theta * q_t * H_t = theta * H0 when
   `maint_on_purchase` is true.
3. Law of motion: q_1 = 1 at entry and q_{t+1} = q_t / R_H. It does not depend
   on the household's choices, so the next-period q at each quadrature node
   is known before the search.
4. Homothety holds: V(W, u, q) = W^(1-gamma) V_tilde(u1, u2, u3, q).
5. q is live in period t when the household is an owner, h_mult > 0, and
   either mortgage = 'annuity' and t <= N_mort, or maint_on_purchase is true.
   With maint_on_purchase, that includes the terminal period, which also
   charges the housing cost. The continuation at t depends on q only if q is
   live in some later period.

## The q axis

1. Nodes q_hi * s^grid_pow_q, with s uniform on [0, 1] and grid_dims(4) base
   nodes. q = 1, the entry state, is spliced in as an exact node, as the
   entry anchors are on u1 and u2.
2. Starting values: q_hi = 2, grid_pow_q = 2, 8 base nodes. The refinement
   check below decides whether they stay.
3. Where owners are, from the house-price process (mu 3.73%, sigma 8.35%),
   0.1th to 99.9th percentile:

   | age | 29 | 39 | 49 | 54 | 100 |
   |---|---|---|---|---|---|
   | q | 0.53-1.44 | 0.25-1.59 | 0.13-1.52 | 0.10-1.45 | 0.01-0.70 (median 0.08) |

   Age 100 matters only for the maintenance test. The most extreme
   house-price node at gh_n = 5 takes q = 1.6 to 1.95, which is still on the
   axis. Beyond q_hi the continuation is extrapolated flat and the
   simulation counts the lookup as off-grid.
4. When q is live in no period (renters, steps without housing, step 7), the
   axis is the single node q = 1. Arrays are N1 x N2 x N3 x N_q x T. With
   N_q = 1, `sol.V(:,:,:,t)` still indexes correctly, so code that reads
   those results keeps working unchanged.
5. In a period where q is not live, solve one slice and copy it to the
   others. Where the continuation does not depend on q, interpolate in 3D on
   one slice. This keeps step 7 bit-identical to today's code.

## New primitives in `config.params` (one line each, sources in CALIBRATION.md)

    p.mortgage          = 'annuity';   % 'annuity': fixed real payment on the purchase price; 'proportional': rate times current value (step 7)
    p.maint_on_purchase = false;       % true: maintenance theta times the purchase price (test)
    p.grid_dims         = [20 20 12 8]; % fourth entry: base nodes on q
    p.q_hi              = 2;           % top of the q axis
    p.grid_pow_q        = 2;           % > 1 bunches q nodes toward 0

## The ladder

1. Step 7 `housing` adds `mortgage = 'proportional'` to its set.
2. A new step directly after it: name `annuity`, label "Real annuity
   mortgage", note "30-year real annuity at 1.36% on the purchase price
   (placeholder rate and term)", set `struct('mortgage', 'annuity')`, and
   vary `struct('maint_on_purchase', true)` for the maintenance test.
3. Steps are numbered by position (`ladder.index`, file names
   `NN_<name>`), so in code the new step is number 8 and steps 8-15 become
   9-16. Ask Quinn at the start whether this is fine, or whether "7b"
   should appear in file names and tables. That would need a display-number
   field.
4. `housing_corr` builds on the new step, because a step builds on the one
   before it by default. `pension` still names `housing_corr`. The last step
   must still equal `config.params()`.
5. `ladder.numerics`: quick [12 12 8 6], standard [16 16 10 8], fine
   [20 20 12 8]. The folder name gets the fourth number
   (`standard_16x16x10x8_gh5`).
6. Every saved ladder result re-solves: the new primitives fail
   `ladder.same_calibration`, and the folders change. Steps without housing
   must give the same numbers as before.

## Code changes, in order

1. `+config/params.m`, CALIBRATION.md: the primitives above. Replace the
   "homothetic approximation" paragraph with the contract and the q state.
2. `+config/derive.m`: validate `mortgage`. Derive `p.q_live` (T x 1) from the
   rule in "The model change", item 5. Build the q axis.
3. `+utility/build_state_grids.m`: the q axis, its collapse to {1}, and
   `grid_nodes.q`. `insert_anchor_nodes.m`: q = 1. `welfare_anchor.m`: read
   at q = 1. `grid_override.m`: `CGM_STATE_GRID` takes four numbers; three
   is an error with a clear message.
4. `+solver/bellman_step_lna.m`:
   - the housing cost per q node;
   - the next q, q / R_H, as a vector over the shocks, in `bellman_rhs`,
     `sweep_cpi` and the floor branch;
   - 4D or 3D interpolation as in "The q axis", item 5;
   - the terminal period loops over q when maint_on_purchase is true.
5. `+solver/solve_lifecycle_lna.m`: 5-D arrays, a warm start per slice, and
   the progress probe at q = 1.
6. `+simulate/paths_lna.m`:
   - `sim.q`, and the payment m_t * H0;
   - maintenance by the switch;
   - `sim.h_cost`;
   - 4D policy lookup where q is live;
   - `n_offgrid_q`.
7. `+model/summarize.m`: housing cost from `sim.h_cost`. Home equity is
   H_t - owed_t * LTV * H0 for the annuity, and the current formula for the
   proportional contract. `+model/checks.m`: `offgrid` gets four entries.
8. `+ladder/steps.m`, `numerics.m`, and the grid variants in `robustness.m`
   and `grid_axes.m` (four entries each). The README ladder table.
9. Figures:
   - `+figures/compare.m`: the policy panels take the slice at q = 1.
   - `+figures/mortgage.m`: the model line is labelled by contract; with the
     annuity it lies on the real annuity.
   - The step-7 diagnostics: `diagnostics/step07/solve_cases.m` and
     `diagnostics/grid_design/solve_grids.m` set three-entry grid_dims, so
     add the fourth.
10. `utility.occupancy`, `auto_state_grids`, `grid_from_occupancy`: they work
    as before when N_q = 1. When N_q > 1 they stop with a clear error.
11. `tests/run_tests.m`: four-entry grid_dims, and the new checks below.
12. Docs: README ("The model in brief", the ladder table); TODO.md (item 1,
    decision 2, settled for this contract; item 5, the mortgage balance,
    done); `docs/SOLVER_BOUNDS.md` (the ends of the q axis, flat
    extrapolation in q); GRIDS.md (one line on the q axis).

## Checks

1. `run_tests(solve=false)`, then the full `run_tests`: 0 failures.
2. New checks in `run_tests`:
   1. Flat house prices (mu_H_level 0, sigma_H_level 0): q stays at 1, so on
      the q = 1 slice 'annuity' and 'proportional' agree within 1e-10 in V,
      c and pi.
   2. N_q = 1 for renters, steps without housing and step 7; N_q > 1 for the
      step-7b owner.
   3. `nohousing_ignores_housing` also changes `mortgage` and
      `maint_on_purchase`.
   4. In the step-7b owner panel, each household's payment is m * LTV * H0
      in every year to N_mort and zero after. Its present value at r_m is
      1.00 times the loan, to 1e-12.
   5. The new step builds on `housing`, and `housing_corr` builds on the new
      step.
3. One-off regression, logged but not kept as a test: step 7, both tenures,
   on a small grid, on the new code and on e87d7d2 (a git worktree). V,
   c_pol, pi_pol and the simulated panel must be bit-identical.
4. Read `model.checks` on every solve: `c_bound_25_39`, `ce_entry`,
   `offgrid` (now including q).
5. Refinement in q on the step-7b owner at standard numerics: 8 against 16
   base nodes. From age 40 they must agree within the stop rule (2 points in
   the equity share, 2% in consumption), with no off-grid lookups in q. Do
   the same for the maintenance test.

## Runs

Run these one at a time at standard numerics. Write an expectation before
each run and stop after each one for Quinn.

1. `ladder.run(7)`. Expect today's step-7 numbers. The owner on 16x16 printed
   floored 4.8% and entry 0.68 on 15 Oct (HANDOFF.md).
2. `ladder.run('annuity')` and `ladder.compare('annuity')`, step 7 against
   7b. Expect:
   - the payment constant at EUR 6.5k to 54, against EUR 18.6k on average
     now;
   - higher consumption at 40-54 and fewer floored years before 40;
   - a much smaller grid dependence in early life;
   - old-age floor states near their step-7 level, since maintenance still
     grows with the house.
3. The grid check as for step 7 (16x16 against 32x16, or
   `ladder.robustness('annuity')`), against the stop rule.
4. `ladder.sensitivity('annuity')`: maintenance on the purchase price. Expect
   the old-age floor states mostly gone. Without maintenance the floor bound
   in 0.01% of years (HANDOFF.md, 12 Oct).

Runtime estimates, to be measured:
- Step-7b owner at standard: about 8 min, against about 90 s for step 7.
  There are 9 q slices for ages 25-54 and one after that, plus the cost of
  4D interpolation.
- The maintenance test: 15-20 min, because q is live at every age.
- Production owner on the fine grid: about 45 min, against about 8 min.
- Renters: unchanged.

## Environment

The session that wrote this ran in a cloud container without MATLAB. If the
implementation runs there too, the checks run on Quinn's PC. In that case
hand over an ordered list of the files to run, and log what they print.
