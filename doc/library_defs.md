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

## 7. Naming a directory — `library.tag`

Independently of `library.defs`, a library directory may carry a `library.tag` file whose
`NAME` line sets the display name:

```
# <libdir>/library.tag
NAME MyStdCells
```

With no `library.tag`, the name defaults to the directory's basename. (`library.tag` names
the directory; `library.defs` is what actually registers it for the browser.)

## 8. Troubleshooting — "my library still isn't showing"

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

## 9. Quick reference

| Task | How |
|---|---|
| Open the browser | Tools ▸ Library Manager · `xschem library_manager` |
| Register a library (GUI) | right-click ▸ New library… |
| Register a library (file) | add `DEFINE <name> <path>` to a `library.defs` |
| Unregister | right-click ▸ Remove from list |
| Point at extra defs files | `XSCHEM_LIBRARY_DEFS=/a/library.defs:/b/library.defs` |
| Put a tree on the search path | `append XSCHEM_LIBRARY_PATH :<dir>` in `xschemrc` |
| Name a directory | `NAME <name>` in `<libdir>/library.tag` |
