# 14 — netlister fold-collision warning + `model_name()` key

`PLAN.md` §3b item 14 · authority `DECISIONS.md` **C2** · spec **extended in place**, `specs/raw_case_mode.md` **§14** (+398, additive). Base
`b756a83e`, `fluid-editing`, nothing pushed; long form (ten reviewer findings, measurement transcripts, 39-row mutation log) in
`14-netlister-collision-warning-annex.md`. **Verdict `[E]`:** the fix round gave this warning a **canvas cue** and a status-bar sentence, and no check
can approve a colour or a sentence.

## 1. Files changed

`src/node_hash.c` **+130** (`netlist_case_collision_check()`) · `src/save.c` **+28** (`netlist_case_mode()`) · `src/xschem.h` **+11** ·
`src/spice_netlist.c` **+43 −7** (per-level call site + `model_name()`'s `keep_case`) · `src/spectre_netlist.c` **+17 −7** (part (b)'s second site) ·
`src/xschem.tcl` **+90** (`sim_case_collision_lines`, `relay_sim_case_collisions`, one line in `proc simulate`) · `specs/raw_case_mode.md` **+398** (§14) · `tests/headless/test_netlist_case_collision.tcl` **NEW, 834 lines, 40 checks** · this receipt + annex. Nothing else touched; `relaycheck.tcl` and `tr_MODE.raw` at the repo root are **pre-existing droppings, not this item's**, and stay unstaged.

## 2. Decisions, and the evidence

- **The gate is C2's direction; the option as written was backwards.** `distinguish` alone **agrees** with the schematic (`node_hash.c:82` compares with `strcmp`, so `Out`/`OUT` really are two nets), so it alone has nothing to report. §14 *RULING — fire only on disagreement*; `CS117`/`CS118`, `M1`/`M2`.
- **Warn, never error** (C2: we cannot see nets arriving via an `.include`d PDK file), so the count is not OR-ed into `err`. The first pass cited
  `CS121`/`CS121b` and **they were not evidence** — an `err |=` left them green while flipping the netlist's exit code 0→10. §14's citation is struck;
  the ruling's check is `CS143`.
- **No profile means `fold`, and the global floor is legitimate *here* — stated, not inherited:** §10 bars the floor from a *file's* verdict, a question about a **run** may use it (item 4's precedent). `netlist_case_mode()` ignores `xctx->raw` by design. `CS120`, `M4`.
- **Called from `spice_netlist()`, not `traverse_node_hash()`:** the latter is also the interactive `show_unconnected_pins()` pass and serves all five backends; the former is per-level, so a subcircuit-body collision is caught — the case upstream misses under `fold`. `CS122`/`CS124`. Now measured: a `spice_netlist=true` child **with `split_files`** gets it inside a spectre/Verilog run (`CS146`); §14's `spice_primitive` trigger was false, corrected.
- **Part (b) narrows an existing fold, it adds none.** The fold is *correct* under `fold`/`preserve`, the card **keyword** stays case-blind in every mode,
  and only `distinguish` splits `NAND2` from `nand2`. The trap was the **parse**, not the hash — the `sscanf` literals matched only because the fold had
  just run, so they became a length skip. `CS125`–`CS145b`; `M10`–`M14`.
- **The relay lives in Tcl because the run log does, and it is ALWAYS ON.** ngspice emits at **parse** time, so a deck cannot capture it from `.control`, and measured the line is on **stderr only**. Ungated: it names the outcome itself, sees `.include`d cards we cannot, and carries the mode the run *actually* had, which a `.spiceinit` can change. §14 *RULING — always on*; `CS136`/`CS138`/`CS148`.
- **Dedup on the order-normalised quoted pair — with a measured refinement that partly refutes C2's mechanic 2:** ngspice prefixes the **instance path**,
  so three instantiations are three *different* pairs and all survive; the dedup earns its keep against one line arriving twice on our two-stream scan.
  The key is anchored on `'…' and '…' differ only in case`, so a mis-parse fails **safe**. `CS135`/`CS147`.
- **Two channels, no third:** `statusmsg(str, 2)` for the netlist-time detail (where all fifteen `netlist.c` warnings go), `ciw_echo … note` for the
  relay. **Fix-round ruling:** that window opens only when the pref is `always` or `err != 0`, default `onerror`, so a warning correctly leaving
  `err == 0` reached nobody. It now **paints both spellings** into the highlight table (`!netlist_count`, one colour per pair) like its five siblings,
  plus a status-bar summary of count, cell and mode (`CS141`/`CS142`); and the **diagnostic phrase comes first**, because names-first a 973-char pair
  emitted 1990 chars carrying neither it nor `(casemode=…)` — `my_snprintf` here drops a whole conversion (`CS144`).
