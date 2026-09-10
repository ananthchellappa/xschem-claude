# V1 — INTEGRITY. Did the backfill lose anything?

**SOUND WITH FIXES**

Nothing was lost. I tried to prove otherwise and could not: all 194 entries that
existed at 12:18 are still there, and for **every one of them the 12:18 file is an
exact byte PREFIX of the live file** — the strongest form of "append-only" there
is, and it forecloses line-1 edits, key drops, reorders and silent rewrites in one
measurement. The two entries the driver added are the only additions, and the
recovered ruling is byte-identical to the 09:20 pre-image plus two stamp lines.

The FIXES are not integrity losses in the backfill. They are: **the driver filed
the batch's own ruling on the bare id `1400`, the one thing N1 told it twice not to
do**, and that entry is destroyable today by the other clone at exit 0 — reproduced
below; and the "09:20" backup was actually taken at **09:37:32**, after the batch
had started, so the label in LEDGER.md and in this batch's prose is wrong by 17
minutes.

## Method, snapshots and honesty about the moving target

A live op-wcard session writes this directory. Everything below is measured
against a `cp -a` snapshot of the live ledger taken at **2026-09-10 12:20:34 -0700**
(`live_snap1`). I re-took it at **12:27:29** (`live_snap2`) and
`diff -rq live_snap1 live_snap2` reported **no change**, so the whole pass sat on a
still ledger. Independent corroboration that op-wcard has been quiet since the
backfill: `find /home/analog/.claude/xschem_owed -mindepth 2 -maxdepth 2 -type f
-newermt '2026-09-10 12:18:52'` returns **nothing**, and `look/` and `suite/`
directory mtimes are still `10:46:33`.

The live ledger was never given to `owed.sh` and was never written. Every exercise
of the tool ran against a `cp -a` copy under
`/tmp/claude-1000/-home-analog-dev-xschem-claude/1e23e38a-228a-491e-a9b0-387bda9d283e/scratchpad/`
with `XSCHEM_OWED_DIR` pointed at the copy; after each read pass
`diff -rq <copy> live_snap1` confirmed the copy was unchanged. `xschem-op-wcard`
was read only — its `owed.sh` was executed **in place** (safe: its only file writes
are lines 187–189, all under `$XSCHEM_OWED_DIR`, verified by
`/usr/bin/grep -n '> *"' tests/headless/owed.sh`), and a `git status --porcelain`
there is clean. No git-mutating command was run anywhere. The binary was not
launched. `~/.xschem/` was not touched.

Every count below names the command that produced it. `/usr/bin/grep` throughout,
never the shell's `grep` function.

## 1 — every 12:18 entry still exists, and line 1 is byte-identical

Presence, entry by entry (loop over `$BAK/{rule,look,suite}/*`, `[ -e "$LIVE/$d/$b" ]`):

* **missing from live: 0** (of 194)
* new in live: exactly **2** — `rule/1351@xschem-claude`, `rule/1400`

Line 1, entry by entry (`head -n1 "$f" | md5sum` on both sides, per entry, not a
count of the whole tree):

* **line 1 identical: 194 — differing: 0**

Stronger, and the check that actually settles "append-only":

```
n=$(stat -c%s "$BAK/$d/$b"); head -c "$n" "$LIVE/$d/$b" | cmp -s - "$BAK/$d/$b"
```

* **prefix-preserved: 194 — not: 0**

So no pre-existing byte anywhere in any entry changed. Not line 1, not lines 2+.
A `>`-style rewrite, a re-ordering, a dropped key or a re-flowed reason is
excluded by construction, not by sampling.

Also checked, because a bare `>>` onto a file with no final newline would have
glued a stamp onto an existing line: **0 of the 194 files at 12:18 lacked a
trailing newline** (`tail -c1 | od -An -c`), and 0 of the 196 live files lack one.

## 2 — every pre-existing line-2+ key survived

Distinct keys (text before the first colon) over lines 2+ of every entry:

`for f in ...; do tail -n +2 "$f"; done | sed 's/:.*//' | sort | uniq -c`

| key | at 12:18 | live 12:20 |
|---|---|---|
| `ref` | 82 | **84** (+2: the two new entries) |
| `eyes` | 22 | **22** (unchanged) |
| `repo` | 0 | 196 |
| `repo_via` | 0 | 196 |

`eyes` and `ref` were the **only** two keys in existence at 12:18. Neither lost a
single instance. No line 2+ in either snapshot lacks a colon
(`tail -n +2 "$f" | /usr/bin/grep -n -v ':'` → empty both sides), so nothing was
mangled into a keyless line.

