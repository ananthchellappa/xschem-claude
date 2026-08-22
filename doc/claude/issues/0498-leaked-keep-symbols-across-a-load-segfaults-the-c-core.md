# 0498 — a leaked `keep_symbols=1` across a schematic load segfaults the C core

STATUS: **FIXED** on branch `annotate`, step **X0498**, 2026-08-22.
Filed 2026-08-21 at `d56283ec` (step S3d), while sabotage-testing S3 attempt 4.
Related: 0431 (the prototypes do not restore on a raise), 0494, 0499,
0600/0601/0602 (measured during the fix, filed not fixed), spec §5 I6.

> ## ⚠ TITLE CORRECTION — THE TITLE IS WRONG AND THE FILENAME IS KEPT ANYWAY
>
> **It is not "across a schematic load", and `keep_symbols` alone is not the
> trigger.** Both halves were measured false during X0498:
>
> * **The carrier is `xschem netlist`, not `xschem load`.** Three consecutive
>   `xschem load` calls with *both* flags leaked survive cleanly
>   (`SURVIVED-LOAD-ONLY insts=1 syms=1`, exit=0). `scheduler.c:7611`'s
>   `keep_symbols` is the **local `-keep_symbols` argument** of the load branch,
>   not the Tcl global, so a leaked Tcl `keep_symbols` never reaches that
>   `remove_symbols()`. **There is no bug in the load path. Do not go looking
>   for one, and do not edit `scheduler.c:7611`** — it would red
>   `test_op_annot` O22/O32 and `test_netlist_log:152-157` while fixing nothing.
> * **`keep_symbols=1` and `no_undo=1` are JOINTLY necessary.** Neither alone
>   crashes (necessity matrix below).
>
> The filename is deliberately **not** renamed: spec §5 I6, 0494 and 0499 all
> cite this issue by name. Accurate one-line restatement:
>
> > a `no_undo=1` leaked into `xschem netlist` (with `keep_symbols=1` so the
> > symbol table is non-empty) disables the netlister's own document save/restore,
> > which silently replaces the user's document with a sub-sheet — and, when that
> > sub-sheet holds more instances than the top cell, drives `draw_hilight_net()`
> > through `xctx->sym[-1]` and takes the process down with SIGSEGV.

---

## What was measured BEFORE (verbatim)

The original 3-of-3 sabotage observation that earned this number, on the S3
attempt-4 `restore_skipped` variant:

```
propagate_hilights(): .ptr<0, unbound symbol: inst 0, name=MP1 sch=w_bare.sch
FATAL: signal 11
(emergency save)
```

Re-measured at `7ad53557` on a **PDK-free** fixture (top = one instance of a
`spice_stop=true` cell whose child sheet holds 100 instances), deterministic
3 legs of 3:

```
### HEAD=7ad53557  binary mtime=2026-08-20 21:07:59.878919178 -0700
propagate_hilights(): .ptr<0, unbound symbol: inst 99, name=MP100 sch=wbare.sch
EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_wbare_fdgbbfggge
FATAL: signal 11
while editing: wbare
exit=1
leg1: FATAL: signal 11 exit=1
leg2: FATAL: signal 11 exit=1
leg3: FATAL: signal 11 exit=1
```

**The necessity matrix — both flags required, measured, not inferred:**

```
keep_symbols=0 no_undo=0 -> rc=10  SURVIVED insts=1 syms=1
keep_symbols=0 no_undo=1 -> rc=0   SURVIVED insts=1 syms=0   (silent corruption)
keep_symbols=1 no_undo=0 -> rc=10  SURVIVED insts=1 syms=1
keep_symbols=1 no_undo=1 -> rc=1   FATAL: signal 11
```

**The stack, from gdb, taken independently by two agents:**

```
#0  0x000055555566d986 in draw_hilight_net ()
#1  0x000055555567b3a6 in global_spice_netlist ()
#2  ... xschem_cmds_n
```

**The load path is innocent — measured:**

```
SURVIVED-LOAD-ONLY insts=1 syms=1
```

