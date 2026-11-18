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
STATUS_MODULES = {
    "single": "tables_2024_single",
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
    ("biz1", "Business 1 net profit (Schedule C)", "Schedule C, line 31"),
    ("biz2", "Business 2 net profit (Schedule C)", "Schedule C, line 31"),
]
PAYMENT_FIELDS = [
    ("withheld", "Federal tax withheld", "Line 25"),
    ("est", "Estimated payments", "Line 26"),
]
ALL_KEYS = [k for k, _, _ in INCOME_FIELDS + PAYMENT_FIELDS]

# legend captions for the generated inputs.bend (auditor-facing text,
# deliberately different from the worksheet labels above — but the KEYS
# are the schema's, so a field added to the schema can't be missed here)
CAPTIONS = {
    "wages": "wages: W-2 box 1",
    "ss_wages": "social security wages: W-2 box 3 (caps the SE SS part)",
    "interest": "taxable interest: 1099-INT",
    "stcg": "short-term capital gains (net)",
    "ltcg": "long-term capital gains (net)",
    "biz1": "Schedule C net profit: business 1",
    "biz2": "Schedule C net profit: business 2",
    "withheld": "withheld: W-2 box 2 + backup",
    "est": "estimated payments",
}
assert set(CAPTIONS) == set(ALL_KEYS), "CAPTIONS and the field schema disagree"

AMOUNT_RE = re.compile(r"^\|\s*([^|]+?)\s*\|\s*([0-9]+)\s*\|\s*\[([ xX])\]\s*\|$")
CHECK_RE = re.compile(r"^- \[([ xX])\]\s*(.*)$")


def die(msg: str) -> "None":
    print(f"facts: error: {msg}", file=sys.stderr)
    sys.exit(1)


# ----------------------------------------------------------------------------
# parse: worksheet -> facts dict
# ----------------------------------------------------------------------------

def parse_worksheet(text: str) -> dict:
    facts: dict = {}
    status_row_seen = False
    attestation_seen = False
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
            matches = [k for k, lbl, _ in INCOME_FIELDS + PAYMENT_FIELDS if lbl == label.strip()]
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
            facts[key] = int(amount_s)
            continue

        if CHECK_RE.match(line.strip()) and "attest" in line.lower():
            checked = CHECK_RE.match(line.strip()).group(1) != " "
            if not checked:
                die("worksheet: the attestation at the bottom is not checked")
            attestation_seen = True

    if not status_row_seen:
        die("worksheet: no filing status section found")
    if "status" not in facts:
        die("worksheet: no filing status is checked")
    if not attestation_seen:
        die("worksheet: the attestation row is missing or unchecked")
    missing = [k for k in ALL_KEYS if k not in facts]
    if missing:
        die(f"worksheet: missing rows: {', '.join(missing)}")
    facts["tax_year"] = TAX_YEAR
    return facts


def canonical_json(facts: dict) -> bytes:
    ordered = {
        "tax_year": facts["tax_year"],
        "status": facts["status"],
        "tables_module": facts["tables_module"],
        **{k: facts[k] for k in ALL_KEYS},
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
    body = "\n".join(f"    {facts[k]}n," for k, _ in fields)
    legend = "\n".join(f"#   {c}" for _, c in fields)
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
    stored = json.loads(raw)
    if facts != stored:
        die(f"{args.facts} does not match {args.worksheet} — re-run `parse`")
    if raw != canonical_json(facts):
        die(f"{args.facts} is not canonical — re-run `parse`")
    print(f"facts: OK  {args.worksheet} ↔ {args.facts}  sha256:{fingerprint(raw)[:16]}…")


def cmd_attest(args: argparse.Namespace) -> None:
    raw = Path(args.facts).read_bytes()
    print(f"sha256:{fingerprint(raw)}  {args.facts}")


def cmd_fields(args: argparse.Namespace) -> None:
    # machine-readable schema for scripts (prepare.sh builds its interview
    # from this, so worksheet labels can never drift out of sync with parse)
    for key, label, ref in {"income": INCOME_FIELDS, "payments": PAYMENT_FIELDS}[args.section]:
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
    p.add_argument("section", choices=["income", "payments"])
    args = ap.parse_args()
    {"parse": cmd_parse, "compile": cmd_compile, "verify": cmd_verify,
     "attest": cmd_attest, "fields": cmd_fields}[args.cmd](args)


if __name__ == "__main__":
    main()
