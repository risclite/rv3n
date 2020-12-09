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

module rv3n_func_jcond
(
    input                               clk,
	input                               rst,

	input                               func_jcond_req_valid,
	input  `N(8)                        func_jcond_req_para,
	input  `N(13)                       func_jcond_req_imm,
	input  `N(`XLEN)                    func_jcond_req_pc,
	input  `N(`XLEN)                    func_jcond_req_operand0,
	input  `N(`XLEN)                    func_jcond_req_operand1,
	
    output                              func_jcond_ack_valid,
	output `N(`XLEN)                    func_jcond_ack_data,
	output                              func_jcond_ack_busy,
	
    output                              ch2predictor_valid,
	output `N(`XLEN)                    ch2predictor_pc,
    output                              ch2predictor_predict,
	output                              ch2predictor_taken,	
	
	output                              jump_jcond_valid,
	output `N(`XLEN)                    jump_jcond_pc

);

    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
	


	
    //---------------------------------------------------------------------------
    //statements description
    //---------------------------------------------------------------------------	
	wire `N(3)  jcond_sel = func_jcond_req_para;	
	wire       jcond_jalr = func_jcond_req_para>>6;
	wire    jcond_predict = func_jcond_req_para>>7;

	wire         jcond_eq = func_jcond_req_operand0==func_jcond_req_operand1;
	wire        jcond_ltu = func_jcond_req_operand0 <func_jcond_req_operand1;
	wire         jcond_lt = (func_jcond_req_operand0[31]^func_jcond_req_operand1[31]) ? func_jcond_req_operand0[31] : jcond_ltu; 
	
	reg  jcond_taken;
	always @(*) begin
	    jcond_taken  = 0;
		case(jcond_sel[2:0])
		3'd0 : jcond_taken =  jcond_eq;
		3'd1 : jcond_taken = ~jcond_eq;
		3'd2 : jcond_taken =  jcond_lt;
		3'd3 : jcond_taken = ~jcond_lt;
		3'd4 : jcond_taken =  jcond_ltu;
		3'd5 : jcond_taken = ~jcond_ltu;
	    endcase
	end	
	

    reg             jcond_break_valid;
	reg             jcond_break_jalr;
	reg             jcond_break_predict;
	reg             jcond_break_taken;
	reg `N(`XLEN)   jcond_break_pc;
	
	`FFx(jcond_break_valid,0)
	jcond_break_valid <= func_jcond_req_valid;

    `FFx(jcond_break_jalr,0)
	jcond_break_jalr <= jcond_jalr;
	
	`FFx(jcond_break_predict,0)
	jcond_break_predict <= jcond_predict;
	
	`FFx(jcond_break_taken,0)
	jcond_break_taken <= jcond_taken;
	
	`FFx(jcond_break_pc,0)
	jcond_break_pc <= (jcond_jalr ? func_jcond_req_operand0 : func_jcond_req_pc) + { {19{func_jcond_req_imm[12]}},func_jcond_req_imm }; 

    assign    jump_jcond_valid = jcond_break_valid & ( jcond_break_jalr|(jcond_break_predict!=jcond_break_taken) );
    assign       jump_jcond_pc = jcond_break_pc; 


    reg     jcond_ack_signal;
	`FFx(jcond_ack_signal,0)
	jcond_ack_signal <= func_jcond_req_valid;
	
	assign func_jcond_ack_valid = jcond_ack_signal;
	assign  func_jcond_ack_data = 0;
	assign  func_jcond_ack_busy = 0;
	
	reg `N(`XLEN) pdt_pc;
	`FFx(pdt_pc,0)
	pdt_pc <= func_jcond_req_pc;
	
	
	assign   ch2predictor_valid = jcond_ack_signal;
    assign      ch2predictor_pc = pdt_pc;
    assign ch2predictor_predict = jcond_break_predict;
    assign   ch2predictor_taken = jcond_break_taken; 	
	
endmodule
