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


//-------------------------------------------------------------------------------
// Recommended core configurations (modifiable)
//-------------------------------------------------------------------------------

`define RV32M
`define RV32C

`define INUM                   1
`define PNUM                   1

`define CHAIN_LEN              3

`define OP_NUM                 1


//-------------------------------------------------------------------------------
// Setting recommended configurations(Please make sure you know these defination)
//-------------------------------------------------------------------------------

`define XLEN                   32
`define HLEN                   16
`define RGBIT                  5

`define PIPE_LEN               `PNUM*`CHAIN_LEN

`define FUNC_NUM               (`OP_NUM+3)
`define FWR_NUM                (`OP_NUM+1)

`define TERMIAL(n,m)           ( (((n)+(m))*((n)-(m)+1))/2 )    // m + (m+1) + (m+2) + ... + n
`define ALMAP_LEN              `TERMIAL(`PIPE_LEN-1,0)
`define INMAP_LEN              `TERMIAL(`PIPE_LEN-1,`PIPE_LEN-`PNUM)

`define DC_LEN                 (  4+4+3+7+13+`XLEN+(3*`RGBIT) )
`define CHATT_LEN              ( ( 1+4+1+1+1+`RGBIT )*`PNUM + `INMAP_LEN*2 )
`define CHPKG_LEN              ( ( 8+13+`XLEN +`XLEN +`XLEN +`XLEN +`FUNC_NUM )*`PNUM )




