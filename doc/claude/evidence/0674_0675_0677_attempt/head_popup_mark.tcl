after 300
catch {ciw_create}; update idletasks
set tp [xschem get top_path]
catch {destroy .ciw.l}; catch {destroy $tp.statusbar.12}
set ::notify_style popup
update idletasks
catch {::xschem::notify {seed} -tag error -short s}
update idletasks
wm iconify .xschem_notify
update idletasks; after 300; update idletasks
puts "HEAD: popup exists=[winfo exists .xschem_notify] mapped=[winfo ismapped .xschem_notify] state=[wm state .xschem_notify]"
puts "HEAD: notify_popup_returns=[::xschem::notify_popup {probe} error]  (1 = the writer claims success)"
set r [::xschem::notify {nobody sees this} -tag error -short nb]
puts "HEAD: notify_returned=$r witness_sinks={[dict get $::xschem::notify_last sinks]}"
puts "HEAD: degraded=[::xschem::notify_channel_degraded]"
exit 0
