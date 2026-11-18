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

# ---- the flat statutory rates and factors -----------------------------------
# Every remaining statutory number that tax.bend's kernels used to inline.
# Each is pinned twice: a small-literal law in LAWS.bend (checker-cheap),
# and an exact pin in CONST_CHECK.bend (runtime, handles any magnitude).

def SE_FACTOR() -> Nat:
  # 9235 = 92.35%: Schedule SE line 4a — net earnings × 92.35%. The
  # missing 7.65% mirrors the FICA an employer would have paid half of.
  9235n

def SE_SS_RATE() -> Nat:
  # 1240 = 12.4%, the Social Security part of the SE tax (§1401(a))
  1240n

def SE_MED_RATE() -> Nat:
  # 290 = 2.9%, the Medicare part of the SE tax (§1401(b))
  290n

def LTCG15() -> Nat:
  # 1500 = 15%, the middle long-term capital gain rate
  1500n

def LTCG20() -> Nat:
  # 2000 = 20%, the top long-term capital gain rate
  2000n

def QBI_RATE() -> Nat:
  # 2000 = 20%, the §199A deduction percentage
  2000n
