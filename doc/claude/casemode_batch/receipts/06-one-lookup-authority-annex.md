# 06 annex — item **5b**: the measurements, the mutation table, the gaps

Companion to `receipts/06-one-lookup-authority.md`. Everything here was produced
on this machine on 2026-08-16/17, on the dev display `:99` or true headless.
**§§1–6 are the first round; §§7–10 are the fix round** (the four confirmed review
findings and what closing them cost) and were moved here out of the receipt, which
the closer cut back to its five mandated sections.

---

## 1. The measurement that decided the design

Run in bare `tclsh 8.6.14` **before any code was written**, because the driver's
brief was explicit that the `upvar` + `unset -nocomplain` + indexed-write shape
must be established by experiment and not from the Tcl manual.

| probe | measured |
|---|---|
| `info exists arr` on a traced but **undefined** array | fires a **read** trace with an empty `name2`, and answers **0** |
| `info exists arr(k)` for a missing element | **fires** the read trace; a trace that sets the element makes it answer 1 |
| a read of a missing element the trace does not set | `can't read …: no such element in array` — the caller's `catch` fails |
| `array names` | fires the **`array`** op |
| **`array unset arr`** | fires `array` then `unset`, and **`trace info variable arr` is then EMPTY** |
| `unset arr` | same |
| inside a proc: `upvar ::ns::a var; unset -nocomplain var; set var(x) {}; lappend var(x) 3.5` | works normally, and **the traces are gone** afterwards |

**The third row of the last block is the whole answer.** A read trace never has
to survive the Tcl publisher, because it cannot: `read_raw_dataset`'s own
`unset -nocomplain var` removes it. The two publishers are serialised by
construction, not by a rule anybody has to remember.

Re-measured in the real binary afterwards (`CS104b`–`CS104g`, `CS105*`).

## 2. Valgrind — the disarm

`free_rawfile()` → `ngspice_data_forget()`. Driven by: read `tr_preserve.raw`,
`update_op`, read a second raw so the registry is not emptied, then
`xschem raw clear <the publisher's file> tran`, then read one element the view
had not yet materialised.

```
fixed build              valgrind -q  ->  (silent)
ngspice_data_forget()    ==2728581== Invalid read of size 8
  made a no-op           ==2728581==    at 0x1E643E: ngspice_data_trace
```

Both runs print the same Tcl-visible result (`no such element in array`), which
is precisely why `CS103g` cannot carry this on its own: `free_rawfile()` frees
`names[]` and the hash table, so the dangling lookup *usually* misses. The defect
is the read, not the answer.

## 3. Mutation table — 26 mutations

Each applied to a copy of a byte-exact backup of the six touched sources, rebuilt
(`cd src && make`), both suites re-run, restored (`md5sum -c`, clean every time),
rebuilt, re-run green. Reds are from **`test_ngspice_data_view.tcl`** unless the
row says otherwise; `+RCM` names extra reds in `test_raw_case_mode.tcl`.

