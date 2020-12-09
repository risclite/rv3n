/////////////////////////////////////////////////////////////////////////////////////
//
//Copyright 2019  Li Xinbing
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

   parameter  `N(6)         OP_ADD   = 6'b000_000,
							OP_SLT   = 6'b000_001,
							OP_SLTU  = 6'b000_010,
							OP_XOR   = 6'b000_011,
							OP_OR    = 6'b000_100,
							OP_AND   = 6'b000_101,

	                        OP_SUB   = 6'b001_000,							
							OP_SLL   = 6'b010_000,
							OP_SRL   = 6'b011_000,
							OP_SRA   = 6'b100_000,   

                            BR_EQ    = 6'b111_000,
							BR_NE    = 6'b111_001,
							BR_LT    = 6'b111_010,
							BR_GE    = 6'b111_011,
							BR_LTU   = 6'b111_100,
							BR_GEU   = 6'b111_101;

							
    function `N(`DC_LEN)          riscv_decoder(input `N(`XLEN) instr,input err);
	    reg                       instr_err, instr_illegal, instr_sys, instr_jalr, instr_jal, instr_csr, instr_lsu, instr_muldiv, instr_jcond, instr_op, instr_fencei;
		reg `N(4)                 instr_para;
		reg `N(6)                 op_sel;
		reg                       rs0_pc_sel;
		reg                       rs1_imm_sel;
		reg                       ld_bypass;
		reg `N(13)                extra_imm;
		reg `N(`XLEN)             rs1_immediate;
		reg `N(`RGBIT)            rd_order,rs1_order,rs0_order;
		
		reg                       instr_super;
		reg                       rs1_imm_selx;
		reg `N(`XLEN)             rs1_immediatex;
		reg                       attr_clu,attr_muldiv,attr_jcond,attr_op;
		reg `N(4)                 super_para;
		reg `N(6)                 clu_para;
		reg `N(7)                 ch_para;
		reg `N(13)                ch_imm;
		begin
		    instr_err         = err;
		    instr_illegal     = 0;
			instr_sys         = 0;
			instr_jalr        = 0;
			instr_jal         = 0;
			instr_csr         = 0;
			instr_lsu         = 0;
			instr_muldiv      = 0;
			instr_jcond       = 0;
			instr_op          = 0;
			instr_fencei      = 0;
			
			instr_para        = {instr[5],instr[14:12]};
			op_sel            = OP_ADD;
			rs0_pc_sel        = 0;
			rs1_imm_sel       = 0;
			ld_bypass         = 0;
			extra_imm         = 0;
			rs1_immediate     = 0;
			
			rd_order          = 0;
			rs1_order         = 0;
			rs0_order         = 0;
			
			if ( instr[1:0]==2'b11 ) begin
			
				case(instr[6:2])
				5'b01101 :                        //LUI
				            begin
					            instr_op        = 1;
							    op_sel          = OP_ADD;								
								rs1_imm_sel     = 1;
								rs1_immediate   = { instr[31:12],12'b0 };
					        	rd_order        = instr[11:7];
					        end
				5'b00101 :                        //AUIPC
				            begin
					            instr_op        = 1;
								op_sel          = OP_ADD;
								rs0_pc_sel      = 1;
								rs1_imm_sel     = 1;
								rs1_immediate   = { instr[31:12],12'b0 };
					        	rd_order        = instr[11:7];						    
					        end
                5'b11011 :                        //JAL
                            begin
					            instr_jal       = 1;
								instr_op        = instr[11:7]!=0;
								op_sel          = OP_ADD;
								rs0_pc_sel      = 1;
								rs1_imm_sel     = 1;
								rs1_immediate   = 4;
					        	rd_order        = instr[11:7];                            
                            end
                5'b11001 :                       //JALR
                            begin
					            instr_jalr      = 1;
								instr_op        = instr[11:7]!=0;
								op_sel          = OP_ADD;
								rs1_imm_sel     = 1;
								rs1_immediate   = 4;
								extra_imm       = { instr[31],instr[31:20] };
					        	rd_order        = instr[11:7];
                                rs0_order       = instr[19:15];                            
                            end	
                5'b11000 :                       //BRANCH
                            begin
                                instr_jcond     = 1;								
								rs0_order       = instr[19:15];
								rs1_order       = instr[24:20];
								extra_imm       = { instr[31],instr[7],instr[30:25],instr[11:8],1'b0 };
								
								case(instr[14:12])
								3'd0 :   op_sel = BR_EQ;
								3'd1 :   op_sel = BR_NE;
								3'd4 :   op_sel = BR_LT;
								3'd5 :   op_sel = BR_GE;
								3'd6 :   op_sel = BR_LTU;
								3'd7 :   op_sel = BR_GEU;
								endcase
								
                            end								
				5'b00000 :                       //LOAD
				            begin
				                instr_lsu       = 1;
								rd_order        = instr[11:7];
								rs0_order       = instr[19:15];
								extra_imm       = { instr[31],instr[31:20] };
				                instr_illegal   = (instr[14:12]==3'b011)|(instr[14:12]==3'b110)|(instr[14:12]==3'b111);
				            end
				5'b01000 :                       //STORE			
				            begin
				                instr_lsu       = 1;
								rs0_order       = instr[19:15];
								rs1_order       = instr[24:20];
								extra_imm       = { instr[31],instr[31:25],instr[11:7] };
				                instr_illegal   = (instr[14:12]>=3'b011);
				            end								
				5'b00100 :                       //OP_IMM
                            begin
				                instr_op        = 1;
								rd_order        = instr[11:7];
								rs0_order       = instr[19:15]; 
                                rs1_imm_sel     = 1;
                                rs1_immediate   = { {21{instr[31]}},instr[30:20] };								
                                instr_illegal   = (instr[14:12]==3'b001) ? (instr[31:25]!=7'b0) : ( (instr[14:12]==3'b101) ?  ( ~( (instr[31:25]==7'b0000000)|(instr[31:25]==7'b0100000) ) ) : 0 );
								
								case(instr[14:12])
								3'd0: op_sel    = OP_ADD;
								3'd1: op_sel    = OP_SLL;
								3'd2: op_sel    = OP_SLT;
								3'd3: op_sel    = OP_SLTU;
								3'd4: op_sel    = OP_XOR;
								3'd5: op_sel    = instr[30] ? OP_SRA : OP_SRL; 
								3'd6: op_sel    = OP_OR;
								3'd7: op_sel    = OP_AND;
								endcase
                            end	
                5'b01100 :                       //OP
                            begin
							    instr_muldiv    =  instr[25];
				                instr_op        = ~instr[25];
								rd_order        = instr[11:7];
								rs0_order       = instr[19:15];       
                                rs1_order       = instr[24:20];	
								
                                if ( instr[31:25]==7'b0000000 )
								    instr_illegal = 0;
								else if ( instr[31:25]==7'b0100000 )
								    instr_illegal = ~( (instr[14:12]==3'b000)|(instr[14:12]==3'b101) );
								else if ( instr[31:25]==7'b0000001 )
								    instr_illegal = 0;
								else 
								    instr_illegal = 1;

								case(instr[14:12])
								3'd0: op_sel    = instr[30] ? OP_SUB : OP_ADD;
								3'd1: op_sel    = OP_SLL;
								3'd2: op_sel    = OP_SLT;
								3'd3: op_sel    = OP_SLTU;
								3'd4: op_sel    = OP_XOR;
								3'd5: op_sel    = instr[30] ? OP_SRA : OP_SRL; 
								3'd6: op_sel    = OP_OR;
								3'd7: op_sel    = OP_AND;
								default: op_sel = OP_ADD;
								endcase	
                            end	
				5'b00011 :                      //MISC_MEM
				            begin
							    instr_fencei = instr[12];
								//fencei = i[12];
								//fence  = ~i[12];
								if ( instr[14:12]==3'b000 )
								    instr_illegal = |{instr[31:28], instr[19:15], instr[11:7]};
							    else if ( instr[14:12]==3'b001 )
								    instr_illegal = |{instr[31:15], instr[11:7]};
								else
								    instr_illegal = 1;
							end
				5'b11100 :                    //ECALL/EBREAK/CSRR
				            begin
							    if ( instr[14:12]==3'b000 ) begin
								    instr_sys = 1;
									if ( {instr[19:15], instr[11:7]}==10'b0 )
									    instr_illegal = ~( (instr[31:20]==12'h000)|(instr[31:20]==12'h001)|(instr[31:20]==12'h302)|(instr[31:20]==12'h105) );
									else 
									    instr_illegal = 1;
								end else begin
								    instr_csr     = 1;
									rd_order      = instr[11:7];
									rs0_order     = instr[14] ? 5'h0 : instr[19:15];
									rs1_imm_sel   = 1;
									rs1_immediate = instr;
								    instr_illegal = (instr[14:12]==3'b100);
							    end
							end
				default  :  instr_illegal = 1;		
				
				endcase			
			end else begin
`ifdef RV32C
                case({instr[15:13],instr[1:0]})                                            
                5'b000_00:   //C.ADDI4SPN
				            begin
							    instr_op        = 1;
								rd_order        = {2'b1,instr[4:2]};
								rs0_order       = 5'h2;
								rs1_imm_sel     = 1;
								rs1_immediate   = { instr[10:7],instr[12:11],instr[5],instr[6],2'b0 };
								op_sel          = OP_ADD;
								instr_illegal   = ~(|instr[12:5]);
							end
                5'b010_00:   //C.LW
				            begin
							    instr_lsu       = 1;
								rd_order        = {2'b1,instr[4:2]};
								rs0_order       = {2'b1,instr[9:7]};
								instr_para      = { 1'b0, 3'b010 };
								extra_imm       = {instr[5],instr[12:10],instr[6],2'b0};
							end
                5'b110_00:   //C.SW
				            begin
							    instr_lsu       = 1;
								rs0_order       = {2'b1,instr[9:7]};
								rs1_order       = {2'b1,instr[4:2]};
								instr_para      = { 1'b1, 3'b010 };
								extra_imm       = {instr[5],instr[12:10],instr[6],2'b0};
							end
                5'b000_01:   //C.ADDI
                            begin
                                instr_op        = 1;
								rd_order        = instr[11:7];
								rs0_order       = instr[11:7];
								rs1_imm_sel     = 1;
								op_sel          = OP_ADD;
								rs1_immediate   = { {27{instr[12]}},instr[6:2] };
                            end								
                5'b001_01:   //C.JAL	
                            begin
                                instr_jal       = 1;
								instr_op        = 1;
								op_sel          = OP_ADD;
								rs0_pc_sel      = 1;
								rs1_imm_sel     = 1;
								rs1_immediate   = 2;								
								rd_order        = 5'h1;
                            end								
                5'b010_01:   //C.LI
				            begin
							    instr_op        = 1;
							    op_sel          = OP_ADD;								
								rs1_imm_sel     = 1;
								rs1_immediate   = { {27{instr[12]}},instr[6:2] };								
								rd_order        = instr[11:7];
							end
                5'b011_01:   //C.ADDI16SP/C.LUI
                            begin
							    instr_op        = 1;
								rd_order        = instr[11:7];
								rs0_order       = (instr[11:7]==5'h2) ? 5'h2 : 5'h0;
								rs1_imm_sel     = 1;
								rs1_immediate   = (instr[11:7]==5'd2) ?  { {23{instr[12]}},instr[4:3],instr[5],instr[2],instr[6],4'b0 } : { {15{instr[12]}},instr[6:2],12'b0 };
								op_sel          = OP_ADD;
								instr_illegal   = ~(|{instr[12], instr[6:2]});
							end
				5'b100_01:  
             				if (instr[11:10]!=2'b11)      //C.SRLI/C.SRAI/C.ANDI
                                begin
							        instr_op      = 1;
									rd_order      = {2'b1,instr[9:7]};
									rs0_order     = {2'b1,instr[9:7]};
									rs1_imm_sel   = 1;
									rs1_immediate = { {27{instr[12]}},instr[6:2] };
									instr_illegal = ~instr[11] & instr[12];
									
									case(instr[11:10])
									2'd0 : op_sel = OP_SRL;
									2'd1 : op_sel = OP_SRA;
									2'd2 : op_sel = OP_AND;
									endcase
									
							    end
							else //C.SUB/C.XOR/C.OR/C.AND
							    begin
								    instr_op      = 1;
									rd_order      = {2'b1,instr[9:7]};
									rs0_order     = {2'b1,instr[9:7]};
									rs1_order     = {2'b1,instr[4:2]};
									instr_illegal = instr[12];

                                    case({instr[12],instr[6:5]})
                                    3'd0 : op_sel = OP_SUB;
                                    3'd1 : op_sel = OP_XOR;
                                    3'd2 : op_sel = OP_OR;
                                    3'd3 : op_sel = OP_AND;
                                    default: op_sel = OP_SUB;
                                    endcase									
									
								end
                5'b101_01:   //C.J
				            begin
							    instr_jal       = 1;									
							end
                5'b110_01,                     
                5'b111_01:   //C.BEQZ/C.BNEZ
				            begin
							    instr_jcond     = 1;
								rs0_order       = {2'b1,instr[9:7]};
								op_sel          = instr[13] ? BR_NE : BR_EQ;
								extra_imm       = { {5{instr[12]}},instr[6:5],instr[2],instr[11:10],instr[4:3],1'b0};
							end
                5'b000_10:   //C.SLLI
				            begin
							    instr_op        = 1;
								rd_order        = instr[11:7];
								rs0_order       = instr[11:7];
								op_sel          = OP_SLL;
								rs1_imm_sel     = 1;
								rs1_immediate   = instr[6:2];
								instr_illegal   = instr[12];
							end
                5'b010_10:   //C.LWSP
				            begin
							    instr_lsu       = 1;
								rd_order        = instr[11:7];
								rs0_order       = 5'h2;
								instr_para      = { 1'b0, 3'b010  };
								extra_imm       = {instr[3:2],instr[12],instr[6:4],2'b0};
								instr_illegal   = ~(|instr[11:7]);
							end
                5'b100_10:   
				            if ( ~instr[12] & (instr[6:2]==5'h0) ) //C.JR
							    begin
                                    instr_jalr    = 1;
									rs0_order     = instr[11:7];
                                    instr_illegal = ~(|instr[11:7]);
                                end									
                            else if ( ~instr[12] & (instr[6:2]!=5'h0)  )  //C.MV
                                begin
								    instr_op      = 1;
									op_sel        = OP_ADD;
									rd_order      = instr[11:7];
									rs1_order     = instr[6:2];
								end
							else if((instr[11:7]==5'h0)&(instr[6:2]==5'h0)) //C.EBREAK
							    begin
								    instr_sys      = 1;
								end
                            else if (instr[6:2]==5'h0)        //C.JALR
                                begin
								    instr_jalr     = 1;
									instr_op       = 1;
									op_sel         = OP_ADD;
									rs1_imm_sel    = 1;
									rs1_immediate  = 2;
									rd_order       = 5'h1;
									rs0_order      = instr[11:7];
								end
							else                 //C.ADD 
							    begin
                                    instr_op       = 1;
									op_sel         = OP_ADD;
									rd_order       = instr[11:7];
									rs0_order      = instr[11:7];
									rs1_order      = instr[6:2];
                                end									
                5'b110_10:   //C.SWSP
				            begin
							    instr_lsu       = 1;
								rs0_order       = 5'h2;
								rs1_order       = instr[6:2];
								instr_para      = { 1'b1, 3'b010  };
								extra_imm       = {instr[8:7],instr[12:9],2'b0};
							end
                default  :  instr_illegal = 1;
                endcase
`else
                instr_illegal = 1;
`endif					
			end
			
		    ld_bypass      = instr_lsu & ( ( instr_para==4'b0010 )|( instr_para==4'b0001 ) );
	
			//level0 : instr: instr_super,instr_jalr,instr_jal,instr_jcond,
			//level1 : rs0/1: rs0_order, rs0_pc_sel, rs1_order, rs1_imm_selx,rs1_immediatex,
			//level2 : attributes: attr_clu,attr_muldiv,attr_jcond, attr_op,ld_bypass,rd_order
			//level3 : pkg : para(7) imm(13), 
			
		    instr_super    = instr_err|instr_illegal|instr_sys|instr_fencei;
			
			rs1_imm_selx   = instr_super|rs1_imm_sel;
			rs1_immediatex = instr_super ? instr : rs1_immediate;
			
			attr_clu       = instr_super|instr_csr|instr_lsu;
			attr_muldiv    = instr_muldiv;
			attr_jcond     = instr_jcond|instr_jalr;
			attr_op        = instr_op;
			
			super_para     = { instr_err,instr_illegal,instr_sys };
			clu_para       = { instr_super,instr_csr,(instr_super ? super_para : instr_para) };
			ch_para        = ( instr_jalr<<6 )|( (attr_jcond|attr_op) ? op_sel : clu_para );
			ch_imm         = extra_imm;
		
		    riscv_decoder = {
			                instr_super,
							instr_jalr,
							instr_jal,
							instr_jcond,
							
							attr_clu,
							attr_muldiv, 
							attr_jcond, 
							attr_op, 
							
							ld_bypass, 
							rs0_pc_sel, 
							rs1_imm_selx,
							
							ch_para, 
							ch_imm,
							rs1_immediatex,							
							rd_order,
							rs1_order, 							
							rs0_order 							
			                };	
		end
	endfunction	

    function `N(1+21) jal_jcond_combo(input `N(`XLEN) instr, input predict);
	    reg             valid;
		reg `N(21)      offset;
		begin
		    valid    = 0;
			offset   = 0;
		    if ( instr[1:0]==2'b11 ) begin
				case(instr[6:2])			
                5'b11011 :                        //JAL
                            begin
					            valid   = 1'b1;
                                offset  = { instr[31],instr[19:12],instr[20],instr[30:21],1'b0 };								
                            end			
                5'b11000 :                       //BRANCH
                            begin
							    valid   = predict;
                                offset  = { {9{instr[31]}},instr[7],instr[30:25],instr[11:8],1'b0 };									
                            end			
				endcase			
			end else begin
`ifdef RV32C
                case({instr[15:13],instr[1:0]})   
                5'b001_01:   //C.JAL	
                            begin
							    valid  = 1'b1;
								offset = { {10{instr[12]}},instr[8],instr[10:9],instr[6],instr[7],instr[2],instr[11],instr[5:3],1'b0 };
                            end	
                5'b101_01:   //C.J
				            begin
							    valid  = 1'b1;
                                offset = { {10{instr[12]}},instr[8],instr[10:9],instr[6],instr[7],instr[2],instr[11],instr[5:3],1'b0 };								
							end
                5'b110_01,                     
                5'b111_01:   //C.BEQZ/C.BNEZ
				            begin
							    valid  = predict;
								offset = { {13{instr[12]}},instr[6:5],instr[2],instr[11:10],instr[4:3],1'b0 };
							end
                endcase
`else
                valid   = 0;
                offset  = 0;				
`endif			
			end
			jal_jcond_combo = { valid,offset }; 
		end
	endfunction	 


