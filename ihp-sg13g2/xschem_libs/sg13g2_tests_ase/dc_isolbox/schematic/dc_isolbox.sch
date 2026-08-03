v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N -500 30 -500 50 {
lab=GND}
N -340 30 -340 50 {
lab=GND}
N -500 -110 -500 -30 {
lab=isosub_net}
N -500 -110 -340 -110 {
lab=isosub_net}
N -340 -110 -340 -90 {
lab=isosub_net}
N -340 -30 -260 -30 {
lab=nwell_net}
N -340 -110 -260 -110 {
lab=isosub_net}
N -260 -30 -260 -10 {
lab=nwell_net}
C {devices/gnd} -500 50 0 0 {name=l2 lab=GND}
C {devices/title} -360 130 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/isource} -500 0 2 0 {name=I0 value=1m}
C {devices/gnd} -340 50 0 0 {name=l1 lab=GND}
C {devices/lab_pin} -260 -110 2 0 {name=p1 sig_type=std_logic lab=isosub_net}
C {devices/lab_pin} -260 -30 2 0 {name=p2 sig_type=std_logic lab=nwell_net}
C {sg13g2_pr/isolbox} -340 -30 0 0 {name=D1
model=isolbox
l=3.0u
w=3.0u
spiceprefix=X
}
C {devices/noconn} -260 -10 3 0 {name=l3}
