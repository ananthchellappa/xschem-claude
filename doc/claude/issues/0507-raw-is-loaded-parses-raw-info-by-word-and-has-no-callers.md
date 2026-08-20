# 0507 — `raw_is_loaded` parses `xschem raw info` by WORD, and has no callers

**Status:** **FIXED** 2026-08-20 by the results batch, item 9
(`kill-second-rawinfo-parser`), on branch `fluid-editing`. Originally measured
at `58b2c24d`, 2026-08-18.

> **THE PROC IS GONE — option (a), not option (b).** `raw_is_loaded` was
> **removed**, not re-expressed on `results::list`. A reader who sees FIXED and
> goes looking for a repaired parser will not find one: there is no
> `raw_is_loaded` in the tree any more, and `src/xschem.tcl` carries an 18-line
> comment where it stood, saying so. Everything that needs the registry now
> reads it per LINE through `wviewer::rawinfo_parse`, via `results::list`
> (`src/results.tcl`), and the read-vs-switch decision the proc used to inform
> is made in C by `xschem raw select` (item 3).

**Area:** `proc raw_is_loaded` (`src/xschem.tcl:6980` as filed — that span is
now the tombstone comment), the `xschem raw info` printer, and the correct
parser `wviewer::rawinfo_parse`.
**Citations below are AS FILED, 2026-08-18, and the body is left as the
historical record.** Two of them moved before the fix landed and the fix uses
the re-grepped ones: the printer `src/save.c:2110-2122` → **`2264-2277`**
(item 3 inserted the `raw select` verb above it), and `rawinfo_parse`
`src/wave_viewer.tcl:2380` → **`:2393`**.
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

## Fix — what actually shipped (item 9, 2026-08-20)

**(a) was taken, and the recommendation of (b) above was overturned with a
measurement.** The proc's four original callers were all in the graph dialog,
and *upstream itself* had already replaced them with an engine call: `23092fc9`
added the proc **with** four
`if {[raw_is_loaded [.graphdialog.center.right.rawentry get] …]}` guards, and
`ad96e222` deleted all four, moving the question into `graph_fill_listbox` as
`elseif {[xschem raw loaded] != -1}` (`src/xschem.tcl:6934` today). This batch
asks the same question in C as well — `results::select` never branches on "is it
loaded?"; it calls `xschem raw select`, whose `what == 1` dedupe arm decides
read-vs-switch inside `extra_rawfile()`. Keeping the name would have shipped a
proc with zero callers **and no caller in prospect**. Ruled as **R304c** in
`doc/claude/specs/results_selection.md` §5.1.

1. **`proc raw_is_loaded` is deleted** (`src/xschem.tcl`). In its place, an
   18-line comment: what it was, why it was wrong, why it is gone, and where the
   question is answered now. **The replacement is LINE-NEUTRAL on purpose** —
   478 `xschem.tcl:<line>` citations across `doc/`, `src/` and `tests/` point
   below the proc's old position, so an 18-line deletion would have staled every
   one of them (spec §11, L9's twin; ruled **R304d**). Neutrality was true at
   the time of the change (`proc waves` at `6373`, `proc load_raw` at `16874`),
   but **SEL471 asserts the tombstone's SHAPE relative to `proc set_rect_flags`,
   not those absolute numbers** — a permanent check may not pin line numbers in
   a 19,046-line file that other items legitimately edit (fixer round; R304d).
2. **All four rotted citations corrected**, not just the two this issue filed.
   `src/wave_viewer.tcl`'s `rawinfo_parse` header: `src/save.c:1456-1465` →
   **`src/save.c:2264-2277`** (`extra_rawfile()`, `what == 4`), and the
   `xschem.tcl:4801 reads the same blob … by WORD` paragraph is rewritten — the
   parser it warned about no longer exists, so the warning now says so and
   points at the grep that forbids a new one. `src/ase.tcl`: the same printer
   cited as `save.c:1469-1477` → **`2264-2277`**, and, in the same comment
   neighbourhood, `raw clear <n>` leaves `extra_idx` at 0 cited as
   `save.c:1417-1421` → **`save.c:2207-2211`**. `src/results.tcl`'s pointer at
   the *removed* proc's line number is gone. Both `save.c` citations are now
   **self-checking**: SEL468/SEL469 extract the range out of the comment and
   assert the cited lines actually contain the printer, and that the range the
   comment used to name does not.
3. **The space-path case is covered live and by grep.** Item 2's SEL118 already
   round-trips a path with a space through `results::list`; item 9's SEL467 adds
   the half it did not measure — that the engine's slot line for such a path
   word-splits into **four** fields for a three-field record, so no by-word
   reader can represent the row at all. And T-K is now a real grep:
   `tests/headless/test_results_select.tcl` group AP, **SEL459-SEL474**, run
   over source stripped of BOTH whole-line `#` and trailing `;#` comments,
   across all 28 `src/*.tcl` and all 358 `tests/headless/*.tcl`, with positive
   controls (the removed proc verbatim, plus the inline, captured-variable and
   index-walk shapes) and negative controls (the line-wise idioms, a by-word
   parse that exists only in a whole-line comment, one that exists only in a
   trailing comment, and a capture whose taint must not leak into the next
   proc).

**What T-K is NOT**, restated because it is easy to get wrong: not "exactly one
parser". Five line-wise readers exist and all are legitimate. The assertion is
about the by-WORD idiom. **Declared limits:** it is a grep over four shapes, not
a static analyser — a proc taking the blob as a *parameter* and splitting it by
word inside would evade it, and the captured-variable arms are proc-scoped, so a
file-scope capture consumed after an intervening `proc` line would too. Both are
named in spec R304c with the measurements behind them.

**Fixer round, 2026-08-20.** The removal itself survived review untouched; three
defects were found in the grep half and fixed, each with an A/B drive:
shape (d) — the **index walk** (`llength`/`lindex`/`lreplace`/`lassign` over the
captured blob) — was undetected, and 0507's defect rewritten that way and
planted in `src/xschem.tcl` left the suite ALL PASS (now reds SEL461, naming
`xschem.tcl`); the taint on a captured variable **name** leaked to end of file,
so an unrelated `lrange $txt …` in a different proc reddened SEL461 against an
innocent file; and a trailing `;#` comment carrying prose about the dead idiom
was scanned as live code. SEL472/SEL473/SEL474 pin the three fixes.

## Related

- `doc/claude/specs/results_selection.md` — the feature that would give this
  proc its first live caller.
- issue **0508** — the sibling coverage hole on the same selection path.
