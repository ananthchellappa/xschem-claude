# 04 — the cross-probe senders (Ctrl-K / Ctrl-Shift-X)

`PLAN.md` §3b item 4 · `DECISIONS.md` **B2b** · spec **extended, not replaced**: `specs/raw_case_mode.md` **§11** (§5/§10
cross-referenced in place). Base `63f3a1a2`, `fluid-editing`, nothing pushed. Covers the item round **and** a fix round of **seven
confirmed review findings**; two prescribed fixes were measurably wrong. Fuller narrative: §11 and the source.

## 1. Files changed

`src/hilight.c` **+223 −27** (gate, five senders, receiver parse) · `src/save.c` **+36 −3** (source 3 survives a descend, primed at
read time) · `src/xschem.h` **+17** (`Raw.sch_case_mode`) · `specs/raw_case_mode.md` **+293 −4** (§11) ·
`tests/headless/test_hilight_case_senders.tcl` **NEW, 723 lines, 30 checks**. Untracked, also committed: this receipt and
`audit_item04_{fixround,closer}_2026-08-16.txt`.

## 2. Decisions, and the evidence

**The real set — "four senders" was low.** Grepped: **nine `strtolower` on eight lines, two `strtoupper` on one more**, plus a
**receiver-side parse** nobody named — FIVE senders (the four named plus `create_plot_cmd()`'s two gaw arms) and
`hilight_graph_node()`, each folding **path and token both**. All eleven are gated. Every ruling below is in spec **§11**.

- **The gate, in rank order:** four sources → `Raw.case_sensitive` → global floor; `fold` folds as before, so a stock ngspice user
  sees no change (`CS70`, `CS82`, `CS83`). `send_*_to_bespice()` and the ngspice arm fold nothing, untouched.
- **`case_sensitive` ranks SECOND, not first.** Reviewers (3×) prescribed "fold only when the resolution says fold AND the lookup is
  not case-sensitive". Refuted by a committed fixture: `tr_fold.raw` read `-case distinguish` against a schematic drawn
  `In`/`MidNode` answers `casemode -all` = `fold schematic`, and only the FOLDED query resolves (`raw index {v(midnode)}` = **2**,
  `{v(MidNode)}` = **−1**). Bytes beat the flag; the flag beats the floor (`CS82`/`CS83` = `M1`/`M2`).
- **The floor is legitimate here though §10 forbids it**, stated not inherited: §10 bars it from a *file's* verdict; a cross-probe
  asks about a **run's** data, and for gaw it is the only answer there is (`CS66b`).
- **The hierarchical-current prefix follows the TOKEN.** Reviewer prescribed "`v.` when folding, `V.` otherwise"; re-measured on
  `ver_50` with the device renamed (fold/preserve/distinguish), deck `Vs` → `i(v.x1.vs)`/`i(V.X1.Vs)`/`i(V.X1.Vs)` but deck `vs` →
  `i(v.x1.vs)`/`i(v.X1.vs)`/`i(v.X1.vs)` — it is the device's own first character, folded with everything else. "`v.` stays
  lowercase in every mode" is **deleted** (`CS72b`/`CS75b`; the prescribed fix is `M4`).
- **The verdict survives a descend** (`Raw.sch_case_mode`): source 3 compares against whatever level `xctx` holds, so descending
  silenced it — inert one level down, the case the gate exists for. Recomputing below is not evidence, so it is stamped when
  computed for real, **replayed** in that hierarchy, **primed at `raw_read`/`table_read`**.
- **Resolve ONCE PER GESTURE, only where usable:** `hilight_net()` for `XSCHEM_GRAPH`/`GAW`, `create_plot_cmd()` for `GAW` after the
  socket check; `hilight_graph_node()` takes **no mode** (per node per REDRAW is the path item 3 forbade).
- **XYCE: the uppercase becomes a FALLBACK, not an assertion.** §5 refused a Xyce fold because no measured way to identify a Xyce
  *file* exists; here `sim_is_xyce` reports the **configured simulator command**, the right authority for a *sender*. Uppercase
  unless the resolution says `preserve`/`distinguish`; `fold`/`unknown` unchanged byte-for-byte (`CS67c`). Xyce stays
  **UNVERIFIED**.
- **The receiver parse: ANCHORED, CASE-BLIND, and it KEEPS its 4** (`CS81`; `CS77`/`CS78`) — item 2's rung-4 defects on this side.
  The 4-vs-5 is **ruled not a disagreement**: both drop `v.`, the reader keeps the `x` because it *rewrites* where this arm *skips*,
  and requiring it would push `i(v.foo)` into the `i(` arm, splitting off a bogus component `v`.
- **Scope fence, a known hole recorded in §11:** `send_current_to_gaw`'s Xyce arm *lowercases* where `create_plot_cmd`'s
  *uppercases*, and `send_net_to_gaw`'s Xyce branch equals its ngspice branch — pre-existing, not unified here.

## 3. Test, checks, RESULT

`tests/headless/test_hilight_case_senders.tcl` — **NEW**, `CS65`–`CS88`, **30 checks** (21 item round, 9 fix round, `CS72b`
rewritten); band grepped. Verbatim: **`RESULT: ALL PASS (30 checks)`**. **It NEEDS A DISPLAY**, hence not folded into
`test_raw_case_mode.tcl`: the `hilight_net()` senders are reachable only through the action registry, `xschem callback .drw`
**segfaults with no window**, and that suite would lose its true-headless property. gaw is faked (`setup_tcp_gaw` shadowed, `gaw_fd`
a plain file, **`vwait` renamed away**). Nothing prints `SKIP`.

**Master red-before-green:** `hilight.c`, `save.c`, `xschem.h` replaced by `git show HEAD:` copies and rebuilt → `RESULT: 22 FAILED
(7 passed)`; restored from byte-exact backups (`md5sum`-verified) → ALL PASS. **Six suites** via `GUI_GATE=1 run_suites.sh` on `:99`
→ **`RESULT: 6/6 runs passed`**: `hilight_case_senders` 30, `raw_case_mode` 277, `wave_hilight` 196, `node_token_split` 168,
`wave_viewer` 400, `backannotate_digital` 81.

**Closer audit** (`GUI_GATE=1 full_audit.sh`, `:99`, `audit_item04_closer_2026-08-16.txt`): `SUMMARY: 318 pass  15 fail  0
crash/timeout  0 skip  (total 333)`. Diffed by NAME and STATUS against `audit_item01_closer_2026-08-16.txt` the whole diff is **one
added row, `> PASS | test_hilight_case_senders`** — **no row moved either way**, none lost, the 15 reds identical by name. Count
rows with `grep -cE '^FAIL +\| +test_'` (**15**), never `grep -c '^FAIL'` (**21**: six are within-file detail). The contract is
about **movers**, there are none, so the baseline may roll here. **Slip disclosed:** the *fix round's* audit had a `make` run ~30
rows in; nothing moved, and this closer audit ran on a quiescent tree.

## 4. Sabotage — each on a copy of a byte-exact backup: rebuilt, run, restored, re-run green

| check | what was broken | red | green again |
|---|---|---|---|
| CS65 | **data**: both `.raw` fixtures moved out of the tree (aborts early, prints no `SKIP`) | yes | yes |
| CS66 | `MG` `create_plot_cmd` spice arm fully ungated | yes | yes |
| CS66b | `MC` the global floor never consulted | yes | yes |
| CS67 | `MD` `sender_folds_upper` always 1 (uppercase back to an assertion) | yes | yes |
| CS67b | `ME` `sender_folds_upper` = `!= PRESERVE` only (`distinguish` stops winning) | yes | yes |
| CS67c | `MF` `sender_folds_upper` always 0 (the Xyce uppercase deleted) | yes | yes |
| CS68 | `MI` `send_net_to_gaw` TOKEN ungated | yes | yes |
| CS69 | `MK` `send_current_to_gaw` TOKEN ungated | yes | yes |
| CS70 | `MC` the floor never consulted (fails on the floor element alone) | yes | yes |
| CS71 | **NOTHING — unsabotaged, NOT evidence**: the `.X1.` descend precondition, no item-4 code under it | — | — |
| CS72 | `MJ` `send_current_to_gaw` PATH ungated → `i(v.x1.Vs)`, the half-fix shape | yes | yes |
| CS72b | `M4` prefix `"v."`/`"V."` by mode — the reviewers' prescribed fix | yes | yes |
| CS73 | `MH` `send_net_to_gaw` PATH ungated → `v(x1.MidNode)` | yes | yes |
| CS74 | `ML` `send_net_to_graph` TOKEN ungated | yes | yes |
| CS75 | `MN` `send_current_to_graph` TOKEN ungated | yes | yes |
| CS75b | `MM` `send_current_to_graph` PATH ungated; also `M4` | yes | yes |
| CS76 | `MP` the parse advance 4 → 5 (adopting the reader's five) | yes | yes |
| CS77 | `MQ` the parse back to six case-ENUMERATED arms → `.V.X1.` | yes | yes |
| CS78 | `MQ` same, mirror spelling `I(v.` the enumeration never listed | yes | yes |
| CS79 | `MR` the parse's `i(` arm deleted | yes | yes |
| CS80 | `MS` the parse's `v(` arm deleted | yes | yes |
| CS81 | `MT` the parse back to UNANCHORED (garbage token reproduced verbatim) | yes | yes |
| CS82 | `M1` `Raw.case_sensitive` never consulted — the blocker finding | yes | yes |
| CS83 | `M2` `case_sensitive` ranked ABOVE the four sources — the prescribed rule | yes | yes |
| CS84 | `M5` the descend replay removed (source 3 alone, no verb typed) | yes | yes |
| CS84b | `M6` the read-time prime removed (read-then-descend, no gesture between) | yes | yes |
| CS85 | `M7` the two `case WIRE:` sends hard-coded to fold | yes | yes |
| CS86 | `M7` same, one level down — the wire path half | yes | yes |
| CS87 | `M8` `create_plot_cmd` spice PATH ungated | yes | yes |
| CS88 | `M9` `create_plot_cmd` **Xyce** PATH ungated | yes | yes |

**`M9` SURVIVED green at 30/30** — `strtoupper("X1:")` is a no-op, so an uppercasing arm's path half is invisible without a
lowercase character present; the fixture gained a sub-instance `Xa1` and `M9` then reddens `CS88` alone (carry forward: an
UPPERCASING transform needs a lowercase subject). `MA`/`MB` (`sender_folds_lower` pinned 1 / 0) redden 17 / 15. **Finding 7 has no
check and cannot have one** — no output; instrumented, *ungated* all of Ngspice/Bespice/Gaw resolve the mode, *gated* only Gaw does.

## 5. What was NOT verified

- **Reviewers: seven findings, all confirmed, all fixed.** The only raised-but-**not**-confirmed items (two lenses' "the mode is
  resolved for viewers that ignore it") duplicate finding 7, fixed anyway.
- **Reviewer not-proven, carried.** No reviewer ran `full_audit.sh`; the closer's run stands in. Whether the descend fix belongs
  here or in item 3's `schname` gate is **not settled**. **`xctx->raw` may be the wrong database when several are loaded** — a
  graph entry can plot from another via a `%rawfile` cross-DB entry (D1); not constructed. Whether the non-Xyce spice arms should
  *uppercase* under `RAW_CASE_UPPER` is undecided; no frozen oracle pins the OLD spelling anywhere in `tests/`.
- **No gaw and no Xyce were involved**; every capture is a faked socket. **`RAW_CASE_UPPER` never came from a real uppercasing
  simulator** and no check drives it end to end. **Source 2 (`Option:` header) never drives a sender.** **`send_*_to_bespice()` is
  untouched and undriven.** **No valgrind** (nothing is allocated).
- **The read-time prime costs one schematic walk per `raw read`, NOT measured** — reasoned from item 3's 147 ms worst case being off
  any hot path; `table_read()` gets the same call. If item 5 or 13 sees raw-read latency regress, look here.
- **No eyeball owed.** The payload is the spelling of a query string, asserted byte for byte; `owed.sh` untouched.
