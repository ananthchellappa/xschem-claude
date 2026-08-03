v {xschem version=3.4.5 file_version=1.2
}
G {}
K {}
V {}
S {}
E {}
T {Nx - number of emitters} -110 80 0 0 0.2 0.2 {}
N -200 30 -200 50 {
lab=GND}
N -200 -40 -200 -30 {
lab=#net1}
N -70 -10 -70 50 {
lab=GND}
N 60 -10 60 50 {
lab=GND}
N -70 -110 -70 -70 {
lab=#net2}
N 60 -110 60 -70 {
lab=#net3}
N -70 -40 -20 -40 {
lab=GND}
N -20 -40 -20 50 {
lab=GND}
N -70 -110 -40 -110 {
lab=#net2}
N 20 -110 60 -110 {
lab=#net3}
N -200 -40 -110 -40 {
lab=#net1}
C {devices/gnd} -70 50 0 0 {name=l1 lab=GND}
C {devices/gnd} -200 50 0 0 {name=l2 lab=GND}
C {devices/vsource} 60 -40 0 0 {name=Vce value=1.5}
C {devices/gnd} 60 50 0 0 {name=l3 lab=GND}
C {devices/gnd} -20 50 0 0 {name=l4 lab=GND}
C {devices/title} -130 260 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/isource} -200 0 2 0 {name=I0 value=1u}
C {devices/ammeter} -10 -110 1 0 {name=Vc}
C {sg13g2_pr/npn13G2} -90 -40 0 0 {name=Q1
model=npn13G2
spiceprefix=X
Nx=1
}
