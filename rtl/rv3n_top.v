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
module rv3n_top
(   
    input                                   clk,
	input                                   rst,

    output                                  imem_req,
	output `N(`XLEN)                        imem_addr,
	input                                   imem_resp,
	input  `N(`INUM*`XLEN)                  imem_rdata,
	input                                   imem_err,

	output                                  dmem_req,
	output                                  dmem_cmd,
	output `N(2)                            dmem_width,
	output `N(`XLEN)                        dmem_addr,
	output `N(`XLEN)                        dmem_wdata,
	input  `N(`XLEN)                        dmem_rdata,
	input                                   dmem_resp,
    input                                   dmem_err	

);


    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
    //stage IF
	wire   `N(`INUM*2)                      imem_predict;
	
	wire                                    dc2if_new_valid;
	wire   `N(`XLEN)                        dc2if_new_pc;
	wire                                    dc2if_continue;
	
	wire                                    if2dc_valid;
	wire   `N(`INUM*`XLEN)                  if2dc_rdata;
	wire                                    if2dc_err;
	wire   `N(`INUM*2)                      if2dc_predict;

    //stage DC
	wire                                    jump_valid;
    wire   `N(`XLEN)                        jump_pc;
	
	wire                                    id2dc_ready;
	wire   `N(`PNUM)                        dc2id_valid;
	wire   `N(`PNUM*`XLEN)                  dc2id_instr;
	wire   `N(`PNUM)                        dc2id_predict;
	wire   `N(`PNUM*`DC_LEN)                dc2id_arguments;
	wire   `N(`PNUM*`XLEN)                  dc2id_pc;

    //stage ID
	wire                                    stage_id_clear;

	wire   `N(`PNUM*`RGBIT)                 id2gsr_rs0_order;
	wire   `N(`PNUM*`RGBIT)                 id2gsr_rs1_order;
	wire   `N(`PNUM*`XLEN)                  gsr2id_rs0_data;
	wire   `N(`PNUM*`XLEN)                  gsr2id_rs1_data;

	wire   `N(`PIPE_LEN)                    chain_rd_lookup_valid;	
    wire   `N(`PIPE_LEN*`RGBIT)             chain_rd_lookup_order;
	wire   `N(`PIPE_LEN*`XLEN)              chain_rd_lookup_data;	

	wire                                    chain_step;
	wire   `N(`CHATT_LEN)                   chain_attributes;
	wire   `N((`CHAIN_LEN+1)*`CHPKG_LEN)    chain_package;
	
    //stage CH	
	wire   `N(`PIPE_LEN*`FUNC_NUM)          chain_authorized;
	wire   `N(`PIPE_LEN*`XLEN)              chain_rs0_feed_data;
	wire   `N(`PIPE_LEN*`XLEN)              chain_rs1_feed_data;
	wire   `N(`PIPE_LEN*`XLEN)              chain_rd_feed_data;	
	
    wire   `N(`CHAIN_LEN*`FUNC_NUM*8)       sub_calc_para;
    wire   `N(`CHAIN_LEN*`FUNC_NUM*13)      sub_calc_imm;
    wire   `N(`CHAIN_LEN*`FUNC_NUM*`XLEN)   sub_calc_pc;
    wire   `N(`CHAIN_LEN*`FUNC_NUM*`XLEN)   sub_calc_operand0;	
    wire   `N(`CHAIN_LEN*`FUNC_NUM*`XLEN)   sub_calc_operand1;		

    //chain manager	
	wire   `N(`PNUM*`RGBIT)                 ch2gsr_order;

    wire   `N(`FUNC_NUM)                    func_calc_req_valid;
	wire   `N(`FUNC_NUM*8)                  func_calc_req_para;
	wire   `N(`FUNC_NUM*13)                 func_calc_req_imm;
	wire   `N(`FUNC_NUM*`XLEN)              func_calc_req_pc;
	wire   `N(`FUNC_NUM*`XLEN)              func_calc_req_operand0;
	wire   `N(`FUNC_NUM*`XLEN)              func_calc_req_operand1;
	wire   `N(`FUNC_NUM)                    func_calc_ack_valid;
	wire   `N(`FUNC_NUM*`XLEN)              func_calc_ack_data;
	wire   `N(`FUNC_NUM)                    func_calc_ack_busy;
	
    wire   `N(`FWR_NUM*`XLEN)               forward_source_data; 
	
	//func lsu
	wire                                    func_lsu_ack_valid;
	wire   `N(`XLEN)                        func_lsu_ack_data;
	wire                                    func_lsu_ack_busy;	

    wire   `N(`XLEN)                        func_lsu_shortcut_data;

   //func_jcond
	wire                                    ch2predictor_valid;
	wire   `N(`XLEN)                        ch2predictor_pc;
	wire                                    ch2predictor_predict;
	wire                                    ch2predictor_taken;		

	wire                                    jump_jcond_valid;
	wire   `N(`XLEN)                        jump_jcond_pc;

    // csr
	wire                                    func_csr_ack_valid;
	wire   `N(`XLEN)                        func_csr_ack_data;
	wire                                    func_csr_ack_busy;		
	
    genvar i;
    //---------------------------------------------------------------------------
    //statements description
    //---------------------------------------------------------------------------

    rv3n_stage_if i_stage_if
    (   
        .clk                        (    clk                                        ),
    	.rst                        (    rst                                        ),
    
        .imem_req                   (    imem_req                                   ),
    	.imem_addr                  (    imem_addr                                  ),
    	.imem_resp                  (    imem_resp                                  ),
    	.imem_rdata                 (    imem_rdata                                 ),
    	.imem_err                   (    imem_err                                   ),
		.imem_predict               (    imem_predict                               ),
    
	    .dc2if_new_valid            (    dc2if_new_valid                            ),
		.dc2if_new_pc               (    dc2if_new_pc                               ),
		.dc2if_continue             (    dc2if_continue                             ),

    	.if2dc_valid                (    if2dc_valid                                ),
    	.if2dc_rdata                (    if2dc_rdata                                ),
    	.if2dc_err                  (    if2dc_err                                  ),
		.if2dc_predict              (    if2dc_predict                              )
    );

    rv3n_stage_dc i_stage_dc
    (   
        .clk                        (    clk                                        ),
    	.rst                        (    rst                                        ),
  
	    .dc2if_new_valid            (    dc2if_new_valid                            ),
		.dc2if_new_pc               (    dc2if_new_pc                               ),
		.dc2if_continue             (    dc2if_continue                             ),

    	.if2dc_valid                (    if2dc_valid                                ),
    	.if2dc_rdata                (    if2dc_rdata                                ),
    	.if2dc_err                  (    if2dc_err                                  ),
		.if2dc_predict              (    if2dc_predict                              ),

        .jump_valid                 (    jump_valid                                 ),
		.jump_pc                    (    jump_pc                                    ),
   
	    .id2dc_ready                (    id2dc_ready                                ),
	    .dc2id_valid                (    dc2id_valid                                ),
	    .dc2id_instr                (    dc2id_instr                                ),
	    .dc2id_predict              (    dc2id_predict                              ),
	    .dc2id_arguments            (    dc2id_arguments                            ),			
	    .dc2id_pc                   (    dc2id_pc                                   )
    );		

   rv3n_stage_id i_stage_id
   (   
        .clk                        (    clk                                        ),
    	.rst                        (    rst                                        ),
    
        .stage_id_clear             (    stage_id_clear                             ),
    
	    .id2dc_ready                (    id2dc_ready                                ),
	    .dc2id_valid                (    dc2id_valid                                ),
	    .dc2id_instr                (    dc2id_instr                                ),
	    .dc2id_predict              (    dc2id_predict                              ),
	    .dc2id_arguments            (    dc2id_arguments                            ),			
	    .dc2id_pc                   (    dc2id_pc                                   ),

	    .id2gsr_rs0_order           (    id2gsr_rs0_order                           ),
	    .id2gsr_rs1_order           (    id2gsr_rs1_order                           ),
	    .gsr2id_rs0_data            (    gsr2id_rs0_data                            ),
	    .gsr2id_rs1_data            (    gsr2id_rs1_data                            ),	
		
		.chain_rd_lookup_valid      (    chain_rd_lookup_valid                      ),
		.chain_rd_lookup_order      (    chain_rd_lookup_order                      ),		
		.chain_rd_lookup_data       (    chain_rd_lookup_data                       ),

	    .chain_step                 (    chain_step                                 ),
		.chain_attributes           (    chain_attributes                           ),
	    .chain_package              (    chain_package[`IDX(0,`CHPKG_LEN)]          )
    );
 
    generate
    for (i=0;i<`CHAIN_LEN;i=i+1) begin:gen_stage_ch	
    rv3n_stage_ch i_stage_ch
    (
    
        .clk                        (    clk                                        ),
    	.rst                        (    rst                                        ),

    	.chain_step                 (    chain_step                                 ),
    	.chain_package_in           (    chain_package[`IDX(i,`CHPKG_LEN)]          ),
		.chain_package_out          (    chain_package[`IDX(i+1,`CHPKG_LEN)]        ),	

		.chain_authorized           (    chain_authorized[`IDX(i,`PNUM*`FUNC_NUM)]  ),		
        .chain_rs0_feed_data        (    chain_rs0_feed_data[`IDX(i,`PNUM*`XLEN)]   ),
		.chain_rs1_feed_data        (    chain_rs1_feed_data[`IDX(i,`PNUM*`XLEN)]   ),
		.chain_rd_feed_data         (    chain_rd_feed_data[`IDX(i,`PNUM*`XLEN)]    ),
		.chain_rd_lookup_data       (    chain_rd_lookup_data[`IDX(i,`PNUM*`XLEN)]  ),
 
        .sub_calc_para              (    sub_calc_para[`IDX(i,`FUNC_NUM*8)]         ),
		.sub_calc_imm               (    sub_calc_imm[`IDX(i,`FUNC_NUM*13)]         ),
		.sub_calc_pc                (    sub_calc_pc[`IDX(i,`FUNC_NUM*`XLEN)]       ),
		.sub_calc_operand0          (    sub_calc_operand0[`IDX(i,`FUNC_NUM*`XLEN)] ),		
		.sub_calc_operand1          (    sub_calc_operand1[`IDX(i,`FUNC_NUM*`XLEN)] )
    ); 
	end
	endgenerate
 
    rv3n_chain_manager i_chain_manager
    (
    
        .clk                        (    clk                                        ),
    	.rst                        (    rst                                        ),
    	
    	.chain_step                 (    chain_step                                 ),
		.ch2gsr_order               (    ch2gsr_order                               ),		
		.chain_attributes           (    chain_attributes                           ),
		
		.chain_authorized           (    chain_authorized                           ),
        .chain_rs0_feed_data        (    chain_rs0_feed_data                        ),
		.chain_rs1_feed_data        (    chain_rs1_feed_data                        ),
		.chain_rd_feed_data         (    chain_rd_feed_data                         ),
		.chain_rd_lookup_valid      (    chain_rd_lookup_valid                      ),
		.chain_rd_lookup_order      (    chain_rd_lookup_order                      ),
		
        .sub_calc_para              (    sub_calc_para                              ),
		.sub_calc_imm               (    sub_calc_imm                               ),
		.sub_calc_pc                (    sub_calc_pc                                ),
		.sub_calc_operand0          (    sub_calc_operand0                          ),		
		.sub_calc_operand1          (    sub_calc_operand1                          ),		
		
        .func_calc_req_valid        (    func_calc_req_valid                        ),
		.func_calc_req_para         (    func_calc_req_para                         ),
		.func_calc_req_imm          (    func_calc_req_imm                          ),
		.func_calc_req_pc           (    func_calc_req_pc                           ),
		.func_calc_req_operand0     (    func_calc_req_operand0                     ),
		.func_calc_req_operand1     (    func_calc_req_operand1                     ),		
		.func_calc_ack_valid        (    func_calc_ack_valid                        ),
		.func_calc_ack_data         (    func_calc_ack_data                         ),
		.func_calc_ack_busy         (    func_calc_ack_busy                         ),
		
		.forward_source_data        (    forward_source_data                        ),
        .jump_jcond_valid           (    jump_jcond_valid                           )		
    
    ); 
 
    generate
	for (i=0;i<`OP_NUM;i=i+1) begin:gen_func_op
    rv3n_func_op i_func_op
    (
        .clk                        (    clk                                        ),
    	.rst                        (    rst                                        ),
		
        .func_op_req_valid          (    func_calc_req_valid[i]                     ),
		.func_op_req_para           (    func_calc_req_para[`IDX(i,8)]              ),
		.func_op_req_imm            (    func_calc_req_imm[`IDX(i,13)]              ),
		.func_op_req_pc             (    func_calc_req_pc[`IDX(i,`XLEN)]            ),
		.func_op_req_operand0       (    func_calc_req_operand0[`IDX(i,`XLEN)]      ),
		.func_op_req_operand1       (    func_calc_req_operand1[`IDX(i,`XLEN)]      ),		
		.func_op_ack_valid          (    func_calc_ack_valid[i]                     ),
		.func_op_ack_data           (    func_calc_ack_data[`IDX(i,`XLEN)]          ),
		.func_op_ack_busy           (    func_calc_ack_busy[i]                      )
    
    ); 
	end
	endgenerate
 
    rv3n_func_lsu i_func_lsu
    (
        .clk                        (    clk                                        ),
    	.rst                        (    rst                                        ),
    	
        .func_lsu_req_valid         (    func_calc_req_valid[`OP_NUM]               ),
		.func_lsu_req_para          (    func_calc_req_para[`IDX(`OP_NUM,8)]        ),
		.func_lsu_req_imm           (    func_calc_req_imm[`IDX(`OP_NUM,13)]        ),
		.func_lsu_req_pc            (    func_calc_req_pc[`IDX(`OP_NUM,`XLEN)]      ),
		.func_lsu_req_operand0      (    func_calc_req_operand0[`IDX(`OP_NUM,`XLEN)]),
		.func_lsu_req_operand1      (    func_calc_req_operand1[`IDX(`OP_NUM,`XLEN)]),		
		.func_lsu_ack_valid         (    func_lsu_ack_valid                         ),
		.func_lsu_ack_data          (    func_lsu_ack_data                          ),
		.func_lsu_ack_busy          (    func_lsu_ack_busy                          ),
	
		.func_lsu_shortcut_data     (    func_lsu_shortcut_data                     ),
    	
    	.dmem_req                   (    dmem_req                                   ),
    	.dmem_cmd                   (    dmem_cmd                                   ),
    	.dmem_width                 (    dmem_width                                 ),
    	.dmem_addr                  (    dmem_addr                                  ),
    	.dmem_wdata                 (    dmem_wdata                                 ),
    	.dmem_rdata                 (    dmem_rdata                                 ),
    	.dmem_resp                  (    dmem_resp                                  ),
        .dmem_err	                (    dmem_err	                                )	
    	
    ); 
 
    rv3n_func_muldiv i_func_muldiv
    (   
        .clk                        (    clk                                        ),
    	.rst                        (    rst                                        ),
    	
        .func_muldiv_req_valid      (    func_calc_req_valid[`OP_NUM+1]               ),
		.func_muldiv_req_para       (    func_calc_req_para[`IDX(`OP_NUM+1,8)]        ),
		.func_muldiv_req_imm        (    func_calc_req_imm[`IDX(`OP_NUM+1,13)]        ),
		.func_muldiv_req_pc         (    func_calc_req_pc[`IDX(`OP_NUM+1,`XLEN)]      ),
		.func_muldiv_req_operand0   (    func_calc_req_operand0[`IDX(`OP_NUM+1,`XLEN)]),
		.func_muldiv_req_operand1   (    func_calc_req_operand1[`IDX(`OP_NUM+1,`XLEN)]),		
		.func_muldiv_ack_valid      (    func_calc_ack_valid[`OP_NUM+1]               ),
		.func_muldiv_ack_data       (    func_calc_ack_data[`IDX(`OP_NUM+1,`XLEN)]    ),
		.func_muldiv_ack_busy       (    func_calc_ack_busy[`OP_NUM+1]                )
    	
    ); 


    rv3n_func_jcond i_func_jcond
    (   
        .clk                        (    clk                                        ),
    	.rst                        (    rst                                        ),
    	
        .func_jcond_req_valid       (    func_calc_req_valid[`OP_NUM+2]               ),
		.func_jcond_req_para        (    func_calc_req_para[`IDX(`OP_NUM+2,8)]        ),
		.func_jcond_req_imm         (    func_calc_req_imm[`IDX(`OP_NUM+2,13)]        ),
		.func_jcond_req_pc          (    func_calc_req_pc[`IDX(`OP_NUM+2,`XLEN)]      ),
		.func_jcond_req_operand0    (    func_calc_req_operand0[`IDX(`OP_NUM+2,`XLEN)]),
		.func_jcond_req_operand1    (    func_calc_req_operand1[`IDX(`OP_NUM+2,`XLEN)]),		
		.func_jcond_ack_valid       (    func_calc_ack_valid[`OP_NUM+2]               ),
		.func_jcond_ack_data        (    func_calc_ack_data[`IDX(`OP_NUM+2,`XLEN)]    ),
		.func_jcond_ack_busy        (    func_calc_ack_busy[`OP_NUM+2]                ),
    	
	    .ch2predictor_valid         (    ch2predictor_valid                         ),
	    .ch2predictor_pc            (    ch2predictor_pc                            ),
	    .ch2predictor_predict       (    ch2predictor_predict                       ),
	    .ch2predictor_taken         (    ch2predictor_taken                         ),

        .jump_jcond_valid           (    jump_jcond_valid                           ),
        .jump_jcond_pc              (    jump_jcond_pc                              )		
		
    ); 	


    rv3n_predictor  i_predictor
    (   
        .clk                        (    clk                                        ),
    	.rst                        (    rst                                        ),
		
    	.imem_req                   (    imem_req                                   ),
    	.imem_addr 	                (    imem_addr                                  ),	
        .imem_predict               (    imem_predict                               ),
		
	    .ch2predictor_valid         (    ch2predictor_valid                         ),
	    .ch2predictor_pc            (    ch2predictor_pc                            ),
	    .ch2predictor_predict       (    ch2predictor_predict                       ),
	    .ch2predictor_taken         (    ch2predictor_taken                         ) 
    
    );

    rv3n_gsr i_gsr
    (   
        .clk                        (    clk                                        ),
    	.rst                        (    rst                                        ),
    
	    .id2gsr_rs0_order           (    id2gsr_rs0_order                           ),
	    .id2gsr_rs1_order           (    id2gsr_rs1_order                           ),
	    .gsr2id_rs0_data            (    gsr2id_rs0_data                            ),
	    .gsr2id_rs1_data            (    gsr2id_rs1_data                            ),
    
        .ch2gsr_order               (    ch2gsr_order                               ),
    	.ch2gsr_data	            (    chain_rd_lookup_data[`IDX(`CHAIN_LEN-1,`PNUM*`XLEN)]    )		
 
    );

    rv3n_csr i_csr
    (   
        .clk                        (    clk                                        ),
    	.rst                        (    rst                                        ),
  
        .func_csr_req_valid         (    func_calc_req_valid[`OP_NUM]               ),
		.func_csr_req_para          (    func_calc_req_para[`IDX(`OP_NUM,8)]        ),
		.func_csr_req_imm           (    func_calc_req_imm[`IDX(`OP_NUM,13)]        ),
		.func_csr_req_pc            (    func_calc_req_pc[`IDX(`OP_NUM,`XLEN)]      ),
		.func_csr_req_operand0      (    func_calc_req_operand0[`IDX(`OP_NUM,`XLEN)]),
		.func_csr_req_operand1      (    func_calc_req_operand1[`IDX(`OP_NUM,`XLEN)]),		
		.func_csr_ack_valid         (    func_csr_ack_valid                         ),
		.func_csr_ack_data          (    func_csr_ack_data                          ),
		.func_csr_ack_busy          (    func_csr_ack_busy                          ),
		
		.jump_jcond_valid           (    jump_jcond_valid                           ),
        .jump_jcond_pc              (    jump_jcond_pc                              ),		
    
        .jump_valid                 (    jump_valid                                 ),
		.jump_pc                    (    jump_pc                                    ),
        .stage_id_clear             (    stage_id_clear                             )
    
    ); 
	
	assign               func_calc_ack_valid[`OP_NUM] = func_lsu_ack_valid|func_csr_ack_valid;
	assign    func_calc_ack_data[`IDX(`OP_NUM,`XLEN)] = func_lsu_ack_data|func_csr_ack_data;
	assign                func_calc_ack_busy[`OP_NUM] = func_lsu_ack_busy|func_csr_ack_busy;
	assign                        forward_source_data = { func_lsu_shortcut_data,func_calc_ack_data[`OP_NUM*`XLEN-1:0] };
	

endmodule
