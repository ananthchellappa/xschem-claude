# Casemode batch ledger — branch `fluid-editing`, base HEAD `577ef5bc`

Driver-mode unattended batch. **Item 0 CLOSED. Items 0a–15 not started.**
Nothing is pushed.

State lives HERE, not in the driver's context. After a compaction, re-read this
file and continue from the first row that is not `[x]`/`[E]`/`[D]`/`[F]`.

## Read before touching anything

1. **`DECISIONS.md`** — the 13 decisions, settled with the user 2026-08-16.
   Authoritative. Four of them overturned the plan's recommendation.
2. **`DESIGN_REVISION.md`** — the read path is redesigned: the fold at
   `save.c:1008` is **deleted**, not gated, and the lookup becomes
   case-insensitive.
3. **`PLAN.md` §3b** — the authoritative item list. §3 and §4 are superseded and
   marked as such; §0b item 1 is marked WRONG in place.
4. `OPEN_QUESTIONS.md` — how each decision was posed, and the one option that
   was written backwards.

Receipts: `receipts/NN-<slug>.md` (120 lines max).

Verdicts: `[x]` done+verified · `[E]` done, eyeball pending (pixels) ·
`[D]` deferred (needs a filed issue) · `[F]` failed (needs a filed issue).

## Baseline — the audit debt is PAID

**`doc/claude/merge5_loose_ends/audit_item02_fixround_2026-08-16.txt`**
— **316 pass / 15 fail / 0 crash-timeout / 0 skip of 331**, taken at `577ef5bc`
on the dev display `:99`, committed.

The plan's "~80 min stash-diff pair still owed" is **discharged** — the merge-5
loose-ends batch shot this at current HEAD. Every later audit is judged by
DIFFING that file by test **NAME and STATUS**, never by the red count.

`doc/claude/batch_F/baseline_status.txt` (285/19/1) was shot with the pre-rework
scorer and is **VOID**. `batch_F/baseline_status_2026-08-15_postmerge5.txt`
(314/17) predates two harness fixes and is superseded by the file above.

## Items

