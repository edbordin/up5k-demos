module qspi_flashmem (
           input clk, reset, run_nes,

           // input valid,
           output reg ready,
           input read_en,
           input [23:0] addr,
           output reg [7:0] rdata,

           // flashmem
           output spi_sclk,
           output spi_cs_n,
           inout spi_mosi, // output only until in QSPI mode (IO0)
           inout spi_miso,  // input only until in QSPI mode (IO1)
           inout flash_wp_n, // output only until in QSPI mode (IO2)
           inout flash_hold_n // output only until in QSPI mode (IO3)
       );
assign spi_sclk = clk;
reg spi_cs=1'b0;
assign spi_cs_n = !spi_cs;

// reg initialized;
reg [3:0] state = STATE_SPI_CMD0;
reg [12:0] counter; // used for different purposes by each state


localparam STATE_SPI_CMD0 = 4'd0; // sending the initial SPI command (enable QE bit)
localparam STATE_END_CMD0 = 4'd1; // ending initial SPI command
localparam STATE_SPI_CMD1 = 4'd2; // sending the second SPI command
localparam STATE_ADDRESS = 4'd3; // sending read address mode
localparam STATE_READ = 4'd4; // let the flash output one byte of read data from dummy address
localparam STATE_WAIT = 4'd5; // flash is initialised and waiting for a read command
localparam STATE_RESET = 4'd6; // send the reset sequence to the flash
localparam STATE_WAIT_RESET = 4'd7; // wait approx 30 us for flash to reset

// spi cmds and data are sent msb first
//localparam [0:15] SPI_CMD0 = 16'hAAAA; // for sim
localparam [0:15] SPI_CMD0 = 16'h31_00 | 16'b00000010; //Write Status Register-2 (31h) set QE bit

// localparam [0:7] SPI_CMD1 = 8'h55; // for sim
localparam [0:7] SPI_CMD1 = 8'hED; //DTR Fast Read Quad I/O
localparam [0:7] M70_ENABLE_FASTREAD = 8'b00100000; // M5-4=1,0 (sent as part of CMD1 to enable continuous read)

