# 0829 — `get_directory [list …]` and `netlist {%s} … {%s}` in the five netlisters execute a crafted filename

**Status:** FIXED (this item, with 0827 + 0817 §Z.2) — RULING SETTLED 2026-08-29: ratified as shipped, no code change. The RULING at the FOOT of this file is the authoritative one; it supersedes the earlier "RATIFIED AS SHIPPED" section and corrects two factual errors in the text above — the L3 table row for `xinit.c:4062` and the "braced list representation" claim in the Fix section.
**Filed by:** the 0827+0817+0828 crew, from a vector DRIVEN during planning; not present in
0817's inventory in any form.

## What it is

The five netlisters spelled the working-directory update

    tclvareval("get_directory [list ", xctx->sch[xctx->currsch], "]", NULL);

`[list …]` READS as the safe form and is not: the bracket is a **command substitution in the
OUTER script**, so whatever is inside it runs while that script's words are being parsed —
before `list` is ever reached. The `.sch` brace-escape defence discussed in 0825/0827 is
irrelevant to this spelling; a `[` in the *filename* is enough.

The same functions also spelled the per-cell netlist hand-off

    my_snprintf(tcl_cmd_netlist, S(tcl_cmd_netlist), "netlist {%s} noshow {%s}",
                netl_filename, cellname);
    tcleval(tcl_cmd_netlist);

— 18 sites, both data words derived from the schematic's own filename, both inside brace
groups, so a `}` closes the group exactly as in 0827.

## Measured, on the pre-fix binary (HEAD 466fab47)

A schematic whose FILENAME is `a[exec touch HOST_NL01]b.sch`, holding one
`examples/cmos_inv.sym` instance:

    xschem load  <dir>/a[exec touch HOST_NL01]b.sch      -> host file NOT created
    xschem netlist                                        -> host file CREATED

One verb past the `load` vector of 0817 §Z.2, same door (a crafted filename), no dialog,
`--nogui`.

## Fix

Every site now goes through `tcl_call()` / `tcl_call_mid()` (src/util.c): the path is handed
to the interpreter as a global and referenced with `$::`, whose substitution result is one
word and is never re-parsed. `get_directory [list $p]` and `get_directory $::v` are
semantically identical for every legitimate path — except that `[list …]` actually passed the
*braced list representation* (`{/a b/c.sch}`) for a path containing a space, which the other
`get_directory` call sites never did; the conversion also removes that inconsistency.

## Acceptance

* `NL01-netlist-list-splice` — load the crafted name, `xschem netlist`, sentinel 0 and no host
  file. Measured RED before the fix (`0 1`), green after.
* `NL02-netlist-still-emits-the-subcircuit` — the anti-hollow twin: the same netlist still
  writes `.subckt cmos_inv` with its `M1`/`M2` lines and `current_dirname` is still right.
* `FN07-no-concat-splice-in-the-load-path` — the source scan that names any surviving
  `"<proc> [list "` spelling.
* `FN08-no-tcl-diagnostics-on-an-ordinary-run` — a plain load/descend/netlist/saveas under a
  directory whose name merely contains `}` must emit zero Tcl diagnostics.

All in `tests/headless/test_raw_read_dispatch.tcl`.

## ⚠ Claims (issue 0823)

A `.sch` is executable **by design** — a `tcleval(` in a text record fires on DRAW via
token.c:78 `tcl_hook2()`. This fix does **not** make an untrusted `.sch` safe to open and does
**not** close "the injection family". It removes paths that executed **without saying so**.

## ⚠ RULING OWED — a user-visible behaviour change rode in with the sweep (ladder L3)

Three of the converted sites spliced their string **UNBRACED**, and two spliced it inside
**double quotes**. Converting those changes what an ORDINARY path does, not only a crafted one:

| site | before | after |
|---|---|---|
| `xinit.c:4062` `xschem load_new_window <argv>` | a command-line filename containing a SPACE split into several words and opened nothing | it opens as ONE file |
| `xinit.c:3857` / `scheduler.c:8888` `file dirname <name>` | same word-split on a spaced `--netlist-filename` / `xschem netlist <file>` | one name |
| `save.c` `ask_save "… <path> …"` (×2) | a `$` or `[` in the path was SUBSTITUTED inside the prompt text | shown literally |
| the five netlisters' `get_directory [list <path>]` | a spaced path was passed as its braced list form `{/a b/c.sch}` | passed as the path itself |

