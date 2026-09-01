# 0645 — `AUDIT_WM`'s default (`openbox`) is not installed on this box, so the documented Xvfb arm silently runs WM-LESS

STATUS: **OPEN — measured 2026-08-23 by the 0616 crew.** A test-environment
defect, and it makes a whole class of measurements silently worthless.

## The problem

`CLAUDE.md` and `tests/headless/xvfb_arm.sh` both promise a reparenting window
manager inside the virtual session:

> **A window manager runs inside the virtual session** (`AUDIT_WM`, default
> `openbox` …). Measured: empty Xvfb does not reparent and silently no-ops
> `wm iconify`; with openbox both work.

On this machine `command -v openbox` is **empty** — openbox is not installed.
`xvfb_arm.sh:154-158` handles that by printing a warning to stderr and falling
back:

```sh
local wm="${AUDIT_WM:-openbox}"
if [ "$wm" != none ] && ! command -v "$wm" >/dev/null 2>&1; then
  echo "display arm: WM '$wm' not found -> running WM-less (…)" >&2
  wm=none
fi
```

A warning on stderr, in a suite run whose stdout is what anybody reads, is not
enough. The persistent dev display agrees: `tests/headless/devdisplay.sh status`
on `:99` reports `wm: none (-)`.

**Consequence:** a run armed the documented way has **no reparenting, no working
`wm iconify`, and no `wm withdraw` semantics to speak of** — so, per the 0616
brief's own rule, it is *not evidence* for any window-mapping issue. A suite
written against it can pass while the defect is live.

## The second half: `AUDIT_WM` cannot express the WM that IS installed

The only WM on this box is `xfwm4`, and **plain `xfwm4` dies at startup on a GLX
`BadValue`**. The working invocation is `xfwm4 --compositor=off` (verified:
reparents = 1, `wm iconify` → `iconic` / `ismapped` 0, `wm withdraw` →
`withdrawn`). But `AUDIT_WM` is consumed as a bare command name — it is passed to
`command -v` and then launched — so there is **nowhere to put the flag**. Every
0616 measurement therefore had to bypass the arm entirely and hand-roll
`Xvfb + xfwm4 --compositor=off` on a private display.

## Fix shape (either or both)

1. Make the fallback **loud**: if `AUDIT_WM` was not satisfied and the caller did
   not ask for `none`, print the degradation on **stdout** in the suite banner,
   and export a variable (`AUDIT_WM_EFFECTIVE=none`) that a suite can assert on,
   so a window-mapping row can self-SKIP with a true reason instead of passing
   vacuously.
2. Let `AUDIT_WM` carry arguments — split it on whitespace and `command -v` only
   the first word — so `AUDIT_WM="xfwm4 --compositor=off"` works. Then add a
   short candidate list (`openbox`, `xfwm4 --compositor=off`, `fluxbox`,
   `metacity`) tried in order, instead of one hardcoded default.

## Acceptance

- On a box without openbox, the arm either starts a working reparenting WM or
  says so where the reader will see it.
- `AUDIT_WM="xfwm4 --compositor=off"` launches that WM.
- A suite can read the *effective* WM and decide, rather than assuming the
  documented default.

## Related

- Issue **0646** — a suite row that self-SKIPs on a blind retry hides a real
  regression; the two together are how a window-mapping defect can survive a
  green suite.
- `CLAUDE.md`'s dev-display section should gain the "openbox may not be
  installed" caveat when this is fixed.
