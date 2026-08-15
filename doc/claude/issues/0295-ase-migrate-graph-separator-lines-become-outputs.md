# 0295 — `ase_migrate` turns a graph widget's `----` separator lines into outputs, silently

Status: FIXED (2026-08-09)
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

## Fix (implemented)

`tools/migrate/ase_migrate.py`:

- new `_GRAPH_SEP_RE = re.compile(r"^[-\s]+$")` beside the other row regexes, and a
  fourth drop path in `_row_outputs` placed **after** the empty-expression check and
  **before** the RPN-whitespace check, so `- - -` reads as a separator instead of as
  an RPN expression whose operand list happens to come out empty.
- the drop is LOUD: `warn.append("graph separator row is not a signal, dropped: %s")`,
  which reaches `MigrationReport.warnings` (`:974`) and prints as a `WARN:` line.
- **DECISION**: the regex is matched against the row's *expression* (`raw`), not the
  whole row. That is a superset of the sketch in the useful direction — `sep;----`
  dies too — while `-; 0.9` still reaches the reference-line path and `----;v(out)`
  keeps its signal (the dashes become only the legend name). Still deliberately
  narrower than "no alphanumerics": `0` is a legal node name.

Evidence, migrating the committed offender
(`xschem_libraries_oa/ngspice_verilog_cosim/tb_counter_wrapper`):

```
before:  extracted: outputs=8   {name o2 expr ---- save 1 plot 1}
                                {name o7 expr ---  save 1 plot 1}    (no WARN at all)
after:   extracted: outputs=6   WARN: graph separator row is not a signal, dropped: ----
                                WARN: graph separator row is not a signal, dropped: ---
         outputs {{name clk …} {name countout3 …} … {name ivamm expr i(vamm) …}}
```

`tools/migrate/test_ase_migrate.py`: G10b/G10c/G10d/G10e/G10f (unit rows, beside the
G10 reference-line case) and G17-G20 (the offender migrated end to end, asserting the
serialized state carries no dash-only output and that the report names both drops).
144 -> 151 checks, `RESULT: ALL PASS (151 checks)`.

## Not this issue

The graph-widget side is fine: `----` is a legitimate separator row in a graph `node=`
list. Only the migration of that list into `outputs` is wrong.
