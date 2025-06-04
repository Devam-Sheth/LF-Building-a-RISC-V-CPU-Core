\m4_TLV_version 1d: tl-x.org
\SV
    // Include RISC-V definitions (opcodes, funct3, etc.)
    // The path should point to a valid risc-v_defs.tlv file.
    m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])
    
// v====================== lib/risc-v_shell_lib.tlv =======================v

// Configuration for WARP-V definitions.
m4+definitions(['
    // Define MUL for m4_asm (Standard M Extension)
    // opcode=0110011, funct3=000, funct7=0000001
    m4_define(MUL, m4_asm_args_r(0110011, 000, 0000001))

    // Define custom RSQR instruction for m4_asm
    // opcode=0001011, funct3=001, funct7=0000010
    m4_define(CUSTOM_RSQR_OPCODE_VAL, 0001011) // Renamed to avoid conflict if CUSTOM_RSQR_OPCODE is defined elsewhere
    m4_define(CUSTOM_RSQR_FUNCT3_VAL, 001)   // Renamed
    m4_define(CUSTOM_RSQR_FUNCT7_VAL, 0000010)  // Renamed
    m4_define(CUSTOM_RSQR, m4_asm_args_r(CUSTOM_RSQR_OPCODE_VAL, CUSTOM_RSQR_FUNCT3_VAL, CUSTOM_RSQR_FUNCT7_VAL))

    // Define full test program.
    // Provide a non-empty argument if this is instantiated within a \TLV region (vs. \SV).
    m4_define(['m4_test_prog'], ['m4_hide(['
        // /====================================\
        // | Test Program for MUL and RSQR      |
        // \====================================/
        //
        // Regs:
        //  x5: operand A (value: 3)
        //  x6: operand B (value: 4)
        //  x7: operand C (value: 5, for RSQR)
        //  x10: result of MUL (x5 * x6) -> 3 * 4 = 12
        //  x11: result of RSQR (x7 * x7) -> 5 * 5 = 25
        //  x12: expected MUL result (12)
        //  x13: expected RSQR result (25)
        //  x14: intermediate check for MUL
        //  x15: intermediate check for RSQR
        //  x30: test status (1 for pass, 0 for fail)

        // Initialize registers
        m4_asm(ADDI, x5, x0, 3)            // x5 = 3
        m4_asm(ADDI, x6, x0, 4)            // x6 = 4
        m4_asm(ADDI, x7, x0, 5)            // x7 = 5 (for RSQR)

        // Test MUL: x10 = x5 * x6
        m4_asm(MUL, x10, x5, x6)           // x10 = 3 * 4 = 12

        // Test CUSTOM_RSQR: x11 = x7 * x7 (rs2 is x0, ignored by typical single-operand custom ops)
        m4_asm(CUSTOM_RSQR, x11, x7, x0)   // x11 = 5 * 5 = 25

        // Verification logic for x30
        m4_asm(ADDI, x12, x0, 12)          // Load expected MUL result into x12
        m4_asm(ADDI, x13, x0, 25)          // Load expected RSQR result into x13
        m4_asm(ADDI, x30, x0, 0)           // Initialize x30 to 0 (fail state)

        // Check MUL result: x14 = (x10 == x12)
        m4_asm(SUB, x14, x10, x12)         // x14 = x10 - 12. If x10==12, x14=0.
        m4_asm(SLTIU, x14, x14, 1)         // x14 = (x14 < 1) ? 1 : 0. So, if x14 was 0 (match), x14 becomes 1.

        // Check RSQR result: x15 = (x11 == x13)
        m4_asm(SUB, x15, x11, x13)         // x15 = x11 - 25. If x11==25, x15=0.
        m4_asm(SLTIU, x15, x15, 1)         // x15 = (x15 < 1) ? 1 : 0. So, if x15 was 0 (match), x15 becomes 1.

        // Combine checks: x30 = x14 AND x15
        m4_asm(AND, x14, x14, x15)         // x14 = 1 if both checks passed, else 0.
        m4_asm(OR, x30, x0, x14)           // Set x30 to 1 if x14 is 1 (overall pass), else x30 remains 0 or becomes 0.

        // Terminate with success condition (x30 should be 1 if tests passed):
        m4_asm(JAL, x0, 0) // Done. Jump to itself (infinite loop).
        
        m4_define(['M4_VIZ_BASE'], 16)     // Visualization base for numbers (hexadecimal)
        m4_define(['M4_MAX_CYC'], 40)      // Max cycles for this test program
    '])m4_ifelse(['$1'], [''], ['m4_asm_end()'], ['m4_asm_end_tlv()'])'])
    
    m4_define_vector(['M4_WORD'], 32)
    m4_define(['M4_EXT_I'], 1) // Assuming RV32I base
    // M4_EXT_M should be defined if MUL is part of standard M extension handling by other macros
    // m4_define(['M4_EXT_M'], 1) 
    
    m4_define(['M4_NUM_INSTRS'], 0) // Initialized, m4_asm will increment this
    
    m4_echo(m4tlv_riscv_gen__body()) // This likely generates instruction encoding logic based on included defs.
    
    // A single-line M4 macro instantiated at the end of the asm code.
    // It actually produces a definition of an SV macro that instantiates the IMem conaining the program.
    m4_define(['m4_asm_end'], ['`define READONLY_MEM(ADDR, DATA) logic [31:0] instrs [0:M4_NUM_INSTRS-1]; assign DATA = instrs[ADDR[$clog2($size(instrs)) + 1 : 2]]; assign instrs = '{m4_instr0['']m4_forloop(['m4_instr_ind'], 1, M4_NUM_INSTRS, [', m4_echo(['m4_instr']m4_instr_ind)'])};'])
    m4_define(['m4_asm_end_tlv'], ['`define READONLY_MEM(ADDR, DATA) logic [31:0] instrs [0:M4_NUM_INSTRS-1]; assign DATA \= instrs[ADDR[\$clog2(\$size(instrs)) + 1 : 2]]; assign instrs \= '{m4_instr0['']m4_forloop(['m4_instr_ind'], 1, M4_NUM_INSTRS, [', m4_echo(['m4_instr']m4_instr_ind)'])};'])
'])

\TLV test_prog() // This macro will now expand to the new test program defined above
    m4_test_prog(['TLV'])

// Register File
\TLV rf(_entries, _width, $_reset, $_port1_en, $_port1_index, $_port1_data, $_port2_en, $_port2_index, $_port2_data, $_port3_en, $_port3_index, $_port3_data)
    // Port 1: Write Port
    $rf1_wr_en = m4_argn(4, $@);
    $rf1_wr_index[\$clog2(_entries)-1:0]  = m4_argn(5, $@);
    $rf1_wr_data[_width-1:0] = m4_argn(6, $@);
    
    // Port 2: Read Port 1 (rs1)
    $rf1_rd_en1 = m4_argn(7, $@);
    $rf1_rd_index1[\$clog2(_entries)-1:0] = m4_argn(8, $@);
    // $_port2_data is output for rs1
    
    // Port 3: Read Port 2 (rs2)
    $rf1_rd_en2 = m4_argn(10, $@);
    $rf1_rd_index2[\$clog2(_entries)-1:0] = m4_argn(11, $@);
    // $_port3_data is output for rs2
    
    /xreg[m4_eval(_entries-1):0]
        // Write logic: only write if enable is high and index is not x0 (if x0 is not writable)
        // Assuming x0 is writable based on original logic ($wr = /top$rf1_wr_en && (/top$rf1_wr_index == #xreg);)
        // If x0 should not be written, add: && (/top$rf1_wr_index != 0)
        $wr = /top$rf1_wr_en && (/top$rf1_wr_index == #xreg);
        <<1$value[_width-1:0] = /top$_reset ? _width'b0 : // Reset to 0
                                 $wr       ? /top$rf1_wr_data :
                                           $RETAIN;
    
    // Read logic for rs1
    $_port2_data[_width-1:0]  =  ($rf1_rd_en1 && $rf1_rd_index1 == 0) ? _width'b0 : // Reading x0 always yields 0
                                 $rf1_rd_en1 ? /xreg[$rf1_rd_index1]$value :
                                 'X; // Undefined if read not enabled
    // Read logic for rs2
    $_port3_data[_width-1:0]  =  ($rf1_rd_en2 && $rf1_rd_index2 == 0) ? _width'b0 : // Reading x0 always yields 0
                                 $rf1_rd_en2 ? /xreg[$rf1_rd_index2]$value :
                                 'X; // Undefined if read not enabled
    
    /xreg[m4_eval(_entries-1):0]
        \viz_js
            box: {width: 120, height: 18, strokeWidth: 0},
            render() {
                let siggen = (name) => {
                    let sig = this.svSigRef(`${name}`)
                    return (sig == null || !sig.exists()) ? this.svSigRef(`sticky_zero`) : sig;
                }
                let rf_rd_en1 = siggen(`L0_rf1_rd_en1_a0`) // Path to rs1 enable
                let rf_rd_index1 = siggen(`L0_rf1_rd_index1_a0`) // Path to rs1 index
                let rf_rd_en2 = siggen(`L0_rf1_rd_en2_a0`) // Path to rs2 enable
                let rf_rd_index2 = siggen(`L0_rf1_rd_index2_a0`) // Path to rs2 index
                let wr = siggen(`L1_Xreg[${this.getIndex()}].L1_wr_a0`) // Path to write enable for this specific register
                let value = siggen(`Xreg_value_a0[${this.getIndex()}]`) // Path to current value of this register
                
                let rd = (rf_rd_en1.asBool(false) && rf_rd_index1.asInt() == this.getIndex()) || 
                         (rf_rd_en2.asBool(false) && rf_rd_index2.asInt() == this.getIndex())
                
                let mod = wr.asBool(false);
                let reg = parseInt(this.getIndex())
                let regIdent = reg.toString().padEnd(2, " ")
                let newValStr = (regIdent + ": ").padEnd(14, " ") // Used for the delayed "clear" effect
                let currentValDisplay = (regIdent + ": " + value.asInt(NaN).toString(M4_VIZ_BASE)).padEnd(14, " ");

                let reg_str = new fabric.Text(currentValDisplay, {
                    top: 0,
                    left: 0,
                    fontSize: 14,
                    fill: mod ? "blue" : "black",
                    fontWeight: mod ? 800 : 400,
                    fontFamily: "monospace",
                    textBackgroundColor: rd ? "#b0ffff" : mod ? "#f0f0f0" : "white"
                })
                if (mod) {
                    setTimeout(() => {
                        // This creates the effect of briefly showing the value, then clearing to "Rx: "
                        reg_str.set({text: newValStr, textBackgroundColor: "#d0e8ff", dirty: true}) 
                        this.global.canvas.renderAll()
                    }, 1500)
                }
                return [reg_str]
            },
            where: {left: 316, top: -40} // Position of the RF visualization block
            
// Data Memory
\TLV dmem(_entries, _width, $_reset, $_addr, $_port1_en, $_port1_data, $_port2_en, $_port2_data)
    // Port 1: Write Port
    $dmem1_wr_en = $_port1_en;
    $dmem1_addr[\$clog2(_entries)-1:0] = $_addr;
    $dmem1_wr_data[_width-1:0] = $_port1_data;
    
    // Port 2: Read Port
    $dmem1_rd_en = $_port2_en;
    // $_port2_data is the output for read data
    
    /dmem[m4_eval(_entries-1):0]
        $wr = /top$dmem1_wr_en && (/top$dmem1_addr == #dmem);
        <<1$value[_width-1:0] = /top$_reset ? _width'b0 : // Reset to 0
                                 $wr       ? /top$dmem1_wr_data :
                                           $RETAIN;
    
    $_port2_data[_width-1:0] = $dmem1_rd_en ? /dmem[$dmem1_addr]$value : 'X; // Undefined if not reading
    /dmem[m4_eval(_entries-1):0]
        \viz_js
            box: {width: 120, height: 18, strokeWidth: 0},
            render() {
                let siggen = (name) => {
                    let sig = this.svSigRef(`${name}`)
                    return (sig == null || !sig.exists()) ? this.svSigRef(`sticky_zero`) : sig;
                }
                let dmem_rd_en = siggen(`L0_dmem1_rd_en_a0`); // Path to dmem read enable
                let dmem_addr = siggen(`L0_dmem1_addr_a0`);   // Path to dmem address
                let wr = siggen(`L1_Dmem[${this.getIndex()}].L1_wr_a0`); // Path to write enable for this memory location
                let value = siggen(`Dmem_value_a0[${this.getIndex()}]`);// Path to current value of this memory location
                
                let rd = dmem_rd_en.asBool() && dmem_addr.asInt() == this.getIndex();
                let mod = wr.asBool(false);
                let reg = parseInt(this.getIndex()); // 'reg' here means memory index
                let regIdent = reg.toString().padEnd(2, " ");
                let newValStr = (regIdent + ": ").padEnd(14, " "); // Used for the delayed "clear" effect
                let currentValDisplay = (regIdent + ": " + value.asInt(NaN).toString(M4_VIZ_BASE)).padEnd(14, " ");

                let dmem_str = new fabric.Text(currentValDisplay, {
                    top: 0,
                    left: 0,
                    fontSize: 14,
                    fill: mod ? "blue" : "black",
                    fontWeight: mod ? 800 : 400,
                    fontFamily: "monospace",
                    textBackgroundColor: rd ? "#b0ffff" : mod ? "#d0e8ff" : "white"
                })
                if (mod) {
                    setTimeout(() => {
                        // This creates the effect of briefly showing the value, then clearing to "MemX: "
                        dmem_str.set({text: newValStr, dirty: true}) // Original didn't change background color here
                        this.global.canvas.renderAll()
                    }, 1500)
                }
                return [dmem_str]
            },
            where: {left: 480, top: -40} // Position of the DMEM visualization block

\TLV cpu_viz()
    // String representations of the instructions for debug.
    \SV_plus
        // A default signal for ones that are not found.
        logic sticky_zero;
        assign sticky_zero = 0;
        // Instruction strings from the assembler.
        logic [40*8-1:0] instr_strs [0:M4_NUM_INSTRS]; // Size based on M4_NUM_INSTRS
        // m4_asm_mem_expr generates the array of strings.
        assign instr_strs = '{m4_asm_mem_expr "END                                     "}; 
    
    \viz_js
        m4_define(['M4_IMEM_TOP'], ['m4_ifelse(m4_eval(M4_NUM_INSTRS > 16), 0, 0, m4_eval(0 - (M4_NUM_INSTRS - 16) * 18))'])
        box: {strokeWidth: 0},
        init() {
            // ... (rest of the init() function from your provided code, it defines boxes and headers) ...
            let imem_box = new fabric.Rect({
                top: M4_IMEM_TOP - 50, left: -700, fill: "#208028", width: 665,
                height: 76 + 18 * M4_NUM_INSTRS, stroke: "black", visible: false
            })
            let decode_box = new fabric.Rect({
                top: -25, left: -15, fill: "#f8f0e8", width: 280, height: 215,
                stroke: "#ff8060", visible: false
            })
            let rf_box = new fabric.Rect({
                top: -90, left: 306, fill: "#2028b0", width: 145, height: 650,
                stroke: "black", visible: false
            })
            let dmem_box = new fabric.Rect({
                top: -90, left: 470, fill: "#208028", width: 145, height: 650,
                stroke: "black", visible: false
            })
            let imem_header = new fabric.Text("🗃️ IMem", {
                top: M4_IMEM_TOP - 35, left: -460, fontSize: 18, fontWeight: 800,
                fontFamily: "monospace", fill: "white", visible: false
            })
            let decode_header = new fabric.Text("⚙️ Instr. Decode", {
                top: -4, left: 20, fill: "maroon", fontSize: 18, fontWeight: 800,
                fontFamily: "monospace", visible: false
            })
            let rf_header = new fabric.Text("📂 RF", {
                top: -75, left: 316, fontSize: 18, fontWeight: 800,
                fontFamily: "monospace", fill: "white", visible: false
            })
            let dmem_header = new fabric.Text("🗃️ DMem", {
                top: -75, left: 480, fontSize: 18, fontWeight: 800,
                fontFamily: "monospace", fill: "white", visible: false
            })
            let passed = new fabric.Text("", {
                top: 340, left: -30, fontSize: 46, fontWeight: 800
            })
            this.missing_col1 = new fabric.Text("", {
                top: 420, left: -480, fontSize: 16, fontWeight: 500,
                fontFamily: "monospace", fill: "purple"
            })
            this.missing_col2 = new fabric.Text("", {
                top: 420, left: -300, fontSize: 16, fontWeight: 500,
                fontFamily: "monospace", fill: "purple"
            })
            let missing_sigs = new fabric.Group(
                [new fabric.Text("🚨 To Be Implemented:", {
                    top: 350, left: -466, fontSize: 18, fontWeight: 800,
                    fill: "red", fontFamily: "monospace"
                }),
                new fabric.Rect({
                    top: 400, left: -500, fill: "#ffffe0", width: 400,
                    height: 300, stroke: "black"
                }),
                this.missing_col1, this.missing_col2,],
                {visible: false}
            )
            return {imem_box, decode_box, rf_box, dmem_box, imem_header, decode_header, rf_header, dmem_header, passed, missing_sigs}
        },
        render() {
            var missing_list = ["", ""]
            var missing_cnt = 0
            let sticky_zero = this.svSigRef(`sticky_zero`);
            let siggen = (name, full_name, expected = true) => {
                var sig = this.svSigRef(full_name ? full_name : `L0_${name}_a0`)
                if (sig == null || !sig.exists()) {
                    sig = sticky_zero;
                    if (expected) {
                        missing_list[missing_cnt > 11 ? 1 : 0] += `◾ $${name}      \n`; // Adjusted spacing
                        missing_cnt++
                    }
                }
                return sig
            }
            siggen_rf_dmem = (name, scope) => { // Ensure this is declared with let/var/const if not global
                return siggen(name, scope, false)
            }
            
            siggen_mnemonic = () => { // Ensure this is declared with let/var/const
                // Added "mul" and "rsqr" to the list
                let instrs = ["lui", "auipc", "jal", "jalr", "beq", "bne", "blt", "bge", "bltu", "bgeu", 
                              "lb", "lh", "lw", "lbu", "lhu", "sb", "sh", "sw", 
                              "addi", "slti", "sltiu", "xori", "ori", "andi", 
                              "slli", "srli", "srai", 
                              "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and",
                              "mul", "rsqr", // Added MUL and RSQR
                              "csrrw", "csrrs", "csrrc", "csrrwi", "csrrsi", "csrrci", 
                              "load", "s_instr"]; // "load" and "s_instr" are generic, specific ones are preferred
                for(let i=0; i<instrs.length; i++) { // Use let for i
                    // Construct signal name, e.g. L0_is_mul_a0, L0_is_rsqr_a0
                    var sig = this.svSigRef(`L0_is_${instrs[i]}_a0`) 
                    if(sig != null && sig.exists() && sig.asBool(false)) { // Check existence before asBool
                        return instrs[i].toUpperCase()
                    }
                }
                return "ILLEGAL"
            }
            
            let pc            =   siggen("pc")
            let instr         =   siggen("instr")
            let types = {I: siggen("is_i_instr"), R: siggen("is_r_instr"), S: siggen("is_s_instr"),
                         B: siggen("is_b_instr"), J: siggen("is_j_instr"), U: siggen("is_u_instr")}
            let rd_valid      =   siggen("rd_valid")
            let rd            =   siggen("rd")
            let result        =   siggen("result") // This is ALU result before load handling
            let src1_value    =   siggen("src1_value")
            let src2_value    =   siggen("src2_value")
            let imm           =   siggen("imm")
            let imm_valid     =   siggen("imm_valid")
            let rs1           =   siggen("rs1")
            let rs2           =   siggen("rs2")
            let rs1_valid     =   siggen("rs1_valid")
            let rs2_valid     =   siggen("rs2_valid")
            let ld_data       =   siggen("ld_data") // Data read from DMEM
            let mnemonic      =   siggen_mnemonic()
            let passed_sig    =   siggen("passed", "L0_passed_a0", false) // Renamed to avoid conflict with passed var in init
            
            let rf_rd_en1     =   siggen_rf_dmem("rf1_rd_en1", `L0_rf1_rd_en1_a0`)
            let rf_rd_index1  =   siggen_rf_dmem("rf1_rd_index1", `L0_rf1_rd_index1_a0`)
            let rf_rd_en2     =   siggen_rf_dmem("rf1_rd_en2", `L0_rf1_rd_en2_a0`)
            let rf_rd_index2  =   siggen_rf_dmem("rf1_rd_index2", `L0_rf1_rd_index2_a0`)
            let rf_wr_en      =   siggen_rf_dmem("rf1_wr_en", `L0_rf1_wr_en_a0`)
            let rf_wr_index   =   siggen_rf_dmem("rf1_wr_index", `L0_rf1_wr_index_a0`)
            let rf_wr_data    =   siggen_rf_dmem("rf1_wr_data", `L0_rf1_wr_data_a0`) // Data to be written to RF
            let dmem_rd_en    =   siggen_rf_dmem("dmem1_rd_en", `L0_dmem1_rd_en_a0`)
            let dmem_wr_en    =   siggen_rf_dmem("dmem1_wr_en", `L0_dmem1_wr_en_a0`)
            let dmem_addr     =   siggen_rf_dmem("dmem1_addr", `L0_dmem1_addr_a0`)
            
            // ... (rest of the render() function from your provided code) ...
            // This includes visibility settings for boxes, arrows, text display, animations.
            if (instr != sticky_zero) {
                this.getObjects().imem_box.set({visible: true})
                this.getObjects().imem_header.set({visible: true})
                this.getObjects().decode_box.set({visible: true})
                this.getObjects().decode_header.set({visible: true})
            }
            let pcPointer = new fabric.Text("👉", {
                top: M4_IMEM_TOP + 18 * (pc.asInt() / 4), left: -375, fill: "blue",
                fontSize: 14, fontFamily: "monospace", visible: pc != sticky_zero
            })
            let pc_arrow = new fabric.Line([-57, M4_IMEM_TOP + 18 * (pc.asInt() / 4) + 6, 6, 35], {
                stroke: "#b0c8df", strokeWidth: 2, visible: instr != sticky_zero
            })
            let type_texts = []
            for (const [type, sig] of Object.entries(types)) {
                if (sig.asBool()) {
                    type_texts.push(
                        new fabric.Text(`(${type})`, {
                            top: 60, left: 10 + type_texts.length * 40, // Adjust left for multiple types
                            fill: "blue", fontSize: 20, fontFamily: "monospace"
                        })
                    )
                }
            }
            let rs1_arrow = new fabric.Line([330, 18 * rf_rd_index1.asInt() + 6 - 40, 190, 75 + 18 * 2], {
                stroke: "#b0c8df", strokeWidth: 2, visible: rf_rd_en1.asBool()
            })
            let rs2_arrow = new fabric.Line([330, 18 * rf_rd_index2.asInt() + 6 - 40, 190, 75 + 18 * 3], {
                stroke: "#b0c8df", strokeWidth: 2, visible: rf_rd_en2.asBool()
            })
            let rd_arrow = new fabric.Line([330, 18 * rf_wr_index.asInt() + 6 - 40, 168, 75 + 18 * 0], {
                stroke: "#b0b0df", strokeWidth: 3, visible: rf_wr_en.asBool()
            })
            let ld_arrow = new fabric.Line([490, 18 * dmem_addr.asInt() + 6 - 40, 168, 75 + 18 * 0], {
                stroke: "#b0c8df", strokeWidth: 2, visible: dmem_rd_en.asBool()
            })
            let st_arrow = new fabric.Line([490, 18 * dmem_addr.asInt() + 6 - 40, 190, 75 + 18 * 3], {
                stroke: "#b0b0df", strokeWidth: 3, visible: dmem_wr_en.asBool()
            })
            if (rf_rd_en1 != sticky_zero) { // Check if RF is used
                this.getObjects().rf_box.set({visible: true})
                this.getObjects().rf_header.set({visible: true})
            }
            if (dmem_rd_en != sticky_zero || dmem_wr_en != sticky_zero) { // Check if DMEM is used
                this.getObjects().dmem_box.set({visible: true})
                this.getObjects().dmem_header.set({visible: true})
            }
            let regStr = (valid, regNum, regValue) => {
                return valid ? `x${regNum}` : `xX` 
            }
            let immStr = (valid, immValue) => {
                let decImm = parseInt(immValue, 2);
                if (immValue.length === 32 && immValue[0] === '1') { // Sign extend for 32-bit imm
                    decImm = decImm - Math.pow(2, 32);
                } else if (immValue.length === 20 && immValue[0] === '1') { // Sign extend for J-type
                     decImm = decImm - Math.pow(2, 20);
                } else if (immValue.length === 12 && immValue[0] === '1') { // Sign extend for I/S/B-type
                     decImm = decImm - Math.pow(2, 12);
                }
                return valid ? `i[${decImm}]` : ``;
            }
            let srcStr = ($srcNum, $valid, $reg, $value) => { // $srcNum added for clarity
                return $valid.asBool(false)
                                ? `\n      ${regStr(true, $reg.asInt(NaN), $value.asInt(NaN))}` // Displaying xN format
                                : "";
            }
            let instrFullStr = `${regStr(rd_valid.asBool(false), rd.asInt(NaN), rf_wr_data.asInt(NaN))}\n` + // Use rf_wr_data for rd value
                               `  = ${mnemonic}${srcStr(1, rs1_valid, rs1, src1_value)}${srcStr(2, rs2_valid, rs2, src2_value)}\n` +
                               `      ${immStr(imm_valid.asBool(false), imm.asBinaryStr("0"))}`;
            let instrWithValues = new fabric.Text(instrFullStr, {
                top: 70, left: 65, fill: "blue", fontSize: 14, fontFamily: "monospace",
                visible: instr != sticky_zero
            })
            let fetch_instr_str = siggen(`instr_strs[${pc.asInt() >> 2}]`, `instr_strs[${pc.asInt() >> 2}]`, false).asString("(?) UNKNOWN").substr(4);
            let fetch_instr_viz = new fabric.Text(fetch_instr_str, {
                top: M4_IMEM_TOP + 18 * (pc.asInt() >> 2), left: -352 + 8 * 4, fill: "black",
                fontSize: 14, fontFamily: "monospace", visible: instr != sticky_zero
            })
            fetch_instr_viz.animate({top: 32, left: 10}, {
                onChange: this.global.canvas.renderAll.bind(this.global.canvas), duration: 500
            })
            let src1_value_viz = new fabric.Text(src1_value.asInt(0).toString(M4_VIZ_BASE), {
                left: 316 + 8 * 4, top: 18 * rs1.asInt(0) - 40, fill: "blue", fontSize: 14,
                fontFamily: "monospace", fontWeight: 800, visible: (src1_value != sticky_zero) && rs1_valid.asBool(false)
            })
            setTimeout(() => {src1_value_viz.animate({left: 166, top: 70 + 18 * 2}, {
                onChange: this.global.canvas.renderAll.bind(this.global.canvas), duration: 500
            })}, 500)
            let src2_value_viz = new fabric.Text(src2_value.asInt(0).toString(M4_VIZ_BASE), {
                left: 316 + 8 * 4, top: 18 * rs2.asInt(0) - 40, fill: "blue", fontSize: 14,
                fontFamily: "monospace", fontWeight: 800, visible: (src2_value != sticky_zero) && rs2_valid.asBool(false)
            })
            setTimeout(() => {src2_value_viz.animate({left: 166, top: 70 + 18 * 3}, {
                onChange: this.global.canvas.renderAll.bind(this.global.canvas), duration: 500
            })}, 500)
            let load_viz = new fabric.Text(ld_data.asInt(0).toString(M4_VIZ_BASE), { // ld_data is from DMEM
                left: 470 + 8*4, top: 18 * dmem_addr.asInt() - 40, fill: "blue", fontSize: 14,
                fontFamily: "monospace", fontWeight: 1000, visible: false
            })
            if (dmem_rd_en.asBool()) {
                setTimeout(() => {
                    load_viz.set({visible: true})
                    load_viz.animate({left: 146, top: 70}, { // Animate to rd field in decode
                        onChange: this.global.canvas.renderAll.bind(this.global.canvas), duration: 500
                    })
                    setTimeout(() => { load_viz.set({visible: false}) }, 500) // Disappear after animation
                }, 500) // Start after src reads
            }
            let store_viz = new fabric.Text(src2_value.asInt(0).toString(M4_VIZ_BASE), { // Data being stored is src2_value
                left: 166, top: 70 + 18 * 3, fill: "blue", fontSize: 14,
                fontFamily: "monospace", fontWeight: 1000, visible: false
            })
            if (dmem_wr_en.asBool()) {
                setTimeout(() => {
                    store_viz.set({visible: true})
                    store_viz.animate({left: 515, top: 18 * dmem_addr.asInt() - 40}, { // Animate from src2 to dmem
                        onChange: this.global.canvas.renderAll.bind(this.global.canvas), duration: 500
                    })
                     setTimeout(() => { store_viz.set({visible: false}) }, 500) // Disappear after animation
                }, 1000) // Start after ALU/result potentially
            }
            let result_shadow = new fabric.Text(result.asInt(0).toString(M4_VIZ_BASE), { // ALU result
                left: 146, top: 70, fill: "#b0b0df", fontSize: 14, fontFamily: "monospace",
                fontWeight: 800, visible: false
            })
            let result_viz = new fabric.Text(rf_wr_data.asInt(0).toString(M4_VIZ_BASE), { // Actual data written to RF (could be ALU or DMEM load)
                left: 146, top: 70, fill: "blue", fontSize: 14, fontFamily: "monospace",
                fontWeight: 800, visible: false
            })
            if (rd_valid.asBool() && rf_wr_en.asBool()) { // Check if rd is valid AND write is enabled
                setTimeout(() => {
                    result_viz.set({visible: rf_wr_data != sticky_zero})
                    result_shadow.set({visible: result != sticky_zero && result.asInt(0) !== rf_wr_data.asInt(0) }) // Show shadow if ALU result differs from RF write data (e.g. load)
                    result_viz.animate({left: 317 + 8 * 4, top: 18 * rf_wr_index.asInt(0) - 40}, {
                        onChange: this.global.canvas.renderAll.bind(this.global.canvas), duration: 500
                    })
                }, 1000)
            }
            this.getObjects().passed.set({visible: false})
            if (passed_sig && passed_sig.exists()) { // Check if passed_sig is valid
                if (passed_sig.step(-1).asBool()) { // Check previous cycle for stable pass
                    this.getObjects().passed.set({visible: true, text:"Passed !!!", fill: "green"})
                } else {
                    try {
                        passed_sig.goToSimEnd().step(-1)
                        if (passed_sig.asBool()) {
                            this.getObjects().passed.set({text:"Sim Passes", visible: true, fill: "lightgray"})
                        }
                    } catch(e) {}
                }
            }
            if (missing_list[0]) {
                this.getObjects().missing_sigs.set({visible: true})
                this.missing_col1.set({text: missing_list[0]})
                this.missing_col2.set({text: missing_list[1]})
            }
            return [pcPointer, pc_arrow, ...type_texts, rs1_arrow, rs2_arrow, rd_arrow, instrWithValues, 
                    fetch_instr_viz, src1_value_viz, src2_value_viz, result_shadow, result_viz, 
                    ld_arrow, st_arrow, load_viz, store_viz]
        }
        
    /imem[m4_eval(M4_NUM_INSTRS-1):0]
        \viz_js // Visualization for each instruction in IMem
            box: {width: 630, height: 18, strokeWidth: 0},
            init() {
                let binary = new fabric.Text("", {
                    top: 0, left: 0, fontSize: 14, fontFamily: "monospace",
                })
                let disassembled = new fabric.Text("", {
                    top: 0, left: 330, fontSize: 14, fontFamily: "monospace"
                })
                return {binary, disassembled}
            },
            onTraceData() { // Called once when trace data is available
                let instr = this.svSigRef(`instrs[${this.getIndex()}]`)
                if (!instr || !instr.exists()) { instr = this.svSigRef(`instrs(${this.getIndex()})`) } // Fallback for older Verilator
                if (instr && instr.exists()) {
                    let binary_str = instr.goToSimStart().asBinaryStr("").padEnd(32, '0'); // Ensure 32 bits
                    this.getObjects().binary.set({text: 
                        `${binary_str.substr(0,7)} ${binary_str.substr(7,5)} ${binary_str.substr(12,5)} ${binary_str.substr(17,3)} ${binary_str.substr(20,5)} ${binary_str.substr(25,7)}`
                    })
                }
                let disassembled_sig = this.svSigRef(`instr_strs[${this.getIndex()}]`)
                if (!disassembled_sig || !disassembled_sig.exists()) { disassembled_sig = this.svSigRef(`instr_strs(${this.getIndex()})`) } // Fallback
                if (disassembled_sig && disassembled_sig.exists()) {
                    let disassembled_str = disassembled_sig.goToSimStart().asString("").slice(0, -5) // Remove padding
                    this.getObjects().disassembled.set({text: disassembled_str})
                }
            },
            render() { // Called each cycle
                let reset = this.svSigRef(`L0_reset_a0`)
                let pc = this.svSigRef(`L0_pc_a0`)
                let rd_viz = pc && pc.exists() && !reset.asBool(false) && (pc.asInt() >> 2) == this.getIndex()
                this.getObjects().disassembled.set({textBackgroundColor: rd_viz ? "#b0ffff" : "white"})
                this.getObjects().binary.set({textBackgroundColor: rd_viz ? "#b0ffff" : "white"})
            },
            where: {left: -680, top: M4_IMEM_TOP}
            
\TLV tb() // Testbench pass/fail condition
    // Pass if x30 is 1 and PC is stuck (JAL x0, 0) and not in reset.
    $passed_cond = (/xreg[30]$value == 32'b1) &&
                   (! $reset && $next_pc[31:0] == $pc[31:0]);
    *passed = >>2$passed_cond; // Check for 2 stable cycles of pass_cond


// (A copy of this appears in the shell code.) - This sum_prog is now superseded by m4_test_prog
// \TLV sum_prog() ... (original sum_prog macro content removed for brevity as m4_test_prog is now the active one)
// ...
// ^===================================================================^

\SV
    m4_makerchip_module  // (Expanded in Nav-TLV pane.)
\TLV
    // This TLV block is for top-level connections or logic if any.
    // If risc-v_shell_lib.tlv is purely a library, this might be empty at this level.
\SV
    endmodule
```
