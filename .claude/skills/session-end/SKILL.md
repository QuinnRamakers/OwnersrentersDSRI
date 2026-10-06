---
name: session-end
description: End of a session on this repo. Run the checks, log the result in HANDOFF.md, commit and push so chat can see it. Use before finishing any session that changed files.
---

1. Run the checks. Always `run_tests(solve=false)`. If `+solver`, `+config`, `+ladder` or `+model` changed, run the full `run_tests` too. Headless: `matlab -batch "addpath tests; run_tests"` from the repo root.
2. If a parameter or ladder step changed, update CALIBRATION.md in the same commit, with the source.
3. Add a log entry at the top of the Log section of HANDOFF.md, in the format at the bottom of that file: what changed, the commands run and the numbers they printed, the commit hash, what is open. Mark the spec done only if its checks passed. If a check failed, say so in the entry; do not hide it.
4. Commit by naming files. Never `git add .`. Do not add `demo - Copy/` or `demo - Copy.zip`.
5. Push to main. Then run `git status -sb` and confirm it shows no ahead or behind.
6. Tell the user in plain words: what changed, what the checks showed, and that it is pushed.
