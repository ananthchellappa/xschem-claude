# 0515 — the Location bar's refused context switch says nothing at all

**Status:** OPEN — measured, ruled deliberately unfixed by results batch item 5.
**Branch:** `fluid-editing`
**Filed:** 2026-08-19, results batch item 5 (`rawbar-load-reexpress`)
**Severity:** low — the gesture is lost, not the data.

## What happens

`wviewer::rawbar_load` (`src/wave_viewer.tcl`) has **five** refusal arms. Three
write one sentence into the viewer sidebar; **two return 0 in silence**, and one
of those two is reachable by an ordinary user gesture:

| arm | condition | sentence |
|---|---|---|
| 1 | the token names no viewer window | **none** |
| 2 | nothing typed | `Location: type the path of a raw file` |
| 3 | `![file isfile $path]` | `Location: no such file '<tail>'` |
| 4 | **`![wviewer::switch_ctx $token]`** | **none** |
| 5 | the engine refused the file | `Location: could not read '<tail>'` |

> ⚠ **THAT IS A TABLE OF ARMS, NOT OF INPUTS, and one input class changed arm
> in the same item that filed this issue.** A `~/`-spelled path naming a
> readable raw used to reach **arm 5** (`extra_rawfile()` never expanded `~`)
> and now succeeds, because the re-expressed body goes through
> `results::select`, which `file normalize`s before the verb and whose verb
> expands `^~/` itself. Ruled as R501c divergence 5 in
> `doc/claude/specs/results_selection.md` §7.1, pinned by SEL337/SEL338. **Arm
> 4 — the subject of this issue — is untouched by it**, and so is the fix below.

Arm 1's silence is **forced**: no window means no sidebar to write into, and
`wviewer::browser_status` looks the token up in the same dict that just failed.
There is no defect there.

**Arm 4's silence is not forced.** The window exists, the sidebar exists, and
`browser_status` would deliver — the sentence simply was never written. The user
types a path into the Location bar, presses Return, and *nothing happens*: no
waveforms, no message, no clue.

## When arm 4 fires

`wviewer::switch_ctx` (`src/wave_viewer.tcl:1339`) verifies its own
`xschem new_schematic switch`, because `switch_window` (`src/xinit.c`) refuses
outright while the current context's semaphore is raised. Reachable states with
the semaphore up include `ase::wait`'s `vwait` bracket (`src/ase.tcl:646`), which
pumps the whole event loop during a simulation — so the Location bar is live and
clickable while a run is in flight, and a load attempted then is silently
dropped. `destroy_all_windows`'s `tk_messageBox` bracket (`src/xinit.c:2482`) and
a placement in flight are the other two.

## Why it is not fixed here

Results batch item 5 re-expressed `rawbar_load` on `results::select`, and its
governing invariant is **T-C** (`doc/claude/specs/results_selection.md` §12):

> `wviewer::rawbar_load`'s observable behaviour is byte-identical before and
> after the re-expression: same rc, same registry delta, same MRU delta, same
> status string, **and the same two arms staying silent.**

T-C names the silence explicitly, so writing a sentence into arm 4 would have
been the one thing that item was told not to do. The ruling is recorded as
**R501b** in §7 of that spec, together with the reason the silence does *not*
violate T-J/F6: `rawbar_load` returns **0 and only 0** on every refusal and 1 on
every success (pinned by `SEL319`), so a refusal can never be mistaken for an
answer — which is the defect F6 is about. What is left is an **R801 gap**
("every refusal returns a value and writes one sentence"), and that is this
issue.

## The fix, when someone takes it

One line, in the arm itself:

```tcl
if {![wviewer::switch_ctx $token]} {
  wviewer::browser_status $token {Location: busy — try again when the current operation finishes}
  return 0
}
```

and `SEL303`/`SEL304`/`SEL317`/`SEL318` of `tests/headless/test_results_select.tcl`
**must be restated at the same time**: they pin today's silence deliberately,
group AM drives the arm through a shimmed `switch_ctx`, and the sabotage that
adds exactly this sentence is `SB4` in item 5's receipt — it reds all four. The
frozen `wviewer::rawbar_load_PRE` body in that group is the *old* implementation
and must not be touched; what changes is the expectation, not the baseline.

The same question is open for every other `switch_ctx` refusal in the file
(`grep -n 'switch_ctx' src/wave_viewer.tcl` — six sites): most are redraw or
status paths where silence is right, and this one is the gesture.
