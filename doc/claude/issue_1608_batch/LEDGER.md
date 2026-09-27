# Ledger — issue 1608 batch

Receipts land in `receipts/`. One row per handed-off task, collected by the driver.

| # | task | crew | receipt | verdict |
|---|---|---|---|---|
| A | drive (C) and (A)/(B) on all three arms; census the callers | `measure:arms+census` | `receipts/A-measure-and-census.md` | **collected — the defect is LIVE and FILE-BORNE, not latent; 13 writes in 4 mechanisms; and it is the un-fixed twin of issue 1351** |
| Av | adversarially refute A | `refute:A` | `receipts/Av-refute.md` | **collected — `%n` IS reachable from a `.sch`; the compiler fence was the wrong flag; the census counts spellings, not calls** |
| B | the bound, and truncate-vs-refuse | `design:bound` | `receipts/B-bound-shape.md` | **collected — a computed bound plus a larger scratch, and `snprintf` refuted on coherence rather than cost** |
| Bv | adversarially refute B | `refute:B` | `receipts/Bv-refute.md` | **collected — B's own patch manufactures an uninitialised-read defect and would have needed a ruling** |
| C | implement and fence | `impl` | `receipts/C-implement.md` | **collected — the five doors closed FIRST and alone, then the formatter; 28 checks** |
| Cv | independently sabotage everything | `sabotage` | `receipts/Cv-sabotage.md` | **collected — every door it could invent is shut, but 5 guards fenced nothing and 21 statements were false, 5 of them wrong ROW CITATIONS** |
| C2 | close the gaps; make citations checkable | `close` | `receipts/C2-close-gaps.md` | **collected — 4 new rows, and a row that CHECKS ROW CITATIONS instead of trusting them; 33 checks** |
| C2v | claim-by-claim truth audit | `audit` | `receipts/C2v-audit.md` | **collected — would gate; found the `if(!refuse)` wrapper unfenced in two arms, and the `#pragma` sentence wrong a SECOND time** |
| C3 | the last gap, and stop quoting counts | `final` | `receipts/C3-final.md` | **collected — 34 checks; the count rule landed as named limit L9, and the sweep found another false count** |
| C4 | make the one output delta go away | `output-neutral` | `receipts/C4-output-neutral.md` | dispatched |
| D | gate: T1 solo, fresh clone, short path | driver | — | pending C |

## ⚠ THE HEADLINE: this was filed as latent and it is LIVE, FILE-BORNE, and an attempted arbitrary write

A **`.sch`/`.sym` text object's `font=` attribute is handed to `my_snprintf` as the FORMAT STRING**
(four sites in `src/svgdraw.c`), and so is the **`--rcfile` command-line argument** (`src/xinit.c`).
`xschem print svg` on someone else's schematic is enough — no `tcleval`, no generator, no display:

* `font=%-2000d` → `*** buffer overflow detected ***`, **rc 134**
* `font=%nd` → `*** %n in writable segments detected ***`, **rc 134** — `%n` followed by any handled
  letter forms a spec that is `strncpy`'d into a **writable stack array** and handed to `sprintf`.
  **The only thing preventing an arbitrary write is glibc's `PRINTF_FORTIFY` refusal of `%n` in a
  non-read-only format** — libc hardening, not a property of this code, on one platform, in a tree
  that targets C89 and Windows as well.
* `--rcfile '%s'` → **rc 139, SIGSEGV**

⚠ **And `%nd` is a three-character spec producing almost no output, so it passes every bound Stage B
designed.** The bound is defence in depth; **only fixing the five non-literal call sites closes the
door.** That reorders the whole batch: the primary fix is in `svgdraw.c` and `xinit.c`, not `util.c`.

**It is the un-fixed twin of a defect this tree already fixed.** `src/psprint.c` carries a comment
headed *"ISSUE 1351 — THE `font=` ATTRIBUTE IS A PostScript NAME AND A FORMAT STRING, AND IT WAS
NEITHER CHECKED NOR QUOTED"* and now writes `"%s", ps_font_token(textfont)`, fenced by rows
`V10`/`V13` of `test_ps_valid_1350.tcl`. The SVG back end was missed — and two sites inside
`svgdraw.c` already use the correct `"%s"` form, so the four bad ones are an inconsistency within one
file.

## What the refutation crews overturned

