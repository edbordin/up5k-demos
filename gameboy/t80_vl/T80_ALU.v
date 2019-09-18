// File T80_ALU.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
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
// Ver 301 parity flag is just parity for 8080, also overflow for Z80, by Sean Riddle
// Ver 300 started tidyup
// MikeJ March 2005
// Latest version from www.fpgaarcade.com (original www.opencores.org)
//
// ****
//
// Z80 compatible microprocessor core
//
// Version : 0247
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
//      0214 : Fixed mostly flags, only the block instructions now fail the zex regression test
//
//      0238 : Fixed zero flag for 16 bit SBC and ADC
//
//      0240 : Added GB operations
//
//      0242 : Cleanup
//
//      0247 : Cleanup
//
// no timescale needed

module T80_ALU(
input wire Arith16,
input wire Z16,
input wire [3:0] ALU_Op,
input wire [5:0] IR,
input wire [1:0] ISet,
input wire [7:0] BusA,
input wire [7:0] BusB,
input wire [7:0] F_In,
output reg [7:0] Q,
output reg [7:0] F_Out
);

parameter [31:0] Mode=0;
parameter [31:0] Flag_C=0;
parameter [31:0] Flag_N=1;
parameter [31:0] Flag_P=2;
parameter [31:0] Flag_X=3;
parameter [31:0] Flag_H=4;
parameter [31:0] Flag_Y=5;
parameter [31:0] Flag_Z=6;
parameter [31:0] Flag_S=7;


