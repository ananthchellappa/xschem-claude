# 0669 — `source_tcl_file`'s modal messageBox hangs an unattended interactive GUI startup, and announces nothing

Status: OPEN. Filed by the 0663 crew, 2026-08-24. Found by the scout, confirmed
by Verify-C, re-measured by the write-up agent on the shipping binary.

`src/xinit.c:1535-1545`.

## Measured, AFTER 0663 landed

A sharedir farm whose `op_annot.tcl` is `error {...}`, launched the way a **human
actually launches xschem** — on a display, with no `--pipe` and no `-q`:

```sh
timeout 15 env GUI_GATE=0 DISPLAY=:99 XSCHEM_SHAREDIR=$farm ./src/xschem \
    --logdir $d --script inner.tcl
```

```
EXIT=124 (timeout fired; the process had not exited)
ANNOUNCE_stderr=0
ANNOUNCE_log=0
Xschem.log = its 3 header lines, nothing else
```

The same farm with `--pipe -q` exits **1** with one announcement in each sink.

## Mechanism

```c
if(has_x && !cli_opt_pipe && !cli_opt_quit) {
  tcleval( "wm withdraw .");
  tcleval( tmp);            /* tk_messageBox -type ok  -- MODAL, blocks here */
  Tcl_Exit(EXIT_FAILURE);
}
return TCL_ERROR;
```

`source_tcl_file()` pops a modal `tk_messageBox` and **blocks inside itself**. It
never returns, so 0663's guard at `src/xinit.c:3571` is never reached and none of
0663's announcement machinery runs. With nobody at the desk to click OK the
process waits forever.

## Why this is the half that matters to the user

0663's fix covers `--nogui`, `--pipe`, `-q` and `-b/--detach` — i.e. every test
harness and every scripted launch, which is the shape 0423/0424 measured. It does
**not** cover the plain interactive GUI launch, which is the only shape the
eyes-on user ever types. For them a broken helper still means: a dialog, no
durable record, and a process that does not leave.

0663's own GUI test legs run `--pipe -q` precisely to stay off this branch, so
**nothing tests it**.

## Options

| # | option | note |
|---|---|---|
| (a) | announce first, then show the dialog | smallest change: call the announcement (stderr + `log_output`) **before** the `tcleval(tmp)`, so the durable record exists whether or not anyone clicks. Does not fix the hang |
| (b) | make the dialog non-blocking or time-limited | a `tk_messageBox` cannot be timed out portably; needs a hand-built toplevel with an `after` auto-dismiss |
| (c) | drop the dialog and use 0663's path uniformly | one behaviour for all launch modes: announce, exit 1. The GUI user loses a dialog they cannot act on anyway and gains a log line and a terminated process. **Recommended** |

(c) is a user-visible change and needs a ruling; (a) is strictly an improvement
under any of them and could land first.

## Acceptance

A GUI launch with a broken helper must, within a bounded time, write exactly one
`STARTUP ABORTED` line to `Xschem.log` and exit non-zero — measured with
`timeout`, on `:99`, with no `--pipe`/`-q`.

## Still open

All of it.
