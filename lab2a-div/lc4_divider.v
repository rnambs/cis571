/* Names: Rahul Nambiar and Lorenzo Lucena Maguire
   PennKey: rnambiar and llucena
*/

`timescale 1ns / 1ps
`default_nettype none

module lc4_divider(input  wire [15:0] i_dividend,
                   input  wire [15:0] i_divisor,
                   output wire [15:0] o_remainder,
                   output wire [15:0] o_quotient);

      /*** YOUR CODE HERE ***/
      // Holder bus for temporary results: 16 groups of 3 wires, 16 bits wide
      wire [15:0] curr_remainder[16];
      wire [15:0] curr_quotient[16];
      wire [15:0] curr_dividend[16];
      
      // First pass
      lc4_divider_one_iter d0(
                        .i_dividend(i_dividend), 
                        .i_divisor(i_divisor), 
                        .i_remainder(16'b0), 
                        .i_quotient(16'b0), 
                        .o_dividend(curr_dividend[0]), 
                        .o_remainder(curr_remainder[0]),
                        .o_quotient(curr_quotient[0])
                        );

      genvar i;
      for (i = 0; i < 15; i = i + 1) begin
            lc4_divider_one_iter divider(
                              .i_dividend(curr_dividend[i]), 
                              .i_divisor(i_divisor), 
                              .i_remainder(curr_remainder[i]), 
                              .i_quotient(curr_quotient[i]), 
                              .o_dividend(curr_dividend[i + 1]), 
                              .o_remainder(curr_remainder[i + 1]),
                              .o_quotient(curr_quotient[i+1])
                              );
      end
      assign o_quotient = curr_quotient[15];
      assign o_remainder = curr_remainder[15];
endmodule // lc4_divider

module lc4_divider_one_iter(input  wire [15:0] i_dividend,
                            input  wire [15:0] i_divisor,
                            input  wire [15:0] i_remainder,
                            input  wire [15:0] i_quotient,
                            output wire [15:0] o_dividend,
                            output wire [15:0] o_remainder,
                            output wire [15:0] o_quotient);

      /*** YOUR CODE HERE ***/
      wire [15:0] temp_remainder;
      assign temp_remainder = i_dividend >> 15 | i_remainder << 1;

      // Calculate Remainder
      wire [15:0] subtract;
      assign subtract = temp_remainder - i_divisor;

      wire [15:0] out_curr_remainder;
      assign out_curr_remainder = (temp_remainder >= i_divisor) ? subtract : temp_remainder;

      // Calculate quotient
      wire [15:0] shift_quotient;
      assign shift_quotient = i_quotient << 1;
      wire [15:0] out_curr_quotient;
      assign out_curr_quotient =  (temp_remainder >= i_divisor) ? shift_quotient | 1'b1 : shift_quotient; 

      assign o_dividend = i_dividend << 1;
      assign o_quotient = (i_divisor != 0) ? out_curr_quotient : 16'b0;
      assign o_remainder = (i_divisor != 0) ? out_curr_remainder : 16'b0;
endmodule
