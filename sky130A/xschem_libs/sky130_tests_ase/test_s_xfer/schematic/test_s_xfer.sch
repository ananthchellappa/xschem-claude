v {xschem version=3.1.0 file_version=1.2
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
T {S-domain (Laplace transform) Transfer function 
using ngspice s_xfer code model} 110 -1070 0 0 1 1 {}
T {A voltage source has been used and customized to call the s_xfer model.} 130 -900 0 0 0.6 0.6 {}
N 140 -310 140 -260 {
lab=A}
N 140 -310 260 -310 {
lab=A}
N 320 -310 380 -310 {
lab=B}
C {devices/vsource} 290 -310 3 0 {name=A1 value=integrator
device_model="
.model integrator s_xfer(num_coeff=[1] den_coeff=[1 0] int_ic=[0] denormalized_freq=1e5)
"}
C {devices/gnd} 140 -200 0 0 {name=l1 lab=GND}
C {devices/lab_pin} 140 -310 0 0 {name=l1 sig_type=std_logic lab=A}
C {devices/lab_pin} 380 -310 0 1 {name=l1 sig_type=std_logic lab=B}
C {devices/vsource} 140 -230 0 0 {name=VIN value="pwl 0 0 1u 0 1.001u 1"}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
