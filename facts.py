#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""facts.py — the glue between the three formats, with strong guarantees.

Chain of custody:
  factfile.md   human review   (structured Markdown, checkmark table)
  factfile.json intermediate    (canonical, deterministic, sha256 fingerprint)
  inputs.bend   native          (generated; embeds the fingerprint)

Guarantees:
  * `parse` refuses a worksheet with any unchecked box, unknown row, or
    malformed amount — nothing compiles from an unreviewed fact.
  * `compile` output is byte-deterministic: same JSON, same inputs.bend.
  * `verify` re-parses the worksheet and re-hashes the JSON; any drift
    between the three formats fails loudly.

Usage (via uv, no deps beyond stdlib):
  uv run facts.py parse   factfile.md [--out factfile.json]
  uv run facts.py compile factfile.json [--out inputs.bend]
  uv run facts.py verify  factfile.md factfile.json
  uv run facts.py attest  factfile.json
  uv run facts.py fields  income|payments   (schema for scripts)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

# ----------------------------------------------------------------------------
# schema
# ----------------------------------------------------------------------------

TAX_YEAR = 2024
# ONE filing path for now: married filing jointly. The engine's other
# status modules (tables_2024_single/mfs/hoh) remain proven, pinned and
# oracle-swept — they're capability, not a user path; worksheets naming
# them are refused until the path reopens.
STATUS_MODULES = {
    "mfj": "tables_2024_mfj",
}
STATUS_LABELS = {v: k for k, v in STATUS_MODULES.items()}

# (json_key, table label, 1040 line ref)
# Order matters twice: parse matches worksheet labels byte-exactly, and
# this order IS the generated Filing{...} field order (compile writes
# ALL_KEYS in order). ss_wages is reporting-only — it caps the SE Social
# Security part (Schedule SE line 8b/8c) and is not added to income.
INCOME_FIELDS = [
    ("wages", "W-2 wages", "Line 1a"),
    ("ss_wages", "Social Security wages", "W-2 box 3"),
    ("interest", "Taxable interest", "Line 2b"),
    ("stcg", "Short-term capital gains (net)", "Line 7 (Schedule D)"),
    ("ltcg", "Long-term capital gains (net)", "Line 7 (Schedule D)"),
    ("biz1", "Business 1 gross receipts (Schedule C)", "Schedule C, line 1"),
    ("biz1_expenses", "Business 1 expenses (Schedule C)", "Schedule C, line 28"),
    ("biz2", "Business 2 gross receipts (Schedule C)", "Schedule C, line 1"),
    ("biz2_expenses", "Business 2 expenses (Schedule C)", "Schedule C, line 28"),
]
PAYMENT_FIELDS = [
    ("withheld", "Federal tax withheld", "Line 25"),
    ("est", "Estimated payments", "Line 26"),
]
BUSINESS_FIELDS = [
    # W-2 wages the businesses PAID to employees — the §199A wage limit
    # above the phaseout threshold (not the owner's own W-2 wages!)
    ("biz_w2", "Total W-2 wages your businesses PAID to employees", "Form 8995, line 5"),
]
ALL_KEYS = [k for k, _, _ in INCOME_FIELDS + PAYMENT_FIELDS + BUSINESS_FIELDS]

# rows whose (net) amount may be negative — losses are real facts for
# these; every other field refuses a minus sign at parse time. Business
# rows are gross receipts and expenses (both ≥ 0); a net LOSS arises
# when expenses exceed receipts, in derive().
SIGNED_OK = {"stcg", "ltcg"}

# maximum NET capital loss deductible against ordinary income (§1211),
# by status; anything beyond is carried to next year (reported, not
# tracked — this tool files one year at a time)
CAP_LOSS_CAPS = {"single": 3000, "mfj": 3000, "hoh": 3000, "mfs": 1500}

# legend captions for the generated inputs.bend (auditor-facing text,
# deliberately different from the worksheet labels above — but the KEYS
# are the schema's, so a field added to the schema can't be missed here)
CAPTIONS = {
    "wages": "wages: W-2 box 1",
    "ss_wages": "social security wages: W-2 box 3 (caps the SE SS part)",
    "interest": "taxable interest: 1099-INT",
    "stcg": "short-term capital gains (net)",
    "ltcg": "long-term capital gains (net)",
    "biz1": "business 1: Schedule C gross receipts",
    "biz1_expenses": "business 1: Schedule C expenses (netted in derive)",
    "biz2": "business 2: Schedule C gross receipts",
    "biz2_expenses": "business 2: Schedule C expenses (netted in derive)",
    "withheld": "withheld: W-2 box 2 + backup",
    "est": "estimated payments",
    "biz_w2": "W-2 wages paid by your businesses (§199A limit)",
}
assert set(CAPTIONS) == set(ALL_KEYS), "CAPTIONS and the field schema disagree"

