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
T {( @#0:resolved_net )} 90 -225 0 0 0.2 0.2 {name=p6 layer=15}
T {( @#0:resolved_net )} 90 -165 0 0 0.2 0.2 {name=p9 layer=15}
T {( @#0:resolved_net )} 90 -145 0 0 0.2 0.2 {name=p10 layer=15}
N 1130 -590 1130 -340 {lab=FN}
N 660 -520 660 -340 {lab=BN}
N 1050 -820 1130 -820 {lab=Q}
N 860 -820 970 -820 {lab=DDN}
N 660 -340 820 -340 {lab=BN}
N 860 -340 1130 -340 {lab=FN}
N 400 -660 860 -660 {lab=DDN}
N 1070 -190 1200 -190 {lab=GN}
N 820 -570 820 -550 {lab=G}
N 820 -490 820 -470 {lab=GN}
N 860 -590 860 -520 {lab=DDN}
N 980 -590 990 -590 {lab=DDN}
N 1070 -590 1130 -590 {lab=FN}
N 660 -520 780 -520 {lab=BN}
N 340 -670 360 -670 {lab=D}
N 360 -670 360 -610 {lab=D}
N 400 -840 400 -820 {lab=vcc}
N 400 -180 400 -160 {lab=vss}
N 400 -660 400 -640 {lab=DDN}
N 400 -730 450 -730 {lab=vccsup}
N 400 -610 450 -610 {lab=vsssup}
N 400 -550 450 -550 {lab=vsssup}
N 400 -790 450 -790 {lab=vccsup}
N 360 -730 360 -670 {lab=D}
N 400 -700 400 -660 {lab=DDN}
N 860 -590 980 -590 {lab=DDN}
N 860 -660 860 -590 {lab=DDN}
N 860 -330 860 -270 {lab=FN}
N 820 -320 820 -300 {lab=BN}
N 770 -390 820 -390 {lab=vccsup}
N 770 -270 820 -270 {lab=vsssup}
N 860 -390 860 -330 {lab=FN}
N 820 -360 820 -320 {lab=BN}
N 820 -440 820 -420 {lab=vcc}
N 400 -210 450 -210 {lab=vsssup}
N 980 -670 1030 -670 {lab=vccsup}
N 980 -720 980 -700 {lab=vcc}
N 980 -640 980 -590 {lab=DDN}
N 980 -720 980 -700 {lab=vcc}
N 860 -820 860 -660 {lab=DDN}
N 400 -520 400 -240 {lab=#net1}
N 400 -240 820 -240 {lab=#net1}
C {devices/ipin} 80 -220 0 0 {name=p6 lab=D}
C {devices/ipin} 80 -160 0 0 {name=p9 lab=G}
C {devices/ipin} 80 -140 0 0 {name=p10 lab=CD}
C {devices/opin} 230 -210 0 0 {name=p11 lab=Q}
C {devices/iopin} 230 -190 0 0 {name=p12 lab=vcc}
C {devices/iopin} 230 -170 0 0 {name=p13 lab=vss}
C {devices/iopin} 230 -150 0 0 {name=p14 lab=vccsup}
C {devices/iopin} 230 -130 0 0 {name=p15 lab=vsssup}
C {devices/lab_pin} 1130 -820 0 1 {name=p1 lab=Q}
C {devices/capa} 630 -460 1 0 {name=c2 m=1 value=3f}
C {devices/lab_pin} 600 -460 1 0 {name=p8 lab=vss}
C {devices/capa} 590 -630 0 0 {name=c3 m=1 value=5f}
C {devices/lab_pin} 590 -600 0 0 {name=p17 lab=vss}
C {devices/lab_wire} 1130 -190 0 0 {name=l0 lab=GN}
C {devices/capa} 1140 -160 0 0 {name=c5 m=1 value=5f}
C {devices/lab_pin} 1140 -130 0 0 {name=p36 lab=vss}
C {devices/lab_pin} 820 -570 0 0 {name=l8 lab=G}
C {devices/lab_pin} 820 -470 0 0 {name=l9 lab=GN}
C {devices/capa} 980 -310 0 0 {name=c7 m=1 value=3f}
C {devices/lab_pin} 980 -280 0 0 {name=p54 lab=vss}
C {devices/lab_pin} 990 -190 0 0 {name=p56 lab=G}
C {devices/lab_wire} 660 -480 0 0 {name=l12 lab=BN}
C {rom8k/passhs} 820 -520 0 0 {name=x8 WN=12u WP=12u VCCPIN=vccsup VSSPIN=vsssup}
C {devices/lab_pin} 340 -670 0 0 {name=p61 lab=D}
C {devices/lab_pin} 400 -840 0 0 {name=p62 lab=vcc}
C {devices/lab_pin} 400 -160 0 0 {name=p63 lab=vss}
C {rom8k/nlv4t} 380 -610 0 0 {name=m17 model=cmosn w=8.4u l=2.4u m=1}
C {rom8k/plv4t} 380 -730 0 0 {name=m1 model=cmosp w=20u l=2.4u m=1
}
C {devices/lab_pin} 450 -730 0 1 {name=p64 lab=vccsup}
C {devices/lab_pin} 450 -610 0 1 {name=p65 lab=vsssup}
C {rom8k/nlv4t} 380 -550 0 0 {name=m2 model=cmosn w=8.4u l=2.4u m=1}
C {devices/lab_pin} 450 -550 0 1 {name=p66 lab=vsssup}
C {rom8k/plv4t} 380 -790 0 0 {name=m3 model=cmosp w=20u l=2.4u m=1
}
C {devices/lab_pin} 450 -790 0 1 {name=p67 lab=vccsup}
C {devices/lab_pin} 360 -550 0 0 {name=l15 lab=G}
C {devices/lab_pin} 360 -790 0 0 {name=l16 lab=GN}
C {rom8k/nlv4t} 840 -270 0 1 {name=m4 model=cmosn w=8.4u l=2.4u m=1}
C {rom8k/plv4t} 840 -390 0 1 {name=m5 model=cmosp w=8.4u l=2.4u m=1
}
C {devices/lab_pin} 770 -390 0 0 {name=p68 lab=vccsup}
C {devices/lab_pin} 770 -270 0 0 {name=p69 lab=vsssup}
C {devices/lab_pin} 820 -440 0 1 {name=p71 lab=vcc}
C {rom8k/nlv4t} 380 -210 0 0 {name=m8 model=cmosn w=24u l=2.4u m=1}
C {devices/lab_pin} 450 -210 0 1 {name=p76 lab=vsssup}
C {devices/lab_pin} 360 -210 0 0 {name=l17 lab=CD}
C {rom8k/plv4t} 960 -670 0 0 {name=m11 model=cmosp w=8.4u l=2.4u m=1
}
C {devices/lab_pin} 1030 -670 0 1 {name=p85 lab=vccsup}
C {devices/lab_pin} 940 -670 0 0 {name=p87 lab=CD}
C {devices/lab_wire} 1130 -480 0 0 {name=l19 lab=FN}
C {devices/lab_wire} 810 -660 0 0 {name=l20 lab=DDN}
C {devices/title} 160 -10 0 0 {name=l3 author="Stefan Schippers"}
C {devices/lab_pin} 980 -720 0 0 {name=p83 lab=vcc}
C {rom8k/lvnot} 1030 -590 0 0 {name=x10 m=1 
+ wn=8.4u lln=2.4u wp=8.4u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {rom8k/lvnot} 1030 -190 0 0 {name=x1 m=1 
+ wn=40u lln=2.4u wp=40u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {rom8k/lvnot} 1010 -820 0 0 {name=x2 m=1 
+ wn=40u lln=2.4u wp=100u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {devices/spice_probe} 650 -660 0 0 {name=p95 analysis=tran}
C {devices/spice_probe} 920 -340 0 0 {name=p2 analysis=tran}
