FAILS=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; FAILS=$((FAILS + 1)); }
assert_eq() { # got want name
  if [ "$1" == "$2" ]; then ok "$3"; else bad "$3 (got '$1', want '$2')"; fi
}
assert_contains() { # haystack needle name
  if grep -qF -- "$2" <<<"$1"; then ok "$3"; else bad "$3 (missing '$2')"; fi
}
assert_not_contains() { # haystack needle name
  if grep -qF -- "$2" <<<"$1"; then bad "$3 (unexpected '$2')"; else ok "$3"; fi
}
finish() { if [ "$FAILS" -eq 0 ]; then echo PASS; else echo "$FAILS failed"; exit 1; fi; }
