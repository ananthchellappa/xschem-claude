# Casemode batch ledger — branch `fluid-editing`, base HEAD `577ef5bc`

Driver-mode unattended batch. **THE BATCH IS COMPLETE — all 16 items landed.**
`[x]` ×13, `[E]` ×3 (items 5, 13, 14 — pixels). No `[D]`, no `[F]`. **Nothing is
pushed.** Nothing is pushed.

**Final audit: `audit_item15_closer_2026-08-18.txt` — 330/15/0/0 of 345** at
`ec2f553f`, IDENTICAL by name and status to item 13's. Every item so far has moved **zero** audit statuses; all growth is the
ten suites they added. **8 `look` debts are open** (items 5 ×2, 13 ×4, 14 ×2) plus a `:0` suite debt; **only the user clears the looks** and only the
user clears those. **Issues filed by this batch: `0418`, `0419`, `0500`, `0501`,
`0502` (code execution), `0503`, `0504`, `0505`.**

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
| 5b | **one lookup authority + lazy `ngspice_data`** (D3) | `[x]` | `9f354aa0` | 160 new | 43 | 8 + 4 audits | no | **All three D3 properties landed; property 3 NOT deferred.** Audit = two added rows (its own suites), zero movers. Workflow died after Verify and was RESUMED. Verifier found a **real shipped leak**, fixed. Spec §13. Issue `0500` filed |
| 6 | extend `sim()` / `simconf` / `simrc` | `[x]` | `169495a4` | 97 | 100 | 9 + 2 audits | no | **RECOVERY RUN** — first attempt died on API 529 with impl null, so Verify + all 3 lenses were SKIPPED and nothing was ever attacked. Relaunched with the disk state described. Audit = one added row, zero movers. Fields: `exe|args|casemode|detected|probed|nospiceinit` + `sim_profile`. Issue **`0502`** filed (code execution) |
| 7 | the capability probe (+ hard timeout) | `[x]` | `ebf4c952` | 61 | 69 | 4 + 3 audits | no | audit = one added row, zero movers. **Two probes built** (capability + run), §3b's contradiction resolved. **Transport changed `-p` → batch deck** (`-p` opens `$DISPLAY` and CORES with it unset). Spec §11 |
| 8 | profile-aware `run_cmd` + mismatch policy | `[x]` | `d44febbd` | 38 | 38 | 3 + 3 audits | no | audit = one added row, zero movers (`_closer2_` authoritative). REFUSE = **before anything is generated**, `run_deck`'s first statement. `CS177c` **pins the two arg filters apart forever**. Spec §12 |
| 9 | `sod_expr` stops folding + current arm | `[x]` | `799cd912` | 54 | 51 | 8 + 3 audits | no | audit = one added row, zero movers. **TEN assertions moved, not ~20 — and only `HL17`'s VALUE changed.** Declared departure from §D3 → issue `0503`. Spec §13 |
| 10 | three defences: pre-flight + `$sim_status` + content | `[x]` | `c56581a4` | 114 | 85 | 5 + 1 audit | no | audit = one added row, zero movers. All three defences + D1 offers + `0503` **narrowed**. The modal is deliberately NOT built (rationale §14.5) — hence `[x]`, not `[E]`. Spec §14 |
| 11 | `result_probe` `-nocase` | `[x]` | `1d217632` | 28 | 19 | 6 + 3 audits | no | audit = one added row, zero movers. **A LADDER with a D2 decline + a delivered-mode veto, NOT a `-nocase` flag** — the naive fix was re-run and reddens 10 checks. **Corrected §13.6**: a plain `fold` run reaches the defect too. Spec §15 |
| 12 | post-load current repair | `[x]` | `66d7122f` | 56 | 51 | 6 + 1 audit | no | audit = one added row, zero movers. **A GUARD, not a rescue** — item 9's construction model is right, so on a correctly-picked expression the repair is needed **never**. In memory only; the session is never rewritten. Spec §16 |
| 13 | simulator dialog (extends `simconf`) | `[E]` | `e998e853` | 69 | 69 | 6 + 1 audit | **YES ×4** | audit = one added row, zero movers. Makes items 8/10/12's dormant paths **reachable by gesture**. 4 look debts + a `:0` suite debt. Two findings carried out → issues `0504`, `0505`. Spec §17 |
| 14 | netlister collision warning + `model_name()` key | `[E]` | `a7f56fa6` | 40 | 39 | 8 + 2 audits | **YES ×2** | audit = one added row, zero movers. Fix round found the warning **reached nobody** (ERC window opens only on error) → canvas cue + status bar. Fires on a **shipped example** → issue `0501`. Spec §14 |
| 15 | docs | `[x]` | `ec2f553f` | – | 10 | 8 + 3 audits | no | audit **IDENTICAL** to item 13's, both directions. Found a **fifth** stale doc claim and a `save.c` comment naming two functions item 5b had DELETED. `C1` (`v(all)` AND `i(all)`) and Xyce-unverified both documented |

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
- **Issue `0500` filed:** `token.c`'s six `@spice_get_*` branches fold the query
  first (13 `strtolower()`), so the two roads agree under `fold`/`preserve` and
  **diverge under `distinguish`**. Each fold feeds case-sensitive logic
  downstream, so it is **item-4-shaped work, not a deletion** — which is why it
  was filed rather than done here.
