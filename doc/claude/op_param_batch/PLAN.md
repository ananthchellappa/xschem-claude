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

## A1 — the mask bit and the chord  ✅ **DONE (status E), 2026-09-02**

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

**Landed.** `tests/headless/test_annot_declutter_1244.tcl`, **36 checks, ALL
PASS**. Audit **364/11/0/2 of 377 → 365/11/0/2 of 378**, the eleven reds
identical by name. Full record:
`doc/claude/op_param_batch/receipts/A1.md`. **Status E** — the three status
sentences are unratified (`rule` debt 1244) and the ON one describes the world
A3 creates. Filed and not fixed: **1246**, **1247**, **1248**.

**⚠ Deviation, deliberate, and it binds every later item.** This item's Do cell
said "register it in `tests/headless/full_audit.sh`". **That file was not edited
and must not be.** Registration on this tree *is* the
`ls "$HERE"/test_*.tcl | sort` glob at `:393`; the three named lists
(`nogui_tests`, `logdir_tests`, `nolog_tests`) are opt-ins for special run modes,
and putting an `event generate` suite on `nogui_tests` strips X and breaks
`bind` outright. **Every new suite in this batch moves the audit denominator, so
diff by name and status, never by count.**

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

**From A1, 2026-09-02.** `src/xschem.h` moved: A1 inserted 32 lines
**immediately after** `ANNOT_SHOW_TRAN`, a pure insertion, so `ANNOT_SHOW_OP`,
`ANNOT_SHOW_VOLTAGE` and `ANNOT_SHOW_TRAN` are still at 432/433/454 and
**everything below 454 shifted by +32**. `TEXT_ANNOT_NAME 1024` belongs in the
*other* block, beside `TEXT_ANNOT_CURRENT 512` — a different block, so the two
edits do not collide — but **do not cite a line number in any comment you add**:
A2's own insertion shifts the mask block in turn. A1's suite already exists and
already carries the three readers A2 needs (`opa_n_grep`, `opa_proc_src`,
`opa_n_rcbind`, the last extended with a `declutter` arm); append rows to it and
keep the banner shape `RESULT: ALL PASS (N checks)` / `RESULT: N FAILED`.

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

**Also owns the three defects A1 found and correctly did not fix:**

