v {xschem version=3.4.8RC file_version=1.3
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
F {}
E {}
L 2 2100 -690 2150 -690 {}
L 2 2240 -610 2290 -610 {}
L 3 1970 -860 1970 -740 {}
L 3 2130 -860 2130 -790 {}
L 3 2290 -860 2290 -740 {}
L 4 1870 -720 1970 -720 {}
L 4 1970 -740 1970 -720 {}
L 4 1970 -740 2290 -740 {}
L 4 2290 -740 2290 -720 {}
L 4 2290 -720 2410 -720 {}
L 4 1870 -790 2130 -790 {}
L 4 2130 -790 2130 -770 {}
L 4 2130 -770 2290 -770 {}
L 4 2290 -790 2290 -770 {}
L 4 2290 -790 2410 -790 {}
L 4 1870 -670 2130 -670 {}
L 4 2130 -670 2150 -690 {}
L 4 2150 -690 2290 -690 {}
L 4 2290 -690 2290 -670 {}
L 4 2290 -670 2410 -670 {}
L 4 1870 -610 2130 -610 {}
L 4 2210 -650 2290 -650 {}
L 4 2290 -650 2290 -610 {}
L 4 2290 -610 2410 -610 {}
L 4 2130 -610 2210 -650 {}
L 4 2270 -640 2270 -620 {}
L 4 2113.75 -683.75 2113.75 -676.25 {}
A 4 1620 -1190 5 0 360 {fill=true}
A 4 1620 -1140 5 0 360 {fill=true}
A 4 1620 -1090 5 0 360 {fill=true}
A 4 1620 -990 5 0 360 {fill=true}
A 4 1620 -890 5 0 360 {fill=true}
A 4 1620 -1040 5 0 360 {fill=true}
A 4 1620 -1240 5 0 360 {fill=true}
P 4 5 70 -1330 640 -1330 640 -760 70 -760 70 -1330 {dash=4}
P 4 4 2270 -650 2267.5 -640 2272.5 -640 2270 -650 {fill=true}
P 4 4 2270 -610 2272.5 -620 2267.5 -620 2270 -610 {fill=true}
P 4 4 2113.75 -690 2111.25 -683.75 2116.25 -683.75 2113.75 -690 {fill=true}
P 4 4 2113.75 -670 2116.25 -676.25 2111.25 -676.25 2113.75 -670 {fill=true}
T {Comparator - design goals} 1840 -1350 0 0 1 1 {}
T {Comparator must detect a differential signal as low as +/-1mV} 1640 -1260 0 0 0.6 0.6 {}
T {1.8V VCC +/- 10%} 1640 -1210 0 0 0.6 0.6 {}
T {-40C to 125C temperature} 1640 -1160 0 0 0.6 0.6 {}
T {Simulate with device mismatch parameters} 1640 -1110 0 0 0.6 0.6 {}
T {Sensing time: 500ns calibration and 500ns sensing
(no speed optimization).} 1640 -1010 0 0 0.6 0.6 {}
T {CAL} 1860 -800 0 1 0.4 0.4 {}
T {EN} 1860 -750 0 1 0.4 0.4 {}
T {CALIBRATION
  1us} 2120 -850 0 1 0.4 0.4 {}
T {SENSING
  1us} 2250 -850 0 1 0.4 0.4 {}
T {OFF} 2380 -850 0 1 0.4 0.4 {}
T {OFF} 1930 -850 0 1 0.4 0.4 {}
T {V+ - V-} 1860 -680 0 1 0.4 0.4 {}
T {SAOUT} 1860 -620 0 1 0.4 0.4 {}
T {2mV} 2050 -700 0 0 0.4 0.4 {}
T {VCC} 2210 -650 0 0 0.4 0.4 {}
T {Icc < 50uA} 1640 -910 0 0 0.6 0.6 {}
T {Self calibration: no circuit trimming} 1640 -1060 0 0 0.6 0.6 {}
T {Check devices. Not on layout
will not be present in LVS
netlist} 20 -1460 0 0 0.6 0.6 {}
T {Mismatch checker} 460 -1100 0 0 0.3 0.3 { layer=4}
T {Simulation temperature} 440 -1270 0 0 0.3 0.3 { layer=4}
T {tcleval(Dataset=\\\\n[xschem getprop rect 2 0 dataset]\\\\n(-1=all))} 1280 -110 0 0 0.5 0.5 {floater=xxx}
N 320 -540 340 -540 { lab=DIFFOUT_N}
N 420 -540 720 -540 { lab=ADJ}
N 130 -880 160 -880 {lab=VSS}
N 130 -930 130 -910 {lab=VTH1}
N 130 -960 130 -930 {lab=VTH1}
N 90 -930 90 -880 { lab=VTH1}
N 90 -930 130 -930 { lab=VTH1}
N 130 -850 130 -800 {
lab=VSS}
N 130 -1060 130 -1020 {
lab=VSS}
N 430 -360 570 -360 {
lab=DIFFOUT_N}
N 120 -1280 120 -1260 {lab=TEMPERAT}
N 290 -880 320 -880 {lab=VSS}
N 290 -930 290 -910 {lab=VTH2}
N 290 -960 290 -930 {lab=VTH2}
N 250 -930 250 -880 { lab=VTH2}
N 250 -930 290 -930 { lab=VTH2}
N 290 -850 290 -800 {
lab=VSS}
N 290 -1060 290 -1020 {
lab=VSS}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {devices/lab_pin} 270 -270 0 0 {name=p1 lab=EN_N}
C {devices/lab_pin} 270 -330 0 0 {name=p2 lab=MINUS}
C {devices/lab_pin} 270 -390 0 0 {name=p3 lab=PLUS}
C {devices/lab_wire} 460 -360 0 1 {name=p4 lab=DIFFOUT_N}
C {devices/lab_pin} 270 -250 0 0 {name=p5 lab=VCC}
C {devices/lab_pin} 270 -230 0 0 {name=p6 lab=VSS}
C {devices/lab_pin} 270 -290 0 0 {name=p7 lab=ADJ}
C {sky130_tests/passgate} 380 -540 0 0 {name=x6 W_N=0.42 L_N=0.3 W_P=0.7 L_P=0.35 VCCBPIN=VCC VSSBPIN=VSS m=1
modelp=pfet_01v8_lvt
schematic=passgate_1
}
C {devices/lab_pin} 380 -510 0 0 {name=l34 sig_type=std_logic lab=START_N}
C {devices/lab_pin} 380 -570 0 0 {name=l37 sig_type=std_logic lab=START}
C {devices/lab_pin} 720 -540 0 1 {name=l255 lab=ADJ}
C {devices/lab_pin} 490 -480 0 0 {name=l40 sig_type=std_logic lab=VSS}
C {sky130_fd_pr/cap_mim_m3_2} 490 -510 0 0 {name=C1 model=cap_mim_m3_2 W=9 L=9 MF=2 spiceprefix=X }
C {devices/lab_pin} 320 -540 0 0 {name=p9 lab=DIFFOUT_N}
C {sky130_tests/not} 540 -700 0 0 {name=x2 m=1 VCCPIN=VCC VSSPIN=VSS W_N=1 L_N=0.15 W_P=2 L_P=0.15}
C {devices/lab_pin} 500 -700 0 0 {name=p15 lab=START}
C {devices/lab_pin} 580 -700 0 1 {name=p16 lab=START_N}
C {sky130_tests/zero_opamp} 350 -360 0 0 {name=x1}
C {devices/lab_pin} 160 -880 0 1 {name=p23 lab=VSS}
C {sky130_fd_pr/nfet_01v8} 110 -880 0 0 {name=M18
L=0.15
W=0.5
nf=1 mult=1
model=nfet_01v8
spiceprefix=X
 lvs_format=" "}
C {devices/lab_pin} 130 -930 0 1 {name=l5 lab=VTH1}
C {devices/lab_pin} 130 -800 0 0 {name=p8 lab=VSS}
C {devices/isource} 130 -990 0 0 {name=I0 value=100n
lvs_format=" "}
C {devices/lab_pin} 130 -1060 0 0 {name=p10 lab=VSS}
C {sky130_tests/gain_stage} 630 -360 0 0 {name=x3 wcap=9 modeln=nfet_01v8
schematic=gain_stage2}
C {devices/lab_pin} 690 -360 0 1 {name=p12 lab=OUT}
C {devices/lab_pin} 610 -250 0 0 {name=p13 lab=VCC}
C {devices/lab_pin} 610 -230 0 0 {name=p14 lab=VSS}
C {devices/lab_pin} 610 -270 0 0 {name=p17 lab=START_N}
C {devices/lab_pin} 610 -290 0 0 {name=p18 lab=START}
C {devices/lab_pin} 610 -310 0 0 {name=p19 lab=EN_N}
C {devices/vsource_arith} 120 -1230 0 0 {name=E5 VOL=temper MAX=200 MIN=-200
lvs_format=" "}
C {devices/lab_pin} 120 -1280 0 1 {name=p113 lab=TEMPERAT}
C {devices/lab_pin} 120 -1200 0 0 {name=p114 lab=VSS}
C {devices/noconn} 120 -1280 0 0 {name=l12}
C {devices/lab_pin} 80 -570 0 0 { name=p11 lab=VCC }
C {devices/lab_pin} 80 -590 0 0 { name=p20 lab=START }
C {devices/lab_pin} 80 -610 0 0 { name=p21 lab=PLUS }
C {devices/lab_pin} 80 -650 0 0 { name=p24 lab=MINUS }
C {devices/lab_pin} 80 -670 0 0 { name=p25 lab=EN_N }
C {devices/ipin} 0 -20 0 0 { name=p22 lab=VCC }
C {devices/ipin} 0 -40 0 0 { name=p26 lab=START }
C {devices/ipin} 0 -60 0 0 { name=p27 lab=PLUS }
C {devices/opin} 0 -80 0 0 { name=p28 lab=OUT }
C {devices/ipin} 0 -100 0 0 { name=p29 lab=MINUS }
C {devices/ipin} 0 -120 0 0 { name=p30 lab=EN_N }
C {devices/noconn} 80 -670 0 1 {name=l2}
C {devices/noconn} 80 -650 0 1 {name=l3}
C {devices/noconn} 80 -610 0 1 {name=l4}
C {devices/noconn} 80 -590 0 1 {name=l6}
C {devices/noconn} 80 -570 0 1 {name=l7}
C {devices/lab_pin} 320 -880 0 1 {name=p31 lab=VSS}
C {sky130_fd_pr/nfet_01v8} 270 -880 0 0 {name=M1
L=0.15
W=0.5
nf=1 mult=1
model=nfet_01v8
spiceprefix=X
 lvs_format=" "}
C {devices/lab_pin} 290 -930 0 1 {name=l8 lab=VTH2}
C {devices/lab_pin} 290 -800 0 0 {name=p32 lab=VSS}
C {devices/isource} 290 -990 0 0 {name=I1 value=100n
lvs_format=" "}
C {devices/lab_pin} 290 -1060 0 0 {name=p33 lab=VSS}