**Shipped reachability — 0498's original "shipping code cannot reach it" is
FALSE.** A driver containing **zero** `xschem set` calls (verified,
`grep -c 'xschem set'` = 0): `source sky130A/sky130_procs.tcl` → load the shipped
cell `sky130_tests/test_generators` → call `sky130_save_fet_params` (the shipped
menu command *SKY130 → Create FET .save file*, `sky130_procs.tcl:237`) → it raises
`Symbol not found` and leaks all three flags (issue 0431) → open another design →
`xschem netlist`:

```
P2 shipped walk rc=1 msg=Symbol not found ; leaked ks=1 nd=1
FATAL: signal 11
```

**The silent variant, which is arguably worse than the crash** — same leak,
`xschem netlist` on stock `sky130_tests/bandgap_opamp` (75 instances), rc=0, no
warning, no crash:

```
CTRL  after netlist insts=75 first=l1 p93 p94 p95 p96 p97
LEAK  after  netlist insts=13 first=p179 p180 l1 p1 p2 p3
LEAK  current_name=sky130_tests/bandgap_opamp/schematic/bandgap_opamp.sch  schname=bandgap_opamp.sch
```

The top-level buffer has been replaced by a sub-sheet while `current_name` and
`schname` still name the user's cell. **A save from that state writes the wrong
cell over the user's design.** ⚠ See *Still open* — the adversary could **not**
reproduce this particular stock-cell transcript (75 → 75 on both binaries); the
synthetic fixture reproduces the same corruption cleanly and is what the suite
guards.

---

## The mechanism, end to end

1. `no_undo=1` makes `xctx->push_undo()` **and** `xctx->pop_undo()` silent
   no-ops (`save.c:4713`/`:4795`, `in_memory_undo.c:439`/`:600`).
2. `global_spice_netlist()` restores the top-level document by **exactly one
   mechanism**: its own `push_undo()` … `pop_undo(4, 0)` pair
   (`spice_netlist.c:290`/`:524`). With `no_undo` set, that restore never happens.
3. `keep_symbols=1` skips `remove_symbols()` (`spice_netlist.c:450`), so
   `xctx->symbols` is non-zero and the traversal at `:459` actually runs — with
   `keep_symbols=0` the symbol table is empty and the loop body never executes.
   That is exactly why `keep_symbols` is co-necessary.
4. The traversal reaches `spice_block_netlist()`, whose `spice_stop` arm
   (`spice_netlist.c:694`) calls `load_schematic(0, filename, 0, alert)`.
   `load_symbols=0` skips `save.c:4474`'s
   `if(load_symbols) link_symbols_to_instances(-1);`, so the child sheet's
   instances land in `xctx` with `.ptr` unresolved.
5. Because the `pop_undo` is a no-op those child instances **stay**, and
   `spice_netlist.c:530` relabels `xctx->current_name` back to the top cell —
   which is why the crash message names the top sheet.
6. `stored_flags` was `calloc`'d at the **entry** instance count
   (`spice_netlist.c:438`) and is read back over the **current** count (`:539`):
   a heap over-read that hands garbage into `xctx->inst[i].color`.
7. Those garbage colours pass `hilight.c:4162`'s `!= -10000` gate, and
   `symptr = (xctx->inst[i].ptr + xctx->sym);` at `:4187` dereferences
   `xctx->sym[-1]` at `:4188-4190`. **SIGSEGV.**

`propagate_hilights()` (`hilight.c:1886`) already guards `.ptr < 0` and only
prints the warning. `draw_hilight_net()` is the copy that was never given the
guard.

---

## What changed

**BOTH defensive and corrective**, because a defensive-only fix converts the
SIGSEGV into the silent document swap above, and `save.c` RULING **D5-1** already
rules a plausible wrong artifact worse than none.

### Corrective — the root cause (`src/netlist.c`, `src/xschem.h`)

```c
int  undo_shield_push(void);      /* returns xctx->no_undo, then sets it to 0 */
void undo_shield_pop(int saved);  /* xctx->no_undo = saved */
```

The walk's `push_undo`/`pop_undo` pair is **not editing undo — it is the walk's
save/restore**, so it must not be disableable by an editing flag. The shield is
taken immediately before `push_undo()` and dropped on **every** exit path,
including the early `fopen`-failure `return 1`:

