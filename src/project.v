`default_nettype none

module tt_um_avyukth_tinyrv32 (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    // Word address within the fixed 32-word demo ROM.
    reg [4:0] pc;
    reg [31:0] instruction;

    always @* begin
        case (pc)
            5'd0 : instruction = 32'h00000013; // NOP
            5'd1 : instruction = 32'h00500093; // ADDI x1, x0, 5
            5'd2 : instruction = 32'h00a00113; // ADDI x2, x0, 10
            5'd3 : instruction = 32'h002081b3; // ADD x3, x1, x2
            5'd4 : instruction = 32'h40110233; // SUB x4, x2, x1
            5'd5 : instruction = 32'h0020f2b3; // AND x5, x1, x2
            5'd6 : instruction = 32'h0020e333; // OR x6, x1, x2
            5'd7 : instruction = 32'h0020c3b3; // XOR x7, x1, x2
            5'd8 : instruction = 32'h01400413; // ADDI x8, x0, 20
            5'd9 : instruction = 32'h01e42493; // SLTI x9, x8, 30
            5'd10: instruction = 32'h00a43513; // SLTIU x10, x8, 10
            5'd11: instruction = 32'h00f44593; // XORI x11, x8, 15
            5'd12: instruction = 32'h00346613; // ORI x12, x8, 3
            5'd13: instruction = 32'h00747693; // ANDI x13, x8, 7
            5'd14: instruction = 32'h00241713; // SLLI x14, x8, 2
            5'd15: instruction = 32'h00245793; // SRLI x15, x8, 2
            5'd16: instruction = 32'hff800413; // ADDI x8, x0, -8
            5'd17: instruction = 32'h001421b3; // SLT x3, x8, x1
            5'd18: instruction = 32'h00143233; // SLTU x4, x8, x1
            5'd19: instruction = 32'h001092b3; // SLL x5, x1, x1
            5'd20: instruction = 32'h01f00113; // ADDI x2, x0, 31
            5'd21: instruction = 32'h00245333; // SRL x6, x8, x2
            5'd22: instruction = 32'h402453b3; // SRA x7, x8, x2
            5'd23: instruction = 32'h41f45493; // SRAI x9, x8, 31
            5'd24: instruction = 32'hfff42513; // SLTI x10, x8, -1
            5'd25: instruction = 32'hfff0b593; // SLTIU x11, x1, -1
            5'd26: instruction = 32'h00700013; // ADDI x0, x0, 7
            5'd27: instruction = 32'h02200113; // ADDI x2, x0, 34
            5'd28: instruction = 32'h00209633; // SLL x12, x1, x2
            5'd29: instruction = 32'h00a43693; // SLTIU x13, x8, 10
            5'd30: instruction = 32'h01f45693; // SRLI x13, x8, 31
            5'd31: instruction = 32'h022080b3; // Unsupported OP encoding, no write
            default: instruction = 32'h00000013;
        endcase
    end

    wire [6:0] opcode = instruction[6:0];
    wire [4:0] rd     = instruction[11:7];
    wire [2:0] funct3 = instruction[14:12];
    wire [4:0] rs1    = instruction[19:15];
    wire [4:0] rs2    = instruction[24:20];
    wire [6:0] funct7 = instruction[31:25];
    wire [31:0] imm   = {{20{instruction[31]}}, instruction[31:20]};
    wire is_imm = opcode == 7'b0010011;
    wire is_reg = opcode == 7'b0110011;

    // Only x0/x1/x2/x8 are sources in the fixed ROM. Keep full words
    // for x1/x2/x8 and keep only the visible byte of the write-only
    // result slots. The ROM only loads source slots with ADDI from x0.
    // Keep that path separate so the ALU does not feed its own source muxes.
    reg [31:0] x1, x2, x8;
    wire rs1_valid = rs1 == 0 || rs1 == 1 || rs1 == 2 || rs1 == 8;
    wire rs2_valid = rs2 == 0 || rs2 == 1 || rs2 == 2 || rs2 == 8;
    wire [31:0] a = (rs1 == 1) ? x1 : (rs1 == 2) ? x2 : (rs1 == 8) ? x8 : 32'd0;
    wire [31:0] b_reg = (rs2 == 1) ? x1 : (rs2 == 2) ? x2 : (rs2 == 8) ? x8 : 32'd0;
    wire [31:0] b = is_imm ? imm : b_reg;

    wire shift_op = funct3 == 3'b001 || funct3 == 3'b101;
    wire alternate = funct7 == 7'b0100000;
    wire base_funct7 = funct7 == 7'b0000000;
    wire valid_funct = is_imm
        ? (!shift_op || base_funct7 || (funct3 == 3'b101 && alternate))
        : (base_funct7 || ((funct3 == 3'b000 || funct3 == 3'b101) && alternate));
    wire writeback = ena && (is_imm || is_reg) && valid_funct
                   && rs1_valid && (is_imm || rs2_valid) && !rd[4] && rd != 0;

    // Share add/subtract and the left/logical/arithmetic shift hardware.
    wire subtract = is_reg && alternate && funct3 == 3'b000;
    wire [31:0] sum = a + (b ^ {32{subtract}}) + {31'b0, subtract};

    function [31:0] reverse_bits;
        input [31:0] word;
        integer bit_index;
        begin
            for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1)
                reverse_bits[bit_index] = word[31-bit_index];
        end
    endfunction

    wire shift_left = funct3 == 3'b001;
    wire sign_fill = !shift_left && alternate && a[31];
    wire [31:0] shift_in = shift_left ? reverse_bits(a) : a;
    wire signed [32:0] shift_extended = {sign_fill, shift_in};
    wire signed [32:0] shift_out = shift_extended >>> b[4:0];
    wire [31:0] shift_result = shift_left ? reverse_bits(shift_out[31:0]) : shift_out[31:0];
    wire less_unsigned = a < b;
    wire less_signed = (a[31] ^ b[31]) ? a[31] : less_unsigned;

    reg [31:0] result;
    always @* begin
        case (funct3)
            3'b000: result = sum;
            3'b001, 3'b101: result = shift_result;
            3'b010: result = {31'b0, less_signed};
            3'b011: result = {31'b0, less_unsigned};
            3'b100: result = a ^ b;
            3'b110: result = a | b;
            3'b111: result = a & b;
            default: result = 32'd0;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            pc <= 5'd0;
            x1 <= 32'd0;
            x2 <= 32'd0;
            x8 <= 32'd0;
        end else begin
            if (ena)
                pc <= pc + 5'd1;
            if (writeback && is_imm && funct3 == 3'b000 && rs1 == 0) begin
                case (rd)
                    5'd1: x1 <= imm;
                    5'd2: x2 <= imm;
                    5'd8: x8 <= imm;
                    default: ;
                endcase
            end
        end
    end

    wire [7:0] debug_bytes [0:15];
    assign debug_bytes[0] = 8'd0;
    assign debug_bytes[1] = x1[7:0];
    assign debug_bytes[2] = x2[7:0];
    assign debug_bytes[8] = x8[7:0];

    genvar g;
    generate
        for (g = 3; g < 16; g = g + 1) begin : gen_debug
            if (g != 8) begin : gen_result
                localparam [4:0] SLOT = g;
                reg [7:0] value;
                always @(posedge clk) begin
                    if (!rst_n)
                        value <= 8'd0;
                    else if (writeback && rd == SLOT)
                        value <= result[7:0];
                end
                assign debug_bytes[g] = value;
            end
        end
    endgenerate

    assign uo_out = debug_bytes[ui_in[3:0]];
    assign uio_out = 8'd0;
    assign uio_oe = 8'd0;

    wire _unused = &{ui_in[7:4], uio_in, shift_out[32], 1'b0};
endmodule

`default_nettype wire
