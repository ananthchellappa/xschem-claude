# ASE Waveform Viewer — TABS

*Spec written 2026-08-03. Feature request: "there are only so many plots that can
be reasonably displayed on one screen".*
*Revised 2026-08-03 after a six-dimension source scout; §3 changed design (the
STASH, replacing a tab-key namespace) and §10 gained the G9 correction.*

Read first: `doc/claude/code_analysis/waveform_subsystem_reference.md` (the map;
§8 is the viewer, §11 the 52 landmines), `doc/claude/specs/waveform_viewer.md`
(viewer UX contracts) and `waveform_viewer_modes.md` §§12-19 (plot modes, the
LMB seam, undo, the selection-as-a-set rules). This document is the authority
for everything below; §15 "As shipped" records every delta once built.

---

## 1. What is being asked

A viewer window today shows ONE stack of strips. Beyond ~6 strips the bands are
too short to read. Tabs give one window several independent stacks.

| # | requirement (user's words) |
|---|---|
| R1 | tabs in the Waveform Viewer |
| R2 | `Ctrl-W` closes the open **tab** (today: kills the window). ⚠ **Ruled 2026-08-03: with only one tab `Ctrl-W` does NOTHING.** It closes a tab only when more than one exists |
| R3 | `Ctrl-Q` (remappable) kills the active Waveform Viewer **window** |
| R4 | `Ctrl-N` (remappable) opens a new tab, starting with one empty strip |
| R5 | `Ctrl-C` / `Ctrl-V` copy & paste traces between tabs. Destination in **multi**-plot mode ⇒ pasted traces keep their *separateness*, landing on different strips as they were in the origin tab. Destination in **single**-plot mode ⇒ all pasted traces land on one strip |
| R6 | every action logged to the CIW **and** the log file. Replayable is nice-to-have, not must-have |

Non-goals for v1 in §14.

---

## 2. D1 — a tab is a MODEL, not a context

**A viewer WINDOW keeps exactly one xschem context, one toplevel, one canvas and
one loaded raw. A TAB is another value of the Tcl model, rendered by the
regenerate that already exists.**

All six scout dimensions reached this independently. The evidence is not "it is
cheaper"; option (a), one xschem context per tab, is **currently
unimplementable**:

- `create_new_tab` and `switch_tab` hardcode a tab's render target to
  `save_xctx[0]->window` (`xinit.c` ~2187, ~1925), so an xschem tab minted for
  the viewer toplevel would draw onto the MAIN schematic window's `.drw`.
  `doc/claude/specs/multi_window_detach.md:41-45` states it outright — "A tab
  cannot belong to a second top-level" — and that spec's Phase 1 is **proposed,
  not built**.
- An xschem tab has `top_path == ""` and shares the main window's canvas
  (`xinit.c` ~2178, ~2186, ~2572-2581). `.xN.drw` would not be a Tk widget, so
  `bind $wp`, `bindtags $wp`, `winfo width $wp`, `focus $wp` and
  `strip_bindings $wp` would all aim at the user's schematic canvas.
- Each context costs ~0.5 MB of fixed tables (two 31627-entry hashes, four
  50×50 spatial tables), ~49 GCs and a full-canvas pixmap, and burns one of
  only **20** globally shared slots (`xschem.h:158`) whose exhaustion is silent
  (`xinit.c` ~1989-1992, measured in issue 0187).
- It would multiply two OPEN bugs by the tab count: issue 0187 (the open guard
  is circular — measured branding a user's 23-instance schematic
  `wave_viewer=1 readonly=1 no_grid=1 no_snap=1` while `open` returned success)
  and issue 0186 (a viewer context is destructible by a CIW `xschem reload`).
- Landmine 42 seals it: a ctx switch ends in `set_modify(-1)`, which rewrites
  the target window's title from its buffer name **and pushes that name into
  the tab button's `-text`** (`actions.c` ~242-266, `xschem.tcl` ~13370-13373).
  A viewer buffer is nameless and read-only, so every viewer tab would be
  labelled `untitled-N.sch`.

By contrast `wviewer::regenerate` already does `xschem clear_drawing` and
re-places **every** rect from the Tcl model, and `wviewer::restore`
(`wave_viewer.tcl` ~2062-2107) is already a whole-model swap in one window —
overwrite `layouts`, set `sharedx`/`mode`/`target`, clear the history and the
highlight set, ONE `regenerate`. **A tab switch is that operation.** Design (b)
adds ZERO new context switches, which is the entire content of issue 0173.

Consequence accepted openly: all tabs of one window share the raw, the engine's
cursor A/B state and the window geometry. Per-tab raws are §14 deferred.

---

## 3. D2 — THE STASH. Tabs add a dimension without adding a key space.

*(This replaces the first draft's `<token>#N` tab-key namespace, which the scout
refuted: `wviewer::token_for_canvas` resolves win_path → token by FIRST MATCH
and ~35 call sites depend on that being 1:1, and `windows`/`graphbb` are the
Tk identity of the window. Minting extra tokens into `windows` makes the reverse
lookup ambiguous.)*

