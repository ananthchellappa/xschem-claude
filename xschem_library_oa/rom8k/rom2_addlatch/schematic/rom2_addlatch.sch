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
N 320 -490 380 -490 {lab=LDCP_B}
N 320 -490 320 -280 {lab=LDCP_B}
N 320 -280 380 -280 {lab=LDCP_B}
N 270 -490 320 -490 {lab=LDCP_B}
N 190 -340 380 -340 {lab=LDEN}
N 580 -340 610 -340 {lab=LDEN_LAT}
N 540 -340 580 -340 {lab=LDEN_LAT}
N 540 -550 600 -550 {lab=#net1}
N 760 -550 760 -450 {lab=LDAI[12:0]}
N 680 -550 680 -450 {lab=#net2}
C {rom8k/LD2QHDX4stef} 460 -510 0 0 {name=x0[12:0]}
C {devices/lab_pin} 380 -550 0 0 {name=p30 lab=LDA[12:0]}
C {devices/lab_pin} 430 -440 3 0 {name=p33 lab=VCC}
C {devices/lab_pin} 450 -440 3 0 {name=p34 lab=VSS}
C {devices/lab_pin} 470 -440 3 0 {name=p35 lab=VCC}
C {devices/lab_pin} 490 -440 3 0 {name=p36 lab=VSS}
C {rom8k/lvnot} 720 -550 0 0 {name=x9[12:0] m=1 
+ wn=24u lln=2.4u wp=80u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {devices/lab_pin} 760 -550 0 1 {name=p38 lab=LDAI[12:0]}
C {rom8k/lvnot} 640 -550 0 0 {name=x10[12:0] m=1 
+ wn=16u lln=2.4u wp=40u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {rom8k/LD2QHDX4stef} 460 -300 0 0 {name=x3}
C {devices/lab_pin} 430 -230 3 0 {name=p10 lab=VCC}
C {devices/lab_pin} 450 -230 3 0 {name=p18 lab=VSS}
C {devices/lab_pin} 470 -230 3 0 {name=p19 lab=VCC}
C {devices/lab_pin} 490 -230 3 0 {name=p21 lab=VSS}
C {devices/lab_pin} 190 -340 0 0 {name=p22 lab=LDEN}
C {devices/lab_pin} 380 -260 0 0 {name=p23 lab=VCC}
C {devices/lab_pin} 610 -340 0 1 {name=p24 lab=LDEN_LAT}
C {devices/lab_pin} 270 -490 0 0 {name=p15 lab=LDCP_B}
C {devices/title} 170 0 0 0 {name=l3 author="Stefan Schippers"}
C {devices/opin} 250 -160 0 0 { name=p2 lab=LDEN_LAT }
C {devices/opin} 250 -120 0 0 { name=p6 lab=LDAI[12:0] }
C {devices/ipin} 180 -190 0 0 { name=p1 lab=LDEN }
C {devices/ipin} 180 -170 0 0 { name=p3 lab=LDCP_B }
C {devices/ipin} 180 -150 0 0 { name=p4 lab=LDA[12:0] }
C {devices/ipin} 180 -130 0 0 { name=p7 lab=VCC }
C {devices/ipin} 180 -110 0 0 { name=p8 lab=VSS }
C {devices/lab_pin} 380 -470 0 0 {name=p9 lab=VCC}
C {rom8k/lvnot} 720 -450 0 0 {name=x1[12:0] m=1 
+ wn=24u lln=2.4u wp=80u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
