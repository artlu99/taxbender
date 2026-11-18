import Base
import ./tax.bend as T
import ./tables_2024.bend as Y

# ============================================================================
# tables_2024_single.bend — 2024 statutory tables, SINGLE filer.
# IRS Rev. Proc. 2023-34. Each floor is chained to the previous one
# (F(k+1) is literally F(k) + band width) so the tiling law applies
# by construction.
# ============================================================================

def F1() -> Nat:
  11600n

def F2() -> Nat:
  Nat.add(F1(), 35550n)

def F3() -> Nat:
  Nat.add(F2(), 53375n)

def F4() -> Nat:
  Nat.add(F3(), 91425n)

def F5() -> Nat:
  Nat.add(F4(), 51775n)

def F6() -> Nat:
  Nat.add(F5(), 365625n)

# LTCG 0% / 15%→20% breakpoints (single)
def T1() -> Nat:
  47025n

def T2() -> Nat:
  Nat.add(T1(), 471875n)

def STD_DED() -> Nat:
  14600n


# ---- §199A phaseout, additional Medicare and NIIT thresholds (2024) ---------
def QBI_THR() -> Nat:
  # §199A(b)(3): taxable income where the phaseout begins
  191950n

def QBI_WIDTH() -> Nat:
  # width of the SSTB phaseout range (100000 MFJ, 50000 all others)
  50000n

def MED_THR() -> Nat:
  # §3103(b)(2): additional Medicare tax threshold on combined wages + SE
  200000n

def NIIT_THR() -> Nat:
  # §1411(b)(2): MAGI threshold for the net investment income tax
  200000n

def tables() -> T.Tables:
  T.Tables{
    F1(), F2(), F3(), F4(), F5(), F6(),
    Y.R10(), Y.R12(), Y.R22(), Y.R24(), Y.R32(), Y.R35(), Y.R37(),
    T1(), T2(),
    Y.SS_WAGE_BASE(),
    STD_DED(),
    QBI_THR(), QBI_WIDTH(), MED_THR(), NIIT_THR(),
  }
