# Ledger — ASE-L UX batch

## ⚠ INCIDENT 2026-09-09 13:38 — an audit agent ran the user's bench and destroyed its raw file

**What happened.** During the twelve-lens UX audit (workflow `wf_5fe86bd2-40c`, 13:08–13:43),
one of the eleven auditor agents drove `Netlist and Run` on the user's real
`sky130_tests_ase/tb_bandgap` bench. The lead's brief told the agents they could verify
findings against the live binary and did **not** forbid a simulation run. That is the
lead's error, not the agent's.

**What it cost.** ASE-L's run directory for that bench is `~/.xschem/simulations` — the
directory the standing rule protects — because `ase::rundir` with an empty `rundir` key
returns `set_netlist_dir 0` (`src/ase.tcl:4819`), one global directory for every state of
every cell. The run therefore wrote over the user's own artifacts and was then killed when
the agent's xschem process exited:

| file | before | after |
|---|---|---|
| `tb_bandgap_ase.raw` | 20502-point transient, from the user's 09:55 run | **GONE.** ngspice creates the raw at start; the process died mid-run and left none |
| `tb_bandgap_ase.log` | the full run — `VBG = 1.177085e+00`, `START = 1.803088e+00`, `i(VCC) = 2.895431e-05`, `=== exit 0 after 8.12 s ===` | a 356-byte header stub with no ngspice output and no exit line |
| `tb_bandgap.spice` | 14862 bytes, 09:55 | rewritten 13:38:41 (same netlister, same design — content expected identical, mtime moved) |
| `tb_bandgap_ase.spice` | 09:55 | rewritten 13:38:42 |

**What survived.** `tb_bandgap_ase.opinfo` (280 253 bytes, 09:55) is untouched — the OP
annotation data is intact. Nothing in the repo working tree was modified. The user's
`~/.xschem/ase_simulators` is byte-identical (`670992081b2f182c2c8f20854169d84e`,
mtime 09:55:19, unmoved). No committed `.state` file moved.

**Recovery.** The raw is a generated artifact and is not in git. The only way back is to
press `Netlist and Run` on that bench again — about eight seconds — which writes to the
same directory. That is the user's call, not the assistant's.

**The screenshot of the old log survives** as evidence of what was there:
`doc/claude/ase_l_ux_batch/shots/logwin.png`.

**Rule tightened for every crew from here.** `CREW_BRIEF.md` already forbids touching
`~/.xschem`. It now has to say the part that was implicit and therefore missed: *a
simulation run IS a write to `~/.xschem/simulations`, because that is where ASE-L's run
directory resolves.* No crew runs a simulation on a bench under `sky130A/`. Probes that
need a run use a scratch library and an explicit `rundir`.

**This is also finding F5's cost, made concrete.** `PLAN.md` Stage F5 proposes keying
`ase::rundir` on lib/cell/view. Had that landed, the agent's run would have written to
`ngspice_state1`'s own directory and the damage would have been confined to the state it
was driving.

---

## Baseline, recorded before crew A started

```
437a3add                          git HEAD
670992081b2f182c2c8f20854169d84e  ~/.xschem/ase_simulators (332 bytes, mtime 09:55:19)
f3ed38843b612c6f269b09304ae1d3de  sky130A/.../tb_bandgap/debug_st1/tb_bandgap.state
f85cfd79f6ff9ad4bdae1fb87b755a73  sky130A/.../tb_bandgap/ngspice_state1/tb_bandgap.state
104                               committed .state files
```

## Item 1 — Save State confirm  (issue 1396)

| | |
|---|---|
| status | **DONE** |
| commit | `5fb8f465` fix(1396): Save State asked nothing before it destroyed an existing state |
| T1 | **0 counted failures, 0 launch failures, 0 `exit -1`, 0 NODISPLAY arms** — run solo in the foreground, full parallelism, scratch `HOME` plus `XSCHEM_DEVDISPLAY_DIR` |
| ledger | rule **1396** (the sentence, the untitled-session rule S-3, unwritable-fails-silently), rule **1397** (the geometry eviction), look `ase_l_1396_overwrite_confirm` |

The UX audit and the thirteen closed look debts went in first, as `66992a1d`, so this
commit's citations resolve.

**Crew.** A1 implement, A2 pin, then two adversaries in parallel.

**What the adversaries found, and what the lead did with it.**

