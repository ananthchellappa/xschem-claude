# Plan — issue 1608, `my_snprintf`'s two 50-byte buffers

**Target:** `doc/claude/issues/1608-my-snprintf-writes-into-two-fixed-50-byte-buffers-and-checks-the-bound-afterwards.md`
(`claim=open fix=untried open=5`). **Read the 1606 issue and batch first** — this defect was found
there, deliberately left, and is the blocker on that issue's own option 3.

**Why this and not another open item.** It is the same class as 1606 — an unchecked `sprintf` into a
fixed buffer — but in **one function with ~748 callers**, overflowing the function's **own** stack,
so no caller can prevent it and no caller's buffer size makes it safe. The guard is two lines per
arm. And it is the thing standing between this tree and a `my_snprintf` that understands `%.*`,
which would retire the whole hand-clamped family 1606 had to build.

## What the driver measured before writing this plan

`src/util.c`'s hand-rolled `my_snprintf` (the `#else` arm — `HAS_SNPRINTF` is defined nowhere, and
the 1606 batch confirmed that four ways) handles conversions in **three** arms, each opening
`char nfmt[50], nstr[50];`:

| arm | conversions |
|---|---|
| `src/util.c:685` | `d` `x` `c` `u` |
| `src/util.c:707` | `p` |
| `src/util.c:730` | `g` `e` `f` |

Every arm carries the same two mechanisms:

* **(C)** `nlen = sprintf(nstr, nfmt, i);` then `if(n + nlen + 1 > size) { overflow = 1; break; }`
  — the caller's size is consulted **after** the write into `nstr[50]`.
* **(A)/(B)** `l = f - fmt + 1; strncpy(nfmt, fmt, l); nfmt[l] = '\0';` — `l` is the conversion
  spec's length straight from the caller's format, never compared with `sizeof(nfmt)`.

**Six unchecked writes, two mechanisms.** The 1606 batch's carried-forward note named only (C),
and only for float precision. ⚠ **A field WIDTH reaches (C) with a short spec** — `%-2000d` is
seven characters producing 2000 bytes, in the **integer** arm — so this is not a float-only or
precision-only defect. **Nobody has looked at (A)/(B) at all.**

## Stages

One crew per stage, one receipt each. A crew reads `CREW_BRIEF.md`, its stage section here, and the
**previous stage's receipt** — the corrections to this plan live in the receipts. The last four
batches each had a crew catch the driver being wrong; that is the point.

### Stage A — measure, on all three arms and both mechanisms

1. **Drive (C) per arm**, through a real `my_snprintf` call in the built binary and **not only**
   through a `sed`-extracted copy. The 1606 batch's figures for this function came from an
   extraction, and one crew's quoted number from such a probe turned out not to be a fact about the
   code. Say per arm whether it aborts (fortify) or corrupts silently, and give the verbatim
   outcome. Suggested shapes: `%-2000d` (integer arm), `%f` of `1e300` (float arm, 316 chars),
   `%.60g`, and something for the `p` arm.
2. **Drive (A)/(B)** with a conversion spec over 49 characters. ⚠ Work out `strncpy`'s semantics
   rather than assuming: `strncpy(dst, src, l)` with `l == 60` writes 60 bytes into a 50-byte
   array, and `nfmt[l] = '\0'` then writes at offset 60. Establish which of the two fires first and
   whether either is reachable from any format string in the tree.
3. **Find the real reachability boundary.** The 1606 batch asserts every live float caller is
   ≤ 24 characters and the only `%f` is `scheduler.c`'s `"%.6f"`. **Re-derive that over all ~748
   call sites** rather than inheriting it, and report the widest conversion any live caller can
   produce, per arm. A `%*d`, a `%-60s`, or a format that is not a literal would each change the
   answer.
4. **Is the never-compiled `HAS_SNPRINTF` arm a hazard in itself?** 1606 proved it has never
   compiled anywhere, from `scheduler.c`'s `my_snprintf(res, S(res), "HAS_SNPRINTF=%s\n",
   HAS_SNPRINTF)` handing `%s` an `int`. Say whether deleting it, fixing it, or fencing it is
   right — and note 1606 costed **enabling** it as worse than leaving it, because five sites consume
   a return value whose meaning differs between the arms.
5. **Behavioural reachability from a test.** Which `xschem` verb formats through `my_snprintf` with
   a caller-influenced conversion? The suite's backbone should be a behavioural row, per the brief,
   so this determines whether one exists.

### Stage B — the bound, and what it does when it fires

The fix is arithmetic; the **behaviour** on overflow is the question:

1. Bound (C) before the write. The natural instruments are a size check on a computed worst case, a
   heap buffer, or `snprintf` — ⚠ **`snprintf` is C99 and this tree targets C89**, which is the
   entire reason this function exists, so costing that option means costing the portability claim,
   not just the call.
2. Bound (A)/(B), or prove the spec length cannot exceed 49 and say so **with the measurement** in
   a comment.
3. **Truncate or refuse?** The function today sets `overflow` and `break`s, leaving the caller a
   truncated string plus a `dbg(1, …)`. ⚠ 1606 established truncation here is **user-visible
   badly** — a number cut mid-digit with its exponent and suffix amputated — so re-run that
   argument for this site rather than inheriting it, and say whether the answer differs because
   here the truncation is of one conversion rather than of a whole number.
4. Whether this makes 1606's option 3 (a `*`-aware `my_snprintf`) cheap enough to recommend as a
   follow-up. **Do not implement it here** — just say what it would then cost, since retiring
   thirteen hand-written clamps is the prize and this issue is the gate on it.

### Stage C — implement and fence

Per the brief: **a behavioural row is the backbone**, a compiler-diagnostic row if one applies, and
static rows only where neither reaches — named for what they grep, claiming no count. Every bound
gets a row that reddens on **its own** single removal; if two bounds cover one path, fence each
separately and say so in the row's own comment.

### Stage D — gate

T1 in a **fresh clone of the commit, built from scratch, solo, throwaway home, at a SHORT path**
(`/tmp/g1608`, 10 characters). Baseline to beat: `cases=99 blocks=98 counted_failures=0 skips=8`
(`results.2257277.log` at `eb20dc62`, `wc -l` 296, `elapsed=588s`). One suite in `hcases` alone
costs one case and no skip. ⚠ **`skips=8` has held for five figures by coincidence, not by
property** — read the trailer, do not check against the number.
