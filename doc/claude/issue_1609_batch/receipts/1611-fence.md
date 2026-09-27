# Receipt — issue 1611, the fence

New suite: `tests/headless/test_vhdl_component_index_1611.tcl` (the only repo file this crew
created). `src/vhdl_netlist.c` was sabotaged twice and restored; it is byte-identical to how it was
found — `md5sum` `fa138402ab04e7ccb01561ae5b57a775` before and after, and `git status --porcelain
src/` is silent. Rebuilt after the restore; `make -C src` then says *Nothing to be done*.

Measured 2026-09-27 on the working tree at `9fa31dd0`. The 1611 fix, which the brief described as
uncommitted, **landed as `fdf876d3` while this crew was running**, so the working tree now matches
HEAD. The fix's bytes are the ones the brief described and the ones this suite was written against.

**Not registered** in `tests/run_regression.tcl`, per the brief. Checked that nothing in the tree
enforces registration structurally: no suite greps `tests/run_regression.tcl` for the presence of
its own name, so an unregistered suite in `tests/headless/` does not redden T1 today — it simply
does not run there. `hcases` alone is the right list (no display needed, one case, no skip).

---

## 1. Verdict

`ALL PASS (18 checks)` on every arm, all driven through the armed spelling
`tests/headless/run_suites.sh [--nogui] test_vhdl_component_index_1611`:

| arm | result |
|---|---|
| `--nogui` (dev display `:99` attached, engine arm) | ALL PASS (18 checks) |
| display arm (`:99`, no `--nogui`) | ALL PASS (18 checks) |
| `AUDIT_DISPLAY=none --nogui` (DISPLAY unset) | ALL PASS (18 checks) |
| `-n 2 --nogui` (back-to-back, scratch reuse) | 2/2 runs, 18 checks each |

**The suite needs no display.** Identical check count on all three arms, zero `skip:` lines, no
`toplevel`/`winfo`/`bind`/`event generate` anywhere in it. The whole thing is five VHDL netlist runs
plus a read of `src/vhdl_netlist.c` and the four sibling netlisters.

`FLOOR: 18 checks` is stated in the header (12 driven `L1`–`L8` + `D1`–`D4`, 6 structural `P1`–`P6`).

---

## 2. Sabotage → row mapping (driven, one access reverted at a time)

Each sabotage was a single `sed` on one line, followed by `make -C src` (which relinked) and a fresh
suite run. Restores were `cp` from a plain copy, never `cp -a`, so `make` always saw a newer source.

