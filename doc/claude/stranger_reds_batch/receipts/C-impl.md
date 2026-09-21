# C-impl — issues 1484 + 1490, a path the simulator's control line cannot take literally

Implementer receipt. Tree `0eed8a1b` plus the files listed in §6. Scratch root `/var/tmp/xsr_c`,
deleted at the end; peak size in §9.

**They are one defect.** Two faces of one cause, both now traced rather than inferred: ngspice
lowercases a control line whose command is not on its whitelist, and every control line splits an
unquoted path at the first space. The capital face and the space face are the same word arriving at
the same parser.

---

## 1. The mechanism — TRACED, and what is read vs measured

**MEASURED** (decks written by hand, ngspice run, the filesystem looked at afterwards), on
`/usr/bin/ngspice` **45.2** and on the ASE registry's fork `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
(**46+**), with identical results on both:

| control line | a capital in the path | a space in the path |
|---|---|---|
| `write <p>` | lands correctly | **splits** |
| `wrdata <p> …` | lands correctly | **splits** |
| `echo … >> <p>` | lands correctly | **splits** |
| `print … >> <p>` | lands correctly | **splits** |
| `eprvcd … > <p>` | lands correctly | **splits** |
| `set >> <p>` | **lowercased** | **splits** |
| `meas … >> <p>` | **lowercased** | **splits** |
| `wrnodev <p>` | **lowercased** | **splits** |
| `wrs2p <p>` | **lowercased** | **splits** |
| `shell mv -f <a> <b>` | lands correctly | **splits, and single quotes do NOT help** |

**The capital face is case folding, not anything else.** With a lowercase sibling directory
present beside `Cap/`, a deck saying `/x/Cap/f` wrote `/x/cap/f` — the **wrong directory**, at rc 0,
with nothing on stderr. With no sibling, `wrs2p` says `/x/cap/o.s2p: No such file or directory`
**and still exits 0**, so nothing downstream notices.

**The space face is word splitting.** `wrs2p /var/tmp/xsr_c/tr/w s/out.s2p` wrote a complete
653-byte Touchstone file to `/var/tmp/xsr_c/tr/w` — a **file** where the user has a **directory** —
at rc 0 with nothing said. `com_write_sparam` takes `wl->wl_word`, the first word, and the
redirection parser takes the first word after `>`/`>>`.

