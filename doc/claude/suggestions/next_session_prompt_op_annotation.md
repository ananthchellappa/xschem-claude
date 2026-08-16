# Next session — OP annotation on the schematic, in atomic steps

Paste everything below the line as the opening prompt of a fresh session.

Every measurement quoted below was taken on branch `annotate` (branched from
`fluid-editing`) with the installed `/usr/bin/ngspice` and the in-tree
`src/xschem`. Re-run the probes before trusting a number if more has landed.

---

Implement `doc/claude/specs/op_annotation.md`. **Read that spec in full first** —
especially §3 (the three measured ngspice rules), §4.2 (the PDK descriptor),
§5 (invariants I1–I7) and §6 (landmines).

Also read, before touching anything:

- `ihp-sg13g2/sg13g2_procs.tcl` lines **304–505** — the working single-PDK
  prototype. `sg13g2_write_save_lines`, `sg13g2_sch_expand`/`_hier_sch_expand`,
  `sg13g2_save_params`, `sg13g2_display_fet_params`, `sg13g2_raw_or_double`.
  This is not inspiration, it is the reference implementation to generalize;
  ported line by line it removes most of the risk from S3 and S5.
- `ihp-sg13g2/xschem_libs/sg13g2_pr/annotate_fet_params/symbol/annotate_fet_params.sym`
  — the carrier symbol, 11 lines.
- `ihp-sg13g2/sg13g2_procs.tcl` lines **585–655** — how the IHP menu wires all of
  it up, including the "place annotator pre-filled from selection" idiom.
- `doc/claude/code_analysis/waveform_subsystem_reference.md` §6.

Branch is `annotate`. Number new issues from **0418** (0417 is the highest taken).

---

## Ground rules for this work

- **I1 above everything.** One name builder (`op_annot::vector`), two consumers
  (save cards, display). The moment they diverge the failure is silent.
- **I3.** A vector that is not in the raw renders **blank**. Not `0`, not `NaN`
  on screen, not the previous run's number. `save.c`'s RULING D5-1 is the
  precedent and the reason.
- Steps S1–S6 are **pure Tcl and data**. No C, no rebuild. Land them first; they
  are what turns tb_bandgap's `-` into numbers.
- Do not start S9 before S7 lands — the overlay with no mask to gate it is a
  screenful of text nobody can turn off.
- Per CLAUDE.md: do not run `make` while subagents are fanned out (~7.8 GB box).

---

## S1 — the core namespace and the name builder

**Files:** new `src/op_annot.tcl`; sourced from `src/xschem.tcl` alongside the
other loadable helpers.

**Deliver:**

```tcl
namespace eval op_annot {}
op_annot::register <symbol-type> <dict>     ;# stores/overrides a descriptor
op_annot::descriptor <symbol-type>          ;# -> dict or {}
op_annot::devpath <instname>                ;# -> "@m.x1.xm1.msky130_fd_pr__nfet_01v8"
op_annot::vector <instname> <param> <kind>  ;# -> "i(...)" / bare / "v(...)"
```

`devpath` expands the descriptor's `devpath` template with
`xschem translate <inst> <template>` (so `@name`, `@model`, `@spiceprefix` work)
and `$path` from `xschem get sim_sch_path`; or calls `devproc` when the
descriptor has one. `vector` applies the kind wrapper (`0` → `i(…[p])`, `1` →
bare `…[p]`, `2` → `v(…[p])`) — the `get_fqdevice()` convention, spec §3 R3.

**Acceptance:** with no schematic loaded, `op_annot::register` + a stubbed
instance yields the exact strings ngspice writes. Golden strings to match,
measured from real raw headers:

```
sky130 nfet_01v8, inst M1 (spiceprefix X) at path x1. :
  gm    -> @m.x1.xm1.msky130_fd_pr__nfet_01v8[gm]
  id    -> i(@m.x1.xm1.msky130_fd_pr__nfet_01v8[id])
  vdsat -> v(@m.x1.xm1.msky130_fd_pr__nfet_01v8[vdsat])
```

**Risk:** low. **Blocks:** everything.

---

## S2 — the three PDK descriptors

**Files:** `sky130A/sky130_procs.tcl`, `gf180mcuD/…_procs.tcl`,
`ihp-sg13g2/sg13g2_procs.tcl` (add registrations; leave the existing sg13g2
procs alone for now).

Descriptors are written out in spec §4.2 — copy them. The IHP one must reproduce
`sg13g2_write_save_lines`' ten FET parameters and thirteen NPN parameters
exactly, including the `_5t` model-suffix strip via `devproc`.

**Acceptance:** for the IHP `dc_lv_nmos` test cell, `op_annot::vector` reproduces
every line `sg13g2_write_save_lines` emits, byte for byte. That diff being empty
is the proof the generalization lost nothing.

**Risk:** low, but it is where every PDK naming quirk shows up. Landmines §6.2
and §6.3.

---

## S3 — hierarchy walk and save-card generation

**Files:** `src/op_annot.tcl`.

