# 0228 — `run_suites.sh` is the only one of the three harnesses that will not read the `OVERALL: ok` sentinel, so passing suites score `NORESULT` through the X arm

Status: **FIXED** (see `## What actually shipped` at the bottom — the patch suggested below
is right in shape but wrong in three details, all measured). The X arm did **not** cope:
measured, `xarm.sh suites test_wire_split.tcl` reported `NORESULT` and exited 1 while the
file passed 121 of 121 checks.
Found by: the merge-4 audit, running `tests/headless/test_wire_split.tcl` through both the
true-headless invocation and the batch's sanctioned X arm
(`doc/claude/signal_browser_2pane_batch/xarm.sh`) and getting a pass and a `NORESULT` from
the same output.
Severity: medium — no coverage is actually lost (two of the three harnesses score these
files correctly), but through the X arm a *real* regression in those 121 checks is
indistinguishable from their permanent `NORESULT`.
Pre-existing: yes. `git diff --stat pre-open-pdk-merge-4 HEAD -- tests/headless/run_suites.sh
tests/headless/full_audit.sh` is **empty** — both readers are byte-identical across merge
`15c600c6`.
Related: `doc/claude/issues/0227-*.md` (the other harness-shaped finding of the same audit);
issue 0147, whose inverse this is.

## Symptom

The file passes and prints no `RESULT:` line:

```
$ env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wire_split.tcl
EXIT=0
RESULT lines: 0
ok lines: 121
161:OVERALL: ok
```

The emitting line is `tests/headless/test_wire_split.tcl:870`:

```tcl
if {$fail == 0} { puts "OVERALL: ok"; exit 0 } else { puts "OVERALL: notok"; exit 1 }
```

Through the batch's X arm (`xarm.sh mode` → `GATED :0`, control file `RUN`):

```
$ SUITE_TIMEOUT=400 ./doc/claude/signal_browser_2pane_batch/xarm.sh suites test_wire_split.tcl
NORESULT | test_wire_split              run 1/1 (exit 0 — binary never reported)
RESULT: 0/1 runs passed
```

exit 1.

## This is not a test-file defect — it is two harnesses disagreeing

The reported framing was "a test breaks a harness convention". That is wrong, and the issue
has to be written the other way round or the fix goes in the wrong file.

`tests/headless/test_wire_split.tcl:40` documents the choice:

```
# Prints "OVERALL: ok" on success (run_regression sentinel).
```

