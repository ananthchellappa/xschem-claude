# PLAN — OP parameter lists, the authoritative item list

Spec: `doc/claude/specs/op_param_lists.md`
Rulings: `DECISIONS.md` (D-1 … D-8) — **read that first, it overrides the spec**
Measurements: `doc/claude/code_analysis/1244_op_param_list_measurements.md`
Issues: **1244** (declutter) · **1245** (Results Display Window)

Eight items. Each is independently testable and names its own files, so two
items that do not share a file may run concurrently. The dependency edges are
the only ordering constraint.

```
A1 ──┐
A2 ──┴─> A3                     (feature A — 1244)

B1 ──┐
B2 ──┼─> B5                     (feature B — 1245)
B3 ──┴─> B4
```

---

## A1 — the mask bit and the chord

**Do.** Add `ANNOT_SHOW_NOPARAM 8` to the `annot_show` mask. Add
`cadence::annot_declutter toggle` in `utils/annot_mode.tcl`, writing the mask
**only** through `xschem set annot_show N` (never a bare `set ::annot_show` —
the C field reads stale and the variable is an integer, so `true` atoi's to 0).
Bind `<Control-Alt-Key-6>` in `src/cadence_style_rc`, **explicitly and with a
trailing `break`**.

**Why it is not free.** Tk matches a pattern whose modifiers are a *subset* of
the event's, so today `Ctrl-Alt-6` falls into `<Alt-Key-6>` and switches node
voltages on. This item's headline check is that it no longer does.

**Files.** `src/xschem.h` · `utils/annot_mode.tcl` · `src/cadence_style_rc` ·
new `tests/headless/test_annot_declutter_1244.tcl`

**Accept.** A chord matrix fired with `event generate` under all four profiles:
`6`→`|=1`, `Ctrl-6`→`0`, `Alt-6`→`|=2`, `Alt-Shift-6`/`Alt-asciicircum`→bit2,
`Ctrl-Alt-6`→toggles bit3 **and leaves bit1 alone**. Plus: `rectcolor` unchanged
throughout, and `xschem set annot_show true` still reads back 0 (the trap, pinned
so nobody "fixes" it).

---

## A2 — the name classifier

**Do.** Add `TEXT_ANNOT_NAME 1024` and set it in `set_text_flags()`
(`src/actions.c:1289`) beside the existing `annot_content_class()` call, on a
**whole-string** match (the existing classifier's discipline) against the three
spellings: `@name`, `@spiceprefix@name`, `@symname`.

**Why three.** Measured across 3,686 shipped `.sym` files: `@name` 3,165,
`@symname` 1,386, `@spiceprefix@name` 81. `draw.c:873`'s shipped keep-name test
misses the third, which is gf180's FETs and the generic `devices/nmos4.sym`. Do
not copy that test — it carries a measured bug.

**Files.** `src/xschem.h` · `src/actions.c` · rows in A1's suite

**Accept.** All three spellings classify; a text merely *containing* `@name`
(e.g. `x=@name`) does **not**; the bit is additive and changes no existing
`hide=` behaviour; `flags` is still never serialised.

---

## A3 — the draw rung and the per-instance gate  *(needs A1, A2)*

**Do.** One rung in `text_hidden()`: in an instance context, with **both**
`ANNOT_SHOW_OP` and `ANNOT_SHOW_NOPARAM` set, hide any text carrying neither
`TEXT_ANNOT_NAME` nor an annotation class. Per D-6 the rung fires only for
instances whose `op_annot::text` block is non-blank — and because symbol texts
are **shared by every instance of a symbol** (`draw_symbol` walks
`symptr->text[j]`), that gate cannot live in `xText.flags`; carry it as a new
context value `TEXT_CTX_INSTANCE_ANNOTATED` at the six instance call sites.

**⚠ The eleventh call site.** `src/actions.c:1832`, inside
`get_annot_overlay()`, calls `text_hidden(HIDE_TEXT_OP, TEXT_CTX_INSTANCE)` with
a **synthetic literal** — it is asking "would an OP text show right now?" as a
proxy for "should the overlay paint?". The new rung must sit **after** the class
tests so this answer is unchanged. A declutter that switches the annotation
overlay off is the feature eating itself.

**Files.** `src/xschem.h` · `src/actions.c` · `src/draw.c` · `src/svgdraw.c` ·
`src/psprint.c` · `src/select.c` · rows in A1's suite

**Accept.** Per PDK (sky130, gf180, IHP): with annotation + declutter on, an
annotated FET draws its name and its OP block and nothing else; a subcircuit
instance is untouched; a descriptor-less cap/res is untouched. With
`ANNOT_SHOW_OP` clear the declutter bit changes **nothing**. The `.sch` bytes
are **byte-identical** across a toggle and the modify flag is not set. SVG and
PS exports agree with the screen. And the click target: `select.c:709` shrinks
the with-text bbox that `findnet.c:461` gates on, so record what happens to
`find_closest_element` rather than discovering it later.

---

## B1 — the backend seam  *(no dependencies)*

**Do.** `ase::backend::ngspice::op_param_set <devpath>` → ordered `{param value}`
pairs, read **from the run's own raw**, plus a capability answer saying whether
the backend can enumerate. Pure Tcl, no UI, no deck change.

**⚠ D-4 and D-5 are the whole item.** No `show` parse, no catalogue, no
probe-and-prune. A zero-length or `dims=0` vector is **absent**, not zero. The
seam exists so the user's custom ngspice can supply a wildcard later without
anything above it changing.

**Files.** `src/ase.tcl` · new `tests/headless/test_rdw_seam_1245.tcl`

**Accept.** Against a **fabricated raw** (no ngspice needed): a device with six
saved params returns six pairs in order; an unknown device returns empty, not an
error; a `dims=0` column is omitted; the capability answer is honest. Plus the
multi-primitive case of D-3 — one `XR1` resolving to its several primitives.

---

## B2 — the list store and the settings file  *(no dependencies)*

**Do.** The class map (`type=` token → broad class: `nmos`/`pmos`→`mos`,
`res`/`poly_resistor`/`high_precision_poly_resistor`/`high_precision_poly_p`→
`resistor`, `capacitor`/`moscap`→`capacitor`, `diode`→`diode`,
`vertical_npn`/`vertical_pnp`→`bipolar`), extendable by the user. The three
lists per class. **D-7: seed from the PDK's `op_annot::register` calls, the
user's file wins per class.** Atomic write-beside-and-move (issue 0937). The
window and the CIW name the exact path on every Save.

**Files.** new `src/op_param_lists.tcl` (+ `src/Makefile.in` install **and**
uninstall, then re-run `./configure`) · new
`tests/headless/test_op_param_store_1245.tcl`

**Accept.** `grep -c op_param_lists.tcl src/Makefile` is **2**. A user entry
overrides its class and leaves the others seeded. Round-trips through a
save/reload. An interrupted write never truncates. The vocabulary really is
ragged — sky130 spells a resistor three ways — so the map is data, not a
`switch`.

---

## B3 — the window  *(no dependencies)*

**Do.** `src/rdw.tcl`, namespace **`rdw::`** (⚠ `results::` is taken by
`Results > Select`). Singleton toplevel, raise-if-exists. A **string-backed,
read-only, `-exportselection`** text pane; newest dump on top. A button column:
Up · Down · Delete · Add · Save, greyed per the spec's table.

**⚠ Not `textwindow`.** `xschem.tcl:13567` takes a *filename*, opens an
*editable* widget, and its Save writes back to that file. Building on it would
offer to save the dump over a design file.

**Files.** new `src/rdw.tcl` (+ `Makefile.in` ×2, `./configure`) ·
`src/xschem.tcl` (the menu entry) · new `tests/headless/test_rdw_window_1245.tcl`

**Accept.** `grep -c rdw.tcl src/Makefile` is **2**. Opens, raises, closes,
reopens. Text is selectable and copyable and cannot be edited. Survives
`--nogui` by not being constructed there.

---

## B4 — the keys and the two grammars  *(needs B3)*

**Do.** Bind bare `1`/`2`/`3`/`4` in `src/cadence_style_rc` with `break` (D-2).
**noun-verb**: one instance selected → dump it. **verb-noun**: nothing selected →
seize `<ButtonPress-1>` and `<Key-Escape>` like ASE Direct Plot does, resolve
each click with `xschem instance_at` so **the selection never changes**, and
`cmdmode::register` so a descend can suspend and resume it. Refuse in one short
CIW line for >1 selected, or nothing available.

**⚠ What it costs.** `logic_set` has no menu entry and no second accelerator, so
inside the cadence profile these keys are its only door. `xschem logic_set n`
stays scriptable. Say so in the commit.

**Files.** `src/cadence_style_rc` · `src/rdw.tcl` · rows in B3's suite

**Accept.** Both grammars. Escape leaves the mode with bindings restored. A
descend mid-mode suspends and resumes on the **descended** canvas. Clicking in
verb-noun mode leaves `xschem selection` byte-identical. Each refusal is one
line.

---

## B5 — the button column and the two scope dialogs  *(needs B2, B3)*

**Do.** Up/Down reorder in all three lists. Delete and Add per the spec's table,
each raising a **scope dialog** — *this device flavor only* vs *every device of
this class* — which writes a `match` glob or a class entry respectively. Save
writes the settings file.

**⚠ Modal dialogs hang headless suites** (issue 0803). The dialog needs a
test-drivable path in the **first** commit, not retrofitted.

**Files.** `src/rdw.tcl` · `src/op_param_lists.tcl` · rows in B2's and B3's suites

**Accept.** Reorder persists through Save/reload. Narrow scope touches one
flavor and leaves siblings alone; broad scope moves the class. Delete is greyed
on list 3. Add from list 3 asks *which* list. Every dialog is driven headlessly.

---

## Verification, every item

* Its own suite green, registered in `tests/headless/full_audit.sh`.
* A **name+status diff** against the baseline below — never a count.
* `cd tests && tclsh run_regression.tcl`, **solo** (issue 0990).
* A `look` debt for anything only an eyeball can judge. Never report a pixel
  deliverable done on a green suite.

**Baseline**, taken at `9ef4a37e` on the dev display: **364 pass / 11 fail /
0 crash-timeout / 2 skip of 377**, the eleven being `test_altf5_ciw`,
`test_ase_core`, `test_ase_window`, `test_cadence_drag`, `test_cosim_golden_e2e`,
`test_lib_manager_gui`, `test_lib_sweep`, `test_rotate_stretch_short_0104`,
`test_selflog_output`, `test_wave_sigbrowser_0312`, `test_wave_sigbrowser_keys`.
No new red names. A red going green is fine and gets recorded.
