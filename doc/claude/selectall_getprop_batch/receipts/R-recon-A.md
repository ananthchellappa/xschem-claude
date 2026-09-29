# Receipt — Stage R, recon A (Ctrl-A selects all traces, PLAN questions 1–6)

Crew: recon-A. Read-only. **Nothing in the tree was changed; this file is the only
addition.** Measured at `b89fddda` on branch `fluid-editing`, 2026-09-29.

Every line number below is at `b89fddda`; everything else is cited by symbol.

**Headline: PLAN question 5's claim is half wrong.** `select_all()` is **not** reached
by Ctrl+A over a graph — `waves_callback()` is, and it **toggles x-cursor A**. The other
half of the claim (what `select_all()` selects) is right. Both halves are measured, not
read. §5 has the transcripts.

---

## What I ran

Three throwaway probe scripts under
`…/scratchpad/R-recon-A/` (`probe_ctrl_a.tcl`, `probe_selcount.tcl`,
`probe_keyfilter.tcl`), each with `HOME` armed by
`. tests/headless/test_home.sh; test_home_arm` (banner confirmed
`test home: throwaway /tmp/xschem-test-home.516029.W9FYIC`). The two that need pixels ran
under `tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --script …` (the dev
display `:99` was already `alive` and was left exactly as found — no `start`/`stop`/`view`).
The one that does not ran under `./src/xschem --nogui --pipe -q --script …`. No suite was
run, no T1, no build. Fixture: the shipped read-only
`xschem_library/examples/tb_test_evaluated_param.sch` (one layer-2 graph rect at
`540 -740 1200 -340`, no `lock` token), the same fixture
`tests/headless/test_key_graph_context.tcl` uses.

Binary freshness checked before believing anything (CLAUDE.md "No test harness builds"):
newest `src/*.c` mtime `1790666946` < `src/xschem` mtime `1790666948`, so the binary is
current for C. `src/wave_viewer.tcl` is newer but is interpreted at run time, not compiled.

---

## 1. What does `ctrl+a` do today when the pointer is over a waveform graph?

**It toggles x-cursor A on, and off again on the next press. It selects nothing.**

The real path, end to end:

1. **`src/keybindings.csv`** carries exactly two rows for keysym 97 and **no canvas row at
   all**:

   ```
   key,97,ctrl,graph,graph.forward,
   key,97,0,graph,graph.forward,1
   ```

   Confirmed live rather than by reading the file — `xschem bindings dump` under
   `--nogui`:

   ```
   NOGUI-DUMP: {key 97 ctrl graph graph.forward} {key 97 0 graph graph.forward idle}
   ```

   and `lsearch -all -inline -glob $dump {key 97 ctrl canvas *}` is **empty**. So the
   schematic Ctrl+A is *not* in the binding table and *not* remappable through
   `keybindings.csv`; only the graph-context routing is data.

2. The builtin table that the csv is generated from is `init_input_bindings()` in
   `src/callback.c`; the row is
   `set_input_binding(DEV_KEY, 'a', ControlMask, ACTX_OVER_GRAPH, "graph.forward")`
   (line 6479, comment `/* select all */` — the comment describes the *canvas* fallthrough,
   not this row's effect, which is how the driver's claim probably arose).

3. The pre-switch dispatch block at the head of `handle_key_press()` (`src/callback.c`,
   ~7472–7490) runs `key_chord_has_binding(97, ControlMask)` → true (the graph row exists),
   then, because `find_binding(DEV_KEY,'a',ControlMask,ACTX_OVER_GRAPH)` is non-NULL,
   resolves the context through `current_input_ctx()` → `waves_selected()`.

4. Over a graph `waves_selected()` returns 1 (ControlMask clears its
   `graph_use_ctrl_key` gate, and `SET_MODMASK` is Mod1/Mod4 only — `src/callback.c:26`),
   so `dispatch_input_action()` finds `graph.forward` → `act_graph_forward()` →
   **`waves_callback()`**, which returns 1 = handled, so `handle_key_press()` **returns
   before the `switch(key)`**. `case 'a'`, and therefore `select_all()`, is never reached.

5. Inside `waves_callback()` the branch `else if(key == 'a' && access_cond)` does
   `xctx->graph_flags ^= 2` and seeds `cursor1_x` — the **x-cursor A toggle**.
   `access_cond = !graph_use_ctrl_key || (state & ControlMask)`, so it is satisfied in
   **both** profiles: with the shipping default `graph_use_ctrl_key 0` (`src/xschem.tcl`,
   `set_ne graph_use_ctrl_key 0`) by the first term, and with it set to 1 by the second.

