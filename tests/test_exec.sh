#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
root=$(mktemp -d)
export PATH="$PWD/tests/fake-herdr:$PATH" HERDR_ENV=1 FAKE_HERDR_LOG="$root/log" HQ_LOCAL="$root/none"
co="$root/my co"; mkdir -p "$co"
canary="$root/pwned"
q="Should we raise prices? \$(touch $canary) \`touch $canary\`
second line"

bin/hq exec "$co" "$q" acme >/dev/null 2>&1
rc=$?; log=$(cat "$FAKE_HERDR_LOG")
assert_eq "$rc" 0 "hq exec exits 0"
[ -d "$co/.git" ] && ok "git init on a plain folder" || bad "git init on a plain folder"
assert_eq "$(git -C "$co" symbolic-ref --short HEAD)" main "new repo starts on main"
assert_contains "$log" '"workspace","create","--cwd","'"$co"'","--label","acme"' "workspace in path with spaces"
assert_contains "$log" '"tab","rename","w9:t1","exec"' "first tab is exec"
assert_contains "$log" '"pane","split","w9:p1","--direction","right","--ratio","0.6"' "ceo keeps 60% of the exec tab"
assert_eq "$(grep -c '"pane","split"' <<<"$log")" 2 "two splits: cto column, coo below it"
assert_contains "$log" '"tab","create","--workspace","w9","--cwd","'"$co"'","--label","shell"' "shell tab"
assert_contains "$log" '"pane","rename","w9:p1","acme-ceo"' "ceo pane labelled"
for r in cto coo; do
  grep -qE '^\["pane","rename","w9:p[0-9]+","acme-'"$r"'"\]$' <<<"$log" && ok "pane labelled acme-$r" || bad "pane not labelled acme-$r"
done
assert_contains "$log" '"shell"]' "shell pane labelled"
for pair in ceo:claude cto:omp coo:copilot; do
  assert_contains "$log" '"agent","start","acme-'"${pair%%:*}"'","--kind","'"${pair#*:}"'"' "starts ${pair%%:*} as ${pair#*:}"
  grep -F '"agent","start","acme-'"${pair%%:*}"'"' <<<"$log" | grep -qF '"--add-dir","'"$PWD/roles"'"' &&
    ok "${pair%%:*} may read the roles dir" || bad "${pair%%:*} not given --add-dir roles"
done
assert_not_contains "$log" '--auto-approve' "no autonomy flags"
assert_eq "$(grep -c '"agent","prompt"' <<<"$log")" 3 "three first prompts"
assert_contains "$log" "roles/cto.md" "cto gets its role file"
assert_contains "$log" "until the CEO sends you" "crew wait for the CEO"
ceo=$(grep '"agent","prompt","acme-ceo"' <<<"$log")
assert_contains "$ceo" "roles/ceo.md" "ceo gets its role file"
assert_contains "$ceo" "Company root: $co" "ceo told the company root"
assert_contains "$ceo" "Execs: acme-cto (omp), acme-coo (copilot)" "ceo told the execs and their tools"
assert_contains "$ceo" "Mode: new" "ceo told the mode"
assert_contains "$ceo" '$(touch' "question passed verbatim"
assert_contains "$ceo" 'second line' "multi-line question kept"
assert_not_contains "$ceo" '"--wait"' "ceo prompt does not block hq"
[ -e "$canary" ] && bad "question was executed" || ok "question not executed"
assert_contains "$log" '"workspace","focus","w9"' "workspace focused"

# no question, default label
: >"$FAKE_HERDR_LOG"
bin/hq exec "$co" >/dev/null 2>&1; rc=$?
assert_eq "$rc" 0 "hq exec without a question exits 0"
assert_contains "$(cat "$FAKE_HERDR_LOG")" '"--label","my co"' "label defaults to the folder name"
assert_contains "$(grep '"agent","prompt","my-co-ceo"' "$FAKE_HERDR_LOG")" "Question:" "ceo prompt still has a Question line"

# an existing repo is left on its branch
git -C "$co" checkout -q -b founder-notes
: >"$FAKE_HERDR_LOG"
bin/hq exec "$co" "q" acme >/dev/null 2>&1
assert_eq "$(git -C "$co" symbolic-ref --short HEAD)" founder-notes "existing repo branch untouched"

