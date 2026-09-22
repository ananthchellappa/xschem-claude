# Decisions — headless crashes batch

# D1 — Item A first, because it is what makes the rest measurable (driver)

`xserver_ok()` closes the display and leaves the global pointing at freed memory. While
that is true, a missed guard reads whatever survives in the freed block — measured on 1483
as `XMaxRequestSize=4` against a true 65535 — so the defect class is silent wherever a
`DISPLAY` happens to be set, which is every arm anyone routinely runs. Nulling the pointer
converts every remaining missed guard from a plausible wrong answer into a fault.

That is deliberately a fault-finding change: it will surface sites nobody has found. Those
are the point, not collateral.

# D2 — Two crews were launched outside this batch while its Map stage ran (driver)

This batch's first stage is a survey in a throwaway clone, so the main tree sits idle
while it runs. Rather than leave it idle the driver opened two more streams. Recording
them here, in the batch that was live at the time, so the record shows where the
attention went:

* **Issue 1352** — `input_line`'s OK button hands what the user typed to `eval` as a
  script rather than as a value. Surfaced as the one urgent item by the owed-queue triage
  (`doc/claude/code_analysis/owed_queue_triage_2026-09-22.md`, D-1) and re-verified live
  that day through the shipped precision menu. It is inherited stock xschem on the branch
  the user publishes, and the fix is one line, so it does not wait for a batch of its own.
* **Issue 1600** — `test_ase_core`'s 5324-line unnamed file-scope `catch`. The suite is a
  T1 case, so this is a hole in the instrument every other claim in every batch is
  measured with.

# D3 — Crews that run T1 get their own clone; crews that edit product code do not (driver)

Three crews, one tree, is a measurement hazard rather than a memory one: the harness
tolerates concurrent T1 runs (CLAUDE.md, "Concurrent T1 runs"), but a T1 run in the main
tree measures whatever every other crew has half-written into it at that moment. So the
1600 crew clones to `/var/tmp/x1600/tree` and hands back file paths for the driver to
copy, while the 1352 crew — whose change is one line in `src/xschem.tcl` plus a new suite
— edits the main tree directly and is the only crew allowed to.

The cost is that the 1600 crew's T1 is taken against a tree without the 1352 fix, so the
driver re-gates once after applying both. That is one extra gate run, and it is the price
of each crew's number meaning something on its own.

# D4 — the Map corrects D1's premise, and the correction is worth more than item A (driver)

D1 said nulling `display` "converts every remaining missed guard from a plausible wrong
answer into a fault", and treated that as the change that makes the rest measurable. The
Map receipt (`receipts/A-map.md`) shows the premise is **half right**, and the half it gets
wrong is the more interesting half.

**Three of the five user-reachable crashes do not fault on a NULL `Display*` at all.**
`handle_expose`, `erase_crosshair` and `grabscreen` fault on a **NULL GC**:
`MyXCopyArea(display=…, src=0, dest=0, gc=0x0, …)`. With `has_x == 0`, `create_gc()` is
never called, so `xctx->gc[]`, `xctx->window` and `xctx->save_pixmap` are all 0/NULL. The
crew proved this the only way that settles it — on the **tracer build**, where `has_x` is 0
while `display` is a live, usable connection. They crash there too.

So **nulling `display` does not make these safe and never could.** A `has_x` guard fixes
them; a `!display` guard would not. `copy_hilights` is a third member of the same family
with a NULL `Xschem_ctx` — and it crashes identically **with a full GUI and `has_x == 1`**,
which means one of 1492's four verbs was never a display defect.

Item A still lands, for the reason the receipt gives rather than the one D1 gave: it
removes the libxcb undefined-behaviour arm (`Extra reply data still left in queue`, an
assertion failure inside `_XReply`), which is the one failure shape that cannot be reasoned
about. That is a smaller claim than D1 made and it is the true one.

# D5 — the tracer build is the method to keep, not the null build (driver)

The crew's second scratch build is the piece of technique this batch should be remembered
for. `xserver_ok()` **keeps** the probe connection open instead of closing it, and installs
an `XSetErrorHandler` that swallows protocol errors — so `has_x` is 0 while `display` is
live. A missed guard then does **not** fault, and the run continues past it.

That converts a stop-at-the-first-crash walk into an exhaustive sweep, which is what makes
"17 of 271 sites execute with `has_x == 0`" a measurement rather than a guess. Paired with
enumerating the sites through the compiler — `extern Display *display
__attribute__((deprecated("XHCUSE")));`, one warning per use site, immune to callee naming,
macros and argument position — it settles a question three grep passes had answered three
different ways (152/69/13, 172/70/7, 182/70/13).

⚠ And the receipt names the one blind spot honestly: **the preprocessor, not callee
naming.** Five `display` dereferences are real and unguarded but excluded from this build —
`psprint.c:333` (needs libjpeg), `draw.c:165` (no-cairo builds), and the `#ifndef __unix__`
Windows paths in `draw.c` and `xinit.c`. They exist in other builds and no run here can see
them.