| # | what was broken | went red |
|---|---|---|
| M1 | `ngspice_data_arm()` never installs the trace | 25 checks: CS97 CS97b CS97c CS98 CS98c CS99 CS99b CS99b2 CS99b3 CS100 CS100c CS100d CS102 CS102b CS102c CS103c2 CS104 CS104d CS105b CS106c CS106c2 CS106d CS106f CS106g CS106h **+RCM** CS22 CS23 CS23d CS36d CS36e |
| M2 | the trace's **read** arm returns without resolving | 21 checks (M1 minus the four enumeration-only ones) **+RCM** the same five |
| M3 | the trace's **array** arm returns without populating | CS100d CS100f CS102 CS102b CS102d **+RCM** CS22 CS23 CS23d |
| M4 | enumeration no longer drops the materialised keys | CS100d CS100f CS102d **+RCM** CS22 CS23 CS23d |
| M5 | the view formats the **next** variable's value | CS99b CS99b2 CS99b3 CS106c CS106c2 CS106d CS106g CS106h **+RCM** CS36d CS36e |
| M5b | the view prints `%.17g` instead of the publisher's precision | CS106c2 |
| M6 | `get_raw_index_in()` ignores its `Raw*` and uses `xctx->raw` | CS103c2 CS103d CS103h |
| M7 | `ngspice_data_forget()` a no-op | CS101d CS102 — *via freed memory, so allocator-dependent; §2 is the real evidence* |
| M7b | M7 **plus** `free_rawfile()` keeps the hash table | none — the freed `Raw` struct itself is poisoned, so the lookup still misses. Recorded as a **failed** attempt to redden `CS103g` |
| M8 | the `n\ vars` sentinel is not written | CS101d CS102 |
| M9 | a materialised key is not recorded for cleanup | CS100d CS100f CS102d **+RCM** CS22 CS23 CS23d |
| T1 | `string tolower` back in `ngspice::get_voltage` | CS97 CS106g CS106i |
| T2 | `ngspice::lookup` always answers `?` | CS97 CS97b CS97c CS98 CS98c CS99 CS99b CS99b2 CS99b3 CS105f CS106g CS106h |
| T3 | `get_current`'s `[ve]` test back to case-sensitive | CS97b |
| T4 | `string tolower` back in `ngspice::get_node` | CS97c |
| T5 | `get_diff_voltage` returns `$resn`, not the difference | CS99b CS99b2 CS99b3 |
| T6 | `get_diff_voltage` drops its `?` guard | CS99c CS99d |
| T8 | `raw_case_mode_sniff()` always `UNKNOWN` | CS107h CS108h **+RCM** 5 |
| T9 | the `raw casemode <mode>` setter does not store | CS107k CS108j **+RCM** 3 |
| T11 | `raw casemode` answers only for a spice `tran` database | 19 checks: all of CS107c–CS107m and CS108c–CS108j **+RCM** 49 |
| T12 | the read trace never misses (`idx < 0` → 0) | CS97 CS97b CS97c CS98b CS99 CS99c CS99d CS100f CS101d CS101e CS102 CS103d CS103h CS106e CS106i |
| T13 | `read_raw_dataset`'s `unset -nocomplain var` deleted — **the hazard** | CS105c CS105d CS105e CS105f |
| T14 | `read_raw_dataset`'s own `string tolower` deleted | CS105c CS105f |
| T15 | `raw_lookup_name()`'s case-folded rung never fires | CS98 CS99b3 CS102c CS108m **+RCM** 35 |
| T16 | `update_op()` no longer refuses a digital database | CS109b CS109c CS109d CS109e |
| T17 | `extra_rawfile()`'s clear-all arm stops unsetting the array | CS104g |

**T5 was green until its fixture changed.** It first ran against
`tr_preserve.raw` point 0, where every node reads 0.0 — and `0 − 0 == 0`, so
"return the first operand" passed 93/93. `CS99b*` now has its own raw with two
distinct non-zero voltages. A vacuous check found by sabotage, not by review.

**T17 was green until its check moved.** `CS104g` sat after a `raw case` re-read
that had already unset the array, so it measured an array that was empty for
another reason. `CS104f2` now re-arms first.

## 4. The 33 unsabotaged checks — NOT evidence

⚠ **This list is the FIRST ROUND's, and the fix round changed two entries.**
`CS100e` is no longer on it (see below), and the fix round's own 27 new checks have
their own unsabotaged list in §9 below — 21 of 62, plus two declared weak in the
test file itself and two more that pin Tcl's own behaviour.

- **Premise / setup, owned by items 1–3:** `CS96` `CS96b` `CS96c` `CS96d`
  `CS99b0` `CS99b1` `CS100b` `CS101` `CS101b` `CS101c` `CS103` `CS103b`
  `CS103e` `CS103f` `CS104e` `CS104f` `CS104f2` `CS105` `CS106` `CS106b`
  `CS107` `CS107b` `CS108` `CS108b` `CS108k` `CS108l` `CS108n` `CS109`.
