/* Rahul Nambiar (rnambiar) and Lorenzo Lucena Maguire (llucena) */

`timescale 1ns / 1ps
`default_nettype none

module lc4_alu(input  wire [15:0] i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);


      /*** YOUR CODE HERE ***/

      // Arithmetic unit
      wire [15:0] o_arith, o_arith_remainder;
      arithmetic_unit arith(
            .i_insn(i_insn),
            .i_pc(i_pc),
            .i_r1data(i_r1data),
            .i_r2data(i_r2data),
            .remainder(o_arith_remainder),
            .o_result(o_arith)
            );
      // Shifting Unit
      wire [15:0] o_shift;
      shift_unit shift(
            .i_insn(i_insn),
            .i_r1data(i_r1data),
            .i_remainder(o_arith_remainder),
            .o_result(o_shift)
      );
      // Compare Unit
      wire [15:0] o_compare;
      compare_unit compare(
            .i_insn(i_insn),
            .i_r1data(i_r1data),
            .i_r2data(i_r2data),
            .o_result(o_compare)
            );
      // Logic Unit
      wire [15:0] o_logic;
      logic_unit logic_artifact(
            .i_insn(i_insn),
            .i_r1data(i_r1data),
            .i_r2data(i_r2data),
            .o_result(o_logic)
            );

      // HICONST
      wire [15:0] o_hiconst = (i_r1data & 8'hFF) | (i_insn[7:0] << 8);

      // CONST
      wire [15:0] o_const = {{7{i_insn[8]}},i_insn[8:0]};
      
      // Output MUX -- keep on adding ternary terms as needed
      wire [3:0] opcode = i_insn[15:12];
      assign o_result = opcode == 4'b0000 ? o_arith : // BR
                        opcode == 4'b0001 ? o_arith : // ARITH
                        opcode == 4'b0010 ? o_compare : // CMP
                        opcode == 4'b0101 ? o_logic : //LOGIC
                        i_insn[15:13] == 3'b011 ? o_arith : //LDR + STR
                        opcode == 4'b1001 ? o_const: // CONST
                        opcode == 4'b1010 ? o_shift : // SHIFTING UNIT
                        opcode == 4'b1101 ? o_hiconst: // HICONST
                        i_insn[15:11] == 5'b01000 ? i_r1data : // JSRR
                        i_insn[15:11] == 5'b11000 ? i_r1data : // JMPR
                        i_insn[15:11] == 5'b11001 ? o_arith : // JMP - No effects
                        {16{1'b1}};
endmodule


module arithmetic_unit(input  wire [15:0] i_insn,
               input wire [15:0] i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] remainder,
               output wire [15:0] o_result);

      wire signed i_sext_imm5 = {{11{i_insn[4]}}, i_insn[4:0]};
      wire signed i_sext_imm6 = {{10{i_insn[5]}},i_insn[5:0]};
      wire signed i_sext_imm9 = {{6{i_insn[8]}},i_insn[8:0]};
      wire signed i_sext_imm11 = {{5{i_insn[10]}},i_insn[10:0]};
      
      
      // Handle Input for CLA
      
      // BR
      wire [15:0] br_cla_input [2];
      assign br_cla_input[0] = i_pc;
      assign br_cla_input[1] = i_sext_imm9;
      
      // ADD, SUB
      wire [15:0] add_sub_cla_input[2] ;
      assign add_sub_cla_input[0] = i_r1data;
      assign add_sub_cla_input[1] = i_insn[5] == 1'b1 ? i_sext_imm5 : // ADD IMM5
                              i_insn[4] == 1'b1 ? !i_r2data : // SUB
                              i_r2data; // ADD

      // LDR, STR
      wire[15:0] ldr_str_cla_input[2]; 
      assign ldr_str_cla_input[0] = i_r1data;
      assign ldr_str_cla_input[1] = i_sext_imm6;

      // JMP
      wire [15:0] jmp_cla_input[2];
      assign jmp_cla_input[0] = i_pc;
      assign jmp_cla_input[1] = i_sext_imm11;

      // CLA INPUTS

      wire [15:0] cla_input[2];

      assign cla_input[0] =   i_insn[15:12] == 4'b0000 ? br_cla_input[0] : 
                              i_insn[15:13] == 3'b011 ? ldr_str_cla_input[0] : 
                              i_insn[15:11] == 5'b11001 ? jmp_cla_input[0] : 
                              add_sub_cla_input[0];

      assign cla_input[1] =   i_insn[15:12] == 4'b0000 ? br_cla_input[1] : 
                              i_insn[15:13] == 3'b011 ? ldr_str_cla_input[1] : 
                              i_insn[15:11] == 5'b11001 ? jmp_cla_input[1] : 
                              add_sub_cla_input[1];


      wire carry_in = i_insn[15:12] == 4'b0000 ? 1'b1 : // BR
                      i_insn[15:11] == 5'b11001 ? 1'b1 : // BR
                      i_insn[5:4] == 2'b01 ? 1'b1 :
                      1'b0;

      wire [15:0] cla_wire;
      
      cla16 cla(
            .a(cla_input[0]),
            .b(cla_input[1]),
            .cin(carry_in),
            .sum(cla_wire)
            );
      always @*
            $display(" a: %b %b %b %b , b: %b %b %b %b , cin: %b\n, output: %b %b %b %b\n", cla_input[0][15:12], cla_input[0][11:8], cla_input[0][7:4] , cla_input[0][3:0], cla_input[1][15:12], cla_input[1][11:8], cla_input[1][7:4] , cla_input[1][3:0], carry_in, cla_wire[15:12], cla_wire[11:8], cla_wire[7:4], cla_wire[3:0]);
      
      // DIV
      wire [15:0] div_wire;
      lc4_divider divider(
            .i_dividend(i_r1data),
            .i_divisor(i_r2data),
            .o_remainder(remainder),
            .o_quotient(div_wire)
      );

      // MUL
      wire [15:0] mul_wire = i_r1data * i_r2data;

      assign o_result = i_insn[15:12] == 4'b0000 ? cla_wire :
                        i_insn[4:3] == 2'b01 ? mul_wire :
                        i_insn[4:3] == 2'b11 ? div_wire :
                        cla_wire;
endmodule

module shift_unit(
               input  wire [15:0] i_insn,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_remainder,
               output wire [15:0] o_result);
      wire [3:0] i_imm4 = i_insn[3:0];
      //SLL
      wire [15:0] sll_wire = i_r1data << i_imm4;
      //SRA
      wire [15:0] sra_wire = i_r1data >>> i_imm4;
      //SRL
      wire [15:0] srl_wire = i_r1data >> i_imm4;
      // Assign output
      assign o_result = i_insn[5:4] == 2'b00 ?  sll_wire:
                   i_insn[5:4] == 2'b01 ?  sra_wire:
                   i_insn[5:4] == 2'b10 ? srl_wire:
                   i_remainder;
endmodule

module compare_unit(input wire [15:0]  i_insn,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);

wire signed [15:0] signed_rs = i_r1data;
wire signed [15:0] signed_rt = i_r2data;

//CMP
wire [15:0] cmp_wire = signed_rs > signed_rt ? {{15{1'b0}}, 1'b1}: 
                        signed_rs == signed_rt ? {16{1'b0}} : 
                        {16{1'b1}};
//CMPU
wire [15:0] cmpu_wire = i_r1data > i_r2data ? {{15{1'b0}}, 1'b1}: 
                        i_r1data == i_r2data ? {16{1'b0}} : 
                        {16{1'b1}};
//CMPI
wire [15:0] cmpi_wire;

wire signed [15:0] i_sext_imm7 = {{9{i_insn[6]}}, i_insn[6:0]};

assign cmpi_wire = signed_rs > i_sext_imm7 ? {{15{1'b0}}, 1'b1}: 
                  signed_rs == i_sext_imm7 ? {16{1'b0}} : 
                  {16{1'b1}};

//CMPIU
wire signed i_imm7 = {{9{1'b0}}, i_insn[6:0]};
wire [15:0] cmpiu_wire = i_r1data > i_imm7 ? {{15{1'b0}}, 1'b1}: 
                        i_r1data == i_imm7 ? {16{1'b0}} : 
                        {16{1'b1}};

// Assign result`
assign o_result = i_insn[9:8] == 2'b00 ?  cmp_wire:
                   i_insn[9:8] == 2'b01 ?  cmpu_wire:
                   i_insn[9:8] == 2'b10 ? cmpi_wire:
                   cmpiu_wire;
endmodule


// Logic Unit
module logic_unit(input wire [15:0] i_insn,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);

wire [15:0] and_wire;
wire [15:0] or_wire;
wire [15:0] xor_wire;
wire [15:0] not_wire;

// Assign logical wires
assign and_wire = i_r1data && (i_insn[5] == 1 ? {{11{i_insn[4]}}, i_insn[4:0]}: i_r2data);
assign or_wire = i_r1data | i_r2data;
assign xor_wire = i_r1data ^ i_r2data;
assign not_wire = !i_r1data;
// Assign result according to sub-op code
assign o_result = i_insn[4] == 1'b0 ? (i_insn[3] == 1'b0 ? and_wire : not_wire) : (i_insn[3] == 1'b0 ? or_wire : xor_wire);
endmodule