* **1246** — `Waves > Op Annotate` does `xschem set annot_show 3` at
  `src/xschem.tcl:17299` and `:17725`, a **hard set** that silently clears the
  declutter bit. Make it OR in `1|2` and leave bit 3 alone. (Adds
  `src/xschem.tcl` to this item's files.)
* **1247** — `annot_show_set()` (`src/actions.c:1406`) stamps `xctx->annot_root`
  for **any** nonzero mask, so two `Ctrl-Alt-6` presses — a net-zero pair whose
  advertised effect is nothing — convert an `xschemrc`-armed annotation into one
  a later `File > Open` clears. Pre-existing mechanism (issue **0688**); A1 owned
  no C file that could fix it. You do.
* **1248** — A1's suite proves the mask arithmetic well and the **rendering** not
  at all: its "A3 MUST REPLACE" tripwire runs on a fixture that cannot see the
  mask, so it cannot trip. **Replacing it with a real rendering check is this
  item's obligation, not an optional extra** — A1's status sentence *"a device
  showing operating-point values draws its name and those values only"* is a
  promise only this item can make true, and the driver accepted that wording on
  the explicit condition that A3 proves it.

**Files.** `src/xschem.h` · `src/actions.c` · `src/draw.c` · `src/svgdraw.c` ·
`src/psprint.c` · `src/select.c` · `src/xschem.tcl` (1246) · rows in A1's suite

**Accept.** Per PDK (sky130, gf180, IHP): with annotation + declutter on, an
annotated FET draws its name and its OP block and nothing else; a subcircuit
instance is untouched; a descriptor-less cap/res is untouched. With
`ANNOT_SHOW_OP` clear the declutter bit changes **nothing**. The `.sch` bytes
are **byte-identical** across a toggle and the modify flag is not set. SVG and
PS exports agree with the screen. And the click target: `select.c:709` shrinks
the with-text bbox that `findnet.c:461` gates on, so record what happens to
`find_closest_element` rather than discovering it later.

**From A1, 2026-09-02 — four things that bind this item.**

1. **⚠ ROW I2's FIXTURE CANNOT SEE THE MASK — issue 1248.** A1's row I2 is
   labelled "A3 MUST REPLACE", but it renders `nand2.sch` with no raw and eight
   unresolved symbols, and *every* mask exports byte-identically there —
   measured `0=1 1=1 2=1 3=1 8=1 9=1 11=1`, **including 1 vs 3**, a pair that
   genuinely differ in meaning. **A3 can land, work perfectly, and leave I2
   green.** Replacing the row means replacing the fixture: a real raw, in
   `test_op_annot.tcl`'s `opa_o_mkrlraw` shape, so that 1 vs 3 differ *before*
   A3 lands and the row has a non-vacuity control. Row I3 (invariant I-C,
   permanent) needs the same fixture for the same reason.
2. **Use the SPEC's `text_hidden` call-site list, §2.3 — re-verified against the
   tree on 2026-09-02 and correct.** Eleven sites: `draw.c:872, 1140, 10307,
   10688` · `svgdraw.c:927, 1334` · `psprint.c:1209, 1710` · `select.c:709` ·
   `actions.c:1832` (the synthetic literal) · `actions.c:6324`. Six of them are
   `TEXT_CTX_INSTANCE`: `draw.c:872, 1140, 10307`, `svgdraw.c:927`,
   `psprint.c:1209`, `select.c:709`. **The list in CLAUDE.md and in the crew
   brief is stale on nine of ten entries** and names `actions.c:4422`, which is
   not a call site at all.
3. **Exposure grows here.** Issue **1246** (`Waves > Op Annotate` hard-sets
   `annot_show 3`, silently clearing bit 3) is invisible today and user-visible
   the moment A3 makes the bit hide text. Issue **1247** (a net-zero pair of
   presses arms the 0688 root-change clear) is the same shape.
4. **`cadence::_annot_msg` is blind to bit 3** — it switches on `$mask & 7`
   (`utils/annot_mode.tcl:906`), so after the declutter a subsequent `6` writes
   a status line that says nothing about the hidden parameters. A1 left it alone
   deliberately: row V21 of `test_op_annot.tcl` golds its eight arms
   byte-for-byte and A1 owns neither file. **A3 should decide whether to close
   that gap**, because A3 is the item that makes the silence wrong.

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

## What A1 learned that every later item needs

* **Issue numbers come from `doc/claude/issues/NUMBERING.md` and nowhere else.**
  The crew brief's "number from 0619 upward" and "hard ceiling 0499" are **both
  false on this tree** — `0619`…`0629` exist as files. **The next free number is
  1249**; 1244 and 1245 stay reserved as feature numbers with no files.
* **The default `xschemrc` does NOT source `src/cadence_style_rc`.** A bare
  `./src/xschem --pipe --script t.tcl` has no `::cadence` namespace at all and
  every `.drw` chord bind is the empty string. Any suite or probe that touches a
  cadence chord must `source .../src/cadence_style_rc` first — this cost A1's
  measure pass a whole probe run.
* **`full_audit.sh` is not edited to register a suite.** The glob at `:393` is
  the registration. Every new suite moves the denominator, so **the baseline
  diff is by name and status** — A1 went 377 → 378 and its +1 is its own suite.
* **The item's own suite is not the tier list.** A1's 36 checks were green while
  `run_regression.tcl` was red on a *structural* contract in a file A1 does not
  own (`test_op_annot.tcl` row A11-2: every line in `utils/annot_mode.tcl` that
  writes `xschem statusmsg -hold` must name `_annot_fit` on the **same line**).
  Run T1 solo, every time, and read it.
* **`callback.c`'s layer-select arm is `:7470 case '6':` / `:7474
  if(state==ControlMask)`** — the brief's `callback.c:7272` is a mouse
  select-by-area and is wrong.
* **`event generate` is fine for Tk-side chords.**
  `test_wave_sigbrowser_i12.tcl:1141`'s warning that `<Control-Alt-Key-…>` "does
  not work under `event generate`" is true only for a **C-side** handler reading
  the numeric `%s` (a synthesised Alt sets the virtual META bit, not Mod1). A Tk
  `bind` pattern matches fine — A1 confirmed it both ways, including with a
  physical `-state 12`.
* **Nothing installs `utils/`** (issue **0458**, pre-existing and open), yet the
  installed `cadence_style_rc` sources twelve helpers from it. In-tree
  everything passes because `XSCHEM_SHAREDIR` resolves to `src/`. Any item that
  adds a `src/*.tcl` still owes `Makefile.in` ×2 and a `./configure` (issue
  0424); an item that adds a `utils/*.tcl` inherits 0458.

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
