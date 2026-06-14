# Spec — multi-instance property editing (Cadence-style)

*Status:* **P1 IMPLEMENTED (2026-06-13) — default-fix + sticky "Apply to" scope +
name-greying, changed-fields-only for all scopes. Next: P2 (Apply button +
Next/Prev, needs the mid-session `apply_properties` command), then P3
(varying-value warning); highlighting backlogged.** Key decisions ratified
(2026-06-14). Builds on the slick per-field property form ([[slick-property-forms]],
branch `slick-property-forms`) and the stable instance handles
([[stable-object-handles]]). Highlighting (§3 deferred) is explicitly **backlog**,
out of scope for this round.

*Summary:* when several instances are selected and the user opens the Properties
form, give Cadence-grade support: a **Next / Prev** walk through the targets, an
**"Apply to"** scope (Only Current / All Selected / All), automatic **greying of
attributes that cannot apply to many** (e.g. `name`), and **on-canvas
highlighting** that distinguishes *selected* from *being-edited* and reflects the
current scope live.

---

## 1. What happens today (verified in the code)

When you select N instances and invoke Edit Properties (`xschem edit`, key `Q` →
`edit_property(0)`, `editprop.c:1157`):

1. The selection array is rebuilt; the **first** selected object decides the type
   (`set_first_sel`, `editprop.c:1288`). For instances it calls
   `edit_symbol_property(x, j)` on that **first** instance only.
2. If more than one object is selected, **`preserve_unchanged_attrs` is forced on**
   (`editprop.c:1282`). The dialog opens showing the **first** instance's
   properties (via the slick form → `slickprop::edit_form`, which sets
   `tctx::retval` to that instance's string).
3. On **OK**, `update_symbol()` (`editprop.c:834`) **loops over every selected
   instance** (`for(k=0;k<xctx->lastsel;++k)`, `:885`) and, because
   `preserve_unchanged_attrs` is on, applies only the **changed** tokens to each:
   `set_different_token(&inst.prop, new_prop, old_prop)` — "modify only the token
   values that differ between *new* and *old*" (`token.c:204-207`), where *old* is
   the **first** instance's original string. Each instance keeps its own other
   attributes. Per-instance unique-name enforcement then runs (`:948` ff).

**So the effective behavior today is "All Selected, changed-fields-only" — but
with no UI for it:** the user is silently editing the first instance, can't tell
they're affecting N, has no scope choice, no navigation, no greying, and the
canvas highlight doesn't change. (There is a niche `edit_symbol_prop_new_sel`
chain-loop at `:1295` that re-edits the next mouse-clicked instance; the slick
form does not drive it.)

### 1.1 The good news: the apply engine already exists

The hard part — "apply the fields I changed to a set of instances, preserving
each one's other attributes" — is already built and battle-tested
(`set_different_token` + the `update_symbol` loop). This dovetails exactly with
the slick form's model: the form already tracks **dirty fields** and emits
`new_prop` = first-instance + my edits (subst-into-original). `set_different_token`
then extracts precisely those edits and fans them out. **This feature is therefore
mostly a UI + scope-selection + highlighting layer over an engine that already
does the work** — not a new editing core.

---

## 2. The gap vs. Cadence

| Cadence capability | xschem today |
| --- | --- |
| Next / Prev through the target instances | — (edits the first only) |
| "Apply to": Only Current / All Selected / All | partial: implicitly "All Selected, changed-only" when >1, no control |
| Grey attributes that can't apply to many (name…) | — (relies on per-instance unique-name fixups after the fact) |
| Canvas highlight: *selected* vs *being-edited*, scoped, live | — (selection highlight only, static) |

---

## 3. Desired behavior

**Throughout: only the CHANGED fields are ever applied.** None of the scopes make
the instances' properties identical — they each receive only the tokens the user
edited (the dirty fields), keeping every other attribute of their own. This is
already exactly what the engine does (`set_different_token`, §1.1).

### 3.1 "Apply to" scope selector — and the default-behavior FIX

A dropdown in the form header, three modes:

- **Only Current** — changes apply to the one instance currently shown.
- **All Selected** — changed fields apply to every selected instance.
- **All** — changed fields apply to **all instances of the same cell / symbol /
  master in the current schematic window** (resolved §6.A). Different masters are
  never touched.

