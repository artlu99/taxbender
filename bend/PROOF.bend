import Base
import ./tax.bend as T
import ./LAWS.bend as Laws

# ============================================================================
# PROOF.bend — the proofs. The machine reads this file.
# Run: bend PROOF.bend            (checker gate)
#      bend PROOF.bend --verdict  (independent Lean kernel re-check)
#
# Rewrite discipline:
#   %e : P  with  e : {a == b}
#   requires  P[_ := b] == goal   (`_` marks where b sits in the goal,
#                                 and only that occurrence is replaced)
#   and leaves the goal as  P[_ := a].
#   To flip a lemma whose b-form does not appear in the goal, wrap it in
#   Equal.sym(A, x0, y0, e0) with e0 : {x0 == y0}; it yields {y0 == x0}.
# ============================================================================

# ---- arithmetic foundation -------------------------------------------------

def Laws.add_zero_r(x):
  match x:
    case 0n:
      {==}
    case 1n+p:
      %Laws.add_zero_r(p) : {1n+p == 1n+_ : Nat}
      {==}

def Laws.add_succ_r(x, y):
  match x:
    case 0n:
      {==}
    case 1n+p:
      %Laws.add_succ_r(p, y) : {1n+Nat.add(p, 1n+y) == 1n+_ : Nat}
      {==}

def Laws.add_succ_l(x, y):
  %Laws.add_succ_r(x, y) : {_ == Nat.add(x, 1n+y) : Nat}
  {==}

def Laws.add_comm(x, y):
  match x:
    case 0n:
      %Laws.add_zero_r(y) : {y == _ : Nat}
      {==}
    case 1n+p:
      %Laws.add_succ_l(y, p) : {1n+Nat.add(p, y) == _ : Nat}
      %Laws.add_comm(p, y) : {1n+Nat.add(p, y) == 1n+_ : Nat}
      {==}

def Laws.add_assoc(x, y, z):
  match x:
    case 0n:
      {==}
    case 1n+p:
      %Laws.add_assoc(p, y, z) : {1n+Nat.add(Nat.add(p, y), z) == 1n+_ : Nat}
      {==}

def Laws.sub_zero_r(x):
  match x:
    case 0n:
      {==}
    case 1n+p:
      {==}

def Laws.sub_diag(x):
  match x:
    case 0n:
      {==}
    case 1n+p:
      %Laws.sub_diag(p) : {Nat.sub(p, p) == _ : Nat}
      {==}

def Laws.sub_add_cancel(lo, w):
  match lo:
    case 0n:
      %Laws.sub_zero_r(w) : {w == _ : Nat}
      {==}
    case 1n+lp:
      %Laws.sub_add_cancel(lp, w) : {w == _ : Nat}
      {==}

def Laws.min_split(i, m, w):
  match i:
    case 0n:
      {==}
    case 1n+ip:
      match m:
        case 0n:
          %Laws.sub_zero_r(Nat.min(1n+ip, w)) : {Nat.min(1n+ip, w) == _ : Nat}
          {==}
        case 1n+mp:
          %Equal.sym(Nat,
            Nat.min(ip, Nat.add(mp, w)),
            Nat.add(Nat.min(ip, mp), Nat.sub(Nat.min(ip, Nat.add(mp, w)), mp)),
            Laws.min_split(ip, mp, w))
            : {1n+_ == 1n+Nat.add(Nat.min(ip, mp), Nat.sub(Nat.min(ip, Nat.add(mp, w)), mp)) : Nat}
          {==}

def Laws.min_add_le(i, r):
  match i:
    case 0n:
      {==}
    case 1n+ip:
      %Equal.sym(Nat, Nat.min(ip, Nat.add(ip, r)), ip, Laws.min_add_le(ip, r))
        : {1n+_ == 1n+ip : Nat}
      {==}

def Laws.min_le_l(a, b):
  match a b:
    case 0n _:
      {==}
    case 1n+ap 0n:
      {==}
    case 1n+ap 1n+bp:
      %Laws.min_le_l(ap, bp) : {Nat.sub(Nat.min(ap, bp), ap) == _ : Nat}
      {==}

