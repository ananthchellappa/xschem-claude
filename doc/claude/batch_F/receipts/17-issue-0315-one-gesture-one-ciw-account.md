# Receipt 17 — issue 0315: one gesture, one CIW account, and no red line on a benign one

**Issue:** `doc/claude/issues/0315-the-signal-browser-reports-one-landing-twice-in-the-ciw-and-one-of-the-two-is-red.md`
**Branch** `fluid-editing`. **Start HEAD** `a1da62e6`. **Nothing pushed.**
**Test:** `tests/headless/test_wave_sigbrowser_0315.tcl`, 21 checks, band **BE**,
**19 sabotage mutations**.

---

## 1. The ruling, and it was the user's

The issue shipped with **four** candidates and no ruling, because "which of the
two lines should survive" is a decision about the log the user reads, not a bug
with one right answer. Asked in plain English with the cost of each, the answer
taken 2026-08-12 was **(1) AND (3), both**:

* **(1) The ASE command owns the CIW account of its own gesture.**
  `wviewer::browser_say` keeps its sidebar status-line write on every branch and
  skips its CIW echo when `ase::show_in_browser_for_current` is driving it. A
  caller that is *not* an ASE command still gets the viewer's own line.
* **(3) A landing that fell through is not an error.** The `err` that `ase.tcl`'s
  last-mile retry recovers from must not paint a red line in a log the user is
  being trained to read as a failure marker.

They are not exclusive: **(1) fixes the count, (3) fixes the colour.**

Before: three CIW lines for `a1` (two of them the same sentence), four for the
`a9` control with **one tagged `#!`** — for a gesture whose eyeball verdict is
PASS. After: two `ase: ` lines for either, neither of them red.

## 2. What was NOT built, and why

**Candidate (2)** — "the viewer owns it, drop `ase.tcl` step 6's echo" — was on
the table and was not chosen; it would have dropped the `ase: ` prefix that ties
the line to the key the user pressed.

**A third positional argument on the two entry points was not buildable**, and
that is a measurement rather than a preference. `browser_say` is only ever
reached through `browser_show_path` / `browser_show_db_scope`, so "tell it who is
calling" wants an argument — but **two suites stub those procs with their shipped
arity**: `test_ase_cosim.tcl` (`proc ::wviewer::browser_show_path {token path}`)
and `test_wave_sigbrowser_i12.tcl`. Sabotage **S19** applied exactly that design
and measured the cost: `test_ase_cosim` **5 FAILED** (FV34-FV38 — the gesture's
whole call sequence collapses to `f1 open`) and `test_wave_sigbrowser_i12`
**8+ FAILED**, the first reading verbatim

```
ERR:wrong # args: should be "wviewer::browser_show_path token path"
```

So the mechanism is a **one-shot per-token flag**, and `BE13` pins the arity it
exists to protect.

## 3. The change

### `src/wave_viewer.tcl`

* **`variable sayquiet`** — new per-token array, declared beside `browserwidth` /
  `gripdrag` with the reason, declared again in `wviewer::forget` and swept there
  (`catch {unset sayquiet($token)}`). The file's recurring bug is an *undeclared*
  `variable` making the unset address a local array, which fails and is swallowed
  by its own `catch`; `BE12` has a leg for each half.
* **`browser_say`** — the `browser_status` write is unchanged and
  **unconditional**; the two `wviewer::echo` arms are now inside
  `if {![wviewer::browser_say_quiet_consume $token]} { … }`. **Conditional, not
  deleted:** the unarmed arm is the viewer's own contract.
* **`browser_say_quiet {token {on 1}}`** — arm / disarm. Does not stack.
* **`browser_say_quiet_consume {token}`** — read AND unset; answers 0 for a token
  that was never armed **without creating the entry** (`BE05`).

### `src/ase.tcl`, `show_in_browser_for_current`

* One arm immediately before **each** of the three viewer calls
  (`browser_show_db_scope`, the `segs` `browser_show_path`, the `base` retry).
  **Per call, not once for the proc** — the flag is one-shot, so a single arm at
  the top of step 6 would silence only the first call. `S14` is that mutation and
  `BE09`/`BE10` red on it.
* The arm before the retry is where **ruling (3)** actually lands: that is the
  `err` the next line recovers from, and unarmed it reached the CIW tagged
  `error`.
* A **tail disarm** (`browser_say_quiet $key 0`). It is the leak guard, not the
  mechanism — every arm above is consumed by the say of the call it was armed
  for, so it normally unsets nothing.

## 4. Evidence

