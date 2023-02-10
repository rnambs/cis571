/* Lorenzo Lucena Maguire (llucena) and Rahul Nambiar (rnambiar) */

`timescale 1ns / 1ps
`default_nettype none

/**
 * @param a first 1-bit input
 * @param b second 1-bit input
 * @param g whether a and b generate a carry
 * @param p whether a and b would propagate an incoming carry
 */
module gp1(input wire a, b,
           output wire g, p);
   assign g = a & b;
   assign p = a | b;
endmodule

/**
 * Computes aggregate generate/propagate signals over a 4-bit window.
 * @param gin incoming generate signals 
 * @param pin incoming propagate signals
 * @param cin the incoming carry
 * @param gout whether these 4 bits collectively generate a carry (ignoring cin)
 * @param pout whether these 4 bits collectively would propagate an incoming carry (ignoring cin)
 * @param cout the carry outs for the low-order 3 bits
 */
module gp4(input wire [3:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [2:0] cout);
           // code here
           assign gout = (gin[3]) | (gin[2] & pin[3]) | 
           (gin[1] & pin[2] & pin[3]) | (gin[0] & pin[1] & pin[2] & pin[3]);
           assign pout = pin[0] & pin[1] & pin[2] & pin[3];

           assign cout[0] = gin[0] | (pin[0] & cin);
           assign cout[1] = gin[1] | (pin[1] & gin[0]) | (pin[0] & pin[1] & cin);
           assign cout[2] = gin[2] | (pin[2] & gin[1]) | (pin[1] & pin[2] & gin[0]) | (pin[0] & pin[1] & pin[2] & cin);

           
endmodule

/**
 * 16-bit Carry-Lookahead Adder
 * @param a first input
 * @param b second input
 * @param cin carry in
 * @param sum sum of a + b + carry-in
 */
module cla16
  (input wire [15:0]  a, b,
   input wire         cin,
   output wire [15:0] sum);
  
  wire [15:0] cry;
  wire [15:0] gen_in;
  wire [15:0] prop_in;
  wire [3:0] gen_out;
  wire [3:0] prop_out;
  wire gen_out_last;
  wire prop_out_last;
  wire[2:0] cout_last;

  genvar count;
  // gp1
  for (count = 0; count < 16; count = count + 1) begin
    gp1 g (.a(a[count]), .b(b[count]), .g(gen_in[count]), .p(prop_in[count]));
  end

  //gp4
  gp4 _0 (.gin(gen_in[3:0]), .pin(prop_in[3:0]), .cin(cin), .gout(gen_out[0]), .pout(prop_out[0]), .cout(cry[3:1]));

  gp4 _1 (.gin(gen_in[7:4]), .pin(prop_in[7:4]), .cin(cry[4]), .gout(gen_out[1]), .pout(prop_out[1]), .cout(cry[7:5]));

  gp4 _2 (.gin(gen_in[11:8]), .pin(prop_in[11:8]), .cin(cry[8]), .gout(gen_out[2]), .pout(prop_out[2]), .cout(cry[11:9]));

  gp4 _3 (.gin(gen_in[15:12]), .pin(prop_in[15:12]), .cin(cry[12]), .gout(gen_out[3]), .pout(prop_out[3]), .cout(cry[15:13]));

  gp4 _4 (.gin(gen_out[3:0]), .pin(prop_out[3:0]), .cin(cin), .gout(gen_out_last), .pout(prop_out_last), .cout(cout_last));

  // final sum
  assign cry[0] = cin;
  assign cry[4] = cout_last[0];
  assign cry[8] = cout_last[1];
  assign cry[12] = cout_last[2];
  assign sum = a ^ b ^ cry;

endmodule


/** Lab 2 Extra Credit, see details at
  https://github.com/upenn-acg/cis501/blob/master/lab2-alu/lab2-cla.md#extra-credit
 If you are not doing the extra credit, you should leave this module empty.
 */
module gpn
  #(parameter N = 4)
  (input wire [N-1:0] gin, pin,
   input wire  cin,
   output wire gout, pout,
   output wire [N-2:0] cout);
 
endmodule
