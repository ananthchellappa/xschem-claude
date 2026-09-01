# Cadence-style key bindings — plan

Status: **PLAN / for review**. No files changed yet. Target branch: `fluid-editing`.

## Goal

Add six Cadence-flavoured keyboard shortcuts, driven entirely from Tcl loaded via
`--rcfile` / `--script` (the user runs `src/xschem --script src/cadence_style_rc`).
**No C code is touched.**

| Key | Action |
|-----|--------|
| `Ctrl-Alt-S` | `locate_selected_in_libmgr` — show the selected instance in the Library Manager |
| `Ctrl-Alt-N` | `place_libmgr_selection` — place the current Library-Manager selection |
| `Ctrl-Shift-N` | Open the **schematic** of the selected instance in a **new window, read-only** — always a fresh window, even if that schematic is already open |
| `Ctrl-X` | If an instance is selected, **descend** into its schematic; else no-op |
| `Alt-E` | **Return to top** of hierarchy (warn/stop if edits would be lost) and **remember** the location we came from (per window, as an instance-name list a Tcl proc can reuse) |
| `Alt-X` | **Descend back** into the location remembered by the last `Alt-E` for this window |

---

## 1. Conflict analysis

Two dispatch layers can claim a key:

* **Tk layer** — `bind $topwin <KeyPress> "… xschem callback …"` (`src/xschem.tcl:10906`)
  forwards every key to C. A *more specific* Tk binding pre-empts it; the existing
  `bind $topwin <Control-Shift-Key-P>` (command palette, `xschem.tcl:10911`) and the
  rc's own `bind .drw <Key-i> {xschem create_instance; break}` (`src/cadence_style_rc`,
  last line) are the precedents we follow.
* **C input-binding table** (`xschem bind`, `src/callback.c:2727+`, `src/scheduler.c:565`)
  plus the legacy keysym `switch` in `handle_key_press()` (`src/callback.c:3557+`).

What is already bound on each requested chord. The C dispatcher uses two idioms that
are easy to miss when grepping: `SET_MODMASK` = `(rstate & Mod1Mask)||(rstate & Mod4Mask)`
(Alt **or** Super, possibly with Ctrl) and `EQUAL_MODMASK` = `(rstate==Mod1Mask)||
(rstate==Mod4Mask)` (Alt/Super **only**). `rstate` is `state` with Shift stripped, so a
Shift chord on a letter arrives as the **uppercase** keysym with `rstate==ControlMask`.

| Chord | Currently | Verdict |
|-------|-----------|---------|
| `Ctrl-Alt-S` | C: **Save as Symbol** (`callback.c:4398` case `'s'`, `SET_MODMASK && (state&ControlMask)` → `saveas(NULL,SYMBOL)`; menu File ▸ Save as Symbol) | **stolen** → rehome |
| `Ctrl-Alt-N` | nothing — `case 'n'` is fully migrated to the input-binding table with only `n`/`Ctrl-n` rows; no `Ctrl-Alt` row | **free** |
| `Ctrl-Shift-N` | C: **Clear symbol** (`callback.c:4175` case `'N'`, `rstate==ControlMask` → `xschem clear symbol`) | **stolen** → rehome |
| `Ctrl-X` | C: **cut selection** (`callback.c:4615` case `'x'`, `rstate==ControlMask` → `save_selection(2); delete()`; Tcl `xschem cut`) | **stolen** → rehome |
| `Alt-E` | C: **edit schematic in new window** (`callback.c:3813` case `'e'`, `EQUAL_MODMASK` → `open_sub_schematic`) | **stolen** → rehome |
| `Alt-X` | C: **toggle draw crosshair** (`callback.c:4607` case `'x'`, `EQUAL_MODMASK`) | **stolen** → rehome |

**5 of the 6 chords are already bound; only `Ctrl-Alt-N` is free.** This does **not**
change the approach: every binding sits on `.drw` and ends in `break`, so it fires
*before* the generic `<KeyPress>` forwarder reaches C — all six chords are captured for
our actions regardless of what C had. The cost is five displaced commands (§6).

Notes:
* Plain `x` (= "new cad session"), plain `s`/`n`, `Ctrl-s`, and `Alt/Super-only` variants
  are **not** disturbed — we only bind the specific chords listed above.
