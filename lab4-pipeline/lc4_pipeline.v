/* Lorenzo Lucena Maguire (llucena) and Rahul Nambiar (rnambiar) */

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

   // pc wires attached to the PC register's ports
   wire [15:0]   next_pc; // Next program counter (you compute this and feed it into next_pc)

   /**
      FETCH 
      Input: PC
   */
   wire [15:0]   f_pc;

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) f_pc_reg (.in(next_pc), .out(f_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   assign o_cur_pc = f_pc;

   wire [1:0] f_stall;
   assign f_stall = 2'b0;

   /**
      DECODE
      Input: PC, Instruction (i_cur_insn)
   */

   wire [15:0] d_pc, d_insn;



   // Create registers for inputs

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) d_pc_reg (.in(f_pc), .out(d_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // Fetched instruction register, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) d_insn_reg (.in(i_cur_insn), .out(d_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));



   // DECODER WIRES
   wire [2:0] d_r1_sel; // rs selector
   wire d_r1re; // does this instruction read from rs
   wire [2:0] d_r2_sel; // rt selector
   wire d_r2re; // does this instruction read from rt?
   wire [2:0] d_rd_sel; // rd selector
   wire d_regfile_we; // does this instruction write to rd?
   wire d_nzp_we; // does this instruction write the NZP bits?
   wire d_select_pc_plus_one; // wrtie PC+1 to the regfile?
   wire d_is_load; // is this a load instruction?
   wire d_is_store; // is this is a store instruction?
   wire d_is_branch; // is this a branch instruction?
   wire d_is_control_insn; // is this a control instruction?
   wire [8:0] d_control_signals = {d_r1re, d_r2re, d_regfile_we, d_nzp_we, d_select_pc_plus_one,  d_is_load, d_is_store, d_is_branch, d_is_control_insn};


   

   // Decode signals
   lc4_decoder decoder(
                  .insn(d_insn), //instruction
                  .r1sel(d_r1_sel), //rs
                  .r1re(d_r1re), // does this instruction read from rs?
                  .r2sel(d_r2_sel), // rt
                  .r2re(d_r2re), // does this instruction read from rt?
                  .wsel(d_rd_sel), // rd
                  .regfile_we(d_regfile_we), // does this instruction write to rd?
                  .nzp_we(d_nzp_we), // does this instruction write to NZP bits?
                  .select_pc_plus_one(d_select_pc_plus_one), // write PC+1 to regfile?
                  .is_load(d_is_load), // is this a load instruction?
                  .is_store(d_is_store), // is this a store instruction?
                  .is_branch(d_is_branch), // is this a branch instruction?
                  .is_control_insn(d_is_control_insn) // is this a control instruction?
                  );

   // Register File
   wire [15:0] d_o_r1_data, d_o_r2_data, d_i_reg_data;
   lc4_regfile #(.n(16)) reg_lc4(
      .clk(clk), 
      .gwe(gwe), 
      .rst(rst), 
      .i_rs(d_r1_sel), 
      .o_rs_data(d_o_r1_data),
      .i_rt(d_r2_sel), 
      .o_rt_data(d_o_r2_data), 
      .i_rd(d_rd_sel), 
      .i_wdata(d_i_reg_data),
      .i_rd_we(d_regfile_we)
      );

   wire [1:0] d_stall, d_stall_next;
   Nbit_reg #(2, 2'b10) d_stall_reg (.in(d_stall_next), .out(d_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign d_stall_next = f_stall;


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

   // Create registers for inputs for execute stage
   wire [15:0] x_pc, x_insn, x_o_r1_data, x_o_r2_data;
   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) x_pc_reg (.in(d_pc), .out(x_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // Fetched instruction register, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) x_insn_reg (.in(d_insn), .out(x_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // R1 DATA, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) x_r1_data_reg (.in(d_o_r1_data), .out(x_o_r1_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // R2 DATA, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) x_r2_data_reg (.in(d_o_r2_data), .out(x_o_r2_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // CONTROL SIGNALS
   
   wire [8:0] x_control_signals;
   Nbit_reg #(9, {9{1'b0}}) x_control_signals_reg (.in(d_control_signals), .out(x_control_signals), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   wire x_r1re, x_r2re, x_regfile_we, x_nzp_we, x_select_pc_plus_one,  x_is_load, x_is_store, x_is_branch, x_is_control_insn;
   assign {x_r1re, x_r2re, x_regfile_we, x_nzp_we, x_select_pc_plus_one,  x_is_load, x_is_store, x_is_branch, x_is_control_insn} = x_control_signals;
   // ALU         
   wire [15:0] x_o_alu_data;
   lc4_alu alu(.i_insn(x_insn), 
      .i_pc(x_pc), 
      .i_r1data(x_o_r1_data), 
      .i_r2data(x_o_r2_data),
      .o_result(x_o_alu_data)
      );

   wire [1:0] x_stall, x_stall_next;
   Nbit_reg #(2, 2'b10) x_stall_reg (.in(x_stall_next), .out(x_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign x_stall_next = d_stall;


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

   wire [15:0] m_pc, m_insn, m_alu_data, m_r2_data;
   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) m_pc_reg (.in(x_pc), .out(m_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // Fetched instruction register, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) m_insn_reg (.in(x_insn), .out(m_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // ALU DATA, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) m_alu_data_reg (.in(x_o_alu_data), .out(m_alu_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // R2 DATA, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) m_r2_data_reg (.in(x_o_r2_data), .out(m_r2_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // CONTROL SIGNALS
   wire [8:0] m_control_signals;
   Nbit_reg #(9, {9{1'b0}}) m_control_signals_reg (.in(x_control_signals), .out(m_control_signals), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   wire m_r1re, m_r2re, m_regfile_we, m_nzp_we, m_select_pc_plus_one,  m_is_load, m_is_store, m_is_branch, m_is_control_insn; 
   assign {m_r1re, m_r2re, m_regfile_we, m_nzp_we, m_select_pc_plus_one,  m_is_load, m_is_store, m_is_branch, m_is_control_insn} = m_control_signals;


   // MEMORY
   assign o_dmem_addr = (m_is_load == 1'b1) ? m_alu_data : (m_is_store == 1'b1) ? m_alu_data : 16'b0;
   assign o_dmem_towrite = m_r2_data;
   assign o_dmem_we = m_is_store;

   wire [1:0] m_stall, m_stall_next;
   Nbit_reg #(2, 2'b10) m_stall_reg (.in(m_stall_next), .out(m_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign m_stall_next = x_stall;



   /**
      WRITEBACK
      
      INPUT: 
      - PC, INSN, ALU_DATA, I_CURR_MEM_DATA
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

   wire [15:0] w_pc, w_insn, w_alu_data, w_i_curr_dmem_data;
   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) w_pc_reg (.in(m_pc), .out(w_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // Fetched instruction register, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) w_insn_reg (.in(m_insn), .out(w_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // ALU DATA, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) w_alu_data_reg (.in(m_alu_data), .out(w_alu_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // R2 DATA, starts at 0000h at bootup
   Nbit_reg #(16, 16'h0000) w_r2_data_reg (.in(i_cur_dmem_data), .out(w_i_curr_dmem_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // CONTROL SIGNALS
   
   wire [8:0] w_control_signals;
   Nbit_reg #(9, {9{1'b0}}) w_control_signals_reg (.in(m_control_signals), .out(w_control_signals), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   wire w_r1re, w_r2re, w_regfile_we, w_nzp_we, w_select_pc_plus_one,  w_is_load, w_is_store, w_is_branch, w_is_control_insn; 
   assign { w_r1re, w_r2re, w_regfile_we, w_nzp_we, w_select_pc_plus_one,  w_is_load, w_is_store, w_is_branch, w_is_control_insn} = w_control_signals;

   // Control signals logic
   wire [15:0] pc_plus_one;
   cla16 cla(.a(w_pc), 
      .b(16'b0), 
      .cin(1'b1), 
      .sum(pc_plus_one)
      );


   // Register Input Mux
   assign d_i_reg_data = (w_select_pc_plus_one == 1'b1) ? pc_plus_one : (w_is_load == 1'b1) ? w_i_curr_dmem_data : w_alu_data;

      
   // NZP Register and Branch stuff (issues here)
   wire [2:0] i_nzp =  ($signed(d_i_reg_data) < 0) ? 100 :
                       ($signed(d_i_reg_data) > 0) ? 001 : 010;
   wire [2:0] o_nzp;

   Nbit_reg #(3, 3'b000) nzp_reg (.in(i_nzp), .out(o_nzp), .clk(clk), .we(w_nzp_we), .gwe(gwe), .rst(rst));
   

   wire pc_branch, o_nzp_test;
   assign o_nzp_test = (| (w_insn[11:9] & o_nzp));
   assign pc_branch = w_is_control_insn | (o_nzp_test & w_is_branch);

   assign next_pc = pc_branch ? w_alu_data : pc_plus_one;

   wire [1:0] w_stall, w_stall_next;
   Nbit_reg #(2, 2'b10) w_stall_reg (.in(w_stall_next), .out(w_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign w_stall_next = m_stall;
   

   
   // Assign test wires
   assign test_stall = w_stall; //Testbench: is this a stall cycle? (don't compare the test values)
   assign test_cur_pc = w_pc; // Testbench: program counter
   assign test_cur_insn = w_insn; // Testbench: instruction bits
   assign test_regfile_we = w_regfile_we; // Testbench: register file write enable
   assign test_regfile_wsel = w_insn[11:8]; // Testbench: which register to write in the register file 
   assign test_regfile_data = d_i_reg_data; // Testbench: value to write into the register file
   assign test_nzp_we = w_nzp_we; // Testbench: NZP condition codes write enable
   assign test_nzp_new_bits = i_nzp; // Testbench: value to write to NZP bits
   assign test_dmem_we = w_is_store; // Testbench: data memory write enable
   assign test_dmem_addr = o_dmem_addr; // Testbench: address to read/write memory
   assign test_dmem_data = (w_is_load == 1'b1) ? w_i_curr_dmem_data : (w_is_store == 1'b1) ? o_dmem_towrite : 16'b0; // Testbench: value read/writen from/to memory



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
      $display("%d PC: f: %h, d: %h, x: %h, m: %h, w: %h - next_pc: %h", $time, f_pc, d_pc, x_pc, m_pc, w_pc, next_pc);
      $display("%d INSN: f: %h, d: %h, x: %h, m: %h, w: %h", $time, i_cur_insn, d_insn, x_insn, m_insn, w_insn);
      
      // $display("%d m_alu: %h, w_alu: %h, pc_plus_one: %h, pc_branch: %b", 
      // $time, 
      // m_alu_data, 
      // w_alu_data, 
      // pc_plus_one, 
      // pc_branch);

      // // CONTROL SIGNALS
      // $display("%d d_r1re %b, d_r2re %b, d_regfile_we %b, d_nzp_we %b, d_select_pc_plus_one %b,  d_is_load %b, d_is_store %b, d_is_branch %b, d_is_control_insn %b", 
      // $time, 
      // d_r1re, d_r2re, d_regfile_we, d_nzp_we, d_select_pc_plus_one,  d_is_load, d_is_store, d_is_branch, d_is_control_insn);
      // $display("%d x_r1re %b, x_r2re %b, x_regfile_we %b, x_nzp_we %b, x_select_pc_plus_one %b,  x_is_load %b, x_is_store %b, x_is_branch %b, x_is_control_insn %b", 
      // $time, 
      // x_r1re, x_r2re, x_regfile_we, x_nzp_we, x_select_pc_plus_one,  x_is_load, x_is_store, x_is_branch, x_is_control_insn);
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