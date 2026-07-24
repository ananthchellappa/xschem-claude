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
import shutil
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
# 3. graph block -> plotted outputs
# --------------------------------------------------------------------------- #
if HAVE:
    gprops = "flags=graph\ny1=-1\ny2=1\nnode=\"i(vd); v(out)\"\ncolor=4"
    outs = m.graph_outputs(gprops)
    check("G1 graph nodes recovered",
          outs == [("i(vd)", 1), ("v(out)", 1)], str(outs))

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
