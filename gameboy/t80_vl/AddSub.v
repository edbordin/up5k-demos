  module AddSub (
    input [3:0] A,
    input [3:0] B,
    input Sub,
    input Carry_In, 
    output Res,
    output Carry);

    wire B_i = Sub ? ~B : B;
    wire Res_i = {1'b0, A, Carry_In} + {1'b0, B_i, 1'b1};
		// Res_i := unsigned("0" & A & Carry_In) + unsigned("0" & B_i & "1");
    assign Carry = Res_i[5];
    assign Res = Res_i[4:0];
		// Carry <= Res_i(A'length + 1);
		// Res <= std_logic_vector(Res_i(A'length downto 1));

  endmodule