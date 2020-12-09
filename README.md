# RV3N
RV3N --- A RV32IMC processor core, which has a new pipeline with "3+N" stages

## Architecture

![diagram](/diagram.png)
 
RV3N is a configurable RV32IMC CPU core. It has three areas: GENERATOR, CHAIN and FUNCTIONAL.  The areas of GENERATOR and CHAIN constitute a pipeline with "3+N" stages. The GENERATOR area has the initial fixed 3 stages, which are:

1.	IF--- A single loading-instruction operation expects to fetch "INUM" number of 32-bit instructions.

2. DC--- With the help of a tiny buffer, "PNUM" instructions are generated and decoded from available instruction bits.

3. ID--- Each of "PNUM" instructions gets its Rs0/Rs1 from  GSR (the register file) ,which is the original source,  or  Rd fields of  "CH" stages in "CHAIN" area, which are newly updated. If it fails because the target Rd field has not its computation, there is a tag to this Rs0 or Rs1, which assumes when the target Rd field acquires its computation, this Rs0 or Rs1 gets a copy in the same cycle.

The "CHAIN" area has  configurable "CHAIN_LEN" stages. Every "CH" stage has "PNUM" instructions, each of which has 3 fields: Rs0, Rs1 and Rd.
The "FUNCTIONAL" area has several execution units, which are dedicated to different kinds of instructions. Every execution unit has two data inputs: operand0 and operand1, which are connected to ORed signals of all Rs0/Rs1 fields respectively. Outputs of execution units are connected to all Rs0/Rs1/Rd fields. 

There is an algorithm that allocates one of "CHAIN_LEN\*PNUM" instructions to call one of execution units exclusively, and on the next cycle, the result is written back to the Rd field of that instruction or the Rs0/Rs1 fields of following instructions.

Imagine a line of students marching toward the end. They can be one person in a row, or two or three people in a row, as defined by PNUM. In the procession of the queue, one of them can arrange to use equipment such as washing machine and retail machine when his fields of Rs0 and Rs1 are ready and in the front row. The output of these devices will also reach them, as well as the students in the back who need them. The entire queue does not stop while they use the device and get its output. This is an efficient marching queue that completes instruction transactions as parallel as possible as the queue moves.
