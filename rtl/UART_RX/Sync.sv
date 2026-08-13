module Sync #(
parameter bit idle_state
)(
input logic clk,
input logic reset,
input logic ASync,
output logic Sync_out
);

logic [1:0] SR;

always_ff@(posedge clk or posedge reset) begin
if(reset)
  SR <= {2{idle_state}};
else begin
   SR[0] <= ASync;
	SR[1] <= SR[0];
	end
end

assign Sync_out = SR[1];

endmodule
