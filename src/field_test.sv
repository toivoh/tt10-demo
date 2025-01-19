/*
 * Copyright (c) 2025 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module field_table #(parameter X_BITS=5, CMP_BITS=7) (
		input wire signed [X_BITS-1:0] x,
		output reg [CMP_BITS-1:0] cmp // not a register
	);

	always_comb begin 
		case (x)
`include "field-table-generated.v"
			default: cmp = 'X;
		endcase
	end
endmodule


module field_test #(parameter COLOR_CHANNEL_BITS=4) (
		input clk, reset,

		output wire [COLOR_CHANNEL_BITS*3-1:0] rgb,
		output wire hsync, vsync, new_frame
	);

	localparam X0_BITS = 12;
	localparam X_BITS = 10;
	localparam Y_BITS = 9;
	localparam VIS_Y_BITS = 9;

	genvar i;

	// Raster scan
	// ===========
	wire signed [X0_BITS-1:0] x0;
	wire signed [X_BITS-1:0] x = x0[X0_BITS-1:1];
	wire new_pixel = x0[0];
	wire signed [Y_BITS-1:0] y;
	wire active, x_active, y_active;
	wire new_line;
	//raster_scan_c rs(
	raster_scan rs(
		.clk(clk), .reset(reset), .en(1'b1),
		.x(x0), .y(y),
		.active(active), .hsync(hsync), .vsync(vsync), .new_frame(new_frame), .new_line(new_line),
		.x_active(x_active), .y_active(y_active)
	);

	// Field
	// =====

	localparam TIMER_BITS = 16;

	localparam FRAC_BITS = 2;
	localparam DELTA_BITS = FRAC_BITS;
	localparam FX_BITS = 9 + FRAC_BITS;
	localparam FY_BITS = 9 + FRAC_BITS;

	localparam TABLE_BUCKET_BITS = 5;

	localparam TABLE_OUT_BITS = 7;
	localparam CMP_BITS = 5;
	// TABLE_OUT_BITS = CMP_BITS + FRAC_BITS

	reg [TIMER_BITS-1:0] timer = 0;

	reg [FX_BITS-1:0] fx;
	reg [FY_BITS-1:0] fy;
	wire [DELTA_BITS-1:0] delta_fx, delta_fy, dx1, dx2, dy1, dy2;

	wire [FX_BITS-1:0] fx0 = timer >> 1;
	wire [FX_BITS-1:0] fy0 = ~timer >> 2;

	wire [X_BITS-1:0] xy = new_line ? y : x;
	wire [FX_BITS-1:0] fxy = new_line ? fy : fx;

	wire [TABLE_OUT_BITS-1:0] table_out;
	field_table #(.X_BITS(X_BITS-TABLE_BUCKET_BITS), .CMP_BITS(TABLE_OUT_BITS)) ft(.x(xy[X_BITS-1:TABLE_BUCKET_BITS]), .cmp(table_out));

	wire [FRAC_BITS-1:0] delta;
	wire [CMP_BITS-1:0] cmp_val;
	assign {delta, cmp_val} = table_out;

	wire [CMP_BITS-1:0] cmp;
	generate
		for (i = 0; i < CMP_BITS; i++) assign cmp[i] = xy[CMP_BITS-1-i];
	endgenerate

	wire [FX_BITS-1:0] next_fxy = fxy + delta + (cmp_val >= cmp);

	always @(posedge clk) begin
		if (reset) begin
			fx <= -320;
			fy <= -240;
			timer <= 0;
		end else begin
			if (new_line) fx <= fx0;
			else if (new_pixel && x_active) fx <= next_fxy;
			if (new_frame) fy <= fy0;
			else if (new_line && y_active) fy <= next_fxy;
			timer <= timer + new_frame;
		end
	end

	wire [COLOR_CHANNEL_BITS-1:0] r, g, b;
	//assign {r, g, b} = x[5:0] ^ x[X_BITS-1:6] ^ y[5:0] ^ y[Y_BITS-1:6];
	//assign {r, g, b} = fx ^ fy;


	assign r = fx >> 2;
	assign g = fy >> 2;
	assign b = (fx + fy)  >> 2;

	assign rgb = active ? {r, g, b} : '0;
endmodule
