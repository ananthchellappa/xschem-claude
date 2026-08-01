v {xschem version=3.4.6 file_version=1.2
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
* limitations under the License.}
G {}
K {}
V {}
S {}
E {}
P 4 5 740 -840 740 -560 990 -560 990 -840 740 -840 {dash=3}
T {Effect of M2
loading on OUT} 760 -890 0 0 0.4 0.4 {layer=4}
N 520 -330 520 -310 {
lab=S}
N 310 -310 520 -310 {
lab=S}
N 310 -330 310 -310 {
lab=S}
N 410 -310 410 -290 {
lab=S}
N 350 -500 480 -500 {
lab=G}
N 350 -500 350 -470 {
lab=G}
N 310 -470 350 -470 {
lab=G}
N 310 -470 310 -390 {
lab=G}
N 520 -470 520 -390 {
lab=OUT}
N 520 -570 520 -530 {
lab=VCC}
N 310 -570 520 -570 {
lab=VCC}
N 310 -570 310 -530 {
lab=VCC}
N 520 -450 610 -450 {
lab=OUT}
N 410 -150 410 -130 {
lab=GND}
N 410 -290 410 -270 {
lab=S}
N 310 -360 520 -360 {
lab=GND}
N 520 -530 520 -500 {
lab=VCC}
N 310 -530 310 -500 {
lab=VCC}
N 410 -180 410 -150 {
lab=GND}
N 930 -520 990 -520 {
lab=IN}
N 840 -520 870 -520 {
lab=MINUS}
N 760 -520 780 -520 {
lab=OUT}
N 860 -520 860 -360 {
lab=MINUS}
N 560 -360 860 -360 {
lab=MINUS}
N 610 -450 760 -450 {
lab=OUT}
N 760 -520 760 -450 {
lab=OUT}
N 800 -660 870 -660 {
lab=#net1}
N 870 -600 870 -580 {
lab=GND}
N 870 -750 870 -730 {
lab=GND}
N 800 -810 870 -810 {
lab=#net2}
N 800 -810 800 -720 {
lab=#net2}
N 800 -690 840 -690 {
lab=GND}
N 760 -690 760 -550 {
lab=OUT}
N 760 -550 760 -520 {
lab=OUT}
C {sky130_fd_pr/nfet_01v8_lvt} 290 -360 0 0 {name=M1
L=2
W=4
nf=1
mult=1


model=nfet_01v8_lvt
spiceprefix=X
}
C {sky130_fd_pr/nfet_01v8_lvt} 540 -360 0 1 {name=M2
L=2
W=4
nf=1
mult=1


model=nfet_01v8_lvt
spiceprefix=X
}
C {sky130_fd_pr/nfet_01v8_lvt} 390 -180 0 0 {name=M4
L=4
W=4
nf=1
mult=1


model=nfet_01v8_lvt
spiceprefix=X
}
C {devices/lab_wire} 430 -310 0 0 {name=l1 sig_type=std_logic lab=S}
C {sky130_fd_pr/pfet_01v8_lvt} 500 -500 0 0 {name=M3
L=4
W=4
nf=1
mult=1


model=pfet_01v8_lvt
spiceprefix=X
}
C {sky130_fd_pr/pfet_01v8_lvt} 330 -500 0 1 {name=M5
L=4
W=4
nf=1
mult=1


model=pfet_01v8_lvt
spiceprefix=X
}
C {devices/lab_wire} 410 -570 0 0 {name=l1 sig_type=std_logic lab=VCC}
C {devices/lab_wire} 420 -500 0 0 {name=l1 sig_type=std_logic lab=G}
C {devices/lab_pin} 410 -130 0 0 {name=l1 sig_type=std_logic lab=GND}
C {devices/ammeter} 410 -240 0 0 {name=Vtail
current=8.3431e-06}
C {devices/lab_pin} 270 -360 0 0 {name=l1 sig_type=std_logic lab=PLUS}
C {devices/lab_pin} 860 -360 0 1 {name=l1 sig_type=std_logic lab=MINUS}
C {devices/title} 160 -30 0 0 {name=l2}
C {devices/lab_pin} 370 -180 0 0 {name=l1 sig_type=std_logic lab=BIAS}
C {devices/vsource} 50 -190 0 0 {name=V1 value=0.7}
C {devices/lab_pin} 50 -220 0 1 {name=l1 sig_type=std_logic lab=BIAS}
C {devices/vsource} 50 -270 0 0 {name=V2 value=1.8}
C {devices/lab_pin} 50 -300 0 1 {name=l1 sig_type=std_logic lab=VCC}
C {devices/vsource} 50 -360 0 0 {name=V3 value=0.91}
C {devices/lab_pin} 50 -390 0 1 {name=l1 sig_type=std_logic lab=PLUS}
C {devices/vsource} 50 -450 0 0 {name=V4 value="0 ac 1 0
+ sin(0 1m 100meg 0 0 0)"}
C {devices/lab_pin} 50 -480 0 1 {name=l2 sig_type=std_logic lab=IN}
C {devices/lab_wire} 430 -360 0 0 {name=l1 sig_type=std_logic lab=GND}
C {devices/lab_pin} 50 -160 0 0 {name=l1 sig_type=std_logic lab=GND}
C {devices/lab_pin} 50 -240 0 0 {name=l1 sig_type=std_logic lab=GND}
C {devices/lab_pin} 50 -330 0 0 {name=l1 sig_type=std_logic lab=GND}
C {devices/lab_pin} 50 -420 0 0 {name=l1 sig_type=std_logic lab=GND}
C {devices/capa} 900 -520 3 1 {name=C2
m=1
value=1T
footprint=1206
device="ceramic capacitor"}
C {devices/ind} 810 -520 3 1 {name=L1
m=1
value=1T
footprint=1206
device=inductor}
C {devices/lab_pin} 760 -500 0 0 {name=l2 sig_type=std_logic lab=OUT}
C {devices/lab_pin} 990 -520 0 1 {name=l2 sig_type=std_logic lab=IN}
C {devices/vcvs} 870 -630 0 1 {name=E1 value=1}
C {devices/lab_pin} 910 -610 0 1 {name=l2 sig_type=std_logic lab=GND}
C {devices/lab_pin} 910 -650 0 1 {name=l3 sig_type=std_logic lab=S}
C {sky130_fd_pr/nfet_01v8_lvt} 780 -690 0 0 {name=M6
L=2
W=4
nf=1
mult=1


model=nfet_01v8_lvt
spiceprefix=X
}
C {devices/vcvs} 870 -780 0 1 {name=E2 value=1}
C {devices/lab_pin} 910 -760 0 1 {name=l4 sig_type=std_logic lab=GND}
C {devices/lab_pin} 910 -800 0 1 {name=l5 sig_type=std_logic lab=OUT}
C {devices/lab_pin} 870 -580 0 1 {name=l6 sig_type=std_logic lab=GND}
C {devices/lab_pin} 870 -730 0 1 {name=l7 sig_type=std_logic lab=GND}
C {devices/lab_pin} 840 -690 0 1 {name=l8 sig_type=std_logic lab=GND}
C {sky130_fd_pr/annotate_fet_params} 290 -650 0 1 {name=annot1 ref=M5}
C {sky130_fd_pr/annotate_fet_params} 530 -650 0 0 {name=annot2 ref=M3}
C {sky130_fd_pr/annotate_fet_params} 320 -160 0 1 {name=annot5 ref=M4}
C {sky130_fd_pr/annotate_fet_params} 290 -320 0 1 {name=annot3 ref=M1}
C {sky130_fd_pr/annotate_fet_params} 530 -320 0 0 {name=annot4 ref=M2}
