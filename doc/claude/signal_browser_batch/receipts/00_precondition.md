# Item 00 — PRECONDITION: issues 0186 / 0187

Implementer receipt. Branch `fluid-editing`, batch HEAD at start `ccd5f30a`.
Date 2026-08-03.

**Headline for the driver, before anything else:** the PLAN's item-0 clause
*"needs real design → `[D]`, and **items 8-15 are automatically deferred with it**"*
rests on a premise that is **measured false**. 0187 is FIXED here. 0186 is
reproduced and **not** fixed (it needs C, which batch decision 8 forbids), but the
mechanism the PLAN feared — *"anything that adds state makes 0186 strictly worse"* —
does not hold for the state items 8-15 add. Evidence in §3. **Recommendation: do not
fire the auto-defer.** The call is the driver's; this is a recommendation, not an
override.

---

## 1. 0187 — FIXED

### What was wrong

`wviewer::open` stamps five per-context C flags on the window it has just created —
`readonly` (D1), `no_grid` (item 18), `no_snap` (0177), `graph_snap_cursor` (item 9)
and `wave_viewer` (0172). Because the context switch is measured to no-op under a
raised semaphore, the proc re-checked before stamping:

```tcl
set wp [xschem get current_win_path]        ;# after `xschem load_new_window -window {}`
...                                         ;# recovery loop: assigns only a VERIFIED value
if {[xschem get current_win_path] ne $wp} { ... refuse ... }
```

`wp` was **read from** `current_win_path`, and between that read and the comparison
there is no `update`, no event loop and no command that can move the context. The
comparison was a value against itself and **could never fire**. The only live guard was
`$top eq {.}`, which catches the ROOT window and nothing else — so a context parked on
any `.xN.drw` (a detached editor, or any non-first tab) sailed straight through and the
user's live schematic got branded read-only, grid-less, snap-less and permanently
`wave_viewer`.

### The fix — `src/wave_viewer.tcl`, one file

The decision moved into a **pure** proc `wviewer::ctx_verdict wp tops0 tops1 ninst
nwires` → `{ok <toplevel>}` | `{err <msg>}`, inserted between `wviewer::forget` and
`wviewer::open`. Pure because `wviewer::open` returns 0 without `::has_x` and everything
past the brands is Tk — extracting the rules is the only way to test them in the
true-headless arm. Three rules, in order:

1. `$top eq {.}` — the pre-existing ROOT-window refusal, **unchanged**.
2. **the repair** — the context must have landed on a toplevel that was *not* in
   `winfo children .` before the create and *is* in it after. The intended target is
   not a path anybody hands us; it is *"a toplevel THIS call created"*, so that is what
   is tested. Sound in both window models: `-window` sets `force_window=1`, an empty
   file arg takes `new_schematic("create_window",...)`, `xinit.c` always calls
   `create_new_window` for that regardless of `tabbed_interface`, and
   `create_new_window` does `toplevel .xN` — a direct child of `.` either way.
   **Confirmed empirically, not just from source**: in a live tabbed session
   `winfo children .` reads
   `.infotext .menubar .#menubar .drw .statusbar .toolbar .tabs .x1 .x2 …`.
