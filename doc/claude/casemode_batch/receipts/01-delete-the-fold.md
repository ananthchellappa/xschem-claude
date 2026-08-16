# 01 — delete the read-path fold + `Raw.case_sensitive`

`PLAN.md` §3b item 1; design `DESIGN_REVISION.md` §4/§6/§7/§8; spec
`doc/claude/specs/raw_case_mode.md`. Base `c6b1c4d7`, `fluid-editing`, **nothing
pushed**. Detail annex (354 lines): `01-delete-the-fold-annex.md`.
`git diff --stat` on tracked files: 7 files, 382 insertions, 16 deletions.

## 1. Files changed

| file | lines | what |
|---|---|---|
| `src/save.c` | +136 −6 | `strtolower(varname)` **deleted** from `read_dataset()`; AC `v(` prefix test made case-blind; new `raw_case_mode_parse()`, `ngspice_data_key()`, `ngspice_data_publish()`; `extra_rawfile()` records `req_sim_type` |
| `src/scheduler.c` | +188 −2 | `raw read … -case <mode>` (option, not positional); new `raw case [<mode>]` whose set re-reads via `raw_case_reread()`, which probes before it destroys; in-source `raw what …` reference updated |
| `src/xschem.h` | +35 −0 | `Raw.case_sensitive` (boolean), `Raw.req_sim_type`, 3 prototypes |
| `src/callback.c` | +8 −1 | cursor-B `ngspice_data` publisher onto `ngspice_data_publish()` |
| `doc/xschem_man/developer_info.html`, `DESIGN_REVISION.md` | +24 −2 | shipped ref (`case`, `-case`, the error contract); §8 correction — "no extra work" was wrong |
| `tests/headless/full_audit.sh` | +1 −1 | one token: new suite into `nogui_tests` |
| `tests/headless/test_raw_case_mode.tcl` | 474 new | the suite, 81 checks, true headless |
| `doc/claude/specs/raw_case_mode.md` | 271 new | the spec, carries all five rulings |
| receipts ×2 + 3 audit logs | 7047 new | this + the annex; `audit_item01_{,fixround_,closer_}2026-08-16.txt` |

## 2. Decisions, and the evidence

- **Xyce — RULED: accept the change, add NO Xyce-specific fold** (spec §5, with
  what would reopen it). Item 1's to rule; no Xyce here, so ruled from what *is*
  measurable: **no measured identification of a Xyce raw exists.** The header's
  vendor line (`Command: ngspice-46+, …`) is never parsed (`grep -n Command
  src/save.c` is empty) and what Xyce writes there is unmeasured; the
  Xyce-shaped `:`→`.` rewrite runs on **every** raw; `sim_is_xyce`
  (`xschem.tcl:2787`) regexps the configured simulator *command*, never the file.
  A fold would gate a destructive transform on a heuristic.
- **The getter answers `1`/`0`, not a mode word** (§3): the flag records what the
  *lookup* does, not what the simulator did (`DECISIONS.md` B2b). Round-trips.
- **A set RE-READS, and so does `-case` on an already-loaded database** (§3):
  `extra_rawfile()` only *switches* to a file it holds, so stamping the flag
  there was the forbidden flag-flip reached by the other verb — measured, an
  in-memory `raw rename` survived while the flag moved 0→1.
- **A failed re-read is a Tcl error and changes nothing** (§3): the set deleted
  the registry entry *before* knowing the read would work, so an unreadable file
  annihilated the database and reported `"0"` — guaranteed for an embedded
  `spice_data` raw, whose temp file `raw_read_from_attr()` `unlink()`s. It also
  re-read with the **promoted** `sim_type` (`op`→`dc`, never matching
  `Plotname:`), failing every multi-point `.op`; `Raw.req_sim_type` fixes it.
- **`ngspice_data` keys stay FOLDED** at both publish sites, as §6 requires (5b
  not pre-empted); folding is lossy under `distinguish`, so first writer wins
  (matching `XINSERT_NOREPLACE`), the loser named in a `dbg(0)` (§4).
- **The AC `v(` prefix test became case-blind** (§8): it matched only because the
  fold had just lowercased `varname`, so `V(Out)` derived `ph(V(Out))` — a
  different *string*, unrepairable by item 2's alias rung. `varname` unchanged.

## 3. Tests

`tests/headless/test_raw_case_mode.tcl` — prefix `CS`, **81 checks**, true
headless, no simulator (the two committed fixtures, first consumer ever, plus an
inline ASCII AC raw). Verbatim: `RESULT: ALL PASS (81 checks)`

`GUI_GATE=1 full_audit.sh` on `:99` → `audit_item01_closer_2026-08-16.txt`, diffed
by test NAME and STATUS against `merge5_loose_ends/audit_item02_fixround_2026-08-16.txt`
(316/15/0/0 of 331): the **entire** diff, both directions, is one added row
`test_raw_case_mode PASS`. **Zero statuses moved** — 00a's contract, met exactly.

## 4. Sabotage table

**All 81 check ids appear below; none is unsabotaged.** Keyed by mutation, not by
check — 81 rows plus a legend cannot fit the 120-line cap. Each named mutation is
one red/green drive (red sets `·`-separated where a row carries several), applied
to a copy of a byte-exact backup, restored from it (`md5sum` equal), re-run green.