**READ** (ngspice source at `/home/analog/dev/ngspice`, which is the fork's checkout), and it
explains the table exactly: `inp_readall` in `src/frontend/inpcom.c` lowercases every card in place
when case folding is on (the default), **except** for a hard-coded command whitelist —
`write`, `wrdata`, `codemodel`, `osdi`, `pre_osdi`, `echo`, `shell`, `source`, `cd`, `load`,
`setcs`, `strcmp`, `strstr`, plus `.lib`/`.inc`, plus a separate exemption for the token after `>`
on `print`/`eprint`/`eprvcd`/`asciiplot`. **`wrs2p`, `set`, `meas`, `wrnodev` and `show` are on
neither list.** That is read, and it predicts the measured table row for row.

### The obvious remedy is the wrong one, and that is measured too

`wrs2p "<path>"` keeps the quotes **as part of the filename** and fails in a directory with neither
a capital nor a space: `"/tmp/plain/b.s2p": No such file or directory`. Same for `write`, `wrdata`
and `wrnodev`. Issue 1490's own warning — *"a quoted word that ngspice takes literally including the
quotes is a second defect wearing the fix's clothes"* — is real, and this is the row that proves it.

### What does work, on both binaries, for every one of the ten commands

```
setcs ases2p = '/var/tmp/x/w s/cell_ase_sp1.s2p'
wrs2p $ases2p
```

`setcs` is on the whitelist, so its line keeps its case; single quotes make its value one word; and
`$ases2p` is expanded at execution, **after** the reader has folded the line it sits on, so the
value arrives byte for byte.

**Character coverage, measured one directory per character.** Through `setcs` + `$var`, all of
space `"` `\` `;` `&` `|` `<` `>` `*` `?` `[` `]` `~` `%` `!` `#` `@` `(` `)` `=` `+` `,` `:` `-`
`_` `.` and upper case round-trip. `'` does not survive single quotes but **does** survive double
quotes on a `setcs` line. `$`, backquote and `{`/`}` survive **neither**, and backslash escaping was
measured not to help — a backquote is the worst of them, it ran the text as a command and left a
file named `bq ` behind. Those four are now **refused by name** rather than written into the void.

### The one line that goes to a shell, and it takes the opposite quoting

`shell mv -f <a> <b>` is read by ngspice and then handed to `/bin/sh`. Measured, moving a file
inside a directory called `w s`:

```
shell mv -f /x/w s/a /x/w s/b       the shell gets four words: NO MOVE
shell mv -f '/x/w s/a' '/x/w s/b'   ngspice STRIPS the single quotes first: NO MOVE
setcs p = '/x/w s/a' … shell mv -f "$p" "$q"                              MOVED
```

ngspice **keeps** double quotes on a `shell` line and expands the variable inside them, so `/bin/sh`
receives one quoted word. It is the mirror image of the `wrs2p` rule, which is why it has its own
proc (`shell_word`) and its own measurement rather than a flag on the other one.

---

## 2. The damage, by name

Method: three trees built at `/var/tmp/xsr_c/{plain,Cap,w s}/x`, each a `cp -a` of the repository at
`0eed8a1b` with its own build in place, each run from its own tree so the checkout path *is* the
variable, all 44 `test_ase_*` suites through `tests/headless/run_suites.sh --nogui` with
`AUDIT_DISPLAY=none`. Cross-checked against a second, cleaner experiment — one tree, three
`XSCHEM_TEST_SCRATCH` values — which reproduced the capital list identically and the space list to
within the rows that only a checkout move can reach.

### 1484, the capital face: 6 suites, 12 rows

| suite | rows |
|---|---|
| `test_ase_campaign_1462` | `EE2/apt` `EE7/apt` `EE2/fork` `EE7/fork` |
| `test_ase_campaign_gui_1464` | `EE0` `EE2/apt` |
| `test_ase_converge_1459` | `EE5/apt` `EE5/fork` |
| `test_ase_optier_0963` | `Z6` |
| `test_ase_sp_1452` | `SE1/apt` `SE1/fork` |
| `test_ase_variant_1470` | `OT1` |

1484 named five suites; `test_ase_optier_0963` is a sixth. Of the twelve, **ten** are this defect and
go green on the fix; `Z6` and `OT1` are not (§5).

### 1490, the space face: 17 suites, 147 rows — the list that file could not carry

| suite | n | rows |
|---|---|---|
| `test_ase_campaign_1462` | 7 | `RN12` `EE2/apt` `EE3b/apt` `EE7/apt` `EE2/fork` `EE3b/fork` `EE7/fork` |
| `test_ase_campaign_gui_1464` | 4 | `RR1b` `RR5` `EE2/apt` `EE0` |
| `test_ase_converge_1459` | 2 | `EE5/apt` `EE5/fork` |
| `test_ase_core` | 5 | `E1a` `E1b` `E1c` `E1f` `CK11` |
| `test_ase_cosim` | 2 | `HI21-stale-artifact-deleted` `AT17-last-vcdfiles` |
| `test_ase_events_1465` | 15 | `CI2` `CI3` `CI6` `CI8` `EM5` `EE3/apt` `EE4/apt` `EE5/apt` `EE6/apt` `EE10/apt` `EE3/fork` `EE4/fork` `EE5/fork` `EE6/fork` `EE10/fork` |
| `test_ase_final` | 13 | `F9`×2 `F10` `F18`×3 `F13`×2 `F14` `F15` `F16` `F17` `F21` |
| `test_ase_final_gf180` | 3 | `G9`×2 `G10` |
| `test_ase_optier_0963` | 15 | `A1` `A2` `B1` `B4` `M1` `R1` `R3` `R4` `ACC1` `ACC2` `Z6` `X1` `X2` `X3` `X7` |
| `test_ase_preflight` | 3 | `PF218g-…` `PF220-…` `PF220e-…` |
| `test_ase_print_bracket_0167` | 2 | `PB12` `PB12b` |
| `test_ase_simcaps_0948` | 40 | `Z2` `Z3` `B1` `B2` `B4` `B5` `B6` `B9` `B10` `C2` `D1` `D2` `D3` `D4` `D5` `D6` `D10` `D11` `F1` `F2` `F4` `F9` `G4` `G6` `J7` `J11` `J12` `K1` `K2` `K4` `K5` `K5b` `K5c` `K5e` `K5h` `K6` `M2` `N1` `N7` `XE11` |
| `test_ase_simchoice_1395` | 1 | `B1` |
| `test_ase_simreg_0931` | 9 | `A4` `E3` `E6` `E8` `E10` `E13` `R8` `R8b` `S6` |
| `test_ase_sp_1452` | 6 | `SE1/apt` `SE2/apt` `SE1/fork` `SE2/fork` `SE3/apt` `SE3/fork` |
| `test_ase_trnoise_1466` | 18 | `EE1..EE6/apt` `EE1..EE6/fork` `EC2..EC4/apt` `EC2..EC4/fork` |
| `test_ase_variant_1470` | 2 | `OT1` `M21b` |

**147, not 71.** 1490 recorded 71 from a crew that was not looking for this; the difference is the
arm and the suite set, and the receipt that carried the 71 is gone, so the two are not reconcilable.
Take **147/17** as the measured figure for a full `test_ase_*` sweep on the `--nogui` arm at this
commit, and note that **many of the 147 are not this defect** (§5).

---

## 3. The product consequence — measured outside the test suites

A real bench, rendered through `ase::backend::ngspice::render_deck` and run on ngspice 45.2, with
one `op` row, one `sp` row asking for a Touchstone export, one stored option, one measurement and an
operating-point save — seven artifacts. Three run directories, the only difference being the
directory's name. A lowercase sibling of `Cap/` was created on purpose, so a folded write lands
somewhere **visible** instead of merely failing.

**On the unfixed code, ngspice exits 0 every time:**

| run directory | what the user gets |
|---|---|
| `…/plain/run` | all 7 artifacts, correct |
| `…/Cap/run` | **4 of 7.** `_ase_sp1.s2p`, `_ase.effective` and `_ase.nodeset` went to **`…/cap/run`**, a different directory. `_ase.meas` was **split in two**: a 9-byte stub (the `echo` marker, case-safe) in `Cap/run` and the measurement itself in `cap/run`. |
| `…/w s/run` | **1 of 7** — the deck, which Tcl writes. Every simulator artifact collapsed into ONE 870-byte file called `/var/tmp/xsr_c/prodbase/w`, each clobbering the last. |

**So yes: the claim in both issue files is true, and it is worse than either says.** It is not only
the S-parameter export. A user under `~/Documents/My Designs/` loses the **results file** as well —
and `/mnt/c/Users/<First Last>/` is the ordinary Windows home seen from WSL.

**On the fixed code, same three directories, ngspice rc 0:** all 7 artifacts in the directory the
deck named, in all three, with nothing in the lowercase sibling and nothing beside it.

---

## 4. What changed, and why there

All in `src/ase.tcl`, namespace `::ase::backend::ngspice`.

**Two new procs.** `path_word {path var folded}` answers `{prelines word}` — `{}` and the bare path
when the path is safe as a bare word, or one `setcs` line and `$var` when it is not. `folded` says
whether ngspice lowercases this command's line. `path_quoted` renders the quoted value, preferring
single quotes, falling back to double quotes for a path containing `'`, and **raising, by name**,
for `$`, backquote, `{`, `}` or an apostrophe-plus-backslash pair. `shell_word` is the `shell`-line
variant described in §1. `path_bare_ok` is a deliberately small allow-list (`[A-Za-z0-9_./-]`, plus
no uppercase when folded) so the failure direction is always "quoted when it need not be".

**Eleven call sites, each through the helper:** the plotmap `echo … >>` (×2), the results `write`
(×3), the meas sidecar (resolved once for the whole block, since `meas … >>` is folded and is the
strictest command in it), `eprvcd … >`, `wrs2p`, `set >>` for the effective sidecar, `wrnodev`, and
the checkpoint block's `write <tmp>` and `shell mv -f <tmp> <final>`.

**Emitted only where it is needed.** A path already safe as a bare word is still written bare, so
**every bench on an ordinary path renders the deck it always did, byte for byte** — which is this
file's own rule for the deck (`meas_block`: *"an inert line in a generated deck is a line the next
reader has to work out"*), and is why the developer's condition does not move. Both branches are
pinned by rows, in both directions.

**The escape sits immediately above the line that uses it**, except in the checkpoint block, where it
goes **above the `while` loop**: the paths do not change per iteration, and the loop body is an order
several issues pinned by position (`CK13c` reads a window of four consecutive lines).

### The checkpoint block was not in either issue, and it is the worst of them

`write $ckt` + `shell mv -f $ckt $ckf` is the Stop-salvage path. With a space in the run directory
the checkpoint was written to a file named after the **truncated** word and then not moved at all —
so a Stop salvaged **nothing, silently**, which is the one outcome that block exists to prevent.
`test_ase_core` `CK11` is the row; it was red on the base in a space tree and nobody had attributed
it. Both halves are fixed and both have their own sabotage.

---

## 5. Proof

Final measurement: 54 suites (all 44 `test_ase_*` plus the ten other suites that start a real
simulator) in three conditions on one tree, `AUDIT_DISPLAY=none`, `--nogui`.

| condition | reds | which |
|---|---|---|
| plain | **1** | `test_cosim_golden_e2e GE24-matches-the-golden` |
| capital | **3** | `test_ase_optier_0963 Z6`, `test_ase_variant_1470 OT1`, `GE24` |
| space | **103** | see below |

* **The developer's condition is unchanged.** `GE24` fails **identically on `HEAD`** in a plain
  tree — measured, by reverting `src/ase.tcl` and `src/op_annot.tcl` to `HEAD` and re-running it. It
  is an Icarus/VCD golden and has nothing to do with this item.
* **Issue 1484 is fixed.** All six suites it named are green in a capital tree with the same check
  counts as in a plain one: `campaign_1462` 161, `campaign_gui_1464` 78, `converge_1459` 76,
  `sp_1452` 69, `variant_1470` 76 (one red), `optier_0963` 109 (one red). The two remaining rows are
  **not this defect** — `Z6` and `OT1` fail **byte-identically on the base**, and `OT1`'s own output
  names the reason: `{c dumppath}` (§7).
* **Issue 1490's space tree: 57 rows greened and ZERO newly red.** Base 142 `test_ase_*` rows red,
  final 85; the set difference in the other direction is **empty**. The 103 that remain (including
  the ten non-ASE suites) were every one of them red on the base and are other defects (§7).

Check counts for every suite this item touched, final, plain / capital / space:
`test_ase_core` 675/675/675 · `test_ase_meas_1443` 117/117/117 · `test_ase_sp_1452` 69/69/69 ·
`test_ase_effective_1442` 97/97/97 · `test_ase_preflight` 242/242/241+1 ·
`test_ase_events_1465` 88/88/84+4 · `test_ase_converge_1459` 76/76/74+2 ·
`test_ase_campaign_1462` 161/161/160+1 · `test_op_annot` 485/485/481+4.

**The suites gained 11 + 2 = 13 new checks:** `test_ase_sp_1452` 58 → 69, `test_ase_meas_1443`
115 → 117, `test_ase_events_1465` 87 → 88. No suite lost a check in any condition.

### T1

Run solo from `tests/`, on this tree, with the fix and every suite change in place:

```
T1-RUN-BEGIN pid=790800 … planned_cases=87 verdict=results.790800.log
             home=throwaway binary=/home/analog/dev/xschem-claude/src/xschem canonical=results.log
T1-RUN-END   pid=790800 cases=87 blocks=86 counted_failures=0 elapsed=528s
```

**87 `Start` / 87 `Finish`, `wc -l` 177, and ZERO occurrences of `another regression run is live`**
in its own output, which is the positive statement that it ran solo. The baseline is met.

---

## 6. Files changed

* `src/ase.tcl` — the fix (§4). The only product file.
* `tests/headless/test_ase_sp_1452.tcl` — **new rows `CP1`–`CP6`** (11 checks): the escape is
  emitted exactly when this tester's own path needs it and not otherwise (`cp_needs` is the suite's
  own independent predicate, so the row is a second opinion and not a tautology); the folded and
  whitelisted commands are distinguished; the double-quote trap is pinned so nobody "simplifies" the
  escape back into it; the refusal is pinned by name; and `CP6` runs the simulator against a
  directory with a capital, one with a space and a plain control, on both binaries, and asks the
  **filesystem** where the Touchstone export and the results file landed and whether anything landed
  beside them. `SL4` made escape-aware.
