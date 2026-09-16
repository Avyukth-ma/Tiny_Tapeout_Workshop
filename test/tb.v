`default_nettype none
`timescale 1ns / 1ps

module tb ();

  // Clock, reset and enable
  reg clk;
  reg rst_n;
  reg ena;

  // Tiny Tapeout inputs
  reg [7:0] ui_in;
  reg [7:0] uio_in;

  // Tiny Tapeout outputs
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

`ifdef GL_TEST
  // Power supplies for gate-level simulation
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Waveform dump
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // Instantiate 4-bit ALU
  tt_um_avyukth_alu user_project (

`ifdef GL_TEST
      // Power ports for gate-level simulation
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

endmodule

`default_nettype wire