**In the ASE-L waveform viewer window** the same C path is reached through
`wviewer::key_filter` (`src/wave_viewer.tcl`). Keysym 97 is a member of
`wviewer::graphkeys` = `{97 98 100 115 109 116 65 66 77}`, and the modifier carve-out is
`set fwd [expr {!(($N == 100 || $N == 98) && ($s & 4))}]` — **only `d` and `b`**. So Ctrl+a
is forwarded (`xschem callback $W $T $x $y $N 0 0 $s`) and then the filter's tail calls
`wviewer::key_cursor_tail $W 97`, which flips the Tcl `cva($token)` mirror and the
**Cursors ▸ Cursor A** checkbutton. The source says so in as many words, in the comment
above the carve-out: *"graphkeys membership is otherwise unconditional on modifiers, which
is right for a/s (Ctrl+a, Ctrl+s are real ctx=graph rows in keybindings.csv)"*.

Measured through the **real** `wviewer::key_filter` (probe 3; `graphbb` seeded so
`over_graph` answers 1, `key_cursor_tail` instrumented, C left untouched):

```
PROBE3: token_for_canvas .drw = PROBE
PROBE3: over_graph .drw       = 1
PROBE3: graphkeys             = 97 98 100 115 109 116 65 66 77
PROBE3: baseline                  graph_flags=0 lastsel=0 kct=
PROBE3: after key_filter Ctrl+a   graph_flags=2 lastsel=0 kct=97
PROBE3: after 2nd  Ctrl+a         graph_flags=0 lastsel=0 kct=97
PROBE3: after key_filter bare a   graph_flags=2 lastsel=0 kct=97
PROBE3: after key_filter Ctrl+b   graph_flags=2 lastsel=0 kct=
```

`graph_flags` bit 2 is cursor A. Ctrl+a toggles it and calls the cursor tail; bare `a` does
exactly the same; **`lastsel` never moves off 0**. The Ctrl+b line is the method control —
it has the carve-out, so `graph_flags` does not move and the tail is not called, proving the
probe can tell a forwarded chord from a refused one.

⚠ **Caveat on scope of measurement.** Probe 3 drives the real `key_filter` on the real
`.drw` with a synthesised viewer registry entry, not on a real ASE-L viewer toplevel. What
is *measured* is the filter's forward decision plus the C effect; what is *derived* is that
no other binding in a real viewer window intercepts the chord first. That derivation rests
on a grep with zero hits: the only occurrence of any Ctrl-A spelling anywhere in `src/` is
a **comment** (`src/rdw.tcl`, in `rdw::popup_menu`), so there is no
`bind WaveViewer <Control-Key-a>`, no `bind .drw <Control-Key-a>` for
`wviewer::clone_canvas_bindings` to copy, and no `<<SelectAll>>` virtual event in use. The
command that would settle it outright is a `<Control-Key-a>` row inside
`test_wave_viewer.tcl`'s G-band, using its existing `send_key $vdrw <Control-Key-a> {…}`
helper against a really-open viewer.

## 2. The existing trace-selection model

The PLAN's four leads are all real, but they are not peers — two are C, two are Tcl, and
one of the four is misnamed.

**The storage.** Per **graph rect** (layer `GRIDLAYER` = 2, `xschem.h:163`), in two prop
tokens on `r->prop_ptr`: `hilight_wave` (the head of the selection, `-1` or absent = none)
and `sel_waves` (the whole set, ascending, no duplicates, **written only when it holds two
or more** — a 0- or 1-element selection is expressed entirely by `hilight_wave`, which is
what keeps a never-Ctrl-clicked strip byte-identical to pre-0175). Indices are **NODE**
indices: positions in the rect's `node` prop token. Mirrored into `Graph_ctx` as
`hilight_wave`, `sel_wave[GRAPH_MAX_SEL_WAVES]`, `n_sel_waves` (`src/xschem.h`).
`GRAPH_MAX_SEL_WAVES` is **64** (`src/xschem.h:609`).

**The C API — the only sanctioned writers.** In `src/draw.c`, declared in `src/xschem.h`
with a header comment that says explicitly *"these three are the ONLY sanctioned
readers/writers of that pair"*:

* `graph_sel_waves_get(int i, int *out, int max)` — parse rect `i` into `out`, returns the
  count. Falls back to `hilight_wave` when `sel_waves` is absent; fails closed on garbage;
  an absent token is **not** node 0.
* `graph_sel_waves_set(int i, const int *waves, int n)` — write both tokens. `n <= 0`
  clears. Returns 1 only when the prop string actually changed. **Silently clamps
  `n > GRAPH_MAX_SEL_WAVES` to 64** (unlike the toggle, which refuses).
* `graph_sel_waves_toggle(int i, int wcnt)` — the Ctrl+click add/remove; **refuses** the
  65th add rather than dropping silently.
