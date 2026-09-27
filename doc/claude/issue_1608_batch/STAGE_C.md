# Stage C — implementation brief, with every Stage A/B claim already adjudicated

Read `CREW_BRIEF.md` first, then this. **This supersedes `PLAN.md` and `DECISIONS.md` H1/H2
wherever they disagree** — the four measurement crews refuted the driver's prediction on its central
bullet and refuted Stage B's own patch. Do not re-derive the measurements; they are in `receipts/`.

## ⚠ The severity changed, and it changes what the fix IS

**This is not a latent defect and the bound is not the fix.** Measured:

* A **`.sch`/`.sym` text object's `font=` attribute is passed to `my_snprintf` AS THE FORMAT
  STRING** (`svg_draw` and `svg_draw_symbol` in `src/svgdraw.c`, four sites — two `textfont`, two
  `tclgetvar("svg_font_name")`), and so is the **`--rcfile` command-line argument**
  (`Tcl_AppInit` in `src/xinit.c`). `xschem print svg` on someone else's schematic is enough. No
  `tcleval`, no generator, no display.
* `font=%-2000d` → `*** buffer overflow detected ***`, **rc 134**, headless.
* **`font=%nd` → `*** %n in writable segments detected ***`, rc 134.** `%n` escapes the scanner
  alone because `n` is not a terminator, but `%n` followed by any handled letter is a spec that gets
  `strncpy`'d into `nfmt` — **a writable stack array** — and handed to `sprintf`. The only thing
  preventing an arbitrary write is **glibc's `PRINTF_FORTIFY` refusal of `%n` in a non-read-only
  format**: libc hardening, not a property of this code, and this tree targets C89 and Windows too.
* `--rcfile '%s'` → **rc 139, SIGSEGV** (the `%s` arm does `va_arg(args, char *)` then `strlen`).

**⚠ `%nd` IS A THREE-CHARACTER SPEC PRODUCING ~ZERO OUTPUT, SO IT PASSES EVERY BOUND STAGE B
PROPOSED.** Only fixing the five call sites closes the format-string door. The `util.c` bound is
defence in depth and fixes one real live death (`%.6f` of ±`DBL_MAX`); it does **not** close this.

**And this is the un-fixed twin of a defect this tree already fixed.** `src/psprint.c` carries a
comment headed *"ISSUE 1351 — THE `font=` ATTRIBUTE IS A PostScript NAME AND A FORMAT STRING, AND
IT WAS NEITHER CHECKED NOR QUOTED"*, and now writes `"%s", ps_font_token(textfont)`; rows `V10`/`V13`
of `tests/headless/test_ps_valid_1350.tcl` fence it. **The SVG back end was simply missed** — and
two nearby sites inside `svgdraw.c` already use the correct `"%s"` form, so the four bad ones are an
inconsistency within one file.

## The thirteen adjudications

**J1. THE PRIMARY FIX IS THE FIVE CALL SITES, and it lands first.** `svgdraw.c` ×4 and
`xinit.c` ×1 take the `"%s", <value>` form. Follow what `psprint.c` did for 1351 — read
`ps_font_token` and decide whether the SVG side needs the same token-validation or only the `"%s"`.
State which and why. This single change removes every file-borne and command-line door, `%n`
included.

**J2. THE `util.c` BOUND IS DEFENCE IN DEPTH AND STILL SHIPS**, because it fixes a live death that
J1 does not: `%.6f` of ±`DBL_MAX` aborts today at every buffer size tried, from
`scheduler.c`'s `net_hilight_march_offset` caller. Bound (A)/(B) with
`if(l >= sizeof(nfmt)) { … }` before the `strncpy`, and (C) with a computed worst case plus a larger
scratch.

