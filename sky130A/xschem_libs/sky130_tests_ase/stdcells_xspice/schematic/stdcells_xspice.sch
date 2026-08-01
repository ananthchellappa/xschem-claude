v {xschem version=3.4.0 file_version=1.2
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
T {xspice used "code" models are defined in top level.} 10 -280 0 0 0.5 0.5 {}
T {xspice netlist obtained from qflow's spi2xspice.py} 10 -320 0 0 0.5 0.5 {}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {devices/ipin} 250 -560 0 0 { name=p1 lab=RESET_B }
C {devices/ipin} 250 -580 0 0 { name=p2 lab=CLK }
C {devices/ipin} 250 -600 0 0 { name=p3 lab=B }
C {devices/ipin} 250 -620 0 0 { name=p4 lab=A }
C {devices/opin} 360 -590 0 0 { name=p1 lab=Y }
C {devices/opin} 360 -610 0 0 { name=p2 lab=X }
C {devices/opin} 360 -630 0 0 { name=p3 lab=QLATCH}
C {devices/opin} 360 -570 0 0 { name=p1 lab=Q }
C {devices/opin} 360 -550 0 0 { name=p1 lab=XSCHEM }
C {devices/ipin} 250 -490 0 0 { name=p1 lab=VCC }
C {devices/ipin} 250 -470 0 0 { name=p1 lab=VSS }
C {devices/noconn} 250 -620 0 1 {name=l2}
C {devices/noconn} 250 -600 0 1 {name=l3}
C {devices/noconn} 250 -580 0 1 {name=l4}
C {devices/noconn} 250 -560 0 1 {name=l5}
C {devices/noconn} 250 -490 0 1 {name=l6}
C {devices/noconn} 250 -470 0 1 {name=l7}
C {devices/noconn} 360 -630 0 0 {name=l8}
C {devices/noconn} 360 -610 0 0 {name=l9}
C {devices/noconn} 360 -590 0 0 {name=l10}
C {devices/noconn} 360 -570 0 0 {name=l11}
C {devices/noconn} 360 -550 0 0 {name=l12}
