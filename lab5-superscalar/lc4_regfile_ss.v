`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

/* 8-register, n-bit register file with
 * four read ports and two write ports
 * to support two pipes.
 * 
 * If both pipes try to write to the
 * same register, pipe B wins.
 * 
 * Inputs should be bypassed to the outputs
 * as needed so the register file returns
 * data that is written immediately
 * rather than only on the next cycle.
 */
module lc4_regfile_ss #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,

    input  wire [  2:0] i_rs_A,      // pipe A: rs selector
    output wire [n-1:0] o_rs_data_A, // pipe A: rs contents
    input  wire [  2:0] i_rt_A,      // pipe A: rt selector
    output wire [n-1:0] o_rt_data_A, // pipe A: rt contents

    input  wire [  2:0] i_rs_B,      // pipe B: rs selector
    output wire [n-1:0] o_rs_data_B, // pipe B: rs contents
    input  wire [  2:0] i_rt_B,      // pipe B: rt selector
    output wire [n-1:0] o_rt_data_B, // pipe B: rt contents

    input  wire [  2:0]  i_rd_A,     // pipe A: rd selector
    input  wire [n-1:0]  i_wdata_A,  // pipe A: data to write
    input  wire          i_rd_we_A,  // pipe A: write enable

    input  wire [  2:0]  i_rd_B,     // pipe B: rd selector
    input  wire [n-1:0]  i_wdata_B,  // pipe B: data to write
    input  wire          i_rd_we_B   // pipe B: write enable
    );

   wire [n-1:0] o_register[7:0];

   wire [7:0] i_rd_A_one_hot = 
                            i_rd_A == 3'd0 ? 8'b00000001:
                            i_rd_A == 3'd1 ? 8'b00000010:
                            i_rd_A == 3'd2 ? 8'b00000100:
                            i_rd_A == 3'd3 ? 8'b00001000:
                            i_rd_A == 3'd4 ? 8'b00010000:
                            i_rd_A == 3'd5 ? 8'b00100000:
                            i_rd_A == 3'd6 ? 8'b01000000: 8'b10000000;
    
   wire [7:0] i_rd_B_one_hot = 
                        i_rd_B == 3'd0 ? 8'b00000001:
                        i_rd_B == 3'd1 ? 8'b00000010:
                        i_rd_B == 3'd2 ? 8'b00000100:
                        i_rd_B == 3'd3 ? 8'b00001000:
                        i_rd_B == 3'd4 ? 8'b00010000:
                        i_rd_B == 3'd5 ? 8'b00100000:
                        i_rd_B == 3'd6 ? 8'b01000000: 8'b10000000;
    
    genvar i;
    for (i = 0; i < 8; i = i + 1) begin
        wire we = (i_rd_we_A & i_rd_A_one_hot[i]) | (i_rd_we_B & i_rd_B_one_hot[i]);
        wire[n-1:0] i_wdata = (i_rd_we_B & i_rd_B_one_hot[i]) ? i_wdata_B : i_wdata_A;
        Nbit_reg #(n) register_lc4 (
            .in(i_wdata),
            .out(o_register[i]),
            .clk(clk),
            .we(we),
            .gwe(gwe),
            .rst(rst)
        );
    end

   wire[n-1:0] rs_sel_data_A = 
                    i_rs_A == 3'b000 ? o_register[0]:
                    i_rs_A == 3'b001 ? o_register[1]:
                    i_rs_A == 3'b010 ? o_register[2]:
                    i_rs_A == 3'b011 ? o_register[3]:
                    i_rs_A == 3'b100 ? o_register[4]:
                    i_rs_A == 3'b101 ? o_register[5]:
                    i_rs_A == 3'b110 ? o_register[6]: o_register[7];

   wire[n-1:0] rt_sel_data_A = 
                i_rt_A == 3'b000 ? o_register[0]:
                i_rt_A == 3'b001 ? o_register[1]:
                i_rt_A == 3'b010 ? o_register[2]:
                i_rt_A == 3'b011 ? o_register[3]:
                i_rt_A == 3'b100 ? o_register[4]:
                i_rt_A == 3'b101 ? o_register[5]:
                i_rt_A == 3'b110 ? o_register[6]: 
                o_register[7];

   wire[n-1:0] rs_sel_data_B = 
                    i_rs_B == 3'b000 ? o_register[0]:
                    i_rs_B == 3'b001 ? o_register[1]:
                    i_rs_B == 3'b010 ? o_register[2]:
                    i_rs_B == 3'b011 ? o_register[3]:
                    i_rs_B == 3'b100 ? o_register[4]:
                    i_rs_B == 3'b101 ? o_register[5]:
                    i_rs_B == 3'b110 ? o_register[6]: 
                    o_register[7];

   wire[n-1:0] rt_sel_data_B = 
                i_rt_B == 3'b000 ? o_register[0]:
                i_rt_B == 3'b001 ? o_register[1]:
                i_rt_B == 3'b010 ? o_register[2]:
                i_rt_B == 3'b011 ? o_register[3]:
                i_rt_B == 3'b100 ? o_register[4]:
                i_rt_B == 3'b101 ? o_register[5]:
                i_rt_B == 3'b110 ? o_register[6]: 
                o_register[7];

   // Bypass output
   assign o_rs_data_A = i_rd_we_B & (i_rd_B == i_rs_A) ? i_wdata_B :
                        i_rd_we_A & (i_rd_A == i_rs_A) ? i_wdata_A :
                        rs_sel_data_A;

   assign o_rt_data_A = i_rd_we_B & (i_rd_B == i_rt_A) ? i_wdata_B :
                        i_rd_we_A & (i_rd_A == i_rt_A) ? i_wdata_A :
                        rt_sel_data_A;

   assign o_rs_data_B = i_rd_we_B & (i_rd_B == i_rs_B) ? i_wdata_B :
                        i_rd_we_A & (i_rd_A == i_rs_B) ? i_wdata_A :
                        rs_sel_data_B;

   assign o_rt_data_B = i_rd_we_B & (i_rd_B == i_rt_B) ? i_wdata_B :
                        i_rd_we_A & (i_rd_A == i_rt_B) ? i_wdata_A :
                        rt_sel_data_B;
   
endmodule
