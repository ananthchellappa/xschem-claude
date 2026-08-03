v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 40 -210 40 -190 {
lab=GND}
N 40 -350 40 -270 {
lab=#net1}
N 40 -350 200 -350 {
lab=#net1}
N 200 -350 200 -290 {
lab=#net1}
N 200 -230 200 -190 {lab=GND}
N 210 -250 280 -250 {lab=sub!}
N 280 -250 280 -190 {lab=sub!}
N 60 -130 90 -130 {lab=GND}
N 60 -130 60 -120 {lab=GND}
N 150 -130 180 -130 {lab=sub!}
N 180 -130 180 -120 {lab=sub!}
C {devices/gnd} 40 -190 0 0 {name=l2 lab=GND}
C {devices/title} 160 -40 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/isource} 40 -240 2 0 {name=I0 value=1m}
C {devices/gnd} 200 -190 0 0 {name=l1 lab=GND}
C {sg13g2_pr/schottky_nbl1} 200 -260 0 0 {name=D1
model=schottky_nbl1
Nx=1
Ny=1
spiceprefix=X
}
C {sg13g2_pr/sub} 280 -190 0 0 {name=l3 lab=sub!}
C {devices/vsource} 120 -130 1 0 {name=V1 value=0 savecurrent=false}
C {devices/gnd} 60 -120 0 0 {name=l4 lab=GND}
C {sg13g2_pr/sub} 180 -120 0 0 {name=l6 lab=sub!}
