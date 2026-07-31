# What is still open — branch `fluid-editing`

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

## Viewer / waveform thread

The 10-item viewer plan is complete and every item eyeballed; 0151, 0167, 0168,
0171, 0173, 0174, 0175, 0176, 0177, 0178 are all closed. What is left:

| issue | one line |
|---|---|
| **0172** | viewer buffer hijacked by pristine-untitled reuse. Pre-existing, filed 2026-07-29. The only OPEN issue left in this area. |

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
- **0165 was CLOSED on 2026-07-30**: issue doc re-measured (7 wrong claims), then
  D1-D4 answered `warn / loose / no backend changes / resolved_net unchanged` and
  the ERC warning shipped. 15-leg test, RED-first against a true pre-fix binary,
  four sabotages. Output neutrality is measured, not argued — 920 netlists
  byte-identical.
- **0179 was found and FIXED on 2026-07-30** while measuring 0165's D3: the tEDAx
  netlister segfaulted on a symbol with `extra=` and no `extra_pinnumber=`.
  10-leg test, sabotage-verified in both directions. Zero committed designs hit
  it. It leaves one sweep behind — every `my_strtok_r()` call whose first
  argument can be NULL is the same bug, and that has NOT been done.
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
