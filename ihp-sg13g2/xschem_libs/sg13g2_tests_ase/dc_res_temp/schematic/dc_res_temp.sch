v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -140 30 -140 90 {
lab=GND}
N -140 -110 -140 -30 {
lab=Vcc}
N -140 -110 90 -110 {
lab=Vcc}
N 90 -110 90 -70 {
lab=Vcc}
N 90 -10 90 10 {
lab=#net1}
N 90 70 90 90 {
lab=GND}
N 240 -110 240 -70 {
lab=Vcc}
N 240 -10 240 10 {
lab=#net2}
N 240 70 240 90 {
lab=GND}
N 420 -110 420 -70 {
lab=Vcc}
N 420 -10 420 10 {
lab=#net3}
N 420 70 420 90 {
lab=GND}
N 90 -110 240 -110 {
lab=Vcc}
N 240 -110 420 -110 {
lab=Vcc}
C {devices/gnd} 90 90 0 0 {name=l1 lab=GND}
C {devices/vsource} -140 0 0 0 {name=Vres value=1.5}
C {devices/gnd} -140 90 0 0 {name=l3 lab=GND}
C {devices/title} -130 260 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/lab_pin} -140 -60 2 0 {name=p1 sig_type=std_logic lab=Vcc}
C {devices/ammeter} 90 -40 0 0 {name=Vsil}
C {devices/gnd} 240 90 0 0 {name=l2 lab=GND}
C {devices/ammeter} 240 -40 0 0 {name=Vppd}
C {devices/gnd} 420 90 0 0 {name=l4 lab=GND}
C {devices/ammeter} 420 -40 0 0 {name=Vrh}
C {sg13g2_pr/sub} -30 90 0 0 {name=l6 lab=sub!}
C {sg13g2_pr/ptap1} -30 60 0 0 {name=R4
model=ptap1
spiceprefix=X
w=0.78e-6
l=0.78e-6
}
C {devices/gnd} -30 30 2 0 {name=l7 lab=GND}
C {sg13g2_pr/rsil} 90 40 0 0 {name=R1
w=0.5e-6
l=0.5e-6
model=rsil
body=sub!
spiceprefix=X
b=0
m=1
}
C {sg13g2_pr/rhigh} 420 40 0 0 {name=R3
w=0.5e-6
l=0.96e-6
model=rhigh
body=sub!
spiceprefix=X
b=0
m=1
}
C {sg13g2_pr/rppd} 240 40 0 0 {name=R2
w=0.5e-6
l=0.5e-6
model=rppd
body=sub!
spiceprefix=X
b=0
m=1
}
