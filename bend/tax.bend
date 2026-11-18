import Base
import ./tables_2024.bend as Y

# ============================================================================
# tax.bend — a provable federal income tax computation (Form 1040)
#
# Conventions
#   - Amounts are integers in whatever unit the caller chooses (the printed return
#     uses whole dollars). There is no floating point anywhere near money.
#   - Rates are integer basis points: 1240bp = 12.4%.
#   - Amounts are `Nat`: unbounded, so overflow is structurally impossible.
#
# Coverage: W-2 wages, taxable interest, short- and long-term capital
# gains, and two Schedule C sole proprietorships (which pool for the
# self-employment tax and the §199A QBI deduction). Standard deduction
# only.
#
# MODULARITY: this file contains NO statutory numbers or rates. The
# kernels are parameterized over the tables; every wrapper takes a
# `Tables` value carrying a filing status' bracket floors, rates, LTCG
# thresholds, Social Security wage base and standard deduction. The flat
# statutory rates/factors (SE factor, SE rates, LTCG rates, QBI rate)
# live in tables_2024.bend; the concrete year/status tables in
# tables_<year>_<status>.bend — swapping filing status or year is
# swapping which module builds the `Tables`. (The 10000n divisors are
# the basis-point unit scale, not statutory numbers.)
#
# Every claim about this module is stated in LAWS.bend and proven in
# PROOF.bend; `bend PROOF.bend --verdict` is the compliance gate.
# ============================================================================

# ---- the statutory tables, as data ------------------------------------------

type Tables is Data:
  Tables{
    f1: Nat, f2: Nat, f3: Nat, f4: Nat, f5: Nat, f6: Nat,
    r10: Nat, r12: Nat, r22: Nat, r24: Nat, r32: Nat, r35: Nat, r37: Nat,
    t1: Nat, t2: Nat,          # LTCG 0% and 15%→20% breakpoints
    ss_wage_base: Nat,
    std_ded: Nat,
  }

# The width of each band — how many dollars land in it. Div-free, so the
# tiling law (every dollar lands in exactly one bracket) is provable for
# any chained table; return.bend re-checks the concrete instantiation at runtime.
def total_width_at(+i: Nat, +f1: Nat, +f2: Nat, +f3: Nat, +f4: Nat, +f5: Nat, +f6: Nat) -> Nat:
  Nat.add(Nat.min(i, f1),
  Nat.add(Nat.sub(Nat.min(i, f2), f1),
  Nat.add(Nat.sub(Nat.min(i, f3), f2),
  Nat.add(Nat.sub(Nat.min(i, f4), f3),
  Nat.add(Nat.sub(Nat.min(i, f5), f4),
          Nat.sub(Nat.min(i, f6), f5))))))

def tiling_check(+i: Nat, +tb: Tables) -> Bool:
  # runtime instantiation of the proven bands_tile6 law: with the actual
  # statutory table, every dollar up to i lands in exactly one bracket
  match tb:
    case Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, sd}:
      Nat.is_eq(total_width_at(i, f1, f2, f3, f4, f5, f6), Nat.min(i, f6))

# ---- kernels: the same computation parameterized over the statutory
# ---- tables. Laws are stated about these (symbolic tables keep proof
# ---- normalization shallow); the `Tables` wrappers below instantiate
# ---- whichever year/status module the caller passes; return.bend
# ---- exercises them and re-checks the tiling law at runtime.

def ordinary_tax_at(+i: Nat, +f1: Nat, +f2: Nat, +f3: Nat, +f4: Nat, +f5: Nat, +f6: Nat,
                    +r10: Nat, +r12: Nat, +r22: Nat, +r24: Nat, +r32: Nat, +r35: Nat, +r37: Nat) -> Nat:
  Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(
          Nat.div(Nat.mul(Nat.min(i, f1), r10), 10000n),
          Nat.div(Nat.mul(Nat.sub(Nat.min(i, f2), f1), r12), 10000n)),
          Nat.div(Nat.mul(Nat.sub(Nat.min(i, f3), f2), r22), 10000n)),
          Nat.div(Nat.mul(Nat.sub(Nat.min(i, f4), f3), r24), 10000n)),
          Nat.div(Nat.mul(Nat.sub(Nat.min(i, f5), f4), r32), 10000n)),
  Nat.add(Nat.div(Nat.mul(Nat.sub(Nat.min(i, f6), f5), r35), 10000n),
          Nat.div(Nat.mul(Nat.sub(i, f6), r37), 10000n)))