| file | push | pops |
|---|---|---|
| `spice_netlist.c` | `:309` | `:330` (fopen `return 1`), `:635` (tail) |
| `spectre_netlist.c` | `:187` | `:208`, `:513` |
| `vhdl_netlist.c` | `:142` | `:157`, `:519` |
| `verilog_netlist.c` | `:116` | `:130`, `:431` |
| `tedax_netlist.c` | `:152` | `:170`, `:307` |
| `hier_psprint()` | `:65` | `:144` |

With `no_undo == 0` — every normal run and the whole existing suite — both
functions are assignments of the same value and **no code path changes**.

> **Deviation from the plan, verified in source and deliberate:** the shield is
> **unconditional** in `vhdl_netlist.c` and `verilog_netlist.c` rather than gated
> on `global`, because both back ends run `remove_symbols()` + `pop_undo(2,0)`
> *outside* their `if(global)` block (`vhdl_netlist.c:204-206`,
> `verilog_netlist.c:168-170`) — gating them would owe a pop against a push that
> never happened. spice/spectre/tedax keep the `global ?` gate (all their pops are
> inside `if(global)`). Row **X6** and sabotage **SV7** pin that narrowing.

### Defensive — no leaked flag can fault (`src/xschem.h` + four sites)

```c
#define INST_UNBOUND(n) (xctx->inst[n].ptr < 0)   /* issue 0498 */
```

* **`hilight.c:4169`** — the crash site. One `if(INST_UNBOUND(i)) continue;`
  immediately before the `color != -10000` gate in `draw_hilight_net()`'s
  per-layer instance loop. One int compare, no function call, in a hot loop.
* **`draw.c:680`, `psprint.c:992`, `svgdraw.c:755`** — three copies of a
  **guard-after-deref**: each executed `type = xctx->sym[xctx->inst[n].ptr].type;`
  one to three lines *before* the `if(ptr == -1) return;` written to prevent
  exactly that (upstream commit `40fd937d` hoisted the assignment above the
  pre-existing guard). The guard now precedes the dereference.
  `draw.c:1009 draw_temp_symbol()` is the in-tree reference ordering.
  Behaviour-preserving for `ptr >= 0`: the only statements crossed are a
  `tclgetboolvar("lvs_ignore")` read and `if(!has_x) return;`.

### Defensive, second layer — the heap over-read

`stored_flags_n` records the allocation size and bounds the restore loop in
**all five** netlisters (`spice`, `spectre`, `vhdl`, `verilog`, `tedax` — five
byte-identical copies of the same wrong assumption). Output is byte-identical on
any run where the instance count did not change, i.e. every healthy run.

---

## AFTER

```
0498 repro: SURVIVED, exit=10      (was: FATAL: signal 11, exit=1)
tests/headless/test_undo_link_symbols.tcl: RESULT: ALL PASS (54 checks)   [baseline 6]
T1 run_regression.tcl: 3 counted lines (3 FAIL / 0 GOLD? / 0 RESULT? / 0 FATAL) — the
   issue-0491 floor, unchanged
T2 tests/headless/run.sh: HARNESS PASS, 6/6 goldens PASS
T3 test_op_annot 241 -> 241 ALL PASS; test_wave_hilight 139 -> 139; test_undo_selection,
   test_descend_symbol, test_netlist_log, test_apply_hilight_log, buried_hilight,
   hilight_hier_oracle, hilight_hier_dump_replay, hilight_xwin_sync_headless — all unchanged
Stock netlists (nand2, dlatch, flop, bandgap_opamp) fixed vs pre-fix binary: BYTE-IDENTICAL
valgrind on the repro child: "ERROR SUMMARY: 0 errors from 0 contexts"
   (pre-fix: 3 errors, "Invalid read of size 8 at draw_hilight_net / by global_spice_netlist")
```

**Independent netlister-free confirmation** that the `INST_UNBOUND` guard is
load-bearing: `xschem load` + `xschem remove_symbols` (a shipped Tcl verb,
`scheduler.c:10864`) then a 22-operation battery under xvfb (redraw, zoom, select,
hilight, print svg, print ps, save, move, rotate, flip, edit_prop, delete, paste,
attach_labels, break_wires, descend, descend_symbol, check, search, align,
zoom_box, netlist ×2). **Pre-fix binary: SIGSEGV at `xschem hilight`. Fixed: all
22 survive.**

