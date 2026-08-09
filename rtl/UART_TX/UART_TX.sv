module UART_TX#(
parameter int tx_data_width,
parameter int tx_sysclkfreq,
parameter int tx_baudrate
)(
input logic clk,
input logic reset,
input logic Tx_start,
input logic [tx_data_width-1:0] Tx_Din,
output logic Tx_Dout,
output logic Tx_Ready
);

logic Tx_bauclk;
logic [tx_data_width+1:0] Tx_packet;

assign Tx_packet = {1'b1, Tx_Din, 1'b0};

BaudClkGenerator#(
.Data_width(tx_data_width+2),
.sysclkfreq(tx_sysclkfreq),
.baudrate(tx_baudrate),
.rx_true(1'b0)
)baudclk_inst(
.clk(clk),
.reset(reset),
.start(Tx_start),
.baudclk(Tx_baudclk),
.Ready(Tx_Ready)
);

Serialiser#(
.data_width(tx_data_width+2),
.default_state(1'b1)
)sls_inst(
.clk(clk),
.reset(reset),
.Din(Tx_packet),
.Load(Tx_start),
.ShiftEn(Tx_baudclk),
.Dout(Tx_Dout)
);

endmodule
