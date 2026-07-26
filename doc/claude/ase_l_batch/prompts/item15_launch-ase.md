# Item 15 — launch-ase (IMPLEMENTER PROMPT)

Repo: `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
ASE-L mini-batch, ROUND 4, item 15. Read the spec `doc/claude/specs/ase_l.md`
(state schema; UI v2 "Menu tree", "Window chrome"; view creation item-02) and
`doc/claude/ase_l_batch/receipts/02_view-dispatch.md` (seeding contract) before
coding. This prompt is the authoritative contract; the scout has re-verified
every anchor from source (2026-07-21) and resolved every micro-decision below.

## Goal (user ask)

A hosted technology (sky130A / gf180mcuD) gets a DEFAULT MODEL setup that ASE
loads by default; a schematic window gets **Tools > Launch ASE-L** that opens a
FRESH minimal ASE-L session (empty vars/analyses/outputs, but the tech default
model already in place) bound to the current schematic — exactly like Cadence
**Tools > ADE-L**. Launching twice on the same design RAISES the existing
session instead of duplicating it.

Pure Tcl. NO C changes. NO generated-file edits.

---

## Corrected / verified anchors (current line numbers, 2026-07-21)

The PLAN sketch had two stale/typo'd anchors — corrected here:

- `src/ase.tcl`
  - namespace block `namespace eval ase {` line 23; `variable sessions` :39,
    `variable session_notify` :44 — add the new `variable untitled_view` here.
  - `set_ne ase_eng_notation 1` at **:77** — the set_ne pattern to MIRROR for
    `ASE_DEFAULT_MODELS`.
  - `proc ase::state_default` at **:116**; the `models {}` default line is
    **:123** (`    models    {} \`).
  - model render `.lib` at **:642-643** (inside `render_deck`; uses
    `ase::expand_path` + `dict get $m file`/`section`).
  - `proc ase::session_key` **:460**, `proc ase::session_open` **:478**
    (loads a file — `new_session` is the blank counterpart), `session_getattr`
    **:572**, `proc ase::open_state {lib cell view {ro 0}}` **:594** (the Tk
    carve-out precedent: window work guarded by `[info exists ::has_x]`,
    delegates to `ase::ui::*`).
- `src/library_defs.tcl`
  - `proc schematic_cellview {abspath}` at **:317** — **REUSE THIS**. Returns
    `{lib cell view layout}` (nested) or `{lib cell {} flat}` or `{}`; pure
    path/string work, headless-safe, longest-matching library root wins, does
    NOT require the file to exist. This IS the path→design reverse resolver
    deliverable-2 asks for.
  - `proc library_new_view` **:703**; the ngspice_state* SEED at **:711-718**
    already calls `ase::state_default` — so item-02 newview seeding
    auto-inherits the new default models with NO edit to this file.
- `src/ase_window.tcl`
  - `proc ase::ui::window_for` **:189**, `proc ase::ui::open {key lib cell view}`
    **:198** (allocates the window number via `xschem allocate_window_number`
    :200; sets `meta($key)={lib cell view}` :205; only place a number is
    consumed), `populate` **:762**, `save_state_dialog` **:2258** (View prefill
    `$ve insert 0 $mview` at **:2274**), `refresh_title` **:2461** (title
    `Analog Sim Environment <cell>` + ` *` when dirty, :2466-2468),
    `refresh_status` **:2473** (`State: $view` from meta, :2483),
    `session_changed` **:2503**.
- `src/xschem.tcl`
  - `source $XSCHEM_SHAREDIR/ase.tcl` **:14106**, `ase_window.tcl` **:14108**.
  - per-window Tools menu cascade **:14201** (`menu $topwin.menubar.tools` :14202);
    `Library Manager` :14665, `Net highlight styles...` :14666, `separator`
    :14667. **Insert the Launch entry between :14666 and :14667** (see D8).
- Workarea rcs (both CLEAN / committed at 05b2a708 — NOT in the pre-batch dirty
  list; verify clean immediately before staging):
  - `sky130A/cadence_style_rc` — `set ::SKYWATER_MODELS ...` at **:31**.
  - `gf180mcuD/cadence_style_rc` — `set ::180MCU_MODELS ...` at **:34** (the
    header comment :31-32 documents the gf180 model emit).
- symbol-view detection idiom (already in the tree): `create_instance.tcl:100`
  uses `[string match {*.sym} [xschem get schname]]`. Confirms `xschem get
  schname` returns the `.sym` path when a symbol is the current view.

---

## Decisions (scout's calls, each justified)

- **D1 — reuse `schematic_cellview` for the resolver.** It already reverse-maps
  an abs path to `{lib cell view layout}` against the registered library roots
  (`library_list`/`library_registry`). New ASE code wraps it; no new
  library-matching logic, no library_defs.tcl edit.
- **D2 — schematic-only guard by extension.** `ase::design_of_path` refuses any
  datafile whose extension is not `.sch` (a `.sym` / `.state` / other current
  view → honest error) BEFORE calling `schematic_cellview`. This is the exact
  "symbol/non-schematic → honest error" the item wants and matches the
  create_instance.tcl `*.sym` idiom. For a flat-library hit (`view {}`) default
  the design view to `schematic` (cellview_resolve's flat fallback resolves it).
- **D3 — `::ASE_DEFAULT_MODELS` stores the PORTABLE literal form.** The committed
  proof state file
  `sky130A/xschem_libs/sky130_tests/test_nfet_final/ngspice_state1/test_nfet_final.state`
  stores `models {{file $::SKYWATER_MODELS/sky130.lib.spice section tt}}` — the
  LITERAL `$::VAR/...` string, expanded at deck time by `ase::expand_path`
  (ase.tcl:59), NOT the absolute path. So the rc MUST brace-quote the var so it
  stays literal (`{$::SKYWATER_MODELS/sky130.lib.spice}`), NOT `[file join
  $::SKYWATER_MODELS ...]` (which the PLAN sketch wrote — that would expand to a
  machine-specific absolute path and break git-portability). Verified: the
  braced list element round-trips through `dict get`→`ase::expand_path` to the
  correct absolute path; `$::180MCU_MODELS` (digit-leading) substs fine too.
- **D4 — gf180 default model = `{file $::180MCU_MODELS/sm141064.ngspice section
    typical}`.** Verified from the gf180 bench emit (every `gf180mcu_tests`
  bench emits `.lib $::180MCU_MODELS/sm141064.ngspice typical`) — `typical` is
  the corner a working gf180 op sim uses. **Documented caveat** (put it in the
  rc comment): a gf180 bench ALSO emits `.include $::180MCU_MODELS/design.ngspice`
  which defines the global-switch `.param`s (`sw_stat_global`, `mc_skew`, …)
  that `sm141064.ngspice`'s models reference and that sm141064 does NOT
  self-default (verified: sm141064 preamble lines 1-104 carry no such params).
  That is an `.include`, not a `.lib` section, so it falls OUTSIDE the v1
  `::ASE_DEFAULT_MODELS` (a models/`.lib` list) contract — a real gf180 run
  needs it added by hand or via a future includes seed. This honors the PLAN's
  "set the tt/typical corner and note it." Item 15 runs no gf180 sim, so this
  does not block. (sky130 default = `{file $::SKYWATER_MODELS/sky130.lib.spice
  section tt}` — self-contained, a full run works.)
- **D5 — `state_default` reads `::ASE_DEFAULT_MODELS` behind an `info exists`
    guard.** `set_ne ASE_DEFAULT_MODELS {}` at ase.tcl top-level (mirrors
  `ase_eng_notation`), AND the `models` default line becomes
  `models [expr {[info exists ::ASE_DEFAULT_MODELS] ? $::ASE_DEFAULT_MODELS : {}}]`.
  The guard is LOAD-BEARING: the deliverable-5 test literally `unset`s the
  global and expects `models {}` — without the guard `state_default` would throw
  "no such variable". When unset/empty → `{}` (byte-identical to today → no
  regression to any existing test). set_ne+set ordering with the rc is proven
  compatible (item 09 shipped `ase_eng_notation` with the exact pattern).
- **D6 — untitled session key/meta/title.** An untitled launch has NO `.state`
  file. Use the synthetic view label **`(unsaved)`**:
  - session KEY = `ase::session_key $lib $cell (unsaved)` → `lib/cell/(unsaved)`.
    A real state view is `ngspice_stateN` (numbered by the creation flow) — a
    dir/view literally named `(unsaved)` is never produced, so the key can NEVER
    collide with a later LibMgr `ase::open_state` of a real state view (which
    would otherwise reload over the in-memory untitled session).
  - `ase::ui::open` is called with view=`(unsaved)` → `refresh_status` shows
    `State: (unsaved)` automatically (NO refresh_status edit) — status reflects
    untitled.
  - TITLE: `refresh_title` gets a guarded untitled cue (D7).
  - design dict view = the RESOLVED schematic view (e.g. `schematic`) — this is
    what `ase::netlist`/Design Window use (state.design, NOT meta). Decoupled
    and verified (design_path reads state.design at ase_window.tcl:2529).
  - `raise-not-duplicate` is by DESIGN, not key (D9), so the synthetic key does
    not weaken it.
- **D7 — title untitled cue + Save-As prefill (the only two `ase_window.tcl`
    edits).**
  - `refresh_title`: after the cell name, append ` (unsaved)` **iff**
    `[ase::session_getattr $key untitled 0] eq {1}`, BEFORE the ` *` dirty
    marker. From-file sessions have no `untitled` attr → unchanged (W1 title
    assertion stays green).
  - `save_state_dialog` View prefill: change `$ve insert 0 $mview` to
    `$ve insert 0 [ase::session_getattr $key saveview $mview]`. `new_session`
    sets `saveview ngspice_state1` so the untitled Save-As prefills a sensible
    real view name instead of `(unsaved)`. From-file sessions have no `saveview`
    attr → getattr returns `$mview` → unchanged (item-07 dialog tests stay
    green). `do_save_state_as` already handles a session with empty `path`
    (path `{}` → the create/overwrite else-branch): NO save-path edits needed.
- **D8 — Tools menu placement.** Insert
  `$topwin.menubar.tools add command -label "Launch ASE-L" -command
  "ase::launch_for_current"` between the current `Net highlight styles...`
  (:14666) and the `separator` (:14667) — grouping it with `Library Manager` in
  the applications cluster (ASE-L is a launcher/app, like Cadence Tools>ADE-L),
  before the drawing-insert separator. No `$topwin` arg: every other tools
  command (`xschem library_manager`, `net_hilight_style_editor`, `xschem
  place_text`) operates on the current context; `launch_for_current` reads
  `xschem get schname` (current context) the same way.
- **D9 — raise-not-duplicate matches by DESIGN.** `ase::session_for_design {lib
  cell view}` scans `ase::sessions` for any entry whose `state.design`
  lib+cell+view match; if found and (under X) its window is live, raise it. This
  catches BOTH a prior untitled launch AND a from-file session already targeting
  the same design — "if a session already targets this design, raise it."
- **D10 — new test file, not an edit of test_ase_window.** New
  `tests/headless/test_ase_launch.tcl` (auto-discovered by
  `tests/headless/full_audit.sh`; NO `run_regression.tcl` registration — that
  file is pre-batch dirty). Keeps existing test_ase_window checks untouched.

---

## Deliverables (implement exactly)

### 1. `src/ase.tcl`

a. In the `namespace eval ase { … }` block (near :39), add:
```tcl
  # untitled-launch synthetic view label (Tools > Launch ASE-L): a real state
  # view is always ngspice_stateN, so this never collides with a LibMgr open.
  variable untitled_view {(unsaved)}
```

b. Top-level, near the `set_ne ase_eng_notation 1` (ase.tcl:77) OR just above
   `proc ase::state_default`, add:
```tcl
# Per-technology ASE default models: a list of {file <portable-path> section
# <sec>} dicts a fresh session/state view inherits (empty in stock xschem; a
# workarea rc sets it — sky130A: sky130.lib.spice tt; gf180mcuD: sm141064
# typical). set_ne so an rc value set before ase.tcl is sourced survives.
set_ne ASE_DEFAULT_MODELS {}
```

c. In `ase::state_default` (:123) change the `models` default to the guarded read:
```tcl
    models    [expr {[info exists ::ASE_DEFAULT_MODELS] ? $::ASE_DEFAULT_MODELS : {}}] \
```

d. Add the resolver pair (place after `open_state`, before the ngspice backend
   namespace; reuses `schematic_cellview` from library_defs.tcl):
```tcl
# Reverse an absolute cellview datafile path to {lib cell view}, or throw a
# clean error. ASE simulates SCHEMATIC designs only: any non-.sch current view
# (symbol/state/…) is refused up front (the create_instance.tcl *.sym idiom).
# Reuses schematic_cellview (library_defs.tcl) for the library-root matching;
# a flat-library hit (view {}) defaults to the schematic view.
proc ase::design_of_path {abspath} {
  if {$abspath eq {}} {
    return -code error "ase: no current design (empty schematic path)"
  }
  if {[string tolower [file extension $abspath]] ne {.sch}} {
    return -code error "ase: current view is not a schematic\
 (ASE simulates schematic designs)"
  }
  set r [schematic_cellview $abspath]
  if {$r eq {}} {
    return -code error "ase: '$abspath' is not under a registered library"
  }
  lassign $r lib cell view layout
  if {$view eq {}} { set view schematic }
  return [list $lib $cell $view]
}

# {lib cell view} of the CURRENT schematic, or {} after a ciw_echo'd honest
# error (symbol view / unsaved / outside every library).
proc ase::design_of_current {} {
  set p {}
  catch {set p [file normalize [xschem get schname]]}
  if {[catch {ase::design_of_path $p} r]} {
    if {[info commands ::ciw_echo] ne {}} { catch {ciw_echo $r error} }
    return {}
  }
  return $r
}
```

e. Add the session helpers + launcher:
```tcl
# The session key (if any) whose state.design targets {lib cell view}. Used by
# Launch to RAISE rather than duplicate a session already on this design.
proc ase::session_for_design {lib cell view} {
  variable sessions
  dict for {k entry} $sessions {
    set d [ase::state_get [dict get $entry state] design]
    if {[dict exists $d lib]  && [dict get $d lib]  eq $lib  \
     && [dict exists $d cell] && [dict get $d cell] eq $cell \
     && [dict exists $d view] && [dict get $d view] eq $view} {
      return $k
    }
  }
  return {}
}

# Register a BLANK untitled session bound to design {lib cell schview} (Tools >
# Launch ASE-L). Distinct from session_open (which loads a .state file): NO file
# on disk (path {}), state = state_default (already carrying ::ASE_DEFAULT_MODELS
# + empty vars/outputs) with design pointing at the schematic view; saved ==
# state so the session is NOT dirty until edited (item-16's close-prompt will not
# fire on an untouched launch). Key/meta view = the synthetic untitled_view;
# saveview seeds the Save-As View prefill. Returns the session key.
proc ase::new_session {lib cell schview} {
  variable sessions
  variable untitled_view
  set key [ase::session_key $lib $cell $untitled_view]
  set st [ase::state_default]
  dict set st design [list lib $lib cell $cell view $schview]
  dict set sessions $key [dict create path {} state $st saved $st \
    untitled 1 metaview $untitled_view saveview ngspice_state1]
  return $key
}

# Tools > Launch ASE-L: open a FRESH untitled ASE session for the current
# schematic's design (Cadence Tools>ADE-L). Raise-not-duplicate: if any session
# already targets this design, raise it (under X) and return its key. Returns
# the session key, or {} when the current view does not resolve to a schematic
# design (design_of_current already reported the honest error). Headless-safe:
# all Tk work is behind the has_x guard (the open_state carve-out doctrine).
proc ase::launch_for_current {} {
  variable untitled_view
  set d [ase::design_of_current]
  if {$d eq {}} { return {} }
  lassign $d lib cell view
  set ek [ase::session_for_design $lib $cell $view]
  if {$ek ne {}} {
    if {[info exists ::has_x]} {
      set w [ase::ui::window_for $ek]
      if {$w ne {} && [winfo exists $w]} {
        catch {wm deiconify $w}; catch {raise $w}; catch {focus $w}
      }
    }
    return $ek
  }
  set key [ase::new_session $lib $cell $view]
  if {[info exists ::has_x]} {
    ase::ui::open $key $lib $cell $untitled_view
  }
  return $key
}
```

### 2. `src/ase_window.tcl` (two small edits — D7)

a. `refresh_title` (:2466-2467): insert the untitled cue before the dirty marker:
```tcl
  set t "Analog Sim Environment [ase::ui::design_cell_name $key]"
  if {[ase::session_getattr $key untitled 0] eq {1}} { append t { (unsaved)} }
  if {[ase::session_dirty $key]} { append t { *} }
```

b. `save_state_dialog` View prefill (:2274):
```tcl
  $ve insert 0 [ase::session_getattr $key saveview $mview]
```

### 3. `src/xschem.tcl` — Tools menu entry (between :14666 and :14667)
```tcl
  $topwin.menubar.tools add command -label "Launch ASE-L" -command "ase::launch_for_current"
```

### 4. `sky130A/cadence_style_rc` — after the `set ::SKYWATER_MODELS ...` (:31)
```tcl
# ASE-L default corner: preload the sky130 tt models in every fresh session /
# state view. Stored in the PORTABLE $::VAR form (ase::expand_path resolves it
# at deck time) so state files stay git-portable.
set ::ASE_DEFAULT_MODELS [list [list file {$::SKYWATER_MODELS/sky130.lib.spice} section tt]]
```

### 5. `gf180mcuD/cadence_style_rc` — after the `set ::180MCU_MODELS ...` (:34)
```tcl
# ASE-L default corner: preload the GF180MCU typical-corner model .lib in every
# fresh session / state view (portable $::VAR form). NOTE a full gf180 run ALSO
# needs design.ngspice's global-switch .params (sw_stat_global, mc_skew, …),
# which the models reference and sm141064 does not self-default; that is an
# .include (not a .lib section) and thus outside this v1 models list — add it by
# hand or via a future includes seed for an actual gf180 simulation.
set ::ASE_DEFAULT_MODELS [list [list file {$::180MCU_MODELS/sm141064.ngspice} section typical]]
```

### 6. `tests/headless/test_ase_launch.tcl` (NEW)

Model the setup on `tests/headless/test_ase_window.tcl:199-250` (scratch
`aselib` library via a `library.defs` DEFINE + `::library_registry_defs_only
1`, a minimal `nfet_clean/schematic/nfet_clean.sch`). Standalone repro from
repo ROOT: `./src/xschem --pipe -q --nolog --script tests/headless/test_ase_launch.tcl`
(add DISPLAY for the GUI legs). Use `check`/`check_true`, and for GUI legs the
`winfo exists .`/`main_ready` self-SKIP + `send_return`/`send_key` idioms from
full_audit.sh / test_ase_window.tcl. Named checks:

Headless (must run under `--nogui`):
- **L1 resolver .sch** — `ase::design_of_path $schpath` == `{aselib nfet_clean
  schematic}`.
- **L2 resolver symbol** — `catch {ase::design_of_path
  $scratch/aselib/nfet_clean/symbol/nfet_clean.sym}` is nonzero (throws; the
  path need not exist — the extension guard fires first).
- **L3 resolver bogus** — `catch {ase::design_of_path /nope/foo/bar.sch}`
  nonzero (`schematic_cellview` returns {} → "not under a registered library").
- **L4 default set** — with `set ::ASE_DEFAULT_MODELS [list [list file
  {$::SKYWATER_MODELS/sky130.lib.spice} section tt]]`,
  `[dict get [ase::state_default] models]` equals that list (compare the
  in-memory value, NOT a serialized/round-tripped string — see the brace note
  below).
- **L5 default unset** — `unset ::ASE_DEFAULT_MODELS; check {L5} [dict get
  [ase::state_default] models] {}` (proves the info-exists guard: no throw,
  empty result). Restore with `set_ne ASE_DEFAULT_MODELS {}` afterwards.
- **L6 launch registers a session** (headless) — after `xschem load $schpath`,
  `set k [ase::launch_for_current]`; `check_true` `$k ne {}` and
  `[ase::session_state $k]`'s models == `$::ASE_DEFAULT_MODELS`, variables ==
  {}, outputs == {}, and `[ase::session_dirty $k]` == 0.
- **L7 raise-not-duplicate** (headless) — a SECOND `ase::launch_for_current`
  returns the SAME key as L6 and creates no new session (e.g.
  `ase::session_for_design aselib nfet_clean schematic` matches exactly one
  entry; or assert the two launch return-keys are identical AND the design
  appears once across `ase::sessions`).
- **L8 symbol current view errors** — load a `.sym` as current (or drive
  `ase::design_of_current` with a monkey-patched schname) so
  `ase::launch_for_current` returns {} and registers no session. (If loading a
  `.sym` headless is awkward, cover the symbol path via L2 and assert
  design_of_current returns {} when `xschem get schname` is a `.sym` — a small
  temp `.sym` under aselib.)

GUI legs (DISPLAY only; else `puts "gui legs skipped (no DISPLAY)"` and do NOT
emit the full-audit SKIP token):
- **G1 menu wired + launch** — set `::SKYWATER_MODELS` + `::ASE_DEFAULT_MODELS`,
  `xschem load $schpath`, then invoke via the real menu
  (`.menubar.tools invoke [.menubar.tools index "Launch ASE-L"]`) — proves the
  menu wiring. Assert exactly one `.ase*` toplevel now exists; its session's
  `models` == the sky130 default; variables == {}, outputs == {}; the analyses
  pane shows the state_default rows (4); the session is NOT dirty; the status
  bar (`ase::ui::status_text $key`) contains `State: (unsaved)`; the title
  contains `(unsaved)`.
- **G2 second launch raises, no duplicate** — invoke the menu again; assert
  still exactly ONE `.ase*` toplevel (no new window number consumed) and the
  same session key.

**Brace note (do NOT trip on it):** `[list [list file {$::SKYWATER_MODELS/…}
section tt]]` serializes (via `ase::state_serialize`) to
`{{file {$::…} section tt}}` — Tcl list-quoting braces the `$`-bearing element,
so it is STRING-different from the committed proof file's unbraced
`{{file $::… section tt}}` but STRUCTURALLY identical (same `dict get`). The
committed `test_nfet_final.state` is NOT regenerated by this item, and no test
compares a fresh seed byte-for-byte to it. Compare models as in-memory
dicts/values only. `render_deck`→`expand_path` resolves the braced form to the
correct absolute path (verified).

**≥2 sabotages (do all three for margin; each must fail EXACTLY its target and
nothing else; `git diff` to confirm sabotage-only, `git checkout -- <file>`
revert, clean re-run green):**
- **S1** — in `ase::state_default` revert the guarded models read to `{}`.
  Target: L4 (and G1's models assertion) fail; L5 stays green. Confirms the
  default is actually wired.
- **S2** — in `ase::design_of_path` drop the `.sch` extension guard (accept any
  extension). Target: L2 (symbol) fails; L1/L3 stay green. Confirms the
  schematic-only guard runs.
- **S3** — in `ase::launch_for_current` remove the `session_for_design` raise
  arm (always `new_session`). Target: L7 (and G2) fail; L6/G1 stay green.
  Confirms raise-not-duplicate runs.

---

## MUST NOT regress

- **open_state file-load path** (LibMgr double-click / hi_descend): unchanged.
  `new_session` is a NEW parallel entry — do not alter `session_open` or
  `open_state`.
- **item-02 view creation**: `library_new_view`'s ngspice_state* seed already
  routes through `state_default`; do NOT edit `library_defs.tcl`. The seed now
  carries default models only when a workarea rc set the global (that IS the
  intended improvement; stock xschem seeds `models {}` exactly as before).
- **Existing ase tests MUST stay green**: `test_ase_core`, `test_ase_view`,
  `test_ase_window`, `test_ase_dialogs`, `test_ase_final`, `test_ase_interact`,
  `test_ase_plot`, `test_ase_persist`, `test_wave_viewer`. (state_default's
  models default is `{}` whenever the global is unset → byte-identical to
  today; `test_ase_final` F3 round-trips a LOADED file whose own `models` key
  overrides the default → unaffected. The two `ase_window.tcl` edits are
  no-ops for from-file sessions.) Any assertion that legitimately must change
  MUST be justified in the receipt.
- `refresh_status` needs NO edit — it already renders `State: (unsaved)` from
  the meta view.

## Verification before commit

Run each test in its own process from the repo root
(`./src/xschem --pipe -q --nolog --script tests/headless/<t>.tcl`, add DISPLAY
for GUI legs): the new `test_ase_launch` plus the nine ase/wave tests above,
then `tests/headless/full_audit.sh` — the fail set must be a SUBSET of the
PLAN baseline (below); any non-baseline fail is yours. Sabotage-verify per the
policy block.

Baseline-tolerated full_audit fails (pre-existing, NOT yours):
test_altf5_ciw, test_cadence_descend_newwin_ro, test_cadence_drag,
test_cadence_window_hop_log, test_ciw, test_crossview_paste,
test_fluid_editing, test_hi_descend, test_launch_context, test_lib_manager_gui,
test_lib_sweep, test_palette, test_phase3_mints, test_pin_type_edit,
test_reopen_readonly, test_select_at, test_selflog_output,
test_verb_noun_copy_move, test_wire_split, test_wire_vertex_grab; TIMEOUT
test_key_graph_context. WSLg flakes (not regressions if a direct re-run passes):
test_deselect_mode, test_hover_highlight, test_ase_window (send_return / self-
SKIP; rerun-first).

## Commit (ONE commit, explicit file list — stage ONLY these six)

```
git add src/ase.tcl src/ase_window.tcl src/xschem.tcl \
        sky130A/cadence_style_rc gf180mcuD/cadence_style_rc \
        tests/headless/test_ase_launch.tcl
```
Verify the two rc files are CLEAN before staging (`git status --porcelain
sky130A/cadence_style_rc gf180mcuD/cadence_style_rc` empty). NEVER stage the
pre-batch dirty tracked files (below) regardless of their current state, and
never `git add -A`/`commit -a`, never `git reset --hard`, never push.

Suggested message (normal prose + Co-Authored-By trailer):
`feat(ase): Tools > Launch ASE-L — fresh untitled session for the current schematic`

Pre-existing dirty tracked files (NEVER stage): `doc/claude/specs/sky130_workarea.md`,
`sky130A/xschem_libs/library.defs`, `src/ciw.tcl`,
`tests/headless/test_sky130a_libmgr.tcl`, `tests/run_regression.tcl`.

---

## RUNBOOK — Policies (non-negotiable) [verbatim]

- Git: NEVER `git reset --hard`, NEVER `git add -A`/`commit -a`, NEVER push.
  Stage explicit file lists only. Pre-existing dirty tracked files at batch
  start (listed in PLAN.md preflight) must NEVER be staged; in particular
  `tests/run_regression.tcl` is dirty pre-batch → this batch does NOT register
  tests there; tests/headless/full_audit.sh auto-discovers `test_*.tcl`.
- A green suite ≠ the changed code ran: sabotage-verify (each sabotage fails
  EXACTLY its target check, revert via targeted `git checkout -- <file>` only
  after `git diff` confirms the file holds nothing but the sabotage, clean
  re-run green).
- Headless traps: each test its own process; repo-root cwd for relative paths;
  script error idles rather than hangs; `--nogui --pipe -q --nolog --script`.
- GUI tests: DISPLAY-guarded self-SKIP (`winfo exists .` guard pattern from
  full_audit.sh); replay WHOLE Tk event sequences in the shipping rc profile.
- User-facing messages via `ciw_echo`, not puts/statusbar.
- Tcl: TIP-278 (`variable`/absolute names in namespaces); C (if any): C89,
  `_ALLOC_ID_` placeholders. Windows: guard unix-only subprocess paths.
- Do not touch `_nhangle_*`/`_allm_*`/junk dirs or anything outside declared
  scope. Do not edit generated files (Makefile from Makefile.in — tmpasm, no
  `$@`/`$<`, `@` is the delimiter).
- Commit messages: normal prose, Co-Authored-By trailer per repo convention.
