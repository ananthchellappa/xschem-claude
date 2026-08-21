# 0482 — `xschem annotate_op <path>` does not re-read a raw already loaded from that path, so a re-simulated design annotates the PREVIOUS run's numbers

Status: **OPEN, measured twice on this tree (S11 adversary pass, then
independently by the S11 write-up agent). NOT FIXED.**
Filed by the S11 crew (2026-08-20).
Related: invariant **I3** — "never the previous run's number" — issues 0466 /
0469 (the other two live I3 fabrications), 0470 (the same family one layer
down), spec §2.1.

## Measured (write-up agent, binary `2f41eadd…`, flat 1-FET sheet, 5-point tran raw)

    S11AFTER  H1 first annotate  t=3e-9 : v(d)=3  gm=0.00030000001
    ... the SAME file on disk is then rewritten so v(d) becomes 90..94 ...
    S11AFTER  H2 re-annotate SAME path  : v(d)=3  (disk now holds 93)
    S11AFTER  H3 after 'raw clear'      : v(d)=93

Step H2 is `xschem annotate_op <same path>` — the command behind the shipped
**Simulation ▸ Annotate Operating Point** menu item and behind the `6` /
`Alt-6` keys. It reports success and annotates the schematic with the values of
the run **before** the one the user just finished. `xschem raw clear` first
(H3) proves the rewrite was real and that the loader can read it.

## Why it matters more after S11

Before S11 a graphless schematic showed one frozen point, and a stale raw showed
one frozen *wrong* point. After S11 the user can scrub time across that stale
data interactively — every timepoint plausible, every timepoint from the wrong
simulation. This is invariant I3's third clause ("never the previous run's
number") reachable through the ordinary edit → simulate → annotate loop, with no
exotic state.

## Where it lives

Not in S11's arm. The re-read decision is in the raw layer — `extra_rawfile()`
(`save.c`) and the `annotate_op` arm (`scheduler.c`), which treat "a raw with
this path is already resident" as "nothing to do". A fix has to decide what
"same file" means (mtime? size? always re-read?) and is a behaviour change to
every `annotate_op` caller, so it is its own step, not a rider.

## Workaround, until then

`xschem raw clear` before `xschem annotate_op`, or make the annotate menu item /
the `6` key do it. Note that clearing also drops any other resident database, so
the naive workaround is not free for multi-database sessions.

## Still open

All of it. No test row covers this in any suite (the S11 section's fixtures each
write their raw once). A row is easy: annotate, rewrite the same path, annotate
again, assert the NEW number — it will red until this is fixed, so it should be
filed as an expected-fail or written as part of the fix.
