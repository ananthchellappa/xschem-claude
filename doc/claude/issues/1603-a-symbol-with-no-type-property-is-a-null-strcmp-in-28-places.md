# 1603 — a symbol with no global-attribute record is a NULL `strcmp`: 2 real sites of 26 candidates

**STAMP:** `v1 claim=fixed tree=73ebbfa0 stamped=2026-09-24 fix=taken open=0 by=driver`

**Status: CLOSED 2026-09-24** — batch `doc/claude/issue_1603_batch/`. Four guards landed, the
invariant that protects everything else is documented in the source, and
`tests/headless/test_typeless_symbol_1603.tcl` fences all of it with 9 rows, every one shown to
redden. Existing behaviour is unchanged: `tests/netlist_diff/netlist_diff.sh` reports
**BYTE-IDENTICAL across 905 netlists** (186 schematics × 5 back ends, `ERRORS=0`, both arms).

⚠ **The file name says "28 places" and that number was wrong.** It is kept because other
committed documents reference this path; the issue's identity is its number. The measured figure
is **2 driven defects and 2 more patched as defence-in-depth, out of 26 candidates.**

**Filed 2026-09-22** by the driver, from a crash the headless-crashes batch's Map crew found,
recorded and explicitly declined as out of its class.
**Class** NULL dereference on an optional symbol property.
**Related:** **1607**/**1353** (the heap over-read in the same family of back ends, closed in
`97766c66`), **1492**/**1493** (the display-crash class this was found beside and is *not* a
member of). Receipt: `doc/claude/headless_crashes_batch/receipts/A-map.md` §3, item 5.

---

## What this issue got wrong, corrected by measurement

### 1. "A symbol with no `type=` property" does NOT produce a NULL

This was the premise, and it is not sufficient. Read, then driven under gdb:

* `load_sym_def()` (`src/save.c`, cases `'K'` and `'G'`) does
  `load_ascii_string(&symbol[symbols].prop_ptr, …); if(!symbol[symbols].prop_ptr) break;` — and
  only *then* calls `set_sym_flags()`.
* `load_ascii_string` ends in `my_strdup`, whose comment reads *"empty source string →
  dest=NULL"*. So an empty global-attribute record yields `prop_ptr == NULL`, and the `break`
  skips `set_sym_flags` entirely.
* `set_sym_flags()` (`src/actions.c`) does
  `my_strdup2(_ALLOC_ID_, &sym->type, get_tok_value(sym->prop_ptr, "type", 0))`. `get_tok_value`
  **never returns NULL** — it returns `""` for a missing token — and `my_strdup2` duplicates the
  empty string.

So `prop_ptr == NULL` ⟺ `set_sym_flags` was skipped ⟺ `type == NULL`. **The reachable NULL state
is a symbol whose `G`/`K` record is empty or absent**, not one that merely lacks `type=`. A symbol
carrying any other property gets `""` and is harmless.

**This matters for anyone writing a fixture**: a `.sym` with a `K {format=… template=…}` record
and no `type=` is a *control*, not a repro. The committed suite names them `noprop.sym` and
`someprop.sym` so the distinction cannot be lost again, and carries two control rows asserting the
fixture really is what it claims.

### 2. The netlister cluster was the wrong priority — it holds ZERO driven defects

This issue argued the 19 netlister sites were the reason it mattered, and the driver repeated that
argument when recommending the work. The count was right; the implication was not. Of those 19:
**14 already guard** (an `if(!…type) continue;` or `break;` one to four lines above, in the same
loop body), **2 are commented-out code** whose live sibling is an explicit `!= NULL`, **1 must stay
unguarded** (below), and **2 needed a guard** — one of which this issue could not see at all.

### 3. Sixteen of the twenty-six were mis-classified, not one

The issue conceded a single false positive (`spice_netlist.c:96`). There are **sixteen**, and at
the sweep's own commit `d9f45e8f` **six** were guarded on the *immediately preceding* line
(spice 398/399, spectre 250/251, tedax 183/184, vhdl 43/45, 581/582, 590/591). A two-line context
window should have cleared six, not one. `git diff --stat d9f45e8f HEAD` shows those files
unchanged, so this is a flaw in the original classification rather than drift.

### 4. The sweep's method was the real defect — it is blind to the macros

