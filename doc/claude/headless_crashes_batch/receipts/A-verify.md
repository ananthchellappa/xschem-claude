# A-verify — the fix round: six more doors, one guard that made things worse, and the arm that can see a hollow guard

Crew: **FIXER** (the one fix round; there is no round after this one). Work measured in
`/var/tmp/xhc/F/{t,t2,t3}`, a clone of `fluid-editing` at `63558796` carrying the implement
round's five landed files byte-identically (md5s in `A-impl.md` §0 — checked before the
first edit and again before the copy back). The edits are **landed in the main tree**; md5s
in §1.0. **Nothing is committed.**

Read `A-map.md` and `A-impl.md` first. This receipt does three things: it verifies the two
verifiers' findings one by one, it fixes what held up, and it says plainly what it did not
fix and why.

---

## 0. THE HEADLINE, IN THE FORM THE NEXT READER NEEDS

The implement round's title says the class is closed. It was not, and the reason is worth
more than the six bugs: **the sweep that produced `0 / 323` was blind in four directions at
once**, and each blind spot hid a live crash.

| the sweep did this | so it could not see | which hid |
|---|---|---|
| drove every verb **bare** | any body inside `if(argc > 3)` | `fill_type`, `preview_window` |
| ran its ten canvas events on an **empty untitled** schematic, never `xschem load` | anything `waves_selected()` gates | `waves_callback` (23 of the 60 shipped examples) |
| held **key and state fixed** | one keystroke in ~700 | `'\'` → `toggle_fullscreen()`, `XK_Print` → `GRABSCREEN` |
| enumerated dereferences of the `display` **global** | a **local** of the same name, and handles **stored in xctx** | `windowid()`, `waves_callback`'s cairo contexts |

The last row is the one `A-map.md` §6 already named as blind spots (b) and (c) and
`DECISIONS.md` **D5** then compressed to "the ONE blind spot … the preprocessor". **D5 is
wrong as written** and is the sentence a future reader will act on — see §6.

And one guard made things **worse than the crash**: `grabscreen()`'s new entry guard
returned without clearing `ui_state & GRABSCREEN`, and the `XK_Print` key armed that bit
with no `has_x` test. One keystroke and the whole event switch was dead for the life of the
process — a loud crash converted into a silent, permanent swallow of work the user asked
for, which is exactly what PLAN.md criterion 3 forbids.

---

## 1. WHAT I APPLIED — every fix, red-first and after

All red-first figures are on the **landed** binary (the implement round's five files, rebuilt
in my clone: no harness builds, so nothing here is taken from a binary I did not make).
Both `has_x == 0` arms were driven: `env -u DISPLAY … --nogui` and `DISPLAY=:160 … --nogui`
(my own private Xvfb; the dev display `:99` was never touched).

| # | site | red-first (landed binary, no DISPLAY) | after |
|---|---|---|---|
| 1 | `callback.c` `waves_callback()` — `if(!has_x) return 0;` | `FATAL: signal 11` | survives, rc 0 |
| 2 | `callback.c` `case XK_Print` — arms `GRABSCREEN` only under `has_x` | silently swallowed every later event | the editor stays live |
| 3 | `draw.c` `grabscreen()` — **clears** the armed bit instead of returning with it set | same swallow | same |
| 4 | `scheduler.c` `fill_type` — `if(has_x) { free_gc(); create_gc(); }` | `FATAL: signal 11` | works, and still does its display-free half |
| 5 | `scheduler.c` `windowid` + `xinit.c windowid()` | `FATAL: signal 11` | refuses with a message, process lives |
| 6 | `scheduler.c` `preview_window` + `xinit.c preview_window()` | `FATAL: signal 11` | refuses with a message, process lives |
| 7 | `xinit.c toggle_fullscreen()` — the **keyboard** route the verb refusal could not cover | `FATAL: signal 11` | survives, rc 0 |
| 8 | `scheduler.c` `grabscreen` — refusal moved **inside** `#if defined(__unix__) && HAS_CAIRO==1` | (platform correctness) | a Windows/no-cairo build keeps its old no-op |

### 1.0 Files changed, and the md5s landed in the main tree

