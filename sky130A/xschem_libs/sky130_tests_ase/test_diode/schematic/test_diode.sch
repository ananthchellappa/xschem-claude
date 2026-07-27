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
T {Available models:
sky130_fd_pr__diode_pw2nd_05v5
sky130_fd_pr__diode_pw2nd_11v0
sky130_fd_pr__diode_pw2nd_05v5_nvt
sky130_fd_pr__diode_pw2nd_05v5_lvt
sky130_fd_pr__diode_pd2nw_05v5
sky130_fd_pr__diode_pd2nw_11v0
sky130_fd_pr__diode_pd2nw_05v5_hvt
sky130_fd_pr__diode_pd2nw_05v5_lvt
sky130_fd_pr__model__parasitic__rf_diode_ps2nw
sky130_fd_pr__model__parasitic__rf_diode_pw2dn
sky130_fd_pr__model__parasitic__diode_pw2dn
sky130_fd_pr__model__parasitic__diode_ps2dn
sky130_fd_pr__model__parasitic__diode_ps2nw} 500 -360 0 0 0.2 0.2 {}
T {Available_models:
sky130_fd_pr__diode_pw2nd_05v5
sky130_fd_pr__diode_pw2nd_11v0
sky130_fd_pr__diode_pd2nw_05v5
sky130_fd_pr__diode_pd2nw_11v0
sky130_fd_pr__model__parasitic__diode_ps2dn} 950 -280 0 0 0.2 0.2 {}
T {Not clear what are the geometrical
units. Area=1e12 ? should be
Area=1 for a 1um x 1um device,
according to global SCALE 
parameter.} 390 -780 0 0 0.5 0.5 {layer=7}
N 400 -390 400 -360 { lab=0}
N 400 -240 400 -170 { lab=K1}
N 400 -110 400 -80 { lab=0}
N 900 -390 900 -360 { lab=0}
N 900 -240 900 -170 { lab=K2}
N 900 -110 900 -80 { lab=0}
N 1440 -390 1440 -360 { lab=0}
N 1440 -240 1440 -170 { lab=K3}
N 1440 -110 1440 -80 { lab=0}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {devices/lab_pin} 400 -200 0 0 {name=p4 lab=K1}
C {devices/isource} 400 -330 2 0 {name=I1 value="dc 0 pwl 0 0 5n 0 6n 10u 10n 10u 12n -10u 16n -10u 17n 0"
}
C {devices/lab_pin} 400 -390 0 0 {name=p1 lab=0}
C {sky130_fd_pr/diode} 400 -140 0 0 {name=D1
model=diode_pw2nd_05v5
area=1e12
perim=4e6
}
C {devices/lab_pin} 400 -80 0 0 {name=p2 lab=0}
C {devices/lab_pin} 900 -200 0 0 {name=p3 lab=K2}
C {devices/lab_pin} 900 -390 0 0 {name=p5 lab=0}
C {devices/ammeter} 900 -270 0 0 {name=Vk2 }
C {sky130_fd_pr/lvsdiode} 900 -140 0 0 {name=D2
model=diode_pw2nd_11v0
area=1e12
perim=4e6}
C {devices/lab_pin} 900 -80 0 0 {name=p6 lab=0}
C {devices/cccs} 900 -330 0 0 {name=F1 vnam=vk1 value=1}
C {devices/ammeter} 400 -270 0 0 {name=Vk1 }
C {sky130_fd_pr/photodiode} 1440 -140 0 0 {name=D3
model=photodiode
}
C {devices/lab_pin} 1440 -200 0 0 {name=p7 lab=K3}
C {devices/lab_pin} 1440 -390 0 0 {name=p8 lab=0}
C {devices/ammeter} 1440 -270 0 0 {name=Vk3 }
C {devices/lab_pin} 1440 -80 0 0 {name=p9 lab=0}
C {devices/cccs} 1440 -330 0 0 {name=F2 vnam=vk1 value=1}
