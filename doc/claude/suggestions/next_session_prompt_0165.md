We're continuing a backlog of verified, pre-existing defects in xschem that an audit surfaced while
fixing issue 0154 (ASE could not plot auto-named `#netN` nets). The original 0155-0163 backlog is
**closed**; these two are new, and both came out of measuring 0163/0164 rather than from the audit.
Repo: /home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing, HEAD 1db6ce49.
Everything through 1db6ce49 is **pushed** (github/fluid-editing, `bb23c56d..1db6ce49`).
Next free issue number is **0167**.

DONE SO FAR in this thread (do not redo; read the issue docs for detail):
  - **0163** `resolved_net()` trusted ANY instance attribute whose name matched a child net —
    `value=1k` → `1k`, `name` → `X1`, and on the stock library `m` → `1` — 75da344e.
    The loop is not junk: it implements **`extra=`**, upstream's "hidden pins with connections
    passed as parameters" (`doc/xschem_man/symbol_property_syntax.html:284-305`). Gated on
    `hier_attr[].sym_extra`, EXACT whitespace-token match (not the netlister's internal `strstr`).
  - **0163 correction** the `#` strip that fix shipped was **wrong and was reverted** — a5a08bc8.
    That revert is the seed of 0165 below; read its Correction section first.
  - **0164** `resolved_net()` ignored the symbol TEMPLATE default for an `extra=` node — 1db6ce49.
    Fallback guard is `!xctx->tok_size` ("token ABSENT"), **not** `!ptr[0]` ("value empty"):
    measured, an instance carrying `VCCPIN=""` gets NO node in the netlist.
    **0164 is INCOMPLETE — that is issue 0166 below.**

  **Policy ratified in 0156 — carry it forward:** net names are NOT restricted to `[a-zA-Z_]`.
  Only `#` is reserved for the engine. Existing `#foo` names are ordinary user names (never
  rewritten, never refused at load) and reported by ERC. Output-strip sites stay LOOSE; only
  index-computing sites use the strict `is_auto_net_name()`.

READ FIRST (before touching anything):
  - doc/claude/issues/0165-netlist-hash-node-two-names.md
  - doc/claude/issues/0166-resolved-net-ignores-containing-cell-template.md
  - doc/claude/issues/0163-*.md — **especially its "Correction" section**, which is the measurement
    both of these hang off, and its "What the loop is actually for" section.
  - doc/claude/issues/0164-*.md — the chain 0166 says is incomplete.
  - doc/claude/code_analysis/waveform_subsystem_reference.md — §11 landmine 29 (the `extra=` rules),
    landmines 23/26/28, §12 backlog item 0.
  - src/netlist.c:778-790 — the `#`-is-not-proof-of-auto-named policy comment.

HOW I WANT YOU TO WORK — this is the important part:

**One bug at a time. Do NOT batch.** Run this cycle and STOP for my go-ahead:

  1. `cavecrew-investigator` — confirm the defect still reproduces at the quoted file:line, map
     every caller/consumer, report the blast radius. Do not let it propose fixes.
  2. You decide the fix shape yourself from that report. If two shapes are defensible, tell me both
     and your pick before writing code.
  3. RED-first: write the failing test BEFORE the fix. It must fail before and pass after.
     Then **sabotage-verify the teeth** — break the fix, confirm the test catches it, restore.
     Sabotage the OPPOSITE error too, not just the revert. **If a sabotage changes nothing, say so
     out loud** — that half of the fix has no teeth and the report must state it.
  4. `cavecrew-builder` for the edit when it is genuinely 1-2 files and mechanical; else inline.
  5. `cavecrew-reviewer` on the resulting diff. Act on what it finds.
  6. Issue doc + update the subsystem reference (and any spec whose contract moved). Commit.
  7. Report: what you verified, what you did NOT verify, and any judgement call I should weigh in
     on. Then wait.

**I suggest doing 0166 FIRST** — it is a hole in something already shipped and pushed, and it is
netlist-neutral by construction. 0165 is the one that would change netlist output, so it deserves
the fresher context.

────────────────────────────────────────────────────────────────────────────────
0166 — `resolved_net()` misses an `extra=` node from the CONTAINING CELL's template
────────────────────────────────────────────────────────────────────────────────

0164 added ONE template fallback: the instance's own symbol template,
`hier_attr[level-1].templ`, mirroring `translate()` at `src/token.c` ~5206. But the SPICE netlister
uses `print_spice_element()` (`src/token.c` ~2615-2645), a **cascade** that re-tries while the value
still holds an unresolved `@`, and one of its later steps consults the template of the cell that
*contains* the instance.

MEASURED (I reproduced this myself, both the netlist and ngspice):

```
.subckt cmid A  VCCPIN=MIDVCC          cmid's own template carries VCCPIN
xa net1 MIDVCC cleaf                   xa (of cleaf, whose template has NO VCCPIN) gets MIDVCC
.subckt cleaf A VCCPIN

descended .xm.xa. :  xschem resolved_net {VCCPIN}  ->  xm.xa.VCCPIN
```

**Expected `xm.MIDVCC`, not the flat `MIDVCC`** — `MIDVCC` is local to `cmid`, and ngspice-42 names
it `xm.midvcc` (measured). The walk must `level--` on the hit so the name picks up `cmid`'s prefix.
An investigation agent reported the expected value as flat `MIDVCC`; it is wrong. See the issue doc
for the five points to settle (bounds on `level-2`, the static-buffer constraint, whether the
`attr_is_extra_node` gate still applies, the cascade-vs-parallel question, and >2 levels).

Reachability was **not** swept for this variant. Do that first, the way 0163 did.

────────────────────────────────────────────────────────────────────────────────
0165 — one `#`-leading name becomes TWO nodes in the netlist
────────────────────────────────────────────────────────────────────────────────

A wire labelled `#hfoo` netlists as `hfoo` (`set_lab_or_pin_inst_attr`, `src/netlist.c:956`). An
`extra=` binding `HN=#hfoo` is written onto the call line **verbatim** (`print_spice_element`,
`src/token.c` ~2615-2645, no `#` test anywhere). ngspice-42 accepts both and reports them as two
distinct, unconnected nodes. MEASURED, one deck:

```
V1 topn 0 1
X1 topn #hfoo c
R9 hfoo  0    1k

   hfoo    0.0V      #hfoo   1.0V      topn   1.0V
```

The binding's node is unreachable by any other means — no label can land on it — so such a design
silently floats the child's supply, with no ERC or simulator complaint.

**This is the one that would change netlist output.** 0163 and 0164 were both verified
byte-identical over 201 stock designs; a strip on the binding side would not be. Four undecided
questions are in the issue doc: strip vs leave, strict `is_auto_net_name()` vs loose, warn-instead-
of-rewrite (there is an existing ERC-warning precedent at `netlist.c:1491`), and which backends.
Bring me the netlist diff before you commit to a shape.

Reachability: **zero committed designs** — of 68016 non-empty instance attribute values, 7 start
with `#` and all are the same disabled `xxxspiceprefix=#D#`, none an `extra=` binding.

────────────────────────────────────────────────────────────────────────────────
HARD-WON TRAPS — these cost real time; do not rediscover them
────────────────────────────────────────────────────────────────────────────────

**Testing / verification**

1. **ALWAYS probe BOTH arms before believing a non-repro.** 0155's contamination comes from a
   `has_x`-gated eval, so `--nogui` CANNOT reproduce it.
   GUI arm = `DISPLAY=:0 ./src/xschem --pipe -q --nolog --script <t>`.
2. **Subagents report confident wrong answers, including ones that claim to have RUN the binary.**
   The 0166 finding above came from an agent and was RIGHT about the defect but WRONG about the
   expected value. Reproduce everything yourself before writing it into a test or a doc.
3. **Sweep agents miss sites, and mislabel.** Grep the tree yourself as a cross-check and verify the
   enclosing function of every line you quote. My own 0163 sweep mis-flagged 84 hits through bad
   symbol→schematic resolution; the corrected number came from a second, independent pass.
4. **`perl -0pi -e 's/\Q...$var...\E/.../'` INTERPOLATES `$var` TO EMPTY.** Use python and **assert
   the pattern was found**: `if old not in s: print("PATTERN NOT FOUND"); sys.exit(1)`. Write the
   file only at the END so a failed assert leaves the tree untouched.
5. **Tcl list quoting bites expectations.** Build expected values with `[list ...]`; a bare
   `{.x9[15]. lvnor2.sch}` is NOT what `[list {.x9[15].} lvnor2.sch]` produces. A wire snapshot
   record `{x1 y1 x2 y2 lab}` has the lab at index **4**, not 3.
6. **`rename foo {}` DELETES a proc.** `rename foo real_foo` first; restore stubs OUTSIDE the main
   `catch` so a FATAL path cannot leave them installed.
7. **Assert ERC warnings via `xschem get infowindow_text`** (works in both arms); `print_erc` only
   fires on a NETLIST run, so drive it with `xschem netlist`.
8. **Crash legs must run the binary as a SUBPROCESS** (`exec $xbin --nogui --pipe -q --nolog
   --script <child>`), else a segfault kills the whole test file. Copy the `child` proc from
   tests/headless/test_hash_label_crash_0156.tcl.
9. **Scratch dirs: ALWAYS `test_scratch` from tests/headless/scratch.tcl.** Throwaway probe scripts
   go in the session scratchpad, never in the repo.
10. **A new test must end with `RESULT: ALL PASS (N checks)`** or `full_audit.sh`'s `is_pass()`
    scores it FAIL while every leg says ok. Copy the tail of
    `tests/headless/test_resolved_net_hash_bus_0158.tcl`.
11. C changes need `cd src && make`. **The shell's cwd PERSISTS across tool calls.** Use absolute
    paths for file creation.
12. **`git stash push src/<file>` on a CLEAN tree stashes NOTHING.** For a real pre-fix comparison
    use `git checkout <prev-sha> -- src/<file>`, rebuild, copy the binary out, and **verify it is
    actually the old one** (run the new test against it and confirm it fails). A binary copied out
    of the tree needs `XSCHEM_SHAREDIR=$PWD/src` to run.
13. **Netlist-diff comparisons must run BOTH binaries BACK TO BACK.** xschem writes gitignored
    `<cell>~.sch` autosave files while descending (`.gitignore` has `*~.sch`), and
    `xschem_library/examples/*.sch` globs them as tops — a stale one produced a spurious
    `Q1~.spice` diff that looked exactly like a behaviour change.
14. **A change can be behavior-neutral and you must report it.** 0162's H2 guard passed every
    sabotage in both directions; building a hybrid binary (one guard fixed, the other old) is how
    you tell "no teeth" from "covered".

**Environment**

15. **The GUI arm is unreliable on this box (WSLg).** Display-dependent tests flip PASS/FAIL/SKIP
    run-to-run on an UNCHANGED binary. Two consecutive full audits on identical code gave
    12 fail / 0 skip and 12 fail / 5 skip with a **different** extra-failure set each time
    (`test_remap` one run, `test_fluid_editing` + `test_hover_highlight` the next; all three pass
    singly on both a fixed and a true pre-fix binary). Before calling anything a regression: re-run
    it singly, then against a TRUE pre-fix build (trap 12).
16. **full_audit floor is 10 real failures**, all pre-existing: test_cadence_drag, test_ciw,
    test_hi_descend, test_lib_manager_gui, test_lib_sweep, test_phase3_mints, test_reopen_readonly,
    test_rotate_stretch_short_0104, test_select_at, test_selflog_output.
    Also pre-existing: tests/stable_handles/net_wrap.tcl is 35 PASS / 4 FAIL, writing to
    /tmp/sh_net_test.log, not stdout.
17. **Do NOT `GUI_GATE=0` the full 250-test audit.** The gate panel is the user's consent to having
    the display flooded; it parks the run until Proceed is clicked. Single-test runs are fine:
    `GUI_GATE=0 tests/headless/full_audit.sh <test>`.

**Engine facts established by measurement (do not re-derive)**

18. **`extra=` is the complete declaration channel for a net-by-attribute binding.** Swept every
    symbol whose `format=` names a single-`@` token that is also a net in its schematic and is
    neither a pin nor in `extra=`: **0 hits**. `@@X` is a PIN reference and goes through the
    portmap, untouched.
19. **`xschem expandlabel` is PURE** — no design needed — and it is the bus splitter.
    `xschem resolved_net` is NOT pure (it runs prepare_netlist_structs).
20. **`resolved_net` semantics at depth 2**: an internal net gets the path prefix, a PORT resolves UP
    to the parent's net, a port dangling one level up stops there, a GLOBAL stays flat, a bus expands
    per bit. Its level floor is `sch_waves_loaded()`, so the answer is relative to a loaded raw.
21. **ngspice-42 naming**: internal node `x1.x2.mid`, nested vsource branch `v.x1.x2.v1#branch`;
    `.save v(x1.x2.mid) i(v.x1.x2.v1)` accepted verbatim. A bad `.save` card is fatal only when it is
    the SOLE `.save`. `.save v(d,e)` never aborts — `v(a,b)` is ngspice's DIFFERENTIAL voltage, so
    never "fix" a comma expr a user typed. **ngspice-42 also accepts `#` in a node name** and reports
    it verbatim — that is the whole of 0165.
22. **`set_inst_prop()` (`src/editprop.c:213`) copies the WHOLE symbol template into a newly placed
    instance**, which is why no committed design hits 0164: GUI-placed instances always spell their
    attributes out. The routes that don't: hand-edited files, generator/script-written instances, and
    a symbol whose template GAINS an attribute after its instances were placed.
23. **`lock` is enforced ONLY in `select.c` and `findnet.c`.** No lock check in move.c / actions.c /
    clip.c / paste.c / any delete path. **Selection IS the lock.**
24. **`ase::netlist` has no `currsch` guard** — it compares `xschem get schname` against the design
    path, and descending changes `schname` to the child.

VERIFY LIKE THIS:
  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl
  DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/<t>.tcl
  tests/headless/wireedit/run_wireedit.sh          # 58 tests, TRUE headless — the reliable gate
  GUI_GATE=0 tests/headless/full_audit.sh <test>   # single test, no gate panel
  tests/headless/full_audit.sh                     # 252 tests, ~6-25 min, WAITS at the gate panel
  cd tests && tclsh netlisting.tcl                 # 752 jobs, but NOGOLD — see below

Suites that matter for a `resolved_net` change (leg counts):
  nogui-friendly: test_resolved_net_attr_scope_0163 (34), test_resolved_net_templ_fallback_0164 (23),
  test_resolved_net_bus_global_0157 (19), test_resolved_net_hash_bus_0158 (21),
  test_ase_hier_pick_0161 (21), test_prep_result_contamination_0155 (12),
  test_hash_label_crash_0156 (23), test_ase_unnamed_net (28), test_ase_bus_bits_0159 (22),
  test_ase_locked_wire_pick_0160 (16);
  nogui-ONLY (fail spuriously with a DISPLAY): test_ase_core (66), test_ase_final (28),
  test_ase_final_gf180 (33);
  GUI arm: test_ase_interact (63), test_ase_plot (145), test_wave_viewer (292), test_wave_modes (174),
  test_ase_window (166), test_ase_dialogs (133), test_ase_persist (109).

**The netlisting regression has NO gold baseline** — it can only report NOGOLD. The real check for a
`resolved_net` or netlister change is a **netlist diff against a true pre-fix binary over ~200 stock
designs** (see trap 13 for how to do it without a false positive). That is what proved 0163 and 0164
byte-identical, and it is exactly the evidence 0165 will need.

Fixtures you already have: `tests/headless/fixtures/ase_hier/` (committed 3-level, netlistable,
simulatable). The 0163 and 0164 tests each build their own `extra=` fixtures in `test_scratch` —
0164's already has the two-level `g`/`c` template-hop shape that 0166 needs to extend by one level.

────────────────────────────────────────────────────────────────────────────────
OPEN QUESTIONS I OWE YOU AN ANSWER ON — ask me once, early, then proceed
────────────────────────────────────────────────────────────────────────────────
  1. 0166 first or 0165 first? (My suggestion is 0166 — see above.)
  2. For 0165: rewrite the netlist, or warn and leave output alone? I want the netlist diff before
     I decide.
  3. Eyeball is still pending on 0161's descended picking AND on 0163/0164 — all of it has only ever
     been driven programmatically. Want me to walk you through a manual check?

Start with the reachability sweep for whichever you pick, then show me the fix-shape options.
Investigate first, show me the plan, then go.
