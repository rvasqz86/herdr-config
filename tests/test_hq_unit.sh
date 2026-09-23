#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
export ROLES_DIR=/r
source bin/hq
set +euo pipefail

assert_eq "$(slug 'Architext')" architext "slug lowercases"
assert_eq "$(slug '2025_Taxes')" taxes "slug strips leading digits"
assert_eq "$(slug '2025')" p2025 "slug gives all-digit labels a letter"
assert_eq "$(slug 'Q4 platform strategy & more')" q4-platform-strategy "slug squeezes and truncates to 20"
long=$(slug 'An extremely long workspace label that goes on and on')
[[ "$long-taskrev" =~ ^[a-z][a-z0-9_-]{0,31}$ ]] && ok "long label yields valid agent name" || bad "invalid agent name: $long-taskrev"

assert_eq "$(role_kind manager)" claude "manager is claude"
assert_eq "$(role_kind planner)" omp "planner is omp"
assert_eq "$(role_kind specrev)" copilot "specrev is copilot"
assert_eq "$(role_kind impl)" cursor "impl is cursor"
assert_eq "$(role_kind taskrev)" claude "taskrev is claude"
role_kind bogus >/dev/null && bad "unknown role accepted" || ok "unknown role rejected"
assert_eq "$(role_file specrev)" /r/spec-review.md "role_file maps specrev"
assert_eq "$(role_file impl)" /r/implementer.md "role_file maps impl"

tmp=$(mktemp -d)
assert_eq "$(runtime_get "$tmp" dev)" "" "runtime_get empty without file"
mkdir -p "$tmp/.hq"
printf 'dev=npm run dev\nerrors=(Error|panic)\nautonomy=trusted   # comment\n' >"$tmp/.hq/runtime"
assert_eq "$(runtime_get "$tmp" dev)" "npm run dev" "runtime_get reads value"
assert_eq "$(runtime_get "$tmp" errors)" "(Error|panic)" "runtime_get keeps regex"
assert_eq "$(runtime_get "$tmp" autonomy)" trusted "runtime_get strips trailing comment"

git -C "$tmp" init -q -b main
assert_eq "$(current_branch "$tmp")" main "current_branch"

assert_eq "$(agent_flags claude ask hq/x)" "" "ask mode: no flags"
assert_eq "$(agent_flags claude trusted main)" "" "trusted off hq/* branch: no flags"
assert_eq "$(agent_flags claude trusted hq/x | paste -sd' ')" '--dangerously-skip-permissions --settings {"skipDangerousModePermissionPrompt":true}' "claude trusted flags skip the bypass confirmation"
assert_eq "$(agent_flags omp trusted hq/x)" --auto-approve "omp trusted flag"
assert_eq "$(agent_flags copilot trusted hq/x)" --allow-all-tools "copilot trusted flag"
assert_eq "$(agent_flags cursor trusted hq/x | paste -sd' ')" "--force --trust" "cursor trusted flags"

assert_eq "$(size_bytes 20M)" 20971520 "size_bytes M"
assert_eq "$(size_bytes 512K)" 524288 "size_bytes K"
assert_eq "$(size_bytes 1G)" 1073741824 "size_bytes G"
assert_eq "$(size_bytes 1000)" 1000 "size_bytes plain bytes"
assert_eq "$(size_bytes '')" 20971520 "size_bytes default 20M"
size_bytes lots >/dev/null && bad "size_bytes accepted junk" || ok "size_bytes rejects junk"

k=$(mktemp -d); mkdir -p "$k/.hq"
assert_eq "$(kind_for "$k" impl)" cursor "kind_for defaults to role_kind"
printf 'kind_impl=claude\nkind_specrev=omp  # stand-in\n' >"$k/.hq/runtime"
assert_eq "$(kind_for "$k" impl)" claude "kind_for reads kind_<role> from .hq/runtime"
assert_eq "$(kind_for "$k" specrev)" omp "kind_for strips comment"
assert_eq "$(kind_for "$k" planner)" omp "kind_for falls back per role"
assert_eq "$(HQ_KIND_impl=copilot kind_for "$k" impl)" copilot "env HQ_KIND_<role> wins"
echo kind_impl=bogus >"$k/.hq/runtime"
kind_for "$k" impl >/dev/null 2>&1 && bad "kind_for accepted unknown tool" || ok "kind_for rejects unknown tool"
rm -rf "$k"

out=$(env -u HERDR_ENV bash bin/hq code . 2>&1)
assert_contains "$out" "not running inside herdr" "executing still checks HERDR_ENV"
rm -rf "$tmp"
finish
