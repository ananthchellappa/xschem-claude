v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 420 -300 420 -270 {lab=GND}
N 550 -440 550 -380 {lab=#net1}
N 420 -370 420 -330 {lab=D}
N 340 -380 340 -300 {lab=G}
N 300 -380 300 -340 {lab=G}
N 300 -380 340 -380 {lab=G}
N 340 -300 380 -300 {lab=G}
N 550 -320 550 -270 {lab=GND}
N 300 -280 300 -270 {lab=GND}
N 300 -270 420 -270 {lab=GND}
N 420 -270 550 -270 {lab=GND}
N 420 -440 420 -430 {lab=#net1}
N 380 -400 400 -400 {lab=#net1}
N 380 -440 380 -400 {lab=#net1}
N 380 -440 420 -440 {lab=#net1}
N 420 -440 550 -440 {lab=#net1}
C {sky130_fd_pr/nfet_01v8} 400 -300 0 0 {name=M1 W=1 L=0.15 nf=1}
C {devices/vsource} 550 -350 0 0 {name=V1 value=Vds}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 420 -350 0 0 {name=lD lab=D}
C {devices/lab_wire} 300 -380 0 0 {name=lG lab=G}
C {devices/vpulse} 300 -310 0 1 {name="V2" DC="Vgs"
Vinit=0
Vpulse="Vgs"
TD="10n"
TR=1n
TF=1n
PW=50n
PER=100n}
C {sky130_fd_pr/res_high_po} 420 -400 0 0 {name=R1
W=1
L=1
model=res_high_po
spiceprefix=X
mult=1}
