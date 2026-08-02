#!/bin/sh
# Launch the xschem PDK launcher GUI.
#   ./pdk_launcher.sh
# Pick a PDK workarea (sky130A / gf180mcuD / ihp-sg13g2 / none), a log directory
# and an optional schematic, then press Launch. See tools/launcher/pdk_launcher.tcl.
here=$(cd "$(dirname "$0")" && pwd)

if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
  echo "pdk_launcher: no DISPLAY — this is a GUI. Use src/xschem --script <pdk>/cadence_style_rc instead." >&2
  exit 1
fi

for w in wish wish8.6 wish8.5; do
  if command -v "$w" >/dev/null 2>&1; then
    exec "$w" "$here/tools/launcher/pdk_launcher.tcl" "$@"
  fi
done

echo "pdk_launcher: no 'wish' on PATH (install tk)." >&2
exit 1
