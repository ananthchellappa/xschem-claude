# N3 — adversary findings

**Verdict: SOUND WITH FIXES.**

Every number in `receipts/N3.md` that I re-took reproduced exactly, including
the RED run and its per-group breakdown. The item stayed inside
`tests/headless/test_owed.sh`, never wrote the real ledger, never wrote
op-wcard, never launched the binary. I found **one vacuous row** (a check that
cannot fail, proved by a mutation that escapes it), **one unverified code path**
the receipt should declare rather than imply, and **one count-as-floor** that is
environment-dependent. None of the three hides a defect in the shipped
`owed.sh`; all three weaken the evidence.

I also *measured* two things the receipt labelled as inferred or as another
item's — both hold.

---

## 1. Re-taken counts — all reproduce

Every number below with `/usr/bin/grep`, in
`/home/analog/dev/xschem-claude`, 2026-09-10 10:28–10:40.

| receipt claim | command | measured |
|---|---|---|
| `ALL PASS (181 checks, 1 skipped)` | `env -u DISPLAY OWED_TEST_DISPLAY=none bash tests/headless/test_owed.sh \| tail -1` | **identical**, 3 consecutive runs, 2.70 / 2.66 / 2.69 s |
| 0 failures / 181 ok lines | `/usr/bin/grep -c '^FAIL' green1.out` → 0 ; `/usr/bin/grep -c '^ok:' green1.out` → 181 | **0 / 181** |
| baseline 75 | HEAD suite + HEAD `owed.sh` in a scratch tree with a `doc/claude/issues` symlink | `ALL PASS (75 checks, 1 skipped)` |
| baseline 75 still holds on the NEW `owed.sh` | HEAD suite + working-tree `owed.sh`, same tree | `ALL PASS (75 checks, 1 skipped)` |
| RED `70 FAILED (111 passed, 1 skipped)` | `OWED_SH=<git show HEAD:…/owed.sh> …` | **identical** |
| 0 old rows red | `/usr/bin/grep '^FAIL' red_final.out \| /usr/bin/grep -Evc 'O2[3-9]\|O3[0-4]'` | **0** |
| 70 new rows red | same, `-Ec` | **70** |
| 36 new rows green | `/usr/bin/grep '^ok:' red_final.out \| /usr/bin/grep -Ec 'O2[3-9]\|O3[0-4]'` | **36** |
| per-group red table 4/5/2/9/8/7/8/6/5/4/9/3 | `/usr/bin/grep '^FAIL' red_final.out \| awk '{print $2}' \| sort \| uniq -c` | **O23 4, O24 5, O25 2, O26 9, O27 8, O28 7, O29 8, O30 6, O31 5, O32 4, O33 9, O34 3 — exact** |
| RED copy 459 lines, no origin code | `git show HEAD:tests/headless/owed.sh \| wc -l` ; `/usr/bin/grep -c 'repo:\|_origin_init'` | **459 / 0** (the 6 hits for `repo\|_origin` are `_issue_ref`'s comment and the word "reporting") |
| `+480/-3`, 353 → 830 | `git diff --stat`; `git show HEAD:… \| wc -l`; `wc -l` | **480 ++, 3 --; 353 → 830** |
| the three deleted lines | `git diff … \| /usr/bin/grep '^-' \| /usr/bin/grep -v '^---'` | **exactly the three named** (header `O1..O22`, `OWED="$HERE/owed.sh"`, the O13 skip wording) |
| old rows unaltered | `git diff -U0 \| /usr/bin/grep '^@@'` | insertions land at `+2`, `+11`, `+36`, `+342`, `+793`, `+805`, `+807`, `+815`. **The 75 old rows (old lines 31–330) are untouched**, so "none removed, none altered" is structural, not asserted |
| script sees GNU grep | `bash -c 'command -v grep'` ; `env \| /usr/bin/grep -c BASH_FUNC` | **`/usr/bin/grep` / 0** (`type -a grep` in a script: `/usr/bin/grep`, `/bin/grep`) |
| cwd does not matter | run from `/tmp` with an absolute path | `ALL PASS (181 checks, 1 skipped)` |

The RED run is real evidence: same suite file, same fixture, only the code under
test differs, and **not one of the 75 pre-existing rows moves**.

## 2. Independent sabotage — 10 fresh mutations, none of them the receipt's

Each is a single-anchor edit to a **copy** of the shipped `owed.sh`, run through
`OWED_SH`. The working-tree `owed.sh` was never touched (`git status` at the end
is byte-for-byte the status at the start).

| # | mutation | rows turned red |
|---|---|---|
| m1 | `_log_gone` writes to `$HERE/cleared.log` instead of `$OWED_DIR/…` | 8, all O33 |
| m2 | `cmd_clear` logs the pre-image **before** the origin check | 4: **O27 "a refusal destroys nothing"** + 3 O33 |
| m3 | `list` marks every `ref:` `(not in this clone)` | 1: **O34 "does not mark a ref that resolves here"** |
| m4 | `list` prints `from:` for this clone's own entries too | 1: **O34 "list names no clone"** |
| m5 | `_log_gone` writes the state-dir log **and** a stray copy at `$HERE` | **0 — ALL PASS (181)**, see §3 |
| m6 | `clear --repo here` no longer reaches the `<id>@<tag>` slot | 2, the O28 pair |
| m7 | `drain` claims an unattributed suite debt whose name resolves nowhere | 1: **O32 "stays unattributed"** |
| m8 | `--repo` on `clear` becomes a force (origin check dropped) | 2, the O29 not-a-`-f` pair |
| m9 | `drain` runs the **owning** clone's copy instead of skipping | 6, all O30 — including **"nor the other clone's"**, the witness row I most suspected |
| m10 | `cmd_list` globs `$OWED_DIR/cleared.log` as well as the kind dirs | 2: both O33 "not read as an entry" rows |

Nine of ten land, and the distributions corroborate the receipt's own matrix
without re-running it: m9 ≡ its s4 ("6 red, O30 only"), m1's 8 O33 reds ≡ its s6
("8 red, O33 only" — and the O33 row that stays green under both is the same
one, `an add that REPLACES says so`, which is a message not a log), m7 ≡ its s9
("1 red, O32 only"), m4 ≡ its s10 ("1 red, O34 only").

So the pristine-green rows the receipt defends in §1 as "paired" really are
paired: I turned red, individually, every one I doubted.

## 3. FINDING 1 — one row cannot fail, and a real escape walks past it

`tests/headless/test_owed.sh:761-762`

```sh
ck "O33 ...and nothing was written outside the state dir (R502)" 0 \
   "$(ls -1 "$FX" | $GREP -c 'cleared.log')"
```

`FX="$TMP/clones"` (`:376`) is the **parent** of the two fake clones. It is a
non-recursive `ls` of a directory `owed.sh` has no expression for: its only
write targets are `$d/$id` (`:446-448`), `$OWED_DIR/cleared.log` (`:240`) and
`$OWED_DIR/.rewrite.$$` (`:253`) — measured with
`/usr/bin/grep -nE '>[>]?[[:space:]]*"?\$' tests/headless/owed.sh`. Nothing in
`owed.sh` can put a file directly in `$FX`, so the row is **structurally unable
to go red**, whatever the code does.

That is not theoretical. **m5** makes `_log_gone` append its own line to
`$HERE/cleared.log` *in addition to* the state-dir log — i.e. ledger pre-images
leaking into a git checkout's `tests/headless/`, as untracked litter, which is
exactly what R502 exists to forbid — and the suite reports:

```
=== m5: RESULT: ALL PASS (181 checks, 1 skipped)
-rw-r--r-- 1 analog analog   147 Sep 10 10:33 …/mut/m5/tests/headless/cleared.log
```

The eight sibling O33 rows catch m1 (log **moved** out) because the state-dir
log then goes missing. They cannot catch m5 (log **also** written out), and m5
is the shape the rule is about. The one row named for the job is the one that
cannot do it.

To be clear about severity: the **shipped** `owed.sh` writes no stray file — I
checked the redirection list statically and the fixture dirs after a green run.
This is a hole in the evidence, not a live defect. But this batch's own standard
is that a verification which cannot fail is worse than none, and this is one.

## 4. FINDING 2 — the edited O13 branch has never been executed

The receipt's §8 records that every run used `env -u DISPLAY` or
`OWED_TEST_DISPLAY=none`; mine did too, under the same instruction. So the three
lines N3 added to the live arm — the `note:` announcement at `:807`, and
`[ "$DPY" = "none" ] && DPY=""` at `:805` — have only ever run in their false
arms. `1 skipped` in every published result reads as coverage; it is the
opposite.

What I could verify without launching anything, and did:

* `OWED_TEST_DISPLAY=none` → `skip: O13 (OWED_TEST_DISPLAY=none -- asked not to start the binary)`
* no `DISPLAY`, no `OWED_TEST_DISPLAY` → `skip: O13 (no display or no built binary)` (the pre-existing wording, preserved)
* with the live `$DISPLAY` **set** and `OWED_TEST_DISPLAY=none` → `ALL PASS (181 checks, 1 skipped)`, and nothing pops: `drain` hands only `.tcl` suites to `run_suites.sh` (`owed.sh:803`), every suite in the fixture is a `.sh`, so no gate and no binary.

**F1's condition is confirmed live**: `$DISPLAY` here is `172.20.160.1:0` (the
Windows X server), `src/xschem` exists (built 2026-09-05 20:05). A plain
`bash tests/headless/test_owed.sh` on this box does drive the user's real
screen. One bound the receipt does **not** state, and should:
`full_audit.sh:393` is `ls "$HERE"/test_*.tcl`, so `test_owed.sh` is **not** in
the audit set — F1 can only fire on a hand-run, never on an audit.

