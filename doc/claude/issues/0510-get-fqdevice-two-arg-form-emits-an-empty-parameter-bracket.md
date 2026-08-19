# 0510 — `xschem get_fqdevice <inst>` emits an EMPTY parameter bracket

**Status:** OPEN. Measured on branch `fluid-editing` at `89d0f13e`, 2026-08-19.
**Area:** the scheduler verb (`src/scheduler.c:5460-5472`) and the composer
`get_fqdevice()` (`src/token.c:4514`).
**Found:** 2026-08-19, enumerating the emit sites for
`doc/claude/specs/typed_signal_accessors.md` §6.
**Severity:** low-to-medium. The 2-argument form is the one a
`node="tcleval([xschem get_fqdevice …])"` floater would naturally use, and it
produces a name that can never resolve.

---

## What

`get_fqdevice()` chooses a default device parameter with `param ? param : "id"`
(and `: "ic"` for a BJT). The scheduler's 2-argument arm passes the **empty
string**, not NULL:

```c
} else if(argc > 2) {
  fqdev = get_fqdevice("", 0, argv[2]);
```
— `src/scheduler.c:5469`

`""` is a valid pointer, so the ternary picks it and the default is never
applied. Measured against the in-tree binary:

```
xschem get_fqdevice M1        ->  i(@m1[])      <- empty bracket
xschem get_fqdevice Q1        ->  i(@q1[])
xschem get_fqdevice D1        ->  i(@d1[])
xschem get_fqdevice M1 id 0   ->  i(@m1[id])    <- the 3-argument control
xschem get_fqdevice V1        ->  i(v1)         <- unaffected: no bracket path
```

The affected branches are the ones that interpolate `param`: the no-path arms at
`src/token.c:4559` (`q` → `"ic"`) and `:4561` (`d`/`m` → `"id"`), and their
hierarchical twins at `:4545-4549`. Devices whose branch has no `[param]` at all
(`v`, `e`, and the `i`/other fall-throughs writing `[current]`/`[i]`) are not
affected.

## Why it matters

`i(@m1[])` resolves in no raw file. `get_raw_index()` returns -1 and, on the
back-annotation road, the value prints as `?`; on the graph road the trace draws
nothing. The failure is silent in both.

## Not a duplicate of the arity question

The verb is documented positionally as
`get_fqdevice instname param modelparam` (`src/scheduler.c:5450-5459`), and the
`argc > 4` arm is correct. This issue is only about what the 2-argument arm
substitutes for a missing `param`.

## Fix direction

Pass `NULL` rather than `""` from the 2-argument arm, so the composer's own
per-device defaults apply — i.e. make `xschem get_fqdevice M1` agree with
`xschem get_fqdevice M1 id 0`. A test would assert exactly that agreement for
one device of each prefix class (`m`, `q`, `d`, `v`, `c`, `r`, `i`).

## Related

`doc/claude/specs/typed_signal_accessors.md` §6.1 E7p, which needs this verb to
grow an accessor argument and records that a naively appended word is **silently
dropped** by the same `argc` ladder (measured: `xschem get_fqdevice V1 IT` →
`i(v1)`).
