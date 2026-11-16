# Stage D2 verification: the orphaned-drag check (`fluid_reroute_orphan_check()`)

Verifier, 2026-11-15. Patch under test: `D-combined.patch` (md5 `6c0d21198ed4827c294d7cba96b1061a`,
checked) applied to `e6b38ba83` in the clone `~/gdv2`; `D2-incremental.patch` md5
`94056d1e5b096a16720f15ca844d3e32` checked. Compared against `~/gdb1` (B, base `e6b38ba83`) and
`~/gdv1` (D, base + `D-fix.patch`). N below means `~/gdv2`. All three were built from clean
`./configure && make -C src`; N's build has the same 6 warnings as B and D.

Displays `:270`-`:273` (Xvfb + openbox, this verifier's own), headless runs with `env -u DISPLAY`
and `AUDIT_DISPLAY=none`, a throwaway HOME per run.

## Verdict

**SAFE TO LAND, WITH LIMITS.** The check does what D2 says on every path measured: stage D's
finding F1 is closed (every orphan in the key sweep, the command sweep and the scripted tables now
reads declared), the live steps still declare nothing, and no path produced a stray `~`, an empty
`~`, another level's geometry in a `~`, or a crash. Cost is not measurable (about 1 ns per
`xschem` call). Nothing found is a regression against base that a real key or mouse reaches,
except the class in G1, which stage D introduced and D2 does not change.

## In plain English

Stage D stopped a drag from marking the page modified until it ends. D2 adds a check after every
xschem command: if that command ended a drag without finishing or cancelling it (undo, redo,
netlist, unselect pressed mid-drag) and the same page is still on screen, the page is marked
modified once. I tried to make that check fire when it should not, and to find a way round it.

It held. Undo, redo, netlist and unselect pressed mid-drag now mark the page and write its backup.
Loading another cell, clearing, reloading, saving and moving up or down the hierarchy mid-drag
write no backup and mark nothing. Pressing `e` mid-drag (the descend dialog) now keeps the drag on
the parent page, which stage D had lost. The check costs nothing you can measure.

Two things remain that you would notice. Pressing Ctrl-Q, Ctrl-W, or Ctrl-E in a child cell while
still holding the mouse button in a drag closes or leaves the page without asking to save. The
drag is simply dropped, as Escape would drop it. Before stage D it asked. Separately, and unchanged
since before this work, xschem offers crash recovery only when a cell opens in an empty window.
Opened in a new tab, or reached by descending, it does not offer, and the first edit then
overwrites the previous session's backup.

## Findings, ranked

### G1 (MEDIUM, user-visible, needs a ruling). Quit, close and go-up during a LIVE drag drop it with no prompt

Measured on the display arm with real key events while Button-1 is still held (state includes
`Button1Mask`), on a clean sheet:

| key mid-drag | B | D | N |
|---|---|---|---|
| Ctrl-Q (`quit_xschem`) | asks to save | quits, no prompt | quits, no prompt |
| Ctrl-W (`close_schematic_window`) | asks | closes, no prompt | closes, no prompt |
| Ctrl-E in a child (`go_back(1)`) | asks "bandgap has unsaved changes" | goes up, no prompt, drag gone | same as D |
| `e` (`hi_descend` dialog, then OK or Return) | descends, parent kept modified but restored from a stale mid-step `~` (27 wires on return against 17 on screen) | descends, parent comes back at disk geometry, clean: drag silently gone | descends, parent kept modified, `~` = the sheet on screen (17 wires), quit prompts |

- With prior unsaved edits all three builds prompt (the hold never clears `modified`), so no
  committed work is lost; what is lost is the drag in progress.
- The orphan check cannot cover the first three rows: the gesture is still LIVE (`STARTMOVE` set)
  when `hierarchy_close` reads `modified`, and for Ctrl-Q the process exits inside the KeyPress's
  own `xschem callback`, so no outermost return ever comes. This is the answer to focus (3): a
  gesture can end without the check running, by quit or close.
