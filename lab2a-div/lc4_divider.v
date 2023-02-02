/* Names: Rahul Nambiar and Lorenzo Lucena Maguire
   PennKey: rnambiar and 
*/

`timescale 1ns / 1ps
`default_nettype none

module lc4_divider(input  wire [15:0] i_dividend,
                   input  wire [15:0] i_divisor,
                   output wire [15:0] o_remainder,
                   output wire [15:0] o_quotient);

      /*** YOUR CODE HERE ***/

endmodule // lc4_divider

module lc4_divider_one_iter(input  wire [15:0] i_dividend,
                            input  wire [15:0] i_divisor,
                            input  wire [15:0] i_remainder,
                            input  wire [15:0] i_quotient,
                            output wire [15:0] o_dividend,
                            output wire [15:0] o_remainder,
                            output wire [15:0] o_quotient);

      /*** YOUR CODE HERE ***/
      assign out_dividend = i_dividend << 1;

      wire [15:0] curr_remainder;
      assign curr_remainder = i_dividend >> 15 | i_remainder << 1;

      wire [15:0] subtract;
      assign subtract = curr_remainder - i_divisor;

      wire [15:0] out_curr_remainder;
      assign out_curr_remainder = (curr_remainder < i_divisor) ? curr_remainder : subtract;

      wire [15:0] bits;
      assign bits = (curr_remainder < i_divisor) ? 1'b0 : 1'b1;

      wire [15:0] curr_quotient;
      assign curr_quotient = i_quotient << 1;

      wire [15:0] out_curr_quotient;
      assign out_curr_quotient = curr_quotient | {15'b0, bits};

      assign out_quotient = (i_divisor != 0) ? out_curr_quotient : 16'b0;
      assign out_remainder = (i_divisor != 0) ? out_curr_remainder : 16'b0;


endmodule
