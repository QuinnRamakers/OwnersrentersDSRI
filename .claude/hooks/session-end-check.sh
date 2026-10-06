#!/bin/bash
# Runs when Claude is about to stop. Blocks once if the work is not safely in
# git, so chat (which reads GitHub) can see it. Exit code 2 sends the message
# back to Claude; the stop_hook_active check stops it from looping.
input=$(cat)
if echo "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

problems=""

dirty=$(git status --porcelain --untracked-files=no)
if [ -n "$dirty" ]; then
  problems="${problems}- Uncommitted changes to tracked files:
$(echo "$dirty" | head -n 10)
"
fi

up=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null)
if [ -n "$up" ]; then
  ahead=$(git rev-list --count '@{u}..HEAD')
  if [ "$ahead" -gt 0 ]; then
    problems="${problems}- $ahead commit(s) not pushed to $up.
"
  fi
  changed=$( { git diff --name-only HEAD; git diff --name-only '@{u}..HEAD'; } | sort -u )
else
  changed=$(git diff --name-only HEAD)
fi

if echo "$changed" | grep -q '\.m$' && ! echo "$changed" | grep -qx 'HANDOFF.md'; then
  problems="${problems}- .m files changed but HANDOFF.md has no new log entry.
"
fi

if [ -n "$problems" ]; then
  {
    echo "Do not finish yet. Follow the session-end skill:"
    printf '%s' "$problems"
  } >&2
  exit 2
fi
exit 0
