# 0807 — `xschem annotate_op` destroys the attached OP database on a truncated raw, and reports success

STATUS: **OPEN — measured 2026-08-25 at HEAD with no patch applied, filed not fixed.**
FOUND IN: `src/scheduler.c:2411-2417` (the `annotate_op` branch), `src/save.c:1988`
`update_op()`, `ngspice::ngspice_data`.
RELATED: [0685](0685-annotate-op-reuses-a-stale-registry-database-at-the-same-path.md) §4
(which attributes this loss to the reverted workaround, and is **incomplete on this
point**), [0683](0683-annotation-is-reachable-with-no-bound-ase-l-session.md) §7
(refutation 3), [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md).

---

## 1. The defect

`annotate_op` deletes the previously loaded 1-point `op`/`dc` database and
`array unset`s `ngspice::ngspice_data` **before** it attempts to read the new
file. When the read then fails — ngspice mid-rewrite, so the raw is readable but
truncated — nothing replaces what was deleted, and the user's loaded database is
gone.

It then returns `TCL_OK` **with the path string**, so its return value can never
be used as a success test.

## 2. The measurement

Write-up agent, 2026-08-25, `src/xschem` built from the 0688+0683 tree, `--nogui`,
against a 182-byte 1-point op raw truncated to its first 40 bytes:

```
WU| GOOD raw attached: raw loaded=0  v(a)=3.14  switch op=0/1
WU| annotate_op TRUNCATED  rc=0  ret=/…/trunc.raw
WU| AFTER: raw loaded=0/-1  v(a)=1/No raw file loaded  switch op=0/0
WU| ngspice_data entries=0
```

`rc=0` and the returned path are a **lying success**: `raw loaded` went `0` → `-1`,
`raw value v(a) -1` went from `3.14` to a raise, and `ngspice::ngspice_data` is
empty. Three agents on this item reproduced it independently (scout, implement,
adversary). The scout additionally measured that with BOTH a tran waveform db and
an op db attached, the truncated annotate destroys the op db while the tran db
survives, and that in that arrangement `xschem raw switch op` **still answers 1**
over the emptied slot — a lying witness. (In the simpler arrangement above
`raw switch op` answered 0; the witness is unreliable in both directions.)

`/nonexistent.raw` behaves the same way: `raw loaded` −1, `rc` 0.

## 3. Why it matters here, and why 0685 §4 is wrong about it

0685 §4 records the data loss as caused by the reverted `annot_drop_stale`
workaround. It is not: the loss is in the **shipped** command that
`annot_drop_stale` merely called. `annot_drop_stale` **widened** it from `op`/`dc`
to `tran`; it did not create it.

This is the command **both** guarded stock entry points call, and the one ASE-L's
`Results > Annotate` attach arm calls, so it sits inside the annotation feature's
blast radius even though this issue's fix does not.

## 4. What is NOT affected

Issue **0688**'s root-sheet clear, which landed in the same commit, does not go
near this: it writes one int, one Tcl var and one path stamp and never opens a
file. Rows **Y7** and **Y7b** in `tests/headless/test_op_annot.tcl` pin exactly
that, including the truncated-on-disk case — the raw stays in the registry across
the clear and answers `3.14` out of memory.

## 5. The shape of a fix (not implemented)

Read into a scratch database and swap only on success, so a failed read leaves the
previous one intact — the "do not destroy what you cannot replace" rule
`save.c` RULING **D5-1** already states for a different surface. Secondly, the
command must stop returning `TCL_OK` with a path when nothing loaded; a caller has
no other way to tell.

`tests/headless/test_op_annot.tcl`'s section-N comment block records the
missing-file half of this in prose, but there has never been a committed row.

## 6. Still open

All of it.
