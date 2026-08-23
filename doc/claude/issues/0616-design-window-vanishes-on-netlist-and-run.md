# 0616 — "Netlist and Run" makes the schematic window disappear

STATUS: **FIXED 2026-08-23 (status E — one ruling + one look owed to the user).**
Reported by the user 2026-08-22, second eyes-on session. Root-caused by
measurement; **none of the three candidates this issue originally listed was the
cause**, and two sentences of the original text are refuted below.

---

## What the user sees

> "(when I press Netlist and Run, the schematic window disappears). I have to do
> Session > Design window to get it back"

Launch: `src/xschem --script sky130A/cadence_style_rc --logdir /tmp`, open
`ngspice_state1` of `tb_bandgap` (`sky130_tests_ase`), enable only the OP
analysis, press **Netlist and Run**. The design window goes away. It is
recoverable from **Session > Design Window**, so the schematic is not closed —
something unmaps, lowers, or re-parents it.

## Why it matters more than a cosmetic annoyance

The whole OP-annotation workflow is *run, then descend and press 6*. If the run
takes the schematic off screen, every user's next action is a detour through a
menu — and a user who does not know that menu item exists reasonably concludes
the run destroyed their work.

---

## ROOT CAUSE — an explicit `wm withdraw`, two files away from where the issue
## told the crew to stop looking

**Netlist and Run withdraws and re-maps the design toplevel, once per press,
whenever the current xschem context is not the design cellview.** It is a
window-management call, but the verb is an **unmap**, not a raise.

The chain, every line verified on this tree:

| file:line | what it does |
|---|---|
| `src/ase_window.tcl` `do_run` | `if {[file normalize [xschem get schname]] ne $dpath}` — tests the current **context**, not visibility |
| ↓ | `ase::ui::design_window $key` |
| `src/ase_window.tcl` `raise_design_editor` | two-loop window match (exact `current_name`, then the issue-0168 descended-stack loop) |
| `src/ase_window.tcl` `raise_window_entry` | `xschem new_schematic switch …` **then** `raise_activate_toplevel $tp` |
| `src/xschem.tcl:5676` | **`wm withdraw $top`** ← the hide |
| `src/xschem.tcl:5677` | `wm deiconify $top` ← the re-map WSLg is documented to **drop** |

`tabbed_interface` defaults to 1 (`src/xinit.c:2621`), so the "design window" is
a **tab of toplevel `.`** and `$tp` resolves to `.` — the thing withdrawn is the
entire main xschem window. The ASE window, the viewer, the LibMgr and the CIW
are separate toplevels and survive, which is exactly why the user still had a
menu to recover with. And the recovery is the *same proc's other arm*
(`src/xschem.tcl:5679`): an already-withdrawn toplevel gets a plain
`wm deiconify` with no withdraw first, so Session > Design Window reliably
brings it back. Every clause of the user's report is accounted for by one proc.

### The two sentences of this issue that measurement refuted

