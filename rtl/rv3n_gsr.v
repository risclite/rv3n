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

module rv3n_gsr
(   
    input                               clk,
	input                               rst,

	input  `N(`PNUM*`RGBIT)             id2gsr_rs0_order,
	input  `N(`PNUM*`RGBIT)             id2gsr_rs1_order,
	output `N(`PNUM*`XLEN)              gsr2id_rs0_data,
	output `N(`PNUM*`XLEN)              gsr2id_rs1_data,

    input  `N(`PNUM*`RGBIT)             ch2gsr_order,
	input  `N(`PNUM*`XLEN)              ch2gsr_data	

);

    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
    reg    `N(`XLEN)                rg_file            `N(32);
	
    genvar    i;
    //---------------------------------------------------------------------------
    //statements description
    //---------------------------------------------------------------------------

    generate
        for (i=0;i<32;i=i+1)begin:gen_rg_file
	        `FFx(rg_file[i],0) begin:ff_rg_file
	    	    integer j;
	    		for (j=0;j<`PNUM;j=j+1) begin
	    		    if ( ( ch2gsr_order[`IDX(`PNUM-1-j,`RGBIT)]!=0 ) & ( ch2gsr_order[`IDX(`PNUM-1-j,`RGBIT)]==i ) )
	    			    rg_file[i] <= ch2gsr_data[`IDX(`PNUM-1-j,`XLEN)];
	    		end
	    	end
        end
    endgenerate	

    generate
	    for (i=0;i<`PNUM;i=i+1) begin:gen_fetch_rf
	        wire `N(`RGBIT)                   rs0 = id2gsr_rs0_order>>(i*`RGBIT);
			wire `N(`RGBIT)                   rs1 = id2gsr_rs1_order>>(i*`RGBIT);
			assign gsr2id_rs0_data[`IDX(i,`XLEN)] = rg_file[rs0];
			assign gsr2id_rs1_data[`IDX(i,`XLEN)] = rg_file[rs1];			
	    end
    endgenerate

endmodule



