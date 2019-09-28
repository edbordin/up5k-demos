//`timescale 1 ns/ 1 ps
module testbench;
reg clk = 1;
reg clk2 = 1;
always #1 begin
    clk2 = ~clk2;
end
always #4 begin
    clk = ~clk;
end


wire ready;
reg reset = 1'b0;
reg read_en = 1'b0;
reg [23:0] addr = 24'b0;
wire [7:0] rdata;

wire spi_sclk, spi_cs_n, spi_mosi, spi_miso, flash_wp_n, flash_hold_n;

qspi_flashmem flash(
                  .clk(clk2),
                  .reset(reset),
                  .run_nes(1'b1),
                  .ready(ready),
                  .read_en(read_en),
                  .addr(addr),
                  .rdata(rdata),

                  // flashmem
                  .spi_sclk(spi_sclk),
                  .spi_cs_n(spi_cs_n),
                  .spi_mosi(spi_mosi),
                  .spi_miso(spi_miso),
                  .flash_wp_n(flash_wp_n),
                  .flash_hold_n(flash_hold_n)
              );

reg [3:0] ctr = 4'b0000;

always @(posedge clk2) begin
    addr <= 24'b01010101_10101010_11001100;
    // if (ready) begin
        // read_en <= 1'b1;
        // addr <= 24'b01010101_10101010_11001100;
    // end
end

initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("qspi_flash_tb.vcd");
        $dumpvars(0, testbench);
    end

end

initial begin
    repeat (2) @(posedge clk2) begin
		#4 reset <= !reset;
	end
    repeat (200) @(posedge clk2);
    $display("-- Done --");
    $finish;
end

endmodule
