We're continuing work on `resolved_net()` in xschem. Repo:
/home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing, HEAD 6dc77347.
Everything through 1db6ce49 is **pushed** (github/fluid-editing, `bb23c56d..1db6ce49`); 6dc77347
(docs only) is not. Next free issue number is **0167**.

────────────────────────────────────────────────────────────────────────────────
READ THIS FIRST — why this session is a SPEC job, not a bug-fix job
────────────────────────────────────────────────────────────────────────────────

`resolved_net()`'s attribute-resolution loop (`src/hilight.c` ~2658-2690) has been patched three
times in three sessions, and **each patch was justified against a different, partial reading of what
the netlister does**:

  - **0163** (75da344e) gated the lookup on the parent symbol's `extra=` list. Justified against
    `extra=`'s documented meaning + `print_spice_subckt_nodes()`.
  - **0163 correction** (a5a08bc8) reverted a `#` strip that same fix shipped, once ngspice showed
    the premise was false.
  - **0164** (1db6ce49) added a symbol-template fallback, justified against `translate()` at
    `src/token.c` ~5206 — a generic two-step *instance props → that instance's symbol template*.

Then **0166** was found: the chain that actually governs an `extra=` node in a SPICE netlist is
`print_spice_element()` (`src/token.c` ~2615-2645), a **five-step cascade** that re-tries while the
value still holds an unresolved `@`, and consults sources 0164 never looked at — including the
template of the cell that *contains* the instance. 0164 as shipped is incomplete.

**Do not fix 0166 by bolting on a third source.** That is the same mistake a fourth time, and the
next partial reading will find step 5. The job this session is:

  **PHASE 1 — write the specification down. No code changes at all.**
  **PHASE 2 — fix once, against that written spec.**

Stop and show me the Phase 1 table before writing a line of Phase 2.

────────────────────────────────────────────────────────────────────────────────
PHASE 1 — the specification
────────────────────────────────────────────────────────────────────────────────

Produce **one table**: for every way an `extra=` node can get its value, what the NETLIST emits
versus what `xschem resolved_net` currently returns.

Read end to end, and quote file:line for every step you record:
  - `print_spice_element()` — `src/token.c` ~2615-2645. The cascade. Note that each retry is gated
    on the value still containing `@`, and that a later source can re-look-up an *already resolved*
    value as a token — so "fallback" and "remap" are not the same thing and the table must say which
    each step is.
  - `translate3()` — `src/token.c` ~5452-5556. What it does with an unresolved `@TOK`, and the
    multi-source lookup order inside a single call.
  - `translate()` — `src/token.c` ~5206. The two-step 0164 mirrored. Establish where this applies
    and where `print_spice_element` overrides it.
  - `print_spice_subckt_nodes()` and `get_sym_template()` — the SUBCKT HEADER side. Header and call
    site must agree or the port order breaks; confirm they do.
  - the `extra=` write sites into `hier_attr[]`: `actions.c:3582-3586`, `save.c:5588-5593`,
    `spice_netlist.c:472-478`, `spectre_netlist.c:358-364`. Note that the two netlist sites apply
    `tcl_hook2()` and the two descend sites do not — determine whether that can change what
    `get_tok_value()` returns, or state that you could not construct a case.

Build a fixture matrix and **measure every row** — netlist it, and where the answer is a node name,
confirm the name with `ngspice -b`. Cover at least:

  | source of the value | depth |
  |---|---|
  | instance attribute, explicit | 1, 2, 3 |
  | instance attribute, present but EMPTY (`VCCPIN=""`) | 1, 2 |
  | the instance's own symbol template | 1, 2, 3 |
  | the CONTAINING cell's template (this is 0166) | 2, 3 |
  | a great-grandparent's template | 3 |
  | nothing supplies it anywhere | 1, 2 |
  | value chains onto another `extra=` node one level up | 2, 3 |
  | value is a global (`0`, `GND`) | 1, 2 |
  | value is a bus / bus element | 1, 2 |
  | value carries a leading `#` | 1, 2 |

