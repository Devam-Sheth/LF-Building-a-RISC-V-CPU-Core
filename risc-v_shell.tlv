\m4_TLV_version 1d: tl-x.org
\SV
    // This code is based on: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
    
    // Includes the library for M4 macros like m4_asm, m4+rf, m4+dmem, m4+tb, m4+cpu_viz etc.
    m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])

    //---------------------------------------------------------------------------------
    // Test Program for MUL and RSQR
    // - Initializes x5 = 7, x6 = 6
    // - Computes MUL x10, x5, x6 (expected x10 = 42)
    // - Initializes x7 = 9
    // - Computes RSQR x11, x7 (expected x11 = 81)
    // - Sets x30 = 1 if all internal checks pass, otherwise x30 will likely be 0.
    //   The m4+tb() macro from the library checks if x30 is 1 for a PASS.
    //---------------------------------------------------------------------------------
    // x29 will be an error accumulator. If it remains 0, all tests passed before setting x30.
    m4_asm(ADDI, x29, x0, 0)      // x29 = 0 (error flag accumulator)

    // Test 1: MUL x10, x5, x6
    m4_asm(ADDI, x5, x0, 7)       // x5 = 7
    m4_asm(ADDI, x6, x0, 6)       // x6 = 6
    m4_asm_word(0x01628533)       // MUL x10, x5, x6  (Instruction: 0000001 00110 00101 000 01010 0110011)
    m4_asm(ADDI, x12, x0, 42)     // x12 = 42 (expected value for MUL)
    m4_asm(SUB, x31, x10, x12)    // x31 = x10 - x12. If x31 is 0, MUL is correct.
    m4_asm(OR, x29, x29, x31)     // If x31 was non-zero (error), x29 becomes non-zero.

    // Test 2: RSQR x11, x7
    m4_asm(ADDI, x7, x0, 9)       // x7 = 9
    m4_asm_word(0x0403958B)       // RSQR x11, x7 (Instruction: 0000010 00000 00111 001 01011 0001011) (rs2=x0 encoded)
    m4_asm(ADDI, x13, x0, 81)     // x13 = 81 (expected value for RSQR)
    m4_asm(SUB, x31, x11, x13)    // x31 = x11 - x13. If x31 is 0, RSQR is correct.
    m4_asm(OR, x29, x29, x31)     // If x31 was non-zero (error), x29 becomes non-zero.

    // Set final pass/fail status in x30
    // If x29 is 0 (no errors accumulated), then x30 = 1 (PASS). Else x30 = 0 (FAIL).
    m4_asm(SLTIU, x30, x29, 1)    // x30 = (x29 < 1) ? 1 : 0. So if x29 is 0, x30 is 1.

    // Infinite loop to halt CPU and allow inspection of registers
    // loop: // Label for clarity
    m4_asm(BEQ, x0, x0, 0)        // Branch to self (pc = pc + 0 effectively)

    m4_define(['M4_MAX_CYC'], 100) // Define max cycles for this specific test program
    
    // Crucial: This generates the `READONLY_MEM` Verilog macro with the program defined above.
    m4_asm_end_tlv() 

\SV
    m4_makerchip_module   // This macro expands to `module top (...)` or similar.
    /* verilator lint_on WIDTH */
