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

module rv3n_func_op
(
    input                               clk,
	input                               rst,

	input                               func_op_req_valid,
	input  `N(8)                        func_op_req_para,
	input  `N(13)                       func_op_req_imm,
	input  `N(`XLEN)                    func_op_req_pc,
	input  `N(`XLEN)                    func_op_req_operand0,
	input  `N(`XLEN)                    func_op_req_operand1,
	
    output                              func_op_ack_valid,
	output `N(`XLEN)                    func_op_ack_data,
	output                              func_op_ack_busy

);
    `include "include_func.v"

    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
	
	reg                                 out_valid;
	reg    `N(`XLEN)                    out_misc;
	reg    `N(`XLEN)                    out_sub;
	reg    `N(`XLEN)                    out_sll;
	reg    `N(`XLEN)                    out_srl;
	reg    `N(`XLEN)                    out_ari;    	
	

	
    //---------------------------------------------------------------------------
    //statements description
    //---------------------------------------------------------------------------	
	
	wire `N(`XLEN)              operand0 = func_op_req_operand0;
	wire `N(`XLEN)              operand1 = func_op_req_operand1;
	
	wire `N(`XLEN)              word_add = (func_op_req_para[6] ? func_op_req_pc : operand0) + operand1; 
	wire `N(`XLEN)             word_sltu = (operand0<operand1);	
	wire `N(`XLEN)              word_slt = (operand0[31]^operand1[31]) ? operand0[31] : word_sltu;
	wire `N(`XLEN)              word_xor = operand0 ^ operand1;
	wire `N(`XLEN)               word_or = operand0 | operand1;
	wire `N(`XLEN)              word_and = operand0 & operand1;

	wire `N(`XLEN)              word_sub = operand0 - operand1; 
    wire `N(`XLEN)              word_sll = operand0<<operand1[4:0];
	wire `N(`XLEN)              word_srl = operand0>>operand1[4:0];
	wire `N(`XLEN)              word_ari = {`XLEN{operand0[`XLEN-1]}}<<(6'd32-operand1[4:0]);
	
	reg  `N(`XLEN)              word_misc;
	
	always @(*) begin
	    word_misc = 0;
		case(func_op_req_para[2:0])
		3'd0 : word_misc = word_add;
		3'd1 : word_misc = word_slt;
		3'd2 : word_misc = word_sltu;
		3'd3 : word_misc = word_xor;
		3'd4 : word_misc = word_or;
		3'd5 : word_misc = word_and;
	    endcase
	end
	
	`FFx(out_valid,0)
	out_valid <= func_op_req_valid;
	
	`FFx(out_misc,0)
	out_misc <= word_misc & {`XLEN{(func_op_req_para[5:3]==3'b000)}};
	
	`FFx(out_sub,0)
	out_sub <= word_sub & {`XLEN{(func_op_req_para[5:3]==3'b001)}};
	
	`FFx(out_sll,0)
	out_sll <= word_sll & {`XLEN{(func_op_req_para[5:3]==3'b010)}};
	
	`FFx(out_srl,0)
	out_srl <= word_srl & {`XLEN{(func_op_req_para[5:3]==3'b011)|(func_op_req_para[5:3]==3'b100)}};
	
	`FFx(out_ari,0)
	out_ari <= word_ari & {`XLEN{(func_op_req_para[5:3]==3'b100)}};
	
	wire  `N(`XLEN)   out_final = out_misc|out_sub|out_sll|out_srl|out_ari;
	
	assign         func_op_ack_valid = out_valid;
	assign          func_op_ack_data = out_final;
	assign          func_op_ack_busy = 0;
	
endmodule