**The question for the user, not answered here:** should `xschem 'my file.sch'` now open that
single file, and should a save/descend prompt render a `$` or `[` in a path literally instead
of expanding it?

Implemented as YES on ladder L2 grounds — a word-split filename is indistinguishable from a
bug, nobody could be relying on it, and preserving the split would mean re-emitting the
unbraced form and keeping an RCE open to protect a defect. The **ratification is the user's**.
Rejected alternative: leave the unbraced/quoted sites as they are (keeps the vector live).

## RULING — 2026-08-29 — RATIFIED AS SHIPPED (decided under the user's "decide the 23" instruction)

**Decided:** YES to both halves. Opening `xschem 'my file.sch'` opens that one file.
A `$` or a `[` in a path is printed exactly as typed in the "Save anyway?" and
"Create schematic file?" prompts, never expanded. The rejected alternative — put
the unbraced/quoted splices back so a spaced name word-splits again — stays rejected.

**Why it was not worth the user's time:**

* Cadence opens a file whose name has a space in it. Splitting it into pieces and
  opening nothing is the behaviour of a bug, and it is a stock-XSCHEM quirk, which
  under "Cadence or nothing" is an argument against keeping it, not for it.
* Nobody can be relying on the split. Several files on one command line still open
  as several files — the loop calls once per argument
  (`src/xinit.c:4113-4118`), so only a *single* name containing a space changed
  meaning, and that case used to open nothing at all.
* The old `get_directory [list <path>]` spelling was not merely different for a
  spaced path, it was WRONG: it handed the proc the braced list form
  `{/a b/c.sch}`, and `get_directory` (src/xschem.tcl:12490) strips the last `/…`
  component and returns `{/a b`, leading brace and all. The conversion fixes a
  defect; it does not trade one behaviour for another.
* Restoring either half means re-emitting the unbraced form, which is the live
  remote-code-execution route measured in this issue's own driver.

### Verified in the tree before ruling (2026-08-29)

* `src/util.c:1127-1156` — `tcl_call_core()` / `tcl_call()` / `tcl_call_mid()`
  set a global and reference it as `$::…`, so the substituted word is never re-parsed.
* `src/xinit.c:4117` — `tcl_call("xschem load_new_window", cli_opt_argv[i], …)`,
  one call per argv element.
* `src/xinit.c:3909`, `src/scheduler.c:9013`, `src/scheduler.c:9846` —
  `tcl_call("file dirname", …)`.
* `src/save.c:4573`, `src/save.c:6437` — `tcl_call("ask_save", msg, …)`; the prompt
  text carries the path and is passed as one word.
* All ten `get_directory` sites in the five netlisters plus `save.c` use `tcl_call`;
  all 18 `netlist … show|noshow …` hand-offs use `tcl_call_mid`
  (`grep -n get_directory src/*.c`, `grep -n tcl_call_mid src/*.c`).
* Acceptance checks present: `tests/headless/test_raw_read_dispatch.tcl` NL01 (:1264),
  NL02 (:1268), FN07 (:1206), FN08 (:1238), plus SC10/ORD2/SYMP06 which lock ordinary
  spaced paths.

**Code change required: none.** This ratifies what already ships.

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim, on 2026-08-29: *"decide the 23, leave 0861 and 0299 for me"*.
A read-only audit had gone through the 57 open ruling debts on this branch and marked
25 of them as questions whose answer is cheap and obvious — things to be **decided**
rather than put to the user. **This debt was one of those**, so it was settled here,
on the user's instruction, instead of being carried to their queue.

> **This section supersedes the earlier "RULING — 2026-08-29 — RATIFIED AS SHIPPED"
> section above.** The outcome is identical — ratify as shipped, no code change — but
> three of that section's supporting facts are wrong, and one of them is also wrong in
> the "Fix" section and in the L3 table near the top. The corrections are recorded
> below so the next reader does not re-derive the error.

### The ruling, as an instruction to the codebase

1. **Keep the one-file-per-argument open.** `src/xinit.c:4113-4118` hands each
   command-line file name to `tcl_call("xschem load_new_window", …)` as a single word,
   once per argument. Several names on one command line still open several files; a
   name that contains a space opens as one file instead of being chopped at the space.
   Do not restore the unbraced splice.