### Sabotage B — the `abs_path` handed to `check_lib(1, abs_path)`
`abs_sym_path(xctx->sym[j].name, "")` → `xctx->sym[i].name` (the `my_strdup2` line inside
`vhdl_block_netlist()`'s component loop). **5 FAILED (13 passed).**

| row | why it reddened |
|---|---|
| `L2` | `arch_midl` declared `{plug keep}` where the exclusion requires `{keep}` |
| `L4` | same, read as part of the "still a populated architecture" answer: `{-1 {plug keep} dsn}` vs `{-1 keep dsn}` |
| `P1` | the grep's fourth site became `{vhdl_block_netlist {for(j=…)} i}` |
| `P2` | the `sym[j].name, ""` site the 242523cb warning defends no longer exists, so its third element flipped |
| `P6` | one `xctx->sym[i]` back inside the component loop |

### Sabotage A — the `default_schematic` read
`get_tok_value(xctx->sym[j].prop_ptr, "default_schematic", 0)` → `xctx->sym[i].prop_ptr` (same
loop). **4 FAILED (14 passed).**

| row | why it reddened |
|---|---|
| `D1` | `arch_midd` declared `{dsi dsn}` where the attribute requires `{dsn}` |
| `L4` | its third element states `arch_midd`'s list too, so it caught this one as well |
| `P5` | the grep's third site became `{vhdl_block_netlist {for(j=…)} i}` |
| `P6` | one `xctx->sym[i]` back inside the component loop |

### Rows that reddened under NEITHER, by design
`L1`, `L3`, `L5`, `L6`, `L7`, `L8`, `D2`, `D3`, `D4`, `P3`, `P4`. These are the fixture's depth
guard, the controls that stop the subject rows passing vacuously, the pinned residual, the
top-level reference and the peer back ends. The header states this explicitly, with the mapping
above copied into it, so nobody reads their greenness as evidence about the fix.

`L4` and `P6` are the two rows both sabotages reach. `L4` because it states both mid-level component
lists in one answer — it is the row that says "the netlist is not empty for an unrelated reason", so
it has to look at both halves to say it. `P6` because it is the whole-loop invariant: zero
`xctx->sym[i]` anywhere inside `vhdl_block_netlist()`'s component loop.

---

## 3. The mandatory three-level fixture, and the two-level case driven

The fixture is authored at run time into `test_scratch` — nothing of it lives in the repo:

```
top.sch                      x1611mids/midl.sym|.sch   x1611excl/plug.sym|.sch   (excludable leaf)
                                                       x1611lib/keep.sym|.sch    (control leaf)
                             x1611mids/midd.sym|.sch   x1611lib/dsi.sym|.sch     (default_schematic=ignore)
                                                       x1611lib/dsn.sym|.sch     (identical, no attribute)
top2.sch                     x1611excl/plug.sym        (the TWO-level fixture, row L8 only)
```

Directory names are deliberately unmistakable strings because `xschem_libs` entries are Tcl
**regexps** matched by `check_lib()` against the whole absolute symbol path — a pattern like `lib`
would also match the scratch path and the repo path.

**The two-level claim is driven, not asserted.** Row `L8` states the answer from `top2.sch`, which
instances the excludable leaf directly. That answer was **identical on the fixed tree and under both
sabotages**: `arch_top2` declares `{plug}` with no exclusion and `{}` with it, and `entity plug` is
emitted or not accordingly. So a suite built on a two-level fixture reports `ALL PASS` against the
defect — only `global_vhdl_netlist()`'s top-level loop ever sees the leaf as a candidate there, and
that loop always spelled the access `j`. Row `L7` reads the emitted entity list
(`top midl midd plug keep dsn`) and reddens if the fixture ever flattens.

---

## 4. What the issue file got right, and three things it did not

**Refined, not refuted — the visible effect is narrower than "declared *and instantiated*".**
Issue 1611 §"What each one costs" says the excluded leaf "is declared *and instantiated* inside
`arch_mid`", and the brief asked for a row asserting the exclusion stops both. **Driven: the fix
stops the DECLARATION only. The instantiation remains.** The instance loop lives in the static
`vhdl_netlist()` and never calls `check_lib()`, so with `xschem_libs` excluding the leaf the
emitted `arch_midl` still carries

```
xplug1 : plug
port map (
   A => PLUGIN
);
```

with no `component plug` above it and no `entity plug` anywhere in the file. That is **not** a
regression and **not** something this fix introduced: it is exactly what the top level has always
done for a child excluded there, which row `L6` measures directly (`arch_top` declares nothing,
still instantiates `xmidl1 : midl` and `xmidd1 : midd`). The fix makes the two levels agree. Row
`L5` pins the residual as a row rather than leaving it in prose, so a future change to it reddens
something. The issue file's sentence is true of the *pre-fix* netlist — the leaf was declared and
instantiated — but a reader could take it as a statement of what the fix removes, and it removes
only the first half.

**A count in both the issue file and the shipped comment is off by one — FIFTEEN accesses, not
sixteen.** Issue 1611 opens with *"Sixteen accesses in that loop; fourteen use `j` and two use `i`"*,
and `src/vhdl_netlist.c`'s ISSUE 1611 comment repeats it as *"Fourteen of this loop's sixteen
accesses always used `j`"*. Counted on the comment-stripped loop region — extracted by brace depth
from the `for(j=0;j<xctx->symbols; ++j)` header, 59 lines, first line the `for(`, last line its
closing brace — there are **15** `xctx->sym[i|j]` accesses, so pre-fix it was **13 `j` and 2 `i`**.
This is exactly the trap `tests/headless/test_snprintf_fmt_1608.tcl` fences and CLAUDE.md names:
`/usr/bin/grep -c` over that region answers **13**, because it counts LINES, and exactly **two** of
those lines carry two accesses each — the `if(!xctx->sym[j].type || (strcmp(xctx->sym[j].type,…` test
and the `strcmp(…"subcircuit")==0 || strcmp(…"primitive")==0` pair. 13 lines, 15 occurrences, both
measured by the suite's own `cloop_body`/`scount` procs. A hand count reconciling two instruments
that disagree drifts. **So row `P6` asserts ZERO `xctx->sym[i]` in the loop instead of any total**:
that is the real invariant, it is unaffected by an innocent added line, and it reddens under BOTH
reverts. The suite header records the discrepancy. Correcting the two prose copies is left to the
driver — this crew's brief allowed it to touch only the new suite.

**A symbol-name slip in both the issue file and the shipped comment.** Both say the top-level
component loop lives in `vhdl_netlist()`. It does not: `vhdl_netlist()` is the `static` instance
printer at the top of the file, and the top-level component loop is inside
`global_vhdl_netlist()`. The project's own rule is to cite by symbol, so this is worth correcting in
`src/vhdl_netlist.c`'s ISSUE 1611 comment and in the issue file. **This crew did not touch either**
— the brief limited it to the new suite — so it is left as a note for the driver. The suite's own
header and rows name `global_vhdl_netlist()`.

**Everything else in the issue file reproduced.** Two of the loop's accesses read the parent while
every other one read the candidate; the `default_schematic` half being dead code (the parent's own value is tested near the
top of `vhdl_block_netlist()` and returns early — row `D4` fences that the early return still
works); `xschem_libs` honoured at the top level and dropped one level down; the two sibling loops
needing opposite indices, with `242523cb` having deliberately changed the descent loop from `j` to
`i`.

**Could not reproduce, and labelled so.** Nothing. The one thing the issue file itself declines to
drive — that the emitted file is *rejected* by a VHDL analyser — this crew also did not drive, for
the same reason: there is no `ghdl` and no `nvc` on this machine. Both the suite header and row `L5`
mark it **derived**. What is driven is that the file names an entity it does not emit.

**Not chased.** Issue 1611 open item 2 (the `found` test compares `sym[j].name` against
`inst[l].name`, so a synthetic symbol from an instance-level `schematic=` override never matches).
No row here depends on it.

---

## 5. Two facts about the fixture that cost time and are worth passing on

1. **A fixture symbol without a `template` produces a nameless component block.**
   `print_generic()` (`src/token.c`) returns before emitting the `component <name>` /
   `entity <name> is` header for a symbol whose `templ` is empty, and `src/vhdl.awk` then prints the
   whole region verbatim because it never sees an `entity … is` line to switch on. The first draft
   of this fixture had no templates and the emitted file carried an orphan
   `port ( … ); end component ;` with no name on it — so every component list read as empty and
   every row passed for the wrong reason. `template="name=x1"` on each symbol is load-bearing, and
   the suite says so at the `leaf_sym` proc.
2. **`src/parse_synopsys_vhdl.awk` is not in this path.** The VHDL post-processor `proc netlist`
   actually invokes is `src/vhdl.awk`; `parse_synopsys_vhdl.awk` lowercases everything and is not
   called. Names in the emitted netlist keep their case.

---

## 6. Reproducing this receipt

```sh
cd /home/analog/dev/xschem-claude
tests/headless/run_suites.sh --nogui test_vhdl_component_index_1611     # 18 checks
tests/headless/run_suites.sh        test_vhdl_component_index_1611     # 18 checks
AUDIT_DISPLAY=none tests/headless/run_suites.sh --nogui test_vhdl_component_index_1611

cp src/vhdl_netlist.c /tmp/keep.c                     # cp, NOT cp -a
# sabotage B: in vhdl_block_netlist()'s component loop, the my_strdup2 line
#   abs_sym_path(xctx->sym[j].name, "")  ->  xctx->sym[i].name
# sabotage A: in the same loop
#   get_tok_value(xctx->sym[j].prop_ptr, "default_schematic", 0)  ->  sym[i].prop_ptr
make -C src && tests/headless/run_suites.sh --nogui test_vhdl_component_index_1611
cp /tmp/keep.c src/vhdl_netlist.c && make -C src
```

Line numbers are deliberately absent: the two sites are inside
`vhdl_block_netlist()`'s `for(j=0;j<xctx->symbols; ++j)` component loop, each carrying an
`ISSUE 1611` comment block immediately above it.
