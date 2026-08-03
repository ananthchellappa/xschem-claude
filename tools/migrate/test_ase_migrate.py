#!/usr/bin/env python3
"""Tests for ase_migrate — the testbench de-clutter (ASE-L) migrator.

Dependency-free (stdlib only), self-reporting like the headless tcl suites and
the sibling test_libmigrate.py: prints "ok:"/"FAIL:" per check and
"RESULT: ALL PASS" / "RESULT: N FAILED", exits non-zero on failure.

  python3 tools/migrate/test_ase_migrate.py

The integration leg (migrate the real gf180 nfet_test_claude, then run both the
cluttered and the migrated cell through xschem+ngspice and compare Id) is gated
on ./src/xschem and ngspice being present; it self-skips otherwise.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

fail = 0
npass = 0


def check(name, ok, detail=""):
    global fail, npass
    if ok:
        print("ok:   %s %s" % (name, detail)); npass += 1
    else:
        print("FAIL: %s %s" % (name, detail)); fail += 1


try:
    import ase_migrate as m
    HAVE = True
except Exception as e:                       # RED before the module exists
    HAVE = False
    print("import failed: %r" % (e,))

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))

# --------------------------------------------------------------------------- #
# 1. serializer byte-fidelity vs ase::state_serialize (the committed golden)
# --------------------------------------------------------------------------- #
if HAVE:
    golden = os.path.join(REPO, "gf180mcuD", "xschem_libs", "gf180mcu_tests",
                          "test_nfet_final", "ngspice_state1",
                          "test_nfet_final.state")
    st = {
        "version": "1",
        "simulator": "ngspice",
        "design": ["lib", "gf180mcu_tests", "cell", "test_nfet_final",
                   "view", "schematic"],
        "rundir": "",
        "temperature": "27",
        "models": [["file", "$::180MCU_MODELS/sm141064.ngspice",
                    "section", "typical"]],
        "variables": [["name", "Vgs", "value", "3.3"],
                      ["name", "Vds", "value", "1.65"]],
        "analyses": [["type", "op", "enabled", "1"],
                     ["type", "dc", "enabled", "0"],
                     ["type", "ac", "enabled", "0"],
                     ["type", "tran", "enabled", "0"]],
        "outputs": [["name", "id", "expr", "-i(v1)", "save", "1", "plot", "0"]],
        "save_all_v": "0",
        "save_all_i": "0",
        "options": [["name", "savecurrents", "value", "1"]],
        "includes": [["file", "$::180MCU_MODELS/design.ngspice"]],
        "pre_commands": [],
        "viewer": "",
    }
    got = m.serialize_state(st, m.SCHEMA_KEYS)
    if os.path.isfile(golden):
        with open(golden) as f:
            want = f.read()
        check("S1 serializer byte-identical to committed gf180 state",
              got == want, "" if got == want else "\n--- got ---\n%s\n--- want ---\n%s" % (got, want))
    else:
        check("S1 golden state present", False, "(missing %s)" % golden)

    # scalar/quoting spot checks
    check("S2 empty -> {}", m._tcl_conv("") == "{}")
    check("S3 dollar path braced",
          m._tcl_conv("$::X/y.z") == "{$::X/y.z}")
    check("S4 -i(v1) stays bare", m._tcl_conv("-i(v1)") == "-i(v1)")
    check("S5 spaced -> braced",
          m._tcl_conv("a b c") == "{a b c}")

    # S6: values that used to RAISE "out of domain" now convert like Tcl does.
    check("S6a trailing backslash escapes (was MigrationError)",
          m._tcl_conv("s0[255],s0[254],\\") == "s0\\[255\\],s0\\[254\\],\\\\",
          repr(m._tcl_conv("s0[255],s0[254],\\")))
    check("S6b interior backslash braces",
          m._tcl_conv("a\\b") == "{a\\b}", repr(m._tcl_conv("a\\b")))
    check("S6c unbalanced open brace escapes",
          m._tcl_conv("{1.8") == "\\{1.8", repr(m._tcl_conv("{1.8")))
    check("S6d misordered braces escape (count test was not enough)",
          m._tcl_conv("a}b{c") == "a\\}b\\{c", repr(m._tcl_conv("a}b{c")))
    check("S6e balanced braces stay bare",
          m._tcl_conv("a{b}c") == "a{b}c", repr(m._tcl_conv("a{b}c")))
    check("S6f windows path escapes",
          m._tcl_conv("C:\\models\\x.lib") == "{C:\\models\\x.lib}",
          repr(m._tcl_conv("C:\\models\\x.lib")))

    # S7: DIFFERENTIAL — every _tcl_conv result must equal Tcl's own [list $v],
    # for hand-picked pathological values plus a deterministic sweep. This is
    # the contract (byte-identical to ase::state_serialize); tclsh is the oracle.
    TCLSH = shutil.which("tclsh")
    if TCLSH:
        vals = ["", "plain", "a b", "a\\b", "a\\", "a\\\\", "{1.8", "a}b{c",
                "a{b}c", "a]b", 'x;y "q"', "v($vdd)[3]", "#lead", "a#c",
                "s0[255],s0[254],\\", "-i(v1)", "$::X/y.z", "a\tb", "a\nb",
                "C:\\models\\x.lib", "{", "}", "\\", '"', "a\\\nb", "[x]",
                "{a b}", '"quoted"', "\\{b}", "a{b\\}"]
        alpha = "ab{}[]$;\"\\ \t#,()01"
        seed = 12345                       # deterministic LCG, no RNG dependency
        for _ in range(600):
            seed = (1103515245 * seed + 12345) % (1 << 31)
            ln = 1 + (seed >> 16) % 6
            s = []
            for _k in range(ln):
                seed = (1103515245 * seed + 12345) % (1 << 31)
                s.append(alpha[(seed >> 16) % len(alpha)])
            vals.append("".join(s))
        # each line is hex of "\x01"+value, so the EMPTY value still has a line
        drv = ("foreach hx [split [string trim [read stdin]] \\n] {\n"
               "  set v [encoding convertfrom utf-8 [binary format H* $hx]]\n"
               "  set v [string range $v 1 end]\n"
               "  puts [binary encode hex [encoding convertto utf-8 [list $v]]]\n"
               "}\n")
        stdin = "\n".join(("\x01" + v).encode().hex() for v in vals) + "\n"
        # values travel as hex so no shell/Tcl quoting layer can distort them
        with tempfile.NamedTemporaryFile("w", suffix=".tcl", delete=False) as tf:
            tf.write(drv)
            drvpath = tf.name
        try:
            p = subprocess.run([TCLSH, drvpath], input=stdin, text=True,
                               capture_output=True)
            got = [bytes.fromhex(h).decode() for h in p.stdout.split()]
        finally:
            os.unlink(drvpath)
        if len(got) != len(vals):
            check("S7 tclsh differential ran", False,
                  "got %d/%d lines: %s" % (len(got), len(vals), p.stderr[:200]))
        else:
            bad = [(v, m._tcl_conv(v), w) for v, w in zip(vals, got)
                   if m._tcl_conv(v) != w]
            check("S7 _tcl_conv == Tcl [list $v] for %d values" % len(vals),
                  not bad, "" if not bad else "first 3 mismatches: %r" % bad[:3])
            # and the nested form the serializer actually emits
            nested = [["name", v, "value", "x"] for v in vals[:40]]
            with tempfile.NamedTemporaryFile("w", suffix=".tcl",
                                             delete=False) as tf:
                tf.write("foreach hx [split [string trim [read stdin]] \\n] {\n"
                         "  set v [encoding convertfrom utf-8 "
                         "[binary format H* $hx]]\n"
                         "  set v [string range $v 1 end]\n"
                         "  puts [binary encode hex [encoding convertto utf-8 "
                         "[list [list name $v value x]]]]\n}\n")
                drvpath = tf.name
            try:
                stdin2 = "\n".join(("\x01" + v).encode().hex()
                                   for v in vals[:40]) + "\n"
                p2 = subprocess.run([TCLSH, drvpath], input=stdin2, text=True,
                                    capture_output=True)
                got2 = [bytes.fromhex(h).decode() for h in p2.stdout.split()]
            finally:
                os.unlink(drvpath)
            badn = [(n, m._tcl_conv(m._struct_to_str(n)), w)
                    for n, w in zip(nested, got2)
                    if m._tcl_conv(m._struct_to_str(n)) != w]
            check("S8 nested list quoting == Tcl [list [list ...]]",
                  len(got2) == 40 and not badn,
                  "" if not badn else "first: %r" % (badn[:1],))
    else:
        print("skip: S7/S8 tclsh differential (no tclsh)")

    # S9: the leading-`#` rule applies to element 0 only, at every nesting level
    # (`list #a b` -> `{#a} b`; `list b #a` -> `b #a`), and the MASK form keeps
    # already-balanced braces while escaping `]`/`"`.
    check("S9a #-quoting at index 0 of a nested list",
          m._struct_to_str([["#a", "b"], "c"]) == "{{#a} b} c",
          repr(m._struct_to_str([["#a", "b"], "c"])))
    check("S9b # elsewhere is ordinary",
          m._struct_to_str(["b", "#a"]) == "b #a",
          repr(m._struct_to_str(["b", "#a"])))
    check("S9c MASK keeps balanced braces, escapes ] and \"",
          m._tcl_conv("a]b{c}d") == "a\\]b{c}d" and m._tcl_conv("a\"b") == "a\\\"b",
          repr(m._tcl_conv("a]b{c}d")))

# --------------------------------------------------------------------------- #
# 2. SpiceDeck: embedded gf180 models block + a control command block
# --------------------------------------------------------------------------- #
if HAVE:
    d = m.SpiceDeck()
    d.parse("""