1. > "Nothing in `src/ase.tcl` withdraws or destroys a toplevel — `grep -n
   > 'withdraw\|destroy \.\|wm iconify'` comes back empty of anything on the run
   > path, so **the cause is not an explicit hide** and the obvious suspect is
   > already eliminated."

   The grep is correct (confirmed in one line: rc=1, no output). **The inference
   is wrong** — the run path *leaves* `src/ase.tcl`. `do_run` lives in
   `ase_window.tcl` and the hide lives in `xschem.tcl`. There is an explicit
   hide on the run path.

2. > "A regression check asserts `winfo ismapped` and `wm state` across the run,
   > and fails if the window is unmapped…"

   **Measured: that check is GREEN with the defect live.** On a synchronous WM
   the `deiconify` completes inside the same `update`, so `wm state` reads
   `normal` and `winfo ismapped` reads `1` both before and after a press that
   demonstrably withdrew the toplevel. See "the assertion that works", below.

### Why the guard fires in the user's setup at all

The committed state
`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/ngspice_state1/tb_bandgap.state`
ends with `viewer {open 1 …}`, so `ase::ui::open` → `ase::ui::viewer_restore`
opens the waveform viewer at session-open time. `wviewer::open` uses
`new_schematic create_window`, i.e. a real toplevel `.x1`, and it leaves the
current context **there**. The design window is fully visible and front, and the
guard fires anyway and re-maps a window that needed nothing. The same condition
holds after any descend, after clicking in the viewer, and after opening any
other cell.

---

## THE MEASUREMENT (before)

Environment: private Xvfb 1920x1080x24 with **`xfwm4 --compositor=off`** as the
window manager (`_NET_SUPPORTING_WM_CHECK(WINDOW): window id # 0x200032`).
`openbox` is **not installed on this box**, so the arm's documented `AUDIT_WM`
default silently degrades to WM-less — issue **0645**. Design =
`tb_bandgap/ngspice_state1`, OP only, real ngspice, real
`$top.mb.sim invoke {Netlist and Run}`. `tabbed_interface=1`.

```
CASE B — the user's exact situation (state carries `viewer {open 1 ...}`)
  guard = 1   schname=.../untitled.sch   current_win_path=.x1.drw
  BEFORE  exists=1  wm state=normal  ismapped=1  geometry=1000x800+8+31  rootx,rooty=13,90
          stackorder = .ciw . .libmgr .ase4 .x1                Unmap/Map = 0/0
  >>> ase::ui::design_window CALLED key=sky130_tests_ase/tb_bandgap/ngspice_state1
  >>> raise_activate_toplevel CALLED top=. ismapped=1
  <<< UNMAP toplevel . >>>
  <<< MAP   toplevel . >>>
  AFTER   exists=1  wm state=normal  ismapped=1  geometry=1000x800+8+31  rootx,rooty=13,90
          stackorder = .ciw .libmgr .ase4 .x1 . .ase4.logwin   Unmap/Map = 1/1
  >>> RESULT: toplevel . UNMAPPED 1 time(s), re-MAPPED 1 time(s)

CASE A — control, the design IS the current schematic
  guard = 0   schname=.../tb_bandgap/schematic/tb_bandgap.sch  current_win_path=.drw
  BEFORE / AFTER identical, byte for byte.                     Unmap/Map = 0/0
  status after wait = 'Status: Ready'  background=Green

CASE C — descended into x1 (exactly where the OP-annotation "press 6" happens)
  guard = 1   schname=.../sky130_tests_ase/bandgap/schematic/bandgap.sch  currsch=1
  <<< UNMAP toplevel . >>> / <<< MAP toplevel . >>>
  status = 'Status: Error'  background=red   run_id = ''      Unmap/Map = 1/1
```

**Case A is the elimination of candidates 1 and 2, and it is stronger than a
separate probe**: the *same* `ase::netlist` (`xschem netlist -noalert`) and the
*same* `ase::run_deck` (`cd $rd` … `eval execute 0 $cmd` … `cd $save`) executed a
complete successful OP run with **zero** unmaps, identical geometry and identical
stackorder. Neither the netlist walk nor the `cd` moves the window. The only
difference between A and B is the value of `do_run`'s guard. Independently:
`xschem netlist` calls no `get_save_xctx`/`get_old_xctx`/`new_schematic`, and
`grep XUnmapWindow|Tk_UnmapWindow|XIconifyWindow|XWithdrawWindow|XLowerWindow
src/*.c` is empty.

**Candidate 3 is not it either, in the OP-only case**: `ase::ui::auto_plot`
returns early for `sim_type op` ("op results have no sweep"), so the run never
opens or raises the viewer. The only toplevel the run creates is
`.aseN.logwin`, which maps on top and unmaps nothing. **The issue's title is
right: this is disappearance, not stacking.**

### Why the user sees a vanish and the crew saw a flash

