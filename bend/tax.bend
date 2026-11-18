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
# Coverage: W-2 wages, taxable interest, net capital gains (with the
# allowed net capital loss as a deduction field), and pooled Schedule C
# results (profit feeds the self-employment tax and the §199A QBI
# deduction; a net loss deducts above the line). Standard deduction
# only. Loss NETTING happens upstream in facts.py — every field here is
# a non-negative magnitude.
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

# ---- the IRS Tax Table (taxable income below $100,000) ----------------------
# The 1040 instructions MANDATE the paper Tax Table for taxable income
# under $100,000: the tax is the published row for TI's row, which the
# IRS constructs as the tax on the row MIDPOINT (a + w/2 for a row
# [a, a+w)), rounded to the nearest dollar. A continuous computation at
# actual TI deviates from the mandated amount by $1–6 for most filers —
# the table is not an approximation of itself.
#
# This model was fit against the ENTIRE published 2024 table (all 2,062
# rows of each status column, extracted from IRS i1040tt--2024.pdf):
# midpoint a+w/2 with HALF-UP rounding matches all 2,062 × 4 values,
# and the 60 exact-tie rows (e.g. row $3,000–3,050 → $303 from 302.5)
# pin the rounding direction. bend/TAX_TABLE_CHECK.bend re-checks every
# published value on every gate run.
#
# All-integer encoding: the midpoint is (2a+w)/2 dollars, so double
# every width and the band math stays exact in Nat.
#
# The table applies to returns with NO capital gains; with gains, the
# Qualified Dividends and Capital Gain Tax Worksheet computes the whole
# tax (stacking), which is the continuous path.

def cont2_at(+i2: Nat, +f1: Nat, +f2: Nat, +f3: Nat, +f4: Nat, +f5: Nat, +f6: Nat,
             +r10: Nat, +r12: Nat, +r22: Nat, +r24: Nat, +r32: Nat, +r35: Nat, +r37: Nat) -> Nat:
  # 20000 × tax((i2/2) dollars), exact: Σ rate × width-in-half-dollars
  Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(
          Nat.mul(Nat.min(i2, Nat.mul(f1, 2n)), r10),
          Nat.mul(Nat.sub(Nat.min(i2, Nat.mul(f2, 2n)), Nat.mul(f1, 2n)), r12)),
          Nat.mul(Nat.sub(Nat.min(i2, Nat.mul(f3, 2n)), Nat.mul(f2, 2n)), r22)),
          Nat.mul(Nat.sub(Nat.min(i2, Nat.mul(f4, 2n)), Nat.mul(f3, 2n)), r24)),
          Nat.mul(Nat.sub(Nat.min(i2, Nat.mul(f5, 2n)), Nat.mul(f4, 2n)), r32)),
  Nat.add(Nat.mul(Nat.sub(Nat.min(i2, Nat.mul(f6, 2n)), Nat.mul(f5, 2n)), r35),
          Nat.mul(Nat.sub(i2, Nat.mul(f6, 2n)), r37)))

def tax_row_at(+a: Nat, +w: Nat, +f1: Nat, +f2: Nat, +f3: Nat, +f4: Nat, +f5: Nat, +f6: Nat,
               +r10: Nat, +r12: Nat, +r22: Nat, +r24: Nat, +r32: Nat, +r35: Nat, +r37: Nat) -> Nat:
  # the mandated amount for the row [a, a+w): the tax at the midpoint
  # a+w/2, rounded to the nearest dollar (half-up)
  Nat.div(Nat.add(cont2_at(Nat.add(Nat.mul(a, 2n), w), f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37), 10000n), 20000n)

