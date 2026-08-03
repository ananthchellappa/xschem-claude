v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {Uncomment the valid library:
res_typ when mc_ok = 0
res_typ_stat when mc_ok = 0} 360 -430 0 0 0.3 0.3 {}
N 380 40 380 100 {
lab=GND}
N 380 -100 380 -20 {
lab=Vcc}
N 380 -100 610 -100 {
lab=Vcc}
N 610 -100 610 -60 {
lab=Vcc}
N 610 0 610 20 {
lab=#net1}
N 610 80 610 100 {
lab=GND}
N 760 -100 760 -60 {
lab=Vcc}
N 760 0 760 20 {
lab=#net2}
N 760 80 760 100 {
lab=GND}
N 940 -100 940 -60 {
lab=Vcc}
N 940 0 940 20 {
lab=#net3}
N 940 80 940 100 {
lab=GND}
N 610 -100 760 -100 {
lab=Vcc}
N 760 -100 940 -100 {
lab=Vcc}
C {devices/gnd} 610 100 0 0 {name=l1 lab=GND}
C {devices/vsource} 380 10 0 0 {name=Vres value=1.5}
C {devices/gnd} 380 100 0 0 {name=l3 lab=GND}
C {devices/title} -130 260 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/lab_pin} 380 -50 2 0 {name=p1 sig_type=std_logic lab=Vcc}
C {devices/ammeter} 610 -30 0 0 {name=Vsil}
C {devices/gnd} 760 100 0 0 {name=l2 lab=GND}
C {devices/ammeter} 760 -30 0 0 {name=Vppd}
C {devices/gnd} 940 100 0 0 {name=l4 lab=GND}
C {devices/ammeter} 940 -30 0 0 {name=Vrh}
C {sg13g2_pr/rppd} 760 50 0 0 {name=R1
w=0.5e-6
l=0.5e-6
model=rppd
body=sub!
spiceprefix=X
b=0
m=1
}
C {sg13g2_pr/rsil} 610 50 0 0 {name=R2
w=0.5e-6
l=0.5e-6
model=rsil
body=sub!
spiceprefix=X
b=0
m=1
}
C {sg13g2_pr/rhigh} 940 50 0 0 {name=R3
w=0.5e-6
l=0.96e-6
model=rhigh
body=sub!
spiceprefix=X
b=0
m=1
}
C {devices/gnd} 490 30 2 0 {name=l6 lab=GND}
C {sg13g2_pr/ptap1} 490 60 0 0 {name=R4
model=ptap1
spiceprefix=X
w=0.78e-6
l=0.78e-6
}
C {sg13g2_pr/sub} 490 90 0 0 {name=l7 lab=sub!}