- It is the same class as D2's limit 1 (scripted `xschem descend` mid-drag discards the drag), and
  it is coherent with D-fix's own rule that an unfinished drag is not an edit (Escape drops it too).
  But it is a visible change from base, reachable with real keys, and silent.
- **The ruling to ask the user**: when a drag is still held and you quit, close, or go up, should
  xschem drop the drag (current) or keep it as an edit and ask (before)? If "keep", the place to do
  it is the start of those verbs (end the gesture with `move_objects(END)` before the prompt), not
  `unselect_all()`, which is where fix A failed.

### G2 (MEDIUM, pre-existing on base, worth an issue). Crash recovery is offered only on an in-place open

Focus (6). A foreign `bandgap~.sch` (p2 at 220 -80) was planted, then:

| how bandgap was reached | B | N |
|---|---|---|
| `xschem load -gui` into a pristine untitled window (in place) | offered once | offered once |
| `xschem load -gui` from an occupied window (routed to a new tab) | no offer, `~` left | same |
| `xschem load_new_window` | no offer, `~` left | same |
| `xschem descend` into x1, and `hi_descend` OK | no offer, `~` left | same |
| then any edit in that tab | the foreign `~` is overwritten with this session's sheet | same |

- Reading confirms it: in the `xschem load` branch, `xschem_recover_backup` is called only in the
  in-place `load_schematic()` arm; the routed arm goes through `new_schematic("create", …)`, which
  never reaches it. Identical in `~/gdb1`.
- So the usual restart path (reopen the testbench, open or descend into the cell that had unsaved
  work) never offers recovery, and the first edit destroys the only copy, with nothing said.
- Related: issue 0362 (consequence 3: a save destroys a backup the user was never shown). This adds
  the routed-open and descend routes, and the first *edit* (`write_backup()`) as the destroyer.
  Worth an issue, or a section in 0362.

### G3 (LOW, pre-existing on base, scripted only, worth an issue). The fluid snapshot survives a level change

The snapshot taken at START is per context, not per level, and descend and go_back do not drop it
(`clear_schematic()` does, via `fluid_reroute_discard()`). Then, on all of B, D and N, headless and
display:

- live drag on tb_bandgap's x1, `xschem descend`, then `xschem move_objects abort`: the CHILD's
  buffer becomes the parent's geometry (bandgap shows 34 instances and 11 wires).
- live drag in the child, `xschem go_back`, then `move_objects abort`: the parent shows the child's
  115 instances.
- live drag in the child, `xschem go_back`, then `move_objects end`: the parent is marked modified
  and `tb_bandgap~.sch` holds the CHILD's geometry (115C/58N). A save would write it into the
  testbench file.

Every real-input `move_objects(ABORT)` call site in `callback.c` and `scheduler.c` is gated on
`STARTMOVE`, which descend and go_back clear. The `move_objects(END)` sites read so far are gated
on `STARTMOVE` or `START_SYMPIN`, or close a gesture their own START opened (START calls
`fluid_reroute_discard()` first). No Tcl under `src/` calls `xschem move_objects abort|end`. So, as
far as this reading goes, only scripts and tests reach it. Not D2's: the check itself never wrote another
level's geometry in any case.

### G4 (LOW, scripted only, matches base). A declared orphan followed by a scripted abort

`xschem unselect_all` mid-drag, then `xschem move_objects abort`: N declares at the first command,
then the abort restores the pre-drag geometry. The sheet reads modified with a `~` holding the
cancelled drag. B gives the same; D stays clean. A real Escape after an orphan does not restore
(`abort_operation()` only aborts a move when `STARTMOVE` is set), so for real input the moved
shapes stay on screen and the declaration is right.

### G5 (LOW, scripted only). A same-file `xschem load -noundoreset` as the first command after an orphan