* `wave_is_hilighted(Graph_ctx *gr, int wcnt)` is the draw-side predicate; a bare
  `gr->hilight_wave == wcnt` is the documented bug.

**The gesture that writes it** is the Button1 press/release arm of `waves_callback()`
(`src/callback.c`, ~2300–2385): `graph_wave_at()` on the plot body or `graph_legend_at()`
in the legend band gives `wcnt`; Ctrl+click → `graph_sel_waves_toggle(i, wcnt)`; plain
click → `graph_sel_waves_set(i, &wcnt, …)` **plus a cross-strip sweep** that clears every
other graph rect, because *"the selection is one set in the whole window, not one per
strip"*. Ctrl+click deliberately skips the sweep — that is how a multi-strip selection is
built.

**`edit_wave_attributes(int what, int i, Graph_ctx *gr)`** (declared `src/xschem.h`, defined
`src/draw.c`) is **not** a selection setter in the sense the PLAN implies: `what == 2` is
the Button3-on-legend *toggle* and `what == 1` is the wave-attributes dialog. The comment
in `waves_callback()` records that the old comment claiming otherwise was wrong for years.

**`sel_waves` is a prop-token name, not a proc** — there is no `sel_waves()` function. The
Tcl reader of that token is **`wviewer::selected_waves {wp gi}`**, which does
`xschem getprop rect 2 $gi sel_waves`, normalises through `wviewer::sel_waves_norm`, and
falls back to `xschem getprop rect 2 $gi hilight_wave`.

**`wviewer::model_sel` / `wviewer::model_sel_set`** are the *model-side* mirror of the same
pair (pure dict ops on a graph dict `G`), used by the structural remaps
(`remap_sel_after_trace_move`, `remap_sel_after_trace_delete`, `move_trace_in_graphs`). They
do **not** touch a live rect. The rect→model fold happens in `capture_live_graph_state`
(`src/wave_viewer.tcl`, ~5344–5365) and the model→rect emission in `graph_props`
(~3938–3960).

**There is no `xschem` subcommand that reads or writes the trace selection.** Grepped
`src/scheduler.c` for `sel_waves`/`hilight_wave`/`graph_sel` — the only two hits are
comments. Tcl reaches it *read-only* through `xschem getprop rect 2 <gi> <token>` and could
in principle write it through `xschem setprop rect 2 <gi> …`, but that would bypass the
"only sanctioned writers" rule and the `n>=2` / absent-means-absent invariants.

**Two index spaces, and they are not the same** (called "landmine 34" in the viewer):
`selected_waves` answers in NODE space; the Tcl model indexes TRACES. A trace with an empty
`vec` occupies a model slot and no node slot. The crossings are
`wviewer::trace_index_of_node` / `wviewer::node_index_of_trace`, and `wviewer::node_count`
gives the length of the node space. On the C side the same count is
`count_items(get_tok_value(r->prop_ptr, "node", 0), "\n", "\"")` — see `graph_legend_at()`
in `src/draw.c`.

## 3. What Delete already does, and the shape Ctrl-A must produce

`wviewer::key_filter` intercepts keysym **65535** over a graph and **never forwards it**
(Delete is deliberately *not* a `graphkeys` member, because a Delete reaching C with
nothing to delete lands on the canvas delete verb → `readonly_block()` + a modal over a
read-only viewer). It calls **`wviewer::delete_selection_at {W px py}`**, which:

1. reads the **live** selection with `wviewer::selection_pairs $W` — the single fold over
   every strip: `foreach G [dict get [wviewer::layout_for $token] graphs] { foreach ni
   [wviewer::selected_waves $W $gi] { set ti [wviewer::trace_index_of_node $G $ni]; … } }`,
   yielding MODEL `{gi ti}` pairs and dropping a node that maps nowhere;