# Ordinary tax: exactly the IRS worksheet — each band's width times its
# rate, floored to the cent, summed; plus the top slice above f6.
def ordinary_tax(+i: Nat, +tb: Tables) -> Nat:
  match tb:
    case Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_ded}:
      ordinary_tax_at(i, f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37)

# ---- long-term capital gains: 0% / 15% / 20%, stacked ----------------------
# Thresholds ride on TOTAL taxable income (ordinary + gain), per Schedule
# D's worksheet: the gain is sliced where it lands on that axis.

def g0_at(+oi: Nat, +g: Nat, +t1: Nat) -> Nat:
  Nat.sub(Nat.min(Nat.add(oi, g), t1), oi)

def g20_at(+oi: Nat, +g: Nat, +t1: Nat, +t2: Nat) -> Nat:
  Nat.sub(Nat.sub(Nat.add(oi, g), Nat.min(Nat.add(oi, g), t2)),
          Nat.sub(oi, Nat.min(oi, t2)))

def g15_at(+oi: Nat, +g: Nat, +t1: Nat, +t2: Nat) -> Nat:
  Nat.sub(Nat.sub(g, g0_at(oi, g, t1)), g20_at(oi, g, t1, t2))

def ltcg_tax_at(+oi: Nat, +g: Nat, +t1: Nat, +t2: Nat) -> Nat:
  Nat.add(Nat.div(Nat.mul(g15_at(oi, g, t1, t2), Y.LTCG15()), 10000n),
          Nat.div(Nat.mul(g20_at(oi, g, t1, t2), Y.LTCG20()), 10000n))

def g0(+oi: Nat, +g: Nat, +tb: Tables) -> Nat:
  match tb:
    case Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_ded}:
      g0_at(oi, g, t1)

def g20(+oi: Nat, +g: Nat, +tb: Tables) -> Nat:
  match tb:
    case Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_ded}:
      g20_at(oi, g, t1, t2)

def g15(+oi: Nat, +g: Nat, +tb: Tables) -> Nat:
  match tb:
    case Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_ded}:
      g15_at(oi, g, t1, t2)

def ltcg_tax(+oi: Nat, +g: Nat, +tb: Tables) -> Nat:
  match tb:
    case Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_ded}:
      ltcg_tax_at(oi, g, t1, t2)

# ---- self-employment tax (Schedule SE), both businesses pooled -------------
# The Social Security part caps not against the raw wage base but against
# the base LEFT OVER after this taxpayer's W-2 Social Security wages —
# Schedule SE line 8c: 168600 − line 8b, and line 8b IS box 3. (Box 3 can
# EXCEED box 1 — 401(k)/§125 deferrals come out of box 1 but not box 3 —
# so the box-1 stand-in this field replaced enlarged the room and
# understated the tax.) The §164(f) deduction is half of the actual SE
# tax, so it inherits the same cap.
def se_earnings(+b1: Nat, +b2: Nat) -> Nat:
  Nat.add(b1, b2)

def se_base(+e: Nat) -> Nat:
  Nat.div(Nat.mul(e, Y.SE_FACTOR()), 10000n)

def ss_room(+ss_wages: Nat, +base: Nat) -> Nat:
  Nat.sub(base, Nat.min(ss_wages, base))

def ss_part_at(+e: Nat, +base: Nat) -> Nat:
  Nat.div(Nat.mul(Nat.min(se_base(e), base), Y.SE_SS_RATE()), 10000n)

def med_part(+e: Nat) -> Nat:
  Nat.div(Nat.mul(se_base(e), Y.SE_MED_RATE()), 10000n)

def se_tax_at(+e: Nat, +base: Nat) -> Nat:
  Nat.add(ss_part_at(e, base), med_part(e))

def se_deduction_at(+e: Nat, +base: Nat) -> Nat:
  Nat.div(se_tax_at(e, base), 2n)

def ss_part(+ss_wages: Nat, +e: Nat, +tb: Tables) -> Nat:
  match tb:
    case Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_ded}:
      ss_part_at(e, ss_room(ss_wages, ss_wage_base))

def se_tax(+ss_wages: Nat, +e: Nat, +tb: Tables) -> Nat:
  match tb:
    case Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_ded}:
      Nat.add(ss_part_at(e, ss_room(ss_wages, ss_wage_base)), med_part(e))

