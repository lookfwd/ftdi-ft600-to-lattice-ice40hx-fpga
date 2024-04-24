/*
  File Name     : mst_fifo_top.v 
  Department    : IC Design, FTDI SGP
  Author        : Do Ngoc Duong
  History       : 25 April 2016 - Initial Version 

  Description   : This is the top module of Master FIFO bus  
*/

module mst_fifo_top (
  //GPIO Control Signals
  input wire R_OOB,
  input wire W_OOB,  
  // FIFO Slave interface 
  input wire CLK,
  inout wire [15:0] DATA,
  inout wire [1:0] BE,
  input wire RXF_N,    // ACK_N
  input wire TXE_N,
  output wire WR_N,    // REQ_N
  output wire SIWU_N,
  output wire RD_N,
  output wire OE_N,
  // Miscellaneous Interface 
  output wire STRER,
  input wire CLK_IN // PCB 12Mhz
);

  assign SIWU_N		= 1'b1; // Reserved external pull-up

  assign ERDIS = 0; // 1: Disable received data sequence check  
  
  wire tp_dt_oe_n;
  wire tp_be_oe_n;
  wire [15:0] tp_data;
  wire   tp_be;

  assign DATA[7:0] 	 = ~tp_be_oe_n ? tp_data[7:0] 	: 8'bzzzzzzzz;
  assign DATA[15:8]  = ~tp_dt_oe_n ? tp_data[15:8] 	: 8'bzzzzzzzz;
  assign BE 	= ~tp_be_oe_n ? {2{tp_be}} 		: 2'bzz;

  wire RST_N;

  wire ch0_vld;
  wire [15:0] chk_data;
  // 
  wire ch0_req;
  wire [15:0] ch0_dat;
  //
  wire prefena;
  wire prefreq;
  wire[16:0]  prefdout; 
 //
  mst_fifo_fsm i1_fsm (
    // IO interface 
    .rst_n	(RST_N),
    .clk		(CLK),
    .txe_n	(TXE_N),
    .rxf_n	(RXF_N),
    .idata	(DATA),
    .ibe		(BE),
    //
    .r_oob	(R_OOB),
    .w_oob	(W_OOB),
    // 
    .odata	(tp_data),
    .obe		(tp_be),
    .dt_oe_n(tp_dt_oe_n),
    .be_oe_n(tp_be_oe_n),
    .wr_n	(WR_N),
    .rd_n	(RD_N),
    .oe_n	(OE_N),

    // Check Data interface 
    .ch0_vld	(ch0_vld),
    .chk_data	(chk_data),
    .chk_err	(STRER),
    //
    .prefena   (prefena),
    .prefreq   (prefreq),
    .prefdout  (prefdout)
  );
  //
   mst_pre_fet i2_pref (
    .clk      (CLK),
    .rst_n    (RST_N),
     //Flow control interface
    .prefena  (prefena),    
    .prefreq  (prefreq),    
    .prefdout (prefdout),     
     //Streaming generate interface 
    .gen0req  (ch0_req),  
    .gen0dat  (ch0_dat)
     );
  // 
  mst_data_chk i3_chk(
    .rst_n	((!W_OOB) & RST_N),
    .clk	(CLK),
    .erdis 	(ERDIS), 
    .ch0_vld	(ch0_vld),
    .rdata	(chk_data),
    .seq_err	(STRER) 
  );
  //
  mst_data_gen i4_gen(
    .rst_n	((!R_OOB) & RST_N),
    .clk	(CLK),
    .ch0_req	(ch0_req),
    .ch0_dat	(ch0_dat)
  );

  wire pll_locked;
  wire pll_clk; // PLL-Generated Clock (120 Mhz - given settings) - Not Used

  // Global Asynchronous Reset
  // See https://github.com/npetersen2/iCE40_Template/blob/master/sys.v
  reg [3:0] pll_locked_ff;
  always @(posedge CLK_IN)
      pll_locked_ff <= {pll_locked_ff, pll_locked};
  assign RST_N = pll_locked_ff[3];

  pll myPLL(
    .clock_in(CLK_IN),
    .global_clock(pll_clk),
    .locked(pll_locked)
  );

endmodule 
