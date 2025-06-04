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
        m4_asm(CUSTOM_RSQR, x11, x7, x0)   // x11 = x7 * x7  (5 * 5 = 25)

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

\TLV cpu_viz() 
    \SV_plus 
        logic sticky_zero; 
        assign sticky_zero = 0;
        logic [40*8-1:0] instr_strs [0:M4_NUM_INSTRS-1]; 
        assign instr_strs = '{m4_asm_mem_expr "END                                     "}; 
    
    \viz_js 
        m4_define(['M4_IMEM_TOP'], ['m4_ifelse(m4_eval(M4_NUM_INSTRS > 16), 0, 0, m4_eval(0 - (M4_NUM_INSTRS - 16) * 18))'])
        box: {strokeWidth: 0}, 
        init() { 
            let num_instrs_for_viz = typeof M4_NUM_INSTRS !== 'undefined' ? M4_NUM_INSTRS : 1;
            let imem_box_height = 76 + 18 * num_instrs_for_viz; 
            let imem_box = new fabric.Rect({ top: M4_IMEM_TOP - 50, left: -700, fill: "#208028", width: 665, height: imem_box_height, stroke: "black", visible: false });
            let decode_box = new fabric.Rect({ top: -25, left: -15, fill: "#f8f0e8", width: 280, height: 215, stroke: "#ff8060", visible: false });
            let rf_box = new fabric.Rect({ top: -90, left: 306, fill: "#2028b0", width: 145, height: 650, stroke: "black", visible: false });
            let dmem_box = new fabric.Rect({ top: -90, left: 470, fill: "#208028", width: 145, height: 650, stroke: "black", visible: false });
            let imem_header = new fabric.Text("🗃️ IMem", { top: M4_IMEM_TOP - 35, left: -460, fontSize: 18, fontWeight: 800, fontFamily: "monospace", fill: "white", visible: false });
            let decode_header = new fabric.Text("⚙️ Instr. Decode", { top: -4, left: 20, fill: "maroon", fontSize: 18, fontWeight: 800, fontFamily: "monospace", visible: false });
            let rf_header = new fabric.Text("📂 RF", { top: -75, left: 316, fontSize: 18, fontWeight: 800, fontFamily: "monospace", fill: "white", visible: false });
            let dmem_header = new fabric.Text("🗃️ DMem", { top: -75, left: 480, fontSize: 18, fontWeight: 800, fontFamily: "monospace", fill: "white", visible: false });
            let passed_text_obj = new fabric.Text("", { top: 340, left: -30, fontSize: 46, fontWeight: 800 });
            this.missing_col1 = new fabric.Text("", { top: 420, left: -480, fontSize: 16, fontWeight: 500, fontFamily: "monospace", fill: "purple" });
            this.missing_col2 = new fabric.Text("", { top: 420, left: -300, fontSize: 16, fontWeight: 500, fontFamily: "monospace", fill: "purple" });
            let missing_sigs_group = new fabric.Group([ new fabric.Text("🚨 To Be Implemented:", { top: 350, left: -466, fontSize: 18, fontWeight: 800, fill: "red", fontFamily: "monospace" }), new fabric.Rect({ top: 400, left: -500, fill: "#ffffe0", width: 400, height: 300, stroke: "black" }), this.missing_col1, this.missing_col2, ], {visible: false});
            return {imem_box, decode_box, rf_box, dmem_box, imem_header, decode_header, rf_header, dmem_header, passed: passed_text_obj, missing_sigs: missing_sigs_group};
        },
        render() { 
            var missing_list = ["", ""], missing_cnt = 0;
            let sticky_zero = this.svSigRef(`sticky_zero`);
            let siggen = (name, full_name, expected = true) => { var sig = this.svSigRef(full_name ? full_name : `L0_${name}_a0`); if (sig == null || !sig.exists()) { sig = sticky_zero; if (expected) { missing_list[missing_cnt > 11 ? 1 : 0] += `◾ $${name}      \n`; missing_cnt++; } } return sig; };
            let siggen_rf_dmem = (name, scope) => siggen(name, scope, false);
            let siggen_mnemonic = () => { 
                let instrs = [ "lui", "auipc", "jal", "jalr", "beq", "bne", "blt", "bge", "bltu", "bgeu", "lb", "lh", "lw", "lbu", "lhu", "sb", "sh", "sw", "addi", "slti", "sltiu", "xori", "ori", "andi", "slli", "srli", "srai", "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and", "mul", "custom_rsqr", "csrrw", "csrrs", "csrrc", "csrrwi", "csrrsi", "csrrci", "load", "s_instr"]; 
                for(let i=0; i < instrs.length; i++) {
                    let sig_name = `L0_is_${instrs[i]}_a0`;
                    let sig = this.svSigRef(sig_name); 
                    if(sig && sig.exists() && sig.asBool(false)) { return instrs[i].toUpperCase(); }
                } return "ILLEGAL";
            };
            let pc = siggen("pc"), instr = siggen("instr");
            let types = {I: siggen("is_i_instr"), R: siggen("is_r_instr"), S: siggen("is_s_instr"), B: siggen("is_b_instr"), J: siggen("is_j_instr"), U: siggen("is_u_instr")};
            let rd_valid = siggen("rd_valid"), rd = siggen("rd"), result = siggen("result");
            let src1_value = siggen("src1_value"), src2_value = siggen("src2_value");
            let imm = siggen("imm"), imm_valid = siggen("imm_valid");
            let rs1 = siggen("rs1"), rs2 = siggen("rs2");
            let rs1_valid = siggen("rs1_valid"), rs2_valid = siggen("rs2_valid");
            let ld_data = siggen("ld_data"); let mnemonic = siggen_mnemonic();
            // VIZ uses the $passed_cond signal directly, and its own logic checks for stability.
            let passed_sig = siggen("passed_cond", "L0_passed_cond_a0", false); 
            let rf_rd_en1 = siggen_rf_dmem("rf1_rd_en1", `L0_rf1_rd_en1_a0`), rf_rd_index1 = siggen_rf_dmem("rf1_rd_index1", `L0_rf1_rd_index1_a0`);
            let rf_rd_en2 = siggen_rf_dmem("rf1_rd_en2", `L0_rf1_rd_en2_a0`), rf_rd_index2 = siggen_rf_dmem("rf1_rd_index2", `L0_rf1_rd_index2_a0`);
            let rf_wr_en = siggen_rf_dmem("rf1_wr_en", `L0_rf1_wr_en_a0`), rf_wr_index = siggen_rf_dmem("rf1_wr_index", `L0_rf1_wr_index_a0`);
            let rf_wr_data = siggen_rf_dmem("rf1_wr_data", `L0_rf1_wr_data_a0`);
            let dmem_rd_en = siggen_rf_dmem("dmem1_rd_en", `L0_dmem1_rd_en_a0`), dmem_wr_en = siggen_rf_dmem("dmem1_wr_en", `L0_dmem1_wr_en_a0`);
            let dmem_addr = siggen_rf_dmem("dmem1_addr", `L0_dmem1_addr_a0`);
            if (instr != sticky_zero) { this.getObjects().imem_box.set({visible: true}); this.getObjects().imem_header.set({visible: true}); this.getObjects().decode_box.set({visible: true}); this.getObjects().decode_header.set({visible: true}); }
            let pc_val = pc.asInt(0);
            let pcPointer = new fabric.Text("👉", { top: M4_IMEM_TOP + 18 * (pc_val / 4), left: -375, fill: "blue", fontSize: 14, fontFamily: "monospace", visible: pc != sticky_zero && pc_val >=0 });
            let pc_arrow = new fabric.Line([-57, M4_IMEM_TOP + 18 * (pc_val / 4) + 9, 6, 35+9], { stroke: "#b0c8df", strokeWidth: 2, visible: instr != sticky_zero && pc_val >=0 });
            let type_texts = []; for (const [type, sig] of Object.entries(types)) { if (sig.asBool()) { type_texts.push( new fabric.Text(`(${type})`, { top: 60, left: 10 + type_texts.length * 40, fill: "blue", fontSize: 20, fontFamily: "monospace" })); } }
            let rs1_arrow = new fabric.Line([330, 18 * rf_rd_index1.asInt(0) + 6 - 40, 190, 75 + 18 * 2], { stroke: "#b0c8df", strokeWidth: 2, visible: rf_rd_en1.asBool() });
            let rs2_arrow = new fabric.Line([330, 18 * rf_rd_index2.asInt(0) + 6 - 40, 190, 75 + 18 * 3], { stroke: "#b0c8df", strokeWidth: 2, visible: rf_rd_en2.asBool() });
            let rd_arrow = new fabric.Line([330, 18 * rf_wr_index.asInt(0) + 6 - 40, 168, 75 + 18 * 0], { stroke: "#b0b0df", strokeWidth: 3, visible: rf_wr_en.asBool() });
            let ld_arrow = new fabric.Line([490, 18 * dmem_addr.asInt(0) + 6 - 40, 168, 75 + 18 * 0], { stroke: "#b0c8df", strokeWidth: 2, visible: dmem_rd_en.asBool() });
            let st_arrow = new fabric.Line([490, 18 * dmem_addr.asInt(0) + 6 - 40, 190, 75 + 18 * 3], { stroke: "#b0b0df", strokeWidth: 3, visible: dmem_wr_en.asBool() });
            if (rf_rd_en1.exists() && rf_rd_en1 != sticky_zero) { this.getObjects().rf_box.set({visible: true}); this.getObjects().rf_header.set({visible: true}); }
            if ((dmem_rd_en.exists() && dmem_rd_en != sticky_zero) || (dmem_wr_en.exists() && dmem_wr_en != sticky_zero) ) { this.getObjects().dmem_box.set({visible: true}); this.getObjects().dmem_header.set({visible: true}); }
            let regStr = (valid, regNum, regValue) => valid ? `x${regNum}` : `xX`;
            let immStr = (valid, immValueBin) => { if (!valid) return ""; let imm_val = parseInt(immValueBin, 2); if (immValueBin.length === 12 && immValueBin[0] === '1') imm_val -= (1 << 12); else if (immValueBin.length === 20 && immValueBin[0] === '1') imm_val -= (1 << 20); return `i[${imm_val}]`; };
            let srcStr = (srcNum, valid_sig, reg_sig, val_sig) => valid_sig.asBool(false) ? `\n      ${regStr(true, reg_sig.asInt(NaN), val_sig.asInt(NaN))}` : "";
            let instrFullStr = `${regStr(rd_valid.asBool(false), rd.asInt(NaN), rf_wr_data.asInt(NaN))}\n  = ${mnemonic}${srcStr(1, rs1_valid, rs1, src1_value)}${srcStr(2, rs2_valid, rs2, src2_value)}\n      ${immStr(imm_valid.asBool(false), imm.asBinaryStr("0".repeat(32)))}`;
            let instrWithValues = new fabric.Text(instrFullStr, { top: 70, left: 65, fill: "blue", fontSize: 14, fontFamily: "monospace", visible: instr != sticky_zero });
            let fetch_instr_str = siggen(`instr_strs[${pc_val >> 2}]`, `instr_strs[${pc_val >> 2}]`, false).asString("(?)").substr(4);
            let fetch_instr_viz = new fabric.Text(fetch_instr_str, { top: M4_IMEM_TOP + 18 * (pc_val >> 2), left: -352 + 8 * 4, fill: "black", fontSize: 14, fontFamily: "monospace", visible: instr != sticky_zero && pc_val >=0 });
            if(instr != sticky_zero && pc_val >=0) { fetch_instr_viz.animate({top: 32, left: 10}, { onChange: this.global.canvas.renderAll.bind(this.global.canvas), duration: 500 }); }
            let viz_base_render = typeof M4_VIZ_BASE !== 'undefined' ? M4_VIZ_BASE : 16;
            let src1_val_viz_text = src1_value.asInt(0).toString(viz_base_render);
            let src1_value_viz = new fabric.Text(src1_val_viz_text, { left: 316 + 8 * 4, top: 18 * rs1.asInt(0) - 40, fill: "blue", fontSize: 14, fontFamily: "monospace", fontWeight: 800, visible: (src1_value != sticky_zero) && rs1_valid.asBool(false) });
            if((src1_value != sticky_zero) && rs1_valid.asBool(false)) { setTimeout(() => {src1_value_viz.animate({left: 166, top: 70 + 18 * 2}, { onChange: this.global.canvas.renderAll.bind(this.global.canvas), duration: 500 })}, 500); }
            let src2_val_viz_text = src2_value.asInt(0).toString(viz_base_render);
            let src2_value_viz = new fabric.Text(src2_val_viz_text, { left: 316 + 8 * 4, top: 18 * rs2.asInt(0) - 40, fill: "blue", fontSize: 14, fontFamily: "monospace", fontWeight: 800, visible: (src2_value != sticky_zero) && rs2_valid.asBool(false) });
            if((src2_value != sticky_zero) && rs2_valid.asBool(false)) { setTimeout(() => {src2_value_viz.animate({left: 166, top: 70 + 18 * 3}, { onChange: this.global.canvas.renderAll.bind(this.global.canvas), duration: 500 })}, 500); }
            let ld_val_viz_text = ld_data.asInt(0).toString(viz_base_render);
            let load_viz = new fabric.Text(ld_val_viz_text, { left: 470 + 8*4, top: 18 * dmem_addr.asInt(0) - 40, fill: "blue", fontSize: 14, fontFamily: "monospace", fontWeight: 1000, visible: false });
            if (dmem_rd_en.asBool()) { setTimeout(() => { load_viz.set({visible: true}); load_viz.animate({left: 146, top: 70}, { onChange: this.global.canvas.renderAll.bind(this.global.canvas), duration: 500 }); setTimeout(() => { load_viz.set({visible: false}) }, 500); }, 500); }
            let store_val_viz_text = src2_value.asInt(0).toString(viz_base_render);
            let store_viz = new fabric.Text(store_val_viz_text, { left: 166, top: 70 + 18 * 3, fill: "blue", fontSize: 14, fontFamily: "monospace", fontWeight: 1000, visible: false });
            if (dmem_wr_en.asBool()) { setTimeout(() => { store_viz.set({visible: true}); store_viz.animate({left: 515, top: 18 * dmem_addr.asInt(0) - 40}, { onChange: this.global.canvas.renderAll.bind(this.global.canvas), duration: 500 }); setTimeout(() => { store_viz.set({visible: false}) }, 500); }, 1000); }
            let result_shadow_text = result.asInt(0).toString(viz_base_render);
            let result_shadow = new fabric.Text(result_shadow_text, { left: 146, top: 70, fill: "#b0b0df", fontSize: 14, fontFamily: "monospace", fontWeight: 800, visible: false });
            let result_viz_text = rf_wr_data.asInt(0).toString(viz_base_render);
            let result_viz = new fabric.Text(result_viz_text, { left: 146, top: 70, fill: "blue", fontSize: 14, fontFamily: "monospace", fontWeight: 800, visible: false });
            if (rd_valid.asBool() && rf_wr_en.asBool()) { setTimeout(() => { result_viz.set({visible: rf_wr_data != sticky_zero}); result_shadow.set({visible: result != sticky_zero && result.asInt(0) !== rf_wr_data.asInt(0) }); result_viz.animate({left: 317 + 8 * 4, top: 18 * rf_wr_index.asInt(0) - 40}, { onChange: this.global.canvas.renderAll.bind(this.global.canvas), duration: 500 }); }, 1000); }
            let current_passed_obj = this.getObjects().passed; 
            current_passed_obj.set({visible: false}); 
            if (passed_sig && passed_sig.exists()) { if (passed_sig.step(-1).asBool()) { current_passed_obj.set({visible: true, text:"Passed !!!", fill: "green"}); } else { try { passed_sig.goToSimEnd().step(-1); if (passed_sig.asBool()) { current_passed_obj.set({text:"Sim Passes", visible: true, fill: "lightgray"}); } } catch(e) {} } }
            if (missing_list[0]) { this.getObjects().missing_sigs.set({visible: true}); this.missing_col1.set({text: missing_list[0]}); this.missing_col2.set({text: missing_list[1]}); } else {this.getObjects().missing_sigs.set({visible: false});}
            return [pcPointer, pc_arrow, ...type_texts, rs1_arrow, rs2_arrow, rd_arrow, instrWithValues, fetch_instr_viz, src1_value_viz, src2_value_viz, result_shadow, result_viz, ld_arrow, st_arrow, load_viz, store_viz];
        }
        
    /imem[m4_eval(M4_NUM_INSTRS-1):0] 
        \viz_js
            box: {width: 630, height: 18, strokeWidth: 0},
            init() { let binary = new fabric.Text("", { top: 0, left: 0, fontSize: 14, fontFamily: "monospace" }); let disassembled = new fabric.Text("", { top: 0, left: 330, fontSize: 14, fontFamily: "monospace" }); return {binary, disassembled}; },
            onTraceData() { 
                let instr_val_sig = this.svSigRef(`instrs[${this.getIndex()}]`); if (!instr_val_sig || !instr_val_sig.exists()) { instr_val_sig = this.svSigRef(`instrs(${this.getIndex()})`); }
                if (instr_val_sig && instr_val_sig.exists()) { let binary_str = instr_val_sig.goToSimStart().asBinaryStr("0".repeat(32)).padEnd(32, '0'); this.getObjects().binary.set({text: `${binary_str.substr(0,7)} ${binary_str.substr(7,5)} ${binary_str.substr(12,5)} ${binary_str.substr(17,3)} ${binary_str.substr(20,5)} ${binary_str.substr(25,7)}`}); }
                let disassembled_sig = this.svSigRef(`instr_strs[${this.getIndex()}]`); if (!disassembled_sig || !disassembled_sig.exists()) { disassembled_sig = this.svSigRef(`instr_strs(${this.getIndex()})`); }
                if (disassembled_sig && disassembled_sig.exists()) { let disassembled_str = disassembled_sig.goToSimStart().asString("").slice(0, -5); this.getObjects().disassembled.set({text: disassembled_str}); }
            },
            render() { 
                let reset = this.svSigRef(`L0_reset_a0`); let pc = this.svSigRef(`L0_pc_a0`);
                let rd_viz = pc && pc.exists() && !reset.asBool(false) && (pc.asInt(0) >> 2) == this.getIndex();
                this.getObjects().disassembled.set({textBackgroundColor: rd_viz ? "#b0ffff" : "white"});
                this.getObjects().binary.set({textBackgroundColor: rd_viz ? "#b0ffff" : "white"});
            },
            where: {left: -680, top: M4_IMEM_TOP}
            
\TLV tb() 
    // Corrected indentation and simplified *passed assignment
    $passed_cond = (/xreg[30]$value == 32'b1) &&
                   (! $reset && $next_pc[31:0] == $pc[31:0]);
    *passed = $passed_cond; // VIZ will check for stability (passed_sig.step(-1))

// Original sum_prog is kept for reference but not used if m4_test_prog is active.
\TLV sum_prog()
    m4_asm(ADDI, x14, x0, 000000000000)
    m4_asm(ADDI, x12, x0, 000000001010) 
    m4_asm(ADDI, x13, x0, 000000000001)   
    // Loop:
    m4_asm(ADD, x14, x13, x14)
    m4_asm(ADDI, x13, x13, 000000000001)  
    m4_asm(BLT, x13, x12, 1111111111000) 
    m4_asm(ADDI, x30, x14, 111111010100) 
    m4_asm(BGE, x0, x0, 0000000000000) 
    m4_asm_end_tlv()
    m4_define(['M4_MAX_CYC'], 40) 
// ^===================================================================^

\SV
    m4_makerchip_module
\TLV
    // This block is usually empty in the shell.
\SV
    endmodule