def Laws.min_le_r1(a, b, r, e):
  %Equal.sym(Nat, b, Nat.add(a, r), e) : {Nat.min(a, _) == a : Nat}
  Laws.min_add_le(a, r)

def Laws.min_le_r2(a, b, r1, r2, e):
  %Equal.sym(Nat, b, Nat.add(a, Nat.add(r1, r2)), e) : {Nat.min(a, _) == a : Nat}
  Laws.min_add_le(a, Nat.add(r1, r2))

# ---- GENERIC: a chained 6-bracket table tiles income ------------------------
# Five splits, outermost first; then both sides are the same tree.

def Laws.bands_tile6(i, f1, w2, w3, w4, w5, w6):
  %Equal.sym(Nat, Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6)), Nat.add(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5)), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6)), Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5))), Laws.min_split(i, Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.min(i, f1), Nat.sub(Nat.min(i, Nat.add(f1, w2)), f1)), Nat.sub(Nat.min(i, Nat.add(Nat.add(f1, w2), w3)), Nat.add(f1, w2))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(f1, w2), w3), w4)), Nat.add(Nat.add(f1, w2), w3))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5)), Nat.add(Nat.add(Nat.add(f1, w2), w3), w4))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6)), Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5))) == _ : Nat }
  %Equal.sym(Nat, Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5)), Nat.add(Nat.min(i, Nat.add(Nat.add(Nat.add(f1, w2), w3), w4)), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5)), Nat.add(Nat.add(Nat.add(f1, w2), w3), w4))), Laws.min_split(i, Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.min(i, f1), Nat.sub(Nat.min(i, Nat.add(f1, w2)), f1)), Nat.sub(Nat.min(i, Nat.add(Nat.add(f1, w2), w3)), Nat.add(f1, w2))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(f1, w2), w3), w4)), Nat.add(Nat.add(f1, w2), w3))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5)), Nat.add(Nat.add(Nat.add(f1, w2), w3), w4))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6)), Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5))) == Nat.add(_, Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6)), Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5))) : Nat }
  %Equal.sym(Nat, Nat.min(i, Nat.add(Nat.add(Nat.add(f1, w2), w3), w4)), Nat.add(Nat.min(i, Nat.add(Nat.add(f1, w2), w3)), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(f1, w2), w3), w4)), Nat.add(Nat.add(f1, w2), w3))), Laws.min_split(i, Nat.add(Nat.add(f1, w2), w3), w4))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.min(i, f1), Nat.sub(Nat.min(i, Nat.add(f1, w2)), f1)), Nat.sub(Nat.min(i, Nat.add(Nat.add(f1, w2), w3)), Nat.add(f1, w2))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(f1, w2), w3), w4)), Nat.add(Nat.add(f1, w2), w3))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5)), Nat.add(Nat.add(Nat.add(f1, w2), w3), w4))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6)), Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5))) == Nat.add(Nat.add(_, Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5)), Nat.add(Nat.add(Nat.add(f1, w2), w3), w4))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6)), Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5))) : Nat }
  %Equal.sym(Nat, Nat.min(i, Nat.add(Nat.add(f1, w2), w3)), Nat.add(Nat.min(i, Nat.add(f1, w2)), Nat.sub(Nat.min(i, Nat.add(Nat.add(f1, w2), w3)), Nat.add(f1, w2))), Laws.min_split(i, Nat.add(f1, w2), w3))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.min(i, f1), Nat.sub(Nat.min(i, Nat.add(f1, w2)), f1)), Nat.sub(Nat.min(i, Nat.add(Nat.add(f1, w2), w3)), Nat.add(f1, w2))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(f1, w2), w3), w4)), Nat.add(Nat.add(f1, w2), w3))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5)), Nat.add(Nat.add(Nat.add(f1, w2), w3), w4))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6)), Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5))) == Nat.add(Nat.add(Nat.add(_, Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(f1, w2), w3), w4)), Nat.add(Nat.add(f1, w2), w3))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5)), Nat.add(Nat.add(Nat.add(f1, w2), w3), w4))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6)), Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5))) : Nat }
  %Equal.sym(Nat, Nat.min(i, Nat.add(f1, w2)), Nat.add(Nat.min(i, f1), Nat.sub(Nat.min(i, Nat.add(f1, w2)), f1)), Laws.min_split(i, f1, w2))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.min(i, f1), Nat.sub(Nat.min(i, Nat.add(f1, w2)), f1)), Nat.sub(Nat.min(i, Nat.add(Nat.add(f1, w2), w3)), Nat.add(f1, w2))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(f1, w2), w3), w4)), Nat.add(Nat.add(f1, w2), w3))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5)), Nat.add(Nat.add(Nat.add(f1, w2), w3), w4))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6)), Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5))) == Nat.add(Nat.add(Nat.add(Nat.add(_, Nat.sub(Nat.min(i, Nat.add(Nat.add(f1, w2), w3)), Nat.add(f1, w2))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(f1, w2), w3), w4)), Nat.add(Nat.add(f1, w2), w3))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5)), Nat.add(Nat.add(Nat.add(f1, w2), w3), w4))), Nat.sub(Nat.min(i, Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5), w6)), Nat.add(Nat.add(Nat.add(Nat.add(f1, w2), w3), w4), w5))) : Nat }
  {==}

