# 1230 — Answering No to the missing-schematic question still drops you on a blank page

**Status:** FIXED (2026-08-31, item S7). A `look` debt is owed: a person should
press **No** on the real dialog once.

The right-click canvas item is the one control that asks before it acts: when the
file a copy is set to open is not there, it puts up
"Schematic <path> does not exist. Descend into base schematic?".

Answering **No** sets `fallback = 0`, leaves `filename` pointing at the file that
is not there, and `descend_schematic()` loads it anyway — so the person ends up one
level down on a blank page, which is exactly what they declined. So even the
control this branch calls correct strands them.

Two further faults in the same sentence: it is written in internal vocabulary, and
it offers a third button (Cancel) whose meaning is indistinguishable from No.

The question is only asked when there is a screen and `xschem callback` cannot be
driven headlessly, so the only witness is structural: row E4 in
`tests/headless/test_descend_doors_1228.tcl`. A `look` debt is owed for a person to
press No on the real dialog once.


## What landed

Any answer that is not `yes` now clears `filename` and records its own reason,
`view-missing`, with its own sentence — so `descend_schematic()` opens nothing and
the hierarchy level does not move. `descend_schematic()`'s "has no schematic view"
arm is guarded by `xctx->descend_err[0] == '\0'` so it cannot overwrite that
accurate reason with something that did not happen. (Safe: `descend_clear_error()`
runs at the top of `descend_schematic()`, well before `get_sch_from_sym()`.)

The third button is gone — `ask_save` is called with `cancel = 0`, so the question
has exactly two buttons, **Yes** and **No**, and No and Cancel can no longer mean
two indistinguishable things.

The wording is rewritten and is now minted in ONE place,
`descend_view_missing_sentence()` in `src/actions.c` (ruling D5-4), rendered by two
callers — the question, and the status line. It names the copy, the file that is
missing and the cell's own schematic file, in words, with no internal vocabulary:

> The copy named x3 on this sheet is set to open the schematic file comp3_pex, but
> that file is not there. This cell's own schematic file is comp3.sch.

The question then shows both full paths as data underneath, and offers
"Yes opens it. / No leaves you on the sheet you are on now.", plus a line saying
where to change the setting. The sentence names files by **file name** and the
dialog carries the full paths separately because `xctx->statusmsg_text` is 256
bytes: two absolute paths inside one sentence truncated the status line mid-word
(measured: "Opened the cell's own schematic instead." was cut to "Opened the c").

**Verified behaviourally** on the dev display with `ask_save` stubbed, since
`xschem callback` cannot be driven under `--nogui`: Yes → opens the cell's own
sheet, `descend_error` empty; No → hierarchy level unchanged, `descend_error` =
`view-missing`; the old Cancel (empty answer) → identical to No; and a copy whose
binding resolves is never asked at all. Row E4 is the committed structural witness.
