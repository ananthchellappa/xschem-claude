# 0915 — a re-run that lands inside the SAME SECOND and writes the SAME number of bytes is invisible, so the sheet keeps the previous run's numbers

STATUS: **OPEN — measured 2026-08-28 on the delivered item-B1 tree, filed not
fixed.** PRE-EXISTING; not introduced by 0910 or 0914. It has been named as a
known limitation in three places since the 0684 fix
(`doc/claude/issues/0684-…md` §"what is not covered",
`tests/headless/test_annot_stale_0684.tcl`'s header, and `op_annot::_db_stat`'s
own comment) but has never had an issue number, so nobody could be given it.
This file is that number.
FOUND IN: `op_annot::_db_stat`, `src/op_annot.tcl` — the freshness stamp is the
pair `{mtime size}` and nothing else.
RELATED: [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md) (the
stamp), [0910](0910-an-operating-point-attached-from-outside-is-trusted-forever-at-the-same-path.md)
(which narrowed the window to the second press and later),
[0904](0904-the-cost-of-revalidating-was-published-on-the-axis-it-does-not-scale-on.md)
(the axis a content fingerprint would have to be paid for),
[0916](0916-a-symlinked-results-path-defeats-the-same-path-test-so-the-previous-runs-numbers-survive.md)
(the other way the same question answers "unchanged" about a file that changed).

---

## 1. What the user does, and what they see

A fast circuit. The user presses `6`, tweaks something, re-runs, and the
simulator finishes and rewrites the results file **inside the same wall-clock
second** with a file of **the same length** — which is what an operating point
over a fixed device list is: the numbers change, the layout does not. Press `6`
again and the schematic repaints the previous run's numbers under a sentence
saying they were already loaded.

Measured 2026-08-28, `--nogui`, on the delivered tree:

```
Z1| a re-run that lands in the SAME SECOND and writes the SAME number of bytes
Z1|   press 6            -> id = 10u | gm = 100u | gds = 1u
Z1|   disk now holds id=2e-05   (size 247 -> 247, mtime 1787978597 -> 1787978597)
Z1|   press 6 again      -> id = 10u | gm = 100u | gds = 1u
Z1|   status line        : Showing device operating-point values on the schematic. These results were already loaded.
```

That is RULING **D5-1** and invariant **I3** — *"not the previous run's
number"* — violated, by the same sentence 0684 was filed about. It is rarer than
0684's case and it is the same defect.

## 2. Why

`op_annot::_db_stat` (`src/op_annot.tcl`) is the whole of the freshness test:

```tcl
proc op_annot::_db_stat {np} {
  ...
  if {[catch {file mtime $np} m]} { return {} }
  if {[catch {file size $np} s]} { return {} }
  return [list $m $s]
}
```

Tcl's `file mtime` answers **integer seconds** (measured: `1787978597`). So two
writes in one second are one observation, and the size term only helps when the
length moved. Guard **G3b** in `op_annot::db_current` then finds the stamp still
matching and answers "current", and `cadence::annot_mode` takes the `live` arm
without ever re-reading the file.

## 3. What issue 0910's fix did and did not do to this

0910 made the **first** question about this surface's own candidate re-attach
instead of trusting a stamp minted at that first observation. That closes the
window for the first press after an attach from `Waves > Op Annotate` or
`Simulation > Graphs > Annotate Operating Point into schematic`. It does not
touch this: after that first press has written a stamp, every later press is on
G3b's cheap path, and a same-second same-size rewrite is invisible there exactly
as before. The transcript in §1 is the **second** press.

## 4. Why it is not fixed here, and what fixing it would cost

The only thing that sees a same-second same-length rewrite is the **content**.
The cheap end is a cheap digest of the bytes (or of the Values block), paid on
every press instead of a `stat`; 0684 §8's cost table measured a full re-read at
58 ms at 40 000 vectors, and **0904** is the record that that table was published
on the wrong axis, so the cost of a digest has to be measured on the axis that
actually scales before anything is chosen. Doing it inside this item would have
been an unmeasured performance change on the press path, on top of a behaviour
change the item was already making.

The other end — a completion event from the simulator — is rejected for the
reason 0684 records: xschem's own menubar run and any terminal-driven run have
no completion callback that reaches annotation, and hooking `proc simulate` is a
far larger blast radius than the defect.

## 5. Not covered by any row, deliberately

`tests/headless/test_annot_stale_0684.tcl` calls `f_bump` — a real 1.1 s
sleep — before **every** rewrite, and its header says why: without it the file
would measure this limitation instead of the defect it is about. So no row in
the tree fails on this, and none should be added that merely re-states the
limitation. A row is owed when a fix is chosen, and it must show the numbers
CHANGING after a same-second same-size rewrite.

## 6. Repro

`/tmp` probe, delivered tree, headless: stage `::netlist_dir`, write a 1-point
operating point, `cadence::annot_mode op`, then rewrite the same path with
values of identical text length **without sleeping**, and press again. The size
and mtime lines above are printed by the probe itself so the premise is visible
rather than assumed.
