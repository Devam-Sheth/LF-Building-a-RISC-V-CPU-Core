\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/Devam-Sheth/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])

   m4_test_prog()


\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   
   $reset = *reset;
   
   //PC Logic
   
   $pc[31:0] = >>1$next_pc;
   $next_pc[31:0] = $reset ? 32'b0 :
      $taken_br ? $br_tgt_pc :
      $is_jal ? $br_tgt_pc :
      $is_jalr ? $jalr_tgt_pc :
      ($pc + 32'd4);
   
   //IMem Logic
   `READONLY_MEM($pc, $$instr[31:0]);
   
   //Instr. Decode
   
   // R-type
   $is_r_instr = $instr[6:2] == 5'b01011 ||
      $instr[6:2] == 5'b01100 ||
      $instr[6:2] == 5'b01110 ||
      $instr[6:2] == 5'b10100 ||
      $instr[6:2] == 5'b00010;
   
   //S-type
   $is_s_instr = $instr[6:2] == 5'b01000 ||
      $instr[6:2] == 5'b01001;
            
   //U-type
   $is_u_instr = $instr[6:2] == 5'b00101 ||
      $instr[6:2] == 5'b01101;
         
   //B-type
   $is_b_instr = $instr[6:2] == 5'b11000;
   
   //J-type
   $is_j_instr = $instr[6:2] == 5'b11011;
   
   // I-type
   $is_i_instr = $instr[6:2] == 5'b00000 ||
      $instr[6:2] == 5'b00001 ||
      $instr[6:2] == 5'b00100 ||
      $instr[6:2] == 5'b00110 ||
      $instr[6:2] == 5'b11001;
            
   //Load
   $is_load = $opcode == 7'b0000011;
                  
   //Decode Logic
   
   $opcode[6:0] = $instr[6:0];
   $rd[4:0] = $instr[11:7];
   $funct3[2:0] = $instr[14:12];
   $rs1[4:0] = $instr[19:15];
   $rs2[4:0] = $instr[24:20];
   $funct7[6:0] = $instr[31:25]; 
   
   $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
   $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $imm_valid = $is_i_instr || $is_s_instr || $is_b_instr || $is_u_instr || $is_j_instr;
   $funt3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $rd_valid = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr; 
   
   $imm[31:0] = $is_i_instr ? {{20{$instr[31]}},$instr[31:20]} :
      $is_u_instr ? {$instr[31:12],12'b0} :
      $is_s_instr ? {{20{$instr[31]}},$instr[31:25],$instr[11:7]} :
      $is_b_instr ? {{20{$instr[31]}},$instr[7],$instr[30:25],$instr[11:8],1'b0} :
      $is_j_instr ? {{12{$instr[31]}},$instr[19:12],$instr[20],$instr[30:21],1'b0} :
      32'b0;
      
   //Instruction
   $dec_bits[10:0] = {$instr[30],$funct3,$opcode};
   
   $is_lui = $dec_bits ==? 11'bx_xxx_0110111;
   $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;
   $is_jal = $dec_bits ==? 11'bx_000_1101111;
   
   $is_jalr = $dec_bits ==? 11'bx_xxx_1100111;
   
   $is_beq = $dec_bits ==? 11'bx_000_1100011;
   $is_bne = $dec_bits ==? 11'bx_001_1100011;
   $is_blt = $dec_bits ==? 11'bx_100_1100011;
   $is_bge = $dec_bits ==? 11'bx_101_1100011;
   $is_bltu = $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
   
   $is_lb = $dec_bits ==? 11'bx_000_0000011;
   $is_lh = $dec_bits ==? 11'bx_001_0000011;
   $is_lw = $dec_bits ==? 11'bx_010_0000011;
   $is_lbu = $dec_bits ==? 11'bx_100_0000011;
   $is_lhu = $dec_bits ==? 11'bx_101_0000011;
   
   $is_sb = $dec_bits ==? 11'bx_000_0100011;
   $is_sh = $dec_bits ==? 11'bx_001_0100011;
   $is_sw = $dec_bits ==? 11'bx_010_0100011;
   
   $is_addi = $dec_bits ==? 11'bx_000_0010011;
   $is_slti = $dec_bits ==? 11'bx_010_0010011;
   $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
   $is_xori = $dec_bits ==? 11'bx_100_0010011;
   $is_ori = $dec_bits ==? 11'bx_110_0010011;
   $is_andi = $dec_bits ==? 11'bx_111_0010011;
   
   $is_slli = $dec_bits ==? 11'b0_001_0010011;
   $is_srli = $dec_bits ==? 11'b0_101_0010011;
   $is_srai = $dec_bits ==? 11'b1_101_0010011;
   
   $is_add = $dec_bits ==? 11'b0_000_0110011 && $funct7 == 7'b0000000; 
   $is_sub = $dec_bits ==? 11'b0_000_0110011 && $funct7 == 7'b0100000; 
   $is_sll = $dec_bits ==? 11'b0_001_0110011 && $funct7 == 7'b0000000;
   $is_slt = $dec_bits ==? 11'b0_010_0110011 && $funct7 == 7'b0000000;
   $is_sltu = $dec_bits ==? 11'b0_011_0110011 && $funct7 == 7'b0000000;
   $is_xor = $dec_bits ==? 11'b0_100_0110011 && $funct7 == 7'b0000000;
   $is_srl = $dec_bits ==? 11'b0_101_0110011 && $funct7 == 7'b0000000;
   $is_sra = $dec_bits ==? 11'b0_101_0110011 && $funct7 == 7'b0100000;
   $is_or = $dec_bits ==? 11'b0_110_0110011 && $funct7 == 7'b0000000;
   $is_and = $dec_bits ==? 11'b0_111_0110011 && $funct7 == 7'b0000000;
   $is_mul = ($opcode == 7'b0110011) && ($funct3 == 3'b000) && ($funct7 == 7'b0000001);
   $is_rsqr = ($opcode == 7'b0001011) && ($funct3 == 3'b001) && ($funct7 == 7'b0000010);
   
   //SLTU AND SLTI RESULTS
   
   $sltu_rslt[31:0] = {31'b0, $src1_value < $src2_value};
   $sltiu_rslt[31:0] = {31'b0, $src1_value < $imm};
   
   $sext_src1[63:0] = {{32{$src1_value[31]}},$src1_value};
   
   $sra_rslt[63:0] = $sext_src1 >> $src2_value[4:0];
   $srai_rslt[63:0] = $sext_src1 >> $imm[4:0];
   
   //ALU subset
   $result[31:0] = ($is_addi || $is_load || $is_s_instr) ? ($src1_value + $imm) :
      $is_add ? ($src1_value + $src2_value) :
      $is_andi ? ($src1_value & $imm) :
      $is_ori ? ($src1_value | $imm) :
      $is_xori ? ($src1_value ^ $imm) :
      $is_slli ? ($src1_value << $imm[5:0]) :
      $is_srli ? ($src1_value >> $imm[5:0]) :
      $is_and ? ($src1_value & $src2_value) :
      $is_or ? ($src1_value | $src2_value) :
      $is_xor ? ($src1_value ^ $src2_value) :
      $is_sub ? ($src1_value - $src2_value) :
      $is_sll ? ($src1_value << $src2_value[4:0]) :
      $is_srl ? ($src1_value >> $src2_value[4:0]) :
      $is_sltu ? $sltu_rslt  :
      $is_sltiu ? $sltiu_rslt  :
      $is_sra ? $sra_rslt[31:0]  :
      $is_srai ? $srai_rslt[31:0]  :
      $is_lui ? {$imm[31:12],12'b0} :
      $is_auipc ? ($pc + $imm) :
      $is_jal ? ($pc+32'd4) :
      $is_jalr ? ($pc+32'd4) :
      $is_slt ? (($src1_value[31]==$src2_value[31]) ? 
         $sltu_rslt :
         {31'b0,$src1_value[31]}) :
      $is_slti ? (($src1_value[31]==$imm[31]) ? 
         $sltiu_rslt :
         {31'b0,$src1_value[31]}) :
      $is_mul ? ($src1_value * $src2_value) :
      $is_rsqr ? ($src1_value * $src1_value) :
      32'b0;
               
   //Branch Logic
   $taken_br = $is_beq ? ($src1_value == $src2_value) :
      $is_bne ? ($src1_value != $src2_value) :
      $is_blt ? (($src1_value < $src2_value)^($src1_value[31] != $src2_value[31])) :
      $is_bge ? (($src1_value >= $src2_value)^($src1_value[31] != $src2_value[31])) :
      $is_bltu ? ($src1_value < $src2_value) :
      $is_bgeu ? ($src1_value >= $src2_value) :
      1'b0;
   
   $br_tgt_pc[31:0] = $imm + $pc;
   
   //Unconditional Jump
   $jalr_tgt_pc[31:0] = $imm + $src1_value;
   
   
   // Assert these to end simulation (before Makerchip cycle limit).
   m4+tb()
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   // Register File Instantiation (formerly m4+rf and \source block)
   // Instantiated from top.tlv, 224 as: m4+rf(32, 32, $reset, ($rd_valid && $rd != 5'b0), $rd, ($is_load ? $ld_data : $result), $rs1_valid, $rs1, $src1_value, $rs2_valid, $rs2, $src2_value)
   $rf1_wr_en = ($rd_valid && $rd != 5'b0);
   $rf1_wr_index[\$clog2(32)-1:0]  = $rd;
   $rf1_wr_data[32-1:0] = ($is_load ? $ld_data : $result);
   
   $rf1_rd_en1 = $rs1_valid;
   $rf1_rd_index1[\$clog2(32)-1:0] = $rs1;
   
   $rf1_rd_en2 = $rs2_valid;
   $rf1_rd_index2[\$clog2(32)-1:0] = $rs2;
   
   /xreg[31:0]
      $wr = /top$rf1_wr_en && (/top$rf1_wr_index == #xreg);
      <<1$value[32-1:0] = /top$reset ? #xreg :
                           $wr     ? /top$rf1_wr_data :
                                        $RETAIN;
   
   $src1_value[32-1:0]  =  $rf1_rd_en1 ? /xreg[$rf1_rd_index1]$value : 'X;
   $src2_value[32-1:0]  =  $rf1_rd_en2 ? /xreg[$rf1_rd_index2]$value : 'X;
   
   /xreg[31:0]
      
            
   // Data Memory Instantiation (formerly m4+dmem and \source block)
   // Instantiated from top.tlv, 287 as: m4+dmem(32, 32, $reset, $result[6:2], $is_s_instr, $src2_value, $is_load, $ld_data)
   // Allow expressions for most inputs, so define input signals.
   $dmem1_wr_en = $is_s_instr;
   $dmem1_addr[\$clog2(32)-1:0] = $result[6:2];
   $dmem1_wr_data[32-1:0] = $src2_value;
   
   $dmem1_rd_en = $is_load;
   
   /dmem[31:0]
      $wr = /top$dmem1_wr_en && (/top$dmem1_addr == #dmem);
      <<1$value[32-1:0] = /top$reset ? 0 :
                           $wr       ? /top$dmem1_wr_data :
                                        $RETAIN;
   
   $ld_data[32-1:0] = $dmem1_rd_en ? /dmem[$dmem1_addr]$value : 'X;
   /dmem[31:0]
\SV
   endmodule
