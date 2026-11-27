# Prompt: why the grid policy's simulated welfare falls short of its value function

Saved on 27 Nov 2026, on branch `work-2026-11-26` (commit 015ddba or later).
Asked by Quinn: "make a prompt on the grid issue: what is going on with the
simulated welfare vs the value function".

## Goal

Find out why the solver's value function and the welfare its own policy
delivers in simulation disagree, and what makes them agree. There are three
cases: step 18 renters, step 18 owners and step 24 renters (step 24 owners
when their solve exists). For each case, name the source of the gap with a
test that would have come out differently otherwise, and try a fix.

The two numbers:
1. Value-function welfare, `ce_entry` in `model.checks`: the certainty
   equivalent of V at the entry state (welfare anchor b0), in units of
   entry income.
2. Simulated welfare: the same certainty equivalent of the mean realised
   lifetime utility when the grid policy is simulated by
   `simulate.paths_lna` from that state. `neural.sim_utility` computes it
   without a bequest motive. With chi > 0 use the Julia year
   (`neural/scripts/net_panel.jl`, field `U_grid`).

If the solver were exact the two would differ only by Monte Carlo error and
by what policy interpolation loses, which can only lower simulated welfare.

## Read first

1. CLAUDE.md, the working rules.
2. HANDOFF.md, the 27 November log entries: "Neural network, step 18 checked
   in MATLAB", "Step 18: the owners' solver-simulation gap is the absorbing
   state", and the step-24 entries.
3. GRIDS.md and docs/SOLVER_BOUNDS.md.
4. `+solver/bellman_step_lna.m`: the continuation is linear in
   z = ((1-gamma) V_tilde)^(1/(1-gamma)), extrapolated 'nearest'. With
   `abs_node_test` the floor is tested at each quadrature node.
   `bankrupt_nodes` handles the floor, and with `default_choice`,
   V = max(V_default, V_continue).

## What is known

| step, tenure, grid | value function | simulated | gap carried by |
|---|---|---|---|
| 18 renters, standard 16x16x10x8 | 0.3479 | 0.2161 | interpolation on u1, removed by refinement |
| 18 renters, production 32x16x40x4 | 0.2877 | 0.2422 | the same, smaller |
| 18 owners, standard | 0.3594 | 0.2642 | 0.31% bankrupt at 41-54, does not refine away |
| 24 renters, quick 12x12x8x6, gh_n 3 | 0.3637 | 0.0063 | one household holds 80% of utility |
| 24 renters, standard | 0.3544 | 0.0540 | one household holds 81% of utility |
| 24 owners | solve running on 27 Nov | | |

Simulated: 20,000 test households, seed 202.

1. **Step 18 renters.** The same fixed policy, valued by the solver on
   finer grids (`neural.evaluate_policy`, `neural.eval_refinement`),
   converges to simulation:
   - standard-grid policy: 0.3605 (14x14x8), 0.3479 (18x18x10), 0.2679
     (34x18x40), 0.2362 (66x34x40), 0.2278 (66x34x80), 0.2205 (130x34x80),
     against 0.2161 simulated;
   - production-grid policy: 0.2877, 0.2539 and 0.2473, against 0.2422.

   The u1 axis carries the error, and gh_n 7 changes nothing. So the gap is
   interpolation error in the value function, and the policy is optimised
   against that error: the standard-grid policy runs liquid wealth to zero by
   90.
2. **Step 18 owners.** Refining any one axis leaves both the grid policy and
   a network policy at 0.34-0.35, against 0.26-0.29 simulated: u1 to 64
   points, u2 to 32, u3 to 80, q to 17, or gh_n 9.

   The test of value along paths
   (`diagnostics/step18_absorbing/value_along_paths.m`, 100,000 households,
   seed 303):
   - owners who never go bankrupt: solver 0.3594, realised 0.3570;
   - all owners: 0.3594 against 0.2651;
   - the whole gap is the 0.31% who go bankrupt at 41-54;
   - in every year from 25 to 54, the solver's one-step expectation is above
     the realised value next year.

   Where the bankrupt owners sit on the grid
   (`diagnostics/step18_absorbing/bankrupt_owners.m`):
   - 1 - u2 = 0.0077 five years before bankruptcy and 0.0012 one year before;
   - the u2 nodes sit at 1 - u2 = 0.019, 0.017, 0.008, 0.0024, 0.0003 and 0,
     so the last five years fall in two intervals;
   - u1 is 0.04-0.06 and q is 0.42-0.49, between the q nodes 0.20, 0.46 and
     0.82;
   - a year before bankruptcy the grid policy consumes 90% of resources and
     puts 71% of saving in stocks.

   The edge of bankruptcy, liquid resources LW = F, is a surface in u1, u2
   and q together. At chi = 0 the house is worth nothing to its owner (no
   sale, no bequest) but is about two thirds of W, so the liquid dimension
   that matters is a thin slice of the cube.

   There is also a gap in the opposite direction, so far unexplained. For
   owners who never go bankrupt, at 85 and older the solver says 0.13-0.25 and
   they realise about 0.54.
