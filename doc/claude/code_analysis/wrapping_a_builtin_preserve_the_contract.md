# Tutorial — wrapping a built-in: preserve the *whole* contract

A short, transferable lesson pulled from a one-line bug in issue 0129. The topic is bigger than
xschem: **any time you interpose on a primitive — redefine, wrap, decorate, monkey-patch, subclass,
shim — you inherit its entire observable contract, and "mostly transparent" is a bug.** The concrete
case is Tcl's `puts`, but the shape recurs in every language.

## 1. The setup: intercept a built-in, keep its old behavior, add a new one

The CIW console runs a user's command and must both *show* the command's `puts` output in the pane
**and** record it in the action log. The chosen mechanism (src/ciw.tcl) is classic interposition:
rename the real `puts` aside and install a replacement for the duration of the command.

```tcl
rename ::puts ::ciw_saved_puts
proc ::puts {args} {ciw_capture_puts $args}
set code [catch {uplevel #0 $cmd} res]     ;# run the user's command; capture its RESULT
rename ::puts {} ; rename ::ciw_saved_puts ::puts
```

`ciw_capture_puts` echoes to the pane and (after the fix) buffers the text for the log:

```tcl
proc ciw_capture_puts {argl} {
  ...
  if {$n == 1} {
    ciw_echo [lindex $a 0] result
    lappend ::ciw_out_pending result [lindex $a 0]   ;# <-- the last statement executed
  } elseif ...
}
```

Looks right. The pane updates, the log gets the text. Ship it.

## 2. The bug: the wrapper changed the return value

A command typed in the CIW is run through `catch {uplevel #0 $cmd} res` — so **`res` is the command's
return value**, and the transcript logs it as a `#= ` line when non-empty. For `puts [expr $a + $b]`
the *real* `puts` returns `""`, so there is no result line — only the printed `30`.

But the replacement `proc ::puts` returns whatever its body's last statement returns, and that last
statement was `lappend ::ciw_out_pending result 30`, whose value is the **list** `result 30`. So the
redefined `puts` returned `"result 30"`, `res` became non-empty, and the log grew a spurious line:

```
puts [expr $a + $b]
#= 30
#= result 30        <-- garbage: the wrapper's return value leaked into the transcript
```

The real `puts` promises to return `""`. The wrapper kept the *side effect* (printing/logging) but
broke the *return value*. One missing line — `return {}` at the end of the proc — was the whole fix:

```tcl
  ...
  }
  return {}   ;# a real puts returns "" -- match it, or a command ending in puts mints a bogus result
}
```

## 3. Why it hid — and the testing lesson

The natural unit test calls the wrapper directly and checks the visible effect:

```tcl
ciw_capture_puts [list 30]
assert {[log contains "#= 30"]}          ;# passes — the side effect is correct
```

That test **cannot** see the bug, because the bug is not in what `ciw_capture_puts` *does* — it is in
what it *returns to its caller*. And the caller is not the test; it is `catch {uplevel …} res` inside
`ciw_exec`. The defect only exists when a **real `puts` command flows through the real call site**.

> **Testing lesson:** exercise a wrapper in its *actual calling context*, not just by calling it. For
> an interposed primitive that means: run a real statement that uses it through the same
> eval/catch/return path the production code uses, and assert on the *caller's* observation
> (`$res`), not only the wrapper's side effect.

The regression test now does exactly this — a child process redefines `::puts`, evaluates a genuine
`puts HIFAITHFUL` through `catch {uplevel …} res`, and asserts the log has **no** spurious result
line. Delete the `return {}` and that one check goes red; a direct-call test stays green.

## 4. The general principle: a transparent wrapper matches the ORIGINAL's observable contract

"Observable contract" is everything a caller can notice:

| Facet | The trap |
|---|---|
| **Return value** | forgetting to return it (or returning the wrong thing — the bug above) |
| **Side effects** | dropping one, or doing it twice (double-log, double-echo) |
| **Errors** | swallowing an exception the caller expected, or raising a different one |
| **Arity / options** | not forwarding all args/flags (here: `-nonewline`, `stdout`, `stderr`, a channel) |
| **Ordering / timing** | doing the added work at the wrong moment (0129's other half: output logged before the command line) |
| **Identity / teardown** | leaving the replacement installed after it should be gone (scoping) |

The same shape in other ecosystems — all real, common bugs:

```python
# Python decorator that forgets to return the wrapped result
def timed(fn):
    def wrap(*a, **k):
        t = time.time()
        fn(*a, **k)                 # BUG: result dropped; callers get None
        log(time.time() - t)
    return wrap
# fix: `r = fn(*a, **k); log(...); return r`
```
```javascript
// JS monkey-patch that breaks the return value
const orig = arr.push;
arr.push = function (...xs) { audit(xs); orig.apply(this, xs); };  // BUG: push must return new length
// fix: `const n = orig.apply(this, xs); audit(xs); return n;`
```
```java
@Override public int size() { metrics.hit(); }   // BUG: forgot to return super.size();
```
```sh
ls() { command ls "$@"; echo "(listed)"; }   # BUG: exit status is now echo's, not ls's
# fix: `command ls "$@"; local rc=$?; echo "(listed)"; return $rc`
```

Every one keeps the new behavior and quietly corrupts an original guarantee — usually the return
value or the status, because those are invisible until a *caller downstream* consumes them.

## 5. A checklist for interposing on a primitive

Before shipping a wrapper / override / patch, confirm it is transparent on each axis:

1. **Returns** what the original returns (capture it in a variable, do your work, return it). For a
   value-less primitive, return the *same empty/void* it returns — don't let your last statement leak.
2. **Propagates errors/status** identically (don't swallow; preserve exit code / exception type).
3. **Forwards every argument and mode** you don't explicitly mean to intercept (fall through the rest
   to the original).
4. **Performs each side effect once**, at the **right time** relative to the original's effect.
5. **Restores** the original when the interposition is scoped (balanced install/uninstall, even on the
   error path — `catch`/`finally`).
6. **Is tested through the real call site**, asserting on a downstream caller's observation, not just
   the wrapper's visible output — and, where order matters, asserting order, not just presence.

The one-word version: a wrapper should be a **pass-through with a note in the margin**, never a
rewrite of the page.

Related: `doc/claude/code_analysis/ciw_actionlog_transcript_tutorial.md` (the full action-log case,
including the ordering half of 0129), `doc/claude/issues/0129-ciw-actionlog-drops-exit-and-puts-output.md`.
