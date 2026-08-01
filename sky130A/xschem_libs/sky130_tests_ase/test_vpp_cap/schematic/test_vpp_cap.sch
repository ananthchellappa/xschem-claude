v {xschem version=3.4.5 file_version=1.2
* Copyright 2021 Stefan Frederik Schippers
* 
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     https://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.

}
G {}
K {}
V {}
S {}
E {}
T {VPP_CAP vs ideal capacitors} 460 -940 0 0 1 1 {}
T {@model} 280 -90 0 0 0.4 0.4 {name=C1 layer=15}
T {@model} 1390 -90 0 0 0.4 0.4 {name=C4 layer=15}
N 580 -470 580 -440 { lab=0}
N 580 -270 580 -200 { lab=G1}
N 580 -140 580 -110 { lab=0}
N 870 -200 870 -180 { lab=REF}
N 870 -270 870 -260 { lab=G1}
N 580 -270 870 -270 { lab=G1}
N 580 -290 580 -270 { lab=G1}
N 1010 -470 1010 -440 { lab=0}
N 1010 -270 1010 -200 { lab=G2}
N 1010 -140 1010 -110 { lab=0}
N 1150 -200 1150 -180 { lab=REF}
N 1150 -270 1150 -260 { lab=G2}
N 1010 -270 1150 -270 { lab=G2}
N 1010 -290 1010 -270 { lab=G2}
N 390 -440 390 -420 { lab=REF}
N 1590 -470 1590 -440 { lab=0}
N 1590 -270 1590 -200 { lab=G4}
N 1590 -140 1590 -110 { lab=0}
N 1880 -200 1880 -180 { lab=REF}
N 1880 -270 1880 -260 { lab=G4}
N 1590 -270 1880 -270 { lab=G4}
N 1590 -290 1590 -270 { lab=G4}
N 1290 -470 1290 -440 { lab=0}
N 1290 -270 1290 -200 { lab=G3}
N 1290 -140 1290 -110 { lab=0}
N 1430 -200 1430 -180 { lab=REF}
N 1430 -270 1430 -260 { lab=G3}
N 1290 -270 1430 -270 { lab=G3}
N 1290 -290 1290 -270 { lab=G3}
N 580 -380 580 -350 { lab=#net1}
N 1010 -380 1010 -350 { lab=#net2}
N 1290 -380 1290 -350 { lab=#net3}
N 1590 -380 1590 -350 { lab=#net4}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {devices/lab_pin} 580 -230 0 0 {name=p4 lab=G1}
C {devices/isource} 580 -410 0 0 {name=I1 value="pwl 0 0 1000n 0 1010n 100n"}
C {devices/lab_pin} 580 -470 0 0 {name=p1 lab=0}
C {devices/lab_pin} 580 -110 0 0 {name=p2 lab=0}
C {devices/res} 870 -230 0 0 {name=R1
value=1G
footprint=1206
device=resistor
m=1}
C {devices/lab_pin} 870 -180 0 0 {name=p5 lab=REF}
C {devices/lab_pin} 1010 -230 0 0 {name=p9 lab=G2}
C {devices/isource} 1290 -410 0 0 {name=I3 value="pwl 0 0 1000n 0 1010n 100n"}
C {devices/lab_pin} 1010 -470 0 0 {name=p11 lab=0}
C {devices/lab_pin} 1010 -110 0 0 {name=p12 lab=0}
C {devices/res} 1430 -230 0 0 {name=R3
value=1G
footprint=1206
device=resistor
m=1}
C {devices/lab_pin} 1150 -180 0 0 {name=p13 lab=REF}
C {devices/capa} 1010 -170 0 0 {name=C2
m=1
value=137.45f
footprint=1206
device="ceramic capacitor"}
C {devices/vsource} 390 -390 0 0 {name=V1 value=0}
C {devices/lab_pin} 390 -360 0 0 {name=p14 lab=0}
C {devices/lab_pin} 390 -440 0 1 {name=p15 lab=REF}
C {devices/lab_pin} 560 -160 0 0 {name=p3 lab=0}
C {sky130_fd_pr/vpp_cap} 580 -170 0 0 {name=C1
model=cap_vpp_11p5x11p7_l1m1m2m3m4_shieldm5
mult=1 
spiceprefix=X}
C {devices/lab_pin} 1590 -230 0 0 {name=p6 lab=G4}
C {devices/isource} 1010 -410 0 0 {name=I2 value="pwl 0 0 1000n 0 1010n 100n"}
C {devices/lab_pin} 1590 -470 0 0 {name=p7 lab=0}
C {devices/lab_pin} 1590 -110 0 0 {name=p8 lab=0}
C {devices/res} 1150 -230 0 0 {name=R2
value=1G
footprint=1206
device=resistor
m=1}
C {devices/lab_pin} 1880 -180 0 0 {name=p10 lab=REF}
C {devices/lab_pin} 1570 -160 0 0 {name=p16 lab=0}
C {sky130_fd_pr/vpp_cap} 1590 -170 0 0 {name=C4
model=cap_vpp_06p8x06p1_m1m2m3_shieldl1m4
mult=1 
spiceprefix=X}
C {devices/lab_pin} 1290 -230 0 0 {name=p17 lab=G3}
C {devices/isource} 1590 -410 0 0 {name=I4 value="pwl 0 0 1000n 0 1010n 100n"}
C {devices/lab_pin} 1290 -470 0 0 {name=p18 lab=0}
C {devices/lab_pin} 1290 -110 0 0 {name=p19 lab=0}
C {devices/res} 1880 -230 0 0 {name=R4
value=1G
footprint=1206
device=resistor
m=1}
C {devices/lab_pin} 1430 -180 0 0 {name=p20 lab=REF}
C {devices/capa} 1290 -170 0 0 {name=C3
m=1
value=42.11f
footprint=1206
device="ceramic capacitor"}
C {devices/ammeter} 580 -320 0 0 {name=Vc1 savecurrent=true}
C {devices/ammeter} 1010 -320 0 0 {name=Vc2 savecurrent=true}
C {devices/ammeter} 1290 -320 0 0 {name=Vc3 savecurrent=true}
C {devices/ammeter} 1590 -320 0 0 {name=Vc4 savecurrent=true}
