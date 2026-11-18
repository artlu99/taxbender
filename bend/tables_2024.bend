import Base

# ============================================================================
# tables_2024.bend — 2024 amounts that do not depend on filing status:
# the marginal rates (identical for every status) and the Social Security
# wage base. Bracket floors, LTCG breakpoints and the standard deduction
# are per-status; they live in tables_2024_<status>.bend, which imports
# this file.
# ============================================================================

def R10() -> Nat:
  1000n

def R12() -> Nat:
  1200n

def R22() -> Nat:
  2200n

def R24() -> Nat:
  2400n

def R32() -> Nat:
  3200n

def R35() -> Nat:
  3500n

def R37() -> Nat:
  3700n

def SS_WAGE_BASE() -> Nat:
  # 168600 = the 2024 Social Security wage base ($168,600), whole dollars
  # like every other amount here. Written as a plain literal: Nat.mul here
  # overflows the proof checker's stack when the manifest law normalizes it
  # (mul is not tail-recursive).
  168600n
