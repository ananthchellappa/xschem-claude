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
* limitations under the License.

}
G {}
K {}
V {}
S {}
E {}
L 4 740 -550 1110 -550 {}
L 4 1110 -550 1120 -540 {}
L 4 730 -540 740 -550 {}
T {This schematic contains annotators, ngspice_probe,
ngspice_get_value and ngspice_get_expr.
By using the $\{path\} expression instead of the
hierarchy path of this circuit you ensure 
multiple instances (even at different hierarchy
levels) will display each their own data.} 660 -750 0 0 0.4 0.4 {}
T {only_toplevel=true attribute set, 
will be netlisted only if toplevel cell} 830 -580 0 0 0.2 0.2 {layer=4}
N 180 -590 180 -530 { lab=#net1}
N 470 -580 470 -530 { lab=OUT}
N 470 -720 470 -680 { lab=VDD}
N 180 -720 470 -720 { lab=VDD}
N 180 -720 180 -680 { lab=VDD}
N 180 -470 180 -420 { lab=S}
N 410 -420 470 -420 { lab=S}
N 470 -470 470 -420 { lab=S}
N 240 -650 430 -650 { lab=#net1}
N 240 -650 240 -590 { lab=#net1}
N 180 -590 240 -590 { lab=#net1}
N 100 -500 140 -500 { lab=PLUS}
N 510 -500 550 -500 { lab=MINUS}
N 470 -580 630 -580 { lab=OUT}
N 320 -190 320 -160 { lab=GND}
N 240 -220 280 -220 { lab=NBIAS}
N 410 -420 410 -370 { lab=S}
N 850 -530 850 -500 { lab=PLUS}
N 940 -530 940 -500 { lab=NBIAS}
N 750 -530 750 -500 { lab=MINUS}
N 320 -330 320 -250 { lab=#net2}
N 320 -420 320 -390 { lab=S}
N 220 -650 240 -650 { lab=#net1}
N 180 -620 180 -590 { lab=#net1}
N 470 -620 470 -580 { lab=OUT}
N 320 -420 410 -420 { lab=S}
N 180 -420 320 -420 { lab=S}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {sky130_fd_pr/nfet3_01v8_lvt} 160 -500 0 0 {name=M1
L=0.3
W=2
body=GND
nf=1
mult=1
model=nfet_01v8_lvt
spiceprefix=X}
C {sky130_fd_pr/nfet3_01v8_lvt} 490 -500 0 1 {name=M2
L=0.3
W=2
body=GND
nf=1
mult=1
model=nfet_01v8_lvt
spiceprefix=X
}
C {sky130_fd_pr/pfet3_01v8_lvt} 450 -650 0 0 {name=M3
L=0.8
W=4
body=VDD
nf=1
mult=1
model=pfet_01v8_lvt
spiceprefix=X
}
C {sky130_fd_pr/pfet3_01v8_lvt} 200 -650 0 1 {name=M4
L=0.8
W=4
body=VDD
nf=1
mult=1
model=pfet_01v8_lvt
spiceprefix=X
}
C {devices/gnd} 320 -160 0 0 {name=l2 lab=GND}
C {devices/vdd} 350 -720 0 0 {name=l3 lab=VDD}
C {devices/ipin} 100 -500 0 0 {name=p4 sig_type=std_logic lab=PLUS}
C {devices/ipin} 550 -500 0 1 {name=p1 sig_type=std_logic lab=MINUS}
C {devices/opin} 630 -580 0 0 {name=p2 sig_type=std_logic lab=OUT}
C {sky130_fd_pr/nfet3_01v8} 300 -220 0 0 {name=M5
L=1.2
W=0.7
body=GND
nf=1
mult=1
model=nfet_01v8
spiceprefix=X
}
C {devices/ipin} 240 -220 0 0 {name=p3 sig_type=std_logic lab=NBIAS}
C {devices/lab_pin} 470 -420 0 1 {name=l4 sig_type=std_logic lab=S}
C {sky130_fd_pr/res_xhigh_po_0p35} 410 -340 0 0 {name=R1
W=0.35
L=50
model=res_xhigh_po_0p35
spiceprefix=X
mult=1}
C {devices/gnd} 410 -310 0 0 {name=l18 lab=GND}
C {devices/gnd} 390 -340 0 1 {name=l19 lab=GND}
C {devices/ngspice_get_value} 450 -360 0 0 {name=r9 node=i(@b.$\{path\}xr1.x0.brbody[i])
descr="I="}
C {devices/vsource} 850 -470 0 0 {name=V1 value=0.7 only_toplevel=true}
C {devices/gnd} 850 -440 0 0 {name=l9 lab=GND}
C {devices/lab_pin} 850 -530 0 1 {name=l10 sig_type=std_logic lab=PLUS}
C {devices/vsource} 940 -470 0 0 {name=V2 value=0.9 only_toplevel=true}
C {devices/gnd} 940 -440 0 0 {name=l11 lab=GND}
C {devices/lab_pin} 940 -530 0 1 {name=l12 sig_type=std_logic lab=NBIAS}
C {devices/vsource} 1090 -470 0 0 {name=V3 value=1.8 only_toplevel=true}
C {devices/gnd} 1090 -440 0 0 {name=l13 lab=GND}
C {devices/vdd} 1090 -500 0 0 {name=l14 lab=VDD}
C {devices/vsource} 750 -470 0 0 {name=V4 value=0.7 only_toplevel=true}
C {devices/gnd} 750 -440 0 0 {name=l5 lab=GND}
C {devices/lab_pin} 750 -530 0 1 {name=l6 sig_type=std_logic lab=MINUS}
C {devices/ngspice_get_expr} 1070 -470 0 1 {name=r10 node="[ngspice::get_current v3]"}
C {devices/ammeter} 320 -360 0 0 {name=V5}
C {devices/ngspice_get_expr} 400 -160 0 1 {name=r2 node="[to_eng [ngspice::get_current \{xm5.msky130_fd_pr__nfet_01v8[id]\}] * [ngspice::get_voltage s] ]W"
descr="power"}
C {sky130_fd_pr/annotate_fet_params} 180 -340 0 0 {name=annot5 ref=M5}
C {sky130_fd_pr/annotate_fet_params} 120 -470 0 1 {name=annot3 ref=M1}
C {sky130_fd_pr/annotate_fet_params} 540 -470 0 0 {name=annot4 ref=M2}
C {sky130_fd_pr/annotate_fet_params} 170 -810 0 1 {name=annot1 ref=M4}
C {sky130_fd_pr/annotate_fet_params} 490 -810 0 0 {name=annot2 ref=M3}
