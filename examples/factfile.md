# 2024 Form 1040 — SAMPLE facts worksheet
#
# This file is COMMITTED: it demonstrates the worksheet format and gives
# the pipeline something to chew on in CI. It contains no real taxpayer
# data. Your actual facts live in inputs/factfile.md (gitignored).
#
# To file a real return: copy this file to inputs/factfile.md, put your
# own numbers in, check every box, then run  make return .

## Filing status
- [x] Married filing jointly  (tables: `tables_2024_mfj`)
- [ ] Single  (tables: `tables_2024_single`)
- [ ] Married filing separately  (tables: `tables_2024_mfs`)
- [ ] Head of household  (tables: `tables_2024_hoh`)

## Income (whole dollars, US$)

| item | amount | confirmed |
|---|---|---|
| W-2 wages | 60000 | [x] |
| Social Security wages | 60000 | [x] |
| Taxable interest | 200 | [x] |
| Short-term capital gains (net) | 800 | [x] |
| Long-term capital gains (net) | 3000 | [x] |
| Business 1 net profit (Schedule C) | 42000 | [x] |
| Business 2 net profit (Schedule C) | 18000 | [x] |

## Payments (whole dollars, US$)

| item | amount | confirmed |
|---|---|---|
| Federal tax withheld | 6000 | [x] |
| Estimated payments | 4000 | [x] |

## Attestation

- [x] I attest that every amount above matches my records, and every box is checked.

Facts fingerprint: (computed by `uv run facts.py parse`)
