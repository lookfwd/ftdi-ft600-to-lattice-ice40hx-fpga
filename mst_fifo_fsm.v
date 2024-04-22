/*
  File Name     : mst_fifo_fsm.v 
  Department    : IC Design, FTDI SGP
  Author        : Do Ngoc Duong
  History       : 25 April 2016 

  Description   : This module contains state machine for Master bus 
*/
module mst_fifo_fsm (
  // IO interface 
  input  rst_n,
  input  clk,
  input  txe_n,
  input  rxf_n,
  input  [31:0] idata,
  input  [3:0]  ibe,
  //
  input  r_oob,
  input  w_oob,  
  // 
  output  reg [31:0] odata,
  output  reg [3:0]  obe,
  output  reg dt_oe_n,
  output  reg be_oe_n,
  output  reg wr_n,    
  output  reg rd_n,
  output  reg oe_n,

  // Check Data interface 
  output  ch0_vld,
  output  [31:0] chk_data,
  input	  chk_err,  
  // Pre-fetch interface 
  output wire prefena,
  output wire prefreq,
  input [35:0]  prefdout
);
  //
  localparam IDLE	= 4'b0001;
  localparam MTRD	= 4'b0010;
  localparam MDLE	= 4'b0100;
  localparam MTWR	= 4'b1000;
  //  
  reg [3:0] nxt_state, cur_stap1, cur_stap2, cur_stap3, cur_stap4;
  wire [3:0] cur_state;  
  
  // Hardcoded on top-level
  wire [3:0] mst_rd_n = 4'h0;
  wire [3:0] mst_wr_n = 4'h0;

  //
  wire [3:0] imst_rd_n;
  wire [3:0] imst_wr_n;
  reg  [3:0] mst_rd_n_p1;
  reg  [3:0] mst_wr_n_p1;
  reg  [3:0] mst_rd_n_p2;
  reg  [3:0] mst_wr_n_p2;
  reg        mst_wr_n_p3;
  reg        mst_wr_n_p4;

  reg  [36:0] remain; 
  reg  rxf_n_p1;
  reg  txe_n_p1; 
  reg  w_oob_p1;
  reg  w_oob_p2;
  reg  r_oob_p1;
  reg  r_oob_p2;
  reg  r_oob_p3;
  reg  w_1byte;
  reg  w_1flag; 
  //
  assign imst_rd_n = mst_rd_n_p2;
  assign imst_wr_n = mst_wr_n_p2;
  // Write one byte  
  always @ (posedge clk or negedge rst_n)
  begin
    if (~rst_n)
      w_1byte <= 1'b0;
    else if (r_oob_p2 & (!r_oob_p3))
      w_1byte <= 1'b1;
    else if (w_1byte && (cur_stap1 == IDLE) && (cur_stap2 == MTWR))
      w_1byte <= 1'b0;
    else if (!r_oob_p2)
      w_1byte <= 1'b0; 
  end 
  // Write one byte flag  
  always @ (posedge clk or negedge rst_n)
  begin
    if (~rst_n)
      w_1flag <= 1'b0;
    else if (!r_oob_p2) 
      w_1flag <= 1'b0;
    else if (w_1byte & (cur_stap2 == MTWR))
      w_1flag <= 1'b1;
  end 
  //Condition for state change  
  reg [3:0] ifsm_cond;
  wire r_oobe;
  assign r_oobe = r_oob_p2 | ((!wr_n) & (obe != 4'hF)); 
  // 
  always @ (posedge clk or negedge rst_n)
  begin
    if (~rst_n)
      ifsm_cond <= 4'h0;
    else
    begin
      ifsm_cond[0] <= (cur_stap1 == IDLE) & (!imst_rd_n[0]) & (!rxf_n); 
      ifsm_cond[1] <= (cur_state == MTRD) & ( imst_rd_n[0]  | (rxf_n  & (!rxf_n_p1))) ; 
      ifsm_cond[2] <= (cur_state == MDLE) & (!imst_wr_n[0]) & (!txe_n)& (!w_1flag);
      ifsm_cond[3] <= (cur_stap3 == MTWR) & ( imst_wr_n[0]  | (txe_n  & (!txe_n_p1))  | r_oobe) ; 
    end 
  end 
// Master State Machine  
  always @ (posedge clk, negedge rst_n)
  begin
    if (~rst_n) begin
      cur_stap1 <= IDLE;
      cur_stap2 <= IDLE;
      cur_stap3 <= IDLE;
      cur_stap4 <= IDLE;
    end
    else begin
      cur_stap1 <= cur_state;
      cur_stap2 <= cur_stap1; 
      cur_stap3 <= cur_stap2; 
      cur_stap4 <= cur_stap3; 
    end
  end
//
  assign cur_state = nxt_state;
  // 
  always @ (posedge clk, negedge rst_n) 
  begin
    if (~rst_n)
      nxt_state <= IDLE;
    else if (chk_err != 1'b0)
      nxt_state <= MDLE;
    else 
      case (cur_state)
        IDLE : nxt_state <= ifsm_cond[0] ? MTRD : (((cur_stap4 == IDLE) & (cur_stap3 == IDLE)  & 
                                                 (cur_stap2 == IDLE) & (cur_stap1 == IDLE)) ? MDLE : IDLE); 
        MTRD : nxt_state <= ifsm_cond[1] ? MDLE : MTRD;
        MDLE : nxt_state <= ifsm_cond[2] ? MTWR : (((cur_stap4 == MDLE) & (cur_stap3 == MDLE)  & 
                                                 (cur_stap2 == MDLE) & (cur_stap1 == MDLE)) ? IDLE : MDLE); 
        MTWR : nxt_state <= (ifsm_cond[3] | (r_oobe & (!wr_n))) ? IDLE : MTWR; 
      endcase
  end
//
reg  [31:0] rdata;
reg  [3:0] rbe; 
reg  rvalid;
wire [31:0] wdata;
wire [3:0] wbe; 
//
//Slave FIFO data bus control 
  always @ (posedge clk or negedge rst_n)
  begin
    if (~rst_n)
    begin 
      odata	<= 32'hFFFF_FFFF;
      obe	<=  4'hF;
    end
    else if ((cur_state == MTWR) || (cur_stap1 == MTWR)) 
      begin
        odata <= r_oobe ? 32'h0000_0036 : (remain[36] ? remain[31:0]  : wdata[31:0]);
        obe   <= r_oobe ? 4'h1          : (remain[36] ? remain[35:32] : wbe);
      end 
    else if ((cur_stap2 == IDLE) | (cur_stap2 == MDLE)) 
    begin 
      odata	<= 32'hFFFF_FFFF;
      obe	<=  4'hF;
    end
  end
  //Read data valid 
  always @ (posedge clk or negedge rst_n)
  begin
    if (~rst_n)
    begin 
      rdata     <= 'b0;
      rbe	<= 'b0; 
      rvalid    <= 'b0; 
    end
    else if (cur_stap1 == MTRD)
    begin
      rdata 	<= idata;
      rbe	<= ibe;
      rvalid 	<= (rxf_n | rd_n) ? 1'b0 : (!w_oob_p2);   
    end  
    else 
    begin 
      rdata     <= 'b0;
      rbe	<= 'b0; 
      rvalid    <= 'b0; 
    end
  end 
  // IO control 
  always @ (posedge clk or negedge rst_n)
  begin
    if (~rst_n)
    begin 
      dt_oe_n	<= 'b1;
      be_oe_n 	<= 'b1;
      wr_n	<= 'b1;     
      rd_n	<= 'b1; 
      oe_n	<= 'b1;
    end
    else
    begin  
      if ((cur_state == IDLE) || (cur_state == MDLE)) 
      begin 
        dt_oe_n	<= 'b1;
        be_oe_n	<= 'b0;
        wr_n	<= 'b1;     
        rd_n	<= 'b1; 
        oe_n	<= 'b1;
      end
      else if (cur_state == MTRD)
        begin
          dt_oe_n 	<= 'b0;
          be_oe_n 	<= 'b1;
          wr_n		<= 'b1;     
          rd_n		<= (rxf_n | oe_n) ? 1'b1 : 1'b0; 
          oe_n		<=  rxf_n         ? 1'b1 : 1'b0; 
        end
      else if (cur_state == MTWR) 
        begin
      	  dt_oe_n	<= 1'b0; 
      	  be_oe_n 	<= 1'b0;
          if ((cur_stap3 == MTWR) && (cur_stap4 == MDLE)) 
            wr_n        <= 1'b0; 
          else if (r_oobe | txe_n)
	    wr_n 	<= 1'b1;
      	  rd_n		<= 'b1; 
      	  oe_n		<= 'b1;
        end 
    end 
  end
  // Read burst
  wire readburst;
  reg  readburst_p1; 
  // 
  assign readburst = (!txe_n) && (!r_oobe) && (cur_stap3 == MTWR) 
                          && (!remain[36]) && (!mst_wr_n_p4) && prefena;  
  //  
  //Remain data 
  always @ (posedge clk or negedge rst_n)
  begin
    if (~rst_n)
      remain <= 37'd0;
    else if ((cur_stap3 == MTWR) && (cur_stap4 == MDLE))
      remain <= 37'd0;
    else if (((!wr_n) & txe_n & readburst_p1))
      remain <= {1'b1,obe,odata};
  end
  //
  always @ (posedge clk or negedge rst_n)
  begin 
    if (~rst_n) 
    begin 
      readburst_p1<= 1'b0;
      rxf_n_p1	  <= 1'b1;
      txe_n_p1	  <= 1'b1;
      w_oob_p1    <= 1'b0;
      w_oob_p2    <= 1'b0;
      r_oob_p1    <= 1'b0;
      r_oob_p2    <= 1'b0;
      r_oob_p3    <= 1'b0;
      mst_rd_n_p1 <= 4'hF;
      mst_wr_n_p1 <= 4'hF;;
      mst_rd_n_p2 <= 4'hF;
      mst_wr_n_p2 <= 4'hF;;
      mst_wr_n_p3 <= 1'b1;;
      mst_wr_n_p4 <= 1'b1;;
    end 
    else
    begin 
      readburst_p1<= readburst;
      rxf_n_p1    <= rxf_n; 
      txe_n_p1    <= txe_n; 
      w_oob_p1    <= w_oob;		
      w_oob_p2    <= w_oob_p1;
      r_oob_p1    <= r_oob;		
      r_oob_p2    <= r_oob_p1;
      r_oob_p3    <= r_oob_p2;
      mst_rd_n_p1 <= mst_rd_n;
      mst_wr_n_p1 <= mst_wr_n;
      mst_rd_n_p2 <= mst_rd_n_p1;
      mst_wr_n_p2 <= mst_wr_n_p1;
      mst_wr_n_p3 <= mst_wr_n_p2[0];
      mst_wr_n_p4 <= mst_wr_n_p3;
    end 
  end
// Check received streaming data
assign ch0_vld = rvalid;
assign chk_data= rdata;
//*****Prefetch control
assign prefena = (cur_state == MTWR);
assign prefreq = readburst;
assign wdata   = prefdout[31:0];
assign wbe     = prefdout[35:32];
//  
endmodule 
