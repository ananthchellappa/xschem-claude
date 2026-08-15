`timescale 1ps/1ps // needed for Icarus

// 4-bit counter, d_cosim code block for tb_counter_wrapper.
//
// PORTS ARE FIXED BY THE SYMBOL VIEW (counter/symbol/counter.sym):
//     B 5 -72.5 -2.5 -67.5 2.5 {name=clk         dir=in}
//     B 5  67.5 -2.5  72.5 2.5 {name=count[3..0] dir=out}
// and by its d_cosim format string
//     format="@name [ @@clk ] [ @@count[3..0] ] @model"
// The bracket groups are the co-simulation's wire protocol: input ports first,
// then outputs, each in declaration order. Adding or reordering a PORT here
// means editing the symbol too. Adding an INTERNAL signal does not.
//
// Everything below the ports is deliberately internal: it never crosses the
// d_cosim boundary (only ports do), so ngspice cannot see it and neither can
// the .raw file. It exists to be the payload for the Signal Browser work in
// doc/claude/specs/mixed_signal_signal_browser.md — visible only in the VCD
// the patched shim writes (build with tools/cosim/build_cosim_so.sh -V).

module counter (
    input clk,
    output reg [3:0] count
);

  // ---- internal state, invisible to ngspice ----
  reg  [1:0] phase;      // free-running quarter-rate sub-counter
  reg        half;       // toggles on each terminal count
  reg  [3:0] prev;       // previous count value
  wire [3:0] next_count; // combinational next value
  wire       tc;         // terminal count (count == 4'hF)
  wire       carry;      // carry into bit 3

  assign next_count = count + 4'd1;
  assign tc         = &count;
  assign carry      = count[0] & count[1] & count[2];

  initial begin
    $display("counter: initial");
    count = 4'd0;
    phase = 2'd0;
    half  = 1'b0;
    prev  = 4'd0;
  end

  always @(posedge clk) begin
    prev  <= count;
    count <= next_count;
    phase <= phase + 2'd1;
    if (tc) half <= ~half;
    $display("counter: clk event count=%0d phase=%0d tc=%b carry=%b half=%b",
             count, phase, tc, carry, half);
  end

endmodule
