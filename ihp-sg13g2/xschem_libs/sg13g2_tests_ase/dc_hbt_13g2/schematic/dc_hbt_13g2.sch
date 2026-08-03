v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {Nx - number of emitters} -210 110 0 0 0.2 0.2 {}
T {Ctrl-Click to execute launcher} 350 -100 0 0 0.3 0.3 {layer=11}
T {.save file can be created with IHP->"Create FET and BIP .save file"} 350 20 0 0 0.3 0.3 {layer=11}
N -300 60 -300 80 {
lab=GND}
N -300 -10 -300 0 {
lab=#net1}
N -170 20 -170 80 {
lab=GND}
N -40 20 -40 80 {
lab=GND}
N -170 -80 -170 -40 {
lab=#net2}
N -40 -80 -40 -40 {
lab=#net3}
N -170 -10 -120 -10 {
lab=GND}
N -120 -10 -120 80 {
lab=GND}
N -170 -80 -140 -80 {
lab=#net2}
N -80 -80 -40 -80 {
lab=#net3}
N -300 -10 -210 -10 {
lab=#net1}
C {devices/gnd} -170 80 0 0 {name=l1 lab=GND}
C {devices/gnd} -300 80 0 0 {name=l2 lab=GND}
C {devices/vsource} -40 -10 0 0 {name=Vce value=1.5}
C {devices/gnd} -40 80 0 0 {name=l3 lab=GND}
C {devices/gnd} -120 80 0 0 {name=l4 lab=GND}
C {devices/title} -130 260 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/isource} -300 30 2 0 {name=I0 value=1u}
C {devices/ammeter} -110 -80 1 0 {name=Vc}
C {sg13g2_pr/npn13G2} -190 -10 0 0 {name=Q1
model=npn13G2
spiceprefix=X
Nx=1
}
C {sg13g2_pr/annotate_bip_params} -300 -190 0 0 {name=annot1 ref=Q1}
