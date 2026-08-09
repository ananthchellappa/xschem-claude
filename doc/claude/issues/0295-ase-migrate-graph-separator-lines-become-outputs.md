# 0295 — `ase_migrate` turns a graph widget's `----` separator lines into outputs, silently

Status: OPEN
Filed: 2026-08-08, from the section-E work on `doc/claude/specs/mixed_signal_signal_browser.md`
(the spec records this as item **E10**).
Component: `tools/migrate/ase_migrate.py`
Related: 0278 (ASE-L `render_deck` print flood), `doc/claude/specs/ase_l.md` ("Migration tool")

## Symptom

Migrating a testbench whose `flags=graph` widget uses `----` rows as visual separators
produces ASE-L state outputs named after the dashes:

```
outputs {... {name o2 expr ----} ... {name o7 expr ---} ...}
```

`ase::backend::ngspice::render_deck` then emits `.save ----` and `print ----` into the deck.
This was hit for real on `xschem_libraries_oa/ngspice_verilog_cosim_ase/tb_counter_wrapper`
and hand-fixed in the committed state file; nothing prevents the next migration from
reintroducing it.

## Why it matters

A `.save <not-a-vector>` is not harmless. Measured previously with ngspice-42 (issue 0159's
evidence): as the **only** `.save` in a deck it aborts the whole analysis —
`no data saved for Transient analysis; analysis not run`; alongside a valid `.save` it is
dropped silently and the trace simply never appears. So the failure mode is either a dead
run or a missing waveform, neither of which points at the migrator.

## Root cause

`_row_outputs` (`tools/migrate/ase_migrate.py:718-760`) has three drop paths and a `----`
row hits none of them:

- the RPN-expression path needs whitespace in the row — `----` has none;
- the reference-line path needs `_RPN_NUM_RE` (`:679`,
  `^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?[A-Za-z]*$`) to match — a leading `-` must be
  followed by digits, so `----` fails it;
- `_graph_rows` (`:683-708`) only drops rows that are empty or whitespace.

so the row falls through to the final `return [(expr, 1, label)]`.

Reproduced by executing the module directly:

```
'----'   -> [('----', 1, None)]   warn=[]
'---'    -> [('---',  1, None)]   warn=[]
'-; 0.9' -> []                    warn=['graph reference-line constant is not a signal, dropped: -; 0.9']
graph_outputs('flags=graph node="clk\n----\ncount"')
      -> [('clk', 1, None), ('----', 1, None), ('count', 1, None)]   warn=[]
```

Note the empty `warn` list: the defect is **silent**, which contradicts the file's own
stated LOSSLESS-OR-LOUD discipline (`:519`).

## Fix sketch (not implemented)

- In `_row_outputs`, drop a row that contains no character capable of naming a vector —
  concretely, a row matching `^[-\s]+$` (any run of dashes/whitespace) is a separator.
  It is deliberately narrower than "no alphanumerics": `0` is a legal node name.
- Follow the file's discipline and `warn.append(...)` on the drop, as the reference-line
  path already does, so a migration report shows what was removed.
- Add the case to `test_ase_migrate.py` beside the existing reference-line case.

## Not this issue

The graph-widget side is fine: `----` is a legitimate separator row in a graph `node=`
list. Only the migration of that list into `outputs` is wrong.
