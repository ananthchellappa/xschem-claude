# A file-based control gate for a long-running test suite — build notes & lessons

A teaching writeup of the GUI-test control gate (shipped 2026-07-22,
commit 2e4bb185). Product spec: `doc/claude/specs/gui_test_gate.md`. Code:
`tests/headless/gui_gate_widget.tcl`, `tests/headless/gui_gate.sh`,
wired into `tests/headless/full_audit.sh`.

The interesting part is not the Tk widget — it is the **cross-process control
protocol** and the **fail-open discipline**. Both generalize to any situation
where one small interactive controller must govern many unrelated worker
processes it did not spawn.

---

## 1. The problem, and why the first attempt rotted

`full_audit.sh` opens dozens of short-lived xschem windows on a WSLg display.
Run directly it is annoying; run by a fleet of background **workflow crews**
(each item's implement + verify stage runs the suite) it makes the machine
unusable — with no warning and no way to pause.

A previous gate existed as a **Claude Code `settings.local.json` PreToolUse
hook**. It worked for a couple of days, then silently stopped. Root cause: that
file got rewritten and the hook was simply gone. Nothing warned, because the
thing that would have warned was what got deleted.

**Lesson 1 — put durable behavior where it cannot be clobbered by an unrelated
edit.** A test-harness concern belongs in the git-tracked test harness, not in
a settings file that other tooling rewrites wholesale. The moment the gate
moved into `full_audit.sh` + a sourced shell lib, "it disappeared again"
stopped being possible.

There is a second, subtler reason the harness is the right home: the heaviest
load is the **workflow crews**, whose test runs happen inside subagent bash in
separate worktrees. A hook on the *main session's* tool calls never sees those.
The chokepoint that every run — main or subagent — passes through is
`full_audit.sh` itself. Gate the chokepoint, not one caller of it.

---

## 2. Why a filesystem protocol (not a socket, signal, or env var)

The controller (a `wish` panel) and the workers (`full_audit.sh` processes)
are mutually anonymous:

- The panel does not spawn the suites and vice-versa — either may start first.
- Workers run in **different worktrees** and as **subagents**, so no shared
  process tree, no inherited pipe, no agreed TCP port is guaranteed.
- What they *do* share is `$HOME`.

So the rendezvous is a **directory under `$HOME`**
(`~/.claude/gui_test_gate/`, override `GUI_GATE_DIR`). Files are the IPC:

```
widget.pid        controller liveness / singleton lock
req/<pid>         a worker dropped this and is BLOCKED until it is removed
control           RUN | PAUSE | STOP   (workers poll this)
status/<pid>      "which suite / which test"  (controller displays this)
snooze_until      epoch; controller shows a countdown, auto-proceeds at expiry
```

Files win here because they are **location-independent** (every process finds
`$HOME`), **inspectable** (`cat control` to debug), **crash-safe** (a dead
worker just leaves a stale file a sweep removes), and need **no handshake to
establish a channel**. The cost — polling latency — is irrelevant at a
0.3 s tick for a human-driven pause.

**Lesson 2 — for anonymous, restartable, multi-worktree peers, a shared
directory is a more robust bus than any connection-oriented channel.**

---

## 3. Two independent concerns, two mechanisms

The requirements look like one feature but split cleanly:

**(a) Go-ahead — "warn before every suite."** Per-worker, one-shot. Each suite,
at startup, drops `req/<pid>` and **blocks until that file is removed**:

```sh
printf '%s' "$label" > "$req"
while [ -f "$req" ]; do
  _gate_widget_alive || { rm -f "$req"; break; }   # fail open
  sleep 0.3
done
```

The controller owns *all* removal logic: **Proceed** deletes every pending
`req/*`; a **Snooze** timer deletes them on expiry (auto-proceed); **Stop**
deletes them so blocked workers can exit. The worker side is trivial and has no
policy — it just waits for its token to vanish. Because Proceed clears *all*
pending requests at once, several suites that pile up while you were away are
released by a single click, yet each *new* suite still re-arms its own request
(honoring "warn before every suite" without click-spam).

**(b) Pause/Resume/Stop — control a suite already running.** Global, level-
triggered. Checked at a **pause point between atomic tests**, never mid-test:

```sh
# top of the per-test loop, BEFORE running test N
gate_pause_point "full_audit | $name (next of $ntests)"
```
```sh
gate_pause_point() {
  printf '%s' "$1" > "$STATUSDIR/$pid"
  while true; do
    case "$(cat "$CONTROL" 2>/dev/null)" in
      PAUSE) _gate_widget_alive || return 0; sleep 0.3 ;;  # fail open
      STOP)  return 2 ;;
      *)     return 0 ;;
    esac
  done
}
```

The in-flight test always finishes (it is already under its own `timeout`); the
suite only holds at the boundary. Stop returns non-zero so the loop breaks and
reports a partial result.

**Lesson 3 — separate "may this start?" (per-worker, edge) from "control the
running thing" (global, level). Fusing them into one global mode forces false
choices** — e.g. a newly-arriving suite setting `WAIT` would pause a suite
already running. Keeping them orthogonal made "warn every suite" and
"pause everyone at once" both fall out for free.

---

## 4. Fail-open is a design rule, not an afterthought

A control gate that can **wedge the thing it controls** is worse than no gate.
Every failure mode here resolves to *tests run*:

- No `DISPLAY`, or `GUI_GATE=0`, or `wish` not installed → `gate_start` returns
  0 immediately (CI and true-headless are untouched).
- Panel cannot be launched → print a warning, proceed.
- Panel dies while a worker is blocked at go-ahead → the `_gate_widget_alive`
  check in the wait loop removes the request and proceeds.
- Panel dies while a worker is paused → the pause loop's liveness check returns
  0 (resume).
- User **closes** the panel (window-manager X) → treated as "get out of the
  way": it releases every request and sets `RUN`, never `STOP`. Aborting is a
  deliberate **Stop** button, not an accident of closing a window.

We verified fail-open the hard way: an early cleanup command killed the panel
mid-smoke and the suite printed `panel gone, proceeding` and ran green — the
bug (see §6) accidentally demonstrated the safety net.

**Lesson 4 — for any gate/lock/guard, enumerate every way it can fail and prove
each one degrades to "the protected work still happens." Write the test that
kills the controller mid-wait.**

---

## 5. Singleton controller with a liveness file

The first suite to need the panel launches it; later suites reuse it:

```sh
_gate_widget_alive() {          # pid file + kill -0 probe
  wp="$(cat "$GATE_DIR/widget.pid" 2>/dev/null)"
  [ -n "$wp" ] && kill -0 "$wp" 2>/dev/null
}
_gate_ensure_widget() {
  _gate_widget_alive && return 0
  ( wish "$dir/gui_gate_widget.tcl" "$GATE_DIR" >/dev/null 2>&1 & )
  for i in $(seq 1 20); do _gate_widget_alive && return 0; sleep 0.15; done
  _gate_widget_alive
}
```

`kill -0` is the cheap "is this pid alive" probe (signal 0 tests permission /
existence without delivering anything). A stale pid file loses the singleton
race harmlessly — the loser just launches a panel that finds nothing to do.
The panel is **persistent**: it survives across suites so the toggle state and
"running suites" readout stay live; closing it is explicit.

The Pause/Resume **toggle** (one button, two faces) is pure view: the poll loop
reads `control` and sets the button's label+colour (`Pause` amber ⇄ `Resume`
blue). The button command just flips the file. Keeping the button a projection
of the shared state — rather than tracking its own boolean — means it stays
correct even if a *different* process changed `control`.

