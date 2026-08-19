# 0427 — `raw_is_loaded` parses `xschem raw info` by WORD, and has no callers

**Status:** OPEN. Measured on branch `fluid-editing` at `58b2c24d`, 2026-08-18.
**Area:** `proc raw_is_loaded` (`src/xschem.tcl:6980`), the `xschem raw info`
printer (`src/save.c:2110-2122`), the correct parser
`wviewer::rawinfo_parse` (`src/wave_viewer.tcl:2380`).
**Found:** 2026-08-18, mapping xschem's surfaces against Cadence ADE-L's
`Results > Select…` — a survey of every place a raw file is chosen.
**Severity:** low today, because the proc is unreachable. Filed anyway because
the defect is on the *result-selection* path, which is about to grow consumers.

---

## What

`raw_is_loaded {rawfile type}` answers "is this raw already in the registry?"
by splitting the whole `xschem raw info` blob into words:

```tcl
set rawlist [lrange [xschem raw info] 2 end]
foreach {n f t} $rawlist {
  if {$rawfile eq $f && $type eq $t} { set loaded 1 ; break }
}
```
— `src/xschem.tcl:6989-6995`

The engine's output is **line**-structured, not word-structured
(`src/save.c:2110-2122`):

```
<extra_idx> current
<i> <rawfile> <sim_type-or-"<NULL>">
...
```

`lrange … 2 end` drops the two words of the first line, then the `foreach {n f t}`
assumes every slot is exactly three words. **A rawfile path containing a space
shifts every field after it**, and the shift cascades: the leftover words of one
line become the `n`/`f`/`t` of the next.

## Measured

`src/xschem --nogui --pipe -q --script` against a raw copied to a directory
whose name contains a space:

```
--- raw info verbatim ---
0 current
0 /tmp/.../scratchpad/raw dir/srlatch_ase.raw dc

--- by-word parse, exactly as raw_is_loaded does ---
  slot n=|0|  f=|/tmp/.../scratchpad/raw|  t=|dir/srlatch_ase.raw|
  slot n=|dc| f=||                         t=||
raw_is_loaded WOULD RETURN: 0   (correct answer: 1)
raw_is_loaded => 0

--- per-line parse (wviewer::rawinfo_parse) ---
cur 0 dbs {{idx 0 path {/tmp/.../scratchpad/raw dir/srlatch_ase.raw} type dc}}
```

One loaded database is reported as **two** malformed slots, the path is truncated
at the space, and the sim_type field holds the tail of the path. The viewer's own
parser gets the identical input right.

## The part that changes the fix

**`raw_is_loaded` has zero callers.**

```sh
grep -rn "raw_is_loaded" src/ tests/ xschem_library/ sky130A/ gf180mcuD/ ihp-sg13g2/
# -> src/xschem.tcl:6980   (the definition, and nothing else)
```

It is upstream code: introduced by `23092fc9` *("do not rely on raw file existence
to decide if a raw is loaded. Added a function raw_is_loaded for that")* and its
call site went away later (`ad96e222` reworked the graph autoload path). So the
defect is **latent, not live** — no user can reach it today.

That makes this a choice, not a bug fix:

- **(a) delete it.** Nothing calls it; the graph dialog answers the same question
  a different way now.
- **(b) keep it and route it through `wviewer::rawinfo_parse`**, which already
  handles this exact input correctly and is pinned by BD13.

(b) is the better answer if a Results-Selection feature lands, because "is this
result already loaded?" is precisely the question such a feature asks before
deciding between `xschem raw read` and `xschem raw switch`. Whichever is chosen,
**there must not be a second BY-WORD parser** — and note the blob already has
four line-wise readers (`wviewer::rawinfo_parse` `src/wave_viewer.tcl:2380`,
`ase::raw_indices` `src/ase.tcl:2935`, `ase::raw_current` `:2943`, plus the test
helpers). "One parser" is not achievable; "no parser that breaks on a space" is.

## Two stale citations in the comment that warns about it

`wviewer::rawinfo_parse`'s header comment is the only place in the tree that
records this trap, and both of its citations have rotted:

| comment says | actual | drift |
|---|---|---|
| `src/wave_viewer.tcl:2368` — *"The engine prints (src/save.c:1456-1465)"* | `src/save.c:2110-2122` (`extra_rawfile()`, `what == 4`) | ~655 lines; `save.c:1456` is now inside `raw_deletevar()` |
| `src/wave_viewer.tcl:2373` — *"xschem.tcl:4801 reads the same blob … by WORD"* | `src/xschem.tcl:6989` | ~2188 lines |

Anyone following either pointer lands on unrelated code and concludes the
warning is stale. Fix both in the same change.

## Fix

1. Decide (a) or (b) above. Recommended: (b) — one parser, named
   `wviewer::rawinfo_parse`, reused.
2. Correct the citations in `src/wave_viewer.tcl:2368` and `:2373` — and, while
   there, `src/ase.tcl:2934`, which cites the same blob's format.
3. If (b): add a check to the signal-browser suite that a rawfile path
   **containing a space** round-trips through whatever `raw_is_loaded` becomes.
   `wviewer::rawinfo_parse` is already covered for this; the by-word path never
   was, which is why it survived.

## Related

- `doc/claude/specs/results_selection.md` — the feature that would give this
  proc its first live caller.
- issue **0428** — the sibling coverage hole on the same selection path.
