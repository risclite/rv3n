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

module rv3n_func_lsu
(
    input                               clk,
	input                               rst,
	
    input                               func_lsu_req_valid,
	input  `N(8)                        func_lsu_req_para,
	input  `N(13)                       func_lsu_req_imm,
    input  `N(`XLEN)                    func_lsu_req_pc,	
	input  `N(`XLEN)                    func_lsu_req_operand0,
	input  `N(`XLEN)                    func_lsu_req_operand1,
	
	output                              func_lsu_ack_valid,
	output `N(`XLEN)                    func_lsu_ack_data,
	output                              func_lsu_ack_busy,
	output `N(`XLEN)                    func_lsu_shortcut_data,
	
	output                              dmem_req,
	output                              dmem_cmd,
	output `N(2)                        dmem_width,
	output `N(`XLEN)                    dmem_addr,
	output `N(`XLEN)                    dmem_wdata,
	input  `N(`XLEN)                    dmem_rdata,
	input                               dmem_resp,
    input                               dmem_err		
	
	
);

    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
    reg                                 req_sent;
    reg  `N(4)                          req_para;	


    //---------------------------------------------------------------------------
    //statements description
    //---------------------------------------------------------------------------	
	wire               active_valid = func_lsu_req_valid & (func_lsu_req_para[5:4]==0);
	wire `N(4)          active_para = func_lsu_req_para;
	wire `N(`XLEN)      active_addr = func_lsu_req_operand0 + { {19{func_lsu_req_imm[12]}},func_lsu_req_imm };
	wire `N(`XLEN)     active_wdata = func_lsu_req_operand1;

	//dmem request
	assign                dmem_req = active_valid & (~req_sent|dmem_resp);
	assign                dmem_cmd = active_para>>3;
	assign              dmem_width = active_para;
	assign               dmem_addr = active_addr & ( {`XLEN{1'b1}}<<dmem_width );
    assign              dmem_wdata = active_wdata;

	`FFx(req_sent,1'b0)
	if ( ~req_sent|dmem_resp )
	    req_sent <= dmem_req;
	else;
	
    `FFx(req_para,0)
	if ( ~req_sent|dmem_resp )
	    req_para <= active_para;
	else;
	
	wire `N(`XLEN)   unsigned_word = req_para[0] ? dmem_rdata[15:0] : dmem_rdata[7:0];
	wire `N(`XLEN)     signed_word = req_para[0] ? { {16{dmem_rdata[15]}},dmem_rdata[15:0] } : { {24{dmem_rdata[7]}},dmem_rdata[7:0] };
	wire `N(`XLEN)        get_word = req_para[2] ? unsigned_word : ( req_para[1] ? dmem_rdata : signed_word );
	wire `N(`XLEN)        out_word = req_para[3] ? 0 : get_word;
	
	wire `N(`XLEN)     memory_data = out_word;
	wire                memory_err = dmem_err;
	

    assign      func_lsu_ack_valid = req_sent & dmem_resp;
    assign       func_lsu_ack_data = func_lsu_ack_valid ? memory_data : 0;	
    assign       func_lsu_ack_busy = ~( ~req_sent | dmem_resp );
	assign  func_lsu_shortcut_data = req_para[1] ? dmem_rdata : { {16{dmem_rdata[15]}},dmem_rdata[15:0] };

endmodule
