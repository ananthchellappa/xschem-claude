# N2 — adversary findings

**SOUND WITH FIXES**

Read-only pass over `tests/headless/owed.sh` and `doc/claude/specs/owed.md`
against `receipts/N2.md`. Every count in that receipt was re-taken with
`/usr/bin/grep`/`awk`/`cmp` and **every one of them survived**; the RED baseline
was independently reproduced against `git show HEAD:tests/headless/owed.sh`; the
verification commands can all go red. The item is real work with real evidence.

It nevertheless ships a **reproducible, exit-0 bypass of the single guard it
exists to install**, plus two smaller ownership holes, all with one root cause:
`cmd_add` decides ownership with the tag-tolerant comparator `_repo_same`, which
the file's own comment (`owed.sh:194`) and its own spec (`owed.md`, R608, last
bullet) say must never decide ownership. Fix 1 below is not cosmetic — it is a
failed acceptance criterion from PLAN N2 ("`cmd_add` on an existing `rule`/`suite`
id from **another** origin: **refuse, non-zero**").

It is **not live on this machine**: the two real clones are `xschem-claude` and
`xschem-op-wcard`, whose basenames differ. It becomes live the moment anyone
clones this repo twice under its own name, which is the ordinary shape.

---

## 1. Compliance — all clean

**D-1, op-wcard never written.**
`/usr/bin/git -C /home/analog/dev/xschem-op-wcard status --porcelain` →
`M src/psprint.c`, `M src/save.c`, and untracked
`doc/claude/issues/135{0,1,2,3}-*.md`, `tests/headless/test_ps_valid_1350.tcl`.
All PostScript/PDF-link work; nothing owed.sh-shaped, nothing numbering-batch
shaped. `ps -eo pid,lstart,cmd` at 10:37 shows that clone's own binary running
its own `test_ps_valid_1350.tcl`, so a live session there owns those edits. Its
`NUMBERING.md` tail now reads **"The next free number is 1354."** — it has filed
1350–1353 since N4 measured 1350 at ~10:16, which is worth the driver's
attention but is not N2's doing.

**The real ledger was not written.** Measured, read-only:

```
for k in rule look suite; do ls -1 "$HOME/.claude/xschem_owed/$k" | wc -l; done
        -> 132 / 52 / 8   (= 192, the number N2 states)
ls -1a $HOME/.claude/xschem_owed          -> . .. look rule suite   (no cleared.log)
/usr/bin/grep -rl '^repo:' $HOME/.claude/xschem_owed | wc -l   -> 0
/usr/bin/grep -rl '^ref:'  $HOME/.claude/xschem_owed | wc -l   -> 82   (control: the -r pattern does match)
find $HOME/.claude/xschem_owed -type f -printf '%T@ %p\n' | sort -rn | head -1
        -> 2026-09-10 09:12:30  look/hier_pdf_links_1338_H4...
```

Newest entry mtime **09:12:30**, before the batch's first receipt (09:35). State
dir root mtime **2026-09-02 03:12** — nothing has been created or removed in the
root since, which is the direct disproof of a `cleared.log` ever landing there.
All 8 suite entries still present with mtimes ≤ 08:25, so no `drain` ran against
it either. The 09:12 look entry is the live op-wcard session's, exactly as
`LEDGER.md`'s baseline note predicted.

**Scope.** `/usr/bin/git -C /home/analog/dev/xschem-claude status --porcelain`
shows `M CLAUDE.md` (N4), `M doc/claude/issues/NUMBERING.md` (N1),
`M doc/claude/specs/owed.md` + `M tests/headless/owed.sh` (N2),
`M tests/headless/test_owed.sh` (N3). mtimes sequence cleanly with the receipts:
NUMBERING 09:51:14 / N1 receipt 09:51:14; owed.md 10:04:20 and owed.sh 10:04:27 /
N2 receipt 10:05:53; CLAUDE.md 10:14:55 / N4 receipt 10:16:45; test_owed.sh
10:23:34 / N3 receipt 10:27:27. **N2 wrote only the two files it owns**
(attribution by mtime window — inferred, not directly observable).

**`~/.xschem/` — one item to disclose, and it is not `recent_files`.** Four
writes fall inside the batch window: `.clipboard.sch` 09:39:11,
`simulations/{clean,short}.spice` 09:39:09, `op_annot/` 09:42:17,
`geometry` 09:51:58. `recent_files` was **not** touched (Sep 9 21:53), so the
0924 hazard did not fire, and no bare `xschem` was involved.
`clean.spice`/`short.spice` are written by `test_ase_core.tcl`/
`test_ase_window.tcl` (`/usr/bin/grep -rln 'clean\.spice' tests/ src/ utils/`),
which O13 does not run — that traffic is not N2's. `geometry` at 09:51:58 sits
inside N2's window and is consistent with the one launch N2 discloses in its §9
("77/77 with a display" → O13 → `run_suites.sh test_calc_skeleton` → `src/xschem`
on `$DISPLAY`, the user's real Windows X server). No `.log` was left in
`tests/headless` because `run_suites.sh` runs `--nolog` and captures to a
variable (`run_suites.sh:121,125`), so log absence is not counter-evidence.
**Inferred, not proved** — other sessions were live in this tree. The disclosure
in N2's receipt is honest as far as it goes; it should also have said that the
launch writes `~/.xschem/geometry`, which the brief names.

---

## 2. Every count in the receipt, re-taken

| receipt claim | re-measured | verdict |
|---|---|---|
| ledger 132 rule / 52 look / 8 suite (192) | 132 / 52 / 8 | ✅ |
| `^repo:` in the live ledger → 0 | 0 (control `^ref:` → 82, so the pattern works) | ✅ |
| 82 of 132 rule entries carry a `ref:` | 82 | ✅ |
| exactly **1** ref fails to resolve here | 1 — `rule/1339` → `doc/claude/issues/1339-pdf-link-hotspot-tracks-name.md` | ✅ |
| **42 of the 82** fail to resolve in op-wcard | 42 | ✅ |
| 7 of 8 suite names resolve here, 6 of those differ (`cmp -s`) | 7 resolve here; `test_hier_pdf_links_1333` only there; 6 differ | ✅ |
| line 1 still exactly 3 tab fields after stamping | `awk -F'\t' 'NR==1{print NF}'` → 3 | ✅ |
| `ls -1 $HOME/.claude/xschem_owed` → `look rule suite` | identical | ✅ |
| `test_owed.sh` (HEAD) still 75/75 | **75 checks, 1 skipped, ALL PASS** | ✅ |
| `list` output identical bar the one marker | `diff` → **no differences**; 1 `(not in this clone)`, 0 `(another clone)` | ✅ |
| `list` 2.39 s → 1.36 s | HEAD 2.47/2.47/2.49 s, new 1.43/1.43/1.47 s (3 runs each, live-ledger copy) | ✅ direction and magnitude hold |

Method for the two suite runs: a symlink mirror of the tree in scratch, with the
delivered `owed.sh` and `git show HEAD:tests/headless/test_owed.sh` dropped in,
run as `env -u DISPLAY -u OWED_TEST_DISPLAY GUI_GATE=0 bash ./test_owed.sh`
(so O13 skips and no binary starts). I also ran the **current** suite
(N3's) against the delivered `owed.sh`: `RESULT: ALL PASS (181 checks, 1 skipped)`.

**RED is real, not a can't-fail check.** Reproduced independently against two
`git init` clones carrying `git show HEAD:tests/headless/owed.sh`:

```
$B add   rule 1344 "B's unrelated question"   -> owed: recorded rule debt: 1344   exit=0
                                                 A's ruling text gone, no warning
$B clear rule 1344                            -> owed: cleared rule debt 1344     exit=0
                                                 entry deleted
```

Also verified red-capable: `/usr/bin/grep -rlc '^repo:' <stamped fixture>` → 1.

**Two receipt wordings that are loose, not wrong**

* §7 says "7 resolve here, 7 resolve there". op-wcard resolves **8** of the 8
  (it holds `test_hier_pdf_links_1333` as well). §4's prose says this correctly;
  §7's shorthand reads as a second, different claim.
* §7 says the non-`test_owed.sh` matches are "ALL comments".
  `doc/claude/lookdebt_batch/build_page.py:52` is not a comment — it *emits*
  `owed.sh clear look <id>` into the look-debt digest page the user reads. It
  never executes owed.sh, so "no other executable consumer" stands, but that page
  now prints a command that **exits 5** for any look debt filed in another clone,
  and unlike `show` it does not print the `--repo` form. See fix 4.
* R608 hard-codes "**192 entries were standing when this landed**" into a
  permanent spec. It was 191 at 08:19 (LEDGER.md's own baseline) and 192 by 09:12.
  The sentence does carry the "the count moves" caveat; the number should not
  have been frozen into a requirement at all.

---

## 3. What breaks — reproduced, with commands

### F1 — BLOCKING. A plain cross-clone `add` still destroys a standing ruling, at exit 0, when two clones share a directory name

`cmd_add:422` decides ownership with `_repo_same`, which falls back to comparing
**basenames** (`_repo_tag`, `owed.sh:195-201`). `cmd_clear:628` decides it with
an exact string compare. So the two commands disagree, and `add` — the path PLAN
calls "the path with 35 loaded barrels" — is the permissive one.

Two clones, both named `xschem`, in different parents:

```
$P1 add rule 1344 'P1 STANDING RULING -- unanswered'
$P2 add rule 1344 'P2 unrelated question'          # no flags at all
   -> owed: updated rule debt: 1344  (id 1344, clone xschem)
   -> exit=0
```

Result on disk:

```
1789061565  1344  P2 unrelated question
repo:/…/p1/xschem            <-- still P1's stamp
repo_via:git
```

P1's unanswered ruling is gone, and the entry still claims to be P1's, so P1
will never see it as foreign. This is verbatim the defect PLAN describes
(`cmd_add` "…silently truncates this tree's standing 1344 ruling"), surviving in
the shipped fix. The only mitigation that fired is `cleared.log`, which does hold
the pre-image — real, and the reason this is recoverable rather than lost.

`owed.sh:194` states the invariant that is violated: *"ownership is compared on
the FULL id (`_entry_is_mine`, exact), and only a `--repo` the human typed may
match by tag."* `_entry_is_mine` (`:226`) is used in exactly one place — the
did-you-mean list at `:305` — and never in an ownership decision. `owed.md`'s
R608 makes the same promise in the same words.

**N3's suite cannot see this.** Its fixture is `mk_clone cloneA` / `mk_clone
cloneB` (`test_owed.sh:390-391`), distinct basenames throughout, and O29
(`:583-585`) *asserts the tag-tolerant behaviour as correct*. 106 new rows, and
the headline defect walks through them.

### F2 — BLOCKING. `--repo here` clears and overwrites another clone's entry, same cause

`cmd_clear:625` uses `_repo_same "$st" "$want"` for the `--repo` arm, and `here`
resolves to this clone's full origin — so a flag documented as "clear **your
own**" reaches another clone's file:

```
$P1 add   rule 1339 'P1: a ruling the user has NOT answered'
$P2 clear rule 1339              -> REFUSED, exit 5        (correct)
$P2 clear rule 1339 --repo here  -> owed: cleared rule debt 1339, exit=0
                                    entry DESTROYED
$P2 add   rule 1337 '…' --repo here -> overwrites P1's, keeps P1's stamp, exit 0
```

`owed.md` R609 says "A `--repo` naming a clone the entry is **not** filed in
refuses too. The escape is a statement of intent, not `-f`." `here` names this
clone; the entry is filed in another; it does not refuse.

### F3 — `add --repo <bare tag>` stamps the tag verbatim and locks the rightful owner out

`_repo_resolve:214` resolves a bare tag by searching the ledger for an existing
stamp ending in `/<tag>`. On the **first** such write there is none, so the tag
is stamped literally:

```
$B add rule 2001 'a ruling that belongs to A' --repo cloneA
   -> repo:cloneA        repo_via:told

$A clear rule 2001        # A is the owner
   -> !! owed REFUSED: rule 2001 belongs to another clone -- NOT cleared
      its clone: cloneA
      to clear THEIRS anyway: … clear rule 2001 --repo cloneA      # its own
   -> exit=5

$A add rule 2001 'A refines its own ruling'  -> exit=0    # but this works
```

That is precisely the failure `_repo_resolve`'s own comment says it exists to
prevent ("the clone it names would then read its OWN entry as foreign, which is
the refusal firing on the one person entitled to write"). The guard only works
once the ledger already knows the tag. Note also the asymmetry it exposes: `A`
can **overwrite** the entry (F1's comparator) but cannot **clear** it.

### F4 — `show` prints the bypass, so the refusal costs one copy-paste

Verified: `show` on a foreign look debt prints
`clear with: …/owed.sh clear look <id> --repo cloneA`, and running that verbatim
clears another clone's **look** debt at exit 0. N2 designed this deliberately
(receipt §6, "a queue that tells the user to type a command that gets refused is
worse than one that says nothing") and R609 sanctions `--repo`. But the failure
mode PLAN describes is an *agent* in tree B closing tree A's unanswered ruling,
and `show` now hands that agent the exact command with no friction and no
statement of consequence. **This one is a ruling, not a defect** — the driver or
the user should decide whether `show` prints the override, or prints
"filed in <clone> — clear it there" and leaves `--repo` to `help`.

### F5 — latent: `list`/`show` and `add`/`clear`/`drain` disagree about an unterminated entry

The new `_read_opts` (`:265-275`) reads with a bash `while read` loop, which
drops a final line that has no trailing newline; `_entry_field` (`:141-143`)
uses `sed`, which does not. Same file, two answers:

```
printf '1750000000\t4001\tP1 ruling\nrepo:/…/cloneA' > state/rule/4001   # no final \n
$B list rule   -> no "(another clone)" marker at all
$B clear rule 4001 -> REFUSED, exit 5
```

`ref:` and `eyes:` on a final unterminated line vanish from `list`/`show` the
same way. Before this change every reader went through `_entry_field`, so the
divergence is new. **Latent here**: 0 of the 192 live entries lack a trailing
newline (checked with `tail -c1 | od -An -c` over the `cp -a` copy).

### F6 — latent: a multi-line `why` forges the stamp

`why` is not sanitised, and `_entry_repo` takes the **first** `repo:` line:

```
$B add rule 9001 "$(printf 'B claims this\nrepo:/…/cloneA')"
   -> file holds repo:/…/cloneA  then  repo:/…/cloneB
   -> B is refused on its own entry (exit 5); A is offered it
```

Self-inflicted and unlikely, but it shows the stamp is positional, not
authenticated, and that line 1's "no newlines" contract is enforced nowhere on
write.

### F7 — latent, and a spec overclaim: a **worktree** that loses git turns its own entries foreign

R608 argues the `/.git` strip makes the git answer and the path fallback name the
same clone. True for the main worktree (verified: an entry filed with `git`
stubbed out to `exit 127` clears fine once git returns). **False for a linked
worktree**, where `--git-common-dir` gives the clone and the path fallback gives
the worktree:

```
wtA + git      -> repo:/…/cloneA   repo_via:git
wtA, no git    -> repo:/…/wtA      repo_via:path
wtA, no git, clearing its own 8001 -> REFUSED, exit 5
```

### F8 — minor: `cleared.log` is best-effort, and the destroy proceeds without it

With the state-dir root unwritable, `clear` warns and **still removes the entry**
at exit 0 (`_log_gone:239`, `>> "$log" … || _warn`). R610's whole argument is
that the pre-image is the difference between a ledger and luck; a pre-image that
can silently not happen is still luck. The raw shell redirect error also leaks to
stderr ahead of the warning.

---

## 4. What I could not break

* Both drain rewrite arms (FAILED and UNRESOLVED) preserve lines 2+ — `repo:`,
  `repo_via:` and a hand-written `verdict:` all survive; the foreign suite debt
  is skipped, kept, counted separately, exit unaffected; `rule` and `look` lists
  untouched; `cleared.log` records the drained pass with the full pre-image.
  Reproduced end to end in a two-clone fixture.
* The unattributed path: an entry with no `repo:` clears from either clone with
  one warning, and `add` claims it. The 192-entry backward-compatibility contract
  holds.
* `add --repo here` → `<id>@<tag>` slot, `clear --repo here` finds it back; the
  subject is left alone so `_issue_ref` still resolves. Round-trips.
* `add --repo <their tag>` keeps their stamp verbatim (the defect N2's §4 says V5
  caught — it really is fixed).
* `cleared.log` and `.rewrite.$$` in the state-dir root are invisible to `list`,
  `count`, `show` and `_repo_resolve` (which globs `*/*`, i.e. kind dirs only).
  The only root reader in the tree is `test_owed.sh:93` (`| grep -c banana`).
* `help` still renders (81 lines, ends on the new `exit 5` line).
* The `/.git` strip really does unify the git and path ids for a main worktree.
* Spec coverage: R608 ×11, R609 ×12, R610 ×4 mentions, R602/R301/R303 amended,
  §2's "every worktree" corrected at `owed.md:84-89`. Every PLAN N2 bullet is in
  the spec.

---

## 5. Fixes

1. **`owed.sh:422` — use an exact compare on the no-`--repo` path.**
   `elif _repo_same "$st" "$repo"` → `elif [ "$st" = "$repo" ]` (or call
   `_entry_is_mine`). Keeps `--repo <tag>`'s tolerance where a human typed it;
   removes it from the decision that must never be tolerant. Closes F1.
2. **`owed.sh:625` — make `--repo here` exact.** When the `--repo` argument was
   `here`/`HERE`/`.`, compare `"$st" = "$_ORIGIN"` rather than `_repo_same`.
   Same at `:409` for the namespacing decision, so `add --repo here` from a
   same-named clone gets its `<id>@<tag>` slot instead of overwriting. Closes F2.
3. **`owed.sh:214` — refuse an unresolvable bare `--repo <tag>` on `add`.** If
   the ledger holds no stamp ending in `/<tag>` and the argument is not a path or
   `here`, `_die … 2` telling the user to give the clone's path. Never stamp a
   tag as if it were an id. Closes F3.
4. **`doc/claude/lookdebt_batch/build_page.py:52`** (not N2's file — cross-item)
   should print the `--repo` form for a look debt whose entry is stamped to
   another clone, or the page will hand the user a command that exits 5. 51
   `owed.sh clear` lines across 22 files in the tree have the same exposure once
   entries start being stamped; all of them work today because 0 of 192 entries
   are stamped.
5. **Decide F4** — whether `show` should print `--repo` at all. A ruling for the
   user, not for the batch. Worth an `owed.sh add rule` entry of its own.
6. **`owed.sh:265` — read the optional fields with `sed`, or append a synthetic
   newline**, so `list`/`show` and `add`/`clear` cannot disagree (F5).
7. **`owed.sh:410` (`cmd_add`) — reject a `why`/subject containing a newline**,
   `_die … 2`. Line 1's contract is stated in three comments and enforced
   nowhere (F6).
8. **`owed.md` R608 — soften the worktree claim** to "the main worktree", or
   make the fallback ask for the common dir when it can (F7). And drop the frozen
   "192" from the requirement text; the caveat is already there.
9. **`owed.sh:239` — treat a failed `cleared.log` append as fatal for `clear`**
   (exit non-zero, keep the entry), or say in R610 that it is best-effort (F8).
10. **For N3** — the two-clone fixture needs a **third** clone sharing `cloneA`'s
    basename under a different parent. Every row in O23–O34 passes today with the
    comparator wrong; one same-basename pair turns F1 and F2 red. O29 currently
    pins the tag-tolerant behaviour as correct and would need re-aiming at
    `--repo` only.

---

## 6. Method

Read-only throughout. Repo untouched except this file. All ledger work against
`XSCHEM_OWED_DIR` inside
`/tmp/claude-1000/-home-analog-dev-xschem-claude/1e23e38a-228a-491e-a9b0-387bda9d283e/scratchpad`,
plus a `cp -a` copy of the live ledger for the read-only measurements;
`$HOME/.claude/xschem_owed` was never given to `owed.sh` as a target.
`/home/analog/dev/xschem-op-wcard` was read only (`git status`, `[ -e ]`,
`cmp -s`, `tail`). No xschem binary was launched — both suite runs were made with
`OWED_TEST_DISPLAY=none` / `-u DISPLAY` so O13 skipped, and `ps` confirms the only
running xschem processes belong to the op-wcard session's own tree. Every count
above was taken with `/usr/bin/grep`, `awk`, `ls -1 | wc -l`, `cmp` or `find`,
never the shell's `grep` function.
