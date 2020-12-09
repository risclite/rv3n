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

module rv3n_stage_id
(   
    input                               clk,
	input                               rst,

    input                               stage_id_clear,
	
	output                              id2dc_ready,
	input  `N(`PNUM)                    dc2id_valid,
	input  `N(`PNUM*`XLEN)              dc2id_instr,
	input  `N(`PNUM)                    dc2id_predict,
	input  `N(`PNUM*`DC_LEN)            dc2id_arguments,		
	input  `N(`PNUM*`XLEN)              dc2id_pc,
	
	output `N(`PNUM*`RGBIT)             id2gsr_rs0_order,
	output `N(`PNUM*`RGBIT)             id2gsr_rs1_order,
	input  `N(`PNUM*`XLEN)              gsr2id_rs0_data,
	input  `N(`PNUM*`XLEN)              gsr2id_rs1_data,
	
	input  `N(`PIPE_LEN)                chain_rd_lookup_valid,
	input  `N(`PIPE_LEN*`RGBIT)         chain_rd_lookup_order,
	input  `N(`PIPE_LEN*`XLEN)          chain_rd_lookup_data,
	
	input                               chain_step,
	output `N(`CHATT_LEN)               chain_attributes,
	output `N(`CHPKG_LEN)               chain_package
);

    //---------------------------------------------------------------------------
    //function defination
    //---------------------------------------------------------------------------	
    function `N(1+1+`PIPE_LEN+`XLEN) lookup_from_reference (    input `N(`RGBIT)           lookup_order,
	                                                            input `N(`PIPE_LEN)        array_valid,
	                                                            input `N(`PIPE_LEN*`RGBIT) array_order,
														        input `N(`PIPE_LEN*`XLEN)  array_data
													     	);
		integer                    i;		
		reg `N(`PIPE_LEN)          array_hit;
		reg `N(`PIPE_LEN)          array_onehot;
		reg                        out_missing;
		reg                        out_valid;
		reg `N(`PIPE_LEN)          out_map;
		reg `N(`XLEN)              out_data;
		begin
		    for(i=0;i<`PIPE_LEN;i=i+1)
			    array_hit[i]      = array_order[`IDX(i,`RGBIT)] == lookup_order;
				
			array_onehot          = array_hit;
		    
			out_missing           = ( array_onehot==0 );
		    out_valid             = |( array_onehot & array_valid );
			out_map               = array_onehot;
			
			out_data              = 0;
			for(i=0;i<`PIPE_LEN;i=i+1)
			    out_data          = out_data|( {`XLEN{array_onehot[i]}} & array_data[`IDX(i,`XLEN)] );
				
			lookup_from_reference = { out_missing,out_valid,out_map,out_data };
		end
    endfunction	
	
	function `N(`PNUM)  conversion_onehot( input `N(`PNUM) array );
	    reg              valid_flag;
		integer          i;
		begin
		    if ( `PNUM>=3 ) begin
			    valid_flag = 1;
				for (i=0;i<`PNUM;i=i+1) begin
				    conversion_onehot[i] = valid_flag &  array[i];
					valid_flag           = valid_flag & ~array[i];
				end
			end else
			    conversion_onehot = array;
		end
	endfunction
	
    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
    reg    `N(`PNUM)                   active_valid;
    reg    `N(`PNUM*`XLEN)             active_instr;
	reg    `N(`PNUM)                   active_predict;	
	reg    `N(`PNUM*`DC_LEN)           active_arguments;
	reg    `N(`PNUM*`XLEN)             active_pc;

    wire                               following_bypass      `N(`PNUM+1);
    wire                               link_command_halt     `N(`PNUM+1);
  	
	wire   `N(`PNUM*`RGBIT)            all_rd_order;	
	
	wire   `N(`PNUM)                   pkg_valid;
	wire   `N(`PNUM)                   pkg_clu;
	wire   `N(`PNUM)                   pkg_muldiv;
	wire   `N(`PNUM)                   pkg_jcond;
	wire   `N(`PNUM)                   pkg_op;
	wire   `N(`PNUM)                   pkg_rs0_valid;
	wire   `N(`INMAP_LEN)              pkg_rs0_map;
	wire   `N(`PNUM)                   pkg_rs1_valid;
	wire   `N(`INMAP_LEN)              pkg_rs1_map;	
	wire   `N(`PNUM)                   pkg_rd_ld_bypass;
	wire   `N(`PNUM*`RGBIT)            pkg_rd_order;
	
	wire   `N(`PNUM*8)                 pkg_para;
	wire   `N(`PNUM*13)                pkg_imm;
	wire   `N(`PNUM*`XLEN)             pkg_pc;
	wire   `N(`PNUM*`XLEN)             pkg_rs0_data;
	wire   `N(`PNUM*`XLEN)             pkg_rs1_data;
	wire   `N(`PNUM*`XLEN)             pkg_rd_data;
	wire   `N(`PNUM*`FUNC_NUM)         pkg_authorized;
	
	
    localparam      IDLE     = 0,
					WIDL     = 1,	
	                HALT     = 2,
					STATENUM = 3;

	reg    `N(STATENUM)                current_state;
	reg    `N(STATENUM)                next_state;

    genvar  i,j;
    //---------------------------------------------------------------------------
    //statements description
    //---------------------------------------------------------------------------

    //---------------------------------------------------------------------------
    //active stage
    //---------------------------------------------------------------------------	

    `FFx(active_valid,0)
	if ( stage_id_clear )
	    active_valid <= 0;
	else if ( id2dc_ready )
	    active_valid <= dc2id_valid;
	else;
	
	`FFx(active_instr,0)
	if ( id2dc_ready )
	    active_instr <= dc2id_instr;
	else;

	`FFx(active_predict,0)
	if ( id2dc_ready )
	    active_predict <= dc2id_predict;
	else;

    `FFx(active_arguments,0)
	if ( id2dc_ready )
	    active_arguments <= dc2id_arguments;
	else;
	
	`FFx(active_pc,0)
	if ( id2dc_ready )
	    active_pc <= dc2id_pc;
	else;

    assign                             following_bypass[0] = 0;
	assign                            link_command_halt[0] = 0;
	
    generate
	    for (i=0;i<`PNUM;i=i+1) begin:gen_instr
	        //basic info
			wire                                     valid = active_valid>>i;
            wire `N(`XLEN)                           instr = active_instr>>(i*`XLEN);
            wire                                   predict = active_predict>>i;
            wire `N(`DC_LEN)                     arguments = active_arguments>>(i*`DC_LEN);
            wire `N(`XLEN)                              pc = active_pc>>(i*`XLEN);
  
            //instr arguments
			wire                               instr_super = arguments>>(`DC_LEN-1);
			wire                                instr_jalr = arguments>>(`DC_LEN-2);
			wire                                 instr_jal = arguments>>(`DC_LEN-3);
			wire                               instr_jcond = arguments>>(`DC_LEN-4);
			
			wire                                  attr_clu = arguments>>(`DC_LEN-5);
			wire                               attr_muldiv = arguments>>(`DC_LEN-6);
			wire                                attr_jcond = arguments>>(`DC_LEN-7);
			wire                                   attr_op = arguments>>(`DC_LEN-8);
			
			wire                                 ld_bypass = arguments>>(`DC_LEN-9);
			wire                                rs0_pc_sel = arguments>>(`DC_LEN-10);
			wire                               rs1_imm_sel = arguments>>(`DC_LEN-11);
			
			wire `N(7)                             ch_para = arguments>>(13+`XLEN+(3*`RGBIT));
			wire `N(13)                             ch_imm = arguments>>(`XLEN+(3*`RGBIT));
			wire `N(`XLEN)                   rs1_immediate = arguments>>(3*`RGBIT);
			wire `N(`RGBIT)                       rd_order = arguments>>(2*`RGBIT);
			wire `N(`RGBIT)                      rs1_order = arguments>>`RGBIT;
			wire `N(`RGBIT)                      rs0_order = arguments;
			
			//sys & jalr
			assign                   following_bypass[i+1] = following_bypass[i]|( instr_super|instr_jalr|instr_jal|(instr_jcond & predict) );
			assign                  link_command_halt[i+1] = link_command_halt[i]|( valid & ~following_bypass[i] & (instr_super|instr_jalr) );
			
			//rs
            assign            all_rd_order[`IDX(i,`RGBIT)] = rd_order;
			
            //rs0
			assign        id2gsr_rs0_order[`IDX(i,`RGBIT)] = rs0_order;			
	        wire                             rs0_lookup_missing,rs0_lookup_valid;
	        wire `N(`PIPE_LEN)               rs0_lookup_map;
	        wire `N(`XLEN)                   rs0_lookup_data;				
			assign { rs0_lookup_missing,rs0_lookup_valid,rs0_lookup_map,rs0_lookup_data } = lookup_from_reference( rs0_order,chain_rd_lookup_valid,chain_rd_lookup_order,chain_rd_lookup_data );
			
			wire `N(`PNUM)   rs0_equal_other_rd;
			for (j=0;j<`PNUM;j=j+1) begin:gen_rs0_equal
			    assign       rs0_equal_other_rd[`PNUM-1-j] = ( rs0_order==all_rd_order[`IDX(j,`RGBIT)] ) & (i>j);
			end
			
			wire `N(`PNUM)                rs0_parallel_map = conversion_onehot(rs0_equal_other_rd); 
            wire                      rs0_parallel_missing = rs0_equal_other_rd==0;			
			
			wire                          rs0_is_available = (rs0_order==0)|( rs0_parallel_missing & (rs0_lookup_missing|rs0_lookup_valid) ); 
			wire `N(`PIPE_LEN)                     rs0_map = (rs0_order==0) ? 0 : ( rs0_parallel_missing ? (rs0_lookup_map<<`PNUM) : rs0_parallel_map );
			wire `N(`XLEN)                        rs0_data =  rs0_pc_sel ? pc : ( ((rs0_order!=0)&rs0_parallel_missing&rs0_lookup_valid) ? rs0_lookup_data : gsr2id_rs0_data[`IDX(i,`XLEN)] );	
	
            //rs1
			assign        id2gsr_rs1_order[`IDX(i,`RGBIT)] = rs1_order;			
	        wire                               rs1_lookup_missing,rs1_lookup_valid;
	        wire `N(`PIPE_LEN)                 rs1_lookup_map;
	        wire `N(`XLEN)                     rs1_lookup_data;				
			assign { rs1_lookup_missing,rs1_lookup_valid,rs1_lookup_map,rs1_lookup_data } = lookup_from_reference( rs1_order,chain_rd_lookup_valid,chain_rd_lookup_order,chain_rd_lookup_data );
			
			wire `N(`PNUM)   rs1_equal_other_rd;
			for (j=0;j<`PNUM;j=j+1) begin:gen_rs1_equal
			    assign       rs1_equal_other_rd[`PNUM-1-j] = ( rs1_order==all_rd_order[`IDX(j,`RGBIT)] ) & (i>j);
			end
			
			wire `N(`PNUM)                rs1_parallel_map = conversion_onehot(rs1_equal_other_rd);  			
            wire                      rs1_parallel_missing = rs1_equal_other_rd==0;				
			
			wire                          rs1_is_available = (rs1_order==0)|( rs1_parallel_missing & (rs1_lookup_missing|rs1_lookup_valid) ); 
			wire `N(`PIPE_LEN)                     rs1_map = (rs1_order==0) ? 0 : ( rs1_parallel_missing ? (rs1_lookup_map<<`PNUM) : rs1_parallel_map );
			wire `N(`XLEN)                        rs1_data = rs1_imm_sel ? rs1_immediate : ( ((rs1_order!=0)&(rs1_equal_other_rd==0)&rs1_lookup_valid) ? rs1_lookup_data : gsr2id_rs1_data[`IDX(i,`XLEN)] );	
			
			//attributes and package
			localparam `N($clog2(`PNUM))                 T = `PNUM-1-i;
			localparam                           MAP_START = ( `INMAP_LEN - `TERMIAL(`PNUM*(`CHAIN_LEN-1)+i,`PNUM*(`CHAIN_LEN-1)) );
			localparam                          MAP_LENGTH = ( `PNUM*(`CHAIN_LEN-1)+i );			
            wire                                  pkg_pass = valid & ~following_bypass[i] & ~current_state[HALT];
			assign                            pkg_valid[T] = pkg_pass & ( {attr_clu,attr_muldiv,attr_jcond,attr_op}!=0 );
			assign                              pkg_clu[T] = pkg_pass ? attr_clu : 0;
			assign                           pkg_muldiv[T] = pkg_pass ? attr_muldiv : 0;
			assign                            pkg_jcond[T] = pkg_pass ? attr_jcond : 0;
			assign                               pkg_op[T] = pkg_pass ? attr_op : 0;
			assign                        pkg_rs0_valid[T] = rs0_is_available;
			assign      pkg_rs0_map[MAP_START+:MAP_LENGTH] = rs0_map>>(`PNUM-i);
			assign                        pkg_rs1_valid[T] = rs1_is_available;
			assign      pkg_rs1_map[MAP_START+:MAP_LENGTH] = rs1_map>>(`PNUM-i);			
			assign                     pkg_rd_ld_bypass[T] = ld_bypass;
			assign            pkg_rd_order[`IDX(T,`RGBIT)] = rd_order;
			
			assign                     pkg_para[`IDX(T,8)] = {predict,ch_para};
			assign                     pkg_imm[`IDX(T,13)] = ( instr_jcond & predict ) ? ( 2'd2<<(instr[1:0]==2'b11) ) : ch_imm;			
			assign                   pkg_pc[`IDX(T,`XLEN)] = pc;					
	        assign             pkg_rs0_data[`IDX(T,`XLEN)] = rs0_is_available ? rs0_data : 0;
	        assign             pkg_rs1_data[`IDX(T,`XLEN)] = rs1_is_available ? rs1_data : 0;
	        assign              pkg_rd_data[`IDX(T,`XLEN)] = 0;
			assign       pkg_authorized[`IDX(T,`FUNC_NUM)] = 0;				
	    end
	endgenerate

    wire                                      command_halt = link_command_halt[`PNUM];	
	
    assign                                     id2dc_ready = ( current_state[IDLE] & (~(|active_valid)|chain_step) )|( current_state[WIDL] & chain_step );		
		
    //---------------------------------------------------------------------------
    //state machine
    //---------------------------------------------------------------------------		
	
    //main state machine
    `FFx(current_state,1'b1<<IDLE)
	current_state <= next_state;
	
	always @* begin
	    next_state = current_state;
        if ( stage_id_clear )
	        next_state = 1'b1<<IDLE;
	    else case(1'b1)
		    current_state[IDLE] : begin
                                    if ( (|active_valid) & ~chain_step )
		    					        next_state = 1'b1<<WIDL;
		    					    else if ( command_halt )
									    next_state = 1'b1<<HALT;
									else;
		    				    end	
		    current_state[WIDL] : begin
		                            if ( chain_step )
								        next_state = command_halt ? (1'b1<<HALT) : (1'b1<<IDLE);
								    else;
		                        end								
		    current_state[HALT] : begin
			                        next_state = 1'b1<<HALT;
		                        end			   
		    endcase
	end		
	

    //---------------------------------------------------------------------------
    //chain
    //---------------------------------------------------------------------------
		
	assign                                chain_attributes = {
	                                                pkg_valid,
													pkg_clu,
													pkg_muldiv,
													pkg_jcond,
													pkg_op,
													pkg_rs0_valid,
													pkg_rs0_map,
													pkg_rs1_valid,
													pkg_rs1_map,
													pkg_rd_ld_bypass,
													pkg_rd_order
	                                                };
	
	
	assign                                   chain_package = {  
	                                                pkg_para,
	                                                pkg_imm,
				                                    pkg_pc,	                                                
	                                                pkg_rs0_data,
	                                                pkg_rs1_data,
													pkg_rd_data,
				                                    pkg_authorized
                                                    };
endmodule