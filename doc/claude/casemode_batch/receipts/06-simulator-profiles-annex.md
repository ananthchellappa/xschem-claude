# 06 — ANNEX: extend `sim()` / `simconf` / `simrc`, the profile MODEL

**This is the ANNEX to `receipts/06-simulator-profiles.md`.** The receipt proper
is the five-section, 120-line file of that name; this annex holds the long-form
detail the receipt cannot carry — the recovery narrative, the three inherited
defects in full, the twenty reviewer findings row by row, and both complete
mutation tables. Written by the implement/fix rounds, kept verbatim by the closer.

**Two closer corrections to the text below.** (1) The audit run this annex quotes
was produced by the FIX round; the closer re-ran `full_audit.sh` over the same
bytes and the batch's naming convention now holds — `audit_item06_fixround_2026-08-17.txt`
is the fix round's run, `audit_item06_closer_2026-08-17.txt` is the closer's. Both
diff EMPTY against the item-14 baseline; §7's numbers are unchanged.
(2) §1's line counts are superseded by the receipt's, which come from
`git diff --numstat`: `src/xschem.tcl` **+531 −0**, `src/ase.tcl` **+148 −3**,
five tracked files **+700 −9** in total.

**This is casemode batch ITEM 6.** The other `06-` receipt in this
directory — `06-one-lookup-authority.md`, plus its `-annex` — belongs to **item
5b**; the pipeline numbered both from the same `n`. Nothing in this file is about
5b and nothing in 5b's files is about profiles.

`PLAN.md` §3b item 6 · `DECISIONS.md` **B1** (both halves) + **A1**'s
requested-vs-measured split + **A2**'s per-profile `-n` · spec **NEW**:
`doc/claude/specs/simulator_profiles.md`. Base `d0eb835d`, `fluid-editing`,
nothing pushed, nothing committed at this stage. **Model only:** no probe (item
7), no run path (item 8), no widget (item 13). Pure Tcl, no C, nothing built.

## 0. RECOVERY RUN — what I inherited, and what I did to it

The first item-6 crew died on an API 529 while returning, so the pipeline saw
`impl == null` and **skipped Verify and all three Review lenses**. Its work
(470 insertions over 5 tracked files + 4 new files) sat on disk with **nothing
verified, reviewed or sabotaged**, and its own receipt asserted a 54-row
sabotage table that no agent had ever seen driven.

I did not start over and I did not trust it. What I found:

- **The scope is genuinely met.** The fields, the persistence, the state key, the
  no-Tk constraint and the `ase_simulators` prohibition are all as B1 requires.
- **Three real defects, each measured before it was believed** (§2). Two of them
  break a user's own `~/.xschem/simrc`; the third makes the resolver answer about
  an array nothing had built.
- **Its check count was wrong** — it claims 77, the file ran **78**. Counted from
  a run, not from the doc (`grep -c 'eqcheck '` says 79 and is wrong too: one of
  those is `proc eqcheck`).
- **One doc error inside the test**: its header credited the `sim_is_xyce` ruling
  to `CS163`; that ruling is `CS160`/`CS160b`. Fixed.
- **Its two `audit_item06_*.txt` files are DELETED, deliberately.** Its own §5
  disclosed that a first audit was launched *while sabotage mutations were still
  being applied* and then killed; both files came from that unreviewed run, and
  the tree has changed since. Item 5 shipped three audit files with a misnamed
  `_closer` and the ledger had to warn about it — one file, one name.
  (That round's own `audit_item06_impl_2026-08-17.txt` has since been deleted too;
  **`audit_item06_closer_2026-08-17.txt` is the authoritative audit of this item** —
  §7 says why.)
- **Its sabotage table is superseded, not repaired.** I did not attempt to
  reproduce 54 prose descriptions; I built my own table from scratch (§5), drove
  every row, and it covered all 82 checks *of that round*.

## 0b. SECOND PASS — the verifier's and reviewers' findings, fixed

The recovery round above was then verified and reviewed by three lenses, which
found **five more real defects in the code** (two of them in the very class the
round claimed to have closed), **eight coverage holes**, and **two bookkeeping
overclaims**. All are fixed or declared here. The suite is now **97 checks** (82 →
+15) and the numbers below are re-counted, not carried forward.

