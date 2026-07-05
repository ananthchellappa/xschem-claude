# Making a library visible in the Library Manager (`library.defs`)

*You have a directory full of cells (`<lib>/<cell>/symbol/<cell>.sym`) and want it to
show up in the Library Manager browser. This is the `library.defs` registry — how it
works, the two ways to register a library, and why some libraries "just appear" while a
new one you add does not.*

> Companion: `doc/library_instance_commands.md` (the `xschem library_manager` /
> `get_inst_lcv` / `create_instance` commands). Background: `doc/pin_name_migration.md`
> (produces migrated libraries you may then want to register).

---

## 1. The one rule

A library appears in the Library Manager iff it is **`DEFINE`d in a `library.defs` file
that xschem loads**. Nothing else registers a library — not merely being on the symbol
search path, not living in the Cadence `<lib>/<cell>/<view>` layout. There are two ways to
add that `DEFINE`:

- **the GUI** — Library Manager ▸ right-click ▸ **New library…** (§2), or
- **by hand** — add a `DEFINE` line to a `library.defs` (§3).

They do the same thing; the GUI just writes the line for you.

## 2. The GUI way — "New library…"

1. **Tools ▸ Library Manager** (or type `xschem library_manager`).
2. **Right-click in the Library column ▸ "New library…"**.
3. Fill in:
   - **Library name** — the name shown in the browser (and used in lib-qualified
     references, e.g. `C {mylib/myinv}`).
   - **Directory** — where the cells live. **Blank = a new subdirectory next to the
     `library.defs`**, named after the library.
4. **OK**. xschem creates the directory (if needed) and appends
   `DEFINE <name> <path>` to the primary writable `library.defs` (using a path relative to
   the defs file when the library sits under it, so a committed `library.defs` stays
   portable).

To unregister: right-click the library ▸ **Remove from list** (this only removes the
`DEFINE` line — files on disk are left untouched; it errors for an *auto-discovered*
library, which has no `DEFINE` to remove — see §4).

## 3. The `library.defs` file (by hand)

A plain text file, one directive per line:

```
# a comment
DEFINE devices  devices
DEFINE examples examples
DEFINE mylib    ~/projects/mylib
DEFINE stdcells ${PDK_ROOT}/sky130/libs.ref/sky130_fd_sc_hd
```

- `DEFINE <name> <path>` registers `<name>` → `<path>`.
- **Relative paths are resolved against the directory of the `library.defs` itself**
  (the cds.lib convention) — so `DEFINE devices devices` points at the `devices/`
  subdirectory beside the file. This is what makes a committed `library.defs` location-
  independent.
- Paths may use `~`, `~/…`, and `${ENV_VAR}` (expanded from the environment).
- Blank lines and `#` lines are ignored.

Add a line, restart xschem (or reload), and the library is in the browser.

## 4. Where xschem looks for `library.defs` (precedence)

xschem aggregates **every** `library.defs` it can find, in this order:

1. **Explicit** — the files listed in the `XSCHEM_LIBRARY_DEFS` environment variable
   (`:`-separated on Unix, `;` on Windows). Highest priority; the "primary" writable defs
   file for New-library comes from here first.
2. **Auto-discovered on the search path** — a `library.defs` sitting **in** any directory
   on the symbol search path (`XSCHEM_LIBRARY_PATH`, §5) **or one level above it**. This is
   the cds.lib/OA convention, where the defs file lives alongside the per-library
   subdirectories. **This is why a library that ships its own `library.defs` "just
   appears" with no action from you.**
3. **Personal** — `~/.xschem/library.defs`, but only when the global
   `library_personal_defs` is set to `1`. It is **off by default**, so nothing is read
   from or written to `~/.xschem` unless you opt in.

## 5. The search path (`XSCHEM_LIBRARY_PATH`)

Auto-discovery (§4.2) only scans directories that are on the symbol **search path**. That
path is `XSCHEM_LIBRARY_PATH`, set in an `xschemrc`:

```tcl
# in ~/.xschem/xschemrc or ./xschemrc
append XSCHEM_LIBRARY_PATH :~/projects/mylibs
append XSCHEM_LIBRARY_PATH :${XSCHEM_SHAREDIR}/xschem_library/devices
```

So the recipe for a self-contained library tree that carries its own `library.defs` is:
put the tree on `XSCHEM_LIBRARY_PATH`, and every library its `library.defs` `DEFINE`s
appears automatically.

## 6. Worked example — the SANDBOX case

This is the exact situation where a library "appeared on its own" but a new one needed a
manual step.

`xschem_libraries_oa/` ships its **own** `library.defs`:

```
# xschem_libraries_oa/library.defs
DEFINE devices  devices
DEFINE examples examples
DEFINE ngspice  ngspice
DEFINE logic    logic
... (one per sub-library)
```

