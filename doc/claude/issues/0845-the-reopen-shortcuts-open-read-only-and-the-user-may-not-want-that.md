# 0845 — `Ctrl+Shift+O` opens the design READ-ONLY, and that is the user's normal way in

Status: **OPEN — a RULING, not a defect.** The behaviour is deliberate and
documented in the code; whether it is right for this user's workflow is theirs to
decide. Surfaced 2026-08-26 from the user's own action log while investigating
something else. Related: 0839 (the other half of Ctrl+Shift+O), 0843.

## Measured

`/tmp/Xschem.log.6`, the user's session, first toplevel line of every trace
block:

```
.  normal 1000x800+3713+296  'xschem [3] - tb_bandgap.sch (read-only)'
```

The design they were about to netlist, run and annotate was **read-only**, and
nothing about the flow announced it. They did not report it — it was found in the
log.

`src/scheduler.c:7559-7564` says why, and says it plainly:

```c
/* -lastopened/-lastclosed come ONLY from the reopen shortcuts (Open Most Recent
 * Ctrl+Shift+O / Open Last Closed Ctrl+Shift+T / the Recent menu), which default
 * to read mode. ... Edit with Ctrl-2 / View > Toggle Read Only. */
if(lastclosed || lastopened) readonly_open = 1;
```

So this is by design and consistently applied across every dispatch site.

## The question

The user opens `tb_bandgap` with **Ctrl+Shift+O every session** — it is their
normal way in, not an occasional browse. Under the shipped rule that means their
normal way in is also the read-only way in, and the first thing they learn about
it is an edit being refused.

**Keep read-only-by-default** (defensible: a reopen shortcut is a "show me that
again" gesture, and read mode protects a design you did not mean to touch), **or
make the reopen shortcuts open editable** like an ordinary `File > Open`?

A third option worth naming: keep read-only but make it **loud** — the title bar
already says it, and the title bar is the one thing a user never reads. The
status line or the CIW saying *"opened read-only, Ctrl-2 to edit"* on the reopen
path would cost nothing and would have made this discoverable without a log.

⚠ **Not to be decided by whoever notices it next.** It is a shipped, deliberate,
user-visible default; on the owed ledger as `rule` debt `[0845]`.
