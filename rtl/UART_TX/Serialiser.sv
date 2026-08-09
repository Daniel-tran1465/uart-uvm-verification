module Serialiser#(
parameter int data_width,
parameter logic default_state
)(
input logic clk,
input logic reset,
input logic [data_width-1:0] Din,
input logic Load,
input logic ShiftEn,
output logic Dout

);

logic [data_width-1:0] ShiftRegister;

always_ff@(posedge clk or posedge reset) begin
if(reset) 
  ShiftRegister <= {data_width{default_state}};
else begin
  if(Load == 1'b1) 
     ShiftRegister <= Din;
  else if (ShiftEn == 1'b1)
     ShiftRegister <= {default_state, ShiftRegister[data_width-1:1]};
  end
 end
 
 assign Dout = ShiftRegister[0];
 endmodule
 