| # | finding | verdict | now covered by | red under |
|---|---|---|---|---|
| 1 | `sim_profile_valid` modelled the **list** parser, not the **script** parser: a value with backslash-newline was accepted, written, and came back one byte shorter — and a second save then differed from the first | **REAL, fixed** | `CS153g` | N01 · N02 · N03 |
| 2 | `subst -nocommands` does **not** stop a command substitution inside an **array index**: a stored `exe` ran `exec touch` during a pure staleness query | **REAL, fixed** (no `subst` on this path at all) | `CS157l` | N04 · N05 |
| 3 | the normalizer was gated on "did this call rebuild the array", so an **rc-appended row** stayed unshaped for the whole session; the check that covered it called the normalizer by hand | **REAL, fixed** (row-count memo) | `CS151f` (restated) · `CS151i` | N06 · N07 |
| 4 | `ase::sim_profile_resolve` accepted a **non-canonical index** (`02`, `-0`, ` 2 `) and reported `ok` while pointing at a row that does not exist | **REAL, fixed** (canonicalized) | `CS163l` | N21 |
| 5 | `sim_profile_selectable` offered `fold` for a binary that had been **probed and measured to deliver nothing** — a mode `sim_profile_supports` refused in the same breath (A1) | **REAL, fixed** (keys off `probed`) | `CS156g` | N11 · N12 |
| 6 | `CS166`'s Tk blocklist missed `canvas`, `menu`, `text`, `listbox`, `scrollbar`, `menubutton`, `destroy`, `focus`, `tk_*` | **REAL, fixed** (comments stripped, list widened, **sentinels** added so a blind detector fails) | `CS166` (restated) | N25 · N26 |
| 7 | an **invalid hand-edited** `simrc` value is silently deleted at the next save, and the spec only implied it | **DECLARED, not changed** — writing the raw value back can make the whole `simrc` unsourceable; ruled in spec §5 | `CS158g` | N17 |
| 8 | receipt/spec claimed "66 mutations" (round-1 scripts drive 64) and "616 lines" (617) | **bookkeeping, corrected** — see §5, and every count in this file is now from a run | — | — |
| 9 | nothing could catch `probe_record` recording a capability it was **not given** (A1's whole rule) | hole, closed | `CS157m` | N13 |
| 10 | `probed` — the one field whose purpose is surviving between sessions — was never asserted to persist | hole, closed | `CS158e` | N15 |
| 11 | persistence of the six fields was asserted for **`spice` rows only** | hole, closed | `CS158f` | N16 |
| 12 | both shape builders could plant **empty strings** instead of the field defaults (the `nospiceinit 0` hazard the normalizer exists for) | hole, closed | `CS151h` | N08 · N09 |
| 13 | `CS162` could not fail for the reason it names (the fallback also returns `spice`) | hole, closed | `CS162c` | N20 |
| 14 | the row dict's `fg`/`st`, `stamp`/`resolve`'s **tool** argument, and `probe_record`'s **timestamp** had no check that could move them | holes, closed | `CS159` (restated) · `CS163m` · `CS157c` (restated) | N18 · N19 · N23 · N24 · N14 |
| 15 | `CS150`'s stated evidential value ("a real before/after comparison") was a non-sequitur — the post-change persister emits the same bytes | **restated** in the check comment and in spec §5: `CS150` asserts determinism + additivity; the before/after evidence is §8's HEAD-binary `cmp` | `CS150` · `CS150b` | D1 |
| 16 | the verifier's V2/V3: `sim_profile_valid`'s `llength` arms for `args`/`detected` could `return 1` with the suite green | holes, closed — and they are **reachable**: an unmatched quote passes the line guard, and on the READ path a raise would abort the caller | `CS154g` | N27 · N28 |
| 17 | the verifier's V1: `sim_profile_supports`' mode guard moves nothing | **declared unreachable by construction**, with the proof, in spec §4; the guard is kept as defence in depth | — | N29 stays **green**, deliberately |
| 18 | the normalizer's own no-configuration guard had no check | hole, closed | `CS151j` | N10 |
| 19 | *(found by this pass, in its own fix)* a **bare CR** corrupts a value exactly as backslash-newline does (`0d` → `0a` through channel translation) | fixed with finding 1 | `CS153g` | N02 |
| 20 | *(found by this pass, in its own fix)* the replacement expander used `regexp -start` with a `^` anchor — which Tcl does **not** move — so a variable anywhere but offset 0 came back UNEXPANDED (`/opt/$env(HOME)/ngspice`) | fixed before the suite ever saw it green | `CS157n` | N35 · N36 |

**Three things this pass found that no reviewer had** (rows 19-20 above, plus a
test-harness one): my own first draft of `CS151h`/`CS162c` read
`$::sim(spice,1,exe)` and `$ase::backend_tools` **directly**, which under the master
red aborted the file after ONE check with **no `RESULT` line** — the exact trap the
LEDGER carries from items 1, 2 and 5b, and it would have made every later sabotage
read as "nothing went red". Both now go through abort-proof readers (`el`,
`pcall set`), the file carries a comment saying why, and the master red is a clean
`95 FAILED (2 passed)` with the two declared premise survivors.

**The expander defect is worth one more line, because it is the shape of mistake
this batch keeps paying for:** the fix for a *security* hole introduced a *silent
wrong answer* (an unexpanded path reads as "cannot locate", then "stale forever"),
and the existing checks could not see it because every `exe` in the file happened to
begin with its variable. `CS157n` drives a reference in the middle of a path, in
both reference forms.

**One pre-existing hole is left open on purpose and written down:**
`ase::expand_path` (`src/ase.tcl`) expands **model paths out of a state file** with
the same unsafe `subst -nocommands`, so `$env([exec …])/models` in a state file
runs that command. It is not item 6's code, its consumers are other items', and
narrowing model-path expansion here would be an unmeasured change to another
item's surface. Flagged in a comment at its own definition, ruled in spec §5, and
listed in this receipt's `problems` — it deserves its own issue.

## 1. Files changed

Counts from `git diff --numstat` and `wc -l`, after the second pass:

`src/xschem.tcl` **+519 −0** (6 fields, **20** procs — the second pass added
`sim_profile_expand_vars`, `sim_profile_shape_stamp` and
`sim_profile_normalize_if_changed` — the persister arm, the normalize call site,
`simconf_add`'s shape) ·
`src/ase.tcl` **+148 −3** (`sim_profile` in `schema_keys` + `omit_if_empty` +
`state_default`; **5** procs: `backend_tool`,
`sim_profile_resolve/casemode/stamp/clear`; plus the index canonicalization and
the `ase::expand_path` warning comment) ·
`tests/headless/test_sim_profiles.tcl` **NEW, 949 lines, 97 checks**,
`CS150`–`CS166` ·
`tests/headless/fixtures/simrc_pre_casemode` **NEW**, written by the
**pre-change** `save_sim_defaults` · `test_ase_core.tcl` **+1 check, 1
RESTATED** · `test_ase_persist.tcl` **1 RESTATED** · `full_audit.sh` **+1 word**
(`test_sim_profiles` → `nogui_tests`) · `specs/simulator_profiles.md` **NEW**.
**Not created:** `ase_simulators` — B1 killed it. **Untouched:** `run_cmd`,
`simconf`'s widgets, `sod_expr`, every `cmd`, all C.

**Check-id band measured, not quoted:** `grep -ohE 'CS[0-9]+'` over every
`tests/headless/*.tcl` except this item's own file → highest in use `CS149`
(`CS165` appears only as a cross-reference in the two restated comments). Band
`CS150`–`CS166`, contiguous.

## 2. THREE DEFECTS FOUND AND FIXED IN THE INHERITED WORK

Each was reproduced with a driver script before any edit, and each has a check
that reddens under the exact revert (M03 / M04 / M05 in §5).

### A. The persistence guard shipped a value that breaks the whole `simrc`

`sim_profile_valid` guarded storage with `info complete "{$value}"`. That is not
the test the writer needs. **Measured** — the three characters `a`,
close-brace, `b`:

```
value=<a}b>   valid = 1     set = accepted
emitted line: set sim(spice,2,exe) {a}b}
sourcing it : extra characters after close-brace
```

So a value the setter accepted made `~/.xschem/simrc` **unsourceable in its
entirety** — precisely the failure the guard exists to prevent, past the check
(`CS153d`) that claims to cover it. Replaced by the round trip itself: parse the
emitted line as a list, require three words, require the third byte-equal to the
value. Refuses the old cases (unbalanced open brace, trailing backslash) and
still accepts `$`, spaces, newlines and **balanced** inner braces. `CS153e`
drives the refusal, `CS153f` the acceptance through a real save + reload — so a
guard that refuses everything fails too (M59 proves that half).

**SUPERSEDED IN PART by the second pass (§0b finding 1): the list parse is not the
whole round trip either.** `llength`/`lindex` are the LIST parser and the `simrc`
is read by the SCRIPT parser, and inside braces they disagree on backslash-newline.
Two more refusals (backslash-newline, bare CR) and `CS153g` were added; the
acceptance half grew a lone backslash surviving a real save + reload.

Side trap, recorded in both the code and the spec: **a comment inside a Tcl proc
body is still inside that body's braces.** Writing this defect up with a literal
unbalanced brace in a comment aborted the source of all of `xschem.tcl`. Both the
comment and the check build the value from `\175`.

### B. The normalizer skipped exactly the row an ordinary `-n` user gets

`sim_profile_normalize` decided "this row is already shaped" from **one** field —
`nospiceinit`, the last — reasoning that the six are "only ever set as a group".
The persister writes only what **differs from the default**, so **measured**:

```
sim_profile_set spice 2 nospiceinit 1 ; save_sim_defaults ; reload
emitted   : set sim(spice,2,nospiceinit) {1}     (the only profile line on that row)
after load: missing on that row = exe args casemode detected probed
```

A user who ticked A2's `-n` box and changed nothing else. Not an edge case.
`CS151g` drives it end to end through a real save + reload, with the one-field
shape asserted in the same expectation so it cannot go vacuous.

The walk is now **unconditional**, and the cost the short circuit was buying is
bought at the caller instead. This matters because `sim_is_xyce` →
`set_sim_defaults` is reachable from a graph **redraw** via `token.c`'s
`get_fqdevice`, which is item 3's "never poll a walk from a redraw".

**SUPERSEDED by the second pass (§0b finding 3): the caller-side guard was wrong.**
"Normalize only on the routes that (re)built the array" misses the rc route that
APPENDS a row to an array that already exists — B1's own second population route —
and left that row unshaped for the whole session; the check that covered it only
passed because it called the normalizer by hand. The guard is now a **row-count
memo** (`sim_profile_normalize_if_changed`, memo kept inside the `sim` array so an
`unset sim` invalidates it). **Measured, 500 iterations with the array already
built and unchanged: 8.36 µs unconditional, 1.0 µs for the old rebuild flag,
1.6 µs for the memo** (the full walk is 19.6 µs, once per build and once per
row-count change). `CS151f` now drives the real rc route; `CS151i` drives both of
the memo's answers.

### C. `ase::sim_profile_resolve` read an array nothing had built

`sim()` is lazy — its five xschem readers each open with `set_sim_defaults`.
`resolve` did not, so **measured**, in a session that had not touched the
Simulation menu:

```
sim exists = 0
resolve virgin state -> tool spice index -1 status default
```

`index -1` is "the tool's default row" naming no row at all, out of a tool with
three, and item 8 would have had to read it as "no profile". Now it calls
`::set_sim_defaults` first (1.0 µs when the array is there). The `xschem.tcl`
accessors deliberately do **not**: they are reached *from* `set_sim_defaults` via
`save_sim_defaults` → `sim_profile_get`, and a lazy init there would recurse.

**That fix also exposed a missing abort-proof.** With the lazy init reverted, the
array stayed unset and the next checks' bare `$::sim(spice,2,name)` raised — the
file ended with **no `RESULT` line**, under which a sabotage reads as "nothing
went red" (the trap the ledger carries from items 1, 2 and 5b). Confirmed live:
mutation M05 printed `NO RESULT LINE` before the restore was added, and exactly
one red (`CS163k`) after. The suite now restores the array immediately after
`CS163k`.

## 3. Decisions and rulings (spec is authoritative; evidence here)

Inherited and re-verified against the code on disk:

- **Row shape**: `exe args casemode detected probed nospiceinit`, from one
  canonical `sim_profile_field_defaults` that the normalizer, reader, writer,
  persister and tests all walk.
- **`casemode` and `detected` stay SEPARATE** (A1). `CS156` asserts one
  disagreement in one assertion — requested `preserve`, `supports preserve` = 0.
- **`selectable` is `fold` alone until probed** (spec §4). `supports` still
  answers **0 for every mode, `fold` included**, while `detected` is empty (B2b):
  an affordance and an assertion are not the same function. **AMENDED in the
  second pass:** "until probed" now means what it says — the fallback keys off
  `probed`, and a row that WAS probed and measured to deliver nothing offers
  **nothing** rather than `fold` (§0b finding 5, spec §4's third table row).
- **`sim_is_xyce` does NOT consult `exe`** (spec §6, `CS160`/`CS160b`), pinned
  with the exe deliberately pointing the other way. Item 4 built `hilight.c`'s
  Xyce fallback on its answer. M37 (the rejected design, wired) reddens `CS160`.
- **No built-in row gets an `exe`** (`CS151d`); a populated default would also
  break the byte-identity. M31 reddens `CS151d` **and** `CS150`.
- **`exe` is expanded, VARIABLES ONLY** — and **no longer with `subst` at all**.
  The first round used `subst -nocommands -nobackslashes` and said so here; the
  second pass measured that this still runs a `[…]` inside an **array index**, and
  drove `exec touch` from a staleness query (§0b finding 2). It is now
  `sim_profile_expand_vars`, which expands `$name`/`${name}`/`$name(index)` through
  `set` and refuses an index carrying `[`, `]`, `$` or a backslash. `CS157k` keeps
  the top-level case (proved **by side effect** — the return value is `{}` either
  way), `CS157l` adds the array-index case.
- **`sim_profile` state key** in `schema_keys` right after `simulator`, in
  `omit_if_empty`, `version` stays **1**. `resolve` reports
  `default | ok | stale | invalid`.
- **The index integer test is load-bearing, not belt** (`CS163j`): Tcl's `<`/`>=`
  fall back to STRING comparison and `2x` compares below `5`, so a bounds test
  alone reports a non-existent row as `ok`. M47 reddens it. **And it was not
  enough** — `string is integer -strict` accepts `02`, `-0` and whitespace, which
  passed the bounds test and then indexed a row that does not exist while
  reporting `ok`; the index is **canonicalized** now (§0b finding 4, `CS163l`,
  spec §8).
- **`ase::sim_profile_casemode` calls `::sim_profile_casemode` ABSOLUTELY
  qualified** — the two differ only in namespace and the relative name would
  recurse forever.

New this round:

- **RULING — `netlist_case_mode()` stays unwired** (spec §10). `save.c`'s own
  comment says item 6 is where the profile gets layered onto it. It does not, for
  two reasons stated there: with no shipped row carrying a `casemode`, the wired
  and unwired answers are **identical for every configuration that can exist
  before item 13**; and re-pointing a committed, green item-14 authority for zero
  observable difference has exactly one possible effect — an audit row moving,
  against this batch's empty-diff contract. The spec records the one-line
  expression that goes in when a consumer needs it, and the two things its author
  owes (`-1`, and `netlist_type` not always being a `sim()` tool).
- **Two declared limits of `resolve`** written into the spec rather than fixed: a
  state may name a row of another **tool** and resolve `ok` (item 8's business to
  judge), and `stamp` on a **nameless** row can never report `stale`.
- **`CS156e` RESTATED** (this item's own new check, not a committed one). As
  written it was a tautology — `detected` is filtered through the canonical three,
  so `supports … unknown` can only answer 0, and I could not redden it: dropping
  the mode guard and dropping the filter both leave it 0. It now pairs the refusal
  with a mode that WAS measured, and M29 reddens it. **The verifier then showed the
  restatement did not fix the underlying point**: the guard line itself still moves
  nothing (drive `N29`). It is **declared unreachable by construction** in spec §4
  with the proof, and kept as defence in depth — the honest disposition, since a
  check that cannot move is worse than a documented redundancy.

Rulings added by the second pass (each with its evidence in §0b and its rationale
in the spec):

- **RULING — the persistence guard must model the SCRIPT parser**, not the list
  parser: backslash-newline and a bare CR are refused because they are the only
  sequences on which the two disagree inside braces, measured both ways
  (spec §5).
- **RULING — the caller's normalize guard is a ROW-COUNT MEMO**, kept inside the
  `sim` array so an `unset sim` invalidates it (spec §5).
- **RULING — `subst -nocommands` is not a sandbox**; profile-path expansion is
  variables-only through its own expander, and the same pre-existing hole in
  `ase::expand_path` is documented rather than silently inherited (spec §5).
- **RULING — an invalid hand-edited value is DROPPED at the next save**, because
  writing the raw value back can make the whole `simrc` unsourceable; item 13's
  dialog is where a typo gets reported (spec §5, `CS158g`).
- **RULING — a state's profile index is CANONICALIZED once it validates**, not
  refused, for the same reason `invalid` falls back rather than erroring
  (spec §8, `CS163l`).
- **RULING — `selectable` keys off `probed`**, so "measured, delivers nothing"
  offers nothing (spec §4, `CS156g`).

## 4. Checks and RESULT

`tests/headless/test_sim_profiles.tcl` — **97 checks** after the second pass (82 +
15 new), verbatim: **`RESULT: ALL PASS (97 checks)`**. **True headless**
(`--nogui`); added to `nogui_tests` because Tk-freedom is what it asserts.

**MASTER red-before-green.** `src/xschem.tcl` + `src/ase.tcl` replaced by
`git show HEAD:` copies → **`RESULT: 95 FAILED (2 passed)`**. The only two
survivors are exactly the two declared fixture-**premise** checks, `CS150b` and
`CS165b`, which have no item-6 code beneath them by construction. Restored from
byte-exact backups (`md5sum` compared) → `ALL PASS (97 checks)`. (The first attempt
at this master red **aborted with no `RESULT` line** — two of the second pass's own
new checks read array elements directly; that is fixed and is why the run is
quotable at all. See §0b.)

**Suites**, `GUI_GATE=1 tests/headless/run_suites.sh` on `:99`:
`test_sim_profiles` 97, `test_ase_persist` 109, `test_ase_cosim` 342,
`test_raw_case_mode` 277, `test_hilight_case_senders` 30 — all PASS.
`--nogui`: `test_ase_core` 75, `test_ase_final` 28, `test_ase_final_gf180` 33 —
all PASS.

**The three display-arm failures are NOT mine, and I A/B'd each one myself**
rather than citing the dispatch:

| suite | fully pristine (HEAD src + HEAD test) on `:99` | mine on `:99` | mine `--nogui` |
|---|---|---|---|
| `test_ase_core` | **1 FAILED (57 passed)** | 1 FAILED (**58** passed) | ALL PASS (75) |
| `test_ase_final` | **1 FAILED (9 passed)** | 1 FAILED (9 passed) | ALL PASS (28) |
| `test_ase_final_gf180` | **1 FAILED (10 passed)** | 1 FAILED (10 passed) | ALL PASS (33) |

Same single failure on both sides (`ase: design aselib/nfet_clean is not the
current schematic`); the one extra `ase_core` pass is this item's added check.
**All three are `nogui_tests` in `full_audit.sh`, where they pass** — which is why
the baseline records `test_ase_core` as PASS and why that must stay true. Note the
`test_ase_core` A/B needs HEAD's **test file** too: with my 17-key test against
HEAD sources it is `2 FAILED (0 passed)`, which is not an A/B of anything.

## 5. Sabotage — two tables, counted from the scripts' own output

**COUNTS CORRECTED.** The first recovery round's heading claimed "66 mutations";
the scripts it shipped drive **61 + 3 = 64**, plus the master red = **65**, and the
per-row table itself was accurate about *what* went red. Every number in this
section is now the number the script prints.

**Round-1 table (inherited, re-runnable, still valid for the checks it names):**
64 drives —
`…/scratchpad/item06/mutate.py` (61) + `mut2.py` (3, including the two fixture
DATA drives) — plus the master red.

**Round-2 table (this pass): 36 drives** (33 + 3) —
`/tmp/claude-1000/-home-qflow-dev-xschem-claude-1-xschem/8a4b05e0-6037-4454-8649-d096a82b4178/scratchpad/fix06/mutate.py`
(33 code/test mutations, ids `N01`–`N36` with three merged away and not renumbered) + `mut2.py` (the two fixture data drives `D1`/`D2` re-driven and the
`state_default` drive `N34` for the two committed test files), plus the master red.
**Every new and every restated check of this pass is red under at least one row**
(§0b's table names which), and the one drive that stays green — `N29` — is the
guard declared unreachable by construction in spec §4.

Each mutation is an exact literal replacement **asserted to hit exactly once** — a
silently-missed patch would otherwise read as "nothing went red" — applied over a
byte-exact backup, run, restored, and the restore verified by `md5`. Baseline green
before each sweep, green after. Both fixtures and `src/ase.tcl` come back with
`md5` equality asserted in the script, and `git status` on the tracked fixture is
clean afterwards. Six rows are the **reverts of the fixes** (§2's three, §0b's
first five) and are their red-before-green.

| mutation | went red |
|---|---|
| M01 persister writes every field | CS150 CS151g CS158 |
| M02 set_sim_defaults never normalizes · M02b normalize is a no-op | CS150 CS151c CS151g · CS150 CS151c CS151f CS151g |
| **M03 FIX-B REVERT: the per-row short circuit is back** | **CS151g** |
| **M04 FIX-A REVERT: guard is `info complete` again** · M04b guard removed | **CS153e** · CS153d CS153e |
| **M05 FIX-C REVERT: resolve stops building `sim()`** | **CS163k** |
| M06 read-side validation off | CS154b CS156f |
| M07 casemode validation accepts anything · M08 detected · M09 probed · M10 nospiceinit | CS154 CS154c CS154b · CS154b CS156f · CS154d · CS154e |
| M11 row's mode ignored (floor always) · M12 floor never consulted · M13 floor unvalidated · M14 floor+fold fallback deleted | CS155c CS156 CS158c CS164 · CS155b CS164c · CS155d · CS155 CS155b CS155d CS159 CS164b CS164c |
| M15 supports=1 unprobed · M16 selectable offers all three · M17 detected unfiltered | CS156b · CS156c CS159 · CS156d CS156f |
| M18 probe_stale ignores mtime · M19 no mtime recorded · M20 probe_record unfiltered · M57 never-probed reported fresh · M67 unfindable exe reported fresh | CS157e CS157i · CS157c CS157d · CS157b CS157c CS157d · CS157 · CS157f |
| M21 exe_path trusts an unchecked absolute · M22 no expansion · M23 `-nocommands` dropped · M24 expansion `catch` removed · M64 always empty | CS157g · CS157i · CS157k · CS157j · CS157c CS157d CS157h CS157i |
| M25 unknown-field refusal removed · M26 `get`'s `info exists` removed · M27 unknown field returns its name · M28 row-range check removed | CS152c · CS152 CS152b · CS152b · CS152d |
| M29 the setter writes the wrong element | **23 checks** incl. CS153 CS153b CS153c CS156e |
| M30 nospiceinit dropped from the field list | CS151 CS151b CS151f CS151g CS154e CS154f CS158 CS158c CS158d |
| M31 a built-in row given an exe · M32 `simconf_add` shape dropped · M33 row drops `requested` · M34 default clamp removed · M35 no-such-tool guard removed · M36 `default_index` constant | CS151d CS158 · CS151e · CS159 · CS159c · CS159d · CS159b |
| M37 `sim_is_xyce` consults `exe` (**the rejected design**) · M38 its regexp deleted · M39 a `winfo` in a profile proc | CS160 · CS160b · CS166 |
| M40 `schema_keys` loses the key · M41 `omit_if_empty` loses it · M42 `state_default` loses it · M43 the key moved to the END | CS161 CS161b CS161e CS161f CS165 · CS161c CS161e CS165 · CS161d CS165 · CS161b CS161f |
| M44 `backend_tool` returns the backend name · M62 no fallback · M45 stored tool ignored · M46 missing index defaults 0 · M47 integer test dropped · M48 stale-name test removed · M49 `stamp` records no name · M50 `clear` a no-op · M51 stored index never read · M65 "names no profile" reported `ok` · M66 upper bound removed | CS162 CS162b CS163 CS163k CS163e CS163f CS163g CS163i CS163j CS163h · CS162b · CS163f · CS163g CS163i · CS163j · CS163d · CS163c CS163d · CS163h · CS163b CS164 CS165c · CS163 CS163k CS163h · CS163e CS163f |
| M55 persister writes the value unbraced · M59 the guard becomes too STRICT (any brace refused) | CS153f CS158b CS158c CS158d · CS153f |
| **D1** DATA: the pre-item6 `simrc` fixture given a new-field line · **D2** DATA: the pre-item6 ASE state fixture given a `sim_profile` line | **CS150b CS150** · **CS165b CS165** |

### Round-2 rows, verbatim from the scripts' output

| id | what was broken (file:site) | RESULT | went red |
|---|---|---|---|
| N01 | `xschem.tcl` `sim_profile_valid` — the backslash-newline refusal disabled (**the confirmed defect**) | 1 FAILED (96 passed) | `CS153g` |
| N02 | same proc — the bare-CR refusal disabled | 1 FAILED (96 passed) | `CS153g` |
| N03 | same proc — over-refuse: ANY backslash rejected (acceptance half) | 1 FAILED (96 passed) | `CS153g` |
| N33 | same proc — over-refuse: any brace rejected | 1 FAILED (96 passed) | `CS153f` |
| N04 | `sim_profile_exe_path` — back to `subst -nocommands` (**the confirmed defect**) | 1 FAILED (96 passed) | `CS157l` |
| N05 | `sim_profile_expand_vars` — the array-index refusal deleted | 1 FAILED (96 passed) | `CS157l` |
| N31 | `sim_profile_exe_path` — no variable expansion at all | 2 FAILED (95 passed) | `CS157i` · `CS157n` |
| N32 | `sim_profile_exe_path` — an unresolvable variable becomes an ERROR | 2 FAILED (95 passed) | `CS157j` · `CS157l` |
| N35 | `sim_profile_expand_vars` — `^` anchor back on the **braced**-name pattern (my own first-draft defect) | 1 FAILED (96 passed) | `CS157n` |
| N36 | `sim_profile_expand_vars` — `^` anchor back on the **plain**-name pattern (same defect, other arm) | 1 FAILED (96 passed) | `CS157n` |
| N06 | the normalize memo never notices a changed row count (**the confirmed defect**) | 2 FAILED (95 passed) | `CS151f` · `CS151i` |
| N07 | the memo never hits, so the walk runs on every redraw re-entry | 1 FAILED (96 passed) | `CS151i` |
| N08 | `sim_profile_normalize` plants `{}` instead of the field default | 1 FAILED (96 passed) | `CS151h` |
| N09 | `simconf_add` plants `{}` instead of the field default | 1 FAILED (96 passed) | `CS151h` |
| N10 | `sim_profile_normalize` — no-configuration guard deleted | 1 FAILED (96 passed) | `CS151j` |
| N11 | `sim_profile_selectable` — fallback back on `detected` (**the confirmed defect**) | 1 FAILED (96 passed) | `CS156g` |
| N12 | `sim_profile_selectable` — offers nothing even when never probed | 2 FAILED (95 passed) | `CS156c` · `CS159` |
| N13 | `sim_profile_probe_record` — records `fold` it was never given (A1) | 2 FAILED (95 passed) | `CS157m` · `CS156g` |
| N14 | `sim_profile_probe_record` — provenance stamp hard-coded to `time 1` | 1 FAILED (96 passed) | `CS157c` |
| N15 | `save_sim_defaults` — never writes `probed` | 1 FAILED (96 passed) | `CS158e` |
| N16 | `save_sim_defaults` — profile fields for `spice` only | 1 FAILED (96 passed) | `CS158f` |
| N17 | `save_sim_defaults` — writes the RAW element, so an invalid value survives | 1 FAILED (96 passed) | `CS158g` |
| N18 | `sim_profile_row` — drops `fg` and `st` | 1 FAILED (96 passed) | `CS159` |
| N19 | `sim_profile_row` — `cmd`/`name`/`fg`/`st` all come back empty | 1 FAILED (96 passed) | `CS159` |
| N20 | `ase.tcl` `backend_tools` — the whole map deleted | 1 FAILED (96 passed) | `CS162c` |
| N21 | `ase::sim_profile_resolve` — index no longer canonicalized (**the confirmed defect**) | 1 FAILED (96 passed) | `CS163l` |
| N23 | `ase::sim_profile_stamp` — tool argument ignored | 1 FAILED (96 passed) | `CS163m` |
| N24 | `ase::sim_profile_resolve` — returned tool hard-coded | 1 FAILED (96 passed) | `CS163m` |
| N25 | a `canvas` call inserted into `sim_profile_selectable` | 1 FAILED (96 passed) | `CS166` |
| N26 | **TEST** — the Tk detector made blind to `canvas` (the sentinel half) | 1 FAILED (96 passed) | `CS166` |
| N27 | `sim_profile_valid` — the `args` list arm always says yes (verifier V2) | 1 FAILED (96 passed) | `CS154g` |
| N28 | `sim_profile_valid` — the `detected` arm's `llength` guard removed (V3) | 1 FAILED (96 passed) | `CS154g` |
| N29 | `sim_profile_supports` — the mode guard deleted (verifier V1) | **ALL PASS (97)** | **NONE — declared unreachable, spec §4** |
| D1 | **fixture** `simrc_pre_casemode` gains an `exe` line | 2 FAILED (95 passed) | `CS150b` · `CS150` |
| D2 | **fixture** `ase_state_v1_pre_cosim.state` gains a `sim_profile` line | 1 FAILED (96 passed) | `CS165b` |
| N34 | `ase::state_default` loses `sim_profile {}` | `test_ase_core` **2 FAILED (0 passed)** · `test_ase_persist` **1 FAILED (16 passed)** · `test_sim_profiles` 2 FAILED (95 passed) | the two committed **17-key** checks · `CS161d` · `CS165` |

`AFTER RESTORE` printed by both scripts: `test_sim_profiles ALL PASS (97 checks)`,
`test_ase_core ALL PASS (75)`, `test_ase_persist ALL PASS (17)`. Every restore is
`md5`-asserted inside the script, and `git status` on the tracked fixture
(`ase_state_v1_pre_cosim.state`) is clean afterwards.

**No check is left unsabotaged.** The two the master red could not move —
`CS150b`, `CS165b` — are fixture *premise* checks, so they are driven by mutating
the **fixture** (D1/D2), which reddens the premise *and* its dependent check. Both
fixtures were restored byte-exactly (`md5`); `ase_state_v1_pre_cosim.state` is
committed and is unchanged in `git status`.

**Three mutations I expected to bite and which did not, each recorded because it
changed something:**

- `supports` with the mode-validity guard deleted **and** unprobed made capable
  (M54) still leaves `CS156e` green — because `detected` is filtered through the
  canonical three and `unknown` can never be in it. That is what made `CS156e` a
  tautology, and why it was restated (§3).
- The inherited receipt's M31 ("malformed-dict guard is unreachable") is
  **confirmed** by construction here: `dict exists` on `{a b c}` answers 0 rather
  than raising, so `CS163g` reaches the range check. I left the guard deleted.
- The inherited receipt's M14 (`[list $v]` vs `{$v}` in the persister) is
  **untestable as stated** — Tcl braces a `$`-carrying element identically, so the
  two forms are byte-equal. My M55 (unbraced) is the mutation that has content.

## 6. What was NOT verified

- **No probe ran and no simulator was launched by anything here**, by design.
  `detected`/`probed` were written by hand or by `sim_profile_probe_record`, whose
  `mtime` half was driven against a **fake** executable, never `build-ver_50`.
  "Released ngspice accepts and ignores `-D casemode=`" is **inherited** from
  `DECISIONS.md` A1, not re-measured.
- **No old xschem binary read a new `simrc`.** Compat half 2 rests on the grep
  argument plus "write only what differs". I re-ran the grep: nothing in
  `src/*.tcl` or `src/*.c` does `array names sim` / `array get sim`
  (`xschem.tcl:14518` is an `array unset ::sim`, which enumerates nothing), and
  the three C readers cited in the spec are at `hilight.c:941`,
  `scheduler.c:11948`, `callback.c:5598` — all `sim(spicewave,%d,name)`, suffix
  named explicitly. `simulate`'s `subst -nobackslashes $sim($tool,$def,cmd)` is at
  `xschem.tcl:4444` and `:4703`.
- **The rc route works but ships empty.** B1 lists `cadence_style_rc` / any
  `--script` rc as a route that "sets the same globals", and it does — the fields
  are plain globals, so an rc setting `sim(spice,5,exe)` is exactly the
  partly-shaped row `CS151f` drives. But `src/cadence_style_rc` mentions `sim(`
  **nowhere** (grepped) and nothing was added to it: a shipped rc that populated
  an `exe` would break §2's "no built-in row gets an `exe`" ruling and §5's
  byte-identity with it. So the route is exercised **only** in the CS151f /
  CS151g shape, by a test that writes the same globals an rc would.
  **Corrected in the second pass:** the first round's version of this bullet
  claimed `CS151f` covered that route, and it did not — the check called the
  normalizer by hand, which no rc does. `CS151f` now drives `set_sim_defaults`,
  the way an rc reaches it, and `CS151i` adds the later-reader leg
  (`sim_is_xyce`). Still no *shipped* rc exercises it.
- **`ase::expand_path` is left unsafe on purpose.** It expands model paths out of
  a state file with `subst -nocommands -nobackslashes`, which the second pass
  measured to still run a `[…]` inside an array index. Item 6's own expansion no
  longer uses `subst` at all; the model-path one is other items' surface, is
  flagged in a comment at its definition and ruled in spec §5, and wants its own
  issue.
- **`args` is stored and validated, never composed into an argv** (item 8), and
  **nothing reads `nospiceinit`, `probed` or `sim_profile`** outside this item's
  own procs and tests. Items 7/8/13 are the consumers, so these fields are storage
  whose *use* is unproven by construction. `simconf_add` is reachable only from
  commented-out dialog code, so `CS151e` drives a proc no user can reach yet.
- **`netlist_case_mode()` is unwired on purpose** (§3) — so the profile's
  requested mode reaches **no** consumer at all yet. That is the item's honest
  shape, not an oversight.
- **The `-1` index is unhandled downstream.** `sim_profile_default_index` answers
  `-1` for a tool with no configured row and `resolve` propagates it; nothing in
  this item consumes an index, so nothing had to decide what `-1` means.
- **`CS166` is a static blocklist and still has two declared blind spots**, now
  that it has sentinels and strips comments: a Tk command reached by **dynamic
  dispatch** (`[$cmd .w]`) is invisible, because the leading character class
  excludes `$` deliberately — a `$word` in a body is a variable read, not a command
  word, and including `$` would make prose-free code like `$text` a false hit; and
  a Tk command **inside a trailing `;#` comment** is not stripped (only whole-line
  comments are). The primary evidence for no-Tk is unchanged and stronger: the
  whole file, and `test_ase_core`, run under `--nogui` where a Tk command does not
  exist.
- **No valgrind, no C, nothing built. No eyeball owed** — the payload is data plus
  persistence, asserted byte for byte; `owed.sh` untouched, item 13 owns pixels.

## 7. Closer audit

**ONE audit file, one name:
`doc/claude/casemode_batch/audit_item06_closer_2026-08-17.txt` is the authoritative
audit of item 6.** The recovery round's `audit_item06_impl_2026-08-17.txt` has been
**deleted**: it was shot before five code fixes and fifteen checks existed, so
citing it would be citing a tree that no longer exists — and this item has already
had one round of confusion from three audit files with overlapping names (§0). An
earlier attempt at this run was also **discarded**, deliberately: I edited
`src/xschem.tcl` (the expander anchor fix) while it was halfway through, so it
spanned two byte states and could not honestly be quoted. The run below started
after the last edit, and the `md5` of `src/xschem.tcl`, `src/ase.tcl` and
`tests/headless/test_sim_profiles.tcl` was re-verified **after** it finished:

```
c32571b8bb468f3b9ad61ce4dd5300cb  src/xschem.tcl
4e54a3b3b26f25caf36a06118104302f  src/ase.tcl
f2bbce3cc0777fc5622ac97ae90ec752  tests/headless/test_sim_profiles.tcl
```

`GUI_GATE=1 tests/headless/full_audit.sh`, dev display `:99`, self-armed (never
`env -u DISPLAY`). Verbatim:

```
SUMMARY: 323 pass  15 fail  0 crash/timeout  0 skip  (total 338)
WIREEDIT: PASS
SCRATCH:  0 leaked dir(s)
TREE:     0 appeared  0 vanished
```

**DIFF against the baseline `audit_item14_closer_2026-08-17.txt`
(322 / 15 / 0 / 0 of 337, at `a7f56fa6`), by NAME and STATUS:**

| | |
|---|---|
| rows only in the baseline | **none** |
| rows only in mine | **`test_sim_profiles` (PASS)** — this item's new suite |
| **status changes, either direction** | **NONE. Zero rows moved.** |

322 → 323 pass is exactly that one new suite. The 15 reds are the **same 15
names**, compared as sorted lists: `test_ase_window test_cadence_drag test_ciw
test_gf180mcud_libmgr test_ihp_sg13g2_libmgr test_lib_manager_gui
test_lib_manager_locate test_lib_sweep test_reopen_readonly
test_rotate_stretch_short_0104 test_selflog_output test_sky130a_libmgr
test_wave_markers test_wave_sigbrowser_0312 test_wave_sigbrowser_keys`.
**`test_ase_core` is PASS**, as the contract requires (it is a `nogui_test`; its
display-arm failure is pre-existing and A/B'd in §4). The empty-diff contract for
items 1-9 holds.

Counted with a differ that extracts `NAME<tab>STATUS` from the row lines only
(`^(PASS|FAIL|CRASH|TIMEOUT|SKIP) +\| +test_[A-Za-z0-9_]+$`) — so the six
within-file `FAIL     | key …` detail lines cannot be miscounted as test rows.
Self-checked by diffing the baseline against itself first: 337 rows, 322/15, zero
changes.

## 8. Two inherited claims I re-established rather than repeated

- **`fixtures/simrc_pre_casemode` really is pre-change output.** Not taken on
  trust: I checked out `HEAD:src/xschem.tcl`, generated a `simrc` from the
  built-in defaults with that **pre-item-6** `save_sim_defaults`, and compared —
  **byte-identical to the committed fixture** (`cmp`). Source restored and
  `md5`-verified; suite green after. **This manual `cmp`, not `CS150`, is the
  before/after evidence** — the post-change persister emits the same bytes (that
  is the property under test), so the check itself asserts determinism and
  additivity. §0b finding 15; restated in the check's own comment and in spec §5,
  because the first draft of this bullet drew a conclusion its own `cmp` does not
  support.
- **Half 2's grep argument** re-run in full, with the three C sites and the two
  `subst` sites confirmed at their current line numbers (§6).

## 9. State of the tree, and the verdict

**Uncommitted, nothing staged, nothing pushed.** Tracked files modified:
`src/xschem.tcl`, `src/ase.tcl`, `tests/headless/full_audit.sh`,
`tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_persist.tcl`
(+688 −9 in total). New untracked files:
`tests/headless/test_sim_profiles.tcl`,
`tests/headless/fixtures/simrc_pre_casemode`,
`doc/claude/specs/simulator_profiles.md`, this receipt, and
`doc/claude/casemode_batch/audit_item06_closer_2026-08-17.txt`. No file that was
dirty before this item started was touched; the two pre-existing repo droppings
(`relaycheck.tcl`, `tr_MODE.raw`) are left exactly where they were.

**New checks this pass (15):** `CS151h` `CS151i` `CS151j` `CS153g` `CS154g`
`CS156g` `CS157l` `CS157m` `CS157n` `CS158e` `CS158f` `CS158g` `CS162c` `CS163l`
`CS163m`. **Restated (behaviour changed, not renumbered):** `CS151f` `CS157c`
`CS159` `CS166`. **Restated (comment only, because what they prove was
overstated):** `CS150` `CS153f` `CS157k`. Band still `CS150`–`CS166`, contiguous;
nothing renumbered, nothing deleted.

**Verdict `[x]`, not `[E]`.** The payload is data + persistence + one state key,
asserted byte for byte, with no pixel anywhere: item 13 owns the dialog and the
dropdown, and `owed.sh` is untouched by this item. The one thing a reader should
carry forward is not a defect but the item's shape, unchanged since §6 said it:
**the profile's requested case mode still reaches no consumer** — `netlist_case_mode()`
is deliberately unwired, and items 7, 8 and 13 are the consumers.