- **Declared holes:** `M13` (the `Tcl_UnsetVar` in `ngspice_data_arm()`, whose own
  comment calls it load-bearing) is **unpinned by any check**; `CS103g` is
  **valgrind-only** evidence; and a script's own write into a materialised key is
  silently discarded — documented, not fixed.

## Carry-forwards item 14 handed on — C CHAIN COMPLETE, baseline `audit_item14_closer`

**Baseline is `audit_item14_closer_2026-08-17.txt` — 322/15/0/0 of 337** at
`a7f56fa6`. **Items 1, 2, 3, 4, 5, 5b and 14 each moved ZERO statuses.** All
growth across the whole C chain is the six suites they added. Item 14 is `[E]`
with **two `look` debts**; only the user clears those.

**A WARNING THAT REACHED NOBODY — the fix round's real find.** C2 says warn, not
error. But the netlist ERC window opens only when the pref is `always` or when
`err != 0`, default `onerror` — so a warning that correctly left `err == 0`
**was invisible by construction**. The fix paints both spellings into the
highlight table (`!netlist_count`, one colour per pair) exactly as its five
sibling netlist warnings already do, plus a status-bar summary. **Still two
channels, not three:** `statusmsg(str, 2)` for netlist-time detail (where all
fifteen `netlist.c` warnings go) and `ciw_echo … note` for the relay.

**IT FIRES ON A SHIPPED EXAMPLE, AND THE WARNING IS TRUE — issue `0501` filed.**
`xschem_library/examples/test_bus_tap.sch` genuinely carries `VCC`+`vcc` **and**
`VSS`+`vss` (driver-verified by grep). §14's premise "no committed fixture
collides" is corrected in place. No audit row moved because no test netlists that
example — so the empty-diff contract held while user-visible behaviour changed.
**`xschem_library/` is otherwise UNSWEPT for collisions.**

**Two of its own citations were struck as non-evidence, self-caught:**
`CS121`/`CS121b` were cited for "warn, never error" and **were not evidence** — an
`err |=` left them green while flipping the netlist's exit code 0→10. The ruling's
real check is `CS143`.

**C2's mechanic 2 partly REFUTED by measurement.** C2 says ngspice's collision
line "repeats once per subcircuit instantiation", implying dedup is what stops
forty identical lines. Measured: ngspice **prefixes the instance path**, so three
instantiations are three *different* pairs and all survive. The dedup earns its
keep against one line arriving twice on our **two-stream scan**, not against
per-instantiation repeats. The line is on **stderr only**.

**RULING — the relay is ALWAYS ON, unlike the check**, for three reasons: it names
the outcome itself, it sees `.include`d cards our netlister cannot, and it carries
the mode the run *actually* had, which a `.spiceinit` can change.

Other rulings (spec §14):

- **Called from `spice_netlist()`, not `traverse_node_hash()`** — the latter is
  also the interactive `show_unconnected_pins()` pass and serves all five
  backends; the former is per-level, so a **subcircuit-body** collision is caught,
  which is the case upstream misses under `fold`. §14's `spice_primitive` trigger
  claim was false and is corrected: a `spice_netlist=true` child **with
  `split_files`** gets the check inside a spectre/Verilog run.
- **Part (b) narrowed an existing fold and added none.** The trap was the
  **parse**, not the hash — the `sscanf` literals matched only because the fold
  had just run, so they became a length skip. The card **keyword** stays
  case-blind in every mode.
- **`my_snprintf` drops a whole conversion** on a long pair: names-first, a
  973-char pair emitted 1990 chars carrying neither the diagnostic phrase nor
  `(casemode=…)`. The phrase now comes first.
- **The dedup key is anchored** on `'…' and '…' differ only in case` so a
  mis-parse **fails safe**.

**Pre-existing droppings, driver-verified, NOT item 14's:** `relaycheck.tcl`
(2026-08-11, predates the batch) and `tr_MODE.raw` (2026-08-16 06:30, from the
`repro2`/`repro3` re-runs — the documented cwd-relative `write` trap). Both left
unstaged, correctly.

## Carry-forwards item 6 handed on — baseline `audit_item06_closer_2026-08-17`

**Baseline is `audit_item06_closer_2026-08-17.txt` — 323/15/0/0 of 338** at
`169495a4`. Items 1, 2, 3, 4, 5, 5b, 14 and 6 have each moved **zero** statuses.

### A PIPELINE FAILURE MODE WORTH KNOWING — read before relaunching any item

Item 6's first attempt **died on an API 529, not a logic failure**. The
implementer errored *while returning*, so the pipeline saw `impl == null` and
`if (impl)` **skipped the Verify stage and all three Review lenses**. The closer
then 529'd too. Result: 470 lines of finished-looking work on disk, **committed by
nobody and attacked by nothing** — no verifier, no reviewer, no sabotage row.

**A 529 in the implementer silently downgrades the pipeline to "write code, hope".**
When an item returns `[F]` with `commit: ""`, check `git status` before assuming
nothing happened, and relaunch with the disk state described in the hints so the
next crew assesses rather than restarts. A plain `resumeFromRunId` would have
replayed a cached-null implementer without telling anyone the tree was half-built.

### A driver hint that was wrong, and the correction

An earlier dispatch told crews "the baseline carries a `test_ase_core` failure that
reproduces on a pristine HEAD binary — do not chase it". **Half wrong, and
dangerously phrased.** Measured:

