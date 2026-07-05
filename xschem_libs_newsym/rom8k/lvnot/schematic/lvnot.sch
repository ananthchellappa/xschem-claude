v {xschem version=3.4.8RC file_version=1.3
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
G {
y <= not a after 0.1 ns ;}
K {type=subcircuit
function0="1 ~"
vhdl_stop=true
verilog_stop=true
format="@name @pinlist @VCCPIN @VSSPIN @symname wn=@wn lln=@lln wp=@wp lp=@lp m=@m"
template="name=x1 m=1 
+ wn=10u lln=1.2u wp=10u lp=1.2u 
+ VCCPIN=VCC VSSPIN=VSS"
extra="VCCPIN VSSPIN"
generic_type="m=integer wn=real lln=real wp=real lp=real VCCPIN=string VSSPIN=string"
verilog_stop=true}
V {assign #150 y=~a ;}
S {}
F {}
E {}
P 4 5 350 -440 350 -70 480 -70 480 -440 350 -440 {dash=4}
T {@name x @m} 353.75 -455 0 0 0.2 0.2 {}
T {@symname} 486.25 -455 0 1 0.2 0.2 {}
N 420 -260 480 -260 {lab=y}
N 380 -370 380 -140 {lab=a}
N 350 -260 380 -260 {lab=a}
N 420 -370 470 -370 {lab=VCCPIN}
N 470 -400 470 -370 {lab=VCCPIN}
N 420 -400 470 -400 {lab=VCCPIN}
N 420 -140 470 -140 {lab=VSSPIN}
N 470 -140 470 -110 {lab=VSSPIN}
N 420 -110 470 -110 {lab=VSSPIN}
N 420 -420 420 -400 {lab=VCCPIN}
N 420 -110 420 -90 {lab=VSSPIN}
N 420 -340 420 -330 {lab=DP}
N 420 -270 420 -240 {lab=y}
N 420 -180 420 -170 {lab=DN}
C {devices/opin} 480 -260 0 0 {name=p1 lab=y verilog_type=wire}
C {devices/ipin} 350 -260 0 0 {name=p2 lab=a}
C {devices/use} 300 -600 0 0 {------------------------------------------------
library ieee;
        use ieee.std_logic_1164.all;
--         use ieee.std_logic_arith.all;
--         use ieee.std_logic_unsigned.all;

-- library SYNOPSYS;
--         use SYNOPSYS.ATTRIBUTES.ALL;
}
C {rom8k/p} 400 -370 0 0 {name=m2 model=cmosp w=wp l=lp  m=1 }
C {devices/lab_pin} 420 -420 0 0 {name=p149 lab=VCCPIN}
C {devices/lab_pin} 420 -90 0 0 {name=p3 lab=VSSPIN}
C {rom8k/n} 400 -140 0 0 {name=m1 model=cmosn w=wn l=lln m=1}
C {devices/title} 160 0 0 0 {name=l3 author="Stefan Schippers"}
C {devices/verilog_timescale} 660 -217.5 0 0 {name=s1 timestep="1ps" precision="1ps" }
C {devices/ammeter} 420 -300 0 0 {name=Vmeas savecurrent=true spice_ignore=0}
C {devices/ammeter} 420 -210 0 0 {name=Vmeas1 savecurrent=true spice_ignore=0}
C {devices/lab_pin} 420 -180 0 0 {name=p4 sig_type=std_logic lab=DN}
C {devices/lab_pin} 420 -330 0 0 {name=p5 sig_type=std_logic lab=DP}
C {devices/spice_probe} 420 -330 2 0 {name=p95 analysis=tran}
C {devices/spice_probe} 420 -180 0 1 {name=p6 analysis=tran}
