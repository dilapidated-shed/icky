#!/bin/sh

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
idris2_bin=${IDRIS2:-idris2}
boundary_tmp=$(mktemp -d)

cleanup() {
  if [ -n "${boundary_tmp:-}" ] && [ -d "$boundary_tmp" ]; then
    rm -r -- "$boundary_tmp"
  fi
}
trap cleanup EXIT HUP INT TERM

for source in "$project_dir"/src/*.idr; do
  ln -s "$source" "$boundary_tmp/$(basename -- "$source")"
done

expect_rejected() {
  fixture=$1
  expected_text=$2
  fixture_name=$(basename -- "$fixture")
  linked_fixture="$boundary_tmp/$fixture_name"
  log="$boundary_tmp/$fixture_name.log"

  ln -s "$project_dir/$fixture" "$linked_fixture"
  if "$idris2_bin" --check --source-dir "$boundary_tmp" \
       --build-dir "$boundary_tmp/build" "$linked_fixture" >"$log" 2>&1; then
    echo "FAIL: $fixture unexpectedly compiled"
    exit 1
  fi
  if ! grep -F "$expected_text" "$log" >/dev/null; then
    echo "FAIL: $fixture failed for an unexpected reason"
    sed -n '1,120p' "$log"
    exit 1
  fi
  echo "ok: $fixture rejected at its intended type boundary"
}

expect_rejected tests/rejected/ArbitraryName.idr "Name.ValidName is private"
expect_rejected tests/rejected/InvalidDecimal.idr "FromChar DecimalDigit"
expect_rejected tests/rejected/MixedCoordinates.idr "Mismatch between: SourceLine and SourceOffset"
expect_rejected tests/rejected/MixedSeverity.idr "Mismatch between: Fatal and Warning."
expect_rejected tests/rejected/InvalidExpression.idr "FinalPiece -> Expr"
