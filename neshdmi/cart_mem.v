/*
The virtual NES cartridge
At the moment this stores the entire cartridge
in SPRAM, in the future it could stream data from
SQI flash, which is more than fast enough
*/

module cart_mem(
  input flash_clock,
  input clock,
  input run_nes,
  input reset,
  
  input reload,
  input [3:0] index,
  
  output cart_ready,
  // output reg [31:0] flags_out,
  output [31:0] flags_out,
  //address into a given section - 0 is the start of CHR and PRG,
  //region is selected using the select lines for maximum flexibility
  //in partitioning
  input [20:0] address,
  
  input prg_sel, chr_sel,
  input ram_sel, //for cart SRAM (NYI)
  
  input rden, wren,
  
  input  [7:0] write_data,
  output [7:0] read_data,
  
  //Flash load interface
  output flash_csn,
  output flash_sck,
  inout flash_mosi, // output only until in QSPI mode (IO0)
  inout flash_miso, // input only until in QSPI mode (IO1)
  inout flash_wp_n, // output only until in QSPI mode (IO2)
  inout flash_hold_n // output only until in QSPI mode (IO3)
);

wire load_done;
assign flags_out = 32'h00004100; // hardcode to mario for now

wire cart_ready = load_done;
// Does the image use CHR RAM instead of ROM? (i.e. UNROM or some MMC1)
wire is_chram = flags_out[15];
// Work out whether we're in the SPRAM, used for the main ROM, or the extra 8k SRAM
wire spram_en = prg_sel | (!is_chram && chr_sel);
wire sram_en = ram_sel | (is_chram && chr_sel);

wire [16:0] decoded_address;
assign decoded_address = chr_sel ? {1'b1, address[15:0]} : address[16:0];

wire [7:0] rom_read_data;
wire [7:0] csram_read_data;

assign read_data = sram_en ? csram_read_data : rom_read_data;

 // The SRAM, used either for PROG_SRAM or CHR_SRAM
generic_ram #(
  .WIDTH(8),
  .WORDS(8192)
) sram_i (
  .clock(clock),
  .reset(reset),
  .address(decoded_address[12:0]), 
  .wren(wren&sram_en), 
  .write_data(write_data), 
  .read_data(csram_read_data)
);

wire [16:0] rom_address = decoded_address; //load_done ? decoded_address : load_addr;
wire [23:0] flashrom_addr = (24'h100000 + (index << 18)) | rom_address;// {load_addr, 2'b00};

wire flash_ready;
qspi_flashmem flashrom (
  .clk(flash_clock),
  .run_nes(run_nes),
  .reset(reset),
  .ready(load_done),
  .read_en(spram_en),
  // .addr(load_done ? flashrom_addr : load_addr),
  .addr(flashrom_addr),
  .rdata(rom_read_data),
  .spi_sclk(flash_sck),
  .spi_cs_n(flash_csn),
  .spi_mosi(flash_mosi),
  .spi_miso(flash_miso),
  .flash_wp_n(flash_wp_n),
  .flash_hold_n(flash_hold_n)
);

endmodule