and the harness it is registered in requires exactly that. `tests/run_regression.tcl:35`
registers it (`"headless/test_wire_split" \`), and `:115` is the only thing it looks for:

```tcl
set sentinel [regexp -line {^OVERALL: ok$} $body]
```

with `:116` synthesizing a FAIL on `if {$childcode != 0 || !$sentinel}`. The file is
**correct for its registered harness**.

There are **three** readers, not two:

| reader | accepts | verdict on `test_wire_split` |
|---|---|---|
| `tests/run_regression.tcl:115` | `OVERALL: ok` only | correct (PASS) |
| `tests/headless/full_audit.sh:99` | **both** — `[[ "$out" == *"RESULT: ALL PASS"* \|\| "$out" == *"OVERALL: ok"* ]]` | correct (PASS) |
| `tests/headless/run_suites.sh:104` | `grep -E '^RESULT'` only | **`NORESULT`, scored FAIL** |

`full_audit.sh` already found and fixed this exact class, once, in one harness. Its comment
at `:75-82` says so:

```
# Both banners are accepted because ~5 shipped tests (test_wire_split,
# test_crossview_paste, test_pin_type_edit, test_add_pin_lib_symbol_view,
# test_select_at) only ever print "OVERALL: ok" -- they were scored FAIL here
# forever while passing every one of their own checks (red-but-hollow, the
# inverse of issue 0147).
```

`run_suites.sh` never learned it. The classification is at `tests/headless/run_suites.sh:104`,
`:108` and `:112`:

```sh
    result=$(printf '%s\n' "$out" | grep -E '^RESULT' | tail -1)
    …
    elif [ -z "$result" ]; then
      printf 'NORESULT | %-28s run %d/%d (exit %d — binary never reported)\n' …
      FAIL=$((FAIL + 1))
    elif printf '%s' "$result" | grep -q 'ALL PASS'; then
```

`xarm.sh` itself keys on nothing —
`grep -n 'RESULT\|OVERALL\|NORESULT' doc/claude/signal_browser_2pane_batch/xarm.sh` returns
no output. It delegates: `suites` → `run_suites.sh`, `one` → `gated_xschem.sh`.

The disagreement costs registrations in the **other** direction too, so this is genuinely
symmetric and not just "run_suites.sh is behind".
`tests/headless/test_statusmsg_hold_0248.tcl:22-23`:

```
# NOT registered in tests/run_regression.tcl: that harness runs everything with --nogui and
# demands an "OVERALL: ok" sentinel, which an X-gated self-skip cannot honestly print.
```

## Blast radius — measured, not one file

Eight suites pass and emit **zero** `RESULT:` lines (`grep -cE 'RESULT'` over each file is
`0`), so all eight are `NORESULT` through `run_suites.sh`:

| suite | checks | banner |
|---|---|---|
| `test_wire_split` | 121 | `OVERALL: ok` |
| `test_crossview_paste` | 28 | `OVERALL: ok` |
| `test_pin_type_edit` | 19 | `OVERALL: ok` |
| `test_hi_descend` | 19 | `headless: all checks passed` |
| `test_add_pin_lib_symbol_view` | 12 | `OVERALL: ok` |
| `test_readonly_guard` | 11 | `READONLY_GUARD_TEST_PASS` |
| `test_cadence_descend_newwin_ro` | 5 | `headless: all checks passed` |
| `test_nogui` | — | `NOGUI_TEST_PASS` |

The first four `OVERALL: ok` ones were measured through the X arm and all four reported
`NORESULT`.

A ninth has the same hole in a different flavour: `test_lib_new_discovered_defs` passes 21
checks and prints, at `tests/headless/test_lib_new_discovered_defs.tcl:155`,
`RESULT: all passed` — **lowercase**. `run_suites.sh:104` finds a `^RESULT` line, so it is
not `NORESULT`; `:112`'s `grep -q 'ALL PASS'` then misses, so it is scored **FAIL**.

Six further candidates (`test_ciw_autocomplete`, `test_ciw_puts_capture`,
`test_readonly_action_dispatch`, `test_palette`, `test_ihp_sg13g2_libmgr`,
`test_pdk_launcher`) need a real display and were left unmeasured rather than claimed.

The hazard is already called out in-tree, which is why the shape is recognisable:
`tests/headless/wvbs_common.tcl:20-22` — "a shared prelude called `test_…` … would print no
RESULT banner and would be scored FAIL forever" — echoed at
`test_wave_sigbrowser_2pane.tcl:37-39` and `test_wave_sigbrowser_i1315.tcl:88-90`.

### One claim in `full_audit.sh` is wrong

`tests/headless/full_audit.sh:78-80` names **`test_select_at`** among the tests that "only
ever print `OVERALL: ok`". It does not — `tests/headless/test_select_at.tcl:130-131`:

```tcl
if {$::fails} { puts "RESULT: $::fails FAILED" } else { puts "RESULT: ALL PASS" }
puts "OVERALL: [expr {$::fails ? {notok} : {ok}}]"
```

It emits **both**. Measured through the X arm it reported `FAIL | test_select_at
RESULT: 5 FAILED`, not `NORESULT`. The named set is four shipped tests, not five. (Its five
failing checks under X are a separate matter and were not investigated.)

## Repro

```sh
env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wire_split.tcl
#  -> exit 0, 121 "ok:" lines, 0 "^RESULT:" lines, one "OVERALL: ok"

SUITE_TIMEOUT=400 ./doc/claude/signal_browser_2pane_batch/xarm.sh suites test_wire_split.tcl
#  -> NORESULT | test_wire_split   run 1/1 (exit 0 — binary never reported)
#  -> RESULT: 0/1 runs passed      (exit 1)
```

Pre-existing at `pre-open-pdk-merge-4`: `git show pre-open-pdk-merge-4:tests/headless/test_wire_split.tcl`
contains 0 occurrences of `RESULT` and 3 of `OVERALL` — `:16` the same header comment, `:24`
`bail`, `:626` the final banner. The body was re-authored 2026-08-06 for `wire_label_ride`
S2; the sentinel choice is identical. `tests/run_regression.tcl` gained only four `hcases`
lines across the merge.

### Two precision corrections to the report

* **`xarm.sh one` is not a scoring path.** `xarm.sh one test_wire_split.tcl` renders no
  verdict at all — 121 `ok:`, `OVERALL: ok`, zero `RESULT`, and no PASS/FAIL/NORESULT
  classification. Only `xarm.sh suites` (→ `run_suites.sh`) produces `NORESULT`.
* **The `.tcl` suffix is load-bearing.** `xarm.sh one test_wire_split`, worded without it,
  does not run the file — `couldn't read file "test_wire_split": no such file or directory`
  — and still exits 0.

## Suggested fix

Teach `run_suites.sh` the fallback `full_audit.sh:99` already ships, rather than editing
nine test files. It is the only one of the three readers missing it, and adding a `RESULT:`
line to each suite would still leave `run_suites.sh` unable to read the *next* test written
to the `run_regression` convention.

At `tests/headless/run_suites.sh`, immediately after line 104:

```sh
    result=$(printf '%s\n' "$out" | grep -E '^RESULT' | tail -1)
    # Fall back to the older run_regression sentinel, exactly as full_audit.sh:99 does.
    # Four shipped suites (test_wire_split 121 checks, test_crossview_paste 28,
    # test_pin_type_edit 19, test_add_pin_lib_symbol_view 12) only ever print
    # "OVERALL: ok" and were scored NORESULT here while passing every own check.
    if [ -z "$result" ]; then
      if printf '%s\n' "$out" | grep -qx 'OVERALL: ok'; then
        result="RESULT: ALL PASS (via OVERALL: ok sentinel)"
      elif printf '%s\n' "$out" | grep -qx 'OVERALL: notok'; then
        result="RESULT: FAILED (via OVERALL: notok sentinel)"
      fi
    fi
```

Two details that are the whole point of the fix:

* **`OVERALL: notok` must map to FAIL**, not fall through to `NORESULT` — otherwise a real
  failure in those four suites stays indistinguishable from today's state.
* **`grep -qx`** (whole line), matching `run_regression.tcl:115`'s anchored
  `{^OVERALL: ok$}`, so the string appearing inside a check's message cannot forge a pass.

Two smaller items, arguably separate:

* `test_lib_new_discovered_defs` should print `RESULT: ALL PASS` instead of
  `RESULT: all passed`. `full_audit.sh:90` already carries a bespoke case for the lowercase
  banner that could then be deleted too.
* The four custom-banner suites (`test_nogui` `NOGUI_TEST_PASS`, `test_readonly_guard`
  `READONLY_GUARD_TEST_PASS`, `test_hi_descend` and `test_cadence_descend_newwin_ro`
  `headless: all checks passed`) each already need a bespoke case at `full_audit.sh:87-98`.
  Giving those four a standard `RESULT: ALL PASS` line would let both harnesses read them
  without special-casing. The fallback above does not reach them.

**Do not "fix" this by adding a `RESULT:` line to `test_wire_split` alone.** That leaves
`run_suites.sh` still unable to read the convention, and `test_statusmsg_hold_0248.tcl:22-23`
shows the disagreement already costs registrations in the opposite direction. Whichever way
it is fixed, the aim is **one banner rule shared by `run_regression.tcl`, `full_audit.sh`
and `run_suites.sh`**.

---

## What actually shipped

The fallback went into `tests/headless/run_suites.sh` as proposed, but **three details of
the suggested patch above are wrong**, each found by reading the other two harnesses and
each proven by a run:

### 1. `grep -qx` is too strict — it converts only four of the six, not six

`test_ihp_sg13g2_libmgr.tcl:195` and `test_pdk_launcher.tcl:119` print
`OVERALL: ok ($npass checks)`, not a bare `OVERALL: ok`. A whole-line `-qx` refuses both,
so the suggested patch leaves them `NORESULT` — the same red-but-hollow it set out to end.
Shipped instead:

```sh
grep -qE '^OVERALL: ok([[:space:]]+\([^)]*\))?[[:space:]]*$'
```

still whole-line (a check message mentioning the string cannot forge a pass) but tolerant
of the count suffix. `full_audit.sh` never hit this because its match is a **substring**
(`*"OVERALL: ok"*`); `run_regression.tcl:115` never hit it because neither suite is
registered there.

### 2. `notok` is not the only failure spelling

Of the six suites the fallback reaches, `notok` covers three. `test_add_pin_lib_symbol_view`
prints `OVERALL: FAIL`, and the two `(N checks)` suites print `OVERALL: N FAILED (M passed)`.
Matching only `notok` would have left those three failures reported as `NORESULT`, i.e. the
issue's stated point unmet for half the set. Shipped: `^OVERALL: (notok|FAIL|[0-9]+ FAILED)`.

### 3. The fallback needs `full_audit.sh`'s `is_skip` guard, or it forges a green

This is the one that would have shipped a bug. `tests/headless/test_grid_toggle_sel_gc.tcl:34-36`
self-skips with

```tcl
puts "SKIP: no X connection (has_x=0); run under DISPLAY with --pipe"
puts "OVERALL: ok"; exit 0
```

so on the `--nogui` arm the suggested patch scores it **PASS with zero checks run**.
`full_audit.sh:125-132` says in its own comment that running `is_skip` *before* `is_pass` is
"what keeps the `OVERALL: ok` arm above honest". `run_suites.sh` now has a `SKIP` class,
checked before pass/fail, which also fixes a **pre-existing** hollow green: the legacy
banner `RESULT: ALL PASS (0 checks, skipped: no X)` used to match `ALL PASS` and score PASS.
Measured: `run_suites.sh --nogui test_grid_toggle_sel_gc` → `SKIP … RESULT: 0/0 runs passed (1 skipped)`.

Also shipped, same reasoning: the pass arm requires **exit 0** (as `run_regression.tcl:116`
does), and a banner followed by a nonzero exit is reported as
`FAIL … RESULT: FAILED (OVERALL: ok but exit 2)` rather than a "binary never reported"
`NORESULT`.

### The measured before/after — six converted, and the count is neither 4 nor 8

Same tree, same binary, `xarm.sh suites` on the gated `:0`; only `run_suites.sh` differs.

| suite | before | after | checks under X | checks headless |
|---|---|---|---|---|
| `test_wire_split` | NORESULT | **PASS** | 121 | 121 |
| `test_crossview_paste` | NORESULT | **PASS** | 28 | 28 |
| `test_pin_type_edit` | NORESULT | **PASS** | 19 | 19 |
| `test_add_pin_lib_symbol_view` | NORESULT | **PASS** | 12 | 12 |
| `test_pdk_launcher` | NORESULT | **PASS** | 30 | needs X |
| `test_ihp_sg13g2_libmgr` | NORESULT | **FAIL** | 65 ok + **1 real fail** | needs X |
| `test_hi_descend` | NORESULT | NORESULT | — | custom banner, unreached |
| `test_readonly_guard` | NORESULT | NORESULT | — | custom banner, unreached |
| `test_cadence_descend_newwin_ro` | NORESULT | NORESULT | — | custom banner, unreached |
| `test_nogui` | NORESULT | NORESULT | — | custom banner, unreached |
| `test_lib_new_discovered_defs` | FAIL | FAIL | — | lowercase `RESULT: all passed`, unchanged |
| `test_select_at` | FAIL | FAIL | — | 5 real failures, unchanged |

So the disputed count resolves as **six**: the four this issue named, plus the two
`(N checks)` suites it listed as "left unmeasured rather than claimed". The backlog's eight
counted the four custom-banner suites, which the fallback does not reach — both numbers
were right about different things, and neither is the number of suites converted.

`test_ihp_sg13g2_libmgr`'s FAIL is **pre-existing and newly readable**, which is the whole
point of the fix: its "exactly the 9 intended libs" check now sees 12. Filed as
`doc/claude/issues/0324-test-ihp-sg13g2-libmgr-expects-nine-libs-and-the-workarea-now-has-twelve.md`.

### Sabotage — the forged pass, run rather than reasoned about

A scratch suite whose *check message* contains the literal string, and nothing else:

```tcl
puts "ok: banner reads OVERALL: ok when every check passes"
exit 0
```

* shipped anchored form → `NORESULT | sab_forge … exit 1`;
* the same harness with the anchor removed (`grep -qE 'OVERALL: ok'`) →
  `PASS | sab_forge  RESULT: ALL PASS (via OVERALL: ok sentinel)`.

Eleven scratch suites were run in all: `OVERALL: ok` → PASS, `OVERALL: ok (7 checks)` → PASS,
trailing-whitespace banner → PASS, `notok`/`OVERALL: FAIL`/`OVERALL: 3 FAILED` → FAIL,
the forge → NORESULT, banner-then-`exit 1` → FAIL, the two self-skip banners → SKIP, and the
ordinary `RESULT: ALL PASS` / `RESULT: 2 FAILED` pair unchanged.

### Still open, and deliberately not done here

* `test_lib_new_discovered_defs`' lowercase `RESULT: all passed` still scores FAIL through
  `run_suites.sh` (`full_audit.sh:90` carries a bespoke case for it).
* The four custom-banner suites still need `full_audit.sh:87-98`'s bespoke cases.
* A **fourth** reader exists — `tests/headless/wireedit/run_wireedit.sh` — stricter than all
  three; it was not touched.