\TLV
    // This is the CPU core logic
    
    $reset = *reset; // Uses implicit global reset from Makerchip environment
    
    // PC Logic
    // `$pc` is registered, `>>1` indicates it's clocked by the implicit global clk.
    $pc[31:0] = >>1$next_pc;
    $next_pc[31:0] = $reset ? 32'b0 :
                         $taken_br ? $br_tgt_pc :
                         $is_jal ? $br_tgt_pc :
                         $is_jalr ? $jalr_tgt_pc :
                         ($pc + 32'd4);
    
    // IMem Logic
    // `READONLY_MEM` is a Verilog macro defined by `m4_asm_end_tlv()`.
    // It creates an instruction memory initialized with the assembly program.
    // `$$instr` is the instruction fetched from memory at the current `$pc`.
    `READONLY_MEM($pc, $$instr[31:0]);
    
    // Instruction Decode Fields
    $opcode[6:0] = $instr[6:0];
    $rd[4:0] = $instr[11:7];
    $funct3[2:0] = $instr[14:12];
    $rs1[4:0] = $instr[19:15];
    $rs2[4:0] = $instr[24:20];
    $funct7[6:0] = $instr[31:25]; 
    
    // Instruction Type Decode
    // R-type includes standard (01100xx) and custom-0 (00010xx for RSQR)
    $is_r_instr = $instr[6:2] == 5'b01100 || // Standard R-type (ADD, SUB, MUL, etc.)
                  $instr[6:2] == 5'b00010;  // Custom-0 (for our RSQR)
                  // Note: Original $is_r_instr from user's code had other opcodes (5'b01011, 5'b01110, 5'b10100).
                  // These are not standard R-type or custom-0. If they were for other specific
                  // custom instructions, they would need to be re-added or handled separately.
                  // For this exercise, we focus on standard R and custom-0 for RSQR.

    $is_s_instr = $instr[6:2] == 5'b01000 || $instr[6:2] == 5'b01001; // STORE
    $is_u_instr = $instr[6:2] == 5'b00101 || $instr[6:2] == 5'b01101; // LUI, AUIPC
    $is_b_instr = $instr[6:2] == 5'b11000;                            // BRANCH
    $is_j_instr = $instr[6:2] == 5'b11011;                            // JAL
    $is_i_instr = $instr[6:2] == 5'b00000 || $instr[6:2] == 5'b00001 || // LOAD, FENCE, CSR
                  $instr[6:2] == 5'b00100 ||                          // OP-IMM
                  $instr[6:2] == 5'b00110 ||                          // OP-IMM-32 (RV64) - not used here
                  $instr[6:2] == 5'b11001;                            // JALR
    
    // Specific Instruction Flags
    $is_load = $opcode == 7'b0000011; // LOAD instructions (LB, LH, LW, LBU, LHU)
    
    // Operand/Field Validity for Register File and Immediate
    $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
    $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
    $rd_valid  = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
    $imm_valid = $is_i_instr || $is_s_instr || $is_b_instr || $is_u_instr || $is_j_instr;
    // $funt3_valid is implicitly true if opcode matches types that use funct3.
    
    // Immediate Generation
    $imm[31:0] = $is_i_instr ? {{20{$instr[31]}}, $instr[31:20]} :
                 $is_u_instr ? {$instr[31:12], 12'b0} :
                 $is_s_instr ? {{20{$instr[31]}}, $instr[31:25], $instr[11:7]} :
                 $is_b_instr ? {{20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0} :
                 $is_j_instr ? {{12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0} :
                 32'b0; // Default immediate
             
    // Precise Instruction Decode Signals (based on full opcode, funct3, funct7)
    $is_lui    = ($opcode == 7'b0110111);
    $is_auipc  = ($opcode == 7'b0010111);
    $is_jal    = ($opcode == 7'b1101111);
    $is_jalr   = ($opcode == 7'b1100111 && $funct3 == 3'b000);
    
    $is_beq    = ($opcode == 7'b1100011 && $funct3 == 3'b000);
    $is_bne    = ($opcode == 7'b1100011 && $funct3 == 3'b001);
    $is_blt    = ($opcode == 7'b1100011 && $funct3 == 3'b100);
    $is_bge    = ($opcode == 7'b1100011 && $funct3 == 3'b101);
    $is_bltu   = ($opcode == 7'b1100011 && $funct3 == 3'b110);
    $is_bgeu   = ($opcode == 7'b1100011 && $funct3 == 3'b111);
    
    $is_lb     = ($opcode == 7'b0000011 && $funct3 == 3'b000);
    $is_lh     = ($opcode == 7'b0000011 && $funct3 == 3'b001);
    $is_lw     = ($opcode == 7'b0000011 && $funct3 == 3'b010);
    $is_lbu    = ($opcode == 7'b0000011 && $funct3 == 3'b100);
    $is_lhu    = ($opcode == 7'b0000011 && $funct3 == 3'b101);
    
    $is_sb     = ($opcode == 7'b0100011 && $funct3 == 3'b000);
    $is_sh     = ($opcode == 7'b0100011 && $funct3 == 3'b001);
    $is_sw     = ($opcode == 7'b0100011 && $funct3 == 3'b010);
    
    $is_addi   = ($opcode == 7'b0010011 && $funct3 == 3'b000);
    $is_slti   = ($opcode == 7'b0010011 && $funct3 == 3'b010);
    $is_sltiu  = ($opcode == 7'b0010011 && $funct3 == 3'b011);
    $is_xori   = ($opcode == 7'b0010011 && $funct3 == 3'b100);
    $is_ori    = ($opcode == 7'b0010011 && $funct3 == 3'b110);
    $is_andi   = ($opcode == 7'b0010011 && $funct3 == 3'b111);
    
    // I-type shifts (SLLI, SRLI, SRAI) for RV32I
    $is_slli   = ($opcode == 7'b0010011 && $funct3 == 3'b001 && $funct7 == 7'b0000000); // funct7[6:5] must be 00
    $is_srli   = ($opcode == 7'b0010011 && $funct3 == 3'b101 && $funct7 == 7'b0000000); // funct7[6:5] must be 00
    $is_srai   = ($opcode == 7'b0010011 && $funct3 == 3'b101 && $funct7 == 7'b0100000); // funct7[6:5] must be 01 (funct7[5]=1)
    
    // R-type ALU operations
    $is_add    = ($opcode == 7'b0110011 && $funct3 == 3'b000 && $funct7 == 7'b0000000);
    $is_sub    = ($opcode == 7'b0110011 && $funct3 == 3'b000 && $funct7 == 7'b0100000);
    $is_sll    = ($opcode == 7'b0110011 && $funct3 == 3'b001 && $funct7 == 7'b0000000);
    $is_slt    = ($opcode == 7'b0110011 && $funct3 == 3'b010 && $funct7 == 7'b0000000);
    $is_sltu   = ($opcode == 7'b0110011 && $funct3 == 3'b011 && $funct7 == 7'b0000000);
    $is_xor    = ($opcode == 7'b0110011 && $funct3 == 3'b100 && $funct7 == 7'b0000000);
    $is_srl    = ($opcode == 7'b0110011 && $funct3 == 3'b101 && $funct7 == 7'b0000000);
    $is_sra    = ($opcode == 7'b0110011 && $funct3 == 3'b101 && $funct7 == 7'b0100000);
    $is_or     = ($opcode == 7'b0110011 && $funct3 == 3'b110 && $funct7 == 7'b0000000);
    $is_and    = ($opcode == 7'b0110011 && $funct3 == 3'b111 && $funct7 == 7'b0000000);

    // Custom instructions
    $is_mul    = ($opcode == 7'b0110011 && $funct3 == 3'b000 && $funct7 == 7'b0000001); // Standard M-extension MUL
    $is_rsqr   = ($opcode == 7'b0001011 && $funct3 == 3'b001 && $funct7 == 7'b0000010); // Custom RSQR
    
    // Intermediate results for SLT/SLTI
    $sltu_rslt[31:0] = {31'b0, $src1_value < $src2_value};
    $sltiu_rslt[31:0] = {31'b0, $src1_value < $imm};
    
    // Intermediate results for SRA/SRAI
    $sext_src1[63:0] = {{32{$src1_value[31]}},$src1_value}; // Sign-extend src1 for arithmetic right shift
    $sra_rslt[63:0] = $sext_src1 >> $src2_value[4:0];       // R-type SRA shift amount from rs2[4:0]
    $srai_rslt[63:0] = $sext_src1 >> $imm[4:0];             // I-type SRAI shift amount from imm[4:0]
    
    // ALU Result Logic
    $result[31:0] = $is_mul ? ($src1_value * $src2_value) :
                     $is_rsqr ? ($src1_value * $src1_value) :
                     ($is_addi || $is_load || $is_s_instr) ? ($src1_value + $imm) : // $is_s_instr for address calculation
                     $is_add ? ($src1_value + $src2_value) :
                     $is_andi ? ($src1_value & $imm) :
                     $is_ori ? ($src1_value | $imm) :
                     $is_xori ? ($src1_value ^ $imm) :
                     $is_slli ? ($src1_value << $imm[4:0]) :       // Shift amount for I-type SLLI is imm[4:0]
                     $is_srli ? ($src1_value >> $imm[4:0]) :       // Shift amount for I-type SRLI is imm[4:0]
                     $is_and ? ($src1_value & $src2_value) :
                     $is_or ? ($src1_value | $src2_value) :
                     $is_xor ? ($src1_value ^ $src2_value) :
                     $is_sub ? ($src1_value - $src2_value) :
                     $is_sll ? ($src1_value << $src2_value[4:0]) : // Shift amount for R-type SLL is rs2[4:0]
                     $is_srl ? ($src1_value >> $src2_value[4:0]) : // Shift amount for R-type SRL is rs2[4:0]
                     $is_sltu ? $sltu_rslt  :
                     $is_sltiu ? $sltiu_rslt  :
                     $is_sra ? $sra_rslt[31:0]  :
                     $is_srai ? $srai_rslt[31:0]  :
                     $is_lui ? {$imm[31:12],12'b0} :
                     $is_auipc ? ($pc + $imm) :
                     ($is_jal || $is_jalr) ? ($pc+32'd4) :     // Result for JAL/JALR is link address (PC+4)
                     $is_slt ? (($src1_value[31]==$src2_value[31]) ? 
                                     $sltu_rslt : {31'b0,$src1_value[31]}) :
                     $is_slti ? (($src1_value[31]==$imm[31]) ? 
                                 $sltiu_rslt : {31'b0,$src1_value[31]}) :
                     32'b0; // Default result (e.g., for branches, NOP)
                     
    // Branch Logic
    $taken_br = $is_beq ? ($src1_value == $src2_value) :
                $is_bne ? ($src1_value != $src2_value) :
                $is_blt ? (($src1_value < $src2_value)^($src1_value[31] != $src2_value[31])) : // Signed compare
                $is_bge ? (($src1_value >= $src2_value)^($src1_value[31] != $src2_value[31])) : // Signed compare
                $is_bltu ? ($src1_value < $src2_value) :  // Unsigned compare
                $is_bgeu ? ($src1_value >= $src2_value) :  // Unsigned compare
                1'b0; // Default to not taken
    
    $br_tgt_pc[31:0] = $imm + $pc; // Branch target PC calculation
    $jalr_tgt_pc[31:0] = ($imm + $src1_value) & 32'hfffffffe; // JALR target PC, LSB must be 0
    
    // Testbench and Visualization Macros from the library
    // m4+tb() defines *passed and uses /xreg[30]$value == 1 for pass condition.
    m4+tb() 
    *failed = *cyc_cnt > M4_MAX_CYC; // M4_MAX_CYC is defined by m4_define in the asm section
    
    // Register File Instantiation using the library macro
    // m4+rf(num_entries, width, reset, wr_en, wr_idx, wr_data, rd1_en, rd1_idx, rd1_data, rd2_en, rd2_idx, rd2_data)
    // It defines $src1_value and $src2_value as outputs based on read ports.
    m4+rf(32, 32, $reset, ($rd_valid && $rd != 5'b0), $rd, ($is_load ? $ld_data : $result), $rs1_valid, $rs1, $src1_value, $rs2_valid, $rs2, $src2_value)
    
    // Data Memory Instantiation using the library macro
    // m4+dmem(num_entries, width, reset, addr, wr_en, wr_data, rd_en, rd_data)
    // Address for dmem is $result (e.g. for sw, lw: rs1_val + imm)
    // $result[6:2] implies word-addressing for a small dmem (up to 32 words).
    // It defines $ld_data as the output from dmem read.
    m4+dmem(32, 32, $reset, $result[6:2], $is_s_instr, $src2_value, $is_load, $ld_data)
    
    // Makerchip Visualization Macro
    m4+cpu_viz()
\SV
    endmodule
```

**Step 3: Commit and Push Changes to Your GitHub Repository**

1.  Navigate to the root directory of your cloned repository (`Devam-Sheth/LF-Building-a-RISC-V-CPU-Core`) in your terminal or Git client.
2.  Stage the modified `risc-v_shell.tlv` file:
    ```bash
    git add risc-v_shell.tlv
    ```
3.  Commit the changes:
    ```bash
    git commit -m "Implemented MUL and RSQR instructions, added specific test program, and refined CPU logic."
    ```
4.  Push the changes to your GitHub repository:
    ```bash
    git push origin main 
    ```
    (Or `master` or whatever your main branch is named).

**Step 4: Test in Makerchip IDE**

1.  Go to the Makerchip IDE.
2.  Ensure your project is synced with your `Devam-Sheth/LF-Building-a-RISC-V-CPU-Core` repository. If it was already open, you might need to refresh or use Makerchip's Git controls to pull the latest changes.
3.  Run the simulation.
4.  **Verification**:
    * The `m4+tb()` macro, as defined in `risc-v_shell_lib.tlv`, checks if register `x30` (specifically `/xreg[30]$value`) is `1` and the PC is stable (indicating the end of the program loop) to assert the `*passed` signal.
    * Your new test program is designed to set `x30` to `1` if the `MUL` and `RSQR` operations produce the correct results.
    * Look for the "TEST PASSED" indication in Makerchip's UI.
    * You can also manually inspect:
        * `x10` (or `/xreg[10]$value`) should be `42` (0x2A).
        * `x11` (or `/xreg[11]$value`) should be `81` (0x51).
        * `x29` (or `/xreg[29]$value`) should be `0`.
        * `x30` (or `/xreg[30]$value`) should be `1`.
    * Use the waveform viewer to trace signals like `$pc`, `$$instr`, `$is_mul`, `$is_rsqr`, `$result`, `$src1_value`, `$src2_value` to debug if necessary.

This approach ensures that your CPU core logic is enhanced and that it runs a program specifically designed to test these enhancements, all within the structure provided by the "LF-Building-a-RISC-V-CPU-Core" framewo
