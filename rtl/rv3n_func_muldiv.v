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

module rv3n_func_muldiv
(   
    input                               clk,
	input                               rst,
	
	input                               func_muldiv_req_valid,
	input  `N(8)                        func_muldiv_req_para,
	input  `N(13)                       func_muldiv_req_imm,
	input  `N(`XLEN)                    func_muldiv_req_pc,
	input  `N(`XLEN)                    func_muldiv_req_operand0,
	input  `N(`XLEN)                    func_muldiv_req_operand1,
	
    output                              func_muldiv_ack_valid,
	output `N(`XLEN)                    func_muldiv_ack_data,
	output                              func_muldiv_ack_busy
	
);

`ifdef RV32M

    //---------------------------------------------------------------------------
    //function defination
    //---------------------------------------------------------------------------
	
	function `N($clog2(`XLEN)) position_of_highest_one(input `N(`XLEN) d);
	    integer i;
	    begin
	        position_of_highest_one = 0;
	        for (i=0;i<`XLEN;i=i+1)
	    	    if ( d[i] )
	                position_of_highest_one = i;
	    end
	endfunction

    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
    reg    `N(`XLEN)                    idle_operand0;
	reg    `N(`XLEN)                    idle_operand1;	
	
	reg                                 global_div;
	reg                                 global_out_sel;
	reg                                 global_out_sign;
	reg                                 global_divisor_zero;
	
	reg    `N(`XLEN)                    calc_a;
	reg    `N(2*`XLEN)                  calc_b;
	reg    `N(2*`XLEN)                  calc_x;
	reg    `N($clog2(`XLEN))            calc_mul_carry;
	reg    `N($clog2(`XLEN))            calc_count;
	
	wire   `N(`XLEN)                    div_rem;	
    wire                                div_bigger;
	wire                                div_leave;
	
	wire   `N(2*`XLEN)                  mul_x;
	wire                                mul_ca_in;
	wire                                mul_leave;
	
	wire                                calc_leave;

    localparam      IDLE     = 0,
	                POS      = 1,
					DIFF     = 2,
					SHIFT    = 3,
					LOAD     = 4,
                    CALC     = 5,
					CARRY    = 6,
					SIGN     = 7,
					STATENUM = 8;
					   
	reg    `N(STATENUM)                 current_state;
	reg    `N(STATENUM)                 next_state;
	
    //---------------------------------------------------------------------------
    //statements description
    //---------------------------------------------------------------------------

    wire                                     func_muldiv_valid = func_muldiv_req_valid;

    //main state machine
    `FFx(current_state,1'b1<<IDLE)
	current_state <= next_state;
	
	always @* begin
	    next_state = current_state;
	    case(1'b1)
		current_state[IDLE] : begin //incoming operands.
		                    if ( func_muldiv_valid )
		                        next_state = func_muldiv_req_para[2] ? (1'b1<<POS) : (1'b1<<LOAD);
		                end
		current_state[POS] : begin
		                    next_state = 1'b1<<DIFF;
		                end						
		current_state[DIFF] : begin
		                    next_state = 1'b1<<SHIFT;
		                end	
		current_state[SHIFT] : begin
		                    next_state = 1'b1<<LOAD;
		                end							
		current_state[LOAD] : begin
		                    next_state = global_divisor_zero ? (1'b1<<SIGN) : (1'b1<<CALC);
		                end
		current_state[CALC] : begin//to shift & add
		                    if ( calc_leave )
							    next_state = (~global_div & global_out_sel) ?  (1'b1<<CARRY) : (1'b1<<SIGN); 
		                end
		current_state[CARRY] : begin// to add carry of the high part of the product.
		                    next_state = 1'b1<<SIGN;
		               end
		current_state[SIGN] : begin//to do "~x+1"
		                    next_state = 1'b1<<IDLE;
		               end					   
		endcase
	end	

    //operand0 & operand1
    wire                                        mul_sign_a = (func_muldiv_req_para[1:0]!=2'b11) & func_muldiv_req_operand0[`XLEN-1];
    wire                                        mul_sign_b = ~func_muldiv_req_para[1] & func_muldiv_req_operand1[`XLEN-1];
    wire                                        div_sign_a = ~func_muldiv_req_para[0] & func_muldiv_req_operand0[`XLEN-1];
    wire                                        div_sign_b = ~func_muldiv_req_para[0] & func_muldiv_req_operand1[`XLEN-1];

    wire                                     operand0_sign = func_muldiv_req_para[2] ? div_sign_a : mul_sign_a;
	wire                                     operand1_sign = func_muldiv_req_para[2] ? div_sign_b : mul_sign_b;
	
	wire `N(`XLEN)                       incoming_operand0 = operand0_sign ? ( ~func_muldiv_req_operand0 + 1'b1 ) : func_muldiv_req_operand0;
	wire `N(`XLEN)                       incoming_operand1 = operand1_sign ? ( ~func_muldiv_req_operand1 + 1'b1 ) : func_muldiv_req_operand1;         
	
	`FFx(idle_operand0,0)                   
	if ( current_state[IDLE] )	
	    idle_operand0 <= incoming_operand0;
	else;
	
	`FFx(idle_operand1,0)
	if ( current_state[IDLE] )
	    idle_operand1 <= incoming_operand1;
	else;
    
    //global parameter
    wire                                       mul_out_sel = func_muldiv_req_para[1:0]!=0;      //1---high part; 0---low part;
	wire                                      mul_out_sign = mul_sign_a ^ mul_sign_b;   //1---need "~x+1"; 0---do not need
	wire                                       div_out_sel = func_muldiv_req_para[1];           //1---remainder; 0---quotient
    wire                                      div_out_sign = func_muldiv_req_para[1] ? div_sign_a : (div_sign_a ^ div_sign_b); //1---need "~x+1"; 0---do not need

    `FFx(global_div,0)  
	if ( current_state[IDLE] ) 
	    global_div <= func_muldiv_req_para[2];
    else;
	
	`FFx(global_out_sel,0)
	if ( current_state[IDLE] )
	    global_out_sel <= func_muldiv_req_para[2] ? div_out_sel : mul_out_sel;
	else;
	
	`FFx(global_out_sign,0)
	if ( current_state[IDLE] )
	    global_out_sign <= func_muldiv_req_para[2] ? div_out_sign : mul_out_sign;
	else;	

    `FFx(global_divisor_zero,0)
    if ( current_state[IDLE] )
        global_divisor_zero <= func_muldiv_req_para[2] ? (func_muldiv_req_operand1==0) : 0;
    else;

    //position
	reg `N($clog2(`XLEN)) position_a,position_b;
    `FFx(position_a,0)    position_a <= position_of_highest_one(idle_operand0);
    `FFx(position_b,0)    position_b <= position_of_highest_one(idle_operand1);
	
	//diff
    reg `N($clog2(`XLEN)) position_diff; 
	`FFx(position_diff,0)  
	if ( current_state[DIFF] )
	    position_diff <= ( position_a<position_b) ? 0 : (position_a-position_b);
	else;
	
	//shift
	reg `N(`XLEN) shift_operand1;
	`FFx(shift_operand1,0)   shift_operand1 <= idle_operand1<<position_diff;
	
	//calculation
    `FFx(calc_a,0)
	if ( current_state[LOAD] )
	    calc_a <= idle_operand0;
	else if ( current_state[CALC] )
	    if ( global_div )
		    calc_a <= div_bigger ? div_rem : calc_a;
		else
		    calc_a <= calc_a>>1;
	else;
	
	`FFx(calc_b,0)
	if ( current_state[LOAD] )
	    calc_b <= global_div ? shift_operand1 : idle_operand1;
	else if ( current_state[CALC] ) 
	    calc_b <= global_div ? (calc_b>>1) : (calc_b<<1);
	else;
	
	`FFx(calc_x,0)
	if ( current_state[LOAD] )
	    calc_x <= 0;
	else if ( current_state[CALC] )
	    if ( global_div )
		    calc_x[`XLEN-1:0] <= (calc_x[`XLEN-1:0]<<1)|div_bigger;
		else
		    calc_x <= calc_a[0] ? mul_x : calc_x;	    
	else;
	
	`FFx(calc_mul_carry,0)
	if ( current_state[LOAD] )
	    calc_mul_carry <= 0;
	else if ( current_state[CALC] )
        calc_mul_carry <= calc_mul_carry + (calc_a[0] & mul_ca_in);		
	else;

	`FFx(calc_count,0)
	if ( current_state[LOAD] )
	    calc_count <= position_diff;
	else if ( current_state[CALC] )
	    calc_count <= (calc_count==0) ? calc_count : ( calc_count - 1'b1 );
    else;		


	wire `N(`XLEN+1)                         mul_adder_low = calc_x[`XLEN-1:0] + calc_b[`XLEN-1:0];
    wire `N(`XLEN)                          mul_adder_high = (calc_x>>`XLEN) + (calc_b>>`XLEN);
    wire `N(`XLEN+1)                             div_suber = calc_a - calc_b[`XLEN-1:0];

    assign                                         div_rem = div_suber;
    assign                                      div_bigger = ~div_suber[`XLEN];
    assign                                       div_leave = (calc_count==0);
	
	assign                                           mul_x = { mul_adder_high,mul_adder_low[`XLEN-1:0] };
    assign                                       mul_ca_in = mul_adder_low[`XLEN];
	assign                                       mul_leave = calc_a==0;

    assign                                      calc_leave = global_div ? div_leave : mul_leave;
    
	//carry
    reg `N(`XLEN)  mul_high_with_carry;
    `FFx(mul_high_with_carry,0)
    mul_high_with_carry <= (calc_x>>`XLEN) + calc_mul_carry;

    reg            mul_low_is_zero;
	`FFx(mul_low_is_zero,0)
	mul_low_is_zero <= (calc_x[`XLEN-1:0]==0);

    //sign
    reg `N(`XLEN)  md_candidate;
	always @* begin
	    case({global_div,global_out_sel})
	    2'h0 : md_candidate = calc_x;
		2'h1 : md_candidate = mul_high_with_carry;
	    2'h2 : md_candidate = calc_x;
		2'h3 : md_candidate = calc_a;
		endcase
	end
	
	wire       md_sign_one_bit = ({global_div,global_out_sel}==2'b01) ? mul_low_is_zero : 1'b1;

    reg `N(`XLEN) md_sign_out;
    `FFx(md_sign_out,0)
    md_sign_out <= global_out_sign ? ( ~md_candidate + md_sign_one_bit ) : md_candidate;	
	
	//output
	
	wire `N(`XLEN)                                  md_out = (global_divisor_zero & ~global_out_sel) ? 32'hFFFF_FFFF : md_sign_out;
	
	reg                  out_over;
	`FFx(out_over,0)
	out_over <= current_state[SIGN];

    assign            func_muldiv_ack_valid = out_over;
	assign             func_muldiv_ack_data = out_over ? md_out : 0;
    assign             func_muldiv_ack_busy = ~current_state[IDLE];

`else
    assign            func_muldiv_ack_valid = 0;
	assign             func_muldiv_ack_data = 0;
    assign             func_muldiv_ack_busy = 0;

`endif

endmodule