A `strcmp(…type…)` regex cannot see `IS_LABEL_OR_PIN` or `IS_PIN` (`src/xschem.h`), which expand
to unguarded `strcmp`. That blind spot hid **the site that actually faults first**. Swept properly:
8 `IS_LABEL_OR_PIN` uses → exactly **one** unguarded; 10 `IS_PIN` uses → **all guarded**. One decoy
worth recording: `findnet.c:293` looks like a second unguarded use and is a non-site twice over —
inside `#if 0` **and** guarded by `if(!type) continue;` two lines above.

---

## The invariant that protects almost everything, and the single token it rests on

`prepare_netlist_structs()` calls `reset_caches()`, which calls `set_sym_flags()` on **every**
symbol unconditionally — `prop_ptr == NULL` included. **It converts `type == NULL` into `type ==
""` before any netlister, hilighter or net-resolver site is reached.**

Instrumented, with a symbol whose `prop_ptr` is NULL at load: 5 netlisters × 3 schematics +
`list_nets` = 260 visits, 216 on the typeless symbol, **zero NULL**. A broader driver covering
delete+undo, redo, `copy_objects`, `descend`/`go_back`, `check_unique_names` and reloads — the
`in_memory_undo` and `copy_symbol` paths — gives **1576 visits, 1312 typeless, zero NULL**.

⚠ **That safety is one token wide.** Flipping `set_sym_flags`'s `my_strdup2` to `my_strdup` — the
spelling used almost everywhere else in this tree, which NULLs an empty source — produces two
sequential gdb-confirmed segfaults, at `netlist.c` `set_lab_or_pin_inst_attr()` first and
`instcheck()` once the first is guarded, then a clean run once both are. That is why the two
netlister guards below are defence-in-depth **backed by a measurement rather than by style**, and
it is the deterministic sabotage the suite's static rows use.

Both `set_sym_flags()` and the `reset_caches()` call site now carry a comment saying so.

---

## The two DRIVEN defects

### `scheduler.c`, `xschem_cmds_s()`, the `sch_pinlist` branch — TRUE HEADLESS, two lines of Tcl

```
#0 __strcmp_avx2 ()   #1 xschem_cmds_s (…) at scheduler.c:12142   #2 xschem (…) at scheduler.c:15297
```

`if( !strcmp((xctx->inst[i].ptr + xctx->sym)->type, "ipin") ) dir="in";` inside
`for(i = 0; i < xctx->instances; ++i)`, with no `type` test in the branch. Driver:
`xschem load` then `xschem sch_pinlist`.

The two `else if` arms read the same pointer, so **one test must cover all three** — guarding only
the first makes the second the crash site, confirmed by sabotage. Fixed by hoisting the pointer to
a local and wrapping all three arms: a typeless instance leaves `dir` NULL and is skipped by the
existing `if(dir)` gate, which is already what happens to every other non-pin instance. Measured
byte-identical output on pinned schematics.

### `draw.c`, `draw_temp_symbol()` — the guard named the WRONG FIELD

```c
(xctx->hide_symbols==1 && (xctx->inst[n].ptr+ xctx->sym)->prop_ptr &&
 !strcmp( (xctx->inst[n].ptr+ xctx->sym)->type, "subcircuit") ) ||
```

`prop_ptr`, not `type`. `draw_symbol()` has the same expression written correctly against `type`.
On a freshly loaded typeless symbol `prop_ptr` is *also* NULL, so the `&&` short-circuits and the
wrong guard accidentally holds; `xschem setprop symbol … device widget` sets `prop_ptr` **without**
calling `set_sym_flags`, breaking the coupling, and the next `select_all` with `hide_symbols == 1`
dies. Fixed to match its twin, with a comment on both saying they must agree.

`prop_ptr` was not load-bearing and is not kept: `type == "subcircuit"` implies a non-NULL
`prop_ptr`, because the only two writers of `type` are `set_sym_flags()` (which requires
`prop_ptr`) and `copy_symbol()` (which copies both).

**`show_unconnected_pins` is the same site, not a second one.** `draw_temp_symbol()` has exactly
one caller, `draw_selection_impl()` in `move.c`; both doors arrive through it. Driven on the
pristine binary — `FATAL: signal 11`; patched — completes.

## The two patched as DEFENCE-IN-DEPTH

