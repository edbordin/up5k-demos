module boot_rom (
	address,
	clock,
	q);

input	[7:0]  address;
input	  clock;
output reg	[7:0]  q;
  
reg [7:0] rom [0:255];

initial begin
       $readmemh("boot_rom.dat", rom);
end

always@(posedge clk)
   q <= rom[address];
	 
endmodule