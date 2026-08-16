# 01 — delete the read-path fold + `Raw.case_sensitive`

Item 1 of `PLAN.md` §3b, design `DESIGN_REVISION.md` §4/§6/§7/§8. Base HEAD
`577ef5bc`, `fluid-editing`, nothing pushed, tree left dirty for the verifier.

## What landed

| file | change |
|---|---|
| `src/save.c` | `strtolower(varname)` in `read_dataset()` **deleted** (was `:1008`), replaced by the reasoning; the AC `v(` prefix test made **case-blind**; new `raw_case_mode_parse()`, `ngspice_data_key()` and `ngspice_data_publish()`; `update_op()` publishes through the last; `extra_rawfile()` records `req_sim_type` |
| `src/xschem.h` | `Raw.case_sensitive` (boolean), `Raw.req_sim_type` + the three prototypes |
| `src/callback.c` | the cursor-B `ngspice_data` publisher uses `ngspice_data_publish()` too |
| `src/scheduler.c` | `xschem raw read … -case <mode>`; new `xschem raw case [<mode>]`, the set **re-reads**, via one `raw_case_reread()` that probes before it destroys; the in-source `raw what …` reference updated |
| `tests/headless/test_raw_case_mode.tcl` | new, **81** checks, prefix `CS`, true headless |
| `tests/headless/full_audit.sh` | one token: the new suite added to `nogui_tests` |
| `doc/claude/specs/raw_case_mode.md` | new spec, carries both rulings |
| `doc/xschem_man/developer_info.html` | shipped command reference: `case` in the list, `-case` on `raw read`, a `raw case` block |

`-case` is an **option**, extracted before the positionals are counted, so the
three shipped `raw read` forms are byte-identical and
`raw read f tran -case distinguish` cannot feed `-case` to `atof_spice()` as
`sweep1` (CS20/CS20b).

## The two rulings this item owed

**Xyce — ruled: accept the change, add NO Xyce-specific fold.** Full rationale
and what would reopen it: `doc/claude/specs/raw_case_mode.md` §5. Load-bearing
evidence: **there is no header identification of a Xyce raw to hang a fold on.**
Its header has `Title:`/`Date:` and no vendor tag; the `:` → `.` rewrite that
looks Xyce-shaped is applied **unconditionally to every raw**; and `sim_is_xyce`
(`src/xschem.tcl:2787`) does not read the file at all — it regexps `[xX]yce` out
of the *configured simulator command*, a property of the session, not of the
file being opened. A "Xyce fold" would be a heuristic gating a destructive
transform on files nobody has measured.

**`xschem raw case` get answers `1`/`0`, not a mode word.** The flag records
what the *lookup* does, not what the simulator did; answering `fold` would
assert a fact nobody established (`DECISIONS.md` B2b). It round-trips:
`xschem raw case [xschem raw case]` is accepted (CS26).

**`ngspice_data` keys stay folded, as instructed.** Both publish sites fold —
`update_op()` (`save.c`) and the cursor-B publisher (`callback.c`) — via one
`ngspice_data_key()`, so the rule is stated once. This is the interim
`DESIGN_REVISION.md` §6 requires; item 5b's lazy view supersedes it and this
item did **not** pre-empt that.

## Evidence

New suite: **47 checks, all pass** (`tests/headless/test_raw_case_mode.tcl`),
prefix `CS` — unused elsewhere; ids are per-file here, there is no global band.
Data: the two committed fixtures — **their first consumer**, as
`receipts/00a-suite-sweep.md` finding 1 predicted — plus an inline **ASCII AC**
raw, so no ngspice is needed. Load-bearing checks: `CS2b` (`tr_preserve.raw` lists `v(In) v(MidNode) i(Vs)`),
`CS8`–`CS12` (all **four** AC-derived names carry the case: `v(Out) ph(Out)
re(Out) im(Out)`, and no folded twin), `CS22`/`CS23d` (keys folded at **both**
publish sites, each as one conjunction with "capitals are stored" so neither
half can pass vacuously), `CS25b`/`CS25c` (a rename made only in memory is gone
after `raw case distinguish` — **that** is the proof of a re-read, not the flag).

### Sabotages — four, each restored from a byte-exact backup and re-run green

