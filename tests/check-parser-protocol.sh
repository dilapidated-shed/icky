#!/bin/sh
# Strict execution qualification for the actual built ICKY parser.
set -eu

project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
parser=${ICKY_PARSER:-$project/build/exec/icky-parser}
test -x "$parser" || {
  printf 'ICKY parser is not built: %s\n' "$parser" >&2
  exit 1
}
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

printf 'ICKY-LOCATED\t1\tchar-offset\n' > "$scratch/identity.expected"
"$parser" --identity > "$scratch/identity.actual"
cmp "$scratch/identity.expected" "$scratch/identity.actual"

printf '← image' > "$scratch/valid source"
cat > "$scratch/valid.expected" <<'END_EXPECTED'
ICKY-LOCATED	1	char-offset
ok	1
expr	0	0	1	1	7	1	8
glyph	0.0	0	1	1	1	1	2	←
name	0.1	2	1	3	7	1	8	image
END_EXPECTED
"$parser" --parse "$scratch/valid source" > "$scratch/valid.actual"
cmp "$scratch/valid.expected" "$scratch/valid.actual"


printf 'ICKY-LOCATED\t2\tchar-offset\n' > "$scratch/identity-v2.expected"
"$parser" --identity-v2 > "$scratch/identity-v2.actual"
cmp "$scratch/identity-v2.expected" "$scratch/identity-v2.actual"

# Unicode glyph before an octal-looking C literal:
# ICKY's Nat is ten, but the source spelling 010 must remain recoverable.
printf '← 010' > "$scratch/leading-zero"
cat > "$scratch/leading-zero.expected" <<'END_NUMERAL'
ICKY-LOCATED	2	char-offset
ok	1
expr	0	0	1	1	5	1	6
glyph	0.0	0	1	1	1	1	2	←
natural	0.1	2	1	3	5	1	6	10
spelling	0.1	2	1	3	5	1	6	010
END_NUMERAL
"$parser" --parse-v2 "$scratch/leading-zero" > "$scratch/leading-zero.actual"
cmp "$scratch/leading-zero.expected" "$scratch/leading-zero.actual"

printf 'image |> resize' > "$scratch/alias"
cat > "$scratch/alias.expected" <<'END_ALIAS'
ICKY-LOCATED	1	char-offset
ok	1
expr	0	0	1	1	15	1	16
name	0.0	0	1	1	5	1	6	image
glyph	0.1	6	1	7	8	1	9	·
name	0.2	9	1	10	15	1	16	resize
warning	6	1	7	8	1	9	ascii-pipeline
END_ALIAS
"$parser" --parse "$scratch/alias" > "$scratch/alias.actual"
cmp "$scratch/alias.expected" "$scratch/alias.actual"

printf 'image -> resize' > "$scratch/invalid"
if "$parser" --parse "$scratch/invalid" > "$scratch/invalid.actual"; then
  printf 'ICKY accepted a C arrow outside its grammar\n' >&2
  exit 1
fi
grep -F 'ICKY-LOCATED' "$scratch/invalid.actual" >/dev/null
grep -F 'error' "$scratch/invalid.actual" >/dev/null
grep -F 'fatal' "$scratch/invalid.actual" >/dev/null
if grep -F 'ok' "$scratch/invalid.actual" >/dev/null; then
  printf 'ICKY printed successful records after rejecting input\n' >&2
  exit 1
fi

if "$parser" --parse "$scratch/does-not-exist" > "$scratch/missing.actual"; then
  printf 'ICKY accepted a missing source path\n' >&2
  exit 1
fi
grep -F 'io-error' "$scratch/missing.actual" >/dev/null

printf 'ICKY parser protocol: identity, UTF-8, warning and rejection PASS\n'
printf 'ICKY parser v2: written numeral and Unicode character spans PASS\n'
