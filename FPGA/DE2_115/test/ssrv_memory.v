
`include "define.v"


module ssrv_memory
 (

    input                                      clk,
	input                                      rst,

    input                                      imem_req,
	input  `N(`XLEN)                           imem_addr,
	output                                     imem_resp,
	output `N(`XLEN)                           imem_rdata,
	output                                     imem_err,

	input                                      dmem_req,
	input                                      dmem_cmd,
	input  `N(2)                               dmem_width,
	input  `N(`XLEN)                           dmem_addr,
	input  `N(`XLEN)                           dmem_wdata,
	output `N(`XLEN)                           dmem_rdata,
	output                                     dmem_resp,
    output                                     dmem_err	

);

    wire            rden_a = imem_req & ( imem_addr[31:16]==0 );
    wire `N(14)     addr_a = imem_addr[15:0]>>2;
   
    reg   delay_rden_a;
    `FFx(delay_rden_a,0)
    delay_rden_a <= rden_a;
   
    assign       imem_resp = delay_rden_a;
    assign        imem_err = 1'b0;
   
    wire            rden_b = dmem_req & ( dmem_addr[31:16]==0 ) & ~dmem_cmd;
    wire            wren_b = dmem_req & ( dmem_addr[31:16]==0 ) &  dmem_cmd;
    wire `N(14)     addr_b = dmem_addr[15:0]>>2;
    wire `N(4)   byteena_b = (dmem_width==2) ? 4'b1111 : ( (dmem_width==1) ? ( 2'b11<<{dmem_addr[1],1'b0} ) : (1'b1<<dmem_addr[1:0]) );
    wire `N(`XLEN)  data_b = (dmem_width==2) ? dmem_wdata : ( (dmem_width==1) ? {2{dmem_wdata[15:0]}} : {4{dmem_wdata[7:0]}} );
	
	wire `N(`XLEN)  q_b;
	
	reg `N(4)  dmem_para;
	`FFx(dmem_para,0)
	dmem_para <= { dmem_width,dmem_addr[1:0] };
	
	assign      dmem_rdata = (dmem_para[3:2]==2) ? q_b : ( (dmem_para[3:2]==1) ? ( q_b>>(`HLEN*dmem_para[1]) ) : ( q_b>>(8*dmem_para[1:0]) ) );
	
	reg    dmem_ack;
	`FFx(dmem_ack,0)
	dmem_ack <= rden_b|wren_b;
	
	assign       dmem_resp = dmem_ack;
	
	assign        dmem_err = 1'b0;
		
    dualram i_dram (
	    .address_a    (    addr_a                      ),
	    .address_b    (    addr_b                      ),
	    .byteena_b    (    byteena_b                   ),
	    .clock        (    clk                         ),
	    .data_a       (    32'h0                       ),
	    .data_b       (    data_b                      ),
	    .rden_a       (    rden_a                      ),
	    .rden_b       (    rden_b                      ),
	    .wren_a       (    1'b0                        ),
	    .wren_b       (    wren_b                      ),
	    .q_a          (    imem_rdata                  ),
	    .q_b          (    q_b                         )
	);	

endmodule