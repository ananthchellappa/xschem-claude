# 0907 — "These results were already loaded." never says WHICH results

STATUS: OPEN — filed 2026-08-28 by item A15 (the issue 0684 fix), measured, not fixed.
FOUND IN: `cadence::_annot_msg`, `utils/annot_mode.tcl`, the `live` arm.
RELATED: [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md),
RULING D5-1, the PLAIN ENGLISH ruling.

---

## 1. What the user sees

Press `6` twice with nothing changed on disk and the status line reads:

```
Showing device operating-point values on the schematic. These results were already loaded.
```

The `loaded` arm one line below it names the file — *"Loaded results from
/…/mos.raw."* — and the `live` arm names nothing. After 0684 that asymmetry
matters more than it did, because the two sentences are now the ONLY thing on
screen that distinguishes "this is the run you just did" from "this is a
database somebody attached earlier".

## 2. Why it is not cosmetic

0684's fix deliberately leaves a database the user loaded from somewhere else —
another corner's operating point at a different path — exactly where it is,
because replacing it would destroy it (`xschem annotate_op` deletes a 1-point
`op`/`dc` it replaces, `scheduler.c`). Row F20 of
`tests/headless/test_annot_stale_0684.tcl` is that guarantee. The cost of the
guarantee is that `live` can be true over a file the user picked by hand rather
than the session's own — and the sentence does not say so.

## 3. Not changed here, and why

Row V21 of `tests/headless/test_op_annot.tcl` golds this sentence byte for byte,
and rows N5, N10, V31b and W1a-series compare against `$A11_LIVE`. Moving it is a
wording change to a mint with many golden consumers; it needs to be done once,
deliberately, with the user's ruling on the wording — not as a side effect of a
staleness fix.

## 4. Options

1. Always name the file: *"These results were already loaded from `<path>`."*
2. Name it only when it is NOT the session's own candidate — the case that can
   surprise — and keep today's sentence otherwise.
3. Leave it. The file is discoverable through `Waves`.

Recorded as an unratified user-visible decision: `owed.sh add rule 0907`.
