source [file dirname [info script]]/../../src/action_registry.tcl

set err_count 0

proc assert_seq {accel expected} {
    global err_count
    set actual [accel_to_tk_sequence $accel]
    if {$actual ne $expected} {
        puts "FAIL: '$accel' -> expected '$expected', got '$actual'"
        incr err_count
    } else {
        puts "PASS: '$accel' -> '$actual'"
    }
}

# Alpha cases
assert_seq "u" "<Key-u>"
assert_seq "U" "<Key-u>"
assert_seq "Shift+U" "<Shift-Key-U>"
assert_seq "Ctrl+U" "<Control-Key-u>"
assert_seq "Ctrl+Shift+U" "<Control-Shift-Key-U>"
assert_seq "Alt+u" "<Alt-Key-u>"

# Digit cases
assert_seq "1" "<Key-1>"
assert_seq "Shift+1" "<Shift-Key-1>"
assert_seq "Ctrl+2" "<Control-Key-2>"

# Symbol keys
assert_seq "#" "<Key-numbersign>"
assert_seq "=" "<Key-equal>"
assert_seq "*" "<Key-asterisk>"
assert_seq "&" "<Key-ampersand>"
assert_seq "!" "<Key-exclam>"
assert_seq "@" "<Key-at>"
assert_seq "^" "<Key-asciicircum>"
assert_seq "~" "<Key-asciitilde>"
assert_seq "|" "<Key-bar>"
assert_seq "\\" "<Key-backslash>"
assert_seq ">" "<Key-greater>"
assert_seq "<" "<Key-less>"
assert_seq "?" "<Key-question>"
assert_seq "Shift+?" "<Shift-Key-question>"
assert_seq "Ctrl+*" "<Control-Key-asterisk>"

# Named keys
assert_seq "Del" "<Key-Delete>"
assert_seq "Ins" "<Key-Insert>"
assert_seq "Esc" "<Key-Escape>"
assert_seq "Tab" "<Key-Tab>"
assert_seq "Return" "<Key-Return>"
assert_seq "BackSpace" "<Key-BackSpace>"
assert_seq "Space" "<Key-space>"
assert_seq "Shift+Space" "<Shift-Key-space>"

# Function keys
assert_seq "F1" "<Key-F1>"
assert_seq "F12" "<Key-F12>"
assert_seq "Ctrl+F5" "<Control-Key-F5>"

# Navigation keys
assert_seq "Up" "<Key-Up>"
assert_seq "Down" "<Key-Down>"
assert_seq "Left" "<Key-Left>"
assert_seq "Right" "<Key-Right>"
assert_seq "Home" "<Key-Home>"
assert_seq "End" "<Key-End>"
assert_seq "PgUp" "<Key-Prior>"
assert_seq "PgDn" "<Key-Next>"

if {$err_count > 0} {
    puts "$err_count test(s) failed."
    exit 1
} else {
    puts "All tests passed."
    exit 0
}
