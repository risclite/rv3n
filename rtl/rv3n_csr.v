/////////////////////////////////////////////////////////////////////////////////////
//
//Copyright 2020  Li Xinbing
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.
//
/////////////////////////////////////////////////////////////////////////////////////


`include "define.v"

module rv3n_csr
(   
    input                               clk,
	input                               rst,
	
	input                               func_csr_req_valid,
	input  `N(8)                        func_csr_req_para,
	input  `N(13)                       func_csr_req_imm,
	input  `N(`XLEN)                    func_csr_req_pc,
	input  `N(`XLEN)                    func_csr_req_operand0,
	input  `N(`XLEN)                    func_csr_req_operand1,
	
    output                              func_csr_ack_valid,
	output `N(`XLEN)                    func_csr_ack_data,
	output                              func_csr_ack_busy,	

    input                               jump_jcond_valid,
    input  `N(`XLEN)                    jump_jcond_pc,	

    output                              jump_valid,
    output `N(`XLEN)                    jump_pc,
    output                              stage_id_clear

);

	localparam ADDR_MHARTID   = 12'hf14,
	           ADDR_MTVEC     = 12'h305,
			   ADDR_MSCRATCH  = 12'h340,
			   ADDR_MEPC      = 12'h341,
			   ADDR_MCAUSE    = 12'h342,
			   ADDR_MCYCLE    = 12'hc00,
			   ADDR_MTIME     = 12'hc01,
			   ADDR_MCYCLEH   = 12'hc80
			   ;
	
	localparam DATA_MHARTID   = 32'h0,
	           DATA_MCAUSE    = 11
			   ;



    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
	reg                             jump_root_valid;
	reg  `N(`XLEN)                  jump_root_pc;	
  
  
    //---------------------------------------------------------------------------
    //statements description
    //---------------------------------------------------------------------------

    //////////////////////////////////////////////////////////////////////////////////////
    //jump & clear
    //////////////////////////////////////////////////////////////////////////////////////	
    
	assign                            jump_valid = jump_root_valid|jump_jcond_valid;
	assign                               jump_pc = jump_root_valid ? jump_root_pc : jump_jcond_pc;

    assign                        stage_id_clear = jump_root_valid|jump_jcond_valid;
 
    //////////////////////////////////////////////////////////////////////////////////////
    //csr
    //////////////////////////////////////////////////////////////////////////////////////	
	reg  `N(`XLEN)     data_mtvec;
	reg  `N(`XLEN)     data_mscratch;
	reg  `N(`XLEN)     data_mepc;	
    reg  `N(2*`XLEN)   mcycle;	
	reg  `N(7)         mtime_cnt;
	reg  `N(2*`XLEN)   mtime;	
	
	//command level

	
	wire                       command_csr_valid = func_csr_req_valid & func_csr_req_para[4];
    wire `N(5)                    command_csr_rd = func_csr_req_operand1>>7;
    wire `N(3)                  command_csr_func = func_csr_req_operand1>>(7+5);
    wire `N(5)                   command_csr_imm = func_csr_req_operand1>>(7+5+3);
    wire `N(12)                 command_csr_addr = func_csr_req_operand1>>(7+5+3+5);
 	
    reg  `N(`XLEN)           command_csr_rdata;

    always @* begin
	    command_csr_rdata = 0;
		case(command_csr_addr)
	    ADDR_MHARTID   : command_csr_rdata = DATA_MHARTID;
	    ADDR_MTVEC     : command_csr_rdata = data_mtvec;
		ADDR_MSCRATCH  : command_csr_rdata = data_mscratch;
	    ADDR_MEPC      : command_csr_rdata = data_mepc;
        ADDR_MCAUSE    : command_csr_rdata = DATA_MCAUSE;
	    ADDR_MCYCLE    : command_csr_rdata = mcycle[`XLEN-1:0];
        ADDR_MTIME     : command_csr_rdata = mtime[31:0];
	    ADDR_MCYCLEH   : command_csr_rdata = mcycle>>`XLEN;
        endcase
    end	
	
	//write level
	reg             write_csr_valid;
	reg `N(2)       write_csr_func;
	reg `N(12)      write_csr_addr;
	reg `N(`XLEN)   write_csr_raw;
	reg `N(`XLEN)   write_csr_operand;
	
	`FFx(write_csr_valid,0)   write_csr_valid <= command_csr_valid;
	`FFx(write_csr_func,0)    write_csr_func <= command_csr_func;
	`FFx(write_csr_addr,0)    write_csr_addr <= command_csr_addr;
	`FFx(write_csr_raw,0)     if ( command_csr_valid ) write_csr_raw <= command_csr_rdata; else write_csr_raw <= 0;
	`FFx(write_csr_operand,0) write_csr_operand <= command_csr_func[2] ? command_csr_imm : func_csr_req_operand0;
	
	reg `N(`XLEN)  write_csr_wdata;
	always @* begin
	    case(write_csr_func)
		2'd1   : write_csr_wdata =  write_csr_operand;
		2'd2   : write_csr_wdata =  write_csr_operand | write_csr_raw;
		2'd3   : write_csr_wdata = ~write_csr_operand & write_csr_raw;
		default: write_csr_wdata = write_csr_operand;
		endcase
	end
	
    `FFx(data_mscratch,0)
	if ( write_csr_valid & (write_csr_addr==ADDR_MSCRATCH) )
	    data_mscratch <= write_csr_wdata;
	else;	

	`FFx(data_mtvec,0)
	if ( write_csr_valid & (write_csr_addr==ADDR_MTVEC) )
	    data_mtvec <= write_csr_wdata;
	else;
	
	`FFx(data_mepc,0)
	if ( write_csr_valid & (write_csr_addr==ADDR_MEPC) )
	    data_mepc <= write_csr_wdata;
	else;

    `FFx(mcycle,0)
    mcycle <= mcycle + 1'b1;	

	`FFx(mtime_cnt,0)
	if ( mtime_cnt==99 )
	    mtime_cnt <= 0;
	else 
	    mtime_cnt <= mtime_cnt + 1'b1;
	
	`FFx(mtime,0)
	if ( mtime_cnt==99 )
	    mtime <= mtime + 1;
	else;

    //////////////////////////////////////////////////////////////////////////////////////
    //system
    //////////////////////////////////////////////////////////////////////////////////////	

    wire             sys_vld = func_csr_req_valid & func_csr_req_para[5];
	wire `N(`XLEN) sys_instr = func_csr_req_operand1;
    wire `N(3)      sys_para = func_csr_req_para;
    wire `N(`XLEN)    sys_pc = func_csr_req_pc;	

	wire instr_is_ret     = sys_vld & ((sys_para>>1)==0) & ( (sys_instr[31:0]==32'b0000000_00010_00000_000_00000_1110011)|(sys_instr[31:0]==32'b0001000_00010_00000_000_00000_1110011)|(sys_instr[31:0]==32'b0011000_00010_00000_000_00000_1110011) );
	wire instr_is_ecall   = sys_vld & ((sys_para>>1)==0) & (sys_instr[31:0]==32'b0000000_00000_00000_000_00000_1110011);
	wire instr_is_fencei  = sys_vld & ((sys_para>>1)==0) & (sys_instr[31:0]==32'b0000000_00000_00000_001_00000_0001111);
	wire instr_is_illegal = sys_vld & ((sys_para>>1)!=0); 
	

    localparam START_ADDR = 32'h200;

    reg `N(`XLEN) root_pc;
	always @* begin
	    root_pc = 0;
	    case(1'b1)
	    instr_is_ret    : root_pc = data_mepc;
	    instr_is_ecall  : root_pc = data_mtvec;
	    instr_is_fencei : root_pc = sys_pc + 4;
		instr_is_illegal: root_pc = data_mtvec;
		default         : root_pc = data_mtvec;
	    endcase
	end

    `FFx(jump_root_valid,1)
	jump_root_valid <= sys_vld;
	
	`FFx(jump_root_pc,START_ADDR)
	jump_root_pc <= root_pc;
	
	reg  func_csr_delay;
	`FFx(func_csr_delay,0)
	func_csr_delay <= write_csr_valid|jump_root_valid;
	
	reg `N(`XLEN) func_csr_out;
	`FFx(func_csr_out,0)
	if ( write_csr_valid )
	    func_csr_out <= write_csr_raw;
	else 
	    func_csr_out <= 0;
	
	assign   func_csr_ack_valid = func_csr_delay;
    assign    func_csr_ack_data = func_csr_out;
	assign    func_csr_ack_busy = write_csr_valid|jump_root_valid;

endmodule


