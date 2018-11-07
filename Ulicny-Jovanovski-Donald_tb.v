module cpu_tb;

	wire[31:0] PC, IR, ALUOut, MDR, A, B, reg8;
	reg clock;
	
	CPU cpu1 (clock,PC, IR, ALUOut, MDR, A, B, reg8);// Instantiate CPU module  
	
	initial begin
		clock = 0;
		repeat (20) // "20" should be changed based on how many clocks the test MIPS program needs 
		  begin
			#10 clock = ~clock; //alternate clock signal
		  end
		$finish; 
	end
			
endmodule