* The C input-binding table's existing rows for `n` (`toolbar.netlist`), `Ctrl-n`
  (`file.clear_schematic`), `Ctrl-s`-over-graph (`graph.forward`) do **not** collide —
  none of our chords are plain `n`/`Ctrl-n`/`Ctrl-s`.
* Because our Tk bindings sit on `.drw` and end in `break`, the event never reaches the
  generic `<KeyPress>` forwarder, so neither the C keysym `switch` nor the C input table
  ever sees these chords. No double-fire.

**Conclusion: zero C changes required.** Pure Tk `bind` + small Tcl procs.

---

## 2. Binding mechanism

Follow the established rc precedent exactly:

```tcl
bind .drw <Control-Key-x> {cadence::descend_into_inst; break}
```

* Bind on **`.drw`** (the canvas), not the toplevel — same as the `Key-i` line already in
  `cadence_style_rc`. A widget-level binding runs before the toplevel `<KeyPress>` tag;
  `break` stops propagation so the C dispatcher is bypassed.
* Letter keysyms: lowercase with `Control`/`Alt` (`<Control-Key-x>`, `<Alt-Key-e>`),
  **uppercase** when `Shift` is in the chord (`<Control-Shift-Key-N>`), matching the
  command-palette precedent `<Control-Shift-Key-P>`.

Multi-window note: the rc binds only `.drw` (main window). Tab/extra windows
(`.x1.drw`, …) would need the same binds re-applied; out of scope for the primary
single-window Cadence flow (see *Limitations*).

---

## 3. Tcl procs

Two procs already exist in `utils/lib_mgr_helpers.tcl`
(`locate_selected_in_libmgr`, `place_libmgr_selection`) — unchanged.

New file **`utils/cadence_nav.tcl`** (hierarchy navigation):

```tcl
# Cadence-style hierarchy navigation helpers for XSchem.
# Loaded from cadence_style_rc. Pure Tcl, no C changes. See
# doc/claude/specs/cadence_bindkey_plan.md.

namespace eval cadence {
  variable last_loc       ;# per-window: last_loc(<win_path>) = {inst1 inst2 ...}
  array set last_loc {}
}

# --- helpers --------------------------------------------------------------

# 1 iff exactly one instance (ELEMENT == type 8) is selected.
proc cadence::one_instance_selected {} {
  if {[xschem get lastsel] != 1} { return 0 }
  lassign [xschem get first_sel] type n col   ;# "type n col"
  return [expr {$type == 8}]
}

# Current location as a list of instance names, top -> here.
# sch_path looks like ".Xamp.Xstage1." ; top level is ".".
proc cadence::hier_instnames {} {
  set names {}
  foreach c [split [xschem get sch_path] .] {
    if {$c ne ""} { lappend names $c }
  }
  return $names
}

# Walk up to the top. `go_back 1` asks to save when a level is modified; if the
# user cancels, currsch stops decreasing and we abort. 1 = reached top, 0 = stopped.
proc cadence::ascend_to_top {} {
  while {[xschem get currsch] > 0} {
    set before [xschem get currsch]
    xschem go_back 1
    if {[xschem get currsch] >= $before} { return 0 }
  }
  return 1
}

# --- actions --------------------------------------------------------------

# Ctrl-Shift-N: schematic of selected instance, new window, read-only, always fresh.
proc cadence::open_inst_sch_readonly {} {
  if {![cadence::one_instance_selected]} {
    ciw_echo "select one instance to open its schematic (read-only)" error ; return
  }
  # 'force' => new window/tab even if that schematic is already loaded.
  if {[xschem schematic_in_new_window force] == 0} {
    ciw_echo "selected instance has no schematic view" error ; return
  }
  xschem set readonly 1   ;# new window is now the current context
  ciw_echo "opened [xschem get schname] (read-only) in [xschem get current_win_path]"
}

# Ctrl-X: descend into selected instance's schematic; no-op if no instance selected.
proc cadence::descend_into_inst {} {
  if {![cadence::one_instance_selected]} { return }
  xschem descend
}

# Alt-E: return to top (with save warnings) and remember where we were.
proc cadence::return_to_top {} {
  set win [xschem get current_win_path]
  set loc [cadence::hier_instnames]
  if {[llength $loc] == 0} { ciw_echo "already at top level" error ; return }
  if {![cadence::ascend_to_top]} {
    ciw_echo "return-to-top stopped at [xschem get sch_path] (unsaved edits)" error
    return
  }
  set cadence::last_loc($win) $loc
  ciw_echo "at top; remembered: $loc  (Alt-X to return)"
}

# Alt-X: descend back into the location remembered by the last Alt-E for this window.
proc cadence::descend_to_last {} {
  set win [xschem get current_win_path]
  if {![info exists cadence::last_loc($win)] || $cadence::last_loc($win) eq ""} {
    ciw_echo "no remembered location for this window (use Alt-E first)" error ; return
  }
  set loc $cadence::last_loc($win)
  if {![cadence::ascend_to_top]} {
    ciw_echo "cannot return to top to begin descent" error ; return
  }
  foreach name $loc {
    xschem unselect_all
    if {[xschem select instance $name] == 0} {
      ciw_echo "instance '$name' not found while descending to $loc" error ; return
    }
    if {[xschem descend] == 0} {
      ciw_echo "cannot descend into '$name'" error ; return
    }
  }
  ciw_echo "descended back to: $loc"
}
```

