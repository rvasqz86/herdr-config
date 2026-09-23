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

# herdr releases the old agent a moment after its process exits: wait for that
: >"$FAKE_HERDR_LOG"; rm -f "$FAKE_HERDR_LOG".get.* "$FAKE_HERDR_LOG.paneget"
FAKE_KIND=claude FAKE_CWD="$repo" FAKE_PANE_BUSY_READS=2 HQ_POLL=0 bin/hq respawn arch-taskrev >/dev/null 2>&1
log=$(cat "$FAKE_HERDR_LOG")
gets=$(grep -c '"pane","get","w9:p5"' <<<"$log")
start=$(grep -n '"agent","start","arch-taskrev"' <<<"$log" | cut -d: -f1)
last_get=$(grep -n '"pane","get","w9:p5"' <<<"$log" | tail -1 | cut -d: -f1)
[ "$gets" -ge 3 ] && [ "$last_get" -lt "$start" ] && ok "start waits until herdr releases the old agent" || bad "started before the pane was free (gets=$gets)"

reset() { : >"$FAKE_HERDR_LOG"; rm -f "$FAKE_HERDR_LOG".get.* "$FAKE_HERDR_LOG".paneget "$FAKE_HERDR_LOG".proc "$FAKE_HERDR_LOG".reads; }

# role prompt not delivered → respawn fails loudly
reset
out=$(FAKE_KIND=cursor FAKE_CWD="$repo" FAKE_PROMPT_FAIL=1 bin/hq respawn arch-impl 2>&1); rc=$?
assert_eq "$rc" 1 "respawn exits 1 when the role prompt fails"
assert_contains "$out" "arch-impl did not take its role prompt" "respawn says why"

# old session text is cleared before the new agent starts
reset
FAKE_KIND=cursor FAKE_CWD="$repo" bin/hq respawn arch-impl >/dev/null 2>&1; log=$(cat "$FAKE_HERDR_LOG")
clear=$(grep -n '"pane","run","w9:p5","clear"' <<<"$log" | cut -d: -f1)
start=$(grep -n '"agent","start","arch-impl"' <<<"$log" | cut -d: -f1)
[ -n "$clear" ] && [ "$clear" -lt "$start" ] && ok "pane cleared before the new agent starts" || bad "pane not cleared before start"

# the agent exits between the check and the kill: respawn carries on
reset
out=$(FAKE_KIND=cursor FAKE_CWD="$repo" FAKE_PROC_BUSY_READS=2 HQ_POLL=0 bin/hq respawn arch-impl 2>&1); rc=$?
assert_eq "$rc" 0 "failed kill does not abort respawn"
assert_contains "$(cat "$FAKE_HERDR_LOG")" '"agent","start","arch-impl"' "agent restarted after a failed kill"

# label fallback prefers the caller's workspace
reset
FAKE_KIND=claude FAKE_CWD="$repo" FAKE_STATUS=gone FAKE_STATUS_READS=1 FAKE_PANE_LABEL=arch-specrev FAKE_PANE_DUP=1 HERDR_WORKSPACE_ID=w9 \
  bin/hq respawn arch-specrev >/dev/null 2>&1
assert_contains "$(cat "$FAKE_HERDR_LOG")" '"agent","start","arch-specrev","--kind","copilot","--pane","w9:p5"' "label fallback uses the current workspace"
reset
out=$(FAKE_STATUS=gone FAKE_STATUS_READS=1 FAKE_PANE_LABEL=arch-specrev FAKE_PANE_DUP=1 HERDR_WORKSPACE_ID=w5 bin/hq respawn arch-specrev 2>&1); rc=$?
assert_eq "$rc" 1 "ambiguous label outside the current workspace fails"
assert_contains "$out" "2 panes are labelled arch-specrev" "ambiguous label message"

out=$(bin/hq respawn arch-manager 2>&1); assert_contains "$out" "not the manager" "refuses manager"
out=$(bin/hq respawn arch-bogus 2>&1); assert_contains "$out" "unknown role" "refuses unknown role"
out=$(bin/hq respawn 2>&1); assert_contains "$out" "usage: hq respawn" "usage"
rm -rf "$root"
finish
