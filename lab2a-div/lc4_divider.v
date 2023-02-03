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
      wire [15:0] curr_quotient;
      wire [15:0] dividend_temp;
      wire [15:0] curr_remainder;


      lc4_divider_one_iter first(.i_dividend(i_dividend), .i_divisor(i_divisor), .i_remainder(16'b0),
                              .i_quotient(16'b0), .o_dividend(dividend_temp[0]), .o_remainder(curr_remainder[0]),
                              .o_quotient(curr_quotient[0]));

      genvar count;
      for (count = 1; count < 15; count= count+1) begin
            lc4_divider_one_iter middle(.i_dividend(dividend_temp[count-1]), .i_divisor(i_divisor), .i_remainder(curr_remainder[count-1]),
                              .i_quotient(curr_quotient[count-1]), .o_dividend(dividend_temp[count]), .o_remainder(curr_remainder[count]),
                              .o_quotient(curr_quotient[count]));
      end

      lc4_divider_one_iter last(.i_dividend(dividend_temp[14]), .i_divisor(i_divisor), .i_remainder(curr_remainder[14]),
                              .i_quotient(curr_quotient[14]), .o_dividend(dividend_temp[15]), .o_remainder(o_remainder),
                              .o_quotient(o_quotient));


endmodule // lc4_divider

module lc4_divider_one_iter(input  wire [15:0] i_dividend,
                            input  wire [15:0] i_divisor,
                            input  wire [15:0] i_remainder,
                            input  wire [15:0] i_quotient,
                            output wire [15:0] o_dividend,
                            output wire [15:0] o_remainder,
                            output wire [15:0] o_quotient);

      /*** YOUR CODE HERE ***/

      wire [15:0] curr_remainder;
      assign curr_remainder = i_remainder << 1 | i_dividend >> 15;

      assign o_dividend = i_dividend << 1;

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

      assign o_quotient = (i_divisor == 0) ? 16'b0 : out_curr_quotient;
      assign o_remainder = (i_divisor == 0) ? 16'b0 : out_curr_remainder;


endmodule