For each row record: the netlist call line, the ngspice node name, and today's `resolved_net`
answer. **Hierarchy prefixes are part of the answer** — see the 0166 trap below.

Also settle, with evidence:
  - Does the `attr_is_extra_node()` gate (0163) apply to every source, or only to the instance one?
  - Which backends treat `extra=` as NODES at all? SPICE does. Verilog uses `verilog_extra` and a
    different two-step; VHDL turns extra tokens into GENERICS, not nodes; the tEDAx `conn` emission
    sits inside `if(!subcircuit)` and so is unreachable for anything you can descend into. Those
    three claims are from code reading only — **verify or refute them by netlisting the same design
    five ways.**
  - Is spectre's path really structurally identical to SPICE's? Not measured. A fixture symbol needs
    a `spectre_format=` for the spectre backend to emit anything useful.

Deliverable: the table, plus a short list of every row where netlist and `resolved_net` disagree.
Then STOP and show me.

────────────────────────────────────────────────────────────────────────────────
PHASE 2 — fix once, against the table
────────────────────────────────────────────────────────────────────────────────

Only after I've seen Phase 1. The known-bad row today is 0166:

**0166 — `resolved_net()` misses an `extra=` node supplied by the CONTAINING CELL's template.**
Doc: `doc/claude/issues/0166-resolved-net-ignores-containing-cell-template.md`.

MEASURED (reproduced twice, independently, including ngspice):

```
.subckt cmid A  VCCPIN=MIDVCC          cmid's OWN template carries VCCPIN
xa net1 MIDVCC cleaf                   xa (of cleaf, whose template has NO VCCPIN) gets MIDVCC
.subckt cleaf A VCCPIN

descended .xm.xa. :  xschem resolved_net {VCCPIN}  ->  xm.xa.VCCPIN
```

**Expected `xm.MIDVCC`, NOT the flat `MIDVCC`.** `MIDVCC` is local to `cmid`; ngspice-42 names it
`xm.midvcc` (measured). The walk must decrement `level` on the hit so the name picks up `cmid`'s
prefix. The investigation agent that surfaced 0166 reported the expected value as flat `MIDVCC` — it
is wrong, and that is exactly the kind of error the Phase 1 table exists to prevent.

Points to settle before writing code (they may already be answered by the table):
  1. Bounds: any `level-2` index must be guarded against `< 0` **and** `< start_level`
     (`start_level` is `sch_waves_loaded()`, so the floor is not always 0).
  2. `get_tok_value()` returns a **STATIC** buffer — N candidate sources means N calls, only one
     live at a time. `xctx->tok_size` is the "token ABSENT" signal (as opposed to "value empty") and
     is reset by every call, so read it immediately after the call it refers to. That distinction is
     load-bearing and measured: an instance carrying `VCCPIN=""` gets NO node in the netlist.
  3. Whether the fix is "one more source" or "implement the cascade" — the table decides this, not a
     guess.

────────────────────────────────────────────────────────────────────────────────
0165 — LOWER PRIORITY, do not start with it
────────────────────────────────────────────────────────────────────────────────

Doc: `doc/claude/issues/0165-netlist-hash-node-two-names.md`.

A wire labelled `#hfoo` netlists as `hfoo` (`set_lab_or_pin_inst_attr`, `src/netlist.c:956`). An
`extra=` binding `HN=#hfoo` goes onto the call line **verbatim** (`print_spice_element`, no `#` test
anywhere on that path). ngspice-42 accepts both and reports two distinct, unconnected nodes:

```
V1 topn 0 1
X1 topn #hfoo c
R9 hfoo  0    1k
   hfoo 0.0V      #hfoo 1.0V      topn 1.0V
```

The binding's node is unreachable by any label, so such a design silently floats the child's supply.

