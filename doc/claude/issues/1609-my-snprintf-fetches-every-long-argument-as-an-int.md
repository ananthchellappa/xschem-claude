# 1609 — `my_snprintf` fetches every `long` argument as an `int`, and then tells `sprintf` to read eight bytes

**STAMP:** `v1 claim=open tree=70fd152eaf2 stamped=2026-09-27 fix=untried open=3 by=driver`

Carried forward, named but not fixed, from issue 1608 (`doc/claude/issue_1608_batch/STAGE_C.md`,
"Also required"). 1608 hardened the formatter against hostile *format strings*; this is the
remaining defect in how it fetches *arguments*.

## The mechanism

`my_snprintf` in `src/util.c` handles `d` `x` `c` `u` in one arm that declares a single
`int i` and fetches unconditionally:

```c
else if(format_spec && (*f == 'd' || *f == 'x' || *f == 'c' || *f == 'u') ) {
  char nfmt[50], nstr[MY_SNPRINTF_NSTR];
  int i, nlen, refuse;
  i = va_arg(args, int);            /* <-- always an int, whatever the spec said */
  ...
  nlen = sprintf(nstr, nfmt, i);    /* <-- nfmt may be "%ld", and sprintf then reads a long */
```

The spec gate `my_snprintf_spec_ok()` that 1608 added **permits the length modifiers `l` and
`h` on purpose**, because refusing them would change what live callers print. So `nfmt` can be
`"%ld"` or `"%lu"`, and two things then go wrong in sequence:

1. **The fetch truncates.** The caller pushed an 8-byte `long` (LP64); `va_arg(args, int)`
   consumes it as a 4-byte `int`. The upper half is discarded.
2. **The print over-reads.** `i` is an `int`, promoted into a vararg slot for `sprintf`, and
   `"%ld"` tells `sprintf` to read a `long` out of that slot.

On x86-64 SysV the two errors partly cancel: step 1 reads the low half of the slot, step 2's
promotion sign-extends the `int` back into a full slot, so the *truncated* value round-trips
and prints. **It is correct by the ABI's choice of slot layout and by the live values all being
small, not by anything this code does.**

## The three live callers

| site | value pushed | C type |
|---|---|---|
| `scheduler.c`, the `XMaxRequestSize` getter | `XMaxRequestSize(display)` | `long` |
| `scheduler.c`, the `XExtendedMaxRequestSize` getter | `XExtendedMaxRequestSize(display)` | `long` |
| `scheduler.c`, the window-id getter | `(unsigned long)ctx->window` | `unsigned long` (an XID) |

All three are currently in range for an `int`, which is why nobody has seen this. A `Window`
XID is 32 bits of a 64-bit `unsigned long` on LP64, so one at or above 2^31 would print
sign-extended; `XExtendedMaxRequestSize` is a byte count that a future server is free to make
larger than `INT_MAX`.

`%hu` in the first-selection getter is **not** affected: default argument promotion makes an
`unsigned short` arrive as an `int`, so `va_arg(args, int)` is the correct fetch and `%hu`
truncating on print is the correct read.

## Why the ABI accident is not a defence

The tree targets more than x86-64 — `XSchemWin/` holds a Windows config and the conventions
section commits to C89 on both Unix and Windows. Two named platforms behave differently:

* **Win64 (LLP64):** `long` is 4 bytes, so there is no truncation and no over-read. The bug is
  invisible there.
* **aarch64 (AAPCS64):** a 32-bit argument occupies a 64-bit vararg slot whose **upper 32 bits
  are unspecified**. Step 2 reads all 64. So the same code that is accidentally correct on
  x86-64 can print garbage on Apple Silicon and on a Raspberry Pi.

⚠ The aarch64 statement above is a reading of the ABI document, **not a measurement**: there is
no aarch64 toolchain on this machine. Issue 1606's adjudications C5 and C7 forbid a comment
that upgrades a derivation into a claimed measurement, so whatever ships must say which of the
two it is.

## Open questions for the fix

1. **Fetch by modifier, or refuse the modifier?** Fetching `va_arg(args, long)` when the spec
   carries `l` is honest and keeps the three callers' spellings. Refusing `l` and rewriting the
   three callers to cast is smaller in the formatter but touches call sites, and `%lu` of an XID
   would become `%u` of a cast, which is the same accident written out by hand.
2. **Does the `p` arm have the same shape?** It fetches `va_arg(args, void *)` and the gate
   permits `l`, so `"%lp"` is accepted; whether that is reachable or meaningful needs driving.
3. **How is any of this fenced?** The values are all small, so no live caller reddens. A row
   has to drive a `long` outside `int` range through a real `my_snprintf` call, which means a
   planted caller or a test-only entry point — and 1608's receipts record that a `sed`-extracted
   copy of this function is **not** acceptable evidence.
