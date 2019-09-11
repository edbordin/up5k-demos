// File T8080se.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
// vhd2vl settings:
//  * Verilog Module Declaration Style: 2001

// vhd2vl is Free (libre) Software:
//   Copyright (C) 2001 Vincenzo Liguori - Ocean Logic Pty Ltd
//     http://www.ocean-logic.com
//   Modifications Copyright (C) 2006 Mark Gonzales - PMC Sierra Inc
//   Modifications (C) 2010 Shankar Giri
//   Modifications Copyright (C) 2002-2017 Larry Doolittle
//     http://doolittle.icarus.com/~larry/vhd2vl/
//   Modifications (C) 2017 Rodrigo A. Melo
//
//   vhd2vl comes with ABSOLUTELY NO WARRANTY.  Always check the resulting
//   Verilog for correctness, ideally with a formal verification tool.
//
//   You are welcome to redistribute vhd2vl under certain conditions.
//   See the license (GPLv2) file included with the source for details.

// The result of translation follows.  Its copyright status should be
// considered unchanged from the original VHDL.

// ****
// T80(b) core. In an effort to merge and maintain bug fixes ....
//
//
// Ver 300 started tidyup
// MikeJ March 2005
// Latest version from www.fpgaarcade.com (original www.opencores.org)
//
// ****
//
// 8080 compatible microprocessor core, synchronous top level with clock enable
// Different timing than the original 8080
// Inputs needs to be synchronous and outputs may glitch
//
// Version : 0242
//
// Copyright (c) 2002 Daniel Wallner (jesus@opencores.org)
//
// All rights reserved
//
// Redistribution and use in source and synthezised forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
//
// Redistributions in synthesized form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// Neither the name of the author nor the names of other contributors may
// be used to endorse or promote products derived from this software without
// specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// Please report bugs to the author, but before you do so, please
// make sure that this is not a derivative work and that
// you have the latest version of this file.
//
// The latest version of this file can be found at:
//      http://www.opencores.org/cvsweb.shtml/t80/
//
// Limitations :
//      STACK status output not supported
//
// File history :
//
//      0237 : First version
//
//      0238 : Updated for T80 interface change
//
//      0240 : Updated for T80 interface change
//
//      0242 : Updated for T80 interface change
//
// no timescale needed

module T8080se(
input wire RESET_n,
input wire CLK,
input wire CLKEN,
input wire READY,
input wire HOLD,
input wire INT,
output wire INTE,
output reg DBIN,
output wire SYNC,
output wire VAIT,
output wire HLDA,
output reg WR_n,
output wire [15:0] A,
input wire [7:0] DI,
output wire [7:0] DO
);

parameter [31:0] Mode=2;
parameter [31:0] T2Write=0;
// 0 => WR_n active in T3, /=0 => WR_n active in T2



wire IntCycle_n;
wire NoRead;
wire Write;
wire IORQ;
wire INT_n;
wire HALT_n;
wire BUSRQ_n;
wire BUSAK_n;
wire [7:0] DO_i;
reg [7:0] DI_Reg;
wire [2:0] MCycle;
wire [2:0] TState;
wire One;

  assign INT_n =  ~INT;
  assign BUSRQ_n = HOLD;
  assign HLDA =  ~BUSAK_n;
  assign SYNC = TState == 3'b001 ? 1'b1 : 1'b0;
  assign VAIT = TState == 3'b010 ? 1'b1 : 1'b0;
  assign One = 1'b1;
  assign DO[0] = TState == 3'b001 ?  ~IntCycle_n : DO_i[0];
  // INTA
  assign DO[1] = TState == 3'b001 ? Write : DO_i[1];
  // WO_n
  assign DO[2] = DO_i[2];
  // STACK not supported !!!!!!!!!!
  assign DO[3] = TState == 3'b001 ?  ~HALT_n : DO_i[3];
  // HLTA
  assign DO[4] = TState == 3'b001 ? IORQ & Write : DO_i[4];
  // OUT
  assign DO[5] = TState != 3'b001 ? DO_i[5] : MCycle == 3'b001 ? 1'b1 : 1'b0;
  // M1
  assign DO[6] = TState == 3'b001 ? IORQ &  ~Write : DO_i[6];
  // INP
  assign DO[7] = TState == 3'b001 ?  ~IORQ &  ~Write & IntCycle_n : DO_i[7];
  // MEMR
  T80 #(
      .Mode(Mode),
    .IOWait(0))
  u0(
      .CEN(CLKEN),
    .M1_n(/* open */),
    .IORQ(IORQ),
    .NoRead(NoRead),
    .Write(Write),
    .RFSH_n(/* open */),
    .HALT_n(HALT_n),
    .WAIT_n(READY),
    .INT_n(INT_n),
    .NMI_n(One),
    .RESET_n(RESET_n),
    .BUSRQ_n(One),
    .BUSAK_n(BUSAK_n),
    .CLK_n(CLK),
    .A(A),
    .DInst(DI),
    .DI(DI_Reg),
    .DO(DO_i),
    .MC(MCycle),
    .TS(TState),
    .IntCycle_n(IntCycle_n),
    .IntE(INTE));

  always @(posedge RESET_n, posedge CLK) begin
    if(RESET_n == 1'b0) begin
      DBIN <= 1'b0;
      WR_n <= 1'b1;
      DI_Reg <= 8'b00000000;
    end else begin
      if(CLKEN == 1'b1) begin
        DBIN <= 1'b0;
        WR_n <= 1'b1;
        if(MCycle == 3'b001) begin
          if(TState == 3'b001 || (TState == 3'b010 && READY == 1'b0)) begin
            DBIN <= IntCycle_n;
          end
        end
        else begin
          if((TState == 3'b001 || (TState == 3'b010 && READY == 1'b0)) && NoRead == 1'b0 && Write == 1'b0) begin
            DBIN <= 1'b1;
          end
          if(T2Write == 0) begin
            if(TState == 3'b010 && Write == 1'b1) begin
              WR_n <= 1'b0;
            end
          end
          else begin
            if((TState == 3'b001 || (TState == 3'b010 && READY == 1'b0)) && Write == 1'b1) begin
              WR_n <= 1'b0;
            end
          end
        end
        if(TState == 3'b010 && READY == 1'b1) begin
          DI_Reg <= DI;
        end
      end
    end
  end


endmodule