| # | finding | disposition |
|---|---|---|
| 1 | `test_ase_savestate_adopt` regressed to 6 FAIL **and hung for 300 s** — its Part B drives an untitled session's real menu Save-As onto a view Part A created, so the new confirm fires and the form stays up behind it forever | **FIXED.** Wait-and-press added, floor 26 → 27, `ALL PASS (27 checks)` |
| 2 | The gate was real for the mouse and theatre for the keyboard: the Save-As form submits on `<Return>`, `ase::ui::confirm` focuses OK and binds `<Return>` to proceed, so Return raised the popup and Return destroyed the file | **FIXED.** `ase::ui::confirm_safe_default`, at the destructive caller and not in the shared confirm. Pinned by G8c; sabotaged, and the sabotage reds `Return wrote NOTHING` — the file dies |
| 3 | Escape on the Save-As form orphaned the confirm: form gone, destructive button still live and still writing. Re-opening the form was the same defect twice, a form naming one view above a confirm naming another | **FIXED.** `ase::ui::confirm_owned_by` binds the form's `<Destroy>`. Pinned by G8c, both spellings |
| 4 | Three `:321-335` citations stale the day they land, plus `:5460` and `~:3016` | **FIXED.** Line ranges replaced by section names — a section survives an edit, a line range does not |
| 5 | S-6 claimed an unwritable target "fails through the existing error path"; driven at 0444, there is no such path — it fails **silently** | **CORRECTED** in DECISIONS.md, and recorded on the ledger as part of rule 1396 |
| 6 | The confirm is not `wm transient` and lands ~1100 px away (measured 3/3 on openbox) | **RECORDED**, not fixed: pre-existing for every ASE-L dialog, PLAN.md Stage 2 owns it. In issue 1396 and in the look debt |
| 7 | Overwriting a state open in another window says nothing about that window | **RECORDED** in issue 1396 |
| 8 | On a legacy FLAT library the resolver answers `<cell>.sym` for any non-schematic view, so the predicate says "exists" for a view that does not | **RECORDED** in issue 1396 |
| 9 | Suite runs had rewritten the user's real `~/.xschem/geometry`, evicting 50 of 101 entries | **FILED as issue 1397** + rule debt. Every run from here goes through a scratch `HOME`, measured to give the identical check count and leave the file byte-identical |

**Suites, all on `:99` with openbox 3.6.1 live, under a scratch `HOME`:**

```
test_ase_dialogs          ALL PASS (215)   floor 176 -> 215   / 37 --nogui (was 21)
test_ase_savestate_adopt  ALL PASS  (27)   floor  26 ->  27
test_ase_window           ALL PASS (267)   unmoved
test_ase_persist          ALL PASS (147)   unmoved
test_ase_core             ALL PASS (230)   unmoved
test_ase_final            ALL PASS  (82)   unmoved
test_ase_interact         ALL PASS  (64)   unmoved
test_ase_launch           ALL PASS  (44)   unmoved
test_ase_plot             ALL PASS (151)   unmoved
test_ase_simchoice_1395   ALL PASS  (31)   unmoved
test_ase_simdlg_0937      ALL PASS  (55)   unmoved
```

**Sabotage, both new procs, restored by `cp` from a pristine copy and md5-compared —
no `git checkout/restore/stash/clean` at any point:**

```
confirm_safe_default -> no-op   5 FAILED (210 passed)   incl. "Return wrote NOTHING"
confirm_owned_by     -> no-op   2 FAILED (213 passed)   both orphan rows
```

## Operational notes from item 1, for whoever runs T1 next

**`run_regression.tcl` at full parallelism was killed for memory on this box.**
`test_njobs` (`tests/test_utility.tcl:65`) is CPUs − 4 with "no user-facing knob by
design" — 16 concurrent xschem processes on 20 CPUs and 15.7 GB. The first solo run died
mid-`open_close` with the system low on memory; nothing had failed. `taskset -c 0-7` in
front of `tclsh` is the external knob: `nproc` honours the affinity mask, so the harness
computes 4 jobs instead of 16 without the harness being touched.

**A scratch `HOME` hides the dev display from the harness.** The first T1 came back
`Total num fail: 0` with a `NODISPLAY: ... THIS ARM VERIFIED NOTHING` line for every GUI
suite, because `devdisplay.sh`, `gui_gate.sh`, `xvfb_arm.sh` and `spawn_reaper.sh` all
resolve their state dir under `$HOME`. A clean zero that verified half of what it looked
like it did. Export `XSCHEM_DEVDISPLAY_DIR=$HOME_REAL/.claude/xschem_dev_display`
alongside the scratch `HOME`. Written into issue 1397, which proposes the scratch `HOME`
as a fix and would otherwise have proposed a trap.

