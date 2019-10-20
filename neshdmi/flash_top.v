`timescale 1ns / 1ps

module flash_top (
	// clock input
  input clock_12,
  
  // flashmem
  output flash_sck,
  output flash_csn,
  inout flash_mosi, // output only until in QSPI mode
  inout flash_miso,  // input only until in QSPI mode
  inout flash_wp_n, // output only until in QSPI mode
  inout flash_hold_n, // output only until in QSPI mode
  output UART_RX,
  input UART_TX,
  
//   input buttons,

   output [4:0] LED
  
);

reg clock_locked;
wire locked_pre;
always @(posedge clock)
    clock_locked <= locked_pre;

wire sys_reset = !clock_locked;
wire reset_nes = !load_done || sys_reset;
reg [1:0] nes_ce;
wire run_nes = (nes_ce == 3);	// keep running even when reset, so that the reset can actually do its job!

wire run_nes_g;
SB_GB ce_buf (
.USER_SIGNAL_TO_GLOBAL_BUFFER(run_nes),
.GLOBAL_BUFFER_OUTPUT(run_nes_g)
);
  
  // NES is clocked at every 4th cycle.
  always @(posedge clock)
    nes_ce <= nes_ce + 1;

wire clock_flash;
wire clock_12_g;

pll pll_i (
    .clock_in(clock_12),
  	.clock_out(clock_flash),
    .clock_passthrough(clock_12_g),
  	.locked(locked_pre)
);

reg clock;
reg [1:0] ctr;
always @ (posedge clock_flash) begin
    ctr <=  (ctr < 3) ? ctr + 1 : 0;
    clock <= ctr < 2;
end
// Warning: Wire flash_top.flash.spi_cs has an unprocessed 'init' attribute.
wire read_en = 1'b1;
wire [23:0] addr =24'h100000;
wire [7:0] rdata;


wire load_done;

wire [4:0] flash_debug;

qspi_flashmem flash (
    .clk(clock_flash),
    .reset(sys_reset),
    .run_nes(run_nes_g),

    // input valid,
    .ready(load_done),
    .read_en(read_en),
    .addr(addr),
    .rdata(rdata),

    // flashmem
    .spi_sclk(flash_sck),
    .spi_cs_n(flash_csn),
    .spi_mosi(flash_mosi), // output only until in QSPI mode (IO0)
    .spi_miso(flash_miso),  // input only until in QSPI mode (IO1)
    .flash_wp_n(flash_wp_n), // output only until in QSPI mode (IO2)
    .flash_hold_n(flash_hold_n), // output only until in QSPI mode (IO3)
    .debug(flash_debug)
);

icebreaker_sump sump(
  .clk_12m(clock_12_g),
   .clk_cap_tree(clock_flash),
  .uart_tx(UART_TX),
  .uart_rx(UART_RX),
  .led_bus(LED[3:0]),
  .events({11'b0, flash_debug})
);

endmodule
