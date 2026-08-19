# Next session — OP annotation on the schematic, in atomic steps

Paste everything below the line as the opening prompt of a fresh session.

Every measurement quoted below was taken on branch `annotate` (branched from
`fluid-editing`) with the installed `/usr/bin/ngspice` and the in-tree
`src/xschem`. Re-run the probes before trusting a number if more has landed.

---

Implement `doc/claude/specs/op_annotation.md`. **Read that spec in full first** —
especially §3 (the three measured ngspice rules), §4.2 (the PDK descriptor),
§5 (invariants I1–I7) and §6 (landmines).

Also read, before touching anything:

- `ihp-sg13g2/sg13g2_procs.tcl` lines **304–505** — the working single-PDK
  prototype. `sg13g2_write_save_lines`, `sg13g2_sch_expand`/`_hier_sch_expand`,
  `sg13g2_save_params`, `sg13g2_display_fet_params`, `sg13g2_raw_or_double`.
  This is not inspiration, it is the reference implementation to generalize;
  ported line by line it removes most of the risk from S3 and S5.
- `ihp-sg13g2/xschem_libs/sg13g2_pr/annotate_fet_params/symbol/annotate_fet_params.sym`
  — the carrier symbol, 11 lines.
- `ihp-sg13g2/sg13g2_procs.tcl` lines **585–655** — how the IHP menu wires all of
  it up, including the "place annotator pre-filled from selection" idiom.
- `doc/claude/code_analysis/waveform_subsystem_reference.md` §6.

Branch is `annotate`. Number new issues from **0418** (0417 is the highest taken).

---

## Ground rules for this work

- **I1 above everything.** One name builder (`op_annot::vector`), two consumers
  (save cards, display). The moment they diverge the failure is silent.
- **I3.** A vector that is not in the raw renders **blank**. Not `0`, not `NaN`
  on screen, not the previous run's number. `save.c`'s RULING D5-1 is the
  precedent and the reason.
- Steps S1–S6 are **pure Tcl and data**. No C, no rebuild. Land them first; they
  are what turns tb_bandgap's `-` into numbers.
- Do not start S9 before S7 lands — the overlay with no mask to gate it is a
  screenful of text nobody can turn off.
- Per CLAUDE.md: do not run `make` while subagents are fanned out (~7.8 GB box).

---

## S1 — the core namespace and the name builder ✅ LANDED (2026-08-16)

Delivered: `src/op_annot.tcl` (`register` / `descriptor` / `type` / `devpath` /
`vector`), sourced at `src/xschem.tcl:14548`, listed in `src/Makefile.in`'s
`install_shares`, with `tests/headless/test_op_annot.tcl` — **RESULT: ALL PASS
(32 checks)**. All three acceptance goldens reproduce byte for byte. Tiers T1/T2
and eleven T3 suites are identical to the branch baseline (3 pre-existing T1
FAILs, all explained: issues 0420 and 0421).

**Read the thirteen bullets under "What later steps must change" before starting
any step** — bullets 1-5 were measured by S1, bullets 6-13 by S2 (they live under
the S2 section, since that is where they were found). Between them they correct
this plan and the spec on nine points, several of which change what a later step
has to do. Bullets **6, 7 and 8 are binding on S3**; **9, 10 on S5**; **11 on
S4**; and the open question in the S2 section is **S4/S5's to answer**.

**Files:** new `src/op_annot.tcl`; sourced from `src/xschem.tcl` alongside the
other loadable helpers.

**Deliver:**

```tcl
namespace eval op_annot {}
op_annot::register <symbol-type> <dict>     ;# stores/overrides a descriptor
op_annot::descriptor <symbol-type>          ;# -> dict or {}
op_annot::devpath <instname>                ;# -> "@m.x1.xm1.msky130_fd_pr__nfet_01v8"
op_annot::vector <instname> <param> <kind>  ;# -> "i(...)" / bare / "v(...)"
```

`devpath` expands the descriptor's `devpath` template with
`xschem translate <inst> <template>` (so `@name`, `@model`, `@spiceprefix` work)
and `$path` from `xschem get sim_sch_path`; or calls `devproc` when the
descriptor has one. `vector` applies the kind wrapper (`0` → `i(…[p])`, `1` →
bare `…[p]`, `2` → `v(…[p])`) — the `get_fqdevice()` convention, spec §3 R3.

**Acceptance:** ~~with no schematic loaded, `op_annot::register` + a stubbed
instance~~ — **measured false, corrected:** the goldens need a **real loaded
instance**. `xschem translate` raises when the instance does not exist, and
`xschem translate -1 <tmpl>` substitutes every token with its own *name*
(`@spiceprefix` → `spiceprefix`), yielding a plausible-looking wrong string. The
S1 suite therefore builds a 3-file fixture in a scratch dir and does
`load` / `select instance 0` / `descend 1 2` to reach `sim_sch_path` `x1.`.
Golden strings to match, measured from real raw headers:

```
sky130 nfet_01v8, inst M1 (spiceprefix X) at path x1. :
  gm    -> @m.x1.xm1.msky130_fd_pr__nfet_01v8[gm]
  id    -> i(@m.x1.xm1.msky130_fd_pr__nfet_01v8[id])
  vdsat -> v(@m.x1.xm1.msky130_fd_pr__nfet_01v8[vdsat])
```

**Risk:** low. **Blocks:** everything.

### What later steps must change — measured during S1

1. **S3/S4: a save card is BARE. Never `op_annot::vector`.** The single most
   important thing on this page. Measured on `ngspice-42`, one card per deck:
   `.save i(@m.xm1.m1[id])` produces **no vector and no diagnostic**, while
   `.save @m.xm1.m1[id]` produces `i(@m.xm1.m1[id])`. ngspice applies the
   wrapper itself from the parameter's type. So the emitter writes
   `[op_annot::devpath $inst][param]` and `vector` is the **read** shape only.
   Spec rule **R4** and the restated **I1** carry the table. The wording in the
   original plan ("one builder `op_annot::vector`, two consumers") points S3
   straight at the broken form.
2. **S3/S4/S5: a wrong device name yields `0.0`, not a blank.** A save card for
   a device that is not in the netlist still writes a full column under exactly
   the requested name, holding `0.0`, with only `Warning: unrecognized variable`
   on stderr. So the S4 raw-header name diff — billed here as "the single most
   valuable test in this plan" — **cannot detect a wrong descriptor**, because
   the raw contains the wrong name too. Keep the diff (it proves the two sides
   agree) and add: capture ngspice's stderr warnings and surface them, and
   assert the values are not all zero. Spec landmine 9.
3. ~~**S2: copy the spec's §4.2 descriptors, they are now correct.**~~
   **DONE, and the "they are now correct" half was wrong** — S1 fixed the
   *escaping* (issue 0422) but not the *content*. S2 measured four content
   errors and §4.2 has been rewritten to what actually shipped: sky130 needs a
   **devproc**, not a template (its single template mismatches 35 of 119
   prototype cards — the `g5v0d16v0` and `20v0` families); **`pmos` must be
   registered too** (the prototypes branch on `regexp {[pn]mos}` while
   `op_annot`'s key is an exact array index, so 17+9+4 PMOS symbols would have
   gone unannotated in silence); `vertical_npn` has **thirteen** parameters, not
   six; and `pinexpr` must use the shipped `expr(@#N:spice_get_voltage …)`
   spelling. The escaping rule and the "do not port `getprop … spiceprefix`"
   rule both held — see finding 10 for the three shipped cells that prove the
   second. Issue **0425** is now **decided and implemented** (the `match` key,
   finding 6); spec §8's *one interpreter per PDK* still stands.