**FIX REQUIRED (behavior change):** today xschem *forces* "All Selected" whenever
more than one object is selected (`editprop.c:1282` sets
`preserve_unchanged_attrs=1`). That must stop. The **"Apply to" setting is the
sole authority**, it **retains its state** across form invocations (a sticky
session variable, e.g. `::slickprop_apply_scope`), and its initial default is
**Only Current** (the safe choice — opening the form on a multi-selection must not
silently edit them all). Selecting N instances no longer implies editing N; the
user opts in via the dropdown, and the choice persists.

Scope governs **which instances an Apply / OK touches**; it does not change what
the form *displays* (that is Next/Prev, §3.2).

### 3.2 Next / Prev navigation

Two buttons (and ideally `Alt+Right`/`Alt+Left`) that step the **displayed**
instance through the **selected** set, with a position readout ("2 of 7"):

- **Prev is greyed/disabled when the current instance is the first** of the
  selected set; **Next is greyed when it is the last.**
- Navigating **discards** any unapplied edits on the instance you leave (the
  change set belongs to the displayed instance; you commit it with Apply/OK — see
  §3.5). The new instance is shown with its own current values. *(Minor open
  point §6.B': warn before discarding vs silent — recommend silent for v1, the
  modified dots make pending edits visible.)*

### 3.3 Greying attributes that can't apply to many

When the scope is **All Selected** or **All**, attributes that are inherently
per-instance are shown **disabled (greyed, read-only)**:

- **`name`** always (instance names must be unique — applying one name to many is
  meaningless and the engine would have to uniquify anyway).
- Any attribute the symbol marks as per-instance (a future template hint, e.g.
  `unique=name,...`); for v1 a built-in rule covering `name` is enough.

A greyed field is excluded from the change set, so each instance keeps its own.
When the scope returns to **Only Current**, the fields re-enable.

### 3.4 Buttons — OK, Apply, Cancel

- **OK** — apply the current change set to the scope, then **close**.
- **Apply** — apply the current change set to the scope, **stay open** (NEW). This
  is what makes stepping through the set useful: with Next/Prev you can land on an
  instance, edit, **Apply** (or not), move on, all without losing the form.
- **Cancel / Esc** — close, applying nothing pending.

After an Apply, the displayed instance's applied values become its new baseline
(dirty dots clear). Each Apply (and the OK apply) is its **own undo entry** (§3.6).

### 3.5 "Values differ" warning in the status line

The footer status line (normally the muted `Enter: OK   Esc: Cancel` hint) turns
into a **red warning** when, under **All Selected / All**, the focused field's
value is **not the same across all instances in scope** — telling the user that
applying it will overwrite those differing values. The warning is contextual to
the focused field and clears when the field's value is uniform across the set or
the scope is Only Current. (A per-field marker — e.g. a muted `<*>` hint — may
also flag varying fields at a glance; the red status text is the required part.)

### 3.6 Undo granularity

Each apply action is independently undoable:

- **One Apply (or OK) with scope = All Selected / All** → a **single** undo entry
  that reverses the change across *all* affected instances at once.
- **Stepping through with Next/Prev and applying per instance** → a **separate**
  undo entry per Apply; undo reverses only the most recent, on the last instance
  edited.

The engine already pushes exactly one undo per `update_symbol` call (the `pushed`
guard, `editprop.c:901/911`), so each Apply maps to one undo naturally.

### (Deferred) On-canvas highlighting — BACKLOG, out of scope for now

The "cool factor" of distinguishing *selected* vs *being-edited* on the canvas
(and reflecting the scope live) is **parked on the backlog** at the user's
request and is **not** part of this round of code changes. Sketch retained for
later: a transient C "edit-scope" overlay drawn beside `draw_selection`,
referencing instances **by stable id**, updated as scope/navigation change. See
§6.E for the styling questions when it is picked up.

---

## 4. How it maps onto xschem's architecture

- **Form (Tcl, `slickprop::`).** Owns the scope dropdown, Next/Prev, the
  position readout, the greying, and the per-instance display. It already has the
  dirty-field model (the change set) and the field grid. New state: the target
  list (the selected instances, by **stable instance id** so it survives any
  reindexing — leveraging [[stable-object-handles]]), the current index, the scope.