The fix is a sentence, not code. Verifying the live arm for real means launching
the binary, which this batch forbids; declaring it unverified costs nothing.

## 5. FINDING 3 — "75 → 181" is a floor that moves with the environment

Measured, with a `git` shim that exits 1 on `$PATH`:

```
env -u DISPLAY OWED_TEST_DISPLAY=none PATH=<shim>:$PATH bash tests/headless/test_owed.sh
  -> RESULT: ALL PASS (177 checks, 2 skipped)
  skip: O24 worktree/branch/remote legs (git cannot answer --path-format here)
```

Zero failures, four fewer checks. `LEDGER.md`'s baseline already says acceptance
is "name+status, never a count", so the suite is behaving correctly — but the
receipt and the ledger row both publish **181** as the number, and a reader
applying it as a floor will red a git-less box for passing. One clause fixes it.

Incidentally this is the only run in which the `else skipck` arm of the `GIT_OK`
gate has been exercised at all; it works.

## 6. What I measured that the receipt did not — both hold

**F4 is no longer inferred.** The receipt says "everyday output byte-identical
to HEAD is N2's measurement, not mine … inferred here, not re-measured." I
measured it, read-only on the real ledger, by working on a `cp -a` copy:

```sh
cp -a ~/.claude/xschem_owed $SC/realcopy/state          # 132 rule, 52 look, 8 suite
XSCHEM_OWED_DIR=$SC/realcopy/state ./tests/headless/owed.sh list   # new
XSCHEM_OWED_DIR=$SC/realcopy/state <HEAD copy>/owed.sh   list      # old
```