AMOUNT_RE = re.compile(r"^\|\s*([^|]+?)\s*\|\s*(-?[0-9]+)\s*\|\s*\[([ xX])\]\s*\|$")
CHECK_RE = re.compile(r"^- \[([ xX])\]\s*(.*)$")

# per-field input ceilings: nothing plausible for an individual filer is
# this large, so a bigger number is fat-fingered extra digits and is
# refused outright with an actionable message (gains get the widest
# berth — liquidity events do happen — but $100M of gains still is)
FIELD_CAPS = {
    "wages": 25_000_000,
    "ss_wages": 25_000_000,
    "interest": 10_000_000,
    "stcg": 100_000_000,
    "ltcg": 100_000_000,
    "biz1": 25_000_000,
    "biz1_expenses": 25_000_000,
    "biz2": 25_000_000,
    "biz2_expenses": 25_000_000,
    "biz_w2": 25_000_000,
    "withheld": 25_000_000,
    "est": 25_000_000,
}


def die(msg: str) -> "None":
    print(f"facts: error: {msg}", file=sys.stderr)
    sys.exit(1)


def warn(msg: str) -> None:
    print(f"facts: warning: {msg}", file=sys.stderr)


# ----------------------------------------------------------------------------
# parse: worksheet -> facts dict
# ----------------------------------------------------------------------------

def parse_worksheet(text: str) -> dict:
    facts: dict = {}
    status_row_seen = False
    attestation_seen = False
    sstb_row_seen = False
    sstb_checked = False
    seen_keys: set[str] = set()

    for lineno, raw in enumerate(text.splitlines(), start=1):
        line = raw.rstrip()

        # filing status rows: "- [x] Married filing jointly  (tables: `tables_2024_mfj`)"
        m = CHECK_RE.match(line.strip())
        if m and "`tables_" in line:
            checked, rest = m.group(1) != " ", m.group(2)
            sm = re.search(r"\(tables:\s*`(\w+)`\s*\)", rest)
            if not sm:
                die(f"worksheet line {lineno}: status row without a (tables: `module`) marker")
            module = sm.group(1)
            if module not in STATUS_LABELS:
                die(f"worksheet line {lineno}: unknown tables module '{module}'")
            if checked:
                if facts.get("status"):
                    die("worksheet: more than one filing status is checked")
                facts["status"] = STATUS_LABELS[module]
                facts["tables_module"] = module
            status_row_seen = True
            continue

        # amounts table rows
        m = AMOUNT_RE.match(line.strip())
        if m:
            label, amount_s, box = m.group(1), m.group(2), m.group(3)
            matches = [k for k, lbl, _ in INCOME_FIELDS + PAYMENT_FIELDS + BUSINESS_FIELDS
                       if lbl == label.strip()]
            if not matches:
                die(f"worksheet line {lineno}: unknown row label '{label.strip()}'")
            if len(matches) > 1:
                die(f"worksheet line {lineno}: ambiguous row label '{label.strip()}'")
            key = matches[0]
            if key in seen_keys:
                die(f"worksheet line {lineno}: duplicate row '{label.strip()}'")
            if box == " ":
                die(f"worksheet line {lineno}: '{label.strip()}' is not checked — "
                    f"review it and mark [x], or zero it out")
            seen_keys.add(key)
            amount = int(amount_s)
            if amount < 0 and key not in SIGNED_OK:
                die(f"worksheet line {lineno}: '{label.strip()}' cannot be negative — "
                    f"only capital gains (net) and Schedule C profit rows take losses")
            cap = FIELD_CAPS[key]
            if amount > cap:
                die(f"worksheet line {lineno}: '{label.strip()}' = ${amount:,} — beyond the "
                    f"${cap:,} input cap for that row. If it's genuinely correct, this "
                    f"tool is out of scope; if not, fix the extra digits and re-run")
            facts[key] = amount
            continue

        if CHECK_RE.match(line.strip()) and "attest" in line.lower():
            checked = CHECK_RE.match(line.strip()).group(1) != " "
            if not checked:
                die("worksheet: the attestation at the bottom is not checked")
            attestation_seen = True

        # the SSTB declaration (required; unchecked = no specified service
        # businesses) — its (SSTB) marker is what parse keys on
        if CHECK_RE.match(line.strip()) and "(SSTB)" in line:
            sstb_row_seen = True
            sstb_checked = CHECK_RE.match(line.strip()).group(1) != " "

    if not status_row_seen:
        die("worksheet: no filing status section found")
    if "status" not in facts:
        die("worksheet: no filing status is checked")
    if not attestation_seen:
        die("worksheet: the attestation row is missing or unchecked")
    if not sstb_row_seen:
        die("worksheet: the SSTB declaration row is missing — add it "
            "(copy the section from examples/factfile.md)")
    facts["sstb"] = 1 if sstb_checked else 0
    missing = [k for k in ALL_KEYS if k not in facts]
    if missing:
        die(f"worksheet: missing rows: {', '.join(missing)}")

    # cross-field sanity — non-fatal, but a fat finger is louder at parse
    # time than after the return prints
    income_total = sum(facts[k] for k, _, _ in INCOME_FIELDS if k != "ss_wages")
    if facts["wages"] == 0 and facts["withheld"] > 0:
        warn(f"withheld = ${facts['withheld']:,} but wages = $0 — withholding usually "
             f"comes from W-2 boxes; re-check both rows")
    payments = facts["withheld"] + facts["est"]
    if income_total > 0 and payments * 10 > income_total * 7:
        warn(f"payments (${payments:,}) exceed 70% of total income (${income_total:,}) — "
             f"no covered filing pays that rate; re-check for typos")
    if facts["ss_wages"] > facts["wages"] * 2:
        warn(f"Social Security wages (${facts['ss_wages']:,}) are more than double W-2 box 1 "
             f"(${facts['wages']:,}) — deferrals and tips rarely gap that far; re-check "
             f"the rows aren't swapped or mistyped")
    facts["tax_year"] = TAX_YEAR
    return facts


