# 03 annex — the full sabotage table and the measurement transcripts

Detail for `receipts/03-mode-resolution.md`. Nothing here contradicts it; the
receipt is the summary and this is what it was summarised from.

## 1. Every mutation, and the checks it drove red

42 code mutations plus one data drive. Each was applied to a copy of a byte-exact
backup of the file named, rebuilt (`cd src && make`), run
(`devdisplay.sh exec ./src/xschem --nogui --pipe -q --nolog --script
tests/headless/test_raw_case_mode.tcl`), then restored from the backup and the
tree rebuilt green — `md5sum -c` clean over `save.c`, `scheduler.c`, `xschem.h`,
`xschem.tcl`, `test_raw_case_mode.tcl` at the end.

Numbering has gaps (M2, M3, M39) where a first formulation was replaced: M2/M3
were folded into M4 once it was clear the anchor is stated in two places, and
M39 was dropped as a duplicate of M38.

| mutation | file | drove red |
|---|---|---|
| M1 the parser's start-of-line anchor removed | save.c | CS53b |
| M4 the naive parse — key found anywhere, value read to whitespace — **and** every header line fed to it | save.c | CS52c CS53 CS53b CS53c |
| M5 the header key matched case-INSENSITIVELY | save.c | CS54 CS54b |
| M6 the header value matched case-SENSITIVELY (`strtolower` dropped) | save.c | CS55 CS55b |
| M7 the trailing trim dropped | save.c | CS56 |
| M8 the LAST casemode line wins instead of the first | save.c | CS57b |
| M9 a `Casemode:` key accepted, + every line fed to the parser | save.c | CS52b |
| M10 the header is never stamped (branch body disabled) | save.c | CS50b CS50c CS50d CS50e CS51 CS51c CS55 CS55b CS56 CS57b CS59d CS59g CS60e |
| M11 the resolver skips the HEADER source | save.c | CS50c CS50d CS50e CS59g CS60e |
| M12 the resolver skips the EXPLICIT source | save.c | CS59c |
| M13 the sniff gate ignored (source 4 always consulted) | save.c | CS58b CS58c CS62 CS63c CS64f |
| M14 the sniff answers `fold` when it finds no capital | save.c | CS63e CS63f |
| M15 the sniff ranked ABOVE the schematic comparison | save.c | CS63g |
| M16 the "at least two comparable names" rule dropped | save.c | CS61 CS61f |
| M17 the strict-majority test dropped (a tie decides) | save.c | CS61b |
| M18 the no-case-signal guard dropped (an all-lowercase design votes) | save.c | CS61e |
| M19 the all-CAPITALS ambiguity skip dropped | save.c | CS61f |
| M20 `.` and `-` allowed in a candidate node | save.c | CS61h |
| M21 the floor answers `unknown` for an `unknown` global | save.c | CS64e |
| M21b the floor answers `unknown` for a garbage global | save.c | CS64d |
| M22 the floor LEAKS into the resolution of a file | save.c | CS58b CS58d CS62 CS63c CS63f CS64f |
| M23 the explicit setting not carried across the `raw case` re-read | scheduler.c | CS59m |
| M24 `raw casemode <mode>` also flips the lookup flag | scheduler.c | CS59e |
| M25 the mode setter returns 0 | scheduler.c | CS59 CS59f CS59k |
| M26 an unknown mode token accepted instead of refused | scheduler.c | CS59h CS59i |
| M27 an unknown `-option` accepted (falls through silently) | scheduler.c | CS59j |
| M28 the no-database arm answers `unknown` instead of raising | scheduler.c | CS58f |
| M29 **item 1 undone** — `read_dataset()` folds the stored name again | save.c | CS53d CS60c CS60d CS61b CS61f CS63b CS63d CS63g CS63h (+32 item 1/2 checks; `RESULT: 41 FAILED`) |
| M30 an unparseable header value defaults to `fold` | save.c | CS57 |
| M31 **B2b violated** — a file with no casemode line is recorded as `fold` | save.c | CS52b CS52c CS52e CS53 CS53b CS53c CS54 CS54b CS56b CS56c CS57 CS58 CS58b CS58c CS58d CS60b CS60c CS60d CS62 CS63c CS63d CS63f CS63g CS64f |
| M32 the explicit setting parsed but never stored | scheduler.c | CS59b CS59c CS59m |
| M33 `raw case <mode>` no longer stamps the lookup flag | scheduler.c | CS59n (+4 item 1/2 checks) |
| M34 the comparison swaps fold and preserve | save.c | CS60b CS60c CS60f CS61c CS61g |
| M35 the third outcome never counted (upper folded into no vote) | save.c | CS60d CS63g |
| M36 the sniff defaults ON | xschem.tcl | CS58b CS58c CS62 CS63 CS63c |
| M37 the sniff never answers | save.c | CS63b CS63d CS63h |
| M38 the floor ignores the global and is hardwired `fold` | save.c | CS64c |
| M40 the global floor defaults to `preserve` | xschem.tcl | CS64 CS64b |
| M41 the spice reader fails (`exit_status` forced 0) | save.c | CS50 CS51b CS52 CS52d CS52e CS53d CS55 CS55b CS59l (+ ~105 item 1/2 checks; `RESULT: 114 FAILED`) |
| M42 the `raw case` getter hardwired to 1 | scheduler.c | CS58e CS59e (+10 item 1/2 checks) |
| D1 DATA DRIVE: `div_case.sch` given a fourth label | the test | CS60 |

