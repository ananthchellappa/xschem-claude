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
L 4 250 -790 460 -790 {}
L 4 460 -800 460 -790 {}
L 4 460 -800 510 -790 {}
L 4 460 -780 510 -790 {}
L 4 460 -790 460 -780 {}
T {Id vs Length for
nfet_01v8, W=1, 
L=X-axis, 
Vds = Vgs = sweep
from 0.8 to 1.8 step 0.2
Vb = Vs = 0} 70 -540 0 0 0.5 0.5 {}
T {Vgs,Vds=0.8} 1040 -370 0 0 0.4 0.4 {layer=4}
T {Vgs,Vds=1.0} 1040 -400 0 0 0.4 0.4 {layer=5}
T {Vgs,Vds=1.2} 1040 -430 0 0 0.4 0.4 {layer=6}
T {Vgs,Vds=1.4} 1040 -470 0 0 0.4 0.4 {layer=7}
T {Vgs,Vds=1.6} 1040 -520 0 0 0.4 0.4 {layer=8}
T {Vgs,Vds=1.8} 1040 -570 0 0 0.4 0.4 {layer=9}
T {Binning (different models for W/L classes)
produce discontinuities} 10 -770 0 0 0.4 0.4 {}
N 730 -140 750 -140 {lab=B}
N 670 -140 690 -140 {lab=G}
N 730 -190 730 -170 {lab=#net1}
N 730 -110 730 -90 {lab=S}
N 730 -270 730 -250 { lab=D}
C {devices/lab_pin} 730 -90 0 1 {name=p16 lab=S}
C {devices/lab_pin} 750 -140 0 1 {name=p21 lab=B}
C {devices/ammeter} 730 -220 0 0 {name=Vd2  current=5.0094e-04}
C {devices/lab_pin} 670 -140 0 0 {name=p6 lab=G}
C {sky130_fd_pr/nfet_01v8} 710 -140 0 0 {name=M2
L=LENGTH
W=WIDTH
mult=1 nf=1
model=nfet_01v8
spiceprefix=X}
C {devices/lab_pin} 730 -270 0 0 {name=p1 lab=D}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {devices/lab_pin} 300 -170 0 0 { name=p3 lab=G }
C {devices/lab_pin} 300 -210 0 0 { name=p5 lab=B }
C {devices/noconn} 300 -210 0 1 {name=l2}
C {devices/noconn} 300 -170 0 1 {name=l3}
C {devices/code} 20 -190 0 0 {name=ASE_KEEP1
only_toplevel=true
value="
vd d 0 \{VGATE\}
vg g 0 \{VGATE\}
vs s 0 0
vb b 0 0
"}
