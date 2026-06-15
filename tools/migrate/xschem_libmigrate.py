#!/usr/bin/env python3
"""xschem_libmigrate — migrate flat xschem libraries to the lib/cell/view layout.

Part of the library-manager work (see code_analysis/library_manager_design.md).
Converts one or more FLAT libraries (a directory of `<cell>.sym` / `<cell>.sch`
files) into the Cadence/OpenAccess-style layout:

    <lib>/<cell>/symbol/<cell>.sym
    <lib>/<cell>/schematic/<cell>.sch

and rewrites the references inside the files from the legacy flat form
(`C {nmos4.sym}`, `schematic=foo.sch`) to the portable lib-qualified form
(`C {devices/nmos4}`, `schematic=mylib/foo`). It also writes a `library.tag`
(NAME line) in each library and a `library.defs` registry at the destination root.

Design points:
  * NON-DESTRUCTIVE: writes a fresh destination tree; the source is never
    modified. Reverting is just deleting the destination.
  * IDEMPOTENT: rewriting an already-migrated reference is a no-op, and the file
    format is preserved byte-for-byte except for the rewritten reference tokens.
  * stdlib only — no third-party dependencies, so it ships and runs anywhere.

CLI:
    python3 xschem_libmigrate.py --dst OUT --lib devices=PATH --lib mylib=PATH
    python3 xschem_libmigrate.py --dst OUT --lib mylib=PATH --dry-run
"""
import os, re, shutil, argparse

# A reference inside `C { ... }` (instance line) or a `schematic=` attribute.
_C_RE   = re.compile(r'^(C\s*\{)([^}]*)(\}.*)$')
_SCH_RE = re.compile(r'(schematic=)([^\s}]+)')
_EXTS   = (".sym", ".sch")


class Index(object):
    """Cell -> library index used to resolve legacy references during rewrite."""
    def __init__(self, libnames, lib_cells, cell_to_libs):
        self.libnames = libnames          # set of library names
        self.lib_cells = lib_cells        # libname -> set(cell)
        self.cell_to_libs = cell_to_libs  # cell -> [libname, ...] in search order


def build_index(libs):
    """libs: ordered list of (name, path). Returns an Index. The list order is
    the reference search order: a bare `cell.sym` resolves to the FIRST library
    that contains that cell (mirroring abs_sym_path's path iteration)."""
    libnames = set()
    lib_cells = {}
    cell_to_libs = {}
    for name, path in libs:
        libnames.add(name)
        cells = set()
        if os.path.isdir(path):
            for fn in os.listdir(path):
                root, ext = os.path.splitext(fn)
                if ext in _EXTS and os.path.isfile(os.path.join(path, fn)):
                    cells.add(root)
        lib_cells[name] = cells
        for c in cells:
            cell_to_libs.setdefault(c, [])
            if name not in cell_to_libs[c]:
                cell_to_libs[c].append(name)
    return Index(libnames, lib_cells, cell_to_libs)


def rewrite_reference(ref, index):
    """Map a single legacy reference to its lib-qualified form, or return it
    unchanged. Untouched: empty, generators / tcleval (contain parens), absolute
    paths, '~' paths, URLs, and any reference whose cell is not in the index."""
    if not ref:
        return ref
    if "(" in ref or ")" in ref:          # generator / tcleval(...)
        return ref
    if ref.startswith("/") or ref.startswith("~"):
        return ref
    if "://" in ref:                      # web URL
        return ref
    base = ref
    for ext in _EXTS:                     # drop a trailing .sym/.sch if present
        if base.endswith(ext):
            base = base[:-len(ext)]
            break
    if "/" in base:
        prefix, _, last = base.rpartition("/")
        if prefix in index.libnames and last in index.lib_cells.get(prefix, ()):
            return prefix + "/" + last
        return ref                        # unknown prefix / not a cell: leave as-is
    libs = index.cell_to_libs.get(base)
    if libs:
        return libs[0] + "/" + base
    return ref                            # not a known cell: leave as-is


