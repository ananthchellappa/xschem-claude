# Item 00 — PRECONDITION: issues 0186 / 0187 — ledger receipt

Ledger-stage receipt (implement + verify closeout). Batch `signal_browser_batch`,
branch `fluid-editing`, batch HEAD at start `ccd5f30a`. Date 2026-08-03.

The implementer's own long-form receipt is
`doc/claude/signal_browser_batch/receipts/00_precondition.md` — it carries the design
argument, the 0186 re-measurement and the §3 decoupling evidence. This file is the
ledger record: verdict, hashes, counts, sabotages, divergences.

---

## 1. Verdict

**DONE** — with the item **SPLIT**, exactly as the scout verdicted:

* **0187 — FIXED.** Tcl only, `src/wave_viewer.tcl`. Verified end-to-end by the
  verifier's own A/B probe against the pre-fix proc (§6).
* **0186 — REPRODUCED, NOT FIXED, carried as `[D]`.** It needs C
  (`scheduler.c:10036` reload branch + the routing-exempt in-place loads at
  `save.c:3734/3810/3814/3827`), which batch decision 8 forbids, and its Part 2 is an
  undecided design question by the issue's own words.

Verifier: `ok: true`, `scopeClean: true`.

**Open driver call, not a defect:** the ledger line is ticked `[x]` while one of its
two issues is `[D]`. The PLAN's item-0 text says *"needs real design → `[D]`, and items
8-15 are automatically deferred with it"*. The implementer recommends **NOT** firing
that auto-defer and flagged it loudly (ledger line, receipt headline,
`00_precondition.md` §3); the verifier re-read the evidence but did not re-measure it.
Premise measured false: a frame packed `-side left -fill y -before $top.drw` with a
child survives `xschem reload` fully (sidebar/packing/child/toplevel/drw all 1 before
and after), and the raw survives 424 → 424 vars. The "more state makes it worse"
mechanism belongs to 0187 — which is fixed here.

## 2. Commit

`3098afa0` (single commit; not pushed).

## 3. Files touched

| file | why |
|---|---|
| `src/wave_viewer.tcl` | the 0187 fix — new pure proc `wviewer::ctx_verdict`, `wviewer::open` rewired, stale 10-line comment deleted |
| `tests/headless/test_wave_viewer.tcl` | X1–X9 appended |
| `doc/claude/issues/0186-viewer-context-destroyed-by-reload-and-inplace-loads.md` | re-anchored + new HANG datum |
| `doc/claude/issues/0187-wviewer-open-context-guard-is-circular.md` | closed out |
| `doc/claude/signal_browser_batch/receipts/00_precondition.md` | implementer receipt (new) |
| `doc/claude/signal_browser_batch/PLAN.md` | ledger tick + item-0 filename correction |

Verifier confirmed from `git show --stat 3098afa0` plus full per-file diffs: the commit
touches **only** item-00 files, no scope leak into unrelated source.

## 4. Test file and check counts

* Test file: `tests/headless/test_wave_viewer.tcl`
* **Added: 9** (X1–X9). **Total: 57** true-headless (48 → 57), **400** under a real
  `DISPLAY` (392 → 400 — X8 self-skips there, see divergence D2).
* Both arms **ALL PASS**, re-run independently by the verifier through
  `tests/headless/run_suites.sh`.

## 5. Sabotage table (implementer, 3 named)

All three were declared in advance. The fix was uncommitted at sabotage time, so
`git checkout --` would have discarded the fix along with the sabotage: `src/wave_viewer.tcl`
was backed up to the scratchpad and each revert was restored from that backup and
confirmed byte-identical by `diff`.

| id | sabotage | target | failedExactly | reverted | observed |
|---|---|---|---|---|---|
| SB-A | rule (2) made `if {0}` — behaviourally the pre-0187 code | X3, X4 | **yes** | **yes** (scratchpad backup, diff byte-identical) | `--nogui` `2 FAILED (55 passed)`; `DISPLAY` `2 FAILED (398 passed)`; `test_pristine_untitled_viewer_0172` stayed 41/41 |
| SB-B | rule (3), the `$ninst`/`$nwires` belt, deleted | X5, X6 | **yes** | **yes** (diff showed only the 3 deleted lines) | `--nogui` `2 FAILED (55 passed)`; `DISPLAY` `2 FAILED (398 passed)` |
| SB-C | the old circular guard reinstated alongside the new call (a tautology — no behaviour change) | X9 | **yes** | **yes** (scratchpad backup, diff byte-identical) | `--nogui` `1 FAILED (56 passed)`; `DISPLAY` `1 FAILED (399 passed)` — proves X9 is not decorative |