* gf180 models
.include $::180MCU_MODELS/design.ngspice
.lib $::180MCU_MODELS/sm141064.ngspice typical
.options savecurrents
.control
  op
  print -i(v1)
  let foo = 3
.endc
""")
    check("D1 include extracted",
          d.includes == ["$::180MCU_MODELS/design.ngspice"], str(d.includes))
    check("D2 model extracted",
          d.models == [("$::180MCU_MODELS/sm141064.ngspice", "typical")], str(d.models))
    check("D3 option extracted",
          d.options == [("savecurrents", None)], str(d.options))
    check("D4 op analysis", d.analyses.get("op") == {"type": "op", "enabled": "1"})
    check("D5 output from print", ("-i(v1)", 0) in d.outputs, str(d.outputs))
    check("D6 unmappable let preserved in raw_control",
          any("let foo" in r for r in d.raw_control), str(d.raw_control))
    check("D7 let raised a warning", any("let" in w for w in d.warnings))

    # dc / ac / tran grammar
    d2 = m.SpiceDeck()
    d2.parse(".control\ndc V2 0 3.3 0.1\nac dec 10 1 1e9\ntran 1n 1u\n.endc\n")
    check("D8 dc parsed", d2.analyses["dc"] ==
          {"type": "dc", "enabled": "1", "source": "V2",
           "start": "0", "stop": "3.3", "step": "0.1"}, str(d2.analyses.get("dc")))
    check("D9 ac parsed", d2.analyses["ac"]["points"] == "10" and
          d2.analyses["ac"]["stop"] == "1e9")
    check("D10 tran parsed", d2.analyses["tran"] ==
          {"type": "tran", "enabled": "1", "step": "1n", "stop": "1u"})

# --------------------------------------------------------------------------- #
# 3. graph block -> plotted outputs (the `node=` trace mini-language, see
#    draw_graph() src/draw.c and doc/claude/issues/0167-*.md)
# --------------------------------------------------------------------------- #
if HAVE:
    # `alias;expr` is ONE trace: legend `i(vd)`, signal `v(out)`. (This check
    # used to assert both halves were signals — that was the wrong grammar.)
    gprops = "flags=graph\ny1=-1\ny2=1\nnode=\"i(vd); v(out)\"\ncolor=4"
    outs = m.graph_outputs(gprops)
    check("G1 alias;expr -> one output, alias is the label",
          outs == [("v(out)", 1, "i(vd)")], str(outs))

    # rows are newline-separated; `"` quotes a row; a trailing `\` is a
    # CONTINUATION, never a token (this is the value that used to abort the
    # whole sky130_tests library run)
    w = []
    outs = m.graph_outputs("flags=graph\nnode=\"S0;s0[2],s0[1],\\ s0[0]\ncin\"", w)
    check("G2 bus row expands to its bits, continuation absorbed",
          outs == [("s0[2]", 1, None), ("s0[1]", 1, None), ("s0[0]", 1, None),
                   ("cin", 1, None)], str(outs))
    check("G3 no token keeps a stray backslash",
          all("\\" not in o[0] for o in outs), str(outs))

    w = []
    outs = m.graph_outputs("flags=graph\nnode=\"x1.zminus x1.plus -\"", w)
    check("G4 RPN expression contributes its operands, loudly",
          outs == [("x1.zminus", 1, None), ("x1.plus", 1, None)]
          and any("operands" in x for x in w), "%s %s" % (outs, w))

    w = []
    outs = m.graph_outputs("flags=graph\nnode=\"TEMPERAT%0\"", w)
    check("G5 %dataset selector stripped + warned",
          outs == [("TEMPERAT", 1, None)] and any("%0" in x for x in w),
          "%s %s" % (outs, w))

    w = []
    outs = m.graph_outputs("flags=graph\nnode=tcleval(v(@#0:x))", w)
    check("G6 tcleval node not guessed at", outs == [] and len(w) == 1, str(w))

    # the real offender, end to end
    cl = os.path.join(REPO, "sky130A", "xschem_libs", "sky130_tests",
                      "test_carry_lookahead", "schematic",
                      "test_carry_lookahead.sch")
    if os.path.isfile(cl):
        with open(cl) as f:
            cmc = m.CellMigrator(f.read(), m.PDKS["sky130"], "sky130_tests",
                                 "test_carry_lookahead").migrate()
        txt = m.serialize_state(cmc.state, m.SCHEMA_KEYS)
        exprs = [o[3] for o in cmc.state["outputs"]]
        check("G7 test_carry_lookahead serializes (was MigrationError)",
              txt.startswith("version 1"))
        # 9 rows -> 1089 real bits (256 a + 256 b + 1 cin + 32 s2 + 32 s1
        # + 256 s3 + 256 s0) plus the placeholder signal `xxx` the two
        # "NN bit; xxx" header rows name (xschem would try to plot it too).
        check("G8 all 1089 bus bits recovered, no aliases/backslashes",
              len(exprs) == 1090 and "A" not in exprs and "S0" not in exprs
              and "xxx" in exprs and all("\\" not in e for e in exprs),
              "%d exprs" % len(exprs))
        check("G9 output names unique and identifier-shaped",
              len(set(o[1] for o in cmc.state["outputs"])) == len(exprs)
              and all(re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", o[1])
                      for o in cmc.state["outputs"]))
    else:
        print("skip: test_carry_lookahead fixture missing")

# --------------------------------------------------------------------------- #
# 4. classify
# --------------------------------------------------------------------------- #
if HAVE:
    CL = (
        "v {xschem version=3.4.7RC file_version=1.2}\n"
        "G {}\nK {}\nV {}\nS {}\nE {}\n"
        "N 420 -330 600 -330 {}\n"
        "C {gf180mcu_pr/nfet_03v3} 400 -300 0 0 {name=M1 L=0.28u W=1u}\n"
        "C {devices/vsource} 600 -300 0 0 {name=V1 value=1.65}\n"
        "C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}\n"
        "C {sky130_fd_pr/corner} 720 -420 0 0 {name=CORNER corner=tt}\n"
        "C {devices/simulator_commands_shown} 60 -600 0 0 "
        "{name=COMMANDS value=\"\n.control\nop\n.endc\n\"}\n"
        "C {devices/launcher} 185 -635 0 0 {name=h1 descr=x}\n"
        "B 2 580 -540 1170 -80 {flags=graph\nnode=i(vd)}\n"
    )
    recs = m.scan_records(CL)
    cats = [m.classify(r) for r in recs]
    check("C1 nfet is circuit", "circuit" in cats)
    check("C2 corner classified", cats.count("corner") == 1, str(cats))
    check("C3 code_shown is embedded", cats.count("embedded") == 1)
    check("C4 launcher dropped", cats.count("drop") == 1)
    check("C5 graph classified", cats.count("graph") == 1)
    check("C6 header rows kept", cats.count("header") == 6)   # v G K V S E

# --------------------------------------------------------------------------- #
# 5. CellMigrator end-to-end on an inline cluttered fixture (no xschem)
# --------------------------------------------------------------------------- #
if HAVE:
    cm = m.CellMigrator(CL, m.PDKS["sky130"], "mylib", "tb").migrate()
    clean = cm.clean_sch
    check("M1 clean sch keeps the nfet", "nfet_03v3" in clean)
    check("M2 clean sch keeps the vsource", "vsource" in clean)
    check("M3 clean sch drops corner", "corner" not in clean)
    check("M4 clean sch drops code_shown", "code_shown" not in clean)
    check("M5 clean sch drops launcher", "launcher" not in clean)
    check("M6 clean sch drops graph", "flags=graph" not in clean)
    check("M7 state has a model from corner tt",
          cm.state["models"] == [["file", "$::SKYWATER_MODELS/sky130.lib.spice",
                                   "section", "tt"]], str(cm.state["models"]))
    check("M8 state has op analysis enabled",
          cm.state["analyses"][0] == ["type", "op", "enabled", "1"])
    check("M9 state output from graph node",
          any(o[3] == "i(vd)" for o in cm.state["outputs"]), str(cm.state["outputs"]))
    # serialized state is loadable-shaped (round-trips through our own serializer)
    txt = m.serialize_state(cm.state, m.SCHEMA_KEYS)
    check("M10 serialized state nonempty + schema-ordered",
          txt.startswith("version 1\nsimulator ngspice\ndesign {lib mylib cell tb"))

# --------------------------------------------------------------------------- #
# 6. source hoisting (opt-in)
# --------------------------------------------------------------------------- #
if HAVE:
    cmh = m.CellMigrator(CL, m.PDKS["sky130"], "mylib", "tb",
                         hoist_sources=True).migrate()
    check("H1 vsource value hoisted to param",
          ["name", "V1", "value", "1.65"] in cmh.state["variables"],
          str(cmh.state["variables"]))
    check("H2 clean sch references the var, not the literal",
          "value=V1" in cmh.clean_sch and "value=1.65" not in cmh.clean_sch)

# --------------------------------------------------------------------------- #
# 6b. deck-parser robustness (values that used to be shredded or mis-mapped)
# --------------------------------------------------------------------------- #
if HAVE:
    d = m.SpiceDeck()
    d.parse(".param p={1.8 * 2} q=3\n"
            ".include \"/opt/my models/x.lib\"\n"
            ".temp TEMPVAR\n"
            ".opton wnflag=1\n"
            ".options save all\n"
            ".control\nprint del > result.txt\nplot clk+2 v(a) vs time\n.endc\n")
    check("P1 braced .param value kept whole (spaces and all)",
          ("p", "{1.8 * 2}") in d.params, str(d.params))
    check("P2 quoted include path kept whole",
          d.includes == ["/opt/my models/x.lib"], str(d.includes))
    check("P3 non-numeric .temp refused + warned",
          d.temperature is None and any(".temp" in w for w in d.warnings),
          str(d.temperature))
    check("P4 .opton not parsed as an .op analysis",
          "op" not in d.analyses, str(d.analyses))
    check("P5 `.options save all` -> blanket save_all_v",
          d.save_all_v and not any(n in ("save", "all") for n, _v in d.options),
          str(d.options))
    check("P6 shell redirect not an output",
          not any(e in (">", "result.txt") for e, _p in d.outputs),
          str(d.outputs))
    check("P7 plot display offset reduced to the signal",
          ("clk", 1) in d.outputs and ("clk+2", 1) not in d.outputs,
          str(d.outputs))
    check("P8 `vs <xvector>` clause not an output",
          not any(e in ("vs", "time") for e, _p in d.outputs), str(d.outputs))

    # duplicate names must not survive: result_probe keys results by name
    cmn = m.CellMigrator(CL, m.PDKS["sky130"], "l", "c")
    outs = cmn._outputs(m.SpiceDeck(), [("i(curr)", 1, None), ("i(curr)\"", 1, None),
                                        ("v(a)", 1, None), ("va", 1, None)])
    names = [o[1] for o in outs]
    check("P9 colliding output names disambiguated",
          len(set(names)) == len(names), str(names))

# --------------------------------------------------------------------------- #
# 6b2. probe-card grammar: `vs`/`title`/`xlimit` are display clauses on
#      plot/print ONLY — on `save` they are ordinary net names
# --------------------------------------------------------------------------- #
if HAVE:
    d = m.SpiceDeck()
    d.parse(".save vs vd vg\n.control\nsave vs\n"
            "plot v(a) vs time xlimit 0 1n title mytitle xlog\n"
            "plot i(@m1[id]) v(clk)+2\n.endc\n")
    got = [e for e, _p in d.outputs]
    check("P10 `vs` is a NET NAME on .save/save (not a display clause)",
          got.count("vs") == 2 and "vd" in got and "vg" in got, str(got))
    check("P11 plot display clauses dropped, loudly",
          "time" not in got and "mytitle" not in got and "xlimit" not in got
          and "xlog" not in got and "0" not in got
          and any("x-axis selector" in w for w in d.warnings), str(got))
    check("P12 i(@dev[param]) not touched at parse time",
          "i(@m1[id])" in got, str(got))
    check("P13 offset stripped from a parenthesised signal too",
          "v(clk)" in got and "v(clk)+2" not in got, str(got))

    # `i(@dev[param])` is not a vector; ngspice: "no such function as i"
    cmx = m.CellMigrator(CL, m.PDKS["sky130"], "l", "c")
    cmx.report = m.MigrationReport()
    outs = cmx._outputs(m.SpiceDeck(), [("i(@m1[id])", 1, None),
                                        ("@m1[id]", 1, None)])
    check("P14 i(@dev[param]) rewritten to @dev[param] and deduped",
          [o[3] for o in outs] == ["@m1[id]"]
          and any("not a vector" in w for w in cmx.report.warnings), str(outs))

    # option names may be hyphenated (Xyce `.options NONLIN-TRAN`)
    d = m.SpiceDeck()
    d.parse(".options NONLIN-TRAN MAXSTEP=200\n.include /opt/my models/x.lib\n")
    check("P15 hyphenated option kept", ("NONLIN-TRAN", None) in d.options,
          str(d.options))
    check("P16 unquoted include path with spaces kept whole",
          d.includes == ["/opt/my models/x.lib"], str(d.includes))

# --------------------------------------------------------------------------- #
# 6b3. graph rows: constants, empty fields, collapsed ';', quoting
# --------------------------------------------------------------------------- #
if HAVE:
    w = []
    check("G10 reference-line constant is not a signal",
          m.graph_outputs("node=\"-; 0.9\"", w) == []
          and any("reference-line" in x for x in w), str(w))
    w = []
    check("G11 `a;;b` collapses like find_nth does",
          m.graph_outputs("node=\"a;;b\"", w) == [("b", 1, "a")], str(w))
    w = []
    check("G12 empty expression row reported, not silently dropped",
          m.graph_outputs("node=\"v(a);\"", w) == []
          and any("no expression" in x for x in w), str(w))
    check("G13 bus with an empty label keeps every bit",
          m.graph_outputs("node=\";a,b\"") == [("a", 1, None), ("b", 1, None)],
          str(m.graph_outputs("node=\";a,b\"")))
    # `\"` inside a row: the escape is consumed by _graph_rows, the quote is data
    check("G14 escaped quote inside a row does not split it",
          len(m._graph_rows('a\\"b\nc')) == 2, str(m._graph_rows('a\\"b\nc')))
    # a bus alias must never become an output name (M33)
    outs = m.graph_outputs("node=\"CIN;cin\"")
    cmn = m.CellMigrator(CL, m.PDKS["sky130"], "l", "c")
    cmn.report = m.MigrationReport()
    st = cmn._outputs(m.SpiceDeck(), outs)
    check("G15 graph alias becomes the output NAME, not a signal",
          st == [["name", "CIN", "expr", "cin", "save", "1", "plot", "1"]],
          str(st))
    # an alias that would need a _2 suffix loses to the expr-derived name
    st = cmn._outputs(m.SpiceDeck(), [("vth2", 1, None), ("f2", 1, "vth2")])
    check("G16 colliding alias yields to the expr-derived name",
          [o[1] for o in st] == ["vth2", "f2"], str(st))

# --------------------------------------------------------------------------- #
# 6b4. output names: identifier shape, uniqueness, discriminating tail
# --------------------------------------------------------------------------- #
if HAVE:
    long3 = ["@m.xm11.xsky130_fd_pr__pfet_g5v0d16v0.msky130_fd_pr__pfet_base[%s]"
             % p for p in ("gm", "id", "vth")]
    names = [m._mk_name(e, i) for i, e in enumerate(long3, 1)]
    check("N1 over-long names keep their discriminating tail",
          len(set(names)) == 3 and names[0].endswith("gm")
          and names[2].endswith("vth"), str(names))
    check("N2 names are capped", all(len(n) <= m._NAME_MAX for n in names))
    used = set()
    check("N3 leading digit gets a letter prefix",
          m._mk_name("0.9", 1, used) == "o09", m._mk_name("0.9", 2, set()))
    check("N4 duplicates get a stable suffix",
          [m._mk_name("v(a)", 1, used), m._mk_name("va", 2, used)] == ["va", "va_2"])

# --------------------------------------------------------------------------- #
# 6c. library walk: one bad cell must not abort the rest; dry-run must serialize
# --------------------------------------------------------------------------- #
if HAVE:
    tmp = tempfile.mkdtemp(prefix="ase_mig_lib_")
    try:
        for cell, sch in (("good", CL), ("bad", CL)):
            d = os.path.join(tmp, "lib", cell, "schematic")
            os.makedirs(d)
            with open(os.path.join(d, cell + ".sch"), "w") as f:
                f.write(sch)
        lm = m.LibraryMigrator(os.path.join(tmp, "lib"), m.PDKS["sky130"]).scan()
        boom = [cm for name, cm in lm.cells if name == "bad"][0]
        boom.migrate = lambda: (_ for _ in ()).throw(m.MigrationError("boom"))
        res = lm.migrate_all(os.path.join(tmp, "out"))
        check("L1 good cell migrated despite the bad one",
              [c for c, _r in res] == ["good"], str([c for c, _r in res]))
        check("L2 bad cell recorded, not raised",
              len(lm.failed) == 1 and "boom" in lm.failed[0][1], str(lm.failed))
        check("L3 good cell wrote BOTH views",
              os.path.isfile(os.path.join(tmp, "out", "good", "schematic",
                                          "good.sch"))
              and os.path.isfile(os.path.join(tmp, "out", "good",
                                              "ngspice_state1", "good.state")))
        # dry-run: serializes (so it catches serializer errors) but writes nothing
        lm2 = m.LibraryMigrator(os.path.join(tmp, "lib"), m.PDKS["sky130"]).scan()
        lm2.migrate_all(os.path.join(tmp, "dry"), dry_run=True)
        check("L4 dry-run writes nothing", not os.path.exists(os.path.join(tmp, "dry")))
        # the state's design= must name the DESTINATION library — ASE resolves
        # lib/cell/view from the registry, so the SOURCE name would send
        # Session > Design Window back to the cluttered original
        cmg = [cm for name, cm in lm.cells if name == "good"][0]
        check("L6 design= names the destination library",
              cmg.state["design"] == ["lib", "out", "cell", "good",
                                      "view", "schematic"],
              str(cmg.state["design"]))
        lmx = m.LibraryMigrator(os.path.join(tmp, "lib"), m.PDKS["sky130"],
                                libname="mylib").scan()
        lmx.migrate_all(os.path.join(tmp, "out2"), dry_run=True)
        check("L7 an explicit --lib still wins",
              lmx.cells[0][1].state["design"][1] == "mylib",
              str(lmx.cells[0][1].state["design"]))
        # ...but it must still SERIALIZE, or a dry run is a false all-clear
        cmd = [cm for name, cm in lm2.cells if name == "good"][0]
        real = m.serialize_state
        m.serialize_state = lambda *a, **k: (_ for _ in ()).throw(
            m.MigrationError("serializer reached"))
        try:
            hit = False
            try:
                cmd.write(os.path.join(tmp, "dry2"), dry_run=True)
            except m.MigrationError as e:
                hit = "serializer reached" in str(e)
        finally:
            m.serialize_state = real
        check("L5 dry-run still exercises the serializer", hit)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

# --------------------------------------------------------------------------- #
# 6d. the migrated tree must not point back at the SOURCE library
# --------------------------------------------------------------------------- #
# c31fad1d fixed the state's `design {lib …}`; the schematic kept every
# `C {<srclib>/<cell>}` symref, so a migrated bench still netlisted the
# CLUTTERED sibling one level down (19 of the 48 sky130 cells; tb_bandgap pulled
# in sky130_tests/bandgap). A sibling that is NOT migrated must keep naming the
# source library — it has no _ase counterpart.
if HAVE:
    tmp = tempfile.mkdtemp(prefix="ase_mig_rebind_")
    try:
        parent = (CL
                  + "C {lib/kid} 10 10 0 0 {name=x1}\n"
                  + "C {lib/plain} 20 20 0 0 {name=x2}\n")
        for cell, sch in (("parent", parent), ("kid", CL)):
            d = os.path.join(tmp, "lib", cell, "schematic")
            os.makedirs(d)
            with open(os.path.join(d, cell + ".sch"), "w") as f:
                f.write(sch)
            sd = os.path.join(tmp, "lib", cell, "symbol")   # symbol view to copy
            os.makedirs(sd)
            with open(os.path.join(sd, cell + ".sym"), "w") as f:
                f.write("v {xschem version=3.4.7 file_version=1.2}\n"
                        "K {type=subcircuit}\n"
                        "C {lib/kid} 0 0 0 0 {name=s1}\n")
        # `plain` is a clutter-free cell: present in the source library, never
        # migrated, so a reference to it must NOT be rewritten
        d = os.path.join(tmp, "lib", "plain", "schematic")
        os.makedirs(d)
        with open(os.path.join(d, "plain.sch"), "w") as f:
            f.write("v {xschem version=3.4.7 file_version=1.2}\n")
        lm = m.LibraryMigrator(os.path.join(tmp, "lib"), m.PDKS["sky130"]).scan()
        lm.migrate_all(os.path.join(tmp, "lib_ase"))
        got = open(os.path.join(tmp, "lib_ase", "parent", "schematic",
                                "parent.sch")).read()
        check("L8 sibling symref rebound to the destination library",
              "C {lib_ase/kid}" in got and "C {lib/kid}" not in got)
        check("L9 a NON-migrated sibling still names the source library",
              "C {lib/plain}" in got and "lib_ase/plain" not in got)
        symp = os.path.join(tmp, "lib_ase", "parent", "symbol", "parent.sym")
        check("L10 symbol view copied to the destination", os.path.isfile(symp))
        check("L11 symbol view rebound too",
              os.path.isfile(symp) and "C {lib_ase/kid}" in open(symp).read())
        tag = os.path.join(tmp, "lib_ase", "library.tag")
        check("L12 library.tag names the destination library",
              os.path.isfile(tag) and open(tag).read().strip() == "NAME lib_ase",
              open(tag).read().strip() if os.path.isfile(tag) else "missing")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

# --------------------------------------------------------------------------- #
# 6e. sg13g2 profile: pre_* preserved, dead include dropped, sp not faked as op
# --------------------------------------------------------------------------- #
if HAVE:
    check("Q1 sg13g2 is a selectable PDK profile", "sg13g2" in m.PDKS)
    d = m.SpiceDeck()
    d.parse(".control\n"
            "pre_osdi $::SG13G2_OSDI/psp103.osdi\n"
            "pre_set auto_bridge_d_out =\n"
            "+ ( \".model auto_dac dac_bridge()\" )\n"
            "op\n"
            "print {$scratch}.vg\n"
            "print v(d)\n"
            ".endc\n"
            ".lib $::MODELS_NGSPICE/cornerMOSlv.lib mos_tt\n")
    check("Q2 pre_osdi carried into the state, not the report bin",
          d.pre_commands[:1] == ["pre_osdi $::SG13G2_OSDI/psp103.osdi"],
          str(d.pre_commands))
    check("Q3 a `+` continuation is folded onto its card",
          len(d.pre_commands) == 2 and "dac_bridge()" in d.pre_commands[1],
          str(d.pre_commands))
    check("Q4 a control-shell $var is not migrated as a saveable vector",
          [o[0] for o in d.outputs] == ["v(d)"], str(d.outputs))
    check("Q5 ...and it is reported, not silently dropped",
          any("control-shell variable" in w for w in d.warnings), str(d.warnings))
    check("Q6 sg13g2 .lib card still maps to a model entry",
          d.models == [("$::MODELS_NGSPICE/cornerMOSlv.lib", "mos_tt")], str(d.models))
    # an unresolvable relative include (generated by a dropped launcher) must go,
    # or ngspice aborts the whole deck before any analysis
    tmp = tempfile.mkdtemp(prefix="ase_mig_inc_")
    try:
        d2 = m.SpiceDeck()
        d2.parse(".include nosuch.save\n.include $::MODELS_NGSPICE/real.lib\n")
        cm = m.CellMigrator(CL, m.PDKS["sg13g2"], "L", "c", srcdir=tmp)
        cm.migrate()
        keep = cm._includes(d2)
        check("Q7 dangling relative include dropped, portable one kept",
              keep == ["$::MODELS_NGSPICE/real.lib"], str(keep))
        check("Q8 dropping a .save include turns on save_all_i instead",
              d2.save_all_i is True)
        check("Q9 ...and both are reported",
              sum("include target does not exist" in w or "save_all_i enabled" in w
                  for w in cm.report.warnings) == 2, str(cm.report.warnings))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    # `sp` has no ASE equivalent: leaving `op` enabled would run a healthy-looking
    # DIFFERENT simulation (the four sp_* IHP benches)
    d3 = m.SpiceDeck()
    d3.parse(".control\nsp lin 500 1e9 100e9 0\n.endc\n")
    cm3 = m.CellMigrator(CL, m.PDKS["sg13g2"], "L", "c")
    cm3.migrate()
    an = cm3._analyses(d3)
    check("Q10 an unmappable analysis does not fall back to a fabricated op",
          all(a[3] == "0" for a in an), str(an))
    check("Q11 ...and says so", any("no analysis migrated" in w
                                    for w in cm3.report.warnings),
          str(cm3.report.warnings))

# --------------------------------------------------------------------------- #
# 7. INTEGRATION — migrate the real gf180 before-cell, verify Id (gated)
# --------------------------------------------------------------------------- #
XS = os.path.join(REPO, "src", "xschem")
if HAVE and os.path.isfile(XS) and shutil.which("ngspice"):
    before = os.path.join(REPO, "gf180mcuD", "xschem_libs", "gf180mcu_tests",
                          "nfet_test_claude", "schematic", "nfet_test_claude.sch")
    if os.path.isfile(before):
        tmp = tempfile.mkdtemp(prefix="ase_mig_", dir=os.path.join(REPO, "gf180mcuD"))
        try:
            with open(before) as _bf:
                before_text = _bf.read()
            cm = m.CellMigrator(before_text, m.PDKS["gf180"], "gf180mcu_tests",
                                "nfet_test_claude").migrate()
            out_cellroot = os.path.join(tmp, "nfet_test_claude")
            cm.write(out_cellroot)
            # migrated clean sch must be clutter-free
            check("I1 migrated clean sch has no .control",
                  ".control" not in cm.clean_sch)
            check("I2 migrated clean sch has no .lib / code_shown",
                  ".lib" not in cm.clean_sch and "code_shown" not in cm.clean_sch)
            check("I3 migrated state includes design.ngspice",
                  cm.state["includes"] == [["file", "$::180MCU_MODELS/design.ngspice"]],
                  str(cm.state["includes"]))
            check("I4 migrated state model is sm141064 typical",
                  cm.state["models"] == [["file", "$::180MCU_MODELS/sm141064.ngspice",
                                          "section", "typical"]], str(cm.state["models"]))
            idb, ida, ok = m.verify(
                REPO, m.PDKS["gf180"], "gf180mcu_tests", "nfet_test_claude",
                before, tmp, os.path.join(REPO, "gf180mcuD", "models"),
                xschem=XS)
            check("I5 cluttered cell simulated (Id_before)", bool(idb), "Id_before=%s" % idb)
            check("I6 migrated cell simulated (Id_after)", bool(ida), "Id_after=%s" % ida)
            check("I7 before == after within 1 uA", ok is True,
                  "before=%s after=%s" % (idb, ida))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    else:
        print("skip: gf180 nfet_test_claude fixture missing")
else:
    print("skip: integration leg (need ./src/xschem + ngspice)")

# --------------------------------------------------------------------------- #
if fail == 0:
    print("RESULT: ALL PASS (%d checks)" % npass)
else:
    print("RESULT: %d FAILED (%d passed)" % (fail, npass))
sys.exit(1 if fail else 0)
