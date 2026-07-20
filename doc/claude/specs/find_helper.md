# find_helper — Find Navigator (Xschem port of the S-Edit utility)

Status: spec only (fluid-editing). Author: session 2026-07-19. Pure-Tcl port, no C changes.

This is the Xschem port of the Tanner S-Edit "Find Navigator" (`references/find_helper_spec.md`
+ `references/find_helper_usr_guide.md`, both READ-ONLY — no reference `.tcl` exists; the port is
designed from the spec/guide against the real Xschem API). It replaces every S-Edit primitive with
an Xschem equivalent: the S-Edit `find <type> ... -filter/-modify {script}` engine becomes a Tcl
iterate-and-match loop over the current-sheet instance store; `property get/set -name Name -system`
becomes type-dependent `xschem getprop/setprop instance <N> <token>`; `mode renderoff/renderon`
becomes the `push_undo` + `no_undo` + single-`redraw` batch idiom; the shadowed-`clipboard`/`clip.exe`
hack is dropped for native Tk `clipboard` (via `utils/cadence_clip.tcl`).

Related prior art (reuse, do not reinvent):
- `utils/toggle_pins_netlabels.tcl` — instance classification by `cell::type`, the
  push_undo/no_undo single-undo transaction, the `bind .drw <chord> {...; break}` wiring.
- `utils/select_same_cell.tcl` — the `for {i} {i<[xschem get instances]}` enumerate loop and
  `xschem unselect_all` + per-index `xschem select instance $i` selection rebuild.
- `utils/cadence_clip.tcl` — `cadence::clip_put` (native `clipboard clear/append` + `ciw_echo`).
- `doc/claude/specs/instance_update.md` — the sibling S-Edit port (master retarget); shares the
  library/cell/view (LCV) model described below and the Scope/hierarchy-guard decisions.

## Goal

A modeless Tk form (`find_helper::show`) that finds **ports**, **instances**, or **net-labels** by
name pattern in the current schematic, and can **select** them, **count** them, **list** their names
(screen-ordered CSV), and **bulk-rename** them via a `regsub` search-and-replace, reporting which
names changed and which failed. Every widget maps to a concrete Xschem verb (see the mapping table);
the assembled "command" shown to the user is a **human-readable Xschem-flavoured summary line** of
the query it will run (Xschem has no single `find` verb to echo verbatim — see Non-goals).

## Non-goals

- **No new matching engine and no new C verb.** All matching/iteration is pure Tcl over the existing
  `xschem get instances` / `getprop` / `setprop` / `select` verbs. If a needed primitive is missing
  (hierarchy-wide iteration), it is **deferred**, not written in C.
- **No verbatim S-Edit `find` string.** S-Edit could echo the exact `find ...` line it ran; Xschem
  runs a Tcl loop, so the *Command* box shows a faithful **summary** (object type, name pattern,
  match mode, scope, action) — the transparency purpose is preserved, the literal string is not.
- **No hierarchy-scope mutation.** Xschem verbs act on the **current sheet only**; there is no
  cross-sheet find/modify primitive. `hierarchy` scope is refused for Run/List (see *Scope & the
  hierarchy guard*).
- **No cross-session persistence** of form state or history.
- **No symbol-view support.** In a `.sym` view ports/labels are pin RECTS, not instances; the form
  refuses to run there (mirrors `toggle_pins_netlabels.tcl`).
- Rename target is always the object's **Name** (type-routed to `name`/`lab`); choosing a different
  property is out of scope.

---

## Object identity in Xschem (grounding — how S-Edit types map)

S-Edit has separate object classes (`port`, `instance`, `netlabel`). **Xschem has ONE object store:
every port, net-label and component is an `xInstance`**, distinguished only by its symbol's
`cell::type`. There is no per-type storage and no verb that filters by object type — the S-Edit
`find <type>` restriction is reproduced in Tcl by testing `xschem getprop instance <N> cell::type`.

| S-Edit Object | Xschem `cell::type`(s) | User-visible Name lives in | Name token |
|---|---|---|---|
| **port** | `ipin`, `opin`, `iopin` | the net name (the `lab` attr) | `lab` |
| **netlabel** | `label` (lab_pin.sym, lab_wire.sym, …) | the net name (the `lab` attr) | `lab` |
| **instance** | everything else (subcircuits, primitives) | the instance name / refdes | `name` |

Excluded from port/netlabel: `show_label` (lab_show) and empty-type `lab_generic` are **not**
connecting net-labels — skip them (same rule as `toggle_pins_netlabels.tcl:15`).

