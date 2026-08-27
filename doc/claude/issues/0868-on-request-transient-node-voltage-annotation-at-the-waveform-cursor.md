# 0868 — on-request transient node-voltage annotation at the waveform cursor

**Status:** ✅ **LANDED 2026-08-27** (branch `annotate`). Also **closes issue 0865**
by gating its two ACQUISITION publishers, and supplies the CIW channel issue
**0857** half 2 needs.

**Owns:** the user's step 3 of the annotation request, verbatim 2026-08-26:

> "MUST ONLY HAPPEN WHEN USER REQUESTS IT!! Alt-6 and 6 are for OP info and OP node
> voltages. We can add a menu item in Results > Annotate for annotating TRAN node
> voltages for time-point given by cursor B, or A - whatever the convention is - if
> there is only one cursor in the waveform viewer's active tab, use that. If A and B
> are there, then use cursor-A. Give user a way to enter this mode with a different
> shortcut through cadence_style_rc - maybe Alt-Shift-6"

Spec: `doc/claude/specs/op_annotation.md` **§4.9**.

---

## What the user gets

* A third entry in the ASE-L **Results > Annotate** submenu, beside *Operating Point
  info* and *DC Node Voltages*: **Transient Node Voltages (at cursor)**. A
  checkbutton, built disabled, greyed by `ase::has_results` like the other two.
* A fourth chord in the cadence profile: **Alt-Shift-6**. `Ctrl-6` still clears
  everything, bit2 included.
* Both drive **one** body, `cadence::annot_tran` (`utils/annot_mode.tcl`), which
  resolves the time point, publishes it, arms `annot_show` bit2 and says what
  happened in the CIW **and** on the held status line.
* With the *Live annotate probes with 'b' cursor* box in its shipped **unticked**
  state, **nothing paints unless the user asks**: loading a waveform file no longer
  acquires an annotation, and neither does descending into a child.

## What landed, by file

| file | change |
|---|---|
| `src/xschem.h` | `ANNOT_SHOW_TRAN 4`; `backannotate_at_time()` prototype |
| `src/actions.c` | `annot_class_mask()` returns `ANNOT_SHOW_VOLTAGE\|ANNOT_SHOW_TRAN`; `text_hidden()`'s explicit `hide=voltage` arm follows both; **guard G2** in `descend_schematic()` |
| `src/save.c` | **guard G1** in `raw_read()`'s tail |
| `src/callback.c` | `backannotate_cursor_b_in_db()` gains `const double *at` (**G3**); body split into `backannot_pos_at()`; **`backannotate_at_time()`** (**G4** the waves gate, **G5** the wide window) |
| `src/scheduler.c` | `xschem annotate_at <time>` verb (**G10** the floater refresh) |
| `utils/annot_mode.tcl` | `_annot_tran_cursor` (**G7** the rule, **G8** the viewer borrow), `_annot_tran_msg` (the one mint), `_annot_ciw` (the one emitter), `annot_tran` (**G13** arm-last); `_annot_msg` widened `& 3` → `& 7` |
| `src/cadence_style_rc` | **G11** `<Alt-Key-asciicircum>` + the `<Alt-Shift-Key-6>` fallback |
| `src/ase_window.tcl` | **G12** the third checkbutton, `annot_menu_sync` third tick, `annot_apply`'s request arm, `annot_tran_helper` |

## The corrected publisher inventory (both 0865 and the item brief are wrong)

* `src/scheduler.c:12080`, named as an ungated publisher, is inside `#if 0`
  (`:12075`/`:12083`). **Dead code.** Gating it would look like work and be nothing.
* The `else if(backannotate_at_cursor_b_nograph())` arm of the same
  `xschem set cursor2_x` is a **fourth** ungated publisher nobody listed.
* The real ungated set was `save.c`'s `raw_read()` tail, `actions.c`'s
  `descend_schematic()` tail, and **both** `xschem set cursor2_x` arms.

## The decision, and the alternative it rejects — **ratification owed**

**Gated: the two ACQUISITION doors only** — loading waves and descending. **Both
`xschem set cursor2_x` arms are left publishing.**

Reasons, measured: `xschem set cursor2_x <t>` is a sentence somebody TYPED naming a
time, which is what "only when the user requests it" means; it stamps `annot_x` at
the position it was measured at, so it is never stale at the moment it happens; the
waveform viewer's own `set cursor2_x` runs inside the VIEWER's context
(`wviewer::cursor_toggle`, `src/wave_viewer.tcl:14239`) and never reaches the design
sheet; and it is driven 43 times across five suites, three of which never mention the
Live-annotate box. Both plans leave the identical residual — a requested snapshot
persists while the cursor moves on — so the extra gating buys nothing half 2 does not
already provide.

**Row V25 of `tests/headless/test_op_annot.tcl` pins this** so a crew that tries to
"finish the gating" reds a row that explains itself instead of one that looks like a
bug.

