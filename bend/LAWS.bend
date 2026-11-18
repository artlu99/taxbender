import Base
import ./tax.bend as T
import ./tables_2024.bend as Y
import ./tables_2024_single.bend as S
import ./tables_2024_mfj.bend as M
import ./tables_2024_mfs.bend as FS
import ./tables_2024_hoh.bend as H

# ============================================================================
# LAWS.bend — the compliance claims. Humans (and auditors) read this file.
# Each law is proven by a def of the same name in PROOF.bend.
# `bend PROOF.bend --verdict` is the gate: ALL PROOFS CHECK or it ships not.
#
# Two kinds of laws live here:
#   - CONCRETE laws about tax.bend's 2024 tables and functions;
#   - GENERIC laws about any chained bracket table (pure Nat, no T refs),
#     which the concrete table instantiates by construction — tax.bend
#     literally defines F(k+1) = F(k) + width — and which return.bend
#     re-checks at runtime on sample incomes.
# ============================================================================

# ---- arithmetic foundation -------------------------------------------------

law add_zero_r:
  for +x: Nat
  {x == Nat.add(x, 0n) : Nat}

law add_succ_r:
  for +x: Nat
  for +y: Nat
  {Nat.add(x, 1n+y) == 1n+Nat.add(x, y) : Nat}

law add_succ_l:
  for +x: Nat
  for +y: Nat
  {1n+Nat.add(x, y) == Nat.add(x, 1n+y) : Nat}

law add_comm:
  for +x: Nat
  for +y: Nat
  {Nat.add(x, y) == Nat.add(y, x) : Nat}

law add_assoc:
  for +x: Nat
  for +y: Nat
  for +z: Nat
  {Nat.add(Nat.add(x, y), z) == Nat.add(x, Nat.add(y, z)) : Nat}

law sub_zero_r:
  for +x: Nat
  {x == Nat.sub(x, 0n) : Nat}

law sub_diag:
  for +x: Nat
  {Nat.sub(x, x) == 0n : Nat}

law sub_add_cancel:
  for +lo: Nat
  for +w: Nat
  {w == Nat.sub(Nat.add(lo, w), lo) : Nat}

# the master tiling lemma: min(i, m+w) splits exactly at m
law min_split:
  for +i: Nat
  for +m: Nat
  for +w: Nat
  {Nat.min(i, Nat.add(m, w)) == Nat.add(Nat.min(i, m), Nat.sub(Nat.min(i, Nat.add(m, w)), m)) : Nat}

law min_add_le:
  for +i: Nat
  for +r: Nat
  {Nat.min(i, Nat.add(i, r)) == i : Nat}

law min_le_l:
  for +a: Nat
  for +b: Nat
  {Nat.sub(Nat.min(a, b), a) == 0n : Nat}

# min(a, b) collapses to a when b = a + r (the "at most the rate" lemma)
law min_le_r1:
  for +a: Nat
  for +b: Nat
  for r: Nat
  for e: {b == Nat.add(a, r) : Nat}
  {Nat.min(a, b) == a : Nat}

law min_le_r2:
  for +a: Nat
  for +b: Nat
  for +r1: Nat
  for +r2: Nat
  for e: {b == Nat.add(a, Nat.add(r1, r2)) : Nat}
  {Nat.min(a, b) == a : Nat}

# ---- GENERIC: a chained 6-bracket table tiles income with no gap and no
# ---- overlap. This is the theorem every progressive schedule must satisfy;
# ---- the concrete table in tax.bend is chained by construction (F(k+1) is
# ---- literally F(k) + width), and return.bend re-checks it at runtime.
law bands_tile6:
  for +i: Nat
  for +f1: Nat
  for +w2: Nat
  for +w3: Nat
  for +w4: Nat
  for +w5: Nat
  for +w6: Nat
  {Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.min(i, f1), Nat.sub(Nat.min(i, Nat.add(f1, w2)), f1)), Nat.sub(Nat.min(i, Nat.add(Nat.add(f1, w2), w3)), Nat.add(f1, w2))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(f1, w2), w3), w4)), Nat.add(Nat.add(f1, w2), w3))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5)), Nat.add(Nat.add(Nat.add(f1, w2), w3), w4))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6)), Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5)))
   == Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6)) : Nat}