Why it waits: **zero committed designs hit it**, and it is the only one of these that would CHANGE
NETLIST OUTPUT — 0163 and 0164 were both verified byte-identical over 201 stock designs, and a strip
on the binding side would not be. My lean is an **ERC warning rather than a rewrite** (existing
precedent for a `#`-name warning at `netlist.c:1491`; assertable via
`xschem get infowindow_text` after `xschem netlist`). Bring me the 201-design netlist diff before
committing to any shape. Ask me before starting this one at all.

────────────────────────────────────────────────────────────────────────────────
HOW I WANT YOU TO WORK
────────────────────────────────────────────────────────────────────────────────

**One thing at a time. Do NOT batch.** For Phase 2 and anything after it:

  1. `cavecrew-investigator` — confirm the defect still reproduces at the quoted file:line, map
     every caller/consumer, report the blast radius. Do not let it propose fixes.
  2. You decide the fix shape yourself. If two shapes are defensible, tell me both and your pick
     before writing code.
  3. RED-first: write the failing test BEFORE the fix. It must fail before and pass after.
     Then **sabotage-verify the teeth** — break the fix, confirm the test catches it, restore.
     Sabotage the OPPOSITE error too, not just the revert. **If a sabotage changes nothing, say so
     out loud** — that half of the fix has no teeth and the report must state it.
  4. `cavecrew-builder` for the edit when it is genuinely 1-2 files and mechanical; else inline.
  5. `cavecrew-reviewer` on the resulting diff. Act on what it finds.
  6. Issue doc + update the subsystem reference (and any spec whose contract moved). Commit.
  7. Report: what you verified, what you did NOT verify, and any judgement call I should weigh in
     on. Then wait.

Phase 1 has no code, so it is just: measure, tabulate, stop, show me.

────────────────────────────────────────────────────────────────────────────────
BACKGROUND YOU NEED
────────────────────────────────────────────────────────────────────────────────

READ:
  - doc/claude/issues/0163-*.md — **especially "What the loop is actually for" and "Correction"**.
    The Correction is the ngspice measurement that both 0165 and the no-strip rule hang off.
  - doc/claude/issues/0164-*.md — the chain 0166 says is incomplete.
  - doc/claude/issues/0165-*.md, 0166-*.md.
  - doc/claude/code_analysis/waveform_subsystem_reference.md — §11 landmine 29 (the `extra=` rules,
    (a)-(e)), landmines 23/26/28, §12 backlog item 0.
  - src/netlist.c:778-790 — the `#`-is-not-proof-of-auto-named policy comment.

**Policy ratified in 0156:** net names are NOT restricted to `[a-zA-Z_]`. Only `#` is reserved for
the engine. Existing `#foo` names are ordinary user names (never rewritten, never refused at load)
and reported by ERC. Output-strip sites stay LOOSE; only index-computing sites use the strict
`is_auto_net_name()`.

**`resolved_net`'s contract:** return the name the SIMULATOR actually has. That is why the 0163 `#`
strip was reverted — given a binding `HN=#hfoo`, the node *is* `#hfoo`, and stripping named a
different node that the child's port is not connected to.

**Consumers** (all only reachable when descended, i.e. `level > start_level`):
`src/hilight.c:1595` `send_net_to_graph`; `src/token.c:4224` and `:4256` `get_pin_attr`
(`@spice_get_voltage`, `@#n:resolved_net`); `src/token.c:4718` `translate`; `src/scheduler.c:9279`
the verb; `src/ase_window.tcl:905` `ase::ui::sod_qualify`. **No netlist backend calls
`resolved_net`.**

────────────────────────────────────────────────────────────────────────────────
HARD-WON TRAPS — these cost real time; do not rediscover them
────────────────────────────────────────────────────────────────────────────────

**Testing / verification**

1. **ALWAYS probe BOTH arms before believing a non-repro.** 0155's contamination comes from a
   `has_x`-gated eval, so `--nogui` CANNOT reproduce it.
   GUI arm = `DISPLAY=:0 ./src/xschem --pipe -q --nolog --script <t>`.