* `tests/headless/test_ase_meas_1443.tcl` — **new rows `CM1`/`CM2`** (2 checks) pinning the sidecar
  escape and its single-definition-above-every-use shape; `m_unescape`, a scrub that normalises the
  escape away for the rows whose subject is which measurement lines are emitted; `DK2c`'s source-text
  anchor updated.
* `tests/headless/test_ase_core.tcl` — `D1`/`C4`/`C5` goldens made condition-aware (see below);
  `WK3`, `CK11`, `CK21` read the control-line word.
* `tests/headless/test_ase_converge_1459.tcl` — `WR2`/`WR3` expectations through the encoder; `EE5`'s
  own hand-written fixture deck now speaks ngspice as carefully as the generated one does.
* `tests/headless/test_ase_effective_1442.tcl` — `DK4`'s window is computed from the expectation's
  length instead of a fixed `-4`.
* `tests/headless/test_ase_events_1465.tcl` — **new row `EV1`** (1 check) pinning the VCD escape;
  `EM1b`/`EM2`/`EM5`/`EM6`/`EM9`/`EE2` read the word.
* `tests/headless/test_ase_campaign_1462.tcl`, `tests/headless/test_ase_optier_0963.tcl`,
  `tests/headless/test_ase_simcaps_0948.tcl` — the shell **stand-ins** resolve a `setcs` variable the
  way ngspice would. They read the deck's `write` line to know where to put their canned results; a
  stand-in that cannot read the deck ASE-L writes is a fixture defect.
