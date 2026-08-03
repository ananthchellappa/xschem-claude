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
P 4 7 930 -390 930 -260 920 -260 930 -240 940 -260 930 -260 930 -390 {fill=true}
P 4 7 1110 -330 1110 -250 1100 -250 1110 -230 1120 -250 1110 -250 1110 -330 {fill=true}
T {Example of Mismatch simulation of a bandgap reference.
Variations are generated also on Vcc
Plot shows bandgap varying outputs before
and after the offset cancellation.} 10 -770 0 0 0.4 0.4 {}
T {Select one or more graphs (and no other objects)
and use arrow keys to zoom / pan waveforms} 290 -580 0 0 0.3 0.3 {}
T {Bandgap voltage after offset compensation} 950 -350 0 0 0.3 0.3 {layer=4}
T {Bandgap voltage before offset compensation} 820 -410 0 0 0.3 0.3 {layer=4}
T {tcleval(Dataset=[xschem getprop rect 2 0 dataset])} 1020 -790 0 0 0.7 0.7 {floater=xxx}
N 240 -340 240 -320 { lab=EN_N}
N 650 -340 650 -320 { lab=#net1}
N 390 -340 390 -320 { lab=VSS}
N 240 -220 240 -200 {lab=TEMPERAT}
N 390 -220 390 -200 { lab=START}
N 650 -220 650 -200 { lab=CLK}
N 240 -460 300 -460 {
lab=EN_N}
N 240 -440 300 -440 {
lab=VCC}
N 240 -420 300 -420 {
lab=VSS}
N 240 -500 300 -500 {
lab=START}
N 240 -480 300 -480 {
lab=CLK}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {sky130_tests_ase/bandgap} 450 -460 0 0 {name=x1}
C {devices/lab_pin} 600 -500 0 1 {name=p1 lab=VBG}
C {devices/lab_pin} 240 -460 0 0 {name=p2 lab=EN_N}
C {devices/vsource} 240 -290 0 0 {name=V1 value=0}
C {devices/lab_pin} 240 -340 0 1 {name=p3 lab=EN_N}
C {devices/vsource} 650 -290 0 0 {name=V2 value="dc 'VCC' pwl 0 0 1u 0 4u 'VCC'"}
C {devices/lab_pin} 650 -400 0 0 {name=l29 sig_type=std_logic lab=VCC}
C {devices/lab_pin} 240 -440 0 0 {name=p4 lab=VCC}
C {devices/lab_pin} 240 -420 0 0 {name=p5 lab=VSS}
C {devices/vsource} 390 -290 0 0 {name=V3 value=0}
C {devices/lab_pin} 390 -340 0 1 {name=l3 sig_type=std_logic lab=VSS}
C {devices/lab_pin} 240 -260 0 0 {name=l2 sig_type=std_logic lab=VSS}
C {devices/lab_pin} 650 -260 0 0 {name=l4 sig_type=std_logic lab=VSS}
C {devices/lab_pin} 390 -260 0 0 {name=l5 sig_type=std_logic lab=0}
C {devices/vsource_arith} 240 -170 0 0 {name=E5 VOL=temper MAX=200 MIN=-200}
C {devices/lab_pin} 240 -220 0 1 {name=p113 lab=TEMPERAT}
C {devices/lab_pin} 240 -140 0 0 {name=p114 lab=VSS}
C {devices/vsource} 390 -170 0 0 {name=V4 value="pwl 0 'VCC' 25u 'VCC' 25.001u 0"}
C {devices/lab_pin} 390 -220 0 1 {name=p7 lab=START}
C {devices/lab_pin} 390 -140 0 0 {name=l21 sig_type=std_logic lab=VSS}
C {devices/vsource} 650 -170 0 0 {name=V5
value1="dc 0 "
value="dc 0 pulse 
+ 'VCC' 0 
+ 25u
+ 1n 1n 
+ 27000n 30000n"
}
C {devices/lab_pin} 650 -140 0 0 {name=l6 sig_type=std_logic lab=VSS}
C {devices/lab_pin} 650 -220 0 1 {name=p6 lab=CLK}
C {devices/lab_pin} 240 -500 0 0 {name=p8 lab=START}
C {devices/lab_pin} 240 -480 0 0 {name=p9 lab=CLK}
C {devices/spice_probe} 600 -500 0 0 {name=p10 attrs=""}
C {devices/spice_probe} 300 -500 0 1 {name=p11 attrs=""}
C {devices/spice_probe} 300 -480 0 1 {name=p12 attrs=""}
C {devices/spice_probe} 300 -460 0 1 {name=p13 attrs=""}
C {devices/spice_probe} 300 -440 0 1 {name=p14 attrs=""}
C {devices/spice_probe} 300 -420 0 1 {name=p15 attrs=""}
C {devices/spice_probe} 240 -220 0 1 {name=p16 attrs=""}
C {devices/ammeter} 650 -370 2 0 {name=VCC}