### Commands these rely on (all verified to exist on `fluid-editing`)

| Command | Source | Use |
|---------|--------|-----|
| `xschem get lastsel` | `scheduler.c:1764` | count selected objects |
| `xschem get first_sel` → `"type n col"` | `scheduler.c:1698` | type 8 == `ELEMENT` (`xschem.h:268`) |
| `xschem get sch_path` → `".Xamp.Xstage1."` | `scheduler.c:1962`, top = `"."` (`xinit.c:637`) | hierarchy as names |
| `xschem get currsch` | `scheduler.c` | 0 == top |
| `xschem go_back 1` | `scheduler.c:2575` (`actions.c:2710`) | up one level, bit0 = confirm-save if modified |
| `xschem schematic_in_new_window force` → 1/0 | `scheduler.c:6243` | open sel. inst schematic in new window |
| `xschem set readonly 1` / `xschem get readonly` | `scheduler.c:6751` / `:1894` | lock window |
| `xschem descend` → 1/0 | `scheduler.c:1039` | descend into selected instance |
| `xschem select instance <name>` → 1/0 | `scheduler.c:6324` (`get_instance`) | select by instance name |
| `xschem unselect_all` | `scheduler.c:7897` | clear selection |
| `xschem get current_win_path` / `schname` | `scheduler.c` | window key / title |
| `ciw_echo <msg> [error]` | `src/ciw.tcl:95` | status feedback (per CIW-feedback memory) |

---

## 4. Loading from `cadence_style_rc`

Append to `src/cadence_style_rc`. Path is resolved relative to the rc file itself
(`info script`) so it works regardless of the launch cwd:

```tcl
# --- Cadence helper procs (utils/) ---
set _ut [file join [file dirname [file normalize [info script]]] .. utils]
source [file join $_ut lib_mgr_helpers.tcl]
source [file join $_ut cadence_nav.tcl]
unset _ut
```

---

## 5. Bind commands (the six shortcuts)

```tcl
bind .drw <Control-Alt-Key-s>   {locate_selected_in_libmgr;    break}
bind .drw <Control-Alt-Key-n>   {place_libmgr_selection;       break}
bind .drw <Control-Shift-Key-N> {cadence::open_inst_sch_readonly; break}
bind .drw <Control-Key-x>       {cadence::descend_into_inst;   break}
bind .drw <Alt-Key-e>           {cadence::return_to_top;       break}
bind .drw <Alt-Key-x>           {cadence::descend_to_last;     break}
```

---

## 6. Rebind commands for the five displaced actions

Five commands lose their keyboard home. Each stays reachable from its **menu** —
rebinding to a key is optional. Suggested replacement chords below were each checked
against the C `switch`/binding-table and are **free** (Ctrl-Shift-X is *not* free — it is
`create_plot_cmd`; Ctrl-Shift-K is *not* free — it is a hilight action — both avoided):

| Displaced | Tcl command | Menu | Suggested new chord (verified free) |
|-----------|-------------|------|-------------------------------------|
| Cut | `xschem cut` | Edit ▸ Cut | `Alt-Shift-X` (`case 'X'` has no Alt branch) |
| Edit schematic in new window | `open_sub_schematic` | — | `Ctrl-Shift-E` (`case 'E'` only handles Alt) |
| Save as Symbol | `xschem saveas {} symbol` | File ▸ Save as Symbol | `Ctrl-Alt-Shift-S` (or leave on menu) |
| Clear symbol | `xschem clear symbol` | Symbol ▸ Clear symbol | leave on menu (destructive) |
| Toggle crosshair | toggle `draw_crosshair` | Options ▸ Crosshair ▸ Draw crosshair | leave on menu (it is a checkbutton) |