# the Tax Table's row grid narrows at the bottom — $5 for [0,5), $10 for
# [5,25), $25 for [25,3000), then $50 to the switch (grid edges verified
# against the published table). Two views of the same four-way split:
def row_start_at(+ti: Nat, +lt5: Bool, +lt15: Bool, +lt25: Bool, +lt3k: Bool) -> Nat:
  match lt5:
    case True{}:
      0n
    case False{}:
      match lt15:
        case True{}:
          Y.TAX_B2()
        case False{}:
          match lt25:
            case True{}:
              Y.TAX_B3()
            case False{}:
              match lt3k:
                case True{}:
                  Nat.add(Y.TAX_B4(), Nat.mul(Y.TAX_W3(), Nat.div(Nat.sub(ti, Y.TAX_B4()), Y.TAX_W3())))
                case False{}:
                  Nat.add(Y.TAX_B5(), Nat.mul(Y.TAX_W4(), Nat.div(Nat.sub(ti, Y.TAX_B5()), Y.TAX_W4())))

def row_width_at(+ti: Nat, +lt5: Bool, +lt15: Bool, +lt25: Bool, +lt3k: Bool) -> Nat:
  match lt5:
    case True{}:
      Y.TAX_W1()
    case False{}:
      match lt15:
        case True{}:
          Y.TAX_W2()
        case False{}:
          match lt25:
            case True{}:
              Y.TAX_W2()
            case False{}:
              match lt3k:
                case True{}:
                  Y.TAX_W3()
                case False{}:
                  Y.TAX_W4()

def tiled_at(+ti: Nat, +below_max: Bool, +f1: Nat, +f2: Nat, +f3: Nat, +f4: Nat, +f5: Nat, +f6: Nat,
             +r10: Nat, +r12: Nat, +r22: Nat, +r24: Nat, +r32: Nat, +r35: Nat, +r37: Nat) -> Nat:
  match below_max:
    case True{}:
      +b1 : Bool = Nat.is_eq(Nat.div(ti, Y.TAX_B2()), 0n)
      +b2 : Bool = Nat.is_eq(Nat.div(ti, Y.TAX_B3()), 0n)
      +b3 : Bool = Nat.is_eq(Nat.div(ti, Y.TAX_B4()), 0n)
      +b4 : Bool = Nat.is_eq(Nat.div(ti, Y.TAX_B5()), 0n)
      tax_row_at(row_start_at(ti, b1, b2, b3, b4), row_width_at(ti, b1, b2, b3, b4), f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37)
    case False{}:
      ordinary_tax_at(ti, f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37)

def ordinary_tax_tiled(+i: Nat, +tb: Tables) -> Nat:
  match tb:
    case Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_ded}:
      tiled_at(i, Nat.is_eq(Nat.div(i, Y.TAX_TABLE_MAX()), 0n), f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37)

def ordinary_part_at(+oti: Nat, +no_gains: Bool, +tb: Tables) -> Nat:
  match no_gains:
    case True{}:
      ordinary_tax_tiled(oti, tb)
    case False{}:
      ordinary_tax(oti, tb)

def ordinary_part(+oti: Nat, +ncg: Nat, +tb: Tables) -> Nat:
  # the ordinary slice the return actually pays: the mandated Tax Table
  # row when there are no gains and TI is under the switch, continuous
  # otherwise
  ordinary_part_at(oti, Nat.is_eq(ncg, 0n), tb)

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

# ---- self-employment tax (Schedule SE), businesses pooled ------------------
# The Social Security part caps not against the raw wage base but against
# the base LEFT OVER after this taxpayer's W-2 Social Security wages —
# Schedule SE line 8c: 168600 − line 8b, and line 8b IS box 3. (Box 3 can
# EXCEED box 1 — 401(k)/§125 deferrals come out of box 1 but not box 3 —
# so the box-1 stand-in this field replaced enlarged the room and
# understated the tax.) The §164(f) deduction is half of the actual SE
# tax, so it inherits the same cap. The SE base is the POOLED net profit;
# a net Schedule C loss means no SE tax and no QBI.
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
# year and status. `tax(filing, tables)` computes the return. The gain
# and business fields arrive PRE-NETTED by facts.py (losses combined
# across characters/Schedule Cs, the net capital loss capped at
# $3,000/$1,500 MFS — see the FILING Pipeline docs): every field here is
# a non-negative magnitude, and the two loss fields are deductions.
type Filing is Data:
  Filing{
    wages: Nat,      # W-2 box 1
    ss_wages: Nat,   # W-2 box 3 — Social Security wages (Schedule SE line 8b)
    interest: Nat,   # 1099-INT taxable interest
    stcg: Nat,       # short-term capital gain (net, ≥ 0)
    ltcg: Nat,       # long-term capital gain (net, ≥ 0)
    biz_profit: Nat, # Schedule C net profit, both proprietorships pooled
    biz_loss: Nat,   # Schedule C net LOSS (deducted above the line)
    cap_loss: Nat,   # net capital loss allowed against ordinary income
    withheld: Nat,   # W-2 box 2 + backup withholding
    est: Nat,        # estimated payments
  }

