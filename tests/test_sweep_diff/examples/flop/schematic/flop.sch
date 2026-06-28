v {xschem version=3.4.4 file_version=1.2
*
* This file is part of XSCHEM,
* a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
* simulation.
* Copyright (C) 1998-2024 Stefan Frederik Schippers
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 2 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
}
G {}
V {}
S {}
E {}
N 170 -320 220 -320 {lab=#net1}
N 400 -340 480 -340 {lab=#net2}
C {devices/ipin} 240 -160 0 0 {name=p0 lab=D}
C {devices/opin} 540 -160 0 0 {name=p2 lab=Q}
C {devices/ipin} 240 -110 0 0 {name=p4 lab=VSS}
C {devices/ipin} 240 -140 0 0 {name=p1 lab=CK}
C {examples/inv_bsource} 130 -320 0 0 {name=B5 TABLE="'VTH-0.1' VHI 'VTH+0.1' 0"}
C {devices/lab_pin} 130 -290 0 0 {name=p5 lab=VSS}
C {devices/lab_pin} 220 -340 0 0 {name=p10 lab=D}
C {examples/dlatch} 310 -330 0 0 {name=x5 VTH=VTH VHI=VHI}
C {devices/lab_pin} 90 -320 0 0 {name=p11 lab=CK}
C {devices/lab_pin} 480 -320 0 0 {name=p12 lab=CK}
C {devices/lab_pin} 220 -300 0 0 {name=p13 lab=VSS}
C {devices/lab_pin} 480 -300 0 0 {name=p14 lab=VSS}
C {devices/lab_pin} 660 -340 0 1 {name=p15 lab=Q}
C {examples/dlatch} 570 -330 0 0 {name=x1 VTH=VTH VHI=VHI}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
