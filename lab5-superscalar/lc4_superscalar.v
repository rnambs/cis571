`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_processor(input wire         clk,             // main clock
                     input wire         rst,             // global reset
                     input wire         gwe,             // global we for single-step clock

                     output wire [15:0] o_cur_pc,        // address to read from instruction memory
                     input wire [15:0]  i_cur_insn_A,    // output of instruction memory (pipe A)
                     input wire [15:0]  i_cur_insn_B,    // output of instruction memory (pipe B)

                     output wire [15:0] o_dmem_addr,     // address to read/write from/to data memory
                     input wire [15:0]  i_cur_dmem_data, // contents of o_dmem_addr
                     output wire        o_dmem_we,       // data memory write enable
                     output wire [15:0] o_dmem_towrite,  // data to write to o_dmem_addr if we is set

                     // testbench signals (always emitted from the WB stage)
                     output wire [ 1:0] test_stall_A,        // is this a stall cycle?  (0: no stall,
                     output wire [ 1:0] test_stall_B,        // 1: pipeline stall, 2: branch stall, 3: load stall)

                     output wire [15:0] test_cur_pc_A,       // program counter
                     output wire [15:0] test_cur_pc_B,
                     output wire [15:0] test_cur_insn_A,     // instruction bits
                     output wire [15:0] test_cur_insn_B,
                     output wire        test_regfile_we_A,   // register file write-enable
                     output wire        test_regfile_we_B,
                     output wire [ 2:0] test_regfile_wsel_A, // which register to write
                     output wire [ 2:0] test_regfile_wsel_B,
                     output wire [15:0] test_regfile_data_A, // data to write to register file
                     output wire [15:0] test_regfile_data_B,
                     output wire        test_nzp_we_A,       // nzp register write enable
                     output wire        test_nzp_we_B,
                     output wire [ 2:0] test_nzp_new_bits_A, // new nzp bits
                     output wire [ 2:0] test_nzp_new_bits_B,
                     output wire        test_dmem_we_A,      // data memory write enable
                     output wire        test_dmem_we_B,
                     output wire [15:0] test_dmem_addr_A,    // address to read/write from/to memory
                     output wire [15:0] test_dmem_addr_B,
                     output wire [15:0] test_dmem_data_A,    // data to read/write from/to memory
                     output wire [15:0] test_dmem_data_B,

                     // zedboard switches/display/leds (ignore if you don't want to control these)
                     input  wire [ 7:0] switch_data,         // read on/off status of zedboard's 8 switches
                     output wire [ 7:0] led_data             // set on/off status of zedboard's 8 leds
                     );

   /***  YOUR CODE HERE ***/

      FETCH 
      Input: PC
   */
   wire [15:0]   f_pc, next_pc, pc_plus_one;
   Nbit_reg #(16, 16'h8200) next_pc_reg (.in(next_pc), .out(f_pc), .clk(clk), .we(pc_reg_we), .gwe(gwe), .rst(rst));
   

   // some stall logic check here to put correct value into b(in)

   // PC + 1
   cla16 cla(.a(f_pc),
            .b(16'b0),
            .cin(1'b1),
            .sum(pc_plus_one)
         );

   assign next_pc = pc_plus_one
  
   assign o_cur_pc = f_pc;

   // FETCH PC STALL LOGIC
   wire [1:0] f_stall = 2'b0;

   /**
      DECODE
      Input: PC, Instruction (i_cur_insn_A)
   */
   wire [15:0]   d_pc_Apple, d_pc_Apple_plus_one, d_insn_Apple;
   wire d_pc_Apple_reg_we = !(decode_stall_logic_complete == 2'b11);

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) d_pc_Apple_reg (.in(f_pc), .out(d_pc_Apple), .clk(clk), .we(d_pc_Apple_reg_we), .gwe(gwe), .rst(rst));

   //PC+1 LOGIC
   Nbit_reg #(16, 16'h8200) d_pc_Apple_plus_one_reg (.in(next_pc), .out(d_pc_Apple_plus_one), .clk(clk), .we(d_pc_Apple_reg_we), .gwe(gwe), .rst(rst));

   // Fetched instruction register, starts at 0000h at bootup
   Nbit_reg #(16, 16'b0) d_insn_reg (.in(i_cur_insn_A), .out(d_insn_Apple), .clk(clk), .we(d_pc_Apple_reg_we), .gwe(gwe), .rst(rst));

   // Control Signals
   wire d_r1re_Apple, d_r2re_Apple, d_regfile_we_Apple, d_nzp_we_Apple, d_select_pc_plus_one_Apple, d_is_load_Apple, d_is_store_Apple, d_is_branch_Apple, d_is_control_insn_Apple;
   wire [2:0] d_r1_sel_Apple, d_r2_sel_Apple, d_rd_sel_Apple;

   // Decode signals
   lc4_decoder decoder(
                  .insn(d_insn_Apple), //instruction
                  .r1sel(d_r1_sel_Apple), //rs
                  .r1re(d_r1re_Apple), // does this instruction read from rs?
                  .r2sel(d_r2_sel_Apple), // rt
                  .r2re(d_r2re_Apple), // does this instruction read from rt?
                  .wsel(d_rd_sel_Apple), // rd
                  .regfile_we(d_regfile_we_Apple), // does this instruction write to rd?
                  .nzp_we(d_nzp_we_Apple), // does this instruction write to NZP bits?
                  .select_pc_plus_one(d_select_pc_plus_one_Apple), // write PC+1 to regfile?
                  .is_load(d_is_load_Apple), // is this a load instruction?
                  .is_store(d_is_store_Apple), // is this a store instruction?
                  .is_branch(d_is_branch_Apple), // is this a branch instruction?
                  .is_control_insn(d_is_control_insn_Apple) // is this a control instruction?
                  );

   // STALL LOGIC
   wire [1:0] d_stall_Apple;  
   Nbit_reg #(2, 2'b10) d_stall_Apple_reg (.in(f_stall), .out(d_stall_Apple), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));


   // THIS IS THE DECODE FOR PIPE B
   wire [15:0]   d_pc_Banana, d_pc_Banana_plus_one, d_insn_Banana;

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) d_pc_Banana_reg (.in(f_pc), .out(d_pc_Banana), .clk(clk), .we(d_pc_Banana_reg_we), .gwe(gwe), .rst(rst));

   wire d_pc_Banana_reg_we = !(decode_stall_logic_complete == 2'b11);

   wire [15:0] pc_plus_one_Banana;
   cla16 add_pc_B_decode(.a(o_cur_pc), .b(16'b0), .cin(1'b1), .sum(pc_plus_one_Banana));

   // Fetched instruction register, starts at 0000h at bootup
   Nbit_reg #(16, 16'b0) d_insn_reg_Banana (.in(i_cur_insn_B), .out(d_insn_Banana), .clk(clk), .we(d_pc_Banana_reg_we), .gwe(gwe), .rst(rst));
   
   // Control Signals
   wire d_r1re_Banana, d_r2re_Banana, d_regfile_we_Banana, d_nzp_we_Banana, d_select_pc_plus_one_Banana, d_is_load_Banana, d_is_store_Banana, d_is_branch_Banana, d_is_control_insn_Banana;
   wire [2:0] d_r1_sel_Banana, d_r2_sel_Banana, d_rd_sel_Banana;

   // Decode signals
   lc4_decoder decoder(
                  .insn(d_insn_Banana), //instruction
                  .r1sel(d_r1_sel_Banana), //rs
                  .r1re(d_r1re_Banana), // does this instruction read from rs?
                  .r2sel(d_r2_sel_Banana), // rt
                  .r2re(d_r2re_Banana), // does this instruction read from rt?
                  .wsel(d_rd_sel_Banana), // rd
                  .regfile_we(d_regfile_we_Banana), // does this instruction write to rd?
                  .nzp_we(d_nzp_we_Banana), // does this instruction write to NZP bits?
                  .select_pc_plus_one(d_select_pc_plus_one_Banana), // write PC+1 to regfile?
                  .is_load(d_is_load_Banana), // is this a load instruction?
                  .is_store(d_is_store_Banana), // is this a store instruction?
                  .is_branch(d_is_branch_Banana), // is this a branch instruction?
                  .is_control_insn(d_is_control_insn_Banana) // is this a control instruction?
                  );

   wire [15:0] d_o_r1_data_Apple, d_o_r2_data_Apple, d_o_r1_data_Banana, d_o_r2_data_Banana;
   lc4_regfile_ss #(16) d_reg_lc4(.clk(clk), .gwe(gwe), .rst(rst), .i_rs_A(d_r1sel_Apple), .o_rs_data_A(d_o_rs_data_Apple),
                        .i_rt_A(d_r2sel_Apple), .o_rt_data_A(d_o_rt_data_Apple), .i_rs_B(d_r1sel_Banana), .o_rs_data_B(d_o_rs_data_Banana), .i_rt_B(d_r2sel_Banana),
                        .o_rt_data_B(d_o_rt_data_Banana), .i_rd_A(w_wsel_Apple), .i_wdata_A(w_o_alu_Apple), .i_rd_we_A(w_regfile_we_Apple), .i_rd_B(w_wsel_Banana), .i_wdata_B(w_o_alu_Banana), 
                        .i_rd_we_B(w_regfile_we_Banana));

   // STALL LOGIC
   wire [1:0] d_stall_Banana_test;
   Nbit_reg #(2, 2'b10) d_stall_Banana_test_reg (.in(f_stall), .out(d_stall_Banana_test), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   wire is_Banana_stall;
   assign is_Banana_stall = (d_stall_Banana_test != 2'b10) & (((d_r1_sel_Banana == d_rd_sel_Apple) & (d_r1re_Banana & d_regfile_we_Apple)) | ((d_rd_sel_Apple == d_r2_sel_Banana) & (d_regfile_we_Apple & d_r2re_Banana)));
   wire [1:0] d_stall_Banana;
   assign d_stall_Banana = (d_stall_Banana_test == 1'b1) ? 1'b0 : d_nzp_we_Banana;

   /**
      EXECUTE
      INPUT: 
         - PC, INSN, R1_DATA, R2_DATA
         - CONTROL SIGNALS:
                d_r1re_Apple; // does this instruction read from rs
                d_r2re_Apple; // does this instruction read from rt?
                d_regfile_we_Apple; // does this instruction write to rd?
                d_nzp_we_Apple; // does this instruction write the NZP bits?
                d_select_pc_plus_one_Apple; // wrtie PC+1 to the regfile?
                d_is_load_Apple; // is this a load instruction?
                d_is_store_Apple; // is this is a store instruction?
                d_is_branch_Apple; // is this a branch instruction?
                d_is_control_insn_Apple; // is this a control instruction?
   **/
   // Create registers for inputs for execute stage
   wire [15:0] x_pc, x_pc_plus_one, x_insn, x_o_r1_data, x_o_r2_data;
   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) x_pc_reg (.in(d_pc_Apple), .out(x_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // PC plus one
   Nbit_reg #(16, 16'h8200) x_pc_plus_one_reg (.in(d_pc_Apple_plus_one), .out(x_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // Fetched instruction register, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) x_insn_reg (.in(d_insn_Apple), .out(x_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // R1 DATA, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) x_r1_data_reg (.in(d_out_r1_data), .out(x_o_r1_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // R2 DATA, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) x_r2_data_reg (.in(d_out_r2_data), .out(x_o_r2_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // Register Selector Lines
   wire [2:0] x_r1_sel, x_r2_sel, x_rd_sel;
   Nbit_reg #(3, 3'b000) x_r1_sel_reg (.in(d_r1_sel_Apple), .out(x_r1_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b000) x_r2_sel_reg (.in(d_r2_sel_Apple), .out(x_r2_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b000) x_rd_sel_reg (.in(d_rd_sel_Apple), .out(x_rd_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // CONTROL SIGNALS
   wire [8:0] x_control_signals;
   Nbit_reg #(9, {9{1'b0}}) x_control_signals_reg (.in(d_control_signals), .out(x_control_signals), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   wire x_r1re, x_r2re, x_regfile_we, x_nzp_we, x_select_pc_plus_one,  x_is_load, x_is_store, x_is_branch, x_is_control_insn;
   assign {x_r1re, x_r2re, x_regfile_we, x_nzp_we, x_select_pc_plus_one,  x_is_load, x_is_store, x_is_branch, x_is_control_insn} = x_control_signals;
   
   //MX WX BYPASS
   wire[15:0] i_r1_alu = (m_rd_sel == x_r1_sel && m_regfile_we && x_r1re) ? m_regfile_in : 
                     (w_rd_sel == x_r1_sel && w_regfile_we && x_r1re ) ? w_regfile_in : 
                     x_o_r1_data;

   wire[15:0] i_r2_alu = (m_rd_sel == x_r2_sel && m_regfile_we && x_r2re) ? m_regfile_in :
                     (w_rd_sel == x_r2_sel & w_regfile_we && x_r2re) ? w_regfile_in :
                     x_o_r2_data;
                     
   // ALU
   wire [15:0] x_alu_data;

   lc4_alu alu_impl(
      .i_insn(x_insn), 
      .i_pc(x_pc), 
      .i_r1data(i_r1_alu), 
      .i_r2data(i_r2_alu),
      .o_result(x_alu_data)
      );
   
   // NZP
   wire [2:0]   x_nzp_curr, x_nzp_new;      
   assign x_nzp_new = ($signed(x_alu_data) < 0) ? 100 : ($signed(x_alu_data) > 0) ? 001 : 010;
   Nbit_reg #(3, 3'b000) x_nzp_reg (.in(x_nzp_new), .out(x_nzp_curr), .clk(clk), .we(x_nzp_we), .gwe(gwe), .rst(rst));

   // STALL LOGIC
   wire [1:0] x_stall;      
   Nbit_reg #(2, 2'b10) x_stall_reg (.in(decode_stall_logic_complete), .out(x_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   //Branch Prediction
   wire [2:0] branch_nzp = (m_nzp_we & m_stall != 2'b11 & m_stall != 2'b10) ? m_nzp_curr :
                            (w_nzp_we & w_stall != 2'b11 & w_stall != 2'b10) ? w_nzp_curr : x_nzp_curr;

   wire [15:0] change_pc_branch = x_is_control_insn ? x_alu_data :
                                 (x_is_branch & (| (x_insn[11:9] & branch_nzp))) ? x_alu_data :
                                  x_pc_plus_one; 
      
   wire stall_flushing_full = (x_stall == 2'b11 | x_stall == 2'b10) ? 1'b0 : 
                              (x_is_control_insn | (x_is_branch & (| (x_insn[11:9] & branch_nzp))));

   /**
      MEMORY
      INPUT: 
      - PC, INSN, R2_DATA, ALU_DATA
         - CONTROL SIGNALS:
                x_r1re; // does this instruction read from rs
                x_r2re; // does this instruction read from rt?
                x_regfile_we; // does this instruction write to rd?
                x_nzp_we; // does this instruction write the NZP bits?
                x_select_pc_plus_one; // wrtie PC+1 to the regfile?
                x_is_load; // is this a load instruction?
                x_is_store; // is this is a store instruction?
                x_is_branch; // is this a branch instruction?
                x_is_control_insn; // is this a control instruction?
   **/
  // Create registers for inputs for memory stage
   wire [15:0] m_pc, m_pc_plus_one, m_insn, m_alu_data, m_r2_data;
   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) m_pc_reg (.in(x_pc), .out(m_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // PC plus one
   Nbit_reg #(16, 16'h8200) m_pc_plus_one_reg(.in(x_pc_plus_one), .out(m_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // Fetched instruction register, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) m_insn_reg (.in(x_insn), .out(m_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // ALU DATA, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) m_alu_data_reg (.in(x_alu_data), .out(m_alu_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // R2 DATA, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) m_r2_data_reg (.in(i_r2_alu), .out(m_r2_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // Register Selector Lines
   wire [2:0] m_r1_sel, m_r2_sel, m_rd_sel;
   Nbit_reg #(3, 3'b000) m_r1_sel_reg (.in(x_r1_sel), .out(m_r1_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b000) m_r2_sel_reg (.in(x_r2_sel), .out(m_r2_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b000) m_rd_sel_reg (.in(x_rd_sel), .out(m_rd_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // CONTROL SIGNALS
   wire [8:0] m_control_signals;
   Nbit_reg #(9, {9{1'b0}}) m_control_signals_reg (.in(x_control_signals), .out(m_control_signals), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   wire m_r1re, m_r2re, m_regfile_we, m_nzp_we, m_select_pc_plus_one,  m_is_load, m_is_store, m_is_branch, m_is_control_insn; 
   assign {m_r1re, m_r2re, m_regfile_we, m_nzp_we, m_select_pc_plus_one,  m_is_load, m_is_store, m_is_branch, m_is_control_insn} = m_control_signals;
   // STALL SIGNAL
   wire [1:0] m_stall;      
   Nbit_reg #(2, 2'b10) m_stall_reg (.in(x_stall), .out(m_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   

   // WM BYPASS LOGIC
   assign o_dmem_towrite  = (m_is_store & (w_rd_sel == m_r2_sel) & w_regfile_we & ~w_is_store) ? w_regfile_in : m_r2_data;
   
   wire[15:0] m_regfile_in = m_select_pc_plus_one ? m_pc_plus_one : 
                              m_is_load ? i_cur_dmem_data : 
                              m_alu_data;
   // MEMORY LOGIC 
   assign o_dmem_addr = m_is_load |  m_is_store ? m_alu_data : 16'b0;
   assign o_dmem_we = m_is_store;
   
   // NZP
   wire[2:0] m_nzp_curr = ($signed(m_regfile_in) < 0) ? 100 :
                       ($signed(m_regfile_in) > 0) ? 001 : 010;

   /**
      WRITEBACK
      
      INPUT: 
      - PC, INSN, ALU_DATA, I_CURR_m_DATA
      - CONTROL SIGNALS:
               m_r1re; // does this instruction read from rs
               m_r2re; // does this instruction read from rt?
               m_regfile_we; // does this instruction write to rd?
               m_nzp_we; // does this instruction write the NZP bits?
               m_select_pc_plus_one; // wrtie PC+1 to the regfile?
               m_is_load; // is this a load instruction?
               m_is_store; // is this is a store instruction?
               m_is_branch; // is this a branch instruction?
               m_is_control_insn; // is this a control instruction?
   **/      

   wire [15:0] w_pc, w_pc_plus_one, w_insn, w_alu_data;
   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) w_pc_reg (.in(m_pc), .out(w_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // PC plus one
   Nbit_reg #(16, 16'h8200) w_pc_plus_one_reg (.in(m_pc_plus_one), .out(w_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // Fetched instruction register, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) w_insn_reg (.in(m_insn), .out(w_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // ALU DATA, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) w_alu_data_reg (.in(m_alu_data), .out(w_alu_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // Register Selector Lines
   wire [2:0] w_r1_sel, w_r2_sel, w_rd_sel;
   Nbit_reg #(3, 3'b000) w_r1_sel_reg (.in(m_r1_sel), .out(w_r1_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b000) w_r2_sel_reg (.in(m_r2_sel), .out(w_r2_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b000) w_rd_sel_reg (.in(m_rd_sel), .out(w_rd_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // CONTROL SIGNALS
   wire [8:0] w_control_signals;
   Nbit_reg #(9, {9{1'b0}}) w_control_signals_reg (.in(m_control_signals), .out(w_control_signals), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   wire w_r1re, w_r2re, w_regfile_we, w_nzp_we, w_select_pc_plus_one,  w_is_load, w_is_store, w_is_branch, w_is_control_insn; 
   assign { w_r1re, w_r2re, w_regfile_we, w_nzp_we, w_select_pc_plus_one,  w_is_load, w_is_store, w_is_branch, w_is_control_insn} = w_control_signals;
   // STALL SIGNAL
   wire [1:0] w_stall;      
   Nbit_reg #(2, 2'b10) w_stall_reg (.in(m_stall), .out(w_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // MEMORY VALUES
   wire [15:0] w_o_dmem_addr, w_o_dmem_towrite, w_i_curr_dmem_data;
   Nbit_reg #(16, 16'b10) w_dmem_addr_reg (.in(o_dmem_addr), .out(w_o_dmem_addr), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b10) w_dmem_towrite_reg (.in(o_dmem_towrite), .out(w_o_dmem_towrite), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) w_i_dmem_data_reg (.in(i_cur_dmem_data), .out(w_i_curr_dmem_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // NZP 
   wire [2:0]   w_nzp_curr;      
   Nbit_reg #(3, 3'b000) w_nzp_reg (.in(m_nzp_curr), .out(w_nzp_curr), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
  // Register Input Value
   wire [15:0] w_regfile_in = w_select_pc_plus_one  ? w_pc_plus_one : 
                              w_is_load  ? w_i_curr_dmem_data : 
                              w_alu_data;

   // ASSIGN TEST WIRES
   assign test_stall = w_stall; 
   assign test_cur_pc = w_pc;
   assign test_cur_insn = w_insn;
   assign test_regfile_we = w_regfile_we;
   assign test_regfile_wsel = w_rd_sel;
   assign test_regfile_data = w_regfile_in;
   assign test_nzp_we = w_nzp_we;
   assign test_dmem_addr = w_o_dmem_addr;
   assign test_dmem_data = (w_is_load == 1'b1) ? w_i_curr_dmem_data : (w_is_store == 1'b1) ? w_o_dmem_towrite : 16'b0;
   assign test_dmem_we = w_is_store;
   assign test_nzp_new_bits = w_nzp_curr;




   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    */
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc_Apple, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

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
      // run it for that many nanoseconds, then set
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
endmodule