3. **the belt** (0187's "Direction", third option) — refuse to stamp a context that
   holds instances or wires. A viewer buffer never does (a `create_window` buffer is
   measured 0/0), so it cannot false-refuse; it stops a brand dead if rule 2 is ever
   weakened.

`wviewer::open` keeps the `"wviewer: "` prefix so there is exactly one site for it, and
the two pre-existing CIW strings are byte-for-byte unchanged:

* `wviewer: could not give the waveform viewer its own window`
* `wviewer: the waveform window did not take the context, refusing`
* `wviewer: refusing to brand a window that holds a schematic`  ← new (rule 3)

The stale 10-line comment block that claimed the old guard caught the detached-editor
case (it is exactly the case that sailed through) is deleted; its content is superseded
by the `ctx_verdict` header.

**No C.** `create_new_window`'s silent no-free-slots return — the other half of 0187's
"Direction" — was deliberately **not** changed: that is C and batch decision 8 forbids
it. Rule 2 does not need it, because it detects the *absence of the toplevel* rather
than the *absence of an error*.

### Tests — `tests/headless/test_wave_viewer.tcl`, X1-X9

| check | asserts |
|---|---|
| X1 | `ctx_verdict` returns `{ok .x2}` for a toplevel this call created |
| X2 | refuses the ROOT window (rule 1) |
| X3 | refuses when NO new toplevel appeared — **the 0187 trigger-A shape** |
| X4 | refuses a PRE-EXISTING toplevel even when a new one appeared — the semaphore-lag shape |
| X5 | refuses a context holding instances (rule 3) |
| X6 | refuses a context holding wires (rule 3) |
| X7 | messages carry no `wviewer:` prefix — `open` owns it |
| X8 | the C precondition: `create_new_window` is silent when the slots are full |
| X9 | source-shape pin: `info body ::wviewer::open` no longer contains the circular comparison |

Counts: **48 → 57 true-headless**, **392 → 400 under a real `DISPLAY`** (X8 self-skips
there, see below). Both arms ALL PASS.

Two deliberate divergences from the plan's test spec, both declared:

* **X8 runs in the `--nogui` arm only.** It exhausts all 20 window slots. Measured cost:
  **~65 ms and no visible windows true-headless**, versus **57.5 s and 19 real
  toplevels** under `DISPLAY` — and full_audit's per-test timeout is 120 s, with
  `test_wave_viewer`'s DISPLAY arm already at ~55 s. It would also eat every free slot
  for anything running after it. X8 asserts *C* behaviour that this Tcl fix does not
  change, so the cheap arm is enough; the DISPLAY arm prints an explicit
  `SKIPPED: X8 …` line rather than silently dropping it.
* **X8's stop index is 20, not the plan's 19.** 19 creates succeed (`.x1`…`.x19`) and
  the 20th is the one that no-ops. The check asserts the *behaviour*
  (`stuck && rc == 0 && err eq {}`), not the index.

X9 is commented in the test as a deliberately brittle source-shape pin: reinstating the
circular comparison changes **no behaviour**, so no behavioural check can catch it.

### Sabotage-verify (3, all observed)

The fix was uncommitted when the sabotages ran, so `git checkout --` would have
discarded the fix with the sabotage. `src/wave_viewer.tcl` was backed up to the
scratchpad first and restored from the backup, then `diff` against the backup confirmed
byte-identity.

| id | sabotage | target | observed |
|---|---|---|---|
| SB-A | rule 2 made `if {0}` — behaviourally the pre-0187 code | X3, X4 | **exactly X3+X4** in BOTH arms (headless `2 FAILED (55 passed)`, DISPLAY `2 FAILED (398 passed)`); `test_pristine_untitled_viewer_0172` stayed **41/41** |
| SB-B | rule 3 (the `$ninst`/`$nwires` belt) deleted | X5, X6 | **exactly X5+X6** in BOTH arms (`2 FAILED (55 passed)` / `2 FAILED (398 passed)`) |
| SB-C | the old circular guard reinstated alongside the new call (a tautology — no behaviour change) | X9 only | **exactly X9** in BOTH arms (`1 FAILED (56 passed)` / `1 FAILED (399 passed)`) — proving X9 is not decorative |

SB-A and SB-B each move **two** checks because each targets one rule that two checks
exercise. That was declared in the plan up front; the contract held is *"exactly the
declared set moves, and nothing outside it"*.

After each revert, a clean re-run read **57/57** headless.

---

## 2. 0186 — REPRODUCED, NOT FIXED, stays `[D]`

### Re-measured verbatim at `ccd5f30a`, 2026-08-03

`--nogui`, the issue's own recipe plus a raw:

```
before wv=1 ro=1 rects2=1 rawvars=424 rawpoints=20503
after  wv=1 ro=0 rects2=0 rawvars=424 rawpoints=20503
```

Both halves of the defect stand: the graph rects are gone, and `readonly` is silently
cleared on a *failed* load — breaking the viewer's D1 "read-only for the window's life"
contract via a command the viewer never opted into.

**New datum 1 — the raw survives intact.** 424 vars / 20503 points before and after.
That narrows the blast radius to the **graph-rect model**; the loaded waveform data is
untouched.

**New datum 2 — under a real `DISPLAY`, reload on a viewer also HANGS the process.**
The issue was measured `--nogui`. Under X, `load_schematic()`'s fopen-failure path runs
`update; alert_ {Unable to open file: …}`, a **modal** dialog with nobody to dismiss it.
A scripted probe sat there until it was killed at 200 s; the measurement below only
completed after stubbing `alert_`. This is strictly worse than the recorded symptom and
should be carried into whatever fixes 0186.

### Re-anchored line numbers

| what | prompt said | actual today |
|---|---|---|
| the `reload` branch | `scheduler.c:9494` | **`src/scheduler.c:10036`** — body `:10039-10041` is `unselect_all(1); remove_symbols(); load_schematic(1, xctx->sch[xctx->currsch], 1, 1);`, still unguarded |
| `readonly` reset | `save.c:3734` | `src/save.c:3734` — EXACT |
| fopen failure | `save.c:3810` | `src/save.c:3810` — EXACT |
| the alert message | `save.c:3814` | `src/save.c:3814` — EXACT |
| `clear_drawing()` | `save.c:3827` | `src/save.c:3827` — EXACT |

### Why it stays `[D]`

Two independent reasons, either one sufficient:

1. **It needs C.** The two families are `scheduler.c:10036` (reload) and the
   routing-exempt in-place loads in `scheduler.c` / `save.c`. Batch decision 8 says
   *"No new C code in items 1-15… If a scout concludes an item needs a `scheduler.c`
   branch, that is a `[D]`."* No Tcl edit can fix it: `src/xschem.tcl` holds only a
   `xschem reload` **caller** (`:13074`, and `action_registry.tcl:183`), and guarding
   that one caller would leave every other door open.
2. **Its Part 2 is an undecided design question by the issue's own words** — the
   routing-exempt loads are *"arguably correct as it stands"* and the issue asks
   *"whether 'explicit' should still mean 'explicit' when the target is a viewer"*.
   That is a decision, not an implementation.

### The split-out `readonly`-cleared-on-failed-load defect

Not filed here. It belongs to **item 16** ("open a numbered issue for each `[D]` this
batch produced"). Note for whoever files it: the 0186 prompt's *"next free issue number
after 0187 is 0188"* is **stale** — 0188-0194 and 0200-0211 are all taken (highest
`0211-ase-migrate-residue-closeout.md`). **The next free number is 0212.**

---

## 3. Decoupling: items 8-15 should NOT auto-defer

The PLAN's auto-defer rests on one sentence: *"Anything that adds state makes 0186
strictly worse — a reload that destroys the context now also orphans a sidebar."*
**Measured under a real `DISPLAY`, that is false.** A `frame $top.wvbrowser` packed with
exactly the item-8 idiom (`pack … -side left -fill y -before $top.drw`), carrying a
child widget, across an `xschem reload` on a viewer context:

```
before wv=1 ro=1 rects2=1 rawvars=424 sidebar=1 sidebar_packed=1 child=1 toplevel=1 drw=1
after  wv=1 ro=0 rects2=0 rawvars=424 sidebar=1 sidebar_packed=1 child=1 toplevel=1 drw=1
```

Three findings:

* **reload frees no Tk widget.** The toplevel, `$top.drw`, the sidebar, its packing and
  its child all survive. `clear_drawing()` clears the C *document* model; it has no
  reach into the Tk widget tree. A sidebar is not orphaned — nothing orphans it.
* **the raw survives**, 424 vars → 424 vars. Everything the browser displays comes from
  `xschem raw list` / `xschem raw`, which is exactly the state 0186 does not touch.
* **snapshot/restore state is token-keyed Tcl** (`wviewer::snapshot` /
  `wviewer::restore`, `wave_viewer.tcl:2165` / `:2212`, over the namespace's
  `$token`-keyed arrays). It lives in the Tcl interpreter, not in `xctx`, so a context
  wipe cannot reach it either.

**The counter-finding worth stating plainly:** the "adding state makes it worse"
mechanism is real, but it belongs to **0187**, not 0186. 0187's branding lands five
per-context flags — and, with them, viewer *ownership* — on a window that is somebody
else's live schematic; every widget item 8+ hangs off `$top` would then be built on
that window too. That is the defect that got strictly worse with more state, and it is
**fixed** here.

**Recommendation to the driver: do not fire the items-8-15 auto-defer.** This is a
recommendation, not a unilateral override — the PLAN's literal wording is the driver's
to apply or waive.

**The live footgun items 8+ must respect anyway:** 0186 stays OPEN. `xschem reload`
typed in the CIW while a viewer holds the context still blanks the document, still
silently clears `readonly`, and under X still pops a modal nobody can dismiss. Any
browser code that derives state from the **rect model** inherits that bug. Derive from
`xschem raw list`, which survives.

---

## 4. What was NOT verified

* **The C half of 0187 is untouched.** `create_new_window()` still returns silently
  when the slots run out (`src/xinit.c:1990-1991`, second site `:2007`), rc 0, no Tcl
  error. Rule 2 detects the consequence, not the cause. Any other caller of
  `new_schematic("create"…)` is still lied to.
* **X8 does not run in the `DISPLAY` arm** — the arm full_audit uses. Its subject is
  that C behaviour, so it is not a hole in the *fix*'s coverage, but it does mean the
  audit never exercises real slot exhaustion.
* **No `wviewer::open` false-refusal was ever *provoked*** — only observed not to
  happen. The DISPLAY arm's G1-G17 legs (400 checks, ALL PASS) drive the real
  `wviewer::open` happy path repeatedly, including a fresh reopen, which is the
  integration evidence rule 2 needed; but a deliberately failed create was not injected
  into the live proc, only into `ctx_verdict`.
* **Tabbed mode only.** Every DISPLAY run here was in the shipping tabbed profile
  (`winfo children .` shows `.tabs`). Rule 2 is argued sound in the non-tabbed model
  from source (`xinit.c` calls `create_new_window` for `create_window` regardless of
  `tabbed_interface`), not measured there.
* **Nothing about 0186 was fixed or attempted.**

### Suite evidence

| suite | before | after |
|---|---|---|
| `test_wave_viewer` (`--nogui`) | 48 ALL PASS | **57 ALL PASS** |
| `test_wave_viewer` (`DISPLAY`) | 392 ALL PASS | **400 ALL PASS** |
| `test_pristine_untitled_viewer_0172` | 41 ALL PASS | 41 ALL PASS |
| `test_untitled_reuse` / `test_wave_clear_all` / `test_wave_tabs` / `test_wave_snap` / `test_load_window_routing` / `test_wave_grid` | — | 6 / 75 / 172 / 106 / 14 / 240, all ALL PASS |
| `test_wave_trace_menu` | — | 396 passed, 1 failed = the documented ~4-in-10 TG9 WSLg root-coords flake |

`tests/headless/full_audit.sh`: **264 pass / 17 fail / 1 crash-timeout / 0 skip (282)**,
`WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)`. Baseline was 264 / 18 / 0 / 0.

Diff against the 18-name baseline list:

* **Three baseline fails PASSED this run** — `test_remap`,
  `test_resolved_net_hash_bus_0158`, `test_wave_trace_menu`.
* **Three names appeared that are not on it** — `test_ase_plot` (TIMEOUT; the documented
  P4/P6/P8 flake), `test_cadence_window_hop_log`, `test_multi_window`. **All three were
  re-run individually and all three PASS**: `test_multi_window` 15 ALL PASS,
  `test_ase_plot` 150 ALL PASS, `test_cadence_window_hop_log` ALL PASS in its
  `--logdir` arm. None of the three opens a waveform viewer, so none can reach the
  changed code.

Net: no non-baseline failure attributable to this item.

