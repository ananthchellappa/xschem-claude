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
N 340 -260 340 -230 {
lab=GND}
N 340 -380 340 -320 {
lab=in}
N 690 -260 690 -230 {
lab=GND}
N 690 -380 690 -320 {
lab=out}
N 690 -390 690 -380 {
lab=out}
N 370 -400 370 -380 {
lab=in}
N 370 -380 500 -380 {
lab=in}
N 560 -380 690 -380 {
lab=out}
N 340 -380 370 -380 {
lab=in}
C {devices/title} 160 -30 0 0 {name=l1 author="Copyright 2023 IHP PDK Authors"}
C {devices/vsource} 340 -290 0 0 {name=V1 value="dc 0 ac 1"}
C {devices/gnd} 340 -230 0 0 {name=l4 lab=GND}
C {devices/res} 690 -290 0 0 {name=R2
value=100k
footprint=1206
device=resistor
m=1}
C {devices/gnd} 690 -230 0 0 {name=l5 lab=GND}
C {devices/lab_pin} 370 -400 1 0 {name=p1 sig_type=std_logic lab=in}
C {devices/lab_pin} 690 -390 1 0 {name=p2 sig_type=std_logic lab=out}
C {sg13g2_pr/cap_cmim} 530 -380 1 0 {name=C1 model=cap_cmim w=10.0e-6 l=70.0e-6 m=1 spiceprefix=X}
