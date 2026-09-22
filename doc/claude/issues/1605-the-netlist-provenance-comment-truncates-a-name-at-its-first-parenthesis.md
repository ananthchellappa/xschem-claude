# 1605 — the netlist provenance comment truncates a name at its first parenthesis

**STAMP:** `v1 claim=open tree=005abc87 stamped=2026-09-22 fix=untried open=3 by=driver`

**Status: OPEN — filed 2026-09-22** by the driver, from the one loose end the 1604 crew
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