```
1f7ae98666964a95c3ef984239b8760b  src/callback.c
79e9f39f146358f343361c08a0272e5c  src/draw.c
3ad900c9f4b2696e6353c85e8da2ecca  src/scheduler.c
360dc75b580b3c85944952b1f9105d2b  src/xinit.c          (NEW to this batch; see the note below)
8e4f2fb3a57a5136533cf919cbeb24ec  src/hilight.c        (unchanged by this round)
36b998e8761859c74461722d3ee6fe8b  tests/headless/test_callback_argc.tcl   (see the note below)
0818e61e57be873497d696f77b3abc85  tests/headless/test_headless_guards_xarm_1492.tcl   (NEW FILE)
76ed908d51042c9c2001ef5e6fec23f3  tests/run_regression.tcl
926cbe7c96b29ae6675e01ded2126d2b  tests/headless/test_raw_read_dispatch.tcl   (comment only)
489324b5ee53520583ab2257a9869057  tests/headless/test_hilight_case_senders.tcl
```

No file under `doc/claude/` is touched except this receipt and the corrections marked
"fix round" in `A-impl.md`.

⚠ **One COMMENT changed after the gate runs in §5**, and it is named rather than hidden:
`xinit.c`'s `windowid()` comment quoted the verify round's "`gcc -Wshadow` reports exactly
two such declarations in the whole tree". I measured it: two in `xinit.c` (`windowid()` and
the `err()` handler) **and two more in `draw.c`**, so the sentence was a count quoted
forward — the habit this project has a rule against. The comment now states what I measured.
`src/xinit.c` therefore hashes `360dc75b…` where the gate ran `ec79f204…`; the two differ by
that comment and nothing else (`diff` of the two: one hunk, all comment lines), the main tree
was rebuilt, and both suites were re-run against the rebuilt binary — `ALL PASS (50 checks)`
and `ALL PASS (8 checks)`.

The same applies to one **test comment**: `test_callback_argc.tcl`'s grabscreen paragraph
still carried the implement round's sentence "removing just one of them leaves the suite
green", which §4 disproves in both directions. It now says what was measured.
`3c5ad468…` → `36b998e8…`, comment lines only, and the suite was re-run on both arms after
the edit: **`ALL PASS (50 checks)`** headless, **`ALL PASS (36 checks)`** with a display.

### 1.1 The blocker: `waves_callback()` (verify: `reproduce`, blocker)

**VERIFIED.** Three Tcl lines, no state:

```
xschem load xschem_library/examples/cmos_example.sch
xschem zoom_full
xschem callback .drw 6 500 400 0 0 0 0      → FATAL: signal 11
```

gdb on the landed binary:

```
#0 cairo_save () from /usr/lib/x86_64-linux-gnu/libcairo.so.2
#1 waves_callback.isra ()
#2 callback ()
#3 xschem_cmds_c.constprop ()
```

`xctx->cairo_save_ctx` is NULL with `has_x == 0` (`create_gc()`/`resetwin()` never ran) and
the `cairo_save()` pair at the head of that function is unconditional. The guard is the
whole function, not the cairo pair: everything past it paints through `xctx->gc[]` /
`gctiled`, all 0, so a narrower guard would only move the fault down a few frames. The
function's normal exit returns 0 too, so no caller sees a different value (all fourteen
call sites discard it).

### 1.2 The other blocker: the guard that swallowed the editor (verify: `honesty`, blocker)

**VERIFIED, and it is the finding I would keep if I could keep one.** MEASURED on the
landed binary, `env -u DISPLAY … --nogui`:

```
Print key, then zoom-full key : xorigin yorigin zoom = 10 -870 1            (unchanged)
zoom-full key alone (control) : xorigin yorigin zoom = 104.418 103.093 0.2946
```

`case XK_Print` (inside `#if defined(__unix__) && HAS_CAIRO==1`) armed
`xctx->ui_state |= GRABSCREEN` with no `has_x` test — a **second** arming site the implement
round did not find, because it guarded the *verb*. `callback()` then routes **every** canvas
event into `grabscreen()` on that bit alone, and the new `if(!has_x) return 0;` returned
**without clearing it**. Both halves are fixed; §4 shows that each alone is insufficient and
which one the behavioural row can see.

### 1.3 `fill_type` — and why it GUARDS where `fill_reset` REFUSES

