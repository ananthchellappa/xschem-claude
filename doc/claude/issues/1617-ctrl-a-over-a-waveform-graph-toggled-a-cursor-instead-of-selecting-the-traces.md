# 1617 — Ctrl-A over a waveform graph toggled a cursor instead of selecting the traces

**STAMP:** `v1 claim=fixed tree=69adfe59 stamped=2026-09-29 fix=taken open=4`

Status: **FIXED**, 2026-09-29, in `waves_callback()` plus a new `graph_sel_waves_all()`.
Measured on this tree at `69adfe59` · Branch: `fluid-editing`
Related: `doc/claude/specs/wish_list.txt` **new-list item 13** (*"WV: CTRL-A to select all
traces. Select and delete traces."*) — the select-and-delete half already shipped as issues
**0175** and **0176**; batch `doc/claude/selectall_getprop_batch/` decisions **D7**–**D11**,
**D13**–**D15**; ruling **`rule/1617`** on the user's queue; the fence is the `CA*` band of
`tests/headless/test_wave_viewer.tcl`.

## ⚠ THE CHORD WAS NOT EMPTY, AND THE DRIVER'S SCOUTING SAID IT WAS

The item was scouted as "the smallest genuine gap on the whole list — both halves already
ship, the work is one keybinding plus one proc". That was **wrong about the keybinding**.
Ctrl-A over a graph did not fall through to the schematic's select-all; it reached
`waves_callback()` and **toggled x-cursor A**. Measured on the dev display:

```
after Ctrl+a OVER GRAPH      graph_flags=2 lastsel=0
after 2nd Ctrl+a OVER GRAPH  graph_flags=0 lastsel=0
after bare 'a' OVER GRAPH    graph_flags=2 lastsel=0
after Ctrl+a OVER CANVAS     graph_flags=2 lastsel=20
```

`graph_flags` bit 2 is cursor A. The selection count never leaves 0 over the graph and goes
0 → 20 for the same chord 574 px lower.

⚠ **The scouting error came from trusting a shipped comment on the line that contradicts it.**
`src/callback.c` carries

```c
set_input_binding(DEV_KEY,'a',ControlMask,ACTX_OVER_GRAPH,"graph.forward"); /* select all */
```

— and `/* select all */` names the **canvas** meaning that this very row diverts away from.
CLAUDE.md's rule is to cite by symbol and check cross-references rather than trust them; this is
the same lesson arriving from a new direction, where the false cross-reference is a comment
sitting on the correct code. It was reproduced inside a real ASE-L viewer as row `CA4` before
the fix, so the measurement is now a fence rather than a note.

**So this issue TAKES AN OCCUPIED CHORD.** That is a user-visible price, and it is on the user's
queue as `rule/1617` rather than decided here.

## What shipped

* **`graph_sel_waves_all()`** (new, `src/draw.c`), declared in `src/xschem.h`: fills the
  selection set with every drawn trace.
* A new branch in **`waves_callback()`**, above the `key=='a' && access_cond` cursor-A toggle.
* The **`wviewer::key_filter` carve-out** for `wviewer::key_cursor_tail` — see the trap below.
* Scope is **window-wide, every strip** (decision **D8**), not the pointed strip. Two reasons
  that agree: "all" carries no strip qualifier in the user's own wish, and the shipped Delete
  path is already window-wide, so a per-strip Ctrl-A would leave *select all* and *delete the
  selection* disagreeing about what "all" covers — a mismatch discovered by destroying
  something.
* Writes only through the sanctioned writers, so **the existing Delete path consumes the result
  unchanged**. Nothing in the delete path was touched.
* **Logs nothing** (decision **D11**). The PLAN said to match the siblings on replayable
  logging and had it backwards: selection gestures are not logged in this product — only
  mutations are — so matching the siblings means logging nothing.

Implemented as a branch rather than a new registered action (**D13**), which makes two of the
three known traps inapplicable by construction: `keybindings.csv` is unchanged, so
`test_bindings_file` stays green, and `graph.forward` already declares `mutates = 0`.

## The trap that would have shipped a lying checkbutton

`wviewer::key_filter`'s tail calls `wviewer::key_cursor_tail` for keysym 97 **with no modifier
test**. So once C stopped toggling cursor A, the tail still flipped the `cva` mirror and the
**Cursors ▸ Cursor A checkbutton desynced on every Ctrl-A** — the feature working while the menu
lied about cursor state. Fixed with a carve-out shaped like the existing one for 98/100.

Sabotaging the carve-out away reddens `CA4` to `{1 0}` — mirror ON, engine OFF — plus `CA5`×2
and `CA7`, and ⚠ **no selection row moves at all**, which is exactly why the row exists.

## Red first

* First run of the band against the unfixed tree: **`11 FAILED (420 passed)`** — every row
  FAILED, none threw. `CA1 … -> {} (exp {0 1})`; `CA2 strip 0 wrote BOTH tokens -> {-1 {}}`;
  `CA3 selection_pairs … -> {}`; `CA4 … -> {1 1} (exp {0 0})`.
* After adding `CA9` and a `CA7` reset, both halves of the fix were re-reverted for a definitive
  red: **`13 FAILED (424 passed)`**.
* Suite baseline before any edit: **`ALL PASS (407 checks)`**. After: **`ALL PASS (437
  checks)`**, +30 rows. Binary md5 identical before and after the measuring run.

`run_regression.tcl` is untouched — the suite is already in `dcases` and already prints
`OVERALL: ok` (issue 1616 put it there), so no case count and no `skip:` figure moves.

## ⚠ A SABOTAGE SURVIVED, AND THE HAZARD WAS DELETED RATHER THAN A ROW INVENTED

Removing the 64-entry cap left the suite at **`ALL PASS (431)`** — **not caught by anything.**

The reason matters more than the result: `graph_sel_waves_set` clamps as well, so the
behavioural row `CA8` still read 64 while `sel[k] = k` wrote **one int past the end of a stack
array**. A memory error downstream of a clamp is invisible to every behavioural assertion that
*can* be written, because the observable answer stays correct.

No row was invented to look like a fence. **The hazard was removed**: `ndraw` and `n` are now
separate, and `n = ndraw < cap ? ndraw : cap` applies the bound in one undeletable expression
with `cap` derived as `sizeof(sel)/sizeof(sel[0])` rather than restated.

And the honest sentence, which is the deliverable here: **the cap's *behaviour* is fenced by
`CA8`; its *memory safety* is fenced by the shape of the code and by nothing else.** CLAUDE.md
warns that a fence keyed to a symptom dies quietly when something else cures the symptom — this
is that lesson one level deeper, where the symptom is cured by a clamp the fence cannot see past.

## Sabotages that were caught

| sabotage | result | caught by |
|---|---|---|
| per-strip instead of window-wide | 4 FAILED | `CA1` (other strip), `CA2`, **`CA3`** — the Delete path would have missed strip 1 | 
| `hilight_wave` written, `sel_waves` forgotten | 5 FAILED | `CA1`, `CA2`, `CA3`, `CA6`, `CA8` |
| `key_cursor_tail` carve-out omitted | 4 FAILED | `CA4` → `{1 0}`, `CA5`×2, `CA7` — and no selection row moved |
| `mutates = 1` / behind `readonly_block()` | 9 FAILED | incl. two modal-count rows, `{1}` exp `{0}` and `{3}` exp `{2}` |

## Also settled

* **Recon's one open question is answered.** Row `CA0` proves the chord reaches `key_filter` as
  Ctrl+keysym-97 and that **nothing binds `<Control-Key-a>`** on any bindtag of the canvas or the
  toplevel, measured in a really-open viewer rather than derived from a grep.
* **Out-of-scope invariants confirmed unchanged by probe:** bare-canvas Ctrl+A still selects 20,
  `xschem select_all` still 20.
* **D9's declared price is fenced in the direction it was declared.** Row `CA9` proves Ctrl-A
  selects in the `graph_use_ctrl_key 1` profile *and* that cursor A stays put there.
* Siblings green: `test_wave_hilight` 196, `test_wave_modes` 488, `test_wave_axis_zoom` 370,
  `test_wave_cursor_crossdb` 93, `test_key_graph_context`, `test_bindings_file`.

## Still open (open=4)

1. **The ruling `rule/1617` is unanswered**, and it is one conversation in three parts: the
   cursor-A price in the `graph_use_ctrl_key 1` profile; whether Ctrl-A should appear in
   Help ▸ Keys and get a Graph ▸ Select All Traces entry; and whether covering embedded graphs
   is wanted. They were filed together rather than as three rounds because the answers interact.
2. **Ctrl-A appears nowhere in the generated keybindings help**, because
   `generate_keybindings_text` skips `graph.forward` as context plumbing. Nothing got *worse* —
   the old cursor-A meaning was not listed either — but the user's own requested feature is
   undiscoverable. Part of the ruling above.
3. **Migrating to a registered action id** (recon's seam (a)) is a clean follow-on; the `CA` band
   keeps passing across it, and the `readonly_block` rows are already in place for it.
4. **The 5-px band-edge inset** remains the one place where Ctrl-A reaches `select_all()` and
   selects graph rects, because `waves_selected` declines there. Pre-existing, recorded as
   known-and-cosmetic under issue **0149**, and deliberately out of this issue's scope.