**The single biggest porting hazard**: S-Edit's `property get -name Name` is uniform; Xschem's is
type-dependent. The form's one *Name* field must route to token **`name`** for `instance` and token
**`lab`** for `port`/`netlabel`. This routing is centralised in `name_token {objtype}` (returns
`name` or `lab`) and used by every read (`getprop`), match, rename (`setprop`) and List collection.

### The LCV model (shared with instance_update, used here for Scope/current-cell context)

An instance's "master" is a single symbol **reference** string (`cell::name`, e.g.
`devices/lab_pin.sym`) — Xschem stores no MasterLibrary+MasterCell pair. find_helper does **not**
retarget masters (that is `instance_update`'s job), but it uses the LCV registry for one thing: the
*current cell* label in the status/`In cell` context is derived from
`schematic_cellview [xschem get schname]` (element 1), and `-scope selection` restricts the loop to
the already-selected instance set. Library/cell enumeration verbs (`xschem libraries`, `lib_cells`,
`cellview_path`) are **not** needed by find_helper.

---

## Form layout

```
┌─ Find Navigator ─────────────────────────────────────────────┐
│ Object: [port ▾]            Scope: [view ▾]                   │
│                                                              │
│ Name:   [____________________________________]               │
│                                                              │
│ Match mode:   ☐ wildcard   ☐ regex   ☐ nocase    [ List ]   │
│               ☐ exact      ☐ contains                        │
│                                                              │
│ Selection:    ☐ first   ☐ add   ☐ sub   ☐ count             │
│                                                              │
│ ☑ no-goto (do not pan/zoom to matches)                       │
│ ──────────────────────────────────────────────────────────  │
│ ┌─ Rename (regsub on Name) ───────────────┐  ┌─ History ──┐  │
│ │  From (regex): [__________________]      │  │ [ ▲ Prev ] │  │
│ │  To   (subst): [__________________]      │  │ [ ▼ Next ] │  │
│ │ ☐ Report modified (pre-existing) names   │  │   3 / 5    │  │
│ └──────────────────────────────────────────┘  └────────────┘  │
│ ──────────────────────────────────────────────────────────  │
│ [ Build Command ] [ Run ] [ Copy Results ] [ Reset ] [Close]│
│ ──────────────────────────────────────────────────────────  │
│ Command:  (read-only — summary of the query that will run)   │
│ ┌──────────────────────────────────────────────────────┐    │
│ │ find port  name=v.*_port[12]  regex  scope=view       │    │
│ └──────────────────────────────────────────────────────┘    │
│ Results:  (read-only, scrollable)                            │
│ ┌──────────────────────────────────────────────────────┐    │
│ │ 7 matched                                            ▲ │    │
│ │ old_a    ->  new_a                                     │    │
│ │ old_b    ->  new_b                                   ▼ │    │
│ └──────────────────────────────────────────────────────┘    │
│ Status: 7 found, 7 renamed, 0 failed                         │
└──────────────────────────────────────────────────────────────┘
```

Note the labels drop S-Edit's leading `-` (there is no CLI flag being emitted); the checkbox
*meaning* is identical. Fonts/comboboxes follow the house UI idiom (see *UX details*).

---

## Widgets → Xschem-command mapping

Every widget drives Xschem verbs, **not** S-Edit `find`. `<N>` is an instance index from the
enumerate loop; `<tok>` is `name` or `lab` per `name_token`.

| Widget | Var | Default | Drives (Xschem) |
|---|---|---|---|
| **Object** combobox `port`/`instance`/`netlabel` | `::find_helper::ftype` | `port` | selects the `cell::type` filter set + the `name_token` (`lab` vs `name`) used by every getprop/setprop below |
| **Scope** combobox `selection`/`view`/`hierarchy` | `::find_helper::fscope` | `view` | `view` → loop `0..[xschem get instances]-1`; `selection` → loop over `xschem selected_set` names; `hierarchy` → **refused** (guard) |
| **Name** entry | `::find_helper::fname` | empty | the pattern; empty ⇒ match every in-scope object of the type. Compared against `xschem getprop instance <N> <tok>` by the mode's Tcl matcher |
| **wildcard** check | `::find_helper::wildcard` | 0 | matcher = `string match $pat $val` (glob) |
| **regex** check | `::find_helper::regex` | 0 | matcher = `regexp -- $pat $val` |
| **nocase** check | `::find_helper::nocase` | 0 | adds `-nocase` to `string match`/`regexp` (folds case for the default/contains/exact matchers too) |
| **exact** check | `::find_helper::exact` | 0 | matcher = `string equal` (whole-string, case-sensitive) |
| **contains** check | `::find_helper::contains` | 0 | matcher = `string first $pat $val >= 0` (substring) |
| *(no mode checked)* | — | — | matcher = `string equal` default (whole-string) — mirrors S-Edit's default "exact-ish" |
| **first** check | `::find_helper::first` | 0 | `break` after the first match in the loop |
| **add** check | `::find_helper::add` | 0 | matches ADD to selection: keep prior selection, `xschem select instance <N> nodraw` per match |
| **sub** check | `::find_helper::sub` | 0 | matches SUBTRACT: `xschem select instance <N> clear nodraw` per match (keep the rest) |
| **count** check | `::find_helper::count` | 0 | report `llength $matched` in Status; no selection change |
| *(neither add/sub/count)* | — | — | REPLACE selection: `xschem unselect_all` then `xschem select instance <N> nodraw` per match |
| **no-goto** check | `::find_helper::gotonone` | **1** | when **unchecked**, after the loop `xschem select instance <first-match>` + `xschem zoom_full`-style recenter to the first match (view jumps); when checked (default) no recenter (analogue of `-goto none`) |
| **From** entry | `::find_helper::ffrom` | empty | rename regex; non-empty ⇒ rename path runs (`setprop instance <N> <tok>`) |
| **To** entry | `::find_helper::fto` | empty | rename replacement (`regsub -all`); empty+From-set = delete matched text |
| **Report** check | `::find_helper::report` | 0 | controls Results verbosity; with From empty + Report on ⇒ audit list of matched names |
| **List** button | — | — | `find_helper::list_names` — collect matched `{name x y}`, screen-order, CSV → Results |
| **Build Command** button | — | — | `find_helper::build_only` — assemble + show summary, no execution |
| **Run** button | — | — | `find_helper::run` — snapshot to history, execute selection/rename, fill Results/Status |
| **Copy Results** button | — | — | `find_helper::copy_results .fh.res` → `cadence::clip_put` |
| **Reset** button | — | — | `find_helper::reset` (defaults, keep history) |
| **Close** button | — | — | `wm withdraw`/`destroy` the toplevel |
| **▲ Prev / ▼ Next** | `::find_helper::histidx` | — | `history_up` / `history_down` |

### Match-mode checkbox linkage (auto-uncheck — preserved verbatim)

Implemented as `-command find_helper::link <which>` on each match-mode checkbutton, exactly as the
reference. The clear-on-check map (unchanged from S-Edit — these are Tcl matcher semantics, not CLI
flags, so they port 1:1):

| Checking… | clears |
|---|---|
| **wildcard** | regex, exact |
| **regex** | wildcard, exact  *(keeps nocase)* |
| **exact** | wildcard, regex, contains, nocase |
| **contains** | exact |
| **nocase** | exact |
| **add** | sub |
| **sub** | add |

Satisfies: wildcard↔regex exclusive; exact↔contains exclusive; regex↔exact exclusive; regex+nocase
allowed; exact is case-sensitive (clears/cleared-by nocase); add↔sub exclusive. `contains` with
`wildcard`/`regex` is left unconstrained. `find_helper::link` mutates only the namespace vars; the
bound checkbuttons update live.

### Scope & the hierarchy guard

- **view** — enumerate `for {set i 0} {$i < [xschem get instances]} {incr i}`; filter each by
  `cell::type`. (S-Edit `-scope view`.)
- **selection** — enumerate the names in `xschem selected_set` (brace-quoted instname list), filter
  by type. (S-Edit `-scope selection`.) Note the matched set is then re-selected/renamed as usual —
  matching *within* the current selection.
- **hierarchy** — **DEFERRED / REFUSED.** Xschem has no cross-sheet find or `-modify` primitive; a
  built "command" here is a Tcl loop over the current sheet only, so there is nothing S-Edit's
  "List-only-on-hierarchy, then hand-edit the command" trick could target. The combobox still offers
  `hierarchy` (so the option is visible/documented), but **Run** and **List** refuse it with a red
  Status line (`hierarchy scope is not supported — Xschem acts on the current sheet only; descend
  and re-run per sheet`) and no mutation occurs. This mirrors `instance_update`'s hierarchy guard.

---

## Core logic

### The enumerate-match loop (`select_matches` / the shared collector)

Replaces S-Edit `find <type> -name <n> [mode] -scope <s> [-filter/-modify {…}]`. One private
collector walks the in-scope instances and returns the matched **index list** (indices are stable
within a single non-mutating pass; renames re-read by index — see below):

```
proc find_helper::collect {} {
  set objtype  $::find_helper::ftype               ;# port|instance|netlabel
  set tok      [find_helper::name_token $objtype]  ;# lab | name
  set types    [find_helper::type_set  $objtype]   ;# {ipin opin iopin} | {label} | *other*
  set pat      $::find_helper::fname
  set matcher  [find_helper::matcher_for]          ;# closure/spec from the mode vars
  set indices  [find_helper::scope_indices]        ;# view: 0..N-1 ; selection: names->indices
  set out {}
  foreach i $indices {
    set ctype [xschem getprop instance $i cell::type]
    if {![find_helper::type_ok $objtype $ctype]} continue
    set val [xschem getprop instance $i $tok]
    if {$pat eq "" || [find_helper::match $matcher $pat $val]} {
      lappend out $i
      if {$::find_helper::first} break            ;# -first
    }
  }
  return $out
}
```

- `name_token` — `instance`→`name`, `port`/`netlabel`→`lab`.
- `type_ok` — `port`: ctype ∈ {ipin,opin,iopin}; `netlabel`: ctype eq `label`; `instance`: ctype ∉
  {ipin,opin,iopin,label,show_label,""} (everything else).
- `match` — dispatch on the mode vars (pure Tcl, headless-testable, no engine): default→`string
  equal` (+`-nocase`), wildcard→`string match`, regex→`regexp`, exact→`string equal` (case-forced
  on), contains→`string first`≥0. `nocase` folds both operands for the non-regexp matchers.

### Selection action (add / sub / count / replace)

After `collect`, apply the Selection flags with the `nodraw` batch idiom, then one `xschem redraw`:

- **count** → Status `N found`; no selection change.
- **add** → leave existing selection, `xschem select instance $i nodraw` per match.
- **sub** → `xschem select instance $i clear nodraw` per match.
- **replace** (default) → `xschem unselect_all`; `xschem select instance $i nodraw` per match.
- After: `xschem redraw`. If **no-goto** is off, recenter to the first match.

### Rename (the `-modify` port — via getprop/setprop, one undo)

`-modify` runs **iff** From is non-empty **or** Report is on. There is no braced-script injected into
a C engine (Xschem has none); the "static, no-interpolation" safety of the reference is preserved a
different, stronger way — **the rename is native Tcl code in this file, never a string built from
user input.** The user's From/To are only ever passed as *data* to `regsub` (never `eval`/`subst`),
so a From/To containing `{ } [ ] $` is inert.

Single-undo transaction (mirrors `toggle_pins_netlabels.tcl:144-181`): wrap the whole sweep in one
`xschem push_undo` + `xschem set no_undo 1`, `-fast`/`nodraw` on each setprop, then restore
`no_undo 0`, `set_modify 1`, one `redraw` — always balanced via `catch`.

```
proc find_helper::do_rename {indices} {
  set from $::find_helper::ffrom ; set to $::find_helper::fto
  set objtype $::find_helper::ftype ; set tok [find_helper::name_token $objtype]
  set ::find_helper::hits {} ; set ::find_helper::fails {}
  xschem push_undo ; xschem set no_undo 1
  set err [catch {
    foreach i $indices {
      set old [xschem getprop instance $i $tok]
      set new [regsub -all -- $from $old $to]        ;# From/To are DATA only
      if {$new eq $old} continue
      if {[catch {xschem setprop instance $i $tok $new -fast} m]} {
        lappend ::find_helper::fails [list $old $new $m]
      } else {
        lappend ::find_helper::hits [list $old $new]
      }
    }
  } emsg]
  xschem set no_undo 0
  if {!$err} { xschem set_modify 1 }
  xschem redraw
  return $emsg
}
```

Rename addresses objects **by index within one non-mutating pass** — but note `setprop … name` on a
component instance runs the true rename path (hash_names, floater update) and does **not** reorder
the store, so indices from the single `collect` pass stay valid across the sweep. (Contrast
`instance_update`, where `replace_symbol` can rename the refdes — there we re-read by index too.)
`setprop … lab` on a port/label only edits the `lab` token — also index-stable.

- **From non-empty** — rename; always fill `hits`/`fails` so the count is exact regardless of
  Report. Report only governs Results verbosity (full `old -> new` list vs count-only).
- **From empty + Report on** — no `setprop`; `collect` the current Name of each match into `hits`
  for the audit list.
- **From empty + Report off** — no rename path; a plain find/select (Selection flags only).
- Empty **To** + non-empty **From** = valid "delete matched text".
- Readonly sheet: guarded up front (`xschem get readonly`) — Run refuses before mutating. A
  per-object `setprop` that still fails (duplicate/illegal name) lands in `fails`, reported under a
  `FAILED:` heading; the rest proceed (S-Edit's half-updated FAILED reporting, preserved).

### Read-only guard / symbol-view guard

`run` (and any mutating path) first checks: `xschem get readonly` → red Status, abort; and
`string match *.sym [xschem get current_name]` → red Status "not available in symbol view", abort.
`list_names` (read-only) skips the readonly guard but keeps the symbol-view guard.

---

## The List action (screen-ordered CSV) — `list_names` / `order_by_screen`

List is **independent** of Build/Run: it never selects, never renames, ignores the Selection and
Rename fields, and pushes nothing to history. It runs `collect` (Object+Name+Match mode+Scope only),
then for each matched index reads the object's Name and screen coordinates:

```
set name [xschem getprop instance $i $tok]
lassign [find_helper::inst_xy $i] x y      ;# from `xschem instance_coord`/`instance_bbox`
lappend triples [list $name $x $y]
```

`inst_xy` derives x0,y0 from `xschem instance_coord` (selected set) or, for the full view, from
per-index geometry (`xschem instance_bbox <i>` centre, or the `x0 y0` columns of a coord dump). The
exact geometry verb is confirmed at impl time; the screen-order **algorithm** is pure Tcl and is the
headless-tested unit.

**`order_by_screen {triples}`** (verbatim port of the reference algorithm):
- Compute `xspread = max(x) - min(x)` and `yspread = max(y) - min(y)` over all triples.
- If `xspread >= yspread` → objects lie more horizontally → sort **ascending X** (left→right).
- Else → sort **descending Y** (top→bottom; larger Y is higher on the Xschem canvas — Xschem's Y
  grows downward on screen but the reference's "top→bottom = descending Y" convention is preserved as
  a documented, tested choice; if impl finds Xschem screen-Y grows downward, the sort flips to
  **ascending Y** to keep "top of screen first" — decided and locked by the headless test fixture).
- Ties (equal spread) fall to horizontal (ascending X).
- Return the names in sorted order. **No dedup** — one entry per matched object (a supply pin
  repeated around a symbol appears once per instance), preserved as reference behavior.

Result: `join $names ,` into the Results box + `ciw_echo`; Status `N listed`.

---

## History (recall states you actually ran)

Preserved verbatim, over namespace state (no engine involvement — pure Tcl, headless-testable):

- **State** = a snapshot of every input var: `statevars = {ftype fname fscope wildcard regex nocase
  exact contains first add sub count gotonone ffrom fto report}`. `snapshot` returns a `{var value
  …}` dict; `apply_state` does a plain `set ::find_helper::<var> <value>` for each (bound widgets
  update live).
- **Capture** — `run` calls `history_save` **before** executing, so the stack holds only genuinely
  run states. **Build Command does NOT push; List does NOT push.**
- **Dup-collapse** — a snapshot exactly equal to the current stack top is not pushed again
  (re-running the same form does not grow the stack).
- **Navigation** — `history_up` = older, `history_down` = newer; both `apply_state` immediately and
  clamp at the ends. `histidx` parks at `[llength $history]` (one past newest) after a save, so the
  first **▲ Prev** recalls the most-recently-run state. `histlabel` shows `k / n` while recalling,
  `n saved` when parked, `(empty)` before any run.
- **Persistence** — not saved across sessions; **kept across Reset** (Reset clears the form fields
  but re-parks the cursor at the end — the record of what you ran survives).

---

## Copy support (read-only panes → clipboard)

The S-Edit `clip.exe` workaround is **dropped**: Xschem's Tk `clipboard` command is not shadowed.
`copy_results {?t?}`:
- Read the widget's own `sel` tag (`$t get sel.first sel.last`) if there is a selection, else the
  whole pane (`$t get 1.0 end-1c`).
- Push via `cadence::clip_put $txt` (native `clipboard clear` + `clipboard append` + `ciw_echo`,
  from `utils/cadence_clip.tcl`). Wrapped in `catch`; on failure it degrades to `ciw_echo` of the
  text and never raises.
- Bindings on both read-only panes (`.fh.cmd`, `.fh.res`) preempt the class binding:
  ```tcl
  bind $t <<Copy>>         {find_helper::copy_results %W; break}
  bind $t <Control-c>      {find_helper::copy_results %W; break}
  bind $t <Control-Insert> {find_helper::copy_results %W; break}
  ```
  `break` stops `tk_textCopy`. The **Copy Results** button provides the same for discoverability.

---

## The Command box (summary, not a verbatim command)

`build_summary` renders a single read-only line describing the query, e.g.
`find port  name=v.*_port[12]  regex  nocase  scope=view  [rename: /_v1$/_v2/  report]`. It exists
for the same transparency reason as S-Edit's Command box (look before you leap) but is explicitly a
**human summary** — copyable, not re-runnable as a single Xschem verb (Non-goals). Build Command
shows it without executing; Run shows it and executes.

---

## Execution summary

- **Build Command** — `build_summary` → Command box; no execution, no history.
- **Run** — readonly/symbol/hierarchy guards → `history_save` → `collect` → (rename if From/Report)
  → selection action → fill Results + Status → one `redraw`. Wrapped so `no_undo`/undo balance
  always restores.
- **List** — symbol/hierarchy guards → `collect` → `order_by_screen` → CSV to Results + Status; no
  selection/rename/history/undo.
- Everything is also `ciw_echo`'d (Xschem's CIW channel; **not** `puts`/statusbar) so the user has a
  trail. Status uses a red style on guard refusal or `find` error.

---

## Public API (`find_helper` namespace)

| Proc | Purpose |
|---|---|
| `find_helper::show` | Build (or raise) the modeless form. Bound to the keybind. |
| `find_helper::init_fonts` | Create dedicated `Fh*` fonts + combobox-list font (called top of `show`). |
| `find_helper::name_token {objtype}` | `name` for `instance`, `lab` for `port`/`netlabel`. **The type-routing hazard, centralised.** |
| `find_helper::type_set {objtype}` / `type_ok {objtype ctype}` | The `cell::type` filter for each Object. |
| `find_helper::matcher_for` / `match {spec pat val}` | Pure-Tcl matcher from the mode vars (default/wildcard/regex/exact/contains ±nocase). |
| `find_helper::scope_indices` | Index list for `view` (0..N-1) or `selection` (`selected_set`→indices); errors on `hierarchy`. |
| `find_helper::collect` | Enumerate+filter+match → matched index list (honours `-first`). |
| `find_helper::run` | Assemble + execute selection/rename; fill Results/Status; snapshot history. |
| `find_helper::build_only` | Show the summary without running. |
| `find_helper::build_summary` | Return the human-readable query summary line. |
| `find_helper::do_rename {indices}` | The `-modify` port: regsub Name via getprop/setprop, one undo, fill `hits`/`fails`. |
| `find_helper::list_names` | List action: collect + screen-order names, CSV to Results. |
| `find_helper::inst_xy {i}` | `{x y}` screen coords of instance `i` (for ordering). |
| `find_helper::order_by_screen {triples}` | Sort `{name x y}` left→right or top→bottom; return names. |
| `find_helper::copy_results {?t?}` | Copy a pane's text (or selection) via `cadence::clip_put`. |
| `find_helper::link {which}` | Apply the match-mode auto-uncheck rules. |
| `find_helper::snapshot` / `apply_state {s}` | `{var value …}` of `statevars` / restore it. |
| `find_helper::history_save` | Dup-collapse push of the current snapshot (called by `run`). |
| `find_helper::history_up` / `history_down` | Recall older / newer saved state and apply. |
| `find_helper::hist_update_label` | Refresh the `k / n` counter. |
| `find_helper::reset` | Restore field defaults (keep history, re-park cursor). |

Fonts/comboboxes follow the house UI idiom (dedicated `Fh*` fonts via `uiutil::ensure_font`,
`ttk::combobox -state readonly`, `option add *TCombobox*Listbox.font FhEntry`) as the reference and
`copy_current_cell_dialog.tcl` prescribe — carried over unchanged where the repo already provides
the helper; if `uiutil::ensure_font` is absent in Xschem, fall back to plain `font create`.

---

## Keybind + `cadence_style_rc` wiring

- New file: `utils/find_helper.tcl` (namespace + procs; `bind .drw <chord> {...; break}` at bottom).
- Source it in `src/cadence_style_rc` beside the other utils (after line 153, before the effective
  `unset _ut` at line 272), using the pre-computed `$_ut`:
  ```tcl
  # Find Navigator form (Ctrl+Shift+G). Tk bind lives in the util file; see its
  # header for why it is a .drw bind and not a keybindings.csv row.
  source [file join $_ut find_helper.tcl]
  ```
- Keybind — **Ctrl+Shift+G** (the reference's own request; VERIFIED FREE: keysym G=71 has no
  `key,71,ctrl` row in `src/keybindings.csv`, and no existing `Control-Shift-Key-G` bind in
  `cadence_style_rc`/`xschem.tcl`/`mouse_bindings.tcl`). Shift emits the capital keysym, so bind
  `Key-G` (uppercase):
  ```tcl
  bind .drw <Control-Shift-Key-G> {find_helper::show; break}
  ```
  `break` stops the chord reaching the generic `<KeyPress>` → `xschem callback` → C dispatcher.
  `clone_canvas_bindings` (`xschem.tcl:13769`) propagates the `.drw` bind to new/detached canvases.
- **Why not keybindings.csv**: rows there dispatch only compiled C `action_registry[]` ids; there is
  no runtime "register a Tcl proc as an action" path (documented at
  `toggle_pins_netlabels.tcl:33-48`). A brand-new Tcl proc must be a `.drw` bind.

---

## RED-first test plan (`tests/headless/test_find_helper.tcl`)

Mirrors `tests/headless/test_add_wire_label.tcl`: `check name got exp` helper, a pure-Tcl **Section
A** (namespace units, no Tk, no document — these fail RED before impl exists), then loaded-fixture
sections that build an in-memory schematic and assert via `getprop`/`get instances`/`selected_set`.
Footer prints the sentinel `OVERALL: ok` on all-pass, else a `… : FAIL` line + `OVERALL: notok`.
Register in `tests/run_regression.tcl` `hcases` as `headless/test_find_helper`
(`full_audit.sh` auto-discovers; do NOT touch `cases.txt`).
Run one: `./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_find_helper.tcl`.

### Section A — pure-Tcl units (no engine, RED-first)

1. **`name_token`** — `instance`→`name`; `port`→`lab`; `netlabel`→`lab`. (Sabotage: swap ⇒ fails.)
2. **`type_ok`** — port true for ipin/opin/iopin, false for label/subckt; netlabel true only for
   `label`; instance false for ipin/opin/iopin/label/show_label/"" and true for a subckt type.
3. **`match` matchers** — for each mode against a small value set:
   - default: `clk` matches `clk` only (whole-string), not `clk2`, not `CLK`.
   - wildcard: `*_port*` matches `v_port1`, not `port`; `d?` matches `d0` not `d10`.
   - regex: `v.*_port[12]` matches `vx_port1`/`vy_port2`, not `v_port3`.
   - exact: `clk` matches `clk` only, case-sensitive (not `CLK`).
   - contains: `<` matches `a<3>`, `port` matches `clk_port_a`, not `clk`.
   - nocase: `clk` +nocase matches `CLK`, `Clk`; folds default/contains/exact; regex+nocase works.
4. **`link` auto-uncheck** — set all mode vars on, then `link wildcard` clears regex,exact (keeps
   nocase); `link regex` clears wildcard,exact keeps nocase; `link exact` clears wildcard,regex,
   contains,nocase; `link contains` clears exact; `link nocase` clears exact; `link add` clears sub;
   `link sub` clears add. (Sabotage: dropping any pair ⇒ fails.)
5. **`order_by_screen`** — horizontal row `{a 0 0}{b 100 0}{c 50 0}` (xspread>yspread) → `a c b`
   (ascending X); vertical column `{a 0 0}{b 0 100}{c 0 50}` (yspread>xspread) → top-first order
   (locked by the fixture's chosen Y convention); tie `{a 0 0}{b 10 10}` → horizontal fallback;
   single element → itself; no-dedup: `{a 0 0}{a 100 0}` → `a a`.
6. **`build_summary`** — given a set of vars, returns the expected summary string (object, name,
   active modes in canonical order, scope, and the `rename:`/`report` suffix when set); empty Name
   omits `name=`; no-goto off shows a goto marker. (Sabotage: reorder tokens ⇒ fails.)
7. **`snapshot`/`apply_state`** — snapshot captures all 16 `statevars`; `apply_state` of a snapshot
   restores each var exactly; round-trip identity.
8. **History snapshot/recall + dup-collapse** — push A, push A (collapsed: length 1), push B (length
   2); `history_up` from parked recalls B then A and clamps at oldest; `history_down` walks newer and
   clamps at parked; `histlabel` text at each position (`2 / 2`, `1 / 2`, `2 saved`).
9. **From/To injection safety** — `do_rename`'s regsub is fed a From/To containing `[ ] { } $`
   literally (as data): assert `regsub -all -- {a[0]} {a[0]b} {X}` style cases produce the expected
   string and never error/`eval` — the transform is `regsub`, not `subst`. (Unit-test the transform
   helper directly with pathological From/To.)

### Section B — loaded-fixture units (in-memory schematic)

Fixture built with `xschem clear force` then `xschem instance <sym> x y 0 0 {name=… lab=…}` for a
mix: two ipin ports (`lab=clk_in`, `lab=clk_out`), one lab_pin netlabel (`lab=data0`), two component
instances (e.g. `name=R1`, `name=R2`), placed at known coords for ordering.

10. **collect by type** — Object=port + empty Name + scope=view → exactly the two ipin indices;
    Object=netlabel → the lab_pin index; Object=instance → the R1/R2 indices; components excluded
    from port, ports excluded from instance.
11. **collect by pattern** — Object=port, Name=`clk*`, wildcard → both; Name=`clk_in`, exact → one;
    Name=`IN`, contains+nocase → clk_in.
12. **`-first`** — Name=`clk*` wildcard + first → exactly one index.
13. **Selection actions** — replace: after run with no add/sub/count, `xschem get lastsel` == match
    count and `selected_set` == the matched instnames; add: pre-select R1, run add of ports →
    lastsel grows; sub: select all, run sub of ports → ports removed; count: lastsel unchanged,
    Status shows N.
14. **Rename (port, `lab` token)** — Object=port, Name=`clk*` wildcard, From=`clk`, To=`CK` → run;
    assert `getprop instance <i> lab` == `CK_in`/`CK_out`; `hits` has both `old -> new`; Status
    `2 found, 2 renamed, 0 failed`; ONE undo restores both (`xschem undo; getprop … lab` == originals).
15. **Rename (instance, `name` token)** — Object=instance, Name=`R*` wildcard, From=`^R`, To=`RES`
    → `getprop instance <i> name` starts `RES…`; index stability across the sweep.
16. **Report-only (From empty, Report on)** — no name changes; `hits` lists current matched names.
17. **Empty-To delete** — From=`_in$`, To=`` on `clk_in` → `clk`.
18. **FAILED path** — force a duplicate/illegal `setprop` (rename two ports to the same name) →
    the collision lands in `fails`, the other in `hits`, run continues; Status shows `… 1 failed`.
19. **scope=selection** — pre-select one port, Object=port empty Name scope=selection → collect
    returns only that one index (not the unselected sibling port).
20. **hierarchy guard** — scope=hierarchy → run refuses (red Status, no mutation: instances/labels
    unchanged); list_names refuses too.
21. **readonly guard** — `xschem set readonly 1` → run refuses, no mutation.
22. **symbol-view guard** — load a tiny `.sym` fixture → run/list refuse with the symbol-view
    message.
23. **list_names end-to-end** — Object=port empty Name on the horizontal-row fixture → Results CSV
    equals the screen-ordered names; Status `N listed`; no selection change, no history push.

### Sabotage checks (green-but-hollow guard)

- Break `name_token` (always `name`) ⇒ port/netlabel rename tests (14,16,17) fail.
- Make `type_ok` always true ⇒ collect-by-type test (10) fails (components leak into port).
- Drop `-first` handling ⇒ test 12 fails.
- Remove the dup-collapse ⇒ history test 8 (length 1 after A,A) fails.
- Make the hierarchy/readonly/symbol guards no-ops ⇒ tests 20/21/22 mutate and fail.
- Flip `order_by_screen`'s spread comparison ⇒ test 5 horizontal/vertical cases fail.

---

## Out-of-scope / DEFER (with receipts)

- **Hierarchy scope (Run/List).** DEFER — no Xschem cross-sheet find/`-modify` primitive; a Tcl loop
  sees only the current sheet (scout: "There is no -scope hierarchy equivalent"). Refused at runtime,
  not silently degraded. Revisit only if a hierarchy-iteration verb is added in C (separate batch).
- **Verbatim re-runnable Command string.** DEFER — Xschem has no single `find` verb to echo; the
  Command box is a summary. A future "emit an `xschem`-script equivalent" is possible but unneeded.
- **Cross-session persistence** of form state and history (reference already lists as future).
- **Live dry-run preview** (highlight matches before committing a rename).
- **Choosing the rename target property** (always Name / `name`/`lab`).
- **Optional `-nocase` on the regsub substitution** and **List de-duplication** (`-unique`) — both
  reference-listed futures, preserved as out-of-scope.
- **Symbol-view operation** (ports/labels are pin RECTS there — a different data model; the sibling
  symbol-pin editor path handles that).
- **No C changes in this batch** — if any of the above requires a new scheduler verb, it is deferred
  with a receipt rather than adding a `scheduler.c` branch here (pure-Tcl discipline).
