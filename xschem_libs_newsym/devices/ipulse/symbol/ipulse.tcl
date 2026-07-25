# ipulse.tcl — field customization for the devices/ipulse cell, consumed by the
# GENERIC Edit-Properties form (slickprop). The symbol declares `edit_form=ipulse`;
# slickprop::build_fields lazily sources this file (next to ipulse.sym). The field
# set is FIXED (a plain PULSE source), so no custom widget is needed — this only
# gives the ngspice PULSE parameters friendly labels. Everything else (Apply-to,
# Library/Cell/View, Name, and the fields themselves) is the standard generic
# form. See doc/claude/specs/cell_custom_form.md.
#
# ngspice PULSE(V1 V2 TD TR TF PW PER): V1 initial, V2 pulsed, TD delay, TR rise,
# TF fall, PW width, PER period. DC is the operating-point / DC-analysis value.

namespace eval ipulse {}

proc ipulse::field_labels {} {
  return {
    DC     {DC Voltage}
    Vinit  {Initial Value (V1)}
    Vpulse {Pulsed Value (V2)}
    TD     {Delay Time (TD)}
    TR     {Rise Time (TR)}
    TF     {Fall Time (TF)}
    PW     {Pulse Width (PW)}
    PER    {Period (PER)}
  }
}