21 checks. `BE01`-`BE06` the flag itself (one-shot, disarm, per-token, no
stacking, no entry created by an unarmed read). `BE07`-`BE13` source: both echo
arms alive and gated on exactly one consume; `browser_status` outside the guard;
`ase.tcl`'s three arms and one disarm, **each arm before the call it is for**;
the teardown's two halves; the entry-point arity. `BE20`-`BE27` the seam driven
on a **real browser with the real resolver** under X: two positive controls
(unarmed → exactly one line; unarmed `err` → exactly one line **tagged error**),
then armed → zero lines with the status line still carrying the sentence, armed
`err` → **zero lines and zero red**, one-shot at the real seam, the `a9`
fall-through pair, and `forget` dropping an armed flag.

### 4.1 Sabotage — 19 mutations, all measured

The full table is in the test file's header with the exact reds. Summary: **18 of
19 red at least one check**; three red MORE than the claim they were written for
(`S1` also reds `BE08`, `S2`/`S5` also red `BE04`, `S15` also reds `BE10`).
**`S19` is an honest hole and it is recorded as one** — the third-argument design
leaves this file 21/21 green and reds the two arity-stubbing suites instead (§2).

## 5. Review findings — two adversarial agents, neither the implementer

Lens A: **Tcl state lifetime**. Lens B: **evidence quality**. Between them they
broke the first version of this work, which was 21/21 green with 19 sabotage rows.
**Seven findings were confirmed and fixed; the rest are recorded.**

### A-1 / A-2 — the tail disarm is not a leak guard: an exception (or a future
early `return`) between an arm and its say bypasses it. **CONFIRMED, FIXED.**
Reviewer reproduced it end to end under Xvfb by making `browser_reveal` throw:
the flag survived the gesture and **the next unrelated navigation's CIW line was
eaten**. Tcl 8.4 is still a target, so there is no `finally`. **Fixed by clearing
on ENTRY as well** — the next reader of the flag after a leak is the gesture's own
first arm, so the leak cannot reach anything. `S27` is the mutation, `BE09`/`BE10`/
`BE34` red on it. Reachability of the original: **latent, not live** — the
reviewer read every callee inside the armed window and all are pure or
`catch`-guarded.

### A-3 — the safety argument's own return count was wrong. **CONFIRMED, FIXED.**
The comment licensing the one-shot design claimed "8 in `browser_show_path`, 10 in
`browser_show_db_scope`". Measured: **8 and 11**. Corrected, and **`BE15` now pins
both counts and the no-bare-return property**, which nothing in the tree did.
`S26` inserts a bare return and reds it.

### B-1 — the line that is now the gesture's ONLY account was asserted by nothing,
anywhere in the tree. **CONFIRMED, FIXED.** The capture filter kept only
`signal browser:` and discarded every `ase: ` line; `grep -rn "ase: signal
browser" tests/` was empty. So **deleting `ase.tcl`'s echo pair — candidate (2) on
top of (1) — would have left the gesture writing NOTHING, with 21/21 green.**
Fixed: the capture keeps two lists and `BE31`/`BE32`/`BE33` assert the ase
sentences verbatim. `S25` is that mutation.

### B-2 — nothing bounded the NUMBER of viewer calls, only the number of arms.
**CONFIRMED, FIXED.** Reviewer added a fourth **unarmed**
`browser_show_path $key {}` and all thirteen source checks stayed green, restoring
the duplicate-plus-red line on that path. Fixed by `BE16` (calls == arms) and
`BE34` (runtime interleaving). `S23`.

### B-3 — "we cannot drive the real gesture" was FALSE. **CONFIRMED, FIXED.**
Two precedents exist: `fv_arm` in `test_ase_cosim.tcl` (headless) and
`fd_drive_on` in `test_wave_sigbrowser_digital.tcl` (real browser). `BE31`-`BE34`
now drive `ase::show_in_browser_for_current` with only the five design-side reads
stubbed. **This also closed S19**: with the call text pinned to its closing
brackets, the third-argument design reds `BE10`/`BE11` here instead of only
off-file.

### B-4 — `BE07` pinned the consume's NAME, not its token or the guard's polarity.
**CONFIRMED, FIXED.** Both defects measured 13/13 green on the headless arm:
`browser_say_quiet_consume ONE` (a constant token — one window silencing another)
and dropping the `!` (echo only when armed, the inverse of both rulings). Both are
now pinned as exact text; `S20`/`S22`.

### B-5 — ruling (3)'s tag claim had no source coverage. **CONFIRMED, FIXED.**
Swapping the two echo arms — success painted red, failure painted plain, i.e.
ruling (3) backwards — was 13/13 green headless. `BE14` pins which arm carries the
tag by substring order; `S21`.

