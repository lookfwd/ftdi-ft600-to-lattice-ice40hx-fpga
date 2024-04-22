/*
  File Name     : mst_data_chk.v 
  Department    : IC Design, FTDI SGP
  Author        : Do Ngoc Duong
  History       : 25 April 2016 - Initial Version 

  Description   : This module check the received streaming data 
*/
module mst_data_chk (
  input  rst_n, 
  input  clk,
  input  bus16,
  input  erdis, 
  input  ch0_vld,
  input  [31:0] rdata,
  output wire seq_err 
);
  // 
  reg [31:0] cmp0_dat;
  reg cmp0_err;
  //
  assign seq_err = cmp0_err & !erdis;
  //245 Mode or Channel 0 of 600 Mode 
  always @ (posedge clk or negedge rst_n)
  begin
    if (!rst_n)
      begin 
        cmp0_dat <= 32'h0000_0000;
        cmp0_err <= 1'b0;
      end 
    else if (ch0_vld & (!cmp0_err) & (!erdis))
      if (bus16) 
        if (rdata[15:0] == cmp0_dat[15:0])
          begin  
            cmp0_dat <= (&cmp0_dat[15:0]) ? 32'h0000_0000 : {16'h0000,cmp0_dat[15:0] + 1'b1};
            cmp0_err <= 1'b0;
          end 
        else
          begin 
            cmp0_dat <= cmp0_dat;
            cmp0_err <= 1'b1;
          end 
      else  
        if (rdata == cmp0_dat)
          begin  
            cmp0_dat <= (&cmp0_dat) ? 32'h0000_0000 : cmp0_dat + 1'b1;
            cmp0_err <= 1'b0;
          end 
        else
          begin 
            cmp0_dat <= cmp0_dat;
            cmp0_err <= 1'b1;
          end
  end
// 
endmodule 
