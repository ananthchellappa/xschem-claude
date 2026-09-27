# RECON — the `tcleval(` / generator code-execution door

## Five-line summary (driver-actionable)
1. **Does a mere open execute file-supplied code?** **YES — driven.** `xschem load <file>` with no draw, no netlist, no display (`--nogui`, `env -u DISPLAY`) ran an `exec` embedded in an instance's symbol name. Also fires from a plain `./src/xschem --nogui file.sch` command-line open.
2. **Worst verified capability:** **arbitrary Tcl at global level `#0`** — driven `exec /usr/bin/id`, `open ... w` + `puts`, and `file mkdir`, all succeeded, running as the invoking user. Ceiling is "anything Tcl/the shell can do as you."
3. **Shipped dependency:** substantial. **117 library files carry a `tcleval(` value** (49 under `xschem_library/`, 68 under `sky130A/`), plus **5 generator scripts** in `xschem_library/generators/` referenced by shipped schematics (`res.tcl`, `tier.tcl`, `symbolgen.tcl`, `schematicgen.tcl`, `mosgen.tcl`) and 1 generator instance under `sky130A/`. Instruments named below (all `/usr/bin/grep -rlF` / `-roF`). This is a used, load-bearing feature, not a stray.
4. **Guard today:** **none.** No prompt, preference, or trust check anywhere in `src/*.tcl` or `src/*.c`. Prior filing **issue 0823** records this as a deliberate DESIGN FACT and explicitly defers any trust-prompt to the user's ruling.
5. **One sentence for a non-specialist:** *"An xschem schematic file can carry commands that run on your computer the moment you open it — like a spreadsheet macro or a Makefile — and today xschem runs them silently with no warning; the decision is whether opening someone else's schematic should ask you first."*

---

## Q1 — What `tcl_hook2()` actually does (driven + code-read)

