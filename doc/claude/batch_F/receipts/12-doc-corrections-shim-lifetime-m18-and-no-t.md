# Batch F item 12 — doc corrections: shim context lifetime, M18's mechanism, the missing `-t`

DOC-ONLY. Base HEAD `2208d16d`, branch `fluid-editing`, not pushed.

## 1. Files changed

```
doc/claude/specs/mixed_signal_signal_browser.md | 229 +++++++++++++++++++++++-
tools/cosim/README.md                           |  63 ++++++-
tools/cosim/src/verilator_shim.cpp              |  58 +++++-
3 files changed, 334 insertions(+), 16 deletions(-)
```

Also committed: `doc/claude/issues/0311-cosim-shim-drops-every-set-bit-written-to-a-multi-bit-inout-port.md` and this receipt. The 37 KB working receipt `12-doc-corrections.md` stays untracked, superseded.

**The `.cpp` touches no executable line — proven, not asserted:** strip `/*…*/` and `//…` from `git show HEAD:…verilator_shim.cpp` and from the working copy, drop blanks, compare → `IDENTICAL AFTER COMMENT STRIP == True`, 221 lines each. Re-verified after my own edits, proving both "no code moved" and "the new comment block terminates correctly".

## 2. Decisions and evidence

**(a) The rationale was wrong twice; the second error was the dangerous one.** The scope's stop-condition did **not** fire: `grep -n '\bctx\b'` on HEAD gives 3 hits (`:306` decl, `:320`, `:330`), all inside `Cosim_setup` (`:282-347`). So *"and so does the trace setup below"* is false — the VM_TRACE block is `:313-332`, before the closing brace, where the `unique_ptr` is still alive. Hence the earlier "neuter → byte-identical VCD, clean valgrind" result. **But "therefore inert" does not follow**, and the first draft wrote it into four places. Grepping `ctx` is narrower than *who reaches the context object*: `Verilated::threadContextp()` is a thread-local set by the `VerilatedContext` constructor (`/usr/share/verilator/include/verilated.cpp:2421`) and **never cleared by the destructor** (`:2434`, which only stamps `m_magic`); the *generated* model dereferences it inside `topp->eval()` in **every** build whenever the Verilog uses `$time`, `%t`, `$finish`, `$stop` or `$fatal` — `VL_TIME_Q()` is literally `Verilated::threadContextp()->time()` (`verilated_funcs.h:302`, `VL_TIME_UNITED_Q` `:308`), and `vl_finish()` calls `gotFinish()` on it (`verilated.cpp:113`). I verified all five citations. **RULING: keep the `release()`; record the reason as "every build", not "only `-t`"** — spec §A part 2, mirrored in the shim comment and `tools/cosim/README.md`, both warning against re-deriving "inert" from a run of `counter.v`.

**(c) `-t` is never passed — premise confirmed, no correction needed.** `src/ase.tcl:1357-1359` is `set cmd [list $script]` / `if {$trace} { lappend cmd -V }` / `lappend cmd -o $rd $vfile`, exec'd `:1366`; no branch appends `-t`; `ase::cosim_build` is the only caller of `build_cosim_so.sh`; `-t` is the sole source of `-DWITH_TIMING` (`build_cosim_so.sh:42`, `:73`). **Knock-on the reviewers forced:** the first draft generalised this to "every `.so` we ship is TRACE", which is false — `$trace` is 1 *unless* `cosim trace 0` (`src/ase.tcl:1315`), a policy this spec documents in E2/E4/E7, and `-V` also selects the shim source (`:49-53`), so a `trace 0` build links the **stock** shim with none of the patches (`grep -c 'XSCHEM PATCH'` on the system copy → `0`). The tree already tests the switch: `ase::cosim_shim_dir` (`src/ase.tcl:1267-1274`), pinned by BD19/BD20. Corrected in §A part 1.

**(b) M18's mechanism, recorded and re-measured by me.** `keep_case_of_cider_param()` counts `"` on the physical line; **exactly two** preserves the quoted run, every other count — four included — folds the whole line. "Even" is not the rule; the 6-quote row proves it. My own parse-only decks (`.control listing p`) on the installed ngspice-46 reproduced the table: 0 quotes → `./counterup.so` folded; 2 → `./CounterUP.so` **kept**; 4 → `./counterup.so` + `mixedcase.vcd` both folded; 6 → all three folded; `.model` (2) + `+ sim_args` → `.model` line **kept**, continuation folded. Punchline recorded: adding `sim_args` is what retroactively destroys `simulation=`'s case.

