# 1635 — `xschem raw new` returns success for a database it failed to allocate, and its help text's point count is not the one the code computes

**STAMP:** `v1 claim=open tree=a90ffb98 stamped=2026-10-02 fix=none open=3`

Status: **OPEN**, found 2026-10-02 by the calculator batch's recon stages while establishing whether
`raw new` is a usable destination for a computed wave. Pre-existing; no Calculator change caused it.

Area: `new_rawfile()` — `src/save.c` — and the `new` arm plus the `raw new` help block of the
`raw` dispatcher in `xschem_cmds_r()`, `src/scheduler.c`.
Found: `env -u DISPLAY ./src/xschem --pipe -q --nogui --script …`, three calls and a control

## Part 1 — the point count is computed before it is checked, and a negative one is allocated

`new_rawfile()` opens with

```c
int number = (int)floor((end - start) / step) + 1;
```

and never tests `number`. It is then handed straight to four `my_calloc`/`my_realloc` calls, stored
in `raw->allpoints` and `raw->npoints[0]`, and used as a `for` bound. `ret` is initialised to `1`
and the only thing that can clear it is the registry being full.

Measured, two ways of getting a nonsense count, both answering **success**:

```
=== A: end < start ===   xschem raw new backw.raw distrib vs 1.0 0.0 0.1
my_calloc(0,): allocation failure -9 * 8 bytes
my_calloc(0,): allocation failure -9 * 8 bytes
rc=<1>
xschem raw points -> 0-9                    (two concatenated values: dataset 0 has -9 points)
xschem raw values vs 0 -> {}                (empty string)
xschem raw info -> 0 current | 0 backw.raw distrib

=== B: step == 0 ===     xschem raw new zstep.raw distrib vs2 0.0 1.0 0.0
my_calloc(0,): allocation failure -2147483647 * 8 bytes
my_calloc(0,): allocation failure -2147483647 * 8 bytes
rc=<1>
xschem raw points -> 0-2147483647
llength [xschem raw values vs2 0] -> 0
```

`(1.0 - 0.0) / 0.0` is `+inf`; `(int)floor(inf)` is implementation-defined and lands on
`INT_MIN`/`INT_MAX`-adjacent garbage, here `-2147483648 + 1`.

**No crash, and that is the problem.** The two `my_calloc` diagnostics go to the debug channel, the
verb answers `1`, the database is **registered and current**, and every subsequent read answers the
empty string. A caller that checks the return value — which is the only thing a return value is
for — concludes it has a database. It takes a *separate* `xschem raw points` call, and the
knowledge that a point count can be negative, to find out otherwise.

Control: `xschem raw new ok.raw distrib vs4 0.0 1.0 0.1` answers `1` and `raw points` answers `11`.

## Part 2 — the help text's formula is not the code's, and the code's is not robust to binary floating point

The help block in `xschem_cmds_r()` says:

> `xschem raw new name type sweepvar start end step`
> create a new raw file with sweep variable 'sweepvar' with number=(end - start) / step datapoints

`(end - start) / step` and `floor((end - start) / step) + 1` differ by one for every well-formed
request: the control above is **11** points where the help says 10. That is the smaller half.

The larger half is that `floor` over a binary-floating-point quotient loses a point whenever the
quotient lands just below an integer, which for decimal steps is most of the time:

```
xschem raw new fp.raw distrib vs3 0.0 0.3 0.1
rc=<1>
xschem raw points -> 3
xschem raw values vs3 0 -> 0 0.1 0.2
```

`0.3/0.1` is `2.9999999999999996`, so `floor` gives 2 and the sweep stops at **0.2** — the endpoint
the caller asked for is **not in the database**, silently, with a success return. Whether `end` is
meant to be inclusive is itself not stated anywhere; the `+ 1` says inclusive and the arithmetic
delivers it only when the division happens to come out exact.

## Open items

1. **Validate before allocating, and report.** `step == 0`, a non-finite quotient, and
   `number < 1` are three refusals, and the verb has a return value to say so with. This is the
   item with the value in it: a caller can then trust `rc`, which is what it is reading.
2. **Make the count robust, or document the truncation.** The usual spelling is to divide, add a
   relative epsilon before flooring, and clamp — or to round rather than floor when the quotient is
   within a few ulps of an integer. ⚠ **This changes the point count of existing well-formed
   calls** (`0 → 0.3` step `0.1` becomes 4 points, not 3), so it is a behaviour change and not a
   repair; whoever takes it says so out loud. Nothing in the tree is known to depend on the
   off-by-one, but nothing has been measured either.
3. **The help text.** Whatever item 2 settles, the sentence `number=(end - start) / step` is wrong
   today by one for every call, and it does not say whether `end` is included. One sentence fixes
   it, and it is worth doing first and separately, because the help block is what the next caller
   reads — the same reasoning issue 1631 gives for `pos_at`'s help.

## What this is NOT

Not a memory-safety defect as measured. `my_calloc` with a negative size refuses, prints, and
returns without allocating, and the `for(i = 0; i < number; i++)` fill loop does not execute for a
negative `number`, so nothing was written out of bounds in any of the three runs. The reachable
consequence is a registered, current, unreadable database that reports success — which is worse
than a crash only in that nothing notices.

Not a duplicate of issue 1632 (`raw values` reading `npoints` out of bounds for an out-of-range
*dataset*). This is the same field reached from the other side: 1632 reads `npoints[]` past its
end, this one puts a negative value *into* `npoints[0]`.