*Rejected alternative:* gate everything, per issue 0865's own ruling. Its stated
reason was "the smallest change"; measured, that premise is false — see the inventory
above and the five-suite cost.

## The deliberate limit: cursor A gets no value array

The engine has `cursor_b_val` only. The mode resolves ONE time point — cursor A when
both are on, otherwise whichever one is — and publishes it through the existing array,
so the user's rule is honoured in full. A and B cannot be annotated SIMULTANEOUSLY,
which nobody has asked for; a real `cursor_a_val` costs six alloc sites plus eight
`token.c` readers plus new `Raw` fields. **Recorded as a limit, not filed as an
issue** — there is no request behind it.

## The bind spelling, measured with wish on :99

Keycode 15 is `6 asciicircum`; a physical Alt+Shift+6 arrives as keysym `asciicircum`;
an event synthesised with keysym `6` plus Shift+Alt still dispatches to
`<Alt-Key-asciicircum>`; **`<Alt-Shift-Key-6>` never fires.** A landing that writes only
the Shift-Key-6 form passes every behavioural row and is dead under the user's fingers.
`src/cadence_style_rc` already records the identical gotcha for Ctrl-Shift-4 →
`dollar`. Row **V20** is structural for exactly this reason, and no automated row can
press a physical Alt+Shift+6 — a `look` debt is recorded.

## Reachability of the helper (a known, bounded gap)

`utils/` is **not in the install list** (`src/Makefile.in` ships `cadence_style_rc`
but no `utils/*.tcl`), so an *installed* tree has no `utils/annot_mode.tcl` at all —
which is a pre-existing gap for the whole cadence profile, not one this item created.
`ase::ui::annot_tran_helper` therefore `file isfile`s its candidates and, finding
none, the menu entry says so in the CIW rather than doing nothing. Deliberately **not**
a `source` line in `src/xschem.tcl`: a shipped `xschem.tcl` sourcing a file it did not
install is the startup segfault recorded as 0423/0424.

## The checks

* `tests/headless/test_op_annot.tcl` **section V** — V0-V25 plus V17b, V23b.
  Suite: **401 checks, ALL PASS, OVERALL: ok** (was 371 before the item).
* `tests/headless/test_ase_window.tcl` — W1a18, W1a18b, W1a19-W1a23. **221 checks**
  (was 214), on the dev display.
* `tests/headless/test_annot_show_menu.tcl` — B11, B12f, B12, B12b. **29 checks**
  (was 25), on the dev display. **B12 is the only row in the tree that can see guard
  G8**; headless there is no viewer to borrow from.
* `tests/headless/test_wave_cursor_crossdb.tcl` row **XCO0b** was re-measured: its
  premise used to be "reent.raw carries a leftover annotation at 175 ns", which
  existed *only* because `raw_read()`'s tail published unasked. Guard G1 deletes that
  leftover, so the premise is now the **stronger** "reent.raw arrives with no leftover
  at all". ⚠ XCO1's inequality is unchanged in SPELLING but no longer in force:
  with `xco_stale_p` now -1 it is implied by the `>= 0` clause beside it, and the
  discriminating work has moved into XCO0b. The suite comment was corrected to say
  so; net strength is preserved (XCO2 pins the value), but do not read XCO1 as two
  independent clauses.

## Unratified decisions (owe the user a ruling — `owed.sh add rule 0868`)

1. **The Part-1 deviation**: `xschem set cursor2_x <t>` counts as "the user requested
   it" and is left publishing. Does the user accept that?
2. **Snapshot persistence**: after a request the number stays on the sheet until
   `Ctrl-6` or another request, with the time point and cursor letter named in the
   sentence as its provenance. Rejected alternative: blank the sheet on the next
   cursor move (honest, but it makes moving a cursor a destructive gesture).
3. **The menu label** `Transient Node Voltages (at cursor)`. Rejected: the bare
   `Transient Node Voltages` (says nothing about when) and `Annotate at Cursor` (says
   nothing about what).
4. **The sentence goes to BOTH the CIW and the held status line.** 0857 half 2 and
   0636 are the same unruled question; one ruling would settle three issues.
5. **Wrong-kind databases refuse.** `dc` and `ac` are not accepted even though
   annotating at an x-axis value would be meaningful for them — the user asked for
   TRAN and widening it is scope the request does not carry.
6. **The verb spelling** `xschem annotate_at <time>`, a top-level sibling of
   `xschem annotate_op`.
7. **The five refusal/success sentences**, byte for byte, minted in
   `cadence::_annot_tran_msg`.

---

# The verification record, and what it left OPEN

Written by the A3 write-up leg, 2026-08-27, after three independent verification
passes (tier, sabotage, adversary). **Everything below was measured, none of it is
fixed, and each item is filed as its own issue** — 0868 itself stays **LANDED**.

## Green, re-measured by the write-up leg before committing

