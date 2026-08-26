# 0845 — the reopen shortcuts open the design READ-ONLY

Status: **CLOSED — RULED BY THE USER 2026-08-26: keep read-only-by-default, AND make it loud.**
Was a ruling, never a defect. Raised from the user's own action log while
investigating something else; the user did not report it. Related: 0839 (the
other half of Ctrl+Shift+O), 0843.

## The ruling

> "Yes, 'those three' should default to read-only"

Shipped behaviour is ratified. No code change. What this issue leaves behind is
the lock (below) and a corrected account of the mechanism.

## Measured

`/tmp/Xschem.log.6`, the user's session, first toplevel line of every trace block:

```
.  normal 1000x800+3713+296  'xschem [3] - tb_bandgap.sch (read-only)'
```

## The three doors — and the correction

The first write-up of this issue said the read-only default came from
`scheduler.c:7564` and named the Recent menu alongside the two keyboard
shortcuts, as if all three went through that line. **They do not.** There are
two mechanisms:

| door | how it asks | where |
|---|---|---|
| Ctrl+Shift+O (Open Most Recent) | `load -gui -lastopened` | implied by `scheduler.c:7564` |
| Ctrl+Shift+T (Open Last Closed) | `load -gui -lastclosed` | implied by `scheduler.c:7564` |
| File > Open Recent > *name* | `load -gui -readonly` **explicitly** | `xschem.tcl:2635` |

`actions.csv` also spells `-readonly` explicitly on the two keyboard rows, so
they carry it twice — belt and braces, because the keyboard handlers in
`callback.c` bypass the csv command entirely and reach the C load directly.

**All four openers log the same bare `xschem load {f}` line** (`scheduler.c:7723`
fires whenever `!force`, i.e. `-gui`), so *an action log cannot tell you which
door was used*. That ambiguity is what made the first attribution here a guess.

## Two candidates that were investigated and CLEARED

* **Library Manager double-click** — `libmgr::open_view` (`library_manager.tcl:481`)
  runs `xschem load -gui $f` and sets nothing read-only. Not a source.
* **Library Manager > Open (read-only)** — `libmgr::open_view_ro` really does set
  it, but logs `xschem set readonly 1` (`library_manager.tcl:636`), and log.6
  contains no such line. Not what happened.
* **File-protection fallback** — `save.c:4497` raises read-only for a
  non-writable file. `tb_bandgap.sch` is `0644` owned by the user. Not it.

Confirmed independently by the user: a plain `File > Open` shows no read-only
marker, which matches `R1`/`R7` below.

## The lock

`tests/headless/test_reopen_readonly.tcl`, 11 checks, ALL PASS:

* R1 plain load of a writable file opens EDITABLE
* R2/R3 `-readonly` forces read mode and does not stick
* R8/R9 `-lastopened` implies read mode with no explicit flag (the keyboard path)
* R10 `-lastopened` skips a recent entry that is already loaded
* R10b — the positive twin: the skip is conditional, the head comes back when the
  head is not loaded
* R4/R5/R6 the three doors carry their flag; R7 `File > Open` does not

### A standing red fixed on the way in (test defect, not behaviour)

R10 was **red on this machine** and had presumably been red since it was written.
Cause: `--nogui`/`--pipe` **hard-gates the recents list** (`no_recent_files`,
issue 0119, `xinit.c:3496`), so the test's own `xschem load` calls recorded
nothing and the resolver fell through to the USER's persisted
`$USER_CONF_DIR/recent_files`. R10 was asserting the contents of that file. It
now drives `tctx::recentfile` directly — the variable `get_lastopened` reads —
which exercises the resolver and writes no user file (`write_recent_file` stays
gated; verified by md5 before/after).

Sabotage, two directions, opposite reds:

| variant | R10 | R10b |
|---|---|---|
| drop the skip (return the head unconditionally) | **FAIL** | ok |
| over-tighten (always skip index 0) | ok | **FAIL** |

## The loudness, also ruled (same day)

Put to the user separately; answer: **"Yes, add loudness."**

The reopen doors now announce themselves through the house notify channel — CIW
pane, the durable action log, and the short form in the statusbar:

> `Opened Read-Only. Use Edit > Make Editable (Ctrl-2) if needed`

short form: `opened read-only`.

### The sentence was cut once, by the user, after reading it

The first version explained the whole rule — *"… — the default for the reopen
shortcuts (Open Most Recent, Open Last Closed, File > Open Recent). Edits are
refused until you make it editable."* — plus the channel's own `Fix: …` and
`CIW command: …` tails. The user's verdict on reading it: **"full line is too
much"**, and they wrote the replacement themselves. It is used verbatim.

Two things that make the short form stay short, both guarded:

* **`-menu`/`-command` are not passed.** They are TEXT options — `xschem::notify`
  appends `" Fix: <menu>."` and `" CIW command: <cmd>"` to the rendered line — and
  they were most of the length objected to. The remedy lives inside the sentence
  instead. Restoring them is the silent way this grows back, so R14a asserts
  their absence and R14b caps the sentence at 70 characters (it is 61).
* **The filename went with them.** The notice fires at the instant you open the
  thing, so the name it would repeat is the name you just picked.

`reopen_readonly_notice` (`xschem.tcl`, beside `readonly_notice`), called from
the single convergence point in `scheduler.c`. Three decisions worth keeping:

* **Not latched.** No `-once`. The fact worth saying is *which window you are in
  now*, not that the rule exists. You will see it every session; that is the
  point, and it is the thing that most needed the sentence to be short.
* **`!force` only** — an interactive `-gui` open. A scripted load or an
  action-log replay stays silent. R15 is the twin.
* **Outside the `!xctx->readonly` branch.** A non-writable file reopened through
  one of these doors is *already* read-only from `save.c:4497`, so a notice
  nested in the state change would go silent for exactly the file the user is
  least able to edit. R19 is the twin, and SB-3 (nesting it) reds R19 alone.

**One claim about `Ctrl-2`, not two.** An earlier revision named the key only
under `cadence_compat`, on the theory that `cadence::make_editable` is
cadence-only. But the Edit menu already advertises `Ctrl+2` unconditionally
(`xschem.tcl` `toggle_readonly_menu`), so a conditional here would have made the
notice and the menu disagree about the same key. R17 pins that they agree. (No
in-tree file binds `Ctrl-2`; the binding comes from the user's own rc. If that
turns out to be unbound in legacy mode, the menu is the thing making the claim
and it predates this work.)

Sabotage, six variants, each reddening its own rows and nothing else:

| variant | reds |
|---|---|
| drop the `!force` gate | R15 |
| remove the announcement | R11 R12 R13 R14 R19 R20 |
| nest it inside the state change | R19 |
| re-add `-menu`/`-command` | R14a |
| go back to the long sentence | R12 R14b |
| strip the remedy from the sentence | R12 R13 |

23 checks, ALL PASS. Every sink was **stubbed** — `::xschem::notify` is replaced
by a recorder — so nothing here proves the sentence renders. That is a `look`
debt and a `suite` debt, both recorded.
