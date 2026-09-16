/*
 * 4-bit ALU
 *
 * Operations:
 * 000 - ADD       A + B
 * 001 - SUB       A - B
 * 010 - AND       A & B
 * 011 - OR        A | B
 * 100 - XOR       A ^ B
 * 101 - NOT A     ~A
 * 110 - INC A     A + 1
 * 111 - DEC A     A - 1
 *
 * Outputs:
 * uo_out[3:0] - ALU result
 * uo_out[4]   - Carry/Borrow flag
 * uo_out[5]   - Zero flag
 */

`default_nettype none

module tt_um_avyukth_alu (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // -----------------------------
    // Input assignment
    // -----------------------------

    wire [3:0] A;
    wire [3:0] B;
    wire [2:0] OP;

    assign A  = ui_in[3:0];
    assign B  = ui_in[7:4];
    assign OP = uio_in[2:0];

    // -----------------------------
    // ALU signals
    // -----------------------------

    reg [3:0] result;
    reg       carry;

    // -----------------------------
    // ALU operation
    // -----------------------------

    always @(*) begin

        result = 4'b0000;
        carry  = 1'b0;

        case (OP)

            3'b000: begin
                // ADD
                {carry, result} = A + B;
            end

            3'b001: begin
                // SUB
                {carry, result} = A - B;
            end

            3'b010: begin
                // AND
                result = A & B;
            end

            3'b011: begin
                // OR
                result = A | B;
            end

            3'b100: begin
                // XOR
                result = A ^ B;
            end

            3'b101: begin
                // NOT A
                result = ~A;
            end

            3'b110: begin
                // Increment A
                {carry, result} = A + 4'b0001;
            end

            3'b111: begin
                // Decrement A
                {carry, result} = A - 4'b0001;
            end

            default: begin
                result = 4'b0000;
                carry  = 1'b0;
            end

        endcase

    end

    // -----------------------------
    // Zero flag
    // -----------------------------

    wire zero;

    assign zero = (result == 4'b0000);

    // -----------------------------
    // Tiny Tapeout outputs
    // -----------------------------

    assign uo_out[3:0] = result;
    assign uo_out[4]   = carry;
    assign uo_out[5]   = zero;
    assign uo_out[7:6] = 2'b00;

    // -----------------------------
    // Bidirectional pins unused
    // -----------------------------

    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    // -----------------------------
    // Unused Tiny Tapeout inputs
    // -----------------------------

    wire _unused;

    assign _unused = &{ena, clk, rst_n, 1'b0};

endmodule

`default_nettype wire
