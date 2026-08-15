# Handoff: ngspice `casemode` findings

Self-contained. Copy this whole directory into the ngspice working tree (or
read it where it sits) — nothing here depends on xschem.

**This directory now holds two rounds and a reply, so read in this order:**

1. **`feedback/ngspice_upstream/RESPONSE.md`** — the ngspice side's answer to
   round 1 (2026-08-13). Four of the nine moved, including both ⭐ blockers.
   `feedback/ngspice_upstream/FINDINGS.md` is round 1 **with the response's
   notes at each finding's head**, and supersedes the `FINDINGS.md` beside this
   README, which is the copy as sent and is left unedited.
2. **`REPLY.md`** — round 2 (2026-08-14), measured against the tree that
   answered. What we adopted, six new findings, four open questions.
   Repro: `repro2/run_round2.sh`. Three of the six reproduce on stock
   `ngspice-46` and are not casemode defects.
3. **`FINDINGS.md`** — round 1 as originally sent. Historical; one of its asks
   (a new `Casemode:` header key) is measurably wrong, and the response says so.

- **`FINDINGS.md`** — nine findings, ranked, each with the exact deck and the
  measured output. The two marked ⭐ are the ones that blocked `preserve` from
  being a drop-in for a client program; both are now fixed.
- **`repro/run_all.sh`** — reproduces all nine.
  ```sh
  ./repro/run_all.sh [case-capable-ngspice] [baseline-ngspice]
  ```
  Defaults: `/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice` and
  `/usr/local/bin/ngspice`. The baseline is optional (used by findings 6 and 8
  to show a featureless build accepting and ignoring the flag). Generated
  `.raw` files are cleaned on each run and gitignored.
- **`repro/*.cir`** — the decks, one per finding. All start with a title
  comment; see the method notes at the bottom of `FINDINGS.md` for why that
  matters.

Measured 2026-08-12 against `ngspice-46+`, build stamp
`Wed Aug 12 19:28:37 UTC 2026`.

## Where this came from

Adding case-preserving signal names to xschem: a net drawn `EN` should reach
the waveform viewer as `v(EN)`. `preserve` is exactly the right mode for that —
labels keep their capitals while identity still folds, so PDK libraries stay
callable and none of `distinguish`'s silent traps can fire. The findings are
what turned up while wiring it in.

The consuming side's plan, if useful for context, is
`../casemode_batch/PLAN.md` — its §0 "Measured facts" is the same evidence
base viewed from the client end.
