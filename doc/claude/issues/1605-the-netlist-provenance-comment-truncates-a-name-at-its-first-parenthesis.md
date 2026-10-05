# 1605 — the netlist provenance comment truncates a name at its first parenthesis

**STAMP:** `v1 claim=fixed tree=bafa9c1e stamped=2026-10-05 fix=taken open=0 by=driver`

**Status: FIXED 2026-10-05.** Originally filed 2026-09-22 by the driver, from the one loose end the 1604 crew
named and deliberately did not touch: *"`sanitized_abs_sym_path` in `src/actions.c`
carries the same unanchored `regsub {\(.*}`, unguarded. I did not measure whether a
user-named file can reach it. If it can, it is a sibling of 1604 and wants its own
number."*
**Class** the same over-broad pattern as **1604**, in C, on a different path, with a
different consequence.
**Related:** **1604** (**FIXED** in `005abc87` — the same pattern in `is_xschem_file`,
where it made the Insert dialog refuse a file; its survey established the grammar this
one should also agree with).

---

## The site — READ at `005abc87`

```c
const char *sanitized_abs_sym_path(const char *s, const char *ext)
{
  tclsetvar("__san_symp_name", s ? s : "");
  tclsetvar("__san_symp_ext", ext ? ext : "");
  tcleval("abs_sym_path [regsub {\\(.*} $::__san_symp_name {}] $::__san_symp_ext");
  return tclresult();
}
```

`{\(.*}` is unanchored, so it eats the **first** parenthesis and everything after it,
exactly as 1604's did. 1604's survey settled what the pattern *should* be — the ERE
`is_generator` in `src/token.c` enforces, `^[^ \t()]+\([^()]*\)[ \t]*$` — and this site
has not been brought into line with it.

⚠ Note the guard here is **not** the one 1604 left in place elsewhere. The two surviving
unanchored occurrences in `src/xschem.tcl` sit inside `if {[xschem is_generator …]}`, so
C has already established the string is head-then-arguments and the patterns cannot
differ. **This one has no such guard**, which is what makes it a defect rather than a
duplicate.

## It is reachable, and from the operation this program exists to perform

Five callers, all netlisters, and every one of them writes the result into the netlist as
a provenance comment:

| caller | line it writes |
|---|---|
| `src/spice_netlist.c` ×2 | `** sym_path: …` / `** sch_path: …` |
| `src/spectre_netlist.c` ×2 | `// sym_path: …` / `// sch_path: …` |
| `src/verilog_netlist.c` ×2 | `// sym_path: …` / `// sch_path: …` |
| `src/vhdl_netlist.c` ×2 | `-- sym_path: …` / `-- sch_path: …` |
| `src/tedax_netlist.c` ×2 | `## sym_path: …` / `## sch_path: …` |

The arguments are `xctx->sym[i].name` and the schematic `filename` — user-chosen names.
So the trigger is *netlisting a design that instances a symbol whose file name contains a
parenthesis*, which after 1604 is a thing xschem now happily opens.

`src/actions.c`'s own comment above this function says the trigger is reached "many times
through `sanitized_abs_sym_path` in the netlisters" and is "strictly worse than the Graph
dialog's (issue 0821), which at least needs the dialog opened" — written about a
different property of the same function, and equally true of this one.

## What is NOT measured here, and must be before it is fixed

1. **What the written line actually ends up saying.** The truncated name is passed to
   `abs_sym_path`, whose resolution of a nonexistent path has not been measured. It may
   emit a wrong-but-plausible path, an empty one, or the name unchanged. **The three are
   not equally bad and nobody has looked.** A wrong-but-plausible path is the worst case
   because a provenance comment exists to be trusted.
2. **Whether anything reads these lines back.** They are comments to SPICE, but this tree
   has back-annotation and hierarchy tooling; if any of it parses `sym_path:`, the
   consequence is larger than a cosmetic one.
3. **Whether a parenthesised name reaches it at all in practice**, now that 1604 lets such
   a file be opened. Before 1604 the dialog largely refused them, which may be why this
   was never seen.

## Still open

1. Measure the three questions above, starting with what the line says.
2. Bring the pattern into line with `is_generator`'s grammar, as 1604 did — and consider
   calling `is_generator` rather than re-spelling its ERE a third time. Row `S8` of
   `tests/headless/test_generator_paren_1604.tcl` already compares the Tcl spelling with
   the C ERE character for character; a third copy needs the same treatment or it will
   drift.
3. A test row. The cheap half is netlisting a fixture that instances a symbol named with a
   parenthesis and asserting the `sym_path:` line names the real file. That is headless
   and needs no display.

---

## 2026-10-05 — fixed, and the three open measurements are answered

### 1. What the line actually said: the WORST of the three outcomes

Measured by reproducing the function's own expression against the shipped
`abs_sym_path`:

| name | what the provenance line said |
|---|---|
| `opamp(rev2).sym` | `<cwd>/opamp` |
| `gen(a,b).sym` | `<cwd>/gen` |
| `dir(x)/thing.sym` | `<cwd>/dir` |
| `plain_name.sym` | `<cwd>/plain_name.sym` (unaffected) |

So it emitted **a wrong-but-plausible ABSOLUTE path**, with the parenthesis and
the extension both gone — and in the `dir(x)/` case it named a **directory** as
the source file. The issue called that the worst case because a provenance
comment exists to be trusted, and that is what it does.

### 2. Something DOES read these lines back, so it was never cosmetic

`op_annot.tcl` parses `** sch_path:` per block
(`regexp {^\*\* sch_path:[ \t]*(.*)$}`) and its own comment states the
consequence: *"After every descend the callee block's recorded `** sch_path:` is
compared with `xschem get schname`; a mismatch SUPPRESSES the subtree and
warns."* So **a schematic whose file name contained a parenthesis silently lost
operating-point annotation for its whole subtree** — a functional failure on the
ASE-L path, not a cosmetic comment. This is the measurement that changed the
severity, and it was only found because item 2 above was asked.

### 3. Whether such a name reaches it

Yes, and the suite demonstrates it: the fixture sheet instancing
`par(en).sym` **loads**, which it does only because issue 1604 stopped the
parenthesis being refused. That is very likely why this was never seen before.

### The fix

The strip is now gated on `is_generator()` — **called, not re-spelled**. Its ERE
`^[^ \t()]+\([^()]*\)[ \t]*$` already exists twice in the tree with row `S8`
of `test_generator_paren_1604.tcl` holding the two copies together; a third would
have needed the same treatment. ⚠ `is_generator(NULL)` is that function's
CACHE-FREE call rather than a predicate, so the null check has to come first.

Measured after the fix: a real generator `gen(a,b)` still resolves to `<cwd>/gen`
(the strip is preserved where it belongs) while `opamp(rev2).sym`,
`dir(x)/thing.sym` and `a(b)c(d).sym` all keep their full names.

Fenced by `tests/headless/test_sym_path_paren_1605.tcl`, 13 checks, `hcases`
alone. It netlists a real subcircuit hierarchy whose symbol file name carries a
parenthesis and reads the `** sym_path:` lines back out of the deck — the only
door to this C function from a suite, and the door the defect travelled.
Sabotage: removing the gate and rebuilding reddens `SP2` and `SP3`
(behavioural) plus `SP6b` (structural). A control row drives the OLD unanchored
expression on the same two names and requires it to differ, so `SP2`/`SP3`
cannot pass against no difference.
