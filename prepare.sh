#!/usr/bin/env bash
# ============================================================================
# prepare.sh — walk a taxpayer through Form 1040: income first, then
# payments, edit-or-accept at every line. Writes factfile.md (the
# human-review worksheet, all boxes checked because you just reviewed
# them), then runs the facts pipeline: worksheet -> factfile.json ->
# inputs.bend -> bend return.bend. The printed return carries the sha256
# fingerprint of your reviewed facts.
# ============================================================================
set -euo pipefail

cd "$(dirname "$0")"
BEND="${BEND:-$HOME/.bend/bin/bend}"
WORKSHEET="factfile.md"  # reviewed worksheet lives in inputs/

# the fields come from facts.py's schema — the same key|label|ref list
# `parse` matches worksheet rows against, so the interview can never drift
# out of sync with what parse accepts. key | label | line ref, 1040 order.
mapfile -t INCOME_FIELDS < <(uv run facts.py fields income)
mapfile -t PAYMENT_FIELDS < <(uv run facts.py fields payments)
mapfile -t BUSINESS_FIELDS < <(uv run facts.py fields business)
[[ ${#INCOME_FIELDS[@]} -gt 0 && ${#PAYMENT_FIELDS[@]} -gt 0 && ${#BUSINESS_FIELDS[@]} -gt 0 ]] \
  || { echo "prepare: could not read the field schema from facts.py" >&2; exit 1; }
FIELDS=("${INCOME_FIELDS[@]}" "${PAYMENT_FIELDS[@]}" "${BUSINESS_FIELDS[@]}")

# ask LABEL LINE CURRENT -> echoes the accepted value (prompts on stderr)
ask() {
  local label="$1" ref="$2" cur="$3" ans
  while true; do
    printf '\n%s (%s)\n' "$label" "$ref" >&2
    printf '  currently [%s] — Enter to accept, or a new whole-dollar amount: ' "$cur" >&2
    read -r ans
    if [[ -z "$ans" ]]; then
      echo "$cur"; return
    fi
    if [[ "$ans" =~ ^-?[0-9]+$ ]]; then
      echo "$ans"; return
    fi
    echo "  Please enter a whole number of dollars (no commas). Loss rows accept a negative amount." >&2
  done
}

echo "============================================================"
echo " 2024 Form 1040 preparation — whole dollars, standard"
echo " deduction only. Press Enter to accept; type a number to edit."
echo "============================================================"

# filing status selects the tables module (2024: four statuses)
while true; do
  printf '\nFiling status — (1) single, (2) married filing jointly,\n'
  printf '  (3) married filing separately, (4) head of household [2]: ' >&2
  read -r status
  case "${status:-2}" in
    1) TABLES_MODULE="tables_2024_single"; STATUS_NAME="single"; break ;;
    2) TABLES_MODULE="tables_2024_mfj"; STATUS_NAME="married filing jointly"; break ;;
    3) TABLES_MODULE="tables_2024_mfs"; STATUS_NAME="married filing separately"; break ;;
    4) TABLES_MODULE="tables_2024_hoh"; STATUS_NAME="head of household"; break ;;
    *) echo "  Choose 1, 2, 3, or 4." >&2 ;;
  esac
done

declare -A VAL
for field in "${FIELDS[@]}"; do
  IFS='|' read -r key label ref <<< "$field"
  VAL["$key"]="$(ask "$label" "$ref" "${VAL[$key]:-0}")"
done

# ---- review pass -----------------------------------------------------------
echo "============================================================" >&2
echo " Review — Enter keeps each value; type a number to change it." >&2
echo "============================================================" >&2
for field in "${FIELDS[@]}"; do
  IFS='|' read -r key label ref <<< "$field"
  VAL["$key"]="$(ask "$label" "$ref" "${VAL[$key]}")"
done

# the SSTB declaration: yes/no, written as the checkbox row parse requires
sstb_box=" "
while true; do
  printf '\nIs any business a specified service trade (SSTB — health, law,\n' >&2
  printf 'consulting, financial services, etc.)? [y/N]: ' >&2
  read -r sstb_ans
  case "${sstb_ans:-n}" in
    [Yy]|[Yy][Ee][Ss]) sstb_box="x"; break ;;
    [Nn]|[Nn][Oo]|"") break ;;
    *) echo "  Answer y or n." >&2 ;;
  esac
done

# ---- write factfile.md (everything checked: you just reviewed it) ----------
status_single_box=" "; status_mfj_box=" "; status_mfs_box=" "; status_hoh_box=" "
[[ "$TABLES_MODULE" == "tables_2024_single" ]] && status_single_box="x"
[[ "$TABLES_MODULE" == "tables_2024_mfj" ]] && status_mfj_box="x"
[[ "$TABLES_MODULE" == "tables_2024_mfs" ]] && status_mfs_box="x"
[[ "$TABLES_MODULE" == "tables_2024_hoh" ]] && status_hoh_box="x"

income_rows=""
for field in "${INCOME_FIELDS[@]}"; do
  IFS='|' read -r key label ref <<< "$field"
  income_rows+="| $label | ${VAL[$key]} | [x] |"$'\n'
done
payment_rows=""
for field in "${PAYMENT_FIELDS[@]}"; do
  IFS='|' read -r key label ref <<< "$field"
  payment_rows+="| $label | ${VAL[$key]} | [x] |"$'\n'
done
business_rows=""
for field in "${BUSINESS_FIELDS[@]}"; do
  IFS='|' read -r key label ref <<< "$field"
  business_rows+="| $label | ${VAL[$key]} | [x] |"$'\n'
done

mkdir -p inputs
cat > "inputs/$WORKSHEET" <<EOF
# 2024 Form 1040 — facts worksheet

## Filing status
- [$status_mfj_box] Married filing jointly  (tables: \`tables_2024_mfj\`)
- [$status_single_box] Single  (tables: \`tables_2024_single\`)
- [$status_mfs_box] Married filing separately  (tables: \`tables_2024_mfs\`)
- [$status_hoh_box] Head of household  (tables: \`tables_2024_hoh\`)

## Income (whole dollars, US\$)

| item | amount | confirmed |
|---|---|---|
$income_rows
## Payments (whole dollars, US\$)

| item | amount | confirmed |
|---|---|---|
$payment_rows
## Businesses (if any)

| item | amount | confirmed |
|---|---|---|
$business_rows
- [$sstb_box] Any business is a specified service trade (SSTB): health, law, accounting, consulting, financial services, performing arts, athletics, or reputation/skill trades
## Attestation

- [x] I attest that every amount above matches my records, and every box is checked.

Facts fingerprint: (computed by \`uv run facts.py parse\`)
EOF

echo
echo "Wrote inputs/$WORKSHEET (status: $STATUS_NAME). Parsing, compiling, computing..."
echo
uv run facts.py parse "inputs/$WORKSHEET" --out inputs/factfile.json
uv run facts.py compile inputs/factfile.json --out inputs/inputs.bend
"$BEND" bend/return.bend
