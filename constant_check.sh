#!/usr/bin/env bash
# ============================================================================
# constant_check.sh — run CONST_CHECK.bend and fail the gate on any FAIL
# line. Replaces the old div-window manifest: every statutory constant is
# now pinned exactly (the old windows tolerated ±9999 dollars of drift).
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"
BEND="${BEND:-$HOME/.bend/bin/bend}"

out=$("$BEND" bend/CONST_CHECK.bend 2>&1)
rc=$?
printf '%s\n' "$out"

if [ $rc -ne 0 ]; then
  echo "constant check: bend run failed (exit $rc)"
  exit 1
fi

n_fail=$(printf '%s\n' "$out" | grep -c '^FAIL' || true)
n_pass=$(printf '%s\n' "$out" | grep -c '^PASS' || true)

if [ "$n_fail" -gt 0 ] || [ "$n_pass" -eq 0 ]; then
  echo "constant check: FAIL ($n_fail of $((n_fail + n_pass)) pins wrong or missing)"
  exit 1
fi

echo "constant check: all $n_pass statutory pins exact"