Port `sg13g2_sch_expand` / `sg13g2_hier_sch_expand` into
`op_annot::save_cards {}`, de-prefixed and descriptor-driven: visit every
instance, look up its symbol `type`, emit one `save <vector>` per `params` entry.
Skip `pinexpr` and `derived` (nothing to save). **Prepend `save all`** — spec
rule R2, measured: without it the node voltages vanish from the raw.

**I6 is the whole risk of this step.** The walk sets `no_draw 1`, `no_undo 1`,
`keep_symbols 1` and descends the *real* design. Every exit path — including the
"could not descend into a blank schematic" path the IHP prototype already
handles — must restore all three and the original `sch_path`.

**Also deliver** a menu item, modelled on IHP's "Create FET and BIP .save file":
write the block to `$netlist_dir/<cell>.save` and open it in a text window. That
gives non-ASE users the feature immediately, by `.include`.

**Acceptance:** 3-level test design, card list golded; a test asserting
`no_draw` / `no_undo` / `keep_symbols` / `sch_path` are all back to their
entry values afterwards, including after a forced mid-walk failure.

**Risk:** medium — the walk is the only destructive thing in S1–S6.

---

## S4 — ASE carries the cards into the deck

**Files:** `src/ase.tcl` (state schema + `render_deck`), `src/ase_window.tcl`
(the Outputs → Save All dialog).

New state key `save_op_params`, default `0`, in the same group as
`save_all_v` / `save_all_i`. When set, `render_deck` appends
`op_annot::save_cards` output after the `.save all` line (`ase.tcl:3162`).
Add the checkbox to the Save All dialog (`ase_window.tcl:2854`).

**Acceptance:** `tb_bandgap` with `save_op_params 1` renders a deck whose device
save cards match `op_annot::save_cards`; running it produces a raw whose header
contains those exact vector names. **Read the raw header back and diff the two
name sets** — that is the direct test of I1 and it is the single most valuable
test in this plan.

**Risk:** low. **Unblocks:** real numbers on tb_bandgap.

---

## S5 — the display formatter

**Files:** `src/op_annot.tcl`.

`op_annot::text <instname>` — descriptor lookup, read each `params` vector with
`xschem raw value <v> -1`, evaluate `pinexpr` from pin voltages and `derived`
from the read values, format `label = <to_eng value>` per line.

Port `sg13g2_raw_or_double` / `sg13g2_to_eng_safe` as
`op_annot::raw_or_blank` / `op_annot::eng_or_blank` — but **blank, not `NaN`**
(I3; the IHP prototype prints `NaN`, and that is the one behaviour not to carry
over).

**Acceptance:** on a run with the cards saved, the block for one FET matches a
golden string; on a run without them, every line is `label =` with nothing after
it, and no line is `0`.

**Risk:** low.

---

## S6 — the generic annotator symbol

**Files:** new `xschem_library/devices/annotate_params.sym`; a menu item and the
"pre-fill `ref` from the selection" idiom from `sg13g2_procs.tcl:640`.

```
K {type=annotator template="name=annot1 ref=M1"}
T {tcleval([op_annot::text @ref])} … {layer=15 font=Monospace hide=op}
T {@ref} … {layer=4}
```

**This is the first user-visible deliverable of the whole plan**, and it needs no
C change on any PDK. `hide=op` is **verified inert** until S7: `set_text_flags()`
(`actions.c:1121`) does `strboolcmp(str,"true")`, and for an unrecognised value
`strboolcmp` (`util.c:72`) falls through to a plain `strcmp`, returns non-zero,
and no `HIDE_TEXT` bit is set — so the text simply stays visible. Safe to write
the token now and give it meaning in S7.

**Acceptance:** place next to a FET on each of the three PDKs, annotate, read
numbers. Record `owed.sh add look "annotate_params on tb_bandgap"`.

**Risk:** low.

---

## S7 — annotation classes (the only broad C change)

**Files:** `src/xschem.h` (flag bits + `annot_show` field), `src/actions.c`
(`set_text_flags`, and the mirror read at :4324), `src/scheduler.c`
(`xschem set annot_show`), plus the nine visibility sites:
`draw.c:868, 1131, 10266, 10556` · `svgdraw.c:923, 1290` ·
`psprint.c:1205, 1664` · `select.c:709` · `actions.c:4422`.

Collapse those nine copy-pasted tests into one helper `text_hidden(flags)` and
put the class logic inside it. **The refactor is the substance; the feature is a
few lines.** `hide=true` / `hide=instance` semantics must not change for any
existing symbol (I7).

Mask: bit0 = device OP info, bit1 = node voltages. Mirrored in Tcl as
`annot_show`, per the `MIRRORED IN TCL` convention in `xschem.h`.

**Acceptance:** every existing library symbol renders identically with
`annot_show 0` and the old `show_hidden_texts` in both states; a `hide=op` text
appears iff bit0. Test both the draw path and the SVG/PS export paths — those
are two of the nine sites and are the ones nobody looks at.

**Risk:** medium, from breadth. Do it as one commit, no behaviour change mixed in.

---

## S8 — the keys