2. **Subagents report confident wrong answers, INCLUDING ones that claim to have run the binary.**
   0166 came from an agent: right about the defect, wrong about the expected value. Reproduce
   everything yourself before it goes into a test or a doc.
3. **Sweep agents miss sites and mislabel.** Grep the tree yourself as a cross-check and verify the
   enclosing function of every line you quote. A prior sweep mis-flagged 84 hits through bad
   symbol→schematic resolution; the corrected number came from a second independent pass.
4. **`perl -0pi -e 's/\Q...$var...\E/.../'` INTERPOLATES `$var` TO EMPTY.** Use python and **assert
   the pattern was found**: `if old not in s: print("PATTERN NOT FOUND"); sys.exit(1)`. Write the
   file only at the END so a failed assert leaves the tree untouched.
5. **Tcl list quoting bites expectations.** Build expected values with `[list ...]`; a bare
   `{.x9[15]. lvnor2.sch}` is NOT `[list {.x9[15].} lvnor2.sch]`. A wire snapshot record
   `{x1 y1 x2 y2 lab}` has the lab at index **4**, not 3.
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
    scores it FAIL while every leg prints ok. Copy the tail of
    `tests/headless/test_resolved_net_hash_bus_0158.tcl`.
11. C changes need `cd src && make`. **The shell's cwd PERSISTS across tool calls.** Use absolute
    paths for file creation.
12. **`git stash push src/<file>` on a CLEAN tree stashes NOTHING.** For a real pre-fix comparison
    use `git checkout <prev-sha> -- src/<file>`, rebuild, copy the binary out, and **verify it is
    actually the old one** by running the new test against it and confirming it fails. A binary
    copied out of the tree needs `XSCHEM_SHAREDIR=$PWD/src` to run.
13. **Netlist-diff comparisons must run BOTH binaries BACK TO BACK.** xschem writes gitignored
    `<cell>~.sch` autosave files while descending (`.gitignore` has `*~.sch`), and
    `xschem_library/examples/*.sch` globs them as tops — a stale one produced a spurious
    `Q1~.spice` diff that looked exactly like a behaviour change.
14. **A change can be behavior-neutral and you must report it.** 0162's H2 guard passed every
    sabotage in both directions; building a hybrid binary (one guard fixed, the other old) is how
    you tell "no teeth" from "covered".
15. **Hierarchy prefixes are part of the expected value.** A node local to `.subckt cmid` inside
    instance `xm` is `xm.MIDVCC`, not `MIDVCC`. This is the single easiest way to write a
    confidently wrong test in this area.

**Environment**

16. **The GUI arm is unreliable on this box (WSLg).** Display-dependent tests flip PASS/FAIL/SKIP
    run-to-run on an UNCHANGED binary. Two consecutive full audits on identical code gave
    12 fail / 0 skip and 12 fail / 5 skip with a **different** extra-failure set each time
    (`test_remap` one run; `test_fluid_editing` + `test_hover_highlight` the next; all three pass
    singly on both a fixed and a true pre-fix binary). Before calling anything a regression: re-run
    it singly, then against a TRUE pre-fix build (trap 12).
17. **full_audit floor is 10 real failures**, all pre-existing: test_cadence_drag, test_ciw,
    test_hi_descend, test_lib_manager_gui, test_lib_sweep, test_phase3_mints, test_reopen_readonly,
    test_rotate_stretch_short_0104, test_select_at, test_selflog_output.
    Also pre-existing: tests/stable_handles/net_wrap.tcl is 35 PASS / 4 FAIL and writes to
    /tmp/sh_net_test.log, not stdout.
18. **Do NOT `GUI_GATE=0` the full 252-test audit.** The gate panel is my consent to having the
    display flooded; it parks the run until I click Proceed. Single-test runs are fine:
    `GUI_GATE=0 tests/headless/full_audit.sh <test>`.

**Engine facts established by measurement (do not re-derive)**

