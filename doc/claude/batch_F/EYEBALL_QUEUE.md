# Batch F — eyeball queue

**7 hand checks · 5 xschem sessions · ~95 minutes of steps (budget 2 hours).**

Branch `fluid-editing`, HEAD `6fabaaa5`. Batch F's 14 commits are all on this
branch and **nothing is pushed**. Each item below is a behaviour a headless
check cannot see; the one-line "not headless because" says which.

Work top to bottom. The order is by **fixture**, not by item number, so the tool
starts five times instead of seven.

---

## Before the first launch (once)

**1. Rebuild.**

```sh
cd /home/qflow/dev/xschem/claude_1/xschem
make -C src
```

`src/xschem` is dated 11 Aug 07:12 and `callback.c`'s last edit carries the same
minute stamp. Nothing proves the binary contains it. Rebuild and stop wondering.

**2. Build the fixtures.**

```sh
sh doc/claude/batch_F/eyeball_fixtures.sh
```

It synthesizes every raw and VCD as text (the `mkraw`/`mkvcd` idiom of
`tests/headless/test_ase_cosim.tcl` ~758/~768) — no ngspice, no verilator, no
PDK — plus two symbol libraries and the co-simulation map, into
**`/tmp/xschem_eyeball_F`**. It writes nowhere else, and it is safe to re-run at
any point: a re-run restores anything a step deliberately rewrote (item 4 step 9
rewrites the map). Launch lines are also in `/tmp/xschem_eyeball_F/RUN.txt`.

**3. Launch rules, all five sessions.**

* Always `./src/xschem` **from the repo root**. It prints
  `XSCHEM_SHAREDIR = .../claude_1/xschem/src`, i.e. the in-tree `ase.tcl` and
  `wave_viewer.tcl` are what run. An installed `xschem` loads the *installed*
  Tcl and every ASE step becomes meaningless.
* **Never add `-q`** — on the xschem command line that is `--quit`, not
  `--quiet`. **Never add `--nolog`** — it suppresses the CIW, which items 4, 5,
  6, 7 and 8 read from.
* Every session script sets `graph_use_ctrl_key 0`, so `f`, `m` and `b` over a
  graph are **plain keys**. If a graph key does nothing at all, check whether
  your `~/.xschem/xschemrc` sets `graph_use_ctrl_key 1` (then everything is
  `Ctrl-<key>`), and re-read the step before calling it a regression.

**4. The GUI control panel.** These are hand-run interactive xschem processes,
not suites: they enrol in nothing and the panel lists them as `UNGATED`. Leave
the panel alone — nothing here needs Proceed, and `Halt N xschem` will SIGSTOP
your fixture.

---

## The five sessions

| # | launch (from the repo root) | items | ~min |
|---|---|---|---|
| 1 | `DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s1_graphs.tcl` | 1, 8 | 24 |
| 2 | `DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s2_cursor.tcl` | 9 | 15 |
| 3 | `DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s3_browser.tcl` | 6, 7 | 27 |
| 4 | `DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s4_item5.tcl` | 5 | 15 |
| 5 | `DISPLAY=:0 ./src/xschem --rcfile /tmp/xschem_eyeball_F/lib4/f2rc /tmp/xschem_eyeball_F/lib4/dlib/tb4/schematic/tb4.sch` | 4 | 12 |

Quit each session with **File > Exit** and discard the untitled/modified
schematic. Nothing in any fixture is worth saving.

### ⚠ Item 5 is the one where "I saw nothing" is a FAILING result

Item 5's notice shipped once in a state where it was **written and erased inside
the same event-loop turn** — correct for one frame, gone before a human could
read it. Every automated check passed it because each read its surface in the
turn that wrote it. So at item 5, a sidebar that looks *untouched* a second after
the gesture is not "inconclusive" and not "I mis-clicked": it is the defect.
Take your hands off the keyboard and count to three before reading anything.

---

## Contradictions between the seven procedures, and what I kept

1. **Items 1 and 8 each asked for a private xschem.** Merged into session 1: one
   script, four strips. Item 8's three strips are rect indices 0/1/2 exactly as
   its steps assume (verified headless), item 1's is index 3 and is the only
   locked (`flags=graph`) strip — so it is still its own shared-X group of one.
   **Do item 1 first**: item 8's steps move the registry cursor.
2. **Registry slots renumbered for item 8.** Its procedure said `raw switch
   0/1/2/3` for short/long/sig.vcd/one; in the merged registry those are
   **2/3/4/5** (0 and 1 belong to item 1). Every step below uses the merged
   number and names the file.
3. **`f`/`m`/`b` modifier.** Item 1 assumed `graph_use_ctrl_key 0`, item 8 set it
   explicitly. Kept: all five scripts set it to 0 → plain keys.
4. **`XSCHEM_LIBRARY_PATH`.** Item 1 re-assigned it to itself, item 8 set `{}`,
   item 7 set the repo library. Kept: always written **unqualified** (that is the
   form whose write trace rebuilds `pathlist`), `{}` where no symbol is placed;
   `::XSCHEM_LIBRARY_DEFS` always **qualified**.
5. **Items 4 and 5 both define lib `dlib`, cell `dcell2` — with different verilog
   module names** (`realmod` vs `dcell2`), and item 5's expected refusal text
   quotes `module 'dcell2'`. **Not merged**: two library roots (`lib4/`,
   `lib5/`), two sessions.
6. **Items 6 and 7 each demand "exactly three database headers" over different
   files.** One session, two attach phases: typing `eye7` in the CIW re-points
   the same viewer at item 7's databases. Fallback if it does not repopulate:
   quit and launch `/tmp/xschem_eyeball_F/tcl/s3b_collide.tcl`.
7. **Item 9 demanded a rebuild mid-queue.** Moved to the single `make -C src`
   above.
8. **Item 4 was built by `~/f2eye_mkfix.sh` outside the repo.** Kept its
   `--rcfile` launch (that is how it was tested); the fixture is now built by
   `eyeball_fixtures.sh` into the scratch dir, and re-running that script is what
   restores the stale hint after step 9.

---
---

# SESSION 1 — items 1 and 8 (graph strips in one plain window)

```sh
cd /home/qflow/dev/xschem/claude_1/xschem
DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s1_graphs.tcl
```

The CIW log (`/tmp/Xschem.log.N`) must show, before you touch anything
(these fixtures report through `puts`, which lands in the CIW, **not** the
terminal you launched from):

```
ITEM 1: current DB = tran (must be tran)
ITEM 1: TOP.m.siga in current DB = -1 (must be -1)
SESSION 1 ready. rects=4 (must be 4)
```

That `-1` is the premise of item 1: the VCD's signal name **does not exist in the
database that is current**, so anything that resolves it must have honoured the
per-trace `%<rawfile>`. If either line is wrong, stop — the fixture is broken,
not the fix.

The registry (six databases, one window):

