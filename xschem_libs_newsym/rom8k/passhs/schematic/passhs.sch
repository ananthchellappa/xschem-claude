v {xschem version=3.4.5 file_version=1.2
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
N 510 -350 510 -170 {lab=Z}
N 450 -350 450 -170 {lab=A}
N 480 -130 480 -110 {lab=E}
N 420 -110 480 -110 {lab=E}
N 420 -290 450 -290 {lab=A}
N 480 -410 480 -390 {lab=EN}
N 420 -410 480 -410 {lab=EN}
N 510 -290 540 -290 {lab=Z}
N 480 -350 480 -320 {lab=VCCPIN}
N 480 -210 480 -170 {lab=VSSPIN}
C {rom8k/p} 480 -370 3 1 {name=m60 model=cmosp w=WP l=2.4u m=1
}
C {rom8k/n} 480 -150 3 0 {name=m1 model=cmosn w=WN l=2.4u m=1}
C {devices/iopin} 540 -290 0 0 {name=p1 lab=Z}
C {devices/iopin} 420 -290 0 1 {name=p2 lab=A}
C {devices/ipin} 420 -410 0 0 {name=p3 lab=EN}
C {devices/ipin} 420 -110 0 0 {name=p4 lab=E}
C {devices/lab_pin} 480 -320 3 0 {name=l1 sig_type=std_logic lab=VCCPIN}
C {devices/lab_pin} 480 -210 3 1 {name=l2 sig_type=std_logic lab=VSSPIN}
C {devices/title} 160 0 0 0 {name=l3 author="Stefan Schippers"}
C {devices/noconn} 480 -210 2 0 {name=l4}
C {devices/noconn} 480 -320 2 0 {name=l5}
