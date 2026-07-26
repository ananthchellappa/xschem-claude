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
C {sky130_fd_pr/nfet_01v8} 400 -300 0 0 {name=M1 W=1 L=0.15 nf=1}
C {devices/vsource} 600 -300 0 0 {name=V1 value=1}
C {devices/vsource} 250 -300 0 0 {name=V2 value=1.8}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 500 -330 0 0 {name=lD lab=D}
C {devices/lab_wire} 300 -330 0 0 {name=lG lab=G}
C {sky130_fd_pr/corner} 720 -420 0 0 {name=CORNER only_toplevel=false corner=tt}
C {devices/simulator_commands_shown} 60 -520 0 0 {name=COMMANDS simulator=ngspice only_toplevel=false value="
* minimal sky130 nfet operating-point test
.options savecurrents
.control
  op
  print all
  print -i(v1)
.endc
"}