4. **S5: the slots are there and the readers must `catch`.** `derived` and
   `pinexpr` are stored verbatim by `register`, so S5 adds no schema. But
   `xschem raw value <v> -1` **raises** `No raw file loaded` rather than
   returning empty, and `sim_sch_path` is read live on every `devpath` call and
   shifts with the raw's load level (landmine 4) — a raw loaded at a different
   level silently blanks every annotation.
5. **Any step that adds a new `.tcl` must re-run `./configure`.** `src/Makefile`
   is generated, gitignored and never self-regenerates, so a new
   `install_shares` entry leaves `make install` stale — and an installed
   `xschem.tcl` sourcing a file that is not installed **segfaults at startup**
   (exit 139), it does not degrade. Issues **0424** (the live instance of this,
   still open on this tree) and **0423** (why a Tcl error becomes a SIGSEGV).

Smaller findings that cost time if rediscovered: `getprop symbol <cell> type`
**raises** `Symbol not found` for a cell name without `.sym` (so `op_annot::type`
reads `getprop instance <n> cell::type` instead — one call, no raise);
`op_annot::register` from `~/.xschem/xschemrc` fails, because xschemrc is sourced
before `xschem.tcl` (I5 corrected — use a `--script` rc); and `xschem translate`
runs a trailing `expr()`/`tcleval()` pass, so a descriptor template is executable
and must stay plain `@`-token text.

---

## S2 — the three PDK descriptors ✅ DONE (status **E** — one question below)

**Files:** `sky130A/sky130_procs.tcl`, `gf180mcuD/gf180_procs.tcl`,
`ihp-sg13g2/sg13g2_procs.tcl` (registrations appended; the existing prototype
procs left byte-for-byte untouched — they are the acceptance oracle),
`src/op_annot.tcl` (the `match` key), `tests/headless/test_op_annot.tcl`
(Section P, +33 checks).

**Landed.** Seven registrations: sky130 `nmos`/`pmos` (a **devproc**),
gf180 `nmos`/`pmos` (template), IHP `nmos`/`pmos` (template) and IHP
`vertical_npn` (a devproc for the `_5t` strip). Issue **0425** ratified and
implemented as an optional `match` glob list on the descriptor.

**Acceptance, met — but note the acceptance wording on this page was wrong.**
It said "`op_annot::vector` reproduces every line", which is measurably
impossible: a save card is **bare** (finding 1 above, rule R4), so a
vector-based diff would mismatch 30 of the 46 IHP cards by construction. The
real diff is `devpath+[param]`, bare, filtered on `[string match ".save *"]`
because the oracle's first two lines are a comment and a blank. It is empty:
IHP **49/49 loadable `sg13g2_tests` cells** (26 with cards, `IHP_testcases` at
405 cards, the `_5t` HBT cells at 26 each), sky130 `test_nmos` **119/119**.

> **⚠ THE ONE OPEN QUESTION (why S2 is E, and it lands on S4/S5).** sky130's
> `params` carry `cgso` and `cgdo`. **Measured on ngspice-42 against the real
> sky130 models: both are invalid vectors** (`cgs`/`cgd` are the valid
> spellings), and **one invalid `.save` card makes ngspice write no raw file at
> all** in the `.control … write <cell>.raw … .endc` idiom every shipped bench
> uses — `rc=0`, one `checkvalid` warning, no file. They are registered because
> the acceptance above *demanded* byte-equality with `sky130_write_save_lines`,
> which has emitted them for years. **Correcting them breaks that acceptance.**
> Issue **0429**. Answer needed: correct the parameters (and re-baseline both the
> prototype and test row P3), or keep bug-compatibility until S5 deletes the
> prototypes?

**Risk:** was billed low. It was low for the *mechanism* and not low for the
*data* — every card matched the prototype and the prototype was wrong.

### What S2 changed for later steps — measured

6. **S3/S5: a non-empty `descriptor` NO LONGER implies a non-empty `devpath`.**
   The 0425 ruling added an optional `match` glob list (`{*sky130_fd_pr/*}`,
   `{*gf180mcu_pr/*}`, `{*sg13g2_pr/*}`) checked against
   `getprop instance <n> cell::name`. A device the descriptor does not claim gets
   `{}`. **Skip on a blank `devpath`, never on a blank `descriptor`.** Grounded
   in I3 via landmine 9 (re-measured: a nonexistent device name yields
   `… admittance dims=0`, no stderr warning, and `xschem raw value` → `0`).
   Descriptors with no `match` key stay permissive, so S1's 32 rows and a user's
   I5 override are unaffected. Accepted residual: two PDKs in one interpreter
   still lose the first registration — it now degrades to **blank** rather than
   to a wrong name.
7. **S3: I2 (`save all`) and S2's byte-diff acceptance are in direct tension —
   resolve it, do not inherit it.** The prototypes emit bare `.save` cards and
   **no `save all`**, so a block reproducing them byte for byte violates I2 (rule
   R2: any explicit save cancels save-everything, and every node voltage
   disappears). The byte-diff was right for a *name builder* and is wrong for a
   *block emitter*. Assert I2 on the block; keep the byte-diff on card names only.
8. **S3: the I6 reference does not satisfy I6.** `sky130_save_fet_params` on the
   shipped `sky130_tests/test_generators` raises `Symbol not found` and leaves
   `no_draw=1 keep_symbols=1` set — the restore is on the normal path, there is
   no `catch`/`finally`, and `sg13g2_hier_sch_expand` has the same shape. Wrap
   the walk in `catch`, restore unconditionally, re-raise; and **force a raise in
   the test** rather than asserting only on the happy path. Issue **0431**.
9. **S5: `pinexpr` is `expr(@#1:spice_get_voltage - @#2:spice_get_voltage)`**, the
   shipped spelling (`nfet_01v8.sym:65-66`), not §4.2's old `{@#1 - @#2}`
   shorthand — which has no evaluator anywhere in the tree. **⚠ With no raw
   loaded it translates to the literal `" - "`**, so S5 must test
   `string is double -strict` and blank (I3). Pin order D=0 G=1 S=2 B=3.
   Also: `derived` rows are **self-contained** (each `ft` inlines its own
   capacitance sum, no derived label shadows a param), so S5 needs no
   evaluation-order contract. **Deferred user-visible consequence, S5/S6's to
   answer:** an IHP FET block will now show `cgg` (raw) *and* `cgg_tot`, where
   `sg13g2_display_fet_params` shows one `cgg` holding the sum.
   **✅ ANSWERED BY S5, AND IT IS ONE OF THE TWO REASONS S5 IS STATUS E.** The
   IHP FET block is **13 rows** against the prototype's 10 (`vertical_npn`: 16),
   `cgg` names the raw vector and `cgg_tot` the sum. A human must ratify or
   relabel. **⚠ AND THE FIRST SENTENCE OF THIS BULLET IS NOW WRONG:** the
   REGISTERED spelling was missing the space before `)` that the shipped symbol
   has, which `token.c:24` requires (`)` does not terminate an @-token), so
   `vgs`/`vds` were permanently blank on sky130 and gf180. Fixed at S5, one space
   per line, issue **0444** — and that edit is outside S5's Files cell, which is
   the other reason S5 is E. **Do not "tidy" that space away.**
