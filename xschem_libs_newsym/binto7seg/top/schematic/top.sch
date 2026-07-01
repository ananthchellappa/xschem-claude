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
T {REG} 40 -320 0 0 0.4 0.4 {}
T {WIRE} 220 -320 0 0 0.4 0.4 {}
T {Copyright (C) 2008 DJ Delorie (dj delorie com)
Distributed under the terms of the GNU General Public License,
either verion 2 or (at your choice) any later version.} 40 -150 0 0 0.4 0.4 {}
T {INPUTS} 50 -520 0 0 0.4 0.4 {}
T {OUTPUTS} 280 -460 0 0 0.4 0.4 {}
T {Binary to 7-segment chip} 660 -460 0 0 0.7 0.7 {}
N 500 -610 590 -610 {lab=bcd2[1:0]}
N 590 -630 590 -610 {lab=bcd2[1:0]}
N 590 -630 650 -630 {lab=bcd2[1:0]}
N 500 -590 650 -590 {lab=bcd1[3:0]}
N 500 -570 590 -570 {lab=bcd0[3:0]}
N 590 -570 590 -550 {lab=bcd0[3:0]}
N 590 -550 650 -550 {lab=bcd0[3:0]}
N 160 -610 200 -610 {lab=ibinh[7:0]}
C {devices/ipin} 110 -460 0 0 {name=p2 lab=nen}
C {devices/ipin} 110 -440 0 0 {name=p3 lab=en}
C {devices/ipin} 110 -420 0 0 {name=p4 lab=blank}
C {devices/ipin} 110 -380 0 0 {name=p5 lab=polarity}
C {devices/lab_pin} 950 -630 0 1 {name=l15 lab=oseg2t[6:0] verilog_type=reg}
C {devices/lab_pin} 950 -590 0 1 {name=l16 lab=oseg1t[6:0] verilog_type=reg}
C {devices/lab_pin} 950 -550 0 1 {name=l17 lab=oseg0t[6:0] verilog_type=reg}
C {devices/lab_pin} 280 -280 0 0 {name=l1 lab=bcd2[1:0]}
C {devices/lab_pin} 280 -260 0 0 {name=l2 lab=bcd1[3:0]}
C {devices/lab_pin} 280 -240 0 0 {name=l3 lab=bcd0[3:0]}
C {devices/lab_pin} 100 -280 0 0 {name=l4 lab=ibinh[7:0] verilog_type=reg}
C {devices/lab_pin} 100 -260 0 0 {name=l5 lab=blank2 verilog_type=reg}
C {devices/lab_pin} 100 -240 0 0 {name=l6 lab=blank1 verilog_type=reg}
C {devices/lab_pin} 100 -220 0 0 {name=l7 lab=blank0 verilog_type=reg}
C {devices/lab_pin} 100 -200 0 0 {name=l8 lab=lz2 verilog_type=reg}
C {devices/lab_pin} 100 -180 0 0 {name=l9 lab=lz1 verilog_type=reg}
C {devices/lab_pin} 280 -220 0 0 {name=l10 lab=oseg2t[6:0]}
C {devices/lab_pin} 280 -200 0 0 {name=l11 lab=oseg1t[6:0]}
C {devices/lab_pin} 280 -180 0 0 {name=l12 lab=oseg0t[6:0]}
C {binto7seg/sevenseg} 800 -590 0 0 {name=x1}
C {binto7seg/sevenseg012} 800 -630 0 0 {name=x2}
C {binto7seg/bcd} 350 -590 0 0 {name=x3}
C {binto7seg/sevenseg} 800 -550 0 0 {name=x4}
C {devices/lab_wire} 500 -610 0 1 {name=p9 lab=bcd2[1:0]}
C {devices/lab_pin} 160 -610 0 0 {name=l14 lab=ibinh[7:0]}
C {devices/lab_wire} 500 -590 0 1 {name=p11 lab=bcd1[3:0]}
C {devices/lab_wire} 500 -570 0 1 {name=p12 lab=bcd0[3:0]}
C {devices/code} 140 -480 0 0 {name=CODE value="// Copyright (C) 2008 DJ Delorie <dj delorie com>
// Distributed under the terms of the GNU General Public License,
// either verion 2 or (at your choice) any later version.

always @ (ibin, nen, en)
begin
  if (en & ~ nen)
    ibinh = ibin;
  else
    ibinh = ibinh;
end


always @ (bcd2, bcd1)
begin
  lz2 = (bcd2 == 0) ? 1 : 0;
  lz1 = (bcd1 == 0) ? lz2 : 0;
end

always @ (lz2, lz1, lzblank, blank)
begin
  blank2 = (lzblank & lz2) | blank;
  blank1 = (lzblank & lz1) | blank;
  blank0 = blank;
end

always @ (oseg2t, polarity, blank2)
begin
  if (blank2)
    oseg2 = 7'bZ;
  else if (polarity)
    oseg2 = ~ oseg2t;
  else
    oseg2 = oseg2t;
end

always @ (oseg1t, polarity, blank1, blank2)
begin
  if (blank1)
    oseg1 = 7'bZ;
  else if (polarity)
    oseg1 = ~ oseg1t;
  else
    oseg1 = oseg1t;
end

always @ (oseg0t, polarity, blank0)
begin
  if (blank0)
    oseg0 = 7'bZ;
  else if (polarity)
    oseg0 = ~ oseg0t;
  else
    oseg0 = oseg0t;
end
"}
C {devices/verilog_timescale} 350 -320 0 0 {name=s1 timestep="1ns" precision="1ps" }
C {devices/title} 160 -30 0 0 {name=l13 author="Stefan Schippers"}
C {devices/ipin} 110 -400 0 0 {name=p13 lab=lzblank}
C {devices/ipin} 110 -480 0 0 {name=p15 lab=ibin[7:0]}
C {devices/opin} 280 -420 0 0 {name=p6 lab=oseg2[6:0] verilog_type=reg}
C {devices/opin} 280 -400 0 0 {name=p7 lab=oseg1[6:0] verilog_type=reg}
C {devices/opin} 280 -380 0 0 {name=p8 lab=oseg0[6:0] verilog_type=reg}
C {devices/code} 790 -160 0 0 {name=TESTBENCH only_toplevel=false value="
reg [7:0] iibin;
reg ien;
reg inen;
reg iblank;
reg ilzblank;
reg ipolarity;

initial begin
  $dumpfile(\\"dumpfile.vcd\\");
  $dumpvars(0, top);
end

task binpattern;
begin
  iibin = 0;
  #100;
  iibin = 1;
  #100;
  iibin = 2;
  #100;
  iibin = 234;
  #100;
  iibin = 255;
  #100;
  iibin = 188;
  #100;
  iibin = 222;
  #100;
end endtask

initial begin
  ien = 1;
  inen = 0;
  iblank = 0;
  ilzblank = 0;
  ipolarity = 0;
  binpattern;
  ilzblank = 1; // blank leading zeros
  binpattern;
end

assign en = ien;
assign nen = inen;
assign ibin = iibin;
assign blank = iblank;
assign lzblank = ilzblank;
assign polarity = ipolarity;
"}
C {devices/launcher} 760 -390 0 0 {name=h1
descr="Ctrl-click to go to Delorie's 
project page for info" 
url="http://www.delorie.com/electronics/bin2seven"}