Not a contradiction, and not the user being mistaken. `src/xschem.tcl:5652-5663`
and issue **0054** record that `raise_activate_toplevel` exists *because*
WSLg/Weston applies stacking only at map time, and
`tests/headless/test_ase_window.tcl` records in the shipped suite's own comments
that WSLg "occasionally DROPS a re-map outright (1/5 pristine runs stalled here
forever)". **A dropped re-map is precisely a design window that vanished.**
`src/xschem.tcl:5658-5663` also documents a ~32px NW **creep** per re-map on that
WM, so repeated presses walk the window off screen — a second disappearance
mechanism, and an argument against "just re-map harder".

---

## THE FIX

Pure Tcl, one source file. **Split the two jobs `do_run`'s guard conflates.**

`raise_window_entry` does job 1 (the **context** switch,
`xschem new_schematic switch`, which is what makes `ase::netlist`'s own "the
design must BE the current schematic" guard pass) and job 2 (bringing the owning
**toplevel** forward). Job 2 is not free: on WSLg the only thing that raises a
mapped window is a withdraw+deiconify re-map, that re-map is sometimes dropped,
and each one costs ~32px of creep.

An optional trailing `raise_mode` parameter is threaded through the existing
three-proc chain `design_window` → `raise_design_editor` → `raise_window_entry`:

* **`always`** (the default, and what every other caller passes by passing
  nothing) — today's shipped behaviour, byte for byte.
* **`ifhidden`** (what `do_run` now passes) — job 1 always; the expensive
  **withdraw+deiconify re-map** only when the toplevel is *not* currently
  mapped; and on an already-mapped toplevel the **cheap half of the raise**
  (`raise $tp` + `xschem activate_window`) still runs.

Anything that is not literally `ifhidden` means `always`, so a typo or a future
third mode degrades to raising rather than silently disabling every raise in the
program. `vis` defaults to `0` before `catch {set vis [winfo ismapped $tp]}`, so
the headless path (no `winfo`) takes the `always` arm and
`raise_activate_toplevel`'s own `has_x` guard no-ops it, exactly as today.

**`src/xschem.tcl:5670 raise_activate_toplevel` was NOT touched** — 11 call
sites, and issue 0054 records that the user ratified raise-with-creep as the
price of a working WSLg raise. Fix the caller, not the helper.

Precedent, not invention: this exact helper on this exact call was already
reported by this same user and already fixed once, elsewhere —
`doc/claude/specs/waveform_viewer.md:529-535`, the `do_raise` argument that makes
Ctrl-4 skip `design_window`'s flash. `do_run` needed the third state, "raise only
if hidden", because unlike Ctrl-4 it cannot know a priori that the design is
front.

### THE FIRST CUT OF THIS FIX WAS REFUTED, AND THE REFUTATION IS THE INTERESTING PART

The first implementation skipped `raise_activate_toplevel` **entirely** on the
`ifhidden`-and-visible arm. Tiers were green, the sabotage matrix was exact, and
the adversary pass then measured this:

```
BEFORE Netlist and Run   | state=normal ismapped=1 geo=1000x800+8+31 root=13,90 | Unmap/Map=0/0
                         | stackorder = . .ase4 .x1
                         | above: .x1 rect=13 89 1013 889     <- the waveform viewer,
                         |   pixel-coincident with the design (13,90-1013,890)
AFTER  run finished      | stackorder = .ase4 .x1 . .ase4.logwin   (with the SHIPPED pre-fix body)
AFTER  run finished      | stackorder = . .ase4 .x1 ...            (with the first-cut fix)
```

In the user's own committed state the restored viewer opens **on top of and the
same size as** the design window. The shipped withdraw+deiconify was the only
thing putting the schematic back on screen. Dropping it wholesale delivered
"still mapped" but **not** "still visible": the user presses Netlist and Run,
still sees no schematic, and still reaches for Session > Design Window. That is
the reported symptom with a different mechanism — so the fix as first written
did not meet this issue's own acceptance.

