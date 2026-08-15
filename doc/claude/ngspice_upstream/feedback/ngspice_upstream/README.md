# Handoff: ngspice `casemode` findings

Self-contained. Copy this whole directory into the ngspice working tree (or
read it where it sits) — nothing here depends on xschem.

- **`RESPONSE.md`** — the reply, written 2026-08-13 after the findings were
  worked. Which of the nine were fixed, which were not, and what a client
  program has to do differently. **If you are on the xschem side, start here**
  — four of the nine moved, and one of them (`$curcasemode`) removes the probe
  apparatus `FINDINGS.md` argues for.
- **`FINDINGS.md`** — nine findings, ranked, each with the exact deck and the
  measured output. The two marked ⭐ are the ones that blocked `preserve` from
  being a drop-in for a client program; both are now fixed. Findings 2, 3, 4
  and 7 carry a note at their head saying what changed them, and their
  transcripts are left as measured rather than rewritten.
- **`repro/run_all.sh`** — reproduces all nine.
  ```sh
  ./repro/run_all.sh [case-capable-ngspice] [baseline-ngspice]
  ```
  Defaults: `/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice` and
  `/usr/local/bin/ngspice`. The baseline is optional; findings 1, 6 and 8 use
  it, to show a featureless build accepting and ignoring the flag, and to show
  that the header line finding 1 asks for is one an *unmodified* reader already
  parses. Generated `.raw` files are cleaned on each run and gitignored.
- **`repro/*.cir`** — the decks. All start with a title comment; see the method
  notes at the bottom of `FINDINGS.md` for why that matters.
  `repro/spiceinit/` and `repro/count/` each hold a deck plus the `.spiceinit`
  beside it that the finding depends on (5 and 7 respectively).

Measured 2026-08-12 against `ngspice-46+`, build stamp
`Wed Aug 12 19:28:37 UTC 2026`.

## Where this came from

Adding case-preserving signal names to xschem: a net drawn `EN` should reach
the waveform viewer as `v(EN)`. `preserve` is exactly the right mode for that —
labels keep their capitals while identity still folds, so PDK libraries stay
callable and none of `distinguish`'s silent traps can fire. The findings are
what turned up while wiring it in.

The consuming side's plan, if useful for context, is `doc/claude/casemode_batch/PLAN.md`
**in the xschem tree** — its §0 "Measured facts" is the same evidence base
viewed from the client end. It is not part of this directory and nothing here
needs it.