3. **Step 24 renters.** Three features of step 24 meet here:
   - default is a choice, so V is continuous;
   - a household that continues may consume down to phi_floor Y = 1e-6 Y;
   - the bequest chi u(b), with chi = 32, has no shifter.

   In simulation the default decision compares the interpolated V_cont with
   the default value. That V_cont overprices states with almost no
   resources, so:
   - 9% of renters continue at some age below the floor amount;
   - a few continue at 91-92 and 100 on about 1e-4 of entry income;
   - their bequests of that size set welfare
     (`diagnostics/step24_default/decompose.jl`).

   The standard grid has fewer such households than the quick grid, which
   raises simulated welfare from 0.006 to 0.054. Because single households
   set the number, it depends on the sample: on 100,000 households with seed
   303, the standard grid gives 0.001. The modelling choice for step 24
   (bequest shifter, floor as the lower bound of consumption) is open with
   Quinn. Do not decide it here; test under the current specification and
   say that welfare there is set by single households.
4. **Earlier notes.**
   - Linear interpolation in z overprices states next to the floor.
     Refinement moves the trough but does not remove it.
   - The solver's 'nearest' extrapolation snaps all coordinates to the grid.

## Hypotheses, each with a test that tells them apart

1. **Interpolation across the cliff.** Near the floor z falls steeply
   between nodes, and a straight line between a solvent node and a node at
   the floor lies above it. Tests:
   - At the simulated states of the households that later go bankrupt (owners
     one to five years before; renters at step 24 before they continue on
     nothing), solve the Bellman problem at the state itself, using the
     solver's V_next. Compare that value with the interpolated V_t.
   - Repeat with `interp_method = 'makima'`.
   - Repeat with nodes placed by distance to the floor.
2. **Coordinates.** For owners the edge is thin and curved in
   (u1, u2, u3, q). Tests:
   - Use a coordinate that measures liquid resources relative to the floor
     or to the housing cost, for example log X/(W - Y), or more points on u2
     near 1.
   - See whether the owner values move towards simulation.
3. **Policy interpolation, not the value.** Tests:
   - Simulate with the policy optimised afresh at each simulated state
     against the solver's V_next, instead of interpolated c and pi.
   - If welfare rises to the value function, the policy's interpolation is
     the cause.
4. **The default rule in the simulator (step 24).**
   - Decide default by comparing the default value with the value of
     continuing optimised afresh at the state, not with the interpolated
     V_cont.
5. **Quadrature.**
   - Ruled out at step 18 (gh_n 7 for renters, 9 for owners).
   - At step 24 the REIT is a fourth shock (`gh_n_reit`); check it there.

## Tools on the branch

1. `neural.evaluate_policy(p, policy)`: backward induction with a fixed
   policy on any grid, through the eighth input of `bellman_step_lna`.
2. `neural.grid_policy_fn(r)`: the grid policy as the simulator reads it.
   `neural.eval_refinement(r, net_file, grids)` values a policy on a list of
   grids.
3. `diagnostics/step18_absorbing/value_along_paths.m` and
   `bankrupt_owners.m`: the solver's value along simulated paths by age, and
   where the bankrupt owners sit.
4. `diagnostics/step24_default/value_along_paths.m`, `decompose.jl` and
   `figures_renter.m`: the same at step 24, with the bequest, and where
   utility comes from.
5. Solves with `neural.make_testsets({step}, numerics={...}, keep_solve=true)`
   are saved as `neural/data/solve_<step>_<tenure>_<numerics>.mat`
   (gitignored). They exist for:
   - step 18: renter and owner standard, renter fine (production); owner fine
     running on 27 Nov;
   - step 24: renter and owner quick, renter standard; owner standard running
     on 27 Nov.

## What done looks like

1. For each case, the source of the gap, named and shown by a test that
   would have come out differently otherwise.
2. A candidate fix (grid, coordinate, interpolation or simulation rule) and
   its effect, for each case:
   - the solver's value at entry against simulated welfare, with the Monte
     Carlo standard error;
   - the grid size at which they agree within 2%;
   - the run time.
3. Behaviour reported rather than welfare levels wherever the two do not
   agree (CLAUDE.md).
4. No production default changed without Quinn, and nothing merged into main.

## Practicalities

1. Work on a new branch off `work-2026-11-26`.
2. The PC has 32 logical cores, 63 GB and a commit limit of about 67 GB;
   MATLAB's pool has 16 threads.
   - owner standard solve: about 45 minutes at step 18, about 3 hours at step
     24 (four shocks);
   - owner production solve at step 18: about 4 hours. Larger runs go to the
     DSRI (docs/DSRI_HOWTO.md).
3. Always run `run_tests(solve=false)`. Run the full `run_tests` before
   finishing any change to `+solver`, `+config`, `+ladder` or `+model`.
4. Log in HANDOFF.md with the commit and the numbers, then push.
