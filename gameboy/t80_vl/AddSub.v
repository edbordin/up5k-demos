  module AddSub #(
  parameter WIDTH = 1
)(
    input [WIDTH-1:0] A,
    input [WIDTH-1:0] B,
    input Sub,
    input Carry_In, 
    output [WIDTH-1:0] Res,
    output Carry);

    wire B_i = Sub ? ~B : B;
    wire [WIDTH+1:0] Res_i = {1'b0, A, Carry_In} + {1'b0, B_i, 1'b1};
		// Res_i := unsigned("0" & A & Carry_In) + unsigned("0" & B_i & "1");
    assign Carry = Res_i[WIDTH+1];
    assign Res = Res_i[WIDTH:1];
		// Carry <= Res_i(A'length + 1);
		// Res <= std_logic_vector(Res_i(A'length downto 1));

  endmodule