def rewrite_text(text, index):
    """Rewrite every instance reference (`C {...}`) and `schematic=` attribute in
    a .sym/.sch file body. Preserves everything else (including the trailing
    newline) verbatim. Idempotent."""
    out = []
    for line in text.split("\n"):
        m = _C_RE.match(line)
        if m:
            line = m.group(1) + rewrite_reference(m.group(2), index) + m.group(3)
        line = _SCH_RE.sub(
            lambda x: x.group(1) + rewrite_reference(x.group(2), index), line)
        out.append(line)
    return "\n".join(out)


def _read(p):
    with open(p) as f:
        return f.read()


def _write(p, text):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        f.write(text)


def migrate(libs, dst_root, dry_run=False, defs_name="library.defs"):
    """Migrate every (name, path) library into dst_root/<name>/<cell>/<view>/...,
    rewriting references against the index built from all `libs`. Writes a
    library.tag per library and a library.defs at dst_root. Returns a report
    dict. With dry_run=True nothing is written."""
    index = build_index(libs)
    report = {"dry_run": dry_run, "libs": [], "files": 0, "rewritten": 0, "other": 0}
    defs_lines = []
    for name, path in libs:
        libdst = os.path.join(dst_root, name)
        cells = {}     # cell -> {view: src file}
        others = []    # non sym/sch files, preserved at the library root
        for fn in sorted(os.listdir(path)) if os.path.isdir(path) else []:
            full = os.path.join(path, fn)
            if not os.path.isfile(full):
                continue
            root, ext = os.path.splitext(fn)
            if ext == ".sym":
                cells.setdefault(root, {})["symbol"] = full
            elif ext == ".sch":
                cells.setdefault(root, {})["schematic"] = full
            else:
                others.append((fn, full))
        for cell, views in sorted(cells.items()):
            for view, src in sorted(views.items()):
                ext = ".sym" if view == "symbol" else ".sch"
                content = _read(src)
                newc = rewrite_text(content, index)
                if newc != content:
                    report["rewritten"] += 1
                report["files"] += 1
                if not dry_run:
                    _write(os.path.join(libdst, cell, view, cell + ext), newc)
        for fn, full in others:
            report["other"] += 1
            if not dry_run:
                os.makedirs(libdst, exist_ok=True)
                shutil.copy2(full, os.path.join(libdst, fn))
        if not dry_run:
            _write(os.path.join(libdst, "library.tag"), "NAME %s\n" % name)
        defs_lines.append("DEFINE %s %s" % (name, os.path.abspath(libdst)))
        report["libs"].append(name)
    if not dry_run and defs_lines:
        _write(os.path.join(dst_root, defs_name),
               "# generated by xschem_libmigrate\n" + "\n".join(defs_lines) + "\n")
    return report


def _parse_lib(arg):
    if "=" not in arg:
        raise argparse.ArgumentTypeError("expected name=path, got %r" % arg)
    name, path = arg.split("=", 1)
    return (name, path)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Migrate flat xschem libraries to the lib/cell/view layout.")
    ap.add_argument("--dst", required=True, help="destination root directory")
    ap.add_argument("--lib", action="append", type=_parse_lib, required=True, metavar="NAME=PATH",
                    help="a flat library to migrate; repeat for several (order = reference search order)")
    ap.add_argument("--dry-run", action="store_true", help="report only; write nothing")
    args = ap.parse_args(argv)
    report = migrate(args.lib, args.dst, dry_run=args.dry_run)
    print("%s: %d libraries, %d files (%d refs rewritten, %d other files)%s" % (
        "DRY-RUN" if report["dry_run"] else "migrated",
        len(report["libs"]), report["files"], report["rewritten"], report["other"],
        " -> " + args.dst if not report["dry_run"] else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
