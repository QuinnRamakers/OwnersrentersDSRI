---
name: session-start
description: Start of a session on this repo. Read the shared state, then say what will be done and how it will be checked. Use at the beginning of any session.
---

1. Read HANDOFF.md: the specs not yet marked done, and the latest two log entries.
2. Read the repo state the start hook printed (or run `git fetch --all`, `git status -sb`, `git log -5`). If the branch is behind its upstream, run `git pull --ff-only` before editing anything. If it cannot fast-forward, stop and tell the user.
3. If the task touches a parameter, read the matching section of CALIBRATION.md first.
4. Say in three short lines: where the repo stands, which spec you are doing, and which check will show it is done.
5. Do not start work that has no spec in HANDOFF.md without telling the user; add a spec line for it first.
