\m4_TLV_version 1d: tl-x.org
\SV
    // CRITICAL: This MUST point to YOUR modified risc-v_defs.tlv on GitHub
    // which includes the m4_instr definition for CUSTOM_RSQR.
    m4_include_lib(['https://raw.githubusercontent.com/Devam-Sheth/LF-Building-a-RISC-V-CPU-Core/main/risc-v_defs.tlv'])
    
// v====================== lib/risc-v_shell_lib.tlv =======================v

// Configuration definitions.
m4+definitions(['
    // Enable M-extension. The m4_instr for MUL in your risc-v_defs.tlv should use 'M'.
    m4_define(['M4_EXT_M'], 1)
    // M4_EXT_I is defined below and is needed for CUSTOM_RSQR as we defined it with 'I' in risc-v_defs.tlv.

    // Define the test program that will be used by m4_test_prog()
    m4_define(['m4_test_prog'], ['m4_hide(['
        // /====================================\
        // | Test Program for MUL and CUSTOM_RSQR |
        // \====================================/
        
        // Initialize operands
        m4_asm(ADDI, x5, x0, 000000000011)  // x5 = 3
        m4_asm(ADDI, x6, x0, 000000000100)  // x6 = 4
        m4_asm(ADDI, x7, x0, 000000000101)  // x7 = 5 (for RSQR)

        // Test MUL operation
        m4_asm(MUL, x10, x5, x6)           // x10 = x5 * x6  (3 * 4 = 12)

        // Test CUSTOM_RSQR operation
        //m4_asm(CUSTOM_RSQR, x11, x7, x0)   // x11 = x7 * x7  (5 * 5 = 25)

        // Verification Logic
        m4_asm(ADDI, x12, x0, 000000001100) // x12 (expected_mul) = 12
        m4_asm(ADDI, x13, x0, 000000011001) // x13 (expected_rsqr) = 25
        m4_asm(ADDI, x30, x0, 000000000000) // Initialize x30 (pass_status) to 0 (fail)

        // Check MUL: x14 = (x10 == x12) ? 1 : 0
        m4_asm(SUB, x14, x10, x12)         
        m4_asm(SLTIU, x14, x14, 000000000001) // If x14 was 0, x14 becomes 1.

        // Check CUSTOM_RSQR: x15 = (x11 == x13) ? 1 : 0
        m4_asm(SUB, x15, x11, x13)         
        m4_asm(SLTIU, x15, x15, 000000000001) // If x15 was 0, x15 becomes 1.

        // Combine checks: x30 = mul_ok AND rsqr_ok
        m4_asm(AND, x14, x14, x15)         
        m4_asm(OR, x30, x0, x14)           // Set x30 = x14.

        // Halt the processor
        m4_asm(JAL, x0, 00000000000000000000) // Infinite loop (imm for JAL is 20 bits)
        
        m4_define(['M4_VIZ_BASE'], 16)     
        m4_define(['M4_MAX_CYC'], 40)      
    '])m4_ifelse(['$1'], [''], ['m4_asm_end()'], ['m4_asm_end_tlv()'])'])
    
    m4_define_vector(['M4_WORD'], 32)
    m4_define(['M4_EXT_I'], 1) 
    
    m4_define(['M4_NUM_INSTRS'], 0) 
    
    m4_echo(m4tlv_riscv_gen__body()) 
    
    m4_define(['m4_asm_end'], ['`define READONLY_MEM(ADDR, DATA) logic [31:0] instrs [0:M4_NUM_INSTRS-1]; assign DATA = instrs[ADDR[$clog2($size(instrs)) + 1 : 2]]; assign instrs = '{m4_instr0['']m4_forloop(['m4_instr_ind'], 1, M4_NUM_INSTRS, [', m4_echo(['m4_instr']m4_instr_ind)'])};'])
    m4_define(['m4_asm_end_tlv'], ['`define READONLY_MEM(ADDR, DATA) logic [31:0] instrs [0:M4_NUM_INSTRS-1]; assign DATA \= instrs[ADDR[\$clog2(\$size(instrs)) + 1 : 2]]; assign instrs \= '{m4_instr0['']m4_forloop(['m4_instr_ind'], 1, M4_NUM_INSTRS, [', m4_echo(['m4_instr']m4_instr_ind)'])};'])
'])

\TLV test_prog() 
    m4_test_prog(['TLV'])

// Register File
\TLV rf(_entries, _width, $_reset, $_port1_en, $_port1_index, $_port1_data, $_port2_en, $_port2_index, $_port2_data, $_port3_en, $_port3_index, $_port3_data)
    $rf1_wr_en = m4_argn(4, $@);
    $rf1_wr_index[\$clog2(_entries)-1:0]  = m4_argn(5, $@);
    $rf1_wr_data[_width-1:0] = m4_argn(6, $@);
    $rf1_rd_en1 = m4_argn(7, $@);
    $rf1_rd_index1[\$clog2(_entries)-1:0] = m4_argn(8, $@);
    $rf1_rd_en2 = m4_argn(10, $@);
    $rf1_rd_index2[\$clog2(_entries)-1:0] = m4_argn(11, $@);
    /xreg[m4_eval(_entries-1):0]
        $wr = /top$rf1_wr_en && (/top$rf1_wr_index == #xreg);
        <<1$value[_width-1:0] = /top$_reset ? _width'b0 : 
                                 $wr       ? /top$rf1_wr_data :
                                           $RETAIN;
    $_port2_data[_width-1:0]  =  ($rf1_rd_en1 && $rf1_rd_index1 == 0) ? _width'b0 : 
                                 $rf1_rd_en1 ? /xreg[$rf1_rd_index1]$value : 'X; 
    $_port3_data[_width-1:0]  =  ($rf1_rd_en2 && $rf1_rd_index2 == 0) ? _width'b0 :
                                 $rf1_rd_en2 ? /xreg[$rf1_rd_index2]$value : 'X; 
    /xreg[m4_eval(_entries-1):0]
        \viz_js 
            box: {width: 120, height: 18, strokeWidth: 0},
            render() {
                let siggen = (name) => { let sig = this.svSigRef(`${name}`); return (sig == null || !sig.exists()) ? this.svSigRef(`sticky_zero`) : sig; }
                let rf_rd_en1 = siggen(`L0_rf1_rd_en1_a0`), rf_rd_index1 = siggen(`L0_rf1_rd_index1_a0`);
                let rf_rd_en2 = siggen(`L0_rf1_rd_en2_a0`), rf_rd_index2 = siggen(`L0_rf1_rd_index2_a0`);
                let wr = siggen(`L1_Xreg[${this.getIndex()}].L1_wr_a0`);
                let value = siggen(`Xreg_value_a0[${this.getIndex()}]`);
                let rd = (rf_rd_en1.asBool(false) && rf_rd_index1.asInt() == this.getIndex()) || (rf_rd_en2.asBool(false) && rf_rd_index2.asInt() == this.getIndex());
                let mod = wr.asBool(false); let reg = parseInt(this.getIndex()); let regIdent = reg.toString().padEnd(2, " ");
                let newValStr = (regIdent + ": ").padEnd(14, " "); 
                let viz_base = typeof M4_VIZ_BASE !== 'undefined' ? M4_VIZ_BASE : 16;
                let currentValDisplay = (regIdent + ": " + value.asInt(NaN).toString(viz_base)).padEnd(14, " ");
                let reg_str = new fabric.Text(currentValDisplay, { top: 0, left: 0, fontSize: 14, fill: mod ? "blue" : "black", fontWeight: mod ? 800 : 400, fontFamily: "monospace", textBackgroundColor: rd ? "#b0ffff" : mod ? "#f0f0f0" : "white" });
                if (mod) { setTimeout(() => { reg_str.set({text: newValStr, textBackgroundColor: "#d0e8ff", dirty: true}); this.global.canvas.renderAll(); }, 1500); }
                return [reg_str];
            },
            where: {left: 316, top: -40}
            
// Data Memory
\TLV dmem(_entries, _width, $_reset, $_addr, $_port1_en, $_port1_data, $_port2_en, $_port2_data)
    $dmem1_wr_en = $_port1_en;
    $dmem1_addr[\$clog2(_entries)-1:0] = $_addr; 
    $dmem1_wr_data[_width-1:0] = $_port1_data;
    $dmem1_rd_en = $_port2_en;
    /dmem[m4_eval(_entries-1):0]
        $wr = /top$dmem1_wr_en && (/top$dmem1_addr == #dmem);
        <<1$value[_width-1:0] = /top$_reset ? _width'b0 : 
                                 $wr       ? /top$dmem1_wr_data :
                                           $RETAIN;
    $_port2_data[_width-1:0] = $dmem1_rd_en ? /dmem[$dmem1_addr]$value : 'X; 
    /dmem[m4_eval(_entries-1):0]
        \viz_js 
            box: {width: 120, height: 18, strokeWidth: 0},
            render() {
                let siggen = (name) => { let sig = this.svSigRef(`${name}`); return (sig == null || !sig.exists()) ? this.svSigRef(`sticky_zero`) : sig; }
                let dmem_rd_en = siggen(`L0_dmem1_rd_en_a0`), dmem_addr = siggen(`L0_dmem1_addr_a0`);
                let wr = siggen(`L1_Dmem[${this.getIndex()}].L1_wr_a0`);
                let value = siggen(`Dmem_value_a0[${this.getIndex()}]`);
                let rd = dmem_rd_en.asBool() && dmem_addr.asInt() == this.getIndex();
                let mod = wr.asBool(false); let reg = parseInt(this.getIndex()); 
                let regIdent = reg.toString().padEnd(2, " ");
                let newValStr = (regIdent + ": ").padEnd(14, " "); 
                let viz_base = typeof M4_VIZ_BASE !== 'undefined' ? M4_VIZ_BASE : 16;
                let currentValDisplay = (regIdent + ": " + value.asInt(NaN).toString(viz_base)).padEnd(14, " ");
                let dmem_str = new fabric.Text(currentValDisplay, { top: 0, left: 0, fontSize: 14, fill: mod ? "blue" : "black", fontWeight: mod ? 800 : 400, fontFamily: "monospace", textBackgroundColor: rd ? "#b0ffff" : mod ? "#d0e8ff" : "white" });
                if (mod) { setTimeout(() => { dmem_str.set({text: newValStr, dirty: true}); this.global.canvas.renderAll(); }, 1500); }
                return [dmem_str];
            },
            where: {left: 480, top: -40}


\SV
    m4_makerchip_module
\TLV
    // This block is usually empty in the shell.
\SV
    endmodule
