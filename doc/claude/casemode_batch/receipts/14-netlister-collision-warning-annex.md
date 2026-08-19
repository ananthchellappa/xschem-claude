# 14 — the netlister side: fold-collision warning + the model dedup key

`PLAN.md` §3b item 14 · authority `DECISIONS.md` **C2** · spec **extended, not replaced**: `specs/raw_case_mode.md`
**§14**. Base `b756a83e`, `fluid-editing`, nothing pushed, tree left dirty for the verifier. Three deliverables:
(a) a netlist-time warning firing only where **xschem and the simulator disagree about how many nets the design has**,
(a′) a relay of ngspice's own line off the run log, (b) the model dedup key gated on `distinguish` at **both** sites.

## 1. Files changed

`src/node_hash.c` **+75** (`netlist_case_collision_check()`) · `src/save.c` **+28** (`netlist_case_mode()`) ·
`src/xschem.h` **+11** · `src/spice_netlist.c` **+41 −9** (per-level call + `model_name()`'s gate) ·
`src/spectre_netlist.c` **+17 −7** · `src/xschem.tcl` **+81** (relay + one line in `proc simulate`) ·
`specs/raw_case_mode.md` **+255** (§14) · `tests/headless/test_netlist_case_collision.tcl` **NEW, 30 checks** · this
receipt (untracked).

## 2. Decisions, and the evidence

- **The gate direction is C2's, not the option's.** `distinguish` AGREES with the schematic (`node_hash.c:82` compares
  with `strcmp`, so `Out`/`OUT` really are two nets here), so it is the one mode with nothing to report. `CS118` is that
  correction and carries the fold count in the same assertion; sabotage `M1` (gate deleted) reddens it alone.
- **Warn, never error** (C2: we cannot see `.include`d PDK nets). The count is deliberately not OR-ed into `err`.
  **CORRECTED BY THE FIX ROUND:** this line used to cite `CS121`/`CS121b` as the evidence and they are not — they assert
  the deck's contents and the warning count, and `err |= netlist_case_collision_check();` leaves both green while making
  the netlist exit 10. The ruling's check is now **`CS143`**, on the netlist's own returned error status (§6, F3).
- **`netlist_case_mode()` = the REQUESTED mode; `xctx->raw` is not consulted.** A netlist asks about a run that has not
  happened; a loaded raw describes one that has, possibly of another design — so item 4's "bytes beat the flag" ladder
  does **not** apply, there are no relevant bytes. The floor asserting `fold` without evidence is stated, not inherited:
  §10 bars it from a *file's* verdict, a *run* may use it (item 4 recorded the same split). `CS120` + `M4`.
- **Called from `spice_netlist()`, not `traverse_node_hash()`** — the latter is also the interactive
  `show_unconnected_pins()` pass (`CS124`, `M8`), and it serves all five backends while the mode we can consult is
  ngspice's (Verilog is case-sensitive, i.e. C2's silent row). `spice_netlist()` is the **per-level** pass, so a
  subcircuit-body collision is reported at its own level (`CS122`, `M9`). Disclosed in §14: a SPICE block inside a
  VHDL/Verilog/spectre netlist does get the check, because those cards really are SPICE. **CORRECTED BY THE FIX ROUND:**
  the trigger named here and in §14 was `spice_primitive`, a token that appears in **none** of the three drivers; the real
  gate is `spice_netlist=true` **AND** `split_files` (`spectre_netlist.c:395`, `vhdl_netlist.c:446`,
  `verilog_netlist.c:356`), now measured both ways and checked (`CS146`, §6 F6).
- **MEASURED on `build-ver_50` (stamp 2026-08-15 23:54), and it earns both halves their place:** upstream's warning for
  a pair confined to a `.subckt` body under `fold` is **0 lines** (3 under preserve/distinguish, one per instantiation)
  — exactly what our per-level pass catches; and it is on **STDERR only**, so a stdout-only relay finds nothing. Also
  measured: once per **parse**, not per analysis (`.op` card + `.control run` → 1 line).
