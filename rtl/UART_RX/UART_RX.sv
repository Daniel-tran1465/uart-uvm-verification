module UART_RX #(
parameter int rx_data_width,
parameter int sys_clk_freq,
parameter int rx_baudrate
)(
input logic clk,
input logic reset,
input logic Rx_Din,
input logic IRQ_Clear,
output logic [rx_data_width-1:0] Rx_Dout,
output logic Rx_IRQ
);

logic Rx_start;
logic Rx_baudclk;
logic Rx_Ready;
logic rx_sync;

logic falling_edge_detected;
logic rx_sync_delayed;
  
logic [3:0] rx_baud_pulse_count;
logic       rx_shift_en;


  
always_ff @(posedge clk or posedge reset) begin
  if (reset)
    rx_baud_pulse_count <= 4'd0;
  else if (Rx_start)
    rx_baud_pulse_count <= 4'd0;                    // reset đếm mỗi khi bắt đầu frame mới
  else if (Rx_baudclk)
    rx_baud_pulse_count <= rx_baud_pulse_count + 4'd1;
end

  assign rx_shift_en = Rx_baudclk && (rx_baud_pulse_count >= 4'd1) && (rx_baud_pulse_count <= 4'd8);

BaudClkGenerator#(
.Data_width(rx_data_width+2),
.sysclkfreq(sys_clk_freq),
.baudrate(rx_baudrate),
.rx_true(1'b1)
)baudclk_inst(
.clk(clk),
.reset(reset),
.start(Rx_start),
.baudclk(Rx_baudclk),
.Ready(Rx_Ready)
);

ShiftRegister#(
.data_width(rx_data_width),
.Shift_Right(1'b1)
)shiftreg_inst(
.clk(clk),
.reset(reset),
.Din(rx_sync),
.Dout(Rx_Dout),
.ShiftEn(rx_shift_en)
);

Sync#(
.idle_state(1'b1)
)sync_inst(
.clk(clk),
.reset(reset),
.ASync(Rx_Din),
.Sync_out(rx_sync)
);

always_ff@(posedge clk or posedge reset) begin
if(reset) begin
       falling_edge_detected <= 1'b0;
       rx_sync_delayed <= 1'b1;
          end 
else begin
          rx_sync_delayed <= rx_sync;
          
          if(rx_sync == 1'b0 && rx_sync_delayed == 1'b1) 
             falling_edge_detected <= 1'b1;
          else
              falling_edge_detected <= 1'b0;
      end
end

typedef enum logic [1:0] {
  idle,
  collecting_rx_data,
  collected
} state_t;

state_t present_state;
state_t next_state;

always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            present_state <= idle;
				Rx_IRQ <= 1'b0;
        end else begin
            present_state <= next_state;
		              if (IRQ_Clear)
                Rx_IRQ <= 1'b0;
            else if (present_state == collected)
                Rx_IRQ <= 1'b1;
        end
end

always_comb begin
next_state = present_state;
Rx_start   = 1'b0;
				case(present_state)
					 idle: begin
							if(falling_edge_detected==1'b1) begin
							   next_state = collecting_rx_data;
								Rx_start = 1'b1;
								end
								end
					 collecting_rx_data:begin
							if(Rx_Ready == 1'b1) next_state = collected;
							end
					 collected:begin
							next_state = idle;
							end
					 default: next_state = idle;
				endcase
				end

endmodule