**VERIFIED** (`catch {xschem fill_type 1 2}` → `FATAL: signal 11`, both `has_x == 0` arms,
landed binary and base alike). The verifiers both recommended
`scheduler_needs_x_reject(interp, "fill_type")`. **I did not do that, and the reason is a
measurement**: `xctx->fill_type[]` is read by the HEADLESS exporters — `psprint.c` at four
sites and `svgdraw.c` at three — so this verb has real display-free work to do. Two PostScript
exports of `xschem_library/examples/cmos_example.sch` with no DISPLAY, differing only in
`xschem fill_type 4 empty` vs `solid`:

```
md5 53377e8ec5ae645a1f05787bf1d4c139   vs   cc116bea14fc574fdb59e6265c2e79d9
line 257:   S            →   GS C F GR S          (the fill is emitted)
```

So only `free_gc()`/`create_gc()` are skipped. `build_colors()` and `resetwin()` are already
`has_x`-guarded inside, `enable_layers()` touches no X, and `draw()`'s Xlib block is inside
`if(has_x)` — all four stay outside the guard and keep working. A refusal here would have
been criterion 3's other failure: work a user asked for, refused although it could be done.

⚠ **The same argument applies to `fill_reset`, which this round did NOT change** — see §2.6.

### 1.4 `windowid` and `preview_window`

**VERIFIED**, both `FATAL: signal 11` on the landed binary. `windowid()` is the shadowed-local
case `A-map.md` §6(b) predicted: it declares its own `Display *display` and builds it from
`Tk_Display(Tk_MainWindow(interp))`, so the map's compiler enumeration emitted nothing for
it. Both get the verb refusal (they ARE their X effect) **and** a function entry guard;
§4 shows what each of the two catches, separately.

### 1.5 `toggle_fullscreen()` by keyboard

**VERIFIED**: `xschem callback .drw 2 100 100 92 0 0 0` (the `'\'` key) → `FATAL: signal 11`
on the landed binary. The implement round guarded the verb; `handle_key_press()` reaches the
same function with no verb in between. The guard now sits on the **function**, which is the
choice `A-impl.md` already made correctly for `draw_crosshair`/`draw_snap_cursor`/
`handle_expose`, and the verb refusal stays so the verb still names the cause.

---

## 2. WHAT I DID **NOT** FIX, AND WHY — for the driver to file

### 2.1 `psprint.c` reads `ps_colors[cadlayers]`, one past the end (verify: `reproduce`, should)

**VERIFIED, and it is real.** `create_ps()` allocates
`my_calloc(_ALLOC_ID_, cadlayers, sizeof(Ps_color))` and then calls
`ps_draw_symbol(c + 1, i, c + 1, …)` for the text pseudo-layer when `c == cadlayers - 1`;
that call's trailing `if(textlayer != c) set_ps_colors(c);` indexes `ps_colors[cadlayers]`.
Three headless PostScript exports of the SAME file (`xschem_library/examples/LCC_instances.sch`)
on the landed binary:

```
md5 6e2a450a1ddb32fa0f4670030ebd6960 / 2e1a4f414c8634b6ee4072122515a860 / 5aa22645acd20a85521c5634fcad028c
each: 144 `… RGB` lines with a component > 1 (the PostScript gamut is 0..1)
with a display (:160), twice: 8a4a4dc3a34b9d0c1d8e0e7cea0927c7 both times, 0 out of gamut
```

**NOT FIXED. Reasons, in order.** It is not a `display` dereference and not this batch's
class (the verifier that found it says so itself). Every repair — allocating `cadlayers + 1`
or bounding the read — **changes the exported bytes** in 144 places on a path with no golden
and no suite, so it needs its own measurement and its own issue, not a fix smuggled into a
crash-guard commit. `svgdraw.c` carries the identical idiom (`svg_colors` at `:1138`,
`svg_draw_symbol(c + 1, …)` at `:1301`) — READ, not measured.

**Driver: file it**, with this measurement; it is a heap over-read that makes `xschem -p` /
`--pdf` non-deterministic with no display.

### 2.2 `--svg` writes a stub and calls it success (verify: `reproduce`, nit)