# ---- self-employment tax (Schedule SE) --------------------------------------

# the SE tax is exactly the Medicare part plus the Social Security part,
# and the deduction is exactly half of it (§164(f))
law se_tax_split:
  for +e: Nat
  for +base: Nat
  {T.se_tax_at(e, base) == Nat.add(T.med_part(e), T.ss_part_at(e, base)) : Nat}

law se_ded_half:
  for +e: Nat
  for +base: Nat
  {T.se_deduction_at(e, base) == Nat.div(T.se_tax_at(e, base), 2n) : Nat}

# ---- ordinary brackets -------------------------------------------------------

# your ordinary tax is exactly Σ (band width × band rate) plus the top
# slice — the IRS worksheet, stated as a fact about the kernel, for ANY
# chained table and rate schedule
law ordinary_tax_by_bands:
  for +i: Nat
  for +f1: Nat
  for +f2: Nat
  for +f3: Nat
  for +f4: Nat
  for +f5: Nat
  for +f6: Nat
  for +r10: Nat
  for +r12: Nat
  for +r22: Nat
  for +r24: Nat
  for +r32: Nat
  for +r35: Nat
  for +r37: Nat
  {T.ordinary_tax_at(i, f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37)
    == Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(
         Nat.div(Nat.mul(Nat.min(i, f1), r10), 10000n),
         Nat.div(Nat.mul(Nat.sub(Nat.min(i, f2), f1), r12), 10000n)),
         Nat.div(Nat.mul(Nat.sub(Nat.min(i, f3), f2), r22), 10000n)),
         Nat.div(Nat.mul(Nat.sub(Nat.min(i, f4), f3), r24), 10000n)),
         Nat.div(Nat.mul(Nat.sub(Nat.min(i, f5), f4), r32), 10000n)),
    Nat.add(Nat.div(Nat.mul(Nat.sub(Nat.min(i, f6), f5), r35), 10000n),
            Nat.div(Nat.mul(Nat.sub(i, f6), r37), 10000n))) : Nat}

# ---- long-term capital gains -------------------------------------------------

# ---- long-term capital gains: each band behaves as labeled -------------------

# under the 0% threshold, the ENTIRE gain sits in the 0% band
law ltcg_g0_all:
  for +oi: Nat
  for +g: Nat
  for +t1: Nat
  for +r: Nat
  for h1: {t1 == Nat.add(Nat.add(oi, g), r) : Nat}
  {T.g0_at(oi, g, t1) == g : Nat}

# with two threshold-steps of headroom facts, the 20% band is empty when the
# stack ends below t2 (the premises restate t2 = oi+g+r+x in the two shapes
# the proof consumes; proof values are affine, each is used once)
law ltcg_g20_zero:
  for +oi: Nat
  for +g: Nat
  for +t1: Nat
  for +t2: Nat
  for +r: Nat
  for +x: Nat
  for h2a: {t2 == Nat.add(Nat.add(oi, g), Nat.add(r, x)) : Nat}
  for h2b: {t2 == Nat.add(oi, Nat.add(g, Nat.add(r, x))) : Nat}
  {T.g20_at(oi, g, t1, t2) == 0n : Nat}

# and therefore the 15% band absorbs exactly the remainder — zero here
law ltcg_g15_zero:
  for +oi: Nat
  for +g: Nat
  for +t1: Nat
  for +t2: Nat
  for +r: Nat
  for +x: Nat
  for h1: {t1 == Nat.add(Nat.add(oi, g), r) : Nat}
  for h2a: {t2 == Nat.add(Nat.add(oi, g), Nat.add(r, x)) : Nat}
  for h2b: {t2 == Nat.add(oi, Nat.add(g, Nat.add(r, x))) : Nat}
  {T.g15_at(oi, g, t1, t2) == 0n : Nat}

