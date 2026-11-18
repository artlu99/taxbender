#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""oracle.py — an independent Python reference implementation of the
covered 1040 scope, swept against the Bend engine over randomized and
boundary-targeted facts.

The manifest pins CONSTANTS; this pins the WIRING: brackets, LTCG
stacking, the Tax Table, Schedule SE's line-8c wage offset, the §199A
phaseout/wage-limit/SSTB machinery, the §1211 loss netting and the two
surtaxes — computed here from this file's OWN constants (typed from
Rev. Proc. 2023-34 and the IRC, never imported from the Bend tables)
and compared EXACTLY against `bend run` output. Any mismatch fails.

Semantics mirrored from the engine: Nat arithmetic is saturating
(subtraction floors at zero) and every band floors its own division.

Usage:  make oracle   (or: uv run oracle.py [--cases N])
Exit 0 = engine and oracle agree on every component of every case.
"""

from __future__ import annotations

import argparse
import random
import subprocess
import sys
from pathlib import Path

BEND = "~/.bend/bin/bend"

# ---- the oracle's OWN constants (independent transcription) -----------------
BRACKETS = {  # (f1..f6 floors, std deduction) per status, 2024
    "single": ([11600, 47150, 100525, 191950, 243725, 609350], 14600),
    "mfj":    ([23200, 94300, 201050, 383900, 487450, 731200], 29200),
    "mfs":    ([11600, 47150, 100525, 191950, 243725, 365600], 14600),
    "hoh":    ([16550, 63100, 100500, 191950, 243700, 609350], 21900),
}
RATES = [1000, 1200, 2200, 2400, 3200, 3500, 3700]  # bp
LTCG_T = {  # (t1, t2) per status
    "single": (47025, 518900), "mfj": (94050, 583750),
    "mfs": (47025, 291850), "hoh": (63000, 551350),
}
QBI = {  # (threshold, width)
    "single": (191950, 50000), "mfj": (383900, 100000),
    "mfs": (96700, 50000), "hoh": (191950, 50000),
}
SURTAX = {  # (additional Medicare threshold, NIIT MAGI threshold)
    "single": (200000, 200000), "mfj": (250000, 250000),
    "mfs": (125000, 125000), "hoh": (200000, 200000),
}
SS_BASE = 168600
SE_FACTOR, SE_SS, SE_MED = 9235, 1240, 290
LTCG15, LTCG20, QBI_PCT, W2_PCT = 1500, 2000, 2000, 5000
MED_ADDL, NIIT_RATE = 90, 380
TABLE_MAX = 100000


# ---- saturating Nat semantics ------------------------------------------------
def ssub(a: int, b: int) -> int:
    return max(0, a - b)


# ---- the reference computation ------------------------------------------------
def ordinary_continuous(i: int, floors, rates) -> int:
    total = 0
    prev = 0
    for k in range(6):
        width = ssub(min(i, floors[k]), prev)
        total += rates[k] * width // 10000
        prev = floors[k]
    return total + rates[6] * ssub(i, floors[5]) // 10000


def tax_row(a: int, w: int, floors, rates) -> int:
    # the IRS construction: tax on the row midpoint a+w/2, rounded
    # half-up; all-integer via doubled widths
    i2 = 2 * a + w
    total = 0
    prev = 0
    for k in range(6):
        w2 = ssub(min(i2, 2 * floors[k]), prev)
        total += rates[k] * w2
        prev = 2 * floors[k]
    total += rates[6] * ssub(i2, 2 * floors[5])
    return (total + 10000) // 20000


def row_bounds(ti: int) -> tuple[int, int]:
    if ti < 5:
        return 0, 5
    if ti < 15:
        return 5, 10
    if ti < 25:
        return 15, 10
    if ti < 3000:
        return 25 + 25 * ((ti - 25) // 25), 25
    return 3000 + 50 * ((ti - 3000) // 50), 50


def ordinary(oti: int, ncg: int, status: str) -> int:
    floors, _ = BRACKETS[status]
    if ncg != 0:
        return ordinary_continuous(oti, floors, RATES)  # Schedule D worksheet
    if oti < TABLE_MAX:
        a, w = row_bounds(oti)
        return tax_row(a, w, floors, RATES)
    return ordinary_continuous(oti, floors, RATES)


def ltcg(oi: int, g: int, status: str) -> int:
    t1, t2 = LTCG_T[status]
    stack = oi + g
    g0 = ssub(min(stack, t1), oi)
    g20 = ssub(ssub(stack, min(stack, t2)), ssub(oi, min(oi, t2)))
    g15 = ssub(ssub(g, g0), g20)
    return LTCG15 * g15 // 10000 + LTCG20 * g20 // 10000


def se_tax(ss_wages: int, profit: int) -> tuple[int, int]:
    base = SE_FACTOR * profit // 10000
    room = ssub(SS_BASE, min(ss_wages, SS_BASE))
    ss = min(base, room) * SE_SS // 10000
    med = base * SE_MED // 10000
    return ss + med, (ss + med) // 2


def netting(st: int, lt: int, biz1: int, biz2: int, status: str) -> dict:
    if st >= 0 and lt >= 0:
        st_g, lt_g, loss = st, lt, 0
    else:
        combined = st + lt
        if combined >= 0:
            st_g, lt_g = (combined, 0) if st >= 0 else (0, combined)
            loss = 0
        else:
            st_g, lt_g, loss = 0, 0, -combined
    cap = 1500 if status == "mfs" else 3000
    cap_loss = min(loss, cap)
    b = biz1 + biz2
    return {"st_gain": st_g, "lt_gain": lt_g, "cap_loss": cap_loss,
            "biz_profit": max(0, b), "biz_loss": max(0, -b)}


def compute(case: dict) -> dict:
    status = case["status"]
    floors, std = BRACKETS[status]
    n = netting(case["stcg"], case["ltcg"], case["biz1"], case["biz2"], status)
    wages, ss_wages = case["wages"], case["ss_wages"]
    profit = n["biz_profit"]

    se, se_ded = se_tax(ss_wages, profit)
    agi = ssub(wages + case["interest"] + n["st_gain"] + n["lt_gain"] + profit,
               n["cap_loss"] + n["biz_loss"] + se_ded)
    ti_pre = ssub(agi, std)
    ncg = n["lt_gain"]
    qbi = qbi_ded(case["sstb"], profit, case["biz_w2"], ti_pre, ncg, status)
    ti = ssub(ti_pre, qbi)
    oti = ssub(ti, ncg)
    med = MED_ADDL * ssub(wages + SE_FACTOR * profit // 10000,
                          min(wages + SE_FACTOR * profit // 10000, SURTAX[status][0])) // 10000
    nii = ssub(case["interest"] + n["st_gain"] + n["lt_gain"], n["cap_loss"])
    niit = NIIT_RATE * min(ssub(agi, min(agi, SURTAX[status][1])), nii) // 10000
    tax = (ordinary(oti, ncg, status) + ltcg(oti, ncg, status) + se + med + niit)
    return {"agi": agi, "ti": ti, "qbi": qbi, "ord": ordinary(oti, ncg, status),
            "ltcg": ltcg(oti, ncg, status), "se": se, "med": med,
            "niit": niit, "tax": tax}


def qbi_ded(sstb: int, qbi: int, w2: int, ti_pre: int, ncg: int, status: str) -> int:
    thr, width = QBI[status]
    q20 = QBI_PCT * qbi // 10000
    cap = QBI_PCT * ssub(ti_pre, ncg) // 10000
    core = min(q20, cap)
    over = ssub(ti_pre, thr)
    if over == 0:
        return core  # no wage limit, no phaseout below the threshold
    wlim = W2_PCT * w2 // 10000
    if sstb == 0:
        return min(core, wlim)
    r = min(over, width) * 10000 // width
    appl = 10000 - r
    return min(appl * core // 10000, appl * cap // 10000, appl * wlim // 10000)


# ---- case generation -----------------------------------------------------------
ALIAS = {"single": "S", "mfj": "M", "mfs": "FS", "hoh": "H"}


def cases(n_random: int) -> list[dict]:
    rng = random.Random(2024)
    out: list[dict] = []

    def one(status, **kw):
        c = {"status": status,
             "wages": 0, "ss_wages": 0, "interest": 0,
             "stcg": 0, "ltcg": 0, "biz1": 0, "biz2": 0,
             "biz_w2": 0, "sstb": 0, "withheld": 0, "est": 0}
        c.update(kw)
        out.append(c)

    # boundary-targeted: every machinery edge, exact
    one("single", wages=100000, ss_wages=100000, interest=5000, ltcg=99999)      # Tax Table edge, gains
    one("single", wages=100000, ss_wages=100000, interest=5000)                  # Tax Table edge, no gains
    one("mfj", wages=100000, ss_wages=100000, interest=5000)                     # no-gains TI in table
    one("single", wages=0, ss_wages=0, stcg=-5000)                               # pure capital loss, cap+carry
    one("mfs", wages=0, ss_wages=0, stcg=-5000)                                  # MFS 1500 cap
    one("mfj", wages=60000, ss_wages=60000, stcg=-1200, ltcg=3000)               # cross-character netting
    one("mfj", wages=60000, ss_wages=60000, biz1=-20000)                         # Schedule C loss year
    one("mfj", wages=150000, ss_wages=150000, biz1=100000)                       # SE line 8c binds
    one("single", wages=100000, ss_wages=100000, biz1=300000)                    # SS base: SE fully capped
    one("single", wages=100000, ss_wages=100000, biz1=100000, biz_w2=10000, sstb=0)  # wage-capped QBI
    one("single", wages=100000, ss_wages=100000, biz1=100000, biz_w2=10, sstb=1)     # SSTB zeroed above band
    for st in ("single", "mfj", "mfs", "hoh"):
        thr, _width = QBI[st]
        for d in (-1, 0, 1, 5000, 49999, 50000):
            # QBI phaseout band edges: ti_pre lands near thr+d via wages
            one(st, biz1=100000, biz_w2=80000, sstb=1, wages=200000, interest=1000,
                ltcg=max(0, thr + d - (200000 + 1000 + 9235 * 100000 // 10000) + 14600))
    for i in range(n_random):
        st = ["single", "mfj", "mfs", "hoh"][i % 4]
        wages = rng.choice([0, 30000, 80000, 150000, 250000, 400000])
        ss = int(wages * rng.choice([1.0, 1.06, 1.2])) if wages else 0
        stcg = rng.choice([0, -rng.randrange(0, 60000), rng.randrange(0, 90000)])
        ltcg = rng.choice([0, -rng.randrange(0, 40000), rng.randrange(0, 500000)])
        b1 = rng.choice([0, -rng.randrange(0, 60000), rng.randrange(0, 400000)])
        b2 = rng.choice([0, rng.randrange(0, 200000)])
        one(st, wages=wages, ss_wages=ss,
            interest=rng.choice([0, rng.randrange(0, 120000)]),
            stcg=stcg, ltcg=ltcg, biz1=b1, biz2=b2,
            biz_w2=rng.choice([0, rng.randrange(0, 160000)]),
            sstb=rng.choice([0, 1]))
    return out


# ---- bend driver generation + run -----------------------------------------------
COMPONENTS = ["agi", "ti", "qbi", "ord", "ltcg", "se", "med", "niit", "tax"]

# expression per component, in terms of the case's binding names
EXPR = {
    "agi": "T.agi(f{c}, tb{c})",
    "ti": "T.taxable_income(f{c}, tb{c})",
    "qbi": "T.qbi(f{c}, tb{c})",
    "ord": "T.ordinary_part(T.ordinary_ti(f{c}, tb{c}), T.net_cap_gain(f{c}), tb{c})",
    "ltcg": "T.ltcg_tax(T.ordinary_ti(f{c}, tb{c}), T.net_cap_gain(f{c}), tb{c})",
    "se": "T.se_tax(T.ss_wages_of(f{c}), T.biz_profit_of(f{c}), tb{c})",
    "med": "T.addl_med(f{c}, tb{c})",
    "niit": "T.niit(f{c}, tb{c})",
    "tax": "T.tax(f{c}, tb{c})",
}

FILING_ORDER = ["wages", "ss_wages", "interest", "st_gain", "lt_gain",
                "biz_profit", "biz_loss", "biz_w2", "sstb", "cap_loss",
                "withheld", "est"]


def filing_literal(case: dict) -> str:
    n = netting(case["stcg"], case["ltcg"], case["biz1"], case["biz2"], case["status"])
    vals = [case["wages"], case["ss_wages"], case["interest"], n["st_gain"], n["lt_gain"],
            n["biz_profit"], n["biz_loss"], case["biz_w2"], case["sstb"],
            n["cap_loss"], case["withheld"], case["est"]]
    return "T.Filing{" + ", ".join(f"{v}n" for v in vals) + "}"


def driver_source(cases: list[dict]) -> str:
    L = ["import Base",
         "import ../bend/tax.bend as T",
         "import ../bend/tables_2024_single.bend as S",
         "import ../bend/tables_2024_mfj.bend as M",
         "import ../bend/tables_2024_mfs.bend as FS",
         "import ../bend/tables_2024_hoh.bend as H",
         ""]
    # one def per case, printing every component; the oracle (python) holds
    # the expected values and does the comparing
    case_defs = []
    for i, c in enumerate(cases):
        d = [f"def case_{i}() -> IO(Unit):",
             "  do IO<Unit>:",
             f"    +f{i} : T.Filing = {filing_literal(c)}",
             f"    +tb{i} : T.Tables = {ALIAS[c['status']]}.tables()"]
        for comp in COMPONENTS:
            e = EXPR[comp].format(c=i)
            d.append(f'    IO.print("{i}:{comp}=")')
            d.append(f"    IO.print(Nat.show({e}))")
            d.append('    IO.print("\\n")')
        case_defs.append(d)
    # chunk the case defs — a single deep IO do-chain overflows the stack
    CHUNK = 12
    for d in case_defs:
        L.extend(d)
    L.append("")
    blocks = [list(range(i, min(i + CHUNK, len(case_defs)))) for i in range(0, len(case_defs), CHUNK)]
    for bi, members in enumerate(blocks):
        L.append(f"def block_{bi}() -> IO(Unit):")
        L.append("  do IO<Unit>:")
        for i in members:
            L.append(f"    case_{i}()")
        L.append("")
    L.append("def main() -> IO(Unit):")
    L.append("  do IO<Unit>:")
    for bi in range(len(blocks)):
        L.append(f"    block_{bi}()")
    return "\n".join(L) + "\n"


def main() -> None:
    ap = argparse.ArgumentParser(description="differential oracle: python reference vs bend engine")
    ap.add_argument("--cases", type=int, default=40, help="number of randomized cases")
    ap.add_argument("--keep", action="store_true", help="keep the generated driver")
    args = ap.parse_args()

    all_cases = cases(args.cases)
    expected = [compute(c) for c in all_cases]

    driver = Path("inputs/oracle_driver.bend")
    driver.parent.mkdir(exist_ok=True)
    driver.write_text(driver_source(all_cases), encoding="utf-8")

    bend = Path(BEND).expanduser()
    proc = subprocess.run([str(bend), "inputs/oracle_driver.bend"],
                          capture_output=True, text=True)
    if proc.returncode != 0:
        print(proc.stdout)
        print(proc.stderr)
        sys.exit("oracle: bend run failed")

    got: dict[str, int] = {}
    cur_key = None
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.endswith("="):
            cur_key = line[:-1]
        elif cur_key is not None:
            got[cur_key] = int(line)
            cur_key = None

    fails = []
    for i, c in enumerate(all_cases):
        for comp in COMPONENTS:
            key = f"{i}:{comp}"
            want = expected[i][comp]
            have = got.get(key)
            if have != want:
                fails.append(f"  {key} ({c['status']}): engine {have}, oracle {want}")
    total = len(all_cases) * len(COMPONENTS)
    if fails:
        print(f"oracle: FAIL — {len(fails)} of {total} comparisons disagree:")
        print("\n".join(fails[:20]))
        sys.exit(1)
    print(f"oracle: PASS — engine and independent python reference agree on "
          f"all {total} comparisons over {len(all_cases)} cases "
          f"(boundary-targeted + seeded random)")
    if not args.keep:
        driver.unlink()


if __name__ == "__main__":
    main()