* `list`: **4 diff lines — one changed line**, and it is the intended marker on
  op-wcard's ref: `read: doc/claude/issues/1339-pdf-link-hotspot-tracks-name.md   (not in this clone)`.
* `show`: identical after normalising `$0` (the only other difference is the
  literal path each copy prints as its own invocation) — again **one changed
  line**, the same ref under `the options are in:`.
* `count`: `132 rule, 52 look, 8 suite` from both.
* All 192 real entries are unstamped: `/usr/bin/grep -rlc '^repo:'` over the
  three kind dirs → **0 files**.
* A real legacy clear against the copy:
  `owed.sh clear rule 0643` → `!! owed WARNING: rule '0643' predates origin stamps …` /
  `owed: cleared rule debt 0643`, **rc 0**, entry gone, pre-image in
  `cleared.log`. So every `clear rule <id>` quoted in a receipt or issue file
  elsewhere in the tree keeps working, measured against the actual entries
  rather than two synthetic ones.
* `diff -r -q` of the copy against the real ledger **before** that clear:
  identical — `list` and `show` write nothing.

**F2 reproduces verbatim**, in my own two-clone fixture, against the shipped
`owed.sh`: after `B add rule 3001 … --repo cloneA`, A's entry keeps
`repo:…/cloneA` but its `ref:` becomes B's file, and **A's own `list` marks A's
own entry `(not in this clone)`**. Confirmed, correctly assigned to N2's file,
and correctly left unpinned by a check.

## 7. Rules compliance — clean

