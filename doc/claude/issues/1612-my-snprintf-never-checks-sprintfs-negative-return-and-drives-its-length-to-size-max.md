# 1612 — `my_snprintf` never checks `sprintf`'s negative return, and a single `-1` drives its length to `SIZE_MAX`

**STAMP:** `v1 claim=fixed tree=818ea64c stamped=2026-09-27 fix=taken open=2 by=driver`

Found by the issue 1609 Stage A crew while measuring something else. **Not reachable today**, and
the reason it is filed separately rather than fixed inside 1609 is that 1609's own fix could make
it reachable — see "Why this constrains 1609" below.

## 0. FIXED, same day, and how each open question was answered

`if(nlen < 0) { overflow = 1; break; }` now sits in all three arms, after the `sprintf` and before
the bound — **and after the prefix write**, which is issue 1608's J3: a refusal that breaks earlier
leaves the destination entirely unwritten and the caller reads uninitialised memory. Breaking there
means `n` still holds the prefix length and `string` is NUL-terminated.

* **Open 1 — done**, in all three arms, positioned per J3.
* **Open 2 — declined, with the reason.** `%lc` is *not* also refused by GUARD 2's whitelist. That
  would be a second guard on the same path, and per CLAUDE.md two guards on one path means neither
  has a row that reddens on its own removal — which cost the 1606 batch a whole fencing plan. The
  negative-return guard is also the *general* one: it catches an encoding error on any conversion,
  where a `%lc` refusal catches one spelling.
* **Open 3 — answered by construction.** The guard breaks *before* `n += nlen`, so `n` is never
  decremented and the function returns the honest short prefix length. It can no longer return
  `(size_t)-1` from this path. Row `N2` asserts that return is `0`.
* **Open 4 — respected.** The `errno == EILSEQ` reading is labelled glibc's in the code comment, and
  the comment says the *trigger* is glibc-specific while the *unchecked return* is a defect
  everywhere.

**Rows `N1`, `N2`, `N3` in `tests/headless/test_snprintf_fmt_1608.tcl`** (48 checks, up from 45).
Sabotage-verified, three single removals:

| guard removed | reddens |
|---|---|
| `d/x/c/u` arm | `N1` `N2` `N3` |
| `p` arm | `N3` alone |
| `g/e/f` arm | `N3` alone |

⚠ **Only the `d/x/c/u` guard is behaviourally reachable**, and the rows say so rather than implying
coverage: `%p` and the `g/e/f` conversions have no encoding to fail on, so nothing can make their
`sprintf` return negative on this platform. `N3` fences those two by source text.

⚠ **`N3` was written wrong once, and the trap is worth keeping.** Its first form counted
`nlen = sprintf(` sites and required three. There are **five**: issue 1609 made the `d/x/c/u` arm
branch three ways on the length modifier, and all three alternatives share **one** guard because
they are arms of one `if`/`else` chain. The invariant that is exact is *"the refusal precedes the
bound"* — three `if(n + nlen + 1 > size)` tests, each immediately preceded by the refusal — and that
is what `N3` asserts now.

## The mechanism

All three conversion arms of `my_snprintf` in `src/util.c` do:

```c
nlen = sprintf(nstr, nfmt, i);
if(n + nlen + 1 > size) { overflow = 1; break; }
memcpy(string + n, nstr, nlen+1);
n += nlen;
```

`nlen` is an `int` and **`sprintf` is allowed to return a negative value on an output error.**
Nothing here tests for it. With `nlen == -1`:

* the bound becomes `n + (-1) + 1 > size`, i.e. `n > size` — which **passes**;
* `n += nlen` **decrements** `n`, and `n` is a `size_t`, so from `n == 0` it wraps to `SIZE_MAX`.

Three consequences, each driven in its own process at `399341ff`:

| format | result |
|---|---|
| `"[%lc]"` of a byte ≥ 128 | returns `1`, output `]` — the prefix `[` has been overwritten |
| `"%lc"` | returns **`18446744073709551615`** = `(size_t)-1` |
| `"%lcTAIL"` | the tail `memcpy` lands at `string + SIZE_MAX`, i.e. **one byte BEFORE the caller's buffer**; rc 0, silent |

The trigger measured is `%lc` of a byte ≥ 128, where glibc returns `-1` with `errno == 84`
(`EILSEQ`) in the `"C"` locale — confirmed against a plain-`sprintf` control.

**The silence is the same mechanism issue 1608 recorded as J6:** `string` is a pointer parameter,
so `_FORTIFY_SOURCE` cannot know its size and emits no check. There is no abort, no signal and no
message.

**And the `(size_t)-1` return is not a cosmetic wrong number.** `src/util.c`'s own comment (written
by the 1608 batch, about why the `HAS_SNPRINTF` arm could not simply be enabled) records that
**five live sites consume `my_snprintf`'s return value as a length**. This is a second route to a
bogus length that issue 1608's GUARD 3 accumulator cap does not cover, because the cap bounds what
the *spec* can ask for and says nothing about what `sprintf` *reports*.

## Why this constrains issue 1609

1609 fixes `my_snprintf` fetching every `long` as an `int`. One tempting implementation is to
**normalise every integer spec to carry `l`** so that a single `va_arg(args, long)` and a single
`sprintf` call serve all of them. That shortcut would turn **all eighteen live `%c` sites into
`%lc`**, and one of them is reachable from a file: `src/draw.c` formats `"%s[%c]"` with
`gr->unitx_suffix`, which is `val[0]` of a graph rectangle's **`unitx=` attribute out of a `.sch`
file**. So the shortcut would convert an unreachable defect into a file-borne one.

**1609 must therefore keep `%lc` out of its `l` branch** — which is also correct for an independent
reason measured by the same crew: `wint_t` is 4 bytes on glibc and promotes to `int` on Windows, so
the existing `va_arg(args, int)` is already the right width for `%lc`.

## Open

1. **Test `nlen < 0` in all three arms** before the bound and before the `memcpy`, and set
   `overflow`. ⚠ Per issue 1608's J3, the guard must sit **after** the prefix write, never before
   it: a refusal that breaks earlier leaves the destination entirely unwritten and the caller reads
   uninitialised memory. That defect was manufactured once already in the 1608 batch and caught by
   a crew, so the `refuse`-flag-and-fall-through shape is the precedent to follow.
2. **Should `%lc` be refused outright by the spec gate?** The tree's only `%c` uses are
   single-byte, the `l` modifier buys nothing, and refusing is one line in
   `my_snprintf_spec_ok()`'s whitelist. That is belt-and-braces with (1), so per CLAUDE.md each
   needs its own separately-reddening row or neither is fenced.
3. **What should the return be on refusal?** It cannot be `(size_t)-1`, since that is the value the
   five consumers misread. Whatever is chosen, the row must assert it, because a comment asserting
   a return value is the class of claim this tree has already had to correct twice.
4. **The `errno == EILSEQ` reading is glibc's.** The C standard permits a negative return on "an
   encoding error" without fixing the mechanism, so the *trigger* is glibc-specific while the
   *unchecked return* is a defect on every platform. Do not let a fix's comment quote the glibc
   behaviour as though it were the standard's.
