# 0813 — the `raw_read` verb is destroy-then-read too, and it clears the WHOLE registry

> ⚠ **ATTEMPT 2 (2026-08-26) FIXED THIS AND WAS REVERTED FOR AN UNRELATED REASON.**
> The registry-stash fix closed 0813 cleanly — a failed `raw_read` left both attached
> databases alive and its honest `0` unchanged, with the success post-state
> byte-identical to HEAD (rows D1/D2, `test_raw_read_failure_0306` 63 → 73 checks, all
> green). It was reverted only because the same patch made
> [0836](0836-update-op-segfaults-on-a-zero-point-database.md) reachable through
> `annotate_op`. **Nothing about 0813's own fix is in doubt.** The diff is kept at
> `doc/claude/evidence/0807-attempt2-reverted.patch.txt`; see 0807 §13.


STATUS: **OPEN — stub claimed by the 0807 implement agent, 2026-08-25. Measured by the
0807 scout, not fixed.**
FOUND IN: `src/scheduler.c`, the `raw_read` verb (the `extra_rawfile(3, NULL, ...)`
clear-all and the `array unset ngspice::ngspice_data` that precede the read).
RELATED: [0807](0807-annotate-op-destroys-the-attached-op-database-on-a-truncated-raw.md)
(**still OPEN** — a fix was written and REVERTED, see its §7),
[0316](0316-read_dataset-malformed-header-aborts-leak-the-half-built-raw.md) (**still OPEN**,
reverted with it).

⚠ **This file was written while 0807's attempt 1 was in the tree and described that work as
landed. It did not land.** The primitives named below (`extra_rawfile_detach()` /
`_reattach()` / `_discard()`) **do not exist at HEAD**; they are in the reverted diff kept at
`doc/claude/evidence/0807-attempt1-reverted.patch.txt`. The defect described here is
unaffected either way — it is pre-existing and still live.

## The defect

`annotate_op` has the destroy-then-read defect described in 0807. The `raw_read` verb has the
SAME shape with a **wider blast radius**: it clears the **entire** registry (`extra_rawfile(3, NULL, NULL, ...)`) and unsets
`ngspice::ngspice_data` **before** it opens anything, so a read that then fails costs the
user every loaded database, not just the one being replaced.

`tests/headless/test_raw_read_failure_0306.tcl` C12 already names this shape
("clear-then-fail destroys a LOADED database") but only asserts the absence of a crash.

## Not the same as 0316

0316 is the READER wiping the registry on a malformed header. This is the VERB doing it
deliberately, before the read — so it is a **separate** loss that would survive a 0316 fix,
and the two must be fixed independently.

## Fix, when someone takes it

Whatever 0807's retry builds should be general enough to serve here too: detach what the
caller is about to replace
(or, for a clear-all, hold the array and restore it), read, then discard or reattach. The
verb already answers `Tcl_SetResult(interp, my_itoa(res))`, so its return value is already
honest — only the lifetime needs moving.