Every per-view-content array — `layouts`, `mode`, `target`, `sharedx`,
`gridshow`, `undo_hist`, `redo_hist`, `wavehl`, `cva`, `cvb`, `cvr` — is keyed
by the ASE session token and **keeps that key, unchanged, always describing the
ACTIVE TAB**. The inactive tabs live FROZEN in one new per-window store:

```tcl
  variable tabstash ;  # token -> list of frozen tab records, one per tab, in bar order
  variable curtab   ;  # token -> index into that list  (the ACTIVE tab)
  variable tabseq   ;  # token -> next tab id to mint (monotonic, never reused)
```

One frozen record is a dict of exactly the content state a tab owns:

```tcl
  {id <int>  name <string>
   layout {sharedx .. grid .. graphs {..}}      ;# the whole layout value
   mode <single|multi>  target <int>
   cva <0|1>  cvb <0|1>  cvr <0|1>
   undo {..}  redo {..}  wavehl {{gi ni style} ..}}
```

A tab switch is a **freeze/thaw**: freeze the live arrays into
`tabstash($token)[curtab]`, thaw the incoming record into the same arrays, set
`curtab`, regenerate.

**Why this is the right shape, and it is not a stylistic preference:**

- **Not one line of existing viewer code changes its key.** `layout_for
  $token`, `mode($token)`, `target_index $token`, `with_edit $token`,
  `switch_ctx $token`, `token_for_canvas $wp`, `current_token`,
  `resolve_token`, `regenerate $token`, every `*_at %W` bindtag wrapper, every
  menubar `-command`/`-variable` that captured `$token` at build time, and
  every call from `ase_window.tcl` — all correct, untouched, by construction.
- **Direct Plot, auto-plot and `viewer_restore` land in the ACTIVE tab for
  free**, because the arrays they write ARE the active tab. No redirect, no
  normaliser, no sweep over 40 procs, and therefore no class of "one proc was
  missed" bug — which is the failure mode a key-space split would have had, and
  which no single-tab test could see (landmine 46(a) shape).
- `graphbb` (keyed by win_path) needs **no** change: only the active tab is
  drawn, and every switch ends in a `regenerate` that rebuilds it.
- The freeze/thaw pair is the ONE new thing to get right, so the whole feature
  has one narrow place to sabotage-verify instead of forty.

`tabid` is an inert, stable, monotonic integer carried in the record and never
reused. Nothing behavioural reads it; it exists so a test can witness *"the
paste landed in the tab that was second"* independently of *"the tabs got
reordered"* — the `sdid` lesson from `test_wave_viewer`'s `TD*` group.

### D3 — the freeze must be COMPLETE, and `forget` is the audit

The freeze/thaw list above must cover every array a tab owns. The authority for
"what is per-view-content" is the scout's full inventory of
`wave_viewer.tcl:300-454`:

| class | arrays | tab treatment |
|---|---|---|
| per-view CONTENT | `layouts`, `target`, `mode`, `undo_hist`, `redo_hist`, `wavehl` | **frozen/thawed** — every one carries a graph INDEX into a specific graph list |
| per-view content held as MENU MIRRORS | `sharedx`, `gridshow` | **re-synced from the incoming layout** — the authority is the layout dict's own `sharedx`/`grid` keys; these arrays exist only because Tk's `-variable` needs a global |
| per-view content backed by PER-XCTX C state | `cva`, `cvb`, `cvr` | **frozen/thawed AND re-driven into the engine** — one xctx means one pair of cursors for all tabs, so a switch must re-push `xschem cursor` or the outgoing tab's cursors stay drawn |
| per-WINDOW | `windows`, `graphbb`, `cursor_warned`, `cfgafter`, `fillwh`, `mmb`, `b3x0`/`b3y0`/`b3mk` | untouched — they describe the pointer and the canvas, of which there is one |
| per-window but RESET ON SWITCH | `drag_from`/`drag_to`/`drag_y0`/`drag_active`, `tdrag_*` | **reset** — they hold MODEL indices of a half-finished gesture, and an arm on tab 1's strip 3 that survives a switch commits against tab 2's strip 3, silently valid |
| per-window DIALOG state | `axl` (`$token,x`/`$token,y`), `delmap`, and the dialogs `$top.wvadd` / `$top.wvdel` / `$top.wvaxes` + both context menus | **torn down on switch** — their listboxes and comboboxes were built from the OUTGOING tab's graph count |

⚠ **Pre-existing bug found by the scout, fix it first and separately:**
`wviewer::forget` unsets `gridshow($token)` (~:540) but never declares
`variable gridshow` (~:501-511), so that `catch`'d unset silently does nothing
and the mirror leaks across a close/re-open. One line.

`forget` must additionally drop `tabstash`/`curtab`/`tabseq` for the token. A
leg asserts the token's whole array family is empty after a close.

### D4 — bindings created in `open` keep their captured token

`wviewer::open` substitutes `$token` literally into five bindings
(`<ButtonRelease>`, `<Motion>`, `<Configure>` on the canvas; `<FocusIn>`,
`<Destroy>` on the toplevel). Under D2 the token is still the one true key for
that window, so **all five are correct unchanged** — the freeze/thaw is what
makes them tab-correct. (The first draft of this spec had to rewrite them; the
stash removes that work and that risk.)

---

## 4. Lifecycle

### D5 — switching tabs

