module UART#(
parameter int data_width = 8,
parameter int sysclkfreq = 50000000,
parameter int baudrate = 115200
)(
input logic clk,
input logic reset,
input logic Rx_pin,
output logic Tx_pin
);

logic Tx_start;
logic Tx_Ready;
logic IRQ_Clear;
logic Rx_IRQ;
logic [data_width-1:0] Rx_data;

UART_RX#(
.rx_data_width(data_width),
.sys_clk_freq(sysclkfreq),
.rx_baudrate(baudrate)
)rx_inst(
.clk(clk),
.reset(reset),
.Rx_Din(Rx_pin),
.IRQ_Clear(IRQ_Clear),
.Rx_Dout(Rx_data),
.Rx_IRQ(Rx_IRQ)
);

UART_TX#(
.tx_data_width(data_width),
.tx_sysclkfreq(sysclkfreq),
.tx_baudrate(baudrate)
)tx_inst(
.clk(clk),
.reset(reset),
.Tx_start(Tx_start),
.Tx_Din(Rx_data),
.Tx_Dout(Tx_pin),
.Tx_Ready(Tx_Ready)
);

typedef enum logic{
   idle,
	start_transmission
} state;

state present_state;
state next_state;

assign IRQ_Clear = Tx_start;

always_ff@(posedge clk or posedge reset) begin
if(reset) begin
present_state <= idle;
end else begin
present_state <= next_state;
end
end

always_comb begin
next_state = present_state;
Tx_start   = 1'b0;
case(present_state)
idle: begin
if (Rx_IRQ == 1'b1 && Tx_Ready == 1'b1) begin
                Tx_start = 1'b1;
                next_state = start_transmission;
             end
end
start_transmission: 
              next_state = idle;

default: next_state = idle;
endcase
end

endmodule
