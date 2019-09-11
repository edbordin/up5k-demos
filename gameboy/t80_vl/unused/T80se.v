// File T80se.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
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
// Z80 compatible microprocessor core, synchronous top level with clock enable
// Different timing than the original z80
// Inputs needs to be synchronous and outputs may glitch
//
// Version : 0240
//
// Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
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
//
// File history :
//
//      0235 : First release
//
//      0236 : Added T2Write generic
//
//      0237 : Fixed T2Write with wait state
//
//      0238 : Updated for T80 interface change
//
//      0240 : Updated for T80 interface change
//
//      0242 : Updated for T80 interface change
//
// no timescale needed

module T80se(
input wire RESET_n,
input wire CLK_n,
input wire CLKEN,
input wire WAIT_n,
input wire INT_n,
input wire NMI_n,
input wire BUSRQ_n,
output wire M1_n,
output reg MREQ_n,
output reg IORQ_n,
output reg RD_n,
output reg WR_n,
output wire RFSH_n,
output wire HALT_n,
output wire BUSAK_n,
output wire [15:0] A,
input wire [7:0] DI,
output wire [7:0] DO
);

parameter [31:0] Mode=0;
parameter [31:0] T2Write=0;
parameter [31:0] IOWait=1;
// 0 => Single cycle I/O, 1 => Std I/O cycle



wire IntCycle_n;
wire NoRead;
wire Write;
wire IORQ;
reg [7:0] DI_Reg;
wire [2:0] MCycle;
wire [2:0] TState;

  T80 #(
      .Mode(Mode),
    .IOWait(IOWait))
  u0(
      .CEN(CLKEN),
    .M1_n(M1_n),
    .IORQ(IORQ),
    .NoRead(NoRead),
    .Write(Write),
    .RFSH_n(RFSH_n),
    .HALT_n(HALT_n),
    .WAIT_n(Wait_n),
    .INT_n(INT_n),
    .NMI_n(NMI_n),
    .RESET_n(RESET_n),
    .BUSRQ_n(BUSRQ_n),
    .BUSAK_n(BUSAK_n),
    .CLK_n(CLK_n),
    .A(A),
    .DInst(DI),
    .DI(DI_Reg),
    .DO(DO),
    .MC(MCycle),
    .TS(TState),
    .IntCycle_n(IntCycle_n));

  always @(posedge RESET_n, posedge CLK_n) begin
    if(RESET_n == 1'b0) begin
      RD_n <= 1'b1;
      WR_n <= 1'b1;
      IORQ_n <= 1'b1;
      MREQ_n <= 1'b1;
      DI_Reg <= 8'b00000000;
    end else begin
      if(CLKEN == 1'b1) begin
        RD_n <= 1'b1;
        WR_n <= 1'b1;
        IORQ_n <= 1'b1;
        MREQ_n <= 1'b1;
        if(MCycle == 3'b001) begin
          if(TState == 3'b001 || (TState == 3'b010 && Wait_n == 1'b0)) begin
            RD_n <=  ~IntCycle_n;
            MREQ_n <=  ~IntCycle_n;
            IORQ_n <= IntCycle_n;
          end
          if(TState == 3'b011) begin
            MREQ_n <= 1'b0;
          end
        end
        else begin
          if((TState == 3'b001 || (TState == 3'b010 && Wait_n == 1'b0)) && NoRead == 1'b0 && Write == 1'b0) begin
            RD_n <= 1'b0;
            IORQ_n <=  ~IORQ;
            MREQ_n <= IORQ;
          end
          if(T2Write == 0) begin
            if(TState == 3'b010 && Write == 1'b1) begin
              WR_n <= 1'b0;
              IORQ_n <=  ~IORQ;
              MREQ_n <= IORQ;
            end
          end
          else begin
            if((TState == 3'b001 || (TState == 3'b010 && Wait_n == 1'b0)) && Write == 1'b1) begin
              WR_n <= 1'b0;
              IORQ_n <=  ~IORQ;
              MREQ_n <= IORQ;
            end
          end
        end
        if(TState == 3'b010 && Wait_n == 1'b1) begin
          DI_Reg <= DI;
        end
      end
    end
  end


endmodule
