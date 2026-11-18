# taxbender — the return that audits itself

A federal income tax computation (2024, Form 1040) written in
[Bend](https://bend-lang.com), with every claim about it proven by the
compiler and every statutory number pinned against the paper it came
from. `make check` is the compliance gate: **ALL PROOFS CHECK** or it
ships not.

- **Every claim is a proof.** "Every dollar lands in exactly one
  bracket." "The QBI deduction never exceeds 20% of QBI." "Under the
  first bracket, the tax is exactly 10%." "Below their thresholds, the
  surtax bases are exactly zero." [LAWS.bend](bend/LAWS.bend) states
  them in auditor's language; [PROOF.bend](bend/PROOF.bend) proves
  them; the gate refuses any edit that breaks one.
- **Every constant is pinned exactly.** Brackets, LTCG breakpoints,
  standard deductions, rates, thresholds — plus the ENTIRE published
  Tax Table (all 2,062 rows × every status, transcribed from the IRS
  PDF) — checked by `bend run` on every gate run. The old div-window
  manifest tolerated ±9999 dollars of drift; these pins tolerate
  nothing.
- **The wiring is checked against an independent oracle.**
  [oracle.py](oracle.py) reimplements the whole covered scope from its
  own transcription of Rev. Proc. 2023-34 and the IRC and compares all
  nine line components exactly against the engine over randomized and
  boundary-targeted filings. A silent edit to any formula fails
  loudly — the two material bugs the v0.0.1 review caught (a wage base
  100× too large; SE tax ignoring W-2 wages) both passed the old proof
  gate and would both have failed this one.
- **Money is `Nat`** — unbounded, unsigned, saturating. Chosen because
  the proofs need that algebra, not for safety theater; that the return
  *also* can't overflow or go negative line-by-line falls out for free.

## Why an auditor can skip the audit

An auditor does three things: recompute every line, check the
recomputation against the statute, and verify the inputs are real.
This project eliminates the first two and shrinks the third:

1. **Recomputation** — replaced by proofs, exact constant pins, the
   published Tax Table as data, and the differential oracle.
2. **Statute conformance** — the laws *are* the statute, stated as
   equalities the compiler checks on every run. The stacking is
   Schedule D's, mechanically; the Tax Table is honored as mandated
   below $100,000, not approximated.
3. **Inputs** — can never be proven from code (that's W-2/1099
   third-party matching, outside any program). So we make it trivial
   instead: a human-reviewable worksheet, a canonical intermediate form
   with a fingerprint, and glue that refuses to compile anything
   unreviewed.

The precise claim: **IF the facts are true, THEN this tax is exactly
what the statute computes.** That conditional is what an auditor's own
recomputation checks — total, and mechanical.

## Three formats, one chain of custody

| Format | File | Audience | Guarantee |
|---|---|---|---|
| Human review | `inputs/factfile.md` | you | structured Markdown worksheet with checkmarks — nothing compiles while a box is unchecked |
| Intermediate | `inputs/factfile.json` | auditor | canonical, deterministic, one `sha256` fingerprint for the whole chain |
| Native | `inputs/inputs.bend` | the engine | generated, never hand-edited; embeds the fingerprint, printed with the return |

[facts.py](facts.py) is the glue: `parse` (worksheet → JSON, refusing
unchecked or malformed rows, absurd magnitudes, and fat-fingered
amounts), `compile` (JSON → Bend, byte-deterministic), `verify`
(worksheet ↔ JSON ↔ fingerprint), `attest` (print the fingerprint).
Losses are entered as negative amounts on the gains/Schedule C rows;
parse performs Schedule D netting (cross-character offset, the
$3,000/$1,500-MFS cap with carryover reported) and pools the Schedule
Cs before the engine ever sees a number. The fingerprint binds all
three formats: the return prints it, so a filed output is traceable to
the exact reviewed facts.

## Layout

| File | Role |
|---|---|
| [bend/tax.bend](bend/tax.bend) | The engine. Kernels parameterized over the statutory tables; **no statutory numbers**. |
| [bend/tables_2024.bend](bend/tables_2024.bend) | 2024 amounts that don't depend on filing status (rates, SS wage base, Tax Table grid). |
| [bend/tables_2024_single.bend](bend/tables_2024_single.bend) | 2024 brackets, LTCG breakpoints, thresholds — **single**. |
| [bend/tables_2024_mfj.bend](bend/tables_2024_mfj.bend) | Same — **married filing jointly**. |
| [bend/tables_2024_mfs.bend](bend/tables_2024_mfs.bend) | Same — **married filing separately**. |
| [bend/tables_2024_hoh.bend](bend/tables_2024_hoh.bend) | Same — **head of household**. |
| [bend/CONST_CHECK.bend](bend/CONST_CHECK.bend) | Every statutory constant pinned exactly, at runtime. |
| [bend/TAX_TABLE_CHECK.bend](bend/TAX_TABLE_CHECK.bend) | GENERATED from the IRS PDF: every published Tax Table row, as data. |
| [scripts/extract_tax_table.py](scripts/extract_tax_table.py) | The transcriber (PDF → TAX_TABLE_CHECK.bend); committed for provenance. |
| [oracle.py](oracle.py) | Differential oracle: independent Python reference vs the engine. |
| [bend/return.bend](bend/return.bend) | Prints the finished return: headline first, story after. |
| [bend/LAWS.bend](bend/LAWS.bend) | The claims, in human-read form. |
| [bend/PROOF.bend](bend/PROOF.bend) | The machine-checked proofs of those claims. |
| [facts.py](facts.py) | The glue: worksheet → JSON → Bend, with the guarantees above. |
| [prepare.sh](prepare.sh) | Interactive wizard: walks the 1040, edit-or-accept each line, then runs the facts pipeline. |
| [constant_check.sh](constant_check.sh) | Gate wrapper: fails on any FAIL line from the runtime checks. |
| [Makefile](Makefile) | Task runner; `make check` is the gate. |

`inputs/` is the seam — the whole folder is gitignored, so sensitive
facts are never committable by accident. Taxpayer **facts** live there;
the **law** travels in `Tables`, built by whichever
`tables_<year>_<status>` module the inputs select. Swapping year or
filing status is one new tables module and one set of pins.

## Usage

Bend must be installed (`curl -fsSL https://bend-lang.com/install.sh | sh`;
the binary lands in `~/.bend/bin`), plus [uv](https://docs.astral.sh/uv/)
for the Python glue.

**File a return interactively:**

```sh
./prepare.sh          # or: make return  (re-derive from an existing factfile.md)
```

**Recompute or audit an existing worksheet:**

```sh
make facts            # parse + verify the worksheet in inputs/
make return           # full pipeline, prints the fingerprinted return
uv run facts.py attest inputs/factfile.json   # sha256 of the reviewed facts
```

**Run the compliance gate** (required before committing):

```sh
make check            # proofs + Lean verdict + exact pins + Tax Table + oracle
make example          # run the whole pipeline over the committed sample
```

A committed sample lives in [examples/](examples/) — worksheet, canonical
JSON, and generated `inputs.bend`, all containing fake numbers. Copy
`examples/factfile.md` to `inputs/factfile.md` to start a real return.

Every printed return also re-checks the tiling law at runtime on its
own status' table, at the filer's own income points.

Note: the checker's unary normalization caps out around six-digit sums,
so the gate is split — [PROOF.bend](bend/PROOF.bend) carries the
arithmetic proofs over symbolic values, and the runtime gates
([CONST_CHECK.bend](bend/CONST_CHECK.bend),
[TAX_TABLE_CHECK.bend](bend/TAX_TABLE_CHECK.bend),
[oracle.py](oracle.py)) pin everything concrete, exactly.

## What's proven

- **Tiling**: a chained 6-bracket table (each floor literally the
  previous floor plus band width) splits income with no gap and no
  overlap — proven *generically* for any chained table, so a new year's
  numbers inherit the proof by construction. `return.bend` re-checks
  the concrete instantiation at runtime, at the filer's own income.
- **The Tax Table is honored, not approximated**: for taxable income
  under $100,000 with no capital gains, the tax is the mandated table
  row — the midpoint tax, rounded half-up — and the model reproduces
  all 2,062 published rows of all four status columns exactly
  (TAX_TABLE_CHECK pins the paper table itself, both endpoints of
  every row).
- **Worksheet identity**: the ordinary tax is exactly
  Σ (band width × rate), floored, plus the top slice.
- **Under the first floor, the tax is exactly 10%** — min collapses and
  every later band is provably empty.
- **LTCG bands behave as labeled**: below the 0% threshold the whole
  gain is in the 0% band; when the stack ends under the 15%→20%
  breakpoint the 20% band is empty.
- **Schedule SE**: the SE tax is exactly Medicare part + Social
  Security part, the SS part caps against the wages left over after
  box 3 (line 8c), and the §164(f) deduction is exactly half of it.
- **§199A**: the QBI deduction never exceeds 20% of qualified business
  income; above the threshold it never exceeds 50% of the W-2 wages the
  business paid; SSTB income phases out across the statutory band
  (monotonicity swept at runtime); and it is *applied*, reducing
  taxable income before the brackets and the stacking.
- **Surtax threshold sandwiches**: under their thresholds, the
  additional Medicare base and the NIIT base are exactly zero.
- **Conservation**: the headline number is exactly the sum of its
  published parts, and `payments = tax extracted + refund` with no
  rounding leak anywhere.

## Scope (on purpose)

Standard deduction only; one taxpayer per return; Schedule Cs pooled
(one SSTB flag, mixed SSTB/non-SSTB allocation deferred); the §199A
25%-wages+2.5%-UBIA alternative, NOL and capital-loss carryover
*tracking* (carryover is computed and reported, not carried into next
year's filing), box-5 Medicare wages (box 1 stands in, documented),
itemized deductions, credits (EITC/CTC), alternative minimum tax, and
multi-year tables are deferred. The `Tables` struct is where the next
year or filing status plugs in: copy a `tables_2024_*.bend` file,
change the numbers, keep the shape — the proofs carry over, the exact
pins catch any constant that drifts, and the oracle catches any wiring
that doesn't match the statute.