Symbol: **`tcl_hook2()`** in `src/token.c` (cite by symbol; this project's convention).

Contract, verbatim behaviour:
- **Trigger prefix:** the string must *begin with* `tcleval(` — checked as `strstr(cmd, "tcleval(") == cmd`. (⚠ NOT `@tcleval(`; the `@` spelling is a clean false-negative, per 0823.)
- **What it evaluates:** it unescapes `\}`→`}`, then calls the Tcl proc **`tclpropeval2 {<the whole value>}`** (`src/xschem.tcl`, proc `tclpropeval2`).
- **Interpreter level:** `tclpropeval2` strips the `tcleval(` / trailing `)` wrapper and runs **`uplevel #0 "subst \{$s\}"`** — i.e. `subst` at the **global (`#0`) interpreter level**. `subst` expands `[...]` command substitutions, so any bracketed command runs. **Driven:** the payload reported `level=0`, `interp=8.6.17`.
- **Returns:** the Tcl result string (or the input copied unchanged if no `tcleval(` prefix; `tcl_hook2(NULL)` just frees its static buffer).
- Sibling `tclpropeval` (`catch {subst $s}`, reached via the `@tcleval` netlist-template path) is the same `subst`-executes-brackets mechanism at the caller's level.

`tcl_hook2()` is applied at ~40 call sites (driver's "~twenty" is the right order of magnitude) across `save.c`, `token.c`, `spice_netlist.c`, `spectre/verilog/vhdl/tedax_netlist.c`, `actions.c`, `callback.c`, `scheduler.c`, `xinit.c`, `netlist.c` — chiefly on **instance names, symbol names, templates, and per-token values**.

## Q2 — Which verbs reach it; is open enough? (driven)

**The trigger is LOAD.** `load_schematic()` → `load_sym_def()` (`src/save.c`) resolves every instance's symbol name through `tcl_hook2(name)` to find the symbol file. So the code runs while the file is being read, before anything is drawn or netlisted.

Cleanly isolated (driven, `--nogui`, `env -u DISPLAY`, no file on command line):
```
AT-STARTUP-NO-FILE marker=0
xschem load <file>
AFTER-LOAD marker=1   (no draw, no netlist called)
```
Every verb was then driven from a fresh process with the payload in the symbol name; **all fired at load, exit 0, no window:**

| verb (fresh process, then the verb) | file Tcl executed? |
|---|---|
| `xschem load` only | **YES (driven)** |
| plain `./src/xschem --nogui file.sch` (command-line open) | **YES (driven)** — startup load fires it |
| `xschem print svg` | YES (driven) |
| `xschem print ps` | YES (driven) |
| `xschem netlist` (spice) | YES (driven) |
| verilog / vhdl / spectre / tedax netlist | YES (driven) — no back end differs; all load first |
| descend into symbol / save | inherit load (they cannot run without loading first) — **derived** |

**Needs no user gesture beyond opening the file:** loading, command-line open, and (because opening in the GUI draws) GUI open. Every other verb also loads first, so there is **no verb that avoids execution.**

Nuance vs 0823: issue 0823 measured only the *draw-time* trigger for a **text floater** (`T {tcleval(...)}` fires on draw, not load). This recon adds the stronger, independently-driven fact that the **symbol-name** vector (`C {tcleval(...)}`) fires at **load itself**. (Driven: a `value=tcleval(...)` token *embedded mid-format-string* did NOT fire at load or netlist, because `tcl_hook2` only triggers when the *whole* string starts with `tcleval(` — a real boundary worth knowing.)

## Q3 — The ceiling (driven)
Arbitrary Tcl at `#0`. Demonstrated harmlessly, all in the crew's own scratch `out/`:
- `exec /usr/bin/touch <scratch>` → file appeared (multiple markers).
- `open <scratch>/PROOF_open_write w` + `puts` → wrote `level=0 interp=8.6.17 cwd=/home/analog/dev/xschem-claude who=analog`.
- `file mkdir <scratch>/PROOF_mkdir` → dir appeared.
- `set ::PWNED_GLOBAL 1` — global var set (a `[set ...]` in the chain evaluated).

So `exec`, `open` (read/write), and `file` (delete/mkdir/rename) are all reachable, running as the invoking user with their full privileges. Nothing destructive was demonstrated and nothing outside scratch was touched.

## Q4 — The generator/shell claim: **REAL (driven)**
Mechanism: **`get_generator_command()`** in `src/token.c`. If a name matches `is_generator()`'s grammar `^[^ \t()]+\([^()]*\)[ \t]*$` (i.e. `head(args)`), xschem resolves `head` via `abs_sym_path`, and if that file exists builds `"<path>" arg1 arg2 …` and runs it with **`popen(cmd, "r")`** at three sites: `load_schematic` and `load_sym_def` (`src/save.c`) and `paste.c`. `popen` runs the command through **`/bin/sh -c`**.
- Driven: an instance name `{/usr/bin/touch(<scratch>/PROOF_generator_direct)}` — where the generator "head" is an existing system binary and the args come from the file — executed the binary on open.
- Driven: shell metacharacters in the generator args (`/bin/true(z;/usr/bin/touch <scratch>/...)`) also executed via `popen`'s `/bin/sh`, giving a second, non-Tcl execution channel that does not need the `tcleval(` marker.

This is independent of `tcl_hook2`: a bare `head(args)` name with no `tcleval(` prefix still `popen`s.

## Q5 — By design, and how much depends on it (driven census; instruments named)
`tcleval(` is documented, intentional xschem behaviour (computed labels, parameterised symbols, `ngspice::get_node` back-annotation, `@tcleval` netlist templates). Census instruments and figures (reproducible; a census of spellings, per J9):

- Files carrying a `tcleval(` value — `/usr/bin/grep -rlF 'tcleval(' … --include=*.sch --include=*.sym`:
  - `xschem_library/`: **49** (19 `.sch` + 30 `.sym`); total occurrences `-roF`: **92**.
  - `sky130A/`: **68** (38 `.sch` + 30 `.sym`).
  - Combined files: **117**.
- Generator scripts shipped and actually referenced by a shipped `.sch`/`.sym` (`find … -name '*.tcl'` then `grep -rqlF "<base>("`): **5** — `res.tcl`, `tier.tcl`, `symbolgen.tcl`, `schematicgen.tcl`, `mosgen.tcl`, all in `xschem_library/generators/`. Schematics referencing a generator instance (`grep -rlE '^C \{[^ }]+\([^)]*\)\}'`): 3 under `xschem_library/`, 1 under `sky130A/`.

**What breaks if `tcleval(` values stopped being evaluated:** computed/parameterised symbol values render/netlist as the literal string `tcleval(...)` instead of their result; simulator back-annotation probes (`device_param_probe.sym`, `ngspice_get_value.sym`) go dead; parameterised device symbols in sky130 lose their computed geometry/model expressions. This is not a corner feature — it is on the primary PDK path. (Derived from reading the fixtures; not each rendered.)

## Q6 — Existing guard / prompt / preference / docs (driven searches)
- **No guard, prompt, or preference exists.** `grep` for `tcl(eval|_hook).*(enable|disable|allow|permit|safe)` across `src` and `doc` finds only unrelated menu-state code. The one internal flag — `get_tok_value(..., with_quotes)` bit 1 = "do not perform `tcl_hook2` substitution" (`src/token.c`) — is an **anti-double-eval** mechanism, not a security control and not user-reachable.
- **Prior filing: issue 0823** (`doc/claude/issues/0823-a-sch-file-is-executable-by-design-…md`), status **"DESIGN FACT, not a defect, deliberately NOT proposed for a fix."** It states the honest bound: *"a `.sch` is executable by design, like a Makefile or a `.emacs`; the fixes remove the paths that execute WITHOUT saying so."* It names the only acceptable fix shape as **a trust prompt on load** and flags that as **a feature proposal needing the user's ruling**. Its §5 open item #2 asked for exactly the census above ("Not measured here… guessing is how 0681 happened") — **now measured (Q5).**
- Related family: 0812/0816/0817/0821/0822/0829 (the "unmarked door" injection fixes) and 0910 (a trusted-path precedent). The `tcleval(` marker itself was explicitly left open as design.

## Q7 — What a trust model would cost (derived; sketch only, nothing implemented)
Three plausible shapes, each measured against Q5:
1. **Prompt once per file on load (allow / refuse / always-for-this-directory).** Closest to 0823's named shape. Breaks nothing when the user allows; a refuse renders `tcleval(` literally (same as Q5's "stopped evaluating"). Touches: `load_schematic`/`load_sym_def` (`save.c`) as the single load choke-point, a small persistent allow-list (a dot-file or a Tcl var), and the `popen` generator sites. Headless/batch (`--pipe`, netlisting in CI, T1) needs a default-allow or an env override or it deadlocks — this is the main hazard, and the reason it is a ruling not a patch. Moderate: one C entry point + one Tcl dialog + a persistence file.
2. **Evaluate only for files under a trusted path** (e.g. install tree + user-configured dirs), silently literal elsewhere. Zero prompts; keeps all shipped `xschem_library/`+`sky130A/` (they live under trusted install/PDK paths) working — so it breaks **none** of Q5's 117 files if the PDK path is trusted, and disarms only downloaded/mailed sheets. Touches: the same load choke-point + a path-prefix check + a preference for the trusted list. This is the "dissolve the tradeoff" shape — it preserves the feature for the exact files that use it while closing the mail-a-schematic threat. Similar code size to (1) without the batch-deadlock risk (default is silent-literal, never a blocking prompt).
3. **A global preference defaulting one way** (`enable_tcleval` on/off). Cheapest (one guard at the `tcl_hook2` prefix test + `popen` sites), but a blunt instrument: off breaks all 117 files for everyone; on is today's behaviour. Poor fit unless paired with (1) or (2).

All three are **feature proposals that change user-visible behaviour on opening a file → they are the user's ruling, per 0823 and this project's ruling policy.** None is a defect fix.

---
### Method / hard-constraint compliance
All runs: `./src/xschem` (never bare), `--nogui`, `env -u DISPLAY` (real X server `172.20.160.1:0` never touched), `HOME` pinned to crew scratch. All fixtures and proof files under the crew's namespaced scratch `…/recon_exec_door/`; nothing written in the repo, in `~/dev/xschem-op-wcard`, or in `~/.xschem`/`~/.claude` state; no destructive op; no T1. `/usr/bin/grep` used throughout. Marks: **driven** = executed; **derived** = reasoned.