**Files:** `src/cadence_style_rc`, `sky130A/cadence_style_rc`,
`ihp-sg13g2/cadence_style_rc`; `cadence::annot_mode` in the cadence procs.

```tcl
bind .drw <Control-Key-6> {cadence::annot_mode none;   break}
bind .drw <Key-6>         {cadence::annot_mode op;     break}
bind .drw <Alt-Key-6>     {cadence::annot_mode opvolt; break}
```

Verified free/overridable in this tree — plain `6` is a C no-op
(`callback.c:7272`), `Ctrl-6` is "select layer 6" and is overridden with a
trailing `break` exactly as `Ctrl-4` already is, `Alt-6` (keysym 54) is in no row
of `src/keybindings.csv`. No Shift, so the shifted-keysym trap documented in that
file does not apply.

`cadence::annot_mode` sets the mask, auto-loads a raw when none is loaded
(`ase::last_rawfile` / `ase::session_for_current`, else
`$netlist_dir/<cell>.raw` → `xschem annotate_op`), then
`xschem update_all_sym_bboxes; xschem redraw`, and **reports on the status
line** — "no raw file for this cell" and "no annotation descriptor for symbol
type <t>" are the two first-run confusions and both must be said out loud, not
swallowed.

**Acceptance:** the three keys on all three PDKs; a no-raw press says so.

**Risk:** low. Can land right after S6 driving `show_hidden_texts` as a crude
two-state if S7 is not ready.

---

## S9 — the draw-time overlay

**Files:** `src/draw.c`, then `src/svgdraw.c` and `src/psprint.c`.

For every instance whose symbol type has a descriptor, while the mask allows,
draw `op_annot::text` anchored to the symbol bbox. **I4: the schematic is never
modified** — no instance placed, no `set_modify`, nothing written to the `.sch`.
Per-instance `annot_dx` / `annot_dy` attributes override the anchor.

Expect duplication with sky130's always-on `id=`/`gm=` symbol texts until S10.
That is known, documented and not a blocker.

**Acceptance:** press `6` on `sky130_tests_ase/bandgap` and every FET shows its
block; press `Ctrl-6` and they all vanish; save the file and `git diff` is empty.
Export to SVG and PS and the annotation is there.

**Risk:** medium — performance on a large hierarchy (the text is rebuilt per
redraw; cache per instance and invalidate on annotation change).

---

## S10 — per-PDK symbol text cleanup

Script a pass over `sky130A/xschem_libs/sky130_fd_pr/*/symbol/*.sym` (~40 FET
symbols) marking their existing `id=`/`gm=`/`vgs=`/`vds=` texts `hide=op`, so the
overlay is the single source. gf180 already sets `hide=true` on its two; ihp
symbols carry currents only.

**Acceptance:** with `annot_show 0`, a sky130 schematic looks exactly as it did
before this whole plan started.

**Risk:** medium blast radius, zero logic. Separate commit per PDK.

---

## S11 — timepoint annotation without a graph (optional)

`xschem set cursor2_x <t>` currently annotates only when a graph rect exists on
the canvas and cursor B is on (`scheduler.c:11802`). Add the direct path:
interpolate from `xctx->raw` at `x = t` with no graph involved. Then the `6`/
`Alt-6` keys work on a transient raw with nothing plotted.

**Risk:** low, one arm.

---

## S12 — documentation and issues

- Fix `doc/claude/code_analysis/waveform_subsystem_reference.md` §6: "Op text is
  layer-15 (hidden unless `show_hidden_texts=1`)" is wrong — hiding comes from
  the `hide=true` attribute, and the sky130 symbols do not set it.
- File **0418**: `@spice_get_modelparam_<p>(<dev>)` and
  `@spice_get_modelvoltage_<p>(<dev>)` are matched by the regex at
  `token.c:4646` and then silently produce nothing (`token.c:5023` handles only
  the `@spice_get_current` variants). Reserved-but-dead token forms.
- File **0419**: the generic `@spice_get_modelparam_<p>` bare tokens build
  `i(@x…[i])` for any `spiceprefix=X` device, i.e. for every sky130 / gf180 /
  IHP device — `get_fqdevice()` switches on the *element letter*, which for a
  subcircuit-wrapped PDK device is always `x`.
- Update `doc/claude/specs/op_annotation.md` status as steps land.

---

## Landing order and what each step buys

| step | changes | buys |
|---|---|---|
| S1–S2 | Tcl only | the name builder, three PDKs described |
| **S3–S4** | Tcl + ASE | **numbers instead of `-`** — the blocker cleared |
| S5–S6 | Tcl + one symbol | a user-placeable annotator, all PDKs, no C |
| S8 | rc only | the three keys (crude toggle) |
| S7 | C, 9 sites + helper | the real three-state toggle |
| S9 | C, draw + exports | press `6`, every device lights up |
| S10 | bulk `.sym` | no duplication |
| S11 | C, one arm | timepoint OP with no graph |

S3+S4 are worth landing on their own even if nothing else follows: they are the
difference between annotation that shows `-` and annotation that shows numbers.
