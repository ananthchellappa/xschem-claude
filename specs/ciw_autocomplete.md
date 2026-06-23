# CIW — TAB autocomplete for the command entry

Status: **proposed** (branch `feature/autocomplete`).
Related: `specs/action_logging.md` §3 (the CIW), `src/ciw.tcl` (the window),
`src/scheduler.c` (the `xschem` dispatcher — source of the subcommand list),
`claude_suggs/plan_ciw_autocomplete.md` (the implementation plan).

Readline/bash-style TAB completion in the CIW command entry. The user types Tcl
in the lower pane (`.ciw.c.e`); pressing **Tab** completes the token under the
cursor against the right vocabulary for its position — Tcl commands, `xschem`
subcommands, variable names, and file paths — and shows ambiguous candidates in
the upper log pane.

## Motivation

The CIW (Command Interpreter Window, `src/ciw.tcl`) is the Tcl console: every
editor operation is reachable as `xschem <subcommand> …`, and the entry already
has history (Up/Down) and shell-style line editing (`Control-BackSpace`). What it
lacks is discovery and speed. There are **267** `xschem` subcommands, dispatched
by hand-written `strcmp(argv[1], "…")` branches in `scheduler.c`; no one memorises
them. Tab completion turns the CIW from "console for people who already know the
command" into a self-documenting surface — the same lift `<Tab>` gives a shell.

## Where it hooks in

`.ciw.c.e` is a `text` widget (not an `entry`) so its height can follow the sash
(`ciw.tcl:70`). It already binds `<Return>`, `<KP_Enter>`, `<Up>`, `<Down>`,
`<Control-BackSpace>`, each ending in `break` to suppress the Text class binding.
Autocomplete is one more of the same shape:

```tcl
bind .ciw.c.e <Tab> {ciw_complete; break}
```

The trailing `break` is essential — without it Tk also runs the default `<Tab>`
binding, which moves keyboard focus to the next widget.

## Behaviour (readline / bash semantics)

`ciw_complete` reads the text from line start (`1.0`) to the insertion cursor
(`insert`), splits it into whitespace-separated tokens, and completes the **last**
token (the one the cursor sits at the end of). Trailing whitespace means "start a
new, empty token" — Tab there lists everything valid in that position.

Given the candidate set for that token:

- **0 candidates** → `bell`, nothing inserted.
- **1 candidate** → replace the token with the full candidate + a trailing space
  (ready for the next token). Paths are special-cased: a directory completes to
  `dir/` with no trailing space, so the next Tab descends into it.
- **>1 candidates** →
  - extend the token to the **longest common prefix** of all candidates (so Tab
    always makes as much progress as is unambiguous), then
  - if that added nothing (the token already *is* the common prefix), **list** the
    candidates into the upper log pane via `ciw_echo` with the `result` tag — no
    popup, no extra widget; reuses the surface that already shows command output.

Listing in the existing pane (rather than a popup menu) is the deliberate choice:
it matches the console metaphor, needs no new widget/geometry/focus handling, and
the candidates scroll into the same history the user is already reading.

## What gets completed, by token position

The completion source is chosen from the parsed tokens, cheapest/most-specific
first:

1. **Variable reference** — the token starts with `$`. Candidates are the global
   Tcl variables matching the prefix: `info globals <prefix>*` (also `info vars`
   for the rare proc-scope use). The `$` is preserved; only the name completes.

2. **Second token of an `xschem` command** — token 0 is exactly `xschem` and we
   are completing token 1. Candidates are the **xschem subcommand list** (see
   below) filtered by prefix. This is the headline case.

3. **First token (the command)** — candidates are Tcl commands and procs from
   `info commands <prefix>*`. This naturally includes `xschem` itself and every
   user/GUI proc, for free.

4. **Anything else (fallback)** — **file-path completion** via
   `glob -nocomplain ${token}*`, with `~` expansion. This covers the arguments to
   path-taking subcommands (`xschem load`, `save`, `instance`, `hier_psprint`, …)
   without having to know which subcommands those are. Directories complete with a
   trailing `/`.

(Deeper, argument-aware completion — C-side variable names for `xschem set`/`get`,
layer names, in-design instance/net names — is explicitly **out of scope** for the
first cut; see below. The position model above leaves room to add it as more
specific cases ahead of the path fallback.)

