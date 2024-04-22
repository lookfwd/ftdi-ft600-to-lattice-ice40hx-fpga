/*
  File Name     : mst_fifo_top.v 
  Department    : IC Design, FTDI SGP
  Author        : Do Ngoc Duong
  History       : 25 April 2016 - Initial Version 

  Description   : This is the top module of Master FIFO bus  
*/

module mst_fifo_top (
  //GPIO Control Signals
  input wire HRST_N,
  input wire SRST_N,
  input wire MLTCN, // 1: Multi Channel Mode, 0: 245 Mode 
  input wire STREN, // 1: Streaming Test,     0: Loopback Test
  input wire ERDIS, // 1: Disable received data sequence check  
  input wire R_OOB,
  input wire W_OOB,  
  // FIFO Slave interface 
  input wire CLK,
  inout wire [31:0] DATA,
  inout wire [3:0] BE,
  input wire RXF_N,    // ACK_N
  input wire TXE_N,
  output wire WR_N,    // REQ_N
  output wire RD_N,
  output wire OE_N,
  // Miscellaneous Interface 
  output wire [3:0] STRER
);
  
  wire tp_dt_oe_n;
  wire tp_be_oe_n;
  wire [31:0] tp_data;
  wire [3:0]  tp_be;

  assign DATA 	= ~tp_be_oe_n ? tp_data 	: 32'hzzzz;
  assign BE 	= ~tp_be_oe_n ? tp_be 		: 4'bzzzz;

  wire RST_N = SRST_N & HRST_N;

  wire ch0_vld;
  wire ch1_vld;
  wire ch2_vld;
  wire ch3_vld;
  wire [31:0] chk_data;
  // 
  wire ch0_req;
  wire ch1_req;
  wire ch2_req;
  wire ch3_req;
  wire [31:0] ch0_dat;
  wire [31:0] ch1_dat;
  wire [31:0] ch2_dat;
  wire [31:0] ch3_dat;
  // 
  wire ififord;
  wire ififowr;
  wire [1:0] ififowrid;
  wire [3:0] ififoafull;
  wire [3:0] ififonempt;
  wire [35:0] ififo_wdat;
  wire [35:0] ififo_rdat;
  //
  wire prefena;
  wire prefreq;
  wire prefmod;
  wire[ 1:0]  prefchn;
  wire[ 3:0]  prefnempt;
  wire[35:0]  prefdout; 
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
    .mltcn	(MLTCN),
    .stren	(STREN),
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
    // 
    // Check Data interface 
    .ch0_vld	(ch0_vld),
    .ch1_vld	(ch1_vld),
    .ch2_vld	(ch2_vld),
    .ch3_vld	(ch3_vld),
    .chk_data	(chk_data),
    .chk_err	(STRER),
    // internal FIFO control interface 
    .ififoafull	(ififoafull),
    .ififonempt	(ififonempt),
    .ififowr	(ififowr),
    .ififowrid	(ififowrid),
    .ififo_wdat	(ififo_wdat),
    //
    .prefena   (prefena),
    .prefreq   (prefreq),
    .prefmod   (prefmod),
    .prefchn   (prefchn),
    .prefnempt (prefnempt),
    .prefdout  (prefdout)
  );
  //
   mst_pre_fet i2_pref (
    .clk      (CLK),
    .rst_n    (RST_N),
     //Flow control interface
    .prefena  (prefena),    
    .prefreq  (prefreq),    
    .prefmod  (prefmod),
    .prefchn  (prefchn),       
    .prefnempt(prefnempt),     
    .prefdout (prefdout),     
     //Internal FIFO interface  
    .ififord  (ififord),
    .ifnempt  (ififonempt),    
    .ififodat (ififo_rdat),  
     //Streaming generate interface 
    .gen0req  (ch0_req),  
    .gen1req  (ch1_req), 
    .gen2req  (ch2_req),
    .gen3req  (ch3_req),
    .gen0dat  (ch0_dat),
    .gen1dat  (ch1_dat),
    .gen2dat  (ch2_dat),
    .gen3dat  (ch3_dat) 
     );
  // 
  wire tc_bus16  = 1'b1;
  // 
  mst_data_chk i3_chk(
    .rst_n	((!W_OOB) & RST_N),
    .clk	(CLK),
    .bus16	(tc_bus16),
    .erdis 	(ERDIS), 
    .ch0_vld	(ch0_vld),
    .ch1_vld	(ch1_vld),
    .ch2_vld	(ch2_vld),
    .ch3_vld	(ch3_vld),
    .rdata	(chk_data),
    .seq_err	(tp_seq_err) 
  );
  //
  mst_data_gen i4_gen(
    .rst_n	((!R_OOB) & RST_N),
    .clk	(CLK),
    .bus16	(tc_bus16),
    .ch0_req	(ch0_req),
    .ch1_req	(ch1_req),
    .ch2_req	(ch2_req),
    .ch3_req	(ch3_req),
    .ch0_dat	(ch0_dat),
    .ch1_dat	(ch1_dat),
    .ch2_dat	(ch2_dat),
    .ch3_dat	(ch3_dat)
  ); 
  // 
  wire mem_w;       
  wire [13:0] mem_a;
  wire [35:0] mem_d;   
  wire [35:0] mem_q; 
  //  
  mst_fifo_ctl i5_ctl(
    .clk	(CLK),
    .rst_n	(RST_N),
    .mltcn	(MLTCN),
    //FIFO control 
    .fiford	(ififord),
    .fifordid	(prefchn),
    .fifowr	(ififowr),
    .fifowrid	(ififowrid),
    .fifoafull	(ififoafull),
    .fifonempt	(ififonempt),
    .fifo_din	(ififo_wdat),
    .fifo_dout	(ififo_rdat), 
    // Connect to memories
    .mem_we	(mem_w),
    .mem_a	(mem_a),
    .mem_d	(mem_d),
    .mem_q	(mem_q) 
    );


//
endmodule 