**The driver's prediction H1 was refuted on the bullet it flagged as weakest.** It said "(A)/(B) is
unreachable from any format string in this tree" on the premise that all formats are literals. Five
are not, and through two of them a **file** reaches every unchecked write.

**The compiler fence was the wrong flag.** Stage A proposed `format(printf,3,4)` plus
`-Wformat-security` and reported exactly six clean diagnostics. Refuted: `-Wformat-security` warns
only for a non-literal format with **no arguments**, and all five real sites happen to be
zero-argument calls — `my_snprintf(buf, n, uf, 7)` produces nothing. The general flag is
**`-Wformat-nonliteral`**, and Stage A's stated reason was wrong too (`-Wformat-overflow` never
applies to a user function carrying the attribute).

**The census counts spellings, not calls.** Four plants at one real caller, each driven to rc 134: a
`#define`d width and a `#define`d format are mis-bucketed, and `#define XSNP my_snprintf` makes the
call **vanish from the census entirely**. The instrument has to be `gcc -E`. Four different totals
now exist — 769 grep lines, 752 source-text calls, **722 compiled**, and Stage A's 729.

**Stage B's own patch manufactures a defect.** Its guards break *before* the prefix write, so a
refusal on the first conversion leaves the caller's buffer **entirely unwritten**. Driven on a full
patched tree: a planted caller printed uninitialised stack, and the live `--rcfile 'zz%.192f'`
returned **rc 0 having silently sourced a different rc file**. Two lines fix it (a `refuse` flag and
fall-through), and with the fix it stops being a user-visible change — so no ruling is needed. As
specified, one would have been.

**And `spec_maxout`'s arithmetic is refuted by `%Lf`** — `long double`'s exponent range blows past
its `+320`, and the scanner also accepts `z`, `j`, `t` and `hh`, all returning garbage, none
censused.

## Where this came from

Carried out of the **1606** batch (landed `eb20dc62`), which found it while establishing why
1606's option 3 was not viable, named it, and deliberately did not fix it. Minted as **1608** with
both checks CLAUDE.md requires: this clone's `NUMBERING.md` pointer named it, no band conflict, no
issue file in either checkout on this machine, and no other `NUMBERING.md` claimed it.

**The issue is already wider than the note it came from.** That note named one mechanism (the
output buffer) on one arm (float) for one cause (precision). Read at `91bb1bd7`, it is **six
unchecked writes in two mechanisms across three arms**, and a field *width* reaches it with a short
spec — `%-2000d` is seven characters producing 2000 bytes, in the **integer** arm. Nobody has
looked at the format-buffer half at all.

Baseline to gate against, from `eb20dc62`: `cases=99 blocks=98 counted_failures=0 skips=8`
(`results.2257277.log`, fresh clone built from scratch at a 10-character path, solo, throwaway
home, `elapsed=588s`, `wc -l` 296).

⚠ **Gate in a clone at a SHORT path** — the session scratchpad is ~100 characters before the clone
name, and a clone at 173 makes T1 report 11 failures that are not real. `/tmp/g1608` is 10.

## Resume point

Stages A, Av and B dispatched. B is a design analysis of the build and A is a measurement of the
binary, so they are independent; Av attacks A's claims as soon as A lands.


## The fix, as it stands

