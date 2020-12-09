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

module rv3n_stage_ch
(

    input                               clk,
	input                               rst,
	
	input                               chain_step,
	input  `N(`CHPKG_LEN)               chain_package_in,
	output `N(`CHPKG_LEN)               chain_package_out,
	
	input  `N(`PNUM*`FUNC_NUM)          chain_authorized,
	input  `N(`PNUM*`XLEN)              chain_rs0_feed_data,
	input  `N(`PNUM*`XLEN)              chain_rs1_feed_data,
	input  `N(`PNUM*`XLEN)              chain_rd_feed_data,
	output `N(`PNUM*`XLEN)              chain_rd_lookup_data,
	
	output `N(`FUNC_NUM*8)              sub_calc_para,
	output `N(`FUNC_NUM*13)             sub_calc_imm,
	output `N(`FUNC_NUM*`XLEN)          sub_calc_pc,
	output `N(`FUNC_NUM*`XLEN)          sub_calc_operand0,
	output `N(`FUNC_NUM*`XLEN)          sub_calc_operand1

);


    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
	
	wire   `N(`CHPKG_LEN)               in_package;
    reg    `N(`CHPKG_LEN)               active_package;	
	wire   `N(`CHPKG_LEN)               out_package;	
	
	wire   `N(`PNUM*8)                  pkg_para;
	wire   `N(`PNUM*13)                 pkg_imm;
	wire   `N(`PNUM*`XLEN)              pkg_pc;	
	wire   `N(`PNUM*`XLEN)              pkg_rs0_data;
	wire   `N(`PNUM*`XLEN)              pkg_rs1_data;	
	wire   `N(`PNUM*`XLEN)              pkg_rd_data;
	wire   `N(`PNUM*`FUNC_NUM)          pkg_authorized;	

    genvar                              i,j;
    //---------------------------------------------------------------------------
    //statements description
    //---------------------------------------------------------------------------	

    //---------------------------------------------------------------------------
    //package 
    //---------------------------------------------------------------------------		
  
    assign                                                    in_package = chain_package_in; 

    `FFx(active_package,0)
	active_package <= chain_step ? in_package : out_package; 
	
    assign  {
	            pkg_para,
	            pkg_imm,
				pkg_pc,	            
	            pkg_rs0_data,
	            pkg_rs1_data,
				pkg_rd_data,
				pkg_authorized
            }                                                            = active_package;	

    assign    out_package = {
	            pkg_para,
	            pkg_imm,
				pkg_pc,	            
	            pkg_rs0_data|chain_rs0_feed_data,
	            pkg_rs1_data|chain_rs1_feed_data,
				pkg_rd_data|chain_rd_feed_data,
				chain_authorized			
            };

    assign                                             chain_package_out = out_package;			

    assign                                          chain_rd_lookup_data = pkg_rd_data|chain_rd_feed_data;	

    //---------------------------------------------------------------------------
    //func
    //---------------------------------------------------------------------------
	
	wire `N(`FUNC_NUM*8)         link_calc_para            `N(`PNUM+1);
	wire `N(`FUNC_NUM*13)        link_calc_imm             `N(`PNUM+1);
	wire `N(`FUNC_NUM*`XLEN)     link_calc_pc              `N(`PNUM+1);
	wire `N(`FUNC_NUM*`XLEN)     link_calc_operand0        `N(`PNUM+1);
	wire `N(`FUNC_NUM*`XLEN)     link_calc_operand1        `N(`PNUM+1);
	
	assign                                             link_calc_para[0] = 0;
	assign                                              link_calc_imm[0] = 0;
	assign                                               link_calc_pc[0] = 0;
	assign                                         link_calc_operand0[0] = 0;	
	assign                                         link_calc_operand1[0] = 0;	
	
	generate
	    for (i=0;i<`PNUM;i=i+1) begin:gen_stage_ch
            wire `N(`FUNC_NUM)                           authorized_bits = pkg_authorized>>(i*`FUNC_NUM);
			for (j=0;j<`FUNC_NUM;j=j+1) begin:gen_stage_ch_sub
			    wire                                      authorized_one = authorized_bits>>j;
                assign                    link_calc_para[i+1][`IDX(j,8)] = link_calc_para[i][`IDX(j,8)]|( {8{authorized_one}} & pkg_para[`IDX(i,8)] );
                assign                    link_calc_imm[i+1][`IDX(j,13)] = link_calc_imm[i][`IDX(j,13)]|( {13{authorized_one}} & pkg_imm[`IDX(i,13)] );
                assign                  link_calc_pc[i+1][`IDX(j,`XLEN)] = link_calc_pc[i][`IDX(j,`XLEN)]|( {`XLEN{authorized_one}} & pkg_pc[`IDX(i,`XLEN)] );
                assign            link_calc_operand0[i+1][`IDX(j,`XLEN)] = link_calc_operand0[i][`IDX(j,`XLEN)]|( {`XLEN{authorized_one}} & pkg_rs0_data[`IDX(i,`XLEN)] );	
                assign            link_calc_operand1[i+1][`IDX(j,`XLEN)] = link_calc_operand1[i][`IDX(j,`XLEN)]|( {`XLEN{authorized_one}} & pkg_rs1_data[`IDX(i,`XLEN)] );					
            end
	    end
	endgenerate
	
    assign                                                 sub_calc_para = link_calc_para[`PNUM];
	assign                                                  sub_calc_imm = link_calc_imm[`PNUM];
	assign                                                   sub_calc_pc = link_calc_pc[`PNUM];
    assign                                             sub_calc_operand0 = link_calc_operand0[`PNUM];	
    assign                                             sub_calc_operand1 = link_calc_operand1[`PNUM];
endmodule

