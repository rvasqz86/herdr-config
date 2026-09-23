#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
export HERDR_ENV=1
d=$(mktemp -d)
out=$(printf 'a\nb\n' | bin/hq runlog "$d/r.log" 1K)
assert_eq "$out" $'a\nb' "passes output through"
assert_eq "$(cat "$d/r.log")" $'a\nb' "writes the log"
[ -e "$d/r.log.1" ] && bad "rotated too early" || ok "no rotation under half of max"

line=$(printf '%099d' 0)   # 99 chars + newline = 100 bytes
for i in $(seq 1 33); do echo "$line"; done | bin/hq runlog "$d/r.log" 1K >/dev/null
[ -e "$d/r.log.1" ] && ok "rotates at half of max" || bad "no rotation"
total=$(( $(stat -c %s "$d/r.log") + $(stat -c %s "$d/r.log.1") ))
[ "$total" -le 1024 ] && ok "disk use within max ($total bytes)" || bad "disk use $total > 1024"
assert_eq "$(stat -c %s "$d/r.log")" 300 "newest lines kept in the live file"

echo x | bin/hq runlog "$d/r.log" 1K >/dev/null
[ -e "$d/r.log.1" ] && bad "old rotation survives a restart" || ok "restart clears old rotation"
out=$(echo x | bin/hq runlog "$d/r.log" lots 2>&1); assert_contains "$out" "bad size" "rejects bad size"
out=$(echo x | bin/hq runlog 2>&1); assert_contains "$out" "usage:" "requires a path"
# mawk (the Debian/Ubuntu default without gawk) must still stream line by line
nb=$(mktemp -d)
for f in /usr/bin/*; do case ${f##*/} in gawk|awk) ;; *) ln -s "$f" "$nb/${f##*/}" ;; esac; done
[ -x /usr/bin/mawk ] && ln -s /usr/bin/mawk "$nb/awk"
if [ -x /usr/bin/mawk ]; then
  ( echo listening; sleep 3; echo two ) | PATH="$nb" bin/hq runlog "$d/m.log" 1K >/dev/null &
  sleep 1
  assert_eq "$(cat "$d/m.log")" listening "mawk: first line reaches the log immediately"
  wait
else
  ok "mawk not installed — skipped"
fi
rm -rf "$nb"
rm -rf "$d"
finish
