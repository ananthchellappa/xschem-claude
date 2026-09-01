# 0806 — the notice channel RAISES the CIW; the statusbar fallback is retired

STATUS: **RULED BY THE USER 2026-08-25. Not yet implemented.**
Supersedes the fallback-home half of [0650](0650-ase-echo-has-no-sink-in-the-ase-session-window.md) and [0655](0655-ase-session-window-still-has-no-notice-sink.md).
Related: 0653, 0654, 0674, 0675, 0677, 0699, 0800.

---

## 1. The ruling

Asked whether the notice fallback should be the drawing window's `.statusbar.12`
or a new notice segment in the ASE-L session window, the user rejected the
question:

> What does "CIW window is not there to receive it" mean? CIW is the one window
> that is always there. If a message was sent there for user's benefit (as opposed
> to regular logging of activity), then the CIW should be raised (though not
> necessarily steal focus)

Separately ruled, and this one is unambiguous:

> **`::notify_style` ships `ciw`** — quiet by default, pop-up opt-in via the rc
> setting, with the notice naming that setting.

## 2. The premise really was false, and the tree already knew

`src/ciw.tcl:28-36` carries the correction, written by an earlier pass:

> 0650's sink table says ciw_echo "No-ops silently when shut". 0653 says "The CIW
> is a closable toplevel. Closed -> silent no-op." **Both are wrong.**
> `wm protocol .ciw WM_DELETE_WINDOW {wm withdraw .ciw}` means a close WITHDRAWS:
> `.ciw` and `.ciw.l.t` still EXIST, `winfo ismapped .ciw` is 0, and ciw_echo
> happily writes into the invisible widget (measured: the pane text GREW).

So the notice was never lost. It was **delivered into a window nobody could see** —
which is worse, because every liveness check downstream reported success.

`ciw_echo`'s guard is `winfo exists .ciw.l.t` (`src/ciw.tcl:120-121`) when the
question is `ismapped`. That is the same defect as 0675 (identity, not
reachability) in the oldest sink of the channel.

## 3. What the ruling settles

* **There is no fallback problem to solve.** A user-directed notice raises `.ciw`
  (without stealing focus) and writes there. The CIW is withdrawn, never
  destroyed, in every interactive session.
* **`.statusbar.12` (sink 3) is RETIRED as the can't-miss fallback.** It was the
  worst sink available: ~28 characters, shared with `*BUSY*`, and cleared
  unconditionally by `propagate_logic()` at `src/hilight.c:2305` — issue 0654.
  Building the channel's reliability on it was backwards.
* **No ASE-L notice segment is needed** (0650(a), 0655). The question presumed the
  CIW could be unavailable; it cannot.
* **The genuine absences are `--nogui` and pre-bootstrap**, neither of which has a
  human to notify. Log-only is correct there and needs no fallback UI.

## 4. The distinction the ruling turns on, and it must be implemented

> *"If a message was sent there **for user's benefit** (as opposed to regular
> logging of activity)"*

Only a **user-directed notice** raises the CIW. Ordinary activity logging must
not, or the CIW will pop to the front constantly and the raise will be the next
thing filed against this channel. The channel therefore needs an explicit notion
of *this message is addressed to a person*, which it does not have today.

## 5. Do not steal focus

`raise` without focus. `src/ciw.tcl:382` already calls `raise_activate_toplevel
.ciw` on one path — check whether that activates (and therefore steals focus)
before reusing it.