| mutation | what was broken | drove red | green again |
|---|---|---|---|
| M1 | `strtolower(varname)` put back — **the pre-item-1 code, and the item's red-before-green drive** | CS2b CS8 CS9 CS10 CS11 CS12 CS17b CS22 CS23d CS24b CS25b CS28b CS29c CS32d CS34c CS36b CS36f | yes |
| M2 | `read_dataset()` overwrites varname's last char with `Z` | CS1b CS2b CS3 CS8 CS9 CS10 CS11 CS13 CS17b CS18b CS22 CS23 | yes |
| M3 | `ngspice_data_key()` no longer folds (reaches both publish sites) | CS22 CS23 CS23d CS36d CS36e | yes |
| M5 | `raw case <mode>` flips the flag instead of re-reading — **the contract sabotage** | CS25b CS25c CS30b CS30e CS31b | yes |
| M6 | `raw_case_mode_parse()` accepts an unknown token | CS18 CS18b CS27 CS27b | yes |
| M9, M15 | `raw case` getter hard-wired to 0; to 1 in a second build | CS15b CS20c CS25d CS34d CS35b · CS14 CS16 CS17 CS26b CS27b CS30e | yes |
| M10, M11 | missing-`-case`-argument guard replaced by `break`; `raw new` forced to 0 | CS19 · CS31 | yes |
| M13, M30 | sweep window never applied (`npos > 99`); `-case` clobbers the positional window | CS20 CS33 · CS20b | yes |
| M17, M27, M28 | `raw points` −1; `raw vars` −1; `raw value` +1.0 on an uppercase query | CS4 CS25e CS32e · CS4b CS7 · CS5 CS36f | yes |
| M18b, M19b | `raw_case_reread()` blanks `sim_type`; blanks `rawfile`; both after the re-read | CS25f · CS25g CS26 CS26b CS27b CS35 | yes |
| M20, M21 | `raw case` set returns 0; `raw read` returns 0 | CS25 CS26 CS32c CS33b CS35 · CS1 CS2 CS6 CS15 CS28 CS29 CS30 CS32 CS34b CS36 | yes |
| M22, M23, M24 | AC arm derives `pH(`; `update_op()` returns 0; cursor-B backannotate early-returns | CS9 CS29c CS29d · CS21 CS36c · CS23c CS23d | yes |
| M26, M29 | `raw index` returns −1; `raw rename` made a no-op | CS3 CS29b CS29d · CS24 CS24b CS34 | yes |
| N1 | AC prefix test back to case-sensitive (**fix 1's bug**) | CS29c CS29d | yes |
| N3, N10 | file-open probe deleted, i.e. destroy-then-ask (**fix 2's bug**); a failed re-read reported as success, not `TCL_ERROR` | CS30c CS30d CS30e CS31c · CS30b CS30e CS31b | yes |
| N4, N12b | re-read with the promoted `sim_type` (**fix 3's bug**); the `op`→`dc` promotion removed, pinning that premise | CS32c CS32d CS32e · CS32b | yes |
| N5, N6 | re-read drops the sweep window; `-case` on a loaded db back to a bare flag stamp (**fix 4's bug**) | CS33c · CS34c | yes |
| N7, N8 | `"1"` dropped from `raw_case_mode_parse()`; second writer overwrites the collided key (**fix 5's bug**) | CS35 · CS36d | yes |
| fixture | `tr_preserve.raw` moved out of the tree | CS0 — `RESULT: 1 FAILED (0 passed)`; it FAILS, printing no `SKIP` substring | yes |

**CS15 and CS27 pass vacuously on a pre-item-1 binary** (old `raw read` swallowed
the extra argv; `raw case sideways` errored `Wrong command`) and are not evidence
alone — CS15b/CS27b are, and both red there. A rebuilt pristine `HEAD` binary ran
the suite at `RESULT: 24 FAILED (23 passed)`.

## 5. What was NOT verified

- **The Xyce premise** — that Xyce uppercases — is unmeasured; only its
  consequences were. **Allocation tracing:** `ngspice_data_key()`/`nd_key` were
  read, not measured (no `-d 3 -l log`, no valgrind).
- **A THIRD `ngspice_data` publisher exists, in Tcl**, refuting the verifier's
  "only C writes it": `ngspice::read_raw_dataset` (`ngspice_backannotate.tcl:24`),
  harmless today (`string tolower` at :38) but **item 5b must handle it.**
- **Blast radius** beyond the publishers: no sweep of Tcl consumers of `xschem raw
  list` for an exact lowercase comparison that now misses; and **`raw case` on a
  `table_read` database** was never driven (VCD and spice were).
- **Per-mutation green:** restores are byte-exact per mutation, but the
  rebuild-and-re-run-green is per *batch*. **`src/vcd_read.c:139-141` now asserts
  the opposite of the code** — left standing, item 2 schedules retiring it.
- **Already filed, still open — issue `0316`:** a malformed raw header makes
  `read_dataset()` call `extra_rawfile(3, NULL, …)`, clearing **every** loaded
  database. Re-measured here (`tr_fold.raw` loaded, then a raw with
  `No. Points: xyzzy` read → `raw loaded` −1, `raw list` "No raw file loaded"). No
  new issue filed; it is the one hole the new `fopen` probe cannot close.
- **Tree hazard** a reviewer hit here: an mtime-preserving restore leaves `make` a
  no-op, so the next run measures the sabotage while checksums say clean.
- **Not reproduced by the closer:** the `:99` GUI/legend drives and the fresh
  mixed-case raws from the ngspice fork (annex, "Real end-to-end"). The payload is
  machine-checkable, so **no eyeball is owed and none was recorded.** Items 2–15
  are not pre-empted; the declared gap (spec §2) is by design.
