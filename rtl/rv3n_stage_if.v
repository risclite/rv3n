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
module rv3n_stage_if
(   
    input                           clk,
	input                           rst,

    output                          imem_req,
	output `N(`XLEN)                imem_addr,
	input                           imem_resp,
	input  `N(`INUM*`XLEN)          imem_rdata,
	input                           imem_err,
	input  `N(`INUM*2)              imem_predict,

    input                           dc2if_new_valid,
	input  `N(`XLEN)                dc2if_new_pc,
	input                           dc2if_continue,
	
	output                          if2dc_valid,
	output `N(`INUM*`XLEN)          if2dc_rdata,
	output                          if2dc_err,
	output `N(`INUM*2)              if2dc_predict

);

    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
	reg `N(`XLEN)   pc;	
	reg             req_sent;
	reg             instr_verified;
	
    //---------------------------------------------------------------------------
    //statements description
    //---------------------------------------------------------------------------

    wire `N(`XLEN)         dc2if_masked_pc = dc2if_new_pc & ( {`XLEN{1'b1}}<<(2+$clog2(`INUM)) );

    wire                        request_go = dc2if_continue|dc2if_new_valid;	

	`FFx(pc,0)
    if ( imem_req )
	    pc <= imem_addr + (4*`INUM);
	else if ( dc2if_new_valid )
	    pc <= dc2if_masked_pc;
	else;

	wire   `N(`XLEN)            fetch_addr = dc2if_new_valid ? dc2if_masked_pc : pc;
	
	`FFx(instr_verified,0)
    if ( imem_req )
	    instr_verified <= 1;
	else if ( imem_resp|dc2if_new_valid )
	    instr_verified <= 0;
	else;	
	

	`FFx(req_sent,0)
	if ( ~req_sent|imem_resp )
	    req_sent <= request_go;
	else;

    assign                        imem_req = request_go & ( ~req_sent|imem_resp );			
	assign                       imem_addr = fetch_addr;		
	
	assign                     if2dc_valid = instr_verified & imem_resp;
	assign                     if2dc_rdata = imem_rdata;
	assign                       if2dc_err = imem_err;
	assign                   if2dc_predict = imem_predict; 

endmodule