* **`netlist.c`, `set_lab_or_pin_inst_attr()`** — `IS_LABEL_OR_PIN(…type)` with no NULL test. The
  **only** unguarded use of that macro in `src/*.c`; the other seven all write
  `type && IS_LABEL_OR_PIN(type)`. It **dominates** the site this issue listed nearby, so that one
  could never have faulted first.
* **`netlist.c`, `instcheck()`** — `int bus_tap = !strcmp(…type, "bus_tap");`, a declaration
  initialiser that runs before every early return.

## One site that MUST STAY UNGUARDED, and it is the one this issue warned existed

The `strcmp(…, "label")` inside `set_lab_or_pin_inst_attr()`'s guarded block computes a variable
named `port`. A blanket `type ? strcmp(type,"label") : 1` would read *"typeless ⇒ not a label ⇒ it
IS a port"* — **false**. It is also dominated by the guard above it, so it needs nothing. This is
exactly what the issue meant when it said a blanket `type ? type : ""` "would answer all 28 at once
and would be wrong wherever the absence means something other than 'not that type'". A comment now
sits there saying so, so the next reader does not "fix" it.

Two in-tree precedents for the considered form, both by authors visibly thinking about this case:
`move.c`'s `if(!sym->type || strcmp(sym->type, "label")) return -1;` and `check.c`'s
`return type && !strcmp(type, "label");` under the comment *"unlinked symbol: no type to ask
about"*.

## The remaining candidates, accounted for

| count | class |
|---|---|
| 16 | false positives — a dominating guard in the same loop body, or commented-out code |
| 3 | `token.c` printers, unreachable by **caller contract**: every caller gates on `type` (`vhdl_netlist.c`, `verilog_netlist.c`, `tedax_netlist.c`, all `if( type && …)`). Also unreachable *structurally*: giving a symbol a `*_format` attribute to select the primitive path makes `prop_ptr` non-NULL, which makes `type == ""` |
| 2 | `scheduler.c` `else if` arms downstream of the fault — covered by the same fix |
| 2 | reached and survived, measured at `type == ""` |
| 1 | must stay unguarded (above) |

## The fence — `tests/headless/test_typeless_symbol_1603.tcl`, 9 rows, registered in `hcases`

`cases=` 97 → **98**, `blocks=` 96 → **97**, `skips=` **8** with the dev display up (9 without,
naming the one display row).

Behavioural rows assert the **exit code** and the absence of a column-0 `FATAL: signal` marker as
well as the answer — xschem traps SIGSEGV, prints that marker and exits 1, so a dead child's
output line is *absent* and a text-only diff would score the death green. The sabotage output
`pinlist=<<<absent>>> done=0` is exactly that shape.

⚠ **The static rows must strip comments, and this is not optional.** Every guard they assert is
quoted in prose in the source comment directly above it, so without the strip all four rows would
be satisfied by their own documentation. They reuse the `live_code` approach from row `V27` of
`test_ps_valid_1350.tcl` — block comments removed, `#if 0` regions removed by a depth counter,
whitespace collapsed — which exists because a whole-file regexp was once green on a file whose live
code had been deleted, thanks to a `#if 0` copy.

Sabotage: reverting each patch reddens its own row and names it; guarding only the first `sch_pinlist`
arm still reddens; and **the decisive pair** — with the `my_strdup2` flip applied, the netlisters
run **clean with the guards in place** (`ok=5/5`) and **segfault on the first back end without
them** (`ok=0/5`). That is what makes the two defence-in-depth guards load-bearing rather than
decorative.

## Out of scope, found while working, not patched

1. `vhdl_netlist.c` reads `xctx->sym[i]` on two lines inside a `j` loop whose other lines read
   `xctx->sym[j]`; the analogous loop earlier in the file uses `j` throughout. Suspected `i`/`j`
   mix-up, unverified behaviourally.
2. `instcheck()` and the `sch_pinlist` branch both index `xctx->sym[…]` with no `ptr >= 0` test
   (the issue **0498** class; `ptr == -1` is a real state — `draw_temp_symbol()` opens with
   `if(xctx->inst[n].ptr == -1) return;`).
3. `xschem show_unconnected_pins` **blocks indefinitely** on a display when the schematic
   references a symbol file that cannot be found. Measured on the **pristine** binary: still
   running after 150 s at ~0 CPU, so blocked rather than spinning, and unrelated to these patches.
   Most likely a modal dialog a `--pipe` script cannot answer, i.e. possibly not a defect at all;
   the dialog was not identified.
