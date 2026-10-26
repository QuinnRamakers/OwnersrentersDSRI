# Working notes for Claude Code

A life-cycle consumption and portfolio model (Cocco, Gomes and Maenhout 2005 style) for Dutch owners and renters with a DC pension, solved in MATLAB. README.md describes the model. This file lists the rules for working on it.

## Where things live

1. CALIBRATION.md: every parameter value and its source. It is the authority. If the code and CALIBRATION.md disagree, say so and fix one of them.
2. TODO.md: open questions only. Resolved decisions go in CALIBRATION.md and git history.
3. HANDOFF.md: the shared log between chat (Claude on claude.ai) and Claude Code. Read it first, write to it last.
4. The GitHub repo, branch main, is the single source of truth. Anything a chat remembers is only a summary of it.

## Starting and finishing a session

Use the session-start skill at the beginning and the session-end skill at the end. A hook prints the repo state at the start and blocks the end of a session while changes are uncommitted or unpushed. Work only counts once it is pushed, because chat reads GitHub, not this PC.

## Calibration rules

- A new input is a primitive in `config.params`, one line, with its source in CALIBRATION.md. Anything that follows from inputs goes in `config.derive`.
- `ladder.same_calibration` compares every primitive, so a saved result for a different calibration is never reused as if it were comparable. A value kept only in a derived field escapes that check, so do not do that.
- The last ladder step must equal `config.params()`. `run_tests` checks this. To change the production calibration, change the step and `params` together.
- Editing a ladder step re-solves it and every step built on it (the ladder branches at step 6; `ladder.parent`). Compare steps only at the same numerics (quick, standard or fine).
- An override that names a field that is not a primitive is an error. Do not work around it.

## Checks before saying something works

- Always run `run_tests(solve=false)` (fast).
- Before finishing any change to `+solver`, `+config`, `+ladder` or `+model`, run the full `run_tests` (a few minutes).
- Headless from the repo root: `matlab -batch "addpath tests; run_tests"`.
- Read `model.checks` on every solve: `c_bound_25_39`, `ce_entry`, `offgrid`.
- Report what ran and the numbers it printed. Do not write "should work".

## Known limits (do not claim past these)

- Grids at the absorbing floor of EUR 5,000 (`docs/HANDOFF_2026-10-26.md`): u2 and q change nothing; u3 matters most (for owners on the current house value above all) and u1 moves young households. Bunched u1 at 32, u2 at 16, u3 at 40 and q at 4 was chosen (not yet in `config.params`). Nothing is settled before about 35-40, and welfare levels move with every refinement. Report behaviour, not welfare levels, until the housing outflow is settled (TODO.md, item 1). Production charges owners' maintenance on the purchase price since 26 October 2026 (ladder step 17); steps 7-16 use the current value.
- The absorbing floor (`c_min`) is implemented and off; it is not adopted. With it on, consumption is stable across grids from 40 but the equity share is not, welfare levels move 4-5% per grid refinement, and owner bankruptcy is illiquidity (no equity release). Source: `docs/HANDOFF_2026-10-24.md`.
- The REIT parameters are placeholders and the REIT leg is off.
- Free DC investment choice, glide-path comparisons and the September diagnostics live on the `solver-active-set` branch (tag `research-2026-09`), not here.

## Practicalities

- Quote MATLAB package folders in the shell, for example `'+config'`, because of the `+`.
- `*.mat`, `*.png`, `*.csv`, `*.pdf` and `*.txt` are gitignored. Write notes in `.md` files.
- Stage files by name. Never run `git add .`. The folders `demo - Copy/` and `demo - Copy.zip` are leftovers and must not be committed.
- For a quick look at a solve, set `p.grid_dims = [8 6 6 4]; p.gh_n = 3;` before `config.derive`. The environment variables `CGM_STATE_GRID` and `CGM_GH_N` reach only `ladder.numerics` (so `ladder.run`) and `run_model`, not `ladder.params` or `config.derive`; clear them afterwards if set.

## Writing

Plain, direct English in short sentences. Use numbered lists for plans. When handing work over, give an ordered list of exactly the files to run, then a short plain summary of what changed and what it means. In paper text, no bold headings and no editorial framing.
