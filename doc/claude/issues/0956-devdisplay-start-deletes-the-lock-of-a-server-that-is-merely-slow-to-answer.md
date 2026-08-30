# 0956 — `devdisplay.sh start` deletes the lock of a server that is merely slow to answer, and a wedged display reads as a suite failure

**STATUS: OPEN — one half confirmed from the code, one half observed once and
NOT explained. Recorded 2026-08-30 by 0948's write-up pass, from an episode its
verification pass hit and recovered from. Filed rather than fixed: it is
harness infrastructure, and the unexplained half wants a reproduction before
anyone changes the liveness logic.**

## The episode

Mid-session, the persistent dev display `:99` stopped serving. Xvfb (pid 9147)
was alive and its abstract socket `@/tmp/.X11-unix/X99` was still LISTENING, but
`xdpyinfo` and `xset q` both timed out while connections were still being
accepted, with zero X clients on the box.

While it was in that state:

* `test_ase_window` and `test_ase_dialogs` each exited **6** with one line,
  `!! devdisplay ERROR: :99 is not running`, and no banner. Both passed at
  their exact baselines (228 and 174) after the display was repaired.
* `devdisplay.sh start` announced `cleaned stale /tmp/.X99-lock` — deleting the
  lock of a **live** server — and spawned a second Xvfb that died instantly on
  the taken socket.
* Recovery took `kill -9` on the wedged Xvfb plus an orphan openbox (pid
  940175), then a fresh `start`.

## The half that is confirmed, and is worth fixing on its own

`cmd_start` guards the lock deletion with a liveness probe that is a **five
second timeout**:

```sh
tests/headless/devdisplay.sh
  _server_answers() { _x_socket_listening || return 1
                      command -v xdpyinfo >/dev/null 2>&1 || return 0
                      timeout 5 xdpyinfo -display "$DPY" >/dev/null 2>&1 ; }
  cmd_start() { ... if _server_answers; then _die "...served by an X server that is not ours" ; fi
                    if [ -e "/tmp/.X$NUM-lock" ]; then rm -f ... _say "cleaned stale ..." ; fi }
```

So a server that is alive but momentarily slow — a loaded box, or this machine's
well-recorded Windows-host suspend (`runtime_gaps.sh`, and the auto-memory note
"Host suspend fakes long runs") — has its lock removed and a competing Xvfb
started against it. "Did not answer in five seconds" is being read as "is not
there", which is the same category error as issues 0949 and 0953 in the
simulator probe, in a different file.

There is also a second, quieter way to reach it: with `xdpyinfo` absent,
`_server_answers` returns **true** on a listening socket alone, so on a box
without it a wedged display reads as healthy.

## The half that is NOT explained, and must not be guessed at

The verification pass reports that `devdisplay.sh status` said `state: alive`
during the outage. Reading the code, it should not have: `_ours` calls
`_server_answers`, a timed-out `xdpyinfo` makes it false, and `cmd_status` then
falls to `stale` (the pid file is still there), not `alive`. Both observations
in one episode are consistent only if the wedge was intermittent — which a host
suspend would produce. **Nobody has reproduced it.** Do not "fix" `cmd_status`
on the strength of this paragraph; reproduce first.

## Why it is worth someone's time anyway

An exit 6 with a single `devdisplay ERROR` line and no banner is easy to read as
a suite failure, and a crew that hits it spends its budget chasing a product bug
that is not there — the same cost issue 0801 records for a different flake. The
first thing this issue buys is that the next reader recognises it.

## Fix shape

* Give `_server_answers` a retry (or a longer budget) before `start` is allowed
  to delete a lock, and say which of the two it concluded.
* Make `status` distinguish *listening but not answering* from *not there*, in
  its own word, so an operator can tell a wedge from a dead display.
* Have the suite wrappers print something a reader can act on when they cannot
  reach the display — "the dev display is not answering; `devdisplay.sh status`"
  beats "is not running", which is a claim, and in this episode a false one.

## Acceptance

* A live server that is slow to answer keeps its lock, and `start` says so.
* A wedged display and an absent one report differently.
* A reproduction of the wedge, from which the `status` contradiction above can
  finally be settled.