// bitbang the reset sequence rather than messing around with a bunch of states
// FFh to ensure we are out of continuous read mode, 66h enable reset, 99h reset
localparam [0:27] SPI_CMD_RESET = {1'b0, 8'hFF, 1'b0, 8'h66, 1'b0, 8'h99, 1'b0}; 
localparam [0:27] SPI_CS_RESET = {1'b0, 8'hFF, 1'b0, 8'hFF, 1'b0, 8'hFF, 1'b0};

// localparam [12:0] RESET_WAIT_CYCLES = 12'd10; // for sim
localparam [12:0] RESET_WAIT_CYCLES = 12'd2600; // wait 30 us ~= 2566 cycles @ 85.5 MHz

reg [0:7] flash_in; //host out, flash in
wire [0:7] flash_out; // host in, flash out (SB_IO has registers internally)

localparam pin_type = 6'b1000_00; // PIN_OUTPUT_DDR_ENABLE | PIN_INPUT_DDR
reg [3:0] io_oe;

// MOSI | IO0
SB_IO #(
          .PIN_TYPE(pin_type),
          .PULLUP(1'b0)
      ) IO0 (
          .PACKAGE_PIN(spi_mosi),
          .INPUT_CLK(clk),
          .OUTPUT_CLK(clk),
          .OUTPUT_ENABLE(io_oe[0]),
          .D_OUT_0(flash_in[7]),
          .D_OUT_1(flash_in[3]),
          .D_IN_0(flash_out[7]),
          .D_IN_1(flash_out[3])          
      );

// MISO | IO1
SB_IO #(
          .PIN_TYPE(pin_type),
          .PULLUP(1'b 0)
      ) IO1 (
          .PACKAGE_PIN(spi_miso),
          .INPUT_CLK(clk),
          .OUTPUT_CLK(clk),
          .OUTPUT_ENABLE(io_oe[1]),
          .D_OUT_0(flash_in[6]),
          .D_OUT_1(flash_in[2]),
          .D_IN_0(flash_out[6]),
          .D_IN_1(flash_out[2])
      );

// WP_N | IO2
SB_IO #(
          .PIN_TYPE(pin_type),
          .PULLUP(1'b 0)
      ) IO2 (
          .PACKAGE_PIN(flash_wp_n),
          .INPUT_CLK(clk),
          .OUTPUT_CLK(clk),
          .OUTPUT_ENABLE(io_oe[2]),
          .D_OUT_0(flash_in[5]),
          .D_OUT_1(flash_in[1]),
          .D_IN_0(flash_out[5]),
          .D_IN_1(flash_out[1])
      );

// HOLD_N | IO3
SB_IO #(
          .PIN_TYPE(pin_type),
          .PULLUP(1'b 0)
      ) IO3 (
          .PACKAGE_PIN(flash_hold_n),
          .INPUT_CLK(clk),
          .OUTPUT_CLK(clk),
          .OUTPUT_ENABLE(io_oe[3]),          
          .D_OUT_0(flash_in[4]),
          .D_OUT_1(flash_in[0]),
          .D_IN_0(flash_out[4]),
          .D_IN_1(flash_out[0])
      );

reg [2:0] next_state;
reg clear_counter;

reg rdata_load;
reg [7:0] rdata_next;

always @* begin
    // defaults to avoid inferring a latch
    clear_counter = 1'b0;
    ready = 1'b0;
    io_oe = 4'b0000;
    spi_cs = 1'b0;
    next_state = STATE_RESET;
    flash_in = 8'b0;
    rdata_load = 1'b0;
    rdata_next = 8'b0;
    if (reset) begin
        io_oe = 4'b0000;
        spi_cs = 1'b0;
        next_state = STATE_RESET;
        clear_counter = 1'b1;
        flash_in = 8'b0;
    end else if (state == STATE_SPI_CMD0) begin
        if(counter < $bits(SPI_CMD0)) begin
            io_oe = 4'b0001;
            spi_cs = 1'b1;
            next_state = STATE_SPI_CMD0;
            flash_in = {3'b000, SPI_CMD0[counter[2:0]], 3'b000, SPI_CMD0[counter[2:0]]};
        end else begin
            io_oe = 4'b0000;
            spi_cs = 1'b0;
            next_state = STATE_END_CMD0;
            clear_counter = 1;
        end
    end else if (state == STATE_END_CMD0 || (state == STATE_SPI_CMD1 && counter < $bits(SPI_CMD1))) begin
        io_oe = 4'b0001;
        spi_cs = 1'b1;
        next_state = STATE_SPI_CMD1;
        flash_in = {3'b000, SPI_CMD1[counter[2:0]], 3'b000, SPI_CMD1[counter[2:0]]};
    end else if (state == STATE_SPI_CMD1 && counter == $bits(SPI_CMD1)) begin
        io_oe = 4'b1111;
        spi_cs = 1'b1;
        next_state = STATE_ADDRESS;
        clear_counter = 1;
        flash_in <= addr[23:16];
    end else if (state == STATE_ADDRESS) begin
        spi_cs = 1'b1;
        io_oe = 4'b1111;
        next_state = STATE_ADDRESS;
        case(counter)
            6'd0: begin
                flash_in = addr[15:8];
            end
            6'd1: begin
                flash_in = addr[7:0];
            end
            6'd2: begin
                flash_in = M70_ENABLE_FASTREAD;
            end
            6'd3, 6'd4, 6'd5, 6'd6, 6'd7, 6'd8: begin
                io_oe = 4'b0000;
                flash_in = 8'b0;
                // 6/7 dummy clocks
            end
            6'd9: begin
                // 7/7 dummy clocks
                io_oe = 4'b0000;
                flash_in = 8'b0;
                next_state = STATE_READ;
                clear_counter = 1;
            end
        endcase
    end else if (state == STATE_READ) begin
        io_oe = 4'b0000;
        clear_counter = 1;
        rdata_load = 1'b1;
        rdata_next = flash_out;
        next_state = STATE_WAIT;
        spi_cs = 1'b1;
    end else if (state == STATE_WAIT) begin
        if (read_en && !reset) begin
            next_state = STATE_ADDRESS;
            spi_cs = 1'b1;
            io_oe = 4'b1111;
            flash_in = addr[23:16];
            clear_counter = 1;
        end else begin
            ready = 1;
            spi_cs = 1'b0;
            next_state = STATE_WAIT;
            io_oe = 4'b0000;
            clear_counter = 1;
        end
    end else if (state == STATE_RESET) begin
        if (counter < $bits(SPI_CMD_RESET)) begin
            io_oe = 4'b0001;
            // bit bang the cs line instead of writing more state machine logic
            spi_cs = SPI_CS_RESET[counter[4:0]];
            flash_in = {3'b000, SPI_CMD_RESET[counter[4:0]], 3'b000, SPI_CMD_RESET[counter[4:0]]};
            next_state = STATE_RESET;
        end else begin
            next_state = STATE_WAIT_RESET;
            clear_counter = 1;
            io_oe = 4'b0000;
            spi_cs = 1'b0;
        end
    end else if (state == STATE_WAIT_RESET) begin
        io_oe = 4'b0000;
        spi_cs = 1'b0;
        if (counter == RESET_WAIT_CYCLES) begin
            // now init the chip again
            next_state = STATE_SPI_CMD0;
            clear_counter = 1;
        end
    end
end

always @(posedge clk) begin
    if (rdata_load) begin
        rdata <= rdata_next;
    end
    if (state != STATE_WAIT || run_nes == 1'b1) begin
        state <= next_state;
    end
    if (clear_counter) begin
        counter <= 0;
    end else begin
        counter <= counter + 1;
    end
end

endmodule
