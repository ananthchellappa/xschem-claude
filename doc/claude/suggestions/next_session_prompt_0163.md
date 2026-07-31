We're closing out a backlog of verified, pre-existing defects in xschem that an audit
surfaced while fixing issue 0154 (ASE could not plot auto-named `#netN` nets).
**0163 is the last one.**
Repo: /home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing, HEAD bb23c56d.
Everything through 0162 is **pushed** (github/fluid-editing, `d620f21f..bb23c56d`).
Next free issue number is **0164**.

DONE SO FAR (do not redo; read the issue docs if you need detail):
  - **0155** `prepare_netlist_structs()` left `"0"` in the interp result — 014d766b.
  - **0156** `#`-leading net names crashed the binary (two crashes) — 14d02a0c.
  - **0157** `resolved_net()` truncated a bus at a global element — 7dea8447.
  - **0158** `resolved_net()` leaked `#` on every bus element after the first — df0f02a5.
  - **0159** an ASE bus pick emitted one invalid vector → **Select Bus Bits dialog** — 666f7f26.
  - **0160** a `lock=true` wire was unpickable from ASE, silently — 6f526387.
  - **0161** a signal picked while DESCENDED queued an unqualified name — 42a2fb6c.
    New `ase::ui::sod_qualify` in `sod_click`; `sod_expr` stays PURE. Voltages resolve through
    `xschem resolved_net` (**so the ASE pick path now depends on the function 0163 is about**),
    currents mirror `send_current_to_graph`. doc/claude/issues/0161-*.md
  - **0162** the fluid label guards read a user `#` net as tool copper — bb23c56d.
    `fluid_wire_explicit_lab` + the H2 guard now use `is_auto_net_name()`. WIRING risk 15 closed.
  - **harness** `full_audit.sh` `is_pass()` now accepts `OVERALL: ok` and
    `<name> headless: all checks passed` beside `RESULT: ALL PASS` — db3bd6f8. Floor 15 → 10.

  **Policy ratified in 0156 — carry it forward:** net names are NOT restricted to `[a-zA-Z_]`.
  Only `#` is reserved for the engine. Existing `#foo` names are ordinary user names (never
  rewritten, never refused at load) and reported by ERC. Output-strip sites stay LOOSE; only
  index-computing sites use the strict `is_auto_net_name()`.

