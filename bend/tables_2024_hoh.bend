import Base
import ./tax.bend as T
import ./tables_2024.bend as Y

# ============================================================================
# tables_2024_hoh.bend — 2024 statutory tables, HEAD OF HOUSEHOLD.
# IRS Rev. Proc. 2023-34. Each floor is chained to the previous one
# (F(k+1) is literally F(k) + band width) so the tiling law applies
# by construction. The sub-$100k floors are additionally verified
# against the published Tax Table (see TAX_TABLE_CHECK.bend).
# ============================================================================

def F1() -> Nat:
  16550n

def F2() -> Nat:
  Nat.add(F1(), 46550n)

def F3() -> Nat:
  Nat.add(F2(), 37400n)

def F4() -> Nat:
  Nat.add(F3(), 91450n)

def F5() -> Nat:
  Nat.add(F4(), 51750n)

def F6() -> Nat:
  Nat.add(F5(), 365650n)

# LTCG 0% / 15%→20% breakpoints (head of household)
def T1() -> Nat:
  63000n

def T2() -> Nat:
  Nat.add(T1(), 488350n)

def STD_DED() -> Nat:
  21900n


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