2. **Keep the path literal in the prompts.** The "Save anyway?" prompt
   (`src/save.c:4570-4574`) and the "Create schematic file … it will be overwritten"
   prompt (`src/save.c:6435-6438`) build the message with the path in it and pass the
   whole message through `tcl_call("ask_save", …)`. A `$` or a `[` in that path is
   shown exactly as the user typed it. Do not restore the double-quoted splice.
3. **The rejected alternative stays rejected.** Putting the unbraced / double-quoted
   splices back — so that a spaced name word-splits again and a `$` in a prompt is
   substituted again — is refused, because that spelling *is* the measured route by
   which a booby-trapped file name runs commands (this issue's own driver).

### What the user is told, in plain English

> Decided for you: two small fixes stay. (1) When you open several files at once —
> `xschem top.sch 'my amp.sch'` — a name with a space in it now opens as one file.
> Before, only the FIRST name on the line could contain a space; the second and later
> ones got chopped at the space and opened nothing. (2) When a save or overwrite
> prompt shows you a file path containing a `$` or a `[`, it now shows the path
> exactly as you typed it. Before, a `$` in the path made the prompt fail to appear
> and the save quietly did nothing at all. Both came in with the fix that closed a
> hole where a booby-trapped file name could run commands, so undoing either would
> reopen it.

### Why this did not need the user's attention

* **CADENCE OR NOTHING.** Cadence opens a file whose name contains a space. Chopping
  the name at the space and opening nothing is a stock-XSCHEM quirk, and a
  stock-XSCHEM-only behaviour is an argument *against* keeping it, not for it.
* **Nobody can be relying on the old split.** Multi-file open is untouched — the loop
  still runs once per argument — and the only case whose meaning changed (a second or
  later name containing a space) previously opened nothing at all. There is no working
  behaviour to preserve.
* **The prompt half was never cosmetic.** Pre-fix, the path was spliced inside double
  quotes, so a `$` in it made `tcleval` throw, `tclresult()` was never `"yes"`, and
  `save_schematic()` returned 0 — **the save silently did not happen.** Fixing that is
  not a trade.
* **Restoring either half re-opens the measured execution route** documented at the top
  of this issue, in order to protect a defect.
* **PLAIN ENGLISH / INTENT OVER MECHANISM.** A prompt that expands a `$` or a `[` is
  showing the user a path that is not the one they typed, and then acting on their
  answer to a question about a different file.

### Corrections to the record above (measured 2026-08-29)

1. **The L3 table row for `xinit.c:4062` is wrong as written, and so is the question
   sentence under it.** It must say **"the SECOND and later file names on a command
   line"**. `xschem 'my file.sch'` did **not** change and did **not** used to open
   nothing: `src/options.c:212-303` copies `argv[1]` into `cli_opt_filename`, and
   `src/xinit.c:3949-3975` loads that first name through the C `load_schematic()`,
   whose only pre-fix Tcl splices were **braced** (`update_recent_file {…}`), and
   braces do not word-split on a space. The `load_new_window` loop starts at `i = 2`
   (`src/xinit.c:4111-4113`; it starts at 1 only under `--lastopened` /
   `--lastclosed`, where the first name comes from the recent list instead). So drop
   `xschem 'my file.sch'` as the worked example — it is the one command line that did
   not change — and use `xschem a.sch 'my file.sch'`.
2. **Strike the "braced list representation" claim.** It appears twice: in the **Fix**
   section ("`[list …]` actually passed the *braced list representation* (`{/a b/c.sch}`)")
   and in **bullet 3 of the superseded RULING section** ("returns `{/a b`, leading brace
   and all"). Both are false. Run against the real proc body
   (`src/xschem.tcl:12490-12498`), the pre-fix script text
   `get_directory [list /a b/c.sch]` returns **`/a b`** — exactly what the new
   `get_directory $::v` form returns. `list` adds no braces, because neither word needs
   quoting, and a command-substitution result is one word and is not re-parsed.
   **The true statement:** the old `[list …]` splice differs from the new one only for
   *consecutive* whitespace (`/a␣␣b/c.sch` collapses to `/a b`), for a `{`, `}`, `\`
   or `"` in the path (re-quoted), for a `$` (throws: "can't read …: no such
   variable"), and for a `[` — and it is the `[` that made the splice a **command
   substitution in the outer script**, which is the whole reason the site was
   converted. So this conversion is a security fix plus a narrow whitespace fix, not
   the "one behaviour traded for another" the superseded bullet argued from.
3. **The `save.c` row must be restated as behaviour, not cosmetics.** "A `$` or `[` in
   the path was SUBSTITUTED inside the prompt text" undersells it: pre-fix a `$` in the
   path threw inside `tcleval`, so `tclresult()` was never `"yes"`, so
   `save_schematic()` returned 0 — **the file was not saved and nothing said so.**
4. **The coverage gap, recorded honestly.** `ORD2-spaces`
   (`tests/headless/test_raw_read_dispatch.tcl:492`), `SC10-tilde-and-spaces-still-work`
   (`:765`) and `SYMP06-space-path-golden` (`:846`) lock ordinary spaced paths through
   `xschem raw read`, `xschem load` and netlisting **inside a live session**. Nothing in
   `tests/headless` drives a multi-file **command line** (`grep -n load_new_window
   tests/headless/*.tcl` finds only in-session calls). So the `argv[2+]` behaviour this
   ruling ratifies is **untested**. That is a one-row test debt, not a reason to
   withhold the ruling.

### Verified in the tree before ruling (2026-08-29)

* `src/util.c:1127-1156` — `tcl_call_core()` / `tcl_call()` / `tcl_call_mid()` set a
  Tcl global and reference it as `$::__tcl_call_a1` / `$::__tcl_call_a2`, so the
  substituted word is one word and is never re-parsed.
* `src/xinit.c:4111-4118` — `if(cli_opt_lastopened || cli_opt_lastclosed) i = 1; else
  i = 2;` then `tcl_call("xschem load_new_window", cli_opt_argv[i], NULL, NULL)` once
  per argument: multiple names still open multiple files, a spaced name opens as one.
* `src/options.c:212-303` and `src/xinit.c:3949-3975` — `argv[1]` becomes
  `cli_opt_filename` and is loaded by the C `load_schematic()`; the pre-fix companion
  splice was `tclvareval("update_recent_file {", fname, "}")` — braced, so never split.
  (Pre-fix source read from `6fa7d13d^`.)
* `src/xinit.c:3909`, `src/scheduler.c:9013`, `src/scheduler.c:9846` — all three
  `file dirname` sites go through `tcl_call`.
* `src/save.c:4570-4574` and `src/save.c:6435-6438` — both `ask_save` prompts build the
  path-bearing message with `my_snprintf` and pass it through `tcl_call`.
  `ask_save` renders it as `-text $ask` (`src/xschem.tcl:10032,10047`), so a `$` or `[`
  is drawn literally. Pre-fix (`git show 6fa7d13d`) both were
  `tclvareval("ask_save \"…", path, "…\" 0")` — inside double quotes.
* `grep -n get_directory src/*.c` — all ten C call sites (the five netlisters plus
  `save.c`) use `tcl_call`; no `[list ` spelling survives.
  `grep -n tcl_call_mid src/*.c` — all 18 `netlist <file> show|noshow <cellname>`
  hand-offs converted.
* `src/xschem.tcl:12490-12498` — `get_directory` does `regsub {/[^/]*$}`; run against
  both spellings, `/a b/c.sch` gives `/a b` either way (see correction 2).
* Acceptance rows present: `tests/headless/test_raw_read_dispatch.tcl` NL01 (`:1264`),
  NL02 (`:1268`), FN07 (`:1206`), FN08 (`:1238`); ORD2 (`:492`), SC10 (`:765`),
  SYMP06 (`:846`) lock in-session spaced paths only.

### Does anything move?

**No code change.** This ratifies what already ships; the shipped behaviour is correct
on both halves.

**Follow-up work, not yet done —** one test row, to close the gap in correction 4:
open two files from a single command line where the *second* name contains a space,
and assert that both are open and the second one's name is intact. Filing it is not
part of this ruling.

An adversary reviewed this ruling: it upheld the outcome (ratify as shipped, no code
change, do not send it back to the user) and overturned the earlier section's
supporting argument and user-facing sentence on three points of fact — corrections 1,
2 and 3 above are its findings, re-measured here before being recorded.

**The user may reverse this at any time; it was decided to spare their attention, not
to bind them.**
