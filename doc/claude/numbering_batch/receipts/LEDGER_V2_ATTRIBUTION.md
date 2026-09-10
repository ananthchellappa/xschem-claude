# V2 — attribution. Is the 14 / 181 split right?

**SOUND**

The split is correct. I re-derived it by six routes that do not use the driver's
marker rule, and **found zero misattributed entries in 196** and **zero entries I
could not attribute**. The earlier audit's "12 entries with no recorded line in any
transcript" are all twelve resolved below — they were written by one command from
this clone with `>/dev/null 2>&1` on every `add`, which is why no output line exists.

Two things the user should still know, neither of them a stamping defect: the
driver's *marker rule* is a fingerprint of one op-wcard batch, not a rule, and the
absorption merge is already scheduled to break half of it (§5); and op-wcard's look
queue carries a **duplicate H4 entry its own author tried to delete**, which the
backfill has now frozen in place (§6a).

Everything below is measured unless labelled INFERRED. Every count names its command.
The live ledger was never written and `owed.sh` was never run against it.

---

## 0 — snapshots, and whether the ledger moved

| | time (-0700) | rule | look | suite | total |
|---|---|---|---|---|---|
| open of pass | 2026-09-10 **12:20:32** | 134 | 53 | 9 | **196** |
| close of pass | 2026-09-10 **12:30:42** | 134 | 53 | 9 | **196** |
| final re-take | 2026-09-10 **12:35:40** | 134 | 53 | 9 | **196** | (op-wcard stamps still 14)

```
find /home/analog/.claude/xschem_owed/<kind> -maxdepth 1 -type f | wc -l
diff -rq <my 12:20:32 cp -a copy> /home/analog/.claude/xschem_owed   -> no output
```

