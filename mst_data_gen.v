/*
  File Name     : mst_data_gen.v 
  Department    : IC Design, FTDI SGP
  Author        : Do Ngoc Duong
  History       : 25 April 2016 - Initial Version 

  Description   : This module generates the streaming data 
*/

module mst_data_gen (
  input rst_n, 
  input clk,
  input ch0_req,
  output reg [15:0] ch0_dat
);
  //245 Mode
  always @ (posedge clk or negedge rst_n)
  begin
    if (!rst_n)
        ch0_dat <= 16'hFFFF;
    else if (ch0_req)  
      ch0_dat <= (&ch0_dat) ? 16'h0000 : (ch0_dat + 1'b1);
  end  
endmodule 