| # | sabotage | red |
|---|---|---|
| 1 | put `strtolower(varname)` back in `read_dataset()` | **11 checks**: CS2b, CS8, CS9, CS10, CS11, CS12, CS17b, CS22, **CS23d**, CS24b, CS25b |
| 2 | publish `raw->names[i]` unfolded in `update_op()` | CS22, CS23 |
| 3 | `raw case <mode>` flips the flag instead of re-reading | CS25b, CS25c |
| 4 | publish `raw->names[i]` unfolded in the cursor-B publisher | CS23d |

(The row above originally said 10 checks and omitted `CS23d`, the `callback.c`
cursor-B publisher. Corrected in the fix round after an independent re-run
measured 11.)

Sabotage 1 is also the **red-before-green** drive for the whole item: it is
exactly the pre-item-1 code. What stayed green under it — `CS3`
(`raw index v(MidNode)` == 2), because `get_raw_index()`'s lowercase rung finds
`v(midnode)` — is `DESIGN_REVISION.md` §1's point that the fold bought query
resolution, not display. Restores `md5sum -c`'d byte-identical.

## Suites

`GUI_GATE=1`, through `run_suites.sh` (arm: ATTACHED to the dev display `:99`),
checks in brackets:

```
raw_case_mode 47 · raw_read_dispatch 51 · raw_read_failure_0306 63
raw_ascii_point_bounds 90 · vcd_read 187 · vcd_time_base 124 · node_token_split 168
wave_cursor_crossdb 93 · backannotate_digital 81 · wave_viewer 400 · ase_cosim 342
cosim_golden_e2e 46 · ase_plot 150 · calc_skeleton 503 · wave_axis_zoom 370
```

All PASS. **`test_ase_core` FAILED 1/58 under the DISPLAY arm** — investigated,
**not a mover**: A/B'd against a pristine `HEAD` binary (the four touched files
replaced with `git show HEAD:` copies, rebuilt), which fails the identical
check, `UNEXPECTED ERROR: ase: design aselib/nfet_clean is not the current
schematic` — a DISPLAY-arm-only early abort in the netlist leg, no raw file
involved. `full_audit.sh` runs it `--nogui`, where it passes **74/74**.

## Audit

`GUI_GATE=1 tests/headless/full_audit.sh` on `:99`, saved as
`doc/claude/casemode_batch/audit_item01_2026-08-16.txt`:
**317 pass / 15 fail / 0 crash-timeout / 0 skip of 332.** Diffed by test NAME
and STATUS against `merge5_loose_ends/audit_item02_fixround_2026-08-16.txt`
(316/15/0/0 of 331). The **entire** diff:

    > test_raw_case_mode PASS      <- the new suite, the only row

**Zero rows moved, in either direction** — the contract
`receipts/00a-suite-sweep.md` set for this item, met exactly. The same 15 reds
by name (`test_ase_window`, `test_cadence_drag`, `test_ciw`, the four libmgr,
`test_lib_sweep`, `test_reopen_readonly`, `test_rotate_stretch_short_0104`,
`test_selflog_output`, `test_wave_markers`, `test_wave_sigbrowser_0312`,
`test_wave_sigbrowser_keys`). 331 → 332 because `full_audit.sh` globs
`test_*.tcl`.

## Declared limits

- **Item 1 alone leaves a lookup gap**, by design: a lowercase query against a
  mixed-case stored name misses until item 2 adds the folded rung — unreachable
  for any folding simulator, and inside this batch.
- `raw_read_from_attr()` (embedded `spice_data`) and `new_rawfile()` bypass the
  `raw read` arm, so they get `case_sensitive = 0` with no way to ask otherwise.
- A `raw case` set moves the database to the end of the registry (its
  `raw switch <index>` changes) and discards in-memory-only edits — both in the
  spec; the second is what CS25b measures.

---

# Fix round — 2026-08-16

Fifteen confirmed review findings across three lenses; ten distinct defects once
the duplicates are merged. Everything below is in addition to the item as first
landed; nothing above was reverted.

## Code fixes

### 1. The AC `v(` prefix test was case-sensitive (`src/save.c`) — MAJOR