SB-A and SB-B each move **two** checks because each targets one rule that two checks
exercise; that pairing was declared up front and the contract held is *"exactly the
declared set moves, nothing outside it"*. Clean re-run after every revert: **57/57**
headless, **400/400** DISPLAY.

## 6. The verifier's own unnamed sabotages — and the end-to-end probe

**Unnamed sabotage #1 — the wiring the three named sabotages never touched.** The
`wviewer::open` call site was changed to `ctx_verdict $wp $tops1 $tops1`, so rule 2
always refuses.
*Outcome:* the `--nogui` arm stayed **57/57 ALL PASS** (expected — `open` returns 0
without `has_x`), while the **DISPLAY arm FAILED 9 checks** (G1 open returns 1, G1
toplevel exists, G1t ×2, G1 untitled-class, G1s ×3). This proves the *live*
`wviewer::open` path is covered — and proves the `--nogui` arm alone is blind to the
argument wiring. Reverted with `git checkout --`, diff-confirmed byte-identical against
a pre-sabotage backup.

**Unnamed sabotage #2.** Dropped only the `[lsearch -exact $tops0 $top] >= 0` half of
rule 2. *Outcome:* **exactly X3 + X4** failed headless (`2 FAILED / 55 passed`).
Reverted, byte-identical.

