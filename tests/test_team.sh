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
: >"$FAKE_HERDR_LOG"; rm -f "$FAKE_HERDR_LOG".get.*; mkdir -p "$repo/.hq"; echo autonomy=trusted >"$repo/.hq/runtime"
git -C "$repo" checkout -q -b hq/x
bin/hq team "$repo" "b" arch >/dev/null 2>&1; log=$(cat "$FAKE_HERDR_LOG")
assert_contains "$log" '"arch-impl","--kind","cursor","--pane","w9:p' "impl started"
assert_contains "$log" '"--force","--trust"' "cursor trusted flags"
assert_contains "$log" '"--allow-all-tools"' "copilot trusted flag"
assert_not_contains "$(grep '"arch-manager","--kind"' <<<"$log")" "--dangerously" "manager never trusted"

# duplicate label fails before building anything
: >"$FAKE_HERDR_LOG"; rm -f "$FAKE_HERDR_LOG".get.*
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
: >"$FAKE_HERDR_LOG"; rm -f "$FAKE_HERDR_LOG".get.*; mkdir -p "$repo/.hq"; echo phase=tasks >"$repo/.hq/state"
bin/hq team --resume "$repo" arch >/dev/null 2>&1; log=$(cat "$FAKE_HERDR_LOG")
assert_contains "$log" 'Mode: resume' "resume mode passed to manager"
# role prompts only go to ready agents; all agents start before any prompt
: >"$FAKE_HERDR_LOG"; rm -f "$FAKE_HERDR_LOG".get.*; rm -rf "$repo/.hq"; git -C "$repo" symbolic-ref HEAD refs/heads/main
bin/hq team "$repo" "b" arch >/dev/null 2>&1; log=$(cat "$FAKE_HERDR_LOG")
last_start=$(grep -n '"agent","start"' <<<"$log" | tail -1 | cut -d: -f1)
first_prompt=$(grep -n '"agent","prompt"' <<<"$log" | head -1 | cut -d: -f1)
[ "$last_start" -lt "$first_prompt" ] && ok "all agents start before the first prompt" || bad "prompt at line $first_prompt before start at $last_start"
assert_contains "$log" '"agent","get","arch-planner"' "checks readiness before prompting"
assert_not_contains "$log" '"agent","wait"' "idle agents are prompted without waiting"

: >"$FAKE_HERDR_LOG"; rm -f "$FAKE_HERDR_LOG".get.*
out=$(FAKE_STATUS=blocked bin/hq team "$repo" "b" arch 2>&1); log=$(cat "$FAKE_HERDR_LOG")
assert_contains "$log" '"notification","show","arch-planner needs you"' "blocked agent: notify the human"
assert_contains "$log" '"agent","wait","arch-planner","--until","idle","--until","done"' "blocked agent: wait until ready"
assert_contains "$out" "startup screen" "blocked agent: says why it waits"
wait_line=$(grep -n '"agent","wait","arch-planner"' <<<"$log" | cut -d: -f1)
prompt_line=$(grep -n '"agent","prompt","arch-planner"' <<<"$log" | cut -d: -f1)
[ "$wait_line" -lt "$prompt_line" ] && ok "blocked agent: prompt only after the wait" || bad "prompted before waiting"

: >"$FAKE_HERDR_LOG"; rm -f "$FAKE_HERDR_LOG".get.*
out=$(FAKE_STATUS=gone bin/hq team "$repo" "b" arch 2>&1); rc=$?; log=$(cat "$FAKE_HERDR_LOG")
assert_eq "$rc" 0 "missing agent does not abort hq"
assert_not_contains "$log" '"agent","prompt"' "missing agent: nothing typed into its pane"
assert_contains "$out" "arch-manager is not running" "missing agent: reported"
# herdr reports agents on trust/login screens as idle: hq must read the screen
for screen in "❯ No, exit
   Yes, I trust this folder" "Press any key to log in..." "2. Yes, and remember this folder for future sessions" \
  "WARNING: Claude Code running in Bypass Permissions mode"; do
  : >"$FAKE_HERDR_LOG"; rm -f "$FAKE_HERDR_LOG".get.*; rm -f "$FAKE_HERDR_LOG.reads"
  out=$(FAKE_SCREEN="$screen" FAKE_SCREEN_READS=2 HQ_POLL=0 bin/hq team "$repo" "b" arch 2>&1); log=$(cat "$FAKE_HERDR_LOG")
  first=$(head -1 <<<"$screen")
  assert_contains "$out" "startup screen" "idle-but-on-startup-screen detected: $first"
  assert_contains "$log" '"notification","show","arch-planner needs you"' "startup screen notifies: $first"
  reads=$(grep -c '"agent","read","arch-planner"' <<<"$log")
  prompt_line=$(grep -n '"agent","prompt","arch-planner"' <<<"$log" | cut -d: -f1)
  last_read=$(grep -n '"agent","read","arch-planner"' <<<"$log" | tail -1 | cut -d: -f1)
  [ "$reads" -ge 2 ] && [ "$last_read" -lt "$prompt_line" ] && ok "prompt only after the screen clears: $first" || bad "prompted while on startup screen ($first): reads=$reads"
done
# per-project tool override flows into agent start and the manager's crew list
: >"$FAKE_HERDR_LOG"; rm -f "$FAKE_HERDR_LOG".get.* "$FAKE_HERDR_LOG.reads"; mkdir -p "$repo/.hq"; echo kind_impl=claude >"$repo/.hq/runtime"
bin/hq team "$repo" "b" arch >/dev/null 2>&1; log=$(cat "$FAKE_HERDR_LOG")
assert_contains "$log" '"agent","start","arch-impl","--kind","claude"' "kind override used for impl"
assert_contains "$log" 'arch-impl (claude)' "manager told the real impl tool"
rm -rf "$repo/.hq"
rm -rf "$root"
finish
