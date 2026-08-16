# 0367 - test_context_menu_log.tcl hangs under X, and one of its checks scans the whole log

Status: OPEN (measured, not fixed)
Found by: D4 RED agent, backlog run 2026-08-09/10, while placing the issue-0249
phantom-action-log row.
Class: HARNESS

## Symptom 1 -- the suite never finishes under a real/virtual display

`tests/headless/test_context_menu_log.tcl` is documented to run under X with
`--pipe --logdir`. Driven under xvfb it prints the first five `ok:` lines and
then hangs forever:

```
GUI_GATE=0 timeout 90 xvfb-run -a ./src/xschem --pipe -q --logdir $(mktemp -d) \
    --script tests/headless/test_context_menu_log.tcl </dev/null
ok:   action log open
ok:   copy pick logs 'xschem copy'
ok:   descend pick logs a '# ' marker
ok:   descend pick logs NO xschem command
ok:   gesture-start (place wire) logs no line
<hangs; killed at 90s -> EMERGENCY SAVE DIR / FATAL: signal 15>
```

It hangs in or after step 4 (`ctxpick 9`, load-recent, which loads
`xschem_library/examples/nand2.sch`) and step 5 (`source` the action log, which
REPLAYS every recorded command, including that `xschem load`). Stubbing
`ask_save` to decline does NOT unblock it, so the block is not the save prompt.
Headless it does not run at all -- it aborts on `invalid command "focus"`.

Consequence: the suite is scored as neither PASS nor FAIL anywhere. The
2026-08-09 D4 baseline recorded it only as "aborts headless", and nothing in the
tree runs it under a display.

## Symptom 2 -- an unscoped `lsearch` in check 2

```tcl
set n0 [llength [loglines]]
ctxpick 12
set lines [loglines]
check "descend pick logs a '# ' marker" \
  [expr {[lsearch -glob $lines {# context-menu: descend*}] >= $n0}]   ;# scoped
check "descend pick logs NO xschem command" \
  [expr {[lsearch -glob $lines {xschem descend*}] < 0}]               ;# NOT scoped
```

The second check searches the entire log rather than the window the pick just
opened. Its intent ("*this* pick logged no command") only coincides with its
implementation while nothing earlier in the session ever logs a descend line. A
legitimate earlier descend -- e.g. an accepted `descend symbol` pick -- makes it
fail without anything being wrong. It should read
`[lsearch -glob [lrange $lines $n0 end] {xschem descend*}] < 0`.

## Why it is filed rather than fixed here

D4's plan put the issue-0249 phantom-line row (R29) in this suite. Both symptoms
above make that impossible to verify: the suite never reaches an appended
section, and a correct row that logs an accepted descend trips symptom 2. The
row therefore lives in its own X-only file,
`tests/headless/test_context_menu_descend_refusal_0249.tcl`, which reproduces
the same Button3/`context_menu` retval seam in ~90 lines and completes under
xvfb in a few seconds. Merging the two suites is a separate repair.

## Repro

```sh
# symptom 1
GUI_GATE=0 timeout 90 xvfb-run -a ./src/xschem --pipe -q --logdir $(mktemp -d) \
    --script tests/headless/test_context_menu_log.tcl </dev/null ; echo "exit=$?"   # 124

# the replacement suite, same seam, terminates
GUI_GATE=0 xvfb-run -a ./src/xschem --pipe -q --logdir $(mktemp -d) \
    --script tests/headless/test_context_menu_descend_refusal_0249.tcl </dev/null
```

## Anchors

- `tests/headless/test_context_menu_log.tcl:45-51` -- the unscoped `lsearch`
- `tests/headless/test_context_menu_log.tcl:61-73` -- steps 4 and 5, where it blocks
- `src/callback.c` -- `context_menu_action()`, the seam both suites drive
