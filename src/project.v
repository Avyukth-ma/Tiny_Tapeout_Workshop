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

    // ============================================================
    // PROGRAM COUNTER
    // ============================================================

    reg [31:0] pc;

    // ============================================================
    // REGISTER FILE
    // 32 registers, each 32 bits wide
    // x0 is always zero
    // ============================================================

    reg [31:0] registers [0:31];

    // ============================================================
    // INSTRUCTION MEMORY
    // Small internal ROM
    //
    // Each location contains one 32-bit RISC-V instruction.
    // ============================================================

    reg [31:0] instruction_memory [0:15];

    integer i;

    initial begin

        // NOP
        instruction_memory[0] = 32'h00000013;

        // ADDI x1, x0, 5
        instruction_memory[1] = 32'h00500093;

        // ADDI x2, x0, 10
        instruction_memory[2] = 32'h00A00113;

        // ADD x3, x1, x2
        instruction_memory[3] = 32'h002081B3;

        // SUB x4, x2, x1
        instruction_memory[4] = 32'h40110233;

        // AND x5, x1, x2
        instruction_memory[5] = 32'h0020F2B3;

        // OR x6, x1, x2
        instruction_memory[6] = 32'h0020E333;

        // XOR x7, x1, x2
        instruction_memory[7] = 32'h0020C3B3;

        // NOPs
        for (i = 8; i < 16; i = i + 1)
            instruction_memory[i] = 32'h00000013;
    end

    // ============================================================
    // FETCH
    // ============================================================

    wire [31:0] instruction;

    assign instruction = instruction_memory[pc[5:2]];

    // ============================================================
    // INSTRUCTION FIELDS
    // ============================================================

    wire [6:0] opcode;
    wire [4:0] rd;
    wire [2:0] funct3;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [6:0] funct7;

    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct7 = instruction[31:25];

    // ============================================================
    // REGISTER FILE READ
    // ============================================================

    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    assign rs1_data = (rs1 == 5'd0) ? 32'd0 : registers[rs1];
    assign rs2_data = (rs2 == 5'd0) ? 32'd0 : registers[rs2];

    // ============================================================
    // IMMEDIATE GENERATOR
    //
    // Used for ADDI.
    // ============================================================

    wire [31:0] immediate;

    assign immediate = {{20{instruction[31]}},
                        instruction[31:20]};

    // ============================================================
    // CONTROL SIGNALS
    // ============================================================

    reg alu_src_immediate;
    reg reg_write;
    reg [3:0] alu_control;

    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_XOR = 4'b0100;

    // ============================================================
    // INSTRUCTION DECODER
    // ============================================================

    always @(*) begin

        // Default values
        alu_src_immediate = 1'b0;
        reg_write         = 1'b0;
        alu_control       = ALU_ADD;

        case (opcode)

            // ----------------------------------------------------
            // R-TYPE
            // ADD / SUB / AND / OR / XOR
            // ----------------------------------------------------

            7'b0110011: begin

                reg_write = 1'b1;

                case (funct3)

                    3'b000: begin
                        if (funct7 == 7'b0100000)
                            alu_control = ALU_SUB;
                        else
                            alu_control = ALU_ADD;
                    end

                    3'b111:
                        alu_control = ALU_AND;

                    3'b110:
                        alu_control = ALU_OR;

                    3'b100:
                        alu_control = ALU_XOR;

                    default:
                        alu_control = ALU_ADD;

                endcase
            end

            // ----------------------------------------------------
            // I-TYPE
            // ADDI
            // ----------------------------------------------------

            7'b0010011: begin

                if (funct3 == 3'b000) begin
                    alu_src_immediate = 1'b1;
                    reg_write         = 1'b1;
                    alu_control       = ALU_ADD;
                end

            end

            default: begin
                alu_src_immediate = 1'b0;
                reg_write         = 1'b0;
                alu_control       = ALU_ADD;
            end

        endcase
    end

    // ============================================================
    // ALU INPUT SELECTION
    // ============================================================

    wire [31:0] alu_input_b;

    assign alu_input_b =
        alu_src_immediate ? immediate : rs2_data;

    // ============================================================
    // ALU
    // ============================================================

    reg [31:0] alu_result;

    always @(*) begin

        case (alu_control)

            ALU_ADD:
                alu_result = rs1_data + alu_input_b;

            ALU_SUB:
                alu_result = rs1_data - alu_input_b;

            ALU_AND:
                alu_result = rs1_data & alu_input_b;

            ALU_OR:
                alu_result = rs1_data | alu_input_b;

            ALU_XOR:
                alu_result = rs1_data ^ alu_input_b;

            default:
                alu_result = 32'd0;

        endcase
    end

    // ============================================================
    // WRITEBACK + PC UPDATE
    // ============================================================

    always @(posedge clk) begin

        if (!rst_n) begin

            pc <= 32'd0;

            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'd0;

        end

        else if (ena) begin

            // Register writeback
            if (reg_write && (rd != 5'd0))
                registers[rd] <= alu_result;

            // x0 must always remain zero
            registers[0] <= 32'd0;

            // Next instruction
            pc <= pc + 32'd4;

        end

    end

    // ============================================================
    // DEBUG OUTPUT
    //
    // ui_in[2:0] selects which register is displayed:
    //
    // 001 -> x1
    // 010 -> x2
    // 011 -> x3
    // 100 -> x4
    // 101 -> x5
    // 110 -> x6
    // 111 -> x7
    //
    // ui_in[2:0] = 000 displays x0.
    //
    // Only the low 8 bits are exposed.
    // ============================================================
    
    reg [31:0] debug_register;
    
    always @(*) begin
    
        case (ui_in[2:0])
    
            3'b000: debug_register = registers[0];
            3'b001: debug_register = registers[1];
            3'b010: debug_register = registers[2];
            3'b011: debug_register = registers[3];
            3'b100: debug_register = registers[4];
            3'b101: debug_register = registers[5];
            3'b110: debug_register = registers[6];
            3'b111: debug_register = registers[7];
    
            default: debug_register = 32'd0;
    
        endcase
    end
    
    assign uo_out = debug_register[7:0];
    // Bidirectional pins unused
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

endmodule

`default_nettype wire