Key **order** is uniform and is exactly `cmd_add`'s own write order — pre-existing
keys first, stamps appended after (`tail -n +2 "$f" | sed 's/:.*//' | paste -sd,`):

```
107  repo,repo_via
 68  ref,repo,repo_via
 15  eyes,ref,repo,repo_via
  5  eyes,repo,repo_via
  1  eyes,eyes,ref,repo,repo_via
```

196 total; `eyes` instances 1·2+15+5 = 22 ✔; `ref` instances 1+15+68 = 84 ✔.

**One pre-existing malformation, NOT caused by the backfill:**
`rule/1341_nonfinite_in_the_devices_bucket` carries **two `eyes:1` lines**. It has
carried them since at least the 09:20 backup — I checked all three snapshots. Both
values are identical and `_entry_field` takes the first, so it is inert. It is the
only structurally odd entry in the ledger; flagged so it is not later mistaken for
backfill damage.

## 3 — no entry has two `repo:` lines

Per-entry multiplicity scan over all 196 live entries, counting
`^repo:`, `^repo_via:`, `^ref:`, `^eyes:` with `/usr/bin/grep -c` on `tail -n +2`:

* **repo: exactly 1 on 196 of 196.** Zero entries with 0, zero with 2+.
* **repo_via: exactly 1 on 196 of 196.**
* the only multiplicity anomaly in the whole ledger is the pre-existing double
  `eyes:1` above.

