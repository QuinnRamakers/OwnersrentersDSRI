#!/bin/bash
# Prints the repo state at the start of a session, so the session begins from
# what is in git and not from what anyone remembers.
cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

git fetch --all --quiet 2>/dev/null

echo "Repo state at session start:"
git status -sb | head -n 8
echo
echo "Last commits:"
git log -3 --format='%h %ad %s' --date=short

up=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null)
if [ -n "$up" ]; then
  behind=$(git rev-list --count 'HEAD..@{u}')
  ahead=$(git rev-list --count '@{u}..HEAD')
  [ "$behind" -gt 0 ] && echo "WARNING: $behind commit(s) behind $up. Pull before editing."
  [ "$ahead" -gt 0 ] && echo "WARNING: $ahead commit(s) not pushed to $up. Chat cannot see them."
fi

if [ -f HANDOFF.md ]; then
  echo
  echo "HANDOFF.md (open specs and latest log entries):"
  head -n 60 HANDOFF.md
fi
exit 0
