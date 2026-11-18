import Base
import ./tables_2024.bend as Y
import ./tables_2024_single.bend as S
import ./tables_2024_mfj.bend as M

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
