# 0509 — `xschem raw read` of an already-loaded file reports success but leaves it bound to the old cell

**Status:** FIXED 2026-08-19 (results batch item 1) — candidate (1), the
re-stamp on the dedupe path, with one refinement (R110a). See **Resolution** at
the end. Measured on branch `fluid-editing` at `58b2c24d`, 2026-08-18.
**Area:** `extra_rawfile()`'s two "file found: switch to it" branches
(`src/save.c:1916-1921` and `:1970-1975`), the `schname`/`level` stamp in `raw_read()`
(`src/save.c:1383-1384`, `:1545-1547`, `:3131-3132`), the design gate
`sch_waves_loaded()` (`src/draw.c:2825-2840`) and `get_raw_index()`
(`src/save.c:3406-3410`).
**Found:** 2026-08-18, measuring the design-binding constraint while grounding
`doc/claude/specs/results_selection.md`.
**Severity:** live, user-reachable, and silent — the verb returns 1.

---

## The binding rule (working as designed)

A loaded database is bound to the schematic that was current **when it was
read**. `raw_read()` stamps it:

```c
my_strdup2(_ALLOC_ID_, &raw->schname, xctx->sch[xctx->currsch]);
raw->level = xctx->currsch;
```
— `src/save.c:1383-1384` (and `:1545-1547`, `:3131-3132` for the other readers)

and every name lookup is gated on that stamp still matching the *current*
hierarchy stack:

```c
int get_raw_index(const char *node, Int_hashentry **entry_ret)
{
  if(sch_waves_loaded() >= 0) return get_raw_index_in(xctx->raw, node, entry_ret);
  ...
```
— `src/save.c:3406`, with `sch_waves_loaded()` walking `xctx->sch[currsch..0]`
for a `strcmp` match on `raw->schname` (`src/draw.c:2825-2840`).

Measured — the database stays in the registry and stays current, but goes blind:

```
--- A: srlatch open, srlatch raw read here ---
  raw loaded       : 0
  raw index v(q)   : 52
  raw value v(q) 0 : 7.7437794e-16

--- B: navigated to tb_diff_amp, SAME raw still current ---
  raw loaded       : -1
  raw index v(q)   : -1
  raw value v(q) 0 :
  raw info still lists it:
    0 current
    0 .../srlatch/srlatch_ase.raw dc
```

That much is deliberate and is not the defect.

## The defect

The obvious repair — read the file again, so it re-stamps against the cell you
are now standing on — **silently does nothing, and says it worked**:

```
on B, stale:  loaded=-1  idx=-1  n_dbs=1
RE-READ same file while standing on B:
  rc=1
  after: loaded=-1  idx=-1  n_dbs=1        <-- unchanged, and rc says success

CLEAR then read again while standing on B:
  rc=1
  after: loaded=0   idx=52  n_dbs=1        <-- this is what the caller wanted
```

`src/xschem --nogui --pipe -q --script`, 2026-08-18.

Cause: `extra_rawfile(what == 1, …)` dedupes on `(rawfile, sim_type)`. When the
file is already in the registry it takes

```c
} else { /* file found: switch to it */
  xctx->extra_prev_idx = xctx->extra_idx;
  xctx->extra_idx = i;
  xctx->raw = xctx->extra_raw_arr[xctx->extra_idx];
}
```
— `src/save.c:1916-1921`, and **again verbatim at `:1970-1975`**: `extra_rawfile()`'s
`what == 1` arm is written twice, once for the non-spice readers and once for the
spice reader, and both copies end in this same else-branch. A third copy lives in
`new_rawfile()` (`src/save.c:1570-1577`), which differs only in setting `ret = 0`.
**A fix must touch 1916 and 1970 together** — patching one leaves the defect alive
for half the file formats.

The branch moves the cursor and **never re-stamps `raw->schname` / `raw->level`**.
Nothing is re-read, so nothing is re-bound. The verb `read` degrades into
`switch` and returns the success code of a read that never happened.

The dedupe itself is right — re-parsing a 100 kB raw on every request would be
waste, and `scheduler.c:10386-10402` already relies on "the registry did not
grow" to detect this exact case for `-case`. What is wrong is that the stamp is
treated as a property of the *file* when it is a property of the *read*.