wire UseCarry;
wire Carry7_v;
wire Overflow_v;
wire HalfCarry_v;
wire Carry_v;
wire [7:0] Q_v;
reg [7:0] BitMask;

  always @(*) begin
    case(IR[5:3])
      3'b000 : BitMask <= 8'b00000001;
      3'b001 : BitMask <= 8'b00000010;
      3'b010 : BitMask <= 8'b00000100;
      3'b011 : BitMask <= 8'b00001000;
      3'b100 : BitMask <= 8'b00010000;
      3'b101 : BitMask <= 8'b00100000;
      3'b110 : BitMask <= 8'b01000000;
      default : BitMask <= 8'b10000000;
    endcase
  end

  assign UseCarry =  ~ALU_Op[2] & ALU_Op[0];

  // AddSub(BusA(3 downto 0), BusB(3 downto 0), ALU_Op(1), ALU_Op(1) xor (UseCarry and F_In(Flag_C)), Q_v(3 downto 0), HalfCarry_v);
  AddSub addsub1 (BusA[3:0], BusB[3:0], ALU_Op[1], ALU_Op[1] ^ (UseCarry & F_In[Flag_C]), Q_v[3:0], HalfCarry_v);
  
  // AddSub(BusA(6 downto 4), BusB(6 downto 4), ALU_Op(1), HalfCarry_v, Q_v(6 downto 4), Carry7_v);
  AddSub addsub2 (BusA[6:4], BusB[6:4], ALU_Op[1], HalfCarry_v, Q_v[6:4], Carry7_v);

  // AddSub(BusA(7 downto 7), BusB(7 downto 7), ALU_Op(1), Carry7_v, Q_v(7 downto 7), Carry_v);
  AddSub addsub3 (BusA[7:7], BusB[7:7], ALU_Op[1], Carry7_v, Q_v[7:7], Carry_v);

  // bug fix - parity flag is just parity for 8080, also overflow for Z80
  always @(Carry_v, Carry7_v, Q_v) begin
    if((Mode == 2)) begin
      Overflow_v <=  ~(Q_v[0] ^ Q_v[1] ^ Q_v[2] ^ Q_v[3] ^ Q_v[4] ^ Q_v[5] ^ Q_v[6] ^ Q_v[7]);
    end
    else begin
      Overflow_v <= Carry_v ^ Carry7_v;
    end
  end

  always @(Arith16, ALU_Op, F_In, BusA, BusB, IR, Q_v, Carry_v, HalfCarry_v, Overflow_v, BitMask, ISet, Z16) begin : P1
    reg [7:0] Q_t;
    reg [8:0] DAA_Q;

    Q_t = 8'bxxxxxxxx;
    F_Out <= F_In;
    DAA_Q = 9'bxxxxxxxxx;
    case(ALU_Op)
    4'b0000,4'b0001,4'b0010,4'b0011,4'b0100,4'b0101,4'b0110,4'b0111 : begin
      F_Out[Flag_N] <= 1'b0;
      F_Out[Flag_C] <= 1'b0;
      case(ALU_Op[2:0])
      3'b000,3'b001 : begin
        // ADD, ADC
        Q_t = Q_v;
        F_Out[Flag_C] <= Carry_v;
        F_Out[Flag_H] <= HalfCarry_v;
        F_Out[Flag_P] <= Overflow_v;
      end
      3'b010,3'b011,3'b111 : begin
        // SUB, SBC, CP
        Q_t = Q_v;
        F_Out[Flag_N] <= 1'b1;
        F_Out[Flag_C] <=  ~Carry_v;
        F_Out[Flag_H] <=  ~HalfCarry_v;
        F_Out[Flag_P] <= Overflow_v;
      end
      3'b100 : begin
        // AND
        Q_t[7:0] = BusA & BusB;
        F_Out[Flag_H] <= 1'b1;
      end
      3'b101 : begin
        // XOR
        Q_t[7:0] = BusA ^ BusB;
        F_Out[Flag_H] <= 1'b0;
      end
      default : begin
        // OR "110"
        Q_t[7:0] = BusA | BusB;
        F_Out[Flag_H] <= 1'b0;
      end
      endcase
      if(ALU_Op[2:0] == 3'b111) begin
        // CP
        F_Out[Flag_X] <= BusB[3];
        F_Out[Flag_Y] <= BusB[5];
      end
      else begin
        F_Out[Flag_X] <= Q_t[3];
        F_Out[Flag_Y] <= Q_t[5];
      end
      if(Q_t[7:0] == 8'b00000000) begin
        F_Out[Flag_Z] <= 1'b1;
        if(Z16 == 1'b1) begin
          F_Out[Flag_Z] <= F_In[Flag_Z];
          // 16 bit ADC,SBC
        end
      end
      else begin
        F_Out[Flag_Z] <= 1'b0;
      end
      F_Out[Flag_S] <= Q_t[7];
      case(ALU_Op[2:0])
      3'b000,3'b001,3'b010,3'b011,3'b111 : begin
        // ADD, ADC, SUB, SBC, CP
      end
      default : begin
        F_Out[Flag_P] <=  ~(Q_t[0] ^ Q_t[1] ^ Q_t[2] ^ Q_t[3] ^ Q_t[4] ^ Q_t[5] ^ Q_t[6] ^ Q_t[7]);
      end
      endcase
      if(Arith16 == 1'b1) begin
        F_Out[Flag_S] <= F_In[Flag_S];
        F_Out[Flag_Z] <= F_In[Flag_Z];
        F_Out[Flag_P] <= F_In[Flag_P];
      end
    end
    4'b1100 : begin
      // DAA
      F_Out[Flag_H] <= F_In[Flag_H];
      F_Out[Flag_C] <= F_In[Flag_C];
      DAA_Q[7:0] = BusA;
      DAA_Q[8] = 1'b0;
      if(F_In[Flag_N] == 1'b0) begin
        // After addition
        // Alow > 9 or H = 1
        if(DAA_Q[3:0] > 9 || F_In[Flag_H] == 1'b1) begin
          if((DAA_Q[3:0] > 9)) begin
            F_Out[Flag_H] <= 1'b1;
          end
          else begin
            F_Out[Flag_H] <= 1'b0;
          end
          DAA_Q = DAA_Q + 6;
        end
        // new Ahigh > 9 or C = 1
        if(DAA_Q[8:4] > 9 || F_In[Flag_C] == 1'b1) begin
          DAA_Q = DAA_Q + 96;
          // 0x60
        end
      end
      else begin
        // After subtraction
        if(DAA_Q[3:0] > 9 || F_In[Flag_H] == 1'b1) begin
          if(DAA_Q[3:0] > 5) begin
            F_Out[Flag_H] <= 1'b0;
          end
          DAA_Q[7:0] = DAA_Q[7:0] - 6;
        end
        if((BusA) > 153 || F_In[Flag_C] == 1'b1) begin
          DAA_Q = DAA_Q - 352;
          // 0x160
        end
      end
      F_Out[Flag_X] <= DAA_Q[3];
      F_Out[Flag_Y] <= DAA_Q[5];
      F_Out[Flag_C] <= F_In[Flag_C] | DAA_Q[8];
      Q_t = DAA_Q[7:0];
      if(DAA_Q[7:0] == 8'b00000000) begin
        F_Out[Flag_Z] <= 1'b1;
      end
      else begin
        F_Out[Flag_Z] <= 1'b0;
      end
      F_Out[Flag_S] <= DAA_Q[7];
      F_Out[Flag_P] <=  ~(DAA_Q[0] ^ DAA_Q[1] ^ DAA_Q[2] ^ DAA_Q[3] ^ DAA_Q[4] ^ DAA_Q[5] ^ DAA_Q[6] ^ DAA_Q[7]);
    end
    4'b1101,4'b1110 : begin
      // RLD, RRD
      Q_t[7:4] = BusA[7:4];
      if(ALU_Op[0] == 1'b1) begin
        Q_t[3:0] = BusB[7:4];
      end
      else begin
        Q_t[3:0] = BusB[3:0];
      end
      F_Out[Flag_H] <= 1'b0;
      F_Out[Flag_N] <= 1'b0;
      F_Out[Flag_X] <= Q_t[3];
      F_Out[Flag_Y] <= Q_t[5];
      if(Q_t[7:0] == 8'b00000000) begin
        F_Out[Flag_Z] <= 1'b1;
      end
      else begin
        F_Out[Flag_Z] <= 1'b0;
      end
      F_Out[Flag_S] <= Q_t[7];
      F_Out[Flag_P] <=  ~(Q_t[0] ^ Q_t[1] ^ Q_t[2] ^ Q_t[3] ^ Q_t[4] ^ Q_t[5] ^ Q_t[6] ^ Q_t[7]);
    end
    4'b1001 : begin
      // BIT
      Q_t[7:0] = BusB & BitMask;
      F_Out[Flag_S] <= Q_t[7];
      if(Q_t[7:0] == 8'b00000000) begin
        F_Out[Flag_Z] <= 1'b1;
        F_Out[Flag_P] <= 1'b1;
      end
      else begin
        F_Out[Flag_Z] <= 1'b0;
        F_Out[Flag_P] <= 1'b0;
      end
      F_Out[Flag_H] <= 1'b1;
      F_Out[Flag_N] <= 1'b0;
      F_Out[Flag_X] <= 1'b0;
      F_Out[Flag_Y] <= 1'b0;
      if(IR[2:0] != 3'b110) begin
        F_Out[Flag_X] <= BusB[3];
        F_Out[Flag_Y] <= BusB[5];
      end
    end
    4'b1010 : begin
      // SET
      Q_t[7:0] = BusB | BitMask;
    end
    4'b1011 : begin
      // RES
      Q_t[7:0] = BusB &  ~BitMask;
    end
    4'b1000 : begin
      // ROT
      case(IR[5:3])
      3'b000 : begin
        // RLC
        Q_t[7:1] = BusA[6:0];
        Q_t[0] = BusA[7];
        F_Out[Flag_C] <= BusA[7];
      end
      3'b010 : begin
        // RL
        Q_t[7:1] = BusA[6:0];
        Q_t[0] = F_In[Flag_C];
        F_Out[Flag_C] <= BusA[7];
      end
      3'b001 : begin
        // RRC
        Q_t[6:0] = BusA[7:1];
        Q_t[7] = BusA[0];
        F_Out[Flag_C] <= BusA[0];
      end
      3'b011 : begin
        // RR
        Q_t[6:0] = BusA[7:1];
        Q_t[7] = F_In[Flag_C];
        F_Out[Flag_C] <= BusA[0];
      end
      3'b100 : begin
        // SLA
        Q_t[7:1] = BusA[6:0];
        Q_t[0] = 1'b0;
        F_Out[Flag_C] <= BusA[7];
      end
      3'b110 : begin
        // SLL (Undocumented) / SWAP
        if(Mode == 3) begin
          Q_t[7:4] = BusA[3:0];
          Q_t[3:0] = BusA[7:4];
          F_Out[Flag_C] <= 1'b0;
        end
        else begin
          Q_t[7:1] = BusA[6:0];
          Q_t[0] = 1'b1;
          F_Out[Flag_C] <= BusA[7];
        end
      end
      3'b101 : begin
        // SRA
        Q_t[6:0] = BusA[7:1];
        Q_t[7] = BusA[7];
        F_Out[Flag_C] <= BusA[0];
      end
      default : begin
        // SRL
        Q_t[6:0] = BusA[7:1];
        Q_t[7] = 1'b0;
        F_Out[Flag_C] <= BusA[0];
      end
      endcase
      F_Out[Flag_H] <= 1'b0;
      F_Out[Flag_N] <= 1'b0;
      F_Out[Flag_X] <= Q_t[3];
      F_Out[Flag_Y] <= Q_t[5];
      F_Out[Flag_S] <= Q_t[7];
      if(Q_t[7:0] == 8'b00000000) begin
        F_Out[Flag_Z] <= 1'b1;
      end
      else begin
        F_Out[Flag_Z] <= 1'b0;
      end
      F_Out[Flag_P] <=  ~(Q_t[0] ^ Q_t[1] ^ Q_t[2] ^ Q_t[3] ^ Q_t[4] ^ Q_t[5] ^ Q_t[6] ^ Q_t[7]);
      if(ISet == 2'b00) begin
        F_Out[Flag_P] <= F_In[Flag_P];
        F_Out[Flag_S] <= F_In[Flag_S];
        F_Out[Flag_Z] <= F_In[Flag_Z];
      end
    end
    default : begin
    end
    endcase
    Q <= Q_t;
  end


endmodule
