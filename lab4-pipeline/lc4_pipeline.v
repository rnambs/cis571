/* Lorenzo Lucena Maguire (llucena) and Rahul Nambiar (rnambiar) */

// NOT TOO SURE WHATS WRONG - I THINK NZP?
`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // main clock
    input wire         rst, // global reset
    input wire         gwe, // global we for single-step clock
                                    
    output wire [15:0] o_cur_pc, // Address to read from instruction memory
    input wire [15:0]  i_cur_insn, // Output of instruction memory
    output wire [15:0] o_dmem_addr, // Address to read/write from/to data memory
    input wire [15:0]  i_cur_dmem_data, // Output of data memory
    output wire        o_dmem_we, // Data memory write enable
    output wire [15:0] o_dmem_towrite, // Value to write to data memory
   
    output wire [1:0]  test_stall, // Testbench: is this is stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc, // Testbench: program counter
    output wire [15:0] test_cur_insn, // Testbench: instruction bits
    output wire        test_regfile_we, // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel, // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data, // Testbench: value to write into the register file
    output wire        test_nzp_we, // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits, // Testbench: value to write to NZP bits
    output wire        test_dmem_we, // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr, // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data, // Testbench: value read/writen from/to memory

    input wire [7:0]   switch_data, // Current settings of the Zedboard switches
    output wire [7:0]  led_data // Which Zedboard LEDs should be turned on?
    );
   
   /*** YOUR CODE HERE ***/

   // UNUSED WIRES
   assign led_data = 8'h00;


   /**
      
      
      FETCH 
      Input: PC
   */
   wire [15:0]   change_pc;
   wire [15:0]   f_pc;

   Nbit_reg #(16, 16'h8200) f_pc_reg (.in(f_pc), .out(change_pc), .clk(clk), .we(pc_reg_we), .gwe(gwe), .rst(rst));
   
   wire [15:0] pc_plus_one;
   cla16 cla(.a(change_pc),
            .b(16'b0),
            .cin(1'b1),
            .sum(pc_plus_one)
         );

   assign f_pc = (stall_flushing_full == 1'b1) ? change_pc_branch : pc_plus_one;

   wire pc_reg_we;
   assign pc_reg_we = (decode_stall_logic_complete == 2'b11) ? 1'b0 : 1'b1;
  
   assign o_cur_pc = change_pc;

   //FETCH PC STALL LOGIC
   wire [1:0] f_pc_stall;
   assign f_pc_stall = (change_pc == 16'h8200) ? 2'b0 : (stall_flushing_full == 1'b1 & change_pc != 16'h8200) ? 2'b10 : 2'b0;

   /**
      DECODE
      Input: PC, Instruction (i_cur_insn)
   */
   wire [15:0]   d_pc;
   wire [15:0]   change_d_pc;

   Nbit_reg #(16, 16'h8200) d_pc_reg (.in(change_d_pc), .out(d_pc), .clk(clk), .we(d_pc_reg_we), .gwe(gwe), .rst(rst));
   assign change_d_pc = o_cur_pc;

   wire d_pc_reg_we;
   assign d_pc_reg_we = (decode_stall_logic_complete == 2'b11) ? 1'b0 : 1'b1;
   
   //PC+1 LOGIC
   wire [15:0] d_pc_plus_one;
   wire [15:0] d_pc_change;

   Nbit_reg #(16, 16'h8200) d_pc_plus_one_reg (.in(d_pc_change), .out(d_pc_plus_one), .clk(clk), .we(d_pc_reg_we), .gwe(gwe), .rst(rst));
   assign d_pc_change = f_pc;

   // REGISTERS FOR DECODE
   wire [15:0]   d_insn;      
   wire [15:0]   d_i_change_insn;
   Nbit_reg #(16, 16'b0) d_insn_reg (.in(d_i_change_insn), .out(d_insn), .clk(clk), .we(d_pc_reg_we), .gwe(gwe), .rst(rst));
   assign d_i_change_insn = i_cur_insn;

   wire d_r1re, d_r2re, d_regfile_we, d_nzp_we, d_select_pc_plus_one, d_is_load, d_is_store, d_is_branch, d_is_control_insn;
   wire [2:0] d_r1_sel, d_r2_sel, d_rd_sel;

   lc4_decoder decoder(
      .insn(d_insn), 
      .r1sel(d_r1_sel), 
      .r1re(d_r1re),
      .r2sel(d_r2_sel), 
      .r2re(d_r2re), 
      .wsel(d_rd_sel),
      .regfile_we(d_regfile_we), 
      .nzp_we(d_nzp_we), 
      .select_pc_plus_one(d_select_pc_plus_one),
      .is_load(d_is_load), 
      .is_store(d_is_store), 
      .is_branch(d_is_branch), 
      .is_control_insn(d_is_control_insn)
      );

   // REGFILE HERE
   wire [15:0] d_o_r1_data, d_o_r2_data;
   lc4_regfile #(16) reg_lc4(.clk(clk), 
      .gwe(gwe), 
      .rst(rst), 
      .i_rs(d_r1_sel), 
      .o_rs_data(d_o_r1_data),
      .i_rt(d_r2_sel), 
      .o_rt_data(d_o_r2_data), 
      .i_rd(wb_wsel), 
      .i_wdata(regfile_in),
      .i_rd_we(wb_regfile_we)
      );

   // WD BYPASS - NEEDS CHECKING
   wire [15:0] d_out_r1_data, d_out_r2_data;
   assign d_out_r1_data = (wb_wsel == d_r1_sel & wb_regfile_we == 1'b1) ? regfile_in : 
                        d_o_r1_data;

   assign d_out_r2_data = (wb_wsel == d_r2_sel & wb_regfile_we == 1'b1) ? regfile_in : 
                        d_o_r2_data;

   
   // STALL LOGIC HERE
   wire [1:0] d_stall;      
   wire [1:0] d_stall_change_insn; 
   Nbit_reg #(2, 2'b10) d_stall_reg (.in(d_stall_change_insn), .out(d_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign d_stall_change_insn = f_pc_stall;

   wire first_stall_logic, temp_stall_logic;
   assign temp_stall_logic = ((xec_rd_sel == d_r1_sel & d_r1re == 1'b1) | (xec_rd_sel == d_r2_sel & d_r2re == 1'b1 & d_is_store == 1'b0));
   assign first_stall_logic = (xec_is_load == 1'b1) & temp_stall_logic ? 1'b1 : 1'b0;
  
   wire second_stall_logic;
   assign second_stall_logic = (xec_is_load == 1'b1 & (d_is_branch))  | first_stall_logic;
   
   wire d_stall_final;
   assign d_stall_final = (xec_stall == 2'b11) ? 1'b0 : (xec_stall == 2'b10) ? 1'b0 : second_stall_logic;
 
   wire [1:0] decode_stall_logic_complete;
   assign decode_stall_logic_complete = (d_stall == 2'b10) ? 2'b10 : 
                          (d_stall_final == 1'b1) ? 2'b11 :
                          (stall_flushing_full == 1'b1) ? 2'b10 : 2'b0;

   //FLUSHING LOGIC - NEED TO CHECK HERE
   wire dec_r1re, dec_r2re, dec_regfile_we, dec_nzp_we, dec_select_pc_plus_one, dec_is_load, dec_is_store, dec_is_branch, dec_is_control_insn;
   wire [15:0] dec_out_r1_data, dec_out_r2_data;
   assign dec_r1re = d_r1re;
   assign dec_r2re = d_r2re;
   assign dec_regfile_we = (d_stall_final == 1'b1 | d_stall == 2'b10 | stall_flushing_full == 1'b1) ? 1'b0 : d_regfile_we;
   assign dec_is_store = (d_stall_final == 1'b1 | d_stall == 2'b10 | stall_flushing_full == 1'b1) ? 1'b0 : d_is_store;
   assign dec_nzp_we = (d_stall_final == 1'b1 | d_stall == 2'b10 | stall_flushing_full == 1'b1) ? 1'b0 : d_nzp_we;
   assign dec_select_pc_plus_one = d_select_pc_plus_one;
   assign dec_is_load = d_is_load;
   assign dec_is_branch = d_is_branch;
   assign dec_is_control_insn = d_is_control_insn;
   assign dec_out_r1_data = d_out_r1_data;
   assign dec_out_r2_data = d_out_r2_data;


   /**
      EXECUTE
      INPUT: 
         - PC, INSN, R1_DATA, R2_DATA
         - CONTROL SIGNALS:
                d_r1re; // does this instruction read from rs
                d_r2re; // does this instruction read from rt?
                d_regfile_we; // does this instruction write to rd?
                d_nzp_we; // does this instruction write the NZP bits?
                d_select_pc_plus_one; // wrtie PC+1 to the regfile?
                d_is_load; // is this a load instruction?
                d_is_store; // is this is a store instruction?
                d_is_branch; // is this a branch instruction?
                d_is_control_insn; // is this a control instruction?
   **/

   wire [15:0]   xec_pc;
   wire [15:0]   change_xec_pc;

   Nbit_reg #(16, 16'h8200) xec_pc_reg (.in(change_xec_pc), .out(xec_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign change_xec_pc = d_pc;

   // PC+1 STUFF HERE
   wire [15:0]   xec_pc_plus_one;
   wire [15:0]   xec_pc_change;

   Nbit_reg #(16, 16'h8200) xec_pc_plus_one_reg (.in(xec_pc_change), .out(xec_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_pc_change = d_pc_plus_one;


   //INSNS
   wire [15:0]   xec_insn;
   wire [15:0]   xec_change_insn;
   Nbit_reg #(16, 16'b0) xec_insn_reg (.in(xec_change_insn), .out(xec_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_change_insn = d_insn;

   // RS REGISTER
   wire [15:0]   xec_o_r1_data;
   wire [15:0]   xec_o_r1_data_change;
   Nbit_reg #(16, 16'b0) xec_r1_reg (.in(xec_o_r1_data_change), .out(xec_o_r1_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_o_r1_data_change = dec_out_r1_data;

   //RT REGISTERS
   wire [15:0]   xec_o_r2_data;
   wire [15:0]   xec_o_r2_data_change;
   Nbit_reg #(16, 16'b0) xec_r2_reg (.in(xec_o_r2_data_change), .out(xec_o_r2_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_o_r2_data_change = dec_out_r2_data;

   //REGFILE
   wire   xec_regfile_we;      
   wire   xec_regfile_we_change; 
   Nbit_reg #(1, 1'b0) xec_regfile (.in(xec_regfile_we_change), .out(xec_regfile_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_regfile_we_change = dec_regfile_we;

   // NEED TO CHECK IF THERES A WAY TO COMBINE IN ONE - THIS IS LONG....
   wire   xsel_pc_plus_one;
   wire   xsel_pc_plus_one_change;
   Nbit_reg #(1, 1'b0) select_pc_plus_one (.in(xsel_pc_plus_one_change), .out(xsel_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xsel_pc_plus_one_change = dec_select_pc_plus_one;

   wire   xec_is_control_insn;      
   wire   xec_change_is_control_insn; 
   Nbit_reg #(1, 1'b0) xisa_control_insn (.in(xec_change_is_control_insn), .out(xec_is_control_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_change_is_control_insn = dec_is_control_insn;

   wire   xec_is_branch;      
   wire   xec_change_is_branch; 
   Nbit_reg #(1, 1'b0) xec_branch (.in(xec_change_is_branch), .out(xec_is_branch), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_change_is_branch = dec_is_branch;

   wire   xec_is_store;      
   wire   xec_change_is_store; 
   Nbit_reg #(1, 1'b0) xec_store (.in(xec_change_is_store), .out(xec_is_store), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_change_is_store = dec_is_store;

   wire   xec_is_load;      
   wire   xec_change_is_load; 
   Nbit_reg #(1, 1'b0) xec_load (.in(xec_change_is_load), .out(xec_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_change_is_load = dec_is_load;

   wire [2:0]  xec_r1_sel;      
   wire [2:0]  xec_r1_sel_change; 
   Nbit_reg #(3, 3'b0) r1sel (.in(xec_r1_sel_change), .out(xec_r1_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_r1_sel_change = d_r1_sel;

   wire [2:0]  xec_r2sel;      
   wire [2:0]  xec_change_r2sel; 
   Nbit_reg #(3, 3'b0) r2sel (.in(xec_change_r2sel), .out(xec_r2sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_change_r2sel = d_r2_sel;

   wire [2:0]  xec_rd_sel;      
   wire [2:0]  xec_rd_sel_change; 
   Nbit_reg #(3, 3'b0) xwsel (.in(xec_rd_sel_change), .out(xec_rd_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_rd_sel_change = d_rd_sel;

   // NZP - ERRORS HERE
   wire xec_nzp_we;      
   wire xec_nzp_we_change;
   Nbit_reg #(1, 1'b0) xec_nzp_we_reg (.in(xec_nzp_we_change), .out(xec_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_nzp_we_change = dec_nzp_we;

   wire [15:0] xec_alu;

   //BYPASS LOGIC WORKING
   wire [15:0] bypass_mem_write_r1;
   assign bypass_mem_write_r1 = (mem_wsel == xec_r1_sel & mem_regfile_we == 1'b1) ? mem_regfile_in : 
                     (wb_wsel == xec_r1_sel & wb_regfile_we == 1'b1) ? regfile_in : 
                     xec_o_r1_data;

   wire [15:0] bypass_mem_write_r2;
   assign bypass_mem_write_r2 = (mem_wsel == xec_r2sel & mem_regfile_we == 1'b1) ? mem_regfile_in :
                     (wb_wsel == xec_r2sel & wb_regfile_we == 1'b1) ? regfile_in :
                     xec_o_r2_data;
   
   lc4_alu alu_impl(.i_insn(xec_insn), .i_pc(xec_pc), .i_r1data(bypass_mem_write_r1), .i_r2data(bypass_mem_write_r2),
                    .o_result(xec_alu));
   
   //NZP
   wire [2:0]   xec_nzp_curr;      
   wire [2:0]   xec_nzp_new_bits; 

   Nbit_reg #(3, 3'b000) xec_nzp_reg (.in(xec_nzp_new_bits), .out(xec_nzp_curr), .clk(clk), .we(xec_nzp_we), .gwe(gwe), .rst(rst));

   assign xec_nzp_new_bits = ($signed(xec_alu) < 0) ? 100 :
                           ($signed(xec_alu) > 0) ? 001 : 010;

   
   // STALL LOGIC HERE
   wire [1:0] xec_stall;      
   wire [1:0] xec_stall_change; 
   Nbit_reg #(2, 2'b10) xec_stall_reg (.in(xec_stall_change), .out(xec_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign xec_stall_change = decode_stall_logic_complete;

   //Branch Prediction - CHECK HERE
   wire [2:0] branch_nzp;
   assign branch_nzp = (mem_nzp_we == 1'b1 & mem_stall != 2'b11 & mem_stall != 2'b10) ? mem_nzp_curr : (wb_nzp_we == 1'b1 & wb_stall != 2'b11 & wb_stall != 2'b10) ? wb_nzp_curr : xec_nzp_curr;

   wire [15:0] change_pc_branch;
   assign change_pc_branch = xec_is_control_insn ? xec_alu : (xec_is_branch & (| (xec_insn[11:9] & branch_nzp))) ? xec_alu : xec_pc_plus_one; 
      
   wire stall_flushing_full;
   assign stall_flushing_full = (xec_stall == 2'b11) ? 1'b0 : (xec_stall == 2'b10) ? 1'b0 : ((xec_is_control_insn | (xec_is_branch & (| (xec_insn[11:9] & branch_nzp)))) ? 1'b1 : 1'b0);


   /**
      MEMORY
      INPUT: 
      - PC, INSN, R2_DATA, ALU_DATA
         - CONTROL SIGNALS:
                xec_r1re; // does this instruction read from rs
                xec_r2re; // does this instruction read from rt?
                xec_regfile_we; // does this instruction write to rd?
                xec_nzp_we; // does this instruction write the NZP bits?
                xec_select_pc_plus_one; // wrtie PC+1 to the regfile?
                xec_is_load; // is this a load instruction?
                xec_is_store; // is this is a store instruction?
                xec_is_branch; // is this a branch instruction?
                xec_is_control_insn; // is this a control instruction?
   **/
   wire [15:0]   mem_pc;
   wire [15:0]   change_mem_pc;

   Nbit_reg #(16, 16'h8200) mem_pc_reg (.in(change_mem_pc), .out(mem_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign change_mem_pc = xec_pc;

   wire [15:0]   mem_pc_plus_one;
   wire [15:0]   mem_pc_plus_one_change;

   Nbit_reg #(16, 16'h8200) mem_pc_plus_one_reg (.in(mem_pc_plus_one_change), .out(mem_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_pc_plus_one_change = xec_pc_plus_one;

   wire [15:0]   mem_insn;      
   wire [15:0]   mem_change_insn;
   Nbit_reg #(16, 16'b0) mem_insn_reg (.in(mem_change_insn), .out(mem_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_change_insn = xec_insn;

   wire [15:0]   mem_o_alu;
   wire [15:0]   mem_change_o_alu; 
   Nbit_reg #(16, 16'b0) mem_alu_reg (.in(mem_change_o_alu), .out(mem_o_alu), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_change_o_alu = xec_alu;

   wire  mem_regfile_we;
   wire  mem_change_regfile_we;
   Nbit_reg #(1, 1'b0) mem_regfile (.in(mem_change_regfile_we), .out(mem_regfile_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_change_regfile_we = xec_regfile_we;

   wire  mem_nzp_we;      
   wire  mem_change_nzp_we; 
   Nbit_reg #(1, 1'b0) mem_nzp (.in(mem_change_nzp_we), .out(mem_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_change_nzp_we = xec_nzp_we;

   wire  [2:0] mem_wsel;      
   wire  [2:0] mem_change_wsel; 
   Nbit_reg #(3, 3'b0) mwsel (.in(mem_change_wsel), .out(mem_wsel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_change_wsel = xec_rd_sel;

   wire  mem_select_pc_plus_one;      
   wire  mem_change_select_pc_plus_one; 
   Nbit_reg #(1, 1'b0) mselect_pc_plus_one (.in(mem_change_select_pc_plus_one), .out(mem_select_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_change_select_pc_plus_one = xsel_pc_plus_one;

   wire [2:0]   mem_check_nzp_curr;      
   wire [2:0]   mem_nzp_new_bits;  
   Nbit_reg #(3, 3'b000) mem_nzp_reg (.in(mem_nzp_new_bits), .out(mem_check_nzp_curr), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_nzp_new_bits = xec_nzp_curr;

   wire mem_is_store;      
   wire mem_change_is_store; 
   Nbit_reg #(1, 1'b0) mem_store (.in(mem_change_is_store), .out(mem_is_store), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_change_is_store = xec_is_store;

   wire mem_is_load;      
   wire mem_change_is_load; 
   Nbit_reg #(1, 1'b0) mem_load (.in(mem_change_is_load), .out(mem_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_change_is_load = xec_is_load;

   wire [1:0] mem_stall;      
   wire [1:0] mem_change_stall; 
   Nbit_reg #(2, 2'b10) mem_stall_reg (.in(mem_change_stall), .out(mem_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_change_stall = xec_stall;

   wire [2:0]  mem_r2sel;      
   wire [2:0]  mem_change_r2sel; 
   Nbit_reg #(3, 3'b0) mr2sel (.in(mem_change_r2sel), .out(mem_r2sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_change_r2sel = xec_r2sel;

   wire [15:0]   mem_o_rt_data;      
   wire [15:0]   mem_change_o_rt_data; 
   Nbit_reg #(16, 16'b0) mem_rt_reg (.in(mem_change_o_rt_data), .out(mem_o_rt_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_change_o_rt_data = xec_o_r2_data;

   wire [15:0]   mem_bypass_mem_r2;      
   wire [15:0]   mem_change_mxec_wxec_rt; 
   Nbit_reg #(16, 16'b0) mem_mxec_wxec_reg (.in(mem_change_mxec_wxec_rt), .out(mem_bypass_mem_r2), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign mem_change_mxec_wxec_rt = bypass_mem_write_r2;

   assign o_dmem_addr = (mem_is_load == 1'b1) ? mem_o_alu : (mem_is_store == 1'b1) ? mem_o_alu : 16'b0;
   assign o_dmem_we = mem_is_store;

   //WM BYPASS LOGIC - WORKS!
   wire [15:0] wmem_rt;
   assign wmem_rt = ((mem_is_store == 1'b1) & (wb_wsel == mem_r2sel) & (wb_regfile_we == 1'b1) & (wb_is_store == 1'b0)) ? regfile_in : 
                  mem_bypass_mem_r2;
   assign o_dmem_towrite = wmem_rt;

   wire [15:0] mem_regfile_in;
   assign mem_regfile_in = (mem_select_pc_plus_one == 1'b1) ? mem_pc_plus_one : (mem_is_load == 1'b1) ? i_cur_dmem_data : mem_o_alu;

   wire [2:0]   mem_nzp_curr;
   assign mem_nzp_curr = ($signed(mem_regfile_in) < 0) ? 100 :
                       ($signed(mem_regfile_in) > 0) ? 001 : 010;

   /**
      WRITEBACK
      
      INPUT: 
      - PC, INSN, ALU_DATA, I_CURR_MEM_DATA
      - CONTROL SIGNALS:
               mem_r1re; // does this instruction read from rs
               mem_r2re; // does this instruction read from rt?
               mem_regfile_we; // does this instruction write to rd?
               mem_nzp_we; // does this instruction write the NZP bits?
               mem_select_pc_plus_one; // wrtie PC+1 to the regfile?
               mem_is_load; // is this a load instruction?
               mem_is_store; // is this is a store instruction?
               mem_is_branch; // is this a branch instruction?
               mem_is_control_insn; // is this a control instruction?
   **/      

   wire [15:0]   wb_pc;
   wire [15:0]   wb_change_pc;

   Nbit_reg #(16, 16'h8200) wb_pc_reg (.in(wb_change_pc), .out(wb_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_change_pc = mem_pc;

   wire [15:0]   wb_pc_plus_one;
   wire [15:0]   wb_change_pc_plus_one;

   Nbit_reg #(16, 16'h8200) wb_pc_plus_one_reg (.in(wb_change_pc_plus_one), .out(wb_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_change_pc_plus_one = mem_pc_plus_one;

   wire [15:0]   wb_insn;
   wire [15:0]   wb_i_change_insn; 
   Nbit_reg #(16, 16'b0) wb_insn_reg (.in(wb_i_change_insn), .out(wb_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_i_change_insn = mem_insn;

   wire [15:0]   wb_o_alu;      
   wire [15:0]   wb_change_o_alu; 
   Nbit_reg #(16, 16'b0) wb_alu_reg (.in(wb_change_o_alu), .out(wb_o_alu), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_change_o_alu = mem_o_alu;

   wire  wb_regfile_we;      
   wire  wb_change_regfile_we; 
   Nbit_reg #(1, 1'b0) wb_regfile (.in(wb_change_regfile_we), .out(wb_regfile_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_change_regfile_we = mem_regfile_we;

   wire  wb_select_pc_plus_one;      
   wire  wb_change_select_pc_plus_one; 
   Nbit_reg #(1, 1'b0) wselect_pc_plus_one (.in(wb_change_select_pc_plus_one), .out(wb_select_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_change_select_pc_plus_one = mem_select_pc_plus_one;

   wire  wb_nzp_we;      
   wire  wb_change_nzp_we; 
   Nbit_reg #(1, 1'b0) wb_nzp (.in(wb_change_nzp_we), .out(wb_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_change_nzp_we = mem_nzp_we;

   wire   [2:0] wb_wsel;      
   wire   [2:0] wb_change_wsel; 
   Nbit_reg #(3, 3'b0) wwsel (.in(wb_change_wsel), .out(wb_wsel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_change_wsel = mem_wsel;

   wire [15:0] regfile_in;
   assign regfile_in = (wb_select_pc_plus_one == 1'b1) ? wb_pc_plus_one : (wb_is_load == 1'b1) ? wb_i_cur_dmem_data : wb_o_alu;
   
   wire  wb_is_store;      
   wire  wb_change_is_store; 
   Nbit_reg #(1, 1'b0) wb_store (.in(wb_change_is_store), .out(wb_is_store), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_change_is_store = mem_is_store;

   wire wb_is_load;      
   wire wb_change_is_load; 
   Nbit_reg #(1, 1'b0) wb_load (.in(wb_change_is_load), .out(wb_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_change_is_load = mem_is_load;


   wire [2:0]   wb_nzp_curr;      
   wire [2:0]   wb_nzp_new_bits;  
   Nbit_reg #(3, 3'b000) wb_nzp_reg (.in(wb_nzp_new_bits), .out(wb_nzp_curr), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_nzp_new_bits = mem_nzp_curr;

   wire [1:0] wb_stall;      
   wire [1:0] wb_change_stall; 
   Nbit_reg #(2, 2'b10) wb_stall_reg (.in(wb_change_stall), .out(wb_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_stall = mem_stall;

   wire [15:0] wb_o_dmem_addr;
   wire [15:0] wb_change_o_dmem_addr; 
   Nbit_reg #(16, 16'b10) wb_dmem_addr (.in(wb_change_o_dmem_addr), .out(wb_o_dmem_addr), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_change_o_dmem_addr = o_dmem_addr;

   wire [15:0] wb_o_dmem_towrite;
   wire [15:0] wb_change_o_dmem_towrite;
   Nbit_reg #(16, 16'b10) wb_dmem_towrite (.in(wb_change_o_dmem_towrite), .out(wb_o_dmem_towrite), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_change_o_dmem_towrite = o_dmem_towrite;

   wire [15:0] wb_i_cur_dmem_data;      
   wire [15:0] wb_change_i_cur_dmem_data; 
   Nbit_reg #(16, 16'b10) wi_cur_dmem_data (.in(wb_change_i_cur_dmem_data), .out(wb_i_cur_dmem_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign wb_change_i_cur_dmem_data = i_cur_dmem_data;

   // ASSIGN TEST WIRES - NEED TO CHECK ADDR, DATA, NZPS
   assign test_stall = wb_stall; 
   assign test_cur_pc = wb_pc;
   assign test_cur_insn = wb_insn;
   assign test_regfile_we = wb_regfile_we;
   assign test_regfile_wsel = wb_wsel;
   assign test_regfile_data = regfile_in;
   assign test_nzp_we = wb_nzp_we;
   assign test_dmem_addr = wb_o_dmem_addr;
   assign test_dmem_data = (wb_is_load == 1'b1) ? wb_i_cur_dmem_data : (wb_is_store == 1'b1) ? wb_o_dmem_towrite : 16'b0;
   assign test_dmem_we = wb_is_store;
   assign test_nzp_new_bits = wb_nzp_curr;



   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    * 
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    */
`ifndef NDEBUG
   always @(posedge gwe) begin
      //$display("%d PC: f: %h, d: %h, x: %h, m: %h, w: %h - change_pc: %h", $time, f_pc, d_pc, xec_pc, mem_pc, wb_pc, change_pc);
      //$display("%d INSN: f: %h, d: %h, x: %h, m: %h, w: %h", $time, i_cur_insn, d_insn, xec_insn, mem_insn, wb_insn);
      //$display("%d ALU INPUT: R%d:%d, R%d:%d, DEST: R%d, OUTPUT: %d", $time,xec_r1_sel, i_r1_alu, xec_r2_sel, i_r2_alu, xec_rd_sel, xec_alu_data);
      //$display("%d WRITEBACK: R%d %d we: %b", $time, wb_rd_sel, d_i_reg_data, wb_regfile_we);
      //$display("%d REG OUTPUT: R%d:%d, R%d:%d", $time, d_r1_sel, d_o_r1_data, d_r2_sel, d_o_r2_data);
      //$display("");
      // $display("%d mem_alu: %h, wb_alu: %h, pc_plus_one: %h, pc_branch: %b", 
      // $time, 
      // mem_alu_data, 
      // wb_alu_data, 
      // pc_plus_one, 
      // pc_branch);

      // // CONTROL SIGNALS
      // $display("%d d_r1re %b, d_r2re %b, d_regfile_we %b, d_nzp_we %b, d_select_pc_plus_one %b,  d_is_load %b, d_is_store %b, d_is_branch %b, d_is_control_insn %b", 
      // $time, 
      // d_r1re, d_r2re, d_regfile_we, d_nzp_we, d_select_pc_plus_one,  d_is_load, d_is_store, d_is_branch, d_is_control_insn);
      // $display("%d xec_r1re %b, xec_r2re %b, xec_regfile_we %b, xec_nzp_we %b, xec_select_pc_plus_one %b,  xec_is_load %b, xec_is_store %b, xec_is_branch %b, xec_is_control_insn %b", 
      // $time, 
      // xec_r1re, xec_r2re, xec_regfile_we, xec_nzp_we, xec_select_pc_plus_one,  xec_is_load, xec_is_store, xec_is_branch, xec_is_control_insn);
      if (o_dmem_we)
         $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.

      // basic if syntax:
      // if (cond) begin
      //    ...;
      //    ...;
      // end

      // Set a breakpoint on the empty $display() below
      // to step through your pipeline cycle-by-cycle.
      // You'll need to rewind the simulation to start
      // stepping from the beginning.

      // You can also simulate for XXX ns, then set the
      // breakpoint to start stepping midway through the
      // testbench.  Use the $time printouts you added above (!)
      // to figure out when your problem instruction first
      // enters the fetch stage.  Rewind your simulation,
      // run it for that many nano-seconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display(); 
   end
`endif
endmodule