# 1241 — `log_action`'s unbounded `vsprintf` aborts the editor on a long menu command

**Status:** FIXED at the `annotate` → `fluid-editing` merge, 2026-09-01.
Filed after the fact because the defect is older than the merge and the merge
only made it reachable.

## The crash, measured

Clicking **Waves > Op Annotate** killed the process:

```
*** buffer overflow detected ***: terminated
```

Backtrace (gdb, this tree, 2026-09-01):

```
#7  __GI___fortify_fail (msg="buffer overflow detected")
#8  __GI___chk_fail ()
...
#13 __vsprintf_internal (...)
#14 log_action ()
#15 xschem_cmds_l.constprop ()
#16 xschem ()
#17 TclInvokeStringCommand ()
```

The string being formatted was **4971 bytes**: the menu entry's own `-command`
script, which `xschem callback` logs. Not a hang and not a wrong answer — the
editor died on a menu click, with whatever the user had open in it.

## The cause, and why it had never fired

`src/util.c`, `log_action()`:

```c
  char buf[4096]; /* pane copy only; the file write below is unbounded */
  ...
#ifdef HAS_SNPRINTF
  vsnprintf(buf, S(buf), fmt, args);
#else
  vsprintf(buf, fmt, args); /* action lines are short xschem commands */
#endif
```

**`HAS_SNPRINTF` is defined nowhere in this tree** — not in `config.h`, not in
`scconfig/`, not on any command line (`grep -rn HAS_SNPRINTF config.h src
scconfig` finds only this one use). So the **unbounded arm is the one that has
always been compiled, on every platform**, and the bounded arm has never once
run. The `#ifdef` read as protection and was decoration.

The comment was the other half of it: *"action lines are short xschem commands"*
is true of a typed command and false of a Tk `-command`, which is the entry's
whole script, comments included. Nothing enforced the assumption.

The merge brought it into range: annotate's `Op Annotate` body carries issue
0683's ruling in prose, and the merge added R505b's cadence gate and its reason
on top, taking the script past 4096 bytes.

## The fix

`vfprintf` above already formats the same text into the log file **and returns
its length**, so the pane copy is now allocated at exactly that size rather than
guessed at:

```c
  n = vfprintf(actionlog_fp, fmt, args);
  ...
  if(actionlog_suppress_echo || n < 0) return;
  buf = my_malloc(_ALLOC_ID_, (size_t)n + 1);
```

Exact rather than larger, deliberately: a bigger fixed buffer would only move the
cliff, and this codebase is C89, so there is no `snprintf` to reach for. A
negative count (an output error) mirrors nothing, which is the right answer for
text that was not written. The dead `#ifdef` is gone with the comment that
misdescribed it.

## What to check next, not done here

`log_action` is not the only `vsprintf` in the tree, and `HAS_SNPRINTF` being
undefined may leave others compiled on their unbounded arm. That is a survey and
belongs in its own commit:

```sh
grep -rn 'vsprintf\|HAS_SNPRINTF' src/*.c src/*.h
```