`ph()`/`re()`/`im()` are derived off the node inside a `v(` prefix, recognised
with `strstr(varname, "v(") == varname`. That only ever matched because the
deleted fold had just lowercased `varname`. With the fold gone, an uppercase
`V(Out)` fell to the else-branch and derived **`ph(V(Out))`** — a different
*string*, not a differently-cased one — so `xschem raw index ph(Out)` answered
`-1`, and item 2's folded-alias rung could never have repaired it (folding
`ph(V(Out))` gives `ph(v(out))`, never `ph(out)`). Uppercase `V(` is exactly the
shape the item's own Xyce ruling reasons about.

Measured before: `frequency|…|V(Out)|ph(V(Out))|re(V(Out))|im(V(Out))`,
`raw index ph(Out)` = `-1`.
Measured after: `…|V(Out)|ph(Out)|re(Out)|im(Out)`, `raw index ph(Out)` = `5`.

Fixed with one case-blind `vpfx` test used by all three derivations. **`varname`
itself is untouched** — the magnitude name still carries the file's spelling.
Checks CS29–CS29d. Spec `raw_case_mode.md` §8 and a correction block in
`DESIGN_REVISION.md` §8, whose "no extra work" claim this refutes.

### 2. `xschem raw case <mode>` destroyed the database on a re-read it could not do (`src/scheduler.c`) — MAJOR

The registry dedups on filename + `sim_type`, so the old entry had to be deleted
before the same filename could be read again — putting the destruction ahead of
any knowledge that the read would work. An unreadable backing file annihilated
the loaded data and reported it as the string `"0"`. Three routes measured:
a deleted/replaced raw file, a synthetic `raw new` database whose "rawfile" is a
bare label, and — guaranteed — an embedded `spice_data` raw, because
`raw_read_from_attr()` `unlink()`s the temp file whose name it leaves behind.

Fixed by a `raw_case_reread()` helper that opens the file **before** it deletes
anything and returns a Tcl error naming the file, leaving the database exactly
as it was. It also now reports a genuine failure as a **Tcl error** instead of
`"0"`, which no caller was told to check. Checks CS30b–CS30e, CS31b–CS31c.

### 3. The re-read used the PROMOTED `sim_type` (`src/scheduler.c` + `src/xschem.h`) — MAJOR

`read_dataset()` rewrites a multi-point `Operating Point` raw's `sim_type` to
`"dc"`, and the type argument is matched against the `Plotname:` line — so
re-reading that file as `"dc"` can never match. Every ordinary multi-point `.op`
database failed the setter, and (before fix 2) was destroyed by it. Measured:
`raw read multiop.raw op` → 1, `raw sim_type` → `dc`, `raw case distinguish` →
`0`, `raw loaded` → `-1`.

Fixed with `Raw.req_sim_type`, the type the CALLER asked for, recorded by
`extra_rawfile()`'s two read arms and freed in `free_rawfile()`. `sim_type`
remains the key for finding the entry to delete; `req_sim_type` is the argument
to read with. Checks CS32–CS32e.

### 4. `-case` on an already-loaded database was the flag flip the design forbids (`src/scheduler.c`) — minor

`extra_rawfile()` only *switches* to a file it already holds, so
`raw read <same file> … -case <mode>` stamped the flag with nothing read.
Measured: an in-memory-only `raw rename` **survived** while the flag moved
`0 → 1` — the state `raw_case_mode.md` §3 rules out, reached by the other verb.
Fixed by detecting the switch (`xctx->extra_raw_n` did not grow) and routing it
through the same `raw_case_reread()`, so `-case` means one thing either way. A
first read is unaffected. Checks CS34–CS34d.

### 5. Two names differing only in case silently dropped one value (`src/save.c`, `src/callback.c`) — minor

The mandated interim fold of the `ngspice_data` publish keys re-created, on the
publish side, the silent collision the read-path fold was condemned for: under
`distinguish`, `v(EN)` and `v(en)` collapse onto one Tcl array key and the
second overwrote the first with no signal at all. Measured: `v(EN)` = 1.111
published, then lost; `$ngspice::ngspice_data(v(en))` = 2.222.