```
test_ase_core  --nogui      ALL PASS (75 checks)
test_ase_core  display arm  1 FAILED (58 passed)
   UNEXPECTED ERROR: ase: design aselib/nfet_clean is not the current schematic
pristine tree, same arm     1 FAILED (57 passed)   <- identical abort, so NOT a regression
```

The failure is **display-arm only**, and `full_audit.sh` runs that suite `--nogui`,
which is why the baseline records `test_ase_core` as **PASS**. So: it is genuinely
pre-existing, but "it's a known red" must never be used to wave away a
`test_ase_core` failure. **If it goes red in `full_audit.sh`, that is a
regression.** The 15 real baseline reds are now listed verbatim in the pipeline's
POLICY block so this cannot recur.

### Issue `0502` — CODE EXECUTION, pre-existing, filed not fixed

`ase::expand_path` (`src/ase.tcl:174`) expands `$VAR` in model / `.include` /
`.lib` / `pre_commands` paths **taken out of an ASE-L state file**, via
`subst -nocommands`. That flag does **not** stop command substitution inside an
**array index** — Tcl parses the index of `$A(...)` itself. Verified independently
by the driver:

```tcl
set ::RAN 0
catch {subst -nocommands -nobackslashes {$A([set ::RAN 1])/x}} out
# out = can't read "A(1)": no such variable      ... and ::RAN is now 1
```

So **opening a state file someone else wrote can execute arbitrary commands.**
Item 6 guarded its own new field (`sim_profile_exe_path`, `xschem.tcl:2932`) and
filed the issue; the **three original call sites remain unguarded** —
`ase.tcl:3271` (`.include`), `:3274` (`.lib`), `:3327` (`pre_commands`). Not this
batch's scope. Item 8 and item 10 both touch the deck renderer and should not make
it worse.

### Other carry-forwards

