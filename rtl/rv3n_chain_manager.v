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

module rv3n_chain_manager
(
    input                                   clk,
	input                                   rst,

	output                                  chain_step,
	output `N(`PNUM*`RGBIT)                 ch2gsr_order,	
	input  `N(`CHATT_LEN)                   chain_attributes,
	
	output `N(`PIPE_LEN*`FUNC_NUM)          chain_authorized,
	output `N(`PIPE_LEN*`XLEN)              chain_rs0_feed_data,
	output `N(`PIPE_LEN*`XLEN)              chain_rs1_feed_data,
	output `N(`PIPE_LEN*`XLEN)              chain_rd_feed_data,
	output `N(`PIPE_LEN)                    chain_rd_lookup_valid,
	output `N(`PIPE_LEN*`RGBIT)             chain_rd_lookup_order,
	
	input  `N(`CHAIN_LEN*`FUNC_NUM*8)       sub_calc_para,
	input  `N(`CHAIN_LEN*`FUNC_NUM*13)      sub_calc_imm,
	input  `N(`CHAIN_LEN*`FUNC_NUM*`XLEN)   sub_calc_pc,
	input  `N(`CHAIN_LEN*`FUNC_NUM*`XLEN)   sub_calc_operand0,	
	input  `N(`CHAIN_LEN*`FUNC_NUM*`XLEN)   sub_calc_operand1,

    output `N(`FUNC_NUM)                    func_calc_req_valid,
	output `N(`FUNC_NUM*8)                  func_calc_req_para,
	output `N(`FUNC_NUM*13)                 func_calc_req_imm,
	output `N(`FUNC_NUM*`XLEN)              func_calc_req_pc,
	output `N(`FUNC_NUM*`XLEN)              func_calc_req_operand0,
	output `N(`FUNC_NUM*`XLEN)              func_calc_req_operand1,
	input  `N(`FUNC_NUM)                    func_calc_ack_valid,
	input  `N(`FUNC_NUM*`XLEN)              func_calc_ack_data,
	input  `N(`FUNC_NUM)                    func_calc_ack_busy,
	
    input  `N(`FWR_NUM*`XLEN)               forward_source_data,
    input                                   jump_jcond_valid	

);

    //---------------------------------------------------------------------------
    //function defination
    //---------------------------------------------------------------------------

    function `N(`PIPE_LEN*`RGBIT) conversion_lookup_order( input `N(`PIPE_LEN*`RGBIT) order, input `N(`PIPE_LEN) valid );
	    reg `N(`RGBIT)            current_order;
		reg                       current_valid;
		reg                       current_hit;
		reg `N(`PIPE_LEN*`RGBIT)  out_order;
		integer                   i,j;
	    begin
		    for ( i=0;i<`PIPE_LEN;i=i+1) begin
			    current_order = order[`IDX(i,`RGBIT)];
				current_valid = valid[i];
				current_hit   = 0;
				for (j=0;j<i;j=j+1) begin
				    current_hit = current_hit|(valid[j] & (current_order==order[`IDX(j,`RGBIT)]));
				end
				out_order[`IDX(i,`RGBIT)] = ( current_valid & ~current_hit ) ? current_order : 0;
			end
			conversion_lookup_order = out_order;
		end
	endfunction	

	//  001011001  -> 111000000 : The first higheset 1 masks the others.
    function `N(`PIPE_LEN)    conversion_maskrest(input `N(`PIPE_LEN) array);
	    reg                   valid_bit;
		reg  `N(`PIPE_LEN)    out_bits; 
		integer i;
		begin
		    valid_bit                    = 1;
			for (i=0;i<`PIPE_LEN;i=i+1) begin
		        out_bits[`PIPE_LEN-1-i]  = valid_bit;
                valid_bit                = valid_bit & ~array[`PIPE_LEN-1-i];				
		    end
			conversion_maskrest          = out_bits;
		end
	endfunction

    //  001011001  -> 001000000 : Only the first 1 exists.
    function `N(`PIPE_LEN)    conversion_onehot(input `N(`PIPE_LEN) array);
	    reg                   valid_flag;
		reg  `N(`PIPE_LEN)    out_bits; 
		integer i;
		begin
		    valid_flag   = 1;
			for (i=0;i<`PIPE_LEN;i=i+1) begin
		        out_bits[`PIPE_LEN-1-i]  = valid_flag &  array[`PIPE_LEN-1-i];
                valid_flag               = valid_flag << array[`PIPE_LEN-1-i];				
		    end
			conversion_onehot            = out_bits;
		end
	endfunction
	
	function `N(`PIPE_LEN)  conversion_jcond(  input `N(`PIPE_LEN) jcond_array,
	                                           input `N(`PIPE_LEN) jcond_available
											   );
		reg                    valid_flag;
		reg                    first_flag;
		reg  `N(`PIPE_LEN)     out_bits;
		integer                i;
		begin
		    valid_flag = 1;
			first_flag = 1;
		    for (i=0;i<`PIPE_LEN;i=i+1) begin
			    out_bits[`PIPE_LEN-1-i] = valid_flag;			    
			    if ( jcond_array[`PIPE_LEN-1-i] ) begin
					valid_flag = first_flag & jcond_available[`PIPE_LEN-1-i];
			        first_flag = 0; 
			    end
			end
			conversion_jcond = out_bits;
		end
	endfunction	

    function `N(`PIPE_LEN*`OP_NUM) conversion_op (   input `N(`PIPE_LEN)  array );
	    reg  `N(`OP_NUM)             op_flag;
		reg  `N(`OP_NUM)             op_bits;
		reg  `N(`PIPE_LEN*`OP_NUM)   out_bits;
		integer            i,j;
		begin
		    op_flag = 1'b1;
			for (i=0;i<`PIPE_LEN;i=i+1) begin
			    op_bits = op_flag & {`OP_NUM{array[`PIPE_LEN-1-i]}};
				for ( j=0;j<`OP_NUM;j=j+1) begin
				    out_bits[j*`PIPE_LEN+`PIPE_LEN-1-i] = op_bits[j];
				end
				op_flag = op_flag<<array[`PIPE_LEN-1-i];
			end
			conversion_op = out_bits;
		end
	endfunction

    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
    reg    `N(`PIPE_LEN)                    jcond_maskbits;	
	
    wire   `N(`PNUM)                        in_valid;
	wire   `N(`PNUM)                        in_clu;
	wire   `N(`PNUM)                        in_muldiv;
	wire   `N(`PNUM)                        in_jcond;
	wire   `N(`PNUM)                        in_op;
	wire   `N(`PNUM)                        in_rs0_valid;
	wire   `N(`INMAP_LEN)                   in_rs0_map;
	wire   `N(`PNUM)                        in_rs1_valid;
	wire   `N(`INMAP_LEN)                   in_rs1_map;
	wire   `N(`PNUM)                        in_rd_ld_bypass;
	wire   `N(`PNUM*`RGBIT)                 in_rd_order;

    wire   `N(`PIPE_LEN)                    status_masked_clu;
    wire   `N(`PIPE_LEN)                    status_masked_muldiv;
    wire   `N(`PIPE_LEN)                    status_masked_jcond;
    wire   `N(`PIPE_LEN)                    status_masked_op;

	reg    `N(`PIPE_LEN)                    status_valid;
	reg    `N(`PIPE_LEN)                    status_clu;
	reg    `N(`PIPE_LEN)                    status_muldiv;
	reg    `N(`PIPE_LEN)                    status_jcond;
	reg    `N(`PIPE_LEN)                    status_op;	

	wire   `N(`PIPE_LEN)                    ban_jump;

	wire   `N(`PIPE_LEN)                    status_added_rs0_valid;
	wire   `N(`PIPE_LEN)                    status_added_rs1_valid;	
	wire   `N(`PIPE_LEN)                    status_added_rd_valid;

    reg    `N(`PIPE_LEN)                    status_rs0_valid;
	reg    `N(`ALMAP_LEN)                   status_rs0_map;
    reg    `N(`PIPE_LEN)                    status_rs1_valid;
	reg    `N(`ALMAP_LEN)                   status_rs1_map;	
	reg    `N(`PIPE_LEN)                    status_rd_valid;
	reg    `N(`PIPE_LEN)                    status_rd_ld_bypass;
	reg    `N(`PIPE_LEN*`RGBIT)             status_rd_order;

	reg    `N(`PIPE_LEN*`RGBIT)             out_rd_lookup_order;
	wire   `N(`PNUM*`RGBIT)                 candidate_rd_order;	
	
	wire   `N(`PIPE_LEN*`FWR_NUM)           forward_calc_running;
	
	reg    `N(`PIPE_LEN)                    calc_rd_switch    `N(`FUNC_NUM);
	reg    `N(`PIPE_LEN)                    calc_rs0_switch   `N(`FUNC_NUM);	
	reg    `N(`PIPE_LEN)                    calc_rs1_switch   `N(`FUNC_NUM);	

	genvar i,j;
	
    //---------------------------------------------------------------------------
    //statements description
    //---------------------------------------------------------------------------

    //---------------------------------------------------------------------------
    //valid, clu, muldiv, jcond, op
    //---------------------------------------------------------------------------

	wire               trigger_jump = jump_jcond_valid;
	assign                 ban_jump = trigger_jump ? jcond_maskbits : {`PIPE_LEN{1'b1}};

	assign   { in_valid,in_clu,in_muldiv,in_jcond,in_op,in_rs0_valid,in_rs0_map,in_rs1_valid,in_rs1_map,in_rd_ld_bypass,in_rd_order	} = chain_attributes;
	
	wire `N(`PNUM)        status_incoming_valid = trigger_jump ? 0 : in_valid;
	wire `N(`PNUM)          status_incoming_clu = trigger_jump ? 0 : in_clu;
	wire `N(`PNUM)       status_incoming_muldiv = trigger_jump ? 0 : in_muldiv;
	wire `N(`PNUM)        status_incoming_jcond = trigger_jump ? 0 : in_jcond;
	wire `N(`PNUM)           status_incoming_op = trigger_jump ? 0 : in_op;

    wire `N(`PIPE_LEN)    status_modified_valid = status_valid;
	wire `N(`PIPE_LEN)      status_modified_clu = status_clu ^ status_masked_clu;
	wire `N(`PIPE_LEN)   status_modified_muldiv = status_muldiv ^ status_masked_muldiv;
	wire `N(`PIPE_LEN)    status_modified_jcond = status_jcond ^ status_masked_jcond;
	wire `N(`PIPE_LEN)       status_modified_op = status_op ^ status_masked_op;
	
    wire `N(`PIPE_LEN)     status_updated_valid = ban_jump & status_modified_valid;
    wire `N(`PIPE_LEN)       status_updated_clu = ban_jump & status_modified_clu;
    wire `N(`PIPE_LEN)    status_updated_muldiv = ban_jump & status_modified_muldiv;
    wire `N(`PIPE_LEN)     status_updated_jcond = ban_jump & status_modified_jcond;
    wire `N(`PIPE_LEN)        status_updated_op = ban_jump & status_modified_op; 	
	
	wire `N(`PIPE_LEN)       status_final_valid = chain_step ? ( (status_updated_valid<<`PNUM)|status_incoming_valid ) : status_updated_valid;
	wire `N(`PIPE_LEN)         status_final_clu = chain_step ? ( (status_updated_clu<<`PNUM)|status_incoming_clu ) : status_updated_clu;
	wire `N(`PIPE_LEN)      status_final_muldiv = chain_step ? ( (status_updated_muldiv<<`PNUM)|status_incoming_muldiv ) : status_updated_muldiv;
	wire `N(`PIPE_LEN)       status_final_jcond = chain_step ? ( (status_updated_jcond<<`PNUM)|status_incoming_jcond ) : status_updated_jcond;
	wire `N(`PIPE_LEN)          status_final_op = chain_step ? ( (status_updated_op<<`PNUM)|status_incoming_op ) : status_updated_op;
	
    `FFx(status_valid,0)
    status_valid <= status_final_valid;
	
    `FFx(status_clu,0)
    status_clu <= status_final_clu;
	
    `FFx(status_muldiv,0)
    status_muldiv <= status_final_muldiv;

    `FFx(status_jcond,0)
    status_jcond <= status_final_jcond;
	
    `FFx(status_op,0)
    status_op <= status_final_op;

    //---------------------------------------------------------------------------
    //rs0_valid, rs0_map rs1_valid, rs1_map, rd_valid, rd_ld_bypass, rd_order
    //---------------------------------------------------------------------------
    wire `N(`PNUM)            status_incoming_rs0_valid = in_rs0_valid;
    wire `N(`INMAP_LEN)         status_incoming_rs0_map = in_rs0_map;
    wire `N(`PNUM)            status_incoming_rs1_valid = in_rs1_valid;
    wire `N(`INMAP_LEN)         status_incoming_rs1_map = in_rs1_map;    	
    wire `N(`PNUM)             status_incoming_rd_valid = 0;
    wire `N(`PNUM)         status_incoming_rd_ld_bypass = in_rd_ld_bypass;
	wire `N(`PNUM*`RGBIT)      status_incoming_rd_order = in_rd_order;
	
    wire `N(`PIPE_LEN)            status_keep_rs0_valid = status_rs0_valid|status_added_rs0_valid;
    wire `N(`ALMAP_LEN)             status_keep_rs0_map = status_rs0_map;
    wire `N(`PIPE_LEN)            status_keep_rs1_valid = status_rs1_valid|status_added_rs1_valid;
    wire `N(`ALMAP_LEN)             status_keep_rs1_map = status_rs1_map;   	
	wire `N(`PIPE_LEN)             status_keep_rd_valid = status_rd_valid|status_added_rd_valid;
	wire `N(`PIPE_LEN)         status_keep_rd_ld_bypass = status_rd_ld_bypass;
	wire `N(`PIPE_LEN*`RGBIT)      status_keep_rd_order = status_rd_order;
	
	wire `N(`PIPE_LEN)            status_step_rs0_valid = ( status_keep_rs0_valid<<`PNUM )|status_incoming_rs0_valid;
    wire `N(`ALMAP_LEN)   status_step_rs0_map;	
	shift_rs_map i_rs0_map ( status_step_rs0_map,status_keep_rs0_map,status_incoming_rs0_map );
	wire `N(`PIPE_LEN)            status_step_rs1_valid = ( status_keep_rs1_valid<<`PNUM )|status_incoming_rs1_valid;
    wire `N(`ALMAP_LEN)   status_step_rs1_map;	
	shift_rs_map i_rs1_map ( status_step_rs1_map,status_keep_rs1_map,status_incoming_rs1_map );
	wire `N(`PIPE_LEN)             status_step_rd_valid = ( status_keep_rd_valid<<`PNUM )|status_incoming_rd_valid;
	wire `N(`PIPE_LEN)         status_step_rd_ld_bypass = ( status_keep_rd_ld_bypass<<`PNUM )|status_incoming_rd_ld_bypass;
	wire `N(`PIPE_LEN*`RGBIT)      status_step_rd_order = ( status_keep_rd_order<<(`PNUM*`RGBIT) )|status_incoming_rd_order;
	
	wire `N(`PIPE_LEN)           status_final_rs0_valid = chain_step ? status_step_rs0_valid : status_keep_rs0_valid;
    wire `N(`ALMAP_LEN)            status_final_rs0_map = chain_step ? status_step_rs0_map : status_keep_rs0_map;
	wire `N(`PIPE_LEN)           status_final_rs1_valid = chain_step ? status_step_rs1_valid : status_keep_rs1_valid;
    wire `N(`ALMAP_LEN)            status_final_rs1_map = chain_step ? status_step_rs1_map : status_keep_rs1_map;	
	wire `N(`PIPE_LEN)            status_final_rd_valid = chain_step ? status_step_rd_valid : status_keep_rd_valid;
	wire `N(`PIPE_LEN)        status_final_rd_ld_bypass = chain_step ? status_step_rd_ld_bypass : status_keep_rd_ld_bypass;
	wire `N(`PIPE_LEN*`RGBIT)     status_final_rd_order = chain_step ? status_step_rd_order : status_keep_rd_order;
	
    `FFx(status_rs0_valid,0)
    status_rs0_valid <= status_final_rs0_valid;
	
	`FFx(status_rs0_map,0)
	status_rs0_map <= status_final_rs0_map;
    
    `FFx(status_rs1_valid,0)
    status_rs1_valid <= status_final_rs1_valid;
	
	`FFx(status_rs1_map,0)
	status_rs1_map <= status_final_rs1_map;

    `FFx(status_rd_valid,0)
	status_rd_valid <= status_final_rd_valid;

    `FFx(status_rd_ld_bypass,0)
	status_rd_ld_bypass <= status_final_rd_ld_bypass;
	
	`FFx(status_rd_order,0)
	status_rd_order <= status_final_rd_order;
	
    //---------------------------------------------------------------------------
    //chain_rd_lookup_valid/order, chain_step,ch2gsr_order
    //---------------------------------------------------------------------------	
	`FFx(out_rd_lookup_order,0)
	out_rd_lookup_order <= conversion_lookup_order(status_final_rd_order,status_final_valid);
	
	assign                      chain_rd_lookup_valid = status_keep_rd_valid;	
	assign                      chain_rd_lookup_order = out_rd_lookup_order;

    wire   link_chain_step        `N(`PNUM+1);
	assign                         link_chain_step[0] = 1;
	generate
	    for (i=0;i<`PNUM;i=i+1) begin:gen_chain_step
		    wire                          instr_valid = status_updated_valid>>( `PNUM*(`CHAIN_LEN-1)+i );
			wire                            instr_clu = status_clu>>( `PNUM*(`CHAIN_LEN-1)+i );
            wire                         instr_muldiv = status_muldiv>>( `PNUM*(`CHAIN_LEN-1)+i );
            wire                          instr_jcond = status_jcond>>( `PNUM*(`CHAIN_LEN-1)+i );
            wire                             instr_op = status_op>>( `PNUM*(`CHAIN_LEN-1)+i );			
			wire                             rd_valid = status_keep_rd_valid>>( `PNUM*(`CHAIN_LEN-1)+i );
            wire                      instr_completed = ~( instr_clu|instr_muldiv|instr_jcond|instr_op ) & rd_valid;
		    assign               link_chain_step[i+1] = link_chain_step[i]&( ~instr_valid|instr_completed );
			assign candidate_rd_order[`IDX(i,`RGBIT)] = instr_valid ? ( status_rd_order>>( ( `PNUM*(`CHAIN_LEN-1)+i )*`RGBIT ) ) : 0;
	    end
	endgenerate

    assign                                 chain_step = link_chain_step[`PNUM]; 
	assign                               ch2gsr_order = chain_step ? candidate_rd_order : 0;

    //---------------------------------------------------------------------------
    //chain_authorized
    //---------------------------------------------------------------------------		
	wire `N(`PIPE_LEN)      link_forward_running  `N(`FWR_NUM+1);
	assign                  link_forward_running[0] = 0;
	generate
	    for (i=0;i<`FWR_NUM;i=i+1) begin:gen_forward_running
			assign link_forward_running[i+1] = link_forward_running[i]|forward_calc_running[`IDX(i,`PIPE_LEN)];
		end
	endgenerate

	wire `N(`PIPE_LEN)             status_rd_available = status_keep_rd_valid|link_forward_running[`FWR_NUM]; 
	
	wire `N(`PIPE_LEN)    status_map_rs0_valid, status_map_rs1_valid;
	get_rs_available  i_rs0_available( status_map_rs0_valid,status_rs0_map,status_rd_available );
	get_rs_available  i_rs1_available( status_map_rs1_valid,status_rs1_map,status_rd_available );	
	
	wire `N(`PIPE_LEN)            status_rs0_available = status_keep_rs0_valid|status_map_rs0_valid;
	wire `N(`PIPE_LEN)            status_rs1_available = status_keep_rs1_valid|status_map_rs1_valid;	
	wire `N(`PIPE_LEN)             status_rs_available = status_rs0_available & status_rs1_available;
	
    wire `N(`PIPE_LEN)                       ban_jcond = conversion_maskrest(status_modified_jcond);
	
	wire `N(`PIPE_LEN*`OP_NUM)           authorized_op = conversion_op(status_modified_op & status_rs_available) & {`OP_NUM{ban_jump}};
	wire `N(`PIPE_LEN)                  authorized_clu = conversion_onehot(status_modified_clu) & status_rs_available & ban_jcond & ban_jump;
	wire `N(`PIPE_LEN)               authorized_muldiv = conversion_onehot(status_modified_muldiv & status_rs_available) & ban_jcond  & ban_jump;
	wire `N(`PIPE_LEN)                authorized_jcond = conversion_onehot(status_modified_jcond) & status_rs_available & ban_jump;
	
	// authorized_array: base: PIPE_LEN  * num: FUNC_NUM
	wire `N(`PIPE_LEN*`FUNC_NUM)      authorized_array = { authorized_jcond,authorized_muldiv, authorized_clu, authorized_op };
	
	// chain_authorized: base: FUNC_NUM  * num: PIPE_LEN 
	generate
	    for (i=0;i<`PIPE_LEN;i=i+1) begin:gen_chain_authorized
		    for (j=0;j<`FUNC_NUM;j=j+1) begin:gen_chain_authorized_sub
			    assign chain_authorized[i*`FUNC_NUM+j] = authorized_array[j*`PIPE_LEN+i];
			end
		end
	endgenerate

    //---------------------------------------------------------------------------
    //flags of op(n) clu muldiv jcond
    //---------------------------------------------------------------------------	
		
	wire `N(`PIPE_LEN)         rs0_forward_array `N(`FWR_NUM);
	wire `N(`PIPE_LEN)         rs1_forward_array `N(`FWR_NUM);	
	generate
	    for (i=0;i<`FWR_NUM;i=i+1) begin:gen_rs_forward_array
		    get_rs_available i_rs0_forward_array ( rs0_forward_array[i],status_rs0_map,forward_calc_running[`IDX(i,`PIPE_LEN)] );
		    get_rs_available i_rs1_forward_array ( rs1_forward_array[i],status_rs1_map,forward_calc_running[`IDX(i,`PIPE_LEN)] );			
		end
	endgenerate	
	
    reg `N(`PIPE_LEN)    func_approved        `N(`FUNC_NUM);
	reg `N(`FWR_NUM)     rs0_from_forward     `N(`FUNC_NUM);
	reg `N(`FWR_NUM)     rs1_from_forward     `N(`FUNC_NUM);

    generate
	    for (i=0;i<`FUNC_NUM;i=i+1) begin:gen_approved
		    `FFx(func_approved[i],0)
			func_approved[i] <= authorized_array[`IDX(i,`PIPE_LEN)]<<(chain_step*`PNUM);
			
			for (j=0;j<`FWR_NUM;j=j+1) begin:gen_approved_sub
			    `FFx(rs0_from_forward[i][j],0)
				rs0_from_forward[i][j] <= |( authorized_array[`IDX(i,`PIPE_LEN)] & rs0_forward_array[j] );

			    `FFx(rs1_from_forward[i][j],0)
				rs1_from_forward[i][j] <= |( authorized_array[`IDX(i,`PIPE_LEN)] & rs1_forward_array[j] );				
			end

	    end
	endgenerate
	
	`FFx(jcond_maskbits,0)
	jcond_maskbits <= conversion_maskrest(func_approved[`FUNC_NUM-1]<<(chain_step*`PNUM));		
	
	
    //---------------------------------------------------------------------------
    //arrangement
    //---------------------------------------------------------------------------	
	wire `N(`PIPE_LEN*`FUNC_NUM)    func_calc_running;
	wire `N(`PIPE_LEN*`FUNC_NUM)    func_calc_final;
	
	wire   func_lsu_ack_valid = func_calc_ack_valid>>`OP_NUM;
	wire    func_lsu_ack_busy = func_calc_ack_busy>>`OP_NUM;
	
	generate
	    for (i=0;i<`FUNC_NUM;i=i+1)begin:gen_calc_req_valid
		    wire                                rs0_from_ld = rs0_from_forward[i]>>(`FWR_NUM-1);
			wire                                rs1_from_ld = rs1_from_forward[i]>>(`FWR_NUM-1);
			wire                                    ld_fail = ( rs0_from_ld|rs1_from_ld ) & ~func_lsu_ack_valid;
			wire                                  func_fail = ld_fail|func_calc_ack_busy[i];
			assign     func_calc_running[`IDX(i,`PIPE_LEN)] = func_approved[i] & {`PIPE_LEN{~func_fail}};
			assign       func_calc_final[`IDX(i,`PIPE_LEN)] = func_calc_running[`IDX(i,`PIPE_LEN)] & ban_jump;
			assign                   func_calc_req_valid[i] = |func_calc_final[`IDX(i,`PIPE_LEN)];
	    end
	endgenerate
	
	generate
	    for (i=0;i<`FWR_NUM;i=i+1) begin:gen_forward_calc_running
		    if ( i<`OP_NUM) begin
		        assign  forward_calc_running[`IDX(i,`PIPE_LEN)] = func_calc_running[`IDX(i,`PIPE_LEN)];
		    end else begin
			    assign  forward_calc_running[`IDX(i,`PIPE_LEN)] = ( func_calc_running[`IDX(i,`PIPE_LEN)]|( {`PIPE_LEN{func_lsu_ack_busy}} & calc_rd_switch[`OP_NUM] ) ) & status_rd_ld_bypass;
		    end
	    end
	endgenerate
	
	wire `N(`PIPE_LEN) link_masked_op `N(`OP_NUM+1);
	assign             link_masked_op[0] = 0;
	generate
	    for (i=0;i<`OP_NUM;i=i+1) begin:gen_masked_op
		    assign   link_masked_op[i+1] = link_masked_op[i]|func_calc_final[`IDX(i,`PIPE_LEN)];
	    end
	endgenerate
	
	assign              status_masked_op = link_masked_op[`OP_NUM];
	assign             status_masked_clu = func_calc_final>>(`OP_NUM*`PIPE_LEN);
	assign          status_masked_muldiv = func_calc_final>>((`OP_NUM+1)*`PIPE_LEN);
    assign           status_masked_jcond = func_calc_final>>((`OP_NUM+2)*`PIPE_LEN);	
	
	
	wire `N(`FUNC_NUM*`XLEN) forward_calc_operand0    `N(`FWR_NUM+1);
	wire `N(`FUNC_NUM*`XLEN) forward_calc_operand1    `N(`FWR_NUM+1);
	
	assign                   forward_calc_operand0[0] = 0;
	assign                   forward_calc_operand1[0] = 0;
	
	generate
	    for (i=0;i<`FWR_NUM;i=i+1) begin:gen_forward
		    for (j=0;j<`FUNC_NUM;j=j+1) begin:gen_forward_sub
		        assign       forward_calc_operand0[i+1][`IDX(j,`XLEN)] = forward_calc_operand0[i][`IDX(j,`XLEN)]|( {`XLEN{rs0_from_forward[j][i]}} & forward_source_data[`IDX(i,`XLEN)] );
		        assign       forward_calc_operand1[i+1][`IDX(j,`XLEN)] = forward_calc_operand1[i][`IDX(j,`XLEN)]|( {`XLEN{rs1_from_forward[j][i]}} & forward_source_data[`IDX(i,`XLEN)] );				
		    end
	    end
	endgenerate
		
	wire `N(`FUNC_NUM*8)     link_calc_para       `N(`CHAIN_LEN+1);
	wire `N(`FUNC_NUM*13)    link_calc_imm        `N(`CHAIN_LEN+1);
	wire `N(`FUNC_NUM*`XLEN) link_calc_pc         `N(`CHAIN_LEN+1);
	wire `N(`FUNC_NUM*`XLEN) link_calc_operand0   `N(`CHAIN_LEN+1);
	wire `N(`FUNC_NUM*`XLEN) link_calc_operand1   `N(`CHAIN_LEN+1);	
	
    assign                    link_calc_para[0] = 0;
    assign                     link_calc_imm[0] = 0;
    assign                      link_calc_pc[0] = 0;
    assign                link_calc_operand0[0] = 0;	
    assign                link_calc_operand1[0] = 0;	
	
	generate
	    for (i=0;i<`CHAIN_LEN;i=i+1) begin:gen_calc_things
	        assign          link_calc_para[i+1] = link_calc_para[i]|sub_calc_para[`IDX(i,`FUNC_NUM*8)];
	        assign           link_calc_imm[i+1] = link_calc_imm[i]|sub_calc_imm[`IDX(i,`FUNC_NUM*13)];		
	        assign            link_calc_pc[i+1] = link_calc_pc[i]|sub_calc_pc[`IDX(i,`FUNC_NUM*`XLEN)];
	        assign      link_calc_operand0[i+1] = link_calc_operand0[i]|sub_calc_operand0[`IDX(i,`FUNC_NUM*`XLEN)];	
	        assign      link_calc_operand1[i+1] = link_calc_operand1[i]|sub_calc_operand1[`IDX(i,`FUNC_NUM*`XLEN)];				
	    end
	endgenerate
	
	assign                   func_calc_req_para = link_calc_para[`CHAIN_LEN];
    assign                    func_calc_req_imm = link_calc_imm[`CHAIN_LEN];
    assign                     func_calc_req_pc = link_calc_pc[`CHAIN_LEN];
    assign               func_calc_req_operand0 = link_calc_operand0[`CHAIN_LEN]|forward_calc_operand0[`FWR_NUM];	
    assign               func_calc_req_operand1 = link_calc_operand1[`CHAIN_LEN]|forward_calc_operand1[`FWR_NUM];		


    //---------------------------------------------------------------------------
    //data
    //---------------------------------------------------------------------------	
	
	generate
	    for (i=0;i<`FUNC_NUM;i=i+1)begin:gen_flag_switch
		    wire `N(`PIPE_LEN)    next_rs0_switch, next_rs1_switch;
	        wire `N(`PIPE_LEN)    next_rd_switch = ( func_calc_final[`IDX(i,`PIPE_LEN)]|({`PIPE_LEN{func_calc_ack_busy[i]}} & calc_rd_switch[i]) )<<(chain_step*`PNUM);      
	        get_rs_available i_rs0_switch ( next_rs0_switch,status_final_rs0_map,next_rd_switch);
	        get_rs_available i_rs1_switch ( next_rs1_switch,status_final_rs1_map,next_rd_switch);	 
	
	        `FFx(calc_rd_switch[i],0)
			calc_rd_switch[i] <= next_rd_switch;
			
	        `FFx(calc_rs0_switch[i],0)
			calc_rs0_switch[i] <= next_rs0_switch;

	        `FFx(calc_rs1_switch[i],0)
			calc_rs1_switch[i] <= next_rs1_switch;				
	    end
	endgenerate
	
	wire  `N(`PIPE_LEN)        link_calc_rs0_valid  `N(`FUNC_NUM+1);
	wire  `N(`PIPE_LEN)        link_calc_rs1_valid  `N(`FUNC_NUM+1);
	wire  `N(`PIPE_LEN)        link_calc_rd_valid   `N(`FUNC_NUM+1);	
	wire  `N(`PIPE_LEN*`XLEN)  link_calc_rs0_data   `N(`FUNC_NUM+1);
	wire  `N(`PIPE_LEN*`XLEN)  link_calc_rs1_data   `N(`FUNC_NUM+1);
	wire  `N(`PIPE_LEN*`XLEN)  link_calc_rd_data    `N(`FUNC_NUM+1);	
	
	assign   link_calc_rs0_valid[0] = 0;
	assign   link_calc_rs1_valid[0] = 0;	
	assign    link_calc_rd_valid[0] = 0;	
	assign    link_calc_rs0_data[0] = 0;
	assign    link_calc_rs1_data[0] = 0;	
	assign     link_calc_rd_data[0] = 0;
	
	generate
	    for (i=0;i<`FUNC_NUM;i=i+1) begin:gen_calc_valid
		    assign   link_calc_rs0_valid[i+1] = link_calc_rs0_valid[i]|( calc_rs0_switch[i] & {`PIPE_LEN{func_calc_ack_valid[i]}} );
		    assign   link_calc_rs1_valid[i+1] = link_calc_rs1_valid[i]|( calc_rs1_switch[i] & {`PIPE_LEN{func_calc_ack_valid[i]}} );		    
		    assign    link_calc_rd_valid[i+1] = link_calc_rd_valid[i]|( calc_rd_switch[i] & {`PIPE_LEN{func_calc_ack_valid[i]}} );		
		
		    for (j=0;j<`PIPE_LEN;j=j+1) begin:gen_calc_valid_sub
                assign link_calc_rs0_data[i+1][`IDX(j,`XLEN)] = link_calc_rs0_data[i][`IDX(j,`XLEN)]|( {`XLEN{calc_rs0_switch[i][j]}} & func_calc_ack_data[`IDX(i,`XLEN)] );
                assign link_calc_rs1_data[i+1][`IDX(j,`XLEN)] = link_calc_rs1_data[i][`IDX(j,`XLEN)]|( {`XLEN{calc_rs1_switch[i][j]}} & func_calc_ack_data[`IDX(i,`XLEN)] );
                assign  link_calc_rd_data[i+1][`IDX(j,`XLEN)] = link_calc_rd_data[i][`IDX(j,`XLEN)]|( {`XLEN{calc_rd_switch[i][j]}} & func_calc_ack_data[`IDX(i,`XLEN)] );					
	        end
	    end
	endgenerate
	
	assign status_added_rs0_valid = link_calc_rs0_valid[`FUNC_NUM];
	assign status_added_rs1_valid = link_calc_rs1_valid[`FUNC_NUM];
	assign  status_added_rd_valid = link_calc_rd_valid[`FUNC_NUM];	
	assign    chain_rs0_feed_data = link_calc_rs0_data[`FUNC_NUM];	
	assign    chain_rs1_feed_data = link_calc_rs1_data[`FUNC_NUM];	
	assign     chain_rd_feed_data = link_calc_rd_data[`FUNC_NUM];	

endmodule

module shift_rs_map(
    output `N(`ALMAP_LEN)           out_map,
	input  `N(`ALMAP_LEN)           in_map,
	input  `N(`INMAP_LEN)           add_map
);
    genvar   i;
	
	generate 
	    for (i=0;i<(`PIPE_LEN-1);i=i+1) begin:gen_rs_map
			if ( i<`PNUM ) begin
			    assign out_map[(`ALMAP_LEN - `TERMIAL(`PIPE_LEN-1-i,0))+:(`PIPE_LEN-1-i)] = add_map[(`INMAP_LEN - `TERMIAL(`PIPE_LEN-1-i,`PIPE_LEN-`PNUM))+:(`PIPE_LEN-1-i)];
			end else begin
			    assign out_map[(`ALMAP_LEN - `TERMIAL(`PIPE_LEN-1-i,0))+:(`PIPE_LEN-1-i)] = in_map[(`ALMAP_LEN - `TERMIAL(`PIPE_LEN-1-(i-`PNUM),0))+:(`PIPE_LEN-1-(i-`PNUM))];
			end		
	    end
    endgenerate

endmodule
	
module get_rs_available(
    output `N(`PIPE_LEN)         rs_available,
	input  `N(`ALMAP_LEN)        rs_map,
	input  `N(`PIPE_LEN)         rd_available
);	
    genvar                       i;
	
	generate
        for (i=0;i<(`PIPE_LEN-1);i=i+1) begin:gen_rs_available
		    assign rs_available[i] = |(rs_map[(`ALMAP_LEN - `TERMIAL(`PIPE_LEN-1-i,0))+:(`PIPE_LEN-1-i)] & (rd_available>>(i+1)));
        end
    endgenerate
	
	assign  rs_available[`PIPE_LEN-1] = 0;
	
endmodule