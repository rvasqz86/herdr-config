#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
root=$(mktemp -d)
export PATH="$PWD/tests/fake-herdr:$PATH" HERDR_ENV=1 FAKE_HERDR_LOG="$root/log"
repo="$root/my repo"; mkdir -p "$repo"; git -C "$repo" init -q -b main
canary="$root/pwned"
brief="Add \"time\" endpoint; \$(touch $canary) \`touch $canary\`
second line"

bin/hq team "$repo" "$brief" arch >/dev/null 2>&1
rc=$?; log=$(cat "$FAKE_HERDR_LOG")
assert_eq "$rc" 0 "hq team exits 0"
assert_contains "$log" '"workspace","create","--cwd","'"$repo"'","--label","arch"' "workspace in path with spaces"
assert_eq "$(grep -c '"pane","split"' <<<"$log")" 5 "five splits"
assert_contains "$log" '"tab","create","--workspace","w9","--cwd","'"$repo"'","--label","crew"' "crew tab"
assert_contains "$log" '"--ratio","0.75"' "runtime row split"
assert_contains "$log" '"pane","rename","w9:p' "runtime pane renamed"
for pair in manager:claude planner:omp specrev:copilot impl:cursor taskrev:claude; do
  assert_contains "$log" '"agent","start","arch-'"${pair%%:*}"'","--kind","'"${pair#*:}"'"' "starts ${pair%%:*} as ${pair#*:}"
done
assert_eq "$(grep -c '"agent","prompt"' <<<"$log")" 5 "five first prompts"
assert_contains "$log" "roles/planner.md" "planner gets its role file"
assert_contains "$log" 'Runtime pane: w9:p' "manager told runtime pane"
assert_contains "$log" '$(touch' "brief passed verbatim"
assert_contains "$log" 'second line' "multi-line brief kept"
[ -e "$canary" ] && bad "brief was executed" || ok "brief not executed"
assert_not_contains "$log" "--dangerously-skip-permissions" "ask mode has no flags"
mgr=$(grep '"agent","prompt","arch-manager"' <<<"$log")
assert_not_contains "$mgr" '"--wait"' "manager prompt does not block hq"

# trusted on hq/* branch → crew flags, never manager
: >"$FAKE_HERDR_LOG"; mkdir -p "$repo/.hq"; echo autonomy=trusted >"$repo/.hq/runtime"
git -C "$repo" checkout -q -b hq/x
bin/hq team "$repo" "b" arch >/dev/null 2>&1; log=$(cat "$FAKE_HERDR_LOG")
assert_contains "$log" '"arch-impl","--kind","cursor","--pane","w9:p' "impl started"
assert_contains "$log" '"--force","--trust"' "cursor trusted flags"
assert_contains "$log" '"--allow-all-tools"' "copilot trusted flag"
assert_not_contains "$(grep '"arch-manager","--kind"' <<<"$log")" "--dangerously" "manager never trusted"

# duplicate label fails before building anything
: >"$FAKE_HERDR_LOG"
out=$(FAKE_AGENTS="arch-manager other" bin/hq team "$repo" "b" arch 2>&1); rc=$?
assert_eq "$rc" 1 "duplicate label exits 1"
assert_contains "$out" "already running" "duplicate label message"
assert_not_contains "$(cat "$FAKE_HERDR_LOG")" '"workspace","create"' "no layout on duplicate"

# usage errors
out=$(bin/hq team "$repo" 2>&1); assert_contains "$out" "usage: hq team" "missing brief"
out=$(bin/hq team "$root" "b" 2>&1); assert_contains "$out" "not a git repository" "non-git dir"
out=$(bin/hq team --resume "$root/nope" 2>&1); assert_contains "$out" "usage: hq team" "resume bad dir"
rm -rf "$repo/.hq"
out=$(bin/hq team --resume "$repo" 2>&1); assert_contains "$out" "nothing to resume" "resume without state"

# resume
: >"$FAKE_HERDR_LOG"; mkdir -p "$repo/.hq"; echo phase=tasks >"$repo/.hq/state"
bin/hq team --resume "$repo" arch >/dev/null 2>&1; log=$(cat "$FAKE_HERDR_LOG")
assert_contains "$log" 'Mode: resume' "resume mode passed to manager"
rm -rf "$root"
finish