- **`CS104b` / `CS104c` pin MEASURED TCL BEHAVIOUR**, not our code: no mutation
  of ours can move them, and that is the point — if a Tcl upgrade stopped
  destroying traces on unset, the design in §1 loses its foundation and these
  are what would say so.
- ~~**`CS100e`** declares the materialised-element cache. A read trace cannot
  fire for an element that exists, so no mutation reaches it.~~ **WRONG ON BOTH
  COUNTS — corrected in the fix round** (§7.5). A read trace *does* fire
  for an existing element (measured: a script write into the array is discarded on
  the next read), and `CS100e` is not unreachable — fix-round mutation **N13**
  (unset the element on a ladder miss instead of leaving it) reddens it. It is
  green because after the rename the ladder can no longer resolve `v(MidNode)`,
  not because the trace was skipped, and it is restated in the test file to say
  so.
- **`CS103c`** reads an element cached before the switch; a cache answers the
  same way however the resolver is wired. Its live twin is `CS103c2`.
- **`CS103g`** — see §2. Backed by valgrind rather than by a mutation, and M7b
  is the recorded failed attempt.

## 5. Counts, verbatim

```
test_ngspice_data_view      RESULT: ALL PASS (98 checks)        (--nogui and :99)
test_raw_case_mode          RESULT: ALL PASS (277 checks)
test_backannotate_digital   RESULT: ALL PASS (81 checks)
test_wave_cursor_crossdb    RESULT: ALL PASS (93 checks)
test_wave_casemode          RESULT: ALL PASS (134 checks)
test_hilight_case_senders   RESULT: ALL PASS (30 checks)
test_wave_viewer            RESULT: ALL PASS (400 checks)
test_node_token_split       RESULT: ALL PASS (168 checks)
test_ase_cosim              RESULT: ALL PASS (342 checks)
test_vcd_read               RESULT: ALL PASS (187 checks)
test_raw_read_dispatch      RESULT: ALL PASS (51 checks)
test_raw_read_failure_0306  RESULT: ALL PASS (63 checks)
test_raw_ascii_point_bounds RESULT: ALL PASS (90 checks)
test_vcd_time_base          RESULT: ALL PASS (124 checks)
test_ase_core               RESULT: 1 FAILED (57 passed)  <- A/B: identical on a
                            pristine HEAD binary under the same arm; true
                            headless it is ALL PASS (74 checks) on both.
```

Master red-before-green, pristine `HEAD` build of all six touched sources.
⚠ **THE NUMBER THAT WAS HERE — `RESULT: 16 FAILED (71 passed)` — WAS STALE AND
CONTRADICTED THE RECEIPT'S**, and `71 + 16 = 87` was never this file's check
count. A reviewer flagged it; the fix round re-measured once and both documents
now carry the same three lines, against the suites as they now stand:

```
test_ngspice_data_view.tcl   RESULT: 35 FAILED (104 passed)     (139)
test_ngspice_data_ctx.tcl    RESULT: 6 FAILED (15 passed)       (21)
test_raw_case_mode.tcl       RESULT: 5 FAILED (272 passed)      (277 — the five restated checks, no others)
```

⚠ `CS114c`–`CS114g` are GREEN on pristine HEAD — HEAD's procs folded, so the third
publisher's road worked there. Their red-before-green is against **the item's own
pre-fix state** (§9, N19), not against HEAD.

Restored `md5sum -c`-clean afterwards and rebuilt; all three green. The fix
round's own 17 mutations are in §9.

## 6. Measured, not filed

- **Cost moved, it did not vanish.** The publishers went from `nvars`
  `Tcl_SetVar2` calls to **two**; in exchange every *missing*-element read now
  walks the four-rung ladder (and may build the lazy fold table on first fuzzy
  lookup). A script that reads every variable once therefore does the same total
  work plus the ladder; a schematic overlay that reads three nets out of a
  400-variable raw does far less. Neither was timed.
