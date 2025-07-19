// FPGA Videopac
//-----------------------------------------------------------------------------
//
// Copyright (c) 2007, Arnim Laeuger (arnim.laeuger@gmx.net)
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
// Based off MiST port by wsoltys in 2014.
//
// Adapted for MiSTer by Kitrinx in 2018
// Bug fixes and new features added by The spanish videopac team in 2021

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,
	
	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,


	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

`ifdef USE_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

`ifdef USE_DDRAM
	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,
`endif

`ifdef USE_SDRAM
   //SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,
`endif

`ifdef DUAL_SDRAM
	//Secondary SDRAM
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;


////////////////////////////  HPS I/O  //////////////////////////////////

// Status Bit Map:
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXX   X XXXXXXX  XX

`include "build_id.v"
localparam CONF_STR = {
	"ODYSSEY2;;",
	"-;",
	"F1,BIN,Load catridge;",
	"F2,ROM,Load XROM;",
	"-;",
	"F3,CHR,Change VDC font;",
	"-;",
   "OF,System,Odyssey2,Videopac;",
   "OCE,G7200,Off,Contrast 1,Contrast 2,Contrast 3,Contrast 4,Contrast 5,Contrast 6,Contrast 7;",
 	"OIJ,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O9B,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"O1,The Voice,Off,On;",
	"O23,Audio,voice(R)/Console(L),25%,50%,Center mixed;",
	"-;",
	"O7,Swap Joysticks,No,Yes;",
	"-;",
	"R0,Reset;",
	"J,Action,Reset,1,2,3,4,5,6,7,8,9,0;",
	"V,v",`BUILD_DATE
};

wire forced_scandoubler;
wire  [1:0] buttons;
wire [127:0] status;
wire [10:0] ps2_key;
wire [21:0] gamma_bus;
wire        ioctl_download;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_wait;
wire        ioctl_wr;
wire  [7:0] ioctl_index;


wire [15:0] joystick_0,joystick_1;
wire [24:0] ps2_mouse;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(gamma_bus),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait),
	.ioctl_index(ioctl_index),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask({status[5]}),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),

	.ps2_key(ps2_key)
);

wire       PAL = status[15];
wire       joy_swap = status[7];

wire       VOICE = status[1];
wire       G7200    = (CONTRAST != 3'd0);
wire [2:0] CONTRAST = status[14:12];

wire [15:0] joya = joy_swap ? joystick_1 : joystick_0;
wire [15:0] joyb = joy_swap ? joystick_0 : joystick_1;


///////////////////////  CLOCK/RESET  ///////////////////////////////////


wire clock_locked;
wire clk_2m5;
wire clk_sys;


////////////The Voice /////////////////////////////////////////////////


wire clk_750k;  

 
pll_thevoice pll_thevoice
( 
  .inclk0(CLK_50M),
  .c0    (clk_750k),
  .c1    (clk_2m5)
);

////////////////////////////////////////////////////////////////////////

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(),
	.outclk_1(clk_sys),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.locked(clock_locked)
);



wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

wire [1:0] col = status[4:3];

always @(posedge CLK_50M) begin : cfg_block
	reg pald = 0, pald2 = 0;
	reg [3:0] state = 0;

	pald <= status[15];
	pald2 <= pald;

	cfg_write <= 0;
	if(pald2 != pald) state <= 1;

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
			case(state)
				1: begin
				cfg_address <= 0;
				cfg_data <= 0;
				cfg_write <= 1;
				end
				5: begin
				cfg_address <= 4;
				cfg_data <= pald2 ? 'h00020605 : 'h00020504;
				cfg_write <= 1;
				end
				7: begin
				cfg_address <= 5;
				cfg_data <= pald2 ? 'h00027271 : 'h00025F5E;
				cfg_write <= 1;
				end
				9: begin
				cfg_address <= 5;
				cfg_data <= pald2 ? 'h00040404 : 'h00060605;
				cfg_write <= 1;
				end
				11: begin
				cfg_address <= 7;
				cfg_data <= pald2 ? 'h5999999A : 'h7332F2C7;
				cfg_write <= 1;
				end
				13: begin
				cfg_address <= 2;
				cfg_data <= 0;
				cfg_write <= 1;
				end
			endcase
	end
