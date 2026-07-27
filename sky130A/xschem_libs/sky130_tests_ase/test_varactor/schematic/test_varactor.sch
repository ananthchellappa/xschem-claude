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
N 350 -820 350 -790 { lab=0}
N 350 -670 350 -600 { lab=G1}
N 350 -540 350 -450 { lab=0}
N 480 -600 480 -580 { lab=REF}
N 480 -670 480 -660 { lab=G1}
N 350 -670 480 -670 { lab=G1}
N 80 -820 80 -790 { lab=0}
N 80 -670 80 -620 { lab=G}
N 50 -490 50 -460 { lab=0}
N 210 -600 210 -580 { lab=REF}
N 210 -670 210 -660 { lab=G}
N 80 -670 210 -670 { lab=G}
N 80 -730 80 -670 { lab=G}
N 350 -730 350 -670 { lab=G1}
N 50 -580 50 -490 { lab=0}
N 80 -490 110 -490 { lab=0}
N 110 -580 110 -490 { lab=0}
N 80 -580 80 -490 { lab=0}
N 30 -420 30 -400 { lab=REF}
N 600 -820 600 -790 { lab=0}
N 600 -670 600 -600 { lab=G2}
N 600 -540 600 -510 { lab=#net1}
N 730 -600 730 -580 { lab=REF}
N 730 -670 730 -660 { lab=G2}
N 600 -670 730 -670 { lab=G2}
N 600 -730 600 -670 { lab=G2}
N 50 -490 80 -490 { lab=0}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {devices/lab_pin} 350 -630 0 0 {name=p4 lab=G1}
C {devices/isource} 350 -760 0 0 {name=I1 value="pwl 0 0 1p 100n"}
C {devices/lab_pin} 350 -820 0 0 {name=p1 lab=0}
C {devices/lab_pin} 350 -450 0 0 {name=p2 lab=0}
C {devices/res} 480 -630 0 0 {name=R1
value=100G
footprint=1206
device=resistor
m=1}
C {devices/lab_pin} 480 -580 0 0 {name=p5 lab=REF}
C {devices/lab_pin} 80 -640 0 0 {name=p6 lab=G}
C {devices/isource} 80 -760 0 0 {name=I2 value="pwl 0 0 1p 100n"}
C {devices/lab_pin} 80 -820 0 0 {name=p7 lab=0}
C {devices/lab_pin} 50 -460 0 0 {name=p8 lab=0}
C {devices/res} 210 -630 0 0 {name=R2
value=100G
footprint=1206
device=resistor
m=1}
C {devices/lab_pin} 210 -580 0 0 {name=p10 lab=REF}
C {devices/vsource} 30 -370 0 0 {name=V1 value=-2.1}
C {devices/lab_pin} 30 -340 0 0 {name=p14 lab=0}
C {devices/lab_pin} 30 -420 0 1 {name=p15 lab=REF}
C {sky130_fd_pr/cap_var_lvt} 350 -570 0 0 {name=C4 model=cap_var_lvt W=5 L=5 VM=1 spiceprefix=X}
C {devices/lab_pin} 310 -550 0 0 {name=p20 lab=0}
C {sky130_fd_pr/pfet_01v8} 80 -600 1 0 {name=M2
L=5
W=5
nf=1
mult=1
model=pfet_01v8
spiceprefix=X
}
C {devices/lab_pin} 600 -630 0 0 {name=p4 lab=G2}
C {devices/isource} 600 -760 0 0 {name=I3 value="pwl 0 0 1p 100n"}
C {devices/lab_pin} 600 -820 0 0 {name=p1 lab=0}
C {devices/lab_pin} 600 -450 0 0 {name=p2 lab=0}
C {devices/res} 730 -630 0 0 {name=R3
value=100G
footprint=1206
device=resistor
m=1}
C {devices/lab_pin} 730 -580 0 0 {name=p5 lab=REF}
C {sky130_fd_pr/cap_var_lvt} 600 -570 0 0 {name=C1 model=cap_var_lvt W=5 L=5 VM=1 spiceprefix=X}
C {devices/lab_pin} 560 -550 0 0 {name=p20 lab=0}
C {devices/vsource} 600 -480 0 0 {name=V3 value=1.8}
C {devices/ngspice_probe} 620 -670 0 0 {name=r4}
C {devices/ngspice_probe} 370 -670 0 0 {name=r4}
C {devices/ngspice_probe} 100 -670 0 0 {name=r4}