**The remedy, measured:** keep `raise $tp` (and the `xschem activate_window`
tail) in the `ifhidden` arm and skip *only* the withdraw/deiconify. A bare
`raise .` restacks the design above the viewer with **Unmap/Map = 0/0**, and
issue 0054 records that a plain `raise` is an inert **no-op** on WSLg once a
window is mapped — so it cannot bring the vanish back, and it restores
visibility on every other X server, **including the user's own, which is a
Windows X server over TCP and not WSLg** (see the three-server table in
`CLAUDE.md`).

## THE MEASUREMENT (after)

Same probe, same environment, with the remedied fix:

```
context=.x1.drw  schname=untitled.sch      do_run guard = 1
BEFORE Netlist and Run   | state=normal ismapped=1 geo=1000x800+8+31 root=13,90 | Unmap/Map=0/0
                         | stackorder = . .ase4 .x1
                         | above: .ase4 rect=1023 60 1821 601   partial/none
                         | above: .x1   rect=13 89 1013 889     partial/none
AFTER  run finished      | state=normal ismapped=1 geo=1000x800+8+31 root=13,90 | Unmap/Map=0/0
                         | stackorder = .ase4 .x1 . .ase4.logwin
                         | above: .ase4.logwin rect=974 615 1915 1075  partial/none
schname after = tb_bandgap.sch ; run_id=0
VERDICT unmap/map = 0/0
```

The design ends **above** both the ASE window and the viewer — the same visible
outcome the shipped code produced — with **zero** unmaps, zero creep, and no
flash. Geometry is unchanged (`root=13,90` before and after).

Hidden-window recovery is preserved, checked by hand in both states: forcing the
design toplevel to `iconic` and pressing Netlist and Run gives
`AFTER: wm state=normal ismapped=1 run_id=0`; forcing it to `withdrawn` gives
`AFTER: wm state=normal ismapped=1 run_id=1`. Nobody is stranded.

---

## THE ASSERTION THAT WORKS (and the one that does not)

This is the most important paragraph for anyone extending the test.

* **Does not work:** `winfo ismapped` / `wm state` — this issue's own original
  acceptance wording. Measured `normal`/`1` before *and* after in all three
  cases, including the two where the toplevel was demonstrably withdrawn. It is
  kept as row **W6m4**, labelled in-file as the weak one.
* **Works:** a `<Unmap>` **counter** on `.`, asserted `== 0` across the run
  (row **W6m1**; measured `1` with the defect live). `wm withdraw` unmaps at the
  core-X level, so the count is exact **with or without** a reparenting WM —
  which matters, because `openbox` is not installed here (0645).
  The counter **must** be filtered to `%W eq "."`: a toplevel is a bindtag of
  every descendant, so an unfiltered counter reads **56**, not 1. It rides its
  own private bindtag rather than `bind . <Unmap> {+…}`, because the product's
  own `bind $topwin <Unmap> "wm withdraw .infotext; …"` shares that event and,
  appended to, aborts the concatenated script before the counter runs when
  `.infotext` does not exist.
* **Also needed, and it is half the acceptance:** "still mapped" is worthless if
  the schematic is still not on screen. Row **W6m5** deliberately `lower .`s the
  design under the ASE window before the press — reproducing the user's buried
  shape — and requires it to end up above. That row is what caught the refuted
  first cut, and re-running it against a variant with the `raise` removed
  reproduces `FAIL: W6m5 … -> {design-below-ase} (exp {design-above-ase})`.

W6m5/W6m6/W6m7 skip only after probing the **mechanism** directly (can this X
session restack / re-map at *all*?), never after a blind retry. A blind
retry-then-skip is why the older W4 row degrades to SKIP instead of red on a real
never-raise regression — issue **0646**.

---

## Decisions (ladder rung, and the rejected alternative)

