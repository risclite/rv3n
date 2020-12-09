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

module rv3n_stage_dc
(   
    input                               clk,
	input                               rst,
	
    output                              dc2if_new_valid,
	output `N(`XLEN)                    dc2if_new_pc,
	output                              dc2if_continue,	
	
	input                               if2dc_valid,
	input  `N(`INUM*`XLEN)              if2dc_rdata,
	input                               if2dc_err,
	input  `N(`INUM*2)                  if2dc_predict,	
	
	input                               jump_valid,
	input  `N(`XLEN)                    jump_pc,
	
	input                               id2dc_ready,
	output `N(`PNUM)                    dc2id_valid,
	output `N(`PNUM*`XLEN)              dc2id_instr,
	output `N(`PNUM)                    dc2id_predict,
	output `N(`PNUM*`DC_LEN)            dc2id_arguments,
	output `N(`PNUM*`XLEN)              dc2id_pc

);

    `include "include_func.v"

    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
    localparam                          BUFF_NUM  = 3,                  //INUM*XLEN
	                                    BUFF_SIZE = BUFF_NUM*`INUM*2,   // HLEN
	                                    BUFF_OFF  = $clog2(BUFF_SIZE+1);
	
	reg   `N(BUFF_SIZE*`HLEN)           buffer_data;
    reg	  `N(BUFF_SIZE)                 buffer_err;
	reg   `N(BUFF_SIZE)                 buffer_predict;
	reg   `N(BUFF_OFF)                  buffer_length;
	reg   `N(`XLEN)                     buffer_pc;
	
	reg   `N($clog2(2*`INUM))           imem_offset;

    wire `N($clog2(`PNUM*2+1))          fetch_index    `N(`PNUM+1);
    wire `N($clog2(`PNUM*2+1))          fetch_hlen     `N(`PNUM+1);	
	wire                                break_valid    `N(`PNUM+1);
	wire `N(`XLEN)                      break_pc       `N(`PNUM+1);  
    wire `N(21)                         break_offset   `N(`PNUM+1);

    genvar                              i;
    //---------------------------------------------------------------------------
    //statements description
    //---------------------------------------------------------------------------

    `FFx(imem_offset,0)
	if ( dc2if_new_valid )
	    imem_offset <= dc2if_new_pc>>1;
	else if ( if2dc_valid )
	    imem_offset <= 0;
	else;

    wire `N(`INUM*`XLEN)                      imem_data = if2dc_valid ? ( if2dc_rdata>>(imem_offset*`HLEN) ) : 0;
    wire `N(`INUM*2)                           imem_err = if2dc_valid ? ( {(`INUM*2){if2dc_err}}>>imem_offset ) : 0;
    wire `N(`INUM*2)                       imem_predict = if2dc_valid ? ( if2dc_predict>>imem_offset ) : 0;
    wire `N($clog2(`INUM*2+1))              imem_length = if2dc_valid ? ( (2*`INUM) - imem_offset ) : 0;

    assign                               fetch_index[0] = 0;
	assign                                fetch_hlen[0] = 0;
    assign                               break_valid[0] = 0;
	assign                                  break_pc[0] = 0;
	assign                              break_offset[0] = 0;

    generate
	    for (i=0;i<`PNUM;i=i+1) begin:gen_out_instr
		    //basic info
			wire `N(`XLEN)                        instr = buffer_data>>(fetch_index[i]*`HLEN);
			assign                     fetch_index[i+1] = fetch_index[i] + (1'b1<<(instr[1:0]==2'b11));
			wire                                  valid = (fetch_index[i+1]<=buffer_length);
            wire `N(`XLEN)                           pc = buffer_pc + ( fetch_index[i]<<1 );
            wire `N(2)                             errs = buffer_err>>fetch_index[i];
            wire                                    err = (instr[1:0]==2'b11) ? (|errs) : (errs[0]);
            wire                                predict = buffer_predict>>fetch_index[i];
			assign                      fetch_hlen[i+1] = valid ? fetch_index[i+1] : fetch_hlen[i]; 

			//dc2id
			assign                       dc2id_valid[i] = valid;
            assign           dc2id_instr[`IDX(i,`XLEN)] = instr;
            assign                     dc2id_predict[i] = predict;
 			assign     dc2id_arguments[`IDX(i,`DC_LEN)] = riscv_decoder(instr,err);
			assign              dc2id_pc[`IDX(i,`XLEN)] = pc;

            //break
			wire                             break_flag;
			wire `N(21)                      break_immediate;
			assign      { break_flag,break_immediate } = jal_jcond_combo(instr,predict);
			assign                    break_valid[i+1] = break_valid[i]|(valid & break_flag);
			assign                       break_pc[i+1] = break_valid[i] ? break_pc[i] : pc;
			assign                   break_offset[i+1] = break_valid[i] ? break_offset[i] : break_immediate;
	    end
	endgenerate

    wire `N($clog2(`PNUM*2+1))            fetch_offset = id2dc_ready ? fetch_hlen[`PNUM] : 0;
	wire `N(BUFF_OFF)                    buffer_offset = buffer_length - fetch_offset; 
    wire `N(BUFF_OFF)               buffer_next_length = buffer_offset + imem_length;	

    assign                             dc2if_new_valid = jump_valid|(break_valid[`PNUM] & id2dc_ready);
	assign                                dc2if_new_pc = jump_valid ? jump_pc : ( break_pc[`PNUM] + { {11{break_offset[`PNUM][20]}},break_offset[`PNUM] } );
	assign                              dc2if_continue = buffer_next_length <= ( BUFF_SIZE - 2*`INUM );

    `FFx(buffer_data,0)
	buffer_data <= dc2if_new_valid ? 0 : ( ( buffer_data>>(fetch_offset*`HLEN) )|( imem_data<<(buffer_offset*`HLEN) ) );
	
	`FFx(buffer_err,0)
	buffer_err <= dc2if_new_valid ? 0 : ( ( buffer_err>>fetch_offset )|( imem_err<<buffer_offset ) );
	
	`FFx(buffer_predict,0)
	buffer_predict <= dc2if_new_valid ? 0 : ( ( buffer_predict>>fetch_offset )|( imem_predict<<buffer_offset ) );
	
	`FFx(buffer_length,0)
	buffer_length <= dc2if_new_valid ? 0 : buffer_next_length;
	
	`FFx(buffer_pc,0)
	buffer_pc <= dc2if_new_valid ? (dc2if_new_pc & ({`XLEN{1'b1}}<<1)) : ( buffer_pc + ( fetch_offset<<1 ) );	

endmodule
