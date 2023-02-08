/* INSERT NAME AND PENNKEY HERE */

`timescale 1ns / 1ps
`default_nettype none

module lc4_alu(input  wire [15:0] i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);


      /*** YOUR CODE HERE ***/

endmodule

module arithmetic_unit(input  wire [15:0] i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] remainder,
               output wire [15:0] o_result);

      wire signed i_sext_imm5 = {9{i_insn[11]}, i_insn[4:0]};

      // MUL
      wire [15:0] mul_wire = i_r1data * i_r2data;
      // ADD & SUB
      wire [15:0] add_input = i_insn[5] == 1'b1 ? i_sext_imm5 : 
                              i_insn[4] == 1'b1 ? !i_r2data : 
                              i_r2data;

      wire carry_in = i_insn[5:4] == 2'b01 ? 1'b1 : 1'b0;

      wire [15:0] cla_wire;
      
      cla16(
            .a(i_r1data),
            .b(add_input),
            .cin(carry_in),
            .sum(cla_wire)
            );

      // DIV
      wire [15:0] div_wire;
      lc4_divider(
            .i_dividend(i_r1data),
            .i_divisor(i_r2data),
            .o_remainder(remainder),
            .o_quotient(div_wire)
      );

      assign o_result = i_insn[4:3] == 2'b01 ? mul_wire :
                        i_insn[4:3] == 2'b11 ? div_wire :
                        cla_wire;
endmodule

module shift_unit(
               input  wire [15:0] i_insn,
               input wire [15:0]  i_r1data,
               input wire [15:0]  remainder,
               output wire [15:0] o_result);
      wire [15:0] i_imm4[3:0] = i_insn[3:0];
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
                   remainder;
endmodule

module compare_unit(input wire [15:0]  i_insn,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);

wire signed [15:0] signed_rs = i_r1data;
wire signed [15:0] signed_rt = i_r2data;

//CMP
wire [15:0] cmp_wire = signed_rs > signed_rt ? {15{1'b0}, 1'b1}: 
                        signed_rs == signed_rt ? 16{1'b0} : 
                        16{1'b1};
//CMPU
wire [15:0] cmpu_wire = i_r1data > i_r2data ? {15{1'b0}, 1'b1}: 
                        i_r1data == i_r2data ? 16{1'b0} : 
                        16{1'b1};
//CMPI
wire [15:0] cmpi_wire;

wire signed [15:0] i_sext_imm7 = {9{i_insn[6]}, i_insn[6:0]};

assign cmpi_wire = signed_rs > i_sext_imm7 ? {15{1'b0}, 1'b1}: 
                  signed_rs == i_sext_imm7 ? 16{1'b0} : 
                  16{1'b1};

//CMPIU
wire signed i_imm7 = {9{1'b0}, i_insn[6:0]};
wire [15:0] cmpiu_wire = i_r1data > i_imm7 ? {15{1'b0}, 1'b1}: 
                        i_r1data == i_imm7 ? 16{1'b0} : 
                        16{1'b1};

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
               input wire [15:0]  remainder,
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