```
  select_tab <token> <index>:
    0. already there                       -> no-op, no log line, no CIW line
    1. verified switch_ctx                  (landmine 17)
    2. capture_live_view_state <token>      (selection + markers; NOT the ranges)
    3. tabview <- the live per-strip {x1 x2 y1 y2} read off the rects   (D6)
    4. FREEZE the live arrays into tabstash[curtab]
    5. reset the gesture arrays; tear down the three dialogs + both ctx menus;
       `xschem graph_marker select -none`
    6. THAW tabstash[index]; re-sync the sharedx/gridshow mirrors from the
       incoming layout; re-drive the engine cursors from the incoming cva/cvb
    7. curtab <- index
    8. regenerate            (its own `wave_hilight_push` restores the highlights)
    9. re-apply tabview for the incoming tab, then one redraw            (D6)
   10. refresh the tab bar, the readout, the status bar, the title
   11. one CIW line + one log line
```

Step 2 is not optional and is landmine 50 in its purest form: `regenerate` runs
`clear_drawing`, and the selection lives ONLY in the rect's `hilight_wave` /
`sel_waves` tokens. A switch without the fold destroys the selection of the tab
being left. It uses `capture_live_view_state` — `skip_ranges 1` — for the
reasons landmine 50(c) gives: an unconditional range fold pins every auto axis,
and under Shared X it copies strip 0's window onto every strip's model
permanently.

A tab switch is **navigation, never an undo point** (the `set_plot_mode`
precedent).

### D6 — `tabview`, the transient per-tab view cache

Steps 3 and 9 are the one place tabs go beyond "regenerate does it". Without
them a switch discards the pan/zoom the user made with the mouse: the model
still says `{}` = auto, so `regenerate` re-autozooms. Across a window resize
that is shipped behaviour and tolerable; across a gesture performed dozens of
times a session it is not.

`tabview` is TRANSIENT — never the model, never serialised — exactly the
`wavehl` shape, re-applied by the same kind of push `regenerate` already makes
for the highlight set. It therefore pins nothing and cannot destroy a Shared-X
window. The re-apply is guarded on the strip count matching (the rect↔model 1:1
guard every other fold in this file carries) and silently skips a mismatch.

### D7 — the tab bar appears only when there is a choice

`$top.wvtabs` — a themed `frame` of `button`s, one per tab, plus a trailing
`+` button — packed `-side top -fill x -before $top.drw`. That `-before` is
mandatory: `$top.drw` is packed `-fill both -expand true`, so anything packed
after it gets zero height. It is the idiom `$top.wvstatus` already uses
(`wave_viewer.tcl` ~758). The frame lives on `$top`, OUTSIDE `$wp`, so
`strip_bindings` — which enumerates only `[bind $wp]` — never sees it, and the
existing `bind $top <Destroy>` `%W` guard already tolerates extra descendants.
Every tab widget takes `-takefocus 0` (the `.tabs.x0` precedent) and the select
command ends in `focus <win_path>`, because `autofocus_mainwindow` defaults to
0 and keys only reach `key_filter` while the canvas holds focus.

Plain Tk `frame`+`button`, **not** `ttk::notebook`: a notebook manages its
panes' geometry, and the viewer's "pane" is a single C-drawn X canvas that must
not be reparented or duplicated. One canvas, N models is the correct
decomposition. And **not** xschem's `.tabs` code: those buttons' identity IS
their `-command` string, which `tab_ctx_cmd`/`tab_context_menu` parse back out
with `lindex … 3` and `prev_tab`/`next_tab` scavenge with hardcoded
`.tabs.x$i` + `winfo rootx` (`xschem.tcl` ~12676, ~12797). The frame-of-buttons
SHAPE is worth copying; the code is not.

