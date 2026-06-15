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
K {}
V {}
S {}
E {}
N 420 -320 640 -320 { lab=S[5:0]}
N 760 -320 810 -320 { lab=COUNT[5:0]}
N 800 -350 800 -320 { lab=COUNT[5:0]}
N 280 -350 800 -350 { lab=COUNT[5:0]}
N 280 -350 280 -320 { lab=COUNT[5:0]}
N 420 -300 460 -300 { lab=COUT[5:0]}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {devices/lab_wire} 520 -320 0 1 {name=l42 lab=S[5:0]}
C {devices/lab_pin} 460 -300 0 1 {name=p43 lab=COUT[5:0]}
C {ngspice/flip_flop_ngspice} 700 -300 0 0 {name=x2[5:0]}
C {devices/lab_pin} 810 -320 0 1 {name=p11 lab=COUNT[5:0]}
C {devices/lab_pin} 640 -300 0 0 {name=p13 lab=CK}
C {devices/lab_pin} 640 -280 0 0 {name=p14 lab=RST}
C {ngspice/half_adder_ngspice} 350 -310 0 0 {name=x1[5:0]}
C {devices/lab_pin} 280 -300 0 0 {name=p5 lab=COUT[4:0],D}
C {devices/ipin} 120 -120 0 0 { name=p1 lab=RST }
C {devices/ipin} 120 -140 0 0 { name=p2 lab=D}
C {devices/opin} 220 -160 0 0 { name=p4 lab=COUNT[5:0] }
C {devices/ipin} 120 -160 0 0 { name=p6 lab=CK }
