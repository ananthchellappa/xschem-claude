# 0461 — annot_mode replaces annotate_op's own refusal sentence with a generic one

Status: OPEN (measured by S8's adversary pass, not fixed)
Found: S8 of doc/claude/specs/op_annotation.md. Subject: the `failed` branch of
`cadence::annot_mode`, `utils/annot_mode.tcl`.

When the candidate raw exists but will not serve, `xschem annotate_op` sometimes
MINTS a full, specific explanation and returns it as the interp result. Measured
with a VCD as the candidate:

    backannotation: '<path>' is a digital results database -- it carries logic
    levels over time, not an operating point, so there are no voltages or
    currents in it to annotate onto the schematic

`cadence::annot_mode` throws that away and says only:

    OP annotation ON (device OP info) -- COULD NOT LOAD <path>

Not false — S8 decision D3 deliberately re-asks `xschem raw loaded` rather than
trusting annotate_op's rc, which is 0 even for a file that does not exist — but
strictly poorer than what the C already produced. The generic wording is
correct for the "garbage file" case (where the result is just the echoed path)
and wasteful for the minted-sentence case.

Fix shape, roughly one line: capture annotate_op's result, and when it is
non-empty AND not merely the path echoed back, append it instead of the generic
clause. The discriminator matters — S8 measured that on success and on plain
failure the result IS the file path, so a naive pass-through would print the
path twice.

## Still open

Whether the C should instead write its own held status line at the point it
mints the sentence, which would fix this for every caller (both shipped
**Annotate Operating Point** menu items discard it too) rather than for the
three chords only. That is a C change and was outside S8's rc-only scope.