Fixed by moving both publish sites onto one `ngspice_data_publish()`:
**first writer wins** (matching the read side's `XINSERT_NOREPLACE`) and the
loser is named in a `dbg(0)` pointing at `xschem raw value`. It is *not*
published under a capitalised key — the array's keys stay folded. Both values
remain reachable from the database. Lossy is tolerable until item 5b; silent was
not. Checks CS36–CS36f, spec §4.

## Documentation fixes

- **The Xyce ruling's top reason rested on a false statement about the format.**
  It said the header "carries `Title:` and `Date:` and no vendor tag". It does
  carry one: `grep -a -m1 '^Command:'` on the batch's own fixtures gives
  `Command: ngspice-46+, Build Sun Aug 16 06:52:46 UTC 2026`, and the same line
  is in the two raws this fix round generated from the case-capable ngspice. The
  *true* statement is that `read_dataset()` never parses it (`grep -n Command
  src/save.c` is empty) and nobody has measured what Xyce writes there — so
  there is **no measured identification** to gate a fold on. §5 reason 1 now
  says that. **The ruling stands**: accept the change, add no Xyce-specific
  fold. Reason 2 was also corrected — it claimed item 2 removes the symptom, and
  it does not cover AC derived names; fix 1 above does, in the reader.
- **The declared lookup gap was understated.** It is not only a lowercase query
  that misses against a mixed-case raw: `get_raw_index()` mutates `inode` in
  place (upper, then lower) before building the `v(%s)` rung, so **every bare
  node name misses, including the correctly-spelled one.** Measured on
  `tr_preserve.raw`: `MidNode`, `midnode`, `MIDNODE`, `In`, `v(midnode)` all
  `-1`; only `v(MidNode)` answers. A bare token is the normal graph `node=`
  spelling. Spec §2 now says so and hands item 2 the acceptance check
  `xschem raw index MidNode == 2`, plus the bare device-vector shapes CS28 adds.
- **`scheduler.c`'s in-source `raw what …` reference** was left behind while
  `developer_info.html` was updated: `case` missing from the `what = …` list and
  no `-case` in the `raw read` synopsis. Both added, with a `raw case` entry and
  the spec pointer. `developer_info.html` also gained the new error contract.
- The sabotage-1 row in this receipt said 10 red checks; the measured set is 11
  (`CS23d` was missing). Corrected in place above.

## Fix-round evidence

**81 checks** (was 47; 34 added), `RESULT: ALL PASS`, true headless, no
simulator required. **Every one of the 81 was driven red by a sabotage aimed at
it and green again after a byte-exact restore** — 35 mutations in this round,
each its own build. Two worth naming:

- `N3` (delete the file-open probe, i.e. destroy-then-ask) reds CS30c, CS30d,
  CS30e, CS31c — the database really is gone without it.
- `M5` (flip the flag instead of re-reading) still reds CS25b/CS25c after the
  refactor into `raw_case_reread()`, so the contract check survived the fix.

`CS0`'s guard was re-verified by moving `tr_preserve.raw` out of the tree:
`RESULT: 1 FAILED (0 passed)`, and it FAILS rather than printing any `SKIP`
substring. Fixture restored, `git status` clean.

### Real end-to-end, not unit checks

Fresh raws from the case-capable ngspice
(`/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice -b -D casemode=preserve`,
rc=0 both): a tran raw with `v(In) v(MidNode) i(Vs)` and an **AC** raw with the
full mixed-case quad. Driven in a REAL GUI xschem on the dev display `:99`
through `devdisplay.sh exec`:

```
E1|list|time|v(In)|v(MidNode)|i(Vs)          E1|idx v(MidNode)|2
E2|list|frequency|…|v(Out)|ph(Out)|re(Out)|im(Out)|i(Vs)|ph(i(Vs))|…
E2|idx ph(Out)|9  re(Out)=10  im(Out)=11
E3|list|frequency|…|V(Out)|ph(Out)|re(Out)|im(Out)     E3|idx ph(Out)|5
E4|caseset err|1|xschem raw case: cannot re-read "…/vanish.raw":
                 the database is left as it was
E4|db after|time|v(In)|v(MidNode)|i(Vs)      <- survived
E5|ngspice_data keys|i(vs) {n\ points} {n\ vars} time v(in) v(midnode)
```

Note `E2`: a name with no `v(` prefix at all (`i(Vs)`) still takes the
else-branch and derives `ph(i(Vs))`, unchanged — the case-blind test did not
widen what counts as a prefix.

A real graph rect on the uppercase-prefix AC database, `node="V(Out)\nph(Out)"`,
renders both legends with their capitals and **draws the `ph(Out)` trace** — the
name that answered `-1` before this fix. Screenshot taken on `:99`. Not a pixel
deliverable: the payload is what `raw list` / `get_raw_index` / the published
keys contain, all machine-checked above.

### Suites (fix round)

`GUI_GATE=1`, through `run_suites.sh`, arm ATTACHED to the dev display `:99`:

```
PASS | test_raw_case_mode          ALL PASS (81 checks)
PASS | test_raw_read_dispatch      ALL PASS (51)
PASS | test_raw_read_failure_0306  ALL PASS (63)
PASS | test_raw_ascii_point_bounds ALL PASS (90)
PASS | test_vcd_read               ALL PASS (187)
PASS | test_vcd_time_base          ALL PASS (124)
PASS | test_node_token_split       ALL PASS (168)
PASS | test_wave_cursor_crossdb    ALL PASS (93)
PASS | test_backannotate_digital   ALL PASS (81)          -> 9/9
PASS | test_wave_viewer            ALL PASS (400)
PASS | test_ase_cosim              ALL PASS (342)
PASS | test_cosim_golden_e2e       ALL PASS (46)
PASS | test_ase_plot               ALL PASS (150)
PASS | test_calc_skeleton          ALL PASS (503)
PASS | test_wave_axis_zoom         ALL PASS (370)
FAIL | test_ase_core               1 FAILED (57 passed)   -> 6/7
```

`test_ase_core`'s one failure is the DISPLAY-arm-only, A/B-confirmed
pre-existing one recorded above; `full_audit` runs it `--nogui` at 74/74 and
scores it PASS.

A VCD database was driven through the changed path too (`raw case` there was
never covered by the suite): `raw read t.vcd vcd` → `time|TOP.Clk|TOP.DataOut`,
an in-memory `raw rename TOP.Clk ZZ_MEM` is **discarded** by
`raw case distinguish` (so it really re-read a non-spice database), and
`raw read <same> vcd -case 0` on the already-loaded one now re-reads as well.

## Audit (fix round)

`GUI_GATE=1 tests/headless/full_audit.sh` on `:99`, saved as
`doc/claude/casemode_batch/audit_item01_fixround_2026-08-16.txt`:
**317 pass / 15 fail / 0 crash-timeout / 0 skip of 332.**
`SCRATCH: 0 leaked dir(s)`, `TREE: 0 appeared 0 vanished`, `WIREEDIT: PASS`.

Diffed by test NAME and STATUS against
`merge5_loose_ends/audit_item02_fixround_2026-08-16.txt` (316/15/0/0 of 331) —
the **entire** diff, in both directions:

    > test_raw_case_mode PASS

**Zero statuses moved.** Diffed again against this item's own pre-fix audit
(`audit_item01_2026-08-16.txt`): **empty, zero rows in either direction** — the
fix round moved nothing at all. The 15 reds are the same 15 by name.

## Declared limits (fix round)

- The lookup gap is now stated precisely in the spec: **every bare node name**
  misses against a mixed-case raw, not only a lowercase one. Item 2 owes
  `xschem raw index MidNode == 2` on `tr_preserve.raw` and the CS28 bare shapes.
- `ngspice_data` still cannot represent two names differing only in case. The
  fix makes the loss **deterministic and loud**, not absent; item 5b's lazy view
  is what removes it.
- `raw_case_reread()` probes with an `fopen`, not a trial parse. A file that is
  readable but has become unparseable between the read and the set still loses
  the database — and reports it as a Tcl error rather than `0`. A trial parse
  was rejected: `raw_read()` on success runs `set_modify(-2)` and
  `backannotate_at_cursor_b_pos()`, so probing with one has side effects, and
  `read_rawfile_by_type()` refuses a non-`xctx->raw` destination for the VCD and
  table readers, so it could not cover the non-spice databases at all.
- `raw_read_from_attr()` (embedded `spice_data`) and `new_rawfile()` still leave
  `req_sim_type` NULL and `case_sensitive` 0 with no way to ask otherwise. They
  are now *refused* rather than destroyed.
- The error text from a `-case` failure on the `raw read` verb reads
  `xschem raw case: …`, because both verbs share `raw_case_reread()`.

