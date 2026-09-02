# 1243 — the Outputs pane's Value column is blank whenever a transient is enabled

**Status:** FIXED (2026-09-02)
**Found by:** the user, on their own `tb_bandgap` in sky130 — *"in the ASE-L
output pane, nothing is displayed for values if both OP and TRAN are enabled,
whereas, if only OP is enabled, then values are displayed after simulation."*

## What the user sees

The Outputs pane has a **Value** column, filled in after a run from the deck's
`print` lines. With **only** the operating point enabled it shows numbers. Tick
the transient as well — nothing else changed — and every Value cell goes empty.

## Why

`print` reads whichever plot the simulator is standing in, and the deck's
`print` lines were anchored to **the last analysis in the canonical order
`op dc ac tran`**, i.e. the transient whenever one was enabled.

`ase::backend::ngspice::result_probe` accepts one shape and one only:

```
<expr> = <number>
```

On a multi-point plot `print` does not emit that. It emits a paged table:

```
Index   time            vbg
--------------------------------------------------------------------------------
0	0.000000e+00	4.496521e-19
1	1.000000e-10	4.497966e-19
…
```

Measured on the user's own run log (`~/.xschem/simulations/tb_bandgap_ase.log`,
2026-09-02): **20,514 rows per printed output, 108,275 log lines** for five
outputs, and `result_probe` extracts **nothing at all** from any of them. The
scalar column had never had a value to show for a transient — it was not a
regression, it was a column that only worked when the operating point happened
to be the last analysis in the list.

## The ruling

**Which analysis the Value column reads was an open question, deliberately
left to the user.** Issue 0967 measured both candidate answers and chose
neither; it only froze the answer against an unrelated checkbox (Save All >
save device operating-point parameters), and section P of
`tests/headless/test_ase_optier_0963.tcl` said so in as many words:

> `## 0967 IS NOT BEING SETTLED HERE. Which analysis the Outputs Value column`
> `## reads is the user's ruling to make.`

It was never put in front of the user — no `rule` debt was recorded for it — so
it sat in a test comment for three days until they hit it on the bench. That is
the process defect underneath the code one.

The ruling, made 2026-09-02: **the prints follow the operating point whenever
one is enabled.**

## The fix

`src/ase.tcl`, the ngspice backend's `render_deck`: the print anchor is computed
over `{dc ac tran op}` — the canonical order with `op` moved LAST, so
last-enabled-wins selects it whenever it is enabled.

* The operating point is the only analysis in the set that yields a scalar, so
  "prefer the last analysis" was preferring the one answer that cannot be read.
* **Nothing displayed changes value.** With op+tran the column was EMPTY before
  this change, so no number is replaced by a differently-measured one — a number
  appears where there was none, and it is the operating point's. That is what
  keeps this clear of ruling D5-1.
* With the operating point **off**, the two orders select the same analysis, so
  every op-less deck — transient-only included — renders **byte-identically**.

Measured end-to-end with ngspice-45.2 on the user's own netlist, full 200 µs
transient, both analyses enabled:

| | before | after |
|---|---|---|
| `vbg = …` scalar in the log | absent | `vbg = 1.195979e+00` |
| all five outputs resolved | 0 of 5 | 5 of 5 |
| `Index …` tables | 5 | 0 |
| log lines | 108,275 | **232** |
| plots in the raw | 2 (`Transient Analysis`, `Operating Point`) | 2, unchanged |

The ~102,000 discarded table rows were the bulk of a 3.5 MB run log.

## Still open — and on the ledger

**A transient-only run's Value column is still blank**, unchanged. What a scalar
column should show for a waveform — the final point, the value at t=0, or
nothing — is a separate ruling, recorded as a `rule` debt rather than guessed
at. Guessing would put an unlabelled number beside a row, which is the defect
0967 was filed about. Row **P4** pins the current shape so that whoever answers
it has to come here and say so.

## The rows

`tests/headless/test_ase_optier_0963.tcl` section P (P1, P2, P3, P4) and row
E17.

* **P1** — device requests moved, operating point last: the prints sit after its
  write, at the end of the deck.
* **P2** — the control, tick off, operating point FIRST: the prints follow it
  there, and the transient that runs after them does not take the column. This
  is the row that says the anchor is the enabled set, not the emit order.
* **P3** — op-only and no-analysis-at-all: unchanged.
* **P4** — transient-only: unchanged, still blank. The open half.
* **E17** — 0967's own claim, which outlives the ruling: the answer comes from
  the enabled set, so moving the device requests cannot move it.

## Not this issue

Two other symptoms reported in the same message were **measured and are not
tool defects** — see `doc/claude/code_analysis/1243_op_values_differ_between_runs.md`.
