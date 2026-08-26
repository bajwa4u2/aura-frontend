#!/usr/bin/env bash
#
# GATED PUSH — the push cannot run after a failed prerequisite.
#
# Founder process correction, 2026-08-25. Commit e23b4e2 was pushed with three
# failing tests because the flow was a SEQUENCE of shell statements that looked
# gated and was not:
#
#     flutter test | tail -2      <- failure visible, exit status swallowed by the pipe
#     git commit ...              <- ran anyway
#     git push                    <- ran anyway
#
# Two separate faults: the statements were newline-separated rather than
# chained, and `| tail` discarded the test command's exit status even if they
# had been. This script fixes both.
#
#   set -e          any failing step aborts the script
#   set -o pipefail a failure survives a pipe into tail/grep
#
# Usage:  tool/gated_push.sh "commit message"
#         tool/gated_push.sh --check-only        (gates without committing)

set -euo pipefail

cd "$(dirname "$0")/.."

echo "── analyzer ─────────────────────────────────────────────────────────"
# `dart analyze` exits non-zero on errors and warnings, which is the gate we
# want; pre-existing infos in unrelated files must not block a push, so only
# errors and warnings are treated as fatal.
if dart analyze lib/ test/ integration_test/ 2>&1 | grep -E "^ +(error|warning) " ; then
  echo "ANALYZER FAILED — push refused"
  exit 1
fi
echo "analyzer clean"

echo "── suite ────────────────────────────────────────────────────────────"
# No pipe: the exit status is the gate.
flutter test
echo "suite green"

if [ "${1:-}" = "--check-only" ]; then
  echo "── check-only: nothing committed ────────────────────────────────────"
  exit 0
fi

if [ $# -lt 1 ]; then
  echo "usage: tool/gated_push.sh \"commit message\"" >&2
  exit 2
fi

echo "── commit + push ────────────────────────────────────────────────────"
git add -A
# Nothing staged is not a failure worth aborting a verified run over.
if git diff --cached --quiet; then
  echo "nothing to commit"
  exit 0
fi
git commit -q -F - <<COMMIT_MSG
$1

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
COMMIT_MSG
git push -q origin main
echo "pushed $(git rev-parse --short HEAD)"