* `tests/headless/test_ase_preflight.tcl` — `PF218f2` allows exactly one `setcs` line in the gap it
  bounds and still reds on anything else there; `PF218f3` resolves the word.

**`test_ase_core`'s `D1` golden is worth its own line.** Its three paths resolve under the tester's
`HOME`, and a throwaway HOME's `mktemp` suffix is mixed case about 96% of the time. A golden spelling
the bare form would have been a **coin flip nobody could reproduce**. It now substitutes each path as
the control-line word the emitter will use, with its `setcs` line (or nothing) ahead of it, and was
verified green under a forced upper-case HOME and a forced lower-case one.

---

## 7. What I did NOT fix, and why

Each of these is the same class or adjacent to it. None is issue 1484 or 1490 as filed, and PLAN.md
criterion 4 says a finding outside the item is written down, not fixed on the way past.

1. **`.include` and `.lib` with a space in the path.** Measured: `.include /x/w s/f.lib` →
   `Error: Could not find include file /var/tmp/xsr_c/qa/w`, **rc 1**. Double quotes fix `.include`;
   **nothing fixes `.lib`** — bare, single-quoted and double-quoted all fail on 45.2. These are *deck*
   lines, not control lines, and they fail **loudly** rather than landing somewhere else, which is a
   different severity. `ase::backend::ngspice` emits both (`.include`/`.lib` from the models list, and
   `.include` again from `opstate_lines`'s `force` restore). This is `test_ase_converge_1459 EE5` in a
   space tree, which is why that row is still red there.
2. **Issue 1334 is this defect, found earlier, worked around by declining a feature.**
   `ase::op_dump_reachable_dir` refuses the fast operating-point dump outright whenever the run folder
   carries a capital or a space, and `op_annot::opdump_path` pre-lowercases the target so the reader
   can find what ngspice will write. The user-facing sentence says so in as many words: *"it writes the
   numbers through a path it converts to lower case and cuts at the first space … Rename the run folder
   in lower case with no spaces to get the faster way."* That is `test_ase_variant_1470 OT1`'s
   `{c dumppath}`. **With a general escape in hand that refusal can be lifted**, which would give every
   user with a mixed-case project folder the faster shape back. I did **not** do it: it is user-visible
   behaviour, it retires a user-facing sentence, and it needs its own end-to-end measurement that the
   dump really lands on both binaries. I wrote the emitter fix, measured that it is **unreachable**
   behind 1334's guard, and **reverted it** rather than ship a third mechanism on top of two deliberate
   workarounds. `src/op_annot.tcl` is untouched.
3. **`test_ase_optier_0963 Z6`** — red byte-identically on base and fix in a capital tree. A
   capability-answer-changes-mid-session row; not traced.
4. **The 103 remaining space-tree reds**, all red on the base: `test_ase_simcaps_0948` (39) and
   `test_ase_simreg_0931` (9) are shell stand-ins and registry fixtures whose own paths break;
   `test_cosim_golden_e2e` (14) and `test_op_annot` `XR1`–`XR4` (4) are Icarus/ngspice invocations;
   `test_ase_trnoise_1466` (18), `test_ase_events_1465` `CI*` (4), `test_ase_optier_0963`
   `A1 A2 ACC1 ACC2` and the rest are end-to-end rows whose fixtures do not survive a space. They are
   the same *class* — a path something cannot take literally — in code this item does not own.
5. **A path containing `$`, a backquote or `{}`** is refused, not carried. No encoding exists;
   measured, all four forms.

---

## 8. Sabotages

Each reverts exactly one quoting fix, runs the suites that should notice, and restores.
`src/ase.tcl` verified **byte-identical** afterwards (`md5 fd30648bed2e53695c1b43bb86f99128`, which is this receipt's tree).

| # | reverted | condition | rows that went red |
|---|---|---|---|
| S1 | `wrs2p` | capital | `CP1` `CP2` `CP3` `CP6/{apt,fork}/{cpA,cp s,cpz}` `SE1/apt` `SE1/fork` `SL4` — 12 |
| S2 | the results `write` | space | `CP2` `CP3` `CP6`×6 `SE1`×2 `SE2`×2 `SE3`×2 — 14 |
| S3 | the plotmap `echo >>` | space | `CP3` `SE1/apt` `SE1/fork` — 3 |
| S4 | `set >>` (effective) | capital | `DK4`, and `test_ase_core` `D1` `C4` `C5` — 4 |
| S5 | the meas sidecar | capital **and** space | `CM1` `CM2` — 2 in each |
| S6 | `wrnodev` | capital | `WR2` `WR3` — 2 |
| S7 | `eprvcd` | space | `CI2` `CI3` `CI6` `CI8` `EM5` `EE3/*` `EE5/*` `EE6/*` `EE10/*` — 13 |
| S8 | the `$`/backquote/brace refusal | plain | `CP5` |
| S9 | `path_bare_ok` → always escape | plain | `CP1` `CP2` `SL4` `CM1` `CM2` — 5 |
| S11 | the checkpoint `write` | space | `CK11` |
| S12 | the checkpoint `shell mv` | space | `CK11` |

**S5 is the one worth reading.** On its first run it reddened **nothing** — 115 checks green — because
`m_unescape`, the scrub that lets the TP and DK rows talk about measurement lines rather than quoting,
normalises the escape's *absence* just as happily as its presence. That is what `CM1`/`CM2` were added
for, and they read the block **raw**. A scrub is allowed to exist only in front of a row that pins what
it scrubs.

Also measured: the whole fix reverted to `HEAD` with the new rows in place reddens **8** rows in
`test_ase_sp_1452` and leaves `CP1` green — `CP1` is the non-vacuity row, and `HEAD` emits bare paths,
which is what `CP1` asserts on an ordinary path. `CP6`'s red output names the cause itself:
`{0 0 1 lc/spbench_ase_sp1.s2p}` for the capital directory (the export in the **lowercase sibling**) and
`{0 0 0 beside/cp}` for the spaced one (the **truncated word**).

---

## 9. Scratch

`/var/tmp/xsr_c`, peak **1.5 GB** (three 500 MB checkouts plus ~15 MB of hand-written ngspice decks
and trace directories). Deleted. Nothing was written to the real `HOME`, to `~/.claude`, to `:99` or
to `~/dev/xschem-op-wcard`; the ngspice source at `~/dev/ngspice` was read only.

---

# FIX ROUND — 2026-09-20, item C's one and only fix round (PLAN.md criterion 5)

Written by the fixer, after the adversarial verification in `C-verify.md`. Tree: this
working tree (`HEAD` `37b80387`) plus the files in §6 above. Scratch root `/var/tmp/xsr_c`,
deleted; peak size in §F9. `src/ase.tcl` after this round: md5 `973ffc3f1510254bc90dc92dd26ad285`
(it was `fd30648bed2e53695c1b43bb86f99128` when §8 was written).

Every finding below was re-measured here before being acted on. Two were acted on as
**must**, four as cheap **should**/**nit**, three were rejected with a reason, and three
things are left for the driver to file.

---

## F1. What changed in this round

All measurements on `/usr/bin/ngspice` **45.2** and the ASE registry's fork
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (**46+**) unless stated.

### F1.1 `path_quoted` now refuses a CONTROL CHARACTER by name (product)

**The defect the last round left behind, and it wore this round's own clothes.**
`path_bare_ok` rejects a newline, tab, CR, VT or FF (they are outside `[A-Za-z0-9_./-]`),
and `path_quoted` then **accepted** them and wrapped them in single quotes. Re-measured
with the real emitter rendering the deck, one run directory per character, ngspice run,
filesystem asked:

| run directory | rc | stderr | artifacts in it | stray |
|---|---|---|---|---|
| `nl\nnl` | 0 | nothing | **none** | `…/ctl/nl`, 2680 B |
| `ta\tb` · `cr\rc` · `vt\x0bv` · `ff\x0cf` | 0 | nothing | **none** | none |
| `w s` (control) | 0 | — | 4 of 4 | none |
| `plain` (control) | 0 | — | 4 of 4 | none |

That is the **same silent-loss signature** as the defect this escape exists to remove,
produced by the code that claimed to have removed it. A deck is line-oriented, so no
quoting can carry a newline and refusal is the only correct answer.

**After:** all five raise `ase: the simulator cannot be given this path -- `…` contains a
control character …` out of `render_deck`, nothing is written, and `w s` and `plain` are
untouched (4 of 4 each).

### F1.2 `opstate_lines`' `force` restore is quoted (product) — **the biggest win**

The save side went through `path_word` last round; **the restore side three lines below it
did not**, and it is the one that kills the run outright. Measured end to end on both
binaries, one bench, three run directories, `restore 1 mode force`, on the code as this
round found it:

| run directory | include card | rc | raw file |
|---|---|---|---|
| `…/plain/run` | bare | 0 | written |
| `…/Cap/run` | bare | 0 | written (`.include` is on the case whitelist) |
| `…/w s/run` | bare | **1** | **NONE** — `Error: Could not find include file /var/tmp/…/w`, `fatal error in ngspice, exit(1)` |

A user with a space in the run directory who ticks force-restore **loses the entire run**,
loudly but with nothing salvaged. The path is **ASE-L's own** (`ase::opstate_path` joins it
onto the run directory), so there is no PDK to ask anyone to rename — which is exactly what
separates it from §7.1's models cards.

**And a deck card takes the OPPOSITE quoting from a control line**, measured per character
on both binaries with a load-bearing include (`.param rv=7700` reaching the circuit as
`v(1)/i(v1) = -7.70000e+03`), 26 characters, bare vs `'…'` vs `"…"`:

* `space` and `;` — **bare BAD**, single OK, double OK
* `'` — bare OK, **single BAD**, double OK
* `"` — bare OK, single OK, **double BAD**
* the other 23 (`% + , : = ~ ! # @ ( ) [ ] & * ? \ | < > ^ -`) — all three OK

So there is **no character for which the new quoting is worse than the bare form**, except a
path carrying both `'` and `"` at once (double quotes are chosen for the apostrophe and the
`"` then ends them) — which fails **loudly**, at rc 1, and is noted rather than handled.

**After:** `w s` gives rc 0 and a written raw file on both binaries; `plain` and `Cap` still
render the **bare** card, so no ordinary deck moves.

### F1.3 `ase::op_dump_reachable_dir` asks the same question the escape asks (product)

The guard gated issue 1334's fast operating-point dump on lower-case plus `[ \t\n]` only.
Two measured failures walked through it — the dump is `show all > <path>`, a **bare word on
a folded control line**, so the question is exactly `path_bare_ok $dir 1`:

```
show all > /var/tmp/…/my$dir/f.txt   Error: dir: no such variable. / No such file
                                     or directory   rc 0, NOTHING WRITTEN
show all > /var/tmp/…/o'b/f.txt      an error line, rc 0, NOTHING WRITTEN (both binaries)
```

Both answered "reachable". It is the same predicate now. **A refusal costs only the fast
shape** — the per-device dump still runs and still annotates — so widening it can slow a run
and can never lose a number, which is the direction 1334 chose on purpose.

### F1.4 Four test-side corrections

* **`cp_want` (test_ase_sp_1452) and `ev_pre` (test_ase_events_1465) hard-coded single
  quotes.** The emitter falls back to **double** quotes for a path holding an apostrophe.
  Measured at `XSCHEM_TEST_SCRATCH=/var/tmp/xsr_c/ap/O'Br`: `test_ase_sp_1452` reported
  **4 FAILED (65 passed)** — `SL4`, `CP1`, `CP2`, `CP3` — with the deck **right** and the
  expectation **wrong**, while `CP6`, the end-to-end row, was green in the same run. Fixed
  by giving each suite its own copy of the same quote-choice rule (single unless the path
  holds `'`, then double), so the row stays a second opinion. After: **ALL PASS (73)**.
* **`ev_target` read the `setcs` value with `[lindex [split $sc =] 1]`**, which returns the
  first fragment of any path containing `=` — a legal path, and in the measured round-trip
  set. It is an anchored regexp now, with the old form kept as the fallback.
* **`WR4b` (test_ase_converge_1459) built its expectation from the same `$WRPATH`**, so it
  was tautological about quoting and could never catch F1.2. It goes through the suite's own
  `wr_inc` rule now, and **`WR4b2`** states the rule on three **literal** paths instead of
  agreeing with it.
* **`d1_pathsub`'s and `ck_word`'s comments** now say which half of the golden is a second
  opinion: the **rendering**, never the **predicate** — `cp_needs` and `ck_word` are copies
  of `path_bare_ok`'s regexp and shared its blind spot exactly, which is how F1.1 survived a
  round with every one of those rows green.

### F1.5 Four new rows

| row | suite | what it pins |
|---|---|---|
| `CP5b` | `test_ase_sp_1452` | a control character is refused **by name**, through `path_quoted` and through `path_word` (6 checks in one row) |
| `CP5c` | `test_ase_sp_1452` | a path with **both** `'` and `"` still renders one word (measured to round-trip); apostrophe-plus-backslash is refused by name |
| `CP7` | `test_ase_sp_1452` | **a capital in the CELL NAME alone**, on an all-lowercase path, end to end on each binary: the named artifacts exist and the folded spellings do not |
| `WR4b2` | `test_ase_converge_1459` | the `force` include quotes a space, leaves a capital bare, doubles for an apostrophe — on literal paths |
| `X4b` | `test_op_dump_altshow` | the guard refuses `$`, backquote, braces, an apostrophe and a newline, and still accepts an ordinary directory |

---

## F2. The product consequence, re-measured — and the cell name widens it

### F2.1 Three run-directory shapes, `HEAD`'s emitter against this one

One bench through `ase::backend::ngspice::render_deck`, run on ngspice 45.2, six artifacts
(deck, plotmap, raw, Touchstone export, effective sidecar, operating-point save). A
lowercase sibling of `Cap/` exists on purpose so a folded write lands somewhere visible.
**rc 0 in all six runs.**

| run directory | base (`HEAD`) | fix |
|---|---|---|
| `plain` | 6 of 6, correct | 6 of 6 |
| `Cap` | **3 of 6** — `_ase.effective`, `_ase.nodeset`, `_ase_sp1.s2p` in **`cap/`** | 6 of 6 in `Cap/`, sibling empty |
| `w s` | **1 of 6** (the deck, which Tcl writes) — every simulator artifact collapsed into ONE 832-byte file `…/w` | 6 of 6 in `w s/`, nothing beside |

### F2.2 ⚠ THE CELL NAME IS A TRIGGER, AND NEITHER ISSUE NAMES IT

Both issue files frame the trigger as the checkout or the run directory. **It is not.**
Every ASE-L sidecar is named `<cell>_ase.*`, so a capital in the **cell** is enough on a path
that is entirely lower case. Measured at the product level, same all-lowercase run directory,
cell `LACGbench`, ngspice rc 0 both times:

```
HEAD   LACGbench_ase.plotmap  LACGbench_ase.raw  LACGbench_ase.spice
       lacgbench_ase.effective   lacgbench_ase.nodeset   lacgbench_ase_sp1.s2p
fix    all six spelt LACGbench_ase.*
```

Three of six artifacts written under a name the user never asked for and nothing that reads
them will look up, **silently**. This repository contains a cell named exactly `LACG`. So
§4's *"every bench on an ordinary path renders the deck it always did, byte for byte"* needs
the caveat **"and an all-lowercase cell name"**, and `CP7` is the row that says so.

---

## F3. The row list in all three tree shapes, after the edits

Method as §2: three `cp -a` checkouts at `/var/tmp/xsr_c/{plain,Cap,w s}/x`, each run **from
its own tree** so the checkout path is the variable, `run_suites.sh --nogui`,
`AUDIT_DISPLAY=none`. `n` = checks passed, `+k` = counted failures.

| suite | plain | Cap | space | §5's figure |
|---|---|---|---|---|
| `test_ase_core` | 675 | 675 | **671+4** | 675/675/**675** ← corrected |
| `test_ase_meas_1443` | 117 | 117 | 117 | same |
| `test_ase_sp_1452` | 73 | 73 | 73 | 69/69/69 (+4 new) |
| `test_ase_effective_1442` | 97 | 97 | 97 | same |
| `test_ase_preflight` | 242 | 242 | 241+1 | same |
| `test_ase_events_1465` | 88 | 88 | 84+4 | same |
| `test_ase_converge_1459` | 77 | 77 | **77** | 76/76/**74+2** ← two greened |
| `test_ase_campaign_1462` | 161 | 161 | 160+1 | same |
| `test_op_annot` | 485 | 485 | 481+4 | same |
| `test_op_dump_altshow` | 71 | **NORESULT** | 66+5 | not in §5 |
| `test_ase_variant_1470` | 76 | 75+1 (`OT1`) | 75+1 | §5's survivor |
| `test_ase_optier_0963` | 109 | 108+1 (`Z6`) | 100+9 | §5's survivor |
| `test_ase_simcaps_0948` | 211 | 211 | 171+40 | §7.4 |
| `test_ase_trnoise_1466` | 80 | 80 | 62+18 | §7.4 |

**The plain column is 14/14 ALL PASS.** The `Cap` column is green but for `OT1` and `Z6`,
§5's two known survivors, and the `NORESULT` below. Every space-column red was measured red
before this round as well (see F4).

### F3.1 ⚠ `test_op_dump_altshow` DIES in a capital checkout, and it is pre-existing

`NORESULT | test_op_dump_altshow (exit 0 — binary never reported)` — the suite takes its own
fixture dump with `show >` into its scratch, which carries the checkout's capital, and
`op_annot` raises at line 215:

```
op_annot: no operating-point dump at '/var/tmp/xsr_c/cap/x/tests/headless/.scratch/…/d.opinfo'
```

(note the `cap` — ngspice folded it). **Measured identically with `HEAD`'s `src/ase.tcl` in
the same tree**, so it is not this round's, and it is not a red — it is a suite that stops
at rc 0 with no `RESULT` line, which `run_suites.sh` catches and T1 would not, because
`test_op_dump_altshow` is **not a T1 case**. It is a **seventh suite** for issue 1484's list
and the only one that dies rather than reds. Left for the driver (F7.1).

---

## F4. Nothing newly red, isolated per change rather than asserted

Each of the three product changes was reverted **on its own, in the tree that exercises it**,
and the suites re-run. This is stronger than a whole-fix base comparison: it names which rows
each change owns.

| reverted | tree | result |
|---|---|---|
| the control-character refusal | plain | `CP5b` red (`{0 0 0 0 0 0}` vs `{1 1 1 1 1 1}`), 72 others green |
| `opstate_lines`' force quoting | plain | `WR4b2` red; the end-to-end probe back to rc 1 / no raw in `w s` |
| `opstate_lines`' force quoting | **space** | `test_ase_converge_1459` **ALL PASS (77) → 4 FAILED (73)**: `WR4b`, `WR4b2`, **`EE5/apt`, `EE5/fork`** |
| the `op_dump_reachable_dir` widening | plain | `X4b` red, 70 others green |
| the `op_dump_reachable_dir` widening | **space** | 6 FAILED (`T1` `T5` **`X4b`** `X6` `N1` `N3`) against 5 with the fix — so the other five are pre-existing and the widening reds nothing |
| `cp_want`/`ev_pre` back to single-quotes-only | apostrophe scratch | `SL4` `CP1` `CP2` `CP3` and `EV1` red again |

`src/ase.tcl`, `test_ase_sp_1452.tcl` and `test_ase_events_1465.tcl` were verified
**byte-identical** after every sabotage (`973ffc3f…`, `d9be7597…`, `349bb757…`).

### ⚠ F4.1 §7.1's attribution of `EE5` was WRONG, and that is this round's sharpest result

§7.1 filed `test_ase_converge_1459 EE5` under *"`.include` and `.lib` with a space … These
are deck lines, not control lines … This is `test_ase_converge_1459 EE5` in a space tree,
which is why that row is still red there."* The row above shows it is not: **`EE5` is the
`opstate` force `.include`, ASE-L's own path, and it greens on one conditional pair of
quotes.** The models `.include`/`.lib` class is real and still unfixed (F7.2) — it is just
not what `EE5` was.

---

## F5. The apostrophe tree: 12 rows greened, and `EV1` is NOT what the verifier thought

`XSCHEM_TEST_SCRATCH=/var/tmp/xsr_c/ap/O'Br`, `test_ase_events_1465`, same binary, this
tree's suite files, `HEAD`'s `src/ase.tcl` against this one:

| arm | result |
|---|---|
| base (`HEAD` emitter) | **33 FAILED (55 passed)** |
| fix | **21 FAILED (67 passed)** |

**Twelve rows greened** — `EE2`/`EE3`/`EE4`/`EE5`/`EE6`/`EE10` on both binaries — and
nothing went red that was not red before.

⚠ **`EV1` is red on BOTH arms, and its message is not a quote mismatch.** `C-verify.md` F2
read `got {}` vs `exp {{setcs asevcd = '…'}}` as the expectation hard-coding single quotes.
`got {}` means **there is no `setcs asevcd` line in the deck at all**: the event probe never
ran, so there is no `eprvcd` either. The cause is measured and is a different defect —
`.lib` with an apostrophe:

| card | bare | `'…'` | `"…"` |
|---|---|---|---|
| `.include …/O'Br/p.inc` | **rc 0** | rc 1 | rc 0 |
| `.lib …/O'Br/m.lib tt` | **rc 1** | **rc 1** | **rc 1** |

The probe deck carries the fixture's `.lib`, so it dies, and `CI2` `CI3` `CI4` `CI6` `CI8`
`CI9` `EM*` `RF*` `UN1` red with it — all of them on `HEAD` too. The `ev_pre` widening is
still correct and is still pinned by the sabotage in F4; it is simply **not** what `EV1`'s
apostrophe red is about. That is F7.2's issue, not this one.

---

## F6. Files changed in this round

* `src/ase.tcl` — F1.1, F1.2, F1.3, plus a comment on `event_probe` naming it as the second
  emitter of the `.include`/`.lib` cards (F7.4).
* `tests/headless/test_ase_sp_1452.tcl` — `cp_quoted` + `cp_want`; new `CP5b`, `CP5c`, `CP7`;
  the `cp_needs` comment.
* `tests/headless/test_ase_events_1465.tcl` — `ev_quoted` + `ev_pre`; `ev_target` read by
  regexp.
* `tests/headless/test_ase_converge_1459.tcl` — `wr_inc`; `WR4b` through it; new `WR4b2`.
* `tests/headless/test_ase_core.tcl` — comments only (`d1_pathsub`, `ck_word`).
* `tests/headless/test_op_dump_altshow.tcl` — new `X4b`.

Check-count deltas: `test_ase_sp_1452` 69 → **73**, `test_ase_converge_1459` 76 → **77**,
`test_op_dump_altshow` 70 → **71**. No suite lost a check in any condition.

---

## F7. What I did NOT fix, and why — for the driver

1. **`test_op_dump_altshow` dies in a capital checkout** (F3.1). Pre-existing, not a T1 case,
   and a **suite death** rather than a red. It belongs on issue 1484's suite list as a
   seventh suite, with the note that its shape is `NORESULT`, not `FAIL`.
2. **`.include` and `.lib` with a space or an apostrophe in the USER's path** — §7.1's class,
   still unfiled. **Two corrections to §7.1's sentence, both measured here:**
   * *"Double quotes fix `.include`"* → **either quoting fixes it** (single: rc 0, with the
     included `.param` reaching the circuit; double: rc 0), on both binaries.
   * *"nothing fixes `.lib`"* → **quoting fixes `.lib` on the fork (46+) and not on 45.2**
     (`'…'` and `"…"` both rc 0 on 46+, all three rc 1 on 45.2), **and a RELATIVE `.lib
     m.lib tt` resolves on both binaries** from a spaced directory — measured both with cwd
     inside it and with the deck named by an absolute spaced path from elsewhere. That is the
     same relative-path remedy `ase::cosim_rewrite` and the `cap_deck_*` probes already use,
     and it helps exactly where the space sits in a directory the deck and the target share
     (the `E1` case and every ASE-owned artifact — not a PDK elsewhere on disk).
   * It is the direct cause of `test_ase_core` `E1a` `E1b` `E1c` `E1f` in a space checkout
     (F3's corrected 671+4), of `test_ase_events_1465` `CI2` `CI3` `CI6` `CI8` in a space
     tree, and of the 21 apostrophe-tree rows in F5.
3. **The new refusal arrives as a mid-render raise rather than through a preflight refusal
   tier.** Confirmed as an observation: a run directory containing `$`, a backquote or a
   brace now makes `render_deck` raise, so a bench that used to start (and land 0 of 6
   artifacts) no longer starts. **Refusing is the better behaviour and the raise is an
   established contract** — `render_deck` already raises the same way for
   `meas_fatals`, `opstrategy_refusals`, `opstate_refusals` and `event_refusals`, and
   `C-verify.md` §1.6 measured it loud at the product level (`ase::ui::run_raised` echoes
   the sentence and reddens the status segment). Surfacing it *earlier* means choosing a
   banner and a dialog for a class of refusal that has no home — `ase::ui::conv_refusals` is
   the Convergence dialog's own collector and there is no global precheck list to add to. That
   is user-visible product design, not implementation, and it is not cheap or safe inside a
   one-round cap. **Recorded here as a deliberate behaviour change — silent loss → hard
   refusal — and handed to the driver.**
4. **`event_probe` is a second deck builder** re-implementing `render_deck`'s
   `.include`/`.lib`/`.param`/`pre_commands` emission. It needs no `path_word` today (it
   carries no run-directory-derived control-line path), but any quoting added for item 2
   must land in both places. A comment now says so **in the code**, which is the durable
   half; the `pre_commands` `$::VAR` word-split the verifier read but did not measure is
   left to the driver with that provenance.
5. **The duplicated `setcs` lines** (one 88-line deck carried 11, of which 6 were exact
   duplicates). Cosmetic, and several rows in several suites pin deck line **positions** —
   `CK13c` reads a window of four consecutive lines. Not worth the blast radius in the one
   fix round.
6. **`test_ase_optier_0963 Z6` and `test_ase_variant_1470 OT1`** in a capital tree — §5's two
   survivors, unchanged, byte-identical on the base, and not this defect.
7. **The space tree's other reds** (`simcaps_0948` 40, `trnoise_1466` 18, `optier_0963` 9,
   `op_annot` 4, `preflight` 1, `campaign_1462` 1) — §7.4's set, all red on the base.

---

## F8. T1

Solo, from `tests/`, on this tree with every edit above in place:

```
T1-RUN-BEGIN pid=970455 script=run_regression.tcl start=2026-09-20 19:04:11
             planned_cases=87 verdict=results.970455.log home=throwaway
             binary=/home/analog/dev/xschem-claude/src/xschem canonical=results.log
T1-RUN-END   pid=970455 cases=87 blocks=86 counted_failures=0 elapsed=525s
             end=2026-09-20 19:12:56
```

**87 `Start` / 87 `Finish`, `wc -l` 177, 86 `Total num fail:` lines, zero lines in any
counted shape, and ZERO occurrences of `another regression run is live`** in its own
output — the positive statement that it ran solo. `DISPLAY` was set. The baseline is met.

## F9. Scratch

`/var/tmp/xsr_c`, peak **1.30 GiB** (`du -sb` 1 393 668 247 B = 1.39 GB decimal, measured
immediately before deletion, with all three checkouts and every probe tree in place) — three 500 MB checkouts at
`{plain,Cap,w s}/x`, one 16 MB base `src/` arm with `HEAD:src/ase.tcl` exported over it, and
about 1 MB of hand-written ngspice decks, probe scripts and trace directories. Deleted. Nothing was written to the real `HOME`, to `~/.claude`, to the
dev display `:99`, or to `~/dev/xschem-op-wcard`; `~/dev/ngspice` was read only.