---

## 6. The gotcha that cost the most time: `pkill` suicide

Every cleanup command like

```sh
pkill -f gui_gate_widget      # exit 144, shell dies
```

kept killing **its own shell**. `pkill -f` matches the pattern against every
process's full command line — including the shell currently running
`pkill -f gui_gate_widget`, whose command line literally contains
`gui_gate_widget`. It SIGTERMs itself; the tool reports exit 144 (128 + 16).

Fix — bracket a character so the pattern cannot match its own literal text:

```sh
pkill -f 'gui_gate_widget[.]tcl'   # matches wish's cmdline, not this one
```

`[.]` is a regex "literal dot" that reads as the four characters `[`, `.`, `]`
in the pkill command's own cmdline (so no self-match) but matches a real `.` in
the target `gui_gate_widget.tcl`. Same trick as the classic
`ps aux | grep '[s]shd'`.

**Lesson 5 — `pgrep`/`pkill -f` see themselves. Always bracket one character,
or match on a substring that only the target has.**

---

## 7. Reusing the pattern

To gate any other long loop with the same panel:

```sh
. tests/headless/gui_gate.sh
gate_start "my long job"                 # warn + block until Proceed
for item in "${items[@]}"; do
  gate_pause_point "my job | $item" || break   # hold on Pause, break on Stop
  do_work "$item"
done
gate_finish
```

Design checklist distilled from the above, reusable for any
"one controller, many anonymous workers" problem:

1. Rendezvous on a shared **directory under `$HOME`**, not a connection.
2. Split **admission** (per-worker, edge-triggered handshake) from **runtime
   control** (global, level-triggered flag polled at safe points).
3. Put the durable logic where an unrelated edit **cannot delete it**.
4. **Fail open** on every controller failure; write the kill-the-controller
   test.
5. Make interactive widgets a **projection of shared state**, not an
   independent copy.
6. Remember `pkill -f` **matches itself** — bracket the pattern.