# ---- field accessors (return.bend reads facts one line at a time) -----------
def wages_of(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz_profit, biz_loss, cap_loss, withheld, est}:
      wages

def ss_wages_of(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz_profit, biz_loss, cap_loss, withheld, est}:
      ss_wages

def interest_of(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz_profit, biz_loss, cap_loss, withheld, est}:
      interest

def stcg_of(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz_profit, biz_loss, cap_loss, withheld, est}:
      stcg

def biz_profit_of(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz_profit, biz_loss, cap_loss, withheld, est}:
      biz_profit

def biz_loss_of(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz_profit, biz_loss, cap_loss, withheld, est}:
      biz_loss

def std_ded(+tb: Tables) -> Nat:
  match tb:
    case Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, sd}:
      sd

def net_cap_gain(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz_profit, biz_loss, cap_loss, withheld, est}:
      ltcg

def cap_loss_of(+f: Filing) -> Nat:
  match f:
    case Filing{wages, ss_wages, interest, stcg, ltcg, biz_profit, biz_loss, cap_loss, withheld, est}:
      cap_loss

def total_income(+f: Filing) -> Nat:
  # gross positive components. ss_wages is NOT income of its own — it's
  # the slice of wages already credited to Social Security, reporting
  # only (Schedule SE line 8b). The loss fields are NOT subtracted here;
  # agi subtracts them together with the SE deduction.
  match f:
    case Filing{wages, _, interest, stcg, ltcg, biz_profit, _, _, _, _}:
      Nat.add(wages, Nat.add(interest, Nat.add(stcg, Nat.add(ltcg, biz_profit))))

def agi(+f: Filing, +tb: Tables) -> Nat:
  # above-the-line deductions: the allowed net capital loss, the pooled
  # Schedule C loss, and half the SE tax — AGI floors at zero (Nat sub)
  Nat.sub(total_income(f),
  Nat.add(Nat.add(cap_loss_of(f), biz_loss_of(f)),
          se_deduction(ss_wages_of(f), biz_profit_of(f), tb)))

def taxable_income_pre(+f: Filing, +tb: Tables) -> Nat:
  # taxable income before the QBI deduction (the §199A cap measures against this)
  Nat.sub(agi(f, tb), std_ded(tb))

def qbi(+f: Filing, +tb: Tables) -> Nat:
  qbi_ded(biz_profit_of(f), taxable_income_pre(f, tb), net_cap_gain(f))

def taxable_income(+f: Filing, +tb: Tables) -> Nat:
  Nat.sub(taxable_income_pre(f, tb), qbi(f, tb))

def ordinary_ti(+f: Filing, +tb: Tables) -> Nat:
  Nat.sub(taxable_income(f, tb), net_cap_gain(f))

def tax(+f: Filing, +tb: Tables) -> Nat:
  Nat.add(ordinary_part(ordinary_ti(f, tb), net_cap_gain(f), tb),
  Nat.add(ltcg_tax(ordinary_ti(f, tb), net_cap_gain(f), tb),
          se_tax(ss_wages_of(f), biz_profit_of(f), tb)))

def paid(+f: Filing) -> Nat:
  match f:
    case Filing{_, _, _, _, _, _, _, _, withheld, est}:
      Nat.add(withheld, est)

def refund(+f: Filing, +tb: Tables) -> Nat:
  Nat.sub(paid(f), tax(f, tb))

def owed(+f: Filing, +tb: Tables) -> Nat:
  Nat.sub(tax(f, tb), paid(f))