**VERIFIED with a difference.** `./src/xschem --svg --plotfile out.svg <sch>` with no
DISPLAY writes a **3096-byte file containing 5 tags** and prints
`tcleval(): … tkwait visibility .drw failed / : invalid command name "tkwait"`. On my arm it
then **HUNG** (killed at 120 s) rather than exiting 0 as the verifier measured; `--png` the
same way produced no output and hung too, where the verifier saw it refuse properly. I did
not chase the difference. **NOT FIXED**: a documented CLI flag whose behaviour I cannot yet
describe on both arms is not something to change in a fix round, and no test in the tree
drives `--svg` (grep: 0 hits). **Driver: file it** — the stub is the part that matters, and
it deserves the `--png`-style refusal.

### 2.3 No `XSetIOErrorHandler` (verify: `reproduce`, nit)

Accepted as reported, **not fixed**: pre-existing, outside the `has_x == 0` class, and a
crash-save guarantee for a dropped X connection is a feature with its own design. **Driver:
file it.**

### 2.4 Issue 0815 is 1492's older twin (verify: `honesty`, should)

Confirmed by reading: `doc/claude/issues/0815-compare-schematics-segfaults-under-nogui.md`
is the same defect as 1492's `compare_schematics` row, filed a month earlier and still open.
**Not mine to close** — `doc/claude/` is fenced to this receipt and the resolution sections
are the driver's pass. **Driver: close 0815 with 1492** (or `claim=duplicate super=1492`).
The stale wording it left in `tests/headless/test_raw_read_dispatch.tcl` IS fixed here (§3.3).

### 2.5 `DECISIONS.md` D5 is wrong as written (verify: `reproduce`, must)

D5 says the map's "ONE blind spot … the preprocessor, not callee naming". The map named
**four** (§6 a–d), and two of them each hid a crash measured in this round: (b) shadowed
locals → `windowid()`, (c) handles stored in `xctx` → `waves_callback()`. **Not edited by
me** (fenced). **Driver: correct D5**; §0 of this receipt is the replacement sentence.

### 2.6 `fill_reset` refuses where, by the same measurement, it could work

Not a verifier finding — mine, and I am leaving the landed behaviour alone. `fill_reset` runs
`init_pixdata()`, which populates the same `xctx->fill_type[]` that §1.3 proves changes a
headless PostScript export. So the implement round's stated reason ("a C array that only
`create_gc()` ever reads") is **false**, and a headless caller loses a real capability.

I did not change it because: it is landed, measured and green; its suite rows carry the
batch's one behavioural anti-hollow pair; and a refusal is **loud and recoverable** (the user
gets a message naming the cause), which is not what criterion 3 forbids — criterion 3 forbids
*silence*. **Driver: worth a small issue**, not a last-round edit. `fill_reset` has no caller
in `src/*.tcl` at all, so nothing ships broken either way.

### 2.7 `copy_hilights()`'s `!old_xctx` guard is unreachable today (verify: `honesty`, nit)

**CONFIRMED by sabotage, not by reading** (§4, S13b): with the scheduler refusal in place,
removing the `hilight.c` guard alone leaves the suite `ALL PASS (50 checks)`. With the
scheduler refusal removed instead (S13a), the `hilight.c` guard holds the crash off and two
rows go red. So it is defence in depth, it is load-bearing the moment the scheduler refusal
is not, and the two are now sabotaged separately as the finding asked. **Kept.**

### 2.8 The three paint guards still have no behavioural positive anywhere

`draw_crosshair`, `draw_snap_cursor` and `handle_expose` paint straight to the window with
`draw_pixmap = 0`; an Expose repaint is a copy **into** the window. No pixmap dump, no
`xschem get`, no export can read any of the three back — the same limit `test_wave_snap.tcl`
states for its own diamond. Measured, not assumed: sabotage **SX3** (all three forced to
`if(1) return;`) leaves my new display-arm suite at `ALL PASS (8 checks)`. What they now have
instead is a **textual** row each (`GX2`–`GX4`), which SX3 does redden, plus a real canvas
under the paint path. Stated here so nobody reads §3 as more coverage than it is.

---

## 3. THE TESTS — what runs, on which arm, and at what count

### 3.1 `tests/headless/test_callback_argc.tcl` (the T1 case): 27 → **50** checks