Live drag of l1 on bandgap, then `xschem load -noundoreset bandgap.sch` (or `-noundoreset -gui`):
the sheet is a fresh disk load (l1 back at 160 -30) but N declares it: modified 1 and
`bandgap~.sch` = the disk content (115C/48N). B marks it modified too, with the drag in the `~`; D
stays clean. The load latch is set only when `reset_undo` is set, and the level and file match, so
the check cannot tell this reload from the gesture's own document. The only Tcl that uses
`-noundoreset` (`cellview_setlabels`) loads a different file first, which sets the latch, so it is
not exposed. Setting the latch on every `load_schematic()` would need care: hierarchical netlisting
loads without reset too, and row O4 expects the netlist orphan to be declared.

### G6 (INFO). One unreproduced SIGSEGV, on D, not N

Probe `bk.tcl` row K15 (two contexts on one cell, headless) died once with `FATAL: signal 11` on
`~/gdv1` (D-fix) while six probes ran at once. It did not recur in 8 full and 15 K15-only reruns on
each of B, D and N, and `valgrind -q` of the whole probe is clean on all three. It was one
observation, so nothing was changed for it. Log: `o2_bk_gdv1.txt` in the scratch directory. Its
empty `/tmp/xschem_emergencysave_tb_bandgap_baddcaaagf` (named in that log) was removed.

### G7 (INFO). The START re-arm is redundant, so no fence is missing

A copy built with the latch reset at START removed passes the suite (60 and 71) and still declares
a second orphaned gesture, because START calls `fluid_reroute_discard()` first, which clears the
latch. Belt and braces, not a gap.

## The focus questions

**(1) F1 tables, key sweep, per-step flags.** All now read declared; live steps stay 0/0.

