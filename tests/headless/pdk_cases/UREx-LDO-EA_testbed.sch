v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
T {plot db(Vout/((v(v+)-v(v-))))
.ac dec 20 1 1e12} -370 -320 0 0 0.2 0.2 {}
T {Saturation
NMOS: Vds>Vgs-Vth
PMOS: |Vds|>|Vgs|-|Vth|} -10 -310 0 0 0.4 0.4 {}
N -210 60 -210 70 {lab=GND}
N 260 100 260 160 {lab=#net1}
N 260 100 320 100 {lab=#net1}
N 340 40 340 100 {lab=#net1}
N 320 100 340 100 {lab=#net1}
N 170 100 260 100 {lab=#net1}
N 170 40 170 100 {lab=#net1}
N 340 -130 340 -20 {lab=#net2}
N 170 -130 170 -20 {lab=#net3}
N 210 -160 300 -160 {lab=#net3}
N 170 -130 250 -130 {lab=#net3}
N 250 -160 250 -130 {lab=#net3}
N 170 -210 170 -190 {lab=VDD}
N 170 -210 190 -210 {lab=VDD}
N 190 -210 340 -210 {lab=VDD}
N 340 -210 340 -190 {lab=VDD}
N 650 -130 650 150 {lab=Vout}
N 530 -90 650 -90 {lab=Vout}
N 440 -160 610 -160 {lab=#net2}
N 440 -160 440 -90 {lab=#net2}
N 650 -200 650 -190 {lab=VDD}
N 340 -210 650 -210 {lab=VDD}
N 650 -210 650 -200 {lab=VDD}
N -10 190 220 190 {lab=#net4}
N -50 220 -50 240 {lab=GND}
N -50 240 -40 240 {lab=GND}
N -40 240 260 240 {lab=GND}
N 260 220 260 240 {lab=GND}
N 260 240 650 240 {lab=GND}
N 650 210 650 240 {lab=GND}
N 210 180 210 190 {lab=#net4}
N 260 240 260 260 {lab=GND}
N 340 -220 340 -210 {lab=VDD}
N -50 150 10 150 {lab=#net4}
N 10 150 10 190 {lab=#net4}
N 650 -90 670 -90 {lab=Vout}
N 380 10 400 10 {lab=V+}
N 110 10 130 10 {lab=V-}
N 340 -160 370 -160 {lab=VDD}
N 370 -180 370 -160 {lab=VDD}
N 340 -200 370 -200 {lab=VDD}
N 370 -200 370 -180 {lab=VDD}
N 150 -160 170 -160 {lab=VDD}
N 150 -170 150 -160 {lab=VDD}
N 150 -200 150 -170 {lab=VDD}
N 150 -200 170 -200 {lab=VDD}
N 270 220 270 230 {lab=GND}
N 260 230 270 230 {lab=GND}
N 650 220 670 220 {lab=GND}
N -70 230 -50 230 {lab=GND}
N 650 -160 670 -160 {lab=VDD}
N 670 -170 670 -160 {lab=VDD}
N 670 -190 670 -170 {lab=VDD}
N 650 -200 670 -200 {lab=VDD}
N 670 -200 670 -190 {lab=VDD}
N -50 100 -50 150 {lab=#net4}
N -50 150 -50 160 {lab=#net4}
N 670 -90 750 -90 {lab=Vout}
N 750 -90 790 -90 {lab=Vout}
N 310 10 340 10 {lab=GND}
N 170 10 200 10 {lab=GND}
N 210 170 210 180 {lab=#net4}
N 610 170 610 180 {lab=#net4}
N 750 -10 750 240 {lab=GND}
N 650 240 750 240 {lab=GND}
N -50 -210 -50 40 {lab=VDD}
N -50 -210 170 -210 {lab=VDD}
N 790 -90 860 -90 {lab=Vout}
N 440 -90 470 -90 {lab=#net2}
N 840 30 840 50 {lab=#net5}
N 840 10 840 30 {lab=#net5}
N -70 190 -70 230 {lab=GND}
N -70 190 -50 190 {lab=GND}
N 210 170 610 170 {lab=#net4}
N 260 190 270 190 {lab=GND}
N 270 190 270 220 {lab=GND}
N 650 180 670 180 {lab=GND}
N 670 180 670 220 {lab=GND}
N 750 -90 750 -70 {lab=Vout}
N 340 -90 440 -90 {lab=#net2}
N 110 10 110 20 {lab=V-}
C {vsource.sym} -360 40 0 0 {name=V1 value="\{VDD\}" savecurrent=false}
C {ipin.sym} -360 10 1 0 {name=p10 lab=VDD}
C {gnd.sym} -360 70 0 0 {name=l1 lab=GND}
C {code.sym} -280 -260 0 0 {name=s1 only_toplevel=false 
value= "

.lib /usr/local/share/pdk/sky130A/libs.tech/ngspice/sky130.lib.spice tt 
.param VDD=1.8 amp=1.2
.tran 5u 5m
*.ac dec 20 1 1e12
.save all

.control
run
*plot -i(v1)
plot vout
*plot db(vout/v(v+)) 
*plot 180*cph(vout)/pi
set wr_singlescale
set wr_vecnames
*wrdata /foss/designs/2stageCMOSOpAmp/sim_data/GainvsFreq/gain(max).txt db(vout/v(v+))
*wrdata /foss/designs/2stageCMOSOpAmp/sim_data/sample_waves/a1.3m_f1k_gain700.txt vout
*wrdata /foss/designs/2stageCMOSOpAmp/sim_data/SR/SR.txt vout

.endc
"}
C {ipin.sym} -210 0 3 1 {name=p14 lab=V+
}
C {vsource.sym} -210 30 0 0 {name=V6 value="SIN(0.6 1m 1k)" savecurrent=false}
C {gnd.sym} -210 70 0 0 {name=l2 lab=GND
value="0 AC 1"}
C {capa.sym} 500 -90 3 0 {name=C1
m=1
value=0.5p
footprint=1206
device="ceramic capacitor"}
C {ipin.sym} 340 -220 1 0 {name=p6 lab=VDD}
C {opin.sym} 860 -90 0 0 {name=p8 lab=Vout}
C {ipin.sym} 400 10 0 1 {name=p11 lab=V+
}
C {capa.sym} 750 -40 2 0 {name=C2
m=1
value=5p
footprint=1206
device="ceramic capacitor"}
C {isource.sym} -50 70 0 0 {name=I0 value=4u}
C {gnd.sym} 260 260 0 0 {name=l5 lab=GND
value=c}
C {gnd.sym} 200 10 3 0 {name=l6 lab=GND
value=c}
C {gnd.sym} 310 10 1 0 {name=l7 lab=GND
value=c}
C {vsource.sym} 110 50 0 0 {name=V2 value=0.6 savecurrent=false}
C {gnd.sym} 110 80 0 0 {name=l4 lab=GND}
C {ipin.sym} 110 10 0 0 {name=p1 lab=V-}
C {res.sym} 840 -20 0 0 {name=R1
value=99k
footprint=1206
device=resistor
m=1}
C {res.sym} 840 80 0 0 {name=R2
value=1k
footprint=1206
device=resistor
m=1}
C {gnd.sym} 840 110 0 0 {name=l3 lab=GND
value=c}
C {/usr/local/share/pdk/sky130A/libs.tech/xschem/sky130_fd_pr/nfet_01v8_lvt.sym} 150 10 0 0 {name=M1
W=0.8
L=1
nf=1
mult=1
ad="expr('int((@nf + 1)/2) * @W / @nf * 0.29')"
pd="expr('2*int((@nf + 1)/2) * (@W / @nf + 0.29)')"
as="expr('int((@nf + 2)/2) * @W / @nf * 0.29')"
ps="expr('2*int((@nf + 2)/2) * (@W / @nf + 0.29)')"
nrd="expr('0.29 / @W ')" nrs="expr('0.29 / @W ')"
sa=0 sb=0 sd=0
model=nfet_01v8_lvt
spiceprefix=X
}
C {/usr/local/share/pdk/sky130A/libs.tech/xschem/sky130_fd_pr/pfet_01v8_lvt.sym} 320 -160 0 0 {name=M4
W=0.5
L=1
nf=1
mult=1
ad="expr('int((@nf + 1)/2) * @W / @nf * 0.29')"
pd="expr('2*int((@nf + 1)/2) * (@W / @nf + 0.29)')"
as="expr('int((@nf + 2)/2) * @W / @nf * 0.29')"
ps="expr('2*int((@nf + 2)/2) * (@W / @nf + 0.29)')"
nrd="expr('0.29 / @W ')" nrs="expr('0.29 / @W ')"
sa=0 sb=0 sd=0
model=pfet_01v8_lvt
spiceprefix=X
}
C {/usr/local/share/pdk/sky130A/libs.tech/xschem/sky130_fd_pr/nfet_01v8_lvt.sym} 360 10 0 1 {name=M2
W=0.8
L=1
nf=1
mult=1
ad="expr('int((@nf + 1)/2) * @W / @nf * 0.29')"
pd="expr('2*int((@nf + 1)/2) * (@W / @nf + 0.29)')"
as="expr('int((@nf + 2)/2) * @W / @nf * 0.29')"
ps="expr('2*int((@nf + 2)/2) * (@W / @nf + 0.29)')"
nrd="expr('0.29 / @W ')" nrs="expr('0.29 / @W ')"
sa=0 sb=0 sd=0
model=nfet_01v8_lvt
spiceprefix=X
}
C {/usr/local/share/pdk/sky130A/libs.tech/xschem/sky130_fd_pr/nfet_01v8_lvt.sym} -30 190 0 1 {name=M9
W=1.2
L=1
nf=1
mult=1
ad="expr('int((@nf + 1)/2) * @W / @nf * 0.29')"
pd="expr('2*int((@nf + 1)/2) * (@W / @nf + 0.29)')"
as="expr('int((@nf + 2)/2) * @W / @nf * 0.29')"
ps="expr('2*int((@nf + 2)/2) * (@W / @nf + 0.29)')"
nrd="expr('0.29 / @W ')" nrs="expr('0.29 / @W ')"
sa=0 sb=0 sd=0
model=nfet_01v8_lvt
spiceprefix=X
}
C {/usr/local/share/pdk/sky130A/libs.tech/xschem/sky130_fd_pr/nfet_01v8_lvt.sym} 240 190 0 0 {name=M5
W=1.2
L=1
nf=1
mult=1
ad="expr('int((@nf + 1)/2) * @W / @nf * 0.29')"
pd="expr('2*int((@nf + 1)/2) * (@W / @nf + 0.29)')"
as="expr('int((@nf + 2)/2) * @W / @nf * 0.29')"
ps="expr('2*int((@nf + 2)/2) * (@W / @nf + 0.29)')"
nrd="expr('0.29 / @W ')" nrs="expr('0.29 / @W ')"
sa=0 sb=0 sd=0
model=nfet_01v8_lvt
spiceprefix=X
}
C {/usr/local/share/pdk/sky130A/libs.tech/xschem/sky130_fd_pr/nfet_01v8_lvt.sym} 630 180 0 0 {name=M7
W=5.2
L=0.25
nf=1
mult=1
ad="expr('int((@nf + 1)/2) * @W / @nf * 0.29')"
pd="expr('2*int((@nf + 1)/2) * (@W / @nf + 0.29)')"
as="expr('int((@nf + 2)/2) * @W / @nf * 0.29')"
ps="expr('2*int((@nf + 2)/2) * (@W / @nf + 0.29)')"
nrd="expr('0.29 / @W ')" nrs="expr('0.29 / @W ')"
sa=0 sb=0 sd=0
model=nfet_01v8_lvt
spiceprefix=X
}
C {/usr/local/share/pdk/sky130A/libs.tech/xschem/sky130_fd_pr/pfet_01v8_lvt.sym} 190 -160 0 1 {name=M3
W=0.5
L=1
nf=1
mult=1
ad="expr('int((@nf + 1)/2) * @W / @nf * 0.29')"
pd="expr('2*int((@nf + 1)/2) * (@W / @nf + 0.29)')"
as="expr('int((@nf + 2)/2) * @W / @nf * 0.29')"
ps="expr('2*int((@nf + 2)/2) * (@W / @nf + 0.29)')"
nrd="expr('0.29 / @W ')" nrs="expr('0.29 / @W ')"
sa=0 sb=0 sd=0
model=pfet_01v8_lvt
spiceprefix=X
}
C {/usr/local/share/pdk/sky130A/libs.tech/xschem/sky130_fd_pr/pfet_01v8_lvt.sym} 630 -160 0 0 {name=M6
W=4.2
L=0.35
nf=1
mult=1
ad="expr('int((@nf + 1)/2) * @W / @nf * 0.29')"
pd="expr('2*int((@nf + 1)/2) * (@W / @nf + 0.29)')"
as="expr('int((@nf + 2)/2) * @W / @nf * 0.29')"
ps="expr('2*int((@nf + 2)/2) * (@W / @nf + 0.29)')"
nrd="expr('0.29 / @W ')" nrs="expr('0.29 / @W ')"
sa=0 sb=0 sd=0
model=pfet_01v8_lvt
spiceprefix=X
}
