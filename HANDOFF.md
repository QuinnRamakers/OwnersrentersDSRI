# Handoff

The shared log between chat (Claude on claude.ai) and Claude Code. Newest entry first in each section.

Rules:
1. Chat writes only under "Specs". Claude Code writes only under "Log".
2. A spec is marked done by adding one line under it, "Done: <date of the log entry>". Nothing else is edited.
3. A log entry is not complete without the commit hash and the numbers the checks printed.
4. If this file and chat disagree, this file wins.

## Specs (from chat)

### 2026-10-07 Record a baseline
Change: no code change. Run the full test suite and the quick ladder once, and log the results.
Why: everything later is compared against this.
Checks that must pass: `run_tests` reports 0 failures. `ladder.run('all', numerics='quick')` finishes; log the `model.checks` values (`c_bound_25_39`, `ce_entry`) for steps 6 to 9, both tenures.

## Log (from Claude Code)

### 2026-10-07 Calibration plan and working setup into git (spec: none, asked by Quinn in Claude Code)
Changed: added CALIBRATION_PLAN.md, the step-by-step plan for the new calibration, exported from the Claude Doc at https://claude.ai/code/artifact/f90a2f02-9934-4efe-a81c-2b9f2adb6163 (the doc's route widget is written out as text). README.md points to it. Committed CLAUDE.md, HANDOFF.md and .claude/ (skills and hooks) as they were on disk. `claude_setup/` is an identical copy of `.claude/` and was not committed. Earlier today: pushed main (lean core), solver-active-set, tag research-2026-09 and chore/prune-and-group-scripts, and committed demo/ (9fa84ac). No .m files changed.
Checks run: `matlab -batch "addpath tests; run_tests(solve=false)"` printed 0 of 5 checks failed.
Commit: 0011a63, pushed to main.
Open: the plan's questions 1 to 4 (income polynomial form and units, permanent vs transitory variance, market series, retirement income before the DC pension) block the code work before step 1. The "Record a baseline" spec is not started.

### 2026-10-07 Starting state (checked from chat, not a Claude Code run)
Repo: main at 9fa84ac, equal to github/main. Untracked: `demo - Copy/`, `demo - Copy.zip`.
The ladder, `run_tests` and `model.checks` are in main. The old `param_fingerprint` gate is gone; `ladder.same_calibration` replaces it.
Checks run: none.
Open: baseline spec above.

## Entry formats

Spec:

    ### <date> <short title>
    Change: what to change.
    Why: one line.
    Checks that must pass: what to run and what result counts.

Log:

    ### <date> <short title> (spec: <title or none>)
    Changed: files and what.
    Checks run: command, then the numbers it printed.
    Commit: <hash>, pushed to main.
    Open: what is left, or "none".
