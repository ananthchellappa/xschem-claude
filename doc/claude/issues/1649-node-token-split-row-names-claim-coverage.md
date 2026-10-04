# 1649 — `test_node_token_split`: a hand-kept `7`, and prose naming functions that do not call it

**STAMP:** `v1 claim=open tree=060c6d77 stamped=2026-10-03 fix=none open=2`

Status: **OPEN**, found 2026-10-03 by issue 1645's recon.
Area: `tests/headless/test_node_token_split.tcl` rows `NDR2`, `NDR3`, `NDX3`.

## Defect 1 — a coverage claim over a bare count against a hand-kept literal

`NDR2`/`NDR3` are named for asserting that **all seven** `node=` walkers resolve the sweep column
by name and clamp against `nvars`. The **method** is a line count compared against a literal `7`.
So the name claims a property of the walker population while the predicate asserts only that a
count has not changed — and the two come apart the moment a walker is added or removed.

Measured: the rows go **green on a broken tree** in the `S4`/`S5` shapes. That is row `X1` of
`test_snprintf_fmt_1608.tcl`'s defect one level up — *a hand-kept list is the same defect one level
up* — and the `grep -c '#pragma'` family, with a test row as the victim rather than a comment.

⚠ **This suite is part of why a wrong figure persisted for weeks.** A source comment and a batch
contract both claimed *"all SEVEN `sweep=` walkers carry the token forward"*. Re-derived: **six**
carry forward, the reader population is **nine**, and **three** read only the first token. The
`seven` is correct for a *different* predicate — resolves-the-sweep-column-by-name — which is what
`NDR2`/`NDR3` actually assert. Because nothing runs these rows, nothing ever re-attached the
number to its predicate. **Two live copies of the wrong claim survive** and are reported in issue
1645's receipt: a comment above `proc wviewer::sweep_token` in `src/wave_viewer.tcl` reading
*"which is the one failure ALL SEVEN GRAPH WALKERS turn into a silent re-axing"*, and
`DESTINATION_CONTRACT.md` §9's *"All SEVEN walkers carry the token forward"* — the latter
contradicted by a later section of the same file.

The repair shape is a **derivation** over the walker population plus a non-vacuity leg, not a
corrected literal. A corrected literal rots the same way on the next walker.

## Defect 2 — `NDX3`'s prose names two functions that do not call `node_token_split`

`NDX3` says it covers *"the seven `node=` walkers plus D4's `graph_cursor_dbs()"*. The eight real
`node_token_split` call sites are `graph_x_union_rect`, `graph_cursor_dbs_rect`, `graph_fullyzoom`,
`find_closest_wave`, `graph_point_at`, `wave_hilight_envelope`, `graph_wave_resolve` and
`draw_graph`. So **`graph_fullxzoom` and `graph_cursor_dbs` do not call it at all** — their static
helpers do, on their behalf, and neither helper is named in the row.

This is the fifth instance in this tree of a shipped cross-reference that does not resolve; the
precedent is the *"five shipped source comments cited rows that do not exist"* finding recorded in
CLAUDE.md.

## What is NOT claimed

* **Nothing is red.** Both arms are green at `060c6d77` — 174 checks on each, rc 0, zero `FAIL`
  lines, zero skips.
* **This suite pins no viewer arity.** All four `wviewer` occurrences in it are comments. It must
  not be credited against the silent-arity-break concern issue 1645 opens with; that cover is
  `BM05` (see issue 1646) and `GT8`.

## Outstanding

1. Replacing the hand-kept `7` with a derivation plus a non-vacuity leg, and renaming the rows for
   their method.
2. Correcting `NDX3`'s prose, and the two surviving copies of the wrong walker claim.