end

// hold machine in reset until first download starts
reg old_pal = 0;

always @(posedge clk_sys) begin
	old_pal <= PAL;
end

wire reset = buttons[1] | status[0] | ioctl_download | (old_pal != PAL);

// Original Clocks:
// Standard    NTSC           PAL
// Sys clock   42.95454       70.9379
// Main clock  21.47727 MHz   35.46895 MHz // ntsc/pal colour carrier times 3/4 respectively
// VDC divider 3              5
// VDC clock   7.159 MHz      7.094 MHz
// CPU divider 4              6
// CPU clock   5.369 MHz      5.911 MHz

reg clk_cpu_en;
reg clk_vdc_en;

reg [3:0] clk_cpu_en_ctr;
reg [3:0] clk_vdc_en_ctr;

// Generate pulse enables for cpu and vdc

always @(posedge clk_sys or posedge reset) begin
	if (reset) begin
		clk_cpu_en_ctr <= 4'd0;
		clk_vdc_en_ctr <= 4'd0;
	end else begin

		// CPU Counter
		if (clk_cpu_en_ctr >= (PAL ? 4'd11 : 4'd7)) begin
			clk_cpu_en_ctr <= 4'd0;
			clk_cpu_en <= 1;
		end else begin
			clk_cpu_en_ctr <= clk_cpu_en_ctr + 4'd1;
			clk_cpu_en <= 0;
		end

		// VDC Counter
		if (clk_vdc_en_ctr >= (PAL ? 4'd9 : 4'd5)) begin
			clk_vdc_en_ctr <= 4'd0;
			clk_vdc_en <= 1;
		end else begin
			clk_vdc_en_ctr <= clk_vdc_en_ctr + 4'd1;
			clk_vdc_en <= 0;
		end
	end
end


////////////////////////////  SYSTEM  ///////////////////////////////////

wire cart_cs;
wire cart_cs_n;

vp_console vp
(
	// System
	.is_pal_g       (PAL),
	.clk_i          (clk_sys),
	.clk_cpu_en_i   (clk_cpu_en),
	.clk_vdc_en_i   (clk_vdc_en),
	.clk_750k       (clk_750k),
	.clk_2m5        (clk_2m5),

	.res_n_i        (~reset & joy_reset), // low to reset

	// Cart Data
	.cart_cs_o      (cart_cs),
	.cart_cs_n_o    (cart_cs_n),
	.cart_wr_n_o    (cart_wr_n),   // Cart write
	.cart_a_o       (cart_addr),   // Cart Address
	.cart_d_i       (cart_do), // Cart Data
	.cart_d_o       (cart_di),     // Cart data out
	.cart_bs0_o     (cart_bank_0), // Bank switch 0
	.cart_bs1_o     (cart_bank_1), // Bank Switch 1
	.cart_psen_n_o  (cart_rd_n),   // Program Store Enable (read)
	.cart_t0_i      (),
	.cart_t0_o      (),
	.cart_t0_dir_o  (),
	// Char Rom data
	.char_d_i       (char_do), // Char Data
	.char_a_o       (char_addr),
	.char_en        (char_en),


	// Input
	.joy_up_n_i     (joy_up), //-- idx = 0 : left joystick -- idx = 1 : right joystick
	.joy_down_n_i   (joy_down),
	.joy_left_n_i   (joy_left),
	.joy_right_n_i  (joy_right),
	.joy_action_n_i (joy_action),

	.keyb_dec_o     (kb_dec),
	.keyb_enc_i     (kb_enc),

	// Video
	.r_o            (R),
	.g_o            (G),
	.b_o            (B),
	.l_o            (luma),
	.hsync_n_o      (HSync),
	.vsync_n_o      (VSync),
	.hblank_o          (HBlank),
	.vblank_o          (VBlank),

	// Sound
	.snd_o          (),
	.snd_vec_o      (snd),
	
	//The voice
	.voice_enable   (VOICE),
	.snd_voice_o    (voice_out)
); 

