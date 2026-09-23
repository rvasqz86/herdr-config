#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
root=$(mktemp -d); home="$root/home"; mkdir -p "$home"
tools="$root/tools"; mkdir -p "$tools"
for t in claude omp; do printf '#!/bin/sh\n' >"$tools/$t"; chmod +x "$tools/$t"; done
export FAKE_HERDR_LOG="$root/log"
run() { HQ_LOCAL="$root/hq.local" HOME="$home" PATH="$PWD/tests/fake-herdr:$tools:/usr/bin:/bin" bash bin/bootstrap 2>&1; }

out=$(run); rc=$?
assert_eq "$rc" 0 "bootstrap exits 0"
assert_eq "$(readlink "$home/.local/bin/hq")" "$PWD/bin/hq" "links hq into ~/.local/bin"
log=$(cat "$FAKE_HERDR_LOG")
assert_contains "$log" '["integration","install","claude"]' "installs claude integration"
assert_contains "$log" '["integration","install","omp"]' "installs omp integration"
assert_not_contains "$log" '"install","copilot"' "skips tools that are not installed"
assert_contains "$out" "copilot not installed" "says which tools it skipped"
assert_contains "$out" "not on your PATH" "warns when ~/.local/bin is not on PATH"

assert_eq "$(cat "$root/hq.local")" "$(cat hq.local.example)" "creates hq.local from the example"
assert_contains "$out" "hq.local" "points at hq.local for missing tools"
echo 'code_tools=omp' >"$root/hq.local"
out=$(run); rc=$?
assert_eq "$rc" 0 "bootstrap is re-runnable"
assert_eq "$(readlink "$home/.local/bin/hq")" "$PWD/bin/hq" "link still correct on re-run"
assert_eq "$(cat "$root/hq.local")" "code_tools=omp" "never overwrites an existing hq.local"

echo "#!/bin/sh" >"$home/.local/bin/hq.tmp"; rm "$home/.local/bin/hq"; mv "$home/.local/bin/hq.tmp" "$home/.local/bin/hq"
out=$(run); rc=$?
assert_eq "$rc" 1 "refuses to replace a real file at ~/.local/bin/hq"
assert_contains "$out" "is not a link" "explains the refusal"

out=$(HOME="$home" PATH="$tools:/usr/bin:/bin" bash bin/bootstrap 2>&1); rc=$?
assert_eq "$rc" 1 "fails without herdr"
assert_contains "$out" "https://herdr.dev/install.sh" "points to the herdr installer"
rm -rf "$root"
finish