| # | item | verdict | commit | checks | sabotages | files | eyeball | note |
|---|------|---------|--------|--------|-----------|-------|---------|------|
| 0 | setup: fixtures + docs + upstream exchange | `[x]` | `fc65f14a`, `2cbc999e` | – | – | 97 docs | no | fixtures + plan + rounds 1–3. Audit debt discharged above; base HEAD corrected from `7924d0db` |
| 0b | decisions + design revision + plan/ledger correction | `[x]` | `f7ab5f65` | – | – | 6 docs | no | docs-only, no build/suite owed. `DECISIONS.md`, `DESIGN_REVISION.md`, `OPEN_QUESTIONS.md`, PLAN §3b marked superseded in place |
| 0a | suite sweep for folded-name assertions | `[x]` | `f7ab5f65` | – | – | 1 doc | no | `receipts/00a-suite-sweep.md`: **zero rows expected to move**. Static sweep; 34 suites touch `raw read`/`raw list`, 2 tracked `.raw` fixtures, no test reads either. THIS IS ITEM 1's EXPECTED-DIFF CONTRACT |
| 1 | delete the fold + `Raw.case_sensitive` | `[x]` | `fbfc6395` | 81 | 33 | 7 code + spec | no | audit diff = **one added row** (`test_raw_case_mode PASS`), **zero movers** — 00a's contract met exactly. Review found 5 real bugs beyond scope, all fixed. Xyce **RULED: no fold**. Spec `specs/raw_case_mode.md` |
| 2 | one lookup ladder (+ absorbs the VCD sub-step) | `[x]` | `532b1768` | 105 new (186 in file) | 26 | 11 + 3 audits | no | audit diff vs item 1 **EMPTY**, verified independently. Ladder no longer mutates the query; alias index is a **separate lazy table**, overriding DESIGN_REVISION §4's *mechanism* (rule stands, correction written in place). Fixed a live **default-mode** viewer defect + a 32-byte leak |
| 3 | four-source mode resolution | `[x]` | `26cff1d3` | 91 new (277 in file) | 53 | 8 + 3 audits | no | audit diff **EMPTY**, verified independently. `xschem raw casemode` REPORTS, never acts. **Refuted two design premises by measurement** (see below). Spec §10 |
| 4 | the four `hilight.c` senders (Ctrl-K path) | `[x]` | `5c7ee761` | 30 | 30 | 5 + 2 audits | no | **11 folds gated, not the brief's 4** — 9 `strtolower` on 8 lines + 2 `strtoupper`, five senders + a receiver parse. Audit = one added row (its own suite), zero movers. **Refuted 2 reviewer-prescribed fixes and 1 driver hint by measurement.** Spec §11 |
| 5 | viewer Tcl + two-pane browser scan | `[E]` | `9b1394c9` | 134 | 66 | 5 + 3 audits | **YES ×2** | audit = one added row, zero movers. **B2a's control BUILT, not passed on** (`Options ▸ Case Mode`). Review caught the radios as a **dead control** — no-op left 113/113 green. Spec §12. **2 look debts recorded** |
| 5b | **one lookup authority + lazy `ngspice_data`** (D3) | `[x]` | `9f354aa0` | 160 new | 43 | 8 + 4 audits | no | **All three D3 properties landed; property 3 NOT deferred.** Audit = two added rows (its own suites), zero movers. Workflow died after Verify and was RESUMED. Verifier found a **real shipped leak**, fixed. Spec §13. Issue `0420` filed |
| 6 | extend `sim()` / `simconf` / `simrc` | | | | | | no | replaces the plan's new `ase_simulators` file |
| 7 | the capability probe (+ hard timeout) | | | | | | no | |
| 8 | profile-aware `run_cmd` + mismatch policy | | | | | | no | `distinguish` mismatch REFUSES |
| 9 | `sod_expr` stops folding + current arm | | | | | | no | flips ~20 assertions; that breakage is the evidence |
| 10 | three defences: pre-flight + `$sim_status` + content | | | | | | no | pre-flight also OFFERS legacy corrections (D1) |
| 11 | `result_probe` `-nocase` | | | | | | no | |
| 12 | post-load current repair | | | | | | no | |
| 13 | simulator dialog (extends `simconf`) | | | | | | **YES** | only item with pixels; `owed.sh add look`, never "done on a green suite" |
| 14 | netlister collision warning + `model_name()` key | | | | | | no | fires only under `fold`/`preserve`; silent under `distinguish` |
| 15 | docs | | | | | | no | must name `v(all)` **and** `i(all)`; must record Xyce as unverified |

## The baseline ROLLED FORWARD at item 1 — read this before diffing an audit

Item 1 added one row to the audit (its own new suite `test_raw_case_mode`), so
every later item would otherwise re-explain the same added row forever. The
pipeline's baseline is therefore now

**`doc/claude/casemode_batch/audit_item01_closer_2026-08-16.txt`**
— **317 pass / 15 fail / 0 crash-timeout / 0 skip of 332**, at `fbfc6395`, on `:99`.

The roll is safe because item 1's closer audit was itself diffed against the
merge-5 baseline and **moved zero statuses** — it is that file plus one `PASS`.
Verified independently by the driver, by name and status: the entire diff is
`> test_raw_case_mode PASS`. Diffing each item against the immediately preceding
state is strictly *more* sensitive than diffing them all against a fixed older
file, not less.

**Counting trap in these audit files:** six lines read `FAIL     | key ...` and
are *within-file detail*, not test rows. A naive `grep -c '^FAIL'` returns 21 and
is wrong; the real figure is 15.

## Carry-forwards item 1 handed to later items

Item 1's receipt §5 ("what was NOT verified") is the source. These are **not**
item 1 defects; they are scope that lands elsewhere:

