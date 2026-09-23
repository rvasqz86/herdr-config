#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
root=$(mktemp -d)
export PATH="$PWD/tests/fake-herdr:$PATH" HERDR_ENV=1 FAKE_HERDR_LOG="$root/log"
repo="$root/r"; mkdir -p "$repo/.hq"; git -C "$repo" init -q -b hq/feat
echo autonomy=trusted >"$repo/.hq/runtime"

FAKE_KIND=cursor FAKE_CWD="$repo" bin/hq respawn arch-impl >/dev/null 2>&1
rc=$?; log=$(cat "$FAKE_HERDR_LOG")
assert_eq "$rc" 0 "respawn exits 0"
assert_contains "$log" '"agent","get","arch-impl"' "looks up the agent"
assert_contains "$log" '"agent","start","arch-impl","--kind","cursor","--pane","w9:p5"' "restarts in same pane"
assert_contains "$log" '"--force","--trust"' "keeps trusted flags on hq/* branch"
assert_contains "$log" "roles/implementer.md" "re-sends role prompt"

: >"$FAKE_HERDR_LOG"
rm -f "$FAKE_HERDR_LOG".get.*
FAKE_KIND=cursor FAKE_CWD="$repo" FAKE_STATUS=blocked FAKE_STATUS_READS=2 bin/hq respawn arch-impl >/dev/null 2>&1
log=$(cat "$FAKE_HERDR_LOG")
assert_contains "$log" '"agent","wait","arch-impl","--until","idle","--until","done"' "respawn waits for a ready agent"

# agent exited: find its pane by label and start it again
: >"$FAKE_HERDR_LOG"; rm -f "$FAKE_HERDR_LOG".get.*
out=$(FAKE_KIND=claude FAKE_CWD="$repo" FAKE_STATUS=gone FAKE_STATUS_READS=1 FAKE_PANE_LABEL=arch-specrev bin/hq respawn arch-specrev 2>&1); rc=$?
log=$(cat "$FAKE_HERDR_LOG")
assert_eq "$rc" 0 "respawn of an exited agent exits 0"
assert_contains "$log" '"agent","start","arch-specrev","--kind","copilot","--pane","w9:p5"' "exited agent restarted in its labelled pane"
: >"$FAKE_HERDR_LOG"; rm -f "$FAKE_HERDR_LOG".get.*
out=$(FAKE_STATUS=gone FAKE_STATUS_READS=9 bin/hq respawn arch-specrev 2>&1); rc=$?
assert_eq "$rc" 1 "no agent and no labelled pane fails"
assert_contains "$out" "no live agent or pane labelled arch-specrev" "clear error without a pane"

out=$(bin/hq respawn arch-manager 2>&1); assert_contains "$out" "not the manager" "refuses manager"
out=$(bin/hq respawn arch-bogus 2>&1); assert_contains "$out" "unknown role" "refuses unknown role"
out=$(bin/hq respawn 2>&1); assert_contains "$out" "usage: hq respawn" "usage"
rm -rf "$root"
finish
