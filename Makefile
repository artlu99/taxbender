# bender — task runner. `make check` is the compliance gate.

BEND ?= $(HOME)/.bend/bin/bend

# The proof checker's parallel evaluation has a stack-depth race: on
# multiple cores the heaviest proofs (floor1 bounds, conservation)
# occasionally overflow. Pinning to one core is deterministic and fast
# enough. Falls back to plain BEND where taskset is unavailable.
BEND_CHECK := $(BEND)
ifneq ($(shell command -v taskset 2>/dev/null),)
BEND_CHECK := taskset -c 0 $(BEND)
endif

.PHONY: check proof verdict manifest return facts example clean

## check: full compliance gate (proofs + verdict + tall-floor manifest)
check: proof verdict manifest

## proof: machine-check every law in LAWS.bend
proof:
	$(BEND_CHECK) bend/PROOF.bend

## verdict: independent Lean-kernel re-check of the same proofs
verdict:
	$(BEND_CHECK) bend/PROOF.bend --verdict

## manifest: pin the tall statutory floors (one checker process per law)
manifest:
	./manifest_check.sh

## return: recompute the return from factfile.md (facts -> inputs -> print)
return:
	uv run facts.py parse inputs/factfile.md --out inputs/factfile.json
	uv run facts.py compile inputs/factfile.json --out inputs/inputs.bend
	$(BEND) bend/return.bend

## facts: parse + verify the human worksheet only
facts:
	uv run facts.py parse inputs/factfile.md --out inputs/factfile.json
	uv run facts.py verify inputs/factfile.md inputs/factfile.json

## example: run the facts pipeline over the committed sample (no real data)
example:
	uv run facts.py parse examples/factfile.md --out examples/factfile.json
	uv run facts.py compile examples/factfile.json --out examples/inputs.bend
	uv run facts.py verify examples/factfile.md examples/factfile.json
	$(BEND) --check-only examples/inputs.bend

## clean: remove generated artifacts
clean:
	rm -f inputs/inputs.bend inputs/factfile.json

help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  /'
