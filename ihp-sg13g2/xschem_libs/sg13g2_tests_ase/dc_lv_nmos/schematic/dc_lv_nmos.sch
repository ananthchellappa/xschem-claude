v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {Ctrl-Click to execute launcher} 650 -330 0 0 0.3 0.3 {layer=11}
T {.save file can be created with IHP->"Create FET and BIP .save file"} 650 -210 0 0 0.3 0.3 {layer=11}
N 250 -160 250 -140 {
lab=GND}
N 250 -250 250 -220 {
lab=G}
N 380 -220 380 -160 {
lab=GND}
N 510 -220 510 -160 {
lab=GND}
N 380 -340 380 -280 {
lab=#net1}
N 510 -340 510 -280 {
lab=D}
N 380 -250 450 -250 {
lab=GND}
N 450 -250 450 -160 {
lab=GND}
N 380 -340 410 -340 {
lab=#net1}
N 470 -340 510 -340 {
lab=D}
N 250 -250 340 -250 {
lab=G}
C {devices/gnd} 380 -160 0 0 {name=l1 lab=GND}
C {devices/gnd} 250 -140 0 0 {name=l2 lab=GND}
C {devices/vsource} 250 -190 0 0 {name=Vgs value=1.2}
C {devices/vsource} 510 -250 0 0 {name=Vds value=1.5}
C {devices/gnd} 510 -160 0 0 {name=l3 lab=GND}
C {devices/gnd} 450 -160 0 0 {name=l4 lab=GND}
C {devices/title} 160 -30 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/ammeter} 440 -340 1 0 {name=Vd}
C {sg13g2_pr/annotate_fet_params} 240 -400 0 0 {name=annot1 ref=M1}
C {devices/lab_pin} 250 -250 0 0 {name=p1 sig_type=std_logic lab=G}
C {devices/lab_pin} 510 -340 0 1 {name=p2 sig_type=std_logic lab=D}
C {sg13g2_pr/sg13_lv_nmos} 360 -250 0 0 {name=M1
l=0.45u
w=1.0u
ng=1
m=1
model=sg13_lv_nmos
spiceprefix=X
}
