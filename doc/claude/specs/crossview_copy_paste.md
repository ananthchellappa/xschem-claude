# Cross-view copy/paste: pin transformation between schematic and symbol views

Status: v1 spec, 2026-07-19. Owner: fluid-editing branch.

## What

Copy objects in one view type, paste into the other view type; pins transform
automatically:

- schematic → symbol: `devices/ipin.sym` / `opin.sym` / `iopin.sym` **instances**
  become PINLAYER **pin rects** (with owned name text, per
  cadence_pin_name_text.md Option B) at the instance origin.
  dir mapping: ipin→`in`, opin→`out`, iopin→`inout`.
- symbol → schematic: PINLAYER rects carrying `name=` and `dir=` become
  `devices/ipin|opin|iopin.sym` instances (`lab=<name>`, rot 0 flip 0) at the
  rect center. dir mapping reversed.

Normal paste (Ctrl+V / `xschem paste`) auto-detects; no new binding. The pasted
selection stays cursor-attached exactly like any paste (STARTMERGE +
move_objects), relative positions preserved, user drops anywhere.

Cadence has no equivalent; the productivity target is syncing pin lists between
views without retyping.

## Scope (v1, user-ratified 2026-07-19)

- **Pins only** transform.
- Graphics (L line, B non-pin rect, A arc, P poly, T text) pass through
  unchanged in both directions.
- Skipped with a CIW message (cross-view paste only):
  - schematic → symbol: wires (`N`), non-pin instances (`C`), `lab_pin`/
    `lab_wire` net labels (they are labels, not ports).
  - symbol → schematic: nothing needs skipping (pin rects transform, everything
    else in a symbol is graphics and passes).
- **Duplicate names: paste anyway.** If the destination view already has a pin
  named X, the incoming X is *type-coerced* to the existing pin's direction
  (symbol dest: `dir=` forced; schematic dest: ipin/opin/iopin symbol swapped)
  and a CIW warning names each coerced pin. The duplicate itself is allowed —
  placement is the user's call; ERC flags real conflicts later.
- Source instance rot/flip is ignored (pin rects are square; name-text layout
  uses create_pin defaults). Symbol→schematic instances place at rot 0, flip 0.

## Mechanism

### Source-view marker (clipboard format)

`save_selection()` writes one comment line right after the `G` record:

    #XSCHEM_CLIPBOARD_VIEW=symbol|schematic

decided by `editing_symbol_view()` at copy time. `#` lines are already
discarded by every loader (`merge_file` `'#'` case, `read_record` default), so:

- old xschem reading a new clipboard: ignores the line — no format break;
- new xschem reading an old clipboard (no marker): source view unknown →
  **no transform**, legacy behavior (this is the compatibility default).

### Transform (paste time, inside merge_file)

`merge_file()` keeps a per-call `src_view` (unknown/schematic/symbol), captured
when the `'#'` case sees the marker (marker precedes all object records by
write order). Transform is armed iff `src_view` is known and differs from the
destination (`editing_symbol_view()`); `selection_load==2` (clipboard) and the
`-file`/script forms all pass through the same loop, so all paste entry points
behave identically. Same-view paste and Merge-file of ordinary schematics are
byte-for-byte untouched.

With transform armed, two record cases divert:

- dest = symbol, `'C'` record → `merge_inst_as_pin()`: parse the same fields
  merge_inst parses; if basename is ipin/opin/iopin.sym → `create_pin(x0, y0,
  lab, dir, SELECTED)` (owned name view included; synth_pin_views + the
  existing post-loop view-selection block in merge_file already handle
  selection/regeneration). Else: count-skip. `lab` read from the instance
  prop's `lab=` token.
- dest = symbol, `'N'` record → parse + count-skip (wires are meaningless in a
  symbol body).
- dest = schematic, `'B'` record → `merge_box_as_pin_inst()`: parse the same
  fields merge_box parses; if layer==PINLAYER and prop has nonempty `name=` and
  `dir=` → place a pin instance at the rect center (merge_inst-equivalent
  storage: name resolve, `name=p1 lab=<name>` prop, new_prop_string uniquify,
  hash_names, inst_register, SELECTED). Else: fall through to normal merge_box.
- dest = schematic, `'T'` record: passes through (real texts). Synthesized pin
  name views must never be in the clipboard — see save_selection fix below.

Type coercion scans only *pre-merge* destination objects (index < the count
snapshotted at merge start), so multiple pins inside one paste don't coerce
each other.

### save_selection synthesized-view leak (bug fix rider)

The P1 S3 invariant says synthesized pin-name views never persist, and
merge_file's P4 comment assumes the clipboard has none — but `save_selection()`
writes every selected text with no `owner_pin_id` skip, so copying a shown pin
in a symbol view leaks its name view into the clipboard (double-text on paste
back into a symbol; stray text on paste into a schematic). Fix: skip
`owner_pin_id` texts in save_selection's xTEXT case. RED test covers it.

### CIW report

After the merge loop, when transform was armed and anything was converted /
skipped / coerced, one `ciw_echo` line (guarded by `info procs ciw_echo`, the
util.c:428 pattern):

    # cross-view paste: <n> pin(s) converted, <m> object(s) skipped, <k> dir-coerced (<names>)

### Interactions

- undo: merge_file's existing push_undo covers the whole paste; ESC abort
  deletes the merged (converted) selection via the existing STARTMERGE path.
- read-only: `xschem paste` is already readonly-rejected at the boundary;
  Ctrl+V routes through the same gate.
- action log: unchanged — paste drop logging (end_move_copy_logged / the
  scripted `xschem paste dx dy` coordinate form) already replays merge_file
  against the same clipboard file, and the transform is deterministic given
  clipboard + destination view, so replay reproduces the transform.
- empty conversion result (everything skipped): merge_file's existing
  lastsel==0 branch clears STARTMERGE; no dangling gesture.

## Non-goals (v1)

- wires→lines transform, lab_pin→pin promotion (ratified out).
- Update-in-place sync of existing pins (position-preserving dir/name update);
  the coercion rule above is the only destination mutation.
- Pin-ness by symbol `type=` attribute (would need symbol load at parse time);
  v1 matches ipin/opin/iopin basenames. Custom pin symbols don't transform —
  they count as "skipped instance".
- rot/flip-aware name-text layout for converted pins.

## Files

- src/save.c: save_selection — marker line + owner_pin_id skip.
- src/paste.c: merge_file src_view capture + the two divert helpers + CIW tally.
- tests/headless/test_crossview_paste.tcl (registered in tests/run_regression.tcl
  hcases): RED-first, cases enumerated in the test file header.