## The `xschem` subcommand list — the one real design decision

`xschem` is the central dispatcher but routes via ~267 literal
`strcmp(argv[1], "name")` branches (split across `xschem_cmds_a` … `xschem_cmds_z`
in `scheduler.c`). There is **no runtime registry** and Tcl introspection
(`info`) cannot see subcommands of a C-implemented command. So the list has to be
sourced deliberately. Decision:

**Generate it at build time from `scheduler.c` into a shipped data file.**

A Makefile rule greps the subcommand strings out of `scheduler.c` into
`xschem_subcommands.txt`, which is installed to `XSCHEM_SHAREDIR` exactly like
`actions.csv` / `keybindings.csv`, and loaded once by `ciw.tcl` at first use. This
follows two established conventions in the tree at once — awk/grep build-time
codegen (`create_alloc_ids.awk`, the bison/flex parsers) and shipped data tables
loaded by Tcl (`action_registry.tcl` reading `actions.csv`) — costs nothing at
runtime, and **cannot drift**: the file is regenerated from the single source of
truth whenever `scheduler.c` changes.

Rejected alternatives:

- **A static Tcl/C list** hand-kept in sync with the 267 branches — drifts the
  moment anyone adds a subcommand; the failure is silent (a real command just
  won't autocomplete). No.
- **A new `xschem subcommands` introspection subcommand** returning a compiled-in
  array — cleaner call site, but the array still has to be hand-maintained against
  the strcmp branches, i.e. the same drift with extra C. Only worth it if a
  runtime consumer other than the CIW ever needs the list.

The loader degrades gracefully: if the data file is missing (e.g. a partial dev
tree), subcommand completion is simply empty and the other sources still work.

## Acceptance / tests

`tests/headless/test_ciw_autocomplete.tcl` (extends the existing
`tests/headless/test_ciw.tcl` pattern; needs X + `--pipe`). The discriminating,
deterministic checks — driving `ciw_complete` by setting `.ciw.c.e` content and
placing `insert`, then asserting the resulting text / log-pane content:

- **AC1** unique command prefix completes: entry `xschem add_g` → after Tab the
  entry reads `xschem add_graph ` (subcommand + trailing space, `add_graph` being
  the only `add_g…` command). Proves the generated list loaded and prefix match +
  single-candidate insertion work.
- **AC2** ambiguous prefix inserts the longest common prefix: `xschem loa` matches
  `load`, `load_backup`, `load_new_window`, `load_symbol` → entry advances to the
  common prefix `xschem load` (no trailing space, no spurious command chosen).
- **AC3** ambiguous-with-no-progress lists candidates: Tab on `xschem ` (empty
  token after a space) appends candidate lines to `.ciw.l.t`; assert the pane grew
  and contains a couple of known subcommands.
- **AC4** no match rings the bell and leaves the entry unchanged:
  `xschem zzzzz` + Tab → entry text identical.
- **AC5** first-token completion uses Tcl commands: `ciw_exe` → completes toward
  `ciw_exec` (a known proc), proving the `info commands` path.
- **AC6** variable completion: `puts $ciw_hi` matches the three `ciw_hist…`
  globals → advances to the common prefix `puts $ciw_hist` (the `$` preserved).
- **AC7** the `xschem_subcommands.txt` generated file exists in `XSCHEM_SHAREDIR`
  and parses to a non-empty list that includes a known command (`load`).
- **AC8** the `<Tab>` binding is present on `.ciw.c.e` and ends in `break`.

**Not auto-tested (manual eyeball):** path completion against the real filesystem
(directory `/` suffix, `~` expansion) — environment-dependent; smoke by hand.

## Out of scope (first cut)

- **Argument-aware completion** beyond paths: C-side var names for
  `xschem set`/`get`, layer names, in-design instance/net names. The position
  model leaves a clean insertion point for these as later, more-specific cases.
- **Sub-subcommand trees** (e.g. `xschem raw switch …`, `xschem new_schematic …`)
  — only the first subcommand token completes for now.
- A **dropdown/popup** completion menu. The log-pane listing is the chosen UX; a
  popup is a separate enhancement if ever wanted.
- Completion in any widget other than the CIW entry (the main `.drw` canvas, dialog
  fields, the Library Manager).
- Fuzzy / substring matching — prefix only, like a shell.