### B-6 — `BE24`'s status leg was order-dependent and raced a shared label.
**CONFIRMED, FIXED.** `BE22` leaves the identical sentence on `.ph`, and `.ph` has
~20 writers; in one sabotage run the reviewer measured a third-party
`3 of 3 signals` landing there. Fixed with a sentinel stamped before the call, so
the leg reads "written BY THIS CALL". `S28` (delete the status write) reds
`BE23`/`BE24`.

### B-7 — on the **a1** gesture the sidebar status line does NOT survive the
gesture. **CONFIRMED, recorded, not "fixed".** `ase.tcl` step 7/7b call
`browser_notice`, which overwrites `.ph` — deliberately, with its own ⚠ saying so,
and `test_wave_sigbrowser_digital`'s FD24 asserts that end state. So "the status
line still carries the sentence" is true of the *say*, not of the *gesture*, on the
digital path. **It costs nothing here**: the sentence is still in the CIW, as the
`ase: ` line. The receipt says "status line" only about `browser_say`.

### A-4 / B-8 — declared limits, no code change
* The `if {$on}` in `browser_say_quiet` throws on a non-boolean, and every call
  site is `catch`-wrapped — so a bad argument would make the **guard** fail
  silently. Only literals are passed.
* `browser_say_quiet_consume` is the one **uncaught** call in `browser_say`, whose
  siblings are both `catch`'d. `BE01` catches deletion, not a rename-with-stub.
* `BE09`/`BE10` pin arms by **source offset**: a correct refactor moving them into
  a helper would red them. Accepted — `BE34` is the behavioural twin.

### Categories that yielded NOTHING (verified, not assumed)
Re-entrancy: `browser_say` has exactly two callers; the `sea*` kinds go through a
different proc with no echo at all; there is **no bare `update`/`vwait`/`tkwait`
anywhere in `wave_viewer.tcl`**, so the armed window never re-enters the event
queue, and `ase.tcl`'s one `catch {update}` sits after all three consumes.
More-than-one-say-per-invocation: impossible, every say is a tail return. Token
identity: `$key` is the `wviewer::windows` key throughout; nothing re-keys.
Namespace declarations: all four `variable sayquiet` present, `forget`'s unset in
the unconditional tail. Fixture masquerades and swallowed throws: none.

## 6. Suites

**Family, run through `run_suites.sh` with `GUI_GATE=1` on `DISPLAY=:0`** (the
files that touch this seam, each re-run whole):

| suite | checks |
| --- | --- |
| `test_wave_sigbrowser_0315` | 28 |
| `test_wave_sigbrowser` (FROZEN) | 353 |
| `test_wave_sigbrowser_i12` | 126 |
| `test_wave_sigbrowser_keys` | 49 |
| `test_wave_sigbrowser_digital` | 82 |
| `test_wave_sigbrowser_panes` | 81 |
| `test_wave_sigbrowser_sea` | 79 |
| `test_wave_sigbrowser_i14` | 109 |
| `test_wave_sigbrowser_2pane` | 108 |
| `test_wave_sigbrowser_i1315` | 191 |
| `test_ase_cosim` | 342 |
| `test_wave_sigsearch` | 233 |

**12/12 runs PASS, 1774 checks** (that run predates the review fixes; the
re-verification after them is recorded below with `test_wave_sigbrowser_0312`
added, since one reviewer saw two of its width legs red under **Xvfb** and could
not attribute it).

**Re-verification after the review fixes**, same runner: `test_wave_sigbrowser_0315`
**28**, `test_wave_sigbrowser_0312` **69**, `test_ase_cosim` **342**,
`test_wave_sigbrowser_i12` **126**, `test_wave_sigbrowser_digital` **82**,
`test_wave_sigbrowser_keys` **49** — **6/6 PASS**.

**The `test_wave_sigbrowser_0312` question, answered.** Lens-A's sweep saw that
file **2 FAILED** (`BF21a`, `BF24a`, both only on the searchbar *width* leg) and
said explicitly it had not diffed against a stashed tree. On `DISPLAY=:0` it is
**ALL PASS (69 checks)**. The reviewer ran under **Xvfb at 1400x1000**; those two
legs are font-metric/geometry arms of issue 0312's wrap rule, and the known
guidance for this tree is to pin the screen size on the Xvfb arm. **Not a
regression, and not left as an open question.**

