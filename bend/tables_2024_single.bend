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

def tables() -> T.Tables:
  T.Tables{
    F1(), F2(), F3(), F4(), F5(), F6(),
    Y.R10(), Y.R12(), Y.R22(), Y.R24(), Y.R32(), Y.R35(), Y.R37(),
    T1(), T2(),
    Y.SS_WAGE_BASE(),
    STD_DED(),
  }