2. separately resolves the selected **marker** (`wviewer::marker_selected` +
   `wviewer::marker_graph_at` + `wviewer::strip_at_pixel`, reproducing C's strip-scope gate);
3. returns 0 and touches nothing when both are empty (load-bearing: that is what keeps a
   no-op Delete out of C);
4. otherwise `wviewer::delete_items {} $pairs $marks $token` — one undo point, one
   `wviewer::log_action` line.

**So the shape Ctrl-A must produce is exactly: the per-rect `hilight_wave` + `sel_waves`
prop tokens on the live graph rects, in NODE index space, on whichever strips are to be
selected.** Nothing else is required — `selection_pairs` reads the rects, not the model, and
`delete_items` takes it from there. If Ctrl-A writes those two tokens through
`graph_sel_waves_set()`, the shipped Delete path consumes it unchanged.

Two consequences the implementer owns:

* **The per-rect 64 cap.** `graph_sel_waves_set` clamps at `GRAPH_MAX_SEL_WAVES` silently.
  A strip carrying more than 64 traces would have only its first 64 selected by Ctrl-A, and
  Delete would then delete 64 of them. That is a declared limit, not a bug to hide — say it
  in the receipt, and consider a `ciw_echo` the way `hilight_traces` does for its own cap.
* **Traces with an empty `vec`** are in the model but in no node slot, so they can never be
  selected and Ctrl-A cannot reach them. `trace_index_of_node` already drops them.

## 4. Which suite carries the fence

**`tests/headless/test_wave_viewer.tcl`.** It exists, it is **registered** (in `dcases`
only — `tests/run_regression.tcl`, with a long comment explaining why: 343 of its 402
display-arm checks are display-only and an `hcases` copy would spend a case on the 59
non-GUI rows), and since issue 1616 its epilogue prints

```tcl
puts "OVERALL: ok ($npass checks)"
puts "RESULT: ALL PASS ($npass checks)"
```

which **satisfies `banner_complete`** (`^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$` in
`tests/banner_rule.tcl`) with the `RESULT:` line kept additively. So a band added there is
gated the moment it is written, with no registration work and no case-count move.

It is also already equipped for both halves of this fence:

* a real key driver — `send_key {w ev done}`, already used as
  `send_key $vdrw <Control-Key-w> {…}` in the G9 band;
* a real selection reader — the **WB** band's `wb_bold` helper reads
  `xschem getprop rect 2 0 hilight_wave` after real clicks, and the band already asserts
  select/clear/collapse behaviour (`WB-click`, `WB-precise`, `WB-legend`);
* a `viewer_ready`/`SKIPPED:` idiom so a never-mapped window self-skips rather than fails.

A `sel_waves` reader (`xschem getprop rect 2 <gi> sel_waves`) is not yet in that file and
would need adding — one helper beside `wb_bold`.

**Do not put the fence in these**, and here is why for each:

| suite | state | why not |
|---|---|---|
| `test_key_graph_context.tcl` | **unregistered**, prints only `RESULT: ALL PASS` | the natural home for the *structural* row (`xschem bindings dump`), but registering it means adding an `OVERALL: ok` sentinel **and** a T1 case. Do it only if the driver wants that cost. |
| `test_wave_trace_menu.tcl` | unregistered, `RESULT:` only | same. |
| `test_wave_hilight.tcl` | unregistered, `RESULT:` only | same. |
| `test_bindings_file.tcl` | unregistered | it is the suite that byte-compares `src/keybindings.csv` against the builtin table. If the C table changes, this is the thing that would have caught a forgotten regeneration — and nothing runs it. |

`xschem bindings dump` **works under `--nogui`** (measured above), so a purely structural
row needs no display; it just needs a registered home.

## 5. ⚠ Question 5 — the driver's claim, verified and refuted

The claim: *"`select_all()` in `src/select.c` is reached by ctrl+a over a graph and selects
schematic rects with zero wave awareness."*

**Half A — "reached by ctrl+a over a graph": REFUTED.** Measured (probe 1, dev display,
real `xschem callback .drw 2 <px> <py> 97 0 0 4`):

```
PROBE: rows for keysym 97 (a)  : {key 97 ctrl graph graph.forward} {key 97 0 graph graph.forward idle}
PROBE: any ctrl canvas row for 97:
PROBE: baseline                     graph_flags=0 lastsel=0 hilight_wave= sel_waves=
PROBE: graph centre in pixels = 797,192
PROBE: after Ctrl+a OVER GRAPH      graph_flags=2 lastsel=0 hilight_wave= sel_waves=
PROBE: after 2nd Ctrl+a OVER GRAPH  graph_flags=0 lastsel=0 hilight_wave= sel_waves=
PROBE: after bare 'a' OVER GRAPH    graph_flags=2 lastsel=0 hilight_wave= sel_waves=
PROBE: bare canvas point in pixels = 797,766
PROBE: after Ctrl+a OVER CANVAS     graph_flags=2 lastsel=20 hilight_wave= sel_waves=
PROBE: gucKey=1 Ctrl+a OVER GRAPH   graph_flags=0 lastsel=0 hilight_wave= sel_waves=
```

Over the graph: `lastsel` stays **0** and both selection tokens stay empty, while
`graph_flags` toggles bit 2 — i.e. the x-cursor-A toggle, not a selection. Over bare canvas,
the same chord takes `lastsel` **0 → 20**. The `gucKey=1` line shows the other profile
reaching the same toggle (it flips 2 → 0 from the previous state).

**What makes me confident it is the routing and not some other coincidence:** four
independent signals agree. (i) There is no `key 97 ctrl canvas` row, measured from the live
table. (ii) `act_graph_forward` returns 1 and `dispatch_input_action`'s caller `return`s on
1, so the `switch` is structurally unreachable for a chord whose graph row matched. (iii)
The same chord *does* reach `select_all()` when the pointer is 574 px lower, in the same
process and the same second. (iv) Bare `a` produces a byte-identical outcome to Ctrl+a over
the graph, which is what `access_cond` predicts and what a select-all would not.

**Half B — "selects schematic rects with zero wave awareness": CONFIRMED.**
`select_all()` (`src/select.c`, ~2515) loops wires, texts, instances (plus
`select_attached_floaters`), then for every layer `c < cadlayers` its polygons, lines, arcs
and **rects**. `GRIDLAYER` is **2**, so graph rects are included; `select_box()` refuses only
a rect carrying `lock=true`, and it records `xctx->graph_lastsel` when it selects a graph.
Measured (probe 2, headless):

```
PROBE2: instances=10 wires=6 texts=3 rects(layer2=1) total_countable=20
PROBE2: graph_rects=1
PROBE2: lastsel before select_all = 0
PROBE2: lastsel after  select_all = 20  graph_lastsel=0
PROBE2: done
```

20 = 10 + 6 + 3 + **1 layer-2 rect** — the graph rect is in the set, `graph_lastsel` was
written, and `hilight_wave`/`sel_waves` were untouched throughout. Zero wave awareness,
exactly as claimed.

**The likely origin of the error**, for the record: `src/callback.c:6479` is
`set_input_binding(DEV_KEY, 'a', ControlMask, ACTX_OVER_GRAPH, "graph.forward"); /* select
all */`. That trailing comment names what the chord does **on the canvas**, i.e. what this
row *diverts away from*; read quickly it says the opposite. The `case 'a'` ControlMask
branch carries the mirror-image comment. Neither is wrong, and together they are a trap.

## 6. Conflicts with Ctrl-A elsewhere — what must NOT change

1. **Schematic canvas Ctrl+A → `select_all()`.** Menu **Edit ▸ Select all**, `-command
   "xschem select_all" -accelerator Ctrl+A`, built in **`build_widgets`**
   (`src/xschem.tcl`). The accelerator is cosmetic: the chord is served by the legacy
   `switch` in `handle_key_press()`, **not** by the binding table, so it is not remappable
   and not touchable from `keybindings.csv`. Measured working (`lastsel 0 → 20`). Must not
   change.
2. **The `xschem select_all` subcommand** (`src/scheduler.c`, the `select_all` arm) — a
   scripted entry point independent of any chord. Must not change.
3. **Tk's `Text`/`Entry` class binding `<Control-Key-a>` = beginning-of-line.** `rdw.tcl`
   depends on this and says so in `rdw::popup_menu`: its *Select All* entry *"deliberately
   carries none [no accelerator], because Tk's Text class already spends
   `<Control-Key-a>` on beginning-of-line and an accelerator that does nothing is a lie on
   screen."* This is the reason a viewer-side Ctrl-A must be bound on the **canvas**
   (`WaveViewer` bindtag / the widget-level filter), never on the **toplevel** — a toplevel
   binding would fire for the Signal Browser search entry and the Add Trace dialog entries.
   Exactly the hazard class the Ctrl-B ruling (two-pane item 16, R9) had to reason about and
   measured clean.
4. **Bare `a` over a graph = cursor A**, in the default profile, and
   `wviewer::key_cursor_tail` for `N == 97`. Must keep working.
5. **`key,65,ctrl,graph` and `key,65,0,graph`** (Ctrl+Shift+A and Shift+A — hcursor1 and
   toggle-show-netlist). Different chords; must not be disturbed.
6. **`key,115,ctrl,graph`** — `Ctrl+s` is likewise a real graph row (cursor swap); the same
   "membership is unconditional on modifiers" rule applies, and nothing here should touch it.

⚠ **The one real conflict, and it is user-visible.** Giving Ctrl-A to select-all-traces
takes it away from x-cursor A. Two prices, both bounded:

* In the **default profile** (`graph_use_ctrl_key 0`) bare `a` still toggles cursor A, so
  nothing is lost but a duplicate.
* With **`graph_use_ctrl_key 1`** Ctrl+a is the *only* cursor-A chord: bare `a` makes
  `waves_selected()` skip (no ControlMask, no GRAPHPAN), falls through to canvas `case 'a'`
  with `rstate == 0`, and pops the **make-symbol** dialog. Those users would be left with
  **Cursors ▸ Cursor A** only. This is precisely the precedent the Ctrl-B change declared as
  "limit 8" in `wviewer::build_menubar`'s neighbourhood — a declared price, not a hidden one.

**Nothing documents Ctrl-A over a graph today**, which limits the blast radius: the
**Cursors ▸ Cursor A / Cursor B** menu entries carry **no `-accelerator`** at all
(`wviewer::build_menubar`), and a grep of `doc/claude/specs/*.md` for every Ctrl-A spelling
finds no viewer key table naming it.

## Also reported: user-visible surfaces Stage A would touch

These are the user's to ratify, not the crew's:

1. **Ctrl-A over a graph stops toggling cursor A** (see above, including the
   `graph_use_ctrl_key 1` case where it is the last cursor-A chord).
2. **The generated keybindings cheat-sheet.** `generate_keybindings_text`
   (`src/action_registry.tcl`) builds a live help window from `xschem bindings dump`,
   labelling each row from `src/actions.csv` col `label`, and it explicitly `continue`s over
   `graph.forward` as *"context plumbing, not user commands"*. A **new** action id would
   therefore **appear** in that window — with its `actions.csv` label, or with the raw id if
   no row is added. That label is a user-facing sentence.
3. **Any new menu entry.** The viewer menubar's cascade set is asserted by
   `test_wave_viewer` G2 to be exactly `{File View Graph Cursors Options}`, and there is no
   `Edit` cascade — so a "Select All Traces" item would have to join **Graph** (next to
   *Clear All* / *Delete All Markers* / *Delete Empty Strips*), and its label and
   accelerator are the user's call. The PLAN does not ask for a menu entry; I am naming it
   because "Ctrl-A with no menu twin" is itself a discoverability decision.
4. **Scope: the pointed strip, or every strip?** `Ctrl+click` builds a window-wide
   selection and a plain click collapses it to one strip; Delete acts window-wide. Both
   readings of "select all traces" are defensible and they differ in what the *next* Delete
   destroys. This is behaviour a person experiences and the single most likely thing to get
   wrong silently.
5. **What happens with nothing plotted / a digital or bus strip.** `hilight_traces`'s
   precedent is one `ciw_echo` and no change; a silent no-op is the other option.

---

## What the implementer needs — the exact seams

**Reading the selection (do not reinvent):** `graph_sel_waves_get` in C;
`wviewer::selected_waves` → `wviewer::selection_pairs` (MODEL space) /
`wviewer::selected_node_pairs` (NODE space) in Tcl.

**Writing it:** `graph_sel_waves_set(i, waves, n)` only. It is the sanctioned writer, it
answers "did anything change" so a no-op Ctrl-A does not churn the prop string, it keeps the
`n>=2`/absent-means-absent invariants, and it clamps at 64.

**Enumerating a strip's traces:** C — `count_items(get_tok_value(r->prop_ptr, "node", 0),
"\n", "\"")`, the same expression `graph_legend_at()` uses; Tcl — `wviewer::node_count $G`.
Iterate graph rects as `for(i=0; i<xctx->rects[GRIDLAYER]; ++i)` skipping `!(r->flags & 1)`.

**Two candidate seams for the action itself.** Both are legitimate; the difference is
remappability versus redraw plumbing, and it is an internal engineering call.

* **(a) A new registered action.** Add a row to `action_registry[]` in `src/callback.c`
  (e.g. `graph.select_all_traces`), point the existing
  `set_input_binding(DEV_KEY, 'a', ControlMask, ACTX_OVER_GRAPH, …)` row at it in
  `init_input_bindings`, then **regenerate `src/keybindings.csv`** with
  `save_input_bindings_file` (`src/action_registry.tcl`) — never hand-edit it;
  `tests/headless/test_bindings_file.tcl` byte-compares the two (and is itself
  unregistered, so nothing would catch a forgotten regeneration). Remappable by the user
  from day one, and it shows up in the cheat sheet.
  ⚠ **Declare `mutates = 0`** (the positional 5th field; omit it). `mutates = 1` sends
  `dispatch_input_action` through `readonly_block()`, and the viewer is read-only for its
  whole life — the result would be a modal dialog instead of a selection. `graph.forward`
  itself declares 0, and the shipped Ctrl+click select writes the same prop tokens with no
  `set_modify` and no `push_undo`, which is the precedent: **trace selection is view state.**
  This seam owns its own repaint (the `need_*_redraw` machinery lives inside
  `waves_callback`, not outside it).
* **(b) A new branch inside `waves_callback`**, placed **before** the existing
  `else if(key == 'a' && access_cond)` and gated on `(state & ControlMask)`. Gets
  `need_all_redraw` and the per-graph `setup_graph_data` re-read for free, and touches no
  table. Not separately remappable: the csv row stays `graph.forward`.

**⚠ The trap that will bite whichever seam is chosen:** `wviewer::key_filter`'s tail runs
`if {$T == 2 && ($N == 97 || $N == 98 || $N == 115)} { wviewer::key_cursor_tail $W $N }`
with **no modifier test**, inside `if {$fwd}`. Measured above: `kct=97` on Ctrl+a. If C stops
toggling cursor A for Ctrl+a, that tail still flips the `cva($token)` mirror, so the
**Cursors ▸ Cursor A checkbutton desyncs from the engine on every Ctrl-A**. The tail needs a
carve-out for 97-under-Control, in the same shape as the `fwd` carve-out for 98/100 — and
`wviewer::key_cursor_tail`'s own comment already names this failure mode ("Residual desync
risk: a C-side access_cond refusal the mirror cannot see").

**Replay logging.** The PLAN says to match the siblings, so here is what the siblings
actually do: **selection gestures are NOT logged.** `grep log_action src/callback.c` has no
hit anywhere in the Button1 selection arm or in `graph_sel_waves_*`. The logged viewer verbs
are the **mutations** — `wviewer::delete_items`, `wviewer::move_traces`,
`wviewer::set_wave_hilights`, `wviewer::set_plot_mode` — each through
`wviewer::log_action`, which is a single `catch {xschem log_action $line}`. So a C-seam
Ctrl-A that only changes the selection matches its siblings by logging **nothing**, and an
`actions.csv` `command` column for a new id would need the `nolog` treatment or a real
`xschem` subcommand to replay to. If a replayable line is wanted anyway, the honest shape is
a new CIW-typable Tcl verb (`wviewer::select_all_traces {{token {}}}`, the
`wviewer::hilight_traces` pattern: resolve token, `switch_ctx`, act, `ciw_echo` on refusal,
`log_action` with the explicit token) and the chord calling it — but that puts the write in
Tcl, where the only route to the tokens is `xschem setprop rect 2 …`, which bypasses the
sanctioned writers. **I would not do that**; I am naming it so the driver can reject it
knowingly.

**Fence, both directions, in `test_wave_viewer.tcl`:** with ≥2 traces on a strip (and ideally
2 strips, to settle question (4) of the user-visible list), `send_key $vdrw
<Control-Key-a> {…}` then read `hilight_wave` **and** `sel_waves` per rect; and the empty
case (no traces → nothing selected, no modal, `$::mb_hits` unmoved). Add a `sel_waves`
reader beside `wb_bold`. Remember the red-first rule and the "**a row must FAIL, not
THROW**" rule from the brief: `xschem getprop rect 2 <gi> sel_waves` on a rect with no such
token returns empty, but wrap anything indexing it in `catch` and check a legible sentinel.
A structural row (`xschem bindings dump` shows the new id for `key 97 ctrl graph`, and still
no `key 97 ctrl canvas` row) is headless-capable and cheap.

---

## What I got wrong during the stage, and what corrected me

1. **I started out believing the driver.** My first read of `src/callback.c:6479` —
   `set_input_binding(DEV_KEY, 'a', ControlMask, ACTX_OVER_GRAPH, "graph.forward"); /* select
   all */` — I took as *confirmation* that Ctrl+a over a graph ends in `select_all()`. It says
   the opposite: the comment labels the canvas meaning the row diverts away from. What
   corrected me was reading `act_graph_forward` and noticing it `return 1`, then finding
   `if(dispatch_input_action(&ae)) return;` above the `switch`. **The lesson generalises:
   in this file a binding row's trailing comment names the chord's canvas meaning, not the
   row's effect.** I would have shipped the driver's claim if I had stopped at the grep.
2. **I assumed `sel_waves` was a function**, because the PLAN lists it among "procs and C
   entry points". It is a prop-token name. The C readers/writers are
   `graph_sel_waves_get/set/toggle`; the Tcl reader is `wviewer::selected_waves`. Corrected
   by `grep -rn sel_waves` turning up `get_tok_value(..., "sel_waves", 0)` rather than a
   definition.
3. **I expected a `xschem` subcommand for the selection** and searched `scheduler.c` for one
   before accepting there is none. That absence is load-bearing for the implementation
   choice, so it was worth the detour, but I had assumed its existence for about ten minutes.
4. **I nearly reported the viewer conclusion from the static trace alone.** The `key_filter`
   chain is long (item-19 intercepts, `graphkeys`, the carve-out, the `with_edit` arm, the
   tail) and I had convinced myself by reading. Probe 3 both confirmed it and found the
   `key_cursor_tail` desync trap, which I had not noticed while reading — the `kct=97`
   column is the only reason that paragraph exists.

## What I did NOT do, and why

* **No file in the repo was changed** other than this receipt. No code, no test, no
  `NUMBERING.md`, no issue file.
* **No T1 run**, per the brief. No suite run either: none of the existing suites answers
  "what does Ctrl+A do", so running one would have cost minutes and told me nothing. The dev
  display was left exactly as found (`alive`, not started or stopped by me).
* **I did not open a real ASE-L viewer toplevel.** Its fixture
  (`test_wave_viewer.tcl`, ~lines 121–180) needs a copied ASE state, a scratch
  `library.defs`, `SKYWATER_MODELS`, a simulator-registry isolation call and a real ngspice
  dc sweep. Probe 3 measured the filter decision and the C effect without it. **The one
  thing this leaves unmeasured** is whether some binding in a real viewer window intercepts
  `<Control-Key-a>` before `key_filter`; the grep for every Ctrl-A spelling in `src/` returns
  exactly one hit and it is a comment, so I believe the answer is no. The command that would
  settle it: a `send_key $vdrw <Control-Key-a> {…}` row in that suite's G-band.
* **I did not measure the 5-px `border`-inset case in a real viewer** — the band-edge ring
  where `waves_selected` declines and Ctrl-A would therefore reach `select_all()` and select
  the graph rects as objects. The spec records that hole as already-known and cosmetic
  (`doc/claude/specs/waveform_viewer.md`, *"The graphs OWN the viewer window (issue 0149)"*:
  *"a graph rect can still be selected by a click in the 5 px `border` inset at a band edge
  — cosmetic"*), the viewer's rects carry no `lock` token (grepped `src/wave_viewer.tcl`:
  zero hits for `lock`), and `select_all()` has no read-only guard — so I expect Ctrl-A in
  that ring to select every graph rect today. It is **pre-existing and out of Stage A's
  scope**, but it is the one place where the driver's original claim is literally true, and
  the implementer should not be surprised by it. A `send_key` at a band edge would settle it.
* **I did not touch questions 7–12** (the other crew's), including anything about
  `getprop`'s own arms — even though `wviewer::selected_waves` and `wviewer::marker_graph_at`
  use `xschem getprop rect 2 <gi> <token>` and I read those call sites. I am not reporting on
  the arm's behaviour.
* **No permission prompt denied me anything.**

## Where the PLAN and the BRIEF are wrong or thin

1. **PLAN question 5's premise is wrong** on the "reached by" half. §5 above. The driver's
   scouting has now been wrong three times running; the plan's own instinct to gate on recon
   was right.
2. **PLAN question 2's lead list conflates four kinds of thing.** `wviewer::model_sel` is a
   pure model mirror that never touches a rect; `sel_waves` is a prop token, not a proc;
   `graph_sel_waves_set` is one of three C functions that are the *only* sanctioned writers;
   and `edit_wave_attributes` is the legend dialog (`what == 1`) / legend toggle
   (`what == 2`), not a selection setter. A Stage-A crew handed that list unqualified would
   plausibly write to the wrong layer.
3. **PLAN Stage A's logging constraint mis-frames the siblings.** "The action must be logged
   replayably **if the surrounding gestures are**" — the surrounding *selection* gestures are
   **not** logged (no `log_action` anywhere in the Button1 selection arm). The logged
   neighbours are the *mutations*. Matching the siblings therefore means logging **nothing**,
   which is the opposite of what the sentence reads like on first pass.
4. **PLAN Stage A's remappability constraint is true only for the graph context.** The
   schematic Ctrl+A is **not** in `keybindings.csv` and is not remappable; only
   `key,97,ctrl,graph` is. And "goes through that table" carries an unstated obligation the
   PLAN does not mention: `src/keybindings.csv` is **generated** and byte-compared by
   `tests/headless/test_bindings_file.tcl`, so a C-table change obliges a
   `save_input_bindings_file` regeneration in the same commit — and that suite is
   **unregistered**, so nothing in T1 would catch the omission.
5. **PLAN Stage A's "Fence both directions: selecting all when there are traces, and the
   empty case" is missing the third direction that matters most** — the `graph_use_ctrl_key
   1` profile, where Ctrl+a is today the *only* cursor-A chord. Whatever is decided there
   should have a row, or the regression is invisible.
6. **BRIEF's "Known pre-existing reds" list does not mention `test_wave_viewer`**, which is
   the suite Stage A will most likely touch and is the newest `dcases` entry (registered at
   `6ffc032a`/`3e307011`, one commit before HEAD). I did not run it, so I am not claiming it
   is red — only that the brief's list is silent about the suite in question and the
   implementer should take its own green before adding to it.
7. **BRIEF's environment section is accurate and load-bearing**; the `--pipe` does not imply
   `--nogui` warning in particular saved me from painting on the user's screen. No correction.