| # | rung | decision | rejected |
|---|---|---|---|
| D1 | L2 (smallest blast radius) | fix the **caller** chain; never `raise_activate_toplevel` itself | teaching the helper to skip the withdraw when already mapped — one line, but it silently turns *every* WSLg raise in the program into a no-op, the exact class 0054 was written about |
| D2 | L1 (**I1** — one builder, many consumers, applied to the window scan) | thread `raise_mode` through the existing chain | a `do_run`-local scan over `xschem windows` — a second matcher that drifts silently from `raise_design_editor`'s two-loop match; `src/wave_viewer.tcl` already documents having had to mirror that scan once |
| D3 | L2 (least surprising) | `ifhidden` still re-maps when the toplevel is **not** mapped | reusing Ctrl-4's `do_raise 0` (never touch the toplevel) — would leave a minimised user with no window and no clue, re-arming the very menu detour this issue is about |
| D4 | L2 (fail-safe) | anything ≠ `ifhidden` behaves as `always` | making `ifhidden` the else-branch, where a typo silently disables every raise — a silent failure, which I1's rationale ranks as the worst outcome |
| D5 | L2 | Session menu, `select_on_design`/`direct_plot`, `wave_viewer::browser_descend_to` and the post-load re-scan all keep `always` | flipping the default — Session > Design Window **is** the user's documented recovery for this bug and must keep re-mapping (sabotage V2 reds W6m6 for exactly this) |
| D6 | **L3 → status E** | keep the **cheap** half of the raise in the `ifhidden` arm | dropping it too — implemented first, then refuted by measurement (above). See the ruling owed, below |
| D7 | L2 + named hazard | do **not** fix the descended case here → issue **0643** | making the guard pass by *ascending* — that changes `currsch` immediately before a run, which is issue 0608's ordering trap ("read the raw at the TOP, then descend") |
| D8 | L2 | do **not** fix the unfiltered `<Unmap>` bind here → issue **0644** | using `wm state .infotext` as this issue's assertion — it would anchor a new check to a live defect and go red the moment 0644 is fixed |
| D9 | L2, forced by measurement | the regression assertion is the `%W`-filtered `<Unmap>` counter, **not** `winfo ismapped`/`wm state` | hoping an environment supplies the dropped re-map — the `test_calc_skeleton` S12 lesson: force the property deterministically |
| D10 | L2 | the new leg runs **after W6 and before W6b** (W6b's proof is a hand-edit sentinel that re-netlisting destroys); the decoy schematic lives in `$scratch` | an untitled tab — `new_schematic create {} {}` risks an `untitled*.sch` in the repo root, which turns three suites red |

---

## Sabotage matrix

| variant | predicted red | observed |
|---|---|---|
| V1 revert the caller (`design_window $key`, the shipped defect) | W6m1 | ✅ exact — `W6m1 → {1} (exp {0})`, 1 FAILED (178 passed) |
| V2 flip the default to `ifhidden` everywhere | W6m6, W4 | ⚠ **W6m6 only** — W4 self-SKIPped instead of failing → issue **0646** |
| V3 never raise (no-op in place of `raise_activate_toplevel`) | W6m6, W6m7, W4 | ⚠ **W6m6 + W6m7** — W4 self-SKIPped again |
| V4 drop the context switch | W6m2, W6m3, W4, + `test_ase_plot`/`hier_plot` collateral | ⚠ **W6m2 + W6m3 (×2 rows)** — W4 stayed green, and **neither** predicted collateral suite moved (see the gaps below) |
| V5 invert the visibility test (`\|\| $vis`) | W6m1, W6m7 | ✅ exact — 2 FAILED (177 passed) |
| V6 swallow the mode on the forward (the I1 drift shape) | W6m1 | ✅ exact — 1 FAILED (178 passed) |
| **V7** drop the `raise` from the `ifhidden` arm (the refuted first cut) | W6m5 | ✅ exact — `W6m5 → {design-below-ase} (exp {design-above-ase})`, 1 FAILED (178 passed) |

### Predicted reds that did NOT appear — read these, they are coverage gaps

* **V2/V3: W4 never goes red on a never-raise regression — it self-SKIPs.**
  Measured under `xfwm4 --compositor=off`, a **reparenting, non-WSLg** WM, which
  directly falsifies that block's own in-file claim that "a REAL never-raises
  regression degrades to this SKIP line on EVERY run (and red on any non-WSLg
  display)". It is not red on a non-WSLg display; it is skipped. Filed as
  **0646**. The new W6m5/W6m6/W6m7 rows use a mechanism probe instead, and V7
  confirms the probe does *not* swallow a real regression.
* **V4: W4's own "design is now the current schematic" stayed green** with the
  context switch no-op'd — W4 invokes Session > Design Window while the design is
  not open anywhere, so `design_window` falls through both match loops into the
  fresh-open arm and never enters `raise_window_entry` at all. W4 covers the
  fresh-open path only.
* **V4: `test_ase_plot` (P9) and `test_ase_hier_plot_0168` (HL23-HL25) both
  stayed green** with the context switch no-op'd. HL23 asserts only that
  `raise_design_editor` **returns** 1 and HL24 that `currsch` is undisturbed;
  nothing there asserts the context actually switched. **W6m2/W6m3 are the only
  coverage anywhere in the tree for the context-switch half of
  `raise_window_entry`.**

---

## Acceptance

- [x] After **Netlist and Run** the design window is still mapped **and still
      visible** (raised above the ASE window and the viewer), with no menu
      detour. Measured `Unmap/Map = 0/0`, `stackorder … . .ase4.logwin`.
- [x] A regression check fails if the window is unmapped, iconified, or dropped
      below the ASE window — **W6m1** (unmap counter, the discriminating row),
      **W6m5** (buried → front), **W6m4** (the issue's literal wording, kept and
      labelled weak), **W6m7** (hidden → restored).
- [ ] **Only the user's own X server can close this.** No display on this box
      can reproduce a WSLg/VcXsrv dropped re-map, so a green suite is *not* the
      deliverable — `owed.sh add look` records it.

---

## STILL OPEN

1. **The ruling owed (status E).** On WSLg a plain `raise` is an inert no-op, so
   on *that* server the fix delivers "never vanishes" but not "comes to the
   front". The question for the user is in the ledger and is quoted in the
   commit body.
2. **Issue 0643 — Netlist and Run is REFUSED outright when the user is
   descended into the design.** `Status: Error`, red, `run_id` empty, no
   simulation. That is exactly where "run, then descend and press 6" stands.
   This fix removes the *flash* from that case but not the refusal, deliberately
   (D7). **This is now the largest remaining defect on this button.**
3. **Issue 0647 — the restored waveform viewer opens pixel-coincident over the
   design window** at session-open time. A user whose viewer lands exactly over
   the schematic will describe that as the schematic disappearing too, and it is
   the reason this fix needs the `raise` at all.
4. **Issue 0644** — every other `raise_activate_toplevel` caller still silently
   withdraws `.infotext` and clears `show_infowindow`. `do_run` no longer
   triggers it.
5. **Issue 0646** — W4's blind retry-then-skip masks a never-raise regression.
6. **Issue 0645** — `openbox` is not installed here, so the documented `AUDIT_WM`
   default arm runs WM-less and is not evidence for window-mapping issues.
7. **Post-run keyboard focus** moves to `.aseN.logwin` (the log window opens
   after the raise and takes focus). Pre-fix it ended on `.`. Unchanged by the
   remedy; for the "run, descend, press 6" workflow that is one extra click.
   Not filed — it is the log window doing what a newly opened window does.

## What this did NOT change (checked, not assumed)

`0608` is not re-armed: the fix changes window/tab context only. It never calls
`descend`/`go_back`, never touches `currsch` or `sim_sch_path`, and reorders
nothing around the `ase::netlist` call — so S4's
`catch {ase::op_cards_capture $state $nl}` walk (invariant **I6**'s restore
contract) is on an unchanged path. The user returns to the schematic by the same
code path they left by.
