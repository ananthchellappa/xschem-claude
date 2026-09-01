# 0489 — a bogus `.save` card is silent on stderr; `dims=0` in the raw header is the only detector

**Status:** open (a testing/diagnosis fact, not a code defect in this tree).
**Filed by:** step S3d of `doc/claude/specs/op_annotation.md`.

## What was measured

`/usr/local/bin/ngspice` (46+) and `/usr/bin/ngspice`, both under the
`.control … op … write out.raw … .endc` idiom every shipped PDK bench uses,
with the `.save` block at DECK level:

| block | rc | raw written? | stderr |
|---|---|---|---|
| `.save all` + N good device cards | 0 | yes | empty |
| `.save all` + N good cards + **ONE** bogus card | 0 | **yes** | **literally empty** |
| `.save all` + every device card bogus | 0 | **no** | `Warning from checkvalid: … is not available or has zero length.` + `Error during 'write': no writable vector found.` |

In the one-bogus case the raw gains a column **under exactly the requested
name**, holding zeros, marked `dims=0` in the header:

```
	2	@m.xnope.mzz[gm]	admittance	dims=0
```

## Two consequences for anyone writing an acceptance for a save-card generator

1. **A stderr check is blind in the realistic case.** It fires only when EVERY
   device card is bogus. The step brief for S3 prescribed exactly this detector
   ("capture ngspice's stderr and assert the values are not all zero"); it does
   not work.
2. **A raw-header NAME diff is blind too.** The name is present. Only the value
   and the `dims=0` marker differ.

`dims=0` is present on every bogus vector and absent on every genuinely-produced
one. It also catches a right-device / wrong-PARAM card: a level-1 MOS's `[vth]`
came back `v(@m.xm1.m1[vth]) voltage dims=0` on a REAL device while `[gm]` and
`[id]` were clean.

## Where this is now used

section X, row X3 of the S3 attempt-4 acceptance — **reverted with it (0494)** and
preserved in `0494-attempt-4-reverted.patch` — with its own non-vacuity
control (the same deck plus one deliberately bogus card must make the detector
fire). Row X4 additionally asserts the values are non-zero and finite, because a
full column of 0.0 is a FAIL and not a pass.

## Related

Issue 0434 records that the failure MODE depends on the ngspice invocation
idiom. This issue records that the DIAGNOSIS channel does too, and which one is
reliable.
