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

# ---- the IRS Tax Table switch ------------------------------------------------
# The 1040 instructions mandate the paper Tax Table for taxable income
# under $100,000. Above it, the tax is computed directly. Row values are
# verified exhaustively against the published 2024 table (extracted from
# IRS i1040tt--2024.pdf) by bend/TAX_TABLE_CHECK.bend.
def TAX_TABLE_MAX() -> Nat:
  # 100000 = the last TI for which the Tax Table applies ($99,999 is the
  # final row: "at least $99,950 but less than $100,000")
  100000n

# The row grid narrows at the bottom: rows are $5 wide in [0,5), $10 in
# [5,25), $25 in [25,3000), then $50 up to the switch. Widths and band
# edges as separate constants (W1 = B2 = 5 and W3 = B4 = 25 are the
# IRS's coincidences, not derivations).
def TAX_W1() -> Nat:
  # row width in [0, 5)
  5n

def TAX_W2() -> Nat:
  # row width in [5, 25)
  10n

def TAX_W3() -> Nat:
  # row width in [25, 3000)
  25n

def TAX_W4() -> Nat:
  # row width in [3000, 100000)
  50n

def TAX_B2() -> Nat:
  # grid band edge: $5
  5n

def TAX_B3() -> Nat:
  # grid band edge: $15
  15n

def TAX_B4() -> Nat:
  # grid band edge: $25
  25n

def TAX_B5() -> Nat:
  # grid band edge: $3,000
  3000n

def TAX_ROW_WIDTH() -> Nat:
  # alias of TAX_W4 — the dominant width (1,940 of 2,062 rows)
  TAX_W4()

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

def W2_LIMIT_RATE() -> Nat:
  # 5000 = 50%, the §199A W-2 wage limit above the threshold
  # (§199A(b)(2)(B)(ii)(I); the 25%+2.5%UBIA alternative is out of scope)
  5000n

def MED_ADDL_RATE() -> Nat:
  # 90 = 0.9%, the additional Medicare tax rate (§3103(b))
  90n

def NIIT_RATE() -> Nat:
  # 380 = 3.8%, the net investment income tax rate (§1411)
  380n

# ---- rental loss special allowance (IRC §469(i)) ----------------------------
# Rents are Schedule E income: NOT self-employment income, and rental
# losses are passive. For the active participant, §469(i) allows up to
# $25,000 of rental loss against other income, phased out at 50 cents
# per dollar of MAGI over $100,000 (gone at $150,000); the rest is
# suspended (reported, like the capital-loss carryover).

def RENTAL_ALLOWANCE_MAX() -> Nat:
  25000n

def RENTAL_ALLOWANCE_PHASE_START() -> Nat:
  100000n

def RENTAL_ALLOWANCE_PHASE_RATE() -> Nat:
  # 5000 = 50%, the §469(i)(2) phaseout percentage
  5000n
