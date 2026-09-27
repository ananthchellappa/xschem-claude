# Plan — issue 1609, `my_snprintf` fetches every `long` as an `int`

**Target:** `doc/claude/issues/1609-my-snprintf-fetches-every-long-argument-as-an-int.md`
(`claim=open fix=untried open=3`). **Read issue 1608 and `doc/claude/issue_1608_batch/STAGE_C.md`
first** — this defect was found there, deliberately left, and named in that batch's carried-forward
list. The formatter's *format string* is now gated; this is about its *arguments*.

## Why this and not another open item

It needs no ruling from the user (the output is identical for every live value, so nothing visible
changes), it is one function that 1608 already built a suite around, and it is the last live
correctness item carried out of that batch. It is **latent**, and the honest reason it is latent is
worth stating: not that the code is right, but that x86-64's vararg slot layout hides it and all
three live values are small.

## What the driver measured before writing this plan

`src/util.c`'s `d/x/c/u` arm, verbatim:

```c
char nfmt[50], nstr[MY_SNPRINTF_NSTR];
int i, nlen, refuse;
i = va_arg(args, int);
...
nlen = sprintf(nstr, nfmt, i);
```

`my_snprintf_spec_ok()`'s whitelist admits `l` and `h`. Live `l` callers, three, all
`scheduler.c`: the `XMaxRequestSize` getter, the `XExtendedMaxRequestSize` getter (both pushing
`long`) and the window-id getter (pushing `(unsigned long)ctx->window`). Live `h` caller, one: the
first-selection getter's `%hu`.

## Stages

One crew per stage, one receipt each in `receipts/`. A crew reads `CREW_BRIEF.md`, its stage section
here, `DECISIONS.md`, and the **previous stage's receipt** — the corrections to this plan live in the
receipts. **The last four batches each had a crew catch the driver being wrong; that is the point,
and `DECISIONS.md` states this plan's prediction so it can be refuted rather than confirmed.**

### Stage A — measure the defect and the boundary

1. **Drive it.** Build a caller that pushes a `long` above `INT_MAX` through a real `my_snprintf`
   with `"%ld"`, in the built tree, **not** through a `sed`-extracted copy of the function (1608's
   receipts record an extraction producing a figure that was not a fact about the code). Report the
   verbatim output against what `sprintf` alone gives for the same value.
2. **Establish the `x`/`u`/`c` variants.** `%lx`, `%lu`, `%lc` all reach the same arm. Say which of
   them a live or plausible caller uses and what each does with an out-of-range value.
3. **Is `%hu` genuinely safe?** Verify the promotion argument rather than inheriting it from the
   issue, and say what `%hhd` would do (the gate refuses `hh`, per 1608 — confirm that it does).
4. **The `p` arm.** It fetches `va_arg(args, void *)` and the gate permits `l`, so `"%lp"` is
   accepted. Drive it. Say whether it is reachable, and whether it is even meaningful.
5. **Is any of this reachable from a file or the command line?** 1608 closed the five non-literal
   format sites. Re-derive that rather than inheriting it: if a format string carrying `%ld` can
   still come from outside the binary, the severity changes and this plan changes with it.
6. **What does the aarch64 claim actually rest on?** Quote the ABI document clause. ⚠ There is no
   aarch64 toolchain here, so this stays a **derivation** and whatever ships must say so — issue
   1606's adjudications C5 and C7 forbid upgrading one into a claimed measurement, and that batch
   shipped exactly that mistake about Win64.

### Stage B — the fix shape, and what it costs each way

1. **Fetch by modifier** (`va_arg(args, long)` when the spec carries `l`) versus **refuse `l` and
   rewrite the three callers**. Cost each. Note that the second option's `%lu` of an XID becomes
   `%u` of a cast, which is the same accident written out by hand — say whether that matters.
2. If fetching by modifier: the arm has **one** variable. Say how the branch is structured without
   duplicating the whole arm, and whether `%lx`/`%lu` want `unsigned long` separately from `%ld`'s
   `long` or whether one fetch serves both.
3. **C89.** No `long long`, and `%lld` must therefore be refused, not implemented. Confirm the gate
   already refuses it (1608's whitelist admits `l` — check whether it admits `ll`).
4. Whether this changes anything a user sees. If the answer is yes for any reachable value, stop and
   say so: that would make it a ruling, and the driver files it.

### Stage C — implement and fence

Per the brief: **a behavioural row is the backbone** — `my_snprintf` is directly callable, so a row
can drive a `long` above `INT_MAX` and assert the output. ⚠ **No live caller reddens**, because
every live value is small, so a row that only exercises the three real getters fences nothing. Say
in the row's own comment that it drives a planted value and why it has to. Extend
`tests/headless/test_snprintf_fmt_1608.tcl` rather than adding a suite, unless there is a reason not
to — say which and why. Every guard gets a row that reddens on **its own** single removal.

### Stage D — gate

T1 in a **fresh clone of the commit, built from scratch, solo, throwaway home, at a SHORT path**
(`/tmp/g1609`, 10 characters). Baseline to beat: `cases=100 blocks=99 counted_failures=0 skips=8`
(`results.3131395.log` at `2fbfa809`, `wc -l` 299, `elapsed=594s`). Extending an existing suite
costs no case and no skip. ⚠ **`skips=8` has held for six figures by coincidence of what was
registered, not by property** — read the trailer, never check against the number.