# tools from company/settings, hq.local, env; bad kind stops before any layout
mkdir -p "$co/company"; echo 'kind_cto=claude' >"$co/company/settings"
: >"$FAKE_HERDR_LOG"
bin/hq exec "$co" "q" acme >/dev/null 2>&1
assert_contains "$(cat "$FAKE_HERDR_LOG")" '"acme-cto","--kind","claude"' "cto tool from company/settings"
echo 'kind_coo=cursor' >"$root/local"
: >"$FAKE_HERDR_LOG"
HQ_LOCAL="$root/local" bin/hq exec "$co" "q" acme >/dev/null 2>&1
assert_contains "$(cat "$FAKE_HERDR_LOG")" '"acme-coo","--kind","cursor"' "coo tool from hq.local"
: >"$FAKE_HERDR_LOG"
HQ_KIND_coo=omp HQ_LOCAL="$root/local" bin/hq exec "$co" "q" acme >/dev/null 2>&1
assert_contains "$(cat "$FAKE_HERDR_LOG")" '"acme-coo","--kind","omp"' "env wins for coo"
echo 'kind_cto=bogus' >"$co/company/settings"
: >"$FAKE_HERDR_LOG"
out=$(bin/hq exec "$co" "q" acme 2>&1); rc=$?
assert_eq "$rc" 1 "bad kind exits 1"
assert_contains "$out" "bogus" "bad kind named"
assert_not_contains "$(cat "$FAKE_HERDR_LOG")" '"workspace","create"' "no layout with a bad kind"
rm "$co/company/settings"

# --resume needs a brief
: >"$FAKE_HERDR_LOG"
out=$(bin/hq exec --resume "$co" 2>&1); rc=$?
assert_eq "$rc" 1 "resume without brief exits 1"
assert_contains "$out" "company/brief.md" "resume names the missing brief"
assert_not_contains "$(cat "$FAKE_HERDR_LOG")" '"workspace","create"' "no layout without a brief"
echo '# Brief' >"$co/company/brief.md"
: >"$FAKE_HERDR_LOG"
bin/hq exec --resume "$co" acme >/dev/null 2>&1; rc=$?
assert_eq "$rc" 0 "resume exits 0"
assert_contains "$(grep '"agent","prompt","acme-ceo"' "$FAKE_HERDR_LOG")" "Mode: resume" "ceo told to resume"

# label in use
: >"$FAKE_HERDR_LOG"
out=$(FAKE_AGENTS="acme-ceo acme-cto" bin/hq exec "$co" "q" acme 2>&1); rc=$?
assert_eq "$rc" 1 "label in use refused"
assert_contains "$out" "already running" "label in use explained"

# no directory
out=$(bin/hq exec "$root/nope" "q" 2>&1); rc=$?
assert_eq "$rc" 1 "missing dir exits 1"
# no arguments at all: usage, and the current folder is left alone
plain="$root/plain"; mkdir -p "$plain"
out=$(cd "$plain" && "$OLDPWD/bin/hq" exec 2>&1); rc=$?
assert_eq "$rc" 1 "no-arg hq exec exits 1"
assert_contains "$out" "usage:" "no-arg hq exec prints usage"
[ -d "$plain/.git" ] && bad "no-arg hq exec git-inits the cwd" || ok "no-arg hq exec leaves the cwd alone"
# a failed run never leaves a repo behind
fresh="$root/fresh"; mkdir -p "$fresh"
bin/hq exec --resume "$fresh" >/dev/null 2>&1
[ -d "$fresh/.git" ] && bad "failed resume left a .git" || ok "failed resume leaves no .git"
mkdir -p "$fresh/company"; echo 'kind_cto=bogus' >"$fresh/company/settings"
bin/hq exec "$fresh" "q" >/dev/null 2>&1
[ -d "$fresh/.git" ] && bad "bad kind left a .git" || ok "bad kind leaves no .git"

# picker: exec asks for a question
mkdir -p "$root/development/startup"
: >"$FAKE_HERDR_LOG"
printf 'exec\nstartup\nShould we hire?\n' | HOME=$root bin/hq new >/dev/null 2>&1
assert_contains "$(cat "$FAKE_HERDR_LOG")" '"--cwd","'"$root/development/startup"'"' "picker: exec dir"
assert_contains "$(grep '"agent","prompt","startup-ceo"' "$FAKE_HERDR_LOG")" "Should we hire?" "picker: question reaches the ceo"

rm -rf "$root"
finish
