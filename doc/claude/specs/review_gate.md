# Review gate — "review requested" panel for the one-item-at-a-time build loop

Status: **IMPLEMENTED 2026-07-29**, `tools/review_gate/`. Self-test
`tools/review_gate/test_review_gate.sh` — 31 checks, green.

## The problem

Plans like `doc/claude/suggestions/plan_viewer_enhancements_2026-07.md` are built
**one item at a time**, and its own conventions say each item is independently
landable and wants a human eyeball before the next one starts. That leaves two
bad options and no good one:

- **Block on the ack unconditionally** — an item finished at 02:00 stalls until
  morning. Hours of idle build loop, for nothing.
- **Never block** — ten items land unreviewed, and a wrong call in item 5 is
  discovered only after items 1, 2 and 3 were built on top of it.

The gate is the middle: **ask, then self-release.** The builder raises a
request, a panel pops with a beep and a flash, and the request auto-proceeds
after a timeout (default **30 min**) unless the user explicitly holds it.

Same one rule as the GUI-test gate (`doc/claude/specs/gui_test_gate.md`):
**the only thing that blocks indefinitely is an explicit user hold.**

## Not the GUI-test gate

Deliberately a **separate control dir** (`~/.claude/review_gate`, not
`~/.claude/gui_test_gate`) and a separate panel. "I have eyeballed item 5" and
"do not flood my display with GUI tests right now" are different questions, and
one must never release the other. The two share only their *design*: singleton
`wish` panel, `$HOME` control dir so worktrees and subagent runs reach the same
window, `setsid` so a background task's teardown cannot kill the panel,
relaunch-to-pop for VirtuaWin, fail-open everywhere.

## Files

| file | role |
|---|---|
| `tools/review_gate/review_gate.sh` | blocking CLI: raise one request, wait, print the verdict |
| `tools/review_gate/review_gate_widget.tcl` | the singleton Tk panel |
| `tools/review_gate/test_review_gate.sh` | self-test, both arms |

## Usage

```sh
tools/review_gate/review_gate.sh \
  --label "Item 5 — e deletes all empty strips" \
  --body-file /path/to/summary.md \
  [--timeout 1800] [--out /path/to/verdict.txt] [--dir <control-dir>]
```

prints

```
DECISION: PROCEED | STOP | TIMEOUT | NOGATE
NOTES:
<whatever the user typed in the panel, possibly empty>
```

Exit status: **0** = go on to the next item (`PROCEED` / `TIMEOUT` / `NOGATE`),
**3** = the user pressed Stop, do not start the next item.

**Run it in the background.** A 30-minute foreground wait exceeds the agent's
600 s per-command ceiling; run with `run_in_background`, read `--out` when the
command exits (the harness re-invokes on exit, so the wait costs nothing).

Disable entirely: `REVIEW_GATE=0`. Change the default timeout:
`REVIEW_GATE_TIMEOUT=<secs>`.

## The panel

- **Header** — the item label, and the live countdown
  (`Proceeds to the next item by itself in 27m 14s`).
- **Body** — free text from `--body-file`: what changed, suite counts, and
  **what to eyeball**. This is the part that makes the ack meaningful.
- **Notes box** — free text sent back with whichever button is pressed, so
  "legend still too small, bump 1.2×" reaches the builder without a round trip
  through the chat.
- **Reviewed — proceed** → `PROCEED`, exit 0.
- **Hold (I'm looking)** → freezes the countdown and does **not** release. The
  one state that blocks indefinitely; it means the user is demonstrably at the
  desk. Toggles to **Un-hold**, which restarts the countdown at full length.
- **Stop — wait for me** → `STOP`, exit 3. Halts the loop.
- **Closing the window** replies `PROCEED` to everything pending. Closing is
  "get out of my way", not "abort" — that is the Stop button.

## Control directory

```
$DIR/req/<id>       one line, the item label. Its presence = builder blocked.
$DIR/body/<id>      the --body-file contents.
$DIR/reply/<id>     written by the panel, read+deleted by the shell:
                      line 1 = PROCEED | STOP,  line 2+ = notes
$DIR/hold/<id>      present while held: freezes the countdown
$DIR/deadline/<id>  epoch seconds the request auto-proceeds at
$DIR/widget.pid     panel pid (liveness / singleton lock)
$DIR/last_raise     relaunch throttle
```

## Design notes, each paid for

- **The deadline is owned by the SHELL, not the panel.** `_attention`
  routinely kills and relaunches the panel to pop it onto the current virtual
  desktop; a panel-owned countdown would be lost or restarted every time.
- **Replies are atomic** (`spit_atomic`: write `.tmp`, `file rename -force`).
  The shell polls for `reply/<id>` and reads it the instant it appears, so a
  half-written file would be read as a truncated verdict. Sabotage leg S3
  guards it.
- **`do_reply` iterates `pending()`** rather than writing a fixed path.
  Sabotage leg S1 guards it: with nothing pending, a forced Proceed must write
  nothing.
- **`_attention` sends TERM, not the WM close path.** The close handler replies
  `PROCEED` to everything pending — running it while raising the panel would
  release the very request being raised.
- **`setsid`.** Left in the caller's process group, the routine teardown of a
  background task (`kill -TERM -<pgid>`) takes the panel with it. Measured on
  the GUI-test gate; same fix.
- **Fail open, four ways**: no `DISPLAY`, no `wish`, `REVIEW_GATE=0`, or a panel
  that dies mid-wait → `NOGATE`, exit 0, immediately. A review gate that can
  wedge the build loop is worse than no review gate.

## Loop policy

On `TIMEOUT` the builder proceeds to the next item **and carries the
un-eyeballed item forward**: the plan doc's checkbox line is marked
`AUTO-PROCEEDED, un-eyeballed` so the outstanding reviews can be done in a
batch later. `STOP` halts the loop and the builder reports and waits.

## Testing

`tools/review_gate/test_review_gate.sh` — 31 checks.

- **Shell arm T1–T7**: both fail-open paths, the timeout self-release and its
  elapsed time, `PROCEED` with notes round-tripped, `STOP` → exit 3, hold
  genuinely blocking past a 3 s deadline, and a clean control dir afterwards.
- **Widget arm B1–B13**: the buttons driven by `invoke` (not by a human click),
  the hold toggle's dual face, the notes round trip, the close-fails-open path,
  and the idle disable.
- **Sabotage S1–S3**: the two legs above plus "reply actually written", so the
  atomicity check cannot pass vacuously.

Traps met while writing the test, both worth knowing:
- `on_close` calls `exit`, which **`catch` cannot stop** — the close legs need
  `exit` *and* `destroy` renamed away, in their own process.
- A Tcl error inside an `after` handler pops a **bgerror dialog** and the probe
  hangs until the timeout instead of failing. Every probe overrides `bgerror`
  to print and exit. (First version of the test did hang exactly this way: a
  `ck` helper taking an unevaluated expression string.)