**Non-vacuity of the new rows** — the current suite run against a **pristine
HEAD binary** built out-of-tree from `git show HEAD:src/<f>` (nm: 0 `undo_shield`
symbols): `RESULT: FAIL`, **12 rows red** (X1, X2, X2b, X3, X4, X4b, X7 ×5, X8).
Confirmed independently by two agents. The 30 `S`-rows stayed green because they
read the repo's *sources*, which carry the fix — stated so nobody mistakes it
for vacuity.

---

## Decisions (ladder rung, and the rejected alternative)

1. **[L1 / I6] CORRECTIVE: the C hierarchy walk shields its own `push_undo`/
   `pop_undo` pair from `xctx->no_undo`.** I6 says a hierarchy walk restores its
   flags and `sch_path` on every exit path; `global_*_netlist` **is** a hierarchy
   walk and today delegates that restore entirely to `pop_undo`, which the flag
   disables. **REJECTED:** making the walk refuse or raise when `no_undo` is set —
   rung L3, user-visible, and it breaks every caller that legitimately wraps a
   walk in `no_undo 1` (core `xschem.tcl:3572` `proc traversal`, both PDK walks).
   Refusing to netlist is a worse answer than netlisting correctly.
2. **[L2] BOTH defensive and corrective, not either. REJECTED:** defensive-only
   (guard the deref and stop) — it converts a loud failure into a silent one,
   which RULING D5-1 already rules is worse. Row **X2** exists so that conversion
   cannot pass.
3. **[L2] The core never clears, forces or restores `keep_symbols`, and
   `scheduler.c:7611` is not touched. REJECTED:** forcing `keep_symbols=0` for the
   walk's duration (it is a documented user preference; with the shield in place a
   leaked `keep_symbols` is measurably inert). **ALSO REJECTED:** "fix the load
   path", which this issue's own title implies — measured wrong twice.
4. **[L2] The shield is gated on `global` where every pop is inside `if(global)`,
   unconditional where it is not. REJECTED:** clearing `no_undo` unconditionally
   everywhere — it would push an undo slot on a non-global netlist where no pop is
   owed. Pinned by X6/SV7.
5. **[L2] Fix all three guard-after-deref sites in one commit. REJECTED:** filing
   them and leaving them — a guard sitting *below* the dereference it guards is
   worse than no guard, because the next reader reads it as protection.
6. **[L2] Clamp `stored_flags` in all five netlisters. REJECTED:** spice-only —
   a class fixed in one of five copies is a class still open.
7. **[L2] The new rows live in `tests/headless/test_undo_link_symbols.tcl`.
   REJECTED:** `test_op_annot.tcl` — the defect is not OP annotation, that file is
   already 6129 lines, and `test_undo_link_symbols` is literally the `.ptr = -1`
   suite, already carries the `exec timeout 45 $xschem …` child idiom the rows
   need. **CONSEQUENCE: acceptance must name `test_undo_link_symbols` explicitly**,
   because neither `run.sh` nor `run_regression.tcl` enumerates it.
8. **[L3 — USER-VISIBLE, STATUS E]** A **global** netlist taken while
   `xschem set no_undo 1` is in force now pushes one undo slot where it previously
   pushed none, and leaves the document intact instead of replaced. Implemented as
   the least-surprising option. **The question owed to a human:** *may
   `xschem set no_undo 1` disable the netlister's internal document save/restore?*
   X0498 ruled no. **Measured price, and it is bigger than "one slot"** — on
   `bandgap_opamp` (75 instances), 10 netlists: **disk undo 204 ms vs 36 ms
   (~6×, one gzip subprocess per push); memory undo 73 ms vs 31 ms (~2.4×)**.
   Correct runs (`no_undo=0`) are unchanged (192 vs 206 ms). The regression lands
   precisely on the batch-netlisting workflow that sets `no_undo` **for speed**.
   **REJECTED:** leaving `no_undo` authoritative over the netlister (keeps both
   the SIGSEGV and the silent document swap).

   > ### RULED BY THE USER 2026-08-22 — accepted, and the cost is now issue 0611
   >
   > **The shield is ratified.** A global netlist under a leaked or deliberate
   > `no_undo=1` pushes one undo slot and keeps the user's document, at a measured
   > ~17 ms on a 75-instance cell.
   >
   > **The user declined both horns of the question as framed.** It was put as
   > *who pays* — accept the cost on `no_undo` runs, or make the netlister refuse
   > to run. The ruling instead recorded that the walk's save/restore should not
   > be going through the **user-facing undo path at all**: nothing can ever undo
   > *to* that slot (`pop_undo(2, 0)` consumes it in the same call), so forking
   > `gzip` for it (`src/save.c:4744`) is waste.
   >
   > **And the framing understated the scope.** The row above reads as a
   > `no_undo`-only regression, but its own third measurement says otherwise:
   > correct runs were 206 ms before and 192 ms after — **unchanged, because they
   > were already paying the gzip.** X0498 did not add that cost; it removed the
   > one escape hatch that skipped it. The tax is on *every* global netlist anyone
   > has ever run, and it scales with cell size.
   >
   > Filed as **0611**. Whatever replaces the push/pop pair must stay immune to an
   > editing flag — the property is what X0498 ruled on, not the mechanism.
   >
   > `owed.sh clear rule X0498` — answered, 2026-08-22.

