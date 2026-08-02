#!/bin/bash
# build_ihp_sg13g2.sh — regenerate the in-repo ihp-sg13g2/ Cadence-style workarea
# from the read-only IHP-Open-PDK source tree.
#
#   tools/migrate/build_ihp_sg13g2.sh [PDK_SRC]
#
# PDK_SRC defaults to /home/qflow/dev/IHP-Open-PDK/ihp-sg13g2/libs.tech
#
# Non-destructive w.r.t. the PDK: sources are staged into a scratch dir first and
# only the staged copies are edited. Re-running replaces ihp-sg13g2/xschem_libs
# and ihp-sg13g2/models; the hand-written files (cadence_style_rc,
# sg13g2_procs.tcl, run.sh, README.md) are NEVER touched.
#
# See doc/claude/specs/ihp_sg13g2_workarea.md.
set -euo pipefail

SRC=${1:-/home/qflow/dev/IHP-Open-PDK/ihp-sg13g2/libs.tech}
REPO=$(cd "$(dirname "$0")/../.." && pwd)
WS=$REPO/ihp-sg13g2
XSCHEM_SRC=$SRC/xschem

[ -d "$XSCHEM_SRC" ] || { echo "no such PDK xschem dir: $XSCHEM_SRC" >&2; exit 1; }

STAGE=$(mktemp -d -t ihp_sg13g2_stage.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
echo "staging in $STAGE"

# ---------------------------------------------------------------------------
# 1. Stage the three libraries we migrate.
#
#    sg13g2_tests_xyce is deliberately NOT migrated: it is a cell-for-cell
#    duplicate of sg13g2_tests retargeted at the Xyce backend, and this workarea
#    is ngspice-only. Migrating it would put two cells of the same name in the
#    registry for no gain.
# ---------------------------------------------------------------------------
for lib in sg13g2_pr sg13g2_stdcells sg13g2_tests; do
  mkdir -p "$STAGE/$lib"
  cp -a "$XSCHEM_SRC/$lib/." "$STAGE/$lib/"
done

# ---------------------------------------------------------------------------
# 2. Namespace the PDK helper procs.
#
#    The PDK symbols call bare proc names (drc="fet_drc ...",
#    tcleval([display_fet_params @ref]), [save_params]). Those names are far too
#    generic to inject into the shared interpreter of a multi-PDK workarea — the
#    sky130 workarea hit the same thing and prefixed its own. Rename the CALLS in
#    the staged sources; sg13g2_procs.tcl defines the prefixed names to match.
#    \b anchors keep an already-prefixed name from being prefixed twice.
# ---------------------------------------------------------------------------
for p in fet_drc res_drc mim_drc hbt_drc diode_drc svaricap_drc \
         save_params display_fet_params display_bip_params; do
  find "$STAGE" -type f \( -name '*.sym' -o -name '*.sch' \) -print0 \
    | xargs -0 sed -i -E "s/\b(sg13g2_)?${p}\b/sg13g2_${p}/g"
done

# ---------------------------------------------------------------------------
# 3. flat -> lib/cell/view, rewriting refs to the lib-qualified form.
#
#    `devices` is listed FIRST and INDEX-ONLY: its flat source is used purely to
#    enumerate cell names so that bare refs (lab_pin.sym, launcher.sym, ...) and
#    slashed refs (devices/code_shown.sym) resolve to `devices/<cell>`. Its
#    emitted directory is discarded in step 5 — the registry points at the repo's
#    already-migrated newsym devices instead.
# ---------------------------------------------------------------------------
rm -rf "$WS/xschem_libs"
python3 "$REPO/tools/migrate/xschem_libmigrate.py" --dst "$WS/xschem_libs" \
  --lib devices="$REPO/xschem_library/devices" \
  --lib sg13g2_pr="$STAGE/sg13g2_pr" \
  --lib sg13g2_stdcells="$STAGE/sg13g2_stdcells" \
  --lib sg13g2_tests="$STAGE/sg13g2_tests"

# ---------------------------------------------------------------------------
# 4. Cadence-style pin-owned name tokens. Netlist-invariant.
# ---------------------------------------------------------------------------
for lib in sg13g2_pr sg13g2_stdcells sg13g2_tests; do
  python3 "$REPO/tools/migrate/migrate_pin_names.py" -r --no-backup "$WS/xschem_libs/$lib"
done

# ---------------------------------------------------------------------------
# 5. Curated registry: drop the index-only devices copy, point devices + the five
#    general libs at the repo's newsym tree (repo-relative, so the workarea stays
#    portable as long as it lives inside the repo).
# ---------------------------------------------------------------------------
rm -rf "$WS/xschem_libs/devices"
cat > "$WS/xschem_libs/library.defs" <<'DEFS'
# ihp-sg13g2 workarea registry (cds.lib analog).
# Paths are relative to THIS file. The five general libs + devices are shared
# with the rest of the repo rather than duplicated here.
DEFINE devices ../../xschem_libs_newsym/devices
DEFINE analyses ../../xschem_libs_newsym/analyses
DEFINE examples ../../xschem_libs_newsym/examples
DEFINE ngspice ../../xschem_libs_newsym/ngspice
DEFINE ngspice_verilog_cosim ../../xschem_libs_newsym/ngspice_verilog_cosim
DEFINE xschem_simulator ../../xschem_libs_newsym/xschem_simulator
DEFINE sg13g2_pr sg13g2_pr
DEFINE sg13g2_stdcells sg13g2_stdcells
DEFINE sg13g2_tests sg13g2_tests
DEFS

# ---------------------------------------------------------------------------
# 6. Models: vendored verbatim. Every .lib includes its siblings by BARE name,
#    so the directory is self-contained and needs no transitive-closure trim
#    (unlike sky130, whose corners reach up into libs.ref by relative path).
#
#    The PDK's own .spiceinit is deliberately NOT vendored: it adds
#    $PDK_ROOT/$PDK/... to ngspice's sourcepath and loads OSDI modules from an
#    osdi/ directory that does not exist in this checkout. Step 7 removes the
#    dependency on it instead.
# ---------------------------------------------------------------------------
rm -rf "$WS/models"
mkdir -p "$WS/models"
cp -a "$SRC/ngspice/models/." "$WS/models/"

# ---------------------------------------------------------------------------
# 7. Make model references self-resolving: bare `.lib cornerMOSlv.lib mos_tt`
#    -> `.lib $::MODELS_NGSPICE/cornerMOSlv.lib mos_tt`. Without this, 27 of the
#    42 model-bearing benches netlist fine and then fail to simulate unless
#    ngspice happens to run with the models dir on its sourcepath. See the
#    script's docstring for why `.include <cell>.save` must stay bare.
# ---------------------------------------------------------------------------
python3 "$REPO/tools/migrate/ihp_model_paths.py" "$WS/models" \
  "$WS/xschem_libs/sg13g2_tests" "$WS/xschem_libs/sg13g2_pr" "$WS/xschem_libs/sg13g2_stdcells"

echo
echo "libraries:  $(ls -d "$WS"/xschem_libs/*/ | wc -l) migrated + 6 registered from newsym"
echo "models:     $(ls "$WS"/models | wc -l) files, $(du -sh "$WS/models" | cut -f1)"
echo "workarea:   $(du -sh "$WS" | cut -f1)"
echo "done -> $WS"
