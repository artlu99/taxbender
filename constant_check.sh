#!/usr/bin/env bash
# ============================================================================
# constant_check.sh — run the runtime exactness gates and fail on any FAIL:
#   CONST_CHECK.bend    every statutory constant pinned exactly
#   TAX_TABLE_CHECK.bend every published Tax Table row value (all statuses,
#                        both endpoints of each of the 2,062 rows)
# Replaces the old drift-tolerant div-window manifest.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"
BEND="${BEND:-$HOME/.bend/bin/bend}"

total_fail=0
total_pass=0

for f in bend/CONST_CHECK.bend bend/TAX_TABLE_CHECK.bend; do
  out=$("$BEND" "$f" 2>&1)
  rc=$?
  if [ $rc -ne 0 ]; then
    printf '%s\n' "$out"
    echo "constant check: bend run of $f failed (exit $rc)"
    exit 1
  fi
  n_fail=$(printf '%s\n' "$out" | grep -c '^FAIL' || true)
  n_pass=$(printf '%s\n' "$out" | grep -c '^PASS' || true)
  total_fail=$((total_fail + n_fail))
  total_pass=$((total_pass + n_pass))
done

if [ "$total_fail" -gt 0 ] || [ "$total_pass" -eq 0 ]; then
  echo "constant check: FAIL ($total_fail of $((total_fail + total_pass)) pins wrong or missing)"
  exit 1
fi

echo "constant check: all $total_pass pins exact (constants + full published Tax Table)"
