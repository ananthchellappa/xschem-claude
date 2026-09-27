# 1609 — `my_snprintf` fetches every `long` argument as an `int`, and then tells `sprintf` to read eight bytes

**STAMP:** `v1 claim=fixed tree=5a85ae36 stamped=2026-09-27 fix=taken open=6 by=1609-stage-C`

Carried forward, named but not fixed, from issue 1608 (`doc/claude/issue_1608_batch/STAGE_C.md`,
"Also required"). 1608 hardened the formatter against hostile *format strings*; this is the
remaining defect in how it fetches *arguments*.

## 0. ⚠ CORRECTION, same day — STAGE A REFUTED THE MECHANISM AND TWO CONSEQUENCES

Filed this morning by the driver, measured this afternoon by the Stage A crew, corrected here
before any fix is written. The filing below is kept verbatim so the corrections can be read
against it. **The defect is real and the conclusion stands; the reason given for it was wrong.**

**(a) It is ZERO-extension, not sign-extension, and that changes the whole answer.** The shipped
`src/util.o` carries `mov 0x10(%rsp),%r8d` immediately before `call __sprintf_chk` — a 32-bit
move into the low half, which on x86-64 zeroes the upper half — and the same instruction appears
at `-O0`, `-O1`, `-O2`, `-O3` and `-Os`. So the truncated value round-trips **only as unsigned
32-bit**, and the two halves of the bug agree on exactly **`[0, 2^32)`**. Driven, with a control
from plain `sprintf` for each: `%ld` of `4294967338` → `42`; `%ld` of `-1` → `4294967295`;
`%ld` of `LONG_MAX` → `4294967295`; `%ld` of `LONG_MIN` → `0`.

**(b) The XID claim below is REFUTED.** The filing says an XID "at or above 2^31 would print
sign-extended". It would not: `%lu` of `0x80000001` prints `2147483649`, correct, because
`0x80000001` is inside the agreeing band. Unsigned values only misprint at or above 2^32, and an
XID is a CARD32.

**(c) "Correct by the ABI's choice of slot layout" is REFUTED BY THE x86-64 psABI ITSELF**, which
says the opposite in as many words: *"When a value of a type of class INTEGER is returned or
passed in a register or on the stack, the excess bits … are **unspecified**"*, with the footnote
*"the consumer side of those values needs to extend them"*. So even here nothing guarantees this
works — it is **gcc's instruction selection**, not the ABI, and a different compiler or a future
gcc is free to break it. That is a **stronger** argument for fixing this than the one filed, and
it needs no other platform to make it.

**(d) The aarch64 sentence below is OVERSTATED and must not ship as written.** AArch64 W-register
writes also zero-extend architecturally, and this call's arguments are register-passed, so
AAPCS64's stack-padding case does not arise. Two portability statements that ARE well-founded
replace it: **Win64 is LLP64, so `long` is 4 bytes and there is no defect there at all**; and on
**any big-endian LP64 target the 4-byte read takes the HIGH half, so every value misprints**, not
only those outside the band. (AAPCS64 release 2025Q4 was fetched and read rather than recalled;
there is still no aarch64 toolchain or emulator here, so nothing about that target is measured.)

**(e) `open=3` understates it. A per-character whitelist is not a modifier whitelist.**
`my_snprintf_spec_ok()`'s GUARD 2 scans character by character, so it admits `ll` and `hh` — and
`%lld`, `%llu`, `%llx`, `%hhd`, `%hhu`, `%lhd`, `%hld`, `%llld` and `%hhhhd` are all **accepted**
(while `%zd %jd %td %qd %I32d %*d %nd` are correctly refused). No door is open today, but the fix
must be correct for those spellings, and this is a gap in issue 1608's GUARD 2 relative to its own
stated intent — J4 of that batch listed `hh` among what it meant to stop. In scope here.

