# 0991 — the `short` half of the do-not-write marks has no test row, and dropping it makes the netlist warning name a format that writes the instance as a wire

**Filed** 2026-08-30, by the S4d sabotage pass.
**Status** FIXED 2026-08-30 by the S4d repair pass (rows only; the code was already right). **Class** unwitnessed guard half (issue 0986's rule), RULING D5-1.
**Subject** `src/token.c`, `ua_reach()`'s four `ua_backend_carries()` calls.

## What a designer sees

A symbol may be marked so that one netlist format writes the instance out as a
plain wire instead of as a cell — the mark is `vhdl_ignore=short` (also
`verilog_ignore`, `spectre_ignore`, `tedax_ignore`). A cell written as a wire
carries none of its settings, exactly like a cell that is not written at all.

GUARD UA-IGNORE reads TWO flag bits per format for that reason:

```c
ua_backend_carries(inst, "vhdl_format", VHDL_IGNORE | VHDL_SHORT, 1, 0, tok)
```

`VHDL_IGNORE` comes from `vhdl_ignore=true` (or `=open`); `VHDL_SHORT` comes
from `vhdl_ignore=short` (`src/actions.c:1044-1047`, `:1140-1143`; consumed by
`skip_instance2()` and `src/netlist.c:1233`).

**No test row can see any of the four `| *_SHORT` terms.** Every fixture in
`tests/headless/test_unused_attr_0970.tcl` spells the mark `=true`;
`grep -c _short` on that file is 0.

## Measured

Mutation `SAB-short_VHDL` — delete `| VHDL_SHORT`, rebuild, run the suite:

    RESULT SAB-short_VHDL rc=0 ok=57 nfail=0 allpass_banner=1 REDDENED=[ ]

Deleting all four at once is also 57/57 green. So is each one alone.

A fixture that shows the harm — a one-pin subcircuit whose template declares
`knob`, whose symbol carries `vhdl_ignore=short`, on a sheet that sets
`knob=99`:

* **Shipped code, correct.** `a Verilog netlist of the same cell does carry it`.
* **`| VHDL_SHORT` deleted.** `a VHDL or Verilog netlist of the same cell does
  carry it, so deleting it would break that.`
* **Ground truth.** The VHDL netlist of that sheet contains `knob` NOWHERE; the
  Verilog netlist contains `.knob ( 99 )`.

The mutated sentence is a claim about the user's own design that nobody
measured — RULING D5-1 — and it ships with every check green.

## Fix

One extra instance on the UN4 sheet spelled `vhdl_ignore=short`, asserting the
carrier clause is exactly `Verilog`. Repeat for the other three marks, or put
all four on one sheet of four cells.


---

# FIXED 2026-08-30 — the S4d repair pass

**No code changed here.** The four `| *_SHORT` terms were correct; what was
missing was any sheet that spelled the mark that way. `grep -c _short` on the
suite was 0 and is now 5.

## The fixture

One sheet, `uajoin_top.sch`, five copies of one cell. The cell `uajoin` is
deliberately carried by ALL FOUR backends — its own Spectre and tEDAx lines
read `@knob` and its template declares `knob`, so VHDL and Verilog pass it in
as a generic/parameter. The first copy is plain; each of the other four carries
exactly ONE mark spelled `short`. Every row demands the whole carrier phrase
verbatim, so the row can only pass if the right netlist dropped out.

| copy | mark | the sentence must read | row |
|---|---|---|---|
| xJN | none | `Spectre, VHDL, Verilog or tEDAx` | UF29 |
| xJH | `vhdl_ignore=short` | `Spectre, Verilog or tEDAx` | UF30a |
| xJV | `verilog_ignore=short` | `Spectre, VHDL or tEDAx` | UF30b |
| xJS | `spectre_ignore=short` | `VHDL, Verilog or tEDAx` | UF30c |
| xJT | `tedax_ignore=short` | `Spectre, VHDL or Verilog` | UF30d |

Each row also asserts the control setting beside it still gets the accusing
sentence, so a silence cannot pass by the whole copy having been skipped.

## Measured — one mutation per build, `cp` then `touch`, never `cp -p`

    MUT SHORT-vhdl    => RESULT: 1 FAILED (65 passed) | reds: UF30a
    MUT SHORT-verilog => RESULT: 1 FAILED (65 passed) | reds: UF30b
    MUT SHORT-spectre => RESULT: 1 FAILED (65 passed) | reds: UF30c
    MUT SHORT-tedax   => RESULT: 1 FAILED (65 passed) | reds: UF30d

Each of the four halves is now seen by exactly one row, and by a different one.

## The half nobody had noticed at all

The same fixture is the first sheet in this tree, shipped or fixture, that
produces more than TWO carriers — so it is also the first witness the JOIN has.
`ua_carriers()` word-matches the four names independently and scores the same
answer whatever separator was used, so the `", "` branch was executed by nothing
and `a VHDL, Verilog netlist` could have shipped past every check. Rows UF29 and
UF30a-d lift the phrase verbatim through a new `ua_carrier_phrase()`:

    MUT SEP-empty (", " -> "")     => reds: UF29 UF30a UF30b UF30c UF30d
    MUT SEP-noor  (" or " -> ", ") => reds: UF29 UF30a UF30b UF30c UF30d