---

## The sabotage matrix

Seven planned variants plus one added by the sabotage agent. Every variant was
applied to source, rebuilt, run, and reverted; baseline green was re-confirmed
after restore.

| variant | what it breaks | predicted red | observed red |
|---|---|---|---|
| **SV1** shield no-op | `undo_shield_push()` returns without clearing | X2, X2b, X3, X3b | **7** — X2, X2b, X7 ×5. **X3/X3b did NOT red** |
| **SV2** unguard hilight | `if(0) continue;` in `draw_hilight_net` | X8 | **2** — X8, S1d. X8's child carries a genuine `FATAL: signal 11` |
| **SV3** SV1 + SV2 | both halves | X1, X2, X3, X4, X7 | **13** — X1, X2, X2b, X3, X4, X4b, X7 ×5, X8, S1d. X1's child reproduces the original crash verbatim, 5/5 |
| **SV4** shield pop no-op | `undo_shield_pop()` empty | X4 | **1** — X4 (S3 stays green, which is why X4 probes by EFFECT) |
| **SV5** unclamp `stored_flags` | spice restore loop reverted | S2 spice + valgrind | **1** — S2 spice only. **valgrind did NOT red** |
| **SV6** reorder back | `draw.c` guard back below the deref | S1a + valgrind | **1** — S1a only. **X8 stayed green** |
| **SV7** widen shield | drop the `global ?` gate in spice | X6 | **1** — X6 |
| **SV8** full revert to HEAD (extra) | all 11 C sources restored | — | **32** — X1, X2, X2b, X3, X4, X4b, X7 ×5, X8, S1a-d, S2 ×5, S3 ×11. X5/X6 correctly stayed green (regression guards, green on the unfixed binary by design) |

### ⚠ Predicted reds that did NOT appear — the 0499 lesson applied

* **SV1 predicted X3/X3b (netlist byte-identity) red; they stayed GREEN.**
  Measured cause: the netlist file is written **during** the descent, so the
  emitted deck is genuinely byte-identical even with the shield disabled — the
  damage is purely to the in-memory document afterwards. **X3 does not guard the
  corrective half at all**; it only reds as a side effect of the process dying
  (SV3, SV8). The shield's real guardians are **X2, X2b and X7 ×5**.
* **SV5 predicted a valgrind `Invalid read` and it did not appear.** The
  shield-off + clamp-reverted combination was built, both edits confirmed in
  source, and valgrind on the repro child reported `ERROR SUMMARY: 0 errors from
  0 contexts` (document corrupted 1 → 100 instances, no crash) — because the
  over-read sits behind `if(!inst[i].color)` and freshly-loaded instances carry
  `-10000`. **This kills the plan's nominated oracle.**
* **SV6: X8 stayed green**, so the three guard-after-deref reorders have no
  behavioural in-suite oracle either.

### ⚠ WHAT CANNOT FAIL BEHAVIOURALLY — say it out loud (issue 0499)

**The `stored_flags` clamp and the three `draw.c`/`psprint.c`/`svgdraw.c`
reorders have SOURCE-TEXT guardians only** (rows S2 ×5 and S1a-c). They grep the
repository's sources, not behaviour, and they stayed green against the pristine
pre-fix binary. They red on a revert of the source, which is the thing they were
written to catch — but nobody should read them as behavioural coverage.