- **Enumeration is O(nvars) each time** — it unsets every materialised key and
  re-resolves every stored name through the ladder. `array names` on this array
  used to be free. Only tests enumerate it today.
- **`ngspice_data_arm(NULL, …)` is guarded but unreachable**: both publishers
  already require a `Raw` with `values`.
- **Item 4's latency pointer is still unmeasured** (one schematic walk per
  `raw read`). Nothing looked wrong across ~25 suite runs at unchanged counts,
  which remains an absence of a symptom rather than a measurement.

---

# FIX ROUND (2026-08-17)

Three independent review lenses raised four findings, each with a reproducer;
**every one was confirmed by re-measurement here before a line was changed.** Base
for the round: the item's own uncommitted state (`src/save.c`
`07bde2f7536f3a1f94761218b3b6a158`).

## 7. The four confirmed findings

### 7.1 BLOCKER — a Tcl context switch destroyed the view, and the overlay read `?`

`ngspice::ngspice_data` was a member of `tctx::global_array_list` (`src/xschem.tcl`),
so every tab/window create, switch or close ran `restore_ctx`'s `unset -nocomplain`
over it — and by **this item's own measured fact (§1) an unset destroys every trace
on the variable.** The lazy view became a frozen eager copy of the stored spellings,
and because item 5b **deleted** the Tcl-side `string tolower` and `v(...)` rungs the
operating-point overlay then read `?` for every node, lowercase included:

```
# real road, dev display :99
BEFORE: gv MidNode=0  In=0        AFTER create+switch: gv MidNode=?  In=?
# headless, through the SHIPPED save_ctx/restore_ctx pair
Q1 names=i(Vs) {n\ points} {n\ vars} time v(In) v(MidNode)   <- a frozen eager array
```

**FIX — the array leaves that list**; it is C-owned derived state, not per-window Tcl
state. One line plus the comment saying why it must not go back.

**AND THE HALF THE MEMBERSHIP REALLY DID BUY.** A window that never annotated used to
see an empty array; without it, window B read window A's numbers for any net sharing a
name (measured: `gv MidNode=0` with `raw loaded == -1`). So `nd_view_owned()`
(`save.c`): the view answers only while the publishing `Raw` is reachable from the
**current** context (`xctx->raw` or an `xctx->extra_raw_arr[]` entry), **and** a read
from a non-owning window **drops** the elements the owner materialised — without the
drop the guard only stopped *new* resolutions and an already-materialised value still
answered (measured: `In` survived and read `0`). This is **not** the "follows
`xctx->raw`" behaviour `CS103c2`/`CS103d`/`CS103h` forbid: two databases in one window
are both reachable, so making the other current changes no answer. Those three are
green throughout.

**A SECOND DEFECT FELL OUT OF WRITING THE DROP.** Measured: Tcl suppresses a
variable's traces only for **the element whose trace is running**, so unsetting a
*different* element from inside one delivers our own `TCL_TRACE_UNSETS` callback
**re-entrantly**. The drop loop was mutating the list it walked and skipped an entry.
The list is now **detached** before the first unset. (The same hazard was latent in
the enumeration rebuild's drop loop, where the array trace's active flag happens to
suppress it.)

### 7.2 MAJOR — the THIRD publisher's road could no longer read anything

`ngspice::read_raw_dataset` / `read_raw` (`src/ngspice_backannotate.tcl`) publish this
array from **pure Tcl** through `upvar ::ngspice::ngspice_data arr`, under keys folded
by their own `string tolower` (`v(midnode)`). They never build a `Raw`, so there is
**no authority on that road to reach** — and §1 records that their `unset -nocomplain`
disarms the C view before they write. Deleting the procs' own folds therefore left that
road reading `?` for **every** node, all-lowercase included, where HEAD read a number.
The file is shipped and installed; nothing in the tree sources it, so the road is
opt-in — but a user's `xschemrc` sourcing it is the documented way to use it, so this
is a regression, not dead code.

