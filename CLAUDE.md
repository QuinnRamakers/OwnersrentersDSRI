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

- At the production calibration (ladder step 16), owners are not converged at any age on any grid tried: refining the u3 axis makes them hoard into retirement. Renters are converged only from about 50, on the bunched grid with 20 u3 points; the ladder's evenly spaced grid does not get there. Source: HANDOFF.md, 18 October 2026, "Smallest accurate grid at step 16". Report behaviour, not welfare levels, until the housing outflow is settled (TODO.md, item 1). The floor is a numerical bound, not a calibration target.
- The REIT parameters are placeholders and the REIT leg is off.
- Free DC investment choice, glide-path comparisons and the September diagnostics live on the `solver-active-set` branch (tag `research-2026-09`), not here.

## Practicalities

- Quote MATLAB package folders in the shell, for example `'+config'`, because of the `+`.
- `*.mat`, `*.png`, `*.csv`, `*.pdf` and `*.txt` are gitignored. Write notes in `.md` files.
- Stage files by name. Never run `git add .`. The folders `demo - Copy/` and `demo - Copy.zip` are leftovers and must not be committed.
- For a quick look at a solve, shrink the grid with `setenv('CGM_STATE_GRID','8 6 6 4'); setenv('CGM_GH_N','3')` and clear both afterwards.

## Running on the DSRI

The how-to is `docs/DSRI_HOWTO.md`.

- Only from Claude Code on Quinn's PC, with the UM VPN on. Cloud sessions and chat cannot reach the DSRI.
- Before any DSRI work, run `oc whoami`. If it fails, stop and ask Quinn to log in again and to check the VPN. Do not retry.
- Pod: `oc get pods -l app=cgm-matlab -o name`. Never hard-code the pod name; it changes on every restart.
- Remote folder: `/Solutionstorage/OwnersrentersDSRI`, the only persistent place. Run there with `CGM_OUTPUT_DIR` set to it, so results land under `ladder/` as on the PC.
- `MSYS_NO_PATHCONV=1` must be set, or Git Bash rewrites the `/Solutionstorage` paths: in the `env` of `.claude/settings.json`, or with `export MSYS_NO_PATHCONV=1;` at the start of each command (shell state does not carry over between commands).
- Sync only a committed and pushed tree (`git status -sb --untracked-files=no` shows no changes and nothing ahead), with `oc rsync ./ <pod>:/Solutionstorage/OwnersrentersDSRI/ --exclude=.git --exclude=.claude --exclude=ladder --exclude='*.mat' --exclude='*.png' --exclude='*.pdf' --exclude='*.txt' --exclude='demo - Copy' --exclude='demo - Copy.zip'`. Never `--delete`: the results live in the same folder.
- Long runs: inside `oc exec <pod> -- bash -c "..."`, write `commit <hash>, started <date>` as the first line of `runs/<name>.txt`, then `CGM_OUTPUT_DIR=<folder> nohup matlab -sd <folder> -batch '<statement>' >> runs/<name>.txt 2>&1 &`. MATLAB strings in the statement take escaped double quotes.
- Two runs at once: give each `CGM_N_WORKERS` equal to its share of the pod's cores.
- Progress: `tail` on the log. Running jobs: `ps -eo pid,etime,args | grep [-]batch`.
- When a run ends: read `model.checks` in the log (`c_bound_25_39`, `ce_entry`, `offgrid`), pull `runs/` and the results folder with `oc rsync`, and log the run in HANDOFF.md: that it ran on the DSRI, the commit, the pod's cores, the wall time and the checks.
- `Undefined function 'fmincon'` or "No parallel pool" means the pod restarted: reinstall the toolboxes (`docs/DSRI_HOWTO.md`, section 2.4) and start the run again. `ladder.run` skips steps already saved.
- A licence error: stop and tell Quinn.
- Never run `oc delete`, and never delete anything under `/Solutionstorage`, without asking first.

## Writing

Plain, direct English in short sentences. Use numbered lists for plans. When handing work over, give an ordered list of exactly the files to run, then a short plain summary of what changed and what it means. In paper text, no bold headings and no editorial framing.
