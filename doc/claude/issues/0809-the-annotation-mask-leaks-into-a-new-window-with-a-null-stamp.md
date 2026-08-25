# 0809 — the annotation mask leaks into a NEW window/tab with a NULL stamp, so 0688's clear is permanently inert there

STATUS: **OPEN — measured 2026-08-25, filed not fixed.** This is the defect that
made the 0688+0683 item **status E and not x**: it is the adversary's refutation of
that item's broad claim, re-measured independently by the write-up agent on the
committed tree.
FOUND IN: `src/actions.c:1325` (`annot_show_sync_cache()`'s pull), `src/actions.c`
`annot_show_set()` / `annot_show_check_root()` (0688's fix), `tctx::global_list`
(`src/xschem.tcl:14009`), `restore_ctx` (`src/xschem.tcl:14076`).
RELATED: [0688](0688-the-annotation-mask-outlives-the-schematic-so-window-keyed-binding-cannot-hold.md)
(the fix this defeats), [0683](0683-annotation-is-reachable-with-no-bound-ase-l-session.md)
(the ruling whose intent this leaves unmet), 0682 §4, invariant **I1**.

---

## 1. What 0688's fix claims, and the half of it that is not true

0688 landed on 2026-08-25 as: the mask belongs to the window's **root sheet**.
`annot_show_set()` (`src/actions.c`) is THE one C writer — it writes
`xctx->annot_show`, the Tcl mirror `::annot_show` **and** the
`xctx->annot_root` stamp — and `annot_show_check_root()` drops the mask when the
stamp no longer names `xctx->sch[0]`.

The header comment on `annot_show_set()` states the invariant it is built on:

> so "the mask is on" and "this is the sheet it was armed for" are ONE fact
> written in ONE place.

**That sentence is false, and a stock gesture makes it false.** There is a
SECOND writer of the mask, and it is pre-existing and unchanged by the fix —
`src/actions.c:1325`, inside `annot_show_sync_cache()`:

```c
xctx->annot_show = tclgetintvar("annot_show");
```

`::annot_show` is ONE process-global Tcl variable shared by every window
(`tctx::global_list`), while `annot_root` is per-`Xschem_ctx`. So a context can
acquire a non-zero mask **without ever passing through the setter**, and it then
carries `annot_root == NULL`. `annot_show_check_root()` returns early on a NULL
stamp — deliberately, because a NULL stamp is also how an `xschemrc`
`set annot_show` looks and decision **D2** forbids clearing that — so in such a
window the 0688 clear is **permanently inert**.

## 2. The measurement

Two sanctioned doors produce a ctx with no `tctx` snapshot, so the global keeps
the previous window's value: `File > Create new window/tab` (Ctrl+T,
`actions.csv:46` → `xschem new_schematic create`) and `File > Open in new window`
(Alt+O, `actions.csv:42` → `xschem load_new_window`).

Write-up agent, 2026-08-25, on the committed tree, honest binary, under xvfb:

```
WU| W1 A            annot_show=3 annot_root=dut.sch
WU| W2 (new tab)    annot_show=3 annot_root=      sch0=untitled.sch
WU| W2 after OPEN B annot_show=3 annot_root=      sch0=decoy.sch
WU| W2 after OPEN A annot_show=3 annot_root=      sch0=dut.sch
```

The new tab is annotated, on a sheet nothing armed it for, with an empty stamp —
and a `File > Open` inside it, which is the exact gesture 0688 exists to catch,
does not move it.

The adversary pass measured the same on two independently canary-verified builds
(`5845675f`, `1e41e26a`), for **both** doors.

## 3. What it costs: the 0683 orphan survives, end to end, sanctioned doors only

The adversary's transcript, with numbers on the sheet:

```
load QA.sch ; ase::launch_for_current            -> 1 session
Waves > Op Annotate                              -> mask 3, stamp QA.sch
xschem annotate_op op.raw                        -> v(a)=3.14, carrier bbox 0 -> 59 (painting)
File > Open in new window  QB.sch                -> mask 3, stamp ''
ase::session_close                               -> 0 sessions, mask 3
reopen QA.sch                                    -> mask=3, stamp='', sessions=0,
                                                    v(a)=3.14, paint width 59
invoke BOTH stock entries                        -> both REFUSE ("not annotated: no ASE-L")
                                                    so neither can clear it
```

That is issue **0457**'s original complaint verbatim, and it is 0688 §2's
transcript with one word changed at step 2: `File > Open in new window` instead
of `File > Open`. The brief's stated sequence — the one that uses plain
`File > Open` — **does** end clean after the fix (rows L22/L24, green). This one
does not.

⚠ The refusal guard makes recovery *narrower*, not wider: with both stock
producers refusing, a stamped mask is the only clearable one, so in a leaked
window a non-ASE-L user has no stock gesture that can even re-stamp it. The
recovery is `Tools > Launch ASE-L` → `Results > Annotate` → untick, which is
exactly what the refusal message tells the user to do — so it is recoverable,
but only by the road the message names.

## 4. Why the fix is INCOMPLETE and not WRONG

No regression was introduced. Before 0688 landed, `File > Open` cleared the mask
in **no** window at all; it now clears it in the window that armed it through the
C setter. The leak is the pre-existing `actions.c:1325` pull, unchanged by the
diff (`git diff HEAD -- src/actions.c` shows that line untouched). The item
delivers the single-window clear plus a fully-verified refusal; it does not
deliver "the mask belongs to the loaded root sheet" for a window that acquired
the mask through the pull.

## 5. The seam, and the thing that makes it hard

The obvious repair — "adopt `sch[0]` as the stamp when a ctx pulls a non-zero
mask it never set" — collides head-on with decision **D2**, which exists because
it was measured: at startup `xschem get schname 0` is `<launchdir>/untitled.sch`
and the rc sync (`xinit.c:3839`) runs BEFORE the CLI file is loaded, so an
adopting sync stamps `untitled.sch` and the first real load then silently clears
an `xschemrc`-set mask — killing producer (c), which the 0683 ruling does not
touch.

So the two cases have to be **distinguished**, not merged. Candidates, none
implemented or measured:

1. **Adopt only from a live sibling ctx.** When a new ctx is created while
   another live ctx has a non-zero *stamped* mask, copy the mask AND stamp
   `sch[0]` at the new ctx's first load. An rc-set mask has no sibling to
   inherit from, so D2 survives.
2. **Zero `::annot_show` for a ctx with no `tctx` snapshot.** A brand-new
   window starts unannotated; the user re-arms it. Smallest, most surprising
   (a new tab of an annotated design comes up dark).
3. **Make the mask genuinely per-context in Tcl too** — remove `annot_show`
   from `tctx::global_list` so a new ctx does not inherit the global at all.
   Largest blast radius; `tctx::global_list` membership is what a lot of other
   state depends on.

A ruling is probably owed on (2) either way: "should a new tab inherit annotate
mode?" is a user-visible question in its own right, and note that issue
**0621**'s row already records the related trap — *"a new tab inherits from the
Tcl mirror, so the C initialiser only ever applies to the first context"*.

## 6. Still open

All of it. Nothing here was fixed. The 0688+0683 item's honest claim is **"the
plain-`File > Open` sequence ends clean and both stock producers refuse"**, not
"the orphan is unreachable" — and whoever writes 0688 up must not let the narrow
sentence stand in for the broad one.
