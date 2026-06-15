#!/usr/bin/env python3
"""Phase 5 (library-manager) — tests for the flat -> lib/cell/view migrator.

Dependency-free (stdlib only), self-reporting like the headless tcl suites:
prints "ok:"/"FAIL:" per check and "RESULT: ALL PASS" / "RESULT: N FAILED",
exits non-zero on failure. Run:  python3 tools/migrate/test_libmigrate.py
"""
import os, sys, tempfile, shutil

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

fail = 0
def check(name, ok, detail=""):
    global fail
    if ok: print("ok:   %s %s" % (name, detail))
    else:  print("FAIL: %s %s" % (name, detail)); fail += 1

try:
    import xschem_libmigrate as m
    HAVE = True
except Exception as e:                       # RED: module not written yet
    HAVE = False
    print("import failed: %r" % (e,))

def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f: f.write(text)

def r(path):
    with open(path) as f: return f.read()

# --- fixture: two flat libraries (devices, mylib); mylib/amp references devices
tmp = tempfile.mkdtemp(prefix="libmig_")
dev = os.path.join(tmp, "devices")
myl = os.path.join(tmp, "mylib")
for cell in ("res", "nmos4", "lab_pin"):
    w(os.path.join(dev, cell + ".sym"),
      "v {xschem version=3.4.0 file_version=1.3}\nK {type=res}\n")
w(os.path.join(myl, "amp.sym"),
  "v {xschem version=3.4.0 file_version=1.3}\nK {type=subcircuit}\n")
AMP_SCH = (
  "v {xschem version=3.4.0 file_version=1.3}\n"
  "C {nmos4.sym} 0 0 0 0 {name=M1}\n"
  "C {res.sym} 100 0 0 0 {name=R1}\n"
  "C {lab_pin.sym} 0 100 0 0 {name=l1 lab=A}\n"
  "C {devices/res.sym} 200 0 0 0 {name=R2}\n"
  "C {gen.tcl(@x)} 300 0 0 0 {name=g1}\n"
  "C {amp.sym} 0 200 0 0 {name=xself schematic=res.sch}\n"
  "N 0 0 10 0 {}\n"
)
w(os.path.join(myl, "amp.sch"), AMP_SCH)

LIBS = [("devices", dev), ("mylib", myl)]

if HAVE:
    idx = m.build_index(LIBS)

    # --- RW: reference rewriting -------------------------------------------
    def rw(ref): return m.rewrite_reference(ref, idx)
    check("RW1 bare cell -> first lib", HAVE and rw("nmos4.sym") == "devices/nmos4", "(=> %s)" % rw("nmos4.sym"))
    check("RW2 bare cell in mylib",     rw("amp.sym") == "mylib/amp", "(=> %s)" % rw("amp.sym"))
    check("RW3 qualified -> drop .sym", rw("devices/res.sym") == "devices/res", "(=> %s)" % rw("devices/res.sym"))
    check("RW4 already-qualified idempotent", rw("devices/res") == "devices/res", "(=> %s)" % rw("devices/res"))
    check("RW5 generator untouched",    rw("gen.tcl(@x)") == "gen.tcl(@x)", "(=> %s)" % rw("gen.tcl(@x)"))
    check("RW6 absolute path untouched", rw("/abs/x.sym") == "/abs/x.sym", "(=> %s)" % rw("/abs/x.sym"))
    check("RW7 unknown cell untouched", rw("nosuch.sym") == "nosuch.sym", "(=> %s)" % rw("nosuch.sym"))

    # --- RT: whole-text rewriting (C {} refs + schematic= attr) -------------
    out = m.rewrite_text(AMP_SCH, idx)
    check("RT1 C-ref bare rewritten",   "C {devices/nmos4} " in out, "")
    check("RT2 C-ref qualified rewritten", "C {devices/res} 200" in out, "")
    check("RT3 legacy lab_pin rewritten", "C {devices/lab_pin} " in out, "")
    check("RT4 generator ref preserved", "C {gen.tcl(@x)} " in out, "")
    check("RT5 schematic= attr rewritten", "schematic=mylib/res" not in out and "schematic=devices/res}" in out,
          "(schematic= -> devices/res)")
    check("RT6 wire line untouched",     "N 0 0 10 0 {}" in out, "")
    check("RT7 rewrite is idempotent",   m.rewrite_text(out, idx) == out, "")

    # --- MIG: end-to-end migration to a fresh dst tree ---------------------
    dst = os.path.join(tmp, "out")
    report = m.migrate(LIBS, dst, dry_run=False)
    check("MIG1 symbol moved to view dir",  os.path.isfile(os.path.join(dst, "devices/res/symbol/res.sym")), "")
    check("MIG2 schematic moved to view dir", os.path.isfile(os.path.join(dst, "mylib/amp/schematic/amp.sch")), "")
    check("MIG3 symbol view for amp",       os.path.isfile(os.path.join(dst, "mylib/amp/symbol/amp.sym")), "")
    check("MIG4 library.tag NAME written",  os.path.isfile(os.path.join(dst, "devices/library.tag")) and
          "NAME devices" in r(os.path.join(dst, "devices/library.tag")), "")
    defsf = os.path.join(dst, "library.defs")
    check("MIG5 library.defs has DEFINEs",  os.path.isfile(defsf) and
          "DEFINE devices" in r(defsf) and "DEFINE mylib" in r(defsf), "")
    migamp = r(os.path.join(dst, "mylib/amp/schematic/amp.sch"))
    check("MIG6 migrated file refs rewritten", "C {devices/nmos4} " in migamp and "C {devices/res} 100" in migamp, "")
    check("MIG7 source tree untouched",     os.path.isfile(os.path.join(myl, "amp.sch")) and
          r(os.path.join(myl, "amp.sch")) == AMP_SCH, "")

    # --- DRY: --dry-run writes nothing ------------------------------------
    dst2 = os.path.join(tmp, "out_dry")
    m.migrate(LIBS, dst2, dry_run=True)
    check("DRY1 dry-run writes no files", not os.path.exists(dst2) or not os.listdir(dst2), "")

shutil.rmtree(tmp, ignore_errors=True)
if not HAVE:
    # ensure a clear RED when the module is missing
    for n in range(1, 8): check("RW%d (module missing)" % n, False, "")

print("RESULT: ALL PASS" if fail == 0 else "RESULT: %d FAILED" % fail)
sys.exit(0 if fail == 0 else 1)