**(f) What is CONFIRMED, and one of them for a better reason than the filing gave.** `%hu` is
unaffected: `Selected.type` is `unsigned short` and `INT_MAX >= USHRT_MAX`, so `va_arg(args,int)`
is the correct fetch — verified, not inherited. The `p` arm has no width defect. And no live
caller can *ever* misprint, not because "the values are small" but because **every value a live
caller can produce lies inside the agreeing band by construction**: `Display.max_request_size` is
an `unsigned` in `Xlib.h` and XIDs are CARD32, so neither can reach 2^32. Live readings were
`XMaxRequestSize=65535`, `XExtendedMaxRequestSize=4194303`, window id `6291739`, `first_sel` =
`1 0 0`. **So no ruling is owed** — `DECISIONS.md` K3 holds — and Stage C must note that **no live
caller can be made to redden**, which is why its row has to plant a value.

**(g) Two constraints on the fix. ⚠ THE FIRST ONE'S STATED MECHANISM IS ITSELF REFUTED — see (j)
below, which supersedes this paragraph's second sentence.** One fetch does **not** serve both: `d`
wants `long` while `u`/`x` want `unsigned long`. *(Superseded: this paragraph originally added
"and a single signed fetch would make `%lu` of `-1` print `18446744073709551615` where it prints
`4294967295` today — user-visible, which would turn this into a ruling." That is false on this ABI.)*
And `%lc` must be **excluded** from the `l` branch: `wint_t` is 4 bytes on glibc and promotes to
`int` on Windows, so the existing fetch is already the right width.

**(h) The strongest argument against the "refuse `l`, cast at the call sites" option is a
measurement, not a preference.** `-Wformat -Wformat-nonliteral` over all 40 `src/*.c` finds
**zero** argument-type mismatches at any `my_snprintf` call site, and an anti-vacuity probe proves
gcc would catch both a `long` into `%d` and an `int` into `%ld`. So the format attribute already
polices every caller, and **the only type mismatch in the whole program is inside `my_snprintf`
itself**. A hand-written `(int)` cast at each call site would satisfy gcc and convert a
diagnosable bug into an undiagnosable one.

**(i) A separate and more serious defect fell out of this measurement and is NOT part of 1609.**
`sprintf`'s **negative return is never checked**, and that is filed as its own issue — see the
`NUMBERING.md` entry for it. It is not reachable today, but it becomes reachable if this fix takes
the shortcut of normalising every spec to carry `l`, so it constrains Stage B here.

**(j) ⚠ STAGE C REFUTED (g)'s MECHANISM. The signedness of the fetch changes NO output on this
ABI.** Driven two ways: a two-`va_arg` comparison over the same pushed argument gives identical
text for `%lu` and `%lx`, and making the real site's fetch signed left every one of the
behavioural row's outputs **byte-identical**, with only the source-text row red. Both fetches read
the same eight bytes and both conversions reinterpret them. **The `unsigned long` split is still
correct**, for the reason Stage A's own §6 gave and not the one (g) gave: the C standard's
signed/unsigned `va_arg` exception holds only while the value is representable in **both** types.
But **no behavioural row can fence it**, so the suite asserts the `unsigned long` spelling over the
source text and the reason lives in the code comment rather than as a preference. Two guards in
this fix have no behavioural observable at all — that one, and routing `c` away from the `long`
branch — and both are stated in the row's own name instead of being hidden.

**(k) "Every current output is preserved byte for byte" is FALSE AS WRITTEN and needs its scope.**
Two things do change, and neither could be otherwise: `%lu` of `ULONG_MAX` goes `4294967295` →
`18446744073709551615`, which **is the fix working** — printing `4294967295` for `ULONG_MAX` is the
defect — and `%hhd`/`%hhu` go from formatting to refused. The defensible property, and the one the
rows assert, is neutrality **inside the agreeing band `[0, 2^32)` plus every plain spec**, which is
exactly what a live caller can reach. K3 still holds and no ruling is owed.

**(l) The new guard closed TWO defects nothing in this batch had named.** Because it lives in the
shared spec gate it reaches the other arms: **`X%llfY` returned 6 and printed `X-nanY` from a
correctly-pushed `1.5`** — glibc's `ll` on a floating conversion is undefined and reports no error —
and `X%llpY`/`X%hhpY` were accepted with the modifier silently dropped. All three now refuse.
`%lp`/`%hp` remain accepted-and-ignored, so the carried-forward note about them stands for those two
spellings only.

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
