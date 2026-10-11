#!/bin/sh
# Local producer of exact-head ICKY parser qualification evidence.
# AICI must independently verify/admit the resulting receipts before merge.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
compiler=${IDRIC:?set IDRIC to an explicit, source-built Idric/Idris2 executable}
compiler_revision=${IDRIC_SOURCE_SHA:?set the exact compiler source commit (40 hex)}
idric_prefix=${IDRIC_PREFIX:?set IDRIC_PREFIX to the qualified Idriç library environment}
case "$compiler" in
  /*) ;;
  *) echo 'IDRIC must be an absolute executable path' >&2; exit 2 ;;
esac
case "$compiler_revision" in
  *[!0123456789abcdefABCDEF]*|'')
    echo 'IDRIC_SOURCE_SHA must be a complete hex revision' >&2
    exit 2 ;;
esac
test "${#compiler_revision}" -eq 40 || {
  echo 'IDRIC_SOURCE_SHA must be 40 hex characters' >&2
  exit 2
}
case "$idric_prefix" in
  /*) ;;
  *) echo 'IDRIC_PREFIX must be an absolute source-built prefix' >&2; exit 2 ;;
esac
test -d "$idric_prefix/idris2-0.8.0/prelude-0.8.0" || {
  echo 'Idriç Prelude is absent from declared IDRIC_PREFIX' >&2
  exit 2
}
IDRIS2_PREFIX=$idric_prefix
export IDRIS2_PREFIX
test -x "$compiler" || {
  printf 'qualified compiler not executable: %s\n' "$compiler" >&2
  exit 2
}

cd "$root"
source_revision=$(git rev-parse HEAD)
test -z "$(git status --porcelain --untracked-files=no)" || {
  echo 'tracked ICKY source has local changes; exact revision is not the build' >&2
  exit 1
}
receipt="$root/build/qualification/located-$source_revision"
test ! -e "$receipt" || {
  printf 'refusing to overwrite existing qualification receipt: %s\n' "$receipt" >&2
  exit 1
}
mkdir -p "$receipt"
printf '%s\n' "$source_revision" > "$receipt/icky-source-sha.txt"
printf '%s\n' "$compiler_revision" > "$receipt/idric-source-sha-declared.txt"
printf '%s\n' "$compiler" > "$receipt/idric-executable-path.txt"
printf '%s\n' "$IDRIS2_PREFIX" > "$receipt/idric-prefix.txt"
sha256sum "$compiler" > "$receipt/idric-executable.sha256"
"$compiler" --version > "$receipt/idric-version.txt"
test -s "$receipt/idric-version.txt"

# Every stage uses the named Idriç executable; no system idris2 fallback.
run_logged() {
  log_name=$1
  shift
  if "$@" > "$receipt/$log_name" 2>&1; then
    return 0
  fi
  cat "$receipt/$log_name" >&2
  return 1
}
run_logged icky-build.log "$compiler" --build icky.ipkg
run_logged tests-build.log "$compiler" --build tests.ipkg
run_logged parser-build.log "$compiler" --build icky-parser.ipkg

test -x build/exec/icky-tests
test -x build/exec/icky-parser
sha256sum build/exec/icky-tests build/exec/icky-parser > "$receipt/executables.sha256"

./build/exec/icky-tests > "$receipt/icky-tests.log" 2>&1
IDRIS2="$compiler" sh tests/check-type-boundaries.sh > "$receipt/type-refusals.log" 2>&1
ICKY_PARSER="$root/build/exec/icky-parser" \
  sh tests/check-parser-protocol.sh > "$receipt/parser-protocol.log" 2>&1

test -s "$receipt/icky-tests.log"
test -s "$receipt/type-refusals.log"
grep -Fx 'ICKY parser protocol: identity, UTF-8, warning and rejection PASS' \
  "$receipt/parser-protocol.log" >/dev/null
printf '%s\n' 'LOCAL_PASS (AICI acceptance still required)' > "$receipt/status.txt"
printf 'Local ICKY parser qualification passed for %s\n' "$source_revision"
printf 'Receipts: %s\n' "$receipt"
