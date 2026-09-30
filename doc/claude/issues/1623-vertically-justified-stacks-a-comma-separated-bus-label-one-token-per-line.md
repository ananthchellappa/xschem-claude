# 1623 — "vertically justified" stacks a comma-separated bus label, one token per line

**STAMP:** `v1 claim=fixed tree=3111564579044e stamped=2026-09-30 fix=taken open=5`

Status: **FIXED**, 2026-09-30, with a new display transform `sym_text_vstack()` called at six
render/measure sites and gated by a per-instance `vjust=` token.
Measured on this tree at `31115645` · Branch: `fluid-editing`
Related: `doc/claude/specs/wish_list.txt` **new-list item 2**, its first named gap; issue **1624**
(the angle-bracket netlist hazard, found in the same recon); batch
`doc/claude/wire_label_vjust_batch/`, receipts `R-recon-vjust.md` and `A-vjust.md`; the fence is
`tests/headless/test_add_wire_label.tcl`.

## ⚠ THE NAME IS A TRAP, AND THE DRIVER FELL IN IT TWICE

"Vertically justified" is **not typography.** The user labels a bus by typing a comma-separated token
list into the Add Wire Label form — their example, an 8-bit bus:
`bg_trim[3:0],en_fast,iref_trim[2:0]`. The flag controls that list's **layout**:

* **off** — one line
* **on** — stacked, one token per line, single-spaced, **no blank line between them**

The driver proposed two readings before asking, and both were wrong: rotate the label so its text
runs along a vertical wire (`lab_orient()`, real code and a genuine red herring), and re-anchor
horizontal text via the `hcenter`/`vcenter` attributes generic text exposes.

**The user's own sentence disqualifies both in one stroke:** *"`busname<3:0>` will not render any
different with vertical justification."* Neither rotation nor re-anchoring would leave a single-token
label unchanged — so that sentence was available as a test of the design from the start and the driver
did not apply it. Anyone touching this next should apply it first.

## What shipped

* **`sym_text_vstack(int inst, const char *txt_ptr, const char *s)`** (new, `src/draw.c`), declared
  in `src/xschem.h`, written to **`get_sym_text_layer()`'s exact shape** — including its mandatory
  `xctx->tok_size = 0;` else arm. Called at the **six** sites that render or measure a symbol's text:
  `draw_symbol()`, `draw_temp_symbol()`, `inst_text_bbox()` (`draw.c`), `svg_draw_symbol()`
  (`svgdraw.c`), `ps_draw_symbol()` (`psprint.c`), `symbol_bbox()` (`select.c`). Its static buffer is
  released from `xwin_exit()` via `sym_text_vstack(-1, NULL, NULL)`.
* Gate: a **per-instance `vjust=1`** token, applied **only** to the text record spelled `@lab`.
* Tcl: a sibling tokeniser beside `addlabel::expand_names`, whose 14 pinning rows and
  comma/whitespace equivalence are left untouched because the multi-label queue depends on them.
* `doc/claude/specs/add_wire_label.md` updated.

Driver-verified at `31115645`: the six call sites are present, and **`netlist.c`,
`spice_netlist.c`, `spectre_netlist.c`, `verilog_netlist.c`, `vhdl_netlist.c`, `tedax_netlist.c`,
`save.c` and `token.c` do not reference the helper at all** — so the netlist safety is structural
rather than conventional.

### Why not `translate()`

One recon angle argued for a derived token resolved in `translate()`, since all six sites call it and
the codebase's invariant **I1** ("four copies, one builder", recorded above `text_hidden()` in
`src/xschem.h`) warns against duplicating a transform. It was rejected on evidence: making that route
netlist-safe means inventing `@lab_vstack` and editing all five shipped label `.sym` files, which
**breaks `xschem inst_name_text`'s `strcmp(txt_ptr, "@lab")` resolver** and leaves site-local label
symbols unstacked. `translate()` also has 77 callers including every netlister. Angle 2 keeps I1's
substance — one builder, six call sites, which is exactly what `get_sym_text_layer()` already is.

## ⚠⚠ THE NETLIST FENCE THE DRIVER DEMANDED COULD NOT SEE THE MISTAKE IT EXISTED FOR

This is the most valuable finding in the stage and it is a correction of the **driver's own
instruction**. The brief said, in bold: *prove the constraint by measurement, not by reasoning about
call graphs.* The crew built exactly that — `V22`, "the SPICE deck is byte-identical with the flag on
and off", and `V23`, "every non-comment line is a whole card".

Then sabotage **`S1` put the transform inside `translate()`, precisely the rejected design, and
`V22` stayed GREEN.** A plain `lab_pin` top emits no deck line that routes `@lab` through
`translate()` — `net_name()` reads `get_tok_value(prop, "lab")` directly, and a
`format="*.alias @lab"` produced no line at all. So the "proof by measurement" was **the call-graph
argument in disguise**, which is the one thing the brief forbade.

Repaired with **`V15b`/`V15c`**, which assert `xschem translate <inst> {@lab}` returns the canonical
comma list with **zero newlines**. **`V15b` is what holds the boundary; `V22` is worth keeping but is
not the fence.**

⚠ A second surprise in the same family: **storing a newline in `lab=` does NOT redden the netlist
rows** (`S8`). `my_mstrcat` writes the value unquoted and `SPACE(c)` in `src/token.c` treats `\n` as a
terminator, so the deck stays single-line — it is simply a deck for a **truncated** label. The netlist
rows catch the *quoted* variant; `V20`/`V20b` catch the unquoted one. A fence aimed at "the deck
breaks" would have missed the more likely bug.

