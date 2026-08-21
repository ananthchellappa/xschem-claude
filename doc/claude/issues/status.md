# What is still open — branch `fluid-editing`

> **Renumbering, 2026-08-08 — the old 0220–0238 block is now 0230–0248 (+10).**
> `open_pdk` had filed 0220–0238 while the branch it merges into was filing its
> own issues in 0220–0229, so the two blocks collided. Every file, every
> in-document reference, the two issue-named tests
> (`test_signal_short_nohier_0220` → `_0230`,
> `test_statusmsg_hold_0238` → `_0248`) and `doc/claude/evidence/0230/`
> → `0240/` were shifted together; 0219 and below are untouched.
> **Commit messages are not** — history is immutable. The shift applies to
> **`open_pdk`'s own commits**: those reachable from `99d6f1ed` but not from the
> merge base `74ef1aed` (`git log 99d6f1ed --not 74ef1aed`; ten of them name a
> number in the block). In one of those, "issue 0231" means what is now **0241**.
> **Date is not the discriminator, branch is** — `fluid-editing` was filing its
> own 0212–0225 on the same dates (`a98ab6fe`, 2026-08-07, "docs(issues):
> 0218-0224 …") and none of its numbers moved, so +10 on one of ours lands on a
> real but unrelated file. Our commits already mean the files on disk. See
> `doc/claude/issues/0226-renumbering-note-is-scoped-by-date-not-by-branch.md`.


> **Renumbering, 2026-08-19 — the old 0420–0432 block is now 0500–0512 (+80).**
> `annotate` (branched off `fluid-editing` at `577ef5bc`, 2026-08-16) filed its
> own 0420–0448 while this branch was filing 0420–0432, so the two blocks
> collided file-for-file across thirteen numbers. This branch moved; `annotate`
> did not. Every file, every in-document reference, and the two batch artefacts
> named after a number (`casemode_batch/receipts/16-issue-0426-…` → `16-issue-0506-…`,
> `casemode_batch/audit_issue0426_2026-08-18.txt` → `audit_issue0506_…`) were
> shifted together. **0419 and below are untouched**, and `open_pdk` (fully
> merged here at `cad186ea`) tops out at 0415, so nothing below the block moved.
> No issue-named test and no `doc/claude/evidence/` directory carried a number in
> the block, so none was renamed.
> **Commit messages are not** — history is immutable. Three commits on this
> branch name an old number: `b4a1c8ee` (0426 → **0506**), `af001a12` (0424, 0425
> → **0504**, **0505**), `d0eb835d` (0421 → **0501**).
> **Branch is the discriminator, not date.** `annotate`'s own 0420–0432 are
> different issues and did not move; a `+80` applied to one of its numbers lands
> on a real but unrelated file here.
> **0416–0419 stay where they are, and that is now safe.** `open_pdk` is
> **frozen** — ruled 2026-08-19, it will file nothing further, so the 0416+ gap it
> left can never be re-entered. 0416/0417 are byte-identical on `annotate` and
> must not be moved unilaterally in any case; 0418/0419 were left with them.

---

## Numbering rule for `fluid-editing` — **0500+ only** (ruled 2026-08-19)

**Every new issue filed on this branch takes the next free number at or above
0500.** Highest in use here is **0520**, so the next one is **0521**.

Why, in one line each:

- **`open_pdk` is frozen.** Its last issue is 0415 and there will be no more. It
  is already fully merged here at `cad186ea`, so nothing below 0416 can move.
- **`annotate` owns the 04xx tail.** It is live, branched at `577ef5bc`, and has
  filed through **0448**. It keeps counting upward from there; this branch does
  not follow it. Whoever works `annotate` should stay **below 0500** — that block
  belongs to `fluid-editing`.
- **The gap 0449–0499 is deliberate.** It is `annotate`'s headroom, not a pool to
  draw from. Do not fill it from this branch.
- **0418 and 0419 are the only 04xx numbers unique to this branch**, and they are
  historical. Do not treat them as “the count continues here”.

Deriving the next number, rather than trusting this line:

```sh
ls doc/claude/issues/ | grep -E '^0[0-9]{3}-' | cut -c1-4 | sort -n | tail -1
```

---

Snapshot taken **2026-07-30**, immediately after issue 0176 was closed
(`c8671825` + `d5968562`). This is a point-in-time answer to "what is still
open", not a live index — re-derive it rather than trusting it after any
substantial session. The reproducible way to regenerate the OPEN list:

```sh
for f in doc/claude/issues/*.md; do
  st=$(head -20 "$f" | grep -iE '^[-*]? *\**Status\**:' | head -1)
  case "$st" in *OPEN*) printf "%-58s %s\n" "$(basename "$f" .md)" \
    "$(echo "$st" | sed 's/.*[Ss]tatus\**:\** *//' | cut -c1-72)";; esac
done
```

(A plain `grep -i open` over the issue files is useless — it matches "open a
window", "the open question", "File > Open" and so on in prose. Match the
**status line**.)

---

## Immediate

- **`d5968562` is committed and UNPUSHED** — the 0176 closure doc. The standing
  rule on this branch is commit + raise the review gate, never push until the
  user says so.
- **`doc/claude/suggestions/next_session_prompt_0165.md` has a large uncommitted
  rewrite** (+220 / −129). It was already in the working tree when the 0176
  session started and was deliberately left alone. Someone should decide whether
  it is ready to commit.

## Next in line — session prompt written, work not started

| issue | one line |
|---|---|
| **0166** | resolved net ignores the containing cell template. Spawned by 0164 shipping incomplete. |
| **0180** | a NULL token truncates the Tcl list `xschem list_nets` returns. Mechanism measured, trigger UNPROVEN — read the status line literally. Prompt: `next_session_prompt_0180.md`. |

## Viewer / waveform thread

The 10-item viewer plan is complete and every item eyeballed; 0151, 0167, 0168,
0171, 0173, 0174, 0175, 0176, 0177, 0178 are all closed. What is left:

| issue | one line |
|---|---|
| **0172** | viewer buffer hijacked by pristine-untitled reuse. Pre-existing, filed 2026-07-29. The only OPEN issue left in this area. |

## Calculator / ASE-L results thread

The results batch closed 10 of 10 (`doc/claude/results_batch/LEDGER.md`) and the
Calculator batch is complete to PLAN phase 1 (`doc/claude/calculator_batch/LEDGER.md`).
Three issues are open across the seam between them:

| issue | one line |
|---|---|
| **0516** | a result selected through `Results ▸ Select…`'s `here` arm is invisible to the Calculator. **RULED 2026-08-20 by the user** (U13, the ASE-L session owns the result) — OPEN, awaiting implementation. Rework, not a patch. |
| **0517** | four ASE-L result sentences overflow the Calculator's status entry — 731–1855 px into 609 px of usable width, each cut mid-word exactly where its point is; the other 283 strings the widget can hold all fit. Three live, `browse_inert` latent. `no_result_msg` is U7's ruled text, so shortening it needs the user. |
| **0518** | the Calculator's Results Dir row goes stale when the ASE-L session or its waveform viewer closes. A published snapshot with four publishers, none of them teardown — against W05's "R705 binds: a live query, never a cached value" — and the only gesture that reveals the error (Evaluate) is the one that repairs it. |

The 0516 rework will WRITE new status sentences, so 0517's budget wants ruling
before it starts.

## Fluid / wiring backlog — parked deliberately

| issue | one line |
|---|---|
| **0088** | fluid reroute emits a redundant same-net loop. Reproduced deterministically. |
| **0101** | rotate-local stretch holes. Documented, pre-existing, **not** regressions of 0100. |
| **0121** | add-pin stubs push a spurious undo when every pin is skipped. Surfaced by Refactor B atom 25, kept out of it on purpose. |
| **0079** | follow-set wires render as a user selection. Design/UX — intentional at the mechanism level, wrong at the pixel level. |

`doc/claude/WIRING.md` carries two more marked **STILL OPEN** in its own text
(§11.9b's pure-ortho variant, and the min-copper item). Read WIRING.md before
touching anything that creates, moves, deletes or reroutes wires.

## Action-log coverage — umbrella 0071

| issue | one line |
|---|---|
| **0071** | umbrella / tracking issue for the 2026-07-02 coverage audit. |
| **0061** | non-File menubar items not logged. Largely fixed; remainder open. |
| **0062** | toolbar buttons not logged. Partially fixed. |
| **0069** | gesture drops logged as non-replayable markers. Paste/merge drop fixed 2026-07-14. |
| **0084** | action-replay test log missing a placed instance. |
| **0005** | replayable selection needs stable object referents. **Deferred by design** — captured so the constraint is not rediscovered. |
| **0008** | log graphical text property edits replayably. Design ratified, not built. |
| **0078** | `select_at` replay fidelity for split wires. Known limitation, explicit non-goal of its parent. |

## Filed 2026-08-20 — the command-channel design pass

Both came out of `doc/claude/suggestions/voice_control_natural_language_plan.md`
while measuring what it would take to drive xschem from outside. Neither is
parked: neither is scheduled. **0519 is the one to read first** — one of its
three defects needs no socket at all.

| issue | one line |
|---|---|
| **0519** | ⚠ the TCP command server kills the editor three ways and every one answers like success: a nested event loop destroys `puts` and wedges the channel permanently, a 4096-byte action-log line SIGABRTs, `xschem exit` returns `0` from behind a modal. **One of the three needs no socket** — the 4 KB overflow is in `log_action()` (`src/util.c:508`), so Shift+B, paste 4 KB, OK core-dumps a stock GUI xschem. Fix V2 is one line of C; V1 is 0004's mitigation (1), still unapplied. |
| **0520** | `xschem select` cannot read the handle `xschem object` hands out. `@<id>` is `atoi`'d to index **0** and the verb answers `1`; for `instance`/`pin` it answers `0` and leaves the **previous** selection armed, so the next `delete` takes the wrong object. The same bare `atoi` is in eight `setprop`/`getprop` arms and needs no sigil — `setprop wire OUTI lab ZAP` renames wire 0 under rc 0. Fix (a): route every arm through the selector block `object` already has. |

0519's V1 is the mitigation already listed under **0004** below; the two want
fixing together.

## Longer-parked infrastructure

| issue | one line |
|---|---|
| **0004** | ⚠ TCP command server has **no authentication**. Security gap documented, mitigation options listed, none chosen. |
| **0053** | descend-new-window return should navigate the window chain. Spec agreed 2026-06-27, ready to implement. |
| **0074** | read-only guard gaps + an uncaught header-text error. Found by a `/code-review xhigh` sweep of this branch. |
| **0052** | Library Manager open leaves the target window blank until interaction. |

---

## Not open, but worth knowing

- **Nothing is blocked.** Every item above is independently startable.
- **EYEBALL PENDING on 0165 and 0179** — both are committed, both are fully
  covered by tests, neither has been seen by a human.
  `doc/claude/suggestions/eyeball_0165_0179.md` has the steps, the fixture
  generator (`tests/eyeball/make_0165_0179_fixture.tcl`), a before/after recipe,
  and one open design question: the label-side warning highlights the offending
  instance on canvas and the new binding-side one does not.
- **0165 was CLOSED on 2026-07-30**: issue doc re-measured (7 wrong claims), then
  D1-D4 answered `warn / loose / no backend changes / resolved_net unchanged` and
  the ERC warning shipped. 15-leg test, RED-first against a true pre-fix binary,
  four sabotages. Output neutrality is measured, not argued — 920 netlists
  byte-identical.
- **0179 was found and FIXED on 2026-07-30** while measuring 0165's D3: the tEDAx
  netlister segfaulted on a symbol with `extra=` and no `extra_pinnumber=`.
  10-leg test, sabotage-verified in both directions. Zero committed designs hit
  it. The sweep it implied is now **DONE and empty**: all 48 `my_strtok_r()`
  call sites audited, 0179 was the only reachable one —
  `doc/claude/code_analysis/my_strtok_r_null_argument_audit.md`. That audit also
  looked at a suspected output-corruption defect in `xschem list_nets`
  (`node_hash.c:388-393`, a NULL token silently terminating a `my_mstrcat`
  vararg list). The mechanism is real and measured, but **five attempts failed to
  reach it** — `prepare_netlist_structs()` back-fills the lab of any pin that has
  a node, and a pin with no node never enters the loop. **Filed as 0180** with
  that status stated literally, since the fix is one line.
- The two suites that flake under WSLg and **must not be "fixed"** are recorded
  in their own notes: `test_ase_plot`'s gesture legs, `test_wave_trace_menu`'s
  TG9, and `test_wave_markers`' `MF1` (load- and timing-sensitive; a paired
  control on 2026-07-30 measured 0/8 on this branch while an unpaired soak had
  shown 6/30 — the difference was machine load, not the tree).
- **A committed netlist-diff harness finally exists**:
  `tests/netlist_diff/netlist_diff.sh <old-binary>`. It netlists every
  `xschem_library` design in all five backends with two binaries back to back and
  diffs them, with the three traps (autosave `~.sch` tops, the output dir
  embedded in `.include` lines, `git stash` on a clean tree) documented in its
  header. 0163, 0164 and 0165 each rebuilt this from scratch.
- The GUI-test control gate governs every DISPLAY suite run. Press
  **Allow 30m / Allow 2h** once instead of Proceed per suite, and never use a
  bare `for` loop — `tests/headless/run_suites.sh` or `gated_xschem.sh`.
