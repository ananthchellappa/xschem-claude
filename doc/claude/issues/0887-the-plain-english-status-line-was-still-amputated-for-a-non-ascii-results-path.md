# 0887 — the status line's new budget counted characters; the status line is 255 BYTES

Status: 🟢 **FIXED** — 2026-08-28, in the A11 repair pass. Found by the A11
sabotage run, which neutralized the guard by *correcting* it and watched nothing
turn red.

Class: **a fix that reinstated the defect it repaired**, and **a guard no row
could see**. Sibling of **0639** (the budget's existence) and of **0350/0354**
(a predicate that measures the wrong thing and passes).

## What the user got

A designer whose project directory is spelled with anything outside plain
ASCII — `Diseño/`, `プロジェクト/`, a name with an accent in it — pressed `6` on a
cell that had not been simulated yet and read a status line that stopped in the
middle of their own path, with nothing to say it had been cut.

That is the exact defect issue 0639 and the plain-English pass (**0886**) were
written to remove. It survived them.

## The mechanism

`cadence::_annot_fit` in `utils/annot_mode.tcl` is the one place that knows the
status line has a limit. It measured the sentence with `string length`, which
counts Tcl **characters**. The C side stores the line in
`xctx->statusmsg_text[256]` (`src/xschem.h:1682`) and fills it with
`my_strncpy` (`src/scheduler.c:59`), which counts **bytes**.

The proc's own comment defended the mismatch, and the defence was half right:

> every sentence this file mints is plain printable ASCII, which is what lets a
> CHARACTER budget here stand in for it

True of the **wording**. False of the **sentence** — three of the eight states
(`loaded`, `failed`, `noraw`) paste the user's own results-file path into it, and
a path is whatever the designer named their directory.

## Measured, on the shipped binary

2026-08-28, `noraw` state, mask 1, path `/home/analog/<31 accented chars><60
ASCII>/run.raw`:

| | |
|---|---|
| sentence | **225 characters**, **256 bytes** |
| old `_annot_fit` | returned it untouched — `225 <= 255` |
| `xschem get statusmsg` read back | 255 bytes, cut mid-token, **no `...`** |

The sabotage run's own reading of the same defect: 251 characters / 281 bytes in,
255 bytes back, tail `…/run.raw ye`.

## Why no row saw it

`test_op_annot`'s A11-1, A11-2 and A11-10 all measured the fitted line with
`string length` too, so every one of A11-10's 386 combinations agreed with the
budget **about the wrong unit**. A11-10's own long-path fixture is
`/tmp/[string repeat z 280]/results.data` — pure ASCII, where the two units
cannot disagree. A11-7's ASCII leg checks the sentences the file *mints*, which
were and are ASCII; it never sees a path.

## The fix

`cadence::_annot_bytes` is now the one ruler, and both halves of `_annot_fit`
use it: `string bytelength` where Tcl has it (it reports the modified-UTF-8 form
`Tcl_GetString` actually hands the C side, surrogate pairs included), falling
back to `string length [encoding convertto utf-8 …]` on a Tcl that removed the
command. The cut still lands on a space and is still marked `...`; the CIW copy
is still never trimmed. `string range` cannot split a character, so the window
boundary is always a legal place to stop.

## The rows

* **A11-9** (new) — the fixture above, end to end: the sentence fits in
  characters and does not in bytes, the fitted form is inside the byte budget,
  it is marked, it is a real prefix of the original, and it survives the round
  trip through `xschem statusmsg -hold` → `xschem get statusmsg` byte-identical.
  A 255-character ASCII line is still returned untouched.
* **A11-10** (widened) — a third, non-ASCII path joins the sweep, and the
  overflow is measured in bytes. 578 combinations.
* The suite measures bytes with its **own** helper (`opa_a11_bytes`), never the
  mint's, so a broken ruler cannot agree with itself.

Reverting `_annot_bytes` to `string length` reds A11-9 and A11-10 (66 of 578
combinations overflow, up to 290 bytes). Measured 2026-08-28.
