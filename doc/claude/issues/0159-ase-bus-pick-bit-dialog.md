# 0159 — an ASE bus pick emitted one invalid vector; now it opens a bit-selection dialog

Status: **FIXED** (2026-07-26)
Area: `src/ase_window.tcl` (`sod_bits`, `sod_pick_tokens`, the `bus_dialog*` family, `sod_click`),
`src/ase.tcl` (`bus_expr_bits`, `expand_bus_outputs`, `state_load`)
Tests: `tests/headless/test_ase_bus_bits_0159.tcl` — `BB1`-`BB35` (22 headless / 39 with a DISPLAY,
new file)
Spec: `doc/claude/specs/ase_l.md`, "Select On Design v1 scope" — the bus paragraph is new
Related: 0154 (the audit that surfaced it — "Not fixed" item 6), 0153 (the schematic colour cue),
0157/0158 (the `resolved_net` defects from the same audit)

## Report

From the 0154 backlog:

> **A BUS pick still emits an invalid single vector.** `sod_expr voltage {A[1:0]}` → `v(a[1:0])`
> … It has the same `.save`-card hazard as root cause B did.

Reproduced at 00e591b8 in both arms. Two bus shapes reach the picker, not one:

```
click a wire labelled A[1:0]  ->  flylines net {A[1:0]}  ->  sod_expr -> v(a[1:0])
click a wire labelled D,E     ->  flylines net {D,E}     ->  sod_expr -> v(d,e)
```

`src/ase.tcl:911/:931` interpolate that string verbatim into `.save <expr>` and `print <expr>`.

## What ngspice actually does — the report's severity was half right

Measured directly, ngspice-42 on this box:

| deck | result |
|---|---|
| `.save v(a[1:0])` **alone** | `Error: no data saved for Transient analysis; analysis not run` — **the whole run dies**, no raw written |
| `.save v(a1)` + `.save v(a[1:0])` | **runs fine**; the bad token is silently dropped, raw contains only `v(a1)` |
| `.save all` + `.save v(a[1:0])` + `print v(a[1:0])` | runs; only `Warning from checkvalid: vector a[1:0] is not available or has zero length` |
| `.save v(d,e)` (the comma form) | **never** aborts — ngspice accepts it and saves `v(d)` and `v(e)` |

So "killing every other trace in the session" is true **only when the bus is the sole pick**. In
the ordinary case it is a silently missing trace, which is the harder failure to notice. And the
comma form is not dangerous at all — a distinction that decides the migration rule below.

## Fix — a bit-selection dialog (user decision)

Refusing the pick and fanning it out silently were both on the table; the user chose a third
option, which is the only one that lets the user say *which* bits and *in what order*:

- **`ase::ui::sod_bits {token}`** — pure split of a token into bits via `xschem expandlabel`.
  `A[1:0]` → `{A[1] A[0]}`, `D,E` → `{D E}`, `A[1:0],B` → `{A[1] A[0] B}`, a scalar → itself.
  Verified that `xschem expandlabel` works with **no design loaded**, so `sod_expr`'s purity
  contract (test_ase_interact H1) survives — unlike `xschem resolved_net`, which runs
  `prepare_netlist_structs`.
- **`ase::ui::sod_pick_tokens {key kind token}`** — the seam `sod_click` routes through: a scalar
  or any `current` pick (an instance name, never a bus) returns itself; a multi-bit net opens the
  dialog. Being a seam is what lets a test stub `ase::ui::bus_dialog` and assert the queue set
  without driving Tk.
- **`Select Bus Bits`** (`bus_dialog_build` / `_selected` / `_all` / `_reverse` / `_done` /
  `bus_dialog`) — a listbox in `expandlabel` order. **Nothing selected on open** (so OK with an
  empty selection is a no-op, same as Cancel); **All** selects every bit; **Ctrl-click** toggles
  (Tk `extended`, which also gives Shift-click ranges); **Reverse** flips the displayed order
  *carrying the selection with the items*; **OK** returns the selection in display order;
  **Cancel** returns nothing. Display order is queue order — that is what makes Reverse mean
  anything.
- **`sod_click`** loops over the returned tokens, queueing one row per bit, on **both** paths —
  Direct Plot (`dp_queue`) and the persisted Outputs list (`sod_queue`). The 0153 colour cue is
  painted **once**, for the first bit: the bus is one wire, so N cues would repaint it N times and
  settle on the last bit's colour.

Modal wrapper follows the `ask_save_close` precedent in the same file: build with deterministic
widget paths, `update`, `raise`, `grab`, and a `tkwait` guarded against the window having already
been destroyed during the build-time `update`.

### Legacy saved states