| slot | file | extent | contents |
|---|---|---|---|
| 0 | `nd0305/anlg.raw` tran | 0 … 2 ns | `v(anlg)` ramp 0.25 → 0.30 — **current at startup** |
| 1 | `nd0305/d1.vcd` vcd | 0 … 2 ns | `TOP.m.siga`, edges at 0.5/1.0/1.5/2.0 ns |
| 2 | `xd2/short.raw` tran | 0 … 2 ns | `v(anlg)` ramp 0.05 → 0.45 |
| 3 | `xd2/long.raw` tran | 0 … 2 µs | `v(anlg)` two full sine cycles |
| 4 | `xd2/sig.vcd` vcd | 0 … 500 ns | `TOP.m.sigd`, edges at 125/250/375/500 ns |
| 5 | `xd2/one.raw` tran | a POINT at 1 µs | `v(one)` — one sample |

Four strips, top to bottom on the canvas: **ITEM 1** (rect 3, locked), then
**STRIP 0 / 1 / 2** (rects 0/1/2, unlocked). Two CIW commands move between them
— type them in the CIW's one-line entry and press Return:

* **`eye1`** — fill the window with item 1's strip, current DB back to slot 0.
* **`eye8`** — fill the window with item 8's three strips, current DB → slot 2
  (`short.raw`), which is item 8's documented start state.

The script leaves you on `eye1`. **Do not click on a strip to select it** — a
selected strip joins the shared-X group.

---

## - [x] Item 1 — a cross-database (VCD) trace can be picked, bolded and read by a marker

`7a592f9c` · session 1 · ~12 min
*Not headless because:* pointer proximity, snap-cursor tracking, bolding and
marker callouts are pixels produced by mouse position.

**Steps**

1. Look before touching. One strip fills the window. Across its **top** are two
   legend names: `v(anlg)` left, one containing `vcdsig` right. Inside: a
   near-horizontal line about a third of the way up (`v(anlg)`, 0.25 → 0.30 V)
   and a square wave that is LOW (a flat run a little **below** the analog line)
   over the 1st and 3rd quarters and HIGH (near the top) over the 2nd and 4th.
   Both must be drawn — drawing was never the defect. If the canvas is blank,
   type `eye1` in the CIW.
2. Move the pointer slowly left-to-right along the **HIGH run** of the square
   wave (the flat top between ~1/4 and ~1/2 across). A small diamond snap-cursor
   must ride the square wave directly under the pointer for the whole run.
   *Failure:* the diamond sits on the analog line and never touches the square
   wave.
3. Click LMB once, no drag, directly on that HIGH run. The square wave — and
   only it — must over-stroke in the highlight colour (visibly heavier; marching
   if your net-hilight style animates). *Failure:* nothing changes at all, or the
   **analog** line bolds instead.
4. Click LMB on empty space inside the box to clear the bold, then click once on
   the right-hand legend name (`vcdsig`) at the top of the box. The square wave
   must bold again. *Failure, and the most diagnostic here:* the legend entry
   selects but the trace stays thin.
5. Pointer back on the HIGH run; press **`m`**. A marker must appear **on the
   square wave** with a callout `M1:<time>,1` — the value after the comma exactly
   `1`. *Failure:* the marker lands on the analog line reading `,0.275`.
6. Move onto the **LOW run** (first quarter, the flat line just under the analog
   line) and press `m`. Expect `M2:<time>,0`, marker on the square wave.
7. Control: pointer on the near-horizontal analog line, press `m`. Expect
   `M3:<time>,0.275` (0.25–0.30) with the marker on the analog line. If this one
   also reads 0 or 1, the two databases are swapped rather than separated.
8. Press and hold LMB on **M1's anchor diamond**, drag left and right along the
   square wave, release. The anchor must stay on the square wave, snapping
   between its two levels, callout still `,1` / `,0`. *Failure:* the anchor jumps
   to the analog line, or the callout starts reading 0.2x.
9. Type **`eye8`** in the CIW and go to item 8 in this same window.

**PASS** — the cross-database trace behaves exactly like the trace next to it:
snap-cursor tracks it; one LMB click on its body bolds it and nothing else; a
click on the `vcdsig` legend name bolds it; `m` gives exactly `,1` on the HIGH
run and `,0` on the LOW run with the glyph on the square wave; `m` on the analog
line still gives ~`0.275`; dragging an anchor keeps `,1`/`,0` throughout.

**FAIL** — "it draws but you cannot touch it". The square wave renders
perfectly, then: the snap-cursor parks on the analog line; a click straight on
the square wave bolds nothing (or bolds the analog trace); its legend name
selects but the trace stays thin; `m` over it drops a marker on the **analog**
line reading `,0.275`. That is pre-`7a592f9c`: the name resolved against
whatever database is current instead of the `%<rawfile>` the entry names.
**Not the same as "the feature never ran"**: if the square wave is absent
entirely, or the CIW's two ITEM 1 lines did not say `tran` and `-1`, the
fixture failed and nothing was tested. A crash (`FATAL: signal 11`) on any click
or `m` is the carried-sweep-column hazard — report immediately.

**Record —** date 2026-08-11  verdict ☒ PASS ☐ FAIL ☐ BLOCKED

> what I saw: all 8 steps as written. Diamond snap-cursor rode the square wave;
> LMB on its body bolded it alone; the `vcdsig` legend name bolded it; `m` gave
> `,1` on the HIGH run and `,0` on the LOW run with the glyph on the square wave;
> the analog control still read ~0.275; the M1 anchor drag stayed on the square
> wave with the callout snapping `,1`/`,0`. No crash.
>
> Two deviations, neither a defect: the three `ITEM 1` premise lines did not
> appear on the terminal (session launched with `&`; the fixture reports through
> the CIW), and `eye1` left all four strips on screen instead of filling the
> window with rect 3. Item 1's strip was the topmost and legible, so the steps
> ran against the intended strip.

---

## - [x] Item 8 — the auto X window (`f`) spans every contributing database

`81a2b53f` · session 1 (type `eye8` first) · ~12 min
*Not headless because:* the verdict is a picture — where a 500 ns square wave
stops inside a 2 µs window — and the key is a pointer-position-dependent bind.

**Steps**

