v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 420 -330 600 -330 {}
N 380 -300 380 -330 {}
N 380 -330 250 -330 {}
N 250 -270 600 -270 {}
N 420 -300 420 -270 {}
C {gf180mcu_pr/nfet_03v3} 400 -300 0 0 {name=M1
L=0.28u
W=1u
nf=1
m=1
ad="'int((nf+1)/2) * W/nf * 0.18u'"
pd="'2*int((nf+1)/2) * (W/nf + 0.18u)'"
as="'int((nf+2)/2) * W/nf * 0.18u'"
ps="'2*int((nf+2)/2) * (W/nf + 0.18u)'"
nrd="'0.18u / W'" nrs="'0.18u / W'"
sa=0 sb=0 sd=0
model=nfet_03v3
spiceprefix=X
}
C {devices/vsource} 600 -300 0 0 {name=V1 value=1.65}
C {devices/vsource} 250 -300 0 0 {name=V2 value=3.3}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 500 -330 0 0 {name=lD lab=D}
C {devices/lab_wire} 300 -330 0 0 {name=lG lab=G}
C {devices/code_shown} 60 -620 0 0 {name=MODELS only_toplevel=true
format="tcleval( @value )"
value="
* gf180mcu typical-corner models + global switch params, baked into the schematic
.include $::180MCU_MODELS/design.ngspice
.lib $::180MCU_MODELS/sm141064.ngspice typical
"}
C {devices/simulator_commands_shown} 60 -520 0 0 {name=COMMANDS simulator=ngspice only_toplevel=false value="
* minimal gf180 nfet_03v3 operating-point test
.options savecurrents
.control
  op
  print all
  print -i(v1)
.endc
"}
