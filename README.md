# taxbender — the return that audits itself

A federal income tax computation (2024, Form 1040) written in
[Bend](https://bend-lang.com), with every claim about it proven by the
compiler. `make check` is the compliance gate: **ALL PROOFS CHECK**
or it ships not.

- **Every claim is a proof.** "Every dollar lands in exactly one
  bracket." "The QBI deduction never exceeds 20% of QBI." "Under the
  first bracket, the tax is exactly 10%." [LAWS.bend](LAWS.bend) states
  them in auditor's language; [PROOF.bend](PROOF.bend) proves them; the
  gate refuses any edit that breaks one.
- **Money is `Nat`** — unbounded, unsigned, saturating. Chosen because
  the proofs need that algebra, not for safety theater; that the return
  *also* can't overflow or go negative line-by-line falls out for free.
- **The audit surface is ~20 constants.** Everything computable about
  this return is machine-verified. The only human judgment left is
  checking the statutory tables against Rev. Proc. 2023-34 — and the
  manifest pins those, so a wrong constant fails the gate.

## Why an auditor can skip the audit

An auditor does three things: recompute every line, check the
recomputation against the statute, and verify the inputs are real.
This project eliminates the first two and shrinks the third:

1. **Recomputation** — replaced by proofs. The checker verifies each
   line follows from the previous one, conservatively (money never
   appears or disappears: `payments = tax extracted + refund`, exactly,
   with no rounding leak), and within statutory bounds (under the first
   floor the tax is exactly 10%; the Social Security cap really caps).
2. **Statute conformance** — the laws *are* the statute, stated as
   equalities the compiler checks on every run. The stacking is
   Schedule D's, mechanically.
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
unchecked or malformed rows), `compile` (JSON → Bend, byte-deterministic),
`verify` (worksheet ↔ JSON ↔ fingerprint), `attest` (print the
fingerprint). The fingerprint binds all three: the return prints it, so
a filed output is traceable to the exact reviewed facts.

## Layout

| File | Role |
|---|---|
| [bend/tax.bend](bend/tax.bend) | The engine. Kernels parameterized over the statutory tables; **no numbers**. |
| [bend/tables_2024.bend](bend/tables_2024.bend) | 2024 amounts that don't depend on filing status (rates, SS wage base). |
| [bend/tables_2024_single.bend](bend/tables_2024_single.bend) | 2024 brackets, LTCG breakpoints, standard deduction — **single**. |
| [bend/tables_2024_mfj.bend](bend/tables_2024_mfj.bend) | Same — **married filing jointly**. |
| [prepare.sh](prepare.sh) | Interactive wizard: walks the 1040, edit-or-accept each line, then runs the facts pipeline. |
| [facts.py](facts.py) | The glue: worksheet → JSON → Bend, with the guarantees above. |
| [bend/return.bend](bend/return.bend) | Prints the finished return: headline first, story after. |
| [bend/LAWS.bend](bend/LAWS.bend) | The claims, in human-read form. |
| [bend/PROOF.bend](bend/PROOF.bend) | The machine-checked proofs of those claims. |
| [bend/CONST_CHECK.bend](bend/CONST_CHECK.bend) | Every statutory constant pinned **exactly**, checked by `bend run` (runtime handles magnitudes the checker can't). |
| [Makefile](Makefile) | Task runner; `make check` is the gate. |

`inputs/` is the seam — the whole folder is gitignored, so sensitive
facts are never committable by accident. The pipeline generates
`inputs/inputs.bend`; `return.bend` reads it. Taxpayer **facts** live there; the **law** travels in
`Tables`, built by whichever `tables_<year>_<status>` module the inputs
select. Swapping year or filing status is one new tables module and one
`manifest_check.sh` entry.

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

**Run the compliance gate** (required before committing, per
[AGENTS.md](AGENTS.md)):

```sh
make check            # proofs + Lean-kernel verdict + exact constant pins
make example          # run the whole pipeline over the committed sample
```

A committed sample lives in [examples/](examples/) — worksheet, canonical
JSON, and generated `inputs.bend`, all containing fake numbers. Copy
`examples/factfile.md` to `inputs/factfile.md` to start a real return.

Every printed return also re-checks the tiling law at runtime on its own
status' table.

Note: the checker's unary normalization caps out around six-digit sums,
so the gate is split — [PROOF.bend](PROOF.bend) carries the arithmetic
proofs, and [CONST_CHECK.bend](bend/CONST_CHECK.bend) pins **every**
statutory constant exactly by `bend run` (the old div-window manifest
tolerated ±9999 dollars of drift; these pins tolerate nothing).

## What's proven

- **Tiling**: a chained 6-bracket table (each floor literally the
  previous floor plus band width) splits income with no gap and no
  overlap — proven *generically* for any chained table, so a new year's
  numbers inherit the proof by construction. `return.bend` re-checks the
  concrete instantiation at runtime.
- **Worksheet identity**: the ordinary tax is exactly
  Σ (band width × rate), floored, plus the top slice.
- **Under the first floor, the tax is exactly 10%** — min collapses and
  every later band is provably empty.
- **LTCG bands behave as labeled**: below the 0% threshold the whole
  gain is in the 0% band; when the stack ends under the 15%→20%
  breakpoint the 20% band is empty.
- **Schedule SE**: the SE tax is exactly Medicare part + Social
  Security part, and the §164(f) deduction is exactly half of it.
- **§199A**: the QBI deduction never exceeds 20% of qualified business
  income — and it is *applied*, reducing taxable income before the
  brackets and the LTCG stacking, not printed as a memo.
- **Conservation**: `tax == ordinary + ltcg + se` exactly, and
  `payments = tax extracted + refund` with no rounding leak anywhere.

## Scope (on purpose)

Single standard deduction only; one taxpayer per return; the 0.9%
additional Medicare tax, wage/SSTB limits on §199A, NIIT, itemized
deductions, and multi-year tables are deferred. The `Tables` struct is
where the next year or filing status
plugs in: copy a `tables_2024_*.bend` file, change the numbers, keep
the shape — the proofs carry over, and the manifest catches any
constant that drifts.