- **Ruled, then deliberately left alone:** `examples/test_bus_tap.sch` really carries `VCC`/`vcc` + `VSS`/`vss`, so the check fires on a shipped example — and the warning is **true** there. §14's premise "no committed fixture collides" is corrected; that library file is not this item's to edit, and issue `0420` stays out of scope.

## 3. Test, checks, RESULT

`tests/headless/test_netlist_case_collision.tcl` — **NEW**, `CS115`–`CS149`, band grepped (`CS114` was the highest in use). No simulator and no
display: every relayed line is text copied byte for byte from hand measurements on `build-ver_50`. Verbatim, in the arm `full_audit.sh` uses:
**`RESULT: ALL PASS (40 checks)`**. `--nogui` gives `RESULT: ALL PASS (39 checks)` — `CS149` needs Tk to read `.ciw.l.t` back and self-skips with a
`NOTE:` line carrying none of the substrings `full_audit.sh` scores a whole file on (its audit row is `PASS`, not `SKIP`). **Master red-before-green:**
the six touched sources replaced by `git show HEAD:` copies and rebuilt → `RESULT: 30 FAILED (0 passed)` at the first pass's 30 checks.
**Suites:** `GUI_GATE=1 run_suites.sh`, the 16-file netlisting + casemode set on `:99` → `16/16 runs passed`, counts unchanged; the `tests/`
regression cases were **not** used as a signal, having no committed gold (they can only say `NOGOLD`). **Audit:** `GUI_GATE=1 full_audit.sh` on `:99`
→ `322 pass 15 fail 0 crash/timeout 0 skip (total 337)`, saved as `casemode_batch/audit_item14_closer_2026-08-17.txt` and diffed by name and status
against `audit_item05b_closer_2026-08-17.txt` (321/15/0/0 of 336): **0 moved in either direction, 1 added** (`test_netlist_case_collision`
`(absent) -> PASS`), 0 vanished, the 15 `FAIL` names identical. Its `TREE: 1 appeared` line is this receipt, written while the audit ran; the empty-diff
contract holds even though the fix adds a canvas side effect to the netlister.

## 4. Sabotage — one row per new check

| check | what was broken | red | green |
|---|---|---|---|
| CS115 | the sweep truncated to the top level (`V28`) | yes | yes |
| CS116 | the message no longer says `in cell <name>` (`V34`) | yes | yes |
| CS116b | the message no longer says `(casemode=…)` (`V35`) | yes | yes |
| CS117 | gated on `fold` only — silent under `preserve` too (`M2`) | yes | yes |
| CS118 | the `distinguish` gate deleted — **the backwards option** (`M1`) | yes | yes |
| CS119 | the fold key truncated to one byte — false positives (`V7`) | yes | yes |
| CS120 | the floor stops validating, so a bad request is no longer `fold` (`M4`) | yes | yes |
| CS121 | the call site removed (`V9`) — **partial, see below** | yes | yes |
| CS121b | the call site removed (`V9`); its ruling's check is `CS143` | yes | yes |
| CS122 | `in cell` dropped (`V34`); top-level-only sweep (`V28`) | yes | yes |
| CS122b | the same two — `V28` removes the child level's row entirely | yes | yes |
| CS123 | only the first colliding pair per level reported (`M5`, v2) | yes | yes |
| CS124 | the check moved **into** `traverse_node_hash()` — the rejected design (`M8`) | yes | yes |
| CS125 | spice model key: `keep_case` hardwired 1 — never folds (`M12`) | yes | yes |
| CS126 | spice model key: `keep_case` hardwired 1 (`M12`) | yes | yes |
| CS127 | spice model key: `keep_case` hardwired 0 — today's blanket fold (`M10`) | yes | yes |
| CS128 | the `.model` `sscanf` literal restored against a verbatim source (`M13`) | yes | yes |
| CS129 | spectre model key: `keep_case` hardwired 1 (`M11`) | yes | yes |
| CS130 | spectre model key: `keep_case` hardwired 0 (`M11`) | yes | yes |
| CS131 | the `.subckt` literal restored — the whole card becomes the key (`M13`) | yes | yes |
| CS131b | the keyword searched on the verbatim string, not a folded copy (`M14`) | yes | yes |
| CS132 | the relay paraphrases instead of relaying verbatim (`M19`) | yes | yes |
| CS133 | the dedup dropped altogether (`V16`) | yes | yes |
| CS134 | the pair key no longer order-normalised (`V20`) | yes | yes |
| CS135 | the instance path stripped from the pair key (`M21`) | yes | yes |
| CS136 | the relay **gated by mode** — the `distinguish` line suppressed (`M17`) | yes | yes |
| CS137 | the `differ only in case` filter dropped (`M19`) | yes | yes |
| CS138 | only stdout scanned, and the line is stderr-only (`M18`) | yes | yes |
| CS139 | the dedup dropped, so a stream-merging command relays twice (`V16`) | yes | yes |
| CS140 | `proc simulate` no longer arms the relay (`M20`) | yes | yes |
| CS141 | the status-bar summary line deleted (`V31`) | yes | yes |
| CS142 | the canvas cue deleted (`V30`); only the first spelling painted (`V32`) | yes | yes |
| CS143 | **the warning turned into an error** (`err \|=` at the call site, `V26`) | yes | yes |
| CS144 | the names put back ahead of the diagnostic (`V33`) | yes | yes |
| CS145 | spectre `model` branch: the old `sscanf` literal (`V17`) | yes | yes |
| CS145b | spectre `subckt` branch: the old `sscanf` literal (`V36`) | yes | yes |
| CS146 | the cross-backend path refused unless the netlist type is spice (`V42`) | yes | yes |
| CS147 | the dedup key back to the unanchored first-apostrophe regexp (`V38`) | yes | yes |
| CS148 | a mode gate on `relay_sim_case_collisions`, the production entry (`V39`) | yes | yes |
| CS149 | the relay's `ciw_echo` emit deleted (`V40`); the `note` tag dropped (`V41`) | yes | yes |

