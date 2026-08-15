# Item 02 — `wviewer::signal_list`, the typed signal inventory — LEDGER RECEIPT

Batch `signal_browser_batch`, branch `fluid-editing`. HEAD at item start `bc1efec9`.
Date 2026-08-04. Written by the ledger stage from the implementer result **and** the
independent verifier result. The implementer's own long-form receipt (committed inside
`6a3f8e42`) is preserved **verbatim** as the appendix at the bottom of this file —
nothing it said was dropped.

---

## 1. Verdict

**DONE.** Verified: `ok: true`, `scopeClean: true`. The verifier re-ran the build, the
suite, both NAMED sabotages (independently re-injected, not trusted from the receipt),
two sabotages of its own, a coverage probe, and a full solo audit; it also ran a causal
test against the pre-item source for every fail it could not immediately clear.

**Committed, NOT pushed.**

| | |
|---|---|
| commit | `6a3f8e42a13d951168348567f3efe08657c5ff41` (short `6a3f8e42`), *"feat(wviewer): signal_list, typed raw inventory"* |
| parent / item-start HEAD | `bc1efec9` |
| scope | 3 files, +518 / -13. No C, no other `.tcl`, no scope leak (`git show --stat`, re-run by the verifier) |
| blast radius | **zero** — `grep -rn 'signal_list\|signal_entry\|sig_split\|sig_bare'` over `src/` and `tests/` finds no caller outside the definition block and the test file (verified independently; the only other hits are the pre-existing, unrelated `graph_get_signal_list` in `xschem.tcl`) |

## 2. Files touched

| file | what |
|---|---|
| `src/wave_viewer.tcl` | +105/-13. Four procs appended to the SIGNAL SEARCH section exactly where item 1 reserved the space: `sig_bare` `:1619`, `sig_split` `:1626`, `signal_entry` `:1636` (all pure) and the one ctx-touching accessor `signal_list` `:1659`. The `:1447` section header was amended in the same commit — it claimed the whole section was *"PURE: no Tk, no `xschem`, no ctx"*, which `signal_list` makes false. |
| `tests/headless/test_wave_sigsearch.tcl` | +178. Groups **SB** (12 pure) and **SL** (15 over two real xschem contexts). |
| `doc/claude/signal_browser_batch/receipts/02_receipt.md` | the implementer long-form — now the appendix of this file. |

Contract as shipped:

```
wviewer::signal_list token -> list of dicts
    {name <full raw name> type <v|i|other> leaf <last segment> path <rest>}
```

`{}` for an unknown token, a REFUSED context switch, or a context with no raw; it never
throws for *"nothing to browse"*. `type` routes through item 1's `wviewer::sig_type` and
is never re-implemented (pinned by SB12 and sabotage u4). No UI, no C, no widget paths —
the first widget is item 4's.

## 3. Tests

