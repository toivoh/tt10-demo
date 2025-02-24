/*
 * Copyright (c) 2025 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`include "pwl4_synth.vh"

module tt_um_toivoh_demo (
		input  wire [7:0] ui_in,    // Dedicated inputs
		output wire [7:0] uo_out,   // Dedicated outputs
		input  wire [7:0] uio_in,   // IOs: Input path
		output wire [7:0] uio_out,  // IOs: Output path
		output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
		input  wire       ena,      // always 1 when the design is powered, so you can ignore it
		input  wire       clk,      // clock
		input  wire       rst_n     // reset_n - low to reset
	);

	localparam COLOR_CHANNEL_BITS=2;

	wire reset = !rst_n;
	wire en = 1;

	wire pwm_out;
	wire [COLOR_CHANNEL_BITS*3-1:0] rgb;
	wire hsync, vsync;
	wire enable = 1; // TODO: only every other pixel
	wire [1:0] advance;
	demo_top #(.COLOR_CHANNEL_BITS(COLOR_CHANNEL_BITS)) dtop(
		.clk(clk), .reset(reset), .advance(advance),
		.pwm_out(pwm_out),
		.rgb(rgb), .hsync(hsync), .vsync(vsync)
	);

	assign advance = ui_in[7:6];

	wire [1:0] r, g, b;
	assign {r, g, b} = rgb;

	wire [7:0] uo_out0, uio_out0;
	reg [7:0] uo_out1, uio_out1;

	assign uo_out0 = {
		hsync,
		b[0],
		g[0],
		r[0],
		vsync,
		b[1],
		g[1],
		r[1]
	};
	assign uio_out0[7] = pwm_out; // & !ext_control[`EC_PAUSE];
	assign uio_oe[7] = 1'b1;
	assign uio_out0[6:0] = '0;
	assign uio_oe[6:0] = '0;

	always @(posedge clk) begin
		if (enable) begin
			uo_out1 <= uo_out0;
			uio_out1 <= uio_out0;
		end
		//ui_in_reg <= ui_in;
	end
	assign uo_out = uo_out1;
	assign uio_out = uio_out1;

	// List all unused inputs to prevent warnings
	wire _unused = &{ena, rst_n, ui_in, uio_in};
endmodule
