# 0699 — `notify_log` claims the durable sink while `actionlog_suppress` discards every byte

Status: OPEN (measured, NOT fixed — deliberately out of scope for the 0674+0675+0677 batch)
Filed by: the 0674+0675+0677 crew (the notify-channel cluster, batched)
Class: 0652's — **a report that LIES about what it did**. Seventh appearance in this cluster.

## The measurement

At `e9232ec3`, with a durable log open (`--logdir`):

```tcl
xschem set actionlog_suppress 1
set r [::xschem::notify {SUPMARK-suppressed} -tag error]
```

| what was asked | what was answered | what is true |
|---|---|---|
| `xschem::notify_log` returned | `1` | nothing was written |
| `xschem::notify` returned | `1` | — |
| `notify_last` `sinks` | `{ciw log}` | the log received **0 bytes** |
| `file size` delta around the write | **0 bytes** | — |
| occurrences of `SUPMARK-suppressed` in the log file | **0** | — |

Control, with the suppress cleared: delta **16 bytes**, mark count **1**.

## The mechanism

`log_output()` (`src/util.c:540`) gates on `!actionlog_fp || actionlog_suppress`.
Issue 0657's honesty gate — the reason `notify_log` returns 0 under `--nolog` —
only ever measured the **first half** of that disjunction. `actionlog_suppress`
is a live depth counter (`src/util.c:566-585`), set through
`xschem set actionlog_suppress N` (`src/scheduler.c:11733`) and used by replay
and programmatic paths (e.g. `src/select.c:313`), so this is a state a real
session enters, not a contrivance.

The sink 0650's table calls **"log: always"** is therefore claimed while it
wrote nothing.

## Why it was not fixed here

0497 rule 2 — **split by cause, never one aggregate**. This is a distinct cause
from 0674/0675/0677 and it has its own blast radius:

* the Tcl-only remedy (a `file size` delta inside `notify_log`) would change the
  delivery accounting of **every** notice on **every** suppressed replay path,
  which is a behaviour change outside the batch that measured it;
* the clean remedy is a C-side getter (`xschem get actionlog_suppress`) beside
  the existing setter at `src/scheduler.c:11733` — a `scheduler.c` edit and a
  rebuild, which was not this step's lane.

There is **no** `xschem get actionlog_suppress` today; the setter exists alone.
That is why Tcl cannot see the state at all.

## What ships instead, in the meantime — NOTHING. The carrier was reverted.

The 0674+0675+0677 attempt that measured this hole introduced a
`xschem::notify_reach` whose log arm rendered

```
log=blind(open,UNVERIFIED issue 0699)
```

so the announcement would **admit the uncertainty** rather than assert liveness.
**That attempt was REVERTED** (status F — its adversary leg refuted the central
claim; see the three issue files and
`doc/claude/evidence/0674_0675_0677_attempt/`). No predicate exists in the tree
today, so this hole is currently **unannounced as well as unfixed**: at HEAD
`notify_log` returns 1, `notify_last sinks` names `log`, and zero bytes are
written, with nothing anywhere admitting it.

The `blind(open,UNVERIFIED issue 0699)` rendering remains the recommended shape
for whoever rebuilds the predicate — the point survives the revert.

## Acceptance, when someone takes it

1. A row that sets `actionlog_suppress 1`, notifies, and asserts `notify_log`
   returns **0** and `notify_last sinks` does **not** contain `log`.
2. The control with the suppress cleared still returns 1 and still names `log`.
3. `notify_reach`'s log arm stops saying `UNVERIFIED issue 0699` in the same
   commit, or says why it still must.

## ⚠ NUMBERING BOUNDARY

**0699 is the LAST number before the reserved block.** The next issue after this
one is **0800**, never 0700 — `0700-0799` is reserved by the user. See
`doc/claude/issues/NUMBERING.md`.
