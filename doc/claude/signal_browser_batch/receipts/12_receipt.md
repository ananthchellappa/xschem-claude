# Item 12 — hierarchy sync: schematic → browser ("Show in Signal Browser") — receipt

**Verdict: `[x]` — DONE** (driver note (a): NOT a pixel item; the tests genuinely
judge it). ⚠ **READ §10.2 FIRST** — the item is green, but the test FILE now
crosses a WSLg threshold and that is a driver decision, not an item-12 defect. Implemented in **Tcl only** — settled decision 8 honoured, no `.c`
file touched. Four sabotages injected, each fired its predicted target **plus a
declared superset** (ruling 23), each reverted, clean re-run green.

**Commit: `35d9e18ff60c9c1ec7212a3232f41004777c2ee1`** (`35d9e18f`) — ONE commit,
**NOT pushed**, subject `feat(ase): Show in Signal Browser, schematic->browser` on
`fluid-editing`. Staged as an explicit file list; no `git add -A`.

**Files touched — 6, from `git show --numstat 35d9e18f` re-run at the ledger
stage and by the verifier, no scope leak and NO `.c` file (settled decision 8
honoured):** `src/wave_viewer.tcl` (+273), `src/ase.tcl` (+92),
`src/cadence_style_rc` (+12), `src/xschem.tcl` (+6),
`tests/headless/test_wave_sigbrowser.tcl` (+782, prefix **BX**), and this receipt
(+437). **1602 insertions, 0 deletions** — every hunk is an append, nothing
existing was rewritten. `src/ase_window.tcl` is **NOT** in the commit (§1's
substitution). `tests/headless/test_wave_grid.tcl` is **NOT** in it either (§1's
last row — the baseline's bump claim is false for this item).

⚠ **§11-§13 below were written by the LEDGER stage, after the commit, and are
therefore not inside `35d9e18f` itself** (the same arrangement as
`11_receipt.md` §12-§14). §1-§10 are the implementer's, as committed.

**FAILED-item triage: not applicable.** The verdict is DONE; nothing is owed to a
human as a failure diagnosis. What IS owed — and it is the reason to read this
receipt at all — is the **two driver actions** in §10.2 and §12.4, neither of
which is an item-12 code defect.

**Test file:** `tests/headless/test_wave_sigbrowser.tcl` (appended, decision 9;
prefix **BX**, which the file header at :22 already reserved).
Checks: **X arm 489** (was 397 after item 11, **+92**); **`--nogui` arm 214**
(was 185, **+29**).

**Non-baseline fails: NONE, in BOTH audits** — §10 for the implementer's
(258/22/4), §12.4 for the verifier's independent one (256/25/3) and the two
off-list names he cleared in isolation. §10.2 + §12.2/§12.4 for the X-death
measurement, §10.4 + §12.2 for the **three** one-check flakes turned up (one the
implementer's own, fixed; `BH54` item 11's; `BT45` item 9's) — all owed to the
driver's FLAKY list, none of them item 12's code.

---

## 1. THE ANCHORS — every one re-verified from source, and TWO SCOUT CITATIONS WERE WRONG

| citation | verified |
|---|---|
| `xschem get sim_sch_path` `src/scheduler.c:4567` | **EXACT** — `else if(!strcmp(argv[2], "sim_sch_path"))`; body reads `sch_path[currsch]+1` then skips `sch_waves_loaded()` dots |
| `wviewer::open` `src/wave_viewer.tcl:747` | **EXACT**, raise-or-open, 0 for an unknown session and 0 headless. Not re-implemented (BX10 guards that) |
| item 11's `hier_split` :6502 / `hier_now` :6550 | **EXACT**. REUSED; no second normaliser was written |
| item 9's `browser_rows` :5836 / `browser_populate` :6129 (`-open 1`) / `browser_refresh` :6093 | **EXACT** |
| item 8's `browser_shown` :6912 / `browser_show` :6935 / `browser_toggle` :6985 | **EXACT**, including `browser_toggle`'s early return when the state already matches |
| `ase::session_for_current` `src/ase.tcl:870` (issue 0168) | **EXACT** — `{key level lib cell view}`, NEAREST ancestor wins |
| `ase::ui::sod_rel_path` :931 / `sod_base_level` :950 | **EXACT**. Read-only; `ase_window.tcl` **NOT modified** |
| the Ctrl-4 family in `src/cadence_style_rc` :221-233 | **EXACT** |
| **PLAN Files: `src/ase_window.tcl` (menu/key on the design window)** | ⚠ **WRONG FILE, and the scout caught it.** The design window's menubar is built in `src/xschem.tcl` — `Launch ASE-L` at **:14933**. `ase_window.tcl:388 ase::ui::build` builds the ASE-L **session** window's menubar. Substituted: `src/ase.tcl` + `src/xschem.tcl` |
| **Baseline: "you are adding a key and a menu item, so you will need to bump `test_wave_grid` GH0 again"** | ⚠ **FALSE FOR ITEM 12, and BX13 pins it.** GH0/GH2 count only `bind WaveViewer …` inside `install_default_binds` and `-accelerator` inside `build_menubar`. Item 12's key is a **schematic** `.drw` bind and its menu entry is on **xschem.tcl's** Tools cascade. Re-read literals: `tests/headless/test_wave_grid.tcl:393-395` = **16 / 11**, and they **MUST STAY**. No `data-seq`/`data-accel` row was added to the guide — one would have broken GH0 and GH2 |

---

## 2. THE FIVE MEASURED FACTS THE ITEM TURNS ON

Every one probed through `gated_xschem.sh` before a line was written, and every
one is asserted by a check so it cannot rot.

| # | fact | where it is pinned |
|---|---|---|
| F1 | **`$tv see $id` IS THE EXPANSION** — ttk sets every ancestor `-open 1` and then scrolls. Measured: `open(g:x1)` 0 → 1 across one `see` | BX31, BX42 (SECOND INVOKE) |
| F2 | `browser_populate` inserts **every** row `-open 1` (`wave_viewer.tcl:6133`) and clears the selection, so a repopulate erases exactly the evidence this item's visibility claim needs | BX42's two-invoke shape, §5(a) |
| F3 | `bbox` is empty for **collapsed**, **scrolled-off** and **never-mapped** alike, and a once-mapped-then-**withdrawn** tree still answers `bbox` — only an explicit parent walk plus `winfo ismapped` tells them apart | `bx_vis`, BX33 (ORACLE) |
| F4 | `see`/`selection set`/`bbox` **throw** `Item … not found`; **`$tv exists {}` is TRUE** (the root) | BX33 ×2 |
| F5 | `wviewer::open` **and** the sidebar-show path leave the xschem context **on the viewer** | BX42 (DECLARED), BX10's ordering guard |

---

## 3. WHAT SHIPPED

### `src/wave_viewer.tcl` — the viewer half

| proc | role |
|---|---|
| `browser_node_for {rows segs}` | **PURE.** segs → `{<deepest group id> <segments matched>}`. ONE call answers both "is this the node?" and "what is the deepest ancestor?", so the exact hit and the fallback cannot disagree. **Exact wins within a level, `-nocase` is the fallback** (item 11's `hier_resolve` rule one layer over). **Groups only** — a leaf is a signal, not an instance |
| `browser_origin_drop {level rawlevel}` | **PURE.** How many leading `hier_now` segments to drop to reach the browser's origin. A **negative** answer (raw read *below* the session's design) is the caller's refusal |
| `browser_reveal {token id}` | select → focus → `update idletasks` → **`see`** → open the target. 1/0, never throws. **No expand-ancestors loop** — `see` is the expansion (F1); a loop would be dead code no sabotage could reach |
| `browser_show_path {token path}` | **THE COMMAND's viewer half.** `{ok id landed}` / `{partial id landed asked}` / `{root {}}` / `{err reason}`. Never throws. Speaks on every branch |
| `browser_bars_active {token}` | 1 when either searchbar carries a pattern — the "may be hiding it" clause |
| `browser_msg {res}` | **PURE.** result → sentence. ONE formatter for the status line, the CIW echo and the ASE-side echo, so the three cannot drift |
| `browser_say {token kind …}` | build the result, then say it on both viewer surfaces |

### `src/ase.tcl` — `ase::show_in_browser_for_current {{win {}}}`

Returns the session key or `{}`. Order is load-bearing and commented as such:
context switch **verified by readback** → `session_for_current` (0168) →
**PIVOT read BEFORE the viewer is touched** (F5) → origin drop → `wviewer::open`
→ sidebar un-hide → `browser_show_path` → echo **the same sentence** the sidebar
shows.

### Entry points

* **Menu:** `src/xschem.tcl:14934`, immediately after `Launch ASE-L`:
  `-label "Show in Signal Browser" -accelerator Ctrl+5 -command "ase::show_in_browser_for_current ${topwin}.drw"`.
  Every test that touches that cascade indexes it **by label**
  (`test_ase_launch`, `test_lib_manager_launch`, `test_nh_editor_discover`,
  `test_create_instance`), so inserting there is safe. BX44 invokes it for real.
* **Key:** `src/cadence_style_rc`, next to the Ctrl-4 family:
  `bind .drw <Control-Key-5> {ase::show_in_browser_for_current %W; break}`.
  Cloned to detached windows by `clone_canvas_bindings` for free.

**THE WRITTEN THREE-PATH COLLISION CHECK, run and recorded:**
* **p1 — the C dispatcher.** `src/keybindings.csv` has **no row for keysym 53**
  (67 rows, `grep ,53,` empty). The only Ctrl-5 behaviour is
  `callback.c:5975 case '5'` → under `ControlMask` "choose layer 5" — the **same
  arm Ctrl-4 already overrides** at `cadence_style_rc:221`, so the cost is one
  this file has already accepted and the family reads Ctrl-4 / Ctrl-Shift-4 / Ctrl-5.
* **p2 — existing Tcl binds.** `grep -rn "Control-Key-5" src/*.tcl src/cadence_style_rc`
  → **zero** hits before this change, **exactly one** after (BX11's second leg).
* **p3 — the `break`.** Present, like every other line in that block (BX11).

---

## 4. THE DRIVER'S SIX NOTES, ANSWERED

**(b) — item 11's five plan defects.** All five bear on item 12 and all five were
honoured: the trailing dot is `hier_split`'s (REUSED, not rewritten); the case
collision is real one layer over and is `browser_node_for`'s exact-first +
`-nocase` (sabotage (d) proves it); every world claim is a READBACK; and
**decision 10's pivot choice is NOT claimed as behaviourally proven** (§7).

**(c) — the vacuous-check trap.** Three positive controls come **first** and are
named as such: **BX30** (collapsed → visible on the good path, on the same
fixture), **BX32** (offscreen → visible), **BX40** (sidebar `browser_shown` 0
**AND** absent from `pack info` **AND** `winfo exists` 1 — three values, because
"hidden" and "never built" are different defects). **BX34** asserts the selection
is `{}` before claiming the fallback moved it. And the discipline paid: see §5(a)
— **running** sabotage (a) proved BX42's first visibility leg VACUOUS, and the
check was strengthened rather than the result renamed.

**(d) — verify what the oracle measures.** `bx_vis` is **seven-valued**:
`no-tree` | `root` | `absent` | `collapsed` | `unmapped` | `offscreen` |
`visible`. Each is produced by the fixture at least once, `unmapped` included
(BX33 (ORACLE) withdraws the toplevel and asserts that **bbox still answers**,
which is why `ismapped` is checked first). `selection` alone never stands in for
visibility anywhere in the block.

**(e) — consume, do not re-implement.** `wviewer::open`, `hier_split`,
`hier_now`, item 8's show/hide, item 9's `browser_rows`/`browser_populate` are
all consumed unchanged. **Item 9's D6 was decided deliberately, not inherited
silently** — see §6.

**(f) — the 0168 precedent.** The two **AGREE**, asserted as a value, not
assumed: **BX49** compares `ase::ui::sod_rel_path $level` against
`[join [lrange $segs $level end] .].` at level 0 (`X1.X2.`) **and** level 1
(`X2.`) and requires byte equality. ⚠ It is a **test-only** oracle: the shipped
path never calls `sod_rel_path`, because that proc reads `sch_path`, which
decision 10 forbids this batch. BX09 is what keeps the shipped bodies clean.

**(g) — file conventions.** Inherited whole: `pcall`, the `::bgerror` override,
`wvproc_body`, `bs_packed`, `bs_order`, `bs_wait_mapped`, `send_key`,
`viewer_ready`, the arm blocking (01-19 both arms, 20-39 throwaway toplevel,
40-59 real viewer) and the `SKIPPED: <group> (Tk/X arm only)` banner wording.

**(h) — issue 0212.** Not hit. Item 12 matches raw-derived paths against tree
node ids; it never feeds a path back to `descend -inst`, so the vector-slice
limitation does not arise in this direction. No duplicate filed.

---

## 5. SABOTAGES — 4, one SUBSTITUTED and one ADDED, all declared (ruling 23)

A pristine post-implementation copy of all five files was kept in the scratchpad
**before the first injection**; every injection was `diff`ed against it and
reverted by `cp` (a `git checkout --` would have discarded the whole then-
uncommitted item). Every injection was followed by a clean re-run: **489 / 0**
under X and **214 / 0** under `--nogui`.

| # | injection | predicted | **observed** |
|---|---|---|---|
| **(a) SUBSTITUTED** | delete `if {[catch {$tv see $id}]} { set ok 0 }` from `browser_reveal` | the visibility checks only | **X: 3** — BX31 (`collapsed`, not `visible`), BX32 (`offscreen`), BX42 (SECOND INVOKE). Every **selection** leg stayed GREEN — the built-in positive control that excludes "the command did nothing". `--nogui` untouched (214/214), correct: it is an X-only claim |
| **(b)** | `browser_node_for`: `if {$hit eq {}} { break }` → `return [list {} 0]`, i.e. delete the deepest-ancestor fallback | BX04, BX34, the BX42/BX48 fallback legs | **X: 8** — BX04 ×2, BX07 (leaf leg), BX34 ×2, BX37 (partial sentence), BX42 (SECOND INVOKE), BX50 (D6 snapshot control). `--nogui`: **3** (BX04 ×2, BX07). A superset, every member a genuine fallback check |
| **(c)** | delete the `browser_toggle 1` un-hide from `ase::show_in_browser_for_current` | BX42's shown leg only | **X: 8** — BX42 (SIDEBAR / VISIBLE / DECLARED / SECOND INVOKE), BX44, BX45, BX46, BX43. BX40 proves the sidebar was hidden **first**, so none of these is "it did nothing". `--nogui` untouched |
| **(d) ADDED** | delete the `-nocase` candidate line from `browser_node_for` | BX02 + BX42's selection leg | **X: 6** — BX02, BX04, BX42 (SELECTION), BX42 (status line), BX42 (SECOND INVOKE), BX43. `--nogui`: **2** (BX02, BX04). **BX03 (exact-first) stayed GREEN** — the control that says exact matching still works |

### 5.1 SUBSTITUTION (a), declared

The PLAN's "select the node without expanding ancestors" **is not a state this
implementation can be put into by deletion**: `see` IS the expansion (F1) and
`browser_populate` opens everything anyway (F2). An explicit expand loop would
have been dead code. The injection that carries the real load is deleting `see`.

### 5.2 ⚠ RUNNING SABOTAGE (a) FOUND A VACUOUS CHECK — THE BATCH'S OWN LESSON, AGAIN

The first cut of **BX42 (VISIBLE)** stayed **GREEN** under sabotage (a). Reason,
measured not reasoned: the command's first invoke **un-hides** the sidebar,
`browser_show` repopulates, and `browser_populate` inserts every group `-open 1`
— so the node is visible whether or not anything expanded it. The check was
**strengthened**, not renamed: a **second** invoke now runs with the sidebar
already shown and `g:x1` deliberately collapsed (with a POSITIVE CONTROL
asserting `collapsed` first). That new leg fires under (a), (b), (c) **and** (d).
Found by running the sabotage, exactly as driver note (c) instructs.

### 5.3 ⚠ THE PLAN'S SABOTAGE (b) AS FIRST WRITTEN FIRED THE WRONG THING

Deleting only the `partial` **return arm** (report `err` instead) fired just
**BX34's first leg and BX37** — because `browser_reveal` runs *before* the
branch, so the ancestor was still selected. That injection tests the *reporting*,
not the fallback. It was discarded and replaced by the `browser_node_for`
injection above, which removes the fallback itself. Recorded rather than
quietly relabelled.

### 5.4 WHAT SABOTAGE (c) INCIDENTALLY MEASURED

BX42's **DECLARED context** leg failed under (c), which pins the mechanism
honestly: when the viewer is **already open**, `wviewer::open` only raises and
does not move the C context — it is the **sidebar-show path** (its 0173 context
loan through `signal_list`) that leaves the context on the viewer. Both routes
end in the same place, which is why the declared rule holds; but the *cause* is
the sidebar show, not `open`, and this receipt says so rather than implying
`open` does it.

---

## 6. DECIDED DELIBERATELY — item 9's D6, and the defect the decision exposed

**D6: the browser inventory is a SNAPSHOT taken when the sidebar is SHOWN.**
Item 12's decision: **reload ONLY on a miss.** A hit never reloads, because a
repopulate re-opens every group and clears the selection — it would erase the
user's collapse state and make this item's own visibility claim untestable
(BX50's control asserts a HIT leaves the row snapshot **byte-identical**; BX50's
positive leg adds a signal behind the browser's back and proves a MISS finds it).

⚠ **AND THE PROBE FOUND A REAL DEFECT IN THAT RETRY.** `browser_reload` sets the
inventory to whatever `signal_list` answered — and a read that *fails* answers
with **nothing**, so a bare retry replaces a good tree with an **empty** one.
Observed: the first cut turned BX34's `partial` into an `err` and emptied the
widget. Fixed with **IMPROVE-OR-RESTORE**: the reload's result is kept only when
it matches **more** of the path; otherwise `browsersigs`, `browserrows`, the
widget **and the selection** are put back exactly as they were. **BX39** is the
check, and it is real on that fixture precisely because there is no xschem raw
behind it.

---

## 7. DECLARED LIMITS

* **GROUPS ONLY.** A leaf row is a signal, not an instance; `v(x1.out)` must not
  make `out` look descendable (BX07, both legs).
* **AN ACTIVE SEARCH/FILTER CAN HIDE THE NODE.** Reported — the message names
  the bars — but the bars are **NOT cleared** behind the user's back (BX38, with
  an empty-bars control that asserts the clause is *absent*).
* **THE SELECTION IS LEFT ALONE ON AN OUTRIGHT MISS** (decision 11's mirror:
  leave the user where they were and say so). BX35's third leg.
* **THE CONTEXT IS LEFT ON THE VIEWER** — the exact mirror of item 11 leaving it
  on the design window, and consistent with the raise. Asserted (BX42 DECLARED),
  not accidental. §5.4 names the actual mechanism.
* ⚠ **ITEM 12 IS STRICTLY MORE CAPABLE THAN ITEM 11 IN THE ANCESTOR CASE, AND
  THAT IS A DIVERGENCE WORTH NAMING.** Item 11's `hier_origin_ok` **REFUSES**
  when the design window is opened on an ancestor of the session's design
  (`sod_base_level != 0`). Item 12 instead **MAPS** it, by dropping `level`
  segments — which BX48 proves works and BX49 proves agrees with 0168's own
  `sod_rel_path`. So the two directions do **not** fully agree: browser→schematic
  refuses a case that schematic→browser handles. Said plainly, per driver note
  (f); closing the asymmetry would mean changing item 11, which is out of scope.
* **A RAW READ BELOW THE SESSION'S DESIGN IS REFUSED**, not guessed at — the
  negative-drop arm (BX48's last leg).
* **NO `data-seq` GUIDE ROW AND NO `test_wave_grid` BUMP** — §1's last row.

---

## 8. WHAT THIS ITEM DOES **NOT** CLAIM (ruling 17: narrow the claim)

**Settled decision 10's PIVOT CHOICE is not behaviourally proven here**, for the
same reason item 11 could not prove it: in the DESIGN window no raw is loaded,
`sch_waves_loaded()` is −1, and `sim_sch_path` degrades to `sch_path` minus its
leading dot **byte for byte** — so swapping the getter fires nothing. What IS
proven is:

* the **origin mapping** behaviourally (**BX48**: one hierarchy position, two
  session levels, two *different* browser paths — `X1.X2` at level 0, `X2` at
  level 1 — plus the raw-at-the-session's-own-level and negative-drop arms); and
* a **source guard** that the shipped bodies contain **zero** `sch_path` reads
  (**BX09**, three bodies).

Stated rather than dressed up as a behavioural proof.

---

## 9. GROUPS AND ARMS

| block | arm | what |
|---|---|---|
| BX01-BX08 | **both** | the two PURE procs: exact, `-nocase`, exact-first, the fallback, leaves, the origin arithmetic |
| BX09-BX14 | **both** | the source guards (decision 10, the pivot/open ORDER, the rc line, the Tools entry, the GH0 non-bump) and `browser_msg`'s four sentences |
| BX20, BX30-BX39 | X | the REVEAL on a throwaway toplevel: collapsed→visible, offscreen→visible, missing/empty ids, the fallback, the four status strings, the bar clause, improve-or-restore, and the `unmapped` oracle value |
| BX40-BX50 | X | END TO END on a REAL viewer + a REAL design window + the wvhier fixture: the un-hide, the selection, visibility on a collapsed tree, the REAL Tools entry, a REAL `<Control-Key-5>` with a negative control, the sim-root branch, the no-raw report, the no-session refusal, the 0168 agreement, the origin mapping, and reload-on-miss |

### 9.1 Two measured harness facts, recorded so nobody re-derives them

* **The design window must be NAMED, not inherited.** Item 11's BH5x block closes
  its viewer last, so `current_win_path` on arrival can point at a window that no
  longer exists — the first cut of BX40 read `.x1` and self-skipped the entire
  group. `bx_dwin` is `.drw` (the window BH20's `xschem load` used).
* **Every context switch is DRAINED, RETRIED and RE-READ** (`bx_ctx_to`). An
  `update` between a raise and a context read can deliver an Enter/FocusIn on
  another canvas that switches the context straight back; measured, and it
  produced a whole-group self-skip. BX42's DECLARED leg reads
  `current_win_path` with **no event pump in between** for the same reason.
* **BX48 is measured by SPY, deliberately.** Its claim is exactly "which PATH
  does the command compute", and opening a second real viewer toplevel added
  only WSLg fragility (the first cut self-skipped when the mid session's window
  would not map). BX42 already proves the whole chain end to end; BX48 isolates
  the arithmetic and runs **both** levels from the **same** hierarchy position,
  so the two answers are a discriminator rather than one value in a vacuum.

---

## 10. THE AUDIT

`tests/headless/full_audit.sh`, run start to finish:
**258 pass / 22 fail / 0 crash / 0 timeout / 4 skip (284 classified).**

**NON-BASELINE FAILS: NONE.** Sets compared, not counts. The 22 are:

* **the 16 HARD baseline names, all present** — `test_ase_log_seam_0207`,
  `test_ase_window`, `test_cadence_drag`, `test_ciw`, `test_fluid_editing`,
  `test_gf180mcud_libmgr`, `test_ihp_sg13g2_libmgr`, `test_lib_manager_gui`,
  `test_lib_manager_locate`, `test_lib_sweep`, `test_phase3_mints`,
  `test_reopen_readonly`, `test_rotate_stretch_short_0104`, `test_select_at`,
  `test_selflog_output`, `test_sky130a_libmgr`;
* **4 documented FLAKY names** — `test_ase_unnamed_net`, `test_palette`,
  `test_wave_trace_menu`, `test_wire_vertex_grab`;
* **2 X-DEATH CASUALTIES, each attributed to the exact line the X server died on
  and each CLEARED by an isolated re-run** — `test_wave_sigsearch`
  (`ALL PASS (194 checks)` in isolation, twice) and `test_wave_sigbrowser`
  (`ALL PASS (489 checks)` in isolation; see §10.2 for the full tally).

The four action-log names the baseline flags as reachable from this item
(`test_select_at`, `test_selflog_output`, `test_phase3_mints`,
`test_ase_log_seam_0207`) all failed and are all on the HARD list. Item 12 adds
**no new C emission**; its only action-log line is item 8's own
`wviewer::browser_toggle 1 <token>`, emitted by an existing proc.

### 10.1 The environment during this item

⚠ **WSLg's Xwayland aborted more than a dozen times during this item** —
`Fatal server error: request could not be marshaled: can't send file descriptor`
in `/mnt/wslg/stderr.log`, plus the client-side `X connection to :0 broken` and
its second face `XIO:  fatal IO error 0 (Success)`. This is the documented
`wslg-xwayland-aborts` mode. **Every log was grepped for BOTH strings before it
was interpreted**, per the standing rule, and any run containing one was
discarded and re-run rather than read.

⚠ **The GUI gate was waited out, not bypassed.** One request sat unanswered for
**67 minutes**; `GUI_GATE=0` was never set and no gate file was hand-written.
Every X run went through `gated_xschem.sh` or `run_suites.sh`; no bare loop.

### 10.2 ⚠⚠ THE FILE NOW CROSSES A WSLg THRESHOLD — THE MOST IMPORTANT FINDING IN THIS RECEIPT, AND IT IS FOR THE DRIVER

**The item's 92 checks never fail. The PROCESS gets killed.** Across every single
run in which the X server aborted — thirteen of them — `grep -c '^FAIL: BX'`
returned **ZERO**. The file simply stops mid-stream with
`X connection to :0 broken` or `XIO:  fatal IO error`.

**MEASURED, with the ordering confound removed and both halves probed in
isolation:**

| experiment | result |
|---|---|
| item 11's file (397 checks) at `b81ee0c9`, run back-to-back in the same window | **6/6 CLEAN** |
| item 12's file (489 checks) in the *same* window | **0/6**, then 1/8, then 1/5, then 1/6 |
| A/B, order A(11)→B(12) ×4 | 1/4 vs **4/4** — but **THE ORDER IS A CONFOUND** |
| A/B, order B(12)→A(11) ×4 | 2/4 vs 1/4 — reversing it alone **halved** the rate |
| item 12's **BX4x workload alone**, amplified ×12 in a standalone probe | **3/3 CLEAN** |
| item 12's **BX2x workload alone**, amplified ×10 in a standalone probe | **3/3 CLEAN** |
| the file with BX4x disabled / with BX2x disabled | 1/3 and 2/3 deaths — **neither half is the trigger** |
| `wm withdraw` replaced by `pack forget` for 4 runs | **exonerated**, rate unmoved |
| a 90 s cooldown between runs | **no effect** |

**So nothing in item 12 is X-hostile.** Both halves survive an order of magnitude
more of their own work than the test does. What kills the process is the
**CUMULATIVE** X footprint of the whole file within one xschem process, and item
12 is what pushes it over the edge: the file now creates **six** toplevels in one
process (item 9's `.wvbt1`, item 10's `.wvbm1`, item 8's viewer, item 11's
viewer, item 12's `.wvbx1`, item 12's viewer) where before it created four.
`/mnt/wslg/stderr.log` carries **79** `Fatal server error: request could not be
marshaled: can't send file descriptor` entries for this session.

**ONE REAL DEFECT WAS FOUND AND FIXED WHILE CHASING THIS**, and it is worth
keeping regardless: `bx_ctx_to` called `update` unconditionally on every one of
its ~25 sites, and each `update` redraws BOTH canvases. One run died reporting
`after 68129 requests`. The fast path now pumps no events at all (the switch is
synchronous, so `current_win_path` is already true on return), and `bx_vis_m`'s
map wait is bounded at 2 s instead of `bs_wait_mapped`'s 15 s default.
**Measured: 32 s → 5.9 s per run.** It did not cure the aborts — which is itself
evidence that raw request count is not the mechanism — but it is a 5× reduction
in exposure and strictly better.

⚠⚠ **ACTION FOR THE DRIVER, BEFORE ITEM 13:**
1. **The environment needs `wsl --shutdown`** (the user's own
   `wslg-xwayland-aborts` note records that as the cure). Every measurement in
   this receipt was taken on a machine that logged 79 fatal X server errors.
   **Re-measure item 12's file on a fresh compositor before drawing conclusions
   from the rate above.**
2. **SETTLED DECISION 9 ("two test files, not seventeen") NEEDS REVISITING.**
   `test_wave_sigbrowser.tcl` is at 489 X-arm checks with three more items still
   to append. It is already past what this environment sustains; items 13-15 will
   make it worse monotonically. Splitting the X-arm groups into a second file
   would cost nothing analytically and would put every group back inside the
   envelope. That is a DRIVER decision, not an implementer one, which is why it
   is raised rather than taken.

### 10.3 THE ORDERING CONFOUND, recorded because it nearly produced a false conclusion

The item's file is 23% longer than item 11's (489 checks vs 397) and opens one
additional real viewer toplevel, so it is a bigger X-server target. An
interleaved A/B was run to find out how much bigger. **The first one was run
A-then-B four times and scored item 11 1/4 versus item 12 4/4 — which looks
damning and is not, because the ORDER IS A CONFOUND: the server degrades
monotonically, so whichever file runs SECOND is more likely to die.** Re-run
B-then-A:

| order | item 11 (397) | item 12 (489) |
|---|---|---|
| A(11) then B(12) | 1/4 | **4/4** |
| B(12) then A(11) | 1/4 | **2/4** |

Reversing the order alone halved it. Two corroborating facts point the same way:
**2 of 4 deaths in one sweep landed inside item 10's `BM` block — before a single
line of item-12 code runs** — and unrelated shorter suites (`test_wave_grid` 250,
`test_wave_tabs` 174, `test_ase_launch` 38) were clean throughout.

**Across the whole item the file ran clean — `ALL PASS (489 checks)` — twelve
separate times**, and every failing run carried an X death with **zero** `BX`
failures. ⚠ **LEDGER-STAGE QUALIFIER, added after the verifier measured it
independently: the `ALL PASS` half of that sentence did NOT reproduce.** The
verifier completed the file **once in twelve attempts**, and that one completion
scored **488 pass / 1 FAIL** — the failure being `BT45`, item 9's geometry leg,
which executes before a single line of `BX` code. Read the claim as **"no `BX`
check ever failed"**, which is what both stages could confirm; §12.2.
§10.2 is where the conclusion lives; this section exists so nobody
repeats the confounded A/B and concludes from `4/4 vs 1/4` that item 12's code
is at fault.

### 10.4 TWO ONE-CHECK FLAKES FOUND, ONE OF THEM MINE AND NOW FIXED

* ⚠ **MINE: `BX42 (SECOND INVOKE)` read `unmapped`, 1 run in 4.** A freshly
  raised viewer can report `winfo ismapped` 0 for a few milliseconds, so the
  oracle answered `unmapped` for a node that was visible a moment later.
  **FIXED by `bx_vis_m`, which polls the PRECONDITION (the mapping) and then asks
  the oracle once** — item 5's rule; the asserted value is never polled, and a
  genuinely unmapped widget still reads `unmapped` after the budget. The
  throwaway-toplevel group keeps the RAW `bx_vis`, because BX33's whole purpose
  is to observe `unmapped` deliberately. **Sabotage (a) was re-run afterwards and
  still fires exactly its 3 targets — and BX42 now reports `collapsed`, the real
  defect, instead of `unmapped`. The oracle got sharper, not blunter.**
* ⚠ **NOT MINE, and it reproduces with item 12 entirely absent:
  `test_wave_sigbrowser`'s `BH54 ...and it still raised the design window`
  (`winfo ismapped .`) failed 1 run in 4 running ITEM 11's file** at
  `b81ee0c9`. This is the un-named ~20% one-check flap item 11's verifier
  recorded in §13.4 of `11_receipt.md` but could not identify (his run was piped
  to `tail`). **ACTION FOR THE DRIVER: it is `BH54`, and it belongs on the FLAKY
  list.** `BH50`'s two checks flap the same way, but only ever in runs that also
  carried an X death (2 of 11 runs; green in all 9 clean ones).

---

## 11. SABOTAGE TABLE — ledger form (`failedExactly` / `reverted` per row)

**Seven injections in total**: the implementer's four (§5) — one of them
SUBSTITUTED and one ADDED, both declared under ruling 23 — plus the verifier's
**two own unnamed** ones and his reproduction of (a) (§12.3). Every one was
reverted and followed by a clean re-run.

**Revert method.** The implementer worked against a then-uncommitted item, so a
`git checkout --` would have discarded the whole item: a pristine copy of all
five files was taken in the scratchpad **before the first injection**, every
injection was `diff`ed against it, and the revert was a `cp` back plus a `diff`
to zero. The verifier, working against the committed tree, used
`git checkout -- <file>` — but only after `git diff` confirmed the file held
**nothing but the injection** — and confirmed `git diff --name-only -- src/ tests/`
empty at exit.

| # | origin | injection | predicted targets | observed | `failedExactly` | `reverted` |
|---|---|---|---|---|---|---|
| (a) | PLAN, **SUBSTITUTED** (§5.1, ruling 23) | delete `if {[catch {$tv see $id}]} { set ok 0 }` from `browser_reveal` | the visibility checks only | X arm **3**: BX31 (`collapsed`, not `visible`), BX32 (`offscreen`), BX42 (SECOND INVOKE). **Every selection leg stayed GREEN** — the built-in control excluding "the command did nothing". `--nogui` untouched at **214/214**, correct for an X-only claim | **yes** | **yes** |
| (b) | PLAN, **REPHRASED** (§5.3) | `browser_node_for`: `if {$hit eq {}} { break }` → `return [list {} 0]`, i.e. delete the deepest-ancestor fallback | BX04, BX34, the BX42/BX48 fallback legs | X arm **8**: BX04 ×2, BX07 (leaf leg), BX34 ×2, BX37 (partial sentence), BX42 (SECOND INVOKE), BX50 (D6 snapshot control). `--nogui` **3**: BX04 ×2, BX07. A **declared superset**, every member a genuine fallback check | **yes** (superset declared) | **yes** |
| (c) | PLAN | delete the `browser_toggle 1` un-hide from `ase::show_in_browser_for_current` | BX42's shown leg only | X arm **8**: BX42 (SIDEBAR / VISIBLE / DECLARED / SECOND INVOKE), BX43, BX44, BX45, BX46. BX40 asserts `browser_shown` 0 **AND** absent from `pack info` **AND** `winfo exists` 1 **before** the command, so none of these can be "it did nothing". `--nogui` untouched | **yes** (superset declared) | **yes** |
| (d) | **ADDED** by the implementer (§5, ruling 23) | delete the `-nocase` candidate line from `browser_node_for` | BX02 + BX42's selection leg | X arm **6**: BX02, BX04, BX42 (SELECTION), BX42 (status line), BX42 (SECOND INVOKE), BX43. `--nogui` **2**: BX02, BX04. **BX03 (exact-first) stayed GREEN** — the control proving exact matching still works | **yes** (superset declared) | **yes** |
| (v1) | **VERIFIER, UNNAMED** (§12.3) | `browser_show_path`'s IMPROVE-OR-RESTORE → unconditional accept (`if {1}`) — i.e. keep whatever the miss-retry reload answered | undeclared to the implementer; aimed at §6's late-found defect | **10**: BX39 **both legs**, BX34 **both legs**, BX35 (selection-survives), BX37, BX38 and the rest of the restore family | **yes** | **yes** |
| (v2) | **VERIFIER, UNNAMED** (§12.3) | `browser_origin_drop` → always `0` | undeclared; aimed at the 0168 origin arithmetic | BX08 ×2 **in BOTH arms**, plus BX48 (ORIGIN) and BX48 (NEGATIVE DROP) **behaviourally** — so the arithmetic is pinned by more than its own unit test | **yes** | **yes** |
| (a′) | **VERIFIER, reproduction of (a)** | as row (a) | reproduce the implementer's claim | **exactly 3**, all visibility (BX31, BX32, BX42 SECOND INVOKE); every selection leg green — **the implementer's row (a) reproduced byte for byte** | **yes** | **yes** |

**Two things this table is deliberately not hiding.** Row (a) is a
**substitution**, not the PLAN's sabotage, because the PLAN's state is
unreachable by deletion (§5.1). Rows (b)/(c)/(d) fired **more** than predicted;
each superset is enumerated above and every member is a real check of the
injected mechanism, which is the ruling-23 bar — not "exactly one check" for its
own sake.

---

## 12. VERIFIER STAGE — `ok: true`, `scopeClean: true`

Everything in this section was **re-run by the verifier in a fresh context**, not
read off §1-§10.

### 12.1 Re-runs that reproduced the claims

| what | result |
|---|---|
| `git show --stat / --name-only 35d9e18f` | **6 files, 0 `.c` files**, `ase_window.tcl` NOT touched — the substitution is real and declared |
| `git status --porcelain` | only `doc/claude` batch bookkeeping dirty; **`src/` and `tests/` clean** before and after every injection |
| `--nogui` arm | **214 passed / 0 failed** — matches the +29 claim exactly |
| the anchors, re-read from source | `scheduler.c` `sim_sch_path` body (reads `sch_path[currsch]+1`, skips `sch_waves_loaded()` levels); `callback.c:5975 case '5'`; `keybindings.csv` has **no keysym-53 row**; `grep -rn Control-Key-5 src/` = **exactly one** line, in `cadence_style_rc`; `xschem.tcl:14933 Launch ASE-L` with the new entry immediately after; `ase_window.tcl` builds the **session** window (PLAN's file list wrong, divergence justified); `test_wave_grid` GH0/GH2 scope to `install_default_binds` / `build_menubar`, so **16/11 correctly stay** and the baseline's bump claim is **FALSE**; `ase::ui::sod_rel_path` reads `sch_path`, so **BX49 is correctly declared a test-only oracle**; `ase::session_for_current` returns `{key level lib cell view}`; `xschem raw loaded` returns **−1** with no raw |
| the whole BX block (lines 2989-3760) read line by line hunting tautologies | **none found.** The source-regex legs (BX09-BX13) are **declared** guards; BX48/BX49 pin computed values against literals; BX50's snapshot control uses `browser_node_for` as its own oracle **but is paired with an independent behavioural leg** |
| every other test that touches `.menubar.tools` (`test_ase_launch`, `test_lib_manager_launch`, `test_nh_editor_discover`, `test_create_instance`) | all index **BY LABEL**, so the inserted Tools entry is safe; `test_palette` asserts no counts |
| a **BX-isolating probe copy** (BT/BM/BH-X groups gated off, 334 checks incl. all 92 BX) ×3 | 2 completions, **0 fails**; BX43's real `Ctrl-5` **was delivered** (no self-skip) |

### 12.2 ⚠ THE X-ARM "489/0" NUMBER IS NOT ROUTINELY REPRODUCIBLE

The verifier could complete the shipped file under X **1 run in 12**
(`gated_xschem.sh` ×7, then `run_suites.sh -n 5`). **`grep '^FAIL: BX'` returned
ZERO in all twelve.** The single completion scored **488 pass / 1 FAIL**, and the
failure is **`BT45`** — *"the sidebar is narrower than the canvas on a real
viewer"*, **item 9's geometry leg**.

`BT45` is **not attributable to item 12**, on three independent grounds recorded
by the verifier: it **executes before any BX code runs**; item 12 **adds no viewer
widget and touches no geometry**; and the **same `src/` is under both arms of the
A/B** below. It flapped in **2 of the verifier's 9 HEAD runs that reached it** and
**0 of 8 item-11-version runs** — a newly observed WSLg layout-timing flake for
the FLAKY list, not a regression. §10.3 now carries the qualifier.

### 12.3 The verifier's own UNNAMED sabotages — and their outcomes

Rows **(v1)** and **(v2)** in §11, both undeclared to the implementer, both aimed
at the parts of the item the implementer had most reason to be proud of.

* **(v1) — kill IMPROVE-OR-RESTORE** (`browser_show_path`, unconditional accept).
  **10 checks fired**, including **both** BX39 legs, **both** BX34 legs, BX35's
  selection-survives leg, BX37 and BX38. The defect the implementer found by
  probe (§6) is therefore **genuinely pinned**, not merely described in prose.
* **(v2) — `browser_origin_drop` → always 0.** Fired **BX08 ×2 in BOTH arms** and
  — the point of the probe — **BX48 (ORIGIN) and BX48 (NEGATIVE DROP)
  behaviourally**. The 0168 origin arithmetic is not resting on its own unit test.
* **(a′) — reproduction of the substituted sabotage (a).** Exactly **3** fails,
  all visibility, every selection leg green. The implementer's row (a) reproduced.

All three reverted with `git checkout --` after confirming the file held only the
injection; `src/` diff empty at exit; both probe copies deleted, no scratch dirs
leaked.

### 12.4 ⚠⚠ THE VERIFIER'S ADVISORY — the environment has degraded FURTHER, and only the driver can act

**This is an advisory, not an item-12 code defect** — but it is the reason the
verifier's `problems` array is non-empty on an `ok: true` verdict.

| measurement | implementer | verifier |
|---|---|---|
| shipped file (489 checks) completes under X | ~1 in 6 | **1 in 12** |
| `BX` failures across every aborted run | **0** | **0** |
| the SAME file at `b81ee0c9` (397 checks), same window | 6/6 clean | **8/8 clean, 0 X deaths** (3 runs flapping `BH50` only) |
| BX-only probe (334 checks) | halves 3/3 clean amplified 10-12× | **2/3 complete, 0 fails** |
| `/mnt/wslg/stderr.log` marshalling fatals this session | 79 | **102** |

The A/B is **ruling-22 shape**: same window, same `src/`, only the test file
version differs. **§10.2's finding is CONFIRMED independently and is if anything
understated.** The consequence the driver must own: *from now on
`test_wave_sigbrowser` will report FAIL in nearly every audit, and item 12's X-arm
claims are not routinely re-verifiable.* **Settled decision 9 ("two test files,
not seventeen") is what forces the append, so only the driver can fix it.**

**The full audit, run start to finish by the verifier: 256 pass / 25 fail /
0 crash / 3 skip (284).** Sets compared, not counts (the baseline says the totals
are not reproducible). The fail set diffed against the **16 HARD names** + the
**FLAKY list**; **3 X deaths** attributed by line to `test_ase_persist`,
`test_wave_sigbrowser` (died after **BX44**, with **zero BX fails**) and
`test_wave_sigsearch`. The two names he could not attribute to the baseline were
each cleared in isolation through `run_suites.sh`:

* **`test_prop_form_field_width_0170` — on NEITHER the HARD nor the FLAKY list.**
  Failed the audit (`pinned to 1px (precondition) -> {921} (exp {1})`), then
  **3/3 `ALL PASS` (12 checks)** in isolation. **ACTION: FLAKY list.**
* `test_wave_sigsearch` — failed the audit on an X death, **2/2 `ALL PASS`
  (194 checks)** in isolation, exactly as §10 says.

**`nonBaselineFails` therefore stands EMPTY in BOTH audits** — the implementer's
258/22/4 and the verifier's 256/25/3 reconcile to the same set. **Three names are
owed to the FLAKY list before item 13: `BH54` (item 11's, §10.4), `BT45`
(item 9's, §12.2) and `test_prop_form_field_width_0170` (nobody's).**

### 12.5 One observation on a declared limit — recorded so nobody re-derives it as a defect

**The sidebar un-hide is NOT rolled back on a failed sync**: the `err` and
no-raw branches leave the sidebar shown. That **matches the PLAN** ("show it as
part of the command") and **BX46 asserts it deliberately**, so it is **not** a
settled-decision-11 violation. The verifier flagged it only to stop a future
reader rediscovering it as a bug.

### 12.6 Bookkeeping drift, pre-existing and not from this commit

`receipts/10_receipt.md` and `11_receipt.md` (and, at the ledger stage,
`02`-`07_receipt.md` as well) arrive as **MODIFIED TRACKED** files while the
baseline block lists them as untracked. **Not from `35d9e18f`** — its `--stat`
shows only `12_receipt.md` — and nothing under `src/` or `tests/` is dirty.
Recorded for the driver's bookkeeping pass, not acted on here.

### 12.7 Gating

The GUI gate was **waited out, never bypassed**, by both stages. One request sat
unanswered for **67 minutes**. `GUI_GATE=0` was never set and no gate file was
hand-written; every X run went through `gated_xschem.sh` or `run_suites.sh`, no
bare loop.

---

## 13. DIVERGENCES FROM THE PLAN — the complete list, each with its reason

| # | divergence | reason |
|---|---|---|
| 1 | **PLAN FILE LIST WRONG.** `src/ase_window.tcl` was NOT modified; `src/ase.tcl` (the command) + `src/xschem.tcl` (the Tools entry) substituted. | `ase_window.tcl:388 ase::ui::build` builds the ASE-L **session** window's menubar; the **design** window's Tools cascade is `src/xschem.tcl:14933` (`Launch ASE-L`). Caught by the scout, re-verified by the implementer and again by the verifier. `ase_window.tcl` used **READ-ONLY**. |
| 2 | **BASELINE CLAIM FALSE — no `test_wave_grid` bump, and no `data-seq` guide row.** BX13 pins 16/11 **plus** a control that item 11's `Key-E` row is still there. | GH0/GH2 count only `bind WaveViewer` inside `wviewer::install_default_binds` and `-accelerator` inside `wviewer::build_menubar`. Item 12's key is a **schematic `.drw`** bind and its menu entry is on **xschem.tcl's** Tools cascade — neither is in scope, and adding a `data-seq`/`data-accel` guide row would have **broken** GH0 and GH2. Verified independently by the verifier. |
| 3 | **SABOTAGE (a) SUBSTITUTED** (ruling 23): "select without expanding ancestors" → **delete `$tv see $id`**. | Not a state this implementation can be put into by deletion: **`see` IS the expansion** (ttk opens every ancestor) and `browser_populate` inserts every row `-open 1` anyway. An explicit expand loop would have been dead code no sabotage could reach. |
| 4 | **SABOTAGE (d) ADDED**: delete the `-nocase` candidate line from `browser_node_for`. | Without it the item finds **nothing on any real ngspice raw** — the raw says `x1.x2`, `sim_sch_path` says `X1.X2`. The same defect item 11 hit one layer up. |
| 5 | **SABOTAGE (b) REPHRASED**, and the failed first attempt **recorded rather than relabelled** (§5.3). | The PLAN's phrasing (delete only the `partial` **return** arm) fired the WRONG thing — just BX34 leg 1 + BX37 — because `browser_reveal` runs **before** the branch, so the ancestor was still selected. That injection tests the *reporting*, not the fallback; discarded and replaced with deleting the fallback itself. |
| 6 | **A REAL DEFECT WAS FOUND BY PROBE, NOT BY REASONING, AND FIXED BEFORE IT SHIPPED**: the miss-retry `browser_refresh $token 1` could **destroy a good tree**. Now **IMPROVE-OR-RESTORE**; **BX39** is the check. | `browser_reload` sets the inventory to whatever `signal_list` answered, and a **failed read answers with nothing**. Observed turning a `partial` into an `err` and emptying the widget. The reload is now kept only if it matches **more** of the path; otherwise `browsersigs`, `browserrows`, the widget **and the selection** are restored. Verifier sabotage (v1) fired **10** checks on it. |
| 7 | **BX48 MEASURED BY SPY** rather than by a second real viewer toplevel. | Its claim is exactly "which PATH does the command compute". A second viewer added only WSLg fragility (the first cut self-skipped when it would not map). BX42 already proves the chain end to end; BX48 runs **both** session levels from the **same** hierarchy position, so the two answers discriminate. |
| 8 | **DECLARED ASYMMETRY WITH ITEM 11** — driver note (f) answered as a **finding**, not as agreement. | Item 11's `hier_origin_ok` **REFUSES** when the design window sits on an **ancestor** of the session's design; item 12 **MAPS** that case by dropping `level` segments (BX48 proves it works, BX49 proves it equals `sod_rel_path`). Browser→schematic refuses what schematic→browser handles. **Closing it would mean changing item 11 — out of scope.** |
| 9 | **CLAIM NARROWED (ruling 17):** decision 10's **PIVOT CHOICE is NOT claimed as behaviourally proven**. | With no raw in the design window `sch_waves_loaded()` is −1 and the two getters are **byte-identical**, so swapping them fires nothing — item 11 hit the same wall. What IS proven: the **level>0 ORIGIN MAPPING behaviourally** (BX48) plus a **source guard** that three shipped bodies contain **zero** `sch_path` reads (BX09). |
| 10 | **A TEST DEFECT OF THE IMPLEMENTER'S OWN WAS FOUND AND FIXED**: `BX42 (SECOND INVOKE)` read `unmapped` 1 run in 4. | A freshly raised viewer reports `winfo ismapped` 0 for a few ms. Fixed with `bx_vis_m`, which polls the **PRECONDITION** (the mapping, bounded at 2 s) and then asks the oracle **once** — item 5's rule; the asserted value is never polled. **Sabotage (a) was re-run afterwards and still fires exactly its 3 targets — and now reports `collapsed`, the real defect, instead of `unmapped`.** The oracle got sharper, not blunter. |
| 11 | **A VACUOUS CHECK WAS FOUND BY *RUNNING* A SABOTAGE AND STRENGTHENED, NOT RENAMED** (§5.2) — driver note (c)'s discipline paying off a third time in this batch. | BX42's first visibility leg stayed GREEN under sabotage (a): the command's first invoke un-hides the sidebar, which repopulates an **all-open** tree, so the node is visible whether or not anything expanded it. A **second** invoke now runs on an already-shown, deliberately collapsed tree, with a positive control asserting `collapsed` first. |
| 12 | **THREE FLAKY-LIST ENTRIES OWED TO THE DRIVER**, two of them found while measuring, one of them nobody's. | `BH54` — **item 11's**, `winfo ismapped .`, reproduced **1 in 4 at `b81ee0c9` with item 12 entirely absent**; this is the un-named ~20% flap `11_receipt.md` §13.4 recorded but could not identify (`BH50`'s two checks flap the same way but only in runs that also carried an X death). `BT45` — **item 9's** sidebar-geometry leg (§12.2). `test_prop_form_field_width_0170` — on **neither** list, cleared 3/3 in isolation (§12.4). |
| 13 | ⚠⚠ **A DRIVER DECISION RAISED, NOT TAKEN**: `test_wave_sigbrowser.tcl` at 489 X-arm checks crosses a WSLg Xwayland threshold. | The process is killed mid-run — implementer ~5 of 6, **verifier 11 of 12** — with **ZERO BX failures**, while the **same file at 397 checks is 6/6 and 8/8 clean in the same windows** and both of item 12's halves are 3/3 clean amplified 10-12× standalone. It is the file's **CUMULATIVE** footprint (six toplevels in one process, up from four), not item-12 code. **ACTION: re-measure after `wsl --shutdown`, then revisit settled decision 9 before item 13** — items 13-15 make it monotonically worse, and decision 9 is what forces the append. |
| 14 | **A PERFORMANCE DEFECT WAS FIXED WHILE CHASING THAT**, and is worth keeping regardless: `bx_ctx_to` called `update` unconditionally at ~25 sites, each `update` redrawing BOTH canvases (one run died reporting `after 68129 requests`). | The fast path now pumps no events at all (the switch is synchronous). **32 s → 5.9 s per run.** It did **NOT** cure the aborts — itself evidence that raw request count is not the mechanism — but it is a 5× reduction in exposure. |
| 15 | **DECLARED LIMIT, asserted rather than pretended away:** the sidebar un-hide is **not rolled back** on a failed sync. | Matches the PLAN ("show it as part of the command"); **BX46 asserts it deliberately**. The verifier confirmed it is not a decision-11 violation and asked that it be recorded so nobody re-derives it as a defect (§12.5). |
| 16 | **ISSUE 0212 NOT DUPLICATED** (driver note (h)). | Item 12 matches raw-derived paths against **tree node ids**; it never feeds a path back to `descend -inst`, so the vector-slice limitation does not arise in this direction. |
