v {xschem version=3.4.6 file_version=1.2
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
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {devices/lab_pin} 410 -880 0 0 {name=p22 lab=B}
C {sky130_fd_pr/res_iso_pw} 430 -880 0 0 {name=R1
W=2.65
L=2.65
model=res_iso_pw
spiceprefix=X
 mult=1}
C {devices/lab_pin} 430 -850 0 1 {name=p1 lab=M}
C {devices/lab_pin} 430 -970 0 1 {name=p2 lab=P}
C {devices/ammeter} 430 -940 0 0 {name=Vr1}
C {devices/ammeter} 580 -940 0 0 {name=Vr2}
C {devices/lab_pin} 580 -970 0 1 {name=p3 lab=P}
C {devices/lab_pin} 580 -850 0 1 {name=p4 lab=M}
C {sky130_fd_pr/res_generic_nd} 580 -880 0 0 {name=R2
W=1
L=1
model=res_generic_nd
spiceprefix=X
 mult=1}
C {devices/ammeter} 760 -940 0 0 {name=Vr3}
C {devices/lab_pin} 760 -970 0 1 {name=p6 lab=P}
C {devices/lab_pin} 760 -850 0 1 {name=p7 lab=M}
C {sky130_fd_pr/res_generic_pd} 760 -880 0 0 {name=R3
W=1
L=1
model=res_generic_pd
spiceprefix=X
 mult=1}
C {devices/ammeter} 930 -940 0 0 {name=Vr4}
C {devices/lab_pin} 930 -970 0 1 {name=p9 lab=P}
C {devices/lab_pin} 930 -850 0 1 {name=p10 lab=M}
C {sky130_fd_pr/res_generic_po} 930 -880 0 0 {name=R4
W=1
L=1
model=res_generic_po
spiceprefix=X
spice_ignore=0
mult=1}
C {devices/ammeter} 430 -550 0 0 {name=Vr5}
C {devices/lab_pin} 430 -580 0 1 {name=p12 lab=P}
C {devices/lab_pin} 430 -460 0 1 {name=p13 lab=M}
C {devices/lab_pin} 410 -490 0 0 {name=p14 lab=B}
C {sky130_fd_pr/res_high_po} 430 -490 0 0 {name=R5
W=1
L=1
model=res_high_po
spiceprefix=X
 mult=1}
C {devices/ammeter} 580 -550 0 0 {name=Vr6}
C {devices/lab_pin} 580 -580 0 1 {name=p15 lab=P}
C {devices/lab_pin} 580 -460 0 1 {name=p16 lab=M}
C {devices/lab_pin} 560 -490 0 0 {name=p17 lab=B}
C {sky130_fd_pr/res_high_po_0p35} 580 -490 0 0 {name=R6
L=0.35
model=res_high_po_0p35
spiceprefix=X
 mult=1}
C {devices/ammeter} 760 -550 0 0 {name=Vr7}
C {devices/lab_pin} 760 -580 0 1 {name=p18 lab=P}
C {devices/lab_pin} 760 -460 0 1 {name=p19 lab=M}
C {devices/lab_pin} 740 -490 0 0 {name=p20 lab=B}
C {sky130_fd_pr/res_high_po_0p69} 760 -490 0 0 {name=R7
L=0.69
model=res_high_po_0p69
spiceprefix=X
 mult=1}
C {devices/ammeter} 930 -550 0 0 {name=Vr8}
C {devices/lab_pin} 930 -580 0 1 {name=p21 lab=P}
C {devices/lab_pin} 930 -460 0 1 {name=p23 lab=M}
C {devices/lab_pin} 910 -490 0 0 {name=p24 lab=B}
C {sky130_fd_pr/res_high_po_1p41} 930 -490 0 0 {name=R8
L=1.41
model=res_high_po_1p41
spiceprefix=X
 mult=1}
C {devices/ammeter} 430 -360 0 0 {name=Vr9}
C {devices/lab_pin} 430 -390 0 1 {name=p25 lab=P}
C {devices/lab_pin} 430 -270 0 1 {name=p26 lab=M}
C {devices/lab_pin} 410 -300 0 0 {name=p27 lab=B}
C {sky130_fd_pr/res_xhigh_po} 430 -300 0 0 {name=R9
W=1
L=1
model=res_xhigh_po
spiceprefix=X
 mult=1}
C {devices/ammeter} 580 -360 0 0 {name=Vr10}
C {devices/lab_pin} 580 -390 0 1 {name=p28 lab=P}
C {devices/lab_pin} 580 -270 0 1 {name=p29 lab=M}
C {devices/lab_pin} 560 -300 0 0 {name=p30 lab=B}
C {sky130_fd_pr/res_xhigh_po_0p35} 580 -300 0 0 {name=R10
L=0.35
model=res_xhigh_po_0p35
spiceprefix=X
 mult=1}
C {devices/ammeter} 760 -360 0 0 {name=Vr11}
C {devices/lab_pin} 760 -390 0 1 {name=p31 lab=P}
C {devices/lab_pin} 760 -270 0 1 {name=p32 lab=M}
C {devices/lab_pin} 740 -300 0 0 {name=p33 lab=B}
C {sky130_fd_pr/res_xhigh_po_0p69} 760 -300 0 0 {name=R11
L=0.69
model=res_xhigh_po_0p69
spiceprefix=X
 mult=1}
C {devices/ammeter} 930 -360 0 0 {name=Vr12}
C {devices/lab_pin} 930 -390 0 1 {name=p34 lab=P}
C {devices/lab_pin} 930 -270 0 1 {name=p35 lab=M}
C {devices/lab_pin} 910 -300 0 0 {name=p36 lab=B}
C {sky130_fd_pr/res_xhigh_po_1p41} 930 -300 0 0 {name=R12
L=1.41
model=res_xhigh_po_1p41
spiceprefix=X
 mult=1}
C {devices/ipin} 310 -200 0 0 {name=p45 lab=P}
C {devices/ipin} 310 -160 0 0 {name=p46 lab=M}
C {devices/ipin} 310 -120 0 0 {name=p47 lab=B}
C {devices/ammeter} 580 -170 0 0 {name=Vr14}
C {devices/lab_pin} 580 -200 0 1 {name=p11 lab=P}
C {devices/lab_pin} 580 -80 0 1 {name=p37 lab=M}
C {sky130_fd_pr/res_generic_m1} 580 -110 0 0 {name=R14
W=1
L=1
model=res_generic_m1
spiceprefix=X
mult=1}
C {devices/lab_pin} 560 -880 0 0 {name=p5 lab=B}
C {devices/lab_pin} 740 -880 0 0 {name=p8 lab=B}
C {devices/ammeter} 1110 -360 0 0 {name=Vr13}
C {devices/lab_pin} 1110 -390 0 1 {name=p38 lab=P}
C {devices/lab_pin} 1110 -270 0 1 {name=p39 lab=M}
C {devices/lab_pin} 1090 -300 0 0 {name=p40 lab=B}
C {sky130_fd_pr/res_xhigh_po_2p85} 1110 -300 0 0 {name=R13
L=2.85
model=res_xhigh_po_2p85
spiceprefix=X
 mult=1}
C {devices/ammeter} 1110 -550 0 0 {name=Vr15}
C {devices/lab_pin} 1110 -580 0 1 {name=p41 lab=P}
C {devices/lab_pin} 1110 -460 0 1 {name=p42 lab=M}
C {devices/lab_pin} 1090 -490 0 0 {name=p43 lab=B}
C {sky130_fd_pr/res_high_po_2p85} 1110 -490 0 0 {name=R15
L=2.85
model=res_high_po_2p85
spiceprefix=X
mult=1}
C {devices/ammeter} 1290 -360 0 0 {name=Vr16}
C {devices/lab_pin} 1290 -390 0 1 {name=p44 lab=P}
C {devices/lab_pin} 1290 -270 0 1 {name=p48 lab=M}
C {devices/lab_pin} 1270 -300 0 0 {name=p49 lab=B}
C {devices/ammeter} 1290 -550 0 0 {name=Vr17}
C {devices/lab_pin} 1290 -580 0 1 {name=p50 lab=P}
C {devices/lab_pin} 1290 -460 0 1 {name=p51 lab=M}
C {devices/lab_pin} 1270 -490 0 0 {name=p52 lab=B}
C {sky130_fd_pr/res_xhigh_po_5p73} 1290 -300 0 0 {name=R16
L=5.73
model=res_xhigh_po_5p73
spiceprefix=X
mult=1}
C {sky130_fd_pr/res_high_po_5p73} 1290 -490 0 0 {name=R17
L=5.73
model=res_high_po_5p73
spiceprefix=X
mult=1}
C {devices/ammeter} 760 -170 0 0 {name=Vr18}
C {devices/lab_pin} 760 -200 0 1 {name=p53 lab=P}
C {devices/lab_pin} 760 -80 0 1 {name=p54 lab=M}
C {sky130_fd_pr/res_generic_m2} 760 -110 0 0 {name=R18
W=1
L=1
model=res_generic_m2
mult=1}
C {devices/ammeter} 430 -170 0 0 {name=Vr19}
C {devices/lab_pin} 430 -200 0 1 {name=p55 lab=P}
C {devices/lab_pin} 430 -80 0 1 {name=p56 lab=M}
C {sky130_fd_pr/res_generic_l1} 430 -110 0 0 {name=R19
W=1
L=1
model=res_generic_l1
mult=1}
C {devices/ammeter} 930 -170 0 0 {name=Vr20}
C {devices/lab_pin} 930 -200 0 1 {name=p57 lab=P}
C {devices/lab_pin} 930 -80 0 1 {name=p58 lab=M}
C {devices/ammeter} 1110 -170 0 0 {name=Vr21}
C {devices/lab_pin} 1110 -200 0 1 {name=p59 lab=P}
C {devices/lab_pin} 1110 -80 0 1 {name=p60 lab=M}
C {devices/ammeter} 1290 -170 0 0 {name=Vr22}
C {devices/lab_pin} 1290 -200 0 1 {name=p61 lab=P}
C {devices/lab_pin} 1290 -80 0 1 {name=p62 lab=M}
C {sky130_fd_pr/res_generic_m4} 1110 -110 0 0 {name=R21
W=1
L=1
model=res_generic_m4
mult=1}
C {sky130_fd_pr/res_generic_m3} 930 -110 0 0 {name=R20
W=1
L=1
model=res_generic_m3
mult=1}
C {sky130_fd_pr/res_generic_m5} 1290 -110 0 0 {name=R22
W=1
L=1
model=res_generic_m5
mult=1}
C {devices/ammeter} 430 -750 0 0 {name=Vr23}
C {devices/lab_pin} 430 -780 0 1 {name=p63 lab=P}
C {devices/lab_pin} 430 -660 0 1 {name=p64 lab=M}
C {devices/lab_pin} 410 -690 0 0 {name=p65 lab=B}
C {sky130_fd_pr/res_high_po} 430 -690 0 0 {name=R23
W=1
L=10
model=res_high_po
spiceprefix=X
 mult=1}
C {devices/ammeter} 580 -750 0 0 {name=Vr24}
C {devices/lab_pin} 580 -780 0 1 {name=p66 lab=P}
C {devices/lab_pin} 580 -660 0 1 {name=p67 lab=M}
C {devices/lab_pin} 560 -690 0 0 {name=p68 lab=B}
C {sky130_fd_pr/res_high_po_0p35} 580 -690 0 0 {name=R24
L=3.5
model=res_high_po_0p35
spiceprefix=X
 mult=1}
C {devices/ammeter} 760 -750 0 0 {name=Vr25}
C {devices/lab_pin} 760 -780 0 1 {name=p69 lab=P}
C {devices/lab_pin} 760 -660 0 1 {name=p70 lab=M}
C {devices/lab_pin} 740 -690 0 0 {name=p71 lab=B}
C {sky130_fd_pr/res_high_po_0p69} 760 -690 0 0 {name=R25
L=6.9
model=res_high_po_0p69
spiceprefix=X
 mult=1}
C {devices/ammeter} 930 -750 0 0 {name=Vr26}
C {devices/lab_pin} 930 -780 0 1 {name=p72 lab=P}
C {devices/lab_pin} 930 -660 0 1 {name=p73 lab=M}
C {devices/lab_pin} 910 -690 0 0 {name=p74 lab=B}
C {sky130_fd_pr/res_high_po_1p41} 930 -690 0 0 {name=R26
L=14.1
model=res_high_po_1p41
spiceprefix=X
 mult=1}
C {devices/ammeter} 1110 -750 0 0 {name=Vr27}
C {devices/lab_pin} 1110 -780 0 1 {name=p75 lab=P}
C {devices/lab_pin} 1110 -660 0 1 {name=p76 lab=M}
C {devices/lab_pin} 1090 -690 0 0 {name=p77 lab=B}
C {sky130_fd_pr/res_high_po_2p85} 1110 -690 0 0 {name=R27
L=28.5
model=res_high_po_2p85
spiceprefix=X
mult=1}
C {devices/ammeter} 1290 -750 0 0 {name=Vr28}
C {devices/lab_pin} 1290 -780 0 1 {name=p78 lab=P}
C {devices/lab_pin} 1290 -660 0 1 {name=p79 lab=M}
C {devices/lab_pin} 1270 -690 0 0 {name=p80 lab=B}
C {sky130_fd_pr/res_high_po_5p73} 1290 -690 0 0 {name=R28
L=57.3
model=res_high_po_5p73
spiceprefix=X
mult=1}
