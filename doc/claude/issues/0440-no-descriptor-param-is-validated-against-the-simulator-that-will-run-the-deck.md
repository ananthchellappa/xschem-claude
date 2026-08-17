# 0440 — no descriptor `param` is validated against the simulator that will actually run the generated deck

Status: OPEN, measured, not fixed — deliberately. STUB filed by the S3b
implement agent (op-annotation crew, branch `annotate`). This is the rejected
option (c) of ruling D8 in issue 0429, filed forward so it is not re-invented.

Related: 0429 (the cgso/cgdo ruling this is the residual of), 0434 (the failure
mode depends on the ngspice invocation idiom), spec §3 R1/R5, §5 I1/I3.

## What it is

`op_annot::save_cards` emits one card per `{label param kind}` triple in a
descriptor's `params`, with NO validation of `param` against anything. That is
deliberate and stays deliberate (I1: `params` is the single list the save side
and the display side share, and an emitter that dropped a parameter the display
still reads would be a second, silently drifting policy).

The consequence is measured and it is severe on one of the two ngspice binaries
installed on this box. One parameter per throwaway deck, real sky130 tt models,
under the `.control … write … .endc` idiom every shipped PDK bench uses:

```
/usr/bin/ngspice (42)         gm cgg cgs cgd -> raw written, 0 warnings
                              cgso cgdo      -> exit 0, ONE `checkvalid` line,
                                                and NO RAW FILE AT ALL
/usr/local/bin/ngspice (46+)  cgso cgdo      -> raw written, 2.463135e-16 each
                              bogusparam     -> exit 0, no raw
```

So on ngspice-42 **a single unknown model parameter anywhere in the block
suppresses the whole raw**, with exit status 0. A descriptor is user-editable
data (I5), so any user or any future PDK can reintroduce this at any time.

## Why it is not fixed

The obvious fix — a per-parameter guard in the descriptor plus a
simulator-version probe — was rejected in D8 for three reasons, all of which
still hold:

1. it is new descriptor grammar, on a key three PDKs already use;
2. it puts policy back inside the emitter, which is what I1 objects to;
3. **the probe cannot know which ngspice will run the generated deck.** The
   `.save` file is written now and `.include`d into a testbench that may run on
   another machine, another version, or another simulator entirely.

D8 therefore fixed the one live instance in the DATA (sky130's `cgso`/`cgdo`
rows are gone) and left the general problem here.

## What would settle it

Either a loud one-line diagnostic when a run produced no raw at all (which is
`xschem raw_read`'s side of the fence, not this file's — see 0434), or a
`.save` emission that ngspice cannot fail on. Neither is an S3 change.