Display health checked first (`wslg_health.sh`: HEALTHY, 5120x1440, 34 prior
Xwayland fatals recorded). No `make` — this change is Tcl only.

### 6.1 Audit — diff by test NAME and STATUS

`GUI_GATE=1 DISPLAY=:0 bash tests/headless/full_audit.sh`, joined by name against
`doc/claude/batch_F/baseline_status.txt` (baseline `7a592f9c`, 2026-08-09).

Run: `SUMMARY: 288 pass  23 fail  1 crash/timeout  1 skip  (total 313)` /
`WIREEDIT: ALL PASS` / `SCRATCH: 0 leaked dir(s)`. (The baseline lists the 58
wireedit cases as individual rows; this run reports them as one `ALL PASS` block,
so they are absent from the by-name join and are not a diff — same as receipt 16.)

**RED-WARD — four rows. All four re-run standalone. NONE is a regression.**

| test | baseline | this run | standalone re-run | verdict |
| --- | --- | --- | --- | --- |
| `test_hover_highlight` | PASS | FAIL | **PASS** | batched-sweep flake |
| `test_wave_trace_menu` | PASS | FAIL | **PASS (397 checks)** | batched-sweep flake |
| `test_connected_drag_keeps_selection_0113` | PASS | SKIP | **PASS (7 checks)** | X-gated self-SKIP under load |
| `test_wave_sigbrowser_i1315` | PASS | FAIL | NORESULT once, then **PASS (191 checks)** | the named `BP72` / whole-suite-death classes |

None of the four is in an area this change can reach: it touches
`wviewer::browser_say`'s CIW echo and `ase.tcl`'s gesture arming. Hover
highlighting, the trace context menu and connected drag do not call either.

**GREEN-WARD — eight rows, none of them mine either**: `test_ase_persist`,
`test_ase_plot` (TIMEOUT → PASS), `test_fluid_bodyshove_guards_0132`,
`test_rotate_stretch_dangling_0103`, `test_wave_axis_zoom`,
`test_wave_crossdb_trace`, `test_wave_sigbrowser_i12`, `test_wire_vertex_grab` —
the same flake classes settling the other way, plus work landed between the
baseline and now. Recorded, not claimed.

**NEW ROWS — seven** tests exist now that the baseline predates:
`test_wave_sigbrowser_0315` **PASS** (this change), plus
`test_wave_sigbrowser_0312`, `test_raw_read_failure_0306`,
`test_backannotate_digital`, `test_cosim_golden_e2e`, `test_wave_cursor_crossdb`,
`test_wave_sigbrowser_digital` — all PASS.

**Zero attributable regressions.**

## 7. What this does NOT claim

* **Not claimed: the a1/a9 CIW log itself was re-measured.** The end-to-end
  symptom lives in `/tmp/Xschem.log.<N>` after a real Ctrl-Alt-V on
  `/tmp/xschem_eyeball_F/tcl/s4_item5.tcl`, which needs a session, a selection
  and a loaded raw. What is measured is both halves of the seam — the viewer half
  behaviourally on a real browser (`BE2x`), `ase.tcl`'s arming by source position
  (`BE09`/`BE10`) — and `BE26` replays the fall-through **pair** in the order
  `ase.tcl` issues it. **A log deliverable wants an eyeball**, and it is cheap:
  run the fixture, click `a1` then `a9` with Ctrl-Alt-V, read the log.
* **Not claimed: `ase.tcl`'s own two echoes were re-asserted.** They are
  unchanged code; the ruling moved what the *viewer* says, not what the command
  says.
* **Not claimed: ruling (3) has a reachable effect independent of (1).**
  Measured while ruling: on this tree **`src/ase.tcl` is the only product caller
  of either entry point** (grep over `*.tcl`/`*.c`/`*.csv` excluding tests and
  docs). So the issue's premise that a *viewer-side* gesture (tree double-click,
  `Descend to here`) reaches this code is **false today** — those gestures do not
  go through `browser_show_path`. Consequence: with (1) in place the red line the
  issue exhibits is gone because the viewer no longer echoes it at all, and (3)'s
  own guarantee is carried by the arm before the retry plus `BE24`, which pins
  "an armed fall-through produces no red". The unarmed red arm is kept for the
  caller (1) preserves, and `BE22` proves it still fires.
* **Not claimed: the flag survives an exception between arm and consume.** If a
  future early return in either entry point skips `browser_say`, the armed flag
  is consumed by that gesture's *own* tail disarm in `ase.tcl` — so the worst
  case is that gesture reporting one line fewer, not a later one going silent.
  There is no check for that, because there is no such path today (§5 names who
  verified it).
