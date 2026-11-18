import Base
import ./tax.bend as T
import ./tables_2024.bend as Y

# ============================================================================
# tables_2024_mfj.bend — 2024 statutory tables, MARRIED FILING JOINTLY.
# IRS Rev. Proc. 2023-34. Each floor is chained to the previous one
# (F(k+1) is literally F(k) + band width) so the tiling law applies
# by construction.
# ============================================================================

def F1() -> Nat:
  23200n

def F2() -> Nat:
  Nat.add(F1(), 71100n)

def F3() -> Nat:
  Nat.add(F2(), 106750n)

def F4() -> Nat:
  Nat.add(F3(), 182850n)

def F5() -> Nat:
  Nat.add(F4(), 103550n)

def F6() -> Nat:
  Nat.add(F5(), 243750n)

# LTCG 0% / 15%→20% breakpoints (married filing jointly)
def T1() -> Nat:
  94050n

def T2() -> Nat:
  Nat.add(T1(), 489700n)

def STD_DED() -> Nat:
  29200n

def tables() -> T.Tables:
  T.Tables{
    F1(), F2(), F3(), F4(), F5(), F6(),
    Y.R10(), Y.R12(), Y.R22(), Y.R24(), Y.R32(), Y.R35(), Y.R37(),
    T1(), T2(),
    Y.SS_WAGE_BASE(),
    STD_DED(),
  }
