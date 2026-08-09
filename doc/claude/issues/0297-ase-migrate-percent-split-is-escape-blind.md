# 0297 — `ase_migrate`'s graph `%` split is escape-blind, so `\%` shreds the row

Status: **OPEN**. Pre-existing; **deliberately not fixed** under 0295 (see the last section).
Component: `tools/migrate/ase_migrate.py` — `_row_outputs()`, the `%` partition at `:726-728`.
Authority for the correct behaviour: `find_nth()` `src/token.c:4229-4280` and `my_strtok_r()`
`src/util.c:159-191`, as called by `draw_graph()` (`src/draw.c:4990`, `:5017`, `:5020`, and five
more identical sites at `:3452/:3482`, `:5948/:5954`, `:6364/:6370`, `:7410/:7415`, `:8176/:8210`).
Found: 2026-08-09, in the adversarial review of 0295 item 5 (the `----` separator-row drop).
Related: 0295 (the sibling row-classification defect, FIXED), 0290 (the same "filed, not widened
into someone else's commit" call).
Numbered 0297: local tracker maximum is 0296, `github/open_pdk` is at 0263.

## Symptom

A graph `node=` row that escapes its percent sign — `\%`, a *literal* `%` in the expression —
is split at that `%` anyway. The half after it is thrown away as a nonexistent dataset selector,
a bare `\` survives into the migrated state as an output, and two warnings are printed that
misdescribe what happened.

## The shape of it

`_row_outputs()` partitions the row on the first bare `%`, with no escape check:

```python
# tools/migrate/ase_migrate.py:726-728
if "%" in core:
    core, _sep, tail = core.partition("%")
    warn.append("graph dataset/rawfile selector dropped: %%%s" % tail.strip())
```

xschem does not. `find_nth(str, sep, quote, keep_quote, n)` carries an escape flag `e`; a `\`
sets it and `continue`s, and the *next* character is then tested only in the `else` arm — the
`strchr(sep, str[i])` separator test is guarded by `!e`:

```c
/* src/token.c:4259-4267 */
if(!e && str[i] =='\\') { e = 1; continue; }
if(!e && !q && strchr(sep, str[i])) { ... }   /* <- escaped char never reaches here */
```

`my_strtok_r()` (`src/util.c:172-181`) does the same for the row split one level up. `draw_graph()`
calls it as `find_nth(ntok, "%", "\"", 0, 2)` for the dataset half and
`find_nth(ntok, "%", "\"", 4, 1)` for the expression half; when the dataset half comes back empty
it uses the row **verbatim** (`src/draw.c:5020`, `my_strdup(..., &ntok_copy, ntok)`).

## Repro (measured, this tree, 2026-08-09)

`find_nth` compiled standalone, verbatim from `src/token.c:4229-4280` with only the allocator
wrappers stubbed:

```
row  = SUN \%; SUN 100 *
  dataset  find_nth(row,"%","\"",0,2) = []                          <- no selector
  expr     find_nth(row,"%","\"",4,1) = [SUN \%; SUN 100 *]         <- whole row

row  = TEMPERAT%0
  dataset  find_nth(row,"%","\"",0,2) = [0]                         <- a REAL selector
  expr     find_nth(row,"%","\"",4,1) = [TEMPERAT]
```

The migrator, on the same two rows:

```
$ cd tools/migrate && python3 -c "import ase_migrate as m; w=[]; \
    print(m._row_outputs('SUN \\\\%; SUN 100 *', w)); print(w)"
[('SUN', 1, None), ('\\', 1, None)]
['graph dataset/rawfile selector dropped: %; SUN 100 *',
 'graph expression not saveable as one vector, keeping its operands (SUN, \\): SUN \\']
```

Both warnings are false. Nothing was selecting a dataset, and the expression whose operands were
"kept" is the truncated `SUN \`, not the row's actual expression `SUN 100 *`.

## Why it is reachable, not theoretical

The row is committed, three times over. `xschem_libraries_oa/ngspice/solar_panel/schematic/
solar_panel.sch:141`, with byte-identical copies at `xschem_library/ngspice/solar_panel.sch:141`
and `xschem_libs_newsym/ngspice/solar_panel/schematic/solar_panel.sch:141`:

```
node="Panel power; i(Vpanel) v(PANEL) *
Led power; i(Vled) v(LED) *
Avg.Pan. Pwr; i(Vpanel) v(PANEL) * 20u ravg()
SUN \\\\%; SUN 100 *"          <- four backslashes on disk; `SUN \%; SUN 100 *` after get_tok
```

End to end:

```
$ python3 tools/migrate/ase_migrate.py --sch \
    xschem_libraries_oa/ngspice/solar_panel/schematic/solar_panel.sch --pdk sky130 --dry-run
...
WARN: graph dataset/rawfile selector dropped: %; SUN 100 *
WARN: graph expression not saveable as one vector, keeping its operands (SUN, \): SUN \
```

A non-dry run writes, into `<out>/solar_panel/ngspice_state1/solar_panel.state`:

```
outputs {... {name SUN expr SUN save 1 plot 1} {name o9 expr \\ save 1 plot 1} ...}
save_all_v 1
```

and `ase::backend::ngspice::render_deck` turns every `save 1` output into a deck line
(`src/ase.tcl:2285`, `lappend lines ".save [dict get $o expr]"`), so the deck gets `.save \`.

## Honest qualification — what is and is not lost, on this cell

On `solar_panel` specifically **no trace is actually lost**. The discarded expression `SUN 100 *`
has exactly one operand, `SUN`, and `SUN` coincidentally reappears as the truncated split's first
half — so the state still carries `{name SUN expr SUN save 1 plot 1}`. What lands is the extra
`\` output plus the two warnings that misdescribe the event.

That is luck, not design. On any escaped-`%` row with a richer expression the operands are lost
outright, and the row's *legend label* is promoted to a saved vector in their place. Measured:

```
row='LEG \%; i(V1) v(A) *'
  out = [('LEG', 1, None), ('\\', 1, None)]      <- i(V1) and v(A) gone; LEG is a LABEL
```

Also worth stating plainly, so nobody over-rates the blast radius on `solar_panel`: that state has
`save_all_v 1`, so `render_deck` emits `.save all` (`src/ase.tcl:2281`) *ahead* of the per-output
lines. Per 0295's own ngspice-42 evidence (from 0159), a `.save <not-a-vector>` alongside a valid
`.save` is dropped silently; it aborts the analysis outright only when it is the *sole* `.save`.
So on this cell the failure mode is noise, not a dead run.

## Fix, when someone takes it

`_row_outputs()` must split on the first **unescaped** `%`, the way `find_nth` does, and must not
warn when there is no selector to drop:

```python
_PCT_RE = re.compile(r"(?<!\\)%")               # find_nth's `!e` guard, token.c:4259-4263
mo = _PCT_RE.search(core)
if mo:
    core, tail = core[:mo.start()], core[mo.end():]
    if tail.strip():                            # a trailing `%` selects nothing
        warn.append("graph dataset/rawfile selector dropped: %%%s" % tail.strip())
```

A single negative lookbehind is *not* quite enough on its own: `\\%` — an escaped backslash
followed by a real separator — **is** a genuine selector to `find_nth`, and the lookbehind would
refuse it. Measured on the standalone `find_nth`:

```
row  = a\\%0    dataset = [0]        expr = [a\\]      <- real selector, lookbehind misses it
row  = a\%0     dataset = []         expr = [a\%0]     <- literal %, lookbehind gets it right
```

Whether that shape is worth handling is the implementer's call — it occurs in no committed cell,
and `_graph_unescape()` (`:716-720`) is already approximate about doubled backslashes. If it is
handled, count the backslash run and split only on an even-length one.

Two further things the fix owes:

- The surviving `\%` must be unescaped to a literal `%` before the expression reaches
  `_graph_unescape()`/`_mk_name()`, or the output name and `.save` line keep the backslash.
- Regression checks, beside the existing G5 (`TEMPERAT%0`, which must stay green): a `\%` row
  yields the row's real operands and **no** "selector dropped" warning; and the committed
  `solar_panel` cell migrates with no `\` output and no bogus warning. `xschem_library/ngspice/
  solar_panel.sch` is the smallest of the three copies to point a fixture at.

## Deliberately not fixed under 0295

0295's stated scope is one row classification: drop rows matching `^[-\s]+$` and warn. This is a
second, independent defect in the same function that happens to have been found while reviewing
that change. Widening the commit to cover it would be a silent scope expansion — the same call
0290 made when the VCD reader work uncovered the `table` half of its dispatch bug, and for the
same reason: which pre-existing defects get swept into a scoped change is the user's decision,
not the implementer's. 0295 ships as scoped; this issue holds the evidence so the next person
starts from a measurement rather than a suspicion.

## Not this issue

A **bare** `%` used as an RPN modulo operator (`a b %`) is eaten by xschem too — `find_nth` treats
it as a separator wherever it appears, so `draw_graph` sees the expression `a b ` and the operator
is simply not available in a graph row. Measured: `find_nth("a b %", "%", "\"", 4, 1)` -> `a b `,
dataset half empty. The migrator's operand list for that row (`a`, `b`) therefore matches xschem;
only its "selector dropped: %" warning is spurious. The defect in this issue is specifically the
**escaped** `\%`, which xschem honours as data and the migrator does not.