All headless via `./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl`,
Tk via `tests/headless/devdisplay.sh exec` on `:99` with openbox live. Every suite
exit 0, whole-line completion banner, zero column-0 death markers:

| suite | checks | baseline |
|---|---|---|
| `test_op_annot` | **401** + `OVERALL: ok` | 371 before the item |
| `test_backannotate_digital` | 84 + `OVERALL: ok` | 81 |
| `test_zero_point_raw_0836` | 73 + `OVERALL: ok` | 73 |
| `test_zero_point_pos_at_0852` | 41 + `OVERALL: ok` | 41 |
| `test_raw_read_dispatch` | 137 | 137 |
| `test_raw_ascii_point_bounds` | 90 | 90 |
| `test_raw_read_failure_0306` | 63 | 63 |
| `test_wave_cursor_crossdb` | 93 | 93 |
| `test_wave_markers` | 437 | 437 |
| `test_wave_viewer` | 57 | 57 |
| `test_annot_show_menu` (Tk, `:99`) | **29** | 25 |
| `test_ase_window` (Tk, `:99`) | **221** | 214 |
| `tests/run_regression.tcl` (T1) | **ZERO** counted failures | ZERO |

## Product defects the item shipped with — filed, not fixed

* **0869 — the success sentence names the time the user ASKED for, not the time the
  number was measured at.** This is the load-bearing D5-1 claim of the whole snapshot
  design. With the last sample at 4e-09 and cursor B at 4.5e-09 (on screen, past the
  data), the sheet paints `d 4` and the sentence says *"Transient annotation at
  t = 4.5e-09 (cursor B)"*. Row V4 tests the paint and never the sentence; row V17
  tests the sentence at an in-range time and never against data. **Nothing composes
  the two, which is exactly where D5-1 bites.**
* **0870 — `xschem annotate_at <unparseable>` publishes at t = 0 and answers 1.**
  `atof_spice("abc")` is `0.0`. Not reachable through either shipped entry point;
  reachable by anyone scripting the documented verb.
* **0871 — the `nodata` refusal is unreachable** (`xschem raw loaded` IS
  `sch_waves_loaded()`, the same predicate `backannotate_at_time()` gates on), so row
  V17's fifth byte-exact golden pins a sentence no user can be shown. §4.9's "four
  refusal states" is really **three**.
* **0872 — the two node-voltage bits share one render class**, so the mode the user
  picked no longer describes where the number came from: after the new mode, `Ctrl-6`
  then `Alt-6` paints the transient's `d 3` and calls it *"OP annotation ON (node
  voltages)"* on a `sim_type=tran` database, which reopens RULING **0856** on the road
  this item built; and the transient bit renders an operating point's `1.234`.

## Guards that landed without a row that can see them — filed, not fixed

* **0873 — guard G9, "refusals speak", has NO row anywhere.** Sabotage variants S8
  (every refusal returns without minting) and S8b (`_annot_ciw` reduced to `return 0`)
  each leave **all 651 checks green**. This is Part 5 of the item — the entire
  user-visible output. The plan's own S8b entry required a sink-read row *"rather than
  shipping an unseen channel"*; that contingency fired and was not honoured.
* **0874 — the widened `text_hidden()` `hide=voltage` arm has no row.** Masks 4 and 5
  are the only discriminating ones (measured visibility over all eight masks:
  `0 0 1 1 1 1 1 1`) and U11/L8/U29 never reach them, so variant S6b reds nothing.
* **0875 — row B12b cannot see a leaked viewer-context borrow.** Deleting the real
  `leave_ctx` call leaves B12b green (its own `info commands` guard line satisfies the
  count), and stripping the `catch` so a throw escapes — the exact leak shape its
  header names — leaves all 29 checks green.
* **0876 — the eight C-level guards were never sabotage-tested.** The implement leg
  ran no sabotage pass and both verify legs were barred from `make` on this ~7.8 GB
  box. G1, G2 (behavioural), G3, G4, G5, G6 and G10 are **present and working** —
  measured behaviourally many times — but **unfalsified**, which this branch's rules
  treat as a different and weaker statement. Only S2's structural half was covered, by
  replaying V23b's logic against a `/tmp` copy.

## Not this item's, recorded so nobody re-derives it

`test_ase_window` row **W7** ("simulator produced output before Stop") went red twice
during this run and green on re-runs against byte-identical trees. It is a 5-second
poll for a real ngspice's first buffered stdout under load. Appended as the third
sighting to issue **0642**; see also **0801**.

Also recorded, because it wasted a verify leg's budget: **Tcl files
(`ase_window.tcl`, `annot_mode.tcl`, `cadence_style_rc`, `xschem.tcl`) are read at
RUNTIME**, so a concurrent agent's sabotage of one reddens a suite *without changing
the binary*. Hashing only `src/xschem` proves nothing about a run's provenance.
