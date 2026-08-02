#!/usr/bin/env python3
"""ihp_model_paths.py — make IHP testbench model references self-resolving.

    ihp_model_paths.py MODELS_DIR SCH_DIR...

The IHP PDK testbenches reference the corner libraries by BARE filename:

    .lib cornerMOSlv.lib mos_tt

That only resolves because the PDK ships a `.spiceinit` adding
`$PDK_ROOT/$PDK/libs.tech/ngspice/models` to ngspice's `sourcepath` — i.e. it
depends on PDK_ROOT/PDK being exported and on ngspice picking up that spiceinit.
A self-contained in-repo workarea has neither guarantee, so 27 of the 42
model-bearing benches would netlist cleanly and then fail to simulate.

This rewrites those bare references to `$::MODELS_NGSPICE/<file>`, the same
portable form the other 15 benches already use. `$::MODELS_NGSPICE` is set by
ihp-sg13g2/cadence_style_rc to the vendored models directory, and is expanded at
netlist time by the owning symbol's `tcleval` format — so the .sch files stay
relocatable (no absolute path is ever written into a schematic).

Two details are load-bearing:

  * Only names that actually exist in MODELS_DIR are rewritten. Benches also
    carry `.include <cell>.save` lines, which are netlist_dir-relative and MUST
    stay bare — a blanket regex would break them.

  * The rewrite only pays off if the owning symbol's value is tcleval'd.
    `devices/simulator_commands_shown` tcleval's @value in its own symbol
    definition, but `devices/code_shown`'s default format is a plain `@value`.
    For code_shown blocks with no tcleval anywhere, an instance-level
    `format="tcleval( @value )"` is inserted — otherwise the variable would be
    emitted into the netlist as literal text.

Idempotent: an already-prefixed reference and an already-present format line are
both left alone.
"""
import os, re, sys, glob

FMT_LINE = 'format="tcleval( @value )"'


def model_names(models_dir):
    """Basenames of the vendored model files — the only names we may rewrite."""
    out = set()
    for p in glob.glob(os.path.join(models_dir, "*")):
        if os.path.isfile(p):
            out.add(os.path.basename(p))
    return out


def split_c_blocks(text):
    """Yield (start, end) line-index pairs for each `C {...}` instance block.
    A block runs from its `C {` line up to (not including) the next one."""
    lines = text.split("\n")
    starts = [i for i, l in enumerate(lines) if l.startswith("C {")]
    for n, s in enumerate(starts):
        e = starts[n + 1] if n + 1 < len(starts) else len(lines)
        yield s, e


def fix_text(text, names):
    lines = text.split("\n")
    changed = False
    # Work back-to-front so inserting a line cannot shift a later block's indices.
    for s, e in reversed(list(split_c_blocks(text))):
        block = "\n".join(lines[s:e])
        sym = re.match(r"^C \{([^}]*)\}", block)
        if not sym:
            continue
        symname = sym.group(1)

        hit = False
        for i in range(s, e):
            # Name-driven, NOT line-anchored: a directive may share its line with
            # the attribute that opens it (`value=".lib cornerMOShv.lib mos_tt`),
            # so anchoring on ^ misses it. Gating on `name in names` is what keeps
            # this safe — only files that exist in the vendored models dir are
            # touched, so `.include <cell>.save` can never match.
            def sub(m):
                if m.group(2) not in names:
                    return m.group(0)
                return "%s %s%s" % (m.group(1), "$::MODELS_NGSPICE/", m.group(2))
            new = re.sub(r"(\.(?:lib|include))\s+([^\s/$\"][^\s\"]*)", sub, lines[i])
            if new != lines[i]:
                lines[i] = new
                hit = True
        if not hit:
            continue
        changed = True

        # Ensure the value is actually tcleval'd with $-substitution ON.
        #
        #  * code_shown / code: default format is a plain `@value` (no tcleval at
        #    all), so a block with no tcleval needs the instance format line.
        #
        #  * simulator_commands_shown: its symbol format DOES tcleval, but emits
        #    the payload as `return {@value}` — inside Tcl braces, where `$` is
        #    not substituted, so `$::MODELS_NGSPICE` would reach the netlist as
        #    literal text. Overriding with a plain instance-level format restores
        #    substitution. This drops that symbol's per-simulator gate, which is
        #    acceptable here: the workarea is ngspice-only (sg13g2_tests_xyce is
        #    not migrated) and every affected instance is already simulator=ngspice.
        block = "\n".join(lines[s:e])
        if symname in ("devices/code_shown", "devices/code") and "tcleval" not in block:
            lines.insert(s + 1, FMT_LINE)
        elif symname == "devices/simulator_commands_shown" and "format=" not in block:
            lines.insert(s + 1, FMT_LINE)
    return ("\n".join(lines), changed)


def main(argv):
    if len(argv) < 3:
        sys.stderr.write(__doc__)
        return 2
    models_dir, sch_dirs = argv[1], argv[2:]
    names = model_names(models_dir)
    if not names:
        sys.stderr.write("no model files found in %s\n" % models_dir)
        return 1
    nfiles = nchanged = 0
    for d in sch_dirs:
        for root, _dirs, files in os.walk(d):
            for fn in files:
                if not fn.endswith((".sch", ".sym")):
                    continue
                p = os.path.join(root, fn)
                txt = open(p).read()
                new, changed = fix_text(txt, names)
                nfiles += 1
                if changed:
                    open(p, "w").write(new)
                    nchanged += 1
    print("ihp_model_paths: %d files scanned, %d rewritten (%d model names)"
          % (nfiles, nchanged, len(names)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
