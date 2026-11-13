# 1712 — test_annot_declutter_1244 row A22 counts a comment as a call site, and is red at HEAD

**STAMP:** `v1 claim=fixed tree=514868462764e stamped=2026-11-12 fix=taken open=0 by=backlog_1112-D`

Found by the stage C verifier of the backlog_1112 batch
(`doc/claude/backlog_1112_batch/receipts/C-verify.md` §5). Fixed by stage D of the same batch.

## Observation (measured at `514868462`)

`tests/headless/test_annot_declutter_1244.tcl` row **A22** is a text census of
`text_hidden_inst(` over `src/draw.c`, `src/svgdraw.c`, `src/psprint.c` and `src/select.c`.
Its golden is `{4 2 2 1 0}`; at HEAD it reads one more draw.c site than the golden. On the display arm (private
Xvfb, openbox) the suite gives `RESULT: 1 FAILED (133 passed)`, and A22 is the only failure.

`git log -S 'text_hidden_inst(' -- src/draw.c` puts the extra draw.c line at **15b76baef**
(issue 1623, vertical bus-label stacking).

## Cause: a comment, not a call

The extra line is not code. It is in the block comment above `sym_text_vstack()` in
`src/draw.c`: *"... exactly as text_size_<n>= / text_layer_<n>= (above) and
text_hidden_inst() do -- see the note above text_hidden() in xschem.h"*. The row counted with
`opa_n_grep`, which counts every matching line, prose included. `draw.c` still has exactly
four real calls: in `draw_symbol`, in the P6 pin-name loop, in `draw_temp_symbol` and in
`inst_text_bbox`.

So the golden was right and the product has no defect. The census instrument could not tell
code from prose. This is the issue 1646 shape: when a predicate scans a file as text, an
occurrence in a comment counts.

## Fix (taken)

- A22 now counts with C `/* ... */` comments blanked out. The new procs are `dc_c_blank` and
  `dc_c_ngrep`; blanking keeps every newline, so line structure survives.
- The golden is unchanged.
- A22 gained one leg: `dc_c_blank` must pass a self-test on a fixed sample. A call inside a
  one-line comment and a call inside a two-line comment must vanish. The call outside them
  must stay. The line count must not change.
- Display arm after the fix: `ALL PASS (134 checks)`.
- Sabotages, each restored with `cp` and checked with `cmp`:

| sabotage | result |
|---|---|
| a real stray call appended to draw.c | red: A22 `{5 …}`, and A38 also red |
| a real P6 call removed | red: A22 `{3 …}`, and A38 also red |
| `dc_c_blank` turned into a no-op | red: A22 `{5 2 2 1 0 {3 4}}` |

## Registration (taken, by the stage D verifier)

The suite had been in **no T1 list**, which is how A22 stayed red unnoticed. It is display-only:
under `--nogui` it dies early with an uncaught Tcl error and `run_suites.sh` reports `NORESULT`.
So it is registered in `dcases` **alone**, next to `test_annot_blank_cause_0909`.

Before registering, its epilogue was scored with `banner_complete` from `tests/banner_rule.tcl`
on output captured the way T1's `dcases` arm captures it (`--pipe -q --logdir`, private Xvfb):
it printed `RESULT: ALL PASS` and no `OVERALL:` line, so `banner_complete` answered 0 and the
case would have scored a `HARNESS:` failure with every check passing (issue 1615's shape). The
epilogue now prints `OVERALL: ok (<n> checks)` after the `RESULT:` line, and `OVERALL: notok` on
failure, the shape `test_annot_blank_cause_0909` uses. After the change `banner_complete` answers
1 on a green run and 0 on a sabotaged one.