## Why it matters now

This sits directly on the path a `Results > Select…` feature walks. The natural
implementation is:

```tcl
xschem raw read $chosen_path $type    ;# rc 1 -> "the result is selected"
```

For the *first* selection this works. For "select the result I had open a minute
ago" — i.e. after an `xschem load` of a different cell, which drops the raw's
`schname` off the hierarchy stack — it returns 1 and delivers a database in
which not one signal name resolves. (Descending does *not* trigger it:
`sch_waves_loaded()` already walks `xctx->sch[currsch..0]`, so an ancestor stamp
stays valid all the way down.) The
Calculator's Evaluate (spec phases 3.2/3.4) would then report
`v(nosuch)`-style token errors for names that are demonstrably present in the
file — `xschem raw info` lists it, `raw index` cannot see it.

It also makes `xschem raw switch` the more honest verb of the two: switch never
claimed to re-bind.

## Fix — four candidates, in order

0. **Use the re-stamp verb that already ships.** `xschem set raw_level <n>`
   (`src/scheduler.c:12275-12297`) writes *both* `xctx->raw->level` and
   `xctx->raw->schname` from Tcl, bounded to `0 <= n <= xctx->currsch`, and is
   already emitted by `open_sub_schematic` and `hi_descend`'s new-window arm.
   Measured: `xschem set raw_level [xschem get currsch]` restores the blind
   database above to `raw loaded 0` / `raw index v(q) 52`. This needs **no C
   change** — but it only helps the caller that remembers to follow up, which is
   how this defect came to exist. It is the workaround, not the fix.

1. **Re-stamp on the dedupe path.** In *both* "file found" branches, refresh
   `raw->schname` / `raw->level` from `xctx->sch[xctx->currsch]` before
   returning. Cheap, no re-parse, and makes `read` mean one thing. Risk: a
   *second* window/tab reading the same file would re-point the stamp — but the
   registry is per-`xctx` (`src/xschem.h:2036-2043`), so there is no sharing to
   break.
2. **Make the gate accept a stamp that is no longer on the stack at all** — i.e.
   let a result read against cell A stay resolvable while an unrelated cell B is
   open. Ancestors are *already* accepted (`sch_waves_loaded()` walks
   `xctx->sch[currsch..0]`, `src/draw.c:2830-2837`), so this is strictly about
   unrelated cells. Widest blast radius of the four — **52 call sites** across
   `draw.c` (21), `scheduler.c` (11), `token.c` (10), `save.c` (4), `hilight.c`
   (3), `actions.c` (2) and `callback.c` (1).
3. **Return a distinguishable code**, e.g. 1 for read, 2 for switched-existing,
   and let Tcl decide whether to `raw clear` + re-read. Cheapest to reason
   about; pushes the trap onto every caller, which is how it got here.

(1) is recommended. Whichever is taken, the return contract must be written
down: today `extra_rawfile()`'s header comment says only *"return 1 if
sucessfull, 0 otherwise"* (`src/save.c:1833`), which is exactly the claim that
turned out to be ambiguous.

## Coverage

`tests/headless/test_raw_read_dispatch.tcl` pins the reader dispatch and that
`raw switch <path> <type>` round-trips per format. The `level` half of the stamp
is already covered — `tests/headless/test_raw_read_failure_0306.tcl` drives
`xschem set raw_level` including its `-1` refusals. **Nothing asserts the
`schname` half, and nothing asserts the read-time binding across an
`xschem load`.** Add: read a raw under cell A; `xschem load` cell B; assert
`raw loaded` is -1 and `raw index` is -1 (the designed behaviour); re-read the
same path; assert the chosen semantics — and assert the return code says which
happened.

## Related

- issue **0507** — `raw_is_loaded` parses `xschem raw info` by word.
- issue **0508** — the Waves-menu chooser discards the whole registry.
- `doc/claude/specs/results_selection.md` — the feature this blocks.

---

## Resolution — results batch item 1, 2026-08-19

