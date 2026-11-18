#!/usr/bin/env bash
# ============================================================================
# manifest_check.sh — pins the tall statutory floors (the six-digit ones)
# that overflow the checker when batched with anything else. Each law runs
# as its own one-file checker process. Div-by-10000 windows: ±9999 dollars,
# and every floor above a drift is shifted by it, so windows conspire
# against silent edits.
#
# Values (2024, Rev. Proc. 2023-34): single F3 100525, F4 191950, F5 243725,
# F6 609350, T2 518900; mfj F3 201050, F4 383900, F5 487450, F6 731200,
# T2 583750.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"
BEND="${BEND:-$HOME/.bend/bin/bend}"
BEND_DIR="$(pwd)/bend"

# alias | law name | expression | expected quotient
LAWS=(
  "S|manifest_single_w2|Nat.div(S.F2(), 10000n)|4"
  "S|manifest_single_w3|Nat.div(S.F3(), 10000n)|10"
  "S|manifest_single_w4|Nat.div(S.F4(), 10000n)|19"
  "S|manifest_single_w5|Nat.div(S.F5(), 10000n)|24"
  "S|manifest_single_w6|Nat.div(S.F6(), 10000n)|60"
  "S|manifest_single_t2|Nat.div(S.T2(), 10000n)|51"
  "M|manifest_mfj_w2|Nat.div(M.F2(), 10000n)|9"
  "M|manifest_mfj_w3|Nat.div(M.F3(), 10000n)|20"
  "M|manifest_mfj_w4|Nat.div(M.F4(), 10000n)|38"
  "M|manifest_mfj_w5|Nat.div(M.F5(), 10000n)|48"
  "M|manifest_mfj_w6|Nat.div(M.F6(), 10000n)|73"
  "M|manifest_mfj_t2|Nat.div(M.T2(), 10000n)|58"
)

fail=0
for row in "${LAWS[@]}"; do
  IFS='|' read -r alias name expr val <<< "$row"
  f="$BEND_DIR/.manifest_$name.bend"
  cat > "$f" <<EOF
import Base
import ./tables_2024_single.bend as S
import ./tables_2024_mfj.bend as M

law $name: {$expr == ${val}n : Nat}
def $name(): {==}
EOF
  if "$BEND" "$f" > /dev/null 2>&1; then
    echo "PASS $name ($expr == ${val}n)"
  else
    echo "FAIL $name ($expr == ${val}n)"
    fail=1
  fi
  rm -f "$f"
done
exit $fail