**The ledger did not move during my pass.** The op-wcard session was alive (its
transcript's last record at 12:33 was 12:22:13) but wrote nothing to the ledger
between 12:20:32 and 12:31:58. All work below was done on a `cp -a` snapshot taken
at 12:20:32; the closing counts were re-taken from the live directory.

Stamp counts, taken 12:31:58:

```
find /home/analog/.claude/xschem_owed -type f -exec /usr/bin/grep -l '^repo:/home/analog/dev/xschem-op-wcard$' {} + | wc -l   -> 14
find /home/analog/.claude/xschem_owed -type f -exec /usr/bin/grep -l '^repo:/home/analog/dev/xschem-claude$'   {} + | wc -l   -> 182
find /home/analog/.claude/xschem_owed -type f -exec /usr/bin/grep -L '^repo:' {} + | wc -l                                    -> 0   (unstamped)
find /home/analog/.claude/xschem_owed -type f -exec /usr/bin/grep -c '^repo:' {} + | /usr/bin/grep -cv ':1$'                   -> 0   (double-stamped)
find /home/analog/.claude/xschem_owed -type f | wc -l                                                                         -> 196
```

**The live ledger reads 14 / 182, not 14 / 181.** The backfill stamped 195 (14 + 181);
`rule/1400` was filed afterwards by `owed.sh` itself and carries `repo_via:git`. Every
other entry carries `repo_via:told`. A reader re-checking the driver's number should
expect **182**. Not a discrepancy — an off-by-one in the *reporting* window.

The backfill was purely additive. For all 194 entries present in the 12:18 backup,
stripping `^repo:` and `^repo_via:` from the live file reproduces the backup
byte-for-byte:

```
for f in $(cd bak1218 && find . -type f); do
  diff -q <(/usr/bin/grep -v '^repo:\|^repo_via:' live/$f) bak1218/$f; done
-> identical-after-stamp-strip: 194   problems: 0
```

---

## 1 — the six independent methods

### M1 — the op-wcard clone did not exist before 2026-09-03 21:49:44

```
cd /home/analog/dev/xschem-op-wcard && git reflog --date=iso | tail -1
  052b29f1 HEAD@{2026-09-03 21:49:53 -0700}: clone: from https://github.com/ananthchellappa/xschem-claude.git
stat -c '%w' /home/analog/dev/xschem-op-wcard/.git
  2026-09-03 21:49:44.014127823 -0700
```

Its transcript starts **2026-09-03 21:51:02** — 78 s after the clone. Coverage is
therefore complete from the clone's birth.

**39 of the 196 entries carry an epoch earlier than 1788497384 (the clone's birth).
0 of those 39 are stamped op-wcard.** Those 39 are structurally unattributable to
op-wcard: the clone did not exist. This is a hard bound, not an inference.

### M2 — which session was alive when the entry was written

I built a timestamp index of every record in both project transcript trees
(`opw` 66 jsonl / 16,901 records; `cld` 535 jsonl / 103,660 records) and asked, for
each entry's epoch, which clone had a session record within ±30 s.

| stamped | only op-wcard alive | only this clone alive | both alive |
|---|---|---|---|
| xschem-op-wcard (14) | **6** | **0** | 8 |
| xschem-claude (182) | **0** | **168** | 14 |

**Zero contradictions.** No claude-stamped entry was written in a window where only
op-wcard was alive, and no op-wcard-stamped entry in a window where only this clone
was. The 14 claude-stamped "both" rows are all ASE-L / RDW subjects
(`rule/0643`, `rule/1389…1393`, `look/ASE-L_*`, `suite/test_ase_core`, …), which is
this clone's work by subject.

### M3 — the write command itself, keyed by its `cwd`

I extracted every Bash `tool_use` whose command invokes `owed.sh add`, from every
`.jsonl` in both project trees, and recorded the transcript record's own `cwd` field.

**op-wcard's real-ledger `add` invocations are exactly these, and nothing else:**

```
09-08 14:30:03  look hier_pdf_links_1333          + suite test_hier_pdf_links_1333
09-08 15:20:35  look hier_pdf_links_route4
09-08 17:44:26  look hier_pdf_links_1333_H1a      + suite test_hier_pdf_links_1333
09-08 19:29:56  look hier_pdf_links_1334_H1b      + suite test_hier_pdf_links_1333
09-09 18:56:29  look hier_pdf_links_1336_1337_H2  + suite test_hier_pdf_links_1333
09-10 00:42:32  look hier_pdf_links_1338_1339_H3  + rule 1338 + rule 1339 + suite test_hier_pdf_links_1333
09-10 01:34:58  look hier_pdf_links_1338_1339_H3_menu
09-10 08:25:52  look hier_pdf_links_1338_H4       + suite test_hier_pdf_links_1333
09-10 09:12:27  look hier_pdf_links_1338_H4       (after a failed clear — see §6a)
09-10 10:46:13  rule 1351
09-10 10:46:30  look hier_pdf_links_1343_H5       + suite test_ps_valid_1350
```

That is **15 distinct (kind, subject) pairs**. `rule 1338` was cleared by op-wcard
itself at **09-10 06:54:09** (`owed.sh clear rule 1338`, cwd `/home/analog/dev/xschem-op-wcard`),
which leaves **exactly the 14 the driver stamped**. The first op-wcard `add` that
reached the real ledger is 09-08 14:30:03: between the clone's birth (09-03 21:49) and
that moment op-wcard ran for 4½ days and filed **nothing**.

op-wcard's only two real-ledger `clear` invocations are `rule 1338` (its own, above)
and `look hier_pdf_links_1338_H4` (its own, failed). **No cross-tree destroy by
`clear` in either direction.**

### M4 — `owed.sh`'s own output line, keyed by `cwd`

I matched each entry against `owed: (recorded|updated) <kind> debt: <subject>` found
inside `tool_result` blocks, within ±180 s of the entry's epoch.

* 170 of 182 claude-stamped → this clone only.
* 12 of 14 op-wcard-stamped → op-wcard only.
* 12 claude-stamped → **no output line anywhere** (resolved in §2).
* 2 op-wcard-stamped → matched in *both* trees, purely because this clone later
  `cat`-ed a receipt that quoted the line. Verified by opening the records:
  `…/subagents/workflows/wf_cc9ae996-41f/agent-a247cbcfea1adf0ed.jsonl:23` is the
  tool_result of `cat …/receipts/N1_ADVERSARY.md`, not a write. **M4 is contaminated
  by quotation and must not be used alone**; M3 disambiguates both cleanly.

### M5 — `ref:` resolution plus git provenance in both trees

```
stamped xschem-claude : ref resolves in both 39 | claude-only 43 | op-wcard-only 0 | dangles 0 | no ref 100
stamped xschem-op-wcard: ref resolves in both  0 | claude-only  0 | op-wcard-only 2 | dangles 0 | no ref  12
```

Zero contradictions. Corroborated with history rather than the working tree:

```
cd xschem-claude   && git log --all --oneline -- doc/claude/issues/1339-pdf-link-hotspot-tracks-name.md                        -> 0 commits
cd xschem-claude   && git log --all --oneline -- doc/claude/issues/1351-font-attribute-is-a-postscript-name-and-a-format-string.md -> 0 commits
cd xschem-op-wcard && git log --all --oneline -- doc/claude/issues/1339-select-and-ctrl-c-do-not-copy.md                        -> 0 commits
cd xschem-op-wcard && git log --all --oneline -- doc/claude/issues/1351-the-poll-guard-…-outlives-its-text.md                   -> 0 commits
```

Each tree's 1339 and 1351 issue file is absent from the other tree's entire history.
(`1351-font-attribute-…md` is not committed even on op-wcard — it is live working-tree
work there, which is stronger still.)

### M6 — the two backups differential

```
diff <(cd bak0920 && find . -type f | sort) <(cd bak1218 && find . -type f | sort)
  + ./look/hier_pdf_links_1343_H5.1789062393.2136295
  + ./suite/test_ps_valid_1350
cmp every common file  ->  DIFFERS: ./rule/1351     (only that one)
```

Between 09:20 and 12:18 the ledger changed in exactly three places, and **all three
are op-wcard's**, matching M3's 10:46:13 / 10:46:30 invocations. The recovery is exact:

```
diff <(/usr/bin/grep -v '^repo:\|^repo_via:' live/rule/1351@xschem-claude) bak0920/rule/1351
-> IDENTICAL
```

---

## 2 — the twelve "unattributable" entries, resolved

The earlier audit was right that no `owed:` output line exists for these twelve. The
reason is in the command, not the ledger. **One** Bash call, transcript
`1e23e38a-…jsonl:9124`, `cwd = /home/analog/dev/xschem-claude`,
**2026-09-05 00:43:12 -0700**:

```sh
cd /home/analog/dev/xschem-claude
for d in DD-1_rdw_one_cursor_new_block_clears_it DD-2_rdw_cursor_shade_derived_from_palette \
         DD-3_rdw_updown_act_on_the_cursored_row DD-4_rdw_only_lists_1_and_2_rerender_the_sheet \
         DD-5_rdw_ctrlc_writes_CLIPBOARD_and_a_menu_exists DD-6_rdw_raise_without_activation \
         DD-7_rdw_eng_notation_must_not_blank_anything DD-8_rdw_copy_measured_on_the_real_X_server; do
  tests/headless/owed.sh add rule "$d" "RDW batch driver decision, user away 7h; …" >/dev/null 2>&1
done
tests/headless/owed.sh add look "the_RDW_line_cursor_shade"        "…" >/dev/null 2>&1
tests/headless/owed.sh add look "the_RDW_raise_behaviour"          "…" >/dev/null 2>&1
tests/headless/owed.sh add look "the_RDW_select_and_copy_on_VcXsrv" "…" >/dev/null 2>&1
tests/headless/owed.sh add look "the_RDW_engineering_notation"     "…" >/dev/null 2>&1
```

`_say` writes to stderr; `>/dev/null 2>&1` discarded it. All twelve entries carry
epoch **1788594194** — 2 s after the command. Twelve entries, one command, one clone.
**Attributed to `/home/analog/dev/xschem-claude`, confidence HIGH.** The driver's
stamp on all twelve is correct.

A thirteenth entry, `rule/1351@xschem-claude`, has no `add` that names that filename
because the driver restored it with `cp`. Its *original*, `rule/1351` at epoch
1788626525, was written by this clone at **09-05 09:42:03**, transcript command
quoted verbatim in M3's sibling scan, `cwd = /home/analog/dev/xschem-claude`.
Stamp correct, confidence HIGH.

Also worth recording so nobody re-derives it: a small residue of the DD-* subjects
appears in this clone's transcripts at 12:21–12:26 today. That is **my own scan
output being logged**, not a ledger event.

---

## 3 — the verdict, entry by entry, on the 14

All 14 confirmed op-wcard. `ACT` = M2's ±30 s activity verdict.

| entry | written | ref | ACT | M3 command | verdict |
|---|---|---|---|---|---|
| `look/hier_pdf_links_1333.1788903005.2785484` | 09-08 14:30:05 | none | opw | yes | op-wcard, HIGH |
| `look/hier_pdf_links_1333_H1a.1788914668.3154304` | 09-08 17:44:28 | none | both | yes | op-wcard, HIGH |
| `look/hier_pdf_links_1334_H1b.1788920998.3399581` | 09-08 19:29:58 | none | both | yes | op-wcard, HIGH |
| `look/hier_pdf_links_1336_1337_H2.1789005391.203017` | 09-09 18:56:31 | none | both | yes | op-wcard, HIGH |
| `look/hier_pdf_links_1338_1339_H3.1789026154.688703` | 09-10 00:42:34 | none | opw | yes | op-wcard, HIGH |
| `look/hier_pdf_links_1338_1339_H3_menu.1789029300.830550` | 09-10 01:35:00 | none | opw | yes | op-wcard, HIGH |
| `look/hier_pdf_links_1338_H4.1789053953.1120675` | 09-10 08:25:53 | none | both | yes | op-wcard, HIGH — **see §6a** |
| `look/hier_pdf_links_1338_H4.1789056750.1637118` | 09-10 09:12:30 | none | opw | yes | op-wcard, HIGH — **see §6a** |
| `look/hier_pdf_links_1343_H5.1789062393.2136295` | 09-10 10:46:33 | none | both | yes | op-wcard, HIGH |
| `look/hier_pdf_links_route4.1788906037.2869812` | 09-08 15:20:37 | none | opw | yes | op-wcard, HIGH |
| `rule/1339` | 09-10 00:42:34 | op-wcard-only | opw | yes | op-wcard, HIGH |
| `rule/1351` | 09-10 10:46:14 | op-wcard-only | both | yes | op-wcard, HIGH |
| `suite/test_hier_pdf_links_1333` | 09-10 08:25:53 | none | both | yes | op-wcard, HIGH |
| `suite/test_ps_valid_1350` | 09-10 10:46:33 | none | both | yes | op-wcard, HIGH |

**Misattributed entries: none. Unattributable entries: none.**

The five ledger entries that sit on a **collided issue number** — the place a wrong
stamp costs the most — each independently confirmed:

| entry | stamp | M3 | M2 | ref in claude | ref in op-wcard |
|---|---|---|---|---|---|
| `rule/1339` | op-wcard | opw | opw | no | yes |
| `rule/1344` | claude | cld | cld | yes | no |
| `rule/1351` | op-wcard | opw | both | no | yes |
| `rule/1351@xschem-claude` | claude | cld (via subject) | cld | yes | no |
| `rule/1352` | claude | cld | cld | yes | no |
| `rule/1353` | claude | cld | cld | yes | no |

(There are **12** true collisions as of 12:2x today — 1338, 1339, 1344–1353 — measured
by comparing `ls doc/claude/issues | /usr/bin/grep -oE '^[0-9]{4}'` in both trees and
keeping the numbers whose filenames differ.)

---

## 4 — is any error dangerous? (asked separately, as instructed)

There are no errors, so nothing is live. Recording the shape anyway, because it is
what the next backfill has to be judged against:

* **A wrong *claude* stamp on an op-wcard entry is worse than the mirror.** It refuses
  op-wcard on its own ruling (exit 5) **and** it leaves this clone able to overwrite
  that entry silently at exit 0 — the pre-backfill hazard, preserved for exactly the
  entries the stamp got wrong, while it is removed everywhere else. That is the
  direction I checked hardest: M1 excludes 39 outright and M3/M4 positively place all
  182, so no claude stamp rests on "op-wcard has no evidence".
* **Suite debts are the one operationally dangerous axis**, because `cmd_drain` runs a
  file resolved against the *stamped* clone. Measured:

  | suite debt | stamp | `.tcl` here | `.tcl` in op-wcard | same file? |
  |---|---|---|---|---|
  | `test_annot_declutter_1244` | claude | yes | yes | identical |
  | `test_ase_core` | claude | yes | yes | **DIFFER** |
  | `test_ase_dialogs` | claude | yes | yes | **DIFFER** |
  | `test_ase_simdlg_0937` | claude | yes | yes | **DIFFER** |
  | `test_ase_window` | claude | yes | yes | **DIFFER** |
  | `test_rdw_keys_1245` | claude | yes | yes | **DIFFER** |
  | `test_rdw_window_1245` | claude | yes | yes | **DIFFER** |
  | `test_hier_pdf_links_1333` | op-wcard | **no** | yes | n/a |
  | `test_ps_valid_1350` | op-wcard | **no** | yes | n/a |

  Six of the seven claude suite debts name a file that also exists in op-wcard with
  **different content** — that was the live wrong-suite-run hazard, and the stamps
  close it in the right direction. The two op-wcard suite debts name files that do not
  exist in this clone at all, so even a mis-stamp there could not have produced a
  wrong-suite pass here.

* **`repo_via:` is inert.** `/usr/bin/grep -n 'repo_via\|_stamp_as' tests/headless/owed.sh`:
  written at `:289`, read at `:518` **only to carry a previous value forward**. Every
  ownership decision reads `repo:` through `_entry_repo`. So a `told` stamp enforces
  exactly like a `git` one. The field is honest bookkeeping, not a confidence level the
  tool acts on — nobody should read `told` as "provisional".

---

## 5 — is the driver's marker rule sound going forward?

**No. It is a fingerprint of one op-wcard batch, not a rule, and the absorption merge
is already scheduled to break the half of it that isn't.** It is *correct on today's
data* — I ran it mechanically over all 196 and it reproduces the stamps exactly:

```
predicate: 'hier_pdf_links' or 'test_ps_valid' in (id + subject), OR ref resolves only in op-wcard
mismatches vs the live stamps: 0
op-wcard predicted by marker string only: 12 | by ref-only: 2 | by both: 0
claude-stamped entries whose FULL TEXT contains either marker: 0
```

That last line is the tell rather than the reassurance: **the two halves never
overlap**, so every one of the 14 rests on a *single, unreplicated* signal. Nothing
in the rule cross-checks anything.

What breaks it:

1. **The absorption merge (D-2) kills the `ref:` half outright, and it is the *only*
   signal holding `rule/1339` and `rule/1351`.**
   `doc/claude/issues/1339-pdf-link-hotspot-tracks-name.md` is committed on op-wcard
   (`e451892b`); D-2 measured every colliding issue file as a **clean add**. The moment
   the merge lands, that `ref:` resolves here too and the rule hands op-wcard's 1339
   ruling to this clone — the exact "refused on your own ruling" failure, on the one
   ruling that names a collided number.
2. **`hier_pdf_links` / `test_ps_valid` are one batch's names.** 12 of the 14 rest on
   that literal string, and **12 of the 14 have no `ref:` at all** — there is nothing
   to fall back to. op-wcard's next batch names nothing of the sort; those entries
   would silently be claimed by this clone. (op-wcard also ran for 4½ days filing
   nothing, so the marker set was never even representative of that clone — it is
   representative of one week of one feature.)
3. **A `ref:` that resolves nowhere reads as this clone's.** Today 0 of 196 dangle in
   both trees, so the rule never met the case. A renamed issue file makes it happen,
   and this project renames issue files (0420–0432, +80). A claude entry that dangles
   is handed to claude — right by luck. An **op-wcard** entry that dangles is *also*
   handed to claude — wrong, and in the worse direction of §4.
4. **A `ref:` older than the fork resolves in both, forever.** Both clones descend from
   one repo; 39 claude entries already have refs resolving in both trees, and any
   op-wcard entry pointing at a pre-09-03 file would be invisible to the ref half.
5. **The rule is a claim about the past that the ledger cannot re-derive.** Nothing on
   disk records why an entry was stamped; `repo_via:told` records only that a human
   asserted it, and §4 shows nothing reads that field. Re-checking the split means
   re-reading session transcripts, which are not a durable artefact and which already
   contaminate themselves by quotation (M4). This receipt is currently the only
   durable evidence that the 14 are the 14.

What is actually sound, and needs no rule: **`_origin()` at write time**, which the
shipped `owed.sh` already does. The backfill is a one-time bridge and should not be
repeated. If a third clone ever appears, the answer is not a longer marker list — it
is that unstamped entries get stamped by whoever next touches them, one at a time,
by measurement.

If a backfill ever *is* needed again, the discriminator to use is the one used here:
**the `cwd` of the Bash `tool_use` that produced the entry, matched to the entry's
epoch.** It is signal-bearing for 195 of 196 entries (the 196th, `rule/1351@xschem-claude`,
is a `cp`, and its original is signal-bearing), against 14 of 196 for the marker rule.

---

## 6 — found in passing, attribution-adjacent, and it costs the user

### 6a — the user's look queue carries a duplicate H4 that op-wcard tried to delete

Both `look/hier_pdf_links_1338_H4.*` entries are correctly stamped op-wcard, and
**both are standing**. They should be one. At **09-10 09:12:27** op-wcard ran, in one
command (`90c2d52e-…jsonl:3625`, cwd `/home/analog/dev/xschem-op-wcard`):

```sh
echo "=== correct the look-debt text (it carries the wrong reason) ==="
tests/headless/owed.sh clear look hier_pdf_links_1338_H4 2>&1 | tail -1
tests/headless/owed.sh add   look hier_pdf_links_1338_H4 "RULE-1 implemented: …"
```

and the result (`:3626`) was:

```
!! owed ERROR: no look debt with id 'hier_pdf_links_1338_H4' (see: tests/headless/owed.sh list)
owed: recorded look debt: hier_pdf_links_1338_H4
```

The `clear` could not match because a `look` id is `<slug>.<epoch>.<pid>` — the author
typed the slug. The `add` then created a *second* entry instead of replacing the first.
So the queue shows the same deliverable twice, and the 08:25:53 copy carries text its
own author called "the wrong reason". Nobody was told: the `clear` failure went to
stderr behind `| tail -1`, and the `add` reported success.

This is not the backfill's doing, and the stamps are right — but the backfill has now
made both entries durable, and **only the user can clear a look debt**. Flagging it so
it is a decision rather than a surprise.

### 6b — the count to quote is 14 / 182

See §0. `rule/1400` is this clone's and correctly `repo_via:git`.

---

## Boundaries kept

* Live ledger read-only; `owed.sh` never run against it; no `add`/`clear`/`drain`
  anywhere. All analysis on a `cp -a` snapshot in the session scratchpad.
* `/home/analog/dev/xschem-op-wcard` read only — `git log`, `git reflog`, `ls`, `find`,
  `cmp`. Nothing written, no checkout/restore/stash/clean/commit/push in either tree.
* Nothing under `~/.xschem/` touched. The xschem binary never launched.
* Every count above via `/usr/bin/grep`, `find`, `cmp`, `diff`, or python reading files
  directly. The bare `grep` function was not used for any number in this receipt.
* This receipt is the only file written.
