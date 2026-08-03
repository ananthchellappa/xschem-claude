v {xschem version=3.4.5 file_version=1.2
}
G {}
K {}
V {}
S {}
E {}
N -180 80 -180 100 {
lab=sub!}
N -180 -60 -180 -20 {
lab=#net1}
N 0 -60 0 -20 {
lab=Vcc}
N -180 -60 -100 -60 {
lab=#net1}
N -40 -60 0 -60 {
lab=Vcc}
N 0 -60 50 -60 {
lab=Vcc}
N -180 80 0 80 {
lab=sub!}
N 0 40 0 80 {
lab=sub!}
N -180 40 -180 80 {
lab=sub!}
N -430 40 -430 80 {
lab=sub!}
N -430 80 -180 80 {
lab=sub!}
N -430 -60 -430 -20 {
lab=#net1}
N -430 -60 -180 -60 {
lab=#net1}
N -300 180 -280 180 {
lab=GND}
N -220 180 -200 180 {
lab=sub!}
C {devices/gnd} -300 180 0 0 {name=l1 lab=GND}
C {devices/vsource} 0 10 0 0 {name=Vres value=1.5}
C {devices/title} -100 240 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/lab_pin} 50 -60 2 0 {name=p1 sig_type=std_logic lab=Vcc}
C {devices/ammeter} -70 -60 1 0 {name=Vr}
C {sg13g2_pr/ptap1} -430 10 0 0 {name=R5
model=ptap1
spiceprefix=X
w=10.0e-6
l=1.0e-6
}
C {sg13g2_pr/ptap1} -180 10 0 0 {name=R1
model=ptap1
spiceprefix=X
w=1.0e-6
l=0.78e-6
}
C {sg13g2_pr/sub} -180 100 0 0 {name=l2 lab=sub!}
C {sg13g2_pr/sub} -200 180 0 0 {name=l3 lab=sub!}
C {devices/vsource} -250 180 3 0 {name=Vres1 value=0}
