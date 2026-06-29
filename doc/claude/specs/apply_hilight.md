# Spec — apply_hilight: one-shot "apply my favourite highlight style"

Status: IN PROGRESS 2026-06-28. Pure Tcl, no C changes. Builds on the existing
`net_hilight_apply` (src/xschem.tcl) and the net-highlight-styles table.

## What already exists

`net_hilight_apply {styledef} [net …]` (xschem.tcl:627) already:
- takes a **literal positional** style row `{idx color width dash angle blink anim rate}`
  (short rows are filled with defaults by `net_hilight_style_norm`),
- installs it once, reusing an identical existing row (no table bloat), returns its index,
- applies it to the **current selection** (noun-verb) or to **named nets**.

So the noun-verb + literal case is done. This spec adds the two missing pieces the user
asked for, as a friendly wrapper `apply_hilight`.

## Motivation

One shortcut to apply a favourite highlight style at any time:
- **Something selected (net/wire/pin/label):** style it immediately (noun-verb).
- **Nothing selected:** prompt the user to pick — a single click or a click-drag
  rubber-band (multiple) — then apply the style and finish. It is **once-and-done**, it
  does NOT stay in a click-to-highlight mode until Esc.
- The style may be given **positionally** (as today) or with **named fields** in any
  order, omitted fields defaulting, e.g.
  `apply_hilight {color="blue" pattern={10 20} thickness=10}`.

## Behavior (normative)

### Style argument — three accepted forms (auto-detected)
1. **Named `key=value`** (the user's form): the arg contains `=`. Tokens
   `key=value`, value optionally `"quoted"` or a `{brace list}`, e.g.
   `color="blue" pattern={10 20} thickness=10`.
2. **Named dict** (native Tcl): first element is a known field name, even length, e.g.
   `{color blue thickness 10 pattern {10 20}}`.
3. **Positional list** (existing): e.g. `{4 purple 3 {20 20} 0 1200 none 0}` (or shorter).

Field names → columns (aliases accepted), defaults from
`net_hilight_style_default_row` (`{_ 4 1 {} 0 0 none 0}`):

| field (aliases) | column | default |
|---|---|---|
| `color` | 1 | 4 (a layer) |
| `thickness` / `width` | 2 | 1 |
| `pattern` / `dash` | 3 | {} (solid) |
| `angle` | 4 | 0 |
| `blink` | 5 | 0 (ms) |
| `march` / `anim` | 6 | none (`none`/`march_fwd`/`march_rev`) |
| `rate` / `speed` | 7 | 0 |

Parsing yields an 8-column row (index placeholder 0) that `net_hilight_apply` then
normalises and installs.

### Application
- **`apply_hilight {style}`** with a selection that contains a wire or a pin/net-label →
  `net_hilight_apply $row` (immediate, no cursor advance, dedup). Confirmation to CIW.
- **with no applicable selection** → enter the one-shot prompt: remember the row, show a
  status/CIW prompt; the user's next click or rubber-band selection that lands on a
  net/pin/label gets the style applied and the prompt ends. **Esc cancels.** Clicking
  empty space keeps waiting.

### One-shot prompt mechanics (Tcl, no modes in C)
- A namespaced pending var holds the row while armed; it is "" otherwise.
- A single `+`-appended `<ButtonRelease>` handler on `.drw` (gated by the pending var,
  so inert normally; appended once, never shadows the existing `xschem callback`
  binding) fires after the normal selection completes, and — `after idle` — if the new
  selection contains a net/pin/label, applies the style, clears the prompt and unselects.
- A `+`-appended `<KeyPress>` handler clears the pending var on `Escape`.
- Targets the main canvas `.drw` (consistent with the other cadence rc binds).

## Files

- `utils/apply_hilight.tcl` (new): `aphl::parse`, `aphl::sel_has_net`, `apply_hilight`,
  the one-shot prompt procs + the two gated bindings.
- `src/cadence_style_rc`: source it + an **example** favourite-style key bind (template
  the user edits).
- `tests/apply_hilight.tcl` (new): RED-first.

## Test

`tests/apply_hilight.tcl` (headless): the parser across all three forms (named=, dict,
positional; aliases; omitted→default), and integration — select a net label, run
`apply_hilight`, confirm the style is installed in the table and the net is highlighted
(re-select via `xschem select_hilight_net`, expect a non-empty selection). The verb-noun
one-shot prompt (mouse-driven) is GUI-verified.
