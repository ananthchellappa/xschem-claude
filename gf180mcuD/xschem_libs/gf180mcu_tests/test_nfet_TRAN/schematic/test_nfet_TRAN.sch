v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 420 -300 420 -270 {lab=GND}
N 420 -270 570 -270 {lab=GND}
N 280 -270 420 -270 {lab=GND}
N 280 -340 350 -340 {lab=G}
N 350 -340 350 -300 {lab=G}
N 280 -340 280 -330 {lab=G}
N 350 -300 380 -300 {lab=G}
N 420 -370 420 -330 {lab=D}
N 570 -440 570 -360 {lab=#net1}
N 420 -440 420 -430 {lab=#net1}
N 390 -400 400 -400 {lab=#net1}
N 390 -440 390 -400 {lab=#net1}
N 390 -440 420 -440 {lab=#net1}
N 570 -300 570 -270 {lab=GND}
N 420 -440 570 -440 {lab=#net1}
C {gf180mcu_pr/nfet_03v3} 400 -300 0 0 {name=M1
L=0.28u
W=1u
nf=1
m=1
ad="'int((nf+1)/2) * W/nf * 0.18u'"
pd="'2*int((nf+1)/2) * (W/nf + 0.18u)'"
as="'int((nf+2)/2) * W/nf * 0.18u'"
ps="'2*int((nf+2)/2) * (W/nf + 0.18u)'"
nrd="'0.18u / W'" nrs="'0.18u / W'"
sa=0 sb=0 sd=0
model=nfet_03v3
spiceprefix=X
}
C {devices/vsource} 570 -330 0 0 {name=V1 value=Vds}
C {devices/vpulse} 280 -300 0 0 {name="V2" DC=Vgs
Vinit=0
Vpulse=Vgs
TD=10n
TR=1n
TF=1n
PW=50n
PER=100n}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 420 -350 0 0 {name=lD lab=D}
C {devices/lab_wire} 300 -340 0 0 {name=lG lab=G}
C {gf180mcu_pr/ppolyf_u_1k} 420 -400 0 0 {name=R1
W=1e-6
L=1e-6
model=ppolyf_u_1k
spiceprefix=X
m=1}
