module BaudClkGenerator#(
parameter int Data_width,
parameter int sysclkfreq,
parameter int baudrate,
parameter bit rx_true
)(
input logic clk,
input logic reset,
input logic start,
output logic baudclk,
output logic Ready
);

localparam int bitperiod = sysclkfreq / baudrate;
localparam int halfbitperiod = sysclkfreq / (baudrate*2);
logic [$clog2(bitperiod+1)-1:0] bitperiodcounter;
logic [$clog2(Data_width+1)-1:0] pulse_pending;

////Bitperiodprocess
always_ff@(posedge clk or posedge reset) begin
if (reset) begin 
   baudclk <= 1'b0;
	bitperiodcounter <= 0;
end
else begin
 if (pulse_pending > 0) begin
    if (bitperiodcounter == bitperiod) begin
	    bitperiodcounter <= 0;
		 baudclk <= 1'b0;
	 end
	 else begin
	     bitperiodcounter <= bitperiodcounter + 1;
		  baudclk <= 1'b0;
	 end
	end
 else begin
     baudclk <= 1'b0;
	  if(rx_true == 1'b1) 
	  bitperiodcounter <= halfbitperiod;
	  else
	  bitperiodcounter <= 1'b0;
 end
end
end
////PulseControl_process
always_ff@(posedge clk or posedge reset) begin
if (reset)
    pulse_pending <= 0;
else begin
 if (start == 1'b1) 
     pulse_pending <= Data_width;
 else if (baudclk == 1'b1) 
     pulse_pending <= pulse_pending - 1;
 end
end
////ReadyOutprocess
always_ff@(posedge clk or posedge reset) begin
if (reset)
    Ready <= 1'b0;
else begin
 if (start == 1'b1) 
     Ready <= 1'b0;
 else if (pulse_pending == 0) 
     Ready <= 1'b1;
 end
end

endmodule