1. Look before touching (this is the defect's own picture, seeded on purpose).
   **STRIP 0** shows two flat horizontal lines; **STRIP 1** shows a rising ramp
   across the full width plus a flat line at the bottom; **STRIP 2** looks empty.
   In the CIW: `xschem getprop rect 2 0 x2` → must answer `2e-9`.
2. **THE ITEM.** Pointer into the **middle** of STRIP 0's plot area — well clear
   of the narrow left-hand Y-axis margin — press lower-case **`f`**. PASS: STRIP
   0 redraws to a 2 µs window — two full sine cycles across the whole width, and
   the digital square wave occupying only the **left quarter** (two pulses, last
   edge at 500 ns) and then simply ending, no line at all beyond 25 % of the
   width. Confirm in the CIW: `xschem getprop rect 2 0 x2` → `2e-06`,
   `xschem getprop rect 2 0 x1` → `0`.
3. **Cursor independence.** CIW: `xschem raw switch 4` (slot 4 = `sig.vcd`, the
   500 ns VCD, becomes current). Pointer in the middle of STRIP 0, press `f`
   again. PASS: the picture does not change and `x2` still answers `2e-06`.
   (Optionally repeat with `xschem raw switch 5`, the single-sample database.)
4. **Production shape, part 1.** CIW: `xschem raw switch 3` (slot 3 =
   `long.raw`). Hover the middle of STRIP 1, press `f`. PASS: STRIP 1 now looks
   like STRIP 0 — two sine cycles full width, square wave in the left quarter —
   and `xschem getprop rect 2 1 x2` → `2e-06`.
5. **Production shape, part 2 — the thing NOT to report as a bug.** CIW:
   `xschem raw switch 4` (VCD current). Hover STRIP 1, press `f`. PASS: the
   window MOVES to 0…500 ns (`xschem getprop rect 2 1 x2` → `5e-07`), the square
   wave fills the width and the analog sine **disappears completely**. A bare
   `node=` entry follows the registry cursor, and the VCD has no `v(anlg)`. Only
   an all-`%` strip is cursor-independent (step 3).
6. **Degenerate refusal.** CIW: `xschem raw switch 2`. Hover STRIP 2, press `f`.
   PASS: **nothing happens**, and `xschem getprop rect 2 2 x1` / `x2` still
   answer `0` and `2e-6`. Judgement owed: the refusal is silent, so `f` reads
   here as a dead key. If that reads badly, say so — the agreed fix is a
   `ciw_echo`, never a zero-width window.
7. **Negative control — did the key even arrive?** Pointer inside STRIP 0's
   left-hand **Y-axis margin** (the narrow band left of the plot box, still
   inside the graph rectangle), press `f`. `xschem getprop rect 2 0 y1` / `y2`
   must move off `-0.2` / `1.2` (to roughly 0…1) while `x1` / `x2` stay `0` /
   `2e-06`. If this does nothing either, the key never reached the graph handler
   and steps 2–6 prove nothing.

**PASS** — `f` over STRIP 0 fits 0…2e-06, the **union** of the 2 µs raw and the
500 ns VCD, and keeps it whichever slot the cursor is parked on. STRIP 1 (bare +
`%`) gives 2e-06 with the long raw current and moves to 5e-07 with the VCD
current — correct, not a defect. STRIP 2's `f` is refused. The margin `f` still
does a full-Y zoom.

**FAIL** — at the parent commit `graph_fullxzoom()` never parsed the per-trace
`%<rawfile>`, so it sized from whatever was current: (1) step 2 changes
**nothing** — the strip stays 2 ns wide, two flat lines, `x2` still `2e-9`: a
silent, plausible, wrong answer; (2) step 3 **collapses** STRIP 0 to 0…5e-07 —
square wave full width, three quarters of the sine running off the right edge,
`x2` = `5e-07`; slot 3 would give 2e-06 and slot 5 a zero-width
`1e-06`..`1e-06`, i.e. three different windows for one unchanged strip; (3) step
6 writes `x1 = x2 = 1e-06` and the strip renders blank or garbage
(`setup_graph_data()` divides by `gr->gw == 0`).

**Record —** date 2026-08-11  verdict ☒ PASS ☐ FAIL ☐ BLOCKED

> what I saw: all 7 steps as written. The seeded `2e-9` picture was there; `f` in
> STRIP 0 fitted `0`…`2e-06` — the union of the 2 µs raw and the 500 ns VCD — with
> the square wave ending at the quarter mark, and held that window across
> `raw switch 4`. STRIP 1 gave `2e-06` on the long raw and moved to `5e-07` on the
> VCD, the documented cursor-following shape, not a defect. STRIP 2's `f` was
> refused with `x1`/`x2` intact.
>
> Step 7's margin full-Y zoom did nothing on the first attempt. `graph_left` is
> set from `mousex_snap` (`callback.c:1760`), so the snapped pointer had rounded
> back inside the plot box; aiming at a Y-axis tick number hard against the rect's
> left edge moved `y1`/`y2` off `-0.2`/`1.2` with `x1`/`x2` unchanged. Not a
> defect — and the control was already redundant, since four plot-area `f`
> presses had moved `x1`/`x2`.
>
> Judgement owed by step 6 (silent refusal on the degenerate strip) was not
> flagged: `f` reading as a dead key there is accepted as shipped.

---
---

# SESSION 2 — item 9 (cursor B across three databases)

```sh
cd /home/qflow/dev/xschem/claude_1/xschem
DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s2_cursor.tcl
```

The CIW log must end with `SESSION 2 ready -- registry:` and three slots
(`d4/anlg.raw` tran, `d4/d1.vcd` vcd, `d4/d2.vcd` vcd). If it says
`D4 SETUP FAILED: the viewer did not open`, that is the known ~3-in-10 WSLg
context-follow wobble in `wviewer::open` — quit and re-run the same line.

## - [x] Item 9 — one cursor at t, three databases

`c6d26026` · session 2 · ~15 min
*Not headless because:* the readout bar is drawn text under a cursor the mouse
places, and the drag smoothness has no programmatic proxy.

**Steps**

1. The window on top is titled **"D4 eyeball -- one cursor, three databases"**,
   960×640, **two stacked strips**: top = a straight analog ramp rising
   left-to-right **plus** a 0/1 square wave; bottom = a single 0/1 square wave.
   One empty strip, or the FAILED line above, means the fixture never built.
2. Click the viewer's **title bar** (not the canvas) for keyboard focus. Move the
   pointer into the **top** strip about **42 %** across the plot (full scale is
   0…20 ns, so you are aiming at 8.5 ns) and press **`b`**. A vertical cursor
   appears and a two-line readout bar appears along the bottom of the window.
   Confirm the cursor line is drawn on **both** strips at the same x, one
   unbroken vertical.
3. Read the bar's `B:` line. To reposition, move the pointer and press `b` twice
   (off, then back on at the pointer). Get x between 8n and 9n. PASS:
   `B: x=8.5n   v(anlg)=455m   TOP.m.siga=1   TOP.m.sigb=0` — v(anlg) tracks your
   exact x, the two digital values are exactly 1 and 0, and **all three names are
   on the line**.
4. Move to ~90 % across (18 ns), press `b` twice. PASS:
   `B: x=18n   v(anlg)=740m   TOP.m.siga=1   TOP.m.sigb=1` — both VCDs answer
   past their last sample (14 ns and 12 ns) by holding their last state.
5. Move to ~10 % across (2 ns), press `b` twice. PASS:
   `B: x=2n   v(anlg)=260m   TOP.m.siga=0   TOP.m.sigb=1`. siga ≠ sigb at one
   instant is the proof that two different databases each answered.
6. Drag it: pointer within ~10 px of the cursor line, press and hold LMB, sweep
   slowly left and right across the full width of the top strip, release. The
   line must track with no perceptible lag or stutter. The bar refreshes on
   **release**, not during the drag — deliberate, not the bug.
7. Pointer over the top strip, press **F9**. A modal "D4 engine probe" lists the
   three registry slots. PASS: all three report the **same** `annot_x` (the
   cursor's t), every `annot_p` ≥ 0, and each line carries its own database's
   value — e.g. `slot 0 anlg.raw annot_p=16 annot_x=8.5n v(anlg)=455m` /
   `slot 1 d1.vcd … TOP.m.siga=1` / `slot 2 d2.vcd … TOP.m.sigb=0`. Click OK.
8. Marker check: pointer on the digital square wave in the **top** strip where it
   is HIGH (5–9 ns, i.e. 25–45 % across, near the top of the plot box), press
   **`m`**. PASS: a callout naming `TOP.m.siga` with value `1`. It must not name
   `v(anlg)` and must not read 0.

**PASS** — the bar names **every** plotted trace at every cursor position,
including the two living in VCDs that are not current; `v(anlg)` moves
continuously while the digital values are only ever exactly 0 or 1 and change in
jumps; past a VCD's end they hold; siga and sigb disagree at 2 ns and 8.5 ns; the
cursor is one unbroken vertical across both strips; F9 shows all three slots with
the same `annot_x` and `annot_p` ≥ 0.

**FAIL** — the shipped defect: the digital trace is drawn and legended and then
**silently absent from the cursor line** —

```
B: x=8.5n   v(anlg)=455m
```

with `TOP.m.siga` / `TOP.m.sigb` missing at every position and no error anywhere.
Other, distinguishable regressions: `TOP.m.siga=500m` between 8n and 9n (HOLD
lost — that midpoint is the VCD encoding of X); at 18n the digital values read 0
or an implausible analog-looking number like `375.00001m` (a read one past the
end of the buffer, i.e. a heap word); F9 showing slot 0 live while slot 1 or 2
read `annot_p=-1` and value 0 ("that signal is 0" rather than "nothing asked") —
slot 2 alone stale means the sibling-strip loop is gone; a cursor on only one
strip, or at two different x; a marker callout naming `v(anlg)` or reading 0. No
readout bar at all after `b` usually means the pointer was not over a strip —
re-aim before calling it a regression.

**Record —** date 2026-08-11  verdict ☒ PASS ☐ FAIL ☐ BLOCKED

> what I saw: all 8 steps as written. Cursor B drew as one unbroken vertical
> across both strips; the bar named all three traces at every position —
> `x=8.5n v(anlg)=455m siga=1 sigb=0`, `x=18n … 1/1` (both VCDs held past their
> last sample), `x=2n … 0/1` (the two VCDs disagreeing at one instant). The drag
> tracked without stutter. F9 showed all three slots at the same `annot_x` with
> `annot_p` ≥ 0 and each database's own value. `m` on the HIGH digital run named
> `TOP.m.siga` = 1.
>
> Two fixture/queue mismatches, neither a defect: the window title reads
> `Waveforms eyeball (state1)`, because `wviewer::regenerate`
> (`s2_cursor.tcl:31`) retitles from the session key after line 16 sets the
> descriptive one; and the `SESSION 2 ready` registry dump goes to the CIW log,
> not the launching terminal.

---
---

# SESSION 3 — items 6 then 7 (the Signal Browser sidebar)

```sh
cd /home/qflow/dev/xschem/claude_1/xschem
DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s3_browser.tcl
```

The CIW log must show `EYE: browser kind = vcd  (must be: vcd)`. If it printed
`EYE: no viewer window (headless?)`, quit and re-run (the WSLg context-follow
wobble). One waveform-viewer window comes up with the Signal Browser docked down
its **left** edge. Sidebar top to bottom: a `Browse...` row; the **search bar**
(`All` combobox, pattern entry, `Shell`, `Match case`, **`All DBs`**, `Search`);
a `Plot` button; `Show device internals` / `Show source currents`; the **tree**;
the **lower pane** (a flow list) with its own caption line; the Filter bar; a
two-line status label at the bottom.

Item 6 runs first. When it is done you type **`eye7`** in the CIW to re-point
this same viewer at item 7's databases.

---

## - [x] Item 6 — a VCD's names get the `digital` class

`2208d16d` · session 3 · ~12 min
*Not headless because:* the verdict is which rows exist in a tree at the shipped
default checkbox state, and whether a subtree **moves** when a checkbox does.

**Steps**

1. In the sidebar, immediately under the `Plot` button, confirm the two class
   checkboxes are at their **shipped defaults**: `Show device internals`
   **unticked**, `Show source currents` **ticked**. Change neither yet — the
   point of steps 2 and 3 is that they happen at the default state.
2. Read the tree. Its root row `eye_dig_m` is born open. Click the expander
   triangle on the row `m`. EXPECT `eye_dig_m` → `m` → `sub`, three rows.
   *Regression:* `eye_dig_m` alone, a single row with **no expander at all**.
3. Click the row `sub`. The lower pane must draw exactly **six** cells: `sig`,
   `count`, `count[0]`, `count[1]`, `count[2]`, `count[3]`, and the caption at
   the foot of the pane must read `6 of 6 signals`. *Regression:* cells reading
   `sig:i`, `count:i`, `count:0` … `count:3`, or an empty pane captioned
   `m.sub has no signals of its own`.
4. Click the search bar's pattern entry, type `count[0]` exactly, press Return.
   EXPECT: the tree unchanged, the pane drawing exactly one cell `count[0]`, and
   the status line at the very bottom reading `Signal Browser` / `1 of 7
   signals`. *Regression:* `0 of 7 signals` and an empty pane — typing the exact
   label the pane draws finds nothing. Clear the entry and press Return again.
5. Tick **`All DBs`**. The tree's top level must become three database headers,
   current first: `eye_dig_m.vcd (vcd)`, `eye_anlg.raw (tran)`,
   `counter.vcd (vcd)` — each the file tail plus the engine's own analysis
   string, and **both** VCDs saying `(vcd)`.
6. Expand `counter.vcd (vcd)` all the way: `counter.vcd (vcd)` → `counter` →
   `TOP` → `counter`. **Judgement, not a test** — that VCD classifies identically
   before and after this commit. Does the file name echoed as the design root and
   again two rows later as the instance scope read as sensible, or as a stutter?
   If it reads badly, record it as a new item, not a defect in `2208d16d`.
7. Expand `eye_anlg.raw (tran)`: at the default box state it shows only its
   design root `eye_anlg`, no child groups. Now tick **`Show device internals`**.
   EXPECT the **analog** subtree alone to grow one group `x1`, while **both VCD
   subtrees stay exactly as they were** (`eye_dig_m` → `m` → `sub`, and
   `counter` → `TOP` → `counter`). *Regression:* the VCD subtree moving when the
   box moves — `m` vanishing and a bare `sub` hanging off `eye_dig_m`, rows
   appearing or digital rows disappearing.
8. Untick `Show device internals` and `All DBs`. **Keep this window** — type
   `eye7` in the CIW for item 7.

**PASS** — at the default box state the current VCD's tree reads `eye_dig_m` →
`m` → `sub`; `sub` draws six **bare** cells over `6 of 6 signals`; the exact
label `count[0]` leaves `1 of 7 signals`; `All DBs` gives three
`<file> (<type>)` headers; `Show device internals` grows **only** the analog
subtree.

**FAIL** — pre-`2208d16d`, loudest first: (1) at the default state the current
VCD's tree is one row `eye_dig_m` with no expander, and clicking it lists `time`
and nothing else — every `m.sub.*` name was classed `devnode` (SPICE reads a
one-letter leading segment as a MOSFET tag) and hidden by default; (2) ticking
`Show device internals` makes them reappear under a group `sub` hanging directly
off the root, **the `m` level deleted**; (3) the pane draws `sig:i`, `count:i`,
`count:0` … `count:3` — a wire drawn as a current, the bus index eaten out of its
brackets; (4) `count[0]` matches nothing (`0 of 7 signals`). A **different**
failure, pointing the other way: a VCD subtree that changes when either class
checkbox moves means `digital` was folded into the device classes. And an `x1`
group present in the analog tree with `Show device internals` **unticked** means
declassing was switched off wholesale (issue 0217 undone).

**Record —** date 2026-08-11  verdict ☒ PASS ☐ FAIL ☐ BLOCKED

> what I saw: all 8 steps as written. Default box state gave `eye_dig_m` → `m` →
> `sub`; `sub` drew six bare cells over `6 of 6 signals`; the exact label
> `count[0]` left `1 of 7 signals`; `All DBs` gave the three `<file> (<type>)`
> headers with both VCDs typed `(vcd)`; `Show device internals` grew only the
> analog subtree's `x1` and neither VCD subtree moved.
>
> Step 6's judgement (the `counter.vcd` name echoed as design root and again as
> instance scope) was not objected to — it reads as acceptable, no new item.
>
> **Blocked mid-step and filed as issue 0312:** the `All DBs` checkbox is
> invisible at the shipped window size. `browser_width`
> (`src/wave_viewer.tcl:11500`) caps the sidebar at 45 % of the toplevel under
> `pack propagate 0`, so the search bar is pinned narrower than it needs and the
> packer silently drops `All DBs` and `Search` off its right edge; there is no
> horizontal sash (the only panedwindow is `-orient vertical`, `:7923`), so
> widening by drag does not help and **maximising the window is the only way to
> reach the box**. Item 6 itself is unaffected — every control behaved once
> visible.

---

## - [x] Item 7 — a foreign node lists ITS OWN names, not the current database's namesakes

`f51a19d1` · session 3, after typing `eye7` · ~15 min
*Not headless because:* the regression is neither an error nor an empty pane —
it is a pane with the right count, the right caption and the wrong words in it.

Type **`eye7`** in the CIW. It must print
`F6 attach: n 3 current 0 vcds {…coll_digital.vcd …anc_top.vcd} skipped {}`
and `ITEM 7 READY`. If the sidebar does not repopulate, quit and relaunch with
`DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s3b_collide.tcl`.

**Steps**

1. Start state: the tree holds ONE root `coll_analog` (`time`, `v(rootraw)`, and
   a group `x1`) and the status label's second line reads `4 of 4 signals`. Now
   click **`All DBs`**. The tree's top level must become exactly three headers —
   `coll_analog.raw (tran)`, `coll_digital.vcd (vcd)`, `anc_top.vcd (vcd)` — and
   the status line `4 of 4 signals, +5 from 2 other DBs`. (The per-database sea
   map is populated only under All DBs; with the box off the rest proves
   nothing.)
2. **Control.** Expand `coll_analog.raw (tran)` → `coll_analog`, single-click the
   group row `x1`. The lower pane must list exactly `same` and `onlyraw`, caption
   `2 of 2 signals`.
3. **THE ITEM.** Expand `coll_digital.vcd (vcd)` → `coll_digital`, single-click
   **its** `x1` — same path, one database over. The pane must list `same` and
   `onlyvcd` under a caption word-for-word identical, `2 of 2 signals`. Click
   back and forth between the two `x1` rows three or four times watching only the
   second cell: it must alternate `onlyraw` ↔ `onlyvcd` every time. `onlyraw`
   exists in no other database in this process and `onlyvcd` in none — that one
   word is the whole evidence.
4. **The two design roots.** Click the root row `coll_digital` under the VCD
   header: the pane must list `time` **alone**, caption `1 of 1 signals`. Then
   the root row `coll_analog`: `time` and `rootraw`, `2 of 2 signals`.
5. **A pure ancestor, third database.** Expand `anc_top.vcd (vcd)` → `anc_top`,
   click the group row `TOP`. The pane must be **empty**, caption exactly
   `TOP has no signals of its own`, nothing drawn inside the pane. Click `m`
   beneath it: pane lists `anconly`, caption `1 of 1 signals`, and **no other
   sentence anywhere**. That silence on the success path is the one open question
   only your eye can settle — if a success needs a sentence too, say so now.
6. **`Send to Add Trace...` out of a FOREIGN pane.** Re-select
   `coll_digital.vcd (vcd)` → `coll_digital` → `x1`, then **right-click** on the
   word `same` in the lower pane. The menu's greyed title line must read
   `x1.same`. Choose `Send to Add Trace...`; the `Expression:` field must
   prefill `x1.same`. Set `Destination:` to **New Strip**, type nothing into
   Expression, press OK.
7. **The same gesture from the CURRENT pane.** Select `coll_analog.raw (tran)` →
   `coll_analog` → `x1`, right-click `same`: the title line must read
   `v(x1.same)`, Add Trace prefills `v(x1.same)`. Destination **New Strip**, OK.
   Compare the two new strips: the VCD one is a square level (HIGH 0→1 ns, LOW
   1→2 ns), the raw one ramps 0 → 1.0 at 1 ns → 0.5 at 2 ns. They must not look
   alike.

**PASS** — every list is the list of the database the **row** belongs to, and the
two are told apart by content, never by a count or a caption: foreign `x1` =
`same` `onlyvcd`; current `x1` = `same` `onlyraw`; foreign root = `time` alone;
current root = `time` `rootraw`; `TOP` = empty pane captioned
`TOP has no signals of its own`, `m` = `anconly`; the foreign RMB menu titles
`x1.same` and prefills `x1.same`, the current one `v(x1.same)`; the two New Strip
traces look plainly different; the status line reads
`4 of 4 signals, +5 from 2 other DBs` throughout.

**FAIL** — not an error and not an empty pane. Before `f51a19d1` the `d:N|`
prefix was stripped and the surviving path looked up in whichever database was
current, so a foreign node filled with the **current** run's namesakes — same
count, same caption, nothing on screen to say so: foreign `x1` lists `same` and
**`onlyraw`**; foreign root lists `time` **and `rootraw`** at `2 of 2 signals`;
the foreign RMB menu titles **`v(x1.same)`**; both New Strip traces draw the same
analog ramp. A **different** failure meaning the feature never ran: every foreign
row gives an empty pane captioned `<something> has no signals of its own` — check
`All DBs` is really ticked and that `eye7` really printed `n 3`. Also a fail: a
caption naming the current design over a foreign node, or foreign cells carrying
the analog `v(...)` spelling.

**Record —** date 2026-08-11  verdict ☒ PASS ☐ FAIL ☐ BLOCKED

> what I saw: all 7 steps as written, `eye7` re-attached first time (`n 3`, no
> fallback needed). `All DBs` gave the three headers and
> `4 of 4 signals, +5 from 2 other DBs`. The two `x1` rows were told apart by
> content on every one of four alternations — current `same`/`onlyraw`, foreign
> `same`/`onlyvcd`, captions word-for-word identical. Foreign root listed `time`
> alone (`1 of 1`), current root `time`/`rootraw` (`2 of 2`). `TOP` gave an empty
> pane captioned `TOP has no signals of its own`; `m` gave `anconly` with no
> extra sentence. The foreign RMB titled and prefilled `x1.same`, the current one
> `v(x1.same)`, and the two New Strip traces drew plainly differently — square
> level vs ramp.
>
> Step 5's open question (a success path that says nothing) was not objected to:
> silence on success stands.

---
---

# SESSION 4 — item 5 (the notice that must survive its own gesture)

```sh
cd /home/qflow/dev/xschem/claude_1/xschem
DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s4_item5.tcl
```

## - [x] Item 5 — a verilog-only cell routes to its VCD scope, and the notice is still on screen a second later
<!-- [x] on the RE-RUN (2026-08-11, after 254dc117): steps 6 and 9 PASS by eye,
     step 8 answered (no interruption; spawned issue 0315), step 7 BLOCKED by
     issue 0312 — the divider is not draggable, so the ~250 px judgement cannot
     be taken yet. See the second Record block below. -->


`fda9d5a8` + `7ff1be9d` · session 4 · ~15 min
*Not headless because:* every automated check read the sidebar in the same
event-loop turn that wrote it, which is exactly the turn in which the shipped bug
was invisible.

> **⚠ At this item, "I saw nothing" is a FAIL, not an inconclusive result.**
> Take your hands off the keyboard after each gesture and count to three before
> reading anything.

**Steps**

1. **Pre-state, load-bearing.** Three toplevels: the `xschem CIW`; the design
   window `tb1.sch` showing three boxes labelled **a1 / a2 / a9**; a
   waveform-viewer window with the Signal Browser sidebar open. In the sidebar:
   the tree's design-root row is selected, the lower pane **lists** `time` and
   `v(anlg)`, the caption under the pane reads `2 of 2 signals`, and `All DBs` is
   **unticked**. If any of that is missing, stop.
2. In the **design** window click once on the **middle** box, **a2**, so it goes
   selection-coloured. Click nothing else. (Its cell has a verilog view but no
   entry in the co-simulation map: the refusal path.)
3. Press **Ctrl-Alt-V** (identical: Tools > `Show in Signal Browser`). Then take
   your hands off and **count to three**.
4. Read the caption strip under the lower pane, and the **second line** of the
   `Signal Browser` header at the top of the sidebar. PASS: both read
   `no digital signals to show: no entry of the co-simulation map matches cell
   'dlib/dcell2' (module 'dcell2', model 'dcell2'): this cell was not part of the
   last run's netlist, or the run predates it (f2)` while the pane below still
   lists `time` and `v(anlg)`. FAIL: the caption reads `2 of 2 signals` and the
   header `showing the simulation top level` — the sidebar looks exactly as in
   step 1 and nothing says why no digital pane appeared. **Also FAIL** if you saw
   the sentence and then watched it vanish. (To read the surfaces as text: click
   the CIW entry, type `e5cap`, Return.)
5. Click the design window's title bar or canvas first (the gesture moved focus),
   then click the **left** box, **a1**. Its cell IS in the map and the recorded
   scope is `TOP`, whose sub-scope `m` owns the two wires — so the show
   **succeeds** and the pane is legitimately empty.
6. Press **Ctrl-Alt-V**, hands off, count to three. PASS, all four: (a) the tree
   grew a **second database group** (the VCD) and the row `TOP` inside it is
   selected; (b) `All DBs` has ticked **itself**; (c) the lower pane is empty;
   (d) the sentence `showing the digital scope 'TOP' of 'dig.vcd' in the tree,
   but that scope has no signals of its own - open one of its sub-scopes to see
   any` is in **three places at once** — the pane caption, the sidebar header's
   second line, and drawn and wrapped **inside** the empty pane.
7. **Legibility — no pass/fail, a verdict you record.** With that sentence still
   up, read it on the caption and on the header at the current width. Then drag
   the divider between sidebar and waveform canvas **right** until the sidebar is
   roughly 250 px wide and read both again. Does either single-line surface
   **clip** the sentence? Does the copy drawn in the pane stay sanely wrapped?
   Therefore: does F5 need a short form for the caption and status line?
8. **Read the CIW log.** For the a1 gesture there must be a **pair**:
   `ase: signal browser: showing every results database to reach TOP` in the
   ordinary colour, then `ase: signal browser: showing the digital scope 'TOP' …
   see any` in **dark orange** (a caveat, not a failure). For a2 the last line
   must be the refusal sentence in **red**. Judge whether each pair reads as one
   account of one gesture — in particular a `window 4 activated: untitled.sch`
   line lands **between** the two lines of the a1 pair; say whether that breaks
   it.
9. **Control.** Click the design window, click the **right** box **a9** (no
   verilog view), Ctrl-Alt-V, count to three. PASS: the browser returns to the
   analog root — pane lists `time` and `v(anlg)`, caption `2 of 2 signals`,
   header `showing the simulation top level` — and **nothing** on any surface or
   in the CIW mentions co-simulation, digital signals or a missing VCD. FAIL: any
   `no digital signals to show` / `has no digital signals of its own` for a9.

**PASS** — both notices are still on screen three seconds after the binding
returned, on every surface that carries them: on a2 the refusal on caption AND
header second line with the pane still listing the analog signals and a **red**
CIW line; on a1 the VCD's own tree group with `TOP` selected, `All DBs`
self-ticked, empty pane, and the `showing the digital scope 'TOP' of 'dig.vcd'…`
sentence on caption, header and inside the pane, with a dark-orange CIW line
under the plain one; on a9 nothing digital is ever mentioned.

**FAIL** — a sidebar that looks untouched a second after the gesture. On a2 the
caption falls back to `2 of 2 signals` and the header to `showing the simulation
top level` — the notice was written and erased inside the same event-loop turn.
On a1 the caption falls back to `TOP has no signals of its own` (a sentence that
never says the show succeeded and never names the database), the empty pane draws
nothing, and **no dark-orange CIW line appears at all**. **A blink-and-gone
sentence counts as FAIL, not PASS.** Two milder failures: the branch never firing
(on a1 the tree stays on the analog root, no second database group, `All DBs`
stays unticked) and the gate leaking (any co-simulation sentence for a9).

**Record —** date 2026-08-11  verdict ☐ PASS ☒ FAIL ☐ BLOCKED

> **The notice machinery PASSES; the gesture it rides FAILS.** Split verdict,
> and the failure is not the one this item was minted to catch.
>
> **What passed.** On a2 the refusal reached all three surfaces and was still
> there when `e5cap` read it seconds later — pane caption, sidebar header second
> line, and drawn inside the pane — with the CIW line in red. On a1, driven from
> the CIW, all four conditions of step 6 held at once: the tree grew the VCD
> group with `TREE SEL = d:1|g:TOP`, `ALL-DBS BOX` ticked **itself** to 1, the
> pane was empty, and `showing the digital scope 'TOP' of 'dig.vcd' in the tree,
> but that scope has no signals of its own …` was on the caption, the header and
> the canvas, under the plain/dark-orange CIW pair. The
> written-and-erased-in-one-turn defect `7ff1be9d` fixed has NOT returned.
>
> **What failed.** The a1 gesture never reaches that success by mouse. Three
> Ctrl-Alt-V presses gave `'dig.vcd' is not among the loaded results databases:
> run the simulation, or re-attach its results (f3)` for a VCD sitting in the
> viewer's registry as slot 1. Instrumented at the failing gesture:
> `tok='dlib/tb1/schematic'`, `ctx=.drw`, `ic=1`, and
> `wviewer::signal_list_all` returning **0** — the same call answers 2 from the
> CIW in the same context. `cosim_db_inventory` then falls back to the design
> context, which has no databases, and mints `notloaded`. Filed as **issue
> 0314**; `ase.tcl:1763` names this exact degradation.
>
> **Also filed: issue 0313.** The a2 refusal empties the sidebar — pane rows 2 →
> 0, tree down to its root — and since the root is already selected, clicking it
> fires no `<<TreeviewSelect>>`. Only an unrelated control (`Show device
> internals`, ticked and unticked) brings it back.
>
> Steps 7 (legibility at ~250 px), 8's CIW-pair judgement and 9 (the a9 control)
> were NOT reached — the session was instrumented into an unusable state while
> narrowing 0314. Owed on a re-run once 0314 is fixed.

**Record (RE-RUN) —** date 2026-08-11, after `254dc117` fixed 0314 + 0313
verdict ☒ PASS ☐ FAIL ☒ PARTLY BLOCKED (step 7)

> **Step 6 — PASS, by eye, on the gesture that was blocked.** "Behavior is as
> expected": the tree grows the VCD group with `TOP` selected, `All DBs` ticks
> itself, the pane is empty, and the `showing the digital scope 'TOP' of
> 'dig.vcd' …` sentence is on the caption, the header and inside the pane. The
> refusal that made this item FAIL — `'dig.vcd' is not among the loaded results
> databases: run the simulation` — is gone. Issue 0314 CLOSED; issue 0313 CLOSED
> with it (the a2 refusal no longer empties the sidebar).
>
> **Step 7 — BLOCKED, by issue 0312, and the blocker is now measured from the
> user's side: the divider is NOT DRAGGABLE at all.** The step asks for a
> judgement at ~250 px and there is no way to get there. What it took just to
> see the `All DBs` checkbox: **Ctrl-B to hide the Signal Browser, maximize the
> window, Ctrl-B to show it again, then restore the window to its old size.**
> That trick is the workaround of record until 0312 is ruled — and it is also
> the answer to 0312's own open question about how bad the clipping is: bad
> enough that a shipped control is unreachable without it. The legibility
> verdict F5's short form depends on is owed AFTER 0312.
>
> **Step 8 — the anticipated interruption does NOT happen: there is no
> `window 4 activated: untitled.sch` line between the two lines of the a1 pair.**
> Confirmed in `/tmp/Xschem.log.4`: the lines are contiguous. That half of the
> question is dead. What the log shows instead is **issue 0315** (filed): the
> landing sentence is written to the CIW TWICE — once unprefixed by
> `wviewer::browser_say`, once `ase: `-prefixed by step 6 — and on the a9
> control one of the two is tagged as an ERROR (`#! signal browser: no signals
> under 'a9'`) for a gesture whose verdict is PASS. Which of the two lines
> should survive is a ruling, not a fix, so 0315 is filed and not touched.
>
> ⚠ One expectation in step 8's text needs restating for future runs: the first
> line of the pair reads `showing every results database to reach TOP` only on
> the FIRST a1 gesture of a session, when `browser_show_db_scope` has to tick
> `All DBs` on the user's behalf. On any later a1 gesture the box is already
> ticked, the `alldbs` kind never fires, and the line is the plain
> `showing TOP`. Both are correct.
>
> **Step 7 — ANSWERED 2026-08-12, after issue 0312 shipped the divider, and the
> answer is a DEFECT rather than a legibility verdict.** The grip made the ~250 px
> width reachable, and at that width **the sentence does not clip — it VANISHES
> from the pane entirely**, leaving the unexplained empty box that §F item F5
> exists to abolish. Selecting `a1` and pressing Ctrl-Alt-V again brings it back,
> because that mints a fresh notice. Mechanism located and filed as **issue
> 0318**: the sea canvas's `<Configure>` is wired to `browser_sea_refresh`, whose
> first act is `set browserseanote($token) {}` — so a RESIZE is treated as "the
> user moved" when the user moved nothing. `browser_sea_draw`'s narrow-pane
> `-width` floor works fine; the text never reaches it.
>
> **So the question step 7 was minted to answer is still owed** — "does F5 need a
> short form for the caption and status line?" cannot be judged until the pane
> keeps its sentence at that width. Re-ask it after 0318.
>
> ⚠ 0312's own pixels were eyeballed in the same session and PASS: the divider
> reads as a divider at `#b8b8b8`, and the two-row search bar reads as
> deliberate.
>
> **Step 9 — PASS.** The a9 control mentions nothing about co-simulation,
> digital signals or a missing VCD on any surface or in the CIW, and the sidebar
> returns to the analog root: `PANE ROWS 2`, caption `2 of 2 signals`, header
> `showing the simulation top level`. (`All DBs` stays ticked from step 6, which
> is state carried by design, not a defect.) The two extra CIW lines it prints
> are 0315's, not this item's.

---
---

# SESSION 5 — item 4 (stale scope hint, and the colour of the notice)

```sh
cd /home/qflow/dev/xschem/claude_1/xschem
DISPLAY=:0 ./src/xschem --rcfile /tmp/xschem_eyeball_F/lib4/f2rc \
  /tmp/xschem_eyeball_F/lib4/dlib/tb4/schematic/tb4.sch
```

Two windows: the `tb4` schematic and the CIW. **Every step is typed into the
CIW's lower one-line box and executed with Return**; results appear in the upper
pane. The fixture stages the shape real inlining produces: the `.v` declares
`module realmod`, the recorded map says `scope TOP.realmod`, and only the loaded
VCD knows the digital compile pushed it a level down into a wrapper.

## - [x] Item 4 — a stale `TOP.<module>` hint is overruled by the VCD actually loaded

`11835169` · session 5 · ~12 min
*Not headless because:* the answer must come through **another window's**
database registry, and the notice's colour is a pixel.

**Steps**

1. Type: `list [xschem get schname] [xschem get current_win_path] "raw=[xschem raw info]"`
   → must print `/tmp/xschem_eyeball_F/lib4/dlib/tb4/schematic/tb4.sch .drw raw=`.
   The empty `raw=` is load-bearing: this window holds **no** results database.
2. Build the ASE state:
   `set S [ase::state_default]; dict set S design [dict create lib dlib cell tb4 view schematic]; dict set S rundir /tmp/xschem_eyeball_F/lib4/run; ase::cosim_file $S`
   → must print `/tmp/xschem_eyeball_F/lib4/run/tb4_ase.cosim`.
3. Open the viewer window that owns the token:
   `set K [ase::session_key dlib tb4 st1]; ase::state_save /tmp/xschem_eyeball_F/lib4/run/st1.state $S; ase::session_open $K /tmp/xschem_eyeball_F/lib4/run/st1.state; wviewer::open $K`
   → a waveform-viewer toplevel appears and the result line is `1`. (If it prints
   `0` or errors: skip to step 5, click back on tb4, run step 4's command there,
   and do steps 6–9 with the `$K` argument omitted — you still get the whole
   hint-vs-DB behaviour and the CIW colour.)
4. The viewer is now the current context, so attach the databases **into it**:
   `list [xschem get current_win_path] [ase::attach_dbs /tmp/xschem_eyeball_F/lib4/run/anlg.raw tran [list /tmp/xschem_eyeball_F/lib4/run/dcell2.vcd]]`
   → the first element must **not** be `.drw` (it is the viewer's, e.g. `.x1.drw`)
   and the rest must read
   `n 2 current 0 vcds /tmp/xschem_eyeball_F/lib4/run/dcell2.vcd skipped {}`.
5. Click once on empty canvas in the **tb4** window, then back into the CIW entry:
   `list [xschem get current_win_path] "raw=[xschem raw info]"` → must print
   `.drw raw=`. (If not `.drw`, type `xschem new_schematic switch .drw` and
   repeat.)
6. **Negative control** — this window's own registry is empty:
   `ase::cosim_scope_for_state $S x1.a1` → must print
   `none notloaded {'dcell2.vcd' is not among the loaded results databases: run the simulation, or re-attach its results (f3)}`.
7. **THE ITEM** — same call plus the viewer token:
   `ase::cosim_scope_for_state $S x1.a1 $K`. Watch the upper pane: a notice line
   appears first, then the result line.
8. Prove the notice carries the tag and eyeball its colour: `.ciw.l.t tag ranges note`
   → a non-empty pair of indices (e.g. `14.0 15.0`). Now look at step 7's notice
   against its neighbours: it must be **dark orange** — warmer than the gray30
   result lines, clearly not the blue of echoed input and not the red of errors.
   It should read as "something was off and I recovered".
9. **Quiet control** — rewrite the map so the hint agrees with the database:
   `ase::cosim_save_map $S [list [dict create model dcell2 lib dlib cell dcell2 vfile /tmp/xschem_eyeball_F/lib4/dlib/dcell2/verilog/dcell2.v module realmod scope TOP.wrapper.realmod vcd /tmp/xschem_eyeball_F/lib4/run/dcell2.vcd multi 0 ninst 1]]; ase::cosim_scope_for_state $S x1.a1 $K`
   → the result must now end in `hint {}` and **no new orange line** may appear
   (re-run `.ciw.l.t tag ranges note`: still the single pair from step 8).
   *(Re-run `sh doc/claude/batch_F/eyeball_fixtures.sh` afterwards to restore the
   stale map.)*

**PASS** — step 7 prints, on one result line:

```
ok /tmp/xschem_eyeball_F/lib4/run/dcell2.vcd TOP.wrapper.realmod derived {the recorded scope hint 'TOP.realmod' is not in the loaded database -- using 'TOP.wrapper.realmod', derived from the database itself}
```

— scope `TOP.wrapper.realmod` (read out of the VCD, reachable only as a *prefix*
of `TOP.wrapper.realmod.inner`), how = `derived`, fifth slot naming the overruled
hint. Not `TOP.realmod`, and emphatically not `TOP`. Immediately above it, one
line in **dark orange**:

```
ase: the recorded scope hint 'TOP.realmod' is not in the loaded database -- using 'TOP.wrapper.realmod', derived from the database itself
```

and step 8's `tag ranges note` is non-empty, so the tag is really applied. Step 6
must have said `none notloaded …` and step 4's context must not have been `.drw`
— together those show step 7's answer came through the **viewer's** registry.
Step 9 must print `… TOP.wrapper.realmod hint {}` with no second orange line.

**FAIL** — three distinct outcomes, not the same bug: (1) **the defect this item
exists to prevent** — step 7 answers `ok … TOP.realmod hint {}`, the netlister's
string handed back verbatim, a scope the VCD does not declare, so every later
lookup returns nothing and the browser pane is empty for no stated reason;
variants `ok … TOP.realmod derived {}` (leaf-matches-module accepted without
consulting the DB) and `ok … TOP <anything>` (falling back to the shim's port
mirror — forbidden) are the same failure. (2) **the feature never ran** — a red
`invalid command name "ase::cosim_scope_for_state"` at step 7 or on
`ase::cosim_file` at step 2 means `src/ase.tcl` is not the `11835169` version
(wrong tree, or an installed xschem); fix the launch and restart. (3) **the pixel
regression** — the answer is right but the notice is gray30, indistinguishable
from the results below it, and `tag ranges note` comes back **empty**; red
instead of orange is also a fail. Two further wrong shapes at step 7:
`none noscope …` (the DB was consulted but the derive is broken) and
`none nodigital '<…>' is not an instance of the schematic currently open` (you
are on the wrong window — redo step 5). At step 9, an orange line appearing again
means the notice fires on every answer and the colour is noise.

**Record —** date 2026-08-11  verdict ☒ PASS ☐ FAIL ☐ BLOCKED

> what I saw: the PASS shape exactly. Step 1 gave `.drw raw=` (this window holds
> no database), step 4 `.x1.drw` with
> `n 2 current 0 vcds …/dcell2.vcd skipped {}` (they went into the VIEWER), step
> 5 back to `.drw raw=` — so step 7's answer can only have come through the
> viewer's registry. Step 7:
>
>     ase: the recorded scope hint 'TOP.realmod' is not in the loaded database --
>     using 'TOP.wrapper.realmod', derived from the database itself
>     ok …/run/dcell2.vcd TOP.wrapper.realmod derived {…same sentence…}
>
> — `TOP.wrapper.realmod`, `derived`, the overruled hint named in the fifth slot.
> Not `TOP.realmod`, not `TOP`. `.ciw.l.t tag ranges note` non-empty, and the
> notice is **dark orange** against the gray30 result lines — reads as "something
> was off and I recovered", not as an error.
>
> Step 9's quiet control passed on the second attempt: with the map rewritten to
> agree with the database the answer became `TOP.wrapper.realmod hint {}` and
> `tag ranges note` was still the single pair `46.0 47.0` — no second orange
> line. The first attempt returned `none nodigital 'a1' is not an instance of the
> schematic currently open`, which is the queue's documented wrong-window
> outcome: step 7 had moved the context off tb4. Re-running with
> `xschem new_schematic switch .drw ;` prefixed gave the expected answer. Worth
> noting as ordinary friction, not a defect: every CIW call in this session had
> to re-assert the context, because each one leaves it somewhere else.

---

## When the queue is done

```sh
rm -rf /tmp/xschem_eyeball_F
```

Anything you marked FAIL, or any judgement call you recorded in item 6 step 6,
item 7 step 5, item 8 step 6 or item 5 step 7, belongs in
`doc/claude/batch_F/LEDGER.md` and (if it is a defect) a new numbered issue under
`doc/claude/issues/`.
