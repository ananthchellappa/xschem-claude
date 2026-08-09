# 0258 — ASE-L `render_deck` emits a `print` per output, dumping **every transient point** to the log; `result_probe` can match none of it, and `execute_fileevent` then forks `ps` ~49k times ingesting it

Status: **OPEN** — measured with a controlled pair (deck with vs without the `print` lines), cause
and both call sites identified, fix not implemented. **Major on usability**: a 2 µs transient
produces a **49.9 MB** log and spends **minutes** in xschem's pipe reader for **zero** extracted
results.
Area: `src/ase.tcl:1326-1330` (the `print` loop in `ase::backend::ngspice::render_deck`; intent
stated at `:1232`), `src/ase.tcl:1400-1414` (`result_probe`), amplified by
`src/xschem.tcl:242-262` (`execute_fileevent`).
Tests: none. No test in `tests/` runs an ASE transient and inspects the log size or the results
dict, so the whole surface is unmeasured.
Found: 2026-08-08, building the mixed-signal reference testbench
(`doc/claude/specs/mixed_signal_signal_browser.md` §E9).
Related: `doc/claude/specs/ase_l.md` (the `result_probe` design this was built for),
issue **0210** (ASE `pre_commands`). Numbered 0258 to leave a gap above `github/open_pdk`'s
current maximum (0248) so the next merge needs no renumbering.

## What it does

`render_deck` appends, after the analyses, one `print` per saved output:

```tcl
foreach o [ase::state_get $state outputs] {
  if {[ase::state_get $o save 0] eq {1}} {
    lappend lines "print [ase::backend::ngspice::print_arg [dict get $o expr]]"
  }
}
```

The stated purpose (`src/ase.tcl:1232`) is *"a print per saved output for log-based result
probing"*. That is correct for an **operating point**, where `print clk` emits one scalar line
`clk = 1.5` — exactly what `result_probe` parses.

For a **transient**, `print` emits a paginated table of every point instead.

## Measured

Reference run: `xschem_libraries_oa/ngspice_verilog_cosim_ase/tb_counter_wrapper`,
`tran 10p 2u`, 7 saved outputs, 200,386 points.

```
tb_counter_wrapper_ase.log     49,922,360 bytes    1,475,399 lines
tb_counter_wrapper_ase.raw     20,840,786 bytes    (the actual data, written anyway)
```

The log is 2.4× the raw. Its content:

```
Index   time            clk
--------------------------------------------------------------------------------
0	0.000000e+00	0.000000e+00
1	1.000000e-13	0.000000e+00
```

Controlled pair — same deck at `tran 10p 500n`, the only difference being `sed '/^print /d'`:

| deck | wall clock | log |
|---|---|---|
| with the 7 `print` lines | 1.00 s | 12,250,260 bytes |
| without them | 0.64 s | **2,822 bytes** |

**4,342× the log for the same simulation.**

## It extracts nothing

`result_probe` (`src/ase.tcl:1400`) matches a **scalar** line:

```tcl
set pat [format {^\s*"?%s"?\s*=\s*([-+]?[0-9.]+(?:[eE][-+]?[0-9]+)?)\s*$} $esc]
```

Hits in the 49.9 MB transient log:

| output | matches |
|---|---|
| `clk` | 0 |
| `count_out3` | 0 |
| `SUM` | 0 |
| `i(vamm)` | 0 |

Zero. The 49.9 MB is not "expensive but useful" — it is pure waste. Every byte is produced,
piped, buffered and regex-scanned to return an empty results dict.

## The amplifier: ~49,000 `ps` forks

This is where the minutes actually go, and it is a **separate defect** that this issue merely
triggers. `execute_fileevent` (`src/xschem.tcl:242-262`) is xschem's pipe reader:

```tcl
append execute(data,$id) [read $execute(pipe,$id) 1024]
...
set lastproc [lindex [pid $execute(pipe,$id)] end]
set ps_status [exec ps -o state= -p $lastproc]     ;# per 1024 bytes read
```

**1024 bytes per event, and a fork+exec of `ps` on every one of them.**

```
49,922,360 / 1024 = 48,752 fileevent iterations, each forking ps
```

At a few ms per fork that is the observed multi-minute gap between the co-simulation finishing
and the raw file appearing. It also builds a ~50 MB Tcl string in `execute(data,$id)`, which
`ase::run_done` hands to `result_probe` whole.

⚠ Fixing only this issue's `print` loop leaves the reader unfixed: **any** verbose simulator
output pays the same 1-`ps`-fork-per-KB tax. That deserves its own issue number — the read chunk
should be far larger, and the zombie check should not be per-read.

## A second, pre-existing correctness bug in the same block

The `print` lines are emitted **once, after all analyses** (the analyses loop ends at
`src/ase.tcl:1325`; the `print` loop starts at `:1326`). ngspice's `print` operates on the
**current plot**, which is the *last* analysis that ran.

So for a state with `op` **and** `tran` enabled, the prints read the *tran* plot and
`result_probe` returns nothing — the operating-point values it exists to extract are
unreachable. Only an `op`-alone state probes correctly.

Verified by reading the emission order; the `op`+`tran` combination has **not** been run, so
treat that half as inferred rather than measured.

## Fix sketch (not implemented)

The probe is a *scalar* mechanism, so it should only be emitted when the last-running analysis
yields scalars:

1. Emit the `print` block **only when the last enabled analysis is `op`** — the one case
   `result_probe` can parse. For dc/ac/tran, skip it entirely; the values live in the raw file,
   which the waveform viewer already reads.
2. If per-analysis probing is wanted, move each `print` group *immediately after its own
   analysis* inside the `.control` block, which also fixes the current-plot bug above.
3. Do **not** substitute `print > file` or `wrdata` — that reintroduces the same volume, just
   somewhere else. There is nothing to extract from a sweep by this mechanism; `meas` is the
   right primitive if a transient scalar is ever needed.

Worth pinning with a test that asserts the log stays under some sane bound for a transient with
saved outputs — the current regression surface for this is empty.
