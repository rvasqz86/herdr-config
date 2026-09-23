#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
root=$(mktemp -d)
export PATH="$PWD/tests/fake-herdr:$PATH" HERDR_ENV=1 FAKE_HERDR_LOG="$root/log" HQ_LOCAL="$root/none"

# Every agent pane is labelled with its tool, so the borders say which is which.
bin/hq code "$root" arch >/dev/null 2>&1
rc=$?; log=$(cat "$FAKE_HERDR_LOG")
assert_eq "$rc" 0 "hq code exits 0"
for tool in claude omp copilot cursor; do
  grep -qE '^\["pane","rename","w9:p[0-9]+","'"$tool"'"\]$' <<<"$log" && ok "code: pane labelled $tool" || bad "code: pane not labelled $tool"
  assert_contains "$log" '"agent","start","arch-'"$tool"'","--kind","'"$tool"'"' "code: starts $tool"
done
assert_eq "$(grep -c '"pane","rename"' <<<"$log")" 6 "code: shells labelled too"

: >"$FAKE_HERDR_LOG"
bin/hq docs "$root" notes >/dev/null 2>&1
rc=$?; log=$(cat "$FAKE_HERDR_LOG")
assert_eq "$rc" 0 "hq docs exits 0"
assert_contains "$log" '"pane","rename","w9:p1","writer · claude"' "docs: writer labelled"
grep -qE '^\["pane","rename","w9:p[0-9]+","review · omp"\]$' <<<"$log" && ok "docs: reviewer labelled" || bad "docs: reviewer not labelled"
assert_contains "$log" '"shell"]' "docs: shell labelled"

# hq.local picks the tools on machines without some of them
printf 'code_tools=omp copilot cursor\ndocs_writer=omp\ndocs_reviewer=copilot\n' >"$root/local"
: >"$FAKE_HERDR_LOG"
HQ_LOCAL="$root/local" bin/hq code "$root" arch >/dev/null 2>&1
rc=$?; log=$(cat "$FAKE_HERDR_LOG")
assert_eq "$rc" 0 "code with 3 tools exits 0"
assert_eq "$(grep -c '"pane","split"' <<<"$log")" 3 "3 tools: two splits for agents, one for shells"
assert_not_contains "$log" '"--kind","claude"' "3 tools: no claude"
assert_contains "$log" '"pane","rename","w9:p1","omp"' "3 tools: first tool in the root pane"
for tool in omp copilot cursor; do assert_contains "$log" '"agent","start","arch-'"$tool"'"' "3 tools: starts $tool"; done
: >"$FAKE_HERDR_LOG"
HQ_LOCAL="$root/local" bin/hq docs "$root" notes >/dev/null 2>&1
log=$(cat "$FAKE_HERDR_LOG")
assert_contains "$log" '"writer · omp"' "docs_writer from hq.local"
assert_contains "$log" '"notes-writer","--kind","omp"' "docs writer started as omp"
assert_contains "$log" '"notes-review","--kind","copilot"' "docs_reviewer from hq.local"
echo 'code_tools=nope' >"$root/local"
: >"$FAKE_HERDR_LOG"
out=$(HQ_LOCAL="$root/local" bin/hq code "$root" arch 2>&1); rc=$?
assert_eq "$rc" 1 "bad code_tools exits 1"
assert_contains "$out" "nope" "bad code_tools named"
assert_not_contains "$(cat "$FAKE_HERDR_LOG")" '"workspace","create"' "no workspace with bad code_tools"

# hq new: relative answers land under ~/development, ~ and full paths as typed
mkdir -p "$root/development/proj" "$root/elsewhere"
: >"$FAKE_HERDR_LOG"
printf 'code\nproj\n\n' | HOME=$root bin/hq new >/dev/null 2>&1
assert_contains "$(cat "$FAKE_HERDR_LOG")" '"--cwd","'"$root/development/proj"'","--label","proj"' "new: relative dir under ~/development"
: >"$FAKE_HERDR_LOG"
printf 'docs\n~/elsewhere\nmine\n' | HOME=$root bin/hq new >/dev/null 2>&1
assert_contains "$(cat "$FAKE_HERDR_LOG")" '"--cwd","'"$root/elsewhere"'","--label","mine"' "new: ~ path and label"

rm -rf "$root"
finish