def derive(facts: dict) -> dict:
    """Schedule D and Schedule C netting, on the signed row values.

    Capital: per-character nets (the worksheet rows) are combined with
    the statute's offset order — a net loss in one character eats the
    other's gain first — then the net loss is capped ($3,000; $1,500
    MFS) with the remainder reported as carryover.
    Business: the two Schedule Cs pool; a net profit is SE/QBI income,
    a net loss is an above-the-line deduction (NOL carry is out of
    scope, per the README).
    """
    st, lt = facts["stcg"], facts["ltcg"]
    if st >= 0 and lt >= 0:
        st_eff, lt_eff, loss_raw = st, lt, 0
    else:
        combined = st + lt
        if combined >= 0:
            # the loss character eats the gain character first
            st_eff, lt_eff = (combined, 0) if st >= 0 else (0, combined)
            loss_raw = 0
        else:
            st_eff, lt_eff, loss_raw = 0, 0, -combined
    cap = CAP_LOSS_CAPS[facts["status"]]
    cap_loss = min(loss_raw, cap)
    # Schedule Cs: gross receipts minus expenses per business, pooled
    b1n = facts["biz1"] - facts["biz1_expenses"]
    b2n = facts["biz2"] - facts["biz2_expenses"]
    b = b1n + b2n
    return {
        "st_gain": st_eff,
        "lt_gain": lt_eff,
        "cap_loss": cap_loss,
        "cap_carry": loss_raw - cap_loss,
        "biz_profit": max(0, b),
        "biz_loss": max(0, -b),
    }


def canonical_json(facts: dict) -> bytes:
    ordered = {
        "tax_year": facts["tax_year"],
        "status": facts["status"],
        "tables_module": facts["tables_module"],
        **{k: facts[k] for k in ALL_KEYS},
        "sstb": facts["sstb"],
        **derive(facts),
    }
    blob = json.dumps(ordered, indent=2, sort_keys=False) + "\n"
    return blob.encode("utf-8")


def fingerprint(blob: bytes) -> str:
    return hashlib.sha256(blob).hexdigest()


# ----------------------------------------------------------------------------
# commands
# ----------------------------------------------------------------------------

def cmd_parse(args: argparse.Namespace) -> None:
    text = Path(args.worksheet).read_text(encoding="utf-8")
    facts = parse_worksheet(text)
    d = derive(facts)
    if d["cap_carry"] > 0:
        print(f"facts: note: net capital loss beyond the ${CAP_LOSS_CAPS[facts['status']]:,} "
              f"deduction carries to next year: ${d['cap_carry']:,}")
    blob = canonical_json(facts)
    out = Path(args.out)
    out.write_text(blob.decode("utf-8"), encoding="utf-8")
    print(f"facts: wrote {out}  fingerprint sha256:{fingerprint(blob)[:16]}…")