Two mutations crashed in their first formulation and were reshaped rather than
recorded as passes: an `else if(1)` on the `Option:` branch swallows the
`No. of Data Rows:` / `No. Points:` arms further down the same chain, so
`nvars`/`npoints` stay 0 and the binary-blob seek walks off — `FATAL: signal 11`
and no RESULT line. Both now stamp from a separate statement above the chain.

## 2. The eleven upstream header fixtures, driven

`doc/claude/ngspice_upstream/feedback/ngspice_upstream/repro/hdr_*.raw`, read
with `xschem raw read <f> op` on this binary. `read` was `1` for all eleven —
none of these shapes stops the reader.

```
hdr_option             hdr=preserve  resolved=preserve  src=header
hdr_option_early       hdr=preserve  resolved=preserve  src=header
hdr_optval_upper       hdr=preserve  resolved=preserve  src=header
hdr_optval_mixed       hdr=preserve  resolved=preserve  src=header
hdr_newkey             hdr=unknown   resolved=unknown   src=none
hdr_cmdset             hdr=unknown   resolved=unknown   src=none
hdr_cmd                hdr=unknown   resolved=unknown   src=none
hdr_optname_upper      hdr=unknown   resolved=unknown   src=none
hdr_optname_mixed      hdr=unknown   resolved=unknown   src=none
hdr_ngb                hdr=unknown   resolved=unknown   src=none
hdr_numdgt             hdr=unknown   resolved=unknown   src=none
```

## 3. The two ngspice measurements

`/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice` (`ngspice-46+`),
2026-08-16, `printf 'echo CCM=$curcasemode\nquit\n' | $NG -p -n -D <flag>`:

```
-D casemode=distinguish   CCM=distinguish   (+ the experimental-mode warning)
-D CaseMode=distinguish   CCM=fold          <- silent no-op: a DIFFERENT variable
-D CASEMODE=distinguish   CCM=fold          <- silent no-op
-D casemode=preserve      CCM=preserve
-D casemode=PRESERVE      CCM=preserve      <- the value compare is case-blind
-D casemode=Preserve      CCM=preserve
```

The first three are why the header **key** is matched with `strcmp` and the last
three are why the **value** is matched after a `strtolower`. Upstream
`FINDINGS.md` §6 reported the name half against an older build; it was
re-measured here rather than carried on trust, because the ver_50 tree has moved
three times during this batch.

## 4. Build hygiene

