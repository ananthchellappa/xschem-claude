# 1295 — DD-7's read-modify-write silently rewrites a teammate's line endings

**Status: MEASURED, FILED, NOT FIXED.** Found by item **B2c**'s adversary pass
and reproduced by the write-up agent, 2026-09-03, before B2c was reverted.

**A property of ruling DD-7's shape, not of B2c's patch** — any read-modify-write
that splits on `\n` and writes `\n` does this. Filed so the next implementation
designs for it rather than measuring it afterwards.

---

## What DD-7 and the emitted file promise

> Every other row is **preserved VERBATIM**.

> `# xschem edits only the rows it changed and leaves everything else in this
> file exactly as you wrote it -- your comments, your ordering, and rows a newer
> xschem wrote that this one does not understand.`

## The measurement (2026-09-03)

A settings file written by a Windows teammate, CRLF throughout:

```
version 2\r\nclass nmos mos\r\nparam class mos annotation A id 0\r\n
```

Load it, change one list, save:

```
ATK3  write=1  CR_count_after=0   (was 3)
```

**`rc=1`, zero reports, and every untouched line's bytes changed.** "Preserved
verbatim" is not byte-true for any line of the file.

## Why it happens, and why no row saw it

`_read_lines` deliberately reuses `load_conf`'s preamble — `_chanconf` pins
`-encoding utf-8` and leaves `-translation auto`, then `split $data "\n"` and
`string trimright $raw "\r"`. That is exactly right for a **parser**: it is what
makes a CRLF file parse. It is wrong for a **preserver**, because the `\r` is
discarded before the line reaches the merge, and the writer emits `\n`.

Row **P4** fences the CRLF/LF/no-final-newline cases through the **parse**. The
scout named this in advance — *"a DD-7 raw reader must reuse exactly that
preamble or a teammate's CRLF file will merge wrong in a way no existing row can
see — P4 fences the parse, not the merge"* — and it was reused and the merge
row was not written.

## Why it matters more than it looks

The feature's headline is **shareable with teammates**, and the file is meant to
be checked in. A save that flips every line ending makes **every save a
whole-file diff**, which is the precise opposite of *"the file a team checks in
diffs only when somebody changed something"* — a sentence B2c's own writer
comment used to justify emitting no timestamp, no pid and no hostname.

## The two defensible fixes

1. **Preserve the dominant line ending.** `_read_lines` records whether the file
   was CRLF (or per-line, if you want to be exact) and the writer re-emits it.
   Costs one variable and one `join`.
2. **State the conversion in the emitted header** — *"saving normalises line
   endings to LF"* — and accept the whole-file diff.

(1) is the one that keeps DD-7's own sentence true. (2) at least stops the file
lying.

## Related, same pass, smaller

An **interleaved user comment moves**: a `# why B matters` line sitting
*between* two `param` rows of a key this session changed comes back **after**
the rebuilt group, because the merge replaces a group at its first line and
drops the group's later lines without noticing what was between them. Against
*"your comments, your ordering"*. Cheaper to state in the header than to fix.

## Still open

* Whether the merge should preserve a **missing final newline**. B2c measured
  idempotence from the first save on for that case (row ATK-14), so it is
  handled; it is listed here only so the next crew does not re-derive it.