**The bar is packed only while the window has ≥ 2 tabs.** This is the
issue-0151 precedent applied verbatim ("the active-strip marker only exists
while there is a choice to make"), and it buys the §10 regression contract: a
one-tab viewer has the same widget tree and the same canvas geometry as today,
so no shipped band or pixel assertion moves. Discovery for a one-tab window is
`File > New Tab` with its `Ctrl+N` accelerator label.

⚠ Recorded counter-argument (scout, dimension 3): pack the bar ALWAYS, so a tab
verb never changes canvas geometry behind the `<Configure>` refit. Rejected:
the 1↔2 transition goes through `<Configure>` → `configure_apply`, which
already captures and regenerates — it is the shipped window-resize path, not a
new one — and always-packing would move the geometry of every existing
single-tab viewer, which is exactly the ~1500 shipped checks this design is
built to leave alone.

### D8 — new tab

`Ctrl-N` / `File > New Tab` / the `+` button →

```
  new_tab <token>:
    freeze the active tab (as in D5 steps 1-5)
    append a record: id = tabseq++, name "Tab <id>",
      layout {sharedx <inherited> grid <inherited> graphs {<one empty strip>}},
      mode <the window's current mode, inherited>, target 0,
      cursors <the window's current mirrors>, undo/redo/wavehl empty
    curtab <- the new index; thaw; regenerate; refresh the bar
```

R4: "starts off with an empty graph element as usual" — one empty strip,
exactly what `clear_all` leaves behind, so the tab reads as a graph window and
the next plot has somewhere to land. The mode is INHERITED (the `clear_all`
precedent: a user working in multi-plot keeps working in multi-plot).

No context branding is needed — a new tab is not a new context (D1). This is
also why `Ctrl-N` cannot re-open issue 0187.

### D9 — close tab (`Ctrl-W`) — and D9a, the refusal

```
  close_tab <token> <index>:
    if the window has ONE tab -> REFUSE (D9a)
    else: drop the record; curtab <- the neighbour to the RIGHT, or the LEFT
          when the closed tab was last; thaw it; regenerate; refresh the bar;
          one CIW + one log line
```

**D9a — closing the last tab does NOTHING. `Ctrl-W` never closes a window.**
*(User ruling, 2026-08-03, overriding this spec's first draft, in which the last
tab's close fell through to a window close.)*

- one tab up ⇒ `Ctrl-W` is a **refusal**, not a fall-through. One CIW line
  (`wviewer: only one tab - nothing to close`) and **no** log line: nothing
  changed, so D12's change-only rule applies. A key that silently does nothing
  reads as broken, which is why the refusal is spoken;
- `File > Close Tab` is `-state disabled` while the window has one tab, so the
  menu tells the same truth the key does. One function owns "the tab count
  changed" and refreshes the bar, the button states AND this entry — the
  `graph_marker_label_box` doctrine (one geometry, one owner);
- the only ways a viewer window dies become `Ctrl-Q`, `File > Close Window`,
  the WM close button and a programmatic `wviewer::close`.

⚠ **This is a deliberate break of a shipped key** — see §10 item 4 for its
measured cost, which is NOT zero.

`Ctrl-Q` → `wviewer::close <token>` — the shipped window kill, unchanged
(`ase_window.tcl:268` calls it as public API), now reachable by its own key.

---

## 5. Keys — D10, with the collision check each one owes

All five go on the shared **`WaveViewer` bindtag** in
`wviewer::install_default_binds`, each guarded by `[bind WaveViewer <seq>] eq
{}` so an rc that binds first WINS, and each body ending in `; break`. That tag
is the only rc-remappable, sweep-proof binding table in the viewer, and the
`break` is what guarantees the chord never travels on to the toplevel, the
`all` tag, or a future canvas binding. Disable with `{break}`, never `{}` (an
empty script DELETES the binding, which reads as "never bound" and gets
re-defaulted). Every handler is a `*_at {W}` proc resolving its token via
`token_for_canvas %W`, **never** from the current xschem context — the tag is
process-global.

`wviewer::graphkeys` is NOT touched and no new `key_filter` forward arm is
written: keysyms 113/110/99/118 reach the C engine from a viewer by no path at
all today, and that is the protection.

| key | action | collision check — measured |
|---|---|---|
| `Ctrl-N` | new tab | C binding-table row `key,110,ctrl,canvas,file.clear_schematic` (`src/keybindings.csv:50`) and `cadence_style_rc:173` `bind .drw <Control-Key-n> {cadence::new_blank_window}`. **Neither reaches a viewer**: `key_filter` forwards nothing for keysym 110 and `strip_bindings` sweeps the cloned widget-level bind. The Ctrl-E shape (issue 0171). |
| `Ctrl-W` | close TAB; **no-op at one tab** (D9a) | today a hardcoded first arm of `key_filter` (`wave_viewer.tcl` ~7274-7277) calling `wviewer::close`, i.e. killing the window. **That arm is DELETED** (D11). |
| `Ctrl-Q` | close WINDOW | ⚠ the C dispatcher's `case 'q'` under `ControlMask` is **`quit_xschem` — it quits the application** (`callback.c` ~6670-6677), and `test_multi_window.tcl:157` records that Ctrl-Q is live on a schematic canvas. It cannot reach a viewer (113 is not in `graphkeys`, no intercept arm) and the `break` keeps it that way. This is the one collision that would be catastrophic if the swallow regressed, so the suite carries an explicit leg: `Ctrl-Q` in a viewer closes the window **and the process is still alive**. |
| `Ctrl-C` | copy selected traces | bare `c` in C is the Cadence copy (`callback.c` ~6061); Ctrl+C has no canvas row and is swallowed regardless. |
| `Ctrl-V` | paste traces | bare `v` in C is the vertical-drag constraint (`callback.c` ~6956); a forward would pop `readonly_block()`'s modal over the plot — the failure the existing Ctrl-D carve-out (`wave_viewer.tcl` ~7318-7327) was written to prevent. |

### D11 — the `key_filter` Ctrl-W arm is removed

`key_filter` is bound on the WIDGET (bindtags index 0) and **returns without
`break`**; the `WaveViewer` tag is at index 1. So an arm there AND a tag
binding both fire — one keystroke would close the tab and then destroy the
window. The arm goes; the tag binding is the only handler. Its `Ctrl-Shift-W`
sibling (keysym 87) folds into the same default.

Menu twins in `File` (accelerator labels are inert display strings — Tk does
not dispatch them, and an rc that remaps the tag changes the key, not the
label):

```
  File > New Tab            Ctrl+N
  File > Close Tab          Ctrl+W      (disabled while the window has one tab)
  File > Close Window       Ctrl+Q
  File > Copy Traces        Ctrl+C
  File > Paste Traces       Ctrl+V
```

The shipped `File > Close  Ctrl+W` entry is gone, replaced by the first three.
⚠ **No new top-level cascade.** `test_wave_viewer` `G2` asserts the cascade set
is exactly `{File View Graph Cursors Options}`; a `Tabs` menu (which the scout
suggested) would break it for no user benefit.

---

## 6. Copy and paste of traces

### D12 — what `Ctrl-C` copies

Copy is a **TRACE-level** operation, never a strip-level one. It must NOT copy
graph dicts: those carry `auto`, `markers`, `hilight_wave`/`sel_waves` and axis
ranges, all of which are meaningless or actively harmful in another strip
(`wave_viewer.tcl` ~1500, ~2596-2626).

The correct sequence, and each step is load-bearing:

```
  token from %W via token_for_canvas      (never the current ctx)
  VERIFIED switch_ctx                     (`selected_waves` only catches its own
                                           switch; a refused switch reads a
                                           FOREIGN window's rects)
  capture_live_view_state                 (landmine 50: the selection lives only
                                           on the rect until it is folded)
  selection_pairs %W                      (the one shared NODE->MODEL fold)
  read the 4-key trace dicts out of layout_for
```

The clipboard is a namespace-global (one per session, not per window):

```tcl
  wviewer::clip = {
    from   {<token> <tabid>}          ;# provenance, for the CIW line only
    raw    {<rawfile> <sim_type>}
    items  { {gi <source model strip>  tr {expr .. name .. vec .. color ..}} ... }
  }
```

The **source strip index carried per item is the whole of what R5's
"separateness" needs** — grouping is derived from it, so nothing else about the
source layout has to be copied.

Empty selection ⇒ one CIW line and **the clipboard is left untouched** — a
failed copy must never destroy a good clipboard. Copy mutates no model, so it
takes no undo point, does not regenerate, and writes **no replayable command
line**; its record is the D14 echo line, which reaches both channels and so
satisfies R6.

### D13 — where `Ctrl-V` lands

`plan_paste` is a PURE proc — the `plan_plot` shape, headless-testable — taking
`{mode ngraphs target ngroups empties}` and returning `{new <n> sites {<gi>…}}`,
one site per GROUP (a group = one distinct source strip, in source order).

- **destination `multi`** — one group per strip. Empty non-auto strips are
  reused first, lowest index first (`empty_graph_indices`, the 0171 follow-up
  rule); the shortfall is **APPENDED at the bottom**.
  ⚠ **A paste appends; it does not front-insert.** `plot_signals`' multi arm
  grows the stack upward and lays a batch out newest-first, because a plot batch
  is "the newest thing you asked for"; it then owes the `+nnew` shift of the
  stored target AND of the highlight set. A paste is a copy of a layout fragment
  and must READ THE SAME WAY IT DID in the source, so it appends and owes
  neither shift. The deviation from `plot_signals` is deliberate and is stated
  here so the next reader does not "fix" it.
- **destination `single`** — every group is FLATTENED, in source order, into the
  clamped non-auto target strip. One site, repeated.

The fold is a NEW pure proc `paste_traces_in_graphs`. ⚠ It must **not** reuse
`move_traces_in_graphs`: that proc's `- $done($gi)` per-source index adjustment
(landmine 49(a)) exists only because a move REMOVES from its source, and a paste
removes from nothing. It appends whole dicts (`linsert … end`) and computes each
destination NODE index as `node_count $D` before each append — the two rules
`move_trace_in_graphs` already encodes for exactly this situation.

### D14 — colours

RE-PLAN against the destination, seeded with a preference: **a pasted trace
keeps its source colour when that colour is not already in the destination
strip's `used` set**; otherwise it takes the next unused palette entry
(`first_unused_color`, the landmine-22 machinery). Keeping the colour is what
makes a trace recognisable across tabs — the point of copying it — while
blindly keeping it puts two indistinguishable traces on one strip, precisely
the failure issue 0153 fixed. `add_trace`/`plot_signals` already accept explicit
per-trace colours (the 0153 seam), so no new mechanism is needed. The walk is
per landing strip, in group order, and the `used` set grows as the group is
placed, so two source traces that shared a colour and land together still
separate.

### D15 — ranges of a strip a paste CREATES are blanked to auto

`{}` for `x1/x2/y1/y2`, landmine 34(a): `capture_live_view_state` has just
frozen whatever window was last fitted, and a µA trace dropped into a 0-2 V
window draws off-screen and reads as "the paste failed". A destination strip
that already holds traces keeps its window.

### D16 — the raw: a cross-window paste is a NAME REBIND

A viewer trace carries only a NAME. `graph_props` emits **no** `rawfile=` or
`sim_type=` token, so every trace resolves against the destination context's
`xctx->raw` (`draw.c` ~3300-3310). Consequences:

- an intra-window paste (the R5 case) always resolves — tabs share the
  context's raw (D1) — and needs nothing;
- a cross-window paste is allowed, but it **rebinds names**. It owes a
  destination-side existence check (`xschem raw index` / `raw list`) and one
  CIW line naming the vectors that do not resolve; the paste proceeds, because
  a missing vector simply draws empty, which is the shipped behaviour for a
  stale expression trace after a re-run;
- an expression trace (a `vec` plus a multi-token `expr`) must be
  RE-MATERIALISED in the destination with `xschem raw add $vec $expr` before
  the regenerate — the `wviewer::restore` precedent (~2095-2104), same `catch`
  discipline (the RPN was validated when the trace was created);
- ⚠ **and it must be RENAMED first when that vector name already exists in the
  destination raw** (`auto_expr_name`), or `raw_add_vector` recomputes the
  destination's OWN vector in place and silently changes an unrelated trace
  that was already on screen.

Do not reach for the `%rawfile%simtype` node syntax to "carry" a raw across:
`validate_rpn` rejects such tokens and the fields are `subst`ed at draw time.

### D17 — ONE of everything

A paste owes **one** verified `switch_ctx`, **one**
`capture_live_view_state`, **one** `push_undo` (so `u` undoes the whole paste,
not one trace at a time), **one** `regenerate` and **one** fully-resolved log
line — landmines 46(c) and 49(b). It folds on the PURE layer so no intermediate
state is ever snapshotted, and it validates loudly against the live model while
refusing a no-op **without mutating or logging** (the `move_traces` contract).

### D18 — the selection is NOT changed by a paste (v1)

Tempting, but it means writing `hilight_wave`/`sel_waves` onto rects the
regenerate has just recreated — a second push after the model write, the
snapshot-after-mutate shape. Deferred (§14) rather than half-done.

---

## 7. D19 — persistence

`wviewer::snapshot` returns a flat dict `{open sharedx rawfile graphs mode
target}` nested under the ASE state's `viewer` key. It gains, **only when the
window has two or more tabs**:

```tcl
  tabs      { {name .. layout {..} mode .. target ..}  ... }   ;# ALL tabs, in bar order
  activetab <index>
```

and **keeps the existing flat keys describing the ACTIVE tab verbatim**. So a
single-tab viewer serialises byte-identically to today — which matters beyond
compatibility: `ase::ui::viewer_snapshot`'s difference test (`ase_window.tcl`
~3063-3070) would otherwise mark every session dirty. An older build reading a
new state file gets the active tab and ignores `tabs`; a new build reading an
old file finds no `tabs` key and builds a one-tab viewer. No format version
bump. This is the `sel_waves` compatibility shape (landmine 43) applied to the
state dict.

`tabview`, the undo/redo stacks and the trace-highlight set stay OUT of the
snapshot, exactly as they are today.

⚠ `test_ase_persist` `R1` asserts an exact 15-key state set and `R4` an exact
closed-arm `snapshot` dict. Nesting inside `viewer` and emitting `tabs` only at
≥2 tabs keeps both green; the closed arm is not touched.

---

## 8. D20 — logging (R6), and the 0207 correction

⚠ **`ciw_echo` alone does NOT satisfy R6.** Issue 0207 measured exactly this:
messages sent through the pane helper reach the CIW's mirror and **never the
log file**. There are ~120 pane-only `ciw_echo` sites in `wave_viewer.tcl`,
explicitly left out of scope by 0207.

So add one seam, `wviewer::echo {msg {tag {}}}`, cloned in structure from
`ase::echo` (`ase.tcl:115-125`): the pane half gated on
`[info commands ::ciw_echo]` and **not** on `::has_x` (that guard is precisely
what 0207 measured as the suppressor), empty-message return, `string trimright`
+ trailing-backslash pad, then `xschem log_action -error` for the `error` tag
and `-result` otherwise, both halves catch'd. **Route only the new tab messages
through it**; converting the 58 existing pane-only refusals is 0207's deferred
item 2 and would collide with the in-flight edits to this file.

`wviewer::log_action` (~2199) stays the sole sink for REPLAY lines, and the
shipped practice form `wviewer::<verb> <args…> <token>` — token LAST — is kept
unchanged: issue **0209 is open and undecided**, so consistency with the 15
shipped lines beats a rule whose own author recommends widening it. Note the
choice in 0209.

| operation | CIW (via `wviewer::echo`, both channels) | replay line (via `log_action`) |
|---|---|---|
| new tab | `wviewer: new tab 'Tab 2' (2 tabs)` | `wviewer::new_tab <tabid> <token>` — replayable |
| switch tab | `wviewer: tab 'Tab 2'` | `wviewer::select_tab <tabid> <token>`, **change-only** (the `set_target_strip` rule) |
| close tab | `wviewer: closed tab 'Tab 2' (1 left)` | `wviewer::close_tab <tabid> <token>`, logged always (destructive — the `clear_all` rule) |
| close tab refused | `wviewer: only one tab - nothing to close` | **none** — nothing changed |
| close window | `wviewer: closed the waveform viewer (2 tabs)` | `wviewer::close <token>` — must be no-op-safe on an unknown token on replay, as it already is (~795-797) |
| copy | `wviewer: copied 3 trace(s) from 2 strip(s)` | **none** — a clipboard write mutates no model; the echo line is the honest record |
| paste | `wviewer: pasted 3 trace(s) into 2 strip(s)` | `wviewer::paste_traces <normalised payload> <token>` — carries the descriptors ACTUALLY pasted, not a clipboard reference. The one genuinely replayable new verb (landmine 49(b)'s normalised-arguments rule) |

⚠ `close_tab` and the window close must wrap the teardown in the
**`log_action -suppress`** scope that already exists, so the C side's own
`xschem new_schematic destroy` self-log (`xinit.c` ~2329) does not appear as a
second, un-replayable line.

---

## 9. Files touched

| file | what |
|---|---|
| `src/wave_viewer.tcl` | everything above, plus the D3 `forget`/`gridshow` fix |
| `src/ase_window.tcl` | nothing expected — the stash makes its token calls correct. **Verify**, do not assume: landmine 50(b) records that a file-scoped audit walked past two `regenerate` sites in this file |
| `doc/claude/specs/waveform_viewer_tabs.md` | this document |
| `doc/claude/code_analysis/waveform_subsystem_reference.md` | §8 gains the tab model, §9 the new verbs, §11 a landmine if one is found |
| `doc/ase_l_tutorial.html` §6 | the viewer keyboard table gains the five keys and records the Ctrl-W change |
| `tests/headless/test_wave_viewer.tcl` | **G9 rewritten** (§10 item 4) |
| `tests/headless/test_wave_tabs.tcl` | new suite |
| `tests/headless/full_audit.sh` | register the new suite in `logdir_tests` |

**No C change is expected.** If one turns out to be needed that is a finding
worth stating loudly — the whole design rests on the engine not knowing about
tabs.

---

## 10. Regression contract

1. **A one-tab viewer is byte-identical to the shipped one**: same widget tree
   (no `$top.wvtabs`), same canvas geometry, same band pixels, same array keys,
   same state-dict keys, same log lines.
2. `bind $vdrw` is byte-identical, so `test_wave_viewer` `G1s`'s hardcoded
   allow-list of surviving canvas sequences stays green — the new keys are on
   the BINDTAG, not the canvas.
3. The `WaveViewer` bindtag gains exactly five sequences. Existing tag legs
   (`CG4`/`CG6`, `EG8`) assert membership, not the exact set, so they are
   unaffected; each new key gets its own six-check CG4-shaped block plus the
   CG6 rc-wins / `{break}`-disables pair.
4. ⚠ **THE ONE DELIBERATE BREAK, and it is NOT free.**
   `tests/headless/test_wave_viewer.tcl:615-632` — group **`G9`, eight
   checks** — drives `<Control-Key-w>` into a viewer and asserts the toplevel
   is destroyed, the registry cleaned, no prompt popped, and a re-open builds
   fresh. Under D9a that key is now a no-op on a one-tab viewer, so **G9 must be
   rewritten**: keep every property it guards (no prompt, registry clean,
   re-open fresh) and drive them through `Ctrl-Q`, then ADD the D9a legs (one
   tab ⇒ window survives, CIW said so, no log line; two tabs ⇒ one closes).
   *(This corrects an earlier claim in this session that the churn was zero —
   the grep that produced it could not match `<Control-Key-w>`.)*
   Documentation owes the same: `doc/ase_l_tutorial.html` §6 and the pending
   user guide (`next_session_prompt_waveform_user_guide.md`).
5. `test_wave_viewer` `G2`'s exact cascade set `{File View Graph Cursors
   Options}` — no new top-level menu (D11).
6. `test_ase_persist` `R1` (15 state keys) and `R4` (closed-arm snapshot dict)
   — D19 keeps both.
7. Direct Plot, auto-plot and `viewer_restore` still land where they did — in
   the active tab, which for a one-tab window is the only tab.
8. `mk_expect_*` / `wh_expect_*` pinned check counts are bumped BY HAND if the
   marker or hilight suites are touched.

---

## 11. Landmines this work walks into

| # | why |
|---|---|
| 50 | a tab switch is a regenerate; without the fold it destroys the selection. 50(d)'s witness rules bind every tab leg: multi-trace selection, non-zero strip, non-zero node, plant on the RECT, read EVERY strip |
| 50(c) | do NOT fold the ranges on a switch — hence `tabview` (D6) |
| 49(a) | the paste fold must NOT inherit `move_traces_in_graphs`' `- $done($gi)` term (D13) |
| 49(f) | a fixture where MODEL and NODE index spaces coincide tests neither — plant a vec-less trace at a non-zero model index |
| 34 | model vs NODE index. `selection_pairs` is the only correct bridge (D12) |
| 34(a) | blank the ranges of a strip the paste creates (D15) |
| 22 | the colour `used` set is mode-dependent; D14's walk is per landing strip |
| 46(c) | one undo point for a multi-object gesture (D17) |
| 17 | every mutation through `with_edit`; every `switch_ctx` VERIFIED |
| 42 | end every tab-switch path with `retitle`: any ctx switch into this window stamps `untitled.sch (read-only)` until FocusIn repairs it |
| 41 | the viewer command layer is DISPLAY-only (`open` returns 0 without `::has_x`; `regenerate` bails on an empty `windows` dict). The PURE halves are the both-arms legs |

---

## 12. Test plan — `tests/headless/test_wave_tabs.tcl`

Built from the shipped skeleton: the hardened `check`/`check_true`/`pcall`/
`pexpr`/`note`/`stall` set (`test_wave_markers.tcl:328-368`), `test_scratch
wvtabs`, an `AA0`-style arm-identity check from `/proc/self/cmdline`, one outer
catch with per-group inner catches, an `MZ1`/`MZ2`-style pinned expected-check
count per arm, and the exact `RESULT: ALL PASS ($npass checks)` + `exit 0|1`
footer. `full_audit.sh` auto-discovers `test_*.tcl`; it must ALSO be added to
`logdir_tests` — **no `test_wave_*` suite is there today**, so every wave suite
currently runs `--nolog` with neither a log nor a CIW, and the R6 legs would
silently assert nothing.

**Fixture discipline** (probe placement, `overnight_batch_2026_08_01/PLAN.md`):
three tabs; strips with DIFFERENT trace counts; a vec-less trace planted at a
non-zero MODEL index; a source selection spanning two strips with a
NON-ADJACENT pair; the inert `tabid` read back with `dget` so "it landed in tab
2" is witnessed independently of "the tabs got reordered".

**PURE group `TK*` (both arms)** — the tab-record freeze/thaw round trip; the
tab list add/remove and the neighbour-after-close rule; `plan_paste` in both
modes incl. empty-strip reuse and the append-not-prepend order; the colour
walk; `paste_traces_in_graphs` (grouping preserved, flattening, ranges blanked
on created strips only); a clipboard `encode`/`decode`/`valid` trio mirroring
`markers_encode`/`markers_decode`/`markers_valid`; the state-dict round trip in
BOTH compatibility directions.

**DISPLAY group `TG*`** — the real chords through the bindtag, driven by an
`ax_send_key`-shaped loop (raise, `focus -force` the toplevel THEN the widget,
gate on the RESULT predicate rather than on confirmed focus, return a value the
leg checks) and button events through a `wb_ev`-shaped monotonic `-time`
bumper; the bar appears at 2 tabs and vanishes at 1; per-tab strips survive a
switch; `tabview` restores a pan; a MULTI-trace selection on a NON-ZERO strip
survives a switch away and back; the Shared-X and Grid mirrors follow the tab;
the engine cursors follow the tab; a half-armed strip drag does not survive a
switch; paste into multi keeps separateness; paste into single flattens; `u`
undoes a whole paste; **`Ctrl-W` at one tab leaves the window up, says so in the
CIW and writes no log line** while the same key at two tabs closes one;
`File > Close Tab` is `disabled` at one tab and `normal` at two; `Ctrl-Q`
closes the window **and the process is still alive**; and every message asserted
on **both** channels — the pane via `pane_lines`, the FILE via `loglines`, with
the `test_ase_log_seam_0207` helpers — plus a `uplevel #0` replay leg (never a
fresh sub-interp, where a `wviewer::` line aborts the source).