**J3. ⚠ STAGE B'S PATCH MANUFACTURES A NEW DEFECT — DO NOT LAND IT AS WRITTEN.** Its guards break
**before** the prefix `memcpy(string + n, prev, l); string[n+l] = '\0';`, so a refusal on the first
conversion leaves the destination **entirely unwritten** and the caller reads uninitialised memory.
Driven on a full patched tree: a planted caller printed `|/tmp/claude-1000/-ho|` from uninitialised
stack, and the live `--rcfile 'zz%.192f'` returned **rc 0 having silently sourced a different rc
file** instead of reporting `cannot find zz…`. **Fix: set a local `refuse` flag, fall through the
prefix write, then break.** The `spec_maxout` check may simply move below the prefix block; the
`l >= sizeof(nfmt)` check cannot, since it must precede `strncpy` — hence the flag. With the
reordering this stops being a user-visible shape change, so **no ruling is needed**; without it,
one would be.

**J4. `spec_maxout`'s arithmetic is refuted by the `L` length modifier.** `%Lf` is `long double`,
whose exponent range makes the output far wider than `+320` allows. The scanner accepts `L`, and
also `z`, `j`, `t`, `hh` — all driven through `--rcfile`, all returning garbage, none in any census.
**Decide and state**: either account for `long double` in the bound, or **refuse any length modifier
the function does not implement** (which is all of them — see J11). Refusing is likely simpler and
more honest, since the function already mis-fetches them.

**J5. REFUSE `%n` EXPLICITLY, in the spec scan, belt and braces.** J1 removes today's doors, but
the only thing standing between a future non-literal format and an arbitrary write is libc
hardening on one platform. A formatter that hands `%n` to `sprintf` from a writable buffer should
refuse it itself. ⚠ Note the **death message differs by mechanism** (`*** %n in writable segments
detected ***` vs `*** buffer overflow detected ***`), so a row asserting the buffer-overflow text
misses this shape entirely — **assert `rc`, not the message**.

**J6. Mechanism (D): `if(n+l > size)` must be `>= size`, in ALL FOUR arms** (the `%s` arm included).
At `n+l == size` it writes `string[n+l] = '\0'` one byte past **the caller's** buffer. `string` is a
pointer parameter, so per 1606's own finding `_FORTIFY_SOURCE` cannot size it and emits no check —
**this one is silent**. Driven: `svg_font_family` is `char[80]`, and a `font=` value of exactly 80
characters puts the NUL at index 80, rc 0, no signal, no message.

**J7. The write tally in the issue is wrong and must be corrected.** Not "six unchecked writes in
two mechanisms": **(A) 3 + (B) 3 + (C) 3 + (D) 4 = thirteen unchecked write statements in four
mechanisms.** And **(B) fires FIRST and SILENTLY**, at `l == 50`, one byte past `nfmt` — because
`strncpy` is fortified (`__strncpy_chk` aborts at `l >= 51`) while a plain array store is not. The
plan and the issue both assume the `strncpy` is the concern; it is the lower, quieter threshold that
goes first.

**J8. ⚠ THE COMPILER FENCE IS `-Wformat-nonliteral`, NOT `-Wformat-security`.** Stage A's claim that
the `format(printf,3,4)` attribute makes any future non-literal format a diagnostic is **refuted**:
`-Wformat-security` warns only for a non-literal format with **no arguments**, and the five real
sites are diagnosed only because all five happen to be zero-argument calls. `my_snprintf(buf, n, uf,
7)` gives no diagnostic at all. `-Wformat-nonliteral` is the general flag and was measured to add
exactly five lines tree-wide with no noise — **including the three `sprintf(nstr, nfmt, i)` sites
inside `my_snprintf` itself**, which will need a localised suppression with a comment saying why.
Stage A's stated *reason* was also wrong: `-Wformat-overflow` never applies to a user function
carrying the attribute, only to the builtins whose destination gcc knows.