- **The relay is ALWAYS ON, unlike our own check.** It is the simulator's own statement, it names the outcome ("one
  node"/"two nodes"), it sees `.include`d cards we cannot, and it carries `(casemode=…)` — the mode the run *actually*
  had, which a `.spiceinit` can differ from (A2). `CS136` + `M17`.
- **The relay is Tcl because the run log is Tcl.** Parse-time emission means a deck cannot capture it (C2); the log is
  `execute(data,last)` + `execute(error,last)` — Tcl hands stderr back in the pipe-`close` error text (probed:
  `catch {close $f} err` returns it even on exit 0). Hooked on `proc simulate`'s existing `execute(callback)`, which
  fires after both are set. **ASE-L's `run_cmd` is items 6–12's** and should call `sim_case_collision_lines`.
- **MEASURED REFINEMENT that partly refutes C2's mechanic 2.** "It repeats per instantiation, so dedupe on the quoted
  pair" — measured, ngspice prefixes the instance path, so three instantiations give `'X1.Mid'`/`'X2.Mid'`/`'X3.Mid'`:
  three *different* pairs, all correctly surviving (`CS135`; `M21` strips the path and loses two real collisions). What
  the dedup buys is the same line arriving twice, which our own two-stream scan produces when a command merges the
  streams (`CS139`).
- **Channels: `statusmsg` netlist-side, `ciw_echo … note` for the relay. No third channel.** From the
  neighbours: every netlist warning (`node_hash.c`'s undriven/open/shorted plus **fifteen** `statusmsg(str,2)` sites in
  `netlist.c` — grepped; the brief names six) appends to `xctx->infowindow_text`, which the netlister clears per run. The
  relay cannot use it (that text belongs to the netlist pass, a run finishes minutes later) and the house rule for a
  Tcl-side message is `ciw_echo`. **CORRECTED BY THE FIX ROUND:** the claim that the netlister *pops that window up* is
  measurably false when `err == 0`, which is this item's own design — so the netlist-time half now also paints the two
  nets and says one status-bar summary line (§6, F1). Still two message channels, not three.
- **Part (b) is a NARROWING, not a new fold.** The fold is correct under `fold`/`preserve` and stays; only `distinguish`
  splits `NAND2` from `nand2`. **The card KEYWORD stays case-blind in every mode** (`CS128`) — still located on a folded
  copy; only the identity follows the mode.
- **The trap in (b) was the PARSE, not the hash.** The `sscanf` formats carried the literals `.subckt `/`.model `, which
  matched only because the fold had just run; against a verbatim string a `.SUBCKT` card fails the literal, `sscanf`
  returns 0 and the **whole card** becomes the key. The keyword is now skipped by **length** (`strtolower()` is byte-wise
  and length-preserving). `CS131`/`CS131b`; `M13` restores the literal, `M14` searches the verbatim string.

## 3. Test, checks, RESULT

`tests/headless/test_netlist_case_collision.tcl` — **NEW**, `CS115`–`CS140`, **30 checks**. Band **grepped**, not
quoted: `CS114` (`test_ngspice_data_view.tcl`) was the highest id in use. True headless, no simulator, no display; every
relayed line copied byte for byte from §2's measurements. Verbatim: **`RESULT: ALL PASS (30 checks)`**.

**Master red-before-green:** all six touched files replaced by `git show HEAD:` copies and rebuilt →
**`RESULT: 30 FAILED (0 passed)`** — not one check passes without the item. The file's first cut had ten legs that stayed
green there (the "silent"/"unchanged" ones); each was rewritten to carry its positive evidence in the same assertion
(`CS118 CS119 CS121 CS121b CS124 CS125 CS126 CS128 CS129 CS131b`), and the relay legs abort-proofed so a missing proc
reddens instead of killing the file with no RESULT line.