**Sabotages — each must kill exactly its target, then revert, then green:**

| # | sabotage | must kill |
|---|---|---|
| S1 | the freeze writes the record but the thaw does not read `layout` | the per-tab-content legs |
| S2 | drop `capture_live_view_state` from `select_tab` | the selection-survives-a-switch legs — needs the multi-trace, non-zero-strip witness |
| S3 | `plan_paste`'s multi arm flattens | the separateness legs — needs ≥2 source strips AND ≥2 traces in one |
| S4 | paste front-inserts instead of appending | the order legs |
| S5 | drop the per-strip colour re-plan | the duplicate-colour leg |
| S6 | `close_tab` on the ONLY tab falls through to a window close | the D9a legs: window still up, CIW said so, no log line |
| S7 | `tabview` re-applies the OUTGOING tab's ranges | the pan-survives leg — needs two tabs with DIFFERENT windows on the same strip index |
| S8 | the switch skips the gesture-array reset | the half-armed-drag leg |
| S9 | `wviewer::echo` keeps the `::has_x` guard (the 0207 shape) | the log-FILE legs, leaving the pane legs green |

Declare the tab bar's PIXELS an explicit eyeball-only blind spot
(`pixel-deliverables-need-eyeball`). Run everything through
`tests/headless/run_suites.sh` after pressing `Allow 30m`.

---

## 13. Build order

1. the `forget`/`gridshow` one-liner (D3), on its own
2. `wviewer::echo` (D20) + the `TK*` pure legs it needs
3. the stash + freeze/thaw + `select_tab`/`new_tab`/`close_tab` (D2-D9)
4. the tab bar + the File menu (D7, D11)
5. the keys (D10, D11) + the G9 rewrite (§10.4)
6. `tabview` (D6)
7. copy/paste (D12-D18)
8. docs (§9) + the reference-doc updates

Each step builds, runs its suites green, and is committed before the next
(memory `review-commit-dont-push`).

---

## 14. Deferred, deliberately

tab rename; tab drag-to-reorder; dropping a dragged TRACE onto a tab button;
per-tab raw files; pasted traces becoming the selection (D18); tearing a tab off
into its own window; `Ctrl-X` (cut); converting the ~120 pane-only `ciw_echo`
sites to the new echo seam (0207's own deferred item 2).

---

## 15. As shipped

*(filled in at implementation; THIS SECTION IS THE AUTHORITY on every delta
from the text above.)*
