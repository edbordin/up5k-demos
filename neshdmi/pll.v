// /**
//  * PLL configuration
//  *
//  * This Verilog module was generated automatically
//  * using the icepll tool from the IceStorm project.
//  * Use at your own risk.
//  *
//  * Given input frequency:        12.000 MHz
//  * Requested output frequency:   21.500 MHz
//  * Achieved output frequency:    21.375 MHz
//  */

// module pll(
// 	input  clock_in,
// 	output clock_out,
// 	output locked
// 	);

// SB_PLL40_PAD #(
// 		.FEEDBACK_PATH("SIMPLE"),
// 		.DIVR(4'b0000),		// DIVR =  0
// 		.DIVF(7'b0111000),	// DIVF = 56
// 		.DIVQ(3'b101),		// DIVQ =  5
// 		.FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
// 	) uut (
// 		.LOCK(locked),
// 		.RESETB(1'b1),
// 		.BYPASS(1'b0),
// 		.PACKAGEPIN(clock_in),
// 		.PLLOUTCORE(clock_out)
// 		);

// endmodule

/**
 * PLL configuration
 *
 * This Verilog module was generated automatically
 * using the icepll tool from the IceStorm project.
 * Use at your own risk.
 *
 * Given input frequency:        12.000 MHz
 * Requested output frequency:   85.909 MHz
 * Achieved output frequency:    85.500 MHz
 */

module pll(
        input  clock_in,
        output clock_out,
        output clock_passthrough,
        output locked
        );

SB_PLL40_2_PAD  #(
                .FEEDBACK_PATH("SIMPLE"),
                .DIVR(4'b0000),         // DIVR =  0
                .DIVF(7'b0111000),      // DIVF = 56
                .DIVQ(3'b011),          // DIVQ =  3
                .FILTER_RANGE(3'b001)   // FILTER_RANGE = 1
        ) uut (
                .LOCK(locked),
                .RESETB(1'b1),
                .BYPASS(1'b0),
                .PACKAGEPIN(clock_in),
                .PLLOUTGLOBALA(clock_passthrough),
                .PLLOUTGLOBALB(clock_out)
                );

endmodule