* **D-1.** `/usr/bin/git -C /home/analog/dev/xschem-op-wcard status --porcelain`
  → `M src/psprint.c`, `M src/save.c`, `?? doc/claude/issues/1350..1353-*.md`,
  `?? tests/headless/test_ps_valid_1350.tcl`. That is the live PDF session
  `PLAN.md`/`DECISIONS.md` describe, not this batch: its mtimes are 10:05,
  10:19, 10:22 and **10:36** — the last one *during* my pass — and
  `ps` shows its own headless runs live
  (`/tmp/claude-1000/h5work/sab/tree/src/xschem --nogui --pipe -q --script …/test_ps_valid_1350.tcl`).
  op-wcard's **`tests/headless/owed.sh` and `test_owed.sh` are both dated
  2026-09-04 06:55:36** — untouched. `doc/claude/numbering_batch` does not exist
  there.
* **The real ledger was not written.** `132 rule / 52 look / 8 suite`, root
  mtime `2026-09-02 03:12`, `rule/` `06:54` (before the batch began at 08:19),
  `suite/` `Sep 9 15:14`, **no `cleared.log`** — the file every write path in
  the new code creates. Unchanged before and after all of my runs.
  `look/` is `09:12` and the count is **52**, one above `LEDGER.md`'s baseline
  of 51: the extra file is `hier_pdf_links_1338_H4.1789056750.1637118`, a
  PDF-links `look` debt written by the live op-wcard session. **A live
  op-wcard session moved it, not this batch.**
* **`~/.xschem/` was not touched by this batch.** `geometry` shows
  `10:39:26` — during my pass — but the writers are op-wcard's own
  `xschem --nogui` processes out of `/tmp/claude-1000/h5work/sab/tree` (PIDs
  2109370 / 2111813 observed live). `recent_files` is unchanged at
  `2026-09-09 21:53:48`. No binary was launched from this tree.
* **Files owned.** `git status --porcelain` is identical at the start and end of
  my pass. Among the five modified files, mtimes attribute cleanly
  (*inference from mtime, not proof*): `test_owed.sh` **10:23**, `N3.md`
  **10:27**; `owed.sh` and `specs/owed.md` **10:04** (N2, before N3 ran),
  `CLAUDE.md` **10:14** (N4), `NUMBERING.md` **09:51** (N1). **No file N3 does
  not own was written by N3.**
* No `git checkout/restore/stash/clean/commit/push`. No `owed.sh` run against
  `$HOME/.claude/xschem_owed`. No `/tmp/owedtest.*` left behind (the suite's
  `trap … EXIT` fires; 0 stray dirs).

## 8. Fix list

1. **`tests/headless/test_owed.sh:762`** — replace `ls -1 "$FX"` with a check
   that covers what `owed.sh` can actually reach, e.g.
   `find "$FX" "$TMP/bin" -name cleared.log | wc -l` expecting 0, or
   `ls -1 "$FX"/clone?/tests/headless "$TMP/bin" | $GREP -c cleared.log`.
   Acceptance: mutation m5 (a stray `cleared.log` at `$HERE` alongside the real
   one) must turn this row red. Today it passes 181/181. *(N3's file.)*
2. **`receipts/N3.md` §4/§8 and the `LEDGER.md` N3 row** — state that O13's live
   arm was **never executed** in any published run, that the `note:` line and
   `DPY=""` guard are therefore unverified in their taken branch, and that
   `full_audit.sh:393` globs `test_*.tcl` so `test_owed.sh` is outside the audit
   set. Do not launch the binary to close this.
3. **`receipts/N3.md` §1 headline and the `LEDGER.md` N3 row** — qualify the
   `181` floor: it is `181/1 skipped` where git answers `--path-format` and
   `177/2 skipped` where it does not, both `ALL PASS`. Acceptance stays
   name+status.
4. *(Optional, evidence quality.)* Fold §6's real-ledger measurement into the
   receipt so F4 stops being labelled inferred: `list` and `show` over a `cp -a`
   copy of the live 192-entry ledger differ from HEAD by exactly one line each,
   and a real legacy `clear rule 0643` exits 0 with the warning.

Nothing in this list changes a verdict the suite reaches today. Items 2 and 3
are wording; item 1 is a check that has never been able to fail.

---

*Adversary pass, 2026-09-10 10:28–10:45, read-only on the repo except this
file. Every count with `/usr/bin/grep`. Working files under
`/tmp/claude-1000/-home-analog-dev-xschem-claude/1e23e38a-228a-491e-a9b0-387bda9d283e/scratchpad`.*