| arm | before this round | after |
|---|---|---|
| `env -u DISPLAY … --nogui` (T1's, headless box) | 27, 0 `skip:` | **50**, 0 `skip:` |
| `DISPLAY=:160 … --nogui` (T1's, developer box) | 27, 0 `skip:` | **50**, 0 `skip:` |
| `DISPLAY=:160 …` (`has_x` 1 — `run_suites.sh`) | 18, 5 `skip:` | **36**, 7 `skip:` |

**T1 still gains no `skip:` line**, by the same design the implement round used: every row
that cannot be measured with a display is branched, and the two rows that are unsafe to drive
on a live display (the `'\'` key would fullscreen the real toplevel; the Print key takes a
global pointer grab) `skip:` on the X arm only, which T1 does not run.

New rows: the six fix-round doors above, a control/test pair for the Print-key swallow, and
**thirteen `GX*` rows** that pin every guard's *condition* — `GX1`–`GX13`, one per guard,
each anchored inside its own function body so a guard in a neighbouring function cannot
satisfy it.

### 3.2 `tests/headless/test_headless_guards_xarm_1492.tcl` — NEW, and a `dcases` entry

This is the answer to the verify round's "criterion 3 is asserted by exactly one row on an
arm the gate does not run". `test_callback_argc` is an `hcases` entry and
`run_regression.tcl` hard-codes `--nogui`, so `has_x` is 0 there on **every** box; T1's only
display arm is the `dcases` loop. The new file holds the positives that only a display can
take — the statusbar really updates, the three refusal-gated verbs that are safe to drive
on a shared display really work, the graph handler really runs — and is registered in
`dcases` (T1 goes 94 → 95 cases on this tree; the other two, `fullscreen` and
`compare_schematics`, would resize the toplevel and open a modal chooser).

`DISPLAY=:160`, `has_x` 1: **`RESULT: ALL PASS (8 checks)`**.
`--nogui`: `skip: the whole display arm …` + `RESULT: SKIP (no display)`, exit 0 — so a
stranger running it headless gets a clean statement, not a red. It is **not** in `hcases`,
so T1's `skips=` is unchanged.

### 3.3 The other three suites touched

* **`tests/run_regression.tcl`** — one `dcases` entry plus the comment that says why it is a
  dcase and nothing else.
* **`tests/headless/test_raw_read_dispatch.tcl`** — comment only. Its SC09 block still said
  `compare_schematics` and `preview_window` "SEGFAULT under --nogui"; both now refuse. The
  new paragraph also records why SC09 is *still* their only cover: each refusal is the first
  statement of its branch, ahead of the `argc > 2` tilde expansion, so the path handling SC09
  scans for is unreachable headless by construction. Headless: `ALL PASS (137 checks)`.
* **`tests/headless/test_hilight_case_senders.tcl`** — the fourth of 0227's witnesses, and the
  one that still failed criterion 2. Two Tk/display-only blocks now self-skip by name:
  `RESULT: ALL PASS (21 checks)` + 9 `skip:` headless (it used to die at `invalid command
  name "toplevel"` with **no `RESULT:` line at all**), `ALL PASS (30 checks)` with a display.
  ⚠ **Criterion 2 is still not literally met for this suite** — 21 ≠ 30 — and it cannot be
  without a product change: `CS76`–`CS81` read back what `auto_hilight_graph_nodes` made of a
  graph's node names, and that runs inside `draw()`'s `if(has_x)` block, so headless there is
  no redraw to observe. The shortfall is now **named per row** instead of being a dead suite.

### 3.4 The rest of the affected suites, both arms

| suite | `--nogui`, no DISPLAY | `DISPLAY=:160`, `has_x` 1 |
|---|---|---|
| `test_keybind_snap_grid` | `ALL PASS (6 checks)` | `ALL PASS (6 checks)` |
| `test_undo_selection` | `ALL PASS` | `ALL PASS` |
| `test_window_switch_bogus_enter` | `ALL PASS (2 checks)` | `ALL PASS (2 checks)` |
| `test_hilight_case_senders` | `ALL PASS (21 checks)` + 9 `skip:` | `ALL PASS (30 checks)` |
| `test_callback_argc` | `ALL PASS (50 checks)` | `ALL PASS (36 checks)` + 7 `skip:` |
| `test_headless_guards_xarm_1492` | `SKIP (no display)` | `ALL PASS (8 checks)` |
| `test_raw_read_dispatch` | `ALL PASS (137 checks)` | — |
| `test_wave_viewer` | `ALL PASS (59 checks)` | `ALL PASS (402 checks)` |
| `test_wave_snap` | `ALL PASS (64 checks)` | `ALL PASS (106 checks)` |
| `test_wave_hilight` | `ALL PASS (139 checks)` | `ALL PASS (196 checks)` |

The three wave suites are the ones `waves_callback()` belongs to; their display-arm counts
are identical to the figures the verify round took on the unpatched binary (402 / 106 / 196),
so the new guard costs the X path nothing.

---

## 4. SABOTAGES — every guard this round added or touched, and each one singly

Method as the implement round's: patch one guard, `make`, run the T1 case on the `has_x == 0`
arm (and the new dcase on `:160` where the point is the display arm), restore, `touch`,
rebuild, and `md5sum` back to §1.0 — which passes.

| # | sabotage | result |
|---|---|---|
| SF1 | `waves_callback()` guard removed | **`FATAL: signal 11`**, no `RESULT:` line |
| SF2 | `fill_type`'s `if(has_x)` removed | **`FATAL: signal 11`** |
| SF3a | `windowid` **verb refusal** removed, entry guard kept | **2 rows red**, no crash |
| SF3b | `windowid` **entry guard** removed, refusal kept | **GX11 red** — and nothing else could see it |
| SF3c | `windowid` **both** removed | **`FATAL: signal 11`** |
| SF4 | `preview_window` **both** removed | **`FATAL: signal 11`** |
| SF5 | `toggle_fullscreen()` entry guard removed (verb refusal kept) | **`FATAL: signal 11`** (the `'\'` key) |
| SF6 | `XK_Print` arming guard removed, disarm kept | **2 rows red** (the swallow eats one event) |
| SF7 | `grabscreen()` **disarm** removed, arming guard kept | **GX8 red** — behaviour cannot see it |
| SF8 | **both** grabscreen halves removed | **3 rows red** (the permanent swallow) |
| SX1 | `if(has_x) update_statusbar(…)` → `if(0) …` | **GX1 red headless AND X1 red on the display arm** |
| SX2 | `scheduler_needs_x_reject()` always rejects | **GX9 red headless AND X2/X3/X4 red on the display arm** |
| SX3 | `draw_crosshair`/`draw_snap_cursor`/`handle_expose` → `if(1) return;` | **GX2/GX3/GX4 red headless**; the display arm stays `ALL PASS (8)` |
| S2′ | *(re-run)* `update_statusbar` call-site guard removed | `FATAL: signal 11` |
| S10′ | *(re-run)* `grabscreen` verb refusal removed | 3 rows red, no crash |
| S11′ | *(re-run)* `grabscreen` entry guard removed | **GX8 red** (was: green — see §4.1) |
| S13a | `copy_hilights` **scheduler refusal** removed, `hilight.c` guard kept | 2 rows red, no crash |
| S13b | `copy_hilights` **`hilight.c` guard** removed, refusal kept | `ALL PASS (50 checks)` — unreachable today |
| GX5, GX6, GX10, GX12, GX13 | the guard TEXT altered, one at a time, binary unchanged | the named row, and only that row, goes red |

**SX1 and SX3 are the two that matter most**, because they are the verify round's own
sabotage — the one that left twenty display-arm suites byte-identical and a whole T1 at
`counted_failures=0`. SX1 is now caught **on both arms**; SX3 is caught on the headless arm
by a textual row, and §2.8 says honestly that nothing can catch it behaviourally.

### 4.1 S11's stated reason was wrong, and the corrected sentence

`A-impl.md` §3 says S11 "stays green because the guard it removes is unreachable once the
verb refuses". It was reachable all along — through `XK_Print`, which nothing in the suite
drove (§1.2). The correct sentence is: **green because the suite drove the verb and not the
Print key**. With the Print key now driven and the disarm pinned by `GX8`, S11 reddens.

### 4.2 The pattern worth keeping

Three of the sabotages above (SF3b, SF7, S11′) redden **only a textual row**. That is not a
weakness of those rows; it is the measurement that says which guard is load-bearing *today*
and which is defence in depth — the distinction `A-impl.md`'s S11/S13 could not make because
it reverted pairs together. Sabotage each guard singly when two cover one path.

---

## 5. THE GATE — two full T1 runs, both arms, trailers verbatim

Two clones of the final tree, run concurrently, each `home=throwaway`, each naming its own
binary.

**Arm 1 — `DISPLAY` UNSET** (`/var/tmp/xhc/F/t2`):

```
T1-RUN-BEGIN pid=397772 script=run_regression.tcl start=2026-09-22 16:51:57 planned_cases=95 verdict=results.397772.log home=throwaway binary=/var/tmp/xhc/F/t2/src/xschem canonical=results.log
T1-RUN-END pid=397772 cases=95 blocks=94 counted_failures=4 skips=8 elapsed=604s end=2026-09-22 17:02:01
```

**Arm 2 — `DISPLAY=:160`** (`/var/tmp/xhc/F/t3`):

```
T1-RUN-BEGIN pid=399612 script=run_regression.tcl start=2026-09-22 16:52:02 planned_cases=95 verdict=results.399612.log home=throwaway binary=/var/tmp/xhc/F/t3/src/xschem canonical=results.log
T1-RUN-END pid=399612 cases=95 blocks=94 counted_failures=6 skips=8 elapsed=603s end=2026-09-22 17:02:05
```

### 5.1 ⚠ NEITHER ARM IS AT ZERO, AND NONE OF IT IS THIS ROUND'S — per case, measured

CLAUDE.md is explicit that a standing red is a defect and must be named per case, never
carried as a count. Three cases fail, and each was chased to a binary that does not contain
this batch at all.

| case | row | arm 1 | arm 2 | verdict |
|---|---|---|---|---|
| `headless/test_ase_optier_0963` | `Z6` (a capability re-run is not pinned to the old shape) | FAIL | FAIL | **pre-existing at HEAD** |
| `headless/test_ase_variant_1470` | `OT1` (a MEASURED-unsound printer's per-device shape) | FAIL | FAIL | **pre-existing at HEAD** |
| `headless/test_ase_conv_gui_1460` (display arm) | `GW9` (a step count typed into a field reaches the emitted line) | pass | FAIL once, **pass on the re-run** | **flake on T1's display arm** |

**How the first two were settled.** I rebuilt one clone twice and re-ran both suites
standalone, headless, each time:

```
implement round's landed src (pre-fix-round):  Z6 FAIL / RESULT: 1 FAILED (108 passed)
                                               OT1 FAIL / RESULT: 1 FAILED (75 passed)
PRISTINE HEAD 63558796, `git checkout -- src`: Z6 FAIL / RESULT: 1 FAILED (108 passed)
  (no batch code at all)                       OT1 FAIL / RESULT: 1 FAILED (75 passed)
```

Byte-identical failure text in all four runs. **The committed tree is not at zero**, and it
is not this batch: both rows are about what a simulator's *capability* answer is, which is
the class CLAUDE.md and the project's own notes say is environment-dependent. The implement
round's green T1 was taken at `b2431613`; ten commits later two of these rows are red on a
pristine clone. **Driver: this is a standing red to name and own**, exactly as issue 1456
("T1 has not been at zero since stage 7, and the driver kept reporting that it was") says.

**How the third was settled.** `test_ase_conv_gui_1460` passes standalone on `DISPLAY=:160`
on BOTH binaries — `RESULT: ALL PASS (104 checks)` on the pre-fix-round build and on the
fixed one — and failed in only one of two concurrent T1 arms. GW9 types into a live Tk entry
and reads what the window emits without leaving the field, so it is focus/timing sensitive on
a private Xvfb. **Settled by a third full T1**: the display arm re-run on the same clone and
the same binary comes back with GW9 green and only the two ASE cases red —

```
T1-RUN-BEGIN pid=531516 script=run_regression.tcl start=2026-09-22 17:06:54 planned_cases=95 verdict=results.531516.log home=throwaway binary=/var/tmp/xhc/F/t3/src/xschem canonical=results.log
T1-RUN-END pid=531516 cases=95 blocks=94 counted_failures=4 skips=8 elapsed=539s end=2026-09-22 17:15:53
```

— so the display-arm figure for this tree is **`counted_failures=4`, the two pre-existing ASE
cases**, and GW9 is a flake, named rather than absorbed. `test_callback_argc` and
`test_headless_guards_xarm_1492` are `ALL PASS (50 checks)` / `ALL PASS (8 checks)` with
`Total num fail: 0` in all three verdicts.

**What this round's own suites did on both arms:** `headless/test_callback_argc` →
`RESULT: ALL PASS (50 checks)`, `Total num fail: 0`; `headless/test_headless_guards_xarm_1492`
(display arm) → `RESULT: ALL PASS (8 checks)`, `Total num fail: 0`. On arm 1 the display arm
ran on T1's own private Xvfb (`DISPLAY` was unset for the driver), which is the arm the new
dcase exists for.

**`cases=95`** is the tree's 94 plus this round's one new dcase; **`skips=8`** is the tree's
own baseline at this HEAD (five in `test_op_annot`, and one block each in
`test_input_line_inject_1352`, `test_preview_name_inject_1601` and `test_generator_paren_1604`).
**This round adds ZERO skips to T1** — checked line by line in both verdicts.

---

## 6. WHAT THE DRIVER STILL OWNS

1. **Correct `DECISIONS.md` D5** (§2.5): the map named four blind spots, and (b) and (c)
   each hid a crash measured here.
2. **Close 0815 with 1492** (§2.4), and write the resolution sections for 0227, 0834, 0467,
   1492 and 1493 — `doc/claude/` is fenced to this receipt.
3. **File three new issues**: the `psprint.c` / `svgdraw.c` out-of-bounds colour read (§2.1,
   measured), the `--svg` stub (§2.2, measured), and the missing `XSetIOErrorHandler` (§2.3).
   Optionally a fourth for `fill_reset`'s refusal (§2.6).
4. **Rebuild before the gate.** I rebuilt the main tree after copying (`make -C src`), but
   the harness never builds and this tree carries other crews' work.
5. The commit message must not say the class is closed. What is true: **the class is closed
   at every site measurable by the methods used here, and §0 names the four blind spots those
   methods have.**

---

## 7. HOUSEKEEPING

* **Scratch**: `/var/tmp/xhc/F/` only (three clones `t`, `t2`, `t3`, a work dir, a scratch
  HOME). **Peak size 1.5 GB** (three built clones at 433/507/507 MB plus a work dir and a scratch HOME; measured with `du -sh` just before deletion). Deleted by this crew; the sibling subtrees under
  `/var/tmp/xhc` (`a/`, `A/`, `v2/` and any other crew's) were not touched.
* A private **Xvfb on `:160`** with `openbox` was started and stopped. The dev display `:99`
  was never touched, `HOME` was `/var/tmp/xhc/F/home` or T1's own throwaway throughout, and
  `~/.claude`, `~/.xschem` and `~/dev/xschem-op-wcard` were not written.
* **C89**: `gcc -std=c89 -pedantic -fsyntax-only` on `callback.c`, `draw.c`, `scheduler.c`,
  `xinit.c` and `hilight.c` gives exactly one diagnostic — a mixed-declaration warning in
  `xschem_cmds_s`, a function this round did not touch, and **present identically on the
  pre-fix file** (measured both ways). No new build warning; no allocation added, so
  `_ALLOC_ID_` is not in play. The one platform-sensitive edit moved a refusal **inside** its
  `#if defined(__unix__) && HAS_CAIRO==1`.
* Emergency-save directories: the red-first runs write `/tmp/xschem_emergencysave_*`. The set
  present before this crew started was snapshotted (679) and the **13** this crew created
  were removed; `/tmp` is back at 679.
* ⚠ **One small litter finding, free**: T1 left
  `/var/tmp/xhc/f/t{2,3}/tests/headless/.scratch/_sp1452_<pid>/cpwork` behind — a
  **lower-cased** copy of my clone path (`/var/tmp/xhc/F/…` → `…/f/…`), made by
  `test_ase_sp_1452`. Empty directories only, and removed with my scratch, but it means that
  suite lower-cases a checkout path somewhere it should not, which is the same class as
  issues 1484/1490 ("a path with a space or a capital"). **Driver: worth a look**; it will
  litter any checkout whose path contains a capital letter.