19. **`extra=` is the complete declaration channel for a net-by-attribute binding.** Swept every
    symbol whose `format=` names a single-`@` token that is also a net in its schematic and is
    neither a pin nor in `extra=`: **0 hits**. `@@X` is a PIN reference and goes through the
    portmap, untouched by the attribute loop.
20. **`set_inst_prop()` (`src/editprop.c:213`) copies the WHOLE symbol template into a newly placed
    instance** — which is why no committed design hits 0164. The routes that avoid it: hand-edited
    files, generator/script-written instances, and a symbol whose template GAINS an attribute after
    its instances were placed.
21. **`xschem expandlabel` is PURE** (no design needed) and is the bus splitter.
    `xschem resolved_net` is NOT pure — it runs `prepare_netlist_structs`.
22. **`resolved_net` semantics at depth 2**: an internal net gets the path prefix, a PORT resolves UP
    to the parent's net, a port dangling one level up stops there, a GLOBAL stays flat, a bus expands
    per bit. Level floor is `sch_waves_loaded()`, so the answer is relative to a loaded raw.
23. **ngspice-42 naming**: internal node `x1.x2.mid`, nested vsource branch `v.x1.x2.v1#branch`;
    `.save v(x1.x2.mid) i(v.x1.x2.v1)` accepted verbatim. A bad `.save` card is fatal only when it is
    the SOLE `.save`. `.save v(d,e)` never aborts — `v(a,b)` is ngspice's DIFFERENTIAL voltage, so
    never "fix" a comma expr a user typed. **ngspice-42 also accepts `#` in a node name** and reports
    it verbatim — that is the whole of 0165.
24. **`lock` is enforced ONLY in `select.c` and `findnet.c`.** No lock check in move.c / actions.c /
    clip.c / paste.c / any delete path. **Selection IS the lock.**
25. **`ase::netlist` has no `currsch` guard** — it compares `xschem get schname` against the design
    path, and descending changes `schname` to the child.

────────────────────────────────────────────────────────────────────────────────
VERIFY LIKE THIS
────────────────────────────────────────────────────────────────────────────────

  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl
  DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/<t>.tcl
  tests/headless/wireedit/run_wireedit.sh          # 58 tests, TRUE headless — the reliable gate
  GUI_GATE=0 tests/headless/full_audit.sh <test>   # single test, no gate panel
  tests/headless/full_audit.sh                     # 252 tests, ~6-25 min, WAITS at the gate panel

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

**The netlisting regression (`cd tests && tclsh netlisting.tcl`) has NO gold baseline** — 752 jobs
that can only report NOGOLD. The real check for a `resolved_net` or netlister change is a **netlist
diff against a true pre-fix binary over ~200 stock designs** (traps 12 and 13 for how to do it
without a false positive). That is what proved 0163 and 0164 byte-identical, and it is exactly the
evidence 0165 would need.

Fixtures: `tests/headless/fixtures/ase_hier/` is a committed 3-level netlistable+simulatable
hierarchy. `test_resolved_net_templ_fallback_0164.tcl` already builds the two-level `g`/`c`
template-hop shape in `test_scratch` — extend that by one level for the Phase 1 matrix rather than
starting over.

────────────────────────────────────────────────────────────────────────────────
OPEN QUESTIONS I OWE YOU AN ANSWER ON — ask me once, early, then proceed
────────────────────────────────────────────────────────────────────────────────
  1. After Phase 1: is the fix "one more source" or "implement the cascade"? I want the table first.
  2. For 0165: rewrite the netlist, or ERC-warn and leave output alone? Netlist diff first.
  3. **Eyeball is pending on 0161, 0163 and 0164 — none of it has ever been seen by a human**, only
     driven programmatically. The user-visible surface is ASE-L Direct Plot: descend into a cell
     with `extra=` supplies, pick a signal, confirm the trace actually appears. Offer to walk me
     through that; it is the one check you cannot do yourself.

Start with Phase 1. Measure, tabulate, stop, show me.