**The primary change is not where the issue pointed.** Five call sites passed a value to
`my_snprintf` as the **format string** — `svg_draw` and `svg_draw_symbol` in `src/svgdraw.c` (a
`.sch`/`.sym` text's `font=` attribute, and `svg_font_name`) and `Tcl_AppInit` in `src/xinit.c`
(`--rcfile`). They now take the `"%s", <value>` form, and that alone closes every file-borne and
command-line door including `%n`. It landed first and on its own, with the four doors driven before
and after, so the door-closing is attributable to it rather than to the bound.

**The bound is defence in depth and fixes a real live death of its own**: one gate above
`my_snprintf` with three separately-removable guards — `l >= sizeof(nfmt)` for (A)/(B), a
**whitelist** of flag characters that refuses every length modifier the function does not implement
(`n`, `L`, `z`, `j`, `t`, `'`, `$`, `*` …) while keeping `l` and `h`, and a computed worst case
`max(width) + 320 < sizeof(nstr)` with the scratch raised to 512. Plus the `>` → `>=` correction in
all four arms for mechanism (D), and a NUL write on the refusal path so a refusal can never leave the
caller an untouched buffer.

**The `ps_font_token` judgement, made by the implementation crew and worth recording**: the SVG side
takes the `"%s"` and **nothing else**. `psprint.c`'s helper does two PostScript-specific jobs —
mapping the generic CSS families onto the base-14 PostScript names, and replacing the characters that
end a PostScript *name token* — and neither transfers. SVG's `font-family` **is** that namespace, and
a space inside it is legal and meaningful (`courier new`), not a terminator. Applying it here would
discard the family the user asked for and break every two-word face name that renders correctly
today.

## Why this batch ran to six rounds, and what each one actually bought

Rounds C through C4 were not the fix — the fix was finished in round C. They were the fences, and the
sequence is worth reading as a pattern rather than as a list:

| round | what it found |
|---|---|
| `Cv` | five guards fenced nothing; **21 false statements**, five of them wrong row citations |
| `C2` | fixed those, and replaced hand-written citations with **a row that checks them** |
| `C2v` | the `if(!refuse)` wrapper — *the half that stops the write* — unfenced in two arms; the `#pragma` sentence wrong a **second** time |
| `C3` | fenced it (row `G15`, at spec length **51** — at 50 the write is silent, so the death is the discriminator), and found a **third** false count in its own sweep |

**The recurring defect was never the code. It was writing down a number that nothing re-checks.**
One sentence shipped wrong three times, each time inside the revision written to correct the previous
one: it quoted `grep -c '#pragma'` as 0, then as 1, and the truth was 3 — because `grep -c` counts
**lines** and the correcting rewrite had spread the word `#pragma` across three lines of its own
sentence. The comment became its own counterexample.

So the durable output of this batch is two conventions, both now in the suite's header where the next
author reads them:

* **`L9` — no comment quotes a count a command over the tree's own text produces**, and no comment
  states a figure the instrument cannot reproduce. Either a row asserts it, where it is re-measured
  every run, or the sentence drops the number. Applying it found a *fourth* false count nobody had
  looked at: *"three live callers … `%ld` twice, `%lu` and `%hu` once"* — three, itemising four,
  having counted a `%ld` inside a comment.
* **Row `X1` — citations are checked, not trusted.** It derives the set of real row ids from the
  suite's own `check` calls rather than a hand-kept list (a hand-kept list is the same defect one
  level up), and it catches an id hidden in a block comment, in a string literal, in a `#if 0`
  region, belonging to a different suite, in a `.tcl` file, in backticks, and a range whose middle
  row was renamed away. The shapes it still misses are enumerated in limit `L7` rather than left
  absent.

Both generalise the previous batch's lesson — that a row **name** must describe its method rather
than its coverage — from names to prose and to cross-references.

## Baseline and gate

T1 solo on the working tree, run by two separate crews: `cases=100 blocks=99 counted_failures=0
skips=8`, `wc -l` 299, `elapsed≈595s`. Registered in `hcases` alone, so 99 → 100 cases and `skips=`
unchanged. ⚠ `skips=8` has now held for six figures **by coincidence of what was registered, not by
property** — read the trailer.

⚠ **Gate in a clone at a SHORT path** (`/tmp/g1608`, 10 characters). ⚠ **And never use an
`src/xschem` md5 as a build identity in this tree** — `src/scheduler.c` carries
`char date[] = __DATE__ " : " __TIME__;`, so two builds from byte-identical sources differ in the
linked binary and in `scheduler.o`. Compare the other objects.

## Carried forward — named, not fixed

1. **`my_snprintf` mis-fetches every length modifier.** It forwards the spec verbatim to `sprintf`
   but fetches with `va_arg(args, int)`, so `%ld`/`%lu` make `sprintf` read 8 bytes from a 4-byte
   value — correct today only by x86-64 zero-extension. Live spellings: `%hu` ×1, `%ld` ×2, `%lu` ×1.
   The new whitelist keeps `l` and `h` precisely because they are live; it does not fix the fetch.
2. **The `d/x/c/u` and `p` arms' prefix guard is a bare `break`** where the other arms set
   `overflow = 1`. Proved behaviourally inert today, and a trap if the arithmetic changes.
3. **`src/token.c` quotes a garbage integer in a comment** (`no '@' or '% 536627636n it.`) — limit
   `L9` clause 2's class, in another issue's text.
4. **Not measured**: a non-fortified or Windows build; whether mechanism (D) is reachable from any
   *literal* format; the stack frame against recursion depth.