**J9. ⚠ A CENSUS OVER SOURCE TEXT IS A CENSUS OF SPELLINGS.** Four plants at one real caller, each
driven to rc 134: a `#define`d width (`"%" WPFX "d"`) and a `#define`d format (`PFMT`) are
mis-bucketed, and **`#define XSNP my_snprintf` makes the call vanish from the census entirely**.
**Any census row must run over `gcc -E` output with the tree's real CFLAGS.** Compiled figures, for
the record: **722** call expressions, 716 literal, 5 non-literal, 1218 conversions, max literal spec
length 5, **zero `*`, zero width or precision ≥ 20**. ⚠ And **four different totals exist** — 769
grep lines, 752 source-text calls, 722 compiled, and Stage A's 729. **Quote the compiled one and say
which instrument produced it.**

**J10. Delete the `#ifdef HAS_SNPRINTF` arm, and `scheduler.c`'s `HAS_SNPRINTF=%s` line with it** —
but **leave a comment where it was** recording that it existed, that it has never compiled on any
platform, and *why enabling it is unsafe* (the two arms' return values mean different things — bytes
written vs. bytes that would have been — and live sites consume that return as a length). That
preserves the information without preserving the trap, which neither deleting silently nor
`#error`-ing does. ⚠ A fifth proof it never compiled, and the first behavioural one: `xschem
globals` prints `HAS_DUP2=1`, `HAS_POPEN=1`, `HAS_CAIRO=1` and **no `HAS_SNPRINTF=` line at all**.
⚠ And 1606's wording is half wrong — `-DHAS_SNPRINTF=` is a *compile error*, while `-DHAS_SNPRINTF=1`
**compiles clean even with `-Wall`**, because nothing carries the format attribute today. The
precedent that settles it: `util.c`'s own `log_action` comment records this tree **losing a process**
to exactly this `#ifdef` reading as protection — a 4971-byte Tk menu `-command` script aborted the
editor on a click, with an unsaved schematic in it.

**J11. Fix `src/parselabel.l`'s declaration.** It declares `extern int my_snprintf(char *str, int
size, const char *fmt, ...)` against `util.h`'s `size_t`/`size_t` — **two incompatible declarations
of one function in one program**, which is undefined behaviour and will fight the format attribute.

**J12. Fence it per `CREW_BRIEF.md`'s hard-won rules.** A **behavioural** row is the backbone and
several doors exist: the `font=` `.sch` fixture under `xschem print svg` (headless, no display), the
same with an `l == 62` spec for (A), `%.60g` for (C), `%nd` for J5, and `--rcfile` as an independent
door. ⚠ Two measured traps: **`xschem zoom_full` is required before `print svg`** or the text falls
outside the viewport and no `<text>` is emitted at all; and **assert `rc`, never the death marker** —
across ~40 driven aborts no column-0 `FATAL` line is ever printed, because `main.c`'s `sig_handler`
does not trap SIGABRT. Add the `-Wformat-nonliteral` diagnostic row (J8) and the `gcc -E` census row
(J9). Static rows only where neither reaches, named for **what text they grep** and claiming **no
count** of what escapes them.

**J13. Every bound gets a row that reddens on ITS OWN single removal.** (B) and (A) share one guard
by design — **say so in its comment**, since two guards on one path means neither is individually
fenced, which defeated a whole plan in the 1606 batch.

## Also required

* **Correct the issue file** `1608-…md`: the `## What is LATENT and what is not` section is **false**
  and must be replaced with the driven rc 134; the tally goes to thirteen writes in four mechanisms;
  the `~748` becomes 722 compiled with the instrument named; and the `%n` finding and the 1351 twin
  both need stating. Keep the original filing readable beneath a correction section, as issue 1606
  does.
* Carried forward, **named not fixed**: the scanner mis-fetches every length modifier (`%ld`/`%lu`/
  `%hu` live; `%zd`/`%jd`/`%td`/`%hhd` reachable) — it forwards the spec verbatim to `sprintf` but
  fetches with `va_arg(args, int)`, so `sprintf` reads 8 bytes from a 4-byte value and works only by
  x86-64 zero-extension; the `d/x/c/u` and `p` arms' prefix guard is a bare `break` with no
  `overflow = 1` where the other arms set it; and `1606`'s *"`%.*g` can never exceed 774
  characters"* measured **758** here — not contradicted, but **do not carry 774 into a new comment**.
