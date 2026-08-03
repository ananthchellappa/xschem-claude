v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {Nx - number of emitters} -210 110 0 0 0.2 0.2 {}
T {Ctrl-Click to execute launcher} 450 -120 0 0 0.3 0.3 {layer=11}
T {.save file can be created with IHP->"Create FET and BIP .save file"} 450 0 0 0 0.3 0.3 {layer=11}
N -300 60 -300 80 {
lab=GND}
N -300 -10 -300 0 {
lab=#net1}
N -170 20 -170 80 {
lab=GND}
N 40 20 40 80 {
lab=GND}
N -170 -80 -170 -40 {
lab=#net2}
N 40 -80 40 -40 {
lab=#net3}
N -170 -80 -140 -80 {
lab=#net2}
N -80 -80 40 -80 {
lab=#net3}
N -300 -10 -210 -10 {
lab=#net1}
N -140 40 -140 80 {
lab=GND}
N -120 -10 -80 -10 {
lab=tmp}
N -80 70 -80 80 {
lab=GND}
N -80 -10 -80 10 {
lab=tmp}
N -80 -20 -80 -10 {
lab=tmp}
N 400 70 400 90 {
lab=GND}
N 400 0 400 10 {
lab=#net4}
N 290 30 290 80 {
lab=GND}
N 250 0 250 80 {
lab=GND}
N 250 0 290 0 {
lab=GND}
N 290 -80 290 -30 {
lab=#net5}
N 210 -80 290 -80 {
lab=#net5}
N 40 -80 150 -80 {
lab=#net3}
N 330 -0 400 -0 {
lab=#net4}
C {devices/gnd} -170 80 0 0 {name=l1 lab=GND}
C {devices/gnd} -300 80 0 0 {name=l2 lab=GND}
C {devices/vsource} 40 -10 0 0 {name=Vce value=1.5}
C {devices/gnd} 40 80 0 0 {name=l3 lab=GND}
C {devices/gnd} -140 80 0 0 {name=l4 lab=GND}
C {devices/title} -130 260 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/isource} -300 30 2 0 {name=I0 value=1u}
C {devices/ammeter} -110 -80 1 0 {name=Vc}
C {devices/res} -80 40 0 0 {name=R1
value=10G
footprint=1206
device=resistor
m=1}
C {devices/gnd} -80 80 0 0 {name=l6 lab=GND}
C {devices/lab_wire} -80 -20 0 0 {name=p1 sig_type=std_logic lab=tmp}
C {devices/gnd} 400 90 0 0 {name=l7 lab=GND}
C {devices/isource} 400 40 2 0 {name=I1 value=1u}
C {devices/gnd} 290 80 0 0 {name=l8 lab=GND}
C {devices/gnd} 250 80 0 0 {name=l9 lab=GND}
C {devices/ammeter} 180 -80 3 0 {name=Vc1}
C {sg13g2_pr/npn13G2} 310 0 0 1 {name=Q1
model=npn13G2
spiceprefix=X
Nx=1
}
C {sg13g2_pr/npn13G2_5t} -190 -10 0 0 {name=Q2
model=npn13G2_5t
spiceprefix=X
Nx=1
}
C {sg13g2_pr/annotate_bip_params} -410 -170 0 0 {name=annot1 ref=Q2}
C {sg13g2_pr/annotate_bip_params} 450 50 0 0 {name=annot2 ref=Q1}
