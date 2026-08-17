# 0431 — the prototype hierarchy walk leaves `no_draw=1` and `keep_symbols=1` set when it raises (invariant I6), and S3 is pointed at it as the reference

Status: **open — measured, not fixed. Binds S3.** Found by the S2 Verify-C
adversary of the op-annotation run (2026-08-16) on branch `annotate`.

## What was measured

`sky130_save_fet_params` on the shipped `sky130A/xschem_libs/sky130_tests/`
`test_generators` cell raises `Symbol not found`. Afterwards:

```
D-after-proto-walk-RAISE no_draw=1 keep_symbols=1
```

Both are still set. The walk sets them on entry and clears them at its normal
exit; there is no `catch`/`finally`, so a Tcl raise anywhere inside skips the
restore entirely. `sg13g2_hier_sch_expand` (`ihp-sg13g2/sg13g2_procs.tcl:345-421`)
has the same shape — its `go_back` pairing at :359-361 is on the normal path
only, and the `break` at :406 returns through the normal exit, so the *documented*
error arm is fine while an actual raise is not.

Left set, `no_draw=1` means the editor stops repainting — the schematic appears
frozen — and `keep_symbols=1` suppresses symbol reloading. Neither is obvious to
a user; both persist for the rest of the session.

## Why it is filed against the plan and not just against the PDK files

`doc/claude/specs/op_annotation.md` invariant **I6** says, in terms:

> The hierarchy walk restores `no_draw`, `no_undo`, `keep_symbols` and the
> original `sch_path` on EVERY exit path including error paths.
> `sg13g2_hier_sch_expand`'s `go_back` pairing is the reference.

The named reference **does not satisfy the invariant it is cited as the reference
for.** S3's brief repeats that citation. So an S3 agent that faithfully ports the
reference ships an I6 violation and can still believe it complied.

## Fix

S3 must wrap its walk body in `catch`, restore in the error path as well as the
normal one, and then re-raise — not port `go_back` pairing as-is. Concretely the
shape is

```tcl
set _err [catch {  ...walk body...  } _res _opts]
# restore no_draw / keep_symbols / sch_path here, unconditionally
if {$_err} { return -options $_opts $_res }
```

and the S3 test row should force a raise inside the walk (a cell containing a
missing symbol — `sky130_tests/test_generators` is a shipped one that does it)
and then assert the state is back, rather than asserting only on the happy path.

**Also correct the wording of I6 in the spec**, which currently points at
non-compliant code as the model. Done in the same commit as this issue: the spec
now cites the pairing as the *shape* and this issue as the reason it is not
sufficient.

## Not S2's defect

S2 adds no hierarchy walk (that is explicitly S3's work) and touched none of
these procs' bodies. Filed here because S2's adversary is what measured it and
because leaving it unfiled would hand S3 a booby-trapped reference.