READ FIRST (before touching anything):
  - doc/claude/issues/0163-resolved-net-instance-attribute-lookup.md — the whole issue,
    both measured symptoms, the code, and the three undecided design questions.
  - doc/claude/issues/0157-*.md and 0158-*.md — the two defects already fixed in this same
    function; they establish the house style for changes to `resolved_net`.
  - doc/claude/code_analysis/waveform_subsystem_reference.md — §11 landmines 23-28
    (28 is 0161's), §12 backlog item 0 (which already tracks 0163 as the open remainder).
  - doc/claude/issues/0161-*.md — because a `resolved_net` change now moves the ASE pick path too.

HOW I WANT YOU TO WORK — this is the important part:

**One bug at a time. Do NOT batch.** Run this cycle and STOP for my go-ahead:

  1. `cavecrew-investigator` — confirm the defect still reproduces at the quoted file:line,
     map every caller/consumer, report the blast radius. Do not let it propose fixes.
  2. You decide the fix shape yourself from that report. If two shapes are defensible, tell
     me both and your pick before writing code.
  3. RED-first: write the failing test BEFORE the fix. It must fail before and pass after.
     Then **sabotage-verify the teeth** — break the fix, confirm the test catches it, restore.
     Sabotage the OPPOSITE error too, not just the revert. **If a sabotage changes nothing,
     say so out loud** — that half of the fix has no teeth and the report must state it
     (0162's H2 guard was exactly this).
  4. `cavecrew-builder` for the edit when it is genuinely 1-2 files and mechanical; else inline.
  5. `cavecrew-reviewer` on the resulting diff. Act on what it finds.
  6. Issue doc + update the subsystem reference (and any spec whose contract moved). Commit.
  7. Report: what you verified, what you did NOT verify, and any judgement call I should weigh
     in on. Then wait.

────────────────────────────────────────────────────────────────────────────────
THE BUG — 0163: `resolved_net()` trusts any instance attribute matching a net name
────────────────────────────────────────────────────────────────────────────────

`src/hilight.c:2629-2640`, the attribute-resolution loop:

```c
      while(level > start_level) { /* check if net passed by attribute instead of by port */
        const char *ptr = get_tok_value(xctx->hier_attr[level - 1].prop_ptr, resolved_net, 0);
        if(ptr && ptr[0]) { my_strdup2(_ALLOC_ID_, &resolved_net, ptr); ...
```

`hier_attr[].prop_ptr` is the parent instance's ENTIRE property string, so `get_tok_value`
reaches every attribute, not just ones meant as net bindings. Two measured symptoms:

  (a) any attribute named like a child net REPLACES that net. Child nets `value` and
      `spice_ignore` + an instance carrying `value=1k spice_ignore=false` give
      `resolved_net {value}` → `1k`, `{spice_ignore}` → `false`.
  (b) a `#` in such a value is never stripped (`LOC=#foo` → `#foo`), because 0158's strip runs
      on the name going IN, before this lookup. Nothing downstream strips it — `get_raw_index`
      never does — so the trace is simply not found, silently.

The `dbg()` line below calls it `lcc`, which points at the intended use (a schematic inlined
into the parent). The lookup does not check which kind of instance it is, so it fires on plain
subcircuits too — that is how both symptoms were measured.

**Answer these three with me before coding** (they are the "Not yet decided" section of the doc):
  1. How to narrow the lookup: leave it and only fix `#` · denylist the known non-net fields ·
     gate on "is this really an LCC instance" · require the value to look like a net name.
  2. Whether to strip the `#` off the attribute value (the portmap path already strips at build
     time, `actions.c:3594-3599`, and a user `lab=#foo` netlists as plain `foo`).
  3. How reachable (a) is in a real design. **Do this sweep first and bring me the number**: look
     for child nets named like common instance attributes (`value`, `name`, `model`, `m`,
     `spice_ignore`, `w`, `l`, …) across xschem_library/, xschem_libs_newsym/, tests/, sky130A/,
     gf180mcuD/. That tells us whether a fix is a silent improvement or a behavior change someone
     depends on.

Note the blast radius grew since the doc was written: `resolved_net` now also backs
**ASE signal picking while descended** (0161), on top of `translate()`'s `@#<pin>:resolved_net`
in netlist output and `send_net_to_graph` in the waveform viewer.

────────────────────────────────────────────────────────────────────────────────
HARD-WON TRAPS — these cost real time; do not rediscover them
────────────────────────────────────────────────────────────────────────────────

**Testing / verification**

1. **ALWAYS probe BOTH arms before believing a non-repro.** 0155's contamination comes from a
   `has_x`-gated eval, so `--nogui` CANNOT reproduce it.
   GUI arm = `DISPLAY=:0 ./src/xschem --pipe -q --nolog --script <t>`.
2. **Subagents are sometimes blocked from running the binary** and will report a confident wrong
   answer from code inspection alone. Re-run every repro YOURSELF. (0161: an investigator reported
   "no guard exists in ase::netlist" — true but misleading; the refusal is a `schname` compare.)
3. **Sweep agents miss sites, and mislabel.** Grep the tree yourself as a cross-check and verify
   the enclosing function of every line you quote.
4. **`perl -0pi -e 's/\Q...$var...\E/.../'` INTERPOLATES `$var` TO EMPTY.** Four "sabotages"
   silently patched nothing and the suite went green. Use python and **assert the pattern was
   found**: `if old not in s: print("PATTERN NOT FOUND"); sys.exit(1)`.
5. **Tcl list quoting bites expectations.** `[split {A[1],A[0]} ,]` has the string rep
   `{A[1]} {A[0]}`, which is NOT the literal `{A[1] A[0]}`. Build expected values with `[list ...]`.
   Also: a wire snapshot record `{x1 y1 x2 y2 lab}` has the lab at index **4**, not 3 — an
   off-by-one there silently filters everything out and every leg "fails" for the wrong reason.
6. **`rename foo {}` DELETES a proc.** `rename foo real_foo` first; restore stubs OUTSIDE the main
   `catch` so a FATAL path cannot leave them installed.
7. **Assert ERC warnings via `xschem get infowindow_text`** (works in both arms); `print_erc` only
   fires on a NETLIST run, so drive it with `xschem netlist`.
8. **Crash legs must run the binary as a SUBPROCESS** (`exec $xbin --nogui --pipe -q --nolog
   --script <child>`), else a segfault kills the whole test file. Copy the `child` proc from
   tests/headless/test_hash_label_crash_0156.tcl.
9. **Scratch dirs: ALWAYS `test_scratch` from tests/headless/scratch.tcl.** Throwaway probe
   scripts go in the session scratchpad, never in the repo.
10. `gdb --batch -ex run -ex bt --args ./src/xschem ...` works here and gives a clean bt.
11. C changes need `cd src && make`. **The shell's cwd PERSISTS across tool calls** — a `cd` in an
    earlier command is still in effect. Use absolute paths for file creation; I lost time when five
    fixture files landed under `xschem_library/devices/tests/headless/...`.
12. **`git stash push src/<file>` on a CLEAN tree stashes NOTHING** and the "pristine" build you
    then compare against is the fixed one. For a real pre-fix comparison use
    `git checkout <prev-sha> -- src/<file>`, rebuild, and verify (e.g. `grep -c` for the new symbol).
13. **A change can be behavior-neutral and you must report it.** 0162's H2 guard passed every
    sabotage in both directions; a 36-shape sweep on a diagnostic build (one guard fixed, the other
    old, so any difference is necessarily the second guard's) found zero differences. That
    technique — build the hybrid to isolate one guard — is how you tell "no teeth" from "covered".

**Environment**

14. **The GUI arm is currently unreliable on this box (WSLg).** Display-dependent tests flip
    PASS/FAIL/SKIP run-to-run on an UNCHANGED binary (`test_fluid_editing` FE8, `test_altf5_ciw`,
    `test_graph_context`, `test_ase_unnamed_net`, `test_readonly_action_dispatch`), and an X-server
    drop mid-sweep once produced 2 bogus FAILs + 1 TIMEOUT + 2 SKIPs. Before calling anything a
    regression: re-run it singly, then re-run it against a TRUE pre-fix build (trap 12). The
    trustworthy signal is the **true-headless** tiers: the 58-file wireedit suite and `--nogui` runs.
15. **full_audit floor is 10 real failures**, all pre-existing: test_cadence_drag, test_ciw,
    test_hi_descend, test_lib_manager_gui, test_lib_sweep, test_phase3_mints, test_reopen_readonly,
    test_rotate_stretch_short_0104, test_select_at, test_selflog_output. (Was 15; the banner fix
    freed test_wire_split, test_crossview_paste, test_pin_type_edit,
    test_add_pin_lib_symbol_view, test_cadence_descend_newwin_ro.)
    Also pre-existing: tests/stable_handles/net_wrap.tcl is 35 PASS / 4 FAIL, and it writes to
    /tmp/sh_net_test.log, not stdout.

**Engine facts established by measurement (do not re-derive)**

16. **`xschem expandlabel` is PURE** — no design needed — and it is the bus splitter
    (`A[1:0]` → `A[1],A[0] 2`). `xschem resolved_net` is NOT pure (it runs prepare_netlist_structs).
17. **`resolved_net` semantics, measured at depth 2 on tests/headless/fixtures/ase_hier**
    (`sch_path` = `.x1.x2.`): an internal net gets the path prefix (`mid` → `x1.x2.mid`); a PORT
    resolves UP to the parent's net (`A` → `TOPNET`, no prefix); a port dangling one level up stops
    there (`B` → `x1.net1`); a GLOBAL stays flat (`0` → `0`); a bus expands per bit. Its level floor
    is `sch_waves_loaded()`, so the answer is relative to a loaded raw.
18. **ngspice-42 naming** (measured on that fixture, netlist → `ngspice -b`): internal node
    `x1.x2.mid`, nested vsource branch `v.x1.x2.v1#branch`; `.save v(x1.x2.mid) i(v.x1.x2.v1)`
    accepted verbatim. A bad `.save` card is fatal only when it is the SOLE `.save`; alongside a
    valid one it is silently dropped (missing trace, not dead session). `.save v(d,e)` never
    aborts — `v(a,b)` is ngspice's DIFFERENTIAL voltage, so never "fix" a comma expr a user typed.
19. **`lock` is enforced ONLY in `select.c` and `findnet.c`.** No lock check in move.c / actions.c /
    clip.c / paste.c / any delete path. **Selection IS the lock.**
20. **`ase::netlist` has no `currsch` guard** — it compares `xschem get schname` against the design
    path, and descending changes `schname` to the child. That is what refuses a descended run.

VERIFY LIKE THIS:
  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl
  DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/<t>.tcl
  tests/headless/wireedit/run_wireedit.sh          # 58 tests, TRUE headless — the reliable gate
  GUI_GATE=0 tests/headless/full_audit.sh <test>   # single test, no gate panel
  GUI_GATE=0 tests/headless/full_audit.sh          # 250 tests, ~6-25 min
  sh tests/headless/test_flylines.sh               # RUN BY NOTHING — full_audit globs *.tcl only

Suites that matter for a `resolved_net` change (leg counts):
  nogui-friendly: test_resolved_net_bus_global_0157 (19), test_resolved_net_hash_bus_0158 (21),
  test_ase_hier_pick_0161 (21), test_prep_result_contamination_0155 (12),
  test_hash_label_crash_0156 (23), test_ase_unnamed_net (28), test_ase_bus_bits_0159,
  test_ase_locked_wire_pick_0160 (16);
  nogui-ONLY (fail spuriously with a DISPLAY): test_ase_core (66), test_ase_final (28),
  test_ase_final_gf180 (33);
  GUI arm: test_ase_interact (63), test_ase_plot (145), test_wave_viewer (292),
  test_wave_modes (174), test_ase_window (166), test_ase_dialogs (133), test_ase_persist (109);
  plus the netlisting regression (`cd tests && tclsh netlisting.tcl`) since `resolved_net` reaches
  netlist output through `translate()`'s `@#<pin>:resolved_net`.

Fixtures you already have: `tests/headless/fixtures/ase_hier/` is a committed 3-level, netlistable,
simulatable hierarchy (top → x1 → x2) with a named internal net, a resolved port, a dangling port,
an auto-named net, a bus, a global and a nested vsource. It is the natural base for a 0163 fixture —
add an instance attribute that collides with a child net name.

────────────────────────────────────────────────────────────────────────────────
OPEN QUESTIONS I OWE YOU AN ANSWER ON — ask me once, early, then proceed
────────────────────────────────────────────────────────────────────────────────
  1. The three 0163 design questions above (narrow the lookup how · strip the `#` · reachability).
     Bring me the reachability sweep result first.
  2. Eyeball still pending on 0161's descended picking — it has only ever been driven
     programmatically. Want me to walk you through a manual check?
  3. After 0163 the backlog is empty. Anything you want picked up next, or do we stop there?

Start with the reachability sweep, then show me the fix-shape options. Investigate first, show me
the plan, then go.
