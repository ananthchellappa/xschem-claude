# 1332 — the keys suite's SD rows drive a real modal on a fixed `after 100` and can false-red under load

**Status: FILED, NOT FIXED.** Found by item **B5-3**'s Verify-A agent as a
1-in-134 intermittent, diagnosed and instrumented there. Subject:
`tests/headless/test_rdw_keys_1245.tcl` rows **SD1** (`:1794`), **SD2**
(`:1820`) and **SD3b** (`:1915`).

## The shape

Each SD row drives the real, grabbing `.rdw.scope` dialog with the tree's only
sanctioned modal-driving idiom (`tests/headless/test_ase_bus_bits_0159.tcl:258`,
rows BB34/BB35): a driver armed on `after 100`, plus an `after 5000` deadman so
`tkwait` always returns.

```tcl
after 100 {
  catch {set ::SD3B_SEEN [expr {[winfo exists .rdw.scope] ? 1 : 0}]}
  catch {set ::SD3B_GRAB [grab current]}
  catch {.rdw.scope.sc.broad invoke}
  catch {.rdw.scope.btns.ok invoke}
}
after 5000 {catch {destroy .rdw.scope}}
catch {.rdw.b.delete invoke}
```

The driver's delay is a **fixed 100 ms**, not a poll. If the dialog has not been
constructed by then, every `catch` inside the driver hits nothing, the deadman
cancels the dialog 4.9 s later, and the row reports an **all-zeros tuple** —
a false red, not a hang.

## The measurement

Observed once in 134 runs, during item B5-3's Verify-A pass:

```
RESULT: 1 FAILED (40 passed)
SD3b -> {0 0 0 {} 0 0 {}}   expected {1 1 1 {{id ids 0} {gds gds 1}} 0 0 {}}
```

The whole rest of that log was byte-identical to a passing run — only SD3b
moved. The all-zeros tuple is `SD3B_SEEN=0` + `SD3B_GRAB={}` + store unmoved +
nothing left behind, i.e. the driver fired before the dialog existed.

The real margin, instrumented on a COPY in a `/tmp` shadow tree with a 1 ms
poll (repo file md5-verified untouched), over 88 runs: the dialog appears
**3–6 ms** after the invoke, **max 19 ms** — a 5–30x margin against the 100 ms
timer.

The trigger was **cross-agent contention on the shared `:99` display**, measured
from file mtimes: the failing run occupied 20:50:09–20:50:11 while another crew
agent's `test_op_annot` ran on the same display from 20:50:02 to 20:50:15, with
two further concurrent agent processes live. That is the situation
`CLAUDE.md` issue **0990** says is not evidence.

It did not reproduce in **133** subsequent runs: 3+10 plain, 6 under deliberate
6-way CPU load, 4 in a window→keys pairing, 20 plain, 89 in the shadow tree, and
once inside a full audit (PASS). The write-up agent added a further **10** clean
runs (`pass=10 other=0`) after the tree was final.

## Why this is a test defect and not a product defect

Nothing about it points at `src/rdw.tcl`, `src/op_annot.tcl` or
`src/op_param_lists.tcl`. The deadman **worked** — the suite did not hang, so
issue **0803** is honoured. `CLAUDE.md`'s own rule applies:

> treat a bug that only `:0` can reproduce as a *test* defect too: the fix is to
> force the race deterministically (`test_calc_skeleton` S12), not to hope an
> environment supplies it.

## Recommended fix

Replace the fixed `after 100` in SD1, SD2 and SD3b with a **poll**: an `after 5`
re-arming itself until `[winfo exists .rdw.scope]`, then driving the widgets,
with the `after 5000` deadman kept unchanged. Deterministic on a loaded box, a
slower machine, or any run sharing an X display; and it fails LOUDLY (the
deadman still fires) rather than reporting a plausible zero tuple.

Rejected: widening the delay to 500 ms — the same race with a bigger number,
which is exactly what the rule above forbids; and serialising crew agents on
`:99` — a process rule that no suite can enforce.

## Acceptance

The three rows pass with the poll under deliberate load (a 6-way CPU spinner
plus a concurrent suite on the same display), and a deliberately never-built
dialog still reds within the deadman rather than hanging.

## Still open

The same fixed-delay idiom is used by `test_ase_bus_bits_0159.tcl:258`
(BB34/BB35), which is where the SD rows copied it from. Not measured flaking,
not touched here.
