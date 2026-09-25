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
m=$(cat roles/manager.md 2>/dev/null)
for s in "Gate 1" "Gate 2" "hq respawn" "herdr agent prompt" "herdr notification show" \
         "never answer" ".hq/state" "2 rounds" "3 rounds" "runtime.log" "task NN:" \
         "Mode: resume" "gh pr create" "hq/" "git status --porcelain" "autonomy=trusted" \
         "hq runlog" "log_max" "runtime.log.1"; do
  assert_contains "$m" "$s" "manager: mentions '$s'"
done
# final-review fixes
assert_contains "$m" "git status --porcelain -- . ':!.hq'" "manager: clean-tree check ignores .hq/"
assert_not_contains "$m" "1200000" "manager: no 20-min single tool call"
assert_not_contains "$m" "1800000" "manager: no 30-min single tool call"
assert_contains "$m" "--timeout 540000" "manager: waits fit the Bash tool limit"
assert_contains "$m" "HQ_READY_TIMEOUT=480 hq respawn" "manager: respawn fits the Bash tool limit"
assert_not_contains "$m" "herdr pane wait-output RT" "manager: no scrollback-based readiness wait"
assert_contains "$m" "grep -qE" "manager: readiness read from the fresh log"
assert_contains "$m" ".hq/archive/" "manager: archives an earlier feature's .hq files"
# exec roles
for f in cto coo; do
  body=$(cat "roles/$f.md" 2>/dev/null)
  assert_contains "$body" "DONE <path>" "$f: reply contract DONE"
  assert_contains "$body" "BLOCKED: <reason>" "$f: reply contract BLOCKED"
  assert_contains "$body" "Never commit" "$f: never commits"
  assert_contains "$body" "You may write" "$f: states write scope"
  assert_contains "$body" "company/positions/" "$f: writes positions"
  assert_contains "$body" "Confidence:" "$f: position template"
done
assert_contains "$(cat roles/cto.md)" "company/tech.md" "cto: writes tech.md on the first session"
assert_contains "$(cat roles/coo.md)" "company/ops.md" "coo: writes ops.md on the first session"
assert_contains "$(cat roles/coo.md)" "## Open questions" "coo: lists unknowns"
c=$(cat roles/ceo.md 2>/dev/null)
for s in "spend_limit" "awaiting founder" "exec: company baseline" "company/brief.md" "company/settings" \
         "decisions/log.md" "positions/NNNN-cto.md" "Escalation:" "Status: decided" "Status: rejected" \
         "hq respawn" "HQ_READY_TIMEOUT=480" "--timeout 540000" "herdr notification show" \
         "never answer" "one follow-up" "Mode: resume" "exec: NNNN" "not a decision" \
         "escalate=" "Next steps"; do
  assert_contains "$c" "$s" "ceo: mentions '$s'"
done
assert_not_contains "$c" "1200000" "ceo: no 20-min single tool call"
# review fixes: commits by pathspec, re-classifies before filing, never loosens its own limits,
# follow-ups land in the position file, a first-session question waits for the baseline
assert_eq "$(grep -c -- '-- company\`' roles/ceo.md)" 2 "ceo: both commits use the company pathspec"
assert_contains "$c" "Re-classify" "ceo: re-classifies escalation before filing"
assert_contains "$c" "Never change \`spend_limit\` or \`escalate\`" "ceo: never loosens its own limits"
assert_contains "$c" "## Follow-up" "ceo: follow-ups go into the position file"
assert_contains "$c" "then take the question as the first decision" "ceo: first-session question waits for the baseline"
assert_contains "$(cat roles/cto.md)" "## Follow-up" "cto: answers follow-ups in the position file"
assert_contains "$(cat roles/coo.md)" "## Follow-up" "coo: answers follow-ups in the position file"
finish