# ---- self-employment tax -----------------------------------------------------

def Laws.se_tax_split(e, base):
  %Laws.add_comm(T.ss_part_at(e, base), T.med_part(e)) : {T.se_tax_at(e, base) == _ : Nat}
  {==}

def Laws.se_ded_half(e, base):
  {==}

# ---- ordinary brackets: the worksheet law ------------------------------------

def Laws.ordinary_tax_by_bands(i, f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37):
  {==}

def Laws.ltcg_g0_all(oi, g, t1, r, h1):
  %Equal.sym(Nat, Nat.min(Nat.add(oi, g), t1), Nat.add(oi, g), Laws.min_le_r1(Nat.add(oi, g), t1, r, h1))
    : {Nat.sub(_, oi) == g : Nat}
  %Laws.sub_add_cancel(oi, g) : {_ == g : Nat}
  {==}

def Laws.ltcg_g20_zero(oi, g, t1, t2, r, x, h2a, h2b):
  %Equal.sym(Nat, Nat.min(Nat.add(oi, g), t2), Nat.add(oi, g), Laws.min_le_r2(Nat.add(oi, g), t2, r, x, h2a))
    : {Nat.sub(Nat.sub(Nat.add(oi, g), _), Nat.sub(oi, Nat.min(oi, t2))) == 0n : Nat}
  %Equal.sym(Nat, Nat.min(oi, t2), oi, Laws.min_le_r2(oi, t2, g, Nat.add(r, x), h2b))
    : {Nat.sub(Nat.sub(Nat.add(oi, g), Nat.add(oi, g)), Nat.sub(oi, _)) == 0n : Nat}
  %Equal.sym(Nat, Nat.sub(Nat.add(oi, g), Nat.add(oi, g)), 0n, Laws.sub_diag(Nat.add(oi, g)))
    : {Nat.sub(_, Nat.sub(oi, oi)) == 0n : Nat}
  %Equal.sym(Nat, Nat.sub(oi, oi), 0n, Laws.sub_diag(oi))
    : {Nat.sub(0n, _) == 0n : Nat}
  {==}

def Laws.ltcg_g15_zero(oi, g, t1, t2, r, x, h1, h2a, h2b):
  %Equal.sym(Nat, T.g0_at(oi, g, t1), g, Laws.ltcg_g0_all(oi, g, t1, r, h1))
    : {Nat.sub(Nat.sub(g, _), T.g20_at(oi, g, t1, t2)) == 0n : Nat}
  %Equal.sym(Nat, Nat.sub(g, g), 0n, Laws.sub_diag(g))
    : {Nat.sub(_, T.g20_at(oi, g, t1, t2)) == 0n : Nat}
  %Equal.sym(Nat, T.g20_at(oi, g, t1, t2), 0n, Laws.ltcg_g20_zero(oi, g, t1, t2, r, x, h2a, h2b))
    : {Nat.sub(0n, _) == 0n : Nat}
  {==}

