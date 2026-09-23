#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
for f in planner spec-review implementer task-review; do
  body=$(cat "roles/$f.md" 2>/dev/null)
  assert_contains "$body" "DONE <path>" "$f: reply contract DONE"
  assert_contains "$body" "BLOCKED: <reason>" "$f: reply contract BLOCKED"
  assert_contains "$body" "Never commit" "$f: never commits"
  assert_contains "$body" "You may write" "$f: states write scope"
done
assert_contains "$(cat roles/planner.md)" "Status: todo" "planner: task template"
assert_contains "$(cat roles/planner.md)" "## Spec issue" "planner: spec-issue section"
assert_contains "$(cat roles/spec-review.md)" "Verdict: READY" "spec-review: verdict"
assert_contains "$(cat roles/implementer.md)" "BLOCKED: spec issue" "implementer: spec issue path"
assert_contains "$(cat roles/implementer.md)" "runtime pane" "implementer: leaves the dev server alone"
assert_contains "$(cat roles/task-review.md)" "Verdict: PASS" "task-review: verdict"
assert_contains "$(cat roles/task-review.md)" "git status --porcelain" "task-review: sees untracked files"
finish