10. **S5: deleting the prototypes also fixes a live bug.** They read the prefix
    with `getprop instance … spiceprefix`, which is empty when the token lives
    only in the symbol `template=`. On 3 of 45 shipped sky130 cells
    (`nfet_test_claude`, `test_nfet_TRAN`, `test_nfet_final`) the prototype emits
    `@m.m1.…` where the netlist says `XM1` — a name that names nothing, i.e. a
    fabricated `0.0` per landmine 9. `op_annot::devpath` uses `translate` and is
    correct. Issue **0430**. Corollary for anyone quoting S2: "byte-identical,
    lost nothing" is tree-wide true for **IHP only**.
    **⚠ S5 DID NOT DELETE THE PROTOTYPES AND COULD NOT** — deletion dangles three
    shipped annotator symbols into `invalid command name` inside a draw path and
    destroys the acceptance oracle for four green rows, because the neutral
    carrier is S6 and the neutral emitter is S3 (reverted three times). **0430
    stays open and this bullet moves to whichever step lands both.** Measured at
    S5 and worth knowing: on a correct raw, in the same process where
    `op_annot::text` renders every value, `sky130_display_fet_params` returns
    eight BLANK lines and no `id` row at all — builder #3 is already dead, which
    is invariant I1's failure mode live in the tree.
11. **S4: build the ngspice round trip on sky130 or gf180 — IHP cannot be
    simulated on this box.** `pre_osdi ihp-sg13g2/osdi/psp103.osdi` fails on
    ngspice-42 (the vendored OSDI targets v0.4, ngspice-42 supports v0.3). And
    **add the check S2 could not have**: assert every registered parameter yields
    a real vector in a real raw. S2's acceptance was a string diff between two
    pieces of our own code, which is exactly the shape of check that cannot catch
    issue 0429. Note also that S2 could only validate `kind` where ngspice runs —
    on sky130/gf180 it matched exactly (`i(…[id])`, `v(…[vth])`, bare `…[gm]`);
    IHP's ten FET and thirteen NPN kinds are **unvalidated against a simulator**.
12. **Anyone touching a PDK procs file: registrations go at the END, guarded by
    `[info commands ::op_annot::register] ne {}`.** A raise inside a procs file
    prints `Tcl_AppInit() error: can not execute <rc>`, **abandons the rest of
    the workarea rc** (the PDK menu, `user_startup_commands`, the library-manager
    autostart) and still exits 0. Issue 0424 makes `invalid command name` live in
    an installed tree. Do **not** `catch` `register`'s own malformed-dict raise —
    that is an rc typo and must stay loud. Verified under xvfb: all three
    `cadence_style_rc` still source clean and still define their menus.
13. **Smaller, but each cost time:** `xschem` honours only **one** `--script`
    flag (two silently drops the first); the `match` ruling introduces a new
    silent-blank mode for a PDK symbol **copied into a project library**
    (cell name `mylib/nfet_01v8.sym` matches no glob → no annotation, no
    diagnostic — recorded in 0425, worth an `op_annot::why <inst>` diagnostic in
    a later step); and `xschem raw value <v> -1` returned `0` for a valid vector
    when the raw was not tied to the schematic (`xschem raw loaded` = 0) while
    index `0` returned the true value — an I3 hazard sitting in S5/S6's path.

### What S3's REVERTED attempt proved — measured, and binding on the retry

**S3 was implemented in full, passed 85 checks and 11 sabotage variants, and was
then REVERTED.** The machinery was right; the *names it emits* are wrong in two
reachable states, both silent, both with zero coverage. The whole attempt is
preserved as `doc/claude/issues/0436-attempt-1-reverted.patch` (1032 lines,
applies cleanly to `2be60ece`) — **start from that patch, do not retype it.**
Everything below is what the retry must add to it.