```tcl
# Cut (was Ctrl-X)
bind .drw <Alt-Shift-Key-X> {xschem cut; break}

# Edit schematic in a NEW window (was Alt-E)
bind .drw <Control-Shift-Key-E> {open_sub_schematic; break}

# Save as Symbol (was Ctrl-Alt-S) -- optional; otherwise use File menu
bind .drw <Control-Alt-Shift-Key-S> {xschem saveas {} symbol; break}

# Clear symbol (was Ctrl-Shift-N) and Toggle crosshair (was Alt-X):
# left on their menus by default. If a key is wanted, e.g.:
#   bind .drw <Alt-Shift-Key-C> {xschem clear symbol; break}
#   bind .drw {<Alt-Shift-Key-Z>} {global draw_crosshair
#       set draw_crosshair [expr {!$draw_crosshair}]; xschem draw; break}
```

The menu `-accelerator` labels (`Ctrl+X`, `Alt-X`, `Ctrl+Alt+S`, …) become cosmetically
stale; optionally refresh them in `xschem.tcl` (labels only, no behaviour) — deferred.

---

## 7. Limitations / open questions (review these)

1. **Vector instances.** `hier_instnames` derives names from `sch_path`. If a level was
   entered as the *k*-th instance of a vector (`xschem descend k`), the re-descent in
   `descend_to_last` selects by base name and descends the default instance — it does not
   replay the vector index. Acceptable for scalar hierarchies; flag if vectors matter.
2. **Multi-window.** Binds target `.drw` only. Extra tabs/windows (`.x1.drw`) would need the
   same binds applied on creation (no per-window hook today). `last_loc` is already keyed by
   `current_win_path`, so the data model is ready; only the bind application is missing.
