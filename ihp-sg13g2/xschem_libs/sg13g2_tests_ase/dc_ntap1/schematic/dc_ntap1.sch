v {xschem version=3.4.5 file_version=1.2
}
G {}
K {}
V {}
S {}
E {}
N -100 80 -100 180 {
lab=#net1}
N -100 -60 -100 -20 {
lab=#net2}
N 80 -60 80 -20 {
lab=Vcc}
N -100 -60 -20 -60 {
lab=#net2}
N 40 -60 80 -60 {
lab=Vcc}
N 80 -60 130 -60 {
lab=Vcc}
N -100 80 80 80 {
lab=#net1}
N 80 40 80 80 {
lab=#net1}
N -100 40 -100 80 {
lab=#net1}
N -350 80 -100 80 {
lab=#net1}
N -350 -60 -350 -20 {
lab=#net2}
N -350 -60 -100 -60 {
lab=#net2}
N -220 180 -200 180 {
lab=GND}
N -140 180 -100 180 {
lab=#net1}
N -350 40 -350 80 {
lab=#net1}
C {devices/title} -130 260 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/gnd} -220 180 0 0 {name=l2 lab=GND}
C {devices/vsource} 80 10 0 0 {name=Vres value=1.5}
C {devices/lab_pin} 130 -60 2 0 {name=p2 sig_type=std_logic lab=Vcc}
C {devices/ammeter} 10 -60 1 0 {name=Vr}
C {devices/vsource} -170 180 3 0 {name=Vres2 value=0}
C {sg13g2_pr/ntap1} -100 10 0 0 {name=R4
model=ntap1
spiceprefix=X
w=1.0e-6
l=0.78e-6
}
C {sg13g2_pr/ntap1} -350 10 0 0 {name=R5
model=ntap1
spiceprefix=X
w=10.0e-6
l=1.0e-6
}