| probe | D | N | B |
|---|---|---|---|
| `cmds` (36 commands mid-drag) | UNDECLARED: `unselect_all`, `undo`, `redo`, `netlist -noalert`, `make_symbol` | UNDECLARED: `make_symbol` only (all builds, D2 limit 4) | `make_symbol` |
| key sweep (58 keys, `st\|256`, display) | UNDECLARED: `u`, `U`, `n` | **0 UNDECLARED**; D against N differs on exactly `u`, `U`, `n` | |
| `unsel` row unselect_all | modified 0 | modified 1, `~` 1 | 1 |
| `orphan` O1/O2 (quit after `unselect_all`) | quit silent, asks=0 | asks=1 | asks=1 |
| `disp` d08/d09 (area-select orphan) | modified 0, `~` 0 | 1, 1 | 1, 1 |
| `stepmod` (mod/bak at each live step, then abort) | 0/0 ×4, 0 0 | 0/0 ×4, 0 0 | |
| display live drags before any key (d5, d3, d3b) | | modified 0, no `~` at every live point | modified 1 |
| `hold.tcl` (34 rows), `savemid` | 34 ok; same | 34 ok; same | 34 ok |
| `bk.tcl` K1-K15 | same as N | same as D | 5 rows differ (stage D's K5 K8 K9 K14 K15) |

Also: `xschem save` right after an orphan now saves the moved shapes (D saved nothing, because the
sheet read clean), and a second orphaned gesture after a save or a reload is declared again.

**(2) Wrong fires.** Headless and display (display under valgrind, 0 errors), B / D / N:

| verb mid-drag | stray `~` | empty `~` | wrong level in `~` | crash |
|---|---|---|---|---|
| `clear`, `clear force`, `load`, `load -gui`, `reload`, `saveas`, at the top | B only | none | none | none |
| child: `clear force`, `load`, `go_back`, `go_back 0`, `go_back 2`, `go_back` answered yes | B only | none | none | none |
| `descend`, `descend 1 0` (live drag of x1 itself), display too | B only (`TB~` of the drag) | none | none | **none on N** (fix A's SIGSEGV site) |
| `undo`, `undo 0 0`, `redo` with history | none | none | none | none |
| `unselect_all` then `load`, `reload`, `undo`, new START | N keeps the declared `~` for a sheet then replaced, as B does for any edit (0362 consequence 1) | none | none | none |
| a parent with its own edits, orphan in the child, then up | none | none | none (child `~` = child, parent `~` = parent) | none |
| tab create / switch mid-drag (scripted, display) | none | none | none | none; the drag stays live in its own tab |

Double declarations exist and are harmless: the `u` key's `pop_undo()` declares and then the check
does, and a scripted `move_objects end` after an orphan declares again. Each writes the same sheet.
The only wrong fires found are G4 and G5, both scripted.

**(3) Ways round the check.**
- Every C entry from Tcl is the one `xschem` command (`Tcl_CreateCommand` in `xinit.c`). The only
  other C callbacks are two variable traces (`cadsnap_trace`: a cache flag; `ngspice_data_trace`:
  an annotation view index) and the exit handler; none touches `ui_state` or the selection. Tk
  bindings, Expose, `after` timers, menus and every tab and window reach C through `xschem
  callback` or another `xschem` verb.
- An orphan inside a nested event loop (a `vwait` inside Tcl run by an `xschem callback`, so at depth
  2) is deferred: modified 0 until the outer command returns, then declared. If the nested script
  then loads or clears, nothing is declared and no `~` is left (B leaves a stray `~`). Measured,
  probe `d3b.tcl`.
- Tab-switch keys do not fire mid-drag: Ctrl-Right, Ctrl-Left, Shift-Tab, Ctrl-Shift-Tab and both
  `ISO_Left_Tab` forms switch tabs with no button held (control run) and none switches with
  Button-1 held (probe `keystab.tcl`, B and N alike). A scripted tab create or switch does not
  orphan the drag.
- The gap is quit and close (G1): no outermost return for Ctrl-Q, and the gesture is live anyway.

**(4) Cost.** No measurable difference.

| | B | D | N |
|---|---|---|---|
| `xschem get ui_state`, median ns per call, idle, 4 rounds | 111.5-113.0 | 111.5-113.5 | 113.5-119.5 |
| same with a live armed drag | 111.5-113.0 | 111.5-116.5 | 113.0-116.0 |
| real drag frame (Motion with Button-1 held, then `update`), bandgap, 3 devices, median µs, 4 rounds | 6148-6358 | 5988-6141 | 5965-6264 |
| same, 8 devices | 14799-15525 | 13941-14285 | 13949-14211 |

40 frames × 3 drags per round, B/D/N interleaved four times on `:271`, `STARTMOVE` confirmed set at
the end of every drag. The check is three loads and a return while a drag is live, and runs once per
outermost command.

**(5) Can a real key reach descend while a drag is live?** Yes: `e` with Button-1 held is a plain
press for `hi_descend_keybind_script` (`%s & 0x4c` is 0), so it opens the `hi_descend` dialog, which
takes a grab; OK, Return, or a button release swallowed by the grab followed by OK, all descend with
the drag still live. On N this is not a loss: `hi_descend_current` and `hi_descend_newwin` both run
`xschem unselect_all` as an outermost command first, so the check declares the parent before the
descend. The parent returns modified with the geometry that was on screen. On D the same keys lose
the drag silently, so D2 fixes D here. The plain scripted `xschem descend` still discards (D2 limit
1); no key reaches it bare. Ctrl-E (up) does reach `go_back` mid-drag and drops the child's drag
(G1).

**(6) The `-gui` recovery gap.** Base behaviour, identical on `~/gdb1`; wider than D2 found
(descend and `load_new_window` too), and the next edit destroys the backup. Deserves an issue (G2).

## D2's claims, re-measured

| claim | result |
|---|---|
| §3: N ALL PASS (60) headless, (71) display | yes, and again under `valgrind -q` on both arms, logs empty |
| §5: D against N differ on `u`, `U`, `n`; none UNDECLARED on N | yes (own sweep, `:270`) |
| §2: D and N write no stray or empty `~` on the teardown verbs; N survives a mid-drag `descend` on the display | yes (G-table above); fix A itself not rebuilt here |
| §6: the occupied-window `-gui` open never offers recovery, also at `e6b38ba83` | yes, on `~/gdb1`; also descend and `load_new_window` |
| §8: `planned_cases` 201 → 203; delta +2 cases, +2 blocks, +0 counted, +0 skips, +6 `wc -l`; unchanged by D2 | yes: lists evaluated from all three trees; `tests/run_regression.tcl` change byte-identical in D and N; captures scored with all 16 procs lifted from `run_regression.tcl` and `banner_rule.tcl` sourced: one block of 3 lines per arm, `banner_complete` 1, 0 counted, 0 lowercase `skip:` (2 uppercase `SKIP:` headless) |
| §10.5: cost untimed | timed above |
| issue stamps | `tclsh tests/headless/issue_stamp.tcl`: `ISSUE-STAMP: ok (0 problems)` |

The comments in `fluid_reroute_orphan_check()`, `xschem()` and `save_schematic()` match the code
(the `unselect_all(1)` that orphans the gesture is indeed earlier in `save_schematic()`).

## Suites

`tests/headless/run_suites.sh` over the new suite plus stage D's 244-suite list, N only, each arm
under a private `/tmp` (`unshare`), compared to stage D's D verdicts from the same list:

- Headless (`AUDIT_DISPLAY=none`): **244 of 244 identical to D**, failing rows included; the new
  suite ALL PASS (60). Totals 175 PASS, 50 SKIP, 15 NORESULT, 5 FAIL, all as on D.
- Display (`AUDIT_DISPLAY=:272`, 1534 s): the new suite ALL PASS (71); **242 of 244 identical to
  D**. Totals 213 PASS, 11 FAIL, 8 NORESULT, 7 SKIP, 5 TIMEOUT, against D's 215, 9, 8, 7, 5. The
  two that differ were red on N only in the stream: `test_hier_pdf_links_1333` (2 FAILED, 87
  passed) and `test_wave_hilight` (1 FAILED, 195 passed). Rerun with `run_suites.sh -n 3` on a
  private display, both passed 3 of 3 on N and 3 of 3 on D (89 and 196 checks). Neither suite starts
  a drag, and the check returns at its first test when no drag is armed. In the stream they ran
  while this verifier's probes were loading the other three displays. Recorded as one
  unreproduced observation each, not as a difference. The 9 reds and 5 timeouts shared with D are
  stage D's (see `D-verify.md`), unchanged.

## Not covered

- Fix A was not rebuilt; D2's fix-A table is taken as measured.
- G1 and G5 have no fix proposed in code; G1 is the user's call.
- No `:0` or real-screen run, by rule. Key events are synthesised with explicit state bits; whether
  a physical Ctrl-Q with a held button produces the same state was not checked.
- An orphan and a new START inside one outermost command (D2 limit 3) was not driven directly; the
  one real key that does both (Ctrl-V paste mid-drag) aborts the first gesture itself first.

## State left behind

- `~/gdv2`: `e6b38ba83` + `D-combined.patch`, uncommitted, built. Suite litter listed and removed after the
  streams: 56 ignored `*~.sch` files, none tracked; `git status` now shows only the patch. `~/gdb1` and `~/gdv1` were only run.
- Displays `:270`-`:273` stopped by recorded pid. One orphaned key-sweep child (`-b -s --tcl set
  XSCHEM_START_WINDOW {}`, `DISPLAY=:270`, this verifier's throwaway HOME) was killed by pid.
- Scratch (trimmed): `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/dragDv/`.
  Probes in `scr/`: `attack.tcl`, `attack2.tcl`, `attack3.tcl`, `attack4.tcl` (headless tables),
  `d5.tcl`, `d5b.tcl` (descend and go-up keys), `d3.tcl`, `d3b.tcl` (tabs, nested loop), `d6.tcl`,
  `d6c.tcl` (recovery), `keysq2.tcl` (quit and close keys), `keystab.tcl` and `keystabc.tcl`
  (tab keys with and without a held button), `timing2.tcl`; runner `runh.sh`;
  results `o2_*.txt`, `rs/N_*.txt`, `vg2/`.