**One agent conflict, recorded rather than smoothed over:** the Implement agent
measured SV3 as **not** reproducing X1 (green 3/3, because SV3 retains the
`stored_flags` clamp and the clamp alone suppresses the crash) and built the
pristine-HEAD binary as the substitute proof. The sabotage agent measured SV3 as
reproducing X1 **5/5, deterministically, with the original crash verbatim**. Both
transcripts exist. The reconciling reading is that the crash under *partial*
sabotage is heap-layout sensitive; the **pristine-HEAD run (SV8) is the
unambiguous proof** and is the one to repeat.

---

## Still open

Filed during this fix, **not fixed** (per the step's scope):
**0600** `proc traversal` in core `src/xschem.tcl` leaks all three flags on a
raise; **0601** `test_undo_selection.tcl` litters the repo root with
`untitled~.sch`; **0602** the emergency-save path itself fails during this crash.
`sky130A/sky130_procs.tcl:99-108` and `ihp-sg13g2/sg13g2_procs.tcl:351-361`
remain on **0431**, untouched.

Residual risks the adversary measured and could not close:

* **The unbound-instance deref class is closed only at the four sites touched.**
  `xctx->sym[xctx->inst[i].ptr]` is still dereferenced unguarded in `move.c`
  (12 sites), `editprop.c` (6), `save.c:4328`, `netlist.c` and `select.c:1507`.
  A 22-operation battery reached none of them with `ptr < 0`, so there is no
  counterexample — but the class is **narrowed, not eliminated**, and the fix's
  own comment ("test the flag BEFORE the deref, never after") is advice those
  files do not follow.
* **The stock-cell corruption transcript could not be reproduced by the
  adversary.** Driving the sky130 path with zero hand-set flags gave 75 → 75
  instances on **both** binaries, not the 75 → 13 the Measure agent recorded.
  The synthetic fixture reproduces both failures cleanly and is what the suite
  guards; the stock-cell number rests on one transcript and should be
  re-measured before it is quoted as fact.
* **`descend` → `go_back` leaves the top-level buffer reporting 0 instances** on
  the fixture, identically on both binaries and with no flags leaked — neither
  caused nor fixed here. `go_back` has its own `pop_undo`-shaped restore that
  this change does **not** shield; if it is disableable the same way, the same
  silent-document-loss class is still open on that verb.
* **The shield writes back through the CURRENT global `xctx` at pop time.** If a
  walk could switch context (tab/window), the caller's ctx would keep
  `no_undo=0` and another ctx would be clobbered. Untested rather than cleared —
  `xschem new_schematic create|switch` returned rc=1 headless.
* **`push_undo()`'s own failure latch is now silently overwritten.** On `popen`
  failure `save.c` sets `xctx->no_undo=1` to disable further attempts;
  `undo_shield_pop` at the walk's tail restores the caller's value, so the core
  forgets that undo is broken and retries on every subsequent push. Theoretical,
  but it is a behaviour the shield changes and nothing records it.
* **`INST_UNBOUND(n)` does not parenthesize its argument.** Correct at all four
  current call sites (bare `n`/`i`), but it sits in `xschem.h` beside the
  `IS_LABEL_*` family that the next caller may hand an expression.
* **The `stored_flags` clamp is NOT "unreachable by construction"**, as the plan
  claimed. With `split_files` on and the Tcl `netlist` proc overridden to load a
  bigger sheet (the C walk `tcleval`s it from inside the descent, between the
  `calloc` and the restore loop), the instance count grew 1 → 100 across the walk
  on both binaries. A real behavioural row for the clamp **is** constructible.
* **PRE-EXISTING, UNFILED, in both binaries:** PS export emits 41 out-of-range
  RGB triples per page (e.g. `16.0664 0 3.22514e+06 RGB`) on nand2/dlatch/bandgap.
  The count is identical fixed vs pre-fix, so not caused here — but the garbage
  *value* differs between binaries while being deterministic within one, which
  means any byte-exact PS golden would be code-layout dependent. Worth a number.
* **Test-environment integrity, operational:** during verification the working
  tree cycled through four sabotage variants and `src/xschem` was rebuilt at
  least four times. **Any tier measured without recording the binary's md5 inside
  such a window is untrustworthy.** Serialize the sabotage agent against the
  measuring agents.
