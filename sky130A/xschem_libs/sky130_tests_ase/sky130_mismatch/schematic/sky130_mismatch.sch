v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {This example shows differencies in vth1 / vth2 distributions 
of a 
m=10 / W=0.5 / L=0.15 transistor 
vs 
10 parallel W=0.5 / L=0.15 transistors} 650 -190 0 0 0.4 0.4 {}
N 230 -200 260 -200 {lab=VSS}
N 230 -250 230 -230 {lab=VTH1}
N 230 -280 230 -250 {lab=VTH1}
N 140 -250 140 -200 { lab=VTH1}
N 140 -250 230 -250 { lab=VTH1}
N 230 -170 230 -120 {
lab=VSS}
N 230 -360 230 -340 {
lab=#net1}
N 490 -200 520 -200 {lab=VSS}
N 490 -250 490 -230 {lab=VTH2}
N 490 -280 490 -250 {lab=VTH2}
N 400 -250 400 -200 { lab=VTH2}
N 400 -250 490 -250 { lab=VTH2}
N 490 -170 490 -120 {
lab=VSS}
N 490 -440 490 -340 {
lab=VSS}
N 230 -440 230 -420 {
lab=VSS}
N 400 -200 450 -200 {
lab=VTH2}
N 140 -200 190 -200 {
lab=VTH1}
C {devices/lab_pin} 260 -200 0 1 {name=p23 lab=VSS}
C {sky130_fd_pr/nfet_01v8} 210 -200 0 0 {name=M18
L=0.15
W=0.5
nf=1 mult=10
model=nfet_01v8
spiceprefix=X}
C {devices/lab_pin} 230 -250 0 1 {name=l5 lab=VTH1}
C {devices/lab_pin} 230 -120 0 0 {name=p8 lab=VSS}
C {devices/isource} 230 -310 0 0 {name=I0 value=100n
lvs_format=" "}
C {devices/lab_pin} 230 -440 0 0 {name=p10 lab=VSS}
C {devices/lab_pin} 520 -200 0 1 {name=p1 lab=VSS}
C {sky130_fd_pr/nfet_01v8} 470 -200 0 0 {name=M1[9:0]
L=0.15
W=0.5
nf=1 mult=1
model=nfet_01v8
spiceprefix=X}
C {devices/lab_pin} 490 -250 0 1 {name=l1 lab=VTH2}
C {devices/lab_pin} 490 -120 0 0 {name=p2 lab=VSS}
C {devices/lab_pin} 490 -440 0 0 {name=p3 lab=VSS}
C {devices/ammeter} 230 -390 0 0 {name=V1 savecurrent=true}
C {devices/title} 160 -30 0 0 {name=l2 author="Stefan Schippers"}
C {devices/isource} 490 -310 0 0 {name=I1 value=100n
lvs_format=" "}
