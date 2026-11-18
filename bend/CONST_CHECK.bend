import Base
import ./tables_2024.bend as Y
import ./tables_2024_single.bend as S
import ./tables_2024_mfj.bend as M
import ./tables_2024_mfs.bend as FS
import ./tables_2024_hoh.bend as H
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

def ck_bool_b(name: String, +ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name ++ "\n")
    case False{}:
      IO.print("FAIL " ++ name ++ "\n")

def ck_bool(name: String, ok: Bool) -> IO(Unit):
  ck_bool_b(name, ok)

# the Tax Table rows, per status
def srow(+a: Nat, +w: Nat) -> Nat:
  T.tax_row_at(a, w, S.F1(), S.F2(), S.F3(), S.F4(), S.F5(), S.F6(),
               Y.R10(), Y.R12(), Y.R22(), Y.R24(), Y.R32(), Y.R35(), Y.R37())

def mrow(+a: Nat, +w: Nat) -> Nat:
  T.tax_row_at(a, w, M.F1(), M.F2(), M.F3(), M.F4(), M.F5(), M.F6(),
               Y.R10(), Y.R12(), Y.R22(), Y.R24(), Y.R32(), Y.R35(), Y.R37())

# the §199A deduction never increases as taxable income rises across the
# phaseout band (probe the wrapper both with and without the SSTB flag).
# NOTE: is_le — Nat.sub saturates, so sub(a,b)==0 would be vacuous here.
def qbi_mono_b(+steps: Nat, +t: Nat, +qbi: Nat, +w2: Nat, +sstb: Nat, +thr: Nat, +width: Nat, +ncg: Nat) -> Bool:
  match steps:
    case 0n:
      Nat.is_le(T.qbi_ded_at(sstb, qbi, w2, Nat.add(t, 500n), ncg, thr, width),
                T.qbi_ded_at(sstb, qbi, w2, t, ncg, thr, width))
    case 1n+rp:
      Bool.and(
        Nat.is_le(T.qbi_ded_at(sstb, qbi, w2, Nat.add(t, 500n), ncg, thr, width),
                  T.qbi_ded_at(sstb, qbi, w2, t, ncg, thr, width)),
        qbi_mono_b(rp, Nat.add(t, 500n), qbi, w2, sstb, thr, width, ncg))

# the §469(i) allowance never increases as MAGI rises, and never
# exceeds the raw loss (is_le — saturating sub is not a comparison)
def rental_mono_b(+steps: Nat, +m: Nat, +loss: Nat) -> Bool:
  match steps:
    case 0n:
      Nat.is_le(T.rental_allowance_at(loss, Nat.add(m, 500n)),
                T.rental_allowance_at(loss, m))
    case 1n+rp:
      Bool.and(
        Nat.is_le(T.rental_allowance_at(loss, Nat.add(m, 500n)),
                  T.rental_allowance_at(loss, m)),
        rental_mono_b(rp, Nat.add(m, 500n), loss))

