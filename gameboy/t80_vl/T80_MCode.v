// File T80_MCode.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
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
// Ver 303 add undocumented DDCB and FDCB opcodes by TobiFlex 20.04.2010
// Ver 302 fixed IO cycle timing, tested thanks to Alessandro.
// Ver 300 started tidyup
// MikeJ March 2005
// Latest version from www.fpgaarcade.com (original www.opencores.org)
//
// ****
//
// Z80 compatible microprocessor core
//
// Version : 0242
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
//      0208 : First complete release
//
//      0211 : Fixed IM 1
//
//      0214 : Fixed mostly flags, only the block instructions now fail the zex regression test
//
//      0235 : Added IM 2 fix by Mike Johnson
//
//      0238 : Added NoRead signal
//
//      0238b: Fixed instruction timing for POP and DJNZ
//
//      0240 : Added (IX/IY+d) states, removed op-codes from mode 2 and added all remaining mode 3 op-codes
//      0240mj1 fix for HL inc/dec for INI, IND, INIR, INDR, OUTI, OUTD, OTIR, OTDR
//
//      0242 : Fixed I/O instruction timing, cleanup
//
// no timescale needed

module T80_MCode(
input wire [7:0] IR,
input wire [1:0] ISet,
input wire [2:0] MCycle,
input wire [7:0] F,
input wire NMICycle,
input wire IntCycle,
input wire [1:0] XY_State,
output reg [2:0] MCycles,
output reg [2:0] TStates,
output reg [1:0] Prefix,
output reg Inc_PC,
output reg Inc_WZ,
output reg [3:0] IncDec_16,
output reg Read_To_Reg,
output reg Read_To_Acc,
output reg [3:0] Set_BusA_To,
output reg [3:0] Set_BusB_To,
output reg [3:0] ALU_Op,
output reg Save_ALU,
output reg PreserveC,
output reg Arith16,
output reg [2:0] Set_Addr_To,
output reg IORQ,
output reg Jump,
output reg JumpE,
output reg JumpXY,
output reg Call,
output reg RstP,
output reg LDZ,
output reg LDW,
output reg LDSPHL,
output reg [2:0] Special_LD,
output reg ExchangeDH,
output reg ExchangeRp,
output reg ExchangeAF,
output reg ExchangeRS,
output reg I_DJNZ,
output reg I_CPL,
output reg I_CCF,
output reg I_SCF,
output reg I_RETN,
output reg I_BT,
output reg I_BC,
output reg I_BTR,
output reg I_RLD,
output reg I_RRD,
output reg I_INRC,
output reg SetDI,
output reg SetEI,
output reg [1:0] IMode,
output reg Halt,
output reg NoRead,
output reg Write,
output reg XYbit_undoc
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
// None,CB,ED,DD/FD
// BC,DE,HL,SP   0 is inc
// B,C,D,E,H,L,DI/DB,A,SP(L),SP(M),0,F
// B,C,D,E,H,L,DI,A,SP(L),SP(M),1,F,PC(L),PC(M),0
// ADD, ADC, SUB, SBC, AND, XOR, OR, CP, ROT, BIT, SET, RES, DAA, RLD, RRD, None
// aNone,aXY,aIOA,aSP,aBC,aDE,aZI
// A,I;A,R;I,A;R,A;None
localparam [2:0] aNone = 3'b111;
localparam [2:0] aBC = 3'b000;
localparam [2:0] aDE = 3'b001;
localparam [2:0] aXY = 3'b010;
localparam [2:0] aIOA = 3'b100;
localparam [2:0] aSP = 3'b101;
localparam [2:0] aZI = 3'b110;


function automatic is_cc_true(
  input [7:0] F,
  input [2:0] cc
);
  if (Mode == 3) begin
    case(cc)
      "000": is_cc_true = (F[7] == 1'b0); // NZ
      "001": is_cc_true = (F[7] == 1'b1); // Z
      "010": is_cc_true = (F[4] == 1'b0); // NC
      "011": is_cc_true = (F[4] == 1'b1); // C
      default: is_cc_true = 1'b0;
    endcase
  end else begin
    case(cc)
      "000": is_cc_true = (F[6] == 1'b0); // NZ
      "001": is_cc_true = (F[6] == 1'b1); // Z
      "010": is_cc_true = (F[0] == 1'b0); // NC
      "011": is_cc_true = (F[0] == 1'b1); // C
      "100": is_cc_true = (F[2] == 1'b0); // PO
      "101": is_cc_true = (F[2] == 1'b1); // PE
      "110": is_cc_true = (F[7] == 1'b0); // P
      "111": is_cc_true = (F[7] == 1'b1); // M
    endcase
  end
endfunction

  always @(IR, ISet, MCycle, F, NMICycle, IntCycle) begin : P1
    reg [2:0] DDD;
    reg [2:0] SSS;
    reg [1:0] DPair;
    reg [7:0] IRB;
  //bit_vector(7 downto 0);

    DDD = IR[5:3];
    SSS = IR[2:0];
    DPair = IR[5:4];
    IRB = IR;
    MCycles <= 3'b001;
    if(MCycle == 3'b001) begin
      TStates <= 3'b100;
    end
    else begin
      TStates <= 3'b011;
    end
    Prefix <= 2'b00;
    Inc_PC <= 1'b0;
    Inc_WZ <= 1'b0;
    IncDec_16 <= 4'b0000;
    Read_To_Acc <= 1'b0;
    Read_To_Reg <= 1'b0;
    Set_BusB_To <= 4'b0000;
    Set_BusA_To <= 4'b0000;
    ALU_Op <= {1'b0,IR[5:3]};
    Save_ALU <= 1'b0;
    PreserveC <= 1'b0;
    Arith16 <= 1'b0;
    IORQ <= 1'b0;
    Set_Addr_To <= aNone;
    Jump <= 1'b0;
    JumpE <= 1'b0;
    JumpXY <= 1'b0;
    Call <= 1'b0;
    RstP <= 1'b0;
    LDZ <= 1'b0;
    LDW <= 1'b0;
    LDSPHL <= 1'b0;
    Special_LD <= 3'b000;
    ExchangeDH <= 1'b0;
    ExchangeRp <= 1'b0;
    ExchangeAF <= 1'b0;
    ExchangeRS <= 1'b0;
    I_DJNZ <= 1'b0;
    I_CPL <= 1'b0;
    I_CCF <= 1'b0;
    I_SCF <= 1'b0;
    I_RETN <= 1'b0;
    I_BT <= 1'b0;
    I_BC <= 1'b0;
    I_BTR <= 1'b0;
    I_RLD <= 1'b0;
    I_RRD <= 1'b0;
    I_INRC <= 1'b0;
    SetDI <= 1'b0;
    SetEI <= 1'b0;
    IMode <= 2'b11;
    Halt <= 1'b0;
    NoRead <= 1'b0;
    Write <= 1'b0;
    XYbit_undoc <= 1'b0;
    case(ISet)
    2'b00 : begin
      //----------------------------------------------------------------------------
      //
      //      Unprefixed instructions
      //
      //----------------------------------------------------------------------------
      case(IRB)
            // 8 BIT LOAD GROUP
      8'b01000000,8'b01000001,8'b01000010,8'b01000011,8'b01000100,8'b01000101,8'b01000111,8'b01001000,8'b01001001,8'b01001010,8'b01001011,8'b01001100,8'b01001101,8'b01001111,8'b01010000,8'b01010001,8'b01010010,8'b01010011,8'b01010100,8'b01010101,8'b01010111,8'b01011000,8'b01011001,8'b01011010,8'b01011011,8'b01011100,8'b01011101,8'b01011111,8'b01100000,8'b01100001,8'b01100010,8'b01100011,8'b01100100,8'b01100101,8'b01100111,8'b01101000,8'b01101001,8'b01101010,8'b01101011,8'b01101100,8'b01101101,8'b01101111,8'b01111000,8'b01111001,8'b01111010,8'b01111011,8'b01111100,8'b01111101,8'b01111111 : begin
        // LD r,r'
        Set_BusB_To[2:0] <= SSS;
        ExchangeRp <= 1'b1;
        Set_BusA_To[2:0] <= DDD;
        Read_To_Reg <= 1'b1;
      end
      8'b00000110,8'b00001110,8'b00010110,8'b00011110,8'b00100110,8'b00101110,8'b00111110 : begin
        // LD r,n
        MCycles <= 3'b010;
        case(MCycle)
                //to_integer(unsigned(MCycle)) is
        3'b010 : begin
          //2 =>
          Inc_PC <= 1'b1;
          Set_BusA_To[2:0] <= DDD;
          Read_To_Reg <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01000110,8'b01001110,8'b01010110,8'b01011110,8'b01100110,8'b01101110,8'b01111110 : begin
        // LD r,(HL)
        MCycles <= 3'b010;
        case(MCycle)
                //to_integer(unsigned(MCycle)) is
        3'b001 : begin
          //1 =>
          Set_Addr_To <= aXY;
        end
        3'b010 : begin
          //2 =>
          Set_BusA_To[2:0] <= DDD;
          Read_To_Reg <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01110000,8'b01110001,8'b01110010,8'b01110011,8'b01110100,8'b01110101,8'b01110111 : begin
        // LD (HL),r
        MCycles <= 3'b010;
        case(MCycle)
                //to_integer(unsigned(MCycle)) is
        3'b001 : begin
          //1 =>
          Set_Addr_To <= aXY;
          Set_BusB_To[2:0] <= SSS;
          Set_BusB_To[3] <= 1'b0;
        end
        3'b010 : begin
          //2 =>
          Write <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00110110 : begin
        // LD (HL),n
        MCycles <= 3'b011;
        case(MCycle)
                //to_integer(unsigned(MCycle)) is
        3'b010 : begin
          //2 =>
          Inc_PC <= 1'b1;
          Set_Addr_To <= aXY;
          Set_BusB_To[2:0] <= SSS;
          Set_BusB_To[3] <= 1'b0;
        end
        3'b011 : begin
          //3 =>
          Write <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00001010 : begin
        // LD A,(BC)
        MCycles <= 3'b010;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aBC;
        end
        3'b010 : begin
          // 2 =>
          Read_To_Acc <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00011010 : begin
        // LD A,(DE)
        MCycles <= 3'b010;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aDE;
        end
        3'b010 : begin
          // 2 =>
          Read_To_Acc <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00111010 : begin
        if(Mode == 3) begin
          // LDD A,(HL)
          MCycles <= 3'b010;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001 : begin
            // 1 =>
            Set_Addr_To <= aXY;
          end
          3'b010 : begin
            // 2 =>
            Read_To_Acc <= 1'b1;
            IncDec_16 <= 4'b1110;
          end
          default : begin
          end
          endcase
        end
        else begin
          // LD A,(nn)
          MCycles <= 3'b100;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
            LDZ <= 1'b1;
          end
          3'b011 : begin
            // 3 =>
            Set_Addr_To <= aZI;
            Inc_PC <= 1'b1;
          end
          3'b100 : begin
            // 4 =>
            Read_To_Acc <= 1'b1;
          end
          default : begin
          end
          endcase
        end
      end
      8'b00000010 : begin
        // LD (BC),A
        MCycles <= 3'b010;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aBC;
          Set_BusB_To <= 4'b0111;
        end
        3'b010 : begin
          // 2 =>
          Write <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00010010 : begin
        // LD (DE),A
        MCycles <= 3'b010;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aDE;
          Set_BusB_To <= 4'b0111;
        end
        3'b010 : begin
          // 2 =>
          Write <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00110010 : begin
        if(Mode == 3) begin
          // LDD (HL),A
          MCycles <= 3'b010;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001 : begin
            // 1 =>
            Set_Addr_To <= aXY;
            Set_BusB_To <= 4'b0111;
          end
          3'b010 : begin
            // 2 =>
            Write <= 1'b1;
            IncDec_16 <= 4'b1110;
          end
          default : begin
          end
          endcase
        end
        else begin
          // LD (nn),A
          MCycles <= 3'b100;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
            LDZ <= 1'b1;
          end
          3'b011 : begin
            // 3 =>
            Set_Addr_To <= aZI;
            Inc_PC <= 1'b1;
            Set_BusB_To <= 4'b0111;
          end
          3'b100 : begin
            // 4 =>
            Write <= 1'b1;
          end
          default : begin
          end
          endcase
        end
        // 16 BIT LOAD GROUP
      end
      8'b00000001,8'b00010001,8'b00100001,8'b00110001 : begin
        // LD dd,nn
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b010 : begin
          // 2 =>
          Inc_PC <= 1'b1;
          Read_To_Reg <= 1'b1;
          if(DPair == 2'b11) begin
            Set_BusA_To[3:0] <= 4'b1000;
          end
          else begin
            Set_BusA_To[2:1] <= DPair;
            Set_BusA_To[0] <= 1'b1;
          end
        end
        3'b011 : begin
          // 3 =>
          Inc_PC <= 1'b1;
          Read_To_Reg <= 1'b1;
          if(DPair == 2'b11) begin
            Set_BusA_To[3:0] <= 4'b1001;
          end
          else begin
            Set_BusA_To[2:1] <= DPair;
            Set_BusA_To[0] <= 1'b0;
          end
        end
        default : begin
        end
        endcase
      end
      8'b00101010 : begin
        if(Mode == 3) begin
          // LDI A,(HL)
          MCycles <= 3'b010;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001 : begin
            // 1 =>
            Set_Addr_To <= aXY;
          end
          3'b010 : begin
            // 2 =>
            Read_To_Acc <= 1'b1;
            IncDec_16 <= 4'b0110;
          end
          default : begin
          end
          endcase
        end
        else begin
          // LD HL,(nn)
          MCycles <= 3'b101;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
            LDZ <= 1'b1;
          end
          3'b011 : begin
            // 3 =>
            Set_Addr_To <= aZI;
            Inc_PC <= 1'b1;
            LDW <= 1'b1;
          end
          3'b100 : begin
            // 4 =>
            Set_BusA_To[2:0] <= 3'b101;
            // L
            Read_To_Reg <= 1'b1;
            Inc_WZ <= 1'b1;
            Set_Addr_To <= aZI;
          end
          3'b101 : begin
            // 5 =>
            Set_BusA_To[2:0] <= 3'b100;
            // H
            Read_To_Reg <= 1'b1;
          end
          default : begin
          end
          endcase
        end
      end
      8'b00100010 : begin
        if(Mode == 3) begin
          // LDI (HL),A
          MCycles <= 3'b010;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001 : begin
            // 1 =>
            Set_Addr_To <= aXY;
            Set_BusB_To <= 4'b0111;
          end
          3'b010 : begin
            // 2 =>
            Write <= 1'b1;
            IncDec_16 <= 4'b0110;
          end
          default : begin
          end
          endcase
        end
        else begin
          // LD (nn),HL
          MCycles <= 3'b101;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
            LDZ <= 1'b1;
          end
          3'b011 : begin
            // 3 =>
            Set_Addr_To <= aZI;
            Inc_PC <= 1'b1;
            LDW <= 1'b1;
            Set_BusB_To <= 4'b0101;
            // L
          end
          3'b100 : begin
            // 4 =>
            Inc_WZ <= 1'b1;
            Set_Addr_To <= aZI;
            Write <= 1'b1;
            Set_BusB_To <= 4'b0100;
            // H
          end
          3'b101 : begin
            // 5 =>
            Write <= 1'b1;
          end
          default : begin
          end
          endcase
        end
      end
      8'b11111001 : begin
        // LD SP,HL
        TStates <= 3'b110;
        LDSPHL <= 1'b1;
      end
      8'b11000101,8'b11010101,8'b11100101,8'b11110101 : begin
        // PUSH qq
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          TStates <= 3'b101;
          IncDec_16 <= 4'b1111;
          Set_Addr_To <= aSP;
          if(DPair == 2'b11) begin
            Set_BusB_To <= 4'b0111;
          end
          else begin
            Set_BusB_To[2:1] <= DPair;
            Set_BusB_To[0] <= 1'b0;
            Set_BusB_To[3] <= 1'b0;
          end
        end
        3'b010 : begin
          // 2 =>
          IncDec_16 <= 4'b1111;
          Set_Addr_To <= aSP;
          if(DPair == 2'b11) begin
            Set_BusB_To <= 4'b1011;
          end
          else begin
            Set_BusB_To[2:1] <= DPair;
            Set_BusB_To[0] <= 1'b1;
            Set_BusB_To[3] <= 1'b0;
          end
          Write <= 1'b1;
        end
        3'b011 : begin
          // 3 =>
          Write <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b11000001,8'b11010001,8'b11100001,8'b11110001 : begin
        // POP qq
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aSP;
        end
        3'b010 : begin
          // 2 =>
          IncDec_16 <= 4'b0111;
          Set_Addr_To <= aSP;
          Read_To_Reg <= 1'b1;
          if(DPair == 2'b11) begin
            Set_BusA_To[3:0] <= 4'b1011;
          end
          else begin
            Set_BusA_To[2:1] <= DPair;
            Set_BusA_To[0] <= 1'b1;
          end
        end
        3'b011 : begin
          // 3 =>
          IncDec_16 <= 4'b0111;
          Read_To_Reg <= 1'b1;
          if(DPair == 2'b11) begin
            Set_BusA_To[3:0] <= 4'b0111;
          end
          else begin
            Set_BusA_To[2:1] <= DPair;
            Set_BusA_To[0] <= 1'b0;
          end
        end
        default : begin
        end
        endcase
        // EXCHANGE, BLOCK TRANSFER AND SEARCH GROUP
      end
      8'b11101011 : begin
        if(Mode != 3) begin
          // EX DE,HL
          ExchangeDH <= 1'b1;
        end
      end
      8'b00001000 : begin
        if(Mode == 3) begin
          // LD (nn),SP
          MCycles <= 3'b101;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
            LDZ <= 1'b1;
          end
          3'b011 : begin
            // 3 =>
            Set_Addr_To <= aZI;
            Inc_PC <= 1'b1;
            LDW <= 1'b1;
            Set_BusB_To <= 4'b1000;
          end
          3'b100 : begin
            // 4 =>
            Inc_WZ <= 1'b1;
            Set_Addr_To <= aZI;
            Write <= 1'b1;
            Set_BusB_To <= 4'b1001;
          end
          3'b101 : begin
            // 5 =>
            Write <= 1'b1;
          end
          default : begin
          end
          endcase
        end
        else if(Mode < 2) begin
          // EX AF,AF'
          ExchangeAF <= 1'b1;
        end
      end
      8'b11011001 : begin
        if(Mode == 3) begin
          // RETI
          MCycles <= 3'b011;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001 : begin
            // 1 =>
            Set_Addr_To <= aSP;
          end
          3'b010 : begin
            // 2 =>
            IncDec_16 <= 4'b0111;
            Set_Addr_To <= aSP;
            LDZ <= 1'b1;
          end
          3'b011 : begin
            // 3 =>
            Jump <= 1'b1;
            IncDec_16 <= 4'b0111;
            //I_RETN <= '1';
            SetEI <= 1'b1;
          end
          default : begin
          end
          endcase
        end
        else if(Mode < 2) begin
          // EXX
          ExchangeRS <= 1'b1;
        end
      end
      8'b11100011 : begin
        if(Mode != 3) begin
          // EX (SP),HL
          MCycles <= 3'b101;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001 : begin
            // 1 =>
            Set_Addr_To <= aSP;
          end
          3'b010 : begin
            // 2 =>
            Read_To_Reg <= 1'b1;
            Set_BusA_To <= 4'b0101;
            Set_BusB_To <= 4'b0101;
            Set_Addr_To <= aSP;
          end
          3'b011 : begin
            // 3 =>
            IncDec_16 <= 4'b0111;
            Set_Addr_To <= aSP;
            TStates <= 3'b100;
            Write <= 1'b1;
          end
          3'b100 : begin
            // 4 =>
            Read_To_Reg <= 1'b1;
            Set_BusA_To <= 4'b0100;
            Set_BusB_To <= 4'b0100;
            Set_Addr_To <= aSP;
          end
          3'b101 : begin
            // 5 =>
            IncDec_16 <= 4'b1111;
            TStates <= 3'b101;
            Write <= 1'b1;
          end
          default : begin
          end
          endcase
        end
        // 8 BIT ARITHMETIC AND LOGICAL GROUP
      end
      8'b10000000,8'b10000001,8'b10000010,8'b10000011,8'b10000100,8'b10000101,8'b10000111,8'b10001000,8'b10001001,8'b10001010,8'b10001011,8'b10001100,8'b10001101,8'b10001111,8'b10010000,8'b10010001,8'b10010010,8'b10010011,8'b10010100,8'b10010101,8'b10010111,8'b10011000,8'b10011001,8'b10011010,8'b10011011,8'b10011100,8'b10011101,8'b10011111,8'b10100000,8'b10100001,8'b10100010,8'b10100011,8'b10100100,8'b10100101,8'b10100111,8'b10101000,8'b10101001,8'b10101010,8'b10101011,8'b10101100,8'b10101101,8'b10101111,8'b10110000,8'b10110001,8'b10110010,8'b10110011,8'b10110100,8'b10110101,8'b10110111,8'b10111000,8'b10111001,8'b10111010,8'b10111011,8'b10111100,8'b10111101,8'b10111111 : begin
        // ADD A,r
        // ADC A,r
        // SUB A,r
        // SBC A,r
        // AND A,r
        // OR A,r
        // XOR A,r
        // CP A,r
        Set_BusB_To[2:0] <= SSS;
        Set_BusA_To[2:0] <= 3'b111;
        Read_To_Reg <= 1'b1;
        Save_ALU <= 1'b1;
      end
      8'b10000110,8'b10001110,8'b10010110,8'b10011110,8'b10100110,8'b10101110,8'b10110110,8'b10111110 : begin
        // ADD A,(HL)
        // ADC A,(HL)
        // SUB A,(HL)
        // SBC A,(HL)
        // AND A,(HL)
        // OR A,(HL)
        // XOR A,(HL)
        // CP A,(HL)
        MCycles <= 3'b010;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aXY;
        end
        3'b010 : begin
          // 2 =>
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          Set_BusB_To[2:0] <= SSS;
          Set_BusA_To[2:0] <= 3'b111;
        end
        default : begin
        end
        endcase
      end
      8'b11000110,8'b11001110,8'b11010110,8'b11011110,8'b11100110,8'b11101110,8'b11110110,8'b11111110 : begin
        // ADD A,n
        // ADC A,n
        // SUB A,n
        // SBC A,n
        // AND A,n
        // OR A,n
        // XOR A,n
        // CP A,n
        MCycles <= 3'b010;
        if(MCycle == 3'b010) begin
          Inc_PC <= 1'b1;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          Set_BusB_To[2:0] <= SSS;
          Set_BusA_To[2:0] <= 3'b111;
        end
      end
      8'b00000100,8'b00001100,8'b00010100,8'b00011100,8'b00100100,8'b00101100,8'b00111100 : begin
        // INC r
        Set_BusB_To <= 4'b1010;
        Set_BusA_To[2:0] <= DDD;
        Read_To_Reg <= 1'b1;
        Save_ALU <= 1'b1;
        PreserveC <= 1'b1;
        ALU_Op <= 4'b0000;
      end
      8'b00110100 : begin
        // INC (HL)
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aXY;
        end
        3'b010 : begin
          // 2 =>
          TStates <= 3'b100;
          Set_Addr_To <= aXY;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          PreserveC <= 1'b1;
          ALU_Op <= 4'b0000;
          Set_BusB_To <= 4'b1010;
          Set_BusA_To[2:0] <= DDD;
        end
        3'b011 : begin
          // 3 =>
          Write <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00000101,8'b00001101,8'b00010101,8'b00011101,8'b00100101,8'b00101101,8'b00111101 : begin
        // DEC r
        Set_BusB_To <= 4'b1010;
        Set_BusA_To[2:0] <= DDD;
        Read_To_Reg <= 1'b1;
        Save_ALU <= 1'b1;
        PreserveC <= 1'b1;
        ALU_Op <= 4'b0010;
      end
      8'b00110101 : begin
        // DEC (HL)
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aXY;
        end
        3'b010 : begin
          // 2 =>
          TStates <= 3'b100;
          Set_Addr_To <= aXY;
          ALU_Op <= 4'b0010;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          PreserveC <= 1'b1;
          Set_BusB_To <= 4'b1010;
          Set_BusA_To[2:0] <= DDD;
        end
        3'b011 : begin
          // 3 =>
          Write <= 1'b1;
        end
        default : begin
        end
        endcase
        // GENERAL PURPOSE ARITHMETIC AND CPU CONTROL GROUPS
      end
      8'b00100111 : begin
        // DAA
        Set_BusA_To[2:0] <= 3'b111;
        Read_To_Reg <= 1'b1;
        ALU_Op <= 4'b1100;
        Save_ALU <= 1'b1;
      end
      8'b00101111 : begin
        // CPL
        I_CPL <= 1'b1;
      end
      8'b00111111 : begin
        // CCF
        I_CCF <= 1'b1;
      end
      8'b00110111 : begin
        // SCF
        I_SCF <= 1'b1;
      end
      8'b00000000 : begin
        if(NMICycle == 1'b1) begin
          // NMI
          MCycles <= 3'b011;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001 : begin
            // 1 =>
            TStates <= 3'b101;
            IncDec_16 <= 4'b1111;
            Set_Addr_To <= aSP;
            Set_BusB_To <= 4'b1101;
          end
          3'b010 : begin
            // 2 =>
            TStates <= 3'b100;
            Write <= 1'b1;
            IncDec_16 <= 4'b1111;
            Set_Addr_To <= aSP;
            Set_BusB_To <= 4'b1100;
          end
          3'b011 : begin
            // 3 =>
            TStates <= 3'b100;
            Write <= 1'b1;
          end
          default : begin
          end
          endcase
        end
        else if(IntCycle == 1'b1) begin
          // INT (IM 2)
          if(Mode == 3) begin
            MCycles <= 3'b011;
          end
          else begin
            MCycles <= 3'b101;
          end
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001 : begin
            // 1 =>
            LDZ <= 1'b1;
            TStates <= 3'b101;
            IncDec_16 <= 4'b1111;
            Set_Addr_To <= aSP;
            Set_BusB_To <= 4'b1101;
          end
          3'b010 : begin
            // 2 =>
            TStates <= 3'b100;
            Write <= 1'b1;
            IncDec_16 <= 4'b1111;
            Set_Addr_To <= aSP;
            Set_BusB_To <= 4'b1100;
          end
          3'b011 : begin
            // 3 =>
            TStates <= 3'b100;
            Write <= 1'b1;
          end
          3'b100 : begin
            // 4 =>
            Inc_PC <= 1'b1;
            LDZ <= 1'b1;
          end
          3'b101 : begin
            // 5 =>
            Jump <= 1'b1;
          end
          default : begin
          end
          endcase
        end
        else begin
          // NOP
        end
      end
      8'b01110110 : begin
        // HALT
        Halt <= 1'b1;
      end
      8'b11110011 : begin
        // DI
        SetDI <= 1'b1;
      end
      8'b11111011 : begin
        // EI
        SetEI <= 1'b1;
        // 16 BIT ARITHMETIC GROUP
      end
      8'b00001001,8'b00011001,8'b00101001,8'b00111001 : begin
        // ADD HL,ss
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b010 : begin
          // 2 =>
          NoRead <= 1'b1;
          ALU_Op <= 4'b0000;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          Set_BusA_To[2:0] <= 3'b101;
          case(IR[5:4])
                    // to_integer(unsigned(IR(5 downto 4))) is
          2'b00,2'b01,2'b10 : begin
            Set_BusB_To[2:1] <= IR[5:4];
            Set_BusB_To[0] <= 1'b1;
          end
          default : begin
            Set_BusB_To <= 4'b1000;
          end
          endcase
          TStates <= 3'b100;
          Arith16 <= 1'b1;
        end
        3'b011 : begin
          // 3 =>
          NoRead <= 1'b1;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          ALU_Op <= 4'b0001;
          Set_BusA_To[2:0] <= 3'b100;
          case(IR[5:4])
                    // to_integer(unsigned(IR(5 downto 4))) is
          2'b00,2'b01,2'b10 : begin
            Set_BusB_To[2:1] <= IR[5:4];
          end
          default : begin
            Set_BusB_To <= 4'b1001;
          end
          endcase
          Arith16 <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00000011,8'b00010011,8'b00100011,8'b00110011 : begin
        // INC ss
        TStates <= 3'b110;
        IncDec_16[3:2] <= 2'b01;
        IncDec_16[1:0] <= DPair;
      end
      8'b00001011,8'b00011011,8'b00101011,8'b00111011 : begin
        // DEC ss
        TStates <= 3'b110;
        IncDec_16[3:2] <= 2'b11;
        IncDec_16[1:0] <= DPair;
        // ROTATE AND SHIFT GROUP
      end
      8'b00000111,8'b00010111,8'b00001111,8'b00011111 : begin
        // RLCA			
        // RLA			
        // RRCA			
        // RRA
        Set_BusA_To[2:0] <= 3'b111;
        ALU_Op <= 4'b1000;
        Read_To_Reg <= 1'b1;
        Save_ALU <= 1'b1;
        // JUMP GROUP
      end
      8'b11000011 : begin
        // JP nn
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b010 : begin
          // 2 =>
          Inc_PC <= 1'b1;
          LDZ <= 1'b1;
        end
        3'b011 : begin
          // 3 =>
          Inc_PC <= 1'b1;
          Jump <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b11000010,8'b11001010,8'b11010010,8'b11011010,8'b11100010,8'b11101010,8'b11110010,8'b11111010 : begin
        if(IR[5] == 1'b1 && Mode == 3) begin
          case(IRB[4:3])
          2'b00 : begin
            // LD ($FF00+C),A
            MCycles <= 3'b010;
            case(MCycle)
                        // to_integer(unsigned(MCycle)) is
            3'b001 : begin
              // 1 =>
              Set_Addr_To <= aBC;
              Set_BusB_To <= 4'b0111;
              IORQ <= 1'b1;
              //TH  must be earlier to be stable when address is generated
            end
            3'b010 : begin
              // 2 =>
              Write <= 1'b1;
              //TH this is too late IORQ <= '1';
            end
            default : begin
            end
            endcase
          end
          2'b01 : begin
            // LD (nn),A
            MCycles <= 3'b100;
            case(MCycle)
                        // to_integer(unsigned(MCycle)) is
            3'b010 : begin
              // 2 =>
              Inc_PC <= 1'b1;
              LDZ <= 1'b1;
            end
            3'b011 : begin
              // 3 =>
              Set_Addr_To <= aZI;
              Inc_PC <= 1'b1;
              Set_BusB_To <= 4'b0111;
            end
            3'b100 : begin
              // 4 =>
              Write <= 1'b1;
            end
            default : begin
            end
            endcase
          end
          2'b10 : begin
            // LD A,($FF00+C)
            MCycles <= 3'b010;
            case(MCycle)
                        // to_integer(unsigned(MCycle)) is
            3'b001 : begin
              // 1 =>
              Set_Addr_To <= aBC;
              IORQ <= 1'b1;
              //TH  must be earlier to be stable when address is generated
            end
            3'b010 : begin
              // 2 =>
              Read_To_Acc <= 1'b1;
              //TH this is too late IORQ <= '1';
            end
            default : begin
            end
            endcase
          end
          2'b11 : begin
            // LD A,(nn)
            MCycles <= 3'b100;
            case(MCycle)
                        // to_integer(unsigned(MCycle)) is
            3'b010 : begin
              // 2 =>
              Inc_PC <= 1'b1;
              LDZ <= 1'b1;
            end
            3'b011 : begin
              // 3 =>
              Set_Addr_To <= aZI;
              Inc_PC <= 1'b1;
            end
            3'b100 : begin
              // 4 =>
              Read_To_Acc <= 1'b1;
            end
            default : begin
            end
            endcase
          end
          endcase
        end
        else begin
          // JP cc,nn
          MCycles <= 3'b011;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
            LDZ <= 1'b1;
          end
          3'b011 : begin
            // 3 =>
            Inc_PC <= 1'b1;
            if(is_cc_true(F, IR[5:3])) begin
              //is_cc_true(F, to_bitvector(IR(5 downto 3))) then
              Jump <= 1'b1;
            end
          end
          default : begin
          end
          endcase
        end
      end
      8'b00011000 : begin
        if(Mode != 2) begin
          // JR e
          MCycles <= 3'b011;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
          end
          3'b011 : begin
            // 3 =>
            NoRead <= 1'b1;
            JumpE <= 1'b1;
            TStates <= 3'b101;
          end
          default : begin
          end
          endcase
        end
      end
      8'b00111000 : begin
        if(Mode != 2) begin
          // JR C,e
          MCycles <= 3'b011;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
            if(F[Flag_C] == 1'b0) begin
              MCycles <= 3'b010;
            end
          end
          3'b011 : begin
            // 3 =>
            NoRead <= 1'b1;
            JumpE <= 1'b1;
            TStates <= 3'b101;
          end
          default : begin
          end
          endcase
        end
      end
      8'b00110000 : begin
        if(Mode != 2) begin
          // JR NC,e
          MCycles <= 3'b011;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
            if(F[Flag_C] == 1'b1) begin
              MCycles <= 3'b010;
            end
          end
          3'b011 : begin
            // 3 =>
            NoRead <= 1'b1;
            JumpE <= 1'b1;
            TStates <= 3'b101;
          end
          default : begin
          end
          endcase
        end
      end
      8'b00101000 : begin
        if(Mode != 2) begin
          // JR Z,e
          MCycles <= 3'b011;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
            if(F[Flag_Z] == 1'b0) begin
              MCycles <= 3'b010;
            end
          end
          3'b011 : begin
            // 3 =>
            NoRead <= 1'b1;
            JumpE <= 1'b1;
            TStates <= 3'b101;
          end
          default : begin
          end
          endcase
        end
      end
      8'b00100000 : begin
        if(Mode != 2) begin
          // JR NZ,e
          MCycles <= 3'b011;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
            if(F[Flag_Z] == 1'b1) begin
              MCycles <= 3'b010;
            end
          end
          3'b011 : begin
            // 3 =>
            NoRead <= 1'b1;
            JumpE <= 1'b1;
            TStates <= 3'b101;
          end
          default : begin
          end
          endcase
        end
      end
      8'b11101001 : begin
        // JP (HL)
        JumpXY <= 1'b1;
      end
      8'b00010000 : begin
        if(Mode == 3) begin
          I_DJNZ <= 1'b1;
        end
        else if(Mode < 2) begin
          // DJNZ,e
          MCycles <= 3'b011;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001 : begin
            // 1 =>
            TStates <= 3'b101;
            I_DJNZ <= 1'b1;
            Set_BusB_To <= 4'b1010;
            Set_BusA_To[2:0] <= 3'b000;
            Read_To_Reg <= 1'b1;
            Save_ALU <= 1'b1;
            ALU_Op <= 4'b0010;
          end
          3'b010 : begin
            // 2 =>
            I_DJNZ <= 1'b1;
            Inc_PC <= 1'b1;
          end
          3'b011 : begin
            // 3 =>
            NoRead <= 1'b1;
            JumpE <= 1'b1;
            TStates <= 3'b101;
          end
          default : begin
          end
          endcase
        end
        // CALL AND RETURN GROUP
      end
      8'b11001101 : begin
        // CALL nn
        MCycles <= 3'b101;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b010 : begin
          // 2 =>
          Inc_PC <= 1'b1;
          LDZ <= 1'b1;
        end
        3'b011 : begin
          // 3 =>
          IncDec_16 <= 4'b1111;
          Inc_PC <= 1'b1;
          TStates <= 3'b100;
          Set_Addr_To <= aSP;
          LDW <= 1'b1;
          Set_BusB_To <= 4'b1101;
        end
        3'b100 : begin
          // 4 =>
          Write <= 1'b1;
          IncDec_16 <= 4'b1111;
          Set_Addr_To <= aSP;
          Set_BusB_To <= 4'b1100;
        end
        3'b101 : begin
          // 5 =>
          Write <= 1'b1;
          Call <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b11000100,8'b11001100,8'b11010100,8'b11011100,8'b11100100,8'b11101100,8'b11110100,8'b11111100 : begin
        if(IR[5] == 1'b0 || Mode != 3) begin
          // CALL cc,nn
          MCycles <= 3'b101;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
            LDZ <= 1'b1;
          end
          3'b011 : begin
            // 3 =>
            Inc_PC <= 1'b1;
            LDW <= 1'b1;
            if(is_cc_true(F, IR[5:3])) begin
              //is_cc_true(F, to_bitvector(IR(5 downto 3))) then
              IncDec_16 <= 4'b1111;
              Set_Addr_To <= aSP;
              TStates <= 3'b100;
              Set_BusB_To <= 4'b1101;
            end
            else begin
              MCycles <= 3'b011;
            end
          end
          3'b100 : begin
            // 4 =>
            Write <= 1'b1;
            IncDec_16 <= 4'b1111;
            Set_Addr_To <= aSP;
            Set_BusB_To <= 4'b1100;
          end
          3'b101 : begin
            // 5 =>
            Write <= 1'b1;
            Call <= 1'b1;
          end
          default : begin
          end
          endcase
        end
      end
      8'b11001001 : begin
        // RET
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aSP;
        end
        3'b010 : begin
          // 2 =>
          IncDec_16 <= 4'b0111;
          Set_Addr_To <= aSP;
          LDZ <= 1'b1;
        end
        3'b011 : begin
          // 3 =>
          Jump <= 1'b1;
          IncDec_16 <= 4'b0111;
        end
        default : begin
        end
        endcase
      end
      8'b11000000,8'b11001000,8'b11010000,8'b11011000,8'b11100000,8'b11101000,8'b11110000,8'b11111000 : begin
        if(IR[5] == 1'b1 && Mode == 3) begin
          case(IRB[4:3])
          2'b00 : begin
            // LD ($FF00+nn),A
            MCycles <= 3'b011;
            case(MCycle)
                        // to_integer(unsigned(MCycle)) is
            3'b010 : begin
              // 2 =>
              Inc_PC <= 1'b1;
              Set_Addr_To <= aIOA;
              Set_BusB_To <= 4'b0111;
            end
            3'b011 : begin
              // 3 =>
              Write <= 1'b1;
            end
            default : begin
            end
            endcase
          end
          2'b01 : begin
            // ADD SP,n
            MCycles <= 3'b011;
            case(MCycle)
                        // to_integer(unsigned(MCycle)) is
            3'b010 : begin
              // 2 =>
              ALU_Op <= 4'b0000;
              Inc_PC <= 1'b1;
              Read_To_Reg <= 1'b1;
              Save_ALU <= 1'b1;
              Set_BusA_To <= 4'b1000;
              Set_BusB_To <= 4'b0110;
            end
            3'b011 : begin
              // 3 =>
              NoRead <= 1'b1;
              Read_To_Reg <= 1'b1;
              Save_ALU <= 1'b1;
              ALU_Op <= 4'b0001;
              Set_BusA_To <= 4'b1001;
              Set_BusB_To <= 4'b1110;
              // Incorrect unsigned !!!!!!!!!!!!!!!!!!!!!
            end
            default : begin
            end
            endcase
          end
          2'b10 : begin
            // LD A,($FF00+nn)
            MCycles <= 3'b011;
            case(MCycle)
                        // to_integer(unsigned(MCycle)) is
            3'b010 : begin
              // 2 =>
              Inc_PC <= 1'b1;
              Set_Addr_To <= aIOA;
            end
            3'b011 : begin
              // 3 =>
              Read_To_Acc <= 1'b1;
            end
            default : begin
            end
            endcase
          end
          2'b11 : begin
            // LD HL,SP+n       -- Not correct !!!!!!!!!!!!!!!!!!!
            MCycles <= 3'b101;
            case(MCycle)
                        // to_integer(unsigned(MCycle)) is
            3'b010 : begin
              // 2 =>
              Inc_PC <= 1'b1;
              LDZ <= 1'b1;
            end
            3'b011 : begin
              // 3 =>
              Set_Addr_To <= aZI;
              Inc_PC <= 1'b1;
              LDW <= 1'b1;
            end
            3'b100 : begin
              // 4 =>
              Set_BusA_To[2:0] <= 3'b101;
              // L
              Read_To_Reg <= 1'b1;
              Inc_WZ <= 1'b1;
              Set_Addr_To <= aZI;
            end
            3'b101 : begin
              // 5 =>
              Set_BusA_To[2:0] <= 3'b100;
              // H
              Read_To_Reg <= 1'b1;
            end
            default : begin
            end
            endcase
          end
          endcase
        end
        else begin
          // RET cc
          MCycles <= 3'b011;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001 : begin
            // 1 =>
            if(is_cc_true(F, IR[5:3])) begin
              //is_cc_true(F, to_bitvector(IR(5 downto 3))) then
              Set_Addr_To <= aSP;
            end
            else begin
              MCycles <= 3'b001;
            end
            TStates <= 3'b101;
          end
          3'b010 : begin
            // 2 =>
            IncDec_16 <= 4'b0111;
            Set_Addr_To <= aSP;
            LDZ <= 1'b1;
          end
          3'b011 : begin
            // 3 =>
            Jump <= 1'b1;
            IncDec_16 <= 4'b0111;
          end
          default : begin
          end
          endcase
        end
      end
      8'b11000111,8'b11001111,8'b11010111,8'b11011111,8'b11100111,8'b11101111,8'b11110111,8'b11111111 : begin
        // RST p
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          TStates <= 3'b101;
          IncDec_16 <= 4'b1111;
          Set_Addr_To <= aSP;
          Set_BusB_To <= 4'b1101;
        end
        3'b010 : begin
          // 2 =>
          Write <= 1'b1;
          IncDec_16 <= 4'b1111;
          Set_Addr_To <= aSP;
          Set_BusB_To <= 4'b1100;
        end
        3'b011 : begin
          // 3 =>
          Write <= 1'b1;
          RstP <= 1'b1;
        end
        default : begin
        end
        endcase
        // INPUT AND OUTPUT GROUP
      end
      8'b11011011 : begin
        if(Mode != 3) begin
          // IN A,(n)
          MCycles <= 3'b011;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
            Set_Addr_To <= aIOA;
          end
          3'b011 : begin
            // 3 =>
            Read_To_Acc <= 1'b1;
            IORQ <= 1'b1;
            TStates <= 3'b100;
            // MIKEJ should be 4 for IO cycle
          end
          default : begin
          end
          endcase
        end
      end
      8'b11010011 : begin
        if(Mode != 3) begin
          // OUT (n),A
          MCycles <= 3'b011;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b010 : begin
            // 2 =>
            Inc_PC <= 1'b1;
            Set_Addr_To <= aIOA;
            Set_BusB_To <= 4'b0111;
          end
          3'b011 : begin
            // 3 =>
            Write <= 1'b1;
            IORQ <= 1'b1;
            TStates <= 3'b100;
            // MIKEJ should be 4 for IO cycle
          end
          default : begin
          end
          endcase
        end
        //----------------------------------------------------------------------------
        //----------------------------------------------------------------------------
        // MULTIBYTE INSTRUCTIONS
        //----------------------------------------------------------------------------
        //----------------------------------------------------------------------------
      end
      8'b11001011 : begin
        if(Mode != 2) begin
          Prefix <= 2'b01;
        end
      end
      8'b11101101 : begin
        if(Mode < 2) begin
          Prefix <= 2'b10;
        end
      end
      8'b11011101,8'b11111101 : begin
        if(Mode < 2) begin
          Prefix <= 2'b11;
        end
      end
      endcase
    end
    2'b01 : begin
      //----------------------------------------------------------------------------
      //
      //      CB prefixed instructions
      //
      //----------------------------------------------------------------------------
      Set_BusA_To[2:0] <= IR[2:0];
      Set_BusB_To[2:0] <= IR[2:0];
      case(IRB)
      8'b00000000,8'b00000001,8'b00000010,8'b00000011,8'b00000100,8'b00000101,8'b00000111,8'b00010000,8'b00010001,8'b00010010,8'b00010011,8'b00010100,8'b00010101,8'b00010111,8'b00001000,8'b00001001,8'b00001010,8'b00001011,8'b00001100,8'b00001101,8'b00001111,8'b00011000,8'b00011001,8'b00011010,8'b00011011,8'b00011100,8'b00011101,8'b00011111,8'b00100000,8'b00100001,8'b00100010,8'b00100011,8'b00100100,8'b00100101,8'b00100111,8'b00101000,8'b00101001,8'b00101010,8'b00101011,8'b00101100,8'b00101101,8'b00101111,8'b00110000,8'b00110001,8'b00110010,8'b00110011,8'b00110100,8'b00110101,8'b00110111,8'b00111000,8'b00111001,8'b00111010,8'b00111011,8'b00111100,8'b00111101,8'b00111111 : begin
        // RLC r
        // RL r
        // RRC r
        // RR r
        // SLA r
        // SRA r
        // SRL r
        // SLL r (Undocumented) / SWAP r
        if(XY_State == 2'b00) begin
          if(MCycle == 3'b001) begin
            ALU_Op <= 4'b1000;
            Read_To_Reg <= 1'b1;
            Save_ALU <= 1'b1;
          end
        end
        else begin
          // R/S (IX+d),Reg, undocumented
          MCycles <= 3'b011;
          XYbit_undoc <= 1'b1;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001,3'b111 : begin
            // 1 | 7=>
            Set_Addr_To <= aXY;
          end
          3'b010 : begin
            // 2 =>
            ALU_Op <= 4'b1000;
            Read_To_Reg <= 1'b1;
            Save_ALU <= 1'b1;
            Set_Addr_To <= aXY;
            TStates <= 3'b100;
          end
          3'b011 : begin
            // 3 =>
            Write <= 1'b1;
          end
          default : begin
          end
          endcase
        end
      end
      8'b00000110,8'b00010110,8'b00001110,8'b00011110,8'b00101110,8'b00111110,8'b00100110,8'b00110110 : begin
        // RLC (HL)
        // RL (HL)
        // RRC (HL)
        // RR (HL)
        // SRA (HL)
        // SRL (HL)
        // SLA (HL)
        // SLL (HL) (Undocumented) / SWAP (HL)
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001,3'b111 : begin
          // 1 | 7=>
          Set_Addr_To <= aXY;
        end
        3'b010 : begin
          // 2 =>
          ALU_Op <= 4'b1000;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          Set_Addr_To <= aXY;
          TStates <= 3'b100;
        end
        3'b011 : begin
          // 3 =>
          Write <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01000000,8'b01000001,8'b01000010,8'b01000011,8'b01000100,8'b01000101,8'b01000111,8'b01001000,8'b01001001,8'b01001010,8'b01001011,8'b01001100,8'b01001101,8'b01001111,8'b01010000,8'b01010001,8'b01010010,8'b01010011,8'b01010100,8'b01010101,8'b01010111,8'b01011000,8'b01011001,8'b01011010,8'b01011011,8'b01011100,8'b01011101,8'b01011111,8'b01100000,8'b01100001,8'b01100010,8'b01100011,8'b01100100,8'b01100101,8'b01100111,8'b01101000,8'b01101001,8'b01101010,8'b01101011,8'b01101100,8'b01101101,8'b01101111,8'b01110000,8'b01110001,8'b01110010,8'b01110011,8'b01110100,8'b01110101,8'b01110111,8'b01111000,8'b01111001,8'b01111010,8'b01111011,8'b01111100,8'b01111101,8'b01111111 : begin
        // BIT b,r
        if(XY_State == 2'b00) begin
          if(MCycle == 3'b001) begin
            Set_BusB_To[2:0] <= IR[2:0];
            ALU_Op <= 4'b1001;
          end
        end
        else begin
          // BIT b,(IX+d), undocumented
          MCycles <= 3'b010;
          XYbit_undoc <= 1'b1;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001,3'b111 : begin
            // 1 | 7=>
            Set_Addr_To <= aXY;
          end
          3'b010 : begin
            // 2 =>
            ALU_Op <= 4'b1001;
            TStates <= 3'b100;
          end
          default : begin
          end
          endcase
        end
      end
      8'b01000110,8'b01001110,8'b01010110,8'b01011110,8'b01100110,8'b01101110,8'b01110110,8'b01111110 : begin
        // BIT b,(HL)
        MCycles <= 3'b010;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001,3'b111 : begin
          // 1 | 7=>
          Set_Addr_To <= aXY;
        end
        3'b010 : begin
          // 2 =>
          ALU_Op <= 4'b1001;
          TStates <= 3'b100;
        end
        default : begin
        end
        endcase
      end
      8'b11000000,8'b11000001,8'b11000010,8'b11000011,8'b11000100,8'b11000101,8'b11000111,8'b11001000,8'b11001001,8'b11001010,8'b11001011,8'b11001100,8'b11001101,8'b11001111,8'b11010000,8'b11010001,8'b11010010,8'b11010011,8'b11010100,8'b11010101,8'b11010111,8'b11011000,8'b11011001,8'b11011010,8'b11011011,8'b11011100,8'b11011101,8'b11011111,8'b11100000,8'b11100001,8'b11100010,8'b11100011,8'b11100100,8'b11100101,8'b11100111,8'b11101000,8'b11101001,8'b11101010,8'b11101011,8'b11101100,8'b11101101,8'b11101111,8'b11110000,8'b11110001,8'b11110010,8'b11110011,8'b11110100,8'b11110101,8'b11110111,8'b11111000,8'b11111001,8'b11111010,8'b11111011,8'b11111100,8'b11111101,8'b11111111 : begin
        // SET b,r
        if(XY_State == 2'b00) begin
          if(MCycle == 3'b001) begin
            ALU_Op <= 4'b1010;
            Read_To_Reg <= 1'b1;
            Save_ALU <= 1'b1;
          end
        end
        else begin
          // SET b,(IX+d),Reg, undocumented
          MCycles <= 3'b011;
          XYbit_undoc <= 1'b1;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001,3'b111 : begin
            // 1 | 7=>
            Set_Addr_To <= aXY;
          end
          3'b010 : begin
            // 2 =>
            ALU_Op <= 4'b1010;
            Read_To_Reg <= 1'b1;
            Save_ALU <= 1'b1;
            Set_Addr_To <= aXY;
            TStates <= 3'b100;
          end
          3'b011 : begin
            // 3 =>
            Write <= 1'b1;
          end
          default : begin
          end
          endcase
        end
      end
      8'b11000110,8'b11001110,8'b11010110,8'b11011110,8'b11100110,8'b11101110,8'b11110110,8'b11111110 : begin
        // SET b,(HL)
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001,3'b111 : begin
          // 1 | 7=>
          Set_Addr_To <= aXY;
        end
        3'b010 : begin
          // 2 =>
          ALU_Op <= 4'b1010;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          Set_Addr_To <= aXY;
          TStates <= 3'b100;
        end
        3'b011 : begin
          // 3 =>
          Write <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b10000000,8'b10000001,8'b10000010,8'b10000011,8'b10000100,8'b10000101,8'b10000111,8'b10001000,8'b10001001,8'b10001010,8'b10001011,8'b10001100,8'b10001101,8'b10001111,8'b10010000,8'b10010001,8'b10010010,8'b10010011,8'b10010100,8'b10010101,8'b10010111,8'b10011000,8'b10011001,8'b10011010,8'b10011011,8'b10011100,8'b10011101,8'b10011111,8'b10100000,8'b10100001,8'b10100010,8'b10100011,8'b10100100,8'b10100101,8'b10100111,8'b10101000,8'b10101001,8'b10101010,8'b10101011,8'b10101100,8'b10101101,8'b10101111,8'b10110000,8'b10110001,8'b10110010,8'b10110011,8'b10110100,8'b10110101,8'b10110111,8'b10111000,8'b10111001,8'b10111010,8'b10111011,8'b10111100,8'b10111101,8'b10111111 : begin
        // RES b,r
        if(XY_State == 2'b00) begin
          if(MCycle == 3'b001) begin
            ALU_Op <= 4'b1011;
            Read_To_Reg <= 1'b1;
            Save_ALU <= 1'b1;
          end
        end
        else begin
          // RES b,(IX+d),Reg, undocumented
          MCycles <= 3'b011;
          XYbit_undoc <= 1'b1;
          case(MCycle)
                    // to_integer(unsigned(MCycle)) is
          3'b001,3'b111 : begin
            // 1 | 7=>
            Set_Addr_To <= aXY;
          end
          3'b010 : begin
            // 2 =>
            ALU_Op <= 4'b1011;
            Read_To_Reg <= 1'b1;
            Save_ALU <= 1'b1;
            Set_Addr_To <= aXY;
            TStates <= 3'b100;
          end
          3'b011 : begin
            // 3 =>
            Write <= 1'b1;
          end
          default : begin
          end
          endcase
        end
      end
      8'b10000110,8'b10001110,8'b10010110,8'b10011110,8'b10100110,8'b10101110,8'b10110110,8'b10111110 : begin
        // RES b,(HL)
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001,3'b111 : begin
          // 1 | 7=>
          Set_Addr_To <= aXY;
        end
        3'b010 : begin
          // 2 =>
          ALU_Op <= 4'b1011;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          Set_Addr_To <= aXY;
          TStates <= 3'b100;
        end
        3'b011 : begin
          // 3 =>
          Write <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      endcase
    end
    default : begin
      //----------------------------------------------------------------------------
      //
      //      ED prefixed instructions
      //
      //----------------------------------------------------------------------------
      case(IRB)
      8'b00000000,8'b00000001,8'b00000010,8'b00000011,8'b00000100,8'b00000101,8'b00000110,8'b00000111,8'b00001000,8'b00001001,8'b00001010,8'b00001011,8'b00001100,8'b00001101,8'b00001110,8'b00001111,8'b00010000,8'b00010001,8'b00010010,8'b00010011,8'b00010100,8'b00010101,8'b00010110,8'b00010111,8'b00011000,8'b00011001,8'b00011010,8'b00011011,8'b00011100,8'b00011101,8'b00011110,8'b00011111,8'b00100000,8'b00100001,8'b00100010,8'b00100011,8'b00100100,8'b00100101,8'b00100110,8'b00100111,8'b00101000,8'b00101001,8'b00101010,8'b00101011,8'b00101100,8'b00101101,8'b00101110,8'b00101111,8'b00110000,8'b00110001,8'b00110010,8'b00110011,8'b00110100,8'b00110101,8'b00110110,8'b00110111,8'b00111000,8'b00111001,8'b00111010,8'b00111011,8'b00111100,8'b00111101,8'b00111110,8'b00111111,8'b10000000,8'b10000001,8'b10000010,8'b10000011,8'b10000100,8'b10000101,8'b10000110,8'b10000111,8'b10001000,8'b10001001,8'b10001010,8'b10001011,8'b10001100,8'b10001101,8'b10001110,8'b10001111,8'b10010000,8'b10010001,8'b10010010,8'b10010011,8'b10010100,8'b10010101,8'b10010110,8'b10010111,8'b10011000,8'b10011001,8'b10011010,8'b10011011,8'b10011100,8'b10011101,8'b10011110,8'b10011111,8'b10100100,8'b10100101,8'b10100110,8'b10100111,8'b10101100,8'b10101101,8'b10101110,8'b10101111,8'b10110100,8'b10110101,8'b10110110,8'b10110111,8'b10111100,8'b10111101,8'b10111110,8'b10111111,8'b11000000,8'b11000001,8'b11000010,8'b11000011,8'b11000100,8'b11000101,8'b11000110,8'b11000111,8'b11001000,8'b11001001,8'b11001010,8'b11001011,8'b11001100,8'b11001101,8'b11001110,8'b11001111,8'b11010000,8'b11010001,8'b11010010,8'b11010011,8'b11010100,8'b11010101,8'b11010110,8'b11010111,8'b11011000,8'b11011001,8'b11011010,8'b11011011,8'b11011100,8'b11011101,8'b11011110,8'b11011111,8'b11100000,8'b11100001,8'b11100010,8'b11100011,8'b11100100,8'b11100101,8'b11100110,8'b11100111,8'b11101000,8'b11101001,8'b11101010,8'b11101011,8'b11101100,8'b11101101,8'b11101110,8'b11101111,8'b11110000,8'b11110001,8'b11110010,8'b11110011,8'b11110100,8'b11110101,8'b11110110,8'b11110111,8'b11111000,8'b11111001,8'b11111010,8'b11111011,8'b11111100,8'b11111101,8'b11111110,8'b11111111 : begin
        // NOP, undocumented
      end
      8'b01111110,8'b01111111 : begin
        // NOP, undocumented
                // 8 BIT LOAD GROUP
      end
      8'b01010111 : begin
        // LD A,I
        Special_LD <= 3'b100;
        TStates <= 3'b101;
      end
      8'b01011111 : begin
        // LD A,R
        Special_LD <= 3'b101;
        TStates <= 3'b101;
      end
      8'b01000111 : begin
        // LD I,A
        Special_LD <= 3'b110;
        TStates <= 3'b101;
      end
      8'b01001111 : begin
        // LD R,A
        Special_LD <= 3'b111;
        TStates <= 3'b101;
        // 16 BIT LOAD GROUP
      end
      8'b01001011,8'b01011011,8'b01101011,8'b01111011 : begin
        // LD dd,(nn)
        MCycles <= 3'b101;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b010 : begin
          // 2 =>
          Inc_PC <= 1'b1;
          LDZ <= 1'b1;
        end
        3'b011 : begin
          // 3 =>
          Set_Addr_To <= aZI;
          Inc_PC <= 1'b1;
          LDW <= 1'b1;
        end
        3'b100 : begin
          // 4 =>
          Read_To_Reg <= 1'b1;
          if(IR[5:4] == 2'b11) begin
            Set_BusA_To <= 4'b1000;
          end
          else begin
            Set_BusA_To[2:1] <= IR[5:4];
            Set_BusA_To[0] <= 1'b1;
          end
          Inc_WZ <= 1'b1;
          Set_Addr_To <= aZI;
        end
        3'b101 : begin
          // 5 =>
          Read_To_Reg <= 1'b1;
          if(IR[5:4] == 2'b11) begin
            Set_BusA_To <= 4'b1001;
          end
          else begin
            Set_BusA_To[2:1] <= IR[5:4];
            Set_BusA_To[0] <= 1'b0;
          end
        end
        default : begin
        end
        endcase
      end
      8'b01000011,8'b01010011,8'b01100011,8'b01110011 : begin
        // LD (nn),dd
        MCycles <= 3'b101;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b010 : begin
          // 2 =>
          Inc_PC <= 1'b1;
          LDZ <= 1'b1;
        end
        3'b011 : begin
          // 3 =>
          Set_Addr_To <= aZI;
          Inc_PC <= 1'b1;
          LDW <= 1'b1;
          if(IR[5:4] == 2'b11) begin
            Set_BusB_To <= 4'b1000;
          end
          else begin
            Set_BusB_To[2:1] <= IR[5:4];
            Set_BusB_To[0] <= 1'b1;
            Set_BusB_To[3] <= 1'b0;
          end
        end
        3'b100 : begin
          // 4 =>
          Inc_WZ <= 1'b1;
          Set_Addr_To <= aZI;
          Write <= 1'b1;
          if(IR[5:4] == 2'b11) begin
            Set_BusB_To <= 4'b1001;
          end
          else begin
            Set_BusB_To[2:1] <= IR[5:4];
            Set_BusB_To[0] <= 1'b0;
            Set_BusB_To[3] <= 1'b0;
          end
        end
        3'b101 : begin
          // 5 =>
          Write <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b10100000,8'b10101000,8'b10110000,8'b10111000 : begin
        // LDI, LDD, LDIR, LDDR
        MCycles <= 3'b100;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aXY;
          IncDec_16 <= 4'b1100;
          // BC
        end
        3'b010 : begin
          // 2 =>
          Set_BusB_To <= 4'b0110;
          Set_BusA_To[2:0] <= 3'b111;
          ALU_Op <= 4'b0000;
          Set_Addr_To <= aDE;
          if(IR[3] == 1'b0) begin
            IncDec_16 <= 4'b0110;
            // IX
          end
          else begin
            IncDec_16 <= 4'b1110;
          end
        end
        3'b011 : begin
          // 3 =>
          I_BT <= 1'b1;
          TStates <= 3'b101;
          Write <= 1'b1;
          if(IR[3] == 1'b0) begin
            IncDec_16 <= 4'b0101;
            // DE
          end
          else begin
            IncDec_16 <= 4'b1101;
          end
        end
        3'b100 : begin
          // 4 =>
          NoRead <= 1'b1;
          TStates <= 3'b101;
        end
        default : begin
        end
        endcase
      end
      8'b10100001,8'b10101001,8'b10110001,8'b10111001 : begin
        // CPI, CPD, CPIR, CPDR
        MCycles <= 3'b100;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aXY;
          IncDec_16 <= 4'b1100;
          // BC
        end
        3'b010 : begin
          // 2 =>
          Set_BusB_To <= 4'b0110;
          Set_BusA_To[2:0] <= 3'b111;
          ALU_Op <= 4'b0111;
          Save_ALU <= 1'b1;
          PreserveC <= 1'b1;
          if(IR[3] == 1'b0) begin
            IncDec_16 <= 4'b0110;
          end
          else begin
            IncDec_16 <= 4'b1110;
          end
        end
        3'b011 : begin
          // 3 =>
          NoRead <= 1'b1;
          I_BC <= 1'b1;
          TStates <= 3'b101;
        end
        3'b100 : begin
          // 4 =>
          NoRead <= 1'b1;
          TStates <= 3'b101;
        end
        default : begin
        end
        endcase
      end
      8'b01000100,8'b01001100,8'b01010100,8'b01011100,8'b01100100,8'b01101100,8'b01110100,8'b01111100 : begin
        // NEG
        ALU_Op <= 4'b0010;
        Set_BusB_To <= 4'b0111;
        Set_BusA_To <= 4'b1010;
        Read_To_Acc <= 1'b1;
        Save_ALU <= 1'b1;
      end
      8'b01000110,8'b01001110,8'b01100110,8'b01101110 : begin
        // IM 0
        IMode <= 2'b00;
      end
      8'b01010110,8'b01110110 : begin
        // IM 1
        IMode <= 2'b01;
      end
      8'b01011110,8'b01110111 : begin
        // IM 2
        IMode <= 2'b10;
        // 16 bit arithmetic
      end
      8'b01001010,8'b01011010,8'b01101010,8'b01111010 : begin
        // ADC HL,ss
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b010 : begin
          // 2 =>
          NoRead <= 1'b1;
          ALU_Op <= 4'b0001;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          Set_BusA_To[2:0] <= 3'b101;
          case(IR[5:4])
                    // to_integer(unsigned(IR(5 downto 4))) is
          2'b00,2'b01,2'b10 : begin
            // 0|1|2 =>
            Set_BusB_To[2:1] <= IR[5:4];
            Set_BusB_To[0] <= 1'b1;
          end
          default : begin
            Set_BusB_To <= 4'b1000;
          end
          endcase
          TStates <= 3'b100;
        end
        3'b011 : begin
          // 3 =>
          NoRead <= 1'b1;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          ALU_Op <= 4'b0001;
          Set_BusA_To[2:0] <= 3'b100;
          case(IR[5:4])
                    // to_integer(unsigned(IR(5 downto 4))) is
          2'b00,2'b01,2'b10 : begin
            // 0|1|2 =>
            Set_BusB_To[2:1] <= IR[5:4];
            Set_BusB_To[0] <= 1'b0;
          end
          default : begin
            Set_BusB_To <= 4'b1001;
          end
          endcase
        end
        default : begin
        end
        endcase
      end
      8'b01000010,8'b01010010,8'b01100010,8'b01110010 : begin
        // SBC HL,ss
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b010 : begin
          // 2 =>
          NoRead <= 1'b1;
          ALU_Op <= 4'b0011;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          Set_BusA_To[2:0] <= 3'b101;
          case(IR[5:4])
                    // to_integer(unsigned(IR(5 downto 4))) is
          2'b00,2'b01,2'b10 : begin
            // 0|1|2 =>
            Set_BusB_To[2:1] <= IR[5:4];
            Set_BusB_To[0] <= 1'b1;
          end
          default : begin
            Set_BusB_To <= 4'b1000;
          end
          endcase
          TStates <= 3'b100;
        end
        3'b011 : begin
          // 3 =>
          NoRead <= 1'b1;
          ALU_Op <= 4'b0011;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          Set_BusA_To[2:0] <= 3'b100;
          case(IR[5:4])
                    // to_integer(unsigned(IR(5 downto 4))) is
          2'b00,2'b01,2'b10 : begin
            // 0|1|2 =>
            Set_BusB_To[2:1] <= IR[5:4];
          end
          default : begin
            Set_BusB_To <= 4'b1001;
          end
          endcase
        end
        default : begin
        end
        endcase
      end
      8'b01101111 : begin
        // RLD
        MCycles <= 3'b100;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b010 : begin
          // 2 =>
          NoRead <= 1'b1;
          Set_Addr_To <= aXY;
        end
        3'b011 : begin
          // 3 =>
          Read_To_Reg <= 1'b1;
          Set_BusB_To[2:0] <= 3'b110;
          Set_BusA_To[2:0] <= 3'b111;
          ALU_Op <= 4'b1101;
          TStates <= 3'b100;
          Set_Addr_To <= aXY;
          Save_ALU <= 1'b1;
        end
        3'b100 : begin
          // 4 =>
          I_RLD <= 1'b1;
          Write <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01100111 : begin
        // RRD
        MCycles <= 3'b100;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b010 : begin
          // 2 =>
          Set_Addr_To <= aXY;
        end
        3'b011 : begin
          // 3 =>
          Read_To_Reg <= 1'b1;
          Set_BusB_To[2:0] <= 3'b110;
          Set_BusA_To[2:0] <= 3'b111;
          ALU_Op <= 4'b1110;
          TStates <= 3'b100;
          Set_Addr_To <= aXY;
          Save_ALU <= 1'b1;
        end
        3'b100 : begin
          // 4 =>
          I_RRD <= 1'b1;
          Write <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01000101,8'b01001101,8'b01010101,8'b01011101,8'b01100101,8'b01101101,8'b01110101,8'b01111101 : begin
        // RETI, RETN
        MCycles <= 3'b011;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aSP;
        end
        3'b010 : begin
          // 2 =>
          IncDec_16 <= 4'b0111;
          Set_Addr_To <= aSP;
          LDZ <= 1'b1;
        end
        3'b011 : begin
          // 3 =>
          Jump <= 1'b1;
          IncDec_16 <= 4'b0111;
          I_RETN <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01000000,8'b01001000,8'b01010000,8'b01011000,8'b01100000,8'b01101000,8'b01110000,8'b01111000 : begin
        // IN r,(C)
        MCycles <= 3'b010;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aBC;
        end
        3'b010 : begin
          // 2 =>
          TStates <= 3'b100;
          // MIKEJ should be 4 for IO cycle
          IORQ <= 1'b1;
          if(IR[5:3] != 3'b110) begin
            Read_To_Reg <= 1'b1;
            Set_BusA_To[2:0] <= IR[5:3];
          end
          I_INRC <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01000001,8'b01001001,8'b01010001,8'b01011001,8'b01100001,8'b01101001,8'b01110001,8'b01111001 : begin
        // OUT (C),r
        // OUT (C),0
        MCycles <= 3'b010;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aBC;
          Set_BusB_To[2:0] <= IR[5:3];
          if(IR[5:3] == 3'b110) begin
            Set_BusB_To[3] <= 1'b1;
          end
        end
        3'b010 : begin
          // 2 =>
          TStates <= 3'b100;
          // MIKEJ should be 4 for IO cycle
          Write <= 1'b1;
          IORQ <= 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b10100010,8'b10101010,8'b10110010,8'b10111010 : begin
        // INI, IND, INIR, INDR
        // note B is decremented AFTER being put on the bus
        MCycles <= 3'b100;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          Set_Addr_To <= aBC;
          Set_BusB_To <= 4'b1010;
          Set_BusA_To <= 4'b0000;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          ALU_Op <= 4'b0010;
        end
        3'b010 : begin
          // 2 =>
          TStates <= 3'b100;
          // MIKEJ should be 4 for IO cycle
          IORQ <= 1'b1;
          Set_BusB_To <= 4'b0110;
          Set_Addr_To <= aXY;
        end
        3'b011 : begin
          // 3 =>
          if(IR[3] == 1'b0) begin
            //IncDec_16 <= "0010";
            IncDec_16 <= 4'b0110;
          end
          else begin
            //IncDec_16 <= "1010";
            IncDec_16 <= 4'b1110;
          end
          TStates <= 3'b100;
          Write <= 1'b1;
          I_BTR <= 1'b1;
        end
        3'b100 : begin
          // 4 =>
          NoRead <= 1'b1;
          TStates <= 3'b101;
        end
        default : begin
        end
        endcase
      end
      8'b10100011,8'b10101011,8'b10110011,8'b10111011 : begin
        // OUTI, OUTD, OTIR, OTDR
        // note B is decremented BEFORE being put on the bus.
        // mikej fix for hl inc
        MCycles <= 3'b100;
        case(MCycle)
                // to_integer(unsigned(MCycle)) is
        3'b001 : begin
          // 1 =>
          TStates <= 3'b101;
          Set_Addr_To <= aXY;
          Set_BusB_To <= 4'b1010;
          Set_BusA_To <= 4'b0000;
          Read_To_Reg <= 1'b1;
          Save_ALU <= 1'b1;
          ALU_Op <= 4'b0010;
        end
        3'b010 : begin
          // 2 =>
          Set_BusB_To <= 4'b0110;
          Set_Addr_To <= aBC;
        end
        3'b011 : begin
          // 3 =>
          if(IR[3] == 1'b0) begin
            IncDec_16 <= 4'b0110;
            // mikej
          end
          else begin
            IncDec_16 <= 4'b1110;
            // mikej
          end
          TStates <= 3'b100;
          // MIKEJ should be 4 for IO cycle
          IORQ <= 1'b1;
          Write <= 1'b1;
          I_BTR <= 1'b1;
        end
        3'b100 : begin
          // 4 =>
          NoRead <= 1'b1;
          TStates <= 3'b101;
        end
        default : begin
        end
        endcase
      end
      endcase
    end
    endcase
    if(Mode == 1) begin
      if(MCycle == 3'b001) begin
        //              TStates <= "100";
      end
      else begin
        TStates <= 3'b011;
      end
    end
    if(Mode == 3) begin
      if(MCycle == 3'b001) begin
        //              TStates <= "100";
      end
      else begin
        TStates <= 3'b100;
      end
    end
    if(Mode < 2) begin
      if(MCycle == 3'b110) begin
        Inc_PC <= 1'b1;
        if(Mode == 1) begin
          Set_Addr_To <= aXY;
          TStates <= 3'b100;
          Set_BusB_To[2:0] <= SSS;
          Set_BusB_To[3] <= 1'b0;
        end
        if(IRB == 8'b00110110 || IRB == 8'b11001011) begin
          Set_Addr_To <= aNone;
        end
      end
      if(MCycle == 3'b111) begin
        if(Mode == 0) begin
          TStates <= 3'b101;
        end
        if(ISet != 2'b01) begin
          Set_Addr_To <= aXY;
        end
        Set_BusB_To[2:0] <= SSS;
        Set_BusB_To[3] <= 1'b0;
        if(IRB == 8'b00110110 || ISet == 2'b01) begin
          // LD (HL),n
          Inc_PC <= 1'b1;
        end
        else begin
          NoRead <= 1'b1;
        end
      end
    end
  end


endmodule
