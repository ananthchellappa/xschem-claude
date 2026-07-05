# Spec — ALT-SHIFT-C: capture lib/cell/view to the clipboard + CIW

Status: IN PROGRESS 2026-06-28. Pure Tcl, no C changes. Joins the Cadence-style
shortcut family (`src/cadence_style_rc`, `utils/`), alongside Ctrl-Alt-S "locate in
Library Manager", which it closely mirrors.

## Motivation

A Cadence-style convenience: copy the identity of what you are looking at as a
`lib/cell/view` string so it can be pasted elsewhere (a note, an email, another tool).
The user wants one chord, **ALT-SHIFT-C**, that does the right thing for the current
selection and both copies to the X clipboard and prints the string to the CIW log.

## Behavior (normative)

`ALT-SHIFT-C` branches on the selection (identical selection model to Ctrl-Alt-S):

- **one instance selected** → the instance master's `lib/cell/view`
  (`xschem get_inst_lcv` → `{lib cell view}`), joined with `/`.
- **one text object selected** → the **first** `a/b/c…` slash path (≥ 2
  forward-slash-separated `\w` components) found anywhere in the note text. This lets a
  note like `place at amp/stage1/M3` yield `amp/stage1/M3`.
- **nothing selected** → the currently open cellview's `lib/cell/view`
  (`schematic_cellview [xschem get schname]` → first three elements).
- **anything else** (multiple objects, or a single non-instance/non-text) → an error
  line in the CIW explaining the valid selections; nothing copied.

In every success case the resulting string is placed on the clipboard
(`clipboard clear` + `clipboard append`) **and** echoed to the CIW
(`ciw_echo "copied to clipboard: …" result`) so the user has both a paste buffer and a
visible record.

## Implementation

- **`utils/cadence_clip.tcl`** (new), sourced from `cadence_style_rc`:
  - `cadence::clip_put {s}` — clipboard set + CIW echo (single sink).
  - `cadence::first_slashpath {text}` — first `\w+(?:/\w+)+` match, or `{}`. (Distinct
    from `cadence::deeppath_from_text`, which anchors at `^` for the descend chord;
    here we want the first path *anywhere* in the note.)
  - `cadence::capture_lcv` — the dispatcher above, reusing `cadence::selkind`,
    `xschem get_inst_lcv`, and `schematic_cellview`.
- **`src/cadence_style_rc`**: `bind .drw <Alt-Shift-Key-C> {cadence::capture_lcv; break}`.
  Note the same Shift-keysym gotcha documented for Ctrl-Shift-2 / Ctrl-Shift-N: with
  Shift held the `c` key emits the **capital** `C` keysym, so the bind is on `Key-C`.

## Test

`tests/cadence_clip/` headless unit test for the pure parsing/formatting procs
(`first_slashpath` cases, `clip_put` building the right string). The selection
branching and the live clipboard are GUI-verified.