Every mutation went onto a byte-exact backup, was rebuilt, run, restored (`md5sum`-verified) and re-run green; red lists were read off the run, never
predicted. **The closer re-drove the two that had survived an earlier pass, `V26` and `V17`** (one reviewer's sandbox had served inconsistent bytes):
each reddens its own check **alone** — `CS143` got `{1 2}` for `{0 2}`, `CS145` `{1 2}` for `{1 1}` — the six sources came back `md5sum -c` clean and the
suite returned to `ALL PASS (40 checks)`. **Not evidence, said plainly:** `CS121`'s *"both spellings reach the deck verbatim"* half has **no reachable
sabotage**, since nothing this item adds touches the strings the deck is written from (`V27`: applied, compiled, deck unchanged, 40/40 green) — it is a
regression guard, its `ncoll` half being the covered one. `M5` v1 also survived and was rewritten; the `strcmp(hit->value, entry->token)` guard is
**provably inert** and owes no check.

## 5. What was NOT verified

- **`[E]` — TWO `look` debts stand** (`owed.sh`: 4 suite / 11 look), the fix round having made this *more* pixel-shaped. Look at (1) are the right two
  nets highlighted after a netlist and does the colour read as a warning, (2) does the new status-bar sentence read sensibly and fit, (3) the relayed
  line's `note` colour, (4) the ERC-window sentence. Suites green — please look.
- **No simulator runs inside the suite.** The fixture lines, the "stderr only" finding and the `X1.Mid`/`X2.Mid`/`X3.Mid` refinement were hand-measured
  on `build-ver_50` (2026-08-15 23:54); a reviewer marked all three **not-proven** — plumbing read and sound, but no ngspice run.
- **Reviewer not-proven items standing:** the earlier stages' restore-integrity claims (§4 has the closer's re-drive of the two that mattered); the
  fold-path byte-identity argument, which a reviewer proved empirically instead (**294 decks byte-identical** at `fold`; under `distinguish` 2 of 294
  change, purely as a line **reordering**); and the per-level `Str_hashtable` cost, arithmetic in §14 (their valgrind found zero new-function frames).
- **The `.include`d-PDK class both halves are blind to has no fixture** — one means shipping a PDK. No Xyce, no gaw, no ASE-L path; VHDL/Verilog/tEDAx untouched but for `CS146`'s disclosed path.
- **A ruling a reviewer disagreed with, recorded not hidden:** C2's anti-spam goal for the relay is *not* met — 40 instantiations relay 40 CIW lines,
  since the instance-path prefix makes them 40 different pairs (`CS135` asserts they survive); collapsing them is a new item. The relay is also a new
  per-simulation `append`+`split` over the run log (15 ms at 1 MB, 654 ms at 50 MB), which a `print`-loop deck pays for.
