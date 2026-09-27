# Decisions — issue 1609

## K1 — the driver's prediction, stated so a crew can refute it

**This is a prediction, not a finding.** The last four batches each had a crew refute the driver's
central bullet; state which of these you refuted and which you confirmed, with the measurement.

1. `"%ld"` of a `long` above `INT_MAX` prints the **truncated** value, not garbage, on this machine,
   because x86-64 sign-extends the `int` back into a full vararg slot.
2. The fix is **fetch by modifier**, not refuse the modifier, and it is under ten lines.
3. Nothing a user sees changes, for any value any live caller can produce.
4. `%hu` is safe by default argument promotion and needs no change.
5. ⚠ **The weakest bullet, flagged deliberately:** that no format string reaching this arm can come
   from outside the binary any more. 1608 fixed five call sites; I have not re-derived that there
   were only five, and 1608's own Stage A refuted exactly this shape of inherited claim ("all
   formats are literals" was false — five were not, two reachable from a file).

## K2 — the aarch64 argument is a derivation and ships labelled as one

There is no aarch64 toolchain on this machine. The ABI reading may go in a comment **only** with the
word that marks it as a reading of the document. Issue 1606 shipped a comment that turned a
derivation into a claimed Win64 measurement and had to correct it; do not repeat that.

## K3 — internal engineering, so no ruling is filed

The fetch width of a vararg is not a thing the user sees or experiences, and per the project's
standing instruction the driver decides it and proceeds. **This holds only while K1.3 holds**: if any
reachable value makes the output change, it stops being internal and the driver files a `rule`.