**End-to-end A/B probe of the actual filed defect** (`scratchpad/probe_0187.tcl`, run
through `gated_xschem.sh` under `DISPLAY`): park the context on a real non-root editor
window `.x1`, shim `xschem load_new_window` to a silent no-op (the measured
slot-exhaustion shape), then call the **live** `wviewer::open`.
*Outcome:* **fixed tree** → returns 0, the victim window stays `readonly=0 no_grid=0
wave_viewer=0`, verdict OK. **Pre-fix `wviewer::open`** (extracted from `ccd5f30a` and
`eval`'d over the new one) → returns 1 and **brands the victim** `readonly=1 no_grid=1
wave_viewer=1`. The fix demonstrably fixes the filed defect. No committed check does
this end-to-end.

**Bisect of the residual audit reds** (§7): `ccd5f30a:src/wave_viewer.tcl` was restored
over the fixed file and `test_wave_modes` re-run ×2 — **MG16 fails identically on the
pre-fix tree**. Restored with `git checkout --`, byte-identical.

## 7. Non-baseline fails

**Attributable to this item: none.**

| run | result |
|---|---|
| implementer `full_audit.sh` | 264 pass / 17 fail / 1 crash-timeout / 0 skip (282); `WIREEDIT: PASS`; `SCRATCH: 0 leaked` |
| verifier `full_audit.sh` (independent, full 282) | 258 pass / 21 fail / 3 timeout; `WIREEDIT: PASS`; `SCRATCH: 0 leaked` |
| baseline | 264 / 18 / 0 / 0 |

Implementer's diff vs the 18-name baseline: three baseline fails **passed**
(`test_remap`, `test_resolved_net_hash_bus_0158`, `test_wave_trace_menu`); three
off-list names appeared (`test_ase_plot` TIMEOUT, `test_cadence_window_hop_log`,
`test_multi_window`) — all three re-run individually, **all three PASS** (15 / 150 /
ALL PASS in its `--logdir` arm). None opens a viewer, so none can reach the changed code.

Verifier's run was worse: **eight** names moved off-baseline —
`test_load_window_routing`, `test_prop_form_field_width_0170`,
`test_readonly_action_dispatch`, `test_wave_markers`, `test_wave_split_strip`,
`test_wave_snap`, `test_wave_modes`, `test_wave_viewer`. All eight re-run individually:

* **Six pass outright:** `test_load_window_routing` 14 ALL PASS,
  `test_prop_form_field_width_0170` 12 ALL PASS, `test_readonly_action_dispatch`
  `ACTION_READONLY_TEST_PASS`, `test_wave_markers` 983 ALL PASS,
  `test_wave_split_strip` 221 ALL PASS, `test_wave_snap` 106 ALL PASS.
* **Two stayed red and were bisected:** `test_wave_modes` MG16 and `test_wave_viewer`
  (G5/G6/G9a/TD8/TD9). MG16 fails **identically on the pre-fix tree**; the audit capture
  shows `send_key` printing *"WSLg focus stall"*. This is the documented WSLg
  key-delivery + stale-cursor flake family, not this item.
* The `test_wave_viewer` **TIMEOUT** was 10 s-per-stalled-key on top of a ~71 s nominal
  run, **not** X8 running — the audit's own captured output shows
  `SKIPPED: X8 slot-exhaustion probe` in the DISPLAY arm, with X1–X7 and X9 all reading
  `ok:`.

**Health note for later baselines in this batch:** the box is degrading mid-session
(implementer 264/17/1 → verifier 258/21/3) and the documented cure (`wsl --shutdown`)
has **not** been applied. Treat the 18-name baseline list as optimistic on this machine
right now.

## 8. Divergences from the PLAN, each with its reason

**D1 — item SPLIT: 0187 fixed, 0186 carried as `[D]`.**
*Reason:* 0186 needs C at `scheduler.c:10036` plus the routing-exempt in-place loads
(`save.c:3734/3810/3814/3827`), which batch decision 8 forbids; and its Part 2 is an
undecided design question in the issue's own words. The scout verdicted this split.

**D2 — X8 runs in the `--nogui` arm ONLY; it prints an explicit `SKIPPED` line under
`DISPLAY`.**
*Reason:* measured 65 ms and no visible windows headless vs **57.5 s and 19 real
toplevels** under X. `full_audit`'s per-test timeout is 120 s and `test_wave_viewer`'s
DISPLAY arm is already ~55 s; X8 also exhausts all 20 window slots, starving anything
after it. X8 asserts *C* behaviour this Tcl fix does not change.
*Consequence:* 57 checks headless, **400** under DISPLAY — not 401.

**D3 — X8's stop index is 20, not the PLAN's 19.**
*Reason:* 19 creates succeed (`.x1`…`.x19`) and the 20th no-ops. The check asserts the
behaviour (`stuck && rc == 0 && err eq {}`), not the index.

**D4 — the GUI arm G1–G17 WAS run, contradicting the scout's "no usable DISPLAY on this
box".**
*Reason:* that was an artefact of the scout running with `--nogui`. `DISPLAY :0` is
usable (`xdpyinfo` rc 0) and the GUI gate was inside an approved window, so the arm ran
through `run_suites.sh` / `gated_xschem.sh`: **392 → 400 ALL PASS**. This retires the
scout's highest-consequence risk (rule 2 false-refusing under the tabbed interface).
`winfo children .` in a live tabbed session was confirmed to list `.tabs .x1 .x2 …`, so
the `.xN` toplevels really are direct children of `.` in tabbed mode. The verifier
additionally confirmed from C (`xinit.c new_schematic`) that `create_window` calls
`create_new_window` **regardless of** `tabbed_interface` and only does `toplevel .xN`
under `has_x`, and that `create_new_tab` makes no toplevel — so a context parked on a
tab correctly refuses.

**D5 — the 0186 re-measurement numbers are the implementer's own, not the scout's.**
*Reason:* the raw used has **424 vars / 20503 points**; the scout's "46 vars" was a
different raw. Reported as measured.

**D6 — NEW 0186 datum not in the PLAN: under a real `DISPLAY`, reload on a viewer also
HANGS** on the modal `alert_ {Unable to open file: untitled-1.sch}` — a probe sat there
until killed at 200 s.
*Reason:* the original filing was `--nogui` and could not see this. Recorded in the
issue and in `00_precondition.md` §2.

**D7 — `PLAN.md` item-0 filename citation corrected in place.**
The PLAN cited `0186-viewer-buffer-hijacked-by-pristine-untitled-reuse.md` — 0172's
title carrying 0186's number.
*Reason:* in scope (it is the item implemented), corrected with a note saying it was a
typo, not a missing anchor. Note this is a **declared exception** to the PLAN's own rule
that the pipeline *"ticks exactly one line here per item and touches nothing else in this
file except the eyeball queue"*.

**D8 — the ledger line records the items-8-15 auto-defer as RECOMMENDED NOT TO FIRE,
explicitly marked "Driver's call" rather than asserted as decided.**
*Reason:* the PLAN's literal wording is the driver's to apply or waive. Evidence in
`00_precondition.md` §3 — measured under DISPLAY, an item-8-shaped sidebar frame and its
child survive `xschem reload` fully, the raw survives 424 → 424, and snapshot state is
token-keyed Tcl in the interpreter, out of `xctx`'s reach. The PLAN's premise ("a reload
that destroys the context now also orphans a sidebar") is measured false.

**D9 — the split-out `readonly`-cleared-on-failed-load issue was NOT created.**
*Reason:* left to **item 16** per the PLAN. Note for whoever files it: the 0186 prompt's
"next free number is 0188" is **stale** — 0188-0194 and 0200-0211 are taken, so the next
free number is **0212** (verifier re-confirmed).

## 9. Verifier's problems that are not divergences

* **Coverage caveat.** X1–X7 drive only the pure proc with hand-written argument lists.
  The mapping from real Tk/`xschem` state to those arguments (argument order, where
  `tops0`/`tops1` are captured) is covered **only** by the DISPLAY arm — the verifier's
  arg-swap sabotage was invisible to the 57-check `--nogui` arm and failed 9 checks under
  DISPLAY. That arm is exactly the one currently timing out in `full_audit` on this box,
  so on a bad WSLg day this item's *integration* coverage is effectively unrun.
* **Receipt anchor drift (cosmetic).** `00_precondition.md` cites
  `wviewer::snapshot`/`wviewer::restore` at `wave_viewer.tcl:2165`/`:2212`; post-commit
  they are at `:2205`/`:2252` (pre-fix numbering, off by the +40 the fix added). Also
  *"the alert message | save.c:3814"* is the `fprintf` to `errfp`; the **modal** `alert_`
  behind the D6 hang is `save.c:3816`.
* **`PLAN.md` has no pre-image.** It entered git as a new 714-line file in this commit
  (previously untracked), so "I changed only the ledger line and corrected item 0's
  filename citation in place" is unverifiable by construction.
* **X9 is a source-shape assertion** on `info body ::wviewer::open`, not on behaviour.
  Declared as such in both the test comment and the receipt, and genuinely the only thing
  that can catch a reintroduced no-op guard (SB-C proves it fires) — but it will trip on
  any innocent re-wrap of that line, and the next person must check the comparison is
  really gone rather than just editing the regexp.

## 10. Anchors re-verified from source by the verifier

`scheduler.c:10036` reload branch (body `10039-10041`, unguarded) EXACT;
`save.c:3734/3810/3814/3827` EXACT; `xinit.c:1989-1991` silent no-free-slots return
before `(*window_count)++` EXACT, second site `:2006-2008`; `xschem.h:158`
`MAX_NEW_WINDOWS 20`; `xschem.tcl:13074` and `action_registry.tcl:183` are the only Tcl
`xschem reload` callers; next free issue number really is **0212**. The 9 new checks were
read for tautology, and `xschem get instances` / `get wires` confirmed to exist
(`scheduler.c:4214` / `:4734`).

## 11. If this had FAILED

Not applicable — verdict is DONE. (Section retained per the receipt schema.)

## 12. What was NOT verified

Carried forward verbatim in intent from `00_precondition.md` §4:

* The **C half of 0187 is untouched** — `create_new_window()` still returns silently on
  no free slots (`xinit.c:1990-1991`, second site `:2007`), rc 0, no Tcl error. Rule 2
  detects the consequence, not the cause; other callers of `new_schematic("create"…)`
  are still lied to.
* **X8 never runs in the audit's arm**, so the audit never exercises real slot
  exhaustion.
* **No false refusal was ever provoked inside the live `wviewer::open`** — only inside
  `ctx_verdict` (and, by the verifier, via unnamed sabotage #1, which showed the DISPLAY
  arm does catch it).
* **Every DISPLAY run was tabbed-mode only.** Rule 2 is argued sound in the non-tabbed
  model from source (verifier re-confirmed from `xinit.c`), not measured there.
* **Nothing about 0186 was fixed or attempted.**