def se_deduction(+ss_wages: Nat, +e: Nat, +tb: Tables) -> Nat:
  match tb:
    case Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_ded}:
      se_deduction_at(e, ss_room(ss_wages, ss_wage_base))

# ---- qualified business income deduction (§199A, simplified) ---------------
# 20% of QBI, capped at 20% of (taxable income before QBI minus net
# capital gains). Wage/ SSTB limits are out of scope this phase.
def qbi_ded(+qbi: Nat, +ti_pre: Nat, +ncg: Nat) -> Nat:
  Nat.min(Nat.div(Nat.mul(qbi, Y.QBI_RATE()), 10000n),
          Nat.div(Nat.mul(Nat.sub(ti_pre, ncg), Y.QBI_RATE()), 10000n))

# ---- the return ------------------------------------------------------------
# Filing carries the FACTS of the year; Tables carries the LAW of the
# year and status. `tax(filing, tables)` computes the return.
type Filing is Data:
  Filing{
    wages: Nat,     # W-2 box 1
    ss_wages: Nat,  # W-2 box 3 — Social Security wages (Schedule SE line 8b)
    interest: Nat,  # 1099-INT taxable interest
    stcg: Nat,      # short-term capital gain (net)
    ltcg: Nat,      # long-term capital gain (net)
    biz1: Nat,      # Schedule C net profit, proprietorship one
    biz2: Nat,      # Schedule C net profit, proprietorship two
    withheld: Nat,  # W-2 box 2 + backup withholding
    est: Nat,       # estimated payments
  }

# ---- field accessors (return.bend reads facts one line at a time) -----------
def wages_of(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz1, biz2, withheld, est}:
      wages

def ss_wages_of(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz1, biz2, withheld, est}:
      ss_wages

def interest_of(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz1, biz2, withheld, est}:
      interest

def stcg_of(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz1, biz2, withheld, est}:
      stcg

def biz1_of(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz1, biz2, withheld, est}:
      biz1

def biz2_of(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz1, biz2, withheld, est}:
      biz2

def std_ded(+tb: Tables) -> Nat:
  match tb:
    case Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, sd}:
      sd

def net_cap_gain(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz1, biz2, withheld, est}:
      ltcg

def total_income(+f: Filing) -> Nat:
  # ss_wages is NOT income of its own — it's the slice of wages already
  # credited to Social Security, reporting only (Schedule SE line 8b).
  match f:
    case Filing{wages, _, interest, stcg, ltcg, biz1, biz2, _, _}:
      Nat.add(wages, Nat.add(interest, Nat.add(stcg, Nat.add(ltcg, Nat.add(biz1, biz2)))))

def agi(+f: Filing, +tb: Tables) -> Nat:
  Nat.sub(total_income(f),
          se_deduction(ss_wages_of(f), se_earnings(biz1_of(f), biz2_of(f)), tb))

def taxable_income_pre(+f: Filing, +tb: Tables) -> Nat:
  # taxable income before the QBI deduction (the §199A cap measures against this)
  Nat.sub(agi(f, tb), std_ded(tb))

def qbi(+f: Filing, +tb: Tables) -> Nat:
  qbi_ded(se_earnings(biz1_of(f), biz2_of(f)), taxable_income_pre(f, tb), net_cap_gain(f))

def taxable_income(+f: Filing, +tb: Tables) -> Nat:
  Nat.sub(taxable_income_pre(f, tb), qbi(f, tb))

def ordinary_ti(+f: Filing, +tb: Tables) -> Nat:
  Nat.sub(taxable_income(f, tb), net_cap_gain(f))

def tax(+f: Filing, +tb: Tables) -> Nat:
  Nat.add(ordinary_tax(ordinary_ti(f, tb), tb),
  Nat.add(ltcg_tax(ordinary_ti(f, tb), net_cap_gain(f), tb),
          se_tax(ss_wages_of(f), se_earnings(biz1_of(f), biz2_of(f)), tb)))

def paid(+f: Filing) -> Nat:
  match f:
    case Filing{_, _, _, _, _, _, _, withheld, est}:
      Nat.add(withheld, est)

def refund(+f: Filing, +tb: Tables) -> Nat:
  Nat.sub(paid(f), tax(f, tb))

def owed(+f: Filing, +tb: Tables) -> Nat:
  Nat.sub(tax(f, tb), paid(f))
