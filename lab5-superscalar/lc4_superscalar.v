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

   /*
      FETCH 
      Input: PC
   */

   assign next_pc = d_ltu_stall_A ? f_pc_A: // REPEAT PC Counter if A has LTU STALL
                    stall_flushing_full_A ? branch_pc_A : 
                    stall_flushing_full_B ? branch_pc_B : 
                    d_does_pipe_stall_B ? pc_plus_one : pc_plus_two;
                    
   wire [15:0]   f_pc_A, f_pc_B, next_pc, pc_plus_one, pc_plus_two;
   Nbit_reg #(16, 16'h8200) next_pc_reg (.in(next_pc), .out(f_pc_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   

   // some stall logic check here to put correct value into b(in)

    // PC + 1
   cla16 cla_pc_plus_one(
            .a(f_pc_A),
            .b(16'b0),
            .cin(1'b1),
            .sum(pc_plus_one)
         );   

    // PC + 2
   cla16 cla_pc_plus_two(.a(pc_plus_one),
            .b(16'b0),
            .cin(1'b1),
            .sum(pc_plus_two)
            );
    
   assign o_cur_pc = (d_ltu_stall_A) ? pc_plus_one : f_pc_A;
   assign f_pc_B = (d_ltu_stall_A) ? pc_plus_two : pc_plus_one;

   wire f_reg_we = (d_ltu_stall_A != 1'b1) ? 1'b1 : 1'b0;
   // FETCH PC STALL LOGIC
    wire [1:0] f_stall = (stall_flushing_full_A | stall_flushing_full_B) ? 2'b10 : 2'b00;

    // Fetch Flushing logic 
    // PIPE A 
    wire[15:0] f_pc_final_A =   d_does_pipe_stall_B ? d_pc_B : // Pipeline switch if B stalls
                                o_cur_pc;   

    wire[15:0] f_insn_final_A = (stall_flushing_full_A | stall_flushing_full_B)? 16'b0 : 
                                d_ltu_stall_A ? 16'b0 : // FLUSH INSN if A has LTU dependence
                                d_does_pipe_stall_B ? d_insn_B : // PIPELINE SWITCH
                                i_cur_insn_A; // NORMAL INSN


    // PIPE B 
    wire[15:0] f_pc_final_B = d_does_pipe_stall_B ? o_cur_pc : // Pipeline switch if B stalls
                             f_pc_B;

    wire[15:0] f_insn_final_B = (stall_flushing_full_A | stall_flushing_full_B)? 16'b0 : 
                                d_ltu_stall_A ? 16'b0 : // FLUSH INSN if A has LTU dependence
                                d_does_pipe_stall_B  ? i_cur_insn_A : // PIPELINE SWITCH
                                 i_cur_insn_B; // NORMAL INSN
    
    /**
        DECODE
        Input: PC, Instruction (i_cur_insn_A)
    */


    /**
        DECODE A 
    */
    wire [15:0]   d_pc_A, d_pc_plus_one_A, d_insn_A;
    wire d_pc_reg_we_A = !(decode_stall_logic_complete_A == 2'b11); // Check against flushes

    // Program counter register, starts at 8200h at bootup
    Nbit_reg #(16, 16'h8200) d_pc_A_reg (.in(f_pc_final_A), .out(d_pc_A), .clk(clk), .we(d_pc_reg_we_A), .gwe(gwe), .rst(rst));

    //PC+1 LOGIC
    Nbit_reg #(16, 16'h8200) d_pc_plus_one_A_reg (.in(f_pc_final_B), .out(d_pc_plus_one_A), .clk(clk), .we(d_pc_reg_we_A), .gwe(gwe), .rst(rst));

    // Fetched instruction register, starts at 0000h at bootup
    Nbit_reg #(16, 16'b0) d_insn_reg (.in(f_insn_final_A), .out(d_insn_A), .clk(clk), .we(d_pc_reg_we_A), .gwe(gwe), .rst(rst));
    

    // Control Signals
    wire d_r1re_A, d_r2re_A, d_regfile_we_A, d_nzp_we_A, d_select_pc_plus_one_A, d_is_load_A, d_is_store_A, d_is_branch_A, d_is_control_insn_A;
    wire [2:0] d_r1_sel_A, d_r2_sel_A, d_rd_sel_A;

    // Decode signals
    lc4_decoder decoder_A(
                    .insn(d_insn_A), //instruction
                    .r1sel(d_r1_sel_A), //rs
                    .r1re(d_r1re_A), // does this instruction read from rs?
                    .r2sel(d_r2_sel_A), // rt
                    .r2re(d_r2re_A), // does this instruction read from rt?
                    .wsel(d_rd_sel_A), // rd
                    .regfile_we(d_regfile_we_A), // does this instruction write to rd?
                    .nzp_we(d_nzp_we_A), // does this instruction write to NZP bits?
                    .select_pc_plus_one(d_select_pc_plus_one_A), // write PC+1 to regfile?
                    .is_load(d_is_load_A), // is this a load instruction?
                    .is_store(d_is_store_A), // is this a store instruction?
                    .is_branch(d_is_branch_A), // is this a branch instruction?
                    .is_control_insn(d_is_control_insn_A) // is this a control instruction?
                    );

   

    // STALL LOGIC
    wire [1:0] d_carry_over_stall_A_register;  
    Nbit_reg #(2, 2'b10) d_carry_over_stall_A_reg (.in(f_stall), .out(d_carry_over_stall_A_register), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    wire[1:0] d_carry_over_stall_A;
    assign d_carry_over_stall_A = (stall_flushing_full_A == 1'b1 | stall_flushing_full_B == 1'b1) ? 2'b10 : ((temp_stall_logic_A == 1'b1) ? 2'b11 : d_carry_over_stall_A_register);

    wire temp_stall_logic_A = (x_is_load_A == 1'b1 & x_carry_over_stall_A == 2'b0) & 
        ((x_rd_sel_A == d_r1_sel_A & d_r1re_A == 1'b1) | 
        (x_rd_sel_A == d_r2_sel_A & d_r2re_A == 1'b1 & d_is_store_A == 1'b0)
        ) & temp_stall_decode_A ? 1'b1 : (x_is_load_B == 1'b1 & x_carry_over_stall_B == 2'b0) & 
        ((x_rd_sel_B == d_r1_sel_B & d_r1re_B == 1'b1) | 
        (x_rd_sel_B == d_r2_sel_B & d_r2re_B == 1'b1 & d_is_store_B == 1'b0)
        ) ? 1'b1 : 1'b0;

    wire temp_stall_decode_A = (x_is_load_B == 1'b0) & ((x_rd_sel_A == x_rd_sel_B) & x_regfile_we_B == 1'b1) ? 1'b0 : 1'b1;

    wire first_stall_logic_A = x_is_load_A & temp_stall_logic_A ;
    
    wire second_stall_logic_A = (x_is_load_A & d_is_branch_A)  | first_stall_logic_A;
    
    wire d_stall_final_A = (x_carry_over_stall_A == 2'b11 | x_carry_over_stall_A == 2'b10) ? 1'b0 : second_stall_logic_A;
    
    // LTU Stall 

    // LTU STALL D.A with X.A - Checks for intervention of X.B
    wire d_ltu_stall_with_pipe_A_on_r1_A = x_is_load_A & d_r1re_A & (d_r1_sel_A == x_rd_sel_A) & ((d_r1_sel_A != x_rd_sel_B) || !x_regfile_we_B);
    wire d_ltu_stall_with_pipe_A_on_r2_A = x_is_load_A & d_r2re_A & !d_is_store_A & (d_r2_sel_A == x_rd_sel_A) & ((d_r2_sel_A != x_rd_sel_B) || !x_regfile_we_B);
    // Combine partial results for dependendence between D.A and X.A
    wire d_ltu_stall_with_pipe_A_A = d_ltu_stall_with_pipe_A_on_r1_A | d_ltu_stall_with_pipe_A_on_r2_A;
    // LTU STALL D.A with X.B - Doesn't need intervention checking.
    wire d_ltu_stall_with_pipe_B_A = (x_is_load_B  & ((d_r1re_A  & (d_r1_sel_A == x_rd_sel_B)) || (d_r2re_A  & (d_r2_sel_A == x_rd_sel_B) & !d_is_store_A)));
    // Global LTU stall pipe A
    wire d_ltu_stall_A =  d_ltu_stall_with_pipe_A_A | d_ltu_stall_with_pipe_B_A;

    wire [1:0] decode_stall_logic_complete_A =
                            d_ltu_stall_A ? 2'b11: // LTU Stall in A  
                            (d_carry_over_stall_A == 2'b10) ? 2'b10 : 
                            (stall_flushing_full_A == 1'b1) ? 2'b10 : 2'b0;



    
    // FLUSHING LOGIC
    wire d_flush_regfile_we_A = (d_stall_final_A == 1'b1 | d_carry_over_stall_A == 2'b10 | stall_flushing_full_A == 1'b1) ? 1'b0 : d_regfile_we_A;
    wire d_flush_is_store_A = (d_stall_final_A == 1'b1 | d_carry_over_stall_A == 2'b10 | stall_flushing_full_A == 1'b1) ? 1'b0 : d_is_store_A;
    wire d_flush_nzp_we_A = (d_stall_final_A == 1'b1 | d_carry_over_stall_A == 2'b10 | stall_flushing_full_A == 1'b1) ? 1'b0 : d_nzp_we_A;
    
    wire[15:0] d_insn_final_A = decode_stall_logic_complete_A ? 16'b0 : d_insn_A;

    // Decode control signals
    wire [8:0] d_control_signals_A = decode_stall_logic_complete_A ? 9'b0 : {d_r1re_A, d_r2re_A, d_flush_regfile_we_A, d_flush_nzp_we_A, d_select_pc_plus_one_A,  d_is_load_A, d_flush_is_store_A, d_is_branch_A, d_is_control_insn_A};
    

    /* 
    DECODE B 
    */

    // Needs to be modified
    wire d_pc_B_reg_we = !(decode_stall_logic_complete_A == 2'b11); // Check against flushes

    wire [15:0]   d_pc_B, d_pc_plus_one_B, d_insn_B;
    // Program counter register, starts at 8200h at bootup
    Nbit_reg #(16, 16'h8200) d_pc_B_reg (.in(f_pc_final_B), .out(d_pc_B), .clk(clk), .we(d_pc_B_reg_we), .gwe(gwe), .rst(rst));
    
    //PC+1 LOGIC
    Nbit_reg #(16, 16'h8200) d_pc_plus_one_B_reg (.in(next_pc), .out(d_pc_plus_one_B), .clk(clk), .we(d_pc_reg_we_A), .gwe(gwe), .rst(rst));

    // Fetched instruction register, starts at 0000h at bootup
    Nbit_reg #(16, 16'b0) d_insn_reg_B (.in(f_insn_final_B), .out(d_insn_B), .clk(clk), .we(d_pc_B_reg_we), .gwe(gwe), .rst(rst));
    
    // Control Signals
    wire d_r1re_B, d_r2re_B, d_regfile_we_B, d_nzp_we_B, d_select_pc_plus_one_B, d_is_load_B, d_is_store_B, d_is_branch_B, d_is_control_insn_B;
    wire [2:0] d_r1_sel_B, d_r2_sel_B, d_rd_sel_B;

    // Decode signals
    lc4_decoder decoder_B(
                    .insn(d_insn_B), //instruction
                    .r1sel(d_r1_sel_B), //rs
                    .r1re(d_r1re_B), // does this instruction read from rs?
                    .r2sel(d_r2_sel_B), // rt
                    .r2re(d_r2re_B), // does this instruction read from rt?
                    .wsel(d_rd_sel_B), // rd
                    .regfile_we(d_regfile_we_B), // does this instruction write to rd?
                    .nzp_we(d_nzp_we_B), // does this instruction write to NZP bits?
                    .select_pc_plus_one(d_select_pc_plus_one_B), // write PC+1 to regfile?
                    .is_load(d_is_load_B), // is this a load instruction?
                    .is_store(d_is_store_B), // is this a store instruction?
                    .is_branch(d_is_branch_B), // is this a branch instruction?
                    .is_control_insn(d_is_control_insn_B) // is this a control instruction?
                    );


        // STALLING LOGIC
        wire [1:0] d_carry_over_stall_B;  
        Nbit_reg #(2, 2'b10) d_carry_over_stall_B_reg (.in(f_stall), .out(d_carry_over_stall_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

        
        wire temp_stall_logic_B = (
            (x_rd_sel_B == d_r1_sel_B & d_r1re_B == 1'b1) | 
            (x_rd_sel_B == d_r2_sel_B & d_r2re_B == 1'b1 & d_is_store_B == 1'b0)
            );

        wire second_stall_logic_B = x_is_load_B & (d_is_branch_B | temp_stall_logic_B);
        
        wire d_stall_final_B = (x_carry_over_stall_B == 2'b11 | x_carry_over_stall_B == 2'b10) ? 1'b0 : second_stall_logic_B;
        
        // Superscalar stall
        //  D.B depends on D.A
        wire d_decode_pipe_dependency = ((d_rd_sel_A == d_r1_sel_B) & d_r1re_B & d_regfile_we_A) | ((d_rd_sel_A == d_r2_sel_B) & d_r2re_B & !d_is_store_B & d_regfile_we_A);
        // D.B and D.A are both memory
        wire d_decode_memory_dependency = (d_is_load_A | d_is_store_A) & (d_is_load_B | d_is_store_B);
        // D.B is branch and D.A writes to NZP
        wire d_decode_branch_dependency = (d_is_branch_B & d_nzp_we_A);
        // Global superscalar stall for pipe B
        wire d_superscalar_stall_B = d_decode_pipe_dependency | d_decode_memory_dependency | d_decode_branch_dependency;
       
        // LTU Stall 
        // LTU dependendence with D.B and X.A - Check for double intervention
        wire d_ltu_stall_with_pipe_A_on_r1_B = x_is_load_A & d_r1re_B  & (d_r1_sel_B == x_rd_sel_A);
        wire d_ltu_stall_with_pipe_A_on_r1_intervention_B = ((d_r1_sel_B != x_rd_sel_B) || !x_regfile_we_B) & ((d_r1_sel_B != d_rd_sel_A) || !d_regfile_we_A);
        wire d_ltu_stall_with_pipe_A_on_r2_B = x_is_load_A &  (d_r2re_B  & (d_r2_sel_B == x_rd_sel_A) & !d_is_store_B);
        wire d_ltu_stall_with_pipe_A_on_r2_intervention_B = ((d_r2_sel_B != x_rd_sel_B) || !x_regfile_we_B) & ((d_r2_sel_B != d_rd_sel_A) || !d_regfile_we_A);
        // Combine partial results for dependendence between D.B and X.A
        wire d_ltu_stall_with_pipe_A_B = (x_is_load_A & d_is_branch_B) | (d_ltu_stall_with_pipe_A_on_r1_B & d_ltu_stall_with_pipe_A_on_r1_intervention_B) | (d_ltu_stall_with_pipe_A_on_r2_B & d_ltu_stall_with_pipe_A_on_r2_intervention_B);
        // LTU dependendence between D.B and X.B
        wire d_ltu_stall_with_pipe_B_on_r1_B = x_is_load_B & ((d_r1re_B  & (d_r1_sel_B == x_rd_sel_B)) & ((d_r1_sel_B != d_rd_sel_A) || !d_regfile_we_A));
        wire d_ltu_stall_with_pipe_B_on_r2_B = x_is_load_B & ((d_r2re_B  & (d_r2_sel_B == x_rd_sel_B)) & ((d_r2_sel_B != d_rd_sel_A) || !d_regfile_we_A));
        // Combine partial results for dependendence between D.B and X.B
        wire d_ltu_stall_with_pipe_B_B = (x_is_load_B & d_is_branch_B) | d_ltu_stall_with_pipe_B_on_r1_B | d_ltu_stall_with_pipe_B_on_r2_B;
        // Global LTU Stall
        wire d_ltu_stall_B = d_ltu_stall_with_pipe_A_B | d_ltu_stall_with_pipe_B_B;

        // Global 
        wire d_does_pipe_stall_B = d_superscalar_stall_B | d_ltu_stall_B | d_ltu_stall_A;

        wire [1:0] decode_stall_logic_complete_B =  stall_flushing_full_B ? 2'b10 : // Flushed INSN
                                                    d_ltu_stall_A ? 2'b01: // Superscalar stall -> LTU Stall in A  
                                                    d_superscalar_stall_B ? 2'b01 : // Superscalar stall with A 
                                                    d_ltu_stall_B ? 2'b11: // LTU stall 
                                                    d_carry_over_stall_B; // Carries over previous stall value if any

        // FLUSHING LOGIC
        wire d_flush_regfile_we_B = (d_stall_final_B == 1'b1 | d_carry_over_stall_B == 2'b10 | stall_flushing_full_B == 1'b1) ? 1'b0 : d_regfile_we_B;
        wire d_flush_is_store_B = (d_stall_final_B == 1'b1 | d_carry_over_stall_B == 2'b10 | stall_flushing_full_B == 1'b1) ? 1'b0 : d_is_store_B;
        wire d_flush_nzp_we_B = (d_stall_final_B == 1'b1 | d_carry_over_stall_B == 2'b10 | stall_flushing_full_B == 1'b1) ? 1'b0 : d_nzp_we_B;
        
        
        wire[15:0] d_insn_final_B = decode_stall_logic_complete_B ? 16'b0 : d_insn_B;


        /*
            REGISTER FILE
        */ 

        wire [15:0] d_o_r1_data_A, d_o_r2_data_A, d_o_r1_data_B, d_o_r2_data_B;
        lc4_regfile_ss #(16) d_reg_lc4(.clk(clk), .gwe(gwe), .rst(rst), .i_rs_A(d_r1_sel_A), .o_rs_data_A(d_o_r1_data_A),
                            .i_rt_A(d_r2_sel_A), .o_rt_data_A(d_o_r2_data_A), .i_rs_B(d_r1_sel_B), .o_rs_data_B(d_o_r1_data_B), .i_rt_B(d_r2_sel_B),
                            .o_rt_data_B(d_o_r2_data_B), .i_rd_A(w_rd_sel_A), .i_wdata_A(w_regfile_in_A), .i_rd_we_A(w_regfile_we_A), .i_rd_B(w_rd_sel_B), .i_wdata_B(w_regfile_in_B), 
                            .i_rd_we_B(w_regfile_we_B));
        
        // Encode control signals - Do not propagate if pipe b stalls
        wire [8:0] d_control_signals_B = (decode_stall_logic_complete_B) ? 9'b0 : {d_r1re_B, d_r2re_B, d_flush_regfile_we_B, d_flush_nzp_we_B, d_select_pc_plus_one_B,  d_is_load_B, d_flush_is_store_B, d_is_branch_B, d_is_control_insn_B};
        
    /**
        EXECUTE
        INPUT: 
            - PC, INSN, R1_DATA, R2_DATA
            - CONTROL SIGNALS:
                    d_r1re_A; // does this instruction read from rs
                    d_r2re_A; // does this instruction read from rt?
                    d_regfile_we_A; // does this instruction write to rd?
                    d_nzp_we_A; // does this instruction write the NZP bits?
                    d_select_pc_plus_one_A; // wrtie PC+1 to the regfile?
                    d_is_load_A; // is this a load instruction?
                    d_is_store_A; // is this is a store instruction?
                    d_is_branch_A; // is this a branch instruction?
                    d_is_control_insn_A; // is this a control instruction?
    **/


    /*
        EXECUTE A 
    */

    // Create registers for inputs for execute stage
    wire [15:0] x_pc_A, x_pc_plus_one_A, x_insn_A, x_o_r1_data_A, x_o_r2_data_A;
    // Program counter register, starts at 8200h at bootup
    Nbit_reg #(16, 16'h8200) x_pc_reg_A (.in(d_pc_A), .out(x_pc_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // PC plus one
    Nbit_reg #(16, 16'h8200) x_pc_plus_one_reg_A (.in(d_pc_plus_one_A), .out(x_pc_plus_one_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // Fetched instruction register, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) x_insn_reg_A (.in(d_insn_final_A), .out(x_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // R1 DATA, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) x_r1_data_reg_A (.in(d_o_r1_data_A), .out(x_o_r1_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // R2 DATA, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) x_r2_data_reg_A (.in(d_o_r2_data_A), .out(x_o_r2_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // Register Selector Lines
    wire [2:0] x_r1_sel_A, x_r2_sel_A, x_rd_sel_A;
    Nbit_reg #(3, 3'b000) x_r1_sel_reg_A (.in(d_r1_sel_A), .out(x_r1_sel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) x_r2_sel_reg_A (.in(d_r2_sel_A), .out(x_r2_sel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) x_rd_sel_reg_A (.in(d_rd_sel_A), .out(x_rd_sel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // CONTROL SIGNALS
    wire [8:0] x_control_signals_A;
    Nbit_reg #(9, {9{1'b0}}) x_control_signals_reg_A (.in(d_control_signals_A), .out(x_control_signals_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    wire x_r1re_A, x_r2re_A, x_regfile_we_A, x_nzp_we_A, x_select_pc_plus_one_A,  x_is_load_A, x_is_store_A, x_is_branch_A, x_is_control_insn_A;
    assign {x_r1re_A, x_r2re_A, x_regfile_we_A, x_nzp_we_A, x_select_pc_plus_one_A,  x_is_load_A, x_is_store_A, x_is_branch_A, x_is_control_insn_A} = x_control_signals_A;
    
    //MX WX BYPASS
    wire[15:0] i_r1_alu_A = 
                        (m_rd_sel_B == x_r1_sel_A && m_regfile_we_B && x_r1re_A && !m_carry_over_stall_B) ? m_regfile_in_B :            
                        (m_rd_sel_A == x_r1_sel_A && m_regfile_we_A && x_r1re_A && !m_carry_over_stall_A) ? m_regfile_in_A :
                        (w_rd_sel_B == x_r1_sel_A && w_regfile_we_B && x_r1re_A && !w_carry_over_stall_B) ? w_regfile_in_B : 
                        (w_rd_sel_A == x_r1_sel_A && w_regfile_we_A && x_r1re_A && !w_carry_over_stall_A) ? w_regfile_in_A : 
                        x_o_r1_data_A;

    wire[15:0] i_r2_alu_A = 
                        (m_rd_sel_B == x_r2_sel_A && m_regfile_we_B && x_r2re_A && !m_carry_over_stall_B) ? m_regfile_in_B :
                        (m_rd_sel_A == x_r2_sel_A && m_regfile_we_A && x_r2re_A && !m_carry_over_stall_A) ? m_regfile_in_A :
                        (w_rd_sel_B == x_r2_sel_A && w_regfile_we_B && x_r2re_A && !w_carry_over_stall_B) ? w_regfile_in_B : 
                        (w_rd_sel_A == x_r2_sel_A & w_regfile_we_A && x_r2re_A && !w_carry_over_stall_A) ? w_regfile_in_A :
                        x_o_r2_data_A;
                        
    
    
    // ALU
    wire [15:0] x_alu_data_A;

    lc4_alu alu_impl_A(
        .i_insn(x_insn_A), 
        .i_pc(x_pc_A), 
        .i_r1data(i_r1_alu_A), 
        .i_r2data(i_r2_alu_A),
        .o_result(x_alu_data_A)
        );
    
   
    // STALL LOGIC
    wire [1:0] x_carry_over_stall_A;
    Nbit_reg #(2, 2'b10) x_stall_reg_A (.in(decode_stall_logic_complete_A), .out(x_carry_over_stall_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    //Branch Prediction
    wire [2:0] branch_nzp_A = m_nzp_we_B ? m_nzp_curr_B : // M.B to X.A bypass
                              m_nzp_we_A ? m_nzp_curr_A : // M.A to X.A bypass
                              w_nzp_we_B ? w_nzp_curr_B : // W.B to X.A bypass
                              w_nzp_we_A ? w_nzp_curr_A : // W.A to X.A bypass
                              x_nzp_curr;

    wire[15:0] branch_pc_A = x_is_control_insn_A ? x_alu_data_A : (x_is_branch_A & (| (x_insn_A[11:9] & branch_nzp_A))) ? x_alu_data_A : x_pc_plus_one_A;

    wire change_pc_branch_A = (x_carry_over_stall_A != 2'b10) & (x_is_control_insn_A | (x_is_branch_A & (|(x_insn_A[11:9] & branch_nzp_A))));
        
    wire stall_flushing_full_A = (x_carry_over_stall_A != 2'b11) & change_pc_branch_A;



    /*
        EXECUTE B 
    */

    // Create registers for inputs for execute stage
    wire [15:0] x_pc_B, x_pc_plus_one_B, x_insn_B, x_o_r1_data_B, x_o_r2_data_B;
    // Program counter register, starts at 8200h at bootup
    Nbit_reg #(16, 16'h8200) x_pc_reg (.in(d_pc_B), .out(x_pc_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // PC plus one
    Nbit_reg #(16, 16'h8200) x_pc_plus_one_reg (.in(d_pc_plus_one_B), .out(x_pc_plus_one_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // Fetched instruction register, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) x_insn_reg (.in(d_insn_final_B), .out(x_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // R1 DATA, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) x_r1_data_reg (.in(d_o_r1_data_B), .out(x_o_r1_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // R2 DATA, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) x_r2_data_reg (.in(d_o_r2_data_B), .out(x_o_r2_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // Register Selector Lines
    wire [2:0] x_r1_sel_B, x_r2_sel_B, x_rd_sel_B;
    Nbit_reg #(3, 3'b000) x_r1_sel_reg (.in(d_r1_sel_B), .out(x_r1_sel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) x_r2_sel_reg (.in(d_r2_sel_B), .out(x_r2_sel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) x_rd_sel_reg (.in(d_rd_sel_B), .out(x_rd_sel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // CONTROL SIGNALS
    wire [8:0] x_control_signals_B;
    Nbit_reg #(9, {9{1'b0}}) x_control_signals_reg_B (.in(d_control_signals_B), .out(x_control_signals_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    wire x_r1re_B, x_r2re_B, x_regfile_we_B, x_nzp_we_B, x_select_pc_plus_one_B,  x_is_load_B, x_is_store_B, x_is_branch_B, x_is_control_insn_B;
    assign {x_r1re_B, x_r2re_B, x_regfile_we_B, x_nzp_we_B, x_select_pc_plus_one_B,  x_is_load_B, x_is_store_B, x_is_branch_B, x_is_control_insn_B} = x_control_signals_B;
    
    //MX WX BYPASS
    wire[15:0] i_r1_alu_B =
                        (m_rd_sel_B == x_r1_sel_B && m_regfile_we_B && x_r1re_B && !m_carry_over_stall_B) ? m_regfile_in_B : 
                        (m_rd_sel_A == x_r1_sel_B && m_regfile_we_A && x_r1re_B && !m_carry_over_stall_A) ? m_regfile_in_A :
                        (w_rd_sel_B == x_r1_sel_B && w_regfile_we_B && x_r1re_B && !w_carry_over_stall_B) ? w_regfile_in_B :
                        (w_rd_sel_A == x_r1_sel_B && w_regfile_we_A && x_r1re_B && !w_carry_over_stall_A) ? w_regfile_in_A : 
                        
                        x_o_r1_data_B;

    wire[15:0] i_r2_alu_B = (m_rd_sel_B == x_r2_sel_B && m_regfile_we_B && x_r2re_B && !m_carry_over_stall_B) ? m_regfile_in_B :
                            (m_rd_sel_A == x_r2_sel_B && m_regfile_we_A && x_r2re_B && !m_carry_over_stall_A) ? m_regfile_in_A : 
                            (w_rd_sel_B == x_r2_sel_B & w_regfile_we_B && x_r2re_B && !w_carry_over_stall_B) ? w_regfile_in_B :
                            (w_rd_sel_A == x_r2_sel_B && w_regfile_we_A && x_r2re_B && !w_carry_over_stall_A) ? w_regfile_in_A :
                            x_o_r2_data_B;
                        
    // ALU
    wire [15:0] x_alu_data_B;

    lc4_alu alu_impl_B(
        .i_insn(x_insn_B), 
        .i_pc(x_pc_B), 
        .i_r1data(i_r1_alu_B), 
        .i_r2data(i_r2_alu_B),
        .o_result(x_alu_data_B)
        );
    
   
    // STALL LOGIC
    wire [1:0] x_carry_over_stall_B, x_carry_over_stall_prev_B;
    Nbit_reg #(2, 2'b10) x_stall_reg (.in(decode_stall_logic_complete_B), .out(x_carry_over_stall_prev_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   

    wire [2:0] branch_nzp_B = (m_nzp_we_B ) ? m_nzp_curr_B : // M.B to X.B bypass
                              (m_nzp_we_A ) ? m_nzp_curr_A : // M.A to X.B bypass
                              (w_nzp_we_B ) ? w_nzp_curr_B : // W.B to X.B bypass
                              (w_nzp_we_A) ? w_nzp_curr_A : // W.A to X.B bypass
                              x_nzp_curr;
   
    wire[15:0] branch_pc_B = x_is_control_insn_B ? x_alu_data_B : (x_is_branch_B & (| (x_insn_B[11:9] & branch_nzp_B))) ? x_alu_data_B : x_pc_plus_one_B;

    wire change_pc_branch_B = (x_carry_over_stall_prev_B != 2'b10) & (x_is_control_insn_B | (x_is_branch_B & (|(x_insn_B[11:9] & branch_nzp_B)))) ? 1'b1 : 1'b0;
        
    wire stall_flushing_full_temp_B = (x_carry_over_stall_prev_B != 2'b10) & (x_is_control_insn_B | (x_is_branch_B & (|(x_insn_B[11:9] & branch_nzp_B)))) ? 1'b1 : 1'b0;

    wire stall_flushing_full_B = stall_flushing_full_A | ((x_carry_over_stall_prev_B == 2'b00) & stall_flushing_full_temp_B);

    // Flush insn and control signals if X.A is flushing 
    assign x_carry_over_stall_B = stall_flushing_full_A ? 2'b10 : x_carry_over_stall_prev_B;

    wire[15:0] x_insn_final_B = stall_flushing_full_A? 16'b0 : // FLUSH 
                                x_insn_B;

    wire [8:0] x_control_signals_final_B = stall_flushing_full_A ? 9'b0 : x_control_signals_B;


    // NZP REGISTER
    wire [2:0]   x_nzp_curr, x_nzp_new_A, x_nzp_new_B, x_nzp_new;      
    assign x_nzp_new_A = ($signed(x_alu_data_A) < 0) ? 100 : ($signed(x_alu_data_A) > 0) ? 001 : 010;
    assign x_nzp_new_B = ($signed(x_alu_data_B) < 0) ? 100 : ($signed(x_alu_data_B) > 0) ? 001 : 010;
    assign x_nzp_new = x_nzp_we_B ? x_nzp_new_B :
                        x_nzp_we_A ? x_nzp_new_A :
                        x_nzp_curr;
    Nbit_reg #(3, 3'b000) x_nzp_reg_A (.in(x_nzp_new), .out(x_nzp_curr), .clk(clk), .we(x_nzp_we_A), .gwe(gwe), .rst(rst));
 


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

    /*
            MEMORY A
    */
    // Create registers for inputs for memory stage
    wire [15:0] m_pc_A, m_pc_plus_one_A, m_insn_A, m_alu_data_A, m_r2_data_A;
    // Program counter register, starts at 8200h at bootup
    Nbit_reg #(16, 16'h8200) m_pc_reg_A (.in(x_pc_A), .out(m_pc_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // PC plus one
    Nbit_reg #(16, 16'h8200) m_pc_plus_one_reg_A(.in(x_pc_plus_one_A), .out(m_pc_plus_one_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // Fetched instruction register, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) m_insn_reg_A (.in(x_insn_A), .out(m_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // ALU DATA, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) m_alu_data_reg_A (.in(x_alu_data_A), .out(m_alu_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // R2 DATA, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) m_r2_data_reg_A (.in(i_r2_alu_A), .out(m_r2_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // Register Selector Lines
    wire [2:0] m_r1_sel_A, m_r2_sel_A, m_rd_sel_A;
    Nbit_reg #(3, 3'b000) m_r1_sel_reg_A (.in(x_r1_sel_A), .out(m_r1_sel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) m_r2_sel_reg_A (.in(x_r2_sel_A), .out(m_r2_sel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) m_rd_sel_reg_A (.in(x_rd_sel_A), .out(m_rd_sel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    // CONTROL SIGNALS
    wire [8:0] m_control_signals_A;
    Nbit_reg #(9, {9{1'b0}}) m_control_signals_reg_A (.in(x_control_signals_A), .out(m_control_signals_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    wire m_r1re_A, m_r2re_A, m_regfile_we_A, m_nzp_we_A, m_select_pc_plus_one_A,  m_is_load_A, m_is_store_A, m_is_branch_A, m_is_control_insn_A; 
    assign {m_r1re_A, m_r2re_A, m_regfile_we_A, m_nzp_we_A, m_select_pc_plus_one_A,  m_is_load_A, m_is_store_A, m_is_branch_A, m_is_control_insn_A} = m_control_signals_A;
    // STALL SIGNAL
    wire [1:0] m_carry_over_stall_A;      
    Nbit_reg #(2, 2'b10) m_stall_reg_A (.in(x_carry_over_stall_A), .out(m_carry_over_stall_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    

    // WM BYPASS LOGIC
    wire[15:0] m_regfile_in_A = m_select_pc_plus_one_A ? m_pc_plus_one_A : 
                                m_is_load_A ? i_cur_dmem_data : 
                                m_alu_data_A;

    // NZP
    wire[2:0] m_nzp_curr_A = ($signed(m_regfile_in_A) < 0) ? 100 :
                        ($signed(m_regfile_in_A) > 0) ? 001 : 010;

    // MEMORY LOGIC 
    wire[15:0] m_o_dmem_addr_A = ((m_carry_over_stall_A == 2'b00) & (m_is_load_A | m_is_store_A)) ? m_alu_data_A : 16'b0 ;
    // WM Bypass
    wire[15:0] m_o_dmem_towrite_A  =  (m_is_store_A & (w_rd_sel_B == m_r2_sel_A) & w_regfile_we_B & ~w_is_store_B) ? w_regfile_in_B : // WM Bypass: W.B to M.A
                                        (m_is_store_A & (w_rd_sel_A == m_r2_sel_A) & w_regfile_we_A & ~w_is_store_A) ? w_regfile_in_A : // WM Bypass: W.A to M.A
                                        m_r2_data_A;

    wire m_o_dmem_we_A = m_is_store_A;

        /**
            MEMORY B
        */

        // Create registers for inputs for memory stage
    wire [15:0] m_pc_B, m_pc_plus_one_B, m_insn_B, m_alu_data_B, m_r2_data_B;
    // Program counter register, starts at 8200h at bootup
    Nbit_reg #(16, 16'h8200) m_pc_reg_B (.in(x_pc_B), .out(m_pc_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // PC plus one
    Nbit_reg #(16, 16'h8200) m_pc_plus_one_reg_B(.in(x_pc_plus_one_B), .out(m_pc_plus_one_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // Fetched instruction register, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) m_insn_reg_B (.in(x_insn_final_B), .out(m_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // ALU DATA, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) m_alu_data_reg_B (.in(x_alu_data_B), .out(m_alu_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // R2 DATA, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) m_r2_data_reg_B (.in(i_r2_alu_B), .out(m_r2_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // Register Selector Lines
    wire [2:0] m_r1_sel_B, m_r2_sel_B, m_rd_sel_B;
    Nbit_reg #(3, 3'b000) m_r1_sel_reg_B (.in(x_r1_sel_B), .out(m_r1_sel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) m_r2_sel_reg_B (.in(x_r2_sel_B), .out(m_r2_sel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) m_rd_sel_reg_B (.in(x_rd_sel_B), .out(m_rd_sel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // CONTROL SIGNALS
    wire [8:0] m_control_signals_B;
    Nbit_reg #(9, {9{1'b0}}) m_control_signals_reg_B (.in(x_control_signals_final_B), .out(m_control_signals_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    wire m_r1re_B, m_r2re_B, m_regfile_we_B, m_nzp_we_B, m_select_pc_plus_one_B,  m_is_load_B, m_is_store_B, m_is_branch_B, m_is_control_insn_B; 
    assign {m_r1re_B, m_r2re_B, m_regfile_we_B, m_nzp_we_B, m_select_pc_plus_one_B,  m_is_load_B, m_is_store_B, m_is_branch_B, m_is_control_insn_B} = m_control_signals_B;
    // STALL SIGNAL
    wire [1:0] m_carry_over_stall_B;      
    Nbit_reg #(2, 2'b10) m_stall_reg_B (.in(x_carry_over_stall_B), .out(m_carry_over_stall_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    
    
    wire[15:0] m_regfile_in_B = m_select_pc_plus_one_B ? m_pc_plus_one_B : 
                                m_is_load_B ? i_cur_dmem_data : 
                                m_alu_data_B;
    
    // NZP
    wire[2:0] m_nzp_curr_B = ($signed(m_regfile_in_B) < 0) ? 100 :
                        ($signed(m_regfile_in_B) > 0) ? 001 : 010;


    // MEMORY LOGIC
    wire[15:0] m_o_dmem_addr_B = ((m_carry_over_stall_B == 2'b00) & (m_is_load_B | m_is_store_B)) ? m_alu_data_B : 16'b0;
    // WM and MM BYPASS LOGIC
    wire[15:0] m_o_dmem_towrite_B  =(m_is_store_B & (m_rd_sel_A == m_r2_sel_B) & m_regfile_we_A) ? m_alu_data_A :  // MM bypass 
                                    (m_is_store_B & (w_rd_sel_B == m_r2_sel_B) & w_regfile_we_B & ~w_is_store_B) ? w_regfile_in_B : //WM bypass
                                     m_r2_data_B;

    wire m_o_dmem_we_B = m_is_store_B;
    

    // ASSIGN UNIFIED MEMORY OUTPUT
    assign o_dmem_addr = ((m_carry_over_stall_A == 2'b00) & (m_is_load_A | m_is_store_A)) ? m_o_dmem_addr_A : // Check A has no stall
                         ((m_carry_over_stall_B == 2'b00) & (m_is_load_B | m_is_store_B)) ? m_o_dmem_addr_B:  // Check B has no stall
                         16'b0;

    assign o_dmem_towrite = ((m_carry_over_stall_A == 2'b00) & (m_is_load_A | m_is_store_A)) ? m_o_dmem_towrite_A : // Check A has no stall
                         ((m_carry_over_stall_B == 2'b00) & (m_is_load_B | m_is_store_B)) ? m_o_dmem_towrite_B :  // Check B has no stall
                         16'b0;

    assign o_dmem_we = m_o_dmem_we_A | m_o_dmem_we_B;
    
    
    

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

    /*
            WRITEBACK A
    */

    wire [15:0] w_pc_A, w_pc_plus_one_A, w_insn_A, w_alu_data_A;
    // Program counter register, starts at 8200h at bootup
    Nbit_reg #(16, 16'h8200) w_pc_reg_A (.in(m_pc_A), .out(w_pc_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // PC plus one
    Nbit_reg #(16, 16'h8200) w_pc_plus_one_reg_A (.in(m_pc_plus_one_A), .out(w_pc_plus_one_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // Fetched instruction register, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) w_insn_reg_A (.in(m_insn_A), .out(w_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // ALU DATA, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) w_alu_data_reg_A (.in(m_alu_data_A), .out(w_alu_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // Register Selector Lines
    wire [2:0] w_r1_sel_A, w_r2_sel_A, w_rd_sel_A;
    Nbit_reg #(3, 3'b000) w_r1_sel_reg_A (.in(m_r1_sel_A), .out(w_r1_sel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) w_r2_sel_reg_A (.in(m_r2_sel_A), .out(w_r2_sel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) w_rd_sel_reg_A (.in(m_rd_sel_A), .out(w_rd_sel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // CONTROL SIGNALS
    wire [8:0] w_control_signals_A;
    Nbit_reg #(9, {9{1'b0}}) w_control_signals_reg_A (.in(m_control_signals_A), .out(w_control_signals_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    wire w_r1re_A, w_r2re_A, w_regfile_we_A, w_nzp_we_A, w_select_pc_plus_one_A,  w_is_load_A, w_is_store_A, w_is_branch_A, w_is_control_insn_A; 
    assign { w_r1re_A, w_r2re_A, w_regfile_we_A, w_nzp_we_A, w_select_pc_plus_one_A,  w_is_load_A, w_is_store_A, w_is_branch_A, w_is_control_insn_A} = w_control_signals_A;
    // STALL SIGNAL
    wire [1:0] w_carry_over_stall_A;      
    Nbit_reg #(2, 2'b10) w_stall_reg_A (.in(m_carry_over_stall_A), .out(w_carry_over_stall_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // MEMORY VALUES
    wire [15:0] w_o_dmem_addr_A, w_o_dmem_towrite_A, w_i_curr_dmem_data_A;
    Nbit_reg #(16, 16'b10) w_dmem_addr_reg_A (.in(m_o_dmem_addr_A), .out(w_o_dmem_addr_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'b10) w_dmem_towrite_reg_A (.in(m_o_dmem_towrite_A), .out(w_o_dmem_towrite_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0000) w_i_dmem_data_reg_A (.in(i_cur_dmem_data), .out(w_i_curr_dmem_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // NZP 
    wire [2:0]   w_nzp_curr_A;      
    Nbit_reg #(3, 3'b000) w_nzp_reg_A (.in(m_nzp_curr_A), .out(w_nzp_curr_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    // Register Input Value
    wire [15:0] w_regfile_in_A = w_select_pc_plus_one_A  ? w_pc_plus_one_A : 
                                w_is_load_A  ? w_i_curr_dmem_data_A : 
                                w_alu_data_A;

        /*
            WRITEBACK B
        */

    wire [15:0] w_pc_B, w_pc_plus_one_B, w_insn_B, w_alu_data_B;
    // Program counter register, starts at 8200h at bootup
    Nbit_reg #(16, 16'h8200) w_pc_reg_B (.in(m_pc_B), .out(w_pc_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // PC plus one
    Nbit_reg #(16, 16'h8200) w_pc_plus_one_reg_B (.in(m_pc_plus_one_B), .out(w_pc_plus_one_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // Fetched instruction register, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) w_insn_reg_B (.in(m_insn_B), .out(w_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // ALU DATA, starts at 0000h at bootup
    Nbit_reg #(16, 16'h0000) w_alu_data_reg_B (.in(m_alu_data_B), .out(w_alu_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // Register Selector Lines
    wire [2:0] w_r1_sel_B, w_r2_sel_B, w_rd_sel_B;
    Nbit_reg #(3, 3'b000) w_r1_sel_reg_B (.in(m_r1_sel_B), .out(w_r1_sel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) w_r2_sel_reg_B (.in(m_r2_sel_B), .out(w_r2_sel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) w_rd_sel_reg_B (.in(m_rd_sel_B), .out(w_rd_sel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // CONTROL SIGNALS
    wire [8:0] w_control_signals_B;
    Nbit_reg #(9, {9{1'b0}}) w_control_signals_reg_B (.in(m_control_signals_B), .out(w_control_signals_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    wire w_r1re_B, w_r2re_B, w_regfile_we_B, w_nzp_we_B, w_select_pc_plus_one_B,  w_is_load_B, w_is_store_B, w_is_branch_B, w_is_control_insn_B; 
    assign { w_r1re_B, w_r2re_B, w_regfile_we_B, w_nzp_we_B, w_select_pc_plus_one_B,  w_is_load_B, w_is_store_B, w_is_branch_B, w_is_control_insn_B} = w_control_signals_B;
    // STALL SIGNAL
    wire [1:0] w_carry_over_stall_B;      
    Nbit_reg #(2, 2'b10) w_stall_reg_B (.in(m_carry_over_stall_B), .out(w_carry_over_stall_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // MEMORY VALUES
    wire [15:0] w_o_dmem_addr_B, w_o_dmem_towrite_B, w_i_curr_dmem_data_B;
    Nbit_reg #(16, 16'b10) w_dmem_addr_reg_B (.in(m_o_dmem_addr_B), .out(w_o_dmem_addr_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'b10) w_dmem_towrite_reg_B (.in(m_o_dmem_towrite_B), .out(w_o_dmem_towrite_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0000) w_i_dmem_data_reg_B (.in(i_cur_dmem_data), .out(w_i_curr_dmem_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    // NZP 
    wire [2:0]   w_nzp_curr_B;      
    Nbit_reg #(3, 3'b000) w_nzp_reg (.in(m_nzp_curr_B), .out(w_nzp_curr_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    // Register Input Value
    wire [15:0] w_regfile_in_B = w_select_pc_plus_one_B  ? w_pc_plus_one_B : 
                                w_is_load_B  ? w_i_curr_dmem_data_B : 
                                w_alu_data_B;


    // ASSIGN TEST WIRES 
    assign test_stall_A = w_carry_over_stall_A; 
    assign test_cur_pc_A = w_pc_A;
    assign test_cur_insn_A = w_insn_A;
    assign test_regfile_we_A = w_regfile_we_A;
    assign test_regfile_wsel_A = w_rd_sel_A;
    assign test_regfile_data_A = w_regfile_in_A;
    assign test_nzp_we_A = w_nzp_we_A;
    assign test_dmem_addr_A = w_o_dmem_addr_A;
    assign test_dmem_data_A = (w_is_load_A == 1'b1) ? w_i_curr_dmem_data_A : (w_is_store_A == 1'b1) ? w_o_dmem_towrite_A : 16'b0;
    assign test_dmem_we_A = w_is_store_A;
    assign test_nzp_new_bits_A = w_nzp_curr_A;


    assign test_stall_B = w_carry_over_stall_B; 
    assign test_cur_pc_B = w_pc_B;
    assign test_cur_insn_B = w_insn_B;
    assign test_regfile_we_B = w_regfile_we_B;
    assign test_regfile_wsel_B = w_rd_sel_B;
    assign test_regfile_data_B = w_regfile_in_B;
    assign test_nzp_we_B = w_nzp_we_B;
    assign test_dmem_addr_B = w_o_dmem_addr_B;
    assign test_dmem_data_B = (w_is_load_B == 1'b1) ? w_i_curr_dmem_data_B : (w_is_store_B == 1'b1) ? w_o_dmem_towrite_B : 16'b0;
    assign test_dmem_we_B = w_is_store_B;
    assign test_nzp_new_bits_B = w_nzp_curr_B;
    


   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    */
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, f_pc_A, d_pc_A, e_pc, m_pc, test_cur_pc);
      if (o_dmem_we)
        $display("");
        $display("%d PC:  A: f: %h, d: %h, x: %h, m: %h, w: %h - next_pc: %h", $time, f_pc_A, d_pc_A, x_pc_A, m_pc_A, w_pc_A, next_pc);
        $display("%d PC:  B: f: %h, d: %h, x: %h, m: %h, w: %h ", $time, f_pc_B, d_pc_B, x_pc_B, m_pc_B, w_pc_B);
        
        $display("%d INSN A: f: %h, d: %h, x: %h, m: %h, w: %h", $time, i_cur_insn_A, d_insn_A, x_insn_A, m_insn_A, w_insn_A);
        $display("%d INSN B: f: %h, d: %h, x: %h, m: %h, w: %h", $time, i_cur_insn_B, d_insn_B, x_insn_B, m_insn_B, w_insn_B);
        // $display("%d PC:  A:  f_pc_final_A: %h", $time, f_pc_final_A);
        // $display("%d PC:  B:  f_pc_final_B: %h", $time, f_pc_final_B);
        $display("%d ALU A : r1: (R%d, %h), r2: (R%d, %h), rd: R%h, OUTPUT: %h", $time, x_r1_sel_A, i_r1_alu_A, x_r2_sel_A, i_r2_alu_A, x_rd_sel_A, x_alu_data_A);
        $display("%d ALU DATA A : x: %h, m: %h, w: %h", $time, x_alu_data_A, m_alu_data_A, w_alu_data_A);
        $display("%d ALU B : r1: (R%d, %h), r2: (R%d, %h), rd: R%h, OUTPUT: %h", $time, x_r1_sel_B, i_r1_alu_B, x_r2_sel_B, i_r2_alu_B, x_rd_sel_B, x_alu_data_B);
        $display("%d ALU DATA B : x: %h, m: %h, w: %h", $time, x_alu_data_B, m_alu_data_B, w_alu_data_B);
        
        // $display("%d MEMORY ADDR:  m: %h, w: %h", $time, m_o_dmem_addr_A, w_o_dmem_addr_A);
        // $display("%d MEMORY ADDR B:  m: %h, w: %h", $time, m_o_dmem_addr_B, w_o_dmem_addr_B);
        $display("%d STALL A: f: %h, d: %h, x: %h, m: %h, w: %h", $time, f_stall, d_carry_over_stall_A, x_carry_over_stall_A, m_carry_over_stall_A, w_carry_over_stall_A);
        $display("%d STALL B: f: %h, d: %h, x: %h, m: %h, w: %h", $time, f_stall, d_carry_over_stall_B, x_carry_over_stall_B, m_carry_over_stall_B, w_carry_over_stall_B);
        // $display("%d pipe A LTU: %b, pipe B LTU: %b, superscalar stall: %b, does b stall: %b", $time, d_ltu_stall_A, d_ltu_stall_B, d_superscalar_stall_B, d_does_pipe_stall_B);
        // $display("%d A LTU STALL: D.A & X.A: %b (r1, %b) (r1,%b), D.A & X.B: %b", $time,d_ltu_stall_with_pipe_A_A, d_ltu_stall_with_pipe_A_on_r1_A, d_ltu_stall_with_pipe_A_on_r2_A, d_ltu_stall_with_pipe_B_A);
        // $display("%d A LTU STALL: D.B & X.B: %b (r1, %b) (r1,%b), D.B & X.A: %b", $time, d_ltu_stall_with_pipe_B_B, d_ltu_stall_with_pipe_B_on_r1_B, d_ltu_stall_with_pipe_B_on_r2_B, d_ltu_stall_with_pipe_A_B);
        // $display("%d B superscalar stall: decode dependency: %b, memory dependency: %b", $time, d_decode_pipe_dependency, d_decode_memory_dependency);
        $display("%d Branch take branch A: %b, take branch B: %b", $time, change_pc_branch_A, change_pc_branch_B);
        $display("%d stall_full_flushing_A: %b, stall_full_flushing_B: %b", $time, stall_flushing_full_A, stall_flushing_full_B);
        $display("%d NZP: curr: %b, used: %b, insn:  %b", $time, x_nzp_curr, branch_nzp_A, x_insn_A[11:9] );
        $display("%d NZP WE A: d: %b, x: %b, m: %b, w: %b", $time, d_nzp_we_A, x_nzp_we_A, m_nzp_we_A, w_nzp_we_A);
        
    //    $display("%d INSN: f: %h, d: %h, x: %h, m: %h, w: %h", $time, i_cur_insn, d_insn, x_insn, m_insn, w_insn);
    //    $display("%d ALU INPUT: R%d:%d, R%d:%d, DEST: R%d, OUTPUT: %d", $time,x_r1_sel, i_r1_alu, x_r2_sel, i_r2_alu, x_rd_sel, x_alu_data);
    //    $display("%d WRITEBACK: R%d %d we: %b", $time, w_rd_sel, d_i_reg_data, w_regfile_we);
    //    $display("%d REG OUTPUT: R%d:(%d,%d), R%d:(%d,%d)", $time, d_r1_sel, d_o_r1_data, d_out_r1_data, d_r2_sel, d_o_r2_data, d_out_r2_data);
    //    $display("%d BYPASS: wd_r1: %b, wd_r2: %b, mx_r1: %b, mx_r2: %b, wx_r1: %b, wx_r2: %b",$time,  wd_r1, wd_r2, mx_r1, mx_r2, wx_r1, wx_r2);
       $display("");

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