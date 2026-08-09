module ShiftRegister #(
parameter int data_width,
parameter bit Shift_Right
)(
input logic clk,
input logic reset,
input logic Din,
output logic [data_width-1:0]Dout,
output logic ShiftEn
);

logic [data_width-1:0] Dsig;

always_ff@(posedge clk or posedge reset) begin
               if (reset == 1'b1) 
                       Dsig <= {1'b1};     
               else begin
					     if (Shift_Right) begin
                      if (ShiftEn == 1'b1) 
                        Dsig <= {Din, Dsig[data_width-1:1]};
						  end
						  else begin
						     if (ShiftEn == 1'b1) 
                         Dsig <= {Dsig[data_width-2:0], Din};
                    end
					end
end
				

assign Dout = Dsig;

endmodule
