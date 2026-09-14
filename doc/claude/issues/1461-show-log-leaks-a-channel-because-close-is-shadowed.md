# 1461 — `show_log` leaks a file channel, because `close` is shadowed inside `ase::ui`

**Status:** open · **Filed:** 2026-09-13 by the driver, one line further than issue **1460** looked
**Area:** ASE-L / `src/ase_window.tcl` · **Related:** 1460 (found the class and fixed the `open`)

## The defect

`src/ase_window.tcl:11079`, inside `proc ase::ui::show_log`:

```tcl
# ::open — inside ase::ui a bare `open` resolves to ase::ui::open
set fh [::open $f r]
set data [read $fh]
close $fh                      ;# <- reaches ase::ui::close, NOT Tcl's
ase::ui::log_append $key $data
```

Issue **1460**'s crew found the shadowing class and fixed the `open` on the line above, comment and
all. **The `close` on the next line was missed.**

`proc ase::ui::close {key}` exists at `:681`. A proc defined as `proc ase::ui::show_log` runs its
body **in the `ase::ui` namespace**, so an unqualified command is resolved there first — and
`ase::ui::close` takes exactly one argument, so it matches.

## Measured, not reasoned

```tcl
namespace eval demo {}
proc demo::close {key} { set ::HIT "SHADOW reached with key=$key" }
proc demo::reader {path} {
  set fh [::open $path r]; set d [read $fh]
  close $fh                       ;# unqualified
  return [string length $d]
}
```

```
bytes read     : 6
which close    : SHADOW reached with key=file3
open channels  : file3            <- STILL OPEN
```

**The shadow is reached and the channel is not closed.**

## What it costs, and what it does not

* ⚠ **One leaked file channel per `show_log` invocation.** `show_log` is something a user opens
  repeatedly while watching a run, so the count is bounded by their patience rather than by
  anything in the code.
* **No state damage.** `ase::ui::close` returns at its first line for an unknown key —
  `if {![dict exists $wins $key]} { return }` — and a channel name is never a session key. So the
  spurious call is inert, which is why nothing has ever gone visibly wrong.
* **Exactly one site.** A sweep of every unqualified `close $…` inside an `ase::ui::` proc in
  `src/ase_window.tcl` finds this line and no other.

## The fix

`close $fh` → `::close $fh`, matching the `::open` on the line above.

## ⚠ The general rule, which is the part worth keeping

**`src/ase_window.tcl` shadows two of Tcl's most-used built-ins**, `open` (`:619`) and `close`
(`:681`), and every proc in that file runs in the namespace that shadows them. So:

* **Any file I/O anywhere in `ase::ui` must be spelled `::open` and `::close`.**
* ⚠ **A `catch` around the read does not save you — it is what hides the failure.** Issue 1460's
  crew measured seven of its own suite rows going green while reading an **empty string**, because
  a bare `open` inside a total reader's `catch` answers nothing and says nothing. **A total reader
  that catches the wrong `open` is worse than no reader**, and this is the one place in the batch
  where the defensive pattern it adopted actively conceals a defect.
* A lint would be cheap: every `\[open ` and every `^\s*close \$` in that file must carry the `::`.
