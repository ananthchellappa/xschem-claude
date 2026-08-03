v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {Ctrl-Click to execute launcher} 610 -70 0 0 0.3 0.3 {layer=11}
T {.save file can be created with IHP->"Create FET and BIP .save file"} 610 50 0 0 0.3 0.3 {layer=11}
N -110 70 -110 90 {
lab=GND}
N -110 -0 -110 10 {
lab=#net1}
N 20 30 20 90 {
lab=GND}
N 150 30 150 90 {
lab=GND}
N 20 -70 20 -30 {
lab=#net2}
N 150 -70 150 -30 {
lab=#net3}
N 20 0 70 0 {
lab=GND}
N 70 0 70 90 {
lab=GND}
N 20 -70 50 -70 {
lab=#net2}
N 110 -70 150 -70 {
lab=#net3}
N -110 0 -20 0 {
lab=#net1}
C {devices/gnd} 20 90 0 0 {name=l1 lab=GND}
C {devices/gnd} -110 90 0 0 {name=l2 lab=GND}
C {devices/vsource} -110 40 0 0 {name=Vgs value=0.75}
C {devices/vsource} 150 0 0 0 {name=Vds value=1.5}
C {devices/gnd} 150 90 0 0 {name=l3 lab=GND}
C {devices/gnd} 70 90 0 0 {name=l4 lab=GND}
C {devices/title} -130 260 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/ammeter} 80 -70 1 0 {name=Vd}
C {sg13g2_pr/annotate_fet_params} -120 -140 0 0 {name=annot1 ref=M1}
C {sg13g2_pr/sg13_hv_nmos} 0 0 0 0 {name=M1
l=0.45u
w=1.0u
ng=1
m=1
model=sg13_hv_nmos
spiceprefix=X
}