**Suites — 33 runs**, every netlisting-touching headless file (`grep -l "xschem netlist\|netlist_type" test_*.tcl`) plus
the five casemode ones, via `GUI_GATE=1 tests/headless/run_suites.sh` on `:99`: **`RESULT: 29/32 runs passed
(1 skipped)`**. Counts unchanged: `raw_case_mode` 277, `ngspice_data_view` 139, `wave_casemode` 134,
`expandlabel_zero_neg_mult_0182` 92, `backannotate_digital` 81, `empty_value_swallows_token_0183` 69,
`hash_label_crash_0156` 23, `hash_extra_node_warn_0165` 15, `signal_short_nohier_0230` 11 — all `ALL PASS`.
**Four non-PASS rows, all artefacts of MY invocation, all `PASS` in the baseline audit, each re-driven under the arm
`full_audit.sh` uses:** `test_netlist_log` SKIP (wants `--logdir`), `test_nogui` NORESULT (banner `NOGUI_TEST_PASS`,
which run_suites does not score), `test_hi_descend` NORESULT (own banner), `test_placement_preview_doors` TIMEOUT (it is
in `full_audit.sh`'s `nogui_tests`; `run_suites.sh --nogui` → `ALL PASS (206 checks)`).

**No `full_audit.sh` run by this stage** — the diff against `audit_item05b_closer_2026-08-17.txt` (321/15/0/0 of 336) is
the closer's. Expected: **one added row** (`test_netlist_case_collision PASS`), **zero movers**. **The fix round ran it
(§6d) and that is exactly what it says.**

## 4. Sabotage — each on a copy of a byte-exact backup: rebuilt, run, restored (`md5sum`-verified), re-run green

| id | what was broken | went red |
|---|---|---|
| M1 | the `distinguish` gate deleted — warns in every mode (**the backwards option**) | CS118 |
| M2 | gated on `fold` only — silent under `preserve` too | CS117 |
| M3 | the whole pass a no-op | CS115 CS116 CS116b CS117 CS118 CS119 CS120 CS121 CS121b CS122 CS122b CS123 CS124 |
| M4 | the floor stops validating — an unparseable request is no longer `fold` | CS120 |
| M5 | only the FIRST colliding pair per level is reported | CS123 |
| M6 | the message no longer names the cell | CS116 CS122 CS122b |
| M7 | the message no longer names the mode | CS116b CS117 CS120 |
| M8 | the check moved INTO `traverse_node_hash()` — **the rejected design** | CS124 |
| M9 | the check runs at top level only | CS115 CS117 CS118 CS119 CS120 CS121 CS121b CS122 CS122b CS124 |
| M10 | spice model key: `keep_case` hardwired 0 — today's unconditional fold | CS125 CS126 CS127 CS128 CS131 CS131b |
| M11 | spectre model key: `keep_case` hardwired 0 | CS129 CS130 |
| M12 | spice model key: `keep_case` hardwired 1 — never folds | CS125 CS126 CS131b |
| M13 | the `sscanf` literal restored against a verbatim source | CS128 CS131 CS131b |
| M14 | the card keyword searched on the verbatim string, not a folded copy | CS128 CS131 CS131b |
| M15 | dedup key is the whole line, not the quoted pair | CS134 |
| M16 | the dedup dropped altogether | CS133 CS134 CS139 |
| M17 | the relay GATED by mode — the `distinguish` line suppressed | CS136 |
| M18 | only stdout scanned | CS138 |
| M19 | the `differ only in case` filter dropped | CS132 CS137 CS138 |
| M20 | `proc simulate` no longer arms the relay | CS140 |
| M21 | dedup on the NET pair with the instance path stripped | CS135 |

**Every one of the 30 checks appears in at least one row**; every red list was read off the run, not predicted. Two
disclosures about the drive: **M5's first version SURVIVED green** (30/30) — it `break`ed out of one hash *bucket* and
the three spellings live in three buckets, so it never implemented "only the first"; it now also sets `i = HASHSIZE` and
reddens `CS123` alone. And **M15–M21 were re-driven**: their first pass ran with no rebuild right after M14's build, so
the binary still carried M14 and each showed `CS128 CS131 CS131b` on top of its own target — exactly the stale-binary
trap item 5b's verifier recorded. The rows above are the re-driven ones.

## 5. What was NOT verified

- No simulator runs inside the suite: the relay is driven against captured text, measured by hand (§2). ~~The **CIW
  output itself is never asserted** — `ciw_echo` is silent with no window~~ — **struck by the fix round**: the CIW can be
  created and read headlessly under the `--pipe` arm, and `CS149` now asserts both the text and the `note` tag. What is
  still unseen is the tag's **colour** and whether the sentences read well.
- **ONE `look` DEBT RECORDED** (`owed.sh add look`; ledger now 4 suite / 10 look): read the two new user-facing lines in
  situ — our warning in the netlist ERC window, and the relayed line in the CIW. The **payload** here is a detector and
  a dedup key, both asserted byte-for-byte headlessly, so the verdict is not gated on pixels; but "does the sentence
  read sensibly" is a human's call and recording it costs nothing. Suites green, please look.
- The **`.include`d-PDK class both halves are blind to has no fixture** — one means shipping a PDK. **No Xyce, no gaw,
  no ASE-L path**; VHDL/Verilog/tEDAx deliberately untouched.
- **No valgrind.** The new pass allocates one `Str_hashtable` + one key buffer per level and frees both on every exit
  path (no early return between `str_hash_init` and `str_hash_free`). Its cost — a 253 KB `calloc`/`free` per netlisted
  cell — is **reasoned, not measured**; §14 carries the arithmetic.

---

## 6. FIX ROUND — ten confirmed findings, all ten addressed

Three reviewer lenses raised ten findings; **all ten were real** and none was argued away. Two were **major** and both
were about evidence rather than behaviour, which is the shape of this round: the detector was right, the channel it spoke
on and the checks behind two of its rulings were not. Files touched by the fix: `src/node_hash.c`, `src/xschem.tcl`,
`specs/raw_case_mode.md` §14, `tests/headless/test_netlist_case_collision.tcl` (+9 checks), this receipt. **No change to
`save.c`, `xschem.h`, `spice_netlist.c` or `spectre_netlist.c`** — parts (a)'s gate, (b)'s narrowing and the mode seam
survived review untouched.

| # | finding | what changed |
|---|---|---|
| **F1** | **major.** The netlist-time warning had **no channel the shipped default shows**: `.infotext` is deiconified only when the pref is `always` or `err != 0`, the default is `onerror`, and this warning correctly leaves `err == 0`. Measured: colliding design + `xschem netlist -erc` → `wm state .infotext` = *withdrawn*; a real ERC error, same command → *normal*. Unlike all five siblings it also set **no canvas cue** | both spellings now go into the highlight table (`bus_hilight_hash_lookup`, `!netlist_count`, one colour per pair — sibling-exact), **and** one summary line goes to the status bar (`statusmsg(str, 1)`, seam `xschem get statusmsg`). `CS141` + `CS142`; spec §14 gained a `CORRECTION` block and the false sentence "it is the window the netlister pops up" is gone |
| **F2** | minor. Both names sat **ahead** of the diagnostic, so a long name truncated `differ only in case` and `(casemode=…)` away entirely | diagnostic front-loaded. Measured on two 973-char names: old order → 1990 chars, phrase **absent**; new order → 1101 chars, phrase and mode present, only the second NAME lost. `CS144` |
| **F3 / F7** | **major** (raised twice). "Warn, **never** error" — one of the two rulings this item exists for — was **guarded by nothing**, while spec §14 and §2 above cited `CS121`/`CS121b` as its evidence. `err \|= netlist_case_collision_check();` left 30/30 green and makes the netlist exit 10 | `CS143` asserts the `xschem netlist` branch's own returned error status is **0** while `ncoll == 2`. The false citation is struck in both documents. Sabotage `V26`, which SURVIVED the first pass, now reddens `CS143` **alone** |
| **F4** | minor. The relay's dedup key `'([^']*)'[^']*'([^']*)'` mis-parsed any line with an apostrophe **before** the pair, and mis-parsed to the **same** key every time — so two different collisions collapsed to one and one was **dropped** | key anchored on `'…' and '…' differ only in case`; a mis-parse now falls back to the whole line, i.e. fails **safe** (no dedup, never over-dedup). `CS147` |
| **F5** | minor. The empty-audit premise "no committed fixture collides" is **false**: `examples/test_bus_tap.sch` carries `VCC`/`vcc` + `VSS`/`vss`, so the check fires on it and on `0_examples_top.sch` (6 lines over 3 files in a 147-schematic sweep) | premise corrected in the spec, with the real reason stated: **no headless test asserts that example's ERC transcript**. The two stray labels are left alone deliberately — the warning there is TRUE, and the shipped example is the check's own first customer |
| **F6** | minor. Spec §14 named `spice_primitive` as the cross-backend trigger; that token is in **none** of the three drivers | corrected to `spice_netlist=true` **AND** `split_files`, with the three gating line numbers, plus what the user then reads (an ngspice `casemode=` sentence inside a spectre/Verilog run). Measured both ways and checked: `CS146` |
| **F8** | **major.** The spectre half of (b) — the `sscanf` length skip — had **zero** coverage: `nc_spectre`'s cards differ in the model NAME's case too, so "2 under distinguish" is right either way | `CS145`/`CS145b`: NAME identical, only the KEYWORD's case varying, for the `model` **and** the `subckt` branch (which had no fixture at all). `V17`/`V36` each redden one alone. §3's "every one of the 30 checks appears in at least one row" no longer implies full coverage of the change |
| **F9** | minor. The gate-free relay rule was guarded only on the pure helper; a mode gate on `relay_sim_case_collisions`, the **only** thing `proc simulate` calls, was invisible | `CS148` drives the production entry point with `::sim_case_mode distinguish`. `V39` reddens it alone |
| **F10** | minor. `catch {ciw_echo $ln note}` — the relay's only user-visible effect — had no check, and the stated reason ("silent without a window") is measurably wrong | `CS149`, GUI arm: `ciw_create`, relay, assert the text **and** the `note` tag. `V40` (emit deleted) and `V41` (tag dropped) each redden it |

**Checks: 30 → 39 in the `--nogui` arm, 40 under `--pipe`** (`CS149` needs Tk; it prints a `NOTE:` line otherwise, with
none of the substrings `full_audit.sh` scores a whole file on). Both arms verbatim: **`RESULT: ALL PASS (39 checks)`** /
**`RESULT: ALL PASS (40 checks)`**.

### 6b. Sabotage — 17 mutations, every one restored from a byte-exact backup and re-driven green

Same harness discipline as §4, with the stale-binary trap closed by construction: the restore rewrites **all seven**
files and `os.utime`s each, so `make` can never skip.

| id | what was broken | went red |
|---|---|---|
| V30 | the canvas cue deleted (both `bus_hilight_hash_lookup` calls) | CS142 |
| V31 | the status-bar summary line deleted | CS141 |
| V32 | only the FIRST spelling is painted | CS142 |
| V33 | the names put back ahead of the diagnostic (the first pass's order) | CS144 |
| V34 | the message no longer says `in cell <name>` | CS116 CS122 CS122b CS146 |
| V35 | the message no longer says `(casemode=…)` | CS116b CS117 CS120 CS144 |
| V26 | **the warning turned into an ERROR** (`err \|=` at the call site) — SURVIVED the first pass | CS143 |
| V28 | the check sweeps the TOP LEVEL only | CS115 CS117 CS118 CS119 CS120 CS121 CS121b CS122 CS122b CS124 CS143 CS146 |
| V42 | the check refuses to fire unless the netlist TYPE is spice — the disclosed cross-backend consequence removed | CS146 |
| V17 | spectre `model` branch: the old `sscanf` literal against a verbatim source | CS145 |
| V36 | spectre `subckt` branch: the old `sscanf` literal against a verbatim source | CS145b |
| V38 | the dedup key back to the unanchored first-apostrophe regexp | CS147 |
| V16 | the dedup dropped altogether | CS133 CS134 CS139 CS147 |
| V20 | the pair key no longer order-normalised | CS134 |
| V21 | the instance path stripped from the pair key | CS135 |
| V39 | a mode gate on `relay_sim_case_collisions`, the production entry point | CS148 |
| V40 | the relay's `ciw_echo` emit deleted — the right list, shown to nobody | CS149 (gui arm) |
| V41 | the relayed line emitted with no `note` tag | CS149 (gui arm) |

Every one of the nine new checks has at least one row **aimed at it alone**: CS141←V31, CS142←V30/V32, CS143←V26,
CS144←V33, CS145←V17, CS145b←V36, CS146←V42, CS147←V38, CS148←V39, CS149←V40/V41. The four pre-existing relay checks
whose subject the key change touched (`CS133 CS134 CS135 CS139`) were **re-driven** (V16/V20/V21) and still fire, and so
were the three message checks (`CS116 CS116b CS122 CS122b CS117 CS120`, V34/V35).

### 6c. Verdict and what is still owed

The **`look` debt stands and a second one was recorded** (`owed.sh add look`; ledger now **4 suite / 11 look**): three
user-facing sentences now (the ERC-window line, the new status-bar summary, the relayed CIW line) plus the `note` colour
plus **the two painted nets**, which is a pixel deliverable by definition — a canvas cue is exactly the thing no check can
approve. Suites green — please look. Everything about the detection itself is asserted headlessly, so the verdict letter
is the only thing pixels gate.

Also left standing, deliberately: the two stray lower-case labels in `examples/test_bus_tap.sch` (F5 — a truthful
warning, and a shipped library file is not this item's to edit), and issue **`0500`** (`token.c`'s `@spice_get_*` folds),
which is item-4-shaped work and explicitly out of scope.

### 6d. Audit — the empty-diff contract, measured

`GUI_GATE=1 tests/headless/full_audit.sh` on the dev display `:99`, saved as
`doc/claude/casemode_batch/audit_item14_fixround_2026-08-17.txt`:

```
SUMMARY: 322 pass  15 fail  0 crash/timeout  0 skip  (total 337)
WIREEDIT: PASS      SCRATCH: 0 leaked dir(s)      TREE: 0 appeared  0 vanished
```

Diffed against `audit_item05b_closer_2026-08-17.txt` (321/15/0/0 of 336) **by name and status, both directions**:

| | |
|---|---|
| MOVED | **0** — no row changed status in either direction |
| ADDED | **1** — `test_netlist_case_collision  (absent) -> PASS` |
| VANISHED | 0 |

The 15 `FAIL` rows are **byte-identically the same 15 names** (`diff` of the two `FAIL     |` lists is empty), including
the two known non-ours, `test_wave_markers` and `test_ase_core`'s within-file failure. Empty-diff contract **satisfied**,
and it holds even though the fix adds a **canvas** side effect to the netlister — nothing in the suite set inspects the
highlight table after a netlist except this item's own `CS142`.

Suite set re-run after the fix, `GUI_GATE=1 tests/headless/run_suites.sh` (16 files, the netlisting + casemode set):
**`RESULT: 16/16 runs passed`**, every count unchanged from §3 (`test_netlist_case_collision` now **40**).