- **Apply (C, `update_symbol`).** The core (`set_different_token` per instance) is
  reused, but two structural changes are needed:
  - **The default-behavior fix (§3.1).** Remove the unconditional
    `preserve_unchanged_attrs=1` for multi-selection (`editprop.c:1282`). The
    scope now comes from the sticky setting, and `preserve_unchanged` is always
    effectively on (changed-fields-only is the contract for *every* scope).
  - **A mid-session apply path for the Apply button.** Today the apply happens
    only **after** the dialog closes (`edit_symbol_property` reads the result post
    `edit_prop`, then calls `update_symbol`). The **Apply** button (apply without
    closing) and the per-instance OK model require applying **while the dialog is
    open**, possibly several times. So the `update_symbol` logic must be wrapped
    in a **Tcl-callable command**, e.g.
    `xschem apply_properties <scope> {<inst-id> …} <new_prop> <old_prop>`, that the
    form invokes on Apply and on OK. It takes the **target id list** (Only Current
    = the displayed id; All Selected = the selected ids; All = the same-master ids)
    + the change (new vs old prop) and applies `set_different_token` to each
    target, pushing one undo. OK = call it, then close; Cancel = never call it.
    Targets referenced **by stable instance id** (the [[stable-object-handles]]
    work) so they survive any reindexing between applies.
- **Highlight (C draw).** Backlogged (§3 deferred). When picked up: a transient
  C "edit-scope" overlay drawn beside `draw_selection`, fed the current + in-scope
  ids by the form.

---

## 5. Phasing (incremental, each shippable)

1. **P1 — the default-fix + "Apply to" + greying.** Remove the forced
   all-selected default (§3.1); add the sticky "Apply to" dropdown (Only Current /
   All Selected / All) governing the target set; grey `name` when scope is multi.
   Wrap the apply in the mid-session command (§4). Small, high-value, and it fixes
   a real surprise (silently editing N).
2. **P2 — Apply button + Next/Prev.** The Apply-without-close button; Next/Prev
   walking the selected set with the "k of N" readout and first/last greying;
   the navigation-discards-pending model (§3.2). Per-Apply undo (§3.6).
3. **P3 — "values differ" warning.** The red status-line warning (and optional
   per-field marker) when a focused field varies across the in-scope set (§3.5).
4. **(Backlog) — highlight.** The on-canvas edit-scope overlay — explicitly out of
   scope for now.

## 6. Decisions (ratified 2026-06-14) & remaining minor points

- **A. RESOLVED — "All" = all instances of the *same cell/symbol/master* in the
  current schematic window.** Different masters are never touched.
- **B. RESOLVED — change set belongs to the displayed instance; committed by
  Apply/OK to the scope.** Navigating away without Apply discards pending edits.
  If the user steps to another instance (no Apply), edits it, and presses OK, only
  that instance is updated — and an **Apply button** exists so you can apply while
  stepping without closing. (Undo follows from this — §3.6 / D below.)
- **C. RESOLVED — yes, warn on varying values.** Red text in the status line when
  the focused field differs across the in-scope set (§3.5).
- **D. RESOLVED — undo is per apply action.** One All-Selected/All Apply = one
  undo across all affected; per-instance stepping = one undo each, reversing the
  most recent. (Engine's `pushed` guard already gives one undo per
  `update_symbol`.)
- **E. (Open, but backlogged with the highlight)** highlight styling/colors.
- **F. Greying source.** Hardcode `name` for v1 vs a symbol-template `unique=…`
  hint for symbols to declare extra per-instance attributes — *minor, decide at
  build.*
- **B'. (Minor)** warn-before-discard vs silent on navigation with unapplied edits
  — recommend silent for v1 (the modified dots already flag pending edits).

## 7. Grounding (code references)

- Dispatch + multi-select handling: `edit_property` `editprop.c:1157`, the
  `lastsel>1 → preserve_unchanged_attrs` force `:1282`, the type switch `:1291`,
  the chain-edit loop `:1295`.
- The apply engine: `update_symbol` loop `editprop.c:885`, `set_different_token`
  `token.c:204-207`, unique-name fixups `editprop.c:948`.
- The form: `slickprop::edit_form` / dirty-field model (`src/property_form.tcl`),
  the C↔Tcl contract (`tctx::retval`/`tctx::rcode`, `symbol`,
  `no_change_attrs`/`preserve_unchanged_attrs`).
- Selection highlight: `draw_selection` `move.c:210`, drawn with `gc[SELLAYER]`.
- Stable instance ids (for referencing targets across edits / in the highlight
  command): `xschem instance_id`/`instance_index`, `xschem object instance @id`.

---

*Decisions are ratified (§6). Recommended next step: implement **P1** on the
`slick-property-forms` branch — the default-behavior fix (stop forcing
all-selected), the sticky "Apply to" dropdown (Only Current / All Selected /
All-same-master), `name`-greying when scope is multi, and the mid-session
`apply_properties` command — then P2 (Apply button + Next/Prev) and P3 (varying-
value warning). Highlighting stays on the backlog.*