`gcc -fsyntax-only -std=c89 -pedantic -Wall -Wextra` on `save.c` and
`scheduler.c`: **49 warnings, none inside the new code** (all are pre-existing —
`save.c:140,163,217-222,275,322,676,712,4100` and two `/*`-in-comment notices
from `xschem.h`). The new block is `save.c:2169-2464`; the `read_dataset()`
stamp is at `save.c:~920`.

## 5. Fix round — every mutation, and the checks it drove red

Applied to the fixed tree (`src/save.c` md5 `032bc7448acc9e16edf219274193119a`,
`tests/headless/test_raw_case_mode.tcl` md5 `4fd59393137007863705b01090692b58`),
rebuilt, run through `devdisplay.sh exec`, restored from those byte-exact
backups, re-run `RESULT: ALL PASS (277 checks)`.

| id | edit | red |
|---|---|---|
| F1 | `sch_owned_consider()`: exact test removed, first case-insensitive hit wins (the reported defect, restored) | 4 — CS61i CS61j CS61k CS61o |
| F2 | `sch_owned_consider()`: the `SCH_NAME_AMBIGUOUS` arm made unreachable, exact-first kept | 1 — CS61o |
| F3 | `raw_case_mode_schematic()`: the `raw->schname`/`raw->level` pairing gate replaced by `if(0)` | 1 — CS62d |
| F4 | `sch_owned_name()`: `for(i = 0; i < xctx->wires; ++i)` → `i < 0` | 2 — CS61m CS61n |
| F5 | `raw_case_mode_sniff()`: `for(i = 0; i < 1 && i < raw->nvars; ++i)` | 2 — CS63i CS63j |
| F6 | `read_dataset()`: `int hm = (sim_type \|\| !seen_plotname) ? … : -1;` → unconditional | 1 — CS57d |
| F7 | the same test inverted to `(!sim_type && seen_plotname)` | 15 — CS50b–CS50e CS51 CS51c CS55 CS55b CS56 CS57b CS57d **CS57f** CS59d CS59g CS60e |
| F8 | the same test narrowed to `sim_type` alone (file-level position lost) | 1 — CS51 |
| M09 | header never stamped (`hm = -1`) | 15 |
| M10 | the `Option:` branch aborts the read | 24 — now including **CS57c CS57e** |
| M22 | the schematic lookup made case-SENSITIVE | 7 — CS60b CS60d CS60f CS61c CS61g **CS61m** CS63g |
| M23 | the fold and preserve votes swapped | 7 — CS60b CS60c CS60f CS61c CS61g **CS61m CS61n** |
| M14 | the resolver returns FOLD instead of UNKNOWN | 10 — CS58b CS58d **CS61i CS61o** CS62 **CS62b CS62d** CS63c CS63f CS64f |
| M15 | the sniff gate removed | 9 — CS58b CS58c **CS61i CS61o** CS62 **CS62b CS62d** CS63c CS64f |
| M17 | `comparable < 2` → `< 1` | 3 — CS61 CS61f CS61h |
| M18 | the strict-majority test deleted | 1 — CS61b |
| M19 | the all-lowercase skip deleted | 4 — CS61e **CS61i CS61j CS61k** |
| M20 | the all-CAPITALS ambiguity skip deleted | 3 — CS61f **CS61i CS61k** |
| M21 | the candidate identifier filter deleted | 1 — CS61h |
| D2 | **data drive**: a third wire added to the `div_wire.sch` fixture text | 1 — CS61l (`instances=0 wires=3, want 0 and 2`) |
| D3 | **data drive**: `CS62b` reads `tr_fold.raw` instead of `tr_preserve.raw` | 1 — CS62c (the stored name list changes) |

`CS61k` is worth reading rather than counting: under F1 its own detail line
prints the defect verbatim — `(uppercase-first='fold' lowercase-first='unknown',
want both 'unknown')`, one unchanged raw file given two different answers by the
order of two labels in a `.sch`.