////////////////////////////////////////////////////////////////////////
rom  rom
(
	.clock(clk_sys),
	.address((ioctl_download && ioctl_index < 3)? ioctl_addr[13:0] : rom_addr),
	.data(ioctl_dout),
	.wren(ioctl_wr&& ioctl_index <3),
	.rden(XROM ? rom_oe_n : ~cart_rd_n),
	.q(cart_do)
);

char_rom  char_rom
(
	.clock(clk_sys),
	.address((ioctl_download && ioctl_index == 3) ? ioctl_addr[8:0] : char_addr),
	.data(ioctl_dout),
	.wren(ioctl_wr && ioctl_index == 3),
	.rden(char_en),
	.q(char_do)
);

wire [11:0] cart_addr;
wire [7:0]  cart_do;
wire [11:0] char_addr;
wire [7:0]  char_do;
wire cart_wr_n;
wire [7:0] cart_di;

wire char_en;
wire cart_bank_0;
wire cart_bank_1;
wire cart_rd_n;
reg [15:0]  cart_size;
wire XROM;
wire rom_oe_n = ~(cart_cs_n & cart_bank_0) & cart_rd_n ;
wire [13:0] rom_addr;

reg old_download = 0;


always @(posedge clk_sys) begin
	old_download <= ioctl_download;

	if (~old_download & ioctl_download)
	begin
		cart_size <= 16'd0;
		XROM <= (ioctl_index == 2);
	end
	else if (ioctl_download & ioctl_wr)
		cart_size <= cart_size + 16'd1;
end


