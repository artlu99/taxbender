import Base
import ./tables_2024.bend as Y
import ./tables_2024_single.bend as S
import ./tables_2024_mfj.bend as M
import ./tax.bend as T

# ============================================================================
# CONST_CHECK.bend — every statutory constant pinned EXACTLY, at runtime.
# The proof checker normalizes unary Nats and overflows on six-digit
# arithmetic; the runtime handles big numbers natively, so exact pins
# live here instead of in the checker's laws. One CHECK line per
# constant; constant_check.sh fails the gate on any FAIL line.
#
# The expected values below ARE the human-verified audit surface: each
# traces to IRS Rev. Proc. 2023-34 (brackets, LTCG breakpoints, standard
# deductions), the SSA (wage base), or the IRC (SE and §199A rates).
# ============================================================================

def ck_b(name: String, +got: Nat, +want: Nat, +ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name ++ " = " ++ Nat.show(got) ++ "\n")
    case False{}:
      IO.print("FAIL " ++ name ++ ": got " ++ Nat.show(got) ++ ", want " ++ Nat.show(want) ++ "\n")

def ck(+name: String, +got: Nat, +want: Nat) -> IO(Unit):
  ck_b(name, got, want, Nat.is_eq(got, want))

# the Tax Table rows, per status
def srow(+a: Nat, +w: Nat) -> Nat:
  T.tax_row_at(a, w, S.F1(), S.F2(), S.F3(), S.F4(), S.F5(), S.F6(),
               Y.R10(), Y.R12(), Y.R22(), Y.R24(), Y.R32(), Y.R35(), Y.R37())

def mrow(+a: Nat, +w: Nat) -> Nat:
  T.tax_row_at(a, w, M.F1(), M.F2(), M.F3(), M.F4(), M.F5(), M.F6(),
               Y.R10(), Y.R12(), Y.R22(), Y.R24(), Y.R32(), Y.R35(), Y.R37())

def main() -> IO(Unit):
  do IO<Unit>:
    # ---- §1(j) rate schedule, SINGLE (Rev. Proc. 2023-34 §2.1) --------------
    ck("single F1 (10% ceiling)", S.F1(), 11600n)
    ck("single F2 (12% ceiling)", S.F2(), 47150n)
    ck("single F3 (22% ceiling)", S.F3(), 100525n)
    ck("single F4 (24% ceiling)", S.F4(), 191950n)
    ck("single F5 (32% ceiling)", S.F5(), 243725n)
    ck("single F6 (35% ceiling)", S.F6(), 609350n)
    ck("single T1 (LTCG 0% ceiling)", S.T1(), 47025n)
    ck("single T2 (LTCG 15% ceiling)", S.T2(), 518900n)
    ck("single standard deduction", S.STD_DED(), 14600n)

    # ---- §1(j) rate schedule, MARRIED FILING JOINTLY (§2.1) -----------------
    ck("mfj F1 (10% ceiling)", M.F1(), 23200n)
    ck("mfj F2 (12% ceiling)", M.F2(), 94300n)
    ck("mfj F3 (22% ceiling)", M.F3(), 201050n)
    ck("mfj F4 (24% ceiling)", M.F4(), 383900n)
    ck("mfj F5 (32% ceiling)", M.F5(), 487450n)
    ck("mfj F6 (35% ceiling)", M.F6(), 731200n)
    ck("mfj T1 (LTCG 0% ceiling)", M.T1(), 94050n)
    ck("mfj T2 (LTCG 15% ceiling)", M.T2(), 583750n)
    ck("mfj standard deduction", M.STD_DED(), 29200n)

    # ---- §1(j)(2) marginal rates (identical across statuses) ----------------
    ck("rate 10%", Y.R10(), 1000n)
    ck("rate 12%", Y.R12(), 1200n)
    ck("rate 22%", Y.R22(), 2200n)
    ck("rate 24%", Y.R24(), 2400n)
    ck("rate 32%", Y.R32(), 3200n)
    ck("rate 35%", Y.R35(), 3500n)
    ck("rate 37%", Y.R37(), 3700n)

    # ---- FICA / self-employment (SSA + §1401) --------------------------------
    ck("Social Security wage base", Y.SS_WAGE_BASE(), 168600n)
    ck("SE factor (92.35%)", Y.SE_FACTOR(), 9235n)
    ck("SE Social Security rate (12.4%)", Y.SE_SS_RATE(), 1240n)
    ck("SE Medicare rate (2.9%)", Y.SE_MED_RATE(), 290n)

    # ---- LTCG and §199A rates -------------------------------------------------
    ck("LTCG middle rate (15%)", Y.LTCG15(), 1500n)
    ck("LTCG top rate (20%)", Y.LTCG20(), 2000n)
    ck("QBI rate (20%)", Y.QBI_RATE(), 2000n)

    # ---- IRS Tax Table (mandated for TI < $100k) ------------------------------
    # Structure constants here; every published row VALUE (all 2,062 rows
    # × each status, both endpoints) is checked by TAX_TABLE_CHECK.bend,
    # generated from IRS i1040tt--2024.pdf.
    ck("tax table $100k switch point", Y.TAX_TABLE_MAX(), 100000n)
    ck("tax table row widths (5/10/25/50)", Y.TAX_W4(), 50n)
    ck("tax table row grid edges (5/15/25/3000)", Y.TAX_B5(), 3000n)
    ck("tax table row width W1", Y.TAX_W1(), 5n)
    ck("tax table row width W2", Y.TAX_W2(), 10n)
    ck("tax table row width W3", Y.TAX_W3(), 25n)
    ck("tax table grid edge B2", Y.TAX_B2(), 5n)
    ck("tax table grid edge B3", Y.TAX_B3(), 15n)
    ck("tax table grid edge B4", Y.TAX_B4(), 25n)
    ck("tax table row $0 [0-5] (published single $0)", srow(0n, 5n), 0n)
    ck("tax table row $3,000 [3000-3050] (published single $303, a tie)", srow(3000n, 50n), 303n)
    ck("tax table row $9,950 (published single $998)", srow(9950n, 50n), 998n)
    ck("tax table row $12,000 (published single $1,211)", srow(12000n, 50n), 1211n)
    ck("tax table row $23,200 (published mfj $2,323)", mrow(23200n, 50n), 2323n)
    ck("table at TI $99,999 (single, last row = published $17,048)", T.ordinary_tax_tiled(99999n, S.tables()), 17048n)
    ck("switch: tiled == continuous at exactly $100,000 (single)",
       T.ordinary_tax_tiled(100000n, S.tables()), T.ordinary_tax(100000n, S.tables()))