def rental_bound_b(+steps: Nat, +loss: Nat, +m: Nat) -> Bool:
  match steps:
    case 0n:
      Nat.is_le(T.rental_allowance_at(loss, m), loss)
    case 1n+rp:
      Bool.and(
        Nat.is_le(T.rental_allowance_at(loss, m), loss),
        rental_bound_b(rp, Nat.add(loss, 1000n), m))

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

    # ---- §1(j) rate schedule, MARRIED FILING SEPARATELY (§2.1) --------------
    ck("mfs F1 (10% ceiling)", FS.F1(), 11600n)
    ck("mfs F2 (12% ceiling)", FS.F2(), 47150n)
    ck("mfs F3 (22% ceiling)", FS.F3(), 100525n)
    ck("mfs F4 (24% ceiling)", FS.F4(), 191950n)
    ck("mfs F5 (32% ceiling)", FS.F5(), 243725n)
    ck("mfs F6 (35% ceiling)", FS.F6(), 365600n)
    ck("mfs T1 (LTCG 0% ceiling)", FS.T1(), 47025n)
    ck("mfs T2 (LTCG 15% ceiling)", FS.T2(), 291850n)
    ck("mfs standard deduction", FS.STD_DED(), 14600n)

    # ---- §1(j) rate schedule, HEAD OF HOUSEHOLD (§2.1) ----------------------
    ck("hoh F1 (10% ceiling)", H.F1(), 16550n)
    ck("hoh F2 (12% ceiling)", H.F2(), 63100n)
    ck("hoh F3 (22% ceiling)", H.F3(), 100500n)
    ck("hoh F4 (24% ceiling)", H.F4(), 191950n)
    ck("hoh F5 (32% ceiling)", H.F5(), 243700n)
    ck("hoh F6 (35% ceiling)", H.F6(), 609350n)
    ck("hoh T1 (LTCG 0% ceiling)", H.T1(), 63000n)
    ck("hoh T2 (LTCG 15% ceiling)", H.T2(), 551350n)
    ck("hoh standard deduction", H.STD_DED(), 21900n)

    # ---- §199A phaseout thresholds (IRC §199A(b)(3)) -------------------------
    ck("qbi threshold single", S.QBI_THR(), 191950n)
    ck("qbi phaseout width single", S.QBI_WIDTH(), 50000n)
    ck("qbi threshold mfj", M.QBI_THR(), 383900n)
    ck("qbi phaseout width mfj", M.QBI_WIDTH(), 100000n)
    ck("qbi threshold mfs", FS.QBI_THR(), 96700n)
    ck("qbi phaseout width mfs", FS.QBI_WIDTH(), 50000n)
    ck("qbi threshold hoh", H.QBI_THR(), 191950n)
    ck("qbi phaseout width hoh", H.QBI_WIDTH(), 50000n)

    # ---- additional Medicare + NIIT thresholds (§3103(b), §1411) -------------
    ck("medicare threshold single", S.MED_THR(), 200000n)
    ck("medicare threshold mfj", M.MED_THR(), 250000n)
    ck("medicare threshold mfs", FS.MED_THR(), 125000n)
    ck("medicare threshold hoh", H.MED_THR(), 200000n)
    ck("niit threshold single", S.NIIT_THR(), 200000n)
    ck("niit threshold mfj", M.NIIT_THR(), 250000n)
    ck("niit threshold mfs", FS.NIIT_THR(), 125000n)
    ck("niit threshold hoh", H.NIIT_THR(), 200000n)
    ck("additional Medicare rate (0.9%)", Y.MED_ADDL_RATE(), 90n)
    ck("NIIT rate (3.8%)", Y.NIIT_RATE(), 380n)
    ck("§199A W-2 wage limit rate (50%)", Y.W2_LIMIT_RATE(), 5000n)

    # ---- rental loss special allowance (§469(i)) -----------------------------
    ck("rental allowance max ($25,000)", Y.RENTAL_ALLOWANCE_MAX(), 25000n)
    ck("rental allowance phase start ($100,000 MAGI)", Y.RENTAL_ALLOWANCE_PHASE_START(), 100000n)
    ck("rental allowance phase rate (50%)", Y.RENTAL_ALLOWANCE_PHASE_RATE(), 5000n)
    ck("rental: loss 30k, MAGI 90k -> full 25000", T.rental_allowance_at(30000n, 90000n), 25000n)
    ck("rental: loss 30k, MAGI 110k -> 20000", T.rental_allowance_at(30000n, 110000n), 20000n)
    ck("rental: loss 30k, MAGI 150k -> 0", T.rental_allowance_at(30000n, 150000n), 0n)
    ck("rental: loss 30k, MAGI 160k -> 0", T.rental_allowance_at(30000n, 160000n), 0n)
    ck("rental: loss 10k below max -> 10000", T.rental_allowance_at(10000n, 90000n), 10000n)
    ck_bool("rental allowance monotone (non-increasing in MAGI)",
            rental_mono_b(140n, 90000n, 30000n))
    ck_bool("rental allowance bounded by loss", rental_bound_b(60n, 0n, 90000n))

    # ---- §199A + surtax wiring probes (behavior the checker can't see) ------
    ck("addl med: wages 250k + SE 100k, single = 1281", T.addl_med_at(250000n, 100000n, 200000n), 1281n)
    ck("addl med: no income = 0", T.addl_med_at(0n, 0n, 200000n), 0n)
    ck("niit: magi 300k / nii 100k, single = 3800", T.niit_at(300000n, 100000n, 200000n), 3800n)
    ck("niit: nii-capped (magi 210k / nii 100k) = 380", T.niit_at(210000n, 100000n, 200000n), 380n)
    ck("niit: below threshold = 0", T.niit_at(150000n, 100000n, 200000n), 0n)
    ck("qbi non-SSTB wage-capped: qbi 100k / w2 10k = 5000", T.qbi_ded_non_sstb(100000n, 10000n, 600000n, 0n), 5000n)
    ck("qbi non-SSTB wage limit not binding: w2 120k = 20000", T.qbi_ded_non_sstb(100000n, 120000n, 600000n, 0n), 20000n)
    ck("qbi SSTB below threshold = full 20%", T.qbi_ded_at(1n, 100000n, 120000n, 150000n, 0n, 191950n, 50000n), 20000n)
    ck("qbi SSTB above band end = 0", T.qbi_ded_at(1n, 100000n, 120000n, 600000n, 0n, 191950n, 50000n), 0n)
    ck("qbi SSTB mid-band (appl 50%) = 10000", T.qbi_ded_at(1n, 100000n, 120000n, 216950n, 0n, 191950n, 50000n), 10000n)
    ck("qbi non-SSTB below threshold ignores wage limit", T.qbi_ded_at(0n, 100000n, 10000n, 100000n, 0n, 191950n, 50000n), 20000n)
    ck_bool("qbi monotone across the phaseout (non-SSTB)", qbi_mono_b(112n, 190950n, 100000n, 120000n, 0n, 191950n, 50000n, 0n))
    ck_bool("qbi monotone across the phaseout (SSTB)", qbi_mono_b(112n, 190950n, 100000n, 120000n, 1n, 191950n, 50000n, 0n))

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