**Knock-on edits (6), all in the spec:** M-table preamble, M15, M18, A2, E2, E6. A2 had claimed the M15 fix "is not compiled at all" — false: `contextp.release()` is unguarded at `:350`, between `#endif` `:295` and `#if VM_TRACE` `:357`; only its `WITH_TIMING` *consumer* is conditional. E6 illustrated M18 with a bare `simulation="./Counter.so"` → folded, the **opposite** of the measured rule (2 quotes ⇒ kept); corrected with the condition stated, and M18's own row given the same treatment.

**My own correction as closer: the ngspice citations were 4 lines high.** Cited `inpcom.c:227-258` / `:242` / `:420-441` / `:1911` / `:1900-1903` / `:1916-1930`; against the tree it names (`/home/qflow/dev/ngspice_test`, clean at `db9d99843`) the true numbers are `:223-254` / `:238` / `:416-438` / `:1908` / `:1896-1899` / `:1912-1927` — the stale ones match scratchpad copies from an unrelated session. All six fixed; the section now pins tree path and commit. In an item whose premise is checkable citations, this mattered most.

**Issue 0311 filed, deliberately unfixed.** `verilator_shim.cpp:162` writes `topp->name | (…)` where `:130` writes `|=` — a discarded expression, so a multi-bit `inout` can be cleared but never set while `previous_output[]` records the write as landed. Upstream: identical at `:83`, correct `:51`, in both stock copies. Needs a vendoring-policy decision and an `inout[3:0]` regression that does not exist.

## 3. Tests

**No new check — this item adds none.** Doc-only, and the scope forbade a new test. Suites re-run in the correct `--nogui` arm, 6/6 PASS: `test_ase_cosim`, `test_ase_core`, `test_vcd_time_base`, `test_verilog_view_model`, `test_vcd_read`, `test_node_token_split`. Verbatim RESULT line from the suite covering the touched build path, then the full audit (`GUI_GATE=1 DISPLAY=:0 full_audit.sh`):

```
RESULT: ALL PASS (310 checks)
SUMMARY: 283 pass  23 fail  1 crash/timeout  0 skip  (total 307)
WIREEDIT: PASS
SCRATCH:  0 leaked dir(s)
```

## 4. Sabotage table

| check | what was broken | red? | restored green? |
|---|---|---|---|
| BD20-shimdir-notrace (`test_ase_cosim.tcl:693`) | `src/ase.tcl:1271` `if {!$trace}` → `if {0}` | YES — `got '/x/tools/cosim/src' want '/usr/local/share/ngspice/scripts/src'`, other 309 green | YES — byte-exact backup (md5 `03d69b5433ed39c1116ee889a2b05447`), ALL PASS (310) |
| BD19-shimdir-trace (`test_ase_cosim.tcl:691`) | `src/ase.tcl:1273` `…/src` → `…/SABOTAGE` | YES — `got '/x/tools/cosim/SABOTAGE' want '/x/tools/cosim/src'` | YES — same backup, ALL PASS (310) |
| *the doc claim itself* — "`release()` is inert in the shipping configuration" | `release()` neutered in the **shipped** config (VM_TRACE on, WITH_TIMING off), `topp->eval()` ×40 | YES — ASan `heap-use-after-free`, READ size 8 in `VerilatedContext::time()` ← `nba_sequent__TOP__0` ← `Vlng::eval_step()` | YES — with `release()` in place, exits 0 clean. CONTROL: reference `counter.v`, identical neutered harness, ASan-**clean** — which is why the original probe concluded "inert" |
| *coverage probe* — anything protecting fact (c) | reconstructed the build stub (`:602-617`), fed it `-V -o a` vs `-V -t -o b` | **NO — survived on purpose** | n/a |

**Neither BD19/BD20 nor the ASan harness is a check this item adds.** BD19/BD20 are existing checks the corrected spec now *cites*, sabotaged because an uncheckable citation is exactly the defect this item removes. The last row is a measured coverage hole, not evidence: the stub's option arm is literally `-V|-t) shift ;;` (`:608`) and records no argv, so both invocations gave rc=0 and `diff -r a b` was IDENTICAL — **a stray `lappend cmd -t` would leave all 310 checks green.** Fact (c) is prose-protected.