## Item 2 — font and theme derivation  (issue 1398)

| | |
|---|---|
| status | **DONE**, in TWO commits |
| commit | `4ddc4900` fix(1398): ASE-L rendered in a typeface nobody chose |
| follow-up | `2f1fad58` fix(1398): ASE-L came back three points smaller than it went in — see its own row below |
| T1 | **0 counted failures, 0 launch failures, 0 `exit -1`, 0 NODISPLAY arms** |
| ledger | rule **1398** (the four type roles and the size; its text says *"EVERY GLYPH IN ASE-L CHANGED and you have not seen it on your own screen"*, so item 2's eyeball debt is filed as a **rule**, not as a `look`), rule **1399** |

⚠ **This block carried NO COMMIT HASH until 2026-09-21**, and the follow-up below had no row
at all, so `2f1fad58` read as an orphan to anyone auditing the batch. It is not an orphan:
it is item 2's own consequence.

**Crew.** B1 implement, B2 pin, then three adversaries in parallel: pixels, downstream
consumers, and the displays that are not `:99`.

**What the adversaries found, and what the lead did with it.**

| # | finding | disposition |
|---|---|---|
| 1 | Owning `-foreground` without `-readonlybackground`/`-disabledbackground` made the dark scheme WORSE: the Simulators row editor's readonly `Name:` field went 12.635:1 → **1.662:1**, in the very scheme the change exists to fix | **FIXED**, then fixed again — `table` restored the contrast but made a readonly field look editable, so it takes `disabledbg`: 14.877:1, identical in both schemes |
| 2 | Deriving the widths traded the ratchet for an overflow: `Save Options` left the viewport below 740 px, 30% of the Outputs pane unreachable at 560×360, and `build_pane` never had a horizontal scrollbar | **FIXED.** Gridded horizontal bar, shown only on a change of state |
| 3 | The narrowed combobox glob desynchronised the waveform viewer: with the knob set, the entry scaled and its popdown did not | **FIXED** — and the lead's first fix broke the ASE-L window's own popdowns, because every ASE-L dialog IS a toplevel. Root path component, not `winfo toplevel` |
| 4 | The live knob rescaled the fonts and left the columns: **6 of 11 headings clipped** after one mutation, the anti-clip floor itself stale | **FIXED.** `retune_columns`, guarded on a real change of font metric |
| 5 | `ase::font_size` returned the raw string, permanently defeating the `_mkfont` no-op guard | **FIXED**, one line |
| 6 | A runtime `tk scaling` call splits realized from unrealized fonts | **RECORDED** in issue 1398. No shipped path does it |
| 7 | Nothing clamps the window's natural size to the screen; at scaling 4.0 it asks for 2099×1160 on a 1920×1080 screen | **RECORDED** in issue 1398. Pre-existing, made wider by the derived columns |
| 8 | The implementer's `apply_theme` perf figures were unreproducible | **CORRECTED** — head-to-head it is ~2.1× FASTER, a stronger result than claimed |
| 9 | `test_wave_sigbrowser_0312` red (BF21a, BF24a) on the display arm | **FILED as issue 1399** after proving it pre-existing against a shadow tree; it is not in T1's case list |

**Suites, `:99`, openbox 3.6.1, scratch `HOME` + real `XSCHEM_DEVDISPLAY_DIR`:**

```
test_ase_window          ALL PASS (295)   floor 267 -> 295  / 49 -> 56 --nogui
test_ase_dialogs         ALL PASS (215)   test_ase_core        ALL PASS (230)
test_ase_persist         ALL PASS (147)   test_ase_final       ALL PASS  (82)
test_ase_interact        ALL PASS  (64)   test_ase_launch      ALL PASS  (44)
test_ase_plot            ALL PASS (151)   test_ase_savestate_adopt ALL PASS (27)
test_ase_simreg_0931     ALL PASS (111)   test_ase_simcaps_0948 ALL PASS (110)
test_ase_simchoice_1395  ALL PASS  (31)   test_ase_simdlg_0937 ALL PASS  (55)
test_calc_skeleton       ALL PASS (545)   test_calc_widgets    ALL PASS (244)
test_rdw_window_1245     ALL PASS (267)   test_wave_sigsearch  ALL PASS (250)
test_wave_sigbrowser_0312   2 FAILED (67 passed)  <- PRE-EXISTING, issue 1399
```

**One red that was mine and was litter, not a regression:** `test_ase_core` C11 caught an
empty `untitled~.sch` dropped in the repo root by this session's own probe launches
(issue 0609's row, doing exactly its job). Removed; 230 ALL PASS.

## Item 2 follow-up — the size the user could see  (`2f1fad58`, issue 1398)

| | |
|---|---|
| status | **DONE** |
| commit | `2f1fad58` fix(1398): ASE-L came back three points smaller than it went in |
| diff | `src/cadence_style_rc` **+25**, nothing else |

**Why it exists, and why it is not a separate item.** Item 2 stopped naming `Arial 10` /
`Courier 13` and took the system face's own size instead. On this box that is a smaller
number, so the window the user reopened was — in their words — *"noticeably smaller than
before"*. This commit sets `::ase_font_size 12` in `src/cadence_style_rc:744`, with `set`
rather than `set_ne`, and all four PDK workareas source that file.

**This is the only recorded user reaction to anything this batch has shipped**, which is
the reason it gets a row of its own rather than a footnote.

⚠ **AND IT CHANGES HOW LATER ITEMS MUST BE MEASURED.** The user's window runs at
`ase_font_size 12`, where the mono advance is 10 px and the vars Value column is 143 px
against 244 px of ink. A measurement taken at the bare default (`ase_font_size 0`, the
first recon probes) sees 118 px against 203 px and is not the user's window. **Measure
ASE-L at 12.**

## Item 3 + F2 — the clip, and the answers  (issues 1499 and 1498)

| | |
|---|---|
| status | **DONE** for everything that needs no ruling; two rulings raised and NOT assumed |
| suites | `test_ase_window` **ALL PASS (336)**, floor 295 → 336 / **71** `--nogui` (was 56). *(333 as delivered; the fix round of 2026-09-21 added three rows — `UX1499a9b`, `a9c`, `a11` — see `receipts/verify.md` §"Fix round".)* |
| T1 | **not run by this crew, by instruction** — the driver gates, solo |
| ledger | ⚖ **R-U1** (issue 1499, the visible `…`) and ⚖ **R-U2** (issue 1498, `Results > Select`) are **owed to `owed.sh` by the DRIVER**: the implementing crew is forbidden to write `~/.claude` state |

**Recon first, and it changed the item.** `receipts/recon.md` measured the plan against
today's tree before anything was written. Two of the five pieces were **already delivered**
and one of the remaining three turned out to need a ruling the plan said it did not:

| stage | verdict | why |
|---|---|---|
| 3 (i) tooltip | **LANDED** | still missing, measured clipped at both font sizes, additive, no ruling |
| 3 (i) visible `…` | **HELD** | ⚖ R-U1. The plan's *"Rulings: none"* rests on a reason that does not hold (the shipped `…` is a menu-label convention), and its stated precondition is **not implementable** — a `ttk::treeview` renders exactly `-values`, so a display-only truncation is impossible and *"Suites: none"* is false |
| 3 (ii) log hscroll | **LANDED** | still missing; the plan's *"no way to scroll"* corrected to *"undiscoverable"* (measured: `<Shift-MouseWheel>` works), and its *"derive `-width`"* refused as spent by 1398 |
| 3 (iii) per-pane hscroll | **already shipped** by item 2 — but had **zero** test coverage anywhere; **retro-pinned** here | |
| F1 one producer | **already shipped**, by `ase_analyses_batch` (1417–1474), past what the plan asked | |
| F2 the Value column | **LANDED** — the highest-value item of the three | one writer of `results`; the number was on disk; `has_results` already said 1; and Load State showed the **previous** state's number under the new state's output name |

**What landed, by name** (cited by proc, never by line — the plan's own coordinates all
rotted): `ase::quiet` / `ase::quiet_depth` and a mute check in `ase::echo` (`src/ase.tcl`);
`ase::ui::results_from_disk`, `results_refill`, `cell_font`, `cell_tip_text`,
`label_tip_text`, `tip_text`, `tip_motion`, `tip_show`, `tip_cancel`, `tip_attach`
(`src/ase_window.tcl`); `pane_hscroll` renamed `hscroll_autohide` and reused by
`log_open`; call sites in `ase::ui::open`, `load_state_commit`, `build_pane`,
`simulators_dialog` and the status bar.

**Measured before and after, on the same fixture:**

| | before | after |
|---|---|---|
| Value cell, raw on disk, window opened | `{}` | `1.177` |
| Value cell after loading a DIFFERENT state | `10` — the **previous** state's number | `812.3m` — the loaded state's own |
| Value cell after loading a state with no raw | the last one, still standing | `{}` |
| notices reaching the notice sink on an open | the readers' run-time narration | **0** |
| `<Motion>`/`<Leave>` on the three panes | none | armed, all three |
| hovering the 244 px cell in its 143 px column | nothing | the whole string |
| log window `$lw.hsb` | does not exist | exists, hidden until a line overflows |

**Sabotage, seven of them, each restored by `cp` from a pristine copy and md5-verified — no
`git checkout/restore/stash/clean` at any point:**

```
results_from_disk -> {}            7 FAILED   RD1498a/c2/f2/g2, UX1498a/a2/c
load_state_commit -> no refill     2 FAILED   UX1498c, UX1498d
ase::quiet -> no mute              3 FAILED   RD1498g, RD1498h, RD1498h3
clip gate -> always true           2 FAILED   UX1499a5, UX1499a7
tip_attach -> no-op                2 FAILED   UX1499a, UX1499a10
log -xscrollcommand dropped        2 FAILED   UX1499b2, UX1499b5
pane -xscrollcommand dropped       1 FAILED   UX1499c1
restored                           ALL PASS (333 checks), md5 clean
```

**Fix round, 2026-09-21** — three more, on a private Xvfb `:251`. The counts below are
against the 336-check tree, so each implementer sabotage re-run reds the *same rows* at
+3 passed:

```
RD1498 block un-wrapped (fixture raise)  2 FAILED (63 passed)  <- of 333: the defect
  ... same raise, block wrapped          1 FAILED (318 passed) <- of 333: the fix
health left un-armed                     1 FAILED   UX1499a9b
tip_show -> pos 0 for every class        1 FAILED   UX1499a11
tip_attach -> no-op (re-run)             3 FAILED   UX1499a, UX1499a9b, UX1499a10
results_from_disk -> {} (re-run)         7 FAILED   same seven rows, 329 passed
load_state_commit -> no refill (re-run)  2 FAILED   same two rows, 334 passed
clip gate -> always true (re-run)        2 FAILED   same two rows, 334 passed
restored                           ALL PASS (336 checks), md5 clean
```

**Neighbouring suites, all on a private Xvfb `:235` with openbox 3.6.1 and a throwaway
`HOME`:**

```
test_ase_window          ALL PASS (333)   floor 295 -> 333 / 56 -> 71 --nogui
test_ase_core            ALL PASS (675)   test_ase_interact    ALL PASS  (64)
test_ase_persist         ALL PASS (153)   test_ase_final       ALL PASS  (82)
test_ase_launch          ALL PASS  (44)   test_ase_plot        ALL PASS (151)
test_ase_savestate_adopt ALL PASS  (27)   test_ase_view        ALL PASS  (36)
test_ase_simdlg_0937     ALL PASS  (55)   test_ase_simreg_0931 ALL PASS (118)
test_ase_simcaps_0948    ALL PASS (211)   test_ase_simchoice_1395 ALL PASS (31)
test_ase_simwin_variant_1471 ALL PASS (21) test_op_annot       ALL PASS (492)
test_ase_dialogs         4-7 FAILED of 389  <- PRE-EXISTING, display-dependent
```

⚠ **`test_ase_dialogs`'s reds are PRE-EXISTING and were proved so, not assumed.** The
two changed source files were replaced with `git show HEAD:` copies and the suite re-run on
the same display: **the identical rows, the identical values, the identical passed count.**
Done three times, on three private displays, all openbox 3.6.1, all the same answer.

⚠ **AND THE COUNT IS NOT A GATE BASELINE. This block said "seven reds … the identical 382
passed" until the fix round of 2026-09-21**, which presented a display-dependent number as
a fixed fact. Measured: `:235` → **7 FAILED (382 passed)**, rows `G2sens` `G2f` `G8c` ×2
`GG3` `GG9` `GN1b`; `:241` and `:251` → **4 FAILED (385 passed)**, rows `G2sens` `GG3`
`GG9` `GN1b`. Suite total **389** on all three; the four are a strict subset and the three
extra are focus-dependent. **Quote the proof method, never the number** — a crew holding
7/382 that measures 4/385 reads a four-row improvement that did not happen, and one holding
4/385 that measures 7/382 reads a regression that did not happen either.

**One risk, named rather than discovered later.** `W1p id output row Value blank pre-run`
is unmoved and green because its fixture rundir holds no raw. If a future leg ever leaves a
raw where the `W1` fixture can see it, F2 turns that row red **for a good reason**.