Because that tree is on `XSCHEM_LIBRARY_PATH`, xschem **auto-discovers** this
`library.defs` (§4.2) and every `DEFINE`d sub-library shows up in the Library Manager —
you never had to register them.

Now you add a **new** subdirectory `SANDBOX/` with your own cells. It does **not** appear,
because it is not `DEFINE`d anywhere. Two fixes, either works:

- **GUI:** Library Manager ▸ right-click ▸ New library… → name `SANDBOX`, directory
  `SANDBOX` (or blank). This appends the line for you.
- **By hand:** add one line to `xschem_libraries_oa/library.defs`:
  ```
  DEFINE SANDBOX SANDBOX
  ```
  (relative → resolves to `xschem_libraries_oa/SANDBOX`).

Reload, and `SANDBOX` is in the browser. That hand-edit is precisely what "New library…"
does.

## 7. Loading *migrated* libraries at startup (old → new)

If you converted an old-style library to owned pin-name text with
`tools/migrate/migrate_pin_names.py` (see `doc/pin_name_migration.md`) and produced a
**new tree** (e.g. `xschem_libraries_oa` → `xschem_libs_newsym`), you now have two copies
and need xschem to load the migrated one at startup.

**The key fact:** migration is a drop-in. The migrated tree keeps the same
Library/Cell/View names, the same pin `name=`/`dir=`, and the same connectivity — only
display tokens changed, so **netlists are identical**. It even copied the original's
`library.defs` (same `DEFINE` lines). So "load the correct libraries" is purely a matter of
pointing xschem's startup search at the migrated tree instead of the old one.

xschem's startup library set comes from your `xschemrc` (§4–§5): whichever `library.defs` it
loads — explicitly via `XSCHEM_LIBRARY_DEFS`, or auto-discovered on `XSCHEM_LIBRARY_PATH` —
is what the Library Manager shows. Pick one:

- **A — swap the tree on the path (recommended).** In your `xschemrc`, put the migrated tree
  on `XSCHEM_LIBRARY_PATH` and drop the old one:
  ```tcl
  # was: append XSCHEM_LIBRARY_PATH :/path/xschem_libraries_oa
  append XSCHEM_LIBRARY_PATH :/path/xschem_libs_newsym
  ```
  The migrated tree carries its own `library.defs`, so xschem auto-discovers it and the same
  library names reappear — now with owned pin names.
- **B — point `XSCHEM_LIBRARY_DEFS` at the migrated defs file.**
  ```sh
  export XSCHEM_LIBRARY_DEFS=/path/xschem_libs_newsym/library.defs
  ```
  Explicit defs take precedence over auto-discovered ones (§4).

**Avoid the collision trap.** Do **not** leave *both* trees on the path/defs with the *same*
library names. Two `DEFINE devices …` entries are deduped by name, and which one wins depends
on precedence (explicit before discovered) and search order — you may silently get the old,
un-migrated cells. Remove the old tree from the path, or rename its libraries.

**Simplest of all — migrate in place.** Because migration is display-only, netlist-invariant,
and idempotent, converting the *original* tree in place (its `.bak` files, or git, are your
backup) sidesteps the two-tree question entirely: every `library.defs` entry, schematic
reference, and Library-Manager library stays exactly as it was, and each cell simply gains
owned pin names. If you already made a separate tree, you can instead just replace the old
tree's contents with the migrated ones.

Existing schematics need no edits either way: a reference like `C {devices/nmos4}` resolves
through whichever `devices` library is registered, so once the migrated `devices` is the one
on the path, your schematics pick up the owned-pin-name symbols automatically (and, again,
the netlist is unchanged).

**Verify after (re)starting xschem:** open **Tools ▸ Library Manager**, pick a migrated cell,
and confirm its pin names show (**Symbol ▸ Pin names ▸ Show all pin names**), or that its
`.sym` carries `show_pinname` tokens. On a placed instance, `xschem get_inst_lcv` reports the
Library/Cell/View it resolved from — a quick way to confirm you are on the migrated tree.

## 8. Per-project library setups (a different `library.defs` per project)

If you work on several projects that each need different libraries, don't keep editing one
global config — give each project its own `xschemrc`. `XSCHEM_LIBRARY_DEFS` and
`XSCHEM_LIBRARY_PATH` are **Tcl variables set inside an `xschemrc`** (not OS environment
variables xschem reads on its own), and xschem selects an `xschemrc` per project.

**How xschem chooses an `xschemrc`.** At startup it sources, in order:

1. any `--preinit '<tcl>'` snippet (before every rc);
2. the **system** `xschemrc` (`$XSCHEM_SHAREDIR/xschemrc`) — always;
3. then **exactly one** of, highest priority first:
   - **`--rcfile <file>`** if given (a missing file is a fatal error), else
   - **`./xschemrc`** in the **directory you launched xschem from** (`getcwd()`), else
   - **`~/.xschem/xschemrc`** (the personal one).