Candidate **(1)** was taken. `extra_rawfile()` gained one static helper,
`raw_restamp_design()`, called from **both** `what == 1` "file found: switch to
it" branches — the non-spice (table/vcd) arm and the spice arm. It refreshes
`raw->schname` / `raw->level` from `xctx->sch[xctx->currsch]` and re-primes the
case-mode comparison. Nothing is re-parsed. `xschem raw switch` is untouched
(R111). `sch_waves_loaded()` is untouched (candidate 2 remains not taken).

**One refinement, spec R110a:** the re-stamp fires **only when the current stamp
does not already resolve against the stack**. The unconditional form was
implemented first and measured to create this same defect pointing the other
way — read at the top, descend, re-read, ascend, and the *top* level goes blind
(`loaded=-1`, `raw index` -1) because the binding was moved down one level. Full
measurement and rationale in `doc/claude/specs/results_selection.md` §3.1.

**R112**, the return contract, is written into `extra_rawfile()`'s header
comment: `1` means the request was satisfied, which for `what == 1` is
deliberately not "the file was parsed"; a caller that needs to know which
happened compares `xctx->extra_raw_n` across the call, as `xschem raw read`'s
`-case` option already does.

**Two further refinements, added by the item-1 fix round** (both in
`doc/claude/specs/results_selection.md` §3.1):

- **R110c — the re-bind is opt-in and only the `read` VERBS opt in.** With the
  re-stamp unconditional inside `extra_rawfile()`, the ~14 `src/draw.c` graph
  walkers — which reach the same dedupe arm with the rect's `autoload` flag —
  re-bound too, so merely *opening* a schematic carrying an `autoload=` graph
  that named an already-loaded raw moved the binding to it and blinded the cell
  the user had read it under. That is this issue's symptom recreated one door
  along, and it contradicts driver ruling **U10**. `what` gains bit 6,
  `RAW_READ_REBIND` (`src/xschem.h`), set by `raw read` / `raw table_read` /
  `raw vcd_read` and by nothing in `src/draw.c`.
- **the R110a guard still refreshes `raw->level`.** Returning early left the
  level able to sit above `xctx->currsch`, which `xschem set raw_level` refuses
  to write and which makes four `ngspice::` path builders return an empty string
  where they owe a `?`.

**Coverage** — the gap this issue's own "Coverage" section named is closed by
`tests/headless/test_results_select.tcl` (new, **74** checks, ids
`SEL1`..`SEL74`):

- group **A** (spice arm) and group **B** (table arm) each drive the whole
  scenario — read under cell A, `xschem load` an unrelated cell B, re-read, and
  assert `xschem raw index` ≥ 0 — because **the arm is written twice** and one
  fixture proves only half the file formats. Sabotage confirms two *disjoint*
  red sets: removing the non-spice call reds SEL22/23/24 only; removing the
  spice call reds SEL11/12/13/33/47/48/49 only.
- group **C** pins R111: `raw switch` to a database bound elsewhere succeeds and
  stays blind, and a `raw read` of that same slot one line later re-binds it.
- group **D** pins R110a's guard (red without it).
- group **E** makes the *level* half observable: read one level down
  (`raw_level` 1), load an unrelated top-level cell, re-read, and `raw_level`
  must move 1 → 0. On cells A and B alone the level is 0 either way, so a
  `raw_level` check there cannot go red.
- group **F** pins **R110c**: opening (and explicitly redrawing) a cell whose
  graph rect carries `autoload=1` and names the loaded raw must leave that cell
  blind and the original cell still resolving — with and without an explicit
  `rawfile=` token. Real under X, vacuous under `--nogui`, where
  `xschem draw_graph` is `has_x`-gated.
- group **G** pins **R110b**, the case-mode re-prime, which had no check at all:
  read under a cell whose labels give `fold`, re-read under an unrelated
  hierarchy, **descend** (the only state where the verdict is replayed rather
  than recomputed) and assert the answer is that hierarchy's own `unknown`.
- group **H** pins that the stamp comes from `xctx->sch[xctx->currsch]` and not
  from `sch[0]`: every other re-read in the suite happens at `currsch == 0`, so
  hardcoding the top level left all of groups A-E green.
- group **I** pins the level refresh on the guard path.

Against the pre-change binary the original 49 checks report **10 FAILED / 39
passed**; the shipped suite is 74/74.