def Laws.ltcg_zero_band(oi, g, t1, t2, r, x, h1, h2a, h2b, h2c, h2d):
  %Equal.sym(Nat, T.g15_at(oi, g, t1, t2), 0n,
             Laws.ltcg_g15_zero(oi, g, t1, t2, r, x, h1, h2a, h2b))
    : {Nat.add(Nat.div(Nat.mul(_, 1500n), 10000n),
               Nat.div(Nat.mul(T.g20_at(oi, g, t1, t2), 2000n), 10000n)) == 0n : Nat}
  %Equal.sym(Nat, T.g20_at(oi, g, t1, t2), 0n,
             Laws.ltcg_g20_zero(oi, g, t1, t2, r, x, h2c, h2d))
    : {Nat.add(Nat.div(Nat.mul(0n, 1500n), 10000n),
               Nat.div(Nat.mul(_, 2000n), 10000n)) == 0n : Nat}
  {==}


def Laws.qbi_min_bound(qbi, ti_pre, ncg):
  %Equal.sym(Nat,
    Nat.sub(Nat.min(Nat.div(Nat.mul(qbi, 2000n), 10000n),
                    Nat.div(Nat.mul(Nat.sub(ti_pre, ncg), 2000n), 10000n)),
            Nat.div(Nat.mul(qbi, 2000n), 10000n)),
    0n,
    Laws.min_le_l(Nat.div(Nat.mul(qbi, 2000n), 10000n),
                  Nat.div(Nat.mul(Nat.sub(ti_pre, ncg), 2000n), 10000n)))
    : {_ == 0n : Nat}
  {==}

# ---- the return, recomputed line by line ------------------------------------
# Unfoldings: the right-hand side normalizes to the left.

def Laws.tax_parts(f, tb):
  match f tb:
    case T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est} T.Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_d}:
      {==}

def Laws.qbi_applied(f, tb):
  match f tb:
    case T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est} T.Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_d}:
      {==}

# ---- money conservation -------------------------------------------------------

def Laws.min_sub_split(a, b):
  match a b:
    case 0n _:
      {==}
    case 1n+ap 0n:
      {==}
    case 1n+ap 1n+bp:
      %Laws.min_sub_split(ap, bp) : {1n+Nat.add(Nat.min(ap, bp), Nat.sub(ap, bp)) == 1n+_ : Nat}
      {==}

def Laws.refund_conserves(f, tb):
  match f tb:
    case T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est} T.Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_d}:
      %Laws.min_sub_split(T.paid(T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est}), T.tax(T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est}, T.Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_d}))
        : {Nat.add(Nat.min(T.paid(T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est}), T.tax(T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est}, T.Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_d})), Nat.sub(T.paid(T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est}), T.tax(T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est}, T.Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_d}))) == _ : Nat}
      {==}

def Laws.owed_conserves(f, tb):
  match f tb:
    case T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est} T.Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_d}:
      %Laws.min_sub_split(T.tax(T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est}, T.Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_d}), T.paid(T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est}))
        : {Nat.add(Nat.min(T.tax(T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est}, T.Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_d}), T.paid(T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est})), Nat.sub(T.tax(T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est}, T.Tables{f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, t1, t2, ss_wage_base, std_d}), T.paid(T.Filing{wages, interest, stcg, ltcg, biz1, biz2, withheld, est}))) == _ : Nat}
      {==}

# ---- bounds -------------------------------------------------------------------

def Laws.sub_add_zero(i, r):
  match i:
    case 0n:
      {==}
    case 1n+ip:
      %Laws.sub_add_zero(ip, r) : {Nat.sub(ip, Nat.add(ip, r)) == _ : Nat}
      {==}

def Laws.sub_prem_zero(i, f, r, e):
  %Equal.sym(Nat, f, Nat.add(i, r), e) : {Nat.sub(i, _) == 0n : Nat}
  %Laws.sub_add_zero(i, r) : {Nat.sub(i, Nat.add(i, r)) == _ : Nat}
  {==}

