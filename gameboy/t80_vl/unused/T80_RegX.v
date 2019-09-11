// File T80_RegX.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
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
// T80 Registers for Xilinx Select RAM
//
// Version : 0244
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
//      http://www.opencores.org/cvsweb.shtml/t51/
//
// Limitations :
//
// File history :
//
//      0242 : Initial release
//
//      0244 : Removed UNISIM library and added componet declaration
//
// no timescale needed

module T80_Reg(
input wire Clk,
input wire CEN,
input wire WEH,
input wire WEL,
input wire [2:0] AddrA,
input wire [2:0] AddrB,
input wire [2:0] AddrC,
input wire [7:0] DIH,
input wire [7:0] DIL,
output wire [7:0] DOAH,
output wire [7:0] DOAL,
output wire [7:0] DOBH,
output wire [7:0] DOBL,
output wire [7:0] DOCH,
output wire [7:0] DOCL
);




wire ENH;
wire ENL;

  assign ENH = CEN & WEH;
  assign ENL = CEN & WEL;
  genvar I;
  generate for (I=0; I <= 7; I = I + 1) begin: bG1
      RAM16X1D Reg1H(
          .DPO(DOBH[i]),
      .SPO(DOAH[i]),
      .A0(AddrA[0]),
      .A1(AddrA[1]),
      .A2(AddrA[2]),
      .A3(1'b0),
      .D(DIH[i]),
      .DPRA0(AddrB[0]),
      .DPRA1(AddrB[1]),
      .DPRA2(AddrB[2]),
      .DPRA3(1'b0),
      .WCLK(Clk),
      .WE(ENH));

    RAM16X1D Reg1L(
          .DPO(DOBL[i]),
      .SPO(DOAL[i]),
      .A0(AddrA[0]),
      .A1(AddrA[1]),
      .A2(AddrA[2]),
      .A3(1'b0),
      .D(DIL[i]),
      .DPRA0(AddrB[0]),
      .DPRA1(AddrB[1]),
      .DPRA2(AddrB[2]),
      .DPRA3(1'b0),
      .WCLK(Clk),
      .WE(ENL));

    RAM16X1D Reg2H(
          .DPO(DOCH[i]),
      .SPO(/* open */),
      .A0(AddrA[0]),
      .A1(AddrA[1]),
      .A2(AddrA[2]),
      .A3(1'b0),
      .D(DIH[i]),
      .DPRA0(AddrC[0]),
      .DPRA1(AddrC[1]),
      .DPRA2(AddrC[2]),
      .DPRA3(1'b0),
      .WCLK(Clk),
      .WE(ENH));

    RAM16X1D Reg2L(
          .DPO(DOCL[i]),
      .SPO(/* open */),
      .A0(AddrA[0]),
      .A1(AddrA[1]),
      .A2(AddrA[2]),
      .A3(1'b0),
      .D(DIL[i]),
      .DPRA0(AddrC[0]),
      .DPRA1(AddrC[1]),
      .DPRA2(AddrC[2]),
      .DPRA3(1'b0),
      .WCLK(Clk),
      .WE(ENL));

  end
  endgenerate

endmodule
