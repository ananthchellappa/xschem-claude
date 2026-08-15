# 0311 — cosim shim drops every set-bit written to a multi-bit `inout` port

**Status:** OPEN, not fixed here. Filed from batch F item 12 (a doc-only item);
found by reading `verilator_shim.cpp` closely to verify an unrelated comment.
**Upstream defect**, faithfully inherited by our vendored copy — do not "fix" it
in isolation without deciding the vendoring policy first (see below).

## The defect

`accept_input()` writes an incoming digital value into the Verilated model
through a `VL_DATA` macro that is redefined once per port class. The **input**
version is correct; the **inout** version drops the `=` from its compound
assignment:

`tools/cosim/src/verilator_shim.cpp`

- line 130 (inputs, correct):    `topp->name |= (1 << (msb - index));`
- line 162 (inouts, **wrong**):  `topp->name | (1 << (msb - index));`

Line 162 computes a value and throws it away. The clear path immediately below
it (`&= ~(1 << …)`) is a real assignment, so the bit can be cleared but never
set.

## Blast radius

Only **multi-bit** `inout` ports. A 1-bit inout takes the earlier
`msb == 0 && lsb == 0` arm (`topp->name = val ? 1 : 0;`), which is a real
assignment and works. So:

- 1-bit `inout` — fine.
- `inout [N:0]` with N > 0 — a bit that SPICE drives high never reaches the
  Verilog model. `previous_output[]` is still updated as if it had, so the
  change-detection logic in `step()` believes the write landed and will not
  re-drive it. The symptom is a bus that reads as stuck-low from inside the
  Verilog, with no diagnostic anywhere.

Nothing we ship exercises it: the reference design
(`xschem_libraries_oa/ngspice_verilog_cosim_ase/counter`) has no `inout` at all,
which is why 141 headless checks and a full end-to-end reference run never saw
it.

## It is upstream, not ours

The same line, with the same missing `=`, is in both copies of the stock file:

- `/usr/local/share/ngspice/scripts/src/verilator_shim.cpp:83` (installed ngspice-46)
- `/home/qflow/dev/ngspice_test/src/xspice/verilog/verilator_shim.cpp:83` (ngspice "46+" source tree)

and the correct input-side line is `:51` in both. Our vendored copy under
`tools/cosim/src/` reproduces the upstream text exactly here; every deliberate
divergence in that file is marked `XSCHEM PATCH`, and this is not one.

`g++` does not shout about it in practice because the expression is generated
from a macro; a `-Wunused-value` build would flag it.

## Why it was not fixed in item 12

Item 12 was scoped doc-only and explicitly told not to fix neighbouring code.
More importantly the fix has a policy question attached that an implementer
should not answer alone: `tools/cosim/README.md` ("Keeping `src/` in sync")
states that `src/` is a **vendored copy** to be re-copied wholesale on an ngspice
upgrade with the `XSCHEM PATCH` hunks re-applied. Fixing this makes it a fifth
patch hunk — reasonable, but it should be marked `XSCHEM PATCH` like the others
and reported upstream, or the next re-vendor silently reverts it.

## Suggested fix

One character, plus the marker and a regression that actually has an inout:

```c
    if (val)                                  \
      topp->name |= (1 << (msb - index));  /* XSCHEM PATCH: upstream drops the '=' */ \
```

A regression needs a `.v` with an `inout [3:0]` in the cosim library and a check
that a SPICE-driven high bit is observable inside the block's VCD. Without that
the fix is untested — and an untested one-character change to a wire protocol is
exactly the kind of thing that reads as obviously right and is not.

## References

- `tools/cosim/src/verilator_shim.cpp:122-134` (input macro), `:152-167` (inout macro)
- `tools/cosim/README.md`, "Keeping `src/` in sync"
- `doc/claude/specs/mixed_signal_signal_browser.md` §A
