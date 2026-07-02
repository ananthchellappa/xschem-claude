# Issue 0072 — `xschem setprop instance` hangs (infinite loop) on a heavily-churned buffer

**Opened:** 2026-07-02
**Status:** OPEN — pre-existing bug, surfaced while adding setprop self-logging (slice 5,
`doc/claude/code_analysis/action_log_ciw_coverage_and_virtuoso_parity.md` §9). NOT caused by
the logging change: the added `log_action_argv` line is at the setprop branch *tail* and is
never reached — the process is already spinning inside the instance commit code above it.
**Severity:** MEDIUM — a hard hang (infinite loop; the process must be killed, losing unsaved
work). Mitigated only by an obscure trigger: it needs a long accumulated edit sequence, not a
single operation. No wrong output or file corruption observed — it never returns.
**Branch:** `fluid-editing`.
**Source:** regression harness — `tests/headless/test_selflog_output.tcl` §3f originally ran
`xschem setprop instance 0 …` against the buffer the earlier sections had churned; the test hung.
The committed test reloads a clean `nand2.sch` before §3f, so the suite is green and this edge is
filed here instead.
**Affects:** the `xschem setprop instance` commit path in `src/scheduler.c`
(~`:7995`–`:8047`), specifically the code that runs **even with `-fast`**:
`hash_names(inst, XDELETE)` → `new_prop_string()` → `translate()` → `match_symbol()` →
`set_inst_flags()` → `hash_names(inst, XINSERT)`. Not in the `!fast`-only `symbol_bbox()`/`draw()`
tail (see §2). Likely a corrupted name-hash chain or symbol linkage rather than setprop itself.

---

## 1. Symptom

After a long sequence of edits on `nand2.sch`, a subsequent
`xschem setprop instance 0 <token> <value>` never returns — the editor spins at 100% CPU and
must be killed. On a freshly-loaded schematic the identical `setprop` completes instantly.

## 2. What is (and isn't) reproducible

Faithful headless reproducer (hangs — `pre3f` prints, the `setprop` after it never returns):

```tcl
xschem load xschem_library/examples/nand2.sch
xschem select_all; xschem delete; xschem undo; xschem redo; xschem select_all; xschem cut
xschem undo; menu_action_logged {xschem undo}
xschem log_action -reset; xschem redo; xschem log_action -reset; xschem get xorigin
foreach v {flip flipv rotate} {xschem select_all; xschem $v 10 20}
foreach v {flip_in_place flipv_in_place rotate_in_place align} {xschem select_all; xschem $v}
xschem select_all; menu_action_logged {xschem rotate 10 20}
xschem trim_wires; xschem break_wires; xschem break_wires 1; menu_action_logged {xschem trim_wires}
xschem set readonly 1
foreach v {flipv flip_in_place flipv_in_place rotate_in_place break_wires} {catch {xschem $v}}
xschem set readonly 0
proc keyev {ks st} { xschem select_all; xschem callback .drw 2 400 300 $ks 0 0 $st; update idletasks }
foreach {ks st} {70 0 102 8 82 0 114 8 86 0 118 8 117 8 38 0 33 0 33 4} { keyev $ks $st }
xschem setprop instance 0 tk vl   ;# <-- HANGS HERE
```

Run headless: `DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) --script <file>`.

**Minimization is fragile — and that is itself the clue.** None of these subsets reproduce it:

- the destructive ops alone (`delete`/`undo`/`redo`/`cut`/`undo`);
- the explicit-coordinate transforms alone (`flip`/`flipv`/`rotate`/`*_in_place`/`align`);
- the keyboard-driven transforms alone (the `xschem callback` key drives);
- `trim_wires`/`break_wires` alone;
- destructive + keyboard only; destructive + explicit-transforms only; transforms + keyboard only.

Only the **full accumulation** hangs. A trigger that needs the whole sequence, when no proper
subset does, is the signature of **progressive state corruption** — each class of op leaves the
in-memory structures slightly inconsistent, and the combination eventually produces a cycle (or a
never-terminating walk) that `setprop`'s commit path is the first to traverse.

## 3. Where the loop is (narrowed without a debugger)

`-fast` was the decisive probe. Repeating the exact churn above and then running

```tcl
xschem setprop -fast instance 0 tk vl   ;# ALSO HANGS
```

still hangs. `-fast` skips `push_undo()`, the leading `symbol_bbox()`, and the trailing
`symbol_bbox()`/`draw()`/`bbox()`. So the loop is **not** in the draw/bbox tail; it is in the
common commit code that both paths execute (`src/scheduler.c:8031`–`:8047`):

```c
hash_names(inst, XDELETE);
new_prop_string(inst, subst, tclgetboolvar("disable_unique_names"));
...
my_strdup2(_ALLOC_ID_, &translated_sym, translate(inst, xctx->inst[inst].name));
sym_number = match_symbol(translated_sym);
...
set_inst_flags(&xctx->inst[inst]);
hash_names(inst, XINSERT);
```

The strongest suspects are the ones that **walk a linked/hashed structure**: `hash_names()` (a
cyclic name-hash chain would spin forever) and `match_symbol()`/`translate()` (symbol-table
walk). `new_prop_string` (with `disable_unique_names` false → uniquification) also consults the
name hash. The churn that precedes it — repeated `undo`/`redo` (which free and rebuild the
instance arrays and their hashes), `cut`/`delete` (remove instances), and `break_wires` (deletes
wires) — is exactly the kind of thing that can leave a dangling or self-referential hash entry.

## 4. Suggested investigation

1. Build with a debugger available and attach to the hung process (`gdb -p <pid>`, `bt`) — the
   backtrace will name the spinning function in one step. (gdb was unavailable in the session
   that filed this; that is the only reason the loop was localized by elimination instead.)
2. Alternatively run the reproducer under `valgrind`/ASan, or add a bounded-iteration guard +
   `dbg()` to the `hash_names` chain walk and the `match_symbol` loop to catch the cycle.
3. Confirm whether the corruption is instance-0-specific (a bad `prop_ptr`/`name` on one
   instance) or global (a poisoned name-hash / symbol table) by trying `setprop` on a different
   instance index after the same churn.
4. Bisect the churn against the connectivity/undo invariants: does `xschem check` or
   `rebuild_connectivity` after the sequence (but before `setprop`) either hang too or *clear*
   the state? That isolates whether the culprit is the name hash, the spatial hash, or the undo
   restore.

## 5. Acceptance

`xschem setprop instance <n> <token> <value>` returns in bounded time regardless of the preceding
edit history. A regression driving the §2 reproducer and then asserting the `setprop` completes
(with a watchdog/timeout) would lock it. Relatedly, whatever structural invariant is being
violated should be restored by `undo`/`redo`/`cut`/`break_wires` so the corruption never
accumulates in the first place.