| | |
|---|---|
| test file | `/home/qflow/dev/xschem/claude_1/xschem/tests/headless/test_wave_sigsearch.tcl` (settled decision 9: one file, appended) |
| checks added | **27** (SB01-SB12 pure, SL01-SL15 context) |
| checks total | **34 -> 61** |
| verified how | the verifier counted the check ids by hand — SM (26, no SM03) + ST (8) = 34 from item 1, SB (12) + SL (15) = 27 new, 34+27 = **61 EXACT** — and re-ran `./src/xschem --pipe -q --nolog --nogui --script ...` -> `RESULT: ALL PASS (61 checks)`. Green under `--nogui` **and** under a real X (it is in the PASS column of the verifier's full audit). |
| build | `cd src && make` -> *"Nothing to be done for 'all'"* — Tcl-only item, binary unchanged. |

The verifier read all 27 new checks hunting tautologies and self-computed expectations
and found **none**: SB01-SB12 assert against independent literals, SL03 against a
hardcoded 8, SL04 round-trips names through a REAL `xschem raw add`/`raw list` rather
than comparing a value to itself, SL02/SL05/SL14 read `xschem get current_win_path` back
out of the program, and SL12 is a genuine negative control (the MAIN context carries a
decoy var `wrong_ctx_var` that must NOT appear).

## 4. Sabotage table — implementer's round

Seven injections, every one measured, every one **reverted** (see D5 for the revert
mechanism and why it was not `git checkout --`).

| # | sabotage | predicted target | measured | failedExactly | reverted |
|---|---|---|---|---|---|
| **(a) named** | delete `if {![lindex $ticket 0]} { return {} }` from `signal_list` | SL13 (a token whose `win_path` does not exist -> `{}`) | **SL13 alone**, 1 FAILED / 60 passed. Returned the MAIN context's `{vsweep, wrong_ctx_var}` — a literal wrong-context read, exactly the landmine-17 failure mode. SL01/SL02 untouched (there `win_path` differs from current so `enter_ctx` really switches); SL15 caught earlier by the dict-exists guard. | **yes** | **yes** |
| **(b) named** | replace the guarded read with a bare `set names [split [xschem raw list] "\n"]` (the no-raw arm throws) | SL01 (no raw on the viewer ctx -> `{}` and no throw) | **SL01 alone**, 1 FAILED / 60 passed, `ERR:No raw file loaded`. SL02 stayed GREEN because the outer catch restores the context via `leave_ctx` before re-raising — which is the whole reason for that bracket shape. | **yes** | **yes** |
| u1 unnamed | delete the whole `enter_ctx`/`leave_ctx` bracket | SL03/SL04/SL12 | 11 FAILED / 50 passed — SL01, SL03, SL04, SL06-SL13. **Superset** of the predicted set: the shared fixture means one wrong answer trips every `slfind` that reads it. Caught hard. | no (superset) | **yes** |
| u2 unnamed | `signal_entry` stores the BARE name | SB11 + SL04 | 7 FAILED / 54 passed — SB11, SL04, SL06-SL08, SL10, SL11. Settled decision 2's guard fires plus every name-keyed lookup. Caught. | no (superset) | **yes** |
| u3 unnamed | drop the trailing `$` anchor from `sig_bare`'s regexp | SB09 (`sig_bare v(a)b` is UNCHANGED) | **SB09 alone**, 1 FAILED / 60 passed: `v(a)b` -> `a`. | **yes** | **yes** |
| u4 unnamed | inline a case-SENSITIVE classifier instead of calling `sig_type` | SL08 | 2 FAILED / 59 passed — SB12 and SL08, both case-arm checks and nothing else. Proves the `type` field really routes through item 1's `sig_type`. | no (superset) | **yes** |
| u5 unnamed | delete `leave_ctx` (never restore the context) | the 0173 loan discipline | 3 FAILED / 58 passed — SL02, SL05, SL14. **Added beyond the scout's list** because u1 removes the bracket wholesale and therefore never MOVES the context, leaving the restore itself unpinned. It is now pinned three ways. | no (n/a — no single predicted check) | **yes** |

Both NAMED sabotages fired on **exactly one check each**. The three supersets are honest
scoping, not leakage — see D4.

## 5. The verifier's own sabotages, and their outcomes

The verifier did **not** take the table above on trust: it re-injected both NAMED
sabotages itself and added three probes of its own. Every one was reverted with
`git checkout -- src/wave_viewer.tcl` after `git diff` confirmed the file held nothing
but the sabotage, each followed by a clean re-run.

| # | sabotage | outcome |
|---|---|---|
| **V1** (unnamed, verifier's own, aimed at the item core) | hoist the `xschem raw list` read OUT of the `enter_ctx`/`leave_ctx` bracket while **leaving the bracket in place** — i.e. a change that keeps every *"the bracket exists / the context is restored"* check green and only breaks *"the read came from the viewer's context"* | **10 FAILED / 51 passed** — SL01, SL03, SL04, SL06-SL12. **Caught hard.** |
| **V2** (unnamed, verifier's own, surgical) | `sig_split` path off-by-one: `lindex $parts 0` instead of `join [lrange $parts 0 end-1] .` | **3 FAILED / 58 passed** — SB04, SB07, SL10: exactly the multi-level-path checks and nothing else. |
| **V3 coverage probe** (not a defect hunt — a dead-line hunt) | delete `if {![dict exists $windows $token]} { return {} }` AND `if {$code} { return -code error $cres }` together | **ALL PASS (61)** — both lines are **uncovered** by any standing check. See §7 P2. |
| re-injection of named **(a)** | delete the landmine-17 bail | 1 FAILED / 60 passed, **SL13 alone**, and the returned value was literally the MAIN context's `{vsweep, wrong_ctx_var}` — a real wrong-context read. `failedExactly: true` **confirmed as measured by the verifier**, not read off the receipt. |
| re-injection of named **(b)** | bare `split [xschem raw list]` | 1 FAILED / 60 passed, **SL01 alone** (`ERR:No raw file loaded`), SL02 staying green — which independently confirms the catch / `leave_ctx` / re-raise ordering. `failedExactly: true` **confirmed**. |

The verifier also re-verified every cited anchor from source rather than trusting line
numbers: `enter_ctx` `:993`, `leave_ctx` `:1021`, `switch_ctx` `:959`, `in_ctx` `:940`
(`uplevel #0` confirmed), `retitle` `:517` (guards `winfo exists`, does **not** guard
`wm title` — so the test's fake-`top` rule is real), `sig_type` `:1490`, the three
open-coded `split [xschem raw list]` sites at `:2566`, `:6798`, `:7458` (the PLAN's cited
`:7190`/`:7187` has drifted — D2 is honest), `scheduler.c:9693-9696` (raw list is
`\n`-joined with no trailing newline, so `split {} \n` is a 0-element list and the
receipt's "no empty-name guard needed" is correct) and `scheduler.c:9727` (*"No raw file
loaded"* is a `TCL_ERROR`, so the catch arm is genuinely what absorbs it).

## 6. Non-baseline fails

**Implementer:** `nonBaselineFails: []`. One solo `full_audit.sh` (pgrep-checked, nothing
else running) -> `SUMMARY: 268 pass / 15 fail / 0 crash-timeout / 0 skip (total 283)`,
`WIREEDIT PASS`, `SCRATCH 0 leaked dirs`, all 15 fails inside the 18-name baseline, and
three baseline names (`test_remap`, `test_resolved_net_hash_bus_0158`,
`test_wave_trace_menu`) actually PASSED.

**Verifier: that run did NOT reproduce, and the difference was chased to the ground.**
Its own solo audit on the same commit (under the GUI gate, `DISPLAY=:0`, load avg 0.5)
gave `258 pass / 22 fail / 2 crash-timeout / 1 skip (total 283)`, `WIREEDIT PASS`,
`SCRATCH 0 leaked dirs`, with **eight** names outside the baseline. It investigated every
one rather than waving at "flake":

| non-baseline name | disposition |
|---|---|
| `test_fluid_editing` | PASS on immediate re-run |
| `test_key_graph_context` (TIMEOUT) | PASS on immediate re-run |
| `test_prop_form_field_width_0170` | PASS on immediate re-run |
| `test_readonly_action_dispatch` | PASS on immediate re-run |
| `test_rotate_stretch_reconnect_0100` | had SKIPPED *"no X"* mid-audit; PASS on re-run — evidence the X server degraded partway through, which explains the cluster |
| `test_ase_plot` (TIMEOUT) | **causal test**: with `git checkout bc1efec9 -- src/wave_viewer.tcl` (item 2's only source file reverted to the pre-item commit) it TIMES OUT **identically** — pre-existing, documented ASE gesture flake |
| `test_wave_snap` | **causal test**: FAILs identically (SG6+ST21) without the item; then `run_suites.sh -n 3` at HEAD -> **3/3 ALL PASS (106 checks)** |
| `test_altf5_ciw` | PASSes with the item reverted; `run_suites.sh -n 3` at HEAD -> 2/3, the one failure being *"Alt-F5 raises/opens the CIW"* — the documented WSLg key-delivery/raise flake |
| `test_ase_persist` | PASSes with the item reverted; `run_suites.sh -n 3` at HEAD -> 2/3 — flake |

Source file restored with `git checkout 6a3f8e42 -- src/wave_viewer.tcl`, verified clean.
Tree checked for droppings after every run: no stray `*.raw`, no `test_scratch` dirs,
`git status --porcelain` unchanged from the preflight set, `git diff HEAD -- src tests
doc` showing only `PLAN.md`.

**Ledger conclusion: NO regression is attributable to item 2** — every non-baseline name
is a flake or reproduces without the item. But see §7 P1: *"zero non-baseline fails"* is a
property of that lucky run, **not** of the tree, and must not be used as the counter-
evidence to item 1's re-baseline recommendation.

## 7. Verifier problems (all NON-BLOCKING) — carried forward

* **P1 — the audit numbers are not reproducible on this box, in either direction.**
  268/15/0/0 vs 258/22/2/1 on the same commit. The batch baseline is **stale both ways**:
  `test_remap` and `test_resolved_net_hash_bus_0158` passed in BOTH runs, while
  `test_wave_snap`, `test_ase_plot`, `test_altf5_ciw`, `test_ase_persist`,
  `test_fluid_editing`, `test_key_graph_context`, `test_prop_form_field_width_0170` and
  `test_readonly_action_dispatch` all flake here without any help from item 2. **The
  driver should NOT treat item 2's clean audit as the answer to item 1's re-baseline
  recommendation** — the appendix's §9/§11 explicitly does, and that inference is
  withdrawn here.
* **P2 — two lines of `signal_list` are dead under the shipped test set** (found by
  probe V3, not stated by the implementer). The `dict exists` guard is genuinely
  redundant — `enter_ctx` carries the identical guard and returns `{0 {}}` — so check
  **SL15**, named *"an unknown token -> `{}` (the dict-exists guard)"*, is actually pinned
  by `enter_ctx`'s guard, not `signal_list`'s; the CONTRACT it asserts is real and
  correct, only the attribution in the check name is off. The re-raise is exercised only
  transitively, by named sabotage (b). Neither is a defect — but **a later item that
  "simplifies" either line will get no test failure, so items 3/5 must be told.**
* **P3 — D1 is correctly declared, not silent, and the ruling is genuinely owed.** It
  appears in the proc's comment block, the commit message, the test group header AND the
  appendix §2. It diverges from the PLAN's item-2 contract line, **not** from any settled
  decision: the verifier checked settled decision 2 specifically (`name` still the full
  raw name, `type` still routed through `sig_type` off the full name — pinned by
  SB11/SB12/SL04/SL08, watched passing, plus u2/u4), and decisions 8 (no C), 9 (one test
  file, appended) and 13 (state derived from `xschem raw list`, never the rect model) are
  all intact. It is not a rubber stamp: it changes what item 8's tree shows.

## 8. Divergences from the PLAN

| # | divergence | reason |
|---|---|---|
| **D1** | **DRIVER RULING OWED.** `path`/`leaf` are computed on the **UNWRAPPED** name (`v(x1.x2.net5)` -> path `x1.x2` / leaf `net5`), not on a literal dot-split of the full raw name as the PLAN's contract line reads. | Taken literally that line yields path `v(x1` and leaf `net5)`, so item 8's hierarchy tree would grow a node called `v(x1`. Settled decision 2 is UNTOUCHED: `name` is still the full raw name (SB11/SL04) and `type` still reads the `v(`/`i(` prefix off the full name via `sig_type` (SB12/SL08) — decision 2 governs the MATCH SUBJECT, not the tree split, and `sig_match` is still fed full names. If the driver rules the other way it is a two-line change to `sig_bare` plus checks SB01/SB04/SB07/SL10/SL11. |
| **D2** | The PLAN's *"currently done at `wave_viewer.tcl:7190`"* is **incomplete**: there are THREE open-coded `split [xschem raw list]` sites, now at `:2566`, `:6798` and `:7458`. | Item 2 deliberately retires NONE of them (zero blast radius); items 3/5 own them. Recorded in the section header and here so a later item cannot retire one and declare victory. Independently re-measured by the verifier; the PLAN's `:7190`/`:7187` has drifted. |
| **D3** | The scout listed two new test helpers (`pcall` and `check_true`); only **`pcall`** shipped. | No item-2 check needed `check_true`, and an unused helper in a file six more items will append to is noise. `pcall` itself is REQUIRED, not stylistic — sabotage (b) makes `signal_list` throw, and an unguarded throw hits item 1's outer `catch ... bigerr` and aborts every remaining check, turning a one-target sabotage into a file-wide abort. |
| **D4** | One unnamed sabotage beyond the scout's four (**u5**: delete `leave_ctx`), and u1/u2/u4 fired on **supersets** of their predicted targets. | u5 was added because u1 removes the bracket wholesale and therefore never moves the context, leaving the 0173 restore unpinned by any sabotage. The supersets are honest scoping — a shared fixture means one wrong answer trips every `slfind` reading it — not leakage. Both NAMED sabotages fired on exactly one check each, confirmed by the verifier's independent re-injection. |
| **D5** | Sabotages were reverted from a verified byte-exact **snapshot of the item's own file**, not `git checkout -- src/wave_viewer.tcl`. | The item was uncommitted at that point, so a git checkout would have destroyed the ITEM along with the sabotage. Each restore was proven with `diff` (IDENTICAL, exit 0) plus a green re-run — the same guarantee, one level down. Each injection was also confirmed by `diff` to be the sabotage and nothing else before it was run. (The verifier's own round ran post-commit and could therefore use `git checkout --`.) |
| **D6** | `doc/claude/signal_browser_batch/PLAN.md` was left dirty and NOT staged by the item. | Its pending diff is the **item-1** ledger tick (`-> DONE (a6913ab2 + bc1efec9)`), which the driver's own preflight note calls expected; it is the driver's file, not item 2's. Verified by the verifier: `git diff PLAN.md` is exactly that one added line. Item 2's own ledger line was left unticked for this ledger stage, which has now ticked it. |
| **D7** | The implementer receipt was written to `receipts/02_receipt.md` per the driver's correction, not the PLAN's older `receipts/02_signal_list.md`. | Item 1's precedent split the two roles (`01_sig_match.md` = implementer long-form, `01_receipt.md` = ledger). Because the implementer wrote the long-form straight to the pipeline path, this ledger stage **merged rather than clobbered**: the ledger receipt is §1-§8 above and the implementer's long-form is preserved verbatim as the appendix. Nothing was lost and no second file was created. |
| **D8** *(this stage)* | The ledger line carries a short **DRIVER RULING OWED** note in addition to the bare `-> DONE (6a3f8e42)`. | Following item 1's ledger precedent, which embeds the item's open flags inline. D1 is a ruling the driver owes that changes item 8's output; a bare tick would bury it. `PLAN.md` line 306 still reads **`Receipt: receipts/02_signal_list.md`** — deliberately NOT corrected, because this stage's brief was the ledger line only and correcting the detail section is the driver's call. |

## 9. If a human looks at one thing

Not applicable to the verdict — item 2 is **DONE** and nothing here is a failure. The two
things awaiting a human are both the driver's, in this order:

1. **D1 / P3 — rule on `path`/`leaf`.** It decides what item 8's hierarchy tree shows.
   Two-line change to `sig_bare` plus five checks if the ruling goes the other way; the
   longer it sits the more items build on the current shape.
2. **P1 — the baseline.** Item 2's *"zero non-baseline fails"* was a lucky run, not a
   property of the tree. Item 1's re-baseline recommendation still stands and should be
   decided on its own merits, with `test_remap` and `test_resolved_net_hash_bus_0158` as
   candidates to REMOVE from the 18-name baseline and eight flaky names as candidates to
   note.

Also to hand to items 3/5 when they start: **P2** (the two dead lines in `signal_list`)
and **D2** (the three open-coded sites, and which item owes each).

---

---

# APPENDIX — implementer long-form receipt, preserved verbatim

Below is the receipt as committed inside `6a3f8e42` (file
`doc/claude/signal_browser_batch/receipts/02_receipt.md`, 248 lines), unedited. Where it
and §1-§9 above disagree, **§1-§9 wins** — specifically its §9/§11 claim that item 2's
audit is evidence against item 1's re-baseline recommendation, which is withdrawn by P1.

---

# Item 02 — `wviewer::signal_list`, the typed signal inventory — receipt

Batch `signal_browser_batch`, branch `fluid-editing`. HEAD at item start
`bc1efec9`. Date 2026-08-04. Implementer receipt (the PLAN's older name for this
file was `02_signal_list.md`; the pipeline's path is `02_receipt.md` and that is
what this is).

---

## 1. What shipped

Four procs in `src/wave_viewer.tcl`, appended to the SIGNAL SEARCH section
exactly where item 1's header reserved the space (`:1459`, "Item 2 appends
`wviewer::signal_list` to this section"):

| proc | line | pure? |
|---|---|---|
| `wviewer::sig_bare {name}` | 1619 | pure |
| `wviewer::sig_split {name}` | 1626 | pure |
| `wviewer::signal_entry {name}` | 1636 | pure |
| `wviewer::signal_list {token}` | 1659 | **ctx-touching** — the only one |

Contract, as delivered:

```
wviewer::signal_list token -> list of dicts
    {name <full raw name> type <v|i|other> leaf <last dot-segment> path <rest>}
```

`{}` on: an unknown token, a REFUSED context switch, or a viewer context with no
raw loaded. It never throws for "nothing to browse".

**No UI.** Item 2 ships no toplevel, no frame, no binding, no menu entry. The
first widget in this batch is item 4's search bar.

**Blast radius: zero.** `grep -rn 'signal_list\|signal_entry\|sig_split\|sig_bare'
src/ tests/` outside the definition block and the test file returns no callers.
Nothing user-visible changes.

## 2. The `path`/`leaf` divergence — DRIVER RULING OWED

**Declared, not silent.** The PLAN's contract line reads
*"leaf <last dot-segment> path <all but last>"*. Read literally against the FULL
raw name, `v(x1.x2.net5)` splits into path `v(x1` and leaf `net5)` — item 8's
hierarchy tree would then grow a node literally called `v(x1`.

Shipped instead: `sig_bare` strips ONE `<fn>(...)` wrapper **for the path/leaf
split only**, so `v(x1.x2.net5)` -> path `x1.x2`, leaf `net5`.

This does **not** touch settled decision 2, which governs the MATCH SUBJECT:

* the `name` field is still the FULL raw name (pinned by SB11 + SL04),
* `type` still reads the `v(`/`i(` prefix off the FULL name via `sig_type`
  (pinned by SB12 + SL08),
* `sig_match` is still fed full names — nothing in item 1 changed.

It is a refinement of item 2's own contract line, and the driver owns it. **If
the driver rules the other way** it is a two-line change to `sig_bare` plus
checks SB01/SB04/SB07/SL10/SL11 — no other code moves.

## 3. Why the bracket shape in `signal_list` is what it is

Measured, not reasoned. Do not "simplify" it:

* **`enter_ctx`/`leave_ctx`, not a bare `new_schematic switch`.** Switching INTO a
  viewer is a LOAN (issue 0173, `wave_viewer.tcl:967-982`): the switch runs
  `set_modify(-1)`, which rewrites the target window's `wm` title. A read must
  put the context back *and* re-assert the title. `wviewer::readout_refresh` is
  the direct-caller template.
* **The `if {![lindex $ticket 0]} { return {} }` bail is landmine 17.**
  `new_schematic switch` silently no-ops while the current context's semaphore is
  raised; proceeding blind returns *somebody else's raw*. Measured under sabotage
  (a): the answer became the MAIN context's two vectors.
* **NOT `wviewer::in_ctx`.** Its body runs at `uplevel #0` (the ⚠ at `:933-939`),
  so a body that produces a value pollutes globals — and using it would move
  sabotage (a)'s target into shared code every other viewer path rides.
* **`catch` the body, re-raise AFTER `leave_ctx`.** Load-bearing twice over: it is
  correct product behaviour (a throw must not escape past the restore and leak the
  foreign context), *and* it is what makes sabotage (b) single-target. Measured:
  with no bracket at all, sabotage (b) fails TWO checks (SL01 + SL02); with a
  bracket that SWALLOWS instead of re-raising, it fails ZERO.
* **No empty-name guard in the final `foreach`.** `split {} "\n"` is a 0-element
  list, and the C `raw list` arm (`scheduler.c:9692-9696`) emits no trailing
  newline — a guard would be an untestable branch.

## 4. The three open-coded sites still outstanding

The PLAN says the open-coded `split [xschem raw list] "\n"` is "currently done at
`wave_viewer.tcl:7190`". That is **incomplete** — there are THREE, and after item
2's insertion they sit at:

| line | context | retired by |
|---|---|---|
| `:2566` | `set varlist [split [xschem raw list] "\n"]` | item 5 |
| `:6798` | `set names [split [xschem raw list] "\n"]` | item 5 |
| `:7458` | the Add Trace dialog's listbox fill (with the `catch` arm at `:7455` that produces the *"no raw data loaded"* note at `:7456`) | item 3/5 |

**Item 2 deliberately retires none of them**, so the accessor lands with zero blast
radius. The section header now names all three and says who owes them.

## 5. The `:1447` header amendment

Item 1's header claimed the whole SIGNAL SEARCH section was *"PURE: no Tk, no
`xschem`, no ctx"*. `signal_list` is the first member that touches both the
context and the `xschem` command, so leaving that claim would have made it a lie a
later scout would trust. The header now splits the section into a MATCHER half
(pure) and an INVENTORY half (pure except `signal_list`), and carries the
open-coded-site table from §4.

## 6. The test seam — fabricated `windows` entries, and the fake `top`

`tests/headless/test_wave_sigsearch.tcl` grew groups **SB** (12 pure checks) and
**SL** (15 context checks); the file goes **34 -> 61 checks**.

The `::wviewer::windows` entries are **fabricated** rather than produced by
`wviewer::open`. What that costs and what it does not:

* **Genuine:** the token points at a REAL second xschem context, created by
  `xschem new_schematic create` (`.x1.drw`). The context switch, the per-context
  raw, the refusal path and the 0173 restore are all real.
* **Fake:** only the toplevel. Going through `wviewer::open` would drag in
  `ase::session_open` plus the sky130A cellview scaffolding, and the ASE machinery
  carries the documented P4/P6/P8 gesture flakes — for no extra coverage of
  `signal_list` itself.
* ⚠ **The `top` field MUST be a NON-EXISTENT widget path** (`.wvsl_no_such_top`).
  `leave_ctx` calls `wviewer::retitle`, which guards `winfo exists` but **not**
  `wm title` — pointing `top` at a real non-toplevel frame throws out of
  `leave_ctx` under X while passing under `--nogui`. Both configs measured green
  with a non-existent top.

New test convention: **`pcall`** (error-guarded call, returns `ERR:<msg>` instead
of throwing). Required, not stylistic — sabotage (b) makes `signal_list` throw,
and an unguarded throw hits item 1's outer `catch ... bigerr` and aborts every
remaining check, turning a one-target sabotage into a file-wide abort. The
scout also listed a `check_true` helper; it is **not** shipped, because no item-2
check needed it and an unused helper is noise.

## 7. Process state left for items 3-7

Items 3-7 append to this same file (settled decision 9) and inherit a process that
is **not pristine**. Documented in the test file's header too:

* a SECOND xschem context, `.x1.drw`;
* an in-memory raw on EACH context — `sl_main.raw` (`vsweep`, `wrong_ctx_var`) on
  `.drw`, `sl_view.raw` (the SLFIX names) on `.x1.drw`;
* two `::wviewer::windows` entries, `wvsl` and `wvsl_bogus`.

The group ends by switching the context back to the main window.

**Expected stdout noise**, harmless and new (`full_audit.sh` keys its verdict on
the `RESULT:` line only, `:84`, so neither string can flip a verdict):

```
can't read "toolbar_visible": no such variable
new_schematic("switch_tab"...): no tab to switch to found: .wvsl_nosuch.drw
```

Nothing is written to disk: `xschem raw new` is in-memory, no `.raw` file appears
(verified with `git status --porcelain`).

## 8. Sabotage table — measured, every one reverted

Two named + five unnamed. Because the item was still uncommitted, a
`git checkout -- src/wave_viewer.tcl` would have destroyed the item itself, so each
sabotage was reverted from a byte-exact snapshot of the item's own file and the
restore was **verified with `diff`** (`IDENTICAL`, exit 0) plus a clean re-run —
the same guarantee, one level down.

| # | sabotage | expected target | measured | exactly? |
|---|---|---|---|---|
| **(a)** | delete `if {![lindex $ticket 0]} { return {} }` | SL13 | **SL13 alone**, 60/61 — returned the MAIN ctx's `{vsweep, wrong_ctx_var}`: a literal wrong-context read | **yes** |
| **(b)** | `set names [split [xschem raw list] "\n"]` (the no-raw arm throws) | SL01 | **SL01 alone**, 60/61 (`ERR:No raw file loaded`). SL02 stayed green *because* the outer bracket restores before re-raising | **yes** |
| u1 | delete the whole `enter_ctx`/`leave_ctx` bracket, read the current ctx | SL03/SL04/SL12 | 11 FAILED — SL01, SL03, SL04, SL06-SL13. Superset of expected | caught |
| u2 | `signal_entry` stores the BARE name | SB11 + SL04 | 7 FAILED — SB11, SL04, SL06-SL08, SL10, SL11 (decision 2's guard, plus every `slfind`) | caught |
| u3 | drop the trailing `$` from `sig_bare`'s regexp | SB09 | **SB09 alone**, 60/61 (`v(a)b` -> `a`) | **yes** |
| u4 | inline a case-SENSITIVE classifier instead of `sig_type` | SL08 | SB12 + SL08, 59/61 — both case-arm checks, nothing else | caught |
| u5 | delete `wviewer::leave_ctx $token $ticket` (never restore) | — | SL02, SL05, SL14, 58/61 — the 0173 loan discipline is pinned three ways | caught |

u5 was added beyond the scout's list because u1 removed the bracket wholesale and
therefore never *moved* the context, leaving the restore itself unpinned. It is
now pinned.

## 9. Verification

1. `cd src && make` -> *"Nothing to be done for 'all'"* (Tcl-only item).
2. `tests/headless/run_suites.sh test_wave_sigsearch` -> **RESULT: ALL PASS (61
   checks)**, under the GUI gate.
3. Standalone both ways, since the file header claims both:
   `--nogui` -> ALL PASS (61); with X -> ALL PASS (61).
4. Sabotage round: §8, seven injections, each measured, each reverted, each
   followed by a green re-run.
5. One solo `tests/headless/full_audit.sh` (nothing else running, pgrep-checked):

```
SUMMARY: 268 pass  15 fail  0 crash/timeout  0 skip  (total 283)
WIREEDIT: PASS      SCRATCH: 0 leaked dir(s)
```

**Non-baseline fails: ZERO.** All 15 fails are in the 18-name baseline; three
baseline names (`test_remap`, `test_resolved_net_hash_bus_0158`,
`test_wave_trace_menu` — the TG9 flake) PASSED this run. `test_wave_sigsearch` is
in the pass column. This is the cleanest audit of the batch so far and it is a
data point for item 1's re-baseline recommendation (D7): the flaky set item 1 saw
did not reproduce here at all.

6. `git status --porcelain -- src/ tests/ doc/` shows only this item's two files
   plus the pre-existing `PLAN.md` ledger tick for item 1, which is **not staged**
   — it is the driver's, not this item's.

## 10. Anchors re-verified from the shipping tree

Every line the scout cited was re-measured before it was trusted. Numbers below
are **post-insertion** (i.e. what a reader of the shipped file sees) except where
marked, because item 2 itself moved everything below `:1447`:

* `:1459` *(pre-insertion)* — item 1's "Item 2 appends `wviewer::signal_list` to
  this section" reservation. Exact; the insertion landed there.
* `:1583` *(pre-insertion, now `:1596`)* — `return [list ok $out]`, `sig_match`'s
  last line; `target_clamp` followed at `:1589` *(now `:1678`)*. The four new
  procs landed between them.
* `:518-524` — `wviewer::retitle`, `winfo exists` guarded, `wm title` NOT.
  Unmoved, and this is what forces the fake-`top` rule in §6.
* `:940-953` — `in_ctx`'s `uplevel #0` ⚠ and its catch/leave/re-raise shape.
  Unmoved.
* `:959`, `:993`, `:1021` — `switch_ctx`, `enter_ctx`, `leave_ctx`. Unmoved (all
  three sit above the insertion point).
* `scheduler.c:9692-9696` — the `raw list` arm, `\n`-joined, no trailing newline;
  `:9727` — `"No raw file loaded"`, the throw the no-raw arm absorbs.
* The three open-coded sites, re-measured post-insertion — §4.

Standing warning carried forward from item 1 and honoured here: **drift is not a
constant** (`+40` almost everywhere, `+53` at `wviewer::open`, `+179` at the Add
Trace dialog). Never add a delta; re-measure.

## 11. Divergences from the PLAN

| # | divergence | reason |
|---|---|---|
| **D1** | `path`/`leaf` computed on the UNWRAPPED name (§2) | The literal reading puts `v(x1` in item 8's tree. Declared in code, in the test group header and here. **Driver ruling owed.** |
| **D2** | The PLAN's "currently done at `wave_viewer.tcl:7190`" is incomplete — there are THREE open-coded sites (§4) | Found by the scout, re-measured by me. No action owed by item 2; recorded so items 3/5 do not retire one and declare victory. |
| **D3** | `check_true` not shipped; only `pcall` | No item-2 check needed it. An unused helper in a file six more items will append to is noise. |
| **D4** | Two unnamed sabotages beyond the scout's four (u5), and u1/u2/u4 fired on supersets of their predicted targets | u5 closes a real hole: u1 removes the bracket wholesale and so never moves the context, leaving the restore unpinned. The supersets are honest scoping, not leakage — the shared fixture means one wrong answer trips every `slfind` that reads it. Both NAMED sabotages fire on exactly one check each. |
| **D5** | Sabotages reverted from a verified byte-exact snapshot, not `git checkout --` | The item is uncommitted, so `git checkout --` would have destroyed the item along with the sabotage. Each restore was proven with `diff` (`IDENTICAL`) plus a green re-run — the same guarantee. |

Carried forward, **not item 2's to fix**: item 1's SM04 ruling (D4 there) and the
re-baseline recommendation (D7 there). On the re-baseline: item 2's audit produced
**zero** non-baseline fails, which is evidence the batch tree is fine and the churn
item 1 saw was load/WSLg noise.