`ase::state_load` now expands a stored `v(a[1:0])` row into per-bit rows, keeping the row's other
fields and its position in the list (user decision: expand on load rather than leave or only guard
the deck writer).

That migration is deliberately **narrower** than the pick-side split, because a stored expr is
*opaque* where a picked token is known to be a net:

- only a bare `v(<label>)` is a candidate, so `v(a)-v(b)`, RPN rows, anything with an operator or a
  nested paren is never rewritten;
- **the label must carry an explicit `[n:m]` range.** The comma form is left alone even though a
  comma-bus pick produces it, because `v(a,b)` is *also* ngspice's differential voltage and
  `print v(a,b)` is a real thing a user can have typed into the Add-Output dialog — expanding it
  would silently destroy their row. Giving that up costs nothing measurable: `.save v(d,e)` does
  not abort a run.

## Test

`tests/headless/test_ase_bus_bits_0159.tcl`. 22 checks headless, 39 with a DISPLAY (the dialog and
the real-click groups self-SKIP without one).

- `BB1`-`BB7` — `sod_bits`, run with **no design loaded** to pin the purity contract.
- `BB8`-`BB14` — `state_load` migration: bracket bus expands and keeps its flags; hierarchical
  `v(x1.a[1:0])` expands; scalars, currents, derived expressions and the **comma** form are all
  left alone; a mixed list keeps its order.
- `BB15`-`BB20b` — `sod_pick_tokens` with the dialog stubbed: subset, order, Cancel, and the two
  controls where the dialog must not be consulted at all.
- `BB21`-`BB28` — the real Tk dialog: empty initial selection, bit order, All, Reverse (order flips
  AND selection survives), OK order, Cancel.
- `BB29`-`BB33` — the real `sod_click` on a real bus wire, with `dp_queue`/`sod_queue` stubbed:
  one row per bit on both modes, the single colour cue, Cancel queueing nothing, and a scalar click
  still queueing exactly one row.
- `BB34`-`BB35` — the REAL modal `bus_dialog` (`update`+`grab`+`tkwait`), driven by an `after`
  timer that presses the buttons while it is blocked, with a deadman `after` so it can never hang
  the suite; asserts the returned bits, that no grab or window is left behind, and Cancel.

### Verified

- RED first: the file fails at `invalid command name "ase::ui::sod_bits"` before the change;
  22/22 headless and 39/39 with a DISPLAY after.
- **Nine sabotages, each red on a different leg group** — and note the first attempt at these was a
  false green: `perl -0pi -e 's/\Q…$exp…\E/…/'` interpolates `$exp` to empty, so four "sabotages"
  silently patched nothing and the suite passed. Re-run with a pattern-found assertion:
  1. `sod_bits` never splits → 14 red;
  2. drop the `state_load` migration → `BB8` red;
  3. `bus_dialog_selected` returns sorted instead of display order → `BB27` red;
  4. dialog opens with everything selected → `BB23` red;
  5. `sod_click` queues only the first token → `BB29`/`BB30`/`BB31` red;
  6. `Reverse` drops the selection → `BB26`/`BB27` red;
  7. drop the bracket-only guard in `bus_expr_bits` → `BB10` red (`v(d,e)` wrongly expanded);
  8. the hand-rolled reverse loop appends instead of prepending → `BB25`/`BB27` red;
  9. the modal wrapper discards its result → `BB34` red; and `sod_click` ignoring Cancel →
     `BB32` red.
- Green after the change: `test_ase_unnamed_net` (28), `test_ase_interact` (63), `test_ase_plot`
  (145), `test_wave_viewer` (292), `test_wave_modes` (174), `test_ase_window` (166),
  `test_ase_dialogs` (133), `test_ase_persist` (109), `test_ase_core` (66), `test_ase_final` (28),
  `test_ase_final_gf180` (33), plus `test_prep_result_contamination_0155` (12),
  `test_hash_label_crash_0156` (23), `test_resolved_net_bus_global_0157` (19) and
  `test_resolved_net_hash_bus_0158` (21).

### NOT verified

- No end-to-end run through **real ngspice** with a fanned-out bus: the deck-level behavior was
  measured with hand-written decks (the table above), not by driving an ASE session to a run.
- The dialog has not been eyeballed — only driven programmatically. Layout, theming under
  `apply_theme`, and how a very wide bus (>16 bits, where the listbox scrolls) looks are unchecked.
- `full_audit.sh` classifies the new file as PASS with 0 leaked scratch dirs.
- `dp_finish`'s downstream handling of N traces from one click is exercised only through the
  stubbed `dp_queue`; the viewer side is unchanged but untested for this path.
- No FULL `full_audit.sh` sweep for this change (only the new file was run through it).
