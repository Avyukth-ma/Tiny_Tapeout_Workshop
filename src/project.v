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
    //
    // 32 registers
    // 32 bits per register
    //
    // RISC-V register x0 is hardwired to zero.
    // ============================================================

    reg [31:0] registers [0:31];


    // ============================================================
    // INSTRUCTION MEMORY
    //
    // 32 words x 32 bits
    //
    // PC[6:2] selects one of the 32 instruction words.
    // ============================================================

    reg [31:0] instruction_memory [0:31];

    integer i;


    // ============================================================
    // TEST PROGRAM
    //
    // Instruction format:
    //
    // 0:  NOP
    // 1:  ADDI  x1,  x0, 5
    // 2:  ADDI  x2,  x0, 10
    // 3:  ADD   x3,  x1, x2
    // 4:  SUB   x4,  x2, x1
    // 5:  AND   x5,  x1, x2
    // 6:  OR    x6,  x1, x2
    // 7:  XOR   x7,  x1, x2
    //
    // 8:  ADDI  x8,  x0, 20
    // 9:  SLTI  x9,  x8, 30
    // 10: SLTIU x10, x8, 10
    // 11: XORI  x11, x8, 15
    // 12: ORI   x12, x8, 3
    // 13: ANDI  x13, x8, 7
    // 14: SLLI  x14, x8, 2
    // 15: SRLI  x15, x8, 2
    //
    // 16-31: NOP
    //
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // Basic instructions
        // --------------------------------------------------------

        // 0: NOP
        instruction_memory[0] = 32'h00000013;

        // 1: ADDI x1, x0, 5
        instruction_memory[1] = 32'h00500093;

        // 2: ADDI x2, x0, 10
        instruction_memory[2] = 32'h00A00113;

        // 3: ADD x3, x1, x2
        instruction_memory[3] = 32'h002081B3;

        // 4: SUB x4, x2, x1
        instruction_memory[4] = 32'h40110233;

        // 5: AND x5, x1, x2
        instruction_memory[5] = 32'h0020F2B3;

        // 6: OR x6, x1, x2
        instruction_memory[6] = 32'h0020E333;

        // 7: XOR x7, x1, x2
        instruction_memory[7] = 32'h0020C3B3;


        // --------------------------------------------------------
        // Extended immediate instructions
        // --------------------------------------------------------

        // 8: ADDI x8, x0, 20
        instruction_memory[8] = 32'h01400413;

        // 9: SLTI x9, x8, 30
        instruction_memory[9] = 32'h01E42493;

        // 10: SLTIU x10, x8, 10
        instruction_memory[10] = 32'h00A43513;

        // 11: XORI x11, x8, 15
        instruction_memory[11] = 32'h00F44593;

        // 12: ORI x12, x8, 3
        instruction_memory[12] = 32'h00346613;

        // 13: ANDI x13, x8, 7
        instruction_memory[13] = 32'h00747693;

        // 14: SLLI x14, x8, 2
        instruction_memory[14] = 32'h00241713;

        // 15: SRLI x15, x8, 2
        instruction_memory[15] = 32'h00245793;


        // --------------------------------------------------------
        // Remaining memory locations contain NOP
        // --------------------------------------------------------

        for (i = 16; i < 32; i = i + 1)
            instruction_memory[i] = 32'h00000013;

    end


    // ============================================================
    // INSTRUCTION FETCH
    // ============================================================

    wire [31:0] instruction;

    assign instruction = instruction_memory[pc[6:2]];


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

    assign rs1_data =
        (rs1 == 5'd0) ? 32'd0 : registers[rs1];

    assign rs2_data =
        (rs2 == 5'd0) ? 32'd0 : registers[rs2];


    // ============================================================
    // I-TYPE IMMEDIATE
    //
    // Sign-extended 12-bit immediate.
    // ============================================================

    wire [31:0] immediate;

    assign immediate = {
        {20{instruction[31]}},
        instruction[31:20]
    };


    // ============================================================
    // ALU CONTROL
    // ============================================================

    reg        alu_src_immediate;
    reg        reg_write;
    reg [3:0]  alu_control;

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;


    // ============================================================
    // INSTRUCTION DECODER
    // ============================================================

    always @(*) begin

        // Default control values
        alu_src_immediate = 1'b0;
        reg_write         = 1'b0;
        alu_control       = ALU_ADD;


        case (opcode)

            // ====================================================
            // R-TYPE
            // opcode = 0110011
            // ====================================================

            7'b0110011: begin

                reg_write = 1'b1;

                case (funct3)

                    // --------------------------------------------
                    // ADD / SUB
                    // --------------------------------------------

                    3'b000: begin

                        if (funct7 == 7'b0100000)
                            alu_control = ALU_SUB;
                        else
                            alu_control = ALU_ADD;

                    end


                    // --------------------------------------------
                    // SLL
                    // --------------------------------------------

                    3'b001:
                        alu_control = ALU_SLL;


                    // --------------------------------------------
                    // SLT
                    // --------------------------------------------

                    3'b010:
                        alu_control = ALU_SLT;


                    // --------------------------------------------
                    // SLTU
                    // --------------------------------------------

                    3'b011:
                        alu_control = ALU_SLTU;


                    // --------------------------------------------
                    // XOR
                    // --------------------------------------------

                    3'b100:
                        alu_control = ALU_XOR;


                    // --------------------------------------------
                    // SRL / SRA
                    // --------------------------------------------

                    3'b101: begin

                        if (funct7 == 7'b0100000)
                            alu_control = ALU_SRA;
                        else
                            alu_control = ALU_SRL;

                    end


                    // --------------------------------------------
                    // OR
                    // --------------------------------------------

                    3'b110:
                        alu_control = ALU_OR;


                    // --------------------------------------------
                    // AND
                    // --------------------------------------------

                    3'b111:
                        alu_control = ALU_AND;


                    default:
                        alu_control = ALU_ADD;

                endcase

            end


            // ====================================================
            // I-TYPE ALU
            // opcode = 0010011
            // ====================================================

            7'b0010011: begin

                alu_src_immediate = 1'b1;
                reg_write         = 1'b1;

                case (funct3)

                    // --------------------------------------------
                    // ADDI
                    // --------------------------------------------

                    3'b000:
                        alu_control = ALU_ADD;


                    // --------------------------------------------
                    // SLLI
                    // --------------------------------------------

                    3'b001:
                        alu_control = ALU_SLL;


                    // --------------------------------------------
                    // SLTI
                    // --------------------------------------------

                    3'b010:
                        alu_control = ALU_SLT;


                    // --------------------------------------------
                    // SLTIU
                    // --------------------------------------------

                    3'b011:
                        alu_control = ALU_SLTU;


                    // --------------------------------------------
                    // XORI
                    // --------------------------------------------

                    3'b100:
                        alu_control = ALU_XOR;


                    // --------------------------------------------
                    // SRLI / SRAI
                    // --------------------------------------------

                    3'b101: begin

                        if (funct7 == 7'b0100000)
                            alu_control = ALU_SRA;
                        else
                            alu_control = ALU_SRL;

                    end


                    // --------------------------------------------
                    // ORI
                    // --------------------------------------------

                    3'b110:
                        alu_control = ALU_OR;


                    // --------------------------------------------
                    // ANDI
                    // --------------------------------------------

                    3'b111:
                        alu_control = ALU_AND;


                    default:
                        alu_control = ALU_ADD;

                endcase

            end


            // ====================================================
            // Unsupported instruction
            // ====================================================

            default: begin

                alu_src_immediate = 1'b0;
                reg_write         = 1'b0;
                alu_control       = ALU_ADD;

            end

        endcase

    end


    // ============================================================
    // ALU SECOND OPERAND
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

            // ADD
            ALU_ADD:
                alu_result = rs1_data + alu_input_b;


            // SUB
            ALU_SUB:
                alu_result = rs1_data - alu_input_b;


            // AND
            ALU_AND:
                alu_result = rs1_data & alu_input_b;


            // OR
            ALU_OR:
                alu_result = rs1_data | alu_input_b;


            // XOR
            ALU_XOR:
                alu_result = rs1_data ^ alu_input_b;


            // Shift left logical
            ALU_SLL:
                alu_result =
                    rs1_data << alu_input_b[4:0];


            // Shift right logical
            ALU_SRL:
                alu_result =
                    rs1_data >> alu_input_b[4:0];


            // Shift right arithmetic
            ALU_SRA:
                alu_result =
                    $signed(rs1_data) >>> alu_input_b[4:0];


            // Set less than - signed
            ALU_SLT:
                alu_result =
                    ($signed(rs1_data) < $signed(alu_input_b))
                    ? 32'd1
                    : 32'd0;


            // Set less than - unsigned
            ALU_SLTU:
                alu_result =
                    (rs1_data < alu_input_b)
                    ? 32'd1
                    : 32'd0;


            default:
                alu_result = 32'd0;

        endcase

    end


    // ============================================================
    // SEQUENTIAL LOGIC
    //
    // Register writeback
    // Program counter update
    // Reset
    // ============================================================

    always @(posedge clk) begin

        if (!rst_n) begin

            pc <= 32'd0;

            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'd0;

        end

        else if (ena) begin

            // Write ALU result to destination register
            if (reg_write && (rd != 5'd0))
                registers[rd] <= alu_result;

            // x0 is always zero
            registers[0] <= 32'd0;

            // Advance to next instruction
            pc <= pc + 32'd4;

        end

    end


    // ============================================================
    // DEBUG REGISTER SELECTOR
    //
    // ui_in[3:0] selects one of x0-x15.
    //
    // The lower 8 bits of the selected register are displayed
    // on uo_out.
    //
    // Example:
    //
    // ui_in = 4'b0011
    //       -> select x3
    //
    // If x3 = 15:
    //
    // uo_out = 8'b00001111
    //
    // ============================================================

    reg [31:0] debug_register;

    always @(*) begin

        case (ui_in[3:0])

            4'h0:
                debug_register = registers[0];

            4'h1:
                debug_register = registers[1];

            4'h2:
                debug_register = registers[2];

            4'h3:
                debug_register = registers[3];

            4'h4:
                debug_register = registers[4];

            4'h5:
                debug_register = registers[5];

            4'h6:
                debug_register = registers[6];

            4'h7:
                debug_register = registers[7];

            4'h8:
                debug_register = registers[8];

            4'h9:
                debug_register = registers[9];

            4'hA:
                debug_register = registers[10];

            4'hB:
                debug_register = registers[11];

            4'hC:
                debug_register = registers[12];

            4'hD:
                debug_register = registers[13];

            4'hE:
                debug_register = registers[14];

            4'hF:
                debug_register = registers[15];

            default:
                debug_register = 32'd0;

        endcase

    end


    // ============================================================
    // OUTPUT
    // ============================================================

    assign uo_out = debug_register[7:0];


    // ============================================================
    // UNUSED BIDIRECTIONAL PINS
    // ============================================================

    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

endmodule

`default_nettype wire