I also checked for a stamp forged onto line 1 (N2's F6 class): for every entry,
`/usr/bin/grep -c '^repo:' "$f"` equals the same count over `tail -n +2 "$f"` —
**no entry has a `repo:` at line 1**, so `_entry_field`'s first-match rule reads
the driver's stamp and not a forgery.

Stamp values are clean strings, `cat -A`-verified, no trailing slash or whitespace:

```
repo:/home/analog/dev/xschem-claude$
repo:/home/analog/dev/xschem-op-wcard$
```

and they match `_ORIGIN` exactly. `git rev-parse --path-format=absolute
--git-common-dir` answers `/home/analog/dev/xschem-claude/.git`; `_origin_init`
strips the `/.git` (owed.sh:190), so the compare is exact and no entry reads as
foreign from its own clone. Confirmed by exercise, not inference — see §5.

## 4 — the reading commands, before vs after

`list`, `count` and `show` run against `cp -a` copies of (a) the 12:18 backup and
(b) `live_snap1`, with the **repaired** `owed.sh`:

| | 12:18 | live | rc |
|---|---|---|---|
| `count` | `132 rule, 53 look, 9 suite` | `134 rule, 53 look, 9 suite` | 0 / 0 |
| `list` | 282 lines | 300 lines | 0 / 0 |
| `show` | 828 lines | 850 lines | 0 / 0 |

stderr was **empty** on all six runs. `diff` of the two `list` outputs and of the
two `show` outputs contains **zero `<` lines** — the change is purely additive.
Every difference explained:

* `list`: **+14 `from: /home/analog/dev/xschem-op-wcard (another clone)`** origin
  markers (one per foreign entry) and the two new entries with their `read:` refs.
* `show`: **+12** `filed in another clone:` markers — 14 foreign entries minus the
  2 foreign *suite* debts, which `show` (rule + look only) does not print — and the
  two new entries.
* No `(not in this clone)` ref marker appeared or disappeared: that marking depends
  on whether the file resolves here, not on the stamp, so it is identical in both
  runs. Correct behaviour, and it means the stamps did not perturb ref reporting.

**Nothing failed to parse.** I then ran the same three commands with the
**pristine** reader — `/home/analog/dev/xschem-op-wcard/tests/headless/owed.sh`,
which is `md5 cc88328d…`, byte-identical to this clone's `git show
HEAD:tests/headless/owed.sh` — because that is the script the other clone actually
runs against this ledger:

* rc 0 on all six runs, **stderr empty**, `count` identical to the new reader's.
* `diff` of its `list` outputs: **+4 lines, 0 deletions**, all four belonging to
  the two new entries. `diff` of its `show` outputs: 12 lines, **0 deletions**.
* The old reader neither chokes on `repo:`/`repo_via:` nor echoes them as garbage.

So the backfill is invisible to the un-upgraded reader and legible to the upgraded
one. That is the outcome the append-only rule was supposed to buy.

Structural validation of all 196 live entries — non-empty, line 1 has ≥3
tab-separated fields, field 1 is all digits, file ends in a newline: **0 problems**.
Permissions and ownership unchanged (`-rw-r--r-- analog:analog` on 196 of 196, and
on 194 of 194 at 12:18). No stray, non-regular or nested files anywhere under the
ledger (`find ! -type d ! -type f` and `-mindepth 3` both empty).

## 5 — the recovered ruling

```
diff  ~/.claude/xschem_owed.bak.2026-09-10/rule/1351
      ~/.claude/xschem_owed/rule/1351@xschem-claude
2a3,4
> repo:/home/analog/dev/xschem-claude
> repo_via:told
```

That is the whole diff. Byte-prefix confirmed: the 09:20 file is the first **1450**
bytes of the 1500-byte live file, `cmp` clean. Line 1 — epoch `1788626525` =
**2026-09-05 09:42:05 -0700**, subject `1351`, and the full RDW driver-decision
reason — is intact to the byte.

`ref:doc/claude/issues/1351-the-poll-guard-the-orphan-chain-and-a-selection-that-outlives-its-text.md`
— the RDW poll-guard issue, as claimed. **It exists in this clone**
(`-rw-r--r-- 7325 bytes, Sep 5 09:41`).

The recovered file's *shape* is exactly what `owed.sh` would have produced itself:
`cmd_add`'s namespacing arm sets `id="$id@$(_repo_tag "$repo")"` for the filename
while line 1's subject stays the bare `1351` (owed.sh:495). The recovery is
format-faithful, not hand-shaped. Proved by round-trip, on a copy:

* `add rule 1351 "…" --repo here` → `updated rule debt: 1351 (id 1351@xschem-claude,
  clone xschem-claude)`, rc 0 — it finds the recovered slot, keeps the `ref:`, and
  leaves op-wcard's `rule/1351` **byte-identical** (`cmp` clean).
* `clear rule 1351@xschem-claude` → `cleared`, rc 0. The user can answer it.
* a bare `add rule 1351` from this clone → **rc 5, nothing written**
  (`diff -rq` of the copy against `live_snap1` clean afterwards).
* a bare `clear rule 1351` from this clone → **rc 5**, and the refusal prints
  op-wcard's standing reason, its clone, and the candidate line
  `… clear rule 1351@xschem-claude`. The two rulings cannot be confused by the tool.

**The other clone's `rule/1351` was not touched by the recovery.** Against the
12:18 backup its diff is exactly the two stamp lines the backfill appended:

```
3a4,5
> repo:/home/analog/dev/xschem-op-wcard
> repo_via:told
```

byte-prefix clean over its first 1571 bytes. Its `ref:` names
`1351-font-attribute-is-a-postscript-name-and-a-format-string.md`, which is absent
here and present in op-wcard (`3228 bytes, Sep 10 10:19`) — and `show` correctly
marks it `(not in this clone)` and `filed in another clone`. Both rulings stand,
both are answerable, neither shadows the other.

One cosmetic consequence, owed.sh's design rather than the driver's: `show` prints
both under the heading `1351`, because line 1's subject is the bare id in both.
They are told apart by the `filed in another clone:` line and by their differing
`clear with:` commands. Worth knowing before the user reads the queue.

## 6 — was 10:46:14 an overwrite? Yes, and I can prove it without the driver's argument

I tried to refute it. I could not. The decisive measurement is one the driver did
not use in this form:

**`rule/` directory mtime is `2026-09-10 06:54:10.569645589 -0700` in BOTH the
09:37 backup and the 12:18 backup** (`stat -c '%n mtime=%y'`). A directory mtime
moves on a create and on an unlink; it does not move on an in-place rewrite. So
between 06:54:10 and 12:18:15 **no file was created or unlinked in `rule/`** — yet
`rule/1351`'s content went from this branch's ruling (present in the 09:37 copy) to
op-wcard's (present in the 12:18 copy), and the replacement's own epoch field reads
`1789062374` = **2026-09-10 10:46:14 -0700**. An in-place truncate-and-rewrite is
the only shape that fits.

Three independent corroborations:

1. **The same session's other two writes, 19 seconds later, DID move directory
   mtimes.** `look/` and `suite/` both read `10:46:33` — and the two entries added
   in that window are `look/hier_pdf_links_1343_H5.1789062393.2136295` and
   `suite/test_ps_valid_1350`, epoch `1789062393` = 10:46:33, both stamped
   op-wcard. One writer, two behaviours, 19 seconds apart: creates moved the
   directory, the `rule` write did not. That is a control, not a coincidence.
2. **The rule file count did not change**: 132 at 09:37, 132 at 12:18
   (`find …/rule -maxdepth 1 -type f | wc -l`). A create would have made it 133.
   An unlink-then-create would have moved `rule/`'s mtime twice.
3. **The mechanism is in the code op-wcard runs**: its `cmd_add` ends
   `printf … > "$d/$id"` (`owed.sh:187`) with no existence check — bash's `>`
   truncates in place, same inode, and the directory is untouched. `_say
   "recorded"` is unconditional.

The only way to defeat this would be an unlink+create followed by a deliberate
`touch -d` restoring `rule/`'s mtime to nanosecond precision. Nothing suggests
that, and the same nanosecond value appears in two `cp -a` snapshots taken 2h41m
apart by different passes.

**Correction to the record, and it is one of my FIXES.** The backup everyone calls
"09:20" has a copy-root ctime of **09:37:32.626884587** and per-subdirectory ctimes
of 09:37:32 — so the `cp -a` completed at **09:37:32**, not 09:20. The batch had
already started: `numbering_batch/DECISIONS.md` mtime is **09:34:12**, `PLAN.md`
**09:35:06**. (Inferred, not measured: ctime also moves on a rename or a chmod, so
strictly what I measured is "created or last metadata-touched at 09:37:32".) This
does **not** weaken the recovery — the overwrite was at 10:46:14, an hour later,
and all 192 entries in that copy have line 1 identical to live except `rule/1351`,
which is exactly the signature of a clean pre-overwrite image. But LEDGER.md's
"the `cp -a` taken at 09:20 before any item ran" is wrong twice: 09:37, and the
batch was 3 minutes in. Relabel it.

## 7 — the count, reconciled end to end

`find <dir>/<kind> -maxdepth 1 -type f | wc -l`, per kind:

| snapshot | rule | look | suite | total |
|---|---|---|---|---|
| bak `…2026-09-10` (taken 09:37:32) | 132 | 52 | 8 | **192** |
| bak `…2026-09-10.1218` (taken 12:18:15) | 132 | 53 | 9 | **194** |
| live @ 12:20:34 and @ 12:27:29 | 134 | 53 | 9 | **196** |

Full accounting, no residue:

* **192 → 194**: op-wcard added `look/hier_pdf_links_1343_H5.1789062393.2136295` and
  `suite/test_ps_valid_1350`, both epoch 10:46:33. Identified by name-set difference,
  not by arithmetic. `rule` stayed 132 across the overwrite — the loss was content,
  not an entry.
* **194 → 196**: `+1` recovered `rule/1351@xschem-claude`, `+1` `rule/1400`. No
  other name appeared.
* Against the 09:37 image: **191 of 192 entries have line 1 byte-identical to
  live**; the one exception is `rule/1351`, and its 09:37 line 1 is now back in the
  ledger — `md5sum` of `head -n1` matches `rule/1351@xschem-claude` exactly.
* **Nothing added by the live op-wcard session since the backfill.** No file mtime
  is newer than 12:18:52; `look/` and `suite/` mtimes still 10:46:33; op-wcard's
  `NUMBERING.md` pointer still reads **1354** at 12:27.

Backfill write ordering, from live file mtimes (`find -printf '%T@ %p' | sort -n`):
recovery first at **12:18:24.591**, the 195-entry stamp pass **12:18:37.45 →
12:18:38.94** (~1.5 s), `rule/1400` last at **12:18:51.238**. Consistent with the
driver's account.

### Attribution: 14 / 182, and how much of it is measured

`tail -n +2 "$f" | /usr/bin/grep -m1 '^repo:'` over all 196:

* **182** `repo:/home/analog/dev/xschem-claude`, **14** `repo:/home/analog/dev/xschem-op-wcard`
* `repo_via`: **195 `told`**, **1 `git`** — the `git` one is `rule/1400`, the only
  entry written by the tool itself. The other 195 are the driver's assertion.

I cross-checked the assertion where evidence exists. For the 84 entries carrying a
`ref:`, testing whether the target resolves in each clone:

```
both=39   here-only=43   wcard-only=2   neither=0
```

**Zero mismatches**: no entry stamped `xschem-claude` has a ref that resolves only
in op-wcard, and no entry stamped `xschem-op-wcard` has a ref that resolves only
here. The 2 `wcard-only` refs are precisely `rule/1339` and `rule/1351`, the two
foreign rules. All 14 foreign claims are independently corroborated — 2 rules by
ref, 10 looks named `hier_pdf_links_*` (op-wcard's PDF-links batch), and 2 suites,
`test_hier_pdf_links_1333` and `test_ps_valid_1350`, whose files **exist in
op-wcard and not here** (the other 7 suites resolve in both, so that test says
nothing about them).

A targeted sweep of the contested band — every entry whose id starts `133x`–`135x`
— shows a coherent split: op-wcard holds `1339` (pdf-link-hotspot) and `1351`
(font/PostScript); this clone holds the RDW/ASE ones, including `1339_R3_…` beside
op-wcard's bare `1339`. A keyword sweep for op-wcard-flavoured subjects among the
182 returned only false positives (`ps_` inside "dum**ps_**urvive", "tooltips__",
"fli**ps_b**etween").

**Stated limit:** 45 of 196 attributions are corroborated by evidence outside the
stamp; **151 rest on the driver's assertion alone** and are marked `repo_via:told`,
which is honest. Note also that `cmd_add` preserves a prior `repo_via`
(owed.sh:527), so a `told` stamp never upgrades to `git` on a later same-clone
update — those 195 will read `told` permanently.

## FIXES

**F-1 (the one that matters). `rule/1400` was filed on the bare id, and the other
clone can still destroy it at exit 0.** LEDGER.md's N1 row says it twice —
*"Driver still owes the `rule` debt on 1400 — **and must NOT use the bare id
`1400`**"* — and the live ledger holds `rule/1400`, bare. Reproduced against a
`cp -a` copy, using the script op-wcard actually runs:

```
XSCHEM_OWED_DIR=<copy> bash /home/analog/dev/xschem-op-wcard/tests/headless/owed.sh \
    add rule 1400 "op-wcard would file its own 1400 here"
owed: recorded rule debt: 1400        rc=0
```

md5 `f14176f4…` → `cacc9d32…`. The 651-byte entry becomes 62 bytes; the `ref:` to
`1400-two-clones-filed-the-same-issue-numbers-and-neither-could-see-the-other.md`
and the `repo:` stamp are gone; the word printed is *recorded*. The backfill does
**not** prevent this: the refusal lives in this clone's `owed.sh`, and op-wcard's
copy is `md5 cc88328d…` — identical to this clone's `HEAD`, with a clean
`git status`. Worse, **the repaired `owed.sh` is still uncommitted here**
(`git status --porcelain` → ` M tests/headless/owed.sh`, 531 insertions vs HEAD),
so op-wcard cannot obtain the protection even by pulling.

Risk is real but not imminent: op-wcard's pointer reads **1354**, so it is 46
numbers from 1400 — the same band it is already walking at roughly one an hour.
This is the batch's own ruling — the one entry whose loss would be self-refuting —
sitting on the single id in the ledger that the other clone is guaranteed to reach.

Options, none of which I took (the live ledger is read-only to me, and re-siting an
entry is a destroy-and-recreate the user should authorise):
(a) re-site it as `rule/1400@xschem-claude` — the shipped tool cannot mint that
name while our own entry occupies the bare slot, so it is a hand-write plus a
`clear`, and `cleared.log` should capture the pre-image; (b) commit `owed.sh` and
get op-wcard onto it — blocked for op-wcard by D-1, and D-1 does not block the
commit here; (c) knowingly accept the 46-number head start. My recommendation is
(b) then (a).

**F-2. Relabel the 09:20 backup.** It was taken at **09:37:32**, and the batch had
been running since 09:34:12. LEDGER.md's close-out calls it "taken at 09:20 before
any item ran". Both halves are wrong; the evidence it holds is unaffected (§6).

## Observations, not defects

* `rule/1341_nonfinite_in_the_devices_bucket` has **two `eyes:1` lines**,
  pre-existing since at least 09:37 and inert. Only malformed entry in the ledger.
* **Every live file's mtime is now 12:18** — the original per-entry mtimes survive
  only in the two backups. Nothing user-visible depends on them (`list`'s age comes
  from line 1's epoch: the recovered entry was written at 12:18 and lists as `5d`).
  **Do not delete either backup.**
* `show` heads both 1351 rulings with the bare `1351`; they are distinguished by
  `filed in another clone:` and by their `clear with:` lines. owed.sh's design, not
  the recovery's doing.
