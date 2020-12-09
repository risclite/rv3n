
`include "define.v"
module tb;

    //---------------------------------------------------------------------------
    //clock & reset gnerator
    //---------------------------------------------------------------------------

    localparam    PERIOD  = 10;
	localparam    HALF_PERIOD = PERIOD>>1;
	reg         rst = 1'b1;
    reg         clk = 1'b0;
	
	initial begin
	    #(10*PERIOD)  rst = 1'b0;
	end
	
	always begin
	    clk = #(HALF_PERIOD)   ~clk;
	end

    //---------------------------------------------------------------------------
    //dut
    //---------------------------------------------------------------------------
	
	localparam  IMEM_LEN = `INUM;
	
	wire                          imem_req;
	wire `N(`XLEN)                imem_addr;
	wire `N(IMEM_LEN*`XLEN)       imem_rdata;
	wire                          imem_resp;
	wire                          imem_err;
	
	wire                          dmem_req;
	wire                          dmem_cmd;
	wire `N(2)                    dmem_width;
	wire `N(`XLEN)                dmem_addr;
	wire `N(`XLEN)                dmem_wdata;
	wire `N(`XLEN)                dmem_rdata;
	wire                          dmem_resp;
	wire                          dmem_err;
	
	
    rv3n_top dut(
        .clk                    (    clk                ),
    	.rst                    (    rst                ),
        // instruction memory interface	
        .imem_req               (    imem_req           ),
        .imem_addr              (    imem_addr          ),
        .imem_rdata             (    imem_rdata         ),
        .imem_resp              (    imem_resp          ),
		.imem_err               (    imem_err           ),
        // Data memory interface
        .dmem_req               (    dmem_req           ),
        .dmem_cmd               (    dmem_cmd           ),
        .dmem_width             (    dmem_width         ),
        .dmem_addr              (    dmem_addr          ),
        .dmem_wdata             (    dmem_wdata         ),
        .dmem_rdata             (    dmem_rdata         ),
        .dmem_resp              (    dmem_resp          ),
        .dmem_err               (    dmem_err           )		
    );	
	
    //---------------------------------------------------------------------------
    //imem memory
    //---------------------------------------------------------------------------	
	
	localparam [3:0] IMEM_STALL_DEFINITION = 4'h0;
		
	localparam   MEMSIZE = (1<<16)-1;
	reg `N(8)    memory `N(MEMSIZE);
	
	//imem reading
	reg `N(16)     imem_starting_addr;
	`FFx(imem_starting_addr,0)
	imem_starting_addr <= imem_req ? imem_addr : imem_starting_addr;
	
	reg `N(IMEM_LEN*`XLEN) imem_outcome;
	always @(*) begin:comb_imem_outcome
	    integer   i;
		imem_outcome = 0;
		for (i=0;i<(IMEM_LEN*4);i=i+1)
	       imem_outcome[`IDX(i,8)] = memory[imem_starting_addr+i];
	end
	
	assign              imem_rdata = imem_outcome;
	
	reg [3:0] imem_stall_time;
	always @ ( posedge clk or posedge rst ) begin
	    if ( rst )
		    imem_stall_time <= IMEM_STALL_DEFINITION;
		else if ( imem_req )
		    imem_stall_time <= ( IMEM_STALL_DEFINITION==4'hF ) ? $random : IMEM_STALL_DEFINITION;
		else;
	end	
	
	reg [3:0] imem_stall_count;
	always @ ( posedge clk or posedge rst ) begin
	    if ( rst )
		    imem_stall_count <= IMEM_STALL_DEFINITION;
        else if ( imem_req )
            imem_stall_count <= 0;
        else if ( imem_stall_count<imem_stall_time )
            imem_stall_count <= imem_stall_count + 1;
        else;			
	end
	
	assign               imem_resp = imem_stall_count==imem_stall_time;
	assign                imem_err = 1'b0;

    //---------------------------------------------------------------------------
    //dmem memory reading
    //---------------------------------------------------------------------------	

	localparam [3:0] DMEM_STALL_DEFINITION = 4'h0;
	
	//dmem reading
    wire              dmem_read_en = dmem_req & ~dmem_cmd;
    
    reg `N(16)       dmem_read_starting_addr;
	reg `N(2)        dmem_read_size;
	`FFx(dmem_read_starting_addr,0)
	dmem_read_starting_addr <= dmem_read_en ? dmem_addr : dmem_read_starting_addr;
	
	`FFx(dmem_read_size,0)
	dmem_read_size <= dmem_read_en ? dmem_width : dmem_read_size;
	
	reg `N(`XLEN)    dmem_outcome;
	always @(*) begin:comb_dmem_outcome
	    integer   i;
		reg `N(`XLEN)  mask;
		mask = (dmem_read_size==2) ? {`XLEN{1'b1}} : ( (dmem_read_size==1) ? {`HLEN{1'b1}} : {8{1'b1}} );
		dmem_outcome = 0;
		for (i=0;i<4;i=i+1)
		    dmem_outcome[`IDX(i,8)] = (memory[dmem_read_starting_addr+i]===8'hxx) ? 8'h00 : memory[dmem_read_starting_addr+i];
		dmem_outcome = dmem_outcome & mask;
	end
	
	assign            dmem_rdata = dmem_outcome;	
	
	reg [3:0] dmem_stall_time;
	always @ ( posedge clk or posedge rst ) begin
	    if ( rst )
		    dmem_stall_time <= DMEM_STALL_DEFINITION;
		else if ( dmem_req )
		    dmem_stall_time <= ( DMEM_STALL_DEFINITION==4'hF ) ? $random : DMEM_STALL_DEFINITION;
		else;
	end	
	
	reg [3:0] dmem_stall_count;
	always @ ( posedge clk or posedge rst ) begin
	    if ( rst )
		    dmem_stall_count <= DMEM_STALL_DEFINITION;
        else if ( dmem_req )
            dmem_stall_count <= 0;
        else if ( dmem_stall_count<dmem_stall_time )
            dmem_stall_count <= dmem_stall_count + 1;
        else;			
	end	
	
	assign             dmem_resp = dmem_stall_count==dmem_stall_time;
    assign              dmem_err = 1'b0;	
	
    //---------------------------------------------------------------------------
    //dmem memory writing
    //---------------------------------------------------------------------------		
	
	//dmem writing
	wire             dmem_write_en = dmem_req & dmem_cmd;
	wire                dmem_print = dmem_write_en & ( dmem_addr==32'hF000_0000 );
	
	always @ ( posedge clk )
	if ( dmem_print )
	    $write("%c",dmem_wdata[7:0]);
	else;
	
	always @ ( posedge clk )
	if ( dmem_req & (dmem_addr[31:16]!=0) & ~dmem_print )
	    ;//$display("---DMEM %s %d %8h %8h",dmem_cmd ? "WRITE":"READ",dmem_width,dmem_addr,dmem_wdata);
	else;
	
	wire         dmem_write_to_mem = dmem_write_en & (dmem_addr[31:16]==0);

    always @ ( posedge clk )
	if ( dmem_write_to_mem ) begin
	    if ( dmem_width==2 ) begin
		    memory[dmem_addr[15:0]+0] <= dmem_wdata[`IDX(0,8)];
            memory[dmem_addr[15:0]+1] <= dmem_wdata[`IDX(1,8)];	
           	memory[dmem_addr[15:0]+2] <= dmem_wdata[`IDX(2,8)];	
			memory[dmem_addr[15:0]+3] <= dmem_wdata[`IDX(3,8)];
	    end else if ( dmem_width==1 ) begin
		    memory[dmem_addr[15:0]+0] <= dmem_wdata[`IDX(0,8)];
            memory[dmem_addr[15:0]+1] <= dmem_wdata[`IDX(1,8)];				
		end else begin
		    memory[dmem_addr[15:0]] <= dmem_wdata[`IDX(0,8)];
		end
	end
	
    //---------------------------------------------------------------------------
    //simulation control
    //---------------------------------------------------------------------------	
	
	wire   sim_signal = ( dut.dc2if_new_valid & ( dut.dc2if_new_pc==32'hf8) ); 
	wire   sim_pass   = ~dut.i_gsr.rg_file[10];
	
	reg  sim_exit = 0;  
	always @ ( posedge sim_signal ) begin
	    if ( sim_signal ) begin
		    #2 if ( sim_signal ) begin
		        #(20*PERIOD) sim_exit <= 1;
			    #(PERIOD) sim_exit <= 0;
			end
	    end
	end
	
	task load_memory;
	    input `N(512)  file_name;
	    begin
		    $readmemh(file_name, memory);
		end
	endtask
	
	task  reset_dut;
	    begin
		    @(posedge clk);
			rst  = 1'b1;
			repeat(10) @(posedge clk);
			#(HALF_PERIOD) rst = 1'b0;
		end
	endtask
	
	task verify_file;
	    input `N(512)  file_name;
		reg   `N(512)  hex_name;
		integer        byte_length,i;
		begin
		    byte_length = 0;
			for (i=0;i<32;i=i+1) 
			    byte_length = byte_length + (file_name[`IDX(i,8)]!=0);
		
            hex_name = (("../build/")<<(byte_length*8))|file_name;	
		    $display("---The test hex file : %s",hex_name);
            load_memory(hex_name);
            reset_dut;
            while(~sim_exit) 
			@(posedge clk);
            $display("---This test is %s!!!\n\n\n",sim_pass ? "PASSED" : "FAILED");
            if ( ~sim_pass ) $stop(1);			
		end
	endtask
		
	localparam  TEST_LIST = "test_list.txt";
	
    initial begin:main_block
	    integer         fd_main;
        integer         status;	
        reg `N(512)     file_name;
    	reg             continue_flag;
    	
        fd_main     = $fopen(TEST_LIST,"r");
    	
		if (fd_main==0) begin
     		$display("There is no test list file..."); 
			$stop(1); 
		end
    	
		status = $fgetc(fd_main);
    	
		while (status!=32'hffffffff) begin
    	    while( (status=="\n")|(status==" ") ) begin
    			status = $fgetc(fd_main);
    		end
		    continue_flag  = ~( status == 32'hffffffff );	
    	    if ( status == "/" ) begin
    	        status = $fgetc(fd_main);
                if ( status == "/" ) begin  
                    status = $fgetc(fd_main);
                    while ( (status!="\n")&(status!=32'hffffffff) )
                        status = $fgetc(fd_main);
    				continue_flag = 0;	
                end
                else begin
                    status = $ungetc(status,fd_main);
    				status = $ungetc(status,fd_main);
                end	
			end else if ( status == "#" ) begin
                status = $fgetc(fd_main);
                while ( (status!="\n")&(status!=32'hffffffff) )
                    status = $fgetc(fd_main);
			    continue_flag = 0;		
            end else begin
                status = $ungetc(status,fd_main);
            end	
            if ( continue_flag ) begin		
    	        status = $fscanf(fd_main,"%s",file_name);
    		    $display("A test hex file : %s",file_name);
    	        verify_file(file_name);
    		end
            status = $fgetc(fd_main);		
    	end
        $stop(1);
    end	
   
    /*
    integer fd_event,fd_time;
    initial begin
        fd_event = $fopen("event.txt","w");
    	fd_time  = $fopen("time.txt","w");
    end
    
    always @ (posedge clk)
    if ( dut.dmem_req & ~rst ) begin
        $fdisplay(fd_event,"%1h---%8h---%8h",dut.dmem_cmd,dut.dmem_addr,dut.dmem_cmd ? dut.dmem_wdata : 32'h0);
        $fdisplay(fd_time,"%d",$time);		
    end
    */

endmodule
