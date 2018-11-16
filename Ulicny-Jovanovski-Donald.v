module CPU (clock,PC, IR, ALUOut, MDR, Rs, Rt, reg8);
	parameter R_FORMAT		= 6'b000000;
	parameter JUMP	   		= 6'b000010;
	parameter JUMP_AND_LINK 	= 6'b000011;
	parameter BEQ 	   		= 6'b000100;
	parameter BNE	   		= 6'b000101;
	parameter ADDI	   		= 6'b001000;
	parameter SLTI			= 6'b001010;
	parameter ANDI			= 6'b001100;
	parameter ORI			= 6'b001101;
	parameter LW  	   		= 6'b100011;
	parameter STORE_BYTE		= 6'b101000;
	parameter SW  	   		= 6'b101011;
	parameter JM			= 6'b100101;
	parameter SWAP			= 6'b100001;
	//JM and SWAP instructions included
	// other opcodes go here
	//....
	
	input clock;  //the clock is an external input
	//Make these datapath registers available outside the module in order to do the testing
	output PC, IR, ALUOut, MDR, Rs, Rt;
	reg[31:0] PC, IR, ALUOut, MDR, Rs, Rt;

	
	// The architecturally visible registers and scratch registers for implementation
	reg [31:0] Regs[0:31], Memory [0:1023];
	reg [2:0] state; // processor state
	wire [5:0] opcode; //use to get opcode easily
	wire [31:0] SignExtend, PCOffset; //used to get sign extended offset field
	
	assign opcode = IR[31:26]; //opcode is upper 6 bits
		//sign extension of lower 16-bits of instruction
	assign SignExtend = {{16{IR[15]}},IR[15:0]}; 
	assign PCOffset = SignExtend << 2; //PC offset is shifted 
	
	
	wire [31:0] reg8;
	output [31:0] reg8; //output reg 8 for testing
	assign reg8 = Regs[8]; //output reg 8 (i.e. $t0)
	
	
	initial begin  	//Load a MIPS test program and data into Memory
		
		//I'm not sure if memory indices are supposed to be decimal or hex
		Memory[2] = 32'H20080007;      //addi $t0, $zero, 7 
		Memory[3] = 32'H8c090078;	//lw $t1, 120($zero) 
		Memory[4] = 32'H01284020;	//add $t0, $t1, $t0 
		Memory[5] = 32'H3109002e;	//andi $t1, $t0, 46 
		Memory[6] = 32'H01284024;	//and $t0 ,$t1, $t0 
		Memory[7] = 32'H11090000;	//beq $t0, $t1, LOOP 
		Memory[8] = 32'H15090000;	//bne $t0, $t1, LOOP1
		Memory[9] = 32'H08000000;	//j LOOP 
		Memory[10] = 32'H0c000000;	//jal LOOP1 
		Memory[11] = 32'H03e00008;	//jr $ra 
		Memory[12] = 32'H212a004d;	//addi $t2, $t1, 77 
		Memory[13] = 32'H01494027;	//nor $t0, $t2, $t1 
		Memory[14] = 32'H01484825;	//or $t1, $t2, $t0 
		Memory[15] = 32'H35480011;	//ori $t0, $t2, 17 
		Memory[16] = 32'H012a402a;	//slt $t0, $t1, $t2 
		Memory[17] = 32'H29490096;	//slti $t1, $t2, 150 
		Memory[18] = 32'H00094080;	//sll $t0, $t1, 2 
		Memory[19] = 32'H00094082;	//srl $t0, $t1, 2 
		Memory[20] = 32'Ha1090009;	//sb $t1, 9($t0) 
		Memory[21] = 32'Hac080078;	//sw $t0, 120($zero) 
		Memory[22] = 32'H01284022;	//sub $t0, $t1, $t0 
		//Memory[ ] = ...jm
		//Memory[ ] = ...swap
		
	end
	
	
	initial  begin  // set the PC to 8 and start the control in state 1 to start fetch instructions from Memory[2] (byte 8)
		PC = 8; 
		state = 1; 
	end
	
	always @(posedge clock) begin
		//make R0 0 
		//short-cut way to make sure R0 is always 0
		Regs[0] = 0; 
		
		case (state) //action depends on the state
		
			1: begin     //first step: fetch the instruction, increment PC, go to next state	
				IR <= Memory[PC>>2]; //changed
				PC <= PC + 4;        //changed
				state = 2; //next state
			end
				
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//:::::::: This state (2) is what needs to be repeated to fetch Rs and Rt seperatly on different clock cycles.  ::::::::::::::::
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

			2: begin     //second step: Instruction decode, register fetch, also compute branch address
				Rs <= Regs[IR[25:21]];
				Rt <= Regs[IR[20:16]];
				state = 3;
				ALUOut <= PC + PCOffset; 	// compute PC-relative branch target
			end
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//:::::::: From here on everything should run find in R_FORMAT as A and B are both set. ::::::::::::::::::::::::::::::::::::::::
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

			3: begin     //third step:  Load/Store execution, ALU execution, Branch completion
				state = 4; // default next state
				if (opcode == R_FORMAT) 
					case (IR[5:0]) //case for the various R-type instructions
						00: ALUOut = Rt << shamt; 	//shift left logical
						02: ALUOut = Rt >> shamt; 	//shift right logical
						08: ALUOut = Rs 		//jump register 
						32: ALUOut = Rs + Rt; 		//add 
						33: ALUOut = Rs - Rt; 		//subtract 
						36: ALUOut = Rs && Rt; 		//logical and
						37: ALUOut = Rs || Rt; 		//logical or
						39: ALUOut = ~(Rs || Rt);	//logical nor
						42: ALUOut = (Rs < Rt) ? 1 : 0; //set less than	

						default: ALUOut = Rs; //other R-type operations
					endcase

				else if (opcode == JUMP) begin
					PC <= IR[25:0];
					state = 1;
				end	// JUMP

				else if (opcode == JUMP_AND_LINK) begin
					ALUOut <= PC + 8;
					PC <= IR[25:0];
				end	// JUMP_AND_LINK

				else if (opcode == BNE) begin
					if (Rs != Rt)
						PC <= ALUOut; //branch taken: update PC
					state = 1;	// BNE finished, return to first state
				end

				else if (opcode == BEQ) begin
					if (Rs==Rt)  
						PC <= ALUOut; // branch taken--update PC
					state = 1;  //  BEQ finished, return to first state
				end

				else if (opcode == ADDI)
					ALUOut <= Rs + SignExtend;


				else if (opcode == SLTI) begin
					ALUOut <= Rs < SignExtend ? 1 : 0;
				end

				else if (opcode == ANDI)
					ALUOut <= Rs && SignExtend;

				else if (opcode == ORI)
					ALUOut <= Rs || SignExtend;

				else if ((opcode == LW) |(opcode==SW)) 
					ALUOut <= Rs + SignExtend;
				
				else if (opcode == JM)
					ALUOut <= Rs + SignExtend;
				
				else if (opcode == SWAP)
					//compute effective address


			end	// state 3
		
			4: begin
				if (opcode == R_FORMAT) begin //ALU Operation
					Regs[IR[15:11]] <= ALUOut; // write the result
					state = 1;
				end // R-type

				else if (opcode == JUMP_AND_LINK) begin
					Regs[31] <= ALUOut
				end

				else if ((opcode == ADDI) | (opcode == SLTI) | (opcode == ANDI) | (opcode == ORI) begin
					Regs[IR[20:16]] <= ALUOut;	// write result
					state = 1;
				end	// immediate instructions

				else if (opcode == STORE_BYTE) begin
					Memory[ALUOut>>2][7:0] = Rt[7:0]// TODO
				end

				else if (opcode == LW) begin // load instruction
					MDR <= Memory[ALUOut>>2]; // read the memory
					state = 5; // next state
				end	// LW
				
				else if (opcode == SW) begin
					Memory[ALUOut>>2] <= Rt; // write the memory
					state = 1; // return to state 1
				end // SW
			
	
			end	// state 4
		
			5: begin     //LW is the only instruction still in execution
				Regs[IR[20:16]] = MDR; 		// write the MDR to the register
				state = 1;
			end //complete a LW instruction
				
		endcase
		
	end // always
	
endmodule
