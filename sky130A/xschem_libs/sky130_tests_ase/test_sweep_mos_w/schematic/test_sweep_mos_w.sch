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
T {Use 't' key with mouse close
to a waveform to see only
that waveform and related
annotated data.} 600 -640 0 1 0.2 0.2 {}
N 860 -190 860 -100 {
lab=GND}
N 640 -100 860 -100 {
lab=GND}
N 640 -160 640 -100 {
lab=GND}
N 740 -160 740 -100 {
lab=GND}
N 740 -220 820 -220 {
lab=G}
N 640 -310 640 -220 {
lab=D}
N 640 -310 860 -310 {
lab=D}
N 860 -310 860 -250 {
lab=D}
N 860 -220 960 -220 {
lab=GND}
N 960 -220 960 -100 {
lab=GND}
N 860 -100 960 -100 {
lab=GND}
C {devices/vsource} 740 -190 0 0 {name=V1 value=1}
C {devices/vsource} 640 -190 0 0 {name=V2 value=1.8}
C {devices/gnd} 640 -100 0 0 {name=l1 lab=GND}
C {devices/lab_wire} 790 -310 0 0 {name=p1 sig_type=std_logic lab=D}
C {devices/lab_wire} 790 -220 0 0 {name=p2 sig_type=std_logic lab=G}
C {devices/title} 160 -30 0 0 {name=l2 author="Stefan Schippers"}
C {sky130_fd_pr/nfet_01v8} 840 -220 0 0 {name=M1
L=0.15
W=WN
nf=1 
mult=1
model=nfet_01v8
spiceprefix=X
}
C {devices/ngspice_get_value} 930 -310 0 1 {name=r11 node=v(@m.xm1.msky130_fd_pr__nfet_01v8[w])
descr="W="}
C {sky130_fd_pr/annotate_fet_params} 950 -340 0 0 {name=annot1 ref=M1}