- **The row fields as shipped:** `exe`, `args`, `casemode`, `detected`, `probed`,
  and **`nospiceinit`** (A2's `-n`, the field only — item 13 owns the checkbox).
  `detected` is kept **separate from** `casemode` precisely so item 13 can build
  A1's probe-driven dropdown; collapsing them would have made that impossible.
- **`sim_profile`** is in `schema_keys` **and** `omit_if_empty`, so no existing
  ASE-L state file grows a line on first save. `test_ase_core`'s `R1` was
  **restated 16 → 17 keys**, not renumbered or deleted, and the closed-set
  property it exists for is unchanged.
- **`simrc_pre_casemode`** is the frozen pre-batch fixture proving an old
  hand-written `simrc` still round-trips byte-identically.
- **Two `06-` receipts now exist and they are different items:**
  `receipts/06-one-lookup-authority.md` is **item 5b**;
  `receipts/06-simulator-profiles.md` is **item 6**. Both say so in their headers.

## Carry-forwards item 7 handed on — baseline `audit_item07_closer_2026-08-17`

**Baseline is `audit_item07_closer_2026-08-17.txt` — 324/15/0/0 of 339** at
`ebf4c952`. Every casemode item so far has moved **zero** statuses.

**THE PROBE TRANSPORT CHANGED, AND IT INVALIDATES A MEASUREMENT THE DRIVER MADE.**
`§3b` (and the driver's own dispatch, which had run it successfully) specified
`printf … | $exe -p`. Measured live, mid-item: **`ngspice -p` opens `$DISPLAY`.**
On an exhausted X server it exits with **no answer**; with `DISPLAY` **unset it
dumps core**; on `:99` it answers. A three-mode binary was reporting as supporting
**none** because X was busy. The driver's confirming run only worked because `:99`
happened to be up. **The transport is now `-b <abs deck>`**, which answers
identically under all three conditions and is nearer the real run. `CS170n` pins
all three; reverting to `-p` reddens it. **The pipe transport is gone, not kept as
a fallback.**

**Rulings (spec §11), each with its measurement:**

- **TWO probes, one mechanism parameterised by cwd.** §3b's row is
  self-contradictory — it says "capability probe" but specifies the deck's
  directory, and at registration there is no deck. `sim_profile_probe_capability`
  (`xschem.tcl:3503`, fresh empty temp dir, **records** `detected`+`probed`) serves
  item 13; `ase::sim_probe_run` (`ase.tcl:585`, the **deck's own** directory,
  **records nothing**) serves item 8. Building one would have blocked the other.
- **A1 resolved as (b): probe EACH mode, three invocations.** "Presence implies
  all three" rejected — `$curcasemode` reports the *current* mode, never the
  supported *set*, and both known failure shapes (item 3's wrong-case **key**
  silent ignore, A2's `.spiceinit` override) are request-vs-measurement failures
  that presence-implies-support cannot see.
- **`no such variable` is an ANSWER**, recorded as `detected {fold}` — not a B2b
  breach, because B2b governs *no answer*. Recording `{}` would offer the ordinary
  `apt install` user nothing.
- **A timed-out leg never contributes a mode and invalidates the WHOLE
  measurement** (new `partial` status, never recorded). The first cut recorded a
  partial as `ok`, so one transient stall **permanently narrowed the row** — and
  with `fold` stalled, claimed the row could not deliver the global default.
- **The timeout is Tcl-native and bounds the WHOLE probe.** The first cut timed
  out per *leg*: 3 × 5000 = **15016 ms frozen**, the exact outcome B3 mandated it
  to prevent. Now one budget, re-measured **5006 ms**. `timeout(1)` rejected
  (GNU-only; this tree ships on Windows), `fileevent`+`vwait` rejected
  (re-entrancy inside item 13's modal dialog). Driven by actually hanging it.

**⚠ `sim_probe_safe_args` IS A PROBE-ONLY FILTER — ITEM 8 MUST NOT COPY IT.** A
profile's `args` are spliced into Tcl exec syntax, so for a **probe** they had to
be filtered: `args {> zap.txt}` wrote a file into the probe's cwd (**the user's own
rundir** for a run probe), `args {| cat}` swallowed the answer and was recorded as
"delivers nothing", and `-r`/`-o` — xschem's own shipped batch shape — made the run
probe **overwrite the previous run's outputs**. That filtering is correct for a
probe and **wrong for the real run**, which legitimately needs `-r`/`-o`.

**Other traps found:** `sim_probe_tmpdir` needs a per-process counter plus
`file normalize`, because `file mkdir` **succeeds silently on an existing
directory** — two calls in one millisecond shared one dir and the second's cleanup
deleted the first's. The probe deck never lands in the caller's cwd, and the
child's stdin is the null device.

**Nothing was written to the developer's home directory** — `~/.spiceinit` does not
exist on this machine, checked before and after; ngspice was **measured to honour
`HOME`**, so that layer is driven with `HOME` pointed at a scratch dir and
`CS170e` asserts the override, the real-`HOME` control, and the restore together.
Still true and recorded in §11.8: **the capability probe is not clean either** — an
empty cwd cannot exclude `~/.spiceinit`.

**Declared holes:** the 64 KB output cap and `truncated` flag are undriven; only
the two measured `.spiceinit` layers (cwd, `$HOME`); no `-D` key but `casemode`;
`CS169q` and `alive` are Linux-specific (`/proc`, `kill -0`); and `CS170e`'s
`home_restored` / `CS170n`'s `display_restored` rest on the test's own bookkeeping.

## Carry-forwards item 8 handed on — baseline `audit_item08_closer2_2026-08-17`

**Baseline is `audit_item08_closer2_2026-08-17.txt` — 325/15/0/0 of 340** at
`d44febbd`. Item 8 kept three audit files for provenance; **`_closer2_` is the
authoritative one** (the driver checked: `_closer_` and `_closer2_` are identical
by name and status anyway). Its closer also **self-checked its differ** by
diffing the baseline against itself.

**The probe filter did NOT leak into the run, and a check now pins them apart
permanently.** `CS177c` reads **both** filters on `-r` / `--rawfile` / `--soa-log`
and **reddens if they ever agree**; wiring the probe filter in reddens it. That is
the driver's dispatch warning turned into a standing guard, which is better than
the warning.

**Rulings (spec §12), each measured:**

- **`-o`/`--output` IS dropped from a run, and reported.** Measured on real
  `/usr/local/bin/ngspice`: `-b d.cir` prints `v(a) = 1.000000e+00` on stdout;
  `-b -o o.log d.cir` prints only the log-file banner and **`ase::last_result`
  comes back empty**. Reading `-o`'s file back was rejected — it would make
  ASE-L's parse depend on a path the user chose.
- **`-D casemode=` is emitted only for a NON-`fold` request.** `build-ver_50` with
  no `-D` already answers `CCM=fold`; stock accepts and ignores it; a
  `.spiceinit` overrides it anyway. Always emitting would change every existing
  user's command line and buy nothing.
- **An exe a row NAMES but we cannot locate REFUSES in every mode.** The bare-PATH
  fallback would silently run a **different simulator** — and ver_50 has moved
  three times in four days.
- **REFUSE means before anything is generated.** The gate is `run_deck`'s **first
  statement**, before its first `open` and before the cosim artefacts are cleared:
  no deck, raw, log, VCD deletion, `.so` rebuild, process, `last_run` or callback.
  The message says the rundir's files are from an earlier run. "Not confirmed"
  (timeout, noexe, probe error) **also** refuses under `distinguish`, because
  B4's clause is *confirmed to support it* — which is what catches B4's third
  route, the binary moving under the path.
- **The gate is armed only by a non-`fold` request**, so per A1 it never fires for
  a stock user.
- **A `stale`/`invalid` resolve is REPORTED, not refused.** Item 6 delegated this
  here, and the first cut computed the status and **read it nowhere**, so a
  renamed row **silently ran a different binary** (measured, two stand-ins).
  Refusing was rejected: a hand-edited `simrc` must not make a saved session
  unopenable, and the probe still measures the binary that will actually run.
- **The advice must name a lever that exists** — on the global-floor path there is
  no profile row and no `-n` checkbox, so "turn on the profile's `-n`" was
  nonsense there.
- **The report reaches three channels:** `ase::echo` → CIW pane (item 14's house
  rule), the action log, and the head of `<rundir>/<cell>_ase.log` via
  `run_done`'s new **optional** `notes` argument — optional so `test_ase_cosim`'s
  six 3-argument callers keep working.

## Carry-forwards item 9 handed on — baseline `audit_item09_closer_2026-08-17`

**Baseline is `audit_item09_closer_2026-08-17.txt` — 326/15/0/0 of 341** at
`799cd912`. Every casemode item has still moved **zero** statuses.

**THE DISPATCH'S "~20 ASSERTIONS FLIP" WAS WRONG, AND THE REAL NUMBER IS BETTER.**
Enumerated across all ten named files plus a whole-tree grep: **ten change, and
only `HL17` changes its expected VALUE** (`v.x2.V1` → `V.x2.V1`). The other nine
(`AN10`, `AN11`, `AN12`×2, `H1`×2, `HP1`, `HP2`, `HP3b`) gain an explicit `fold`
argument with **unchanged values** — which is A1 working, not a shortfall. All ten
keep their ids and gained a why-comment; none renumbered, none deleted.

**A REAL DATA-CORRUPTION BUG, found by review and reproduced before fixing.**
`sim_profile_resolve` opened with `::set_sim_defaults`, which is **not a read**:
with `.sim` open it slurps every `…r.$i.cmd` widget into `sim()`. Measured on the
shipped tree — `USER-IS-STILL-TYPING` typed into the spice row-0 box **survived one
`sod_click` and the Cancel after it**. A read-only pick (issue `0204`) may not
write global config. Fixed by asking with `init 0` plus a one-time build guarded
by `![info exists ::sim(tool_list)]`; other callers keep `init 1`.

**A RULING FOUND BY SABOTAGE.** `sod_case_mode` **delegates and does not
re-validate**. The first cut kept a second copy of `::sim_profile_casemode`'s
validation; it **survived every mutation green and masked a real defect** — a
`sod_case_mode` reading `$::sim_case_mode` raw still folded garbage, so `SC206`
was blind. Deleted; three checks now redden.

**Other rulings (spec §13):**

- **The mode is a REQUIRED third argument of `sod_expr`, never defaulted.** A
  defaulted mode is a *silent* fold, and a folded `.save` under `distinguish` is
  `rc=1`, zero vectors, "analysis not run" — the whole session's data. A missing
  argument is a loud Tcl error instead.
- **`sod_qualify` gains NO mode; the branch prefix follows the TOKEN**, re-using
  item 4's `ver_50` measurement. `sod_expr` owns the whole case mapping, and
  `hilight.c`'s `sender_current_prefix()` (`buf[0]=t[0]`) is the C half of the
  same rule — the two roads now agree by construction.
- **The governing mode is the RUN's request** — profile `casemode` → floor
  `sim_case_mode` → `fold`; never a loaded raw's `case_sensitive`. Resolved **once
  per gesture**, before the bus fan-out.
- **A resolver throw folds but is ANNOUNCED** — the blanket `catch` was the same
  silent fold one layer up.
- **A1 IS NOT UNIVERSAL, AND THE EXCEPTION IS A REPAIR.** `vsource_pwl` /
  `vsource_arith` ship `type=vsource` templated `name=E1`, `filesource`
  `name=A1`, so the expression *does* move for them — because **the old literal
  `v.` was BROKEN for those devices**. Measured on `ver_50`: the raw carries
  `i(e.x1.e1)`; `.save i(e.x1.e1)` → rc 0 with the vector, `.save i(v.x1.e1)` →
  "analysis not run" and a 570-byte empty raw. The false quantifier was struck
  from the comment, the spec and the receipt; both columns are pinned.

**⚠ DECLARED DEPARTURE FROM `PLAN` §D3, WITH A MITIGATION ITEM 10 MUST BUILD.**
§D3 says `sod_expr` stops folding *unconditionally*; **A1's byte-identity
requirement outranks it** and forces the mode-conditional shape. The property §D3
bought is therefore lost: **a row picked under `fold` is stale under a later
`distinguish` profile** — filed as issue **`0503`**. The mitigation is written
into spec §13.6 and is **item 10's**: its pre-flight must **REFUSE** such a run.

## Carry-forwards item 10 handed on — baseline `audit_item10_closer_2026-08-17`

**Baseline is `audit_item10_closer_2026-08-17.txt` — 327/15/0/0 of 342** at
`c56581a4`. Zero statuses moved, as for every item before it.

**A CORRECTION TO `DECISIONS.md` C4's REASONING (not its shape).** C4 presents the
`$?sim_status` existence block as guarding against the variable being absent.
Re-measured: it is a **MARKER that defence (b) is inert on that build, NOT an
error suppressor** — `Error: sim_status: no such variable.` is printed at parse
time with the block exactly as without it. The guard shape is unchanged; the
comment and spec §14.3 now say what the block actually does.

**C4's MASKING TRAP REPRODUCED, which is why the guard is per-analysis.** A
failing `dc` followed by a good `tran` with **one end-guard** gives `rc=0` and a
2198-byte raw — **the failure masked**. Per-analysis gives `rc=1` and nothing
written. `F64` is that defect wired back in, and it reddens 6 checks.

**Rulings (spec §14):**

- **The map is built from the NETLIST ARTIFACT, never the schematic**, because
  `ase::run_existing` deliberately runs a netlist the design may no longer match.
- **The map OVER-approximates deliberately**, and the asymmetry is the argument:
  a device card's node count is device-dependent, so every non-`k=v` token after
  the instance name is treated as a node. That error can only make a name look
  **present** when it is not — a miss, caught by (b) and (c). The opposite is a
  **false refusal**, and (a) is the only defence that can block a *good* run.
- **`unknown` is a refusal to judge, and the gate NEVER refuses on it** —
  `@dev[param]`, a bracketed non-exact hit, a hierarchy segment whose master this
  netlist does not define, and a flat name in an `.include`-bearing scope where
  nothing even folds to it. The stand-down is **deliberately narrow**: a fold hit
  is a proof about *this* netlist and still refuses with its correction, or
  defence (a) would be **inert on every PDK design**.
- **Under `fold` BOTH sides fold** — §13.6's trap, built and pinned **first**
  (`PF214`). Item 9 emits `v(midnode)` where the netlist says `MidNode`; a
  case-sensitive comparison would false-refuse **the default mode's every run** on
  any mixed-case design. `preserve` compares case-insensitively (D1's scope).
- **REFUSE = `run_deck`'s first statement after the netlist read**; everything
  between item 8's gate and it only reads. No deck, raw, log, deleted VCD, rebuilt
  `.so`, `last_run` or callback.
- **Every offender gets its own CIW line at tag `error`**, and `ase_preflight 0`
  is a real lever named in the message — item 14's lesson applied: a one-line
  summary of twelve corrections is unactionable.
- **The content check's variable count is a FLOOR that only corroborates**,
  recorded after a decisive marker fires, else a good 2-variable raw would be
  annotated. `set appendwrite` is **reported, not rejected** (plot 1 is genuine); a
  file it cannot parse as a spice raw is **not judged at all** (including one that
  merely quotes the header, as our own refusal message does); and a
  `constants`-named plot carrying **real data** (>12 variables or >1 point, e.g.
  `let`-created vectors) is reported, not thrown away. Scan bounded to head+tail
  64 KB.
- **Wired into `attach_dbs` BEFORE the registry is touched**, so a rejection
  leaves the previously loaded database exactly where it was.

**D1: THE MODAL IS DELIBERATELY NOT BUILT, and the reasoning is sound.**
`ase::preflight_fix_session <key>` composes one whole correction per expression,
rewrites the rows, marks the session dirty and echoes each rewrite; the refusal
names the command. **Nothing rewrites implicitly.** A run-path modal would force
`[E]` plus a fifth look debt for a dialog **no decision in this batch specifies**,
and item 13 owns that surface. Detection, corrections and apply are all headless
and driven — what is deferred is **one button**. Hence `[x]`.

**Issue `0503` is NARROWED, not closed.** The silent-wrong-answer half is gone —
the run refuses, names both stale rows, offers both corrections and names the
issue. The staleness remains, because `0503` asks for a re-case pass derived from
the **schematic** while this is a confirmation-gated repair derived from the
**netlist**, inheriting the map's blind spots. **Whoever builds the re-case pass
closes it.**

## Carry-forwards item 11 handed on — baseline `audit_item11_closer_2026-08-18`

**Baseline is `audit_item11_closer_2026-08-18.txt` — 328/15/0/0 of 343** at
`1d217632`. Zero statuses moved.

**IT CORRECTED SPEC §13.6, WHICH ITEM 9 HAD WRITTEN FOR IT.** §13.6 narrowed item
11 to one combination (requested `preserve`, measured `fold`). Verified rather
than trusted, and the doc was **one combination short**: `render_deck` writes an
output row's `expr` **verbatim**, and the only fold in `ase_window.tcl` is at
`:956` inside item 9's `sod_expr` (whole-file grep, one hit). **Add/Edit Output,
hand-written state files and `expand_bus_outputs` all ship mixed case**, so a
**plain `fold` run reaches the defect too**. The ladder serves both.

**THE NAIVE FIX WAS RE-RUN, NOT ASSUMED WRONG.** `-nocase` as a flag on rung 1
reddens **10** checks — `v(EN)`'s row taking `v(en) = 1.0`, a wrong number in the
Value column. So the shape is the batch's house ladder: exact spelling first
(first line wins, unchanged), a case-insensitive pass second, and **decline when
the second offers more than one differently-cased label** — D2's rule, matching
item 2's `get_raw_index` and item 5's `resolve_signal_db`.

**A NEW RULE THE BATCH DID NOT HAVE: what the run DELIVERED outranks what it
REQUESTED** (§15.4b, added in the fix round after a reviewer produced the run).
`~/.spiceinit` overrides `-D casemode=`, and items 7/8 arm only on a **non-`fold`**
request — so **a plain `fold` run against a `distinguish` init file is measured by
nobody**, and pre-fix it was handed the value of a signal ngspice had just
refused to print. The log announces the delivery, so the log is read; a false
positive costs an empty cell, which is the pre-item-11 behaviour and the safe
direction.

**Other rulings (spec §15):**

- **Rung 2 is OFF under `distinguish` — measured, not cautious.** Under
  `-D casemode=distinguish` a card naming a spelling the circuit lacks prints
  **nothing** while the case-kept line prints two rows away, so a lenient match
  attributes that number to a different net. `NC225b` is the positive control, so
  `NC225` pins the gate rather than an unmatchable pattern.
- **The collision counts SPELLINGS, not lines.** Two analyses print `v(in) = …`
  twice; rung 1 always took the first, so rung 2 does too. Counting lines would
  kill every multi-analysis run's values.
- **The decline SAYS SO** — one CIW line at tag `error` naming every candidate.
  Item 14's lesson: a silent decline is the same empty cell this item removes.
- **The KEY is never folded, only the MATCH.** A folded key puts a named row's
  value where `ase::ui::output_result_key` will not look.
- **The mode is asked READ-ONLY, once per log** — `::set_sim_defaults` is not a
  read; it commits an open Simulation Configuration dialog's unsaved edits.

**Reachability of the decline is stated, not hidden:** with rung 2 off under
`distinguish`, and `fold`/`preserve` merging case-variant nets, **no run this tree
can produce reaches it today**. Kept as a standing guard and driven
synthetically, because the alternative is an unguarded `-nocase` that becomes
wrong the moment item 8's policy is relaxed.

## Carry-forwards item 12 handed on — baseline `audit_item12_closer_2026-08-18`

**Baseline is `audit_item12_closer_2026-08-18.txt` — 329/15/0/0 of 344** at
`66d7122f`. Zero statuses moved.

**IT IS A GUARD, NOT A RESCUE — and that is a measurement, not a hedge.** On
`build-ver_50`, a `.subckt` holding `Vs` and VCVS `E1` in `X1`: `fold` gives
`i(v.x1.vs) i(e.x1.e1) i(v1)`; `preserve`/`distinguish` give
`i(V.X1.Vs) i(E.X1.E1) i(V1)` — **byte for byte what item 9's
`sod_qualify`+`sod_expr` compose**. So item 9's construction model is right and
**on a correctly-picked expression the repair is needed never.**

**THE REAL GATE IS `Raw.case_sensitive`, AND IT IS A THEOREM.** Under
`preserve`/`fold`, item 2's folded rung already answers every case-only mismatch,
so "unmatched" and "matchable case-insensitively" are **disjoint** and this code
cannot fire. Only `-case distinguish` separates them (`raw index i(v.x1.vs)` = −1
while `i(V.X1.Vs)` = 4). One exception, covered: a folding DB whose fold key is
**D2-poisoned**.

**Reachability stated, not overstated:** nothing in ASE-L passes `-case`; no
shipped caller does `raw read … -case` or `raw case 1`; `rawbar_load` reads bare;
the viewer's Case Mode control is item 3's **reporting-only** verb. So it is
**unreachable from every gesture a user can make today** — the one live route is a
script/console `xschem raw case 1` then `dp_finish`/`auto_plot`. Kept as a
standing guard in item 11 §15.5's shape. **Item 13 is what turns it live.**

**§13.6 WAS ONE PRODUCER SHORT AGAIN — the same shape item 11 found.** A current
also arrives verbatim from `output_editor_ok`, a hand-written state file and
`expand_bus_outputs`, and `plot_map_expr` **buries one inside the RPN**
`i(v1) -1 *`. Hence the repair is **token-wise**, and `auto_plot` maps *before* it
repairs. §13.6 carries the correction in place.

**Other rulings (spec §16):**

- **Not a second lookup ladder.** The candidate scan runs over
  `wviewer::name_rungs`, so item 2's `i(v.x`→`i(x` rung is honoured rather than
  re-implemented, with an agreement leg against `resolve_signal_db`. The rule is
  re-applied inline rather than by calling that proc, because calling it costs one
  `signal_list_all` per token.
- **D2 counts SPELLINGS, not slots or occurrences.** One differently-cased
  spelling repairs; two decline at `error` naming every candidate; one name in two
  databases is one answer.
- **In memory; the session is NEVER rewritten** — D1's precedent and item 10's
  explicit `ase::preflight_fix_session`. The row's `expr` and the state file keep
  the user's text, nothing is marked dirty, and the next load repairs and
  announces again.
- **Currents only, by argument not by fence:** a voltage is *resolved* by
  `xschem resolved_net`, so there is nothing constructed to be wrong about. The
  predicate was **widened** to ngspice's `savecurrents` form `@m.x1.m0[id]`,
  because `ase::ui::output_kind` in the same feature already calls that a current
  — two predicates disagreeing was a review finding.
- **A PERFORMANCE DEFECT THE DISPATCH'S WARNING DID NOT COVER.** Item 3's 147 ms
  figure was about the *schematic* comparison; review found a **per-token
  `name_index` rebuild** costing **581.2 ms** on 30 expressions over 10001 names.
  Hoisted into `prepare_slots`: **450.9 ms → 17.7 ms**, verdicts byte-identical.
- **The repair may collapse two queue entries into one string**, so `dp_finish`
  re-dedupes afterwards and filters `qcolors` in lockstep, keeping issue `0153`'s
  one-colour-per-signal invariant.
- **"Post-load" means after an attach actually happened.** `dp_finish`'s no-run
  branch attaches nothing, and the first cut repaired there against whatever raw
  the viewer already held; the call is now gated on `attach_raw`'s return value.

## Carry-forwards item 13 handed on — baseline `audit_item13_closer_2026-08-18`

**Baseline is `audit_item13_closer_2026-08-18.txt` — 330/15/0/0 of 345** at
`e998e853`. Zero statuses moved. **Item 13 is `[E]` with four `look` debts and a
`:0` suite debt; only the user clears the looks.**

**IT MAKES THREE EARLIER ITEMS' CODE REACHABLE BY GESTURE.** Until this dialog
existed, nothing in ASE-L could set a `distinguish` profile, so item 8's REFUSE
path, item 10's pre-flight and item 12's repair were all dormant — item 12's
receipt said in terms that "item 13 is what turns it live". They are live now.

**TWO FINDINGS CARRIED OUT OF THE ITEM, BOTH FILED BY THE DRIVER:**

- **Issue `0504`** — `ase::run_mode_advice` (`src/ase.tcl:990`) keys on
  `sim_profile_resolve` returning status `default`, which happens whenever the
  session **names** no explicit `sim_profile` — not whether a usable row exists.
  So a user who configured a row **through this very dialog** is told "This
  session has NO simulator profile row … or configure a profile": **both clauses
  false, and the second instructs them to repeat what they just did.** Reachable
  by hand-edited `simrc` since item 6; **item 13 makes it reachable by gesture**,
  which is why it is filed rather than noted. Item 8's own rule — *the advice must
  name a lever that exists* — is what it violates.
- **Issue `0505`** — item 5 wrote "the override is deliberately NOT persisted —
  item 13 owns durability", and **that hand-off was never carried into item 13's
  scope by the driver**. Item 13 correctly refused to absorb a *viewer* setting
  into a *simulator profile* dialog rather than silently widening. The issue
  records that **nobody has decided whether it should persist at all**, and notes
  that a persisted explicit setting is the same staleness class as `0503`.

## BATCH CLOSED — the whole-batch audit result

Verified by the driver at `ec2f553f`, diffing the **final** audit against the
**pre-batch** baseline `merge5_loose_ends/audit_item02_fixround_2026-08-16.txt`
(316/15/0/0 of 331, at `577ef5bc`), by test NAME and STATUS:

**14 rows added, ZERO statuses moved in either direction.** Every added row is a
suite this batch wrote:

```
test_ase_current_repair  test_ase_preflight       test_ase_result_case
test_ase_sod_case        test_hilight_case_senders test_netlist_case_collision
test_ngspice_data_ctx    test_ngspice_data_view   test_raw_case_mode
test_sim_dialog          test_sim_probe           test_sim_profiles
test_sim_run_profile     test_wave_casemode
```

Sixteen items, roughly 1100 new checks and 800 sabotage drives, and **not one
pre-existing test changed status**. That was `receipts/00a-suite-sweep.md`'s
contract from before item 1, and it held for the whole batch.

**Issues this batch filed (8):** `0418` `0419` `0500` `0501` `0502` `0503` `0504`
`0505`. **`0502` is a code-execution surface** — `ase::expand_path` runs a command
substitution hidden in an array index, so opening an ASE-L state file someone else
wrote can execute arbitrary commands. **Pre-existing, filed not fixed.**

**What still needs a human:**

1. **8 `look` debts + 1 `:0` suite debt** — `tests/headless/owed.sh list`. A green
   suite never discharges an eyeball.
2. **Nothing is pushed.** 30+ commits sit on `fluid-editing`.
3. **Issue `0501`** is a judgement call about a shipped file: `test_bus_tap.sch`
   really does carry `VCC`+`vcc` and `VSS`+`vss`, so item 14's warning fires on a
   shipped example and the warning is **true**.

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

---

# POST-BATCH — issue 0506, the gap the batch's own scope lines deferred

Added 2026-08-18, after the batch closed at item 15. Not an item; recorded here
because this ledger is what a later session reads to find out where things stand,
and "the batch is closed" was true while the stated goal was still one wire short.

**How it was found.** By asking, of the shipped tree, how far it was from the goal
in plain words: *a net named `EN` in the schematic, shown in the waveform viewer as
`v(EN)`*. The answer was "everything except the last hop" — and no item owned the
last hop, because two scope lines had each correctly declined it.

| the scope line | the item it was right for | now |
|---|---|---|
| `simulator_profiles.md` §10 "Any `cmd` rewriting. Nothing derives a `cmd` from an `exe`" | item 6 — empty audit diff, byte-identical simrc | **superseded narrowly** by §18: one word, three conditions, declines both shipped templates it was written about |
| §10 "`netlist_case_mode()` stays unwired… this is the expression that goes in it when a consumer needs it" | item 6 — no consumer existed | **wired**; the consumer arrived with §18 |
| `raw_case_mode.md` §10 "unknown is **permanent**… no released ngspice writes the header" | item 3 — true of files others wrote | **corrected** for files we cause to be written; we now emit `casemodewrite` |

**What this says about the batch, and it is the useful part.** Every one of those
three was a *correct* deferral with a *stated* reason, and the batch still shipped
a tool whose dialog measured one binary while its Simulate button ran another. A
scope line that is right for its item is not the same as a gap that is owned. The
three were each visible in a different file, and nothing joined them up — no item
was ever asked "does the thing work end to end", because every item was asked
"does your slice hold". **The end-to-end question needs an owner of its own.**

**Carry-forwards.**
- The **dialog is still silent** about a `cmd` that cannot take the flags: an
  `unplaceable` row is discovered at run time, in the CIW. Item 13's status line
  is where it belongs.
- **No probe on this path**, so no B4 verdict — a `distinguish` request here
  composes and launches where ASE-L would refuse. The raw's own header is what
  reports back, which is the other half of why `casemodewrite` is emitted.
- **Spectre/VACASK with a `Case` field is unmeasured** and nothing is emitted.
- The `look` debts are **10** now, not 8. `EYEBALL_SIGNOFF.md` steps 48–59.

Receipt: `receipts/16-issue-0506-plain-simulate-wire.md`. Audit:
`audit_issue0506_2026-08-18.txt`, diffed against `audit_item15_closer_2026-08-18.txt`.