The system rc always runs first, so a project rc *layers on top* — `set` to replace a value,
`append XSCHEM_LIBRARY_PATH :…` to extend it. Pick whichever launch style fits:

**A — one directory per project, each with its own `./xschemrc` (idiomatic).**
```tcl
# ~/proj/chipA/xschemrc
set XSCHEM_LIBRARY_DEFS /home/me/proj/chipA/library.defs
# or build XSCHEM_LIBRARY_PATH so the project tree's library.defs is auto-discovered (§5)
```
`cd ~/proj/chipA && xschem` loads the system rc, then this project's `./xschemrc`. Ten
project directories → ten setups, no flags.

**B — `--rcfile` (explicit, cwd-independent; best for launchers / menu items).**
```sh
xschem --rcfile ~/proj/chipA/xschemrc
```
Takes precedence over the cwd/personal rc. Make one tiny launcher per project, or a wrapper
that takes a project name.

**C — environment-driven (direnv / modules) — needs a one-line bridge.**
A bare `export XSCHEM_LIBRARY_DEFS=…` does **nothing** by itself: xschem reads the Tcl
variable, not the OS env var. Bridge it once in your **personal** `~/.xschem/xschemrc`:
```tcl
if {[info exists env(XSCHEM_LIBRARY_DEFS)]} { set XSCHEM_LIBRARY_DEFS $env(XSCHEM_LIBRARY_DEFS) }
if {[info exists env(XSCHEM_LIBRARY_PATH)]} { set XSCHEM_LIBRARY_PATH $env(XSCHEM_LIBRARY_PATH) }
```
Then set the variable per project — e.g. a direnv `.envrc` in each project directory:
```sh
# ~/proj/chipA/.envrc
export XSCHEM_LIBRARY_DEFS=/home/me/proj/chipA/library.defs
```
`cd` into a project and its libraries switch automatically.

Notes:

- `XSCHEM_LIBRARY_DEFS` is a `:`-separated list, so a project rc can pull in a shared/common
  `library.defs` *and* a project-specific one.
- `--preinit 'set XSCHEM_LIBRARY_DEFS …'` also works, but it runs *before* the system/cwd/
  personal rc, so those can override it — prefer `--rcfile`.
- Because `xschemrc` is just Tcl, a single shared rc can even branch on `$env(PROJECT)` or the
  cwd to choose the defs — but a per-directory rc (A) or `--rcfile` (B) is cleaner.

## 9. Naming a directory — `library.tag`

Independently of `library.defs`, a library directory may carry a `library.tag` file whose
`NAME` line sets the display name:

```
# <libdir>/library.tag
NAME MyStdCells
```

With no `library.tag`, the name defaults to the directory's basename. (`library.tag` names
the directory; `library.defs` is what actually registers it for the browser.)

## 10. Troubleshooting — "my library still isn't showing"

- **Is it `DEFINE`d?** Grep your `library.defs` files for the name. No `DEFINE` → it won't
  show (being on the search path alone is not enough).
- **Is the `library.defs` loaded?** It must be in `XSCHEM_LIBRARY_DEFS`, or on (or just
  above) a directory on `XSCHEM_LIBRARY_PATH`. `echo $XSCHEM_LIBRARY_DEFS` and check your
  `XSCHEM_LIBRARY_PATH`.
- **Relative path pointing where you think?** A relative `DEFINE` path is relative to the
  **defs file's** directory, not your cwd.
- **Cells not in the Cadence layout?** The browser expects
  `<libpath>/<cell>/<view>/<cell>.sym`. A flat directory of `.sym` files is reachable via
  the search path but is *not* a Library-Manager library. (`xschem get_inst_lcv` reports
  "not in a Cadence library" for such symbols — a quick way to check.)
- Changed a `library.defs`? Reopen the Library Manager (or restart xschem) so it re-reads.

## 11. Quick reference

| Task | How |
|---|---|
| Open the browser | Tools ▸ Library Manager · `xschem library_manager` |
| Register a library (GUI) | right-click ▸ New library… |
| Register a library (file) | add `DEFINE <name> <path>` to a `library.defs` |
| Unregister | right-click ▸ Remove from list |
| Point at extra defs files | `XSCHEM_LIBRARY_DEFS=/a/library.defs:/b/library.defs` |
| Put a tree on the search path | `append XSCHEM_LIBRARY_PATH :<dir>` in `xschemrc` |
| Load migrated libs (old → new) | repoint `XSCHEM_LIBRARY_PATH`/`XSCHEM_LIBRARY_DEFS` at the migrated tree (§7); don't keep both |
| Per-project libraries | a `./xschemrc` per project dir, or `xschem --rcfile <proj>/xschemrc` (§8) |
| Name a directory | `NAME <name>` in `<libdir>/library.tag` |
