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
- Editing a ladder step re-solves it and every step after it. Compare steps only at the same numerics (quick, standard or fine).
- An override that names a field that is not a primitive is an error. Do not work around it.

## Checks before saying something works

- Always run `run_tests(solve=false)` (fast).
- Before finishing any change to `+solver`, `+config`, `+ladder` or `+model`, run the full `run_tests` (a few minutes).
- Headless from the repo root: `matlab -batch "addpath tests; run_tests"`.
- Read `model.checks` on every solve: `c_bound_25_39`, `ce_entry`, `offgrid`.
- Report what ran and the numbers it printed. Do not write "should work".

## Known limits (do not claim past these)

- At the production calibration, ages 25 to 39 are not converged. Behaviour from age 40 is reliable. Report behaviour, not welfare levels, until the consumption floor is set (TODO.md, item 1).
- The REIT parameters are placeholders and the REIT leg is off.
- Free DC investment choice, glide-path comparisons and the September diagnostics live on the `solver-active-set` branch (tag `research-2026-09`), not here.

## Practicalities

- Quote MATLAB package folders in the shell, for example `'+config'`, because of the `+`.
- `*.mat`, `*.png`, `*.csv`, `*.pdf` and `*.txt` are gitignored. Write notes in `.md` files.
- Stage files by name. Never run `git add .`. The folders `demo - Copy/` and `demo - Copy.zip` are leftovers and must not be committed.
- For a quick look at a solve, shrink the grid with `setenv('CGM_STATE_GRID','8 6 6'); setenv('CGM_GH_N','3')` and clear both afterwards.

## Writing

Plain, direct English in short sentences. Use numbered lists for plans. When handing work over, give an ordered list of exactly the files to run, then a short plain summary of what changed and what it means. In paper text, no bold headings and no editorial framing.
