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

## Income (whole dollars, US$)

| item | amount | confirmed |
|---|---|---|
| W-2 wages | 60000 | [x] |
| Social Security wages | 60000 | [x] |
| Taxable interest | 200 | [x] |
| Short-term capital gains (net) | -1200 | [x] |
| Long-term capital gains (net) | 3000 | [x] |
| Business 1 gross receipts (Schedule C) | 42000 | [x] |
| Business 1 expenses (Schedule C) | 8000 | [x] |
| Business 2 gross receipts (Schedule C) | 18000 | [x] |
| Business 2 expenses (Schedule C) | 4000 | [x] |

Losses: the gains (net) and Schedule C rows accept negative amounts —
a net short-term loss is offset against long-term gains first, and a
net capital loss beyond the $3,000 deduction ($1,500 MFS) carries
forward. This sample nets a $1,200 short-term loss against the $3,000
long-term gain, leaving $1,800 of preferential gain.

## Payments (whole dollars, US$)

| item | amount | confirmed |
|---|---|---|
| Federal tax withheld | 6000 | [x] |
| Estimated payments | 4000 | [x] |

## Businesses (if any)

| item | amount | confirmed |
|---|---|---|
| Total W-2 wages your businesses PAID to employees | 16000 | [x] |

- [ ] Any business is a specified service trade (SSTB): health, law, accounting, consulting, financial services, performing arts, athletics, or reputation/skill trades

## Rental property (if any)

| item | amount | confirmed |
|---|---|---|
| Gross rents received (Schedule E) | 24000 | [x] |
| Rental depreciation | 6000 | [x] |
| Rental maintenance and repairs | 1800 | [x] |
| Rental management and other rental costs | 2400 | [x] |

A net rental loss is deductible only up to the §469(i) special
allowance ($25,000, phased out above $100,000 MAGI); the rest is
suspended and reported on the printed return. Rents are Schedule E
income: not self-employment income, and passive for the surtaxes.

## Attestation

- [x] I attest that every amount above matches my records, and every box is checked.

Facts fingerprint: (computed by `uv run facts.py parse`)