# if taxable income plus long-term gain sits entirely under the 0%
# threshold, the long-term gains tax is exactly zero — the 0% band is real.
# The four h2 premises restate the same threshold fact in the shapes the
# proof consumes (proof values are affine; each is used once).
law ltcg_zero_band:
  for +oi: Nat
  for +g: Nat
  for +t1: Nat
  for +t2: Nat
  for +r: Nat
  for +x: Nat
  for h1: {t1 == Nat.add(Nat.add(oi, g), r) : Nat}
  for h2a: {t2 == Nat.add(Nat.add(oi, g), Nat.add(r, x)) : Nat}
  for h2b: {t2 == Nat.add(oi, Nat.add(g, Nat.add(r, x))) : Nat}
  for h2c: {t2 == Nat.add(Nat.add(oi, g), Nat.add(r, x)) : Nat}
  for h2d: {t2 == Nat.add(oi, Nat.add(g, Nat.add(r, x))) : Nat}
  {T.ltcg_tax_at(oi, g, t1, t2) == 0n : Nat}

# ---- qualified business income (§199A) ---------------------------------------

# the QBI deduction never exceeds 20% of qualified business income
# (saturating subtraction to zero is ≤)
law qbi_min_bound:
  for +qbi: Nat
  for +ti_pre: Nat
  for +ncg: Nat
  {Nat.sub(T.qbi_core(qbi, ti_pre, ncg), Nat.div(Nat.mul(qbi, 2000n), 10000n)) == 0n : Nat}

# above the threshold, the non-SSTB deduction never exceeds 50% of the
# wages the business paid (§199A(b)(2)(B)); SSTB phaseout monotonicity
# and the wage-limit binding points are swept exactly at runtime
law qbi_wage_capped:
  for +qbi: Nat
  for +w2: Nat
  for +ti_pre: Nat
  for +ncg: Nat
  {Nat.sub(T.qbi_ded_non_sstb(qbi, w2, ti_pre, ncg), Nat.div(Nat.mul(w2, 5000n), 10000n)) == 0n : Nat}

# ---- threshold sandwiches ----------------------------------------------------
# zero below the threshold, positive above it — the surtax analogues of
# the LTCG band laws

law min_zero_l:
  for +x: Nat
  {Nat.min(0n, x) == 0n : Nat}

law min_le_r:
  for +a: Nat
  for +b: Nat
  {Nat.sub(Nat.min(a, b), b) == 0n : Nat}

# with combined wages + SE earnings under the threshold (thr = base + r),
# the additional Medicare taxed base is exactly zero — and since the rate
# multiplies it, the tax is (niit: likewise on its base)
law medicare_below_thr_zero:
  for +w: Nat
  for +e: Nat
  for +thr: Nat
  for +r: Nat
  for h1: {thr == Nat.add(Nat.add(w, T.se_base(e)), r) : Nat}
  {T.addl_med_base_at(w, e, thr) == 0n : Nat}

# with MAGI under the NIIT threshold (thr = magi + r), the NIIT base is zero
law niit_below_thr_zero:
  for +magi: Nat
  for +nii: Nat
  for +thr: Nat
  for +r: Nat
  for h1: {thr == Nat.add(magi, r) : Nat}
  {T.niit_base_at(magi, nii, thr) == 0n : Nat}

# ---- rental loss special allowance (§469(i)) ---------------------------------

# the allowance never exceeds the raw rental loss
law rental_allowance_bounded:
  for +loss: Nat
  for +agi_pre: Nat
  {Nat.sub(T.rental_allowance_at(loss, agi_pre), loss) == 0n : Nat}

# below the phaseout start, the allowance is exactly min(loss, $25,000) —
# no phaseout has bitten
law rental_allowance_unphased:
  for +loss: Nat
  for +agi_pre: Nat
  for +r: Nat
  for h1: {Y.RENTAL_ALLOWANCE_PHASE_START() == Nat.add(agi_pre, r) : Nat}
  {T.rental_allowance_at(loss, agi_pre) == Nat.min(loss, Y.RENTAL_ALLOWANCE_MAX()) : Nat}

# ---- the IRS Tax Table (taxable income below $100,000) ----------------------

# a table row is exactly the midpoint (a + w/2) tax rounded half-up to
# the dollar — the construction that matches ALL 2,062 published rows of
# every status column, where the 60 exact-tie rows (302.5 → 303 etc.)
# pin the rounding direction. The grid structure constants are pinned
# below; every published row value is re-checked at runtime by
# TAX_TABLE_CHECK.bend.
law tax_row_at_midpoint:
  for +a: Nat
  for +w: Nat
  for +f1: Nat
  for +f2: Nat
  for +f3: Nat
  for +f4: Nat
  for +f5: Nat
  for +f6: Nat
  for +r10: Nat
  for +r12: Nat
  for +r22: Nat
  for +r24: Nat
  for +r32: Nat
  for +r35: Nat
  for +r37: Nat
  {T.tax_row_at(a, w, f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37)
    == Nat.div(Nat.add(T.cont2_at(Nat.add(Nat.mul(a, 2n), w), f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37), 10000n), 20000n) : Nat}