always @(*)
  begin
   if (XROM == 1'b1)
	   rom_addr <= {2'b0, cart_addr[11:0]};
	else
	case (cart_size)
	  16'h1000 : rom_addr <= {1'b0,cart_bank_0, cart_addr[11], cart_addr[9:0]};  //4k
	  16'h2000 : rom_addr <= {cart_bank_1,cart_bank_0, cart_addr[11], cart_addr[9:0]};   //8K
	  16'h4000 : rom_addr <= {cart_bank_1,cart_bank_0, cart_addr[11:0]}; //12K (16k banked)
	  default  : rom_addr <= {1'b0, cart_addr[11], cart_addr[9:0]};
	endcase
  end

////////////////////////////  SOUND  ////////////////////////////////////

wire signed[3:0] snd;
wire signed [15:0] voice_out; 

wire signed [15:0] sound_s = {2'b0,snd,snd,snd,2'b0};
wire signed [15:0] voice_s = VOICE ? {voice_out[15],voice_out[11:0],3'b0} : 16'b0;

assign AUDIO_L = sound_s;
assign AUDIO_R = voice_s;
assign AUDIO_S = 1;
assign AUDIO_MIX = status[3:2];

////////////////////////////  VIDEO  ////////////////////////////////////


wire R;
wire G;
wire B;
wire luma;

wire HSync;
wire VSync;
wire VBlank;
wire HBlank;
wire [7:0] video;
wire ce_pix_out; 
wire freeze_sync;

wire ce_pix = clk_vdc_en;

wire [7:0] Rx = color_lut_vp[{R, G, B, luma}][23:16];
wire [7:0] Gx = color_lut_vp[{R, G, B, luma}][15:8];
wire [7:0] Bx = color_lut_vp[{R, G, B, luma}][7:0];

always @(*) begin
        casex (CONTRAST)
                3'd1:    colors <= {{Rx[7:1],Bx[7]}  ,{Gx[7]  ,Rx[7:1]},{Rx[7:1],Bx[7]}  };
                3'd2:    colors <= {{Rx[7:2],Bx[7:6]},{Gx[7:6],Rx[7:2]},{Rx[7:2],Bx[7:6]}};
                3'd3:    colors <= {{Rx[7:4],Bx[7:4]},{Gx[7:4],Rx[7:4]},{Rx[7:4],Bx[7:4]}};
                3'd4:    colors <= {Rx,Gx,Bx};
                3'd5:    colors <= {{Bx[7:4],Rx[7:4]},{Gx[7:4],Bx[7:4]},{Bx[7:4],Rx[7:4]}};
                3'd6:    colors <= {{Bx[7:2],Rx[7:6]},{Gx[7:6],Bx[7:2]},{Bx[7:2],Rx[7:6]}};
                3'd7:    colors <= {{Bx[7:1],Rx[7]}  ,{Gx[7]  ,Bx[7:1]},{Bx[7:1],Rx[7]}  };
           default: colors <= {Rx,Gx,Bx};
        endcase
end


wire [23:0] colors;

assign CLK_VIDEO = clk_sys;
assign VGA_F1 = 0;


wire [2:0] scale = status[11:9];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;


wire [7:0] grayscale;

vga_to_greyscale vga_to_greyscale
(
        .r_in  (colors[23:16]),
        .g_in  (colors[15:8]),
        .b_in  (colors[7:0]),
        .y_out (grayscale)
);


video_mixer #(.LINE_LENGTH(455)) video_mixer
(

   .*,
	//.clk_vid(clk_sys),
	.HBlank(HBlank),
	.VBlank(VBlank),
	.HSync(HSync),
	.VSync(VSync),
	//.ce_pix(ce_pix),

	.scandoubler(scale || forced_scandoubler),
	//.scanlines(0),
	.hq2x(scale==1),
	//.mono(0),

	.R(G7200 ? grayscale : Rx),
   .G(G7200 ? grayscale : Gx),
   .B(G7200 ? grayscale : Bx)

);

assign CLK_VIDEO = clk_sys;
//assign CE_PIXEL = ce_pix;

////////////////////////////  INPUT  ////////////////////////////////////

// [6-15] = Num Keys
// [5]    = Reset
// [4]    = Action
// [3]    = UP
// [2]    = DOWN
// [1]    = LEFT
// [0]    = RIGHT

wire [6:1] kb_dec;
wire [14:7] kb_enc;
wire kb_read_ack;

reg [7:0] ps2_ascii;
reg ps2_changed;
reg ps2_released;

reg [7:0] joy_ascii;
reg [9:0] joy_changed;
reg joy_released;

wire [9:0] joy_numpad = (joya[15:6] | joyb[15:6]);

// If the user tries hard enough with the gamepad they can get keys stuck
// until they press them again. This could stand to be improved in the future.

always @(posedge clk_sys) begin
	reg old_state;
	reg [9:0] old_joy;

	old_state <= ps2_key[10];
	old_joy <= joy_numpad;

	ps2_changed <= (old_state != ps2_key[10]);
	ps2_released <= ~ps2_key[9];

	joy_changed <= (joy_numpad ^ old_joy);
	joy_released <= (joy_numpad ? 1'b0 : 1'b1);

	if(old_state != ps2_key[10]) begin
		casex(ps2_key[8:0])
			'hX16: ps2_ascii <= "1"; // 1
			'hX1E: ps2_ascii <= "2"; // 2
			'hX26: ps2_ascii <= "3"; // 3
			'hX25: ps2_ascii <= "4"; // 4
			'hX2E: ps2_ascii <= "5"; // 5
			'hX36: ps2_ascii <= "6"; // 6
			'hX3D: ps2_ascii <= "7"; // 7
			'hX3E: ps2_ascii <= "8"; // 8
			'hX46: ps2_ascii <= "9"; // 9
			'hX45: ps2_ascii <= "0"; // 0

			'hX1C: ps2_ascii <= "a"; // a
			'hX32: ps2_ascii <= "b"; // b
			'hX21: ps2_ascii <= "c"; // c
			'hX23: ps2_ascii <= "d"; // d
			'hX24: ps2_ascii <= "e"; // e
			'hX2B: ps2_ascii <= "f"; // f
			'hX34: ps2_ascii <= "g"; // g
			'hX33: ps2_ascii <= "h"; // h
			'hX43: ps2_ascii <= "i"; // i
			'hX3B: ps2_ascii <= "j"; // j
			'hX42: ps2_ascii <= "k"; // k
			'hX4B: ps2_ascii <= "l"; // l
			'hX3A: ps2_ascii <= "m"; // m
			'hX31: ps2_ascii <= "n"; // n
			'hX44: ps2_ascii <= "o"; // o
			'hX4D: ps2_ascii <= "p"; // p
			'hX15: ps2_ascii <= "q"; // q
			'hX2D: ps2_ascii <= "r"; // r
			'hX1B: ps2_ascii <= "s"; // s
			'hX2C: ps2_ascii <= "t"; // t
			'hX3C: ps2_ascii <= "u"; // u
			'hX2A: ps2_ascii <= "v"; // v
			'hX1D: ps2_ascii <= "w"; // w
			'hX22: ps2_ascii <= "x"; // x
			'hX35: ps2_ascii <= "y"; // y
			'hX1A: ps2_ascii <= "z"; // z
			'hX29: ps2_ascii <= " "; // space

			'hX79: ps2_ascii <= "+"; // +
			'hX7B: ps2_ascii <= "-"; // -
			'hX7C: ps2_ascii <= "*"; // *
			'hX4A: ps2_ascii <= "/"; // /
			'hX55: ps2_ascii <= "="; // /
			'hX1F: ps2_ascii <= 8'h11; // gui l / yes
			'hX27: ps2_ascii <= 8'h12; // gui r / no
			'hX5A: ps2_ascii <= 8'd10; // enter
			'hX66: ps2_ascii <= 8'd8; // backspace
			default: ps2_ascii <= 8'h00;
		endcase
	end else if (joy_numpad) begin
		if (joy_numpad[0])
			joy_ascii <= "1";
		else if (joy_numpad[1])
			joy_ascii <= "2";
		else if (joy_numpad[2])
			joy_ascii <= "3";
		else if (joy_numpad[3])
			joy_ascii <= "4";
		else if (joy_numpad[4])
			joy_ascii <= "5";
		else if (joy_numpad[5])
			joy_ascii <= "6";
		else if (joy_numpad[6])
			joy_ascii <= "7";
		else if (joy_numpad[7])
			joy_ascii <= "8";
		else if (joy_numpad[8])
			joy_ascii <= "9";
		else if (joy_numpad[9])
			joy_ascii <= "0";
		else
			joy_ascii <= 8'h00;
	end
end

vp_keymap vp_keymap
(
	.clk_i(clk_sys),
	.res_n_i(~reset),
	.keyb_dec_i(kb_dec),
	.keyb_enc_o(kb_enc),

	.rx_data_ready_i(ps2_changed || joy_changed),
	.rx_ascii_i(ps2_changed ? ps2_ascii : joy_ascii),
	.rx_released_i(ps2_released && joy_released),
	.rx_read_o(kb_read_ack)
);

// Joystick wires are low when pressed
// Passed as a vector bit 1 = left bit 0 = right
// There is no definition as to which is player 1

wire [1:0] joy_up     = {~joya[3], ~joyb[3]};
wire [1:0] joy_down   = {~joya[2], ~joyb[2]};
wire [1:0] joy_left   = {~joya[1], ~joyb[1]};
wire [1:0] joy_right  = {~joya[0], ~joyb[0]};
wire [1:0] joy_action = {~joya[4], ~joyb[4]};
wire       joy_reset  = ~joya[5] & ~joyb[5];


////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// LUT using calibrated palette
wire [23:0] color_lut_vp[16] = '{
	  24'h000000,    //BLACK
	  24'h676767,    //GREY
	  24'h1a37be,    //BLUE
	  24'h5c80f6,    //BLUE I
	  24'h006d07,    //GREEN
	  24'h56c469,    //GREEN I
	  24'h2aaabe,    //BLUE GREEN
	  24'h77e6eb,    //BLUE-GREEN I
	  24'h790000,    //RED
	  24'hc75151,    //RED I
	  24'h94309f,    //VIOLET
	  24'hdc84e8,    //VIOLET I
	  24'h77670b,    //KAHKI
	  24'hc6b86a,    //KAHKI I
	  24'hcecece,    //GREY I 
	  24'hffffff     //WHITE
};


endmodule