## Red first

**`RESULT: 17 FAILED (204 passed)`**, `OVERALL: notok`, reddening
`V1 V2 V3 V4 V5 V6 V7 V9 V10 V12 V14 V15 V16 V17 V19 V20 V20b`:

```
FAIL: V1 ... -> {threw (invalid command name "addlabel::split_display_tokens")} (exp {{bg_trim[3:0]} en_fast {iref_trim[2:0]}})
FAIL: V6 name_ok accepts a comma list ... -> {0} (exp {1})
FAIL: V15 a point two lines below the anchor CLICKS the stacked label ... -> {{} {}} (exp {{} {instance 1}})
FAIL: V20 the armed preview stores the canonical comma list and carries the per-instance flag ... -> {{bg_trim[3:0]} 0 {}} (exp {{bg_trim[3:0],en_fast,iref_trim[2:0]} 0 1})
```

Green: **196 → 224** checks headless, **184 → 207** on the display arm.

## Sabotage: eight applied, one survived and is reported as a gap

| sabotage | reddened |
|---|---|
| `S1` transform inside `translate()` | **`V15b` only** — see above |
| `S2` per-instance gate omitted | `V12 V13 V14 V15 V16 V17` |
| **`S3` the `@lab` record gate omitted** | **NOTHING — reported gap** |
| `S4` no separator collapse | `V12b` |
| `S5` one of six sites omitted (`symbol_bbox`) | `V12 V14 V15 V12b`, **SVG rows stayed green** — the I1 divergence, caught |
| `S6` `tok_size = 0` else arm omitted | **`FATAL: signal 11`** |
| `S7` stale `::label_new_vjust` | `V20c` |
| `S8` newline stored in `lab=` | `V20 V20b` |

`S6` is worth keeping in mind: the else arm copied from `get_sym_text_layer()` is not stylistic.
`xctx->tok_size` is a shared global side-channel written by `get_tok_value`, and a stale nonzero makes
the code `atoi(NULL)` — a segfault, not a wrong answer.

## bbox and hit-test agree with what is drawn, measured three independent ways

SVG export (`V16` asserts the exact `<text>` set, `V17` equal y-deltas of 13.538/13.539), bbox (`V12`
heights in arithmetic progression, `V14` narrower) and hit-test (`V15`: `select_at 395 35` →
`instance 1`, against nothing for an unflagged twin). **That they are three separate measurements is
itself proven**: `S5` reddened the box and click rows while the SVG rows stayed green.

## Registration

**No T1 movement.** The suite is already in `hcases` alone: **112 cases / 111 blocks / `skips=` 8
unchanged**. The one new guard prints an uppercase `SKIP:`, matching section W's, which
`summarize_all` does not count. Only the published check count moves, 196 → 224.

⚠ The driver's brief quoted **156** checks for this suite, taken from the recon. It was **196**. A
figure copied from a document rather than measured, which is the defect CLAUDE.md names.

## Still open (open=5)

1. ⚠ **"Split bus" is silently ignored when "Vertically justified" is ticked.** It is the only
   defensible reading — expanding `B[3:0]` would stack four lines and break the single-token
   diagnostic — but it is a **ticked box that does nothing**, with no status copy saying so. The crew
   deliberately wrote no new user-facing sentence, correctly leaving the wording to the user. On the
   user's queue as **`rule/1623`**.
2. **Whitespace also separates on the vjust path**, so `bg_trim[3:0] en_fast` with the flag on is ONE
   stacked label. Forced by `SPACE(c)` truncating an unquoted space in `lab=`, so it is a correctness
   call rather than a preference — but a user may reasonably expect commas only to split.
3. **The stack is left-aligned with a ragged right edge** — pre-existing renderer behaviour, not
   introduced here. `look` debt.
4. **The stack grows downward, across the wire** — likewise pre-existing. `look` debt.
5. ⚠ **The `S3` gap, and the driver's first explanation of it was wrong.** Omitting the `@lab` record
   gate reddens nothing. The receipt's framing implied there is no second text record to corrupt, and
   the driver wrote that down before checking. **It is false:** `xschem_library/devices/lab_pin.sym`
   carries **two** `T` records — `T {@lab}` and `T {@spice_get_voltage} … {layer=15}` — and
   `lab_wire.sym` carries two as well (`lab_generic.sym` and `lab_show.sym` have one).

   So the gate **is** load-bearing on the shipped symbols, and the real reason `S3` is invisible is
   that `@spice_get_voltage` is a **back-annotation** value: it is empty until a simulation has been
   run and back-annotated, and the fixtures never populate it, so the ungated transform stacks an
   empty string and nothing observable changes. That makes this a **writable** fence rather than a
   structural one: a row that sets `spice_get_voltage` to a value containing a separator on a
   `vjust=1` instance and asserts that value is **not** stacked would catch `S3` directly. It is not
   written yet, and this item is that row's specification.

   The lesson is the driver's, not the crew's: *"nothing reddened"* invites an explanation, and the
   first explanation that fits is not evidence. One `grep -c '^T '` refuted it.

## Deliberately left alone

`vjust` does **not** need adding to `unused_attr_stoplist`: labels are `type=label` and never
eligible, and adding it **would have reddened** `test_unused_attr_0970` row `UF14`, which pins that
list name-for-name and in order.