law manifest_tax_table_max: {Y.TAX_TABLE_MAX() == 100000n : Nat}
law manifest_tax_w1: {Y.TAX_W1() == 5n : Nat}
law manifest_tax_w2: {Y.TAX_W2() == 10n : Nat}
law manifest_tax_w3: {Y.TAX_W3() == 25n : Nat}
law manifest_tax_w4: {Y.TAX_W4() == 50n : Nat}
law manifest_tax_b2: {Y.TAX_B2() == 5n : Nat}
law manifest_tax_b3: {Y.TAX_B3() == 15n : Nat}
law manifest_tax_b4: {Y.TAX_B4() == 25n : Nat}
law manifest_tax_b5: {Y.TAX_B5() == 3000n : Nat}

# ---- the return, recomputed line by line ------------------------------------

# the headline number is exactly the sum of its published parts:
# ordinary tax, stacked LTCG tax, and self-employment tax
law tax_parts:
  for +f: T.Filing
  for +tb: T.Tables
  {T.tax(f, tb)
    == Nat.add(T.ordinary_part(T.ordinary_ti(f, tb), T.net_cap_gain(f), tb),
       Nat.add(T.ltcg_tax(T.ordinary_ti(f, tb), T.net_cap_gain(f), tb),
       Nat.add(T.se_tax(T.ss_wages_of(f), T.biz_profit_of(f), tb),
       Nat.add(T.addl_med(f, tb), T.niit(f, tb))))) : Nat}

# the QBI deduction is not a memo: it reduces taxable income,
# measured against the pre-QBI base the statute caps on
law qbi_applied:
  for +f: T.Filing
  for +tb: T.Tables
  {T.taxable_income(f, tb)
    == Nat.sub(T.taxable_income_pre(f, tb), T.qbi(f, tb)) : Nat}

# ---- money conservation: nothing appears or disappears ----------------------

# the master split: min(a,b) and the remainder of a over b reassemble a.
# Applied to paid vs tax, this is "payments = tax extracted + refund"
# and "tax = payments + amount owed" — exactly, with no rounding leak.
law min_sub_split:
  for +a: Nat
  for +b: Nat
  {Nat.add(Nat.min(a, b), Nat.sub(a, b)) == a : Nat}

law refund_conserves:
  for +f: T.Filing
  for +tb: T.Tables
  {Nat.add(Nat.min(T.paid(f), T.tax(f, tb)), T.refund(f, tb)) == T.paid(f) : Nat}

law owed_conserves:
  for +f: T.Filing
  for +tb: T.Tables
  {Nat.add(Nat.min(T.tax(f, tb), T.paid(f)), T.owed(f, tb)) == T.tax(f, tb) : Nat}

# ---- bounds -------------------------------------------------------------------

# subtraction of a positive step saturates: sub(i, i+r) is 0 — the
# lemma the bracket-bound proofs are built on
law sub_add_zero:
  for +i: Nat
  for +r: Nat
  {Nat.sub(i, Nat.add(i, r)) == 0n : Nat}

# the same saturation, stated on the floor directly: with a headroom
# fact f == i + r, sub(i, f) is exactly 0 (the shape the bound proofs
# consume)
law sub_prem_zero:
  for +i: Nat
  for +f: Nat
  for +r: Nat
  for e: {f == Nat.add(i, r) : Nat}
  {Nat.sub(i, f) == 0n : Nat}

