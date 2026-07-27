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
* limitations under the License.}
G {}
K {}
V {}
S {}
E {}
N 810 -190 810 -100 {
lab=GND}
N 590 -100 810 -100 {
lab=GND}
N 590 -160 590 -100 {
lab=GND}
N 590 -310 590 -220 {
lab=D}
N 590 -310 810 -310 {
lab=D}
N 810 -310 810 -250 {
lab=D}
N 790 -220 790 -190 {
lab=GND}
N 790 -190 810 -190 {
lab=GND}
C {devices/vsource} 590 -190 0 0 {name=V2 value=1.8}
C {devices/gnd} 590 -100 0 0 {name=l1 lab=GND}
C {devices/lab_wire} 740 -310 0 0 {name=p1 sig_type=std_logic lab=D}
C {devices/title} 160 -30 0 0 {name=l2 author="Stefan Schippers"}
C {sky130_fd_pr/res_high_po_0p69} 810 -220 0 0 {name=R1
L=\{L\}
model=res_high_po_0p69
spiceprefix=X
mult=1}