- **Item 2** — `src/vcd_read.c:139-141` now asserts the **opposite** of what the
  code does (the apology survived the fold's deletion). Item 2 already owns
  retiring it. Also: `raw case` on a **`table_read`** database was never driven
  (VCD and spice were), and no sweep exists of Tcl consumers of `xschem raw list`
  doing an exact lowercase comparison that could now miss.
- **Item 5b** — **a THIRD `ngspice_data` publisher exists, and it is in Tcl**:
  `ngspice::read_raw_dataset` (`ngspice_backannotate.tcl:24`). It is harmless
  today only because of its own `string tolower` at `:38`. Any 5b work that
  counts the publishers as "the two C sites" is already wrong. This refutes the
  item-1 verifier's "only C writes it".
- **Anyone touching `read_dataset`** — issue **`0316`** is open and was
  re-measured during item 1: a malformed raw header makes `read_dataset()` call
  `extra_rawfile(3, NULL, …)`, clearing **every** loaded database. Item 1's new
  `fopen` probe cannot close it.
- **Xyce is now RULED, not open** (`specs/raw_case_mode.md` §5): **no
  Xyce-specific fold.** Grounded in what is measurable here — no measured way to
  *identify* a Xyce raw exists (`Command:` is never parsed; `sim_is_xyce` regexps
  the configured simulator command, never the file), so a fold would gate a
  destructive transform on a heuristic. The spec records what would reopen it.
  **Item 15 must still record Xyce's behaviour as unverified.**

## Carry-forwards item 2 handed on

Source: `receipts/02-one-lookup-ladder.md` §5. **The baseline did NOT roll at
item 2** — its closer audit is byte-identical by name and status to item 1's, so
`audit_item01_closer_2026-08-16.txt` remains the pipeline's baseline.

- **Item 4** — `hilight.c:329`'s `strstr(n, "i(v.")` carries **the same two bugs
  on the sender side** that item 2 just fixed on the reader side: it is
  case-sensitive, and it is the 4-character `"i(v."` against the reader's
  5-character `"i(v.x"`. Item 2 fixed its own rung by making it **anchored** as
  well as case-blind — the old unanchored `strstr` matched at any offset but
  rewrote `inode[2..3]` regardless, so a match anywhere else probed garbage. Item
  4 should expect the same shape and check the anchoring, not only the case.
- **Item 5 SHRANK, and what is left is precise.** Item 2 already did
  `wviewer::validate_rpn`, because at the **default `fold`** mode it was a live
  defect, not a `distinguish`-only one: on a `Count`/`count` raw,
  `xschem raw index COUNT` returned −1 while the gate called the token valid and
  `raw add` returned 1 — a **silent all-zero trace**. What remains for item 5 is
  `wviewer::resolve_signal_db` (`:2538`), **a second folding matcher that still
  ignores D2**. It is harmless today only because it never calls `raw add`. Item
  5 deletes both mirrors; one is already gone.
- **Issue `0418` filed** (driver, from item 2's "named, not fixed"):
  `raw_add_vector()` swallows `plot_raw_custom_data()`'s `−1`, so
  `xschem raw add x {BADTOK 2 *}` registers an **all-zero column and returns 1**.
  Same silent-wrong-data family as the gate defect above. Item 2 correctly did
  not fix it — two committed suites lean on that engine semantics, and changing
  it would have moved audit rows for a reason unrelated to the case ladder,
  breaking the empty-diff contract.
- **A weak check inherited from item 1**, named by item 2's reviewers: `CS23c`
  string-compares `ERR:No raw file loaded` against `>= 0` and therefore prints
  `ok:` under a reader sabotage. Not load-bearing, but do not cite it as
  evidence.
- **Two abort-proofing guards** went into `test_backannotate_digital.tcl` and
  item 1's `CS36f`: arithmetic on a value a broken reader empties raised a Tcl
  error that **aborted the file with no RESULT line**, under which a sabotage
  reads as "nothing went red". Worth knowing for any later sabotage round.
- **Honest gaps item 2 declared:** 31 of its sabotage rows were not
  independently re-driven, and of the two a reviewer did re-drive, one
  (`CS39f`) **failed** — which is why the `i(.x1.vp)` bait column now exists.
  No real mixed-case simulator run was involved; every fixture is committed or
  inline.

## Carry-forwards item 3 handed on

Source: `receipts/03-mode-resolution.md` §5 + `-annex.md`. Baseline still did not
roll — item 3's closer audit is again identical by name and status.

**Two design premises this item REFUTED by measurement. Both were in our docs.**

1. **`Casemode:` as a header key is REFUSED, and the reason is measured, not
   stylistic: ngspice's own reader ABORTS the load on it** (`FINDINGS.md` §1).
   The driver's dispatch hint treated `hdr_newkey.raw` as simply "the other
   position". It is not — it is a shape that breaks the file. Only `Option:` is
   accepted, in **both** header positions, first line wins. `Command: set
   casemode=` is refused too: `Command:` is free-text that nothing parses.
2. **"One raw, one mode" was FALSE.** The `Option:` branch was the only header
   branch with no `sim_type` guard, so a **two-plot raw reported the other
   plot's mode** (ngspice `rawfile.c:204` vs `222/262`). Found by review, fixed,
   and spec §10 corrected in place. Anything later that assumes a raw file has a
   single mode is wrong.

Other carry-forwards:

- **PERFORMANCE — items 5 and 13 must not poll source 3 from a redraw.** The
  schematic-name comparison has **no cache**, and `-schematic` and `-all` each
  recompute it. Measured at 2000 instances × 500 names: exact-hit 21 ms
  (unchanged), **folded-hit 147 ms** (was ~20), **all-miss 189 ms** (was ~135).
  That is a measured cost, not a defect — but it is per call.
- **B2a's user-facing control is items 5 and 13, not item 3.** Item 3 shipped the
  engine only. So item 5's scope shrank at item 2 (`validate_rpn` already done)
  and **grows here**: showing the detected mode and offering the override.
- **Untested reader kinds — item 2's carry-forward stays OPEN and is now
  compounded.** `raw casemode` on a VCD or `table_read` database has **no
  committed check**; both were hand-driven only. Whoever next touches the read
  path should close this rather than pass it on a fourth time.
- **Not driven, stated plainly:** no binary raw in the suite carries an `Option:`
  line, so parsing one is *reasoned, not driven*; and no check reads the `dbg(0)`
  emitted on a second, disagreeing `Option:` line.
- **The upstream `repro/hdr_*.raw` files are GITIGNORED.** The driver's item-3
  hint pointed at them as fixtures; they cannot be committed, so item 3 inlined
  the header lines into the suite and hand-drove the eleven real files. Point
  future items at the *lines*, not the paths.
- **Two audit reds that are NOT ours, named so a later closer does not read them
  as new:** `test_wave_markers` passes standalone but FAILs in both audits, and a
  `test_ase_core` failure reproduces on the **HEAD** binary too.
- **Checks item 3 declares as NOT evidence:** `CS60`, `CS61l`, `CS62c` have no
  item-3 code beneath them (fixture/premise checks, movable only by data
  drives), and `CS61d` is over-determined with no single-edit mutation.

## Carry-forwards item 4 handed on — AND THE BASELINE ROLLED AGAIN

Source: `receipts/04-hilight-senders.md` §2 and §5. **The pipeline baseline is now
`audit_item04_closer_2026-08-16.txt` — 318 pass / 15 fail / 0 / 0 of 333**, at
`5c7ee761`. Items 1–4 each moved zero statuses; the only growth is the two suites
they added. The two known reds inside it (`test_wave_markers`, `test_ase_core`)
are still not ours.

**Item 4 refuted three prescriptions by measurement — two from its own reviewers,
one from the driver's dispatch hint. Record them so they are not re-prescribed.**

1. **`Raw.case_sensitive` ranks SECOND, not first.** Three reviewers prescribed
   "fold only when the resolution says fold AND the lookup is not
   case-sensitive". Refuted with a committed fixture: `tr_fold.raw` read `-case
   distinguish` against a schematic drawn `In`/`MidNode` resolves to `fold`, and
   only the **folded** query hits (`raw index {v(midnode)}` = 2,
   `{v(MidNode)}` = −1). The rule is **bytes beat the flag; the flag beats the
   floor.**
2. **The hierarchical-current prefix follows the TOKEN**, not the mode. The
   prescription was "`v.` when folding, `V.` otherwise". Re-measured on `ver_50`
   with the device renamed: deck `Vs` gives `i(v.x1.vs)`/`i(V.X1.Vs)`, deck `vs`
   gives `i(v.x1.vs)`/`i(v.X1.vs)` — it is the device's own first character,
   folded with everything else. "`v.` stays lowercase in every mode" is **deleted
   from the spec.**
3. **The 4-vs-5-character difference is NOT a disagreement** — this corrects the
   driver's item-4 hint, which called it a bug. Both sides drop `v.`; the reader
   keeps the `x` because it **rewrites** where this arm **skips**. Requiring five
   would push `i(v.foo)` into the `i(` arm and split off a bogus component `v`.
   The receiver parse is now anchored and case-blind, and **keeps its 4**.

Other carry-forwards:

- **Xyce is resolved without being asserted.** `hilight.c`'s uppercase became a
  **fallback, not an assertion**: `sim_is_xyce` reports the *configured simulator
  command*, which is the right authority for a **sender**, where §5 refused a
  fold for a **reader** because no measured way to identify a Xyce *file* exists.
  Uppercase unless the resolution says `preserve`/`distinguish`; `fold`/`unknown`
  byte-for-byte unchanged. **Xyce remains UNVERIFIED** — item 15 still says so.
- **New field `Raw.sch_case_mode`.** Source 3 compares against whatever level
  `xctx` holds, so **descending silenced the verdict** — inert one level down,
  which is the case the gate exists for. The verdict is now stamped when computed
  for real and replayed in that hierarchy. Whether this belongs here or in item
  3's `schname` gate is **not settled**.
- **A latency risk with a diagnostic pointer:** the read-time prime costs **one
  schematic walk per `raw read`** (and per `table_read`), reasoned off item 3's
  147 ms worst case but **not measured**. If item 5 or 13 sees raw-read latency
  regress, look here first.
- **An open risk nobody has constructed:** `xctx->raw` may be **the wrong
  database when several are loaded** — a graph entry can plot from another via a
  `%rawfile` cross-DB entry (D1). Not built, not tested.
- **A pre-existing inconsistency left unfixed, deliberately:**
  `send_current_to_gaw`'s Xyce arm *lowercases* where `create_plot_cmd`'s
  *uppercases*, and `send_net_to_gaw`'s Xyce branch is identical to its ngspice
  branch. Recorded in spec §11, out of item 4's scope.
- **Never driven end to end:** no gaw and no Xyce were involved (the socket is
  faked); `RAW_CASE_UPPER` never came from a real uppercasing simulator; source 2
  (the `Option:` header) never drives a sender; `send_*_to_bespice()` is
  untouched and undriven.

## Carry-forwards item 5 handed on — baseline rolled to `audit_item05_commit`

**Baseline is now `audit_item05_commit_2026-08-16.txt` — 319/15/0/0 of 334** at
`9b1394c9`. ⚠ **Item 5 committed THREE audit files and `_closer` is MISNAMED** —
it is the implementer's first cut. Judge by **`_commit`**. (All three happen to
agree by name and status; the driver checked. Do not rely on that next time.)

**Item 5 is `[E]`. Two `look` debts are recorded and only the user clears them.**
A green suite never discharges an eyeball.

- **The review caught a DEAD CONTROL, which is the whole reason the fix round
  exists.** The four Case Mode radios' `-command` was never driven by any check —
  replacing it with a no-op left **113/113 green**. Textbook green-but-hollow,
  found by a reviewer, not by the suite. Checks went 113 → 134.
- **RULING that corrects spec §9's closing line: the Tcl matcher STAYS a mirror**
  and does **not** become `xschem raw index`. Two independently sufficient
  reasons: both callers judge a **foreign** name list (`raw index` answers only
  for the *current* database, so routing would need a `raw switch` per
  candidate), and `validate_rpn` must stay callable **with no engine at all**
  (`test_wave_viewer.tcl`). It is held down by an **agreement check** instead —
  a leg that reads `raw index` *and* the gate for one token and fails on any
  difference. This partly overrides the driver's dispatch hint, which said
  "route through the authority"; reproduce-plus-agreement is the ruling.
- **RULING — the fold key is ASCII-only.** The authority is `raw_fold_key()` →
  `strtolower()` (`util.c:1006`), a `tolower()` loop over **bytes**, and there is
  no `setlocale` anywhere in `src/`. Tcl's Unicode fold **invented a D2 collision
  the engine does not have** (`v(CÄ)` + `v(cä)`) and made `resolve_signal_db`
  skip a slot that resolves.
- **RULING — the override does NOT reach the Ctrl-K senders, and the claim that
  it did is deleted.** `hilight_sender_case_mode()` (`hilight.c:364`) reads the
  **schematic** window's `xctx->raw`; the viewer is a separate context with its
  own — measured by loading one file into both and watching them diverge. Not
  plumbed across: "which `Raw` is authoritative when a session has several" is
  not a question a menubar can answer, and **B1 already puts a session-wide mode
  on the simulator profile — item 13.**
- **The override writes the EXPLICIT SOURCE ONLY, never `Raw.case_sensitive`**,
  whose setter re-reads the file. Item 3 separated reporting from acting on
  purpose; a menubar pick must not silently rebuild a loaded database.
- **Issue `0419` filed** (driver): a **top-level** `@dev[param]` current has no
  dots, so the ≥3-segment guard never sees the tag and `sig_declass` classes it a
  `net` — `Show device internals` OFF hides `i(@r.x1.rq[i])` and **keeps**
  `i(@r1[i])`. A classification bug, not a case bug; all three `@` sites are
  already case-blind. It had no home, so it has one now.
- **`raw casemode` on a VCD or `table_read` database has now been passed on FIVE
  TIMES.** It is **mandatory scope for item 5b** — the last item that touches
  this code. If 5b declines it, 5b files the issue; it does not get passed a
  sixth time.
- **Item 4's latency pointer is still unmeasured.** Nineteen suite runs at
  unchanged counts is *an absence of a symptom, not a measurement*.
- **Measured, not filed:** the new per-slot index costs 1.4×–1.7× the old flat
  list (3.8 ms at 5000 names), on a path reached only after the current database
  has already refused. And a D2-poisoned *current* database now lets a
  *different* one satisfy the trace — better than the pre-item-5 answer (issue
  `0418`'s all-zero column), but disclosed nowhere else.
- **The override is deliberately NOT persisted** — item 13 owns durability.

## Carry-forwards item 5b handed on — baseline now `audit_item05b_closer_2026-08-17`

**Baseline is `audit_item05b_closer_2026-08-17.txt` — 321/15/0/0 of 336** at
`9f354aa0`. Items 1–5b moved **zero** statuses between them; all growth is the
five suites they added.

**This item's workflow DIED after the Verify stage and was resumed** with
`resumeFromRunId`. Before resuming, the driver confirmed the tree was the one the
verifier had measured (98/277/81 all pass) rather than sitting on a half-restored
sabotage — worth repeating, because the item-5b verifier recorded being fooled
once by `cp -p` restoring an older mtime so `make` skipped the rebuild and it was
still measuring sabotaged code.

**The verifier caught a real shipped defect, and it is fixed.**
`ngspice_data_trace()`'s read arm recorded a `my_strdup2`'d key on **every**
resolvable read, and a Tcl read trace fires for elements that already exist — so
every repeat read grew the list, on the path every redraw of an annotated
schematic walks. Now guarded by an existence probe before recording.

**A premise WE wrote was withdrawn, in five places.** "A materialised element is
a cache … a read trace does not fire for an element that already exists" went
into `save.c`, the spec, the receipt, the annex **and** the test. It is false on
Tcl 8.6.14 — the trace fires on every read and re-resolves. All five corrected;
`CS111c`/`CS111d` pin the truth. The `n\ vars` backslash claim was wrong too.

**The driver's own framing dissolved under measurement, which is the right
outcome.** The dispatch called the whole-array `upvar` "the hard one, worse than
enumeration". Measured first, before any code: **unsetting the array DESTROYS the
trace** (Tcl 8.6.14; the manual is not explicit). So an unset **is** the trace
reset — the five clear sites needed **no edit**, arming re-installs, and the
pure-Tcl third publisher's `unset -nocomplain` **disarms the view before it
writes**. They cannot interleave.

Rulings worth carrying (spec §13.5–§13.8):

- **Enumeration is REBUILT from `names[]`, never accumulated.**
- **The view is pinned to the PUBLISHING `Raw`, never `xctx->raw`** — hence
  `get_raw_index_in()`. A "current"-resolving view answers out of another
  database after a `raw switch`.
- **It answers only for a window that OWNS it** (`nd_view_owned()`); without
  that, window B read window A's numbers.
- **`free_rawfile()` disarms, and VALGRIND is the evidence a check could not
  be**: removed → `Invalid read of size 8 at ngspice_data_trace`; in place →
  clean, ×3.
- **The third publisher keeps its own fold and is NOT made an authority** —
  `ngspice::read_raw_dataset` never builds a `Raw`. Its fallback in
  `ngspice::lookup` is **gated** on `raw view_armed`; ungated it folds `En` and
  violates D2.

**Two latent defects were found inside the very lines D3 ordered deleted:**
`ngspice::get_diff_voltage` **never returned a difference** (`res` was assigned
only in its failure branch, so the success path hit `can't read "res"`), and
`my_snprintf` cannot see `%.*g` here (no `HAS_SNPRINTF`) so it needed a bare
`sprintf`. Both went with the deletion.

**Property 1 reached a FOURTH proc D3 does not name:** `get_node`, the one the
shipped `ngspice_get_value.sym` / `device_param_probe.sym` actually call. Folded
too, fixed too. **No mode branch exists anywhere in backannotation** — D3's whole
point, achieved.

- **MANDATORY SCOPE CLOSED, not passed a sixth time:** `raw casemode` on a VCD
  (`CS107`–`CS107m`) and on a `table_read` database (`CS108`–`CS108n`).
- **Five checks RESTATED, none renumbered or deleted** — `CS22 CS23 CS23d CS36d
  CS36e` asserted `DESIGN_REVISION` §6's interim folded key that D3 supersedes,
  and item 1's own file had flagged them "tolerable UNTIL ITEM 5B".
- **Issue `0420` filed:** `token.c`'s six `@spice_get_*` branches fold the query
  first (13 `strtolower()`), so the two roads agree under `fold`/`preserve` and
  **diverge under `distinguish`**. Each fold feeds case-sensitive logic
  downstream, so it is **item-4-shaped work, not a deletion** — which is why it
  was filed rather than done here.
- **Declared holes:** `M13` (the `Tcl_UnsetVar` in `ngspice_data_arm()`, whose own
  comment calls it load-bearing) is **unpinned by any check**; `CS103g` is
  **valgrind-only** evidence; and a script's own write into a materialised key is
  silently discarded — documented, not fixed.

## Environment — re-verified 2026-08-16

- Case-capable build: `/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice`
  (`ngspice-46+`). **The build has now moved THREE times** during this batch:
  `2026-08-12` → `Thu Aug 13 22:49:54 UTC` → `Sat Aug 15 18:18:34 UTC` →
  **`Sun Aug 16 06:52:46 UTC 2026`**, the current stamp.
  It is the user's own fork (`/home/qflow/dev/ngspice_test`, branch `ver_50`,
  real ngspice as `upstream`), so it will keep moving.
  **Assert on `$curcasemode` and on measured output, never on "this build has
  fix X in it". Every test needing it must SKIP, not fail, when absent.**
- Baseline ngspice: `/usr/local/bin/ngspice` (`ngspice-46`). Folds always,
  accepts and **ignores** `-D casemode=…`, has no `$curcasemode` (replies
  `Error: curcasemode: no such variable.`) — which is the capability probe.
- Dev display `:99` alive (1920x1080x24, openbox); gate armed `forever`.
- **No round-4 upstream drop.** Latest is
  `feedback/ngspice_upstream/RESPONSE.md`, 2026-08-15 12:31. Check for a new one
  before items 3, 10 or 14 — last time, checking first deleted a whole planned
  migration pass.

## Re-verification at the current build stamp (2026-08-16)

`repro3/run_r3.sh`, `repro3/run_r3b.sh` and `repro2/run_round2.sh` all re-run.
**Every round-3 table holds.** One cell moved and one was reconciled:

- **Near-miss warning count in OUR shape is 1, not 2.** Receipt `00c` records
  `stderr=2`. Both scripts now measure `1`. Reconciled: round 2's `R4` used
  `ctl_fail.cir`, which carries a dot card **and** `.control run` — two analyses,
  hence two warnings. It is **once per analysis**, not a doubling bug.
- **`.save` of an absent node re-measured on today's build: ver_50 is IDENTICAL
  to stock** — rc=1, 12-variable constants raw, **zero** mentions of the bad
  token on either stream. Upstream has withdrawn that fix three times. This is
  why `DECISIONS.md` C3 rules differently from C1.

New measurements taken during the decision Q&A, not in any earlier receipt:

- **`~/.spiceinit` overrides `-D casemode=` too**, not only a `.spiceinit`
  beside the deck. Kills any "check next to the deck" shortcut.
- **The phantom has a current form: `i(all)`.** `op` + exactly one saved
  **current** on stock-46 gives `i(v1) i(all)`. Every earlier note records only
  `v(all)`. Fixed on ver_50 (`0064`) for both.
- **`tran`/`dc` are immune** — their sweep axis (`time`, `v-sweep`) already
  makes the vector count two. Only `op` has no axis.
- **The probe hangs without `quit`** — two minutes, measured. Item 7's timeout
  is not optional.

## Post-merge-5 line numbers (re-grepped; every plan citation was suspect)

| what | plan said | actual at `577ef5bc` |
|---|---|---|
| `strtolower(varname)` — the fold | `save.c:1008` | **`save.c:1008`** — unmoved |
| `get_raw_index` | `save.c:2251` | `save.c:2251` |
| the `i(v.x` fixup | `save.c:2263`/`2260` | **`save.c:2274`** |
| `read_dataset` | — | `save.c:782` |
| `Raw` struct | — | ends `xschem.h:1154` |
| ASE-L `run_cmd` (hardcoded `ngspice`) | `ase.tcl:3238` | `ase.tcl:3238` |
| `simconf` dialog | — | `xschem.tcl:3092` |
| backannotation's duplicate ladder | — | `xschem.tcl:2669`, `:2688`–`:2700`, `:2724` |

## Fixtures committed at item 0

- `fixtures/tr_fold.raw` — tran, nets `In`/`MidNode`, source `Vs`, written under
  `-D casemode=fold`. Variables: `v(in) v(midnode) i(vs)`.
- `fixtures/tr_preserve.raw` — same deck under `-D casemode=preserve`.
  Variables: `v(In) v(MidNode) i(Vs)`.

Both 229-point binary raws, byte-comparable, differing **only** in the Variables
section — so items 1–5 can be tested with no ngspice present at all.

**Trap:** `fixtures/tr_source.cir` uses `write tr_MODE.raw` inside `.control`,
which is **cwd-relative**. Running it with `-r /tmp/x.raw` silently writes
`tr_MODE.raw` into the caller's directory instead. Run it from a scratch dir.