3. **Cancel detection on ascend** uses the "currsch didn't decrease" heuristic rather than a
   return code from `go_back` (which doesn't report cancel). Robust in practice; note if a
   crisper signal is wanted.
4. **Read-only window** is set via `xschem set readonly 1` (a soft flag the save path honors);
   it is not OS file-permission enforcement. Matches how XSchem models read-only elsewhere.
5. **Stolen-key accelerator labels** in the menus are left stale unless we also edit
   `xschem.tcl` (cosmetic).

---

## 8. Implementation checklist (after review)

- [ ] Create `utils/cadence_nav.tcl` with the §3 procs.
- [ ] Append §4 `source` block + §5 + §6 bind blocks to `src/cadence_style_rc`.
- [ ] Smoke test in the user's mode: `src/xschem --script src/cadence_style_rc --logdir /tmp`.
  - [ ] Each of the six chords fires its action; status line shows the `ciw_echo` text.
  - [ ] `Ctrl-X` with nothing selected is a true no-op.
  - [ ] `Alt-E` from depth ≥1 returns to top and remembers; `Alt-X` dives back to the same
        leaf; mid-descent failures report via `ciw_echo`.
  - [ ] `Ctrl-Shift-N` opens a second window on the same instance's schematic, read-only
        (title shows read-only; edits rejected).
  - [ ] Displaced commands still reachable: Cut (new chord), edit-in-new-window (new
        chord), Save as Symbol / Clear symbol / crosshair (menus, or new chords if bound).
- [ ] Optional: refresh menu `-accelerator` labels in `xschem.tcl`.
```

---

## 9. Addendum, 2026-08-15 — `Ctrl-Y` = descend into the selected instance's SYMBOL

Added by crew item **D11** ([issue 0410](../issues/0410-descend-into-symbol-has-no-key-in-cadence-mode.md)).
The chord inventory above predates it and the "verified free" table has no
descend-into-symbol row; this section is that row.

```tcl
bind .drw <Control-Key-y>       {xschem descend_symbol;           break}
```

**Why the chord had to exist.** §1's precedent — `bind .drw <Key-i> {xschem create_instance;
break}` — has a cost the plan never priced: the `break` stops the event reaching the generic
`<KeyPress>` → C dispatcher, and that dispatcher (`callback.c` case `'i'`) is the **only** key
route to descend-into-symbol. So cadence mode left that verb with **no key at all** — menu,
toolbar, right-click and the `e` chooser only. `i` cannot be given back (cadence mode needs it
for Create Instance) and Shift-`i` is not a fallback (`case 'I'` is insert-symbol).

| Chord | Currently | Verdict |
|-------|-----------|---------|
| `Ctrl-Y` | Tk: nothing (`bind .drw <Control-Key-y>` and `<Control-Key-Y>` empty before *and* after the rc, and in all three PDK rc copies). C `switch`: `case 'y'` migrated out (`callback.c:8112`). C binding table: the sole `y` row is `key 121 0 canvas edit.toggle_stretch`, modifier 0, **no ctrl variant**. Tree-wide grep of `src/` + `utils/`: one hit, `utils/toggle_pins_netlabels.tcl:57`, a **commented-out** suggestion for the different chord `<Control-Shift-Key-Y>`. | **free** |

Cadence's own default for descend-into-symbol with an instance selected is Ctrl-Y, which is why
that chord and not another.

**It calls the bare verb, not a `cadence::` proc** — unlike every other member of the hierarchy
family. `xschem descend_symbol` already refuses out loud (returns 0, `descend_error` =
`no-selection`, statusmsg `Descend symbol: select an instance to descend into` — the issue-0251
channel), while `cadence::descend_into_inst`'s gate is silent; and that gate accepts a strictly
smaller set than the core (measured: instance + wire selected → the core descends, the gate
refuses), so wrapping would add a silent refusal on a selection the core handles. See 0410 for
the full decision and its rejected alternatives.

**Known asymmetry:** `descend_readonly` (§ `descend_readonly.md`) is applied in
`descend_schematic()` only, so in browse mode Ctrl-Y opens the `.sym` editable while Ctrl-X opens
a child schematic read-only. Pre-existing, shared with the Edit menu / toolbar / right-click;
filed as [0412](../issues/0412-descend-symbol-ignores-descend-readonly.md).

Covered by `tests/headless/test_cadence_descend_newwin_ro.tcl` (CY1–CY10, true headless) and
`tests/headless/test_altf5_ciw.tcl` (CYT1–CYT3, live Tk).

---

## 10. Addendum, 2026-08-19 — the displaced `Ctrl-<digit>` layer chords

The C default is **`Ctrl-<digit>` = select drawing layer `<digit>`**
(`callback.c:7272`; the shared `case '6'..'9'` body acts **only** when
`state == ControlMask`, so a *plain* digit and an *Alt* digit displace nothing).
Three of those chords are now taken by the cadence profile, each overridden the
same way — a `.drw` bind whose body ends in **`break`**, which is what stops the
event reaching the C layer-select:

| Chord | Now does | Bound at | Displaced verb still reachable as |
|-------|----------|----------|-----------------------------------|
| `Ctrl-2` | ASE plot mode | `src/cadence_style_rc:252` | Layers menu; `xschem set rectcolor 2` |
| `Ctrl-4` | `ase::direct_plot_for_current` | `src/cadence_style_rc:264` | Layers menu; `xschem set rectcolor 4` |
| `Ctrl-6` | `cadence::annot_mode none` (OP annotation OFF) | `src/cadence_style_rc` (S8) | Layers menu; `xschem set rectcolor 6` |

**No layer-select verb is lost** — only its shortcut. `create_layers_menu` still
lists every layer, and `xschem set rectcolor N` is the scriptable form.

Two things worth knowing before adding a fourth:

* **Tk matches a modifier *subset*.** Binding only `<Key-N>` makes `Ctrl-N` and
  `Alt-N` fire it too. S8 measured this the hard way: with `<Control-Key-6>`
  mis-spelled, `Ctrl-6` fell into the plain binding and the OFF key silently
  meant ON. Spell out every chord you intend, and assert all of them in a test —
  `Ctrl+Alt+N` falls into the `Alt` form, and `Shift-N` matches nothing
  (the keysym is punctuation, e.g. `asciicircum` for Shift-6).
* **These binds are invisible to `xschem bindings dump` and to
  `keybindings.csv`**, so they cannot be remapped the way registered C actions
  can — remapping means editing the rc line. That was the stated reason `Ctrl-5`
  was moved into the C action registry (`src/cadence_style_rc:280-291`); whether
  the S8 chords should follow it is the open question in
  [0457](../issues/0457-annot-show-has-no-stock-affordance.md).

The three OP-annotation chords are specified in
[`op_annotation.md` §4.6](op_annotation.md); their body is `utils/annot_mode.tcl`.