**FIX — one fallback in `ngspice::lookup`, and a GATE that is the whole point.**
`xschem raw view_armed` (`ngspice_data_armed()`) answers whether an indexed read of the
array **is** an authority call for this window. The fallback ladder (`v($name)`,
folded, folded-and-wrapped — the C ladder's rungs 1–3) runs **only** when the answer is
no, so while the authority is reachable not one probe happens.

**THE GATE IS NOT DECORATION, AND A SABOTAGE PROVES IT** (N20): remove it and
`ngspice::get_voltage En` on a `distinguish` database holding both `v(EN)` and `v(en)`
answers `2.222` — a D2 violation, `CS106i` red alongside the new `CS114j`. Ungated,
that fallback would be the second authority D3 forbids; gated, it is a degradation path
for a publisher that has no authority at all. Measured after the fix on the third
publisher's own binary op raw: `in`/`In` → `3.0`, `MidNode`/`midnode` → `2.25`,
`get_current Vs` → `-0.00075`, `get_node v(In)` → `3.0`, `nosuchnet` → `?`.

### 7.3 MAJOR — unbounded growth on the array read path

`nd_view_record_key(n2)` ran on **every** resolvable read, and a read trace fires for
an element that already exists, so each repeat read appended another `my_strdup2`'d
key. Measured on the shipped bytes:

```
200000 repeat reads of ONE already-materialised element: VmRSS 16000 -> 23808 kB (~40 B/read)
identical loop over an untraced control array:           +0 kB
after the fix:                                           +0 kB
```

**FIX — record only what the read CREATED** (`Tcl_GetVar2(...) == NULL` first). Not
removal: deleting the call outright reddens 3 + 3 checks, because the recording is
load-bearing for the enumeration rebuild.

**THE ORACLE IS A COUNT, NOT RSS, AND THAT MATTERS.** An RSS assertion at that point in
the suite **passed with the defect in place** — 20000 reads grew RSS by 896 kB in a
fresh process and by **0** there, because the suite had already freed enough heap to
absorb it. So `xschem raw view_keys` was added (introspection only,
`ngspice_data_nkeys()`) and `CS111f` reads `20004` vs `4` under the reverted fix.
`CS111j` still watches RSS, loosely and labelled as such. Enumeration cannot catch it
either: the rebuild unsets every duplicate, so the answer stays `vars + 2` however long
the list grew — `CS111g` says so out loud rather than pretending to be the pin.

### 7.4 MAJOR — unsetting ONE ELEMENT disarmed the whole view

The trace is installed with `name2 == NULL`, so `TCL_TRACE_UNSETS` fires for a single
element too, and the handler called `nd_view_reset()` either way. Measured before the
fix: after `unset arr(v(In))`, `info exists` still said **1** ("an operating point is
loaded", `actions.c`) while nothing resolved lazily, `array names` stopped being
rebuilt, and `ngspice::get_voltage MidNode` read `?`. **FIX:** reset only when the
**array** went away; a single element just leaves the materialised list. `CS112*`.

### 7.5 MINOR ×2 — a false "measured" claim, and a false claim about the sentinel key

- **"A read trace does not fire for an element that already exists"** — written into
  `save.c`, spec §13.6, the receipt, this annex and the test. **False on tcl 8.6.14:**
  `set arr(v(In)) BOGUS` then read it back gives the *number*. All five copies
  corrected; the "materialised element is a cache" ruling is **withdrawn** and restated
  as *re-resolved on every read, keeps its last value only once the name stops
  resolving*; the silently discarded script write is now documented; `CS100e`'s
  rationale is rewritten (green because the ladder can no longer resolve the renamed
  name, **not** because the trace was skipped).
- **"a literal backslash before the space, which is what `$arr(n\ vars)` reads in
  Tcl"** — it is not: Tcl backslash-substitutes an array index, so that form asks for
  `n vars` and errors. Corrected in `save.c` and spec §13.6b, with the note that the
  pure-Tcl publisher writes the *plain* `n vars` key, so the two publishers disagree —
  pre-existing, deliberately unchanged.
- **The receipt and this annex disagreed about the master red-before-green numbers.**
  Confirmed, re-measured once, and the same three lines written into both (§5).

## 8. Fix-round files and counts

| file | what |
|---|---|
| `src/save.c` | ownership guard; the detached drop; per-element unset; record-only-on-create; `ngspice_data_nkeys()`; `ngspice_data_armed()`; four comment corrections |
| `src/xschem.tcl` | the array out of `tctx::global_array_list`, with the reason; `ngspice::lookup` gains the **gated** fallback (§7.2) |
| `src/xschem.h` · `src/scheduler.c` | two prototypes · `xschem raw view_keys` and `raw view_armed` (introspection; `view_armed` also gates the fallback) |
| `tests/headless/test_ngspice_data_view.tcl` | `CS110`–`CS112h`, `CS114*`; `CS100e` restated; two abort guards |
| `tests/headless/test_ngspice_data_ctx.tcl` | **NEW**, `CS113*`, 21 checks, needs a display |
| `specs/raw_case_mode.md` | §13 header, §13.6 rewritten, **§13.6b** and **§13.7** new |

**62 new checks** — `CS110`–`CS110i` (9), `CS111`–`CS111j` (10), `CS112`–`CS112h` (8),
`CS113`–`CS113n` (21, the display suite), `CS114`–`CS114j2` (14) — plus `CS100e`
restated in place.

## 9. Fix-round mutation table — 17 mutations (16 redden, 1 recorded failure)

Each on the fixed tree, rebuilt, both new suites re-run (`test_raw_case_mode` too where
the subject overlaps), restored from a byte-exact backup, rebuilt, green.

| # | mutation | red |
|---|---|---|
| N1 | `ngspice::ngspice_data` back in `tctx::global_array_list` | **10**: `CS110c CS110d CS110e CS110g CS110h`, `CS113h CS113h2 CS113h3 CS113j CS113n` |
| N2 | ownership guard out of `nd_view_resolvable()` | **5**: `CS113e CS113e2 CS113e3 CS113f CS113m` |
| N3 | the drop on a non-owned read removed | **2**: `CS113e3 CS113f` |
| N4 | record a key on **every** read (the growth defect) | **1**: `CS111f` (`20004` vs `4`) |
| N5 | `TCL_TRACE_UNSETS` resets the view for a single element again | **10**: `CS112d CS112e CS112f CS112g`, `CS113h CS113h2 CS113h3 CS113j CS113k CS113n` |
| N6 | the drop walks the live list instead of a detached copy | **3**: `CS113e3 CS113f CS113k` |
| N8 | an existing element is treated as a cache (early return) | **2**: `CS111c CS111d` |
| N10 | `restore_ctx` no longer restores the arrays it unsets | **1**: `CS110i` |
| N13 | on a ladder MISS the element is unset instead of left alone | **4**: `CS100e CS101d CS101e CS102` |
| N14 | the drop keeps every materialised key | **12**: `CS100d CS100f CS102d CS110h`, `CS113e CS113e2 CS113e3 CS113f CS113k`, `+RCM CS22 CS23 CS23d` |
| N15 | the enumeration rebuild no longer records the keys it creates | **4**: `CS111e`, `CS113e3 CS113f CS113k` |
| N16 | `TCL_TRACE_READS` dropped from the arm | **39** (46 on the grown suites), incl. `CS110b CS111b CS111h CS111i CS112b CS112d CS112e CS112g CS113c CS114j2` |
| N18 | `TCL_TRACE_ARRAY` dropped from the arm | **13**, incl. `CS110h CS111e CS112f CS113k` |
| N19 | the gated fallback removed from `ngspice::lookup` (§7.2's defect) | **6**: `CS114c CS114d CS114e CS114e2 CS114f CS114g` |
| N20 | the **GATE** removed (fallback runs while the authority is armed) | **2**: `CS106i CS114j` — a D2 violation, and why the gate exists |
| N21 | `xschem raw view_armed` answers the inverse | **10**: `CS106i CS114b CS114c CS114d CS114e CS114e2 CS114f CS114g CS114i3 CS114j` |

**N7 FAILED to redden anything** and is recorded as such: removing the defensive
`if(!nd_view_resolvable()) return;` re-check after the ARRAY arm's drop left all 437
checks green. It guards a re-entrant disarm no reachable script produces; it stays,
unpinned and declared.

**CS110e and CS110h were STRENGTHENED mid-round**, both vacuous as first written:
`CS110e` only compared two answers (two `?`s satisfy that) and stayed green under N1
until it also demanded a number; `CS110h`'s count alone is `vars + 2` for a frozen copy
too, so it now also demands the renamed name be *in* the enumeration. Found by
sabotage, not by review — the same shape as T5/T17 in §3.

**Unsabotaged fix-round checks, with reasons (21 of 62):** `CS110` `CS110f` `CS111`
`CS112` `CS113` `CS113a` `CS113b` `CS113c2` `CS113d` `CS113d2` `CS113g` `CS113i`
`CS113l` are premises — a verb returning `1`, a fixture existing, a window created or
switched to, several elements materialised before the switch. `CS111g` (enumeration
unchanged by repeat reads) and `CS111j` (RSS not running away) are **declared weak in
the test file itself** and are not the pin for §7.3. `CS112c` and `CS112h` pin Tcl's own
behaviour (an array survives a single-element unset; `array unset` destroys it), which
no mutation of ours can move — the same standing as `CS104b`/`CS104c`. `CS114` (the Tcl
publisher's own folded keys — its output, not ours), `CS114h` (a negative result: a name
no publisher has) and `CS114i`/`CS114i2` (premises on items 1–3's verbs) complete it.

## 10. Tooling traps hit in the fix round

- **`cp -p` from a backup preserves the older mtime, so `make` skips the rebuild** and
  the previous sabotage's binary survives. One run (the first N10) was contaminated that
  way and was **re-run cleanly**; every restore after it used plain `cp` + `md5sum -c` +
  a verified rebuild. The verifier hit the identical trap on the valgrind A/B. The
  closer's own runs began with `touch` on the four C sources and a full relink
  (`md5sum xschem` = `a17e692f9af2292414169e793ef8dc80`).
- **Two pristine-HEAD runs ABORTED with no `RESULT` line** — item 2's trap both times,
  both now hardened: `get_diff_voltage`'s `can't read "res"` (behind `pcall`) and
  `expr {$cs111_k0 + 1}` on `ERR:Wrong command` from a `xschem raw view_keys` HEAD does
  not have (behind `num`). A file that aborts prints no `RESULT` line, and under that a
  whole red-before-green drive reads as "nothing went red".
- `test_ngspice_data_ctx.tcl` drives real windows (`new_schematic create`/`switch`,
  `after 300`). Green on `:99` in 9 runs here, but it is a window-mapping suite and
  inherits that family's WSLg flake exposure if anyone runs it on `:0`.

## 11. Review: what was raised, what was confirmed, what stays unproven

**Raised and NOT confirmed: nothing.** Three independent lenses raised four defects and
two false documentation claims; every one was reproduced here before a line changed, and
all six are fixed (§7). A seventh — the receipt and this annex giving contradictory
master red-before-green numbers — was also true and is closed by one re-measurement (§5).
The receipt's §5 summarises; this is the full carried-forward list.

**Reviewers' own not-proven items, verbatim in substance:**

- **Nobody proved these four are the only lifecycle holes.** Unexercised: `array unset
  ngspice::ngspice_data <pattern>` (same root cause as the single-element unset), a tab
  **CLOSE** with an armed publisher, two windows publishing in turn, and the viewer
  window item 5 measured as a separate `xctx` with a different `xctx->raw`.
- **`M13` — a real coverage hole, found by the verifier and never closed.** Deleting
  `Tcl_UnsetVar(interp, "ngspice::ngspice_data", TCL_GLOBAL_ONLY);` from
  `ngspice_data_arm()` leaves both suites 98/98 and 277/277 green, and that line's own
  comment (repeated as spec §13.5) calls it load-bearing: without it a second trace copy
  stacks on every re-arm and elements from a previous publisher survive it. Nothing pins
  it.
- **`CS103g` / the dangling `Raw`.** The valgrind A/B was run by the implementer and
  re-measured by the verifier (0 errors shipped; 12 errors / 2 contexts, `Invalid read of
  size 8 at ngspice_data_trace`, with the disarm deleted) but by **no reviewer**. One
  reviewer noted by grep that `delete_schematic_data()` (`xinit.c:974`) leaves
  `free_rawfile(&xctx->raw, 0)` **commented out**, so a closed tab leaks its `Raw` rather
  than freeing it — an observation, not a measurement.
- **`nd_view_set`'s `char s[100]`** with `sprintf("%.*g", xctx->ev_precision, …)`: nobody
  bounded `ev_precision`. Same shape as the pre-item code, but now reachable from an
  arbitrary array read rather than only from a publish loop.
- **`ngspice::get_current`'s classification rewrite.** `regexp $prefix {[ve]}` (arguments
  swapped — the prefix used as the *pattern*) became `regexp -nocase {^[ve]$} $prefix`.
  Single-char cases agree, but the **empty**-prefix case flips (old: empty pattern
  matches, no `@` prepended; new: no match, `@` prepended) and a metacharacter prefix used
  to error or match spuriously. No reviewer built a schematic that reaches either, so it
  is recorded, not raised.
- **Issue `0420`'s claim** that `token.c`'s `@spice_get_*` floaters diverge from the Tcl
  road under `distinguish` was measured by the implementer and one verifier, by no
  reviewer.
- **One reviewer saw the materialised alias key `in` still present in `array names` after
  a later enumeration — ONCE in six runs.** Five identical runs and a dedicated headless
  probe (read alias, enumerate twice, twice more) showed the drop working every time. Not
  claimed as a defect; recorded so a future session does not think it is new.
- **A reviewer's expectation that a single-element `unset` disarms the view was refuted**
  on the fixed tree (`arr(MidNode)` still resolved lazily afterwards) — that is §7.4's fix
  working, recorded so nobody re-litigates it.
- **Two reviewers did not run `full_audit.sh` themselves** (the tree was being rebuilt
  under them). Their audit statement is only that the committed captures diff to the new
  rows; the closer's own run (receipt §3) is the independent one. Note that the §7.1
  blocker **would not have shown in any audit anyway** — no audited suite performs a Tcl
  context switch while an operating point is published, which is why the four suites one
  reviewer chose for the blast radius (`test_multi_window`, `test_wave_tabs`,
  `test_wave_crossdb_trace`, `test_raw_read_failure_0306`, 4/4 PASS) could not have caught
  it either.
- **Pre-existing, NOT this item's** (recorded so a fixer does not mistake it for a
  regression): the C sentinels are keyed with a literal backslash, so Tcl's
  `$arr(n\ vars)` asks for `n vars` and misses, while the pure-Tcl publisher writes the
  space-only key. HEAD writes the same bytes.
- **Scope: no leak found.** The only harness edit is one line adding the headless suite to
  `full_audit.sh`'s `nogui_tests`; the `test_backannotate_digital.tcl` edit is
  comment-only; the five restated checks keep their ids and gained clauses rather than
  losing them.
