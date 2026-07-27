v {xschem version=3.4.6RC file_version=1.2
}
G {}
K {}
V {}
S {}
E {}
P 4 5 140 -620 140 -870 710 -870 710 -620 140 -620 {}
P 4 7 410 -620 410 -560 420 -560 410 -540 400 -560 410 -560 410 -620 {}
T {// importing libs
`include "discipline.h"
module diff_amp(
  output electrical out,
  input electrical in1,
  input electrical in2);
parameter real gain = 10; // setting gain to 10 of the differential amplifier
analog begin
    V(out) <+ gain * (V(in1, in2));
    // V(out) <+ 2 * atan( gain / 2 * V(in1, in2) );
end
endmodule} 150 -860 0 0 0.2 0.2 {font=monospace}
T {create a diff_amp.va file with following code 
and compile it into a .osdi file with openvaf.} 190 -930 0 0 0.4 0.4 {}
N 180 -450 320 -450 {lab=B}
N 80 -530 320 -530 {lab=A}
N 520 -490 640 -490 {lab=Z}
N 60 -290 180 -290 {lab=0}
N 180 -330 180 -290 {lab=0}
N 80 -330 80 -290 {lab=0}
N 80 -530 80 -390 {lab=A}
N 180 -450 180 -390 {lab=B}
C {sky130_tests/diff_amp} 420 -490 0 0 {name=U1}
C {devices/lab_pin} 640 -490 0 1 {name=p1 sig_type=std_logic lab=Z}
C {devices/lab_pin} 80 -530 0 0 {name=p2 sig_type=std_logic lab=A}
C {devices/lab_pin} 180 -450 0 0 {name=p3 sig_type=std_logic lab=B}
C {devices/vsource} 80 -360 0 0 {name=V1 value=3.1 savecurrent=false}
C {devices/vsource} 180 -360 0 0 {name=V2 value=3 savecurrent=false}
C {devices/lab_pin} 60 -290 0 0 {name=p4 sig_type=std_logic lab=0}
C {devices/title} 160 -30 0 0 {name=l1 author="Phillip Baade-Pedersen"}