## 5. What was NOT verified

- **The "byte-identical VCD, clean valgrind" probe was never re-run** (needs a verilator build plus a real ngspice cosim run). The spec calls it real-but-narrow and explains why it came back clean; that explanation is measured (ASan control row), the original probe is not.
- **Fact (c) has no automated protection**, and the one harness on that path ignores `-t`. The follow-up is **not** one line: the stub must first record `"$@"` (or exit 2 on an unknown option). Free ids BD27-BD69 (BD1-BD26 plus a stray BD70 in use).
- **The §A part 2 ruling has no regression at all** — nothing in the tree compiles `verilator_shim.cpp` (not in `src/Makefile` `OBJ`), so a re-vendor dropping the LIFETIME hunk would be caught by nothing. **Issue 0311's runtime symptom** is likewise read off the macro, not observed — no `inout` design exists to run.
- **Reviewer points not treated as defects:** the `verilated_trace` `parallel()` path is a second post-setup use of the released pointer but only when `parallel()` is true (reference model reports false) — not demonstrated; whether `~VerilatedContext` touches models registered via `addModel` — unchecked, moot since the `release()` stays; the spec's `:175-210`/`:212-277` step() ranges are `#ifndef`/`#else` arm boundaries, not function boundaries (loose, not wrong).
- **Side effect not otherwise admitted:** `ase::cosim_stamp` (`src/ase.tcl:1277-1287`) feeds the shim's mtime and size into every `<so>.stamp`, so this comment-only edit invalidates every cached cosim `.so` and forces a rebuild on the next Run — the stamp working as designed (E6), but "no behaviour change" is true of the compiled code, not of the build cache. **No eyeball owed:** prose and comments, not pixels.

### Audit diff vs `baseline_status.txt`

Baseline header is `# baseline 7a592f9c 2026-08-09 DISPLAY=:0`; its rows tally **277 PASS / 26 FAIL / 2 TIMEOUT / 1 SKIP over 306** non-wireedit tests. (The working receipt's first draft asserted "96f7678a: 285/19/1/305" about a file it said it had not opened — copied from the orchestrator's policy text, wrong in every element; the fixer corrected it and I re-derived the numbers. `96f7678a` heads the *other* file, `…nodisplay.txt`.) **Caveat governing every row:** baseline is at item 1 (`7a592f9c`), HEAD at item 6 (`2208d16d`), so changed rows belong to items 1-6 or the environment. Item 12 contributes nothing, and the proof is structural: the change is prose plus C comments, provably code-identical after comment-strip.

**RED → GREEN (8), all attributable to items 1-6 or the environment:** `test_ase_persist` FAIL→PASS · `test_ase_plot` TIMEOUT→PASS (documented WSLg flake class) · `test_fluid_bodyshove_guards_0132` FAIL→PASS · `test_rotate_stretch_dangling_0103` SKIP→PASS · `test_wave_axis_zoom` FAIL→PASS · `test_wave_crossdb_trace` FAIL→PASS · `test_wave_sigbrowser_i12` FAIL→PASS · `test_wire_vertex_grab` FAIL→PASS.

**NEW (1):** `test_wave_sigbrowser_digital` absent→PASS — the suite item 6 added, which is why the run has 307 tests against the baseline's 306.

**GREEN → RED (3), each re-run standalone and cleared:** `test_readonly_action_dispatch` PASS→FAIL and `test_sod_pick_no_select_0204` PASS→FAIL both went **2/2 PASS** standalone; `test_wave_trace_menu` PASS→FAIL is the documented **TG9 root-coords WSLg flake** (~4-in-10 on a pristine tree) and reproduced as exactly that on the second standalone run — `FAIL: TG9 it was posted in ROOT coordinates (the event's %X/%Y) -> {0} (exp {1})`, 1 check of 397. None is a regression, and none *could* be one from this item: the change is prose plus C comments, provably code-identical after comment-strip, and no test in the tree reads the spec, the README, or the shim source.

Arithmetic checks out: 277 + 8 − 3 + 1 = **283 PASS**, matching the run.
