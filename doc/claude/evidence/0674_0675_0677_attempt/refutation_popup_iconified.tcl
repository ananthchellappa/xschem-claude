after 300
catch {ciw_create}
update idletasks
set tp [xschem get top_path]
# tear down the two arms the fix DID close, leaving only the popup
catch {destroy .ciw.l}
catch {destroy $tp.statusbar.12}
set ::notify_style popup
update idletasks
# notice 1: creates and maps the popup
set r1 [::xschem::notify {popup notice one} -tag error -short p1]
update idletasks
puts "POPUP-EXISTS=[winfo exists .xschem_notify] MAPPED=[winfo ismapped .xschem_notify] STATE=[wm state .xschem_notify]"
# ONE ORDINARY CLICK: iconify the popup
wm iconify .xschem_notify
update idletasks
after 300
update idletasks
puts "AFTER-ICONIFY: exists=[winfo exists .xschem_notify] mapped=[winfo ismapped .xschem_notify] state=[wm state .xschem_notify]"
puts "degraded=[::xschem::notify_channel_degraded]"
puts "reach=[::xschem::notify_reach_line]"
set r2 [::xschem::notify {a notice that reaches nobody} -tag error -short nobody]
update idletasks
puts "notify_returned=$r2"
puts "witness_sinks={[dict get $::xschem::notify_last sinks]}"
puts "LOGFILE=[xschem get actionlog_filename]"
exit 0