def Laws.ordinary_tax_at_floor1(i, f1, f2, f3, f4, f5, f6, r10, r12, r22, r24, r32, r35, r37, ra, rb, rc, rd, re, rf, ha, hb, hc, hd, he, hf, hg, hh, hi, hj, hk, hl):
  # the kernel sums are left-nested: ((((t1+t2)+t3)+t4)+t5)+(t6+t7);
  # each rewrite's pattern places _ exactly where the lemma's right side sits
  # t1: min(i, f1) -> i  (ha)
  %Equal.sym(Nat, Nat.min(i, f1), i, Laws.min_le_r1(i, f1, ra, ha))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(_, r10), 10000n), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f2), f1), r12), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f3), f2), r22), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f4), f3), r24), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f5), f4), r32), 10000n)), Nat.add(Nat.div(Nat.mul(Nat.sub(Nat.min(i, f6), f5), r35), 10000n), Nat.div(Nat.mul(Nat.sub(i, f6), r37), 10000n))) == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  # band 2: min(i, f2) -> i (hc), then sub(i, f1) -> 0 (hb)
  %Equal.sym(Nat, Nat.min(i, f2), i, Laws.min_le_r1(i, f2, rb, hc))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), Nat.div(Nat.mul(Nat.sub(_, f1), r12), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f3), f2), r22), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f4), f3), r24), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f5), f4), r32), 10000n)), Nat.add(Nat.div(Nat.mul(Nat.sub(Nat.min(i, f6), f5), r35), 10000n), Nat.div(Nat.mul(Nat.sub(i, f6), r37), 10000n))) == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  %Equal.sym(Nat, Nat.sub(i, f1), 0n, Laws.sub_prem_zero(i, f1, ra, hb))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), Nat.div(Nat.mul(_, r12), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f3), f2), r22), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f4), f3), r24), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f5), f4), r32), 10000n)), Nat.add(Nat.div(Nat.mul(Nat.sub(Nat.min(i, f6), f5), r35), 10000n), Nat.div(Nat.mul(Nat.sub(i, f6), r37), 10000n))) == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  # band 3: min(i, f3) -> i (he), then sub(i, f2) -> 0 (hd)
  %Equal.sym(Nat, Nat.min(i, f3), i, Laws.min_le_r1(i, f3, rc, he))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n), Nat.div(Nat.mul(Nat.sub(_, f2), r22), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f4), f3), r24), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f5), f4), r32), 10000n)), Nat.add(Nat.div(Nat.mul(Nat.sub(Nat.min(i, f6), f5), r35), 10000n), Nat.div(Nat.mul(Nat.sub(i, f6), r37), 10000n))) == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  %Equal.sym(Nat, Nat.sub(i, f2), 0n, Laws.sub_prem_zero(i, f2, rb, hd))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n), Nat.div(Nat.mul(_, r22), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f4), f3), r24), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f5), f4), r32), 10000n)), Nat.add(Nat.div(Nat.mul(Nat.sub(Nat.min(i, f6), f5), r35), 10000n), Nat.div(Nat.mul(Nat.sub(i, f6), r37), 10000n))) == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  # band 4: min(i, f4) -> i (hg), then sub(i, f3) -> 0 (hf)
  %Equal.sym(Nat, Nat.min(i, f4), i, Laws.min_le_r1(i, f4, rd, hg))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n), 0n), Nat.div(Nat.mul(Nat.sub(_, f3), r24), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f5), f4), r32), 10000n)), Nat.add(Nat.div(Nat.mul(Nat.sub(Nat.min(i, f6), f5), r35), 10000n), Nat.div(Nat.mul(Nat.sub(i, f6), r37), 10000n))) == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  %Equal.sym(Nat, Nat.sub(i, f3), 0n, Laws.sub_prem_zero(i, f3, rc, hf))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n), 0n), Nat.div(Nat.mul(_, r24), 10000n)), Nat.div(Nat.mul(Nat.sub(Nat.min(i, f5), f4), r32), 10000n)), Nat.add(Nat.div(Nat.mul(Nat.sub(Nat.min(i, f6), f5), r35), 10000n), Nat.div(Nat.mul(Nat.sub(i, f6), r37), 10000n))) == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  # band 5: min(i, f5) -> i (hi), then sub(i, f4) -> 0 (hh)
  %Equal.sym(Nat, Nat.min(i, f5), i, Laws.min_le_r1(i, f5, re, hi))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n), 0n), 0n), Nat.div(Nat.mul(Nat.sub(_, f4), r32), 10000n)), Nat.add(Nat.div(Nat.mul(Nat.sub(Nat.min(i, f6), f5), r35), 10000n), Nat.div(Nat.mul(Nat.sub(i, f6), r37), 10000n))) == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  %Equal.sym(Nat, Nat.sub(i, f4), 0n, Laws.sub_prem_zero(i, f4, rd, hh))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n), 0n), 0n), Nat.div(Nat.mul(_, r32), 10000n)), Nat.add(Nat.div(Nat.mul(Nat.sub(Nat.min(i, f6), f5), r35), 10000n), Nat.div(Nat.mul(Nat.sub(i, f6), r37), 10000n))) == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  # band 6: min(i, f6) -> i (hk), then sub(i, f5) -> 0 (hj)
  %Equal.sym(Nat, Nat.min(i, f6), i, Laws.min_le_r1(i, f6, rf, hk))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n), 0n), 0n), 0n), Nat.add(Nat.div(Nat.mul(Nat.sub(_, f5), r35), 10000n), Nat.div(Nat.mul(Nat.sub(i, f6), r37), 10000n))) == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  %Equal.sym(Nat, Nat.sub(i, f5), 0n, Laws.sub_prem_zero(i, f5, re, hj))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n), 0n), 0n), 0n), Nat.add(Nat.div(Nat.mul(_, r35), 10000n), Nat.div(Nat.mul(Nat.sub(i, f6), r37), 10000n))) == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  # top slice: f6 -> i + rf (hl), then sub(i, f6) -> 0; add(0n, t7) folded to t7
  %Equal.sym(Nat, f6, Nat.add(i, rf), hl)
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n), 0n), 0n), 0n), Nat.div(Nat.mul(Nat.sub(i, _), r37), 10000n)) == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  %Equal.sym(Nat, Nat.sub(i, Nat.add(i, rf)), 0n, Laws.sub_add_zero(i, rf))
    : { Nat.add(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n), 0n), 0n), 0n), Nat.div(Nat.mul(_, r37), 10000n)) == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  # ((((t1+0)+0)+0)+0)+0 — peel the five zero adds, outermost first
  %Laws.add_zero_r(Nat.add(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n), 0n), 0n), 0n))
    : { _ == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  %Laws.add_zero_r(Nat.add(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n), 0n), 0n))
    : { _ == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  %Laws.add_zero_r(Nat.add(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n), 0n))
    : { _ == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  %Laws.add_zero_r(Nat.add(Nat.div(Nat.mul(i, r10), 10000n), 0n))
    : { _ == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  %Laws.add_zero_r(Nat.div(Nat.mul(i, r10), 10000n))
    : { _ == Nat.div(Nat.mul(i, r10), 10000n) : Nat }
  {==}
# ---- the manifest -------------------------------------------------------------

def Laws.manifest_single_f1(): {==}
def Laws.manifest_single_t1(): {==}
def Laws.manifest_single_std(): {==}
def Laws.manifest_mfj_f1(): {==}
def Laws.manifest_mfj_t1(): {==}
def Laws.manifest_mfj_std(): {==}
def Laws.manifest_r10(): {==}
def Laws.manifest_r12(): {==}
def Laws.manifest_r22(): {==}
def Laws.manifest_r24(): {==}
def Laws.manifest_r32(): {==}
def Laws.manifest_r35(): {==}
def Laws.manifest_r37(): {==}
def Laws.manifest_ss_base(): {==}

