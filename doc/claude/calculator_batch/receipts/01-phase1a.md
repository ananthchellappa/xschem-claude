# Item 1 receipt — phase 1a: rulings, colour, Results Dir, status area

Ledger row 1. Plan steps 1.1 and 1.8. Spec §4 W03–W05 / W32–W34, R113, R506.
Capture: `01-phase1a.png` (this directory).

**Verdict: `[E]` — done, eyeball pending.** The payload is colour and layout;
192 checks say the values are right and say nothing about whether it looks
right. Look debt recorded (`owed.sh list`).

> **Revised after review.** The first cut of this item was reviewed by three
> lenses and 19 findings were confirmed. Everything below is the post-fix
> state; the section **"What review found and what changed"** at the bottom
> lists each finding, the fix, and the sabotage that now guards it. Three
> claims in the first cut were **false** and are corrected in place:
> "no literal colour is written in `src/calculator.tcl`" (there were seven
> fallback literals), "these three roles come from the signal browser"
> (`fieldfg`/`selectbg`/`selectfg` came from ttk's defaults), and
> "`S15 … stacking is right`" (that check could not see stacking at all).

---

## A — the driver's rulings, written into the spec

| | |
|---|---|
| **RULING-1** | rewrote **R113** (`doc/claude/specs/calculator.md` §4.1). The rule is now "colours come from the signal browser's palette, through one accessor", naming `ase::palette` (`src/ase_window.tcl:151`), `ase::theme` (`:190`), `ase::ui::apply_theme` (`:236`) and the browser's call site (`src/wave_viewer.tcl:8224`), and stating which role reads which source. What survives of the old text: **one palette, not two**, and **no hardcoded Cadence red**. The amendment says plainly why the old wording failed — `resources.tcl` holds no theming at all (recon/theming.md §1), and "do not hand-set colors" was read as "leave everything grey". Ledger cited. |
| **RULING-2** | rewrote the **W30** row of the §4 widget table: operators only, no digit keys, digits are typed; the row now says it supersedes both the old `7 8 9 / …` list and the reference screenshot's 4×4 pad. Ledger cited. W30 is the only place in the spec that mentioned digits (`grep -in digit doc/claude/specs/calculator.md`). |

Two places outside the spec still assume a digit pad and are **not** mine to
edit — flagged here for items 4 and 7:
`PLAN.md:120` ("16 keys + 4 user buttons") and `PLAN.md:135` ("`7` then `.`
then `5` gives `7.5`").

A third contradiction *was* in my file and is fixed: the phase-0 Keypad
placeholder read `digits,\noperators,\nuser 1-4`. Found by looking at the
capture, not by a check.

### ⚠ The ledger's premise for RULING-3/4/5 was false, and this item acted on it

The item brief says RULING-3, RULING-4 and RULING-5 "are already written into
spec §12", citing the ledger rows, which each say "Already written into spec
§12.2 / §12.3 / §12.1". **They were not there.**

```
$ git show HEAD:doc/claude/specs/calculator.md | grep -c RULED
0
```

This item wrote them: ~24 lines in §12 adding
"**RULED 2026-08-13 by the build: toplevel**" (§12.1),
"**RULED 2026-08-15: no**" (§12.2) and
"**RULED 2026-08-15: both**" (§12.3). The text is correct and matches the
ledger, and §12 is *Open decisions*, not requirement text — so this is a
disclosure gap, not a content one. Recorded here so the **driver can correct
the three ledger rows** before ticking this one; the first cut of this receipt
did not mention the edits at all.

### One ruling the crew had to make

`calc::status` is called by nearly every later item, so its edge cases were
pinned rather than left per-caller. Written into the spec as **R507–R510**
(§8.1, in the previously unused gap between R506 and R601, so nothing
renumbered):

- **R507** empty string **clears the field and records nothing**; returns what it wrote.
- **R508** no window ⇒ **silent no-op**, records nothing, never throws (the
  `ciw_echo` precedent). The history belongs to the window: close clears it.
- **R509** **50 entries, newest first, the oldest drops.** Consecutive
  duplicates are **kept** — `::ciw_history` dedupes because it recalls
  *commands*; two identical status lines mean it happened twice, and hiding the
  second is the silence R506 forbids. Recall re-displays without re-recording.
- **R510** (added in the review round) "reveals the last 50 messages" is a
  **rendering** requirement. See §D.

## B — the colour layer

`calc::color <role>` + `calc::color_sources` + `calc::palette`
(`src/calculator.tcl`). Nine roles, each **read** from its source on every call:

| role | source | value today |
|---|---|---|
| `window` `panel` | `ase::palette panel` | `#f2f2f2` |
| `header` | `ase::palette header` | `#e8e8e8` |
| `field` | `ase::palette table` | `#ffffff` |
| `accent` | `ase::palette accent` | `#8b0000` |
| `fieldfg` | `ase::palette fieldfg` | `#000000` |
| `selectbg` / `selectfg` | `ase::palette selectbg` / `selectfg` | `#4a6984` / `#ffffff` |
| `disabledfg` | option DB `disabledForeground` (`xschem.tcl:15546`) | `grey50` |

Three properties that were **not** true of the first cut and are now:

1. **No literal colour, and no fallback defaults.** The first cut carried a
   fallback column — `#f2f2f2 #f2f2f2 #e8e8e8 #ffffff #8b0000 black grey70
   black grey50` — while R113, the file header and this receipt all claimed the
   file was literal-free. A role that silently defaults renders plausibly, is
   indistinguishable from a deliberate colour by any `cget` check, and then
   never tracks the palette again. `calc::palette` now **throws** on a role that
   does not resolve.
2. **`fieldfg`/`selectbg`/`selectfg` genuinely come from the browser.** They
   were read with `ttk::style lookup Ase.Treeview …`, and `ase::theme` set none
   of the three on that style — so `lookup` fell through the style name chain to
   ttk's **root** style and all three were the ambient ttk theme's, not the
   browser's. `ttk::style lookup NoSuchBrowser.Treeview -foreground` returned the
   identical value, which is why the S13 checks could not notice. Worse, the
   fallthrough was not deterministic: one measured run resolved
   selectbg/selectfg to `#d9d9d9`/`#000000` (the root style under `selected`),
   which with the old per-session cache would have made selected text in the
   status entry invisible for the whole session with no way to re-resolve.
   Fixed at the source: `ase::palette` now **names** `fieldfg`/`selectbg`/
   `selectfg` (plus `disabledbg`/`disabledfg` for the tree's disabled state) and
   `ase::theme` **applies** them to `Ase.Treeview` with an explicit `configure
   -foreground` and `map`. Values are the measured `default`-theme defaults, so
   no pixel moved; what changed is who owns them.
3. **The palette is not cached.** A cached palette can be wrong for the life of
   the process, and the only guard a cache cheaply carries is "not empty", which
   a wrong-but-plausible value walks straight through. Nine dict/option reads
   per `calc::color` call is not worth cacheing.

**And reading a colour no longer has side effects.** `calc::palette_init` used
to call `ase::theme`, which is not a reader: it does `font create
AseLabelFont/AseEntryFont/AseMonoFont` and a **process-global**
`option add *TCombobox*Listbox.font AseEntryFont`. Measured A/B on `:99` with
only `src/calculator.tcl` swapped:

```
WITH the first cut:  BEFORE combobox listbox font: TkTextFont
                     calc::open -> .calc
                     AFTER  combobox listbox font: AseEntryFont
with HEAD's file:    TkTextFont both times, no Ase* fonts at all
pre-created combobox posted AFTER calc::open -> AseEntryFont
  TkTextFont   DejaVu Sans 10, linespace 17
  AseEntryFont Liberation Sans 13, linespace 21   (+24% row height)
```

i.e. opening the inert Calculator once permanently grew every dropdown in the
Graph dialog, Preferences, the Library Manager and 30 other call sites, and
closing it did not undo it. `ase::theme` is now split: **`ase::palette`** is a
pure dict read with no side effects and `ase::theme` calls it, so
`ase::theme`'s own behaviour is unchanged for its 30-odd callers. `calc::color`
reads `ase::palette`. The one `Ase.*` style this window borrowed,
`Ase.TCombobox`, is replaced by a Calculator-local `Calc.TCombobox`. Three
checks guard it, taken at a baseline captured **before S1 ever opens the
window**.

Applied to: the toplevel, both panedwindows (their sash strips are the only
visible part and a grey80 strip between `#f2f2f2` panes is the seam RULING-1 was
about), the menubar and its six cascades, the five labelframes (panel background
+ **accent title text**, which is how `ase::ui::apply_theme` colours a
`Labelframe`, `ase_window.tcl:195-197`), the pane hints, the status bar and the
Results Dir row. Phase 0's `-foreground grey40` on the hints is now
`[calc::color disabledfg]`.

**Every palette background carries a palette foreground with it, hover included.**
The first cut gave the menubar and the six cascades `-background`/
`-activebackground` and no `-foreground`, so under `dark_gui_colorscheme` the
option database's `*foreground white` painted File/Tools/View/Options/
Constants/Help as white text on the light `#f2f2f2` bar — invisible. Measured:

```
DARK mbar bg=#f2f2f2 fg=white activebg=#e8e8e8 activefg=white
DARK res.tog fg=#8b0000 bg=#f2f2f2 activefg=white
```

Phase 0, which set no colours at all, was readable in both schemes; a colour
layer must not regress half the users. `-foreground`, `-activeforeground` and
`-disabledforeground` are now set on both `menu` calls, and
`-activeforeground`/`-foreground` on `.calc.res.tog` and `.calc.res.browse`.
(The signal browser's own menubar, `wave_viewer.tcl:17530-17537`, has the same
omission — a shared latent bug, not fixed here because it is not this item's
window.)

`ase::ui::apply_theme` is deliberately **not** called on `.calc`: it also imposes
ASE's named fonts on every widget it walks, and it paints every class alike where
the accent belongs to panel headers only. Fonts stay stock (recon/theming.md §3)
— and that claim is now true of the whole application, not only of `.calc`'s own
widgets.

Known and recorded in the file header: an explicit `-bg`/`-fg` beats the startup
option database, so these widgets are opted out of `dark_gui_colorscheme` —
exactly as the signal browser already is, and they follow it for free if that
palette ever learns about the dark scheme. That is the argument for not having a
second one.

## C — the Results Dir row (W03–W05)

`.calc.res` / `.tog` / `.lab` / `.path`, plus a **disabled** `.calc.res.browse`
stub (W05's Browse is a later item; the plan forbids leaving a control out).

**The path is `.calc.res`, a child of `.calc`, and it is drawn inside
`.calc.pw.sel`.** Spec §4's paths are normative and W03 says `.calc.res`, while
plan 1.1 says the row lives in the Selectors pane. Both hold through `pack -in`:
a widget may be managed by its parent *or by any descendant of its parent*.

⚠ **The stacking landmine was untested and is now tested.** Stacking is creation
order among siblings, so `.calc.res` must be built after `.calc.pw` or it maps
behind the panedwindow. The first cut cited `S15 row is mapped (stacking is
right)` as the guard, in the code comment, in this receipt and in the summary —
and `winfo ismapped` returns 1 for a widget that is mapped and **completely
obscured**. Measured: changing `raise .calc.res` to `lower .calc.res` left the
suite at `RESULT: ALL PASS (144 checks)` with the entire row invisible.

```
sabotaged: ismapped=1  containing(centre) = .calc.pw.sel
           children .calc = {.calc.res .calc.mbar … .calc.pw}
restored : ismapped=1  containing(centre) = .calc.res.path
           children .calc = {.calc.mbar … .calc.pw .calc.res}
```

Two checks replace it: **`S15 row stacks above the panedwindow`** (`.calc.res`'s
index in `winfo children .calc`, which is documented bottom-to-top stacking
order) and **`S15 row is the topmost widget at its own centre`**
(`winfo containing`). Both go red on that one-word edit. This matters now, not
later: item 2 adds the selector grid to this same pane. `pack forget` still
detaches the row from the pane, which is what the collapse toggle uses.

The path comes from `xschem raw rawfile`. Verified against source rather than
taken from recon: the arm is `src/scheduler.c:10005-10006`, inside the
`raw && raw->values` gate at `:9881`, and the chain's final `else` at `:10046`
**throws** `No raw file loaded` — it does not return empty. So the read is
`catch`'d, exactly as `wave_viewer.tcl:17341` does it. With nothing loaded the
entry reads `(no raw file loaded)` — the browser's own wording
(`wave_viewer.tcl:7886`; the first cut cited `:7861`, which has no such string)
— because an empty readonly entry and a broken one look identical.

The collapse toggle works (layout, not behaviour). Persisting its state is R110,
plan phase 10.

## D — the status area (W32–W34)

`.calc.status.msg` is now an **entry**, readonly, initially empty, driven by
`-textvariable`: R603 needs an evaluated scalar to be selectable and copyable and
only an entry gives that. `.calc.status.hist` is a readonly `ttk::combobox`, two
characters wide — the house combobox shrunk to the dropdown button the reference
draws at the right end of the bar. **Its `-values` are the history.**
`calc::status`, `calc::status_history`, `calc::status_recall` implement R507–R509.

⚠ **…and `-values` is the widget's data, not what the user sees.** ttk sizes a
combobox popdown to the combobox's own pixel width, so a 2-character button gave
a 2-character dropdown:

```
HIST combobox width option = 2 ; pixel width = 35
HIST popdown geom = 35x70  listbox w = 33 px
HIST listbox first item = 'Buffer cleared'   chars visible ≈ 3
```

The user saw `Buf`, `Plo`, `Eva` — W34's whole purpose defeated, and no check
noticed because S16 only asserted `cget -values`. The style knob is
`-postoffset {dx dy dw dh}`, which `ttk::combobox::PlacePopdown` adds to the
popdown's placement (`ttk/combobox.tcl:363` reads it via `ttk::style lookup
$style -postoffset`). `Calc.TCombobox` now carries
`-postoffset {-460 0 460 0}` (`calc::popdown_extra`), so the list opens leftwards
and wide while the button stays 35 px:

```
combobox pixel width  = 35   (unchanged)
popdown geom          = 495x58   listbox 493 px
longest message needs = 361 px
```

Written into the spec as **R510**. The suite now **posts the dropdown** and
measures the listbox against `font measure` of the longest value, rather than
counting `-values`.

---

## Evidence

### Suite: `test_calc_skeleton` 52 → **192 checks**, all pass

`tests/headless/run_suites.sh test_calc_skeleton` → `RESULT: ALL PASS (192 checks)`
(dev display `:99`, openbox, `GUI_GATE=0`). S1–S12 untouched and unrenumbered.
New: **S13** palette accessor + purity, **S14** the chrome wears it, **S15** the
Results Dir row, **S16** the status contract.

**The new checks were run against the code before the feature existed**, with
both `git show HEAD:src/calculator.tcl` and `git show HEAD:src/ase_window.tcl`
in place: `RESULT: 133 FAILED (59 passed)`. 133 of the 140 phase-1a checks are
red without the feature. The 7 that pass:

| check | why it passes at HEAD |
|---|---|
| `S13 no window open` | fixture precondition (S12 closed the window) |
| `S13 the stock dropdown font was readable at baseline` | fixture precondition |
| `S13 no ASE font existed before the Calculator was opened` | absence assertion — a feature that does not exist has no side effects |
| `S13 opening the Calculator created no ASE font` | same |
| `S13 a combobox that predates the Calculator keeps its dropdown font` | same |
| `S13 a combobox created after it keeps the stock dropdown font` | same |
| `S14 open returns .calc` | phase-0 behaviour |

The four "absence" rows are inherent to what they assert and are named here
rather than counted as evidence. **The first cut reported `90 FAILED (54
passed)` and "the 2 that pass are fixture preconditions"; the measured value was
`89 FAILED (55 passed)` with three passing, the third —
`S16 recall recorded nothing` — passing **vacuously**: it compared
`[pcall calc::status_history]` against a `$histbefore` that was also
`[pcall calc::status_history]`, so with the proc absent both sides were the same
`ERR:invalid command name` string. That is exactly the class the first cut
claimed to have swept from five places; one survived. It is now anchored on a
positive control (`S16 the pre-recall snapshot is a real 50-entry history`) and
the comparison substitutes a value that cannot match when the snapshot is an
error, so at HEAD it reads:

```
FAIL: S16 recall recorded nothing -> {NO-SNAPSHOT-TO-COMPARE}
      (exp {ERR:invalid command name "calc::status_history"})
```

Guarding lesson repeated from the first cut and extended: every call a missing or
sabotaged proc can make throw goes through `pcall` (`wvbs_common.tcl:84`), and
that now includes the two `rename` fixtures and the `winfo rootx/containing`
probes — an unguarded one aborted the non-vacuity run at the outer `catch` and
silently deleted 70 checks from the measurement.

### Sabotage table

Every break applied to the working file and reverted from a **byte-exact backup**
(`md5sum` re-checked; never `git checkout --`). The full table, including the
re-run of every first-cut sabotage whose subject moved, is in the fixer's report;
the rows added by the review round are:

| # | break | red |
|---|---|---|
| M70 | `calc::color_sources` reads `ase::theme` instead of `ase::palette` | `S13 opening the Calculator created no ASE font`, + both combobox-font checks |
| M71 | `ase::theme` stops declaring `-foreground` on `Ase.Treeview` | `S13 the browser applies fieldfg to its own tree style -> {}` |
| M72 | the `disabled` half of the `Ase.Treeview` map is dropped | `S13 the tree style kept its disabled foreground/background -> {NO-SUCH-STATE}` |
| M73 / M74 | `selected` bg / fg on `Ase.Treeview` becomes a literal | `S13 the browser applies selectbg / selectfg …` |
| M75 | `calc::palette` substitutes a default instead of throwing | `S13 a role with no source throws, it does not default -> {all nine roles}` |
| M76 | `fieldfg` sourced from a literal | `S13 fieldfg = ase::palette fieldfg -> {#010203}` |
| M77b | `selectbg` sourced from `ttk::style lookup NoSuchBrowser.Treeview …` | `S13 every role reads the browser's palette, and nothing else -> {selectbg}` |
| M78 | `calc::status`'s `info commands winfo` guard deleted | `S13 no winfo command is a silent no-op -> {ERR:invalid command name "winfo"}` |
| M79 / M80 / M81 | menubar loses `-foreground` / cascades lose `-activeforeground` / menubar loses `-background` | `S14 menubar foreground`, `S14 every cascade takes a palette foreground`, `S14 menubar background -> {grey80}` + `is not stock grey` |
| M82 | hint `-foreground` back to the literal `grey40` | all five `S14 … hint text is the muted role` |
| **M83** | **`raise .calc.res` → `lower .calc.res`** | **`S15 row stacks above the panedwindow`, `S15 row is the topmost widget at its own centre`** |
| M85 / M86 | `.calc.res.tog` loses `-foreground` / `-activeforeground` | `S15 toggle wears the accent`, `S15 toggle keeps it on hover` |
| M87 | `.calc.res.lab` loses `-background` | `S15 label background -> {grey80}`, `S15 no control in the row is still stock grey` |
| M88b / M89b | `.calc.res.browse` `-disabledforeground` → literal / loses `-foreground` | `S15 Browse disabled text is the muted role`, `S15 Browse has a palette foreground …` |
| M90 / M91 / M92 | `-postoffset` removed / shrunk to 60 px / style reverted to stock `TCombobox` | `S16 the dropdown is wider than the button that opens it`, `… wide enough to read the longest message` |
| M93c | `calc::status_recall` re-records into the history | `S16 recall recorded nothing` (the rewritten whole-list form still bites) |

**Two sabotages deliberately survived, and both are correct:**

- **M84** — building `.calc.res` *before* the panedwindows. Green, because the
  explicit `raise .calc.res` at the end of `build_panes` is the real guard and it
  still runs. M83 is the sabotage that tests the guard.
- **M88** (drop `-disabledforeground` from `.calc.res.browse` entirely). Green,
  because the `disabledfg` role *is* the option database's `grey50` and the
  option database supplies the identical value when the widget option is absent.
  Semantically a no-op, not a coverage hole; M88b (a *different* colour)
  reddens.

Two checks are structurally weak and are named rather than hidden:
`S15 .calc.res parent is .calc` can only fail when the widget is missing (the
path determines the parent, and the spec forbids renaming the path), and
`S14 open returns .calc` is a phase-0 assertion re-used as a fixture.

### Regression: the driver's suites, plus every suite that walks `ase::theme`

Diffed against `receipts/00b-audit-baseline-2026-08-14.txt` by name and status,
both directions. `src/ase_window.tcl` is the signal browser's own theming and the
first cut did not touch it, so this round adds the ASE and browser suites —
including the five the first cut's reviewers said nobody had run.

| suite | baseline | now |
|---|---|---|
| `test_calc_skeleton` | PASS | PASS (192 checks, was 52) |
| `test_wave_viewer` | PASS | PASS (400) |
| `test_accelerators` | PASS | PASS |
| `test_bindings_file` | PASS | PASS |
| `test_wave_sigbrowser` | PASS | PASS (353) |
| `test_wave_sigsearch` | PASS | PASS (233) |
| `test_wave_trace_menu` | PASS | PASS (397) |
| `test_wave_sigbrowser_2pane` | PASS | PASS (108) |
| `test_wave_sigbrowser_sea` | PASS | PASS (79) |
| `test_wave_tabs` | PASS | PASS (172) |
| `test_ase_dialogs` | PASS | PASS (133) |
| `test_ase_dirty` | PASS | PASS (41) |
| `test_ase_view` | PASS | PASS (36) |
| `test_ase_plot` | PASS | PASS (150) |
| `test_ase_window` | FAIL | FAIL (1 FAILED / 165, `W7 simulator produced output before Stop`) |
| `test_lib_manager_gui` | FAIL | FAIL (2 FAILED, `GUI8`/`GUI9`) |
| **`test_ase_core`** | **PASS** | **FAIL** (1 FAILED / 57) — reproduces byte-identically at HEAD |
| **`test_ase_final`** | **PASS** | **FAIL** (1 FAILED / 9) — reproduces byte-identically at HEAD |

Two statuses moved against the baseline and **neither is this item's doing.**
Both were re-run with `git show HEAD:src/ase_window.tcl` and
`git show HEAD:src/calculator.tcl` in place and fail identically, with the same
message:

```
with the item : UNEXPECTED ERROR: ase: design aselib/nfet_clean is not the
                current schematic; open its design window first
                RESULT: 1 FAILED (57 passed)
at HEAD       : UNEXPECTED ERROR: ase: design aselib/nfet_clean is not the
                current schematic; open its design window first
                RESULT: 1 FAILED (57 passed)      (test_ase_core)

with the item : UNEXPECTED ERROR: ase: design sky130_tests/test_nfet_final is
                not the current schematic … RESULT: 1 FAILED (9 passed)
at HEAD       : identical                          (test_ase_final)
```

The baseline is dated 2026-08-14 at HEAD `8423240a`; this tree is at `6ce8bf3d`,
five commits later. These are tree drift, not a regression from the colour layer.
Both are unrelated to theming — the failing assertions are about which schematic
is current, not about a widget's appearance.

No rebuild: `src/calculator.tcl` and `src/ase_window.tcl` are sourced at runtime
(`src/xschem.tcl:14381`) and nothing outside `.tcl`/`.md`/`.png` was touched.

---

## Eyeball — what a human still has to confirm

Captures, `:99` + openbox: **`01-phase1a.png`** (the window) and
**`01-phase1a-dropdown.png`** (the status history dropdown posted, new in this
round — it is the only evidence of the R510 fix that is not a number).

**One defect the checks could not have caught, found by looking:** the
Keypad placeholder still read `digits, operators, user 1-4` — the exact thing
RULING-2 deletes. Fixed to `operators, user 1-4`.

Confirmed by eye: five panes with dark-red titles; the Results Dir row at the
**top** of the Selectors pane with a white full-width path field reading
`(no raw file loaded)`; the `v` collapse toggle and the greyed `...` Browse at
either end of it; a light menubar with no grey seam against the window; the
status bar spanning the full width with a live message and its dropdown at the
right.

**Not verified, and only a human can:**

1. Whether the accent as **title text** reads as the reference's solid coloured
   **bar** on a panel header. Deliberate — a bar is a different widget, and
   `ase::ui::apply_theme` colours the title text.
2. Whether `v` / `...` are acceptable stand-ins for the reference's red triangle
   and folder icon. No icon work is in scope for phase 1.
3. Whether the two-character history dropdown is discoverable as a dropdown —
   **and whether the widened popdown (495 px opening leftwards from a 35 px
   button) looks deliberate rather than broken.** New in this round.
4. Whether `#f2f2f2` panels next to xschem's `grey80` main window read as
   deliberate rather than as a mismatch, **on `:0`** — the capture is Xvfb.
5. The still-open phase-0 look debt on the keypad pane width, which item 4 owns.
6. **New:** that the signal browser's own trees still look right. `ase::theme`
   now declares `-foreground` and a `selected`/`disabled` state map on
   `Ase.Treeview` where it previously inherited them. The declared values are
   the measured ttk defaults, so no pixel should have moved, but the browser is
   the user's window and a suite cannot see a colour regression there.
7. **New, and visible in `01-phase1a-dropdown.png`:** the popdown *listbox* is
   the option database's light grey, not the palette's white `field`.
   `Calc.TCombobox -fieldbackground` reaches the combobox's entry field, not the
   popdown listbox, which is a plain Tk `listbox` created lazily inside
   `.calc.status.hist.popdown` and takes its colours from the option database.
   Left alone deliberately: no reviewer raised it, no requirement names it, and
   the only ways to reach it are an `option add` pattern keyed on a widget path
   or the same process-global font/colour trick this round just removed from
   `ase::theme`. Say if it should be white and it becomes an item.

`owed.sh add look` recorded (1)–(4) in the first cut and (3-revised) and (6)
in this one; `owed.sh add suite test_calc_skeleton` recorded the `:0` run.
**Nothing is cleared by this item** — a look debt clears only when the user
says so.

---

## What review found and what changed

Three lenses, 19 confirmed findings, deduplicating to 12 distinct defects. Every
one is fixed or, where the fix was "say the true thing", corrected in the spec
and here. Nothing was changed to appease an unconfirmed finding — the
"raised but not confirmed" list was empty.

| # | severity | finding | fix | guard |
|---|---|---|---|---|
| 1 | major | Opening the Calculator permanently changed the dropdown font of every `ttk::combobox` in xschem (33 call sites), because `calc::palette_init` called `ase::theme`, which is not a reader | `ase::palette` split out as a pure dict read; `ase::theme` calls it and is otherwise unchanged for its own 30 callers; `calc::color` reads `ase::palette`; `Ase.TCombobox` → local `Calc.TCombobox` | M70; three checks with a baseline taken before S1 |
| 2 | major | W34's dropdown revealed ~3 characters of each message; S16 asserted `cget -values`, which is data, not rendering | `Calc.TCombobox -postoffset {-460 0 460 0}`; spec R510 | M90/M91/M92; the suite posts the popdown and measures it |
| 3 | major | `S15 row is mapped (stacking is right)` could not see stacking: `lower .calc.res` hid the whole row with the suite ALL PASS | two new checks — stacking index in `winfo children .calc`, and `winfo containing` at the row's centre | **M83** |
| 4 | major | `fieldfg`/`selectbg`/`selectfg` did **not** come from the browser; `ttk::style lookup Ase.Treeview …` fell through to ttk's root style, and the S13 checks could not tell | `ase::palette` names them, `ase::theme` declares them on `Ase.Treeview`; a check pins the *source text*, since the values are indistinguishable | M71/M73/M74/M76/M77b |
| 5 | major | the palette was cached for the process life behind an empty-string-only guard; one observed run cached the root style's `#d9d9d9`/`#000000`, making selected text invisible for the session | cache removed; resolved per call | (the class is gone, not guarded) |
| 6 | minor | seven fallback literals including `#8b0000`, while R113/the header/the receipt all said "no literal colour" | fallbacks deleted; an unresolvable role throws | M75 |
| 7 | minor | menubar + six cascades had a palette background and an option-database foreground → white-on-`#f2f2f2` under `dark_gui_colorscheme` | `-foreground`/`-activeforeground`/`-disabledforeground` on both `menu` calls, `-activeforeground`/`-foreground` on `.calc.res.tog`/`.calc.res.browse` | M79/M80/M81/M85/M86/M89b |
| 8 | minor | the menubar and the Results Dir row's own children had **zero** colour coverage; the hint check sampled 1 of 5 panes | 20 new `cget` checks; the hint check loops all five panes | M81/M82/M85–M89b |
| 9 | minor | `S16 recall recorded nothing` passed vacuously with the feature absent (both sides the same `ERR:` string), and the receipt's non-vacuity figure was wrong (90/54 claimed, 89/55 measured, 3 passing not 2) | positive control + a substitute value that cannot match; figures re-measured and corrected above | re-measured at HEAD: the check now FAILs there |
| 10 | minor | R508 names `--nogui` where `winfo` does not exist; deleting that guard left the suite green | the suite renames `::winfo` away and asserts the no-op | M78 |
| 11 | minor | the ledger's premise that RULING-3/4/5 were "already written into spec §12" was false; this item wrote them and said nothing | disclosed in §A above, with the `git show HEAD` proof, so the driver can correct three ledger rows | n/a |
| 12 | minor | the `(no raw file loaded)` wording was cited as `wave_viewer.tcl:7861`; it is `:7886` | corrected in the code comment and above | n/a |

Two findings were *identical claims from different lenses* (the stacking hole:
3 lenses; the font leak: 2; the tree-style roles: 2; the §12 disclosure: 3), which
is why 19 findings are 12 defects.

## Files

- `src/calculator.tcl` — palette, Results Dir row, status area
- `src/ase_window.tcl` — **new in the review round**: `ase::palette` split out as
  a pure reader; `ase::theme` calls it and now declares `fieldfg`/`selectbg`/
  `selectfg`/`disabledbg`/`disabledfg` on `Ase.Treeview`
- `tests/headless/test_calc_skeleton.tcl` — S13–S16, 52 → 192 checks
- `doc/claude/specs/calculator.md` — R113 rewritten, W30 amended, R507–R510
  added, **and §12's three open questions ruled** (see the disclosure in §A)
- `doc/claude/calculator_batch/receipts/01-phase1a.md`, `01-phase1a.png`

## Next

Item 2 replaces `.calc.pw.sel`'s hint with the 22-button selector grid, **below**
`.calc.res` (`pack slaves .calc.pw.sel` is asserted, so the order cannot drift,
and the two stacking checks now bite if the row is pushed behind the pane).
Every phase-1 stub should call `calc::status "<verb>: not implemented"` — the
proc is live and its contract is R507–R510.