# under the first floor, the tax is exactly the 10% worksheet line —
# not approximately, exactly: min collapses and every later band is
# empty. Premises restate the floors as above income in the shapes the
# proof consumes (affine; each is used twice, so stated twice).
law ordinary_tax_at_floor1:
  for +i: Nat
  for +f1: Nat
  for +f2: Nat
  for +f3: Nat
  for +f4: Nat
  for +f5: Nat
  for +f6: Nat
  for +r10: Nat
  for +r12: Nat
  for +r22: Nat
  for +r24: Nat
  for +r32: Nat
  for +r35: Nat
  for +r37: Nat
  for +ra: Nat
  for +rb: Nat
  for +rc: Nat
  for +rd: Nat
  for +re: Nat
  for +rf: Nat
  for ha: {f1 == Nat.add(i, ra) : Nat}
  for hb: {f1 == Nat.add(i, ra) : Nat}
  for hc: {f2 == Nat.add(i, rb) : Nat}
  for hd: {f2 == Nat.add(i, rb) : Nat}
  for he: {f3 == Nat.add(i, rc) : Nat}
  for hf: {f3 == Nat.add(i, rc) : Nat}
  for hg: {f4 == Nat.add(i, rd) : Nat}
  for hh: {f4 == Nat.add(i, rd) : Nat}
  for hi: {f5 == Nat.add(i, re) : Nat}
  for hj: {f5 == Nat.add(i, re) : Nat}
  for hk: {f6 == Nat.add(i, rf) : Nat}
  for hl: {f6 == Nat.add(i, rf) : Nat}
  {T.ordinary_tax_at(i, f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37)
    == Nat.div(Nat.mul(i, r10), 10000n) : Nat}

# ---- the manifest: the constants an auditor cross-checks ----------------------
# The ONLY numbers a human verifies against IRS Rev. Proc. 2023-34 live in
# the tables modules. Two independent gates pin them:
#   - here: small-literal laws the checker can normalize cheaply;
#   - constant_check.sh: EVERY statutory constant pinned exactly, checked
#     by `bend run` (the runtime handles magnitudes the checker's unary
#     normalization cannot; the old div-window manifest was drift-tolerant
#     by ±9999 dollars — these pins are exact).

law manifest_single_f1: {S.F1() == 11600n : Nat}
law manifest_single_t1: {S.T1() == 47025n : Nat}
law manifest_single_std: {S.STD_DED() == 14600n : Nat}

law manifest_mfj_f1: {M.F1() == 23200n : Nat}
law manifest_mfj_t1: {M.T1() == 94050n : Nat}
law manifest_mfj_std: {M.STD_DED() == 29200n : Nat}

law manifest_mfs_f1: {FS.F1() == 11600n : Nat}
law manifest_mfs_t1: {FS.T1() == 47025n : Nat}
law manifest_mfs_std: {FS.STD_DED() == 14600n : Nat}

law manifest_hoh_f1: {H.F1() == 16550n : Nat}
law manifest_hoh_t1: {H.T1() == 63000n : Nat}
law manifest_hoh_std: {H.STD_DED() == 21900n : Nat}

law manifest_r10: {Y.R10() == 1000n : Nat}
law manifest_r12: {Y.R12() == 1200n : Nat}
law manifest_r22: {Y.R22() == 2200n : Nat}
law manifest_r24: {Y.R24() == 2400n : Nat}
law manifest_r32: {Y.R32() == 3200n : Nat}
law manifest_r35: {Y.R35() == 3500n : Nat}
law manifest_r37: {Y.R37() == 3700n : Nat}
# 168600 = the 2024 Social Security wage base ($168,600)
law manifest_ss_base: {Y.SS_WAGE_BASE() == 168600n : Nat}
# 9235 = 92.35% (Schedule SE line 4a factor); 1240 = 12.4% SS part,
# 290 = 2.9% Medicare part (§1401); 1500/2000 = 15%/20% LTCG rates;
# 2000 = the 20% §199A percentage
law manifest_se_factor: {Y.SE_FACTOR() == 9235n : Nat}
law manifest_se_ss_rate: {Y.SE_SS_RATE() == 1240n : Nat}
law manifest_se_med_rate: {Y.SE_MED_RATE() == 290n : Nat}
law manifest_ltcg15: {Y.LTCG15() == 1500n : Nat}
law manifest_ltcg20: {Y.LTCG20() == 2000n : Nat}
law manifest_qbi_rate: {Y.QBI_RATE() == 2000n : Nat}

# ---- deferred to the next phase ----------------------------------------------
# marginal-rate sandwich (every dollar taxed between 10% and 37%),
# itemized deductions, multi-year tables.