14. **⚠ S3/S4/S5: `op_annot::devpath` answers a RAW-RELATIVE name. A save card
    needs a DECK-ABSOLUTE one. These are two different jobs and I1's "one
    builder" does not settle which basis to use.** This is the finding that
    reverted S3 and it is the single most important line on this page for the
    retry. Confirmed in the C, not just measured: `save.c:1260/1410/2153` bind
    `raw->schname` to `xctx->sch[xctx->currsch]` — **whatever cell the user was
    standing in when the raw was loaded**; `draw.c:2831-2838` `sch_waves_loaded()`
    then re-matches that filename against every level *as the walk descends*; and
    `scheduler.c:5150` `sim_sch_path` **strips every path component above the
    matched level**. So a raw loaded one level down makes two different instances
    of the same subcircuit collapse to the *same* device path. Measured on a
    3-level fixture: 8 cards, only **5 unique**, `.save @m.xa[1].xmleaf.…` for
    both `x1`'s and `x3`'s leaf where the netlist says `x1.xa[1].xmleaf` and
    `x3.xa[1].xmleaf`. `last_warnings` was **empty**. Controls: no raw → 8/8
    unique and correct; raw loaded at the top → 8/8 correct. **Two clicks
    reproduce it**: the menu entry immediately *above* the new one ("Annotate
    Operating Point into schematic") calls `xschem annotate_op` at the current
    level, and the next entry is the writer. The retry needs an explicit basis —
    `op_annot::devpath <inst> ?basis?` with `absolute` for save cards is the
    shape that keeps one builder — **not** path arithmetic in the walk, which
    would recreate the second builder I1 forbids and is what the prototypes'
    `startpath` was. Issue **0436**. Note the prototypes are *immune* to this:
    they use `xschem get sch_path`, which no raw can perturb.
15. **⚠ S3/S4: the walk must not emit cards for instances that are not in the
    netlist.** Measured: an instance carrying the standard `spice_ignore=true` is
    **absent from `xschem netlist`** (only `XMOK` appears) yet still gets a full
    card set, silently. Combined with bullet 16 that means **one `spice_ignore`
    device anywhere in a design makes the generated `.save` file kill the
    simulation it was generated for**. `spice_ignore=short` and `only_toplevel`
    are the same class and were not measured. The suite has no `spice_ignore`
    row anywhere (`grep -c` = 0). Issue **0437**.
16. **⚠ ONE bad card costs the WHOLE raw, and which failure you get depends on
    the invocation idiom — the spec's landmine 9 and issue 0429 are both true and
    describe different idioms.** Re-measured on both binaries: under
    `.control … write out.raw … .endc` — **the idiom every shipped PDK bench
    uses** — one bogus card gives `Warning from checkvalid` and **NO RAW FILE AT
    ALL**. Under `ngspice -b -r out.raw` the same card gives
    `Warning: unrecognized variable` plus a fabricated `0.0` column (landmine 9's
    behaviour). So bullet 2 above is right only for `-b -r`; for the benches, a
    bad card is not a wrong number, it is *no data*. Issue **0434**.
17. **`.save all`, never the bare `save all` — the wording in the S3 cell below
    and in spec I2 is a trap that has now been measured three times
    independently.** A bare deck-level `save all` is `Error on line N … Unable
    to find definition of model` on ngspice-42 **and** 46+ (it parses as an
    `s`-prefixed switch instance) and **no raw file is written** — strictly worse
    than emitting nothing, because it removes the whole raw rather than only the
    node voltages R2 is about. The dot-card works on both. Spec §5 I2 has been
    corrected; this bullet is here because the S3 cell's own wording still reads
    "Prepend `save all`" in every older copy of this plan.
18. **`xschem get no_undo` DOES NOT EXIST** (setter only, `scheduler.c:11958`);
    it returns `{}` whether the flag is 0 or 1. So a quarter of the S3 acceptance
    row below ("`no_undo` back to its entry value") is **unwritable as a flag
    read** — as `== 0` it fails, as "equals the entry value" it passes vacuously
    against `{}`. The reverted attempt restored it to 0 and probed the flag's
    *effect* (`push_undo` → delete → `undo`; `{2 1 2}` live vs `{2 1 1}` dead, so
    the probe provably discriminates). **Residual that probe cannot see:** a
    caller who wraps the walk in its own `no_undo 1` scope has it silently
    disarmed — measured `{3 2 2}` before, `{3 2 3}` after. **S4's `render_deck`
    is exactly such a caller.** Issue **0432**; a 4-line getter beside
    `scheduler.c:4898` fixes it but makes the step a build step.
19. **Do not port `if {$res} … else {go_back 2}` from either prototype.**
    `xschem descend` returns 0 in two classes (`actions.c:4055-4065`, issue 0250):
    a refusal *before* descending leaves `currsch` **unchanged**, a blank/missing
    schematic leaves it **already incremented**. The prototypes' unconditional
    `go_back` is right for the second and pops a level it never pushed for the
    first — invisible at the top level, but one level down it corrupts `sch_path`
    for the rest of the walk and the walk re-visits levels, emitting **duplicate**
    cards. Drive off `xschem get currsch` before/after plus `descend_error`
    (empty on success — `descend_clear_error()`, `actions.c:3855`). The reverted
    patch already does this correctly and its `_descended` seam is worth keeping.
    Issue **0433**; both shipped prototypes still carry the bug.
20. **The walk self-logs and must suppress itself.** `descend`/`go_back` self-log
    (`actions.c:4073`, `:4229`); a walk over a real design floods a log whose
    contract is *replayable user edits*. `xschem log_action -suppress push|pop`
    (`scheduler.c:7795`) is the re-entrant guard; the pop belongs in the same
    unconditional restore block as the flags, because an unpopped scope silences
    the user's log for the rest of the session. **⚠ Measured coverage trap:** a
    test for this is **dark** under `--nolog` — dropping the pop still gave
    `RESULT: ALL PASS`. It only reddens under
    `GUI_GATE=0 xvfb-run -a … --pipe -q --logdir <dir>`. **Ship both invocations
    or the row is decoration.**
21. **`getprop symbol <cell> type` RAISES for generator cells** (6 of the 14
    instances of `sky130_tests/test_generators`) and is the literal trigger of
    0431. Use `op_annot::type` / `getprop instance <n> cell::type`, which raises
    zero times on the same loop and resolves for a vector instance name too.
22. **Smaller, each cost this crew time:** the `sky130A/cadence_style_rc`
    workarea rc needs Tk and dies under `--nogui` with
    `invalid command name "bind"`, so the library path is never set and **every
    sky130 symbol fails to resolve** — a walk over a real sky130 design under
    `--nogui` returns 0 cards as an *artefact*, not a measurement; build fixtures
    self-containedly or launch under xvfb with the real rc. `xschem set <var>`
    silently accepts any unknown variable sorting before `n` (issue **0435**).
    `test_descend_goback_selflog` self-skips under `--nolog`;
    `test_context_menu_descend_refusal_0249` cannot run under `--nogui` at all
    (`invalid command name "focus"`) — neither is a failure.
23. **ENVIRONMENT:** `/usr/local/bin/ngspice` (46+) was installed 2026-08-16 and
    now **shadows** the `/usr/bin/ngspice` (42) that every measurement in this
    plan and the spec quotes. All rules above were re-measured on both and are
    identical, but **S4 must pin the binary path** rather than say `ngspice`.

---

## S3 — hierarchy walk and save-card generation

> **STATUS: ATTEMPTED TWICE (2026-08-16), REVERTED TWICE, NOT DONE.**
> Attempt 2 was green at **96 checks / 8 sabotage variants / tiers clean** and
> was refuted by its adversary pass on ONE of its three mandated fixes. Start
> from **`doc/claude/issues/0442-attempt-2-reverted.patch`** — verified
> `git apply --check` rc=0 against the post-revert tree, and round-tripped
> (apply → `ALL PASS (96 checks)`, revert → `ALL PASS (65 checks)`).
>
> **WHAT ATTEMPT 2 GOT RIGHT — DO NOT RE-LITIGATE, DO NOT RE-DERIVE:**
> * **The basis fix (0436) is CORRECT and survived six independent adversary
>   attack lines.** Four named seams (`_check_basis`, `_pathfor`, `_subst_path`,
>   `_devproc_call`), `devpath <inst> ?basis? ?root?`, `deck` = `sch_path` minus
>   the walk-entry root, `@path` `string map`ped away before `translate` sees it.
>   Ruling **D2**: the deck basis is **ENTRY-RELATIVE**, not level-0-absolute —
>   settled by measuring that `xschem netlist` from a descended cell makes THAT
>   cell the deck top. Issue 0436's own fix sketch (level-0) is the rejected
>   alternative.
> * **I6** held against a forced raise below entry, a descended entry, and the
>   log-suppress scope on the error path. The `_descended` class-1/class-2 split
>   (0433) is right.
> * **The cgso/cgdo ruling (0429, D8) LANDED AND IS IN THE TREE** — the only part
>   of attempt 2 that was kept, because it is in `sky130A/sky130_procs.tcl`,
>   depends on nothing reverted, and the brief forbade deferring it again.
>   Guarded by goldens **P2 and P9** (two, not the three the report claimed —
>   P25 does not fire). **Do not re-decide it. Do not re-implement it.**
>
> **WHAT REFUTED IT — issue 0442, and it is the whole of attempt 3's job:**
> The not-in-the-netlist filter implements **three** of the SPICE netlister's
> **seven** drop classes. Missing, all symbol-level, all in `spice_netlist.c`:
> empty `format` (`:639` — the instance vanishes from the deck entirely),
> `default_schematic=ignore` (`:643`), `spice_sym_def` (`:665`), `spice_stop=true`
> (`:635`+`:695`, `.subckt` emitted **empty**). Measured: cards were emitted for
> three devices that are nowhere in the generated deck, and
> `write_save_file` wrote that block to the file the new menu item hands the user.
> Severity is not cosmetic — re-measured on **both** installed ngspice binaries
> under the dot-card idiom the feature generates, **either** bad-card shape (a
> missing instance prefix, or a missing device inside a present instance) makes
> ngspice write **no raw file at all** at rc=0. That is the same criterion ruling
> D8 used to delete `cgso`/`cgdo`, so the step deleted a parameter to prevent a
> harm while shipping a broader instance of it.
>
> **WHY 96 GREEN CHECKS MISSED IT, AND THE ONE RULE THAT WOULD HAVE CAUGHT IT:**
> Row S31 cross-checks the cards against `xschem netlist` — the right oracle, the
> exact acceptance 0437 asked for. Its **fixture is flat**, and its only variants
> are the classes already handled, so it could not fail. The tell was visible in
> Verify-B: `filter_skips_cards_but_still_descends` was **predicted to red S31 and
> did not**. **A predicted red that does not appear is a fixture defect, not a
> footnote** — fix it before landing. This is now spec landmine 11.
>
> **ATTEMPT 3, CONCRETELY:** re-apply the patch; extend `_netlisted` with the four
> classes (all probed as `getprop instance <n> cell::<attr>`); make `_netlisted`
> and `_descendable` genuinely diverge (`spice_sym_def`/`spice_stop` drop the
> *subtree* while the instance call survives — attempt 2 made them aliases, which
> is why D6 has only one guardian, S28); give S31 a **hierarchical** fixture
> carrying all seven; and correct the two false comments in `op_annot.tcl` (the
> "EMITS ONLY WHAT THE NETLISTER WOULD" box and the `0.0`-column harm model,
> which is wrong under the shipped idiom).
> **Weigh first, because this filter has now drifted twice:** derive the device
> set from `xschem netlist` output, or expose `skip_instance()` (netlist.c:1245)
> to Tcl, instead of maintaining a second copy of the netlister's rules in Tcl.
> The C is the only thing that knows all seven — and it also branches on
> `xctx->netlist_type`, which no Tcl copy has ever consulted.

**Files:** `src/op_annot.tcl`.

Port `sg13g2_sch_expand` / `sg13g2_hier_sch_expand` into
`op_annot::save_cards {}`, de-prefixed and descriptor-driven: visit every
instance, look up its symbol `type` (use `op_annot::type`), emit one save card
per `params` entry.

> **⚠ The card is `[op_annot::devpath $inst][param]` — BARE, not
> `op_annot::vector`.** Measured in S1 on ngspice-42: `.save i(<dev>[id])`
> produces no vector and no diagnostic; the bare card produces
> `i(<dev>[id])` because ngspice applies the wrapper itself. Spec rule **R4**.
> `vector` is the read shape and belongs to S5, not here. Also: a card naming a
> device that does not exist writes a `0.0` column under that exact name, so a
> broken walk fails as zeros, not as blanks (spec landmine 9).
Skip `pinexpr` and `derived` (nothing to save). **Prepend `.save all`** — spec
rule R2, measured: without it the node voltages vanish from the raw. ⚠ **The
DOT-card.** This cell used to read "prepend `save all`"; taken literally that is
worse than emitting nothing (bullet 17 above — no raw file is written at all, on
ngspice-42 and 46+).

**I6 is the whole risk of this step.** The walk sets `no_draw 1`, `no_undo 1`,
`keep_symbols 1` and descends the *real* design. Every exit path — including the
"could not descend into a blank schematic" path the IHP prototype already
handles — must restore all three and the original `sch_path`.

**Also deliver** a menu item, modelled on IHP's "Create FET and BIP .save file":
write the block to `$netlist_dir/<cell>.save` and open it in a text window. That
gives non-ASE users the feature immediately, by `.include`.

**Acceptance:** 3-level test design, card list golded; a test asserting
`no_draw` / `no_undo` / `keep_symbols` / `sch_path` are all back to their
entry values afterwards, including after a forced mid-walk failure.
**Amended by the reverted attempt — these three rows are what it lacked, and all
three are cheap:** (a) a row that loads a raw **one level down** and asserts the
cards are still unique and top-relative (bullet 14 / issue 0436); (b) a row with
a `spice_ignore=true` instance asserting it contributes **no** card (bullet 15 /
issue 0437); (c) the `--logdir` invocation alongside the `--nolog` one, or the
log-suppress row is dark (bullet 20). `no_undo` cannot be asserted as a flag read
at all (bullet 18) — probe its effect, and do not let the row pass vacuously.
**Attempt 2 delivered all three and they are in the preserved patch. The row it
still lacks, and the one that decides attempt 3:** a **hierarchical** fixture
whose subcircuits carry `spice_stop`, `spice_sym_def`, `default_schematic=ignore`
and an empty `format`, cross-checked against `xschem netlist` (issue 0442).

**Menu anchor, corrected and re-verified:** "Annotate Operating Point into
schematic" is `src/xschem.tcl:15315`; the new item goes after `:15324`. Earlier
revisions of this plan and of issue 0436 cited `14943`, which is **stale** and
lands the item in the wrong cascade. The cascade choice (Simulation → Graphs)
was never ratified and rides in the same status-E row as D8.

**Risk:** medium — the walk is the only destructive thing in S1–S6. **Measured
correction, twice over: the walk was never what bit.** The I6 restore worked on
every path either crew could force, including a raise three levels down and an
entry that was already descended. Attempt 1 died on the *name basis* of the cards
and attempt 2 on *which instances got cards* — both times the read-only,
undramatic half that nobody had on the risk list. Weight the risk accordingly:
the destructive-walk story is well covered, and the emitted **content** is where
this step has failed every time.

---

## S4 — ASE carries the cards into the deck

**Files:** `src/ase.tcl` (state schema + `render_deck`), `src/ase_window.tcl`
(the Outputs → Save All dialog).

New state key `save_op_params`, default `0`, in the same group as
`save_all_v` / `save_all_i`. When set, `render_deck` appends
`op_annot::save_cards` output after the `.save all` line (`ase.tcl:3162`).
Add the checkbox to the Save All dialog (`ase_window.tcl:2854`).

> **⚠ CARRIED FROM S3b — `render_deck` IS THE CALLER ISSUE 0432 IS ABOUT.**
> `xschem get no_undo` does not exist (setter only, `scheduler.c:11958`) and it
> does not raise — it returns the **empty string** whether the flag is 0 or 1, so
> a `catch`-based probe cannot detect it. `save_cards` can therefore only restore
> `no_undo` to **0**. If `render_deck` wraps the call in its own `no_undo 1`
> scope, `save_cards` will **silently disarm it** on the way out and the rest of
> `render_deck` runs with undo re-armed. Either set `no_undo 1` again after the
> call, or fix 0432 first. Do not assume the flag survives.
>
> **⚠ `save_cards` returns `{}` for an empty walk, not a lone `.save all`.**
> Append nothing in that case — a deck carrying only `.save all` from this
> feature says nothing while reporting success.
>
> **⚠ The block is DOT-cards and is already self-sufficient**: it prepends its
> own `.save all` (R2). Appending it *after* ASE's existing `.save all` line
> means two — measured harmless, but do not "tidy" it by stripping the block's
> own leader without re-measuring, and never emit the bare `save all` spelling.

**Acceptance:** `tb_bandgap` with `save_op_params 1` renders a deck whose device
save cards match `op_annot::save_cards`; running it produces a raw whose header
contains those exact vector names. **Read the raw header back and diff the two
name sets** — that is the direct test of I1 and it is the single most valuable
test in this plan.

> **⚠ The diff is necessary but not sufficient — measured in S1.** ngspice
> writes a `0.0` column under whatever name you save, existing device or not,
> with only a `Warning: unrecognized variable` on stderr. So a completely wrong
> descriptor passes the name diff with every number zero. Add two assertions:
> ngspice's stderr carries no `unrecognized variable`, and the read-back values
> are not all exactly zero.
>
> **⚠⚠ THAT PARAGRAPH DESCRIBES `ngspice -b -r out.raw` ONLY, AND THIS STEP WILL
> NOT USE THAT IDIOM.** Re-measured in S3b on **both** installed binaries
> (`/usr/bin` = 42, `/usr/local/bin` = 46+) under the dot-card + `.control … write
> … .endc` form that ASE renders and every shipped bench uses: one bad card gives
> `rc=0`, one `checkvalid` line, and **NO RAW FILE AT ALL** — for a missing
> instance prefix *and* for a missing device inside a present instance. So under
> this step's own idiom the failure is not a fabricated zero, it is total silent
> data loss, and the acceptance above inverts: **the tell is that the raw is
> missing, not that a column is zero.** Assert the raw file exists before
> diffing anything, or the test will report a confusing absence. Spec R5 /
> landmine 9 / issues 0434 and 0442.
>
> Note also that the save card is bare while the raw
> name is wrapped (rule **R4**), so the diff compares
> `devpath+[param]` cards against `op_annot::vector` names — that asymmetry *is*
> the thing being tested, and a naive string diff of card-vs-header will fail
> for the right reason if you forget it.

**Risk:** low. **Unblocks:** real numbers on tb_bandgap.

---

## S5 — the display formatter

**Files:** `src/op_annot.tcl`.

`op_annot::text <instname>` — descriptor lookup, read each `params` vector with
`xschem raw value <v> -1`, evaluate `pinexpr` from pin voltages and `derived`
from the read values, format `label = <to_eng value>` per line.

Port `sg13g2_raw_or_double` / `sg13g2_to_eng_safe` as
`op_annot::raw_or_blank` / `op_annot::eng_or_blank` — but **blank, not `NaN`**
(I3; the IHP prototype prints `NaN`, and that is the one behaviour not to carry
over). The `catch` is mandatory, not defensive: measured in S1,
`xschem raw value <v> -1` **raises** `No raw file loaded` rather than returning
empty. `derived` and `pinexpr` are already stored verbatim by `register`, so
there is no schema work here — read them with `dict exists`.

> **⚠ I3 has a hole S5 cannot close on its own** (spec landmine 9): a card for a
> device that does not exist yields a real `0.0`, so "blank when missing" only
> covers names ngspice rejected outright. A wrong descriptor reaches the
> formatter as a legitimate-looking zero.

> **⚠ CARRIED FROM S3b — S5 OWNS DELETING THE PROTOTYPES, AND ONE OF THEM IS A
> LIVE HAZARD UNTIL IT DOES.** The 0429/D8 ruling removed `cgso`/`cgdo` from the
> sky130 **descriptor**, but `sky130_write_save_lines`
> (`sky130A/sky130_procs.tcl:86-87`) still emits `.save …[cgso]` / `[cgdo]`
> behind its still-live `Create FET .save file` menu item (`:235`), and
> `sky130_display_fet_params` (`:201-208`) still divides by them. On ngspice-42
> that menu item is one click from a `.save` file that suppresses the whole raw —
> the exact harm D8 called unshippable. Until S5 deletes the prototypes, **three**
> save-card emitters and **two** competing menu items ship at once (sky130's,
> IHP's `Create FET and BIP .save file` at `sg13g2_procs.tcl:602`, and the new
> PDK-neutral one), producing different parameter sets for the same design.
> Deleting them is therefore not cleanup — it closes an open defect.
>
> **⚠ I1 IS NOT LITERALLY ACHIEVED FOR THE VECTOR *SYNTAX*, and S5 is where it
> gets fixed cheaply.** The *device path* is genuinely single-sourced
> (`devpath`/`_pathfor`), but `op_annot::_wrap` and the save emitter's
> `_cards_for` each build the `dev[param]` bracket shape independently. The
> structural cause is that `op_annot::vector` takes **no `basis` argument**, so
> it is permanently `read`-basis and the save consumer cannot route through it
> even in principle. Give `vector` the same `?basis? ?root?` pass-through and
> have the emitter call `vector $inst $param 1`; that collapses the two builders
> and makes I1 true rather than aspirational.

**Acceptance:** on a run with the cards saved, the block for one FET matches a
golden string; on a run without them, every line is `label =` with nothing after
it, and no line is `0`.

**Risk:** low.

### ✅ S5 — DONE, status **E** (landed, committed, two questions owed to a human)

`op_annot::text`, `op_annot::raw_or_blank`, `op_annot::eng_or_blank`, plus the
privates `_finite` / `_annotated` / `_evalrow`, ship in `src/op_annot.tcl`. Pure
Tcl, no build. `tests/headless/test_op_annot.tcl` 65 → **97 checks, 0 FAIL**;
T1 3 FAIL / 0 FATAL and T2 6/6 goldens, both identical to baseline.
The golden, asserted exact including the trailing newline:

    id    = 10u    gm    = 100u   gds   = 1u     vth   = 0.7    vdsat = 0.1
    cgg   = 1f     vgs   = 0.9    vds   = 1.8    ft    = 15.92G gm/id = 10

**WHY E, AND WHAT A HUMAN MUST ANSWER — two unratified user-visible changes:**

1. **S5 edited two files outside its declared Files cell.** `sky130A/sky130_procs.tcl:377-378`
   and `gf180mcuD/gf180_procs.tcl:84-85` each gained **one space** before the
   closing `)` of two `pinexpr` strings (issue **0444**). Without it those rows
   are permanently blank on two of three PDKs and the acceptance golden would
   have had to bless that. Ratify the out-of-cell edit, or revert it and ship
   `vgs`/`vds` blank on sky130 and gf180.
2. **An IHP FET block is now 13 rows where the prototype showed 10** (`vertical_npn`:
   16), and **`cgg` now names the raw vector while `cgg_tot` names the sum** — the
   prototype printed the sum under the label `cgg`. Ratify, or relabel `cgg_tot`
   back to `cgg` and drop the raw row.

### ⚠ WHAT S5 LEARNED THAT BINDS LATER STEPS — READ BEFORE S6

* **TWO CONFIRMED DEFECTS GATE S6's CARRIER. Nothing calls `op_annot::text`
  today, so neither is user-reachable — they become visible the instant a
  carrier lands.** Close them or accept them explicitly, in writing, first:
  * **0446 — `vgs = 0` / `vds = 0` fabricated on the wrong `.raw`.** Re-scoped:
    it needs **no hierarchy**. A flat schematic, a FET with its source on GND
    (the ordinary topology), and a valid raw from any other circuit is enough —
    `token.c:4364` hardcodes GND to `0.0`, the absent net becomes `-`, and
    `eval_expr` reads `expr(- - 0.0 )` as unary minus and returns a strict-double
    `0`. Eight rows blank correctly, two fabricate. This is the first thing a
    user will do wrong, not a corner case. **Direct I3 violation.** Fix is in C.
  * **0447 — `op_annot::text` RAISES**, despite its own header having claimed it
    never does (the claim is now corrected in the source). `register` validates
    only `dict size`, so a malformed `params`/`pinexpr`/`derived` **list** is
    stored at rc=0 and raises `unmatched open brace in list` at draw time, on all
    three keys. Reachable via **I5** from one unbalanced brace. Through the real
    draw path `tcl_hook2` absorbs it and renders `?`, so the cost is a `?` block,
    not a crash. Fix at `register` (loud, preferred) or catch at read.
* **THE ITEM ABOVE ABOUT DELETING THE PROTOTYPES WAS NOT EXECUTABLE AND WAS NOT
  DONE.** Deleting `sky130_display_fet_params` / `sg13g2_display_fet_params` /
  `sg13g2_display_bip_params` dangles **three shipped annotator symbols** that
  name them by hand in `tcleval([<proc> @ref ])` into `invalid command name`
  inside a draw path, and the PDK-neutral carrier that replaces them is **S6's**.
  Deleting the save emitters destroys the acceptance oracle for four currently
  green rows (P3, P19, P20, P21) and dangles two menu items, because S3 is
  reverted three times and no neutral emitter exists. **Deletion belongs to
  whichever step lands the neutral carrier AND emitter — i.e. S6 at the earliest.**
  The 0429 residual the paragraph above is really worried about is now filed
  separately as issue **0445**.
* **THE `?basis? ?root?` PASS-THROUGH ON `op_annot::vector` WAS NOT ADDED, ON
  PURPOSE.** `op_annot::devpath` on this tree takes exactly **one** argument —
  the basis work exists only inside `0442-attempt-2-reverted.patch` — so a basis
  on `vector` would pass through to nothing and would be inventing S3's
  write-side API from the read side, where it cannot be tested. **Handed to the
  S3 retry, which must add the basis to `devpath` AND `vector` in one change or
  the two drift again.**
* **THE BRIEF'S CLAIM THAT D8 "CORRECTED sky130's cgso/cgdo TO cgs/cgd" IS
  FALSE** — found independently by three S5 agents. D8 **DELETED** both rows. The
  live sky130 descriptor is six params `{id gm gds vth vdsat cgg}` with
  `derived {ft, gm/id}`. Any golden written against a `cgs`/`cgd` assumption is
  wrong. Do not re-propagate the claim.
* **`derived` SEES LABELS, NOT PARAM NAMES**, and may reference `pinexpr` labels
  too (row order `params` → `pinexpr` → `derived` is now a contract). Values bind
  only when finite, so a missing input leaves the variable UNSET and the row
  blanks. Evaluated in a proc-LOCAL scope — `uplevel #0` would let a descriptor
  read and clobber globals, and `to_eng` (`xschem.tcl:1908`) really does run
  embedded `[...]`.
* **A PLAIN `catch` IS NOT ENOUGH FOR I3.** `expr {1.0/0.0}` → `Inf` with **no
  raise**, `string is double -strict Inf` → 1, `to_eng Inf` → `infT`. Every
  shipped derived row is a division. Use the finiteness test.
* **`xschem raw annot` ITSELF RAISES with no raw loaded** — catch-wrap the gate
  or it becomes a second raise source in a draw path.
* **A RAW READ BUT NEVER PUBLISHED RETURNS A FABRICATED 0** (`xschem raw read`
  never calls `update_op()`), and **this only reproduces in a FRESH process** —
  once any `annotate_op` has published, `cursor_b_val` survives a later `xschem
  load` and the same sequence returns the true value. Any test row for it must
  run **first** in its process or it passes vacuously.
* **STILL OPEN, LOWER PRIORITY, ALL MEASURED:** `_evalrow` uses an unbraced
  `expr`, so a `derived` string containing `[...]` executes once per device per
  redraw (descriptors are sourced Tcl, so same trust level — but D10's "controlled
  scope" was about variables, not command substitution). `op_annot::_kind` is a
  first-match lookup, so a descriptor with two `params` rows naming the same param
  with different kinds makes `text` and `vector` disagree (row S12 detects it,
  nothing prevents it). The committed golden is a hand-written ASCII raw — the
  suite never reads a raw ngspice actually wrote, so an ngspice change to the
  R1/R3 shapes would pass green. The block's numbers depend on the global
  `ev_precision` (at 8 the golden becomes `gm = 99.999997u`).
* **COVERAGE HOLE FOUND BY SABOTAGE, NOT CLOSED:** `op_annot::text`'s three early
  returns (type, descriptor, devpath) are mutually redundant — deleting **any one**
  reds nothing, 97/97 stays green. Rows S19/S20 claim to cover the type and
  descriptor guards but are caught by an earlier guard and never reach the one
  they name.
* **CREW HAZARD, NOT A CODE DEFECT:** two agents applying sabotage to one shared
  checkout concurrently made the same suite read 97 / 96 / 95 / 85 within minutes.
  Anyone reading a red `test_op_annot.tcl` from this run's logs must check
  `md5sum src/op_annot.tcl` (shipping value `1fc5e8bc3dd2f1877ea0c782c9ca2594`)
  before believing it. Serialize sabotage, or use a worktree.
* **UNRELATED, FILED AS 0448:** the parallel netlisting runner intermittently
  loses a worker to SIGPIPE (exit 141) and `run_regression.tcl` scores it as a
  leading `FATAL`, which reads as a regression to anyone diffing tier counts. Not
  reproducible standalone (5/5 clean). The netlisting result-file count also
  drifts run to run (1476–1496); harmless only while netlisting stays NOGOLD.

---

## S6 — the generic annotator symbol

**Files:** new `xschem_library/devices/annotate_params.sym`; a menu item and the
"pre-fill `ref` from the selection" idiom from `sg13g2_procs.tcl:640`.

```
K {type=annotator template="name=annot1 ref=M1"}
T {tcleval([op_annot::text @ref])} … {layer=15 font=Monospace hide=op}
T {@ref} … {layer=4}
```

**This is the first user-visible deliverable of the whole plan**, and it needs no
C change on any PDK. `hide=op` is **verified inert** until S7: `set_text_flags()`
(`actions.c:1121`) does `strboolcmp(str,"true")`, and for an unrecognised value
`strboolcmp` (`util.c:72`) falls through to a plain `strcmp`, returns non-zero,
and no `HIDE_TEXT` bit is set — so the text simply stays visible. Safe to write
the token now and give it meaning in S7.

**Acceptance:** place next to a FET on each of the three PDKs, annotate, read
numbers. Record `owed.sh add look "annotate_params on tb_bandgap"`.

**Risk:** low.

---

## S7 — annotation classes (the only broad C change)

**Files:** `src/xschem.h` (flag bits + `annot_show` field), `src/actions.c`
(`set_text_flags`, and the mirror read at :4324), `src/scheduler.c`
(`xschem set annot_show`), plus the nine visibility sites:
`draw.c:868, 1131, 10266, 10556` · `svgdraw.c:923, 1290` ·
`psprint.c:1205, 1664` · `select.c:709` · `actions.c:4422`.

Collapse those nine copy-pasted tests into one helper `text_hidden(flags)` and
put the class logic inside it. **The refactor is the substance; the feature is a
few lines.** `hide=true` / `hide=instance` semantics must not change for any
existing symbol (I7).

Mask: bit0 = device OP info, bit1 = node voltages. Mirrored in Tcl as
`annot_show`, per the `MIRRORED IN TCL` convention in `xschem.h`.

**Acceptance:** every existing library symbol renders identically with
`annot_show 0` and the old `show_hidden_texts` in both states; a `hide=op` text
appears iff bit0. Test both the draw path and the SVG/PS export paths — those
are two of the nine sites and are the ones nobody looks at.

**Risk:** medium, from breadth. Do it as one commit, no behaviour change mixed in.

---

## S8 — the keys

**Files:** `src/cadence_style_rc`, `sky130A/cadence_style_rc`,
`ihp-sg13g2/cadence_style_rc`; `cadence::annot_mode` in the cadence procs.

```tcl
bind .drw <Control-Key-6> {cadence::annot_mode none;   break}
bind .drw <Key-6>         {cadence::annot_mode op;     break}
bind .drw <Alt-Key-6>     {cadence::annot_mode opvolt; break}
```

Verified free/overridable in this tree — plain `6` is a C no-op
(`callback.c:7272`), `Ctrl-6` is "select layer 6" and is overridden with a
trailing `break` exactly as `Ctrl-4` already is, `Alt-6` (keysym 54) is in no row
of `src/keybindings.csv`. No Shift, so the shifted-keysym trap documented in that
file does not apply.

`cadence::annot_mode` sets the mask, auto-loads a raw when none is loaded
(`ase::last_rawfile` / `ase::session_for_current`, else
`$netlist_dir/<cell>.raw` → `xschem annotate_op`), then
`xschem update_all_sym_bboxes; xschem redraw`, and **reports on the status
line** — "no raw file for this cell" and "no annotation descriptor for symbol
type <t>" are the two first-run confusions and both must be said out loud, not
swallowed.

**Acceptance:** the three keys on all three PDKs; a no-raw press says so.

**Risk:** low. Can land right after S6 driving `show_hidden_texts` as a crude
two-state if S7 is not ready.

---

## S9 — the draw-time overlay

**Files:** `src/draw.c`, then `src/svgdraw.c` and `src/psprint.c`.

For every instance whose symbol type has a descriptor, while the mask allows,
draw `op_annot::text` anchored to the symbol bbox. **I4: the schematic is never
modified** — no instance placed, no `set_modify`, nothing written to the `.sch`.
Per-instance `annot_dx` / `annot_dy` attributes override the anchor.

Expect duplication with sky130's always-on `id=`/`gm=` symbol texts until S10.
That is known, documented and not a blocker.

**Acceptance:** press `6` on `sky130_tests_ase/bandgap` and every FET shows its
block; press `Ctrl-6` and they all vanish; save the file and `git diff` is empty.
Export to SVG and PS and the annotation is there.

**Risk:** medium — performance on a large hierarchy (the text is rebuilt per
redraw; cache per instance and invalidate on annotation change). Note
`op_annot::vector` resolves the symbol type and the descriptor **twice** per
call (once inside `devpath`, once inside `_kind`), i.e. two `xschem getprop`
round-trips per parameter per device. Fine for S1–S5's call rate, worth
collapsing before it runs over every instance on screen.

---

## S10 — per-PDK symbol text cleanup

Script a pass over `sky130A/xschem_libs/sky130_fd_pr/*/symbol/*.sym` (~40 FET
symbols) marking their existing `id=`/`gm=`/`vgs=`/`vds=` texts `hide=op`, so the
overlay is the single source. gf180 already sets `hide=true` on its two; ihp
symbols carry currents only.

**Acceptance:** with `annot_show 0`, a sky130 schematic looks exactly as it did
before this whole plan started.

**Risk:** medium blast radius, zero logic. Separate commit per PDK.

---

## S11 — timepoint annotation without a graph (optional)

`xschem set cursor2_x <t>` currently annotates only when a graph rect exists on
the canvas and cursor B is on (`scheduler.c:11802`). Add the direct path:
interpolate from `xctx->raw` at `x = t` with no graph involved. Then the `6`/
`Alt-6` keys work on a transient raw with nothing plotted.

**Risk:** low, one arm.

---

## S12 — documentation and issues

- Fix `doc/claude/code_analysis/waveform_subsystem_reference.md` §6: "Op text is
  layer-15 (hidden unless `show_hidden_texts=1`)" is wrong — hiding comes from
  the `hide=true` attribute, and the sky130 symbols do not set it.
- File **0418**: `@spice_get_modelparam_<p>(<dev>)` and
  `@spice_get_modelvoltage_<p>(<dev>)` are matched by the regex at
  `token.c:4646` and then silently produce nothing (`token.c:5023` handles only
  the `@spice_get_current` variants). Reserved-but-dead token forms.
- File **0419**: the generic `@spice_get_modelparam_<p>` bare tokens build
  `i(@x…[i])` for any `spiceprefix=X` device, i.e. for every sky130 / gf180 /
  IHP device — `get_fqdevice()` switches on the *element letter*, which for a
  subcircuit-wrapped PDK device is always `x`.
- Update `doc/claude/specs/op_annotation.md` status as steps land.

Already filed by the S1 crew, and **0418/0419 are still free for S12 as
described above** — nothing was numbered into them:

| # | what |
|---|---|
| 0420 | `run_regression.tcl:117`'s anchored `^OVERALL: ok$` rejects `OVERALL: ok (N checks)`, so `test_pdk_launcher` is a permanent false HARNESS FAIL |
| 0421 | `test_ihp_sg13g2_libmgr` pins a 9-library list; the tree now has 10 |
| 0422 | spec §4.2's `devpath` templates did not survive `translate` (fixed in the spec by S1) |
| 0423 | a Tcl error in any sourced helper SIGSEGVs in `alloc_xschem_data()` instead of reporting |
| 0424 | **open on this tree** — `make install` ships `xschem.tcl` sourcing an uninstalled `op_annot.tcl`; re-run `./configure` |
| 0425 | the descriptor key `type=nmos` collides across all three PDKs and the generic device library |
| 0426 | `op_annot` accepts a malformed `params` row (silently becomes `v(…)`) and a whitespace-only template |

Number new issues from **0427**.

---

## Landing order and what each step buys

| step | changes | buys |
|---|---|---|
| S1–S2 | Tcl only | the name builder, three PDKs described |
| **S3–S4** | Tcl + ASE | **numbers instead of `-`** — the blocker cleared |
| S5–S6 | Tcl + one symbol | a user-placeable annotator, all PDKs, no C |
| S8 | rc only | the three keys (crude toggle) |
| S7 | C, 9 sites + helper | the real three-state toggle |
| S9 | C, draw + exports | press `6`, every device lights up |
| S10 | bulk `.sym` | no duplication |
| S11 | C, one arm | timepoint OP with no graph |

**Progress:** S1 ✅ · S2 ✅(E) · S3 ❌ reverted ×3, S4 deferred with it · **S5 ✅(E)**.
S5 landed without S3/S4 by reading a raw produced from a hand-written deck — the
formatter never needed the generator. **S6 is next and must first decide what to
do about 0446 and 0447**, both of which become user-visible the moment a carrier
calls `op_annot::text`.

S3+S4 are worth landing on their own even if nothing else follows: they are the
difference between annotation that shows `-` and annotation that shows numbers.
