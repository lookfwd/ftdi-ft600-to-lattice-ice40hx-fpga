/*
  File Name     : mst_pre_fet.v  
  Department    : IC Design, FTDI SGP
  Author        : Do Ngoc Duong
  History       : 30 June 2016 - Initial Version 

  Description   : This module contains pre-fetch data 
*/

module mst_pre_fet 
    (
     clk,
     rst_n,
     //Flow control interface
     prefena,       // pre-fetch enable 
     prefreq,       // pre-fetch data request signal
     prefdout,      // pre-fetch data out
     //Streaming generate interface 
     gen0req,        // Generate request channel 0
     gen0dat,        // Generate data channel 0
     );
//**********************************************
parameter ADDRBIT = 2;
parameter LENGTH  = 4;
parameter WIDTH   = 17;
//**********************************************
input clk;
input rst_n;
//
input prefena;      
input prefreq;      
output[WIDTH -1:0]  prefdout;      
//Streaming generate interface 
output gen0req;
input[WIDTH-5:0]  gen0dat; 
//*********************************************
reg     [WIDTH-1:0]     pref_dat0 [LENGTH-1:0];
reg     [ADDRBIT:0]     pref_len0;
reg     [ADDRBIT-1:0]   wrcnt0;
//
wire    prefnempt; 
assign  prefnempt    =   (pref_len0!={1'b0,{ADDRBIT{1'b0}}});
// 
wire    preffull;
assign  preffull    =   (pref_len0[ADDRBIT]);
//
wire    prefwr; 
wire    write;
assign  write       =   (prefwr & !preffull);
// 
wire    read;
assign  read        =   (prefreq & prefnempt);
// 
wire    [ADDRBIT-1:0]   rdcnt0;
assign  rdcnt0       =   wrcnt0 - pref_len0[ADDRBIT-1:0];
// 
integer     i;
reg [WIDTH-1:0] prefdat0 [LENGTH-1:0];
reg [WIDTH-1:0] prefdin; 
//
always @(posedge clk or negedge rst_n)
begin
  if(!rst_n) 
    for(i=0; i<LENGTH; i=i+1)
    begin 
      prefdat0[i]      <= {WIDTH{1'b0}};
    end 
  else if(write)
    prefdat0[wrcnt0] <= prefdin;
end
// 
always @(posedge clk or negedge rst_n)
begin
  if(!rst_n) 
  begin
    wrcnt0 <= {ADDRBIT{1'b0}};
  end 
  else if(write)
    wrcnt0 <= wrcnt0 + 1'b1;
end  
// 
always @(posedge clk or negedge rst_n)
begin
  if(!rst_n) pref_len0  <= {1'b0,{ADDRBIT{1'b0}}};
  else
    case({read,write})
      2'b01:   pref_len0 <= pref_len0 + 1'b1;
      2'b10:   pref_len0 <= pref_len0 - 1'b1;
      default: pref_len0 <= pref_len0;
    endcase
end

wire [WIDTH-1:0] prefdout;  
assign prefdout = prefdat0[rdcnt0]; 
//Internal FIFO control
wire prenotful; 
assign prenotful = (pref_len0 < 3);
//read data from FIFO
wire datareq;
assign datareq = prefena && prenotful ;
// 
reg datareq_p1;
always @(posedge clk or negedge rst_n)
begin
  if(!rst_n) 
    datareq_p1 <= 1'b0;
  else
    datareq_p1 <= datareq; 
end
//
assign prefwr = datareq_p1;
// 
always @(*)  
begin 
    prefdin = {1'b1,gen0dat};
end 
//Generate Data Request 
wire gen0req;
//
assign gen0req = datareq; 
// 
endmodule 
