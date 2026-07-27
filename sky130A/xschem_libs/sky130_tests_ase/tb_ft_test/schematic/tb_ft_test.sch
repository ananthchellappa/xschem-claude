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
T {Transistor ft measurement} 20 -710 0 0 0.8 0.8 {}
T {AC simulation.
M1 gate current and
M1 drain current
vs frequency.
ft is at the Xpoint.} 830 -710 0 1 0.3 0.3 {layer=15}
T {ft calculated as
gm / [2π (Cgg + Cgdo + Cgso)]
vs bias current} 830 -430 0 1 0.3 0.3 {layer=15}
T {@spice_get_current} 257.5 -415 0 1 0.2 0.2 {layer=17
name=L2}
T {@name} 265 -468.75 0 0 0.2 0.2 {name=L2}
T {@value} 265 -456.25 0 0 0.2 0.2 {name=L2}
T {m=@m} 265 -443.75 0 0 0.2 0.2 {name=L2}
N 30 -540 30 -110 { lab=GND}
N 30 -540 180 -540 { lab=GND}
N 30 -110 470 -110 { lab=GND}
N 470 -270 470 -110 {lab=GND}
N 470 -350 470 -330 {lab=#net1}
N 180 -540 180 -500 {lab=GND}
N 180 -440 180 -430 { lab=G}
N 180 -270 180 -110 {lab=GND}
N 220 -300 310 -300 {lab=G}
N 260 -340 260 -300 {lab=G}
N 180 -340 260 -340 {lab=G}
N 180 -430 180 -330 {lab=G}
N 180 -420 250 -420 {lab=G}
N 470 -420 470 -410 {lab=D}
N 410 -470 470 -470 {lab=D}
N 470 -470 470 -420 {lab=D}
N 370 -420 370 -400 {lab=GND}
N 370 -400 410 -400 {lab=GND}
N 410 -410 410 -390 {lab=GND}
N 340 -460 370 -460 {lab=#net2}
N 340 -460 340 -420 {lab=#net2}
N 310 -420 340 -420 {lab=#net2}
N 310 -300 350 -300 {lab=G}
N 410 -300 430 -300 {lab=#net3}
C {sky130_fd_pr/nfet3_01v8_lvt} 450 -300 0 0 {name=M_DUT
L=0.15
W=10
nf=1 
mult=1
body=GND
model=nfet_01v8_lvt
spiceprefix=X
}
C {devices/isource} 180 -470 0 1 {name=Idref value="dc 3m AC 1 0"}
C {devices/gnd} 470 -110 0 0 {name=l1 lab=GND}
C {devices/lab_wire} 260 -340 0 0 {name=l3 sig_type=std_logic lab=G}
C {devices/title} 160 -30 0 0 {name=l4 author="Rafael Marinho"}
C {sky130_fd_pr/annotate_fet_params} 460 -232.6817735695556 0 1 {name=annot1 ref=M_DUT}
C {devices/ammeter} 470 -380 0 0 {name=Vd savecurrent=true spice_ignore=0}
C {devices/ammeter} 380 -300 3 0 {name=Vg savecurrent=true spice_ignore=0}
C {sky130_fd_pr/nfet3_01v8_lvt} 200 -300 0 1 {name=M_BIAS
L=0.15
W=10
nf=1 
mult=1
body=GND
model=nfet_01v8_lvt
spiceprefix=X
}
C {devices/ind} 280 -420 1 0 {name=L2
m=1
value=1
footprint=1206
device=inductor
hide_texts=true
attach=L2}
C {devices/parax_cap} 330 -410 0 0 {name=C1 gnd=GND value=1 m=1}
C {devices/vcvs} 410 -440 0 0 {name=E1 value=1}
C {devices/gnd} 410 -390 0 0 {name=l5 lab=GND}
C {devices/lab_wire} 470 -470 0 0 {name=l6 sig_type=std_logic lab=D}
C {sky130_fd_pr/annotate_fet_params} 170 -232.6817735695556 0 1 {name=annot2 ref=M_BIAS}