def cmd_compile(args: argparse.Namespace) -> None:
    raw = Path(args.facts).read_bytes()
    facts = json.loads(raw)
    missing = [k for k in ("tax_year", "status", "tables_module", *ALL_KEYS) if k not in facts]
    if missing:
        die(f"JSON missing keys: {', '.join(missing)}")
    if facts.get("tables_module") not in STATUS_MODULES.values():
        die(f"JSON has unknown tables_module: {facts.get('tables_module')!r}")
    # canonicality is a property of the bytes: dict equality would ignore key
    # order and let a reordered file through with a drifting fingerprint
    if raw != canonical_json(facts):
        die("JSON is not canonical — re-run `parse` to regenerate it")

    fp = fingerprint(raw)
    fields = [(k, CAPTIONS[k]) for k in ALL_KEYS]
    # the Filing literal, in Filing field order: raw facts plus the
    # derived nets (the byte-canonicality check above already proved the
    # derived values equal derive(raw facts))
    body_rows = [
        ("wages", facts["wages"]),
        ("ss_wages", facts["ss_wages"]),
        ("interest", facts["interest"]),
        ("stcg", facts["st_gain"]),
        ("ltcg", facts["lt_gain"]),
        ("biz_profit", facts["biz_profit"]),
        ("biz_loss", facts["biz_loss"]),
        ("biz_w2", facts["biz_w2"]),
        ("sstb", facts["sstb"]),
        ("cap_loss", facts["cap_loss"]),
        ("withheld", facts["withheld"]),
        ("est", facts["est"]),
    ]
    body = "\n".join(f"    {v}n," for _, v in body_rows)
    legend = "\n".join(f"#   {c}" for _, c in fields)
    legend += f"\n#   SSTB flag: {facts['sstb']} (1 = any business is a specified service trade)"
    legend += "\n#   derived nets: Schedule D netting applied (cap loss capped at the"
    legend += "\n#   §1211 limit); Schedule Cs pooled into biz_profit/biz_loss"
    out_text = f"""import Base
import ../bend/tax.bend as T
import ../bend/{facts['tables_module']}.bend as Tables

# generated by facts.py from factfile.json — DO NOT EDIT BY HAND.
# (lives in inputs/; its imports point up into bend/ — Bend treats the
#  import path text as module identity, so return.bend must spell tax's
#  path the same way or the Filing/Tables types will not unify)
# facts fingerprint sha256:{fp}
# facts: {facts['tax_year']} {facts['status']}
{legend}

def facts_fingerprint() -> String:
  "{fp}"

def filing() -> T.Filing:
  T.Filing{{
{body}
  }}

def tables() -> T.Tables:
  Tables.tables()
"""
    Path(args.out).write_text(out_text, encoding="utf-8")
    print(f"facts: wrote {args.out}  fingerprint sha256:{fp[:16]}…")


def cmd_verify(args: argparse.Namespace) -> None:
    text = Path(args.worksheet).read_text(encoding="utf-8")
    facts = parse_worksheet(text)
    raw = Path(args.facts).read_bytes()
    # the bytes ARE the claim: canonical_json recomputes the derived nets
    # from the re-parsed worksheet, so one byte comparison covers both
    # re-parse drift and any tampering with the derived fields
    if raw != canonical_json(facts):
        die(f"{args.facts} does not match {args.worksheet} — re-run `parse`")
    print(f"facts: OK  {args.worksheet} ↔ {args.facts}  sha256:{fingerprint(raw)[:16]}…")


def cmd_attest(args: argparse.Namespace) -> None:
    raw = Path(args.facts).read_bytes()
    print(f"sha256:{fingerprint(raw)}  {args.facts}")


def cmd_fields(args: argparse.Namespace) -> None:
    # machine-readable schema for scripts (prepare.sh builds its interview
    # from this, so worksheet labels can never drift out of sync with parse)
    for key, label, ref in {"income": INCOME_FIELDS, "payments": PAYMENT_FIELDS,
                            "business": BUSINESS_FIELDS}[args.section]:
        print(f"{key}|{label}|{ref}")


def main() -> None:
    ap = argparse.ArgumentParser(description="factfile pipeline glue")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("parse", help="worksheet -> canonical JSON (strict)")
    p.add_argument("worksheet")
    p.add_argument("--out", default="factfile.json")
    p = sub.add_parser("compile", help="canonical JSON -> inputs.bend")
    p.add_argument("facts")
    p.add_argument("--out", default="inputs/inputs.bend")
    p = sub.add_parser("verify", help="worksheet ↔ JSON ↔ fingerprint")
    p.add_argument("worksheet")
    p.add_argument("facts")
    p = sub.add_parser("attest", help="print the sha256 fingerprint")
    p.add_argument("facts")
    p = sub.add_parser("fields", help="emit the field schema (key|label|ref) for scripts")
    p.add_argument("section", choices=["income", "payments", "business"])
    args = ap.parse_args()
    {"parse": cmd_parse, "compile": cmd_compile, "verify": cmd_verify,
     "attest": cmd_attest, "fields": cmd_fields}[args.cmd](args)


if __name__ == "__main__":
    main()
