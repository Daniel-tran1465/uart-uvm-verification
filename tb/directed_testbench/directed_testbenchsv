interface testbench(input logic clk, input logic reset);
  logic Rx_pin = 1'b1;
  logic Tx_pin;
endinterface
  
module top_testbench;
  logic clk = 0;
  logic reset;
  localparam int BIT_PERIOD = 434;
  always #10 clk = ~clk;
  uart_pin_if vif(clk, reset);
 
  UART #(
    .data_width(8),
    .sysclkfreq(50000000),
    .baudrate(115200)
  ) DUT (
    .clk(clk),
    .reset(reset),
    .Rx_pin(vif.Rx_pin),
    .Tx_pin(vif.Tx_pin)
  );
 
  task send_byte(bit [7:0] data);
    vif.Rx_pin = 1'b0; repeat(BIT_PERIOD) @(posedge clk); // start bit
    for(int i = 0; i<8 ; i++) begin
      vif.Rx_pin = data[i]; repeat(BIT_PERIOD) @(posedge clk); // data, LSB first
    end
    vif.Rx_pin = 1'b1; repeat(BIT_PERIOD) @(posedge clk); // stop bit
  endtask
 
  // ---- TEST 1: basic single frame (F1-F3) ----
  task test_basic();
    $display("=== [TEST 1] Basic single frame: sending 0xA5 ===");
    send_byte(8'hA5);
    repeat(BIT_PERIOD*15) @(posedge clk); // đợi đủ cho TX echo xong
    $display("=== [TEST 1] Done — check Rx_data ended at 0xA5, Tx_pin echoed it ===");
  endtask
 
  // ---- TEST 2: back-to-back frame, không nghỉ giữa 2 byte (F7) ----
  task test_back_to_back();
    $display("=== [TEST 2] Back-to-back: 0x11 immediately followed by 0x22 ===");
    send_byte(8'h11);
    send_byte(8'h22); // gọi ngay lập tức, không delay -> Rx_pin lên 1 (stop bit byte 1) rồi xuống 0 ngay (start bit byte 2)
    repeat(BIT_PERIOD*25) @(posedge clk); // đợi đủ lâu để xem cả 2 có được echo không, echo theo thứ tự nào
    $display("=== [TEST 2] Done — check: byte nao duoc echo? Ca 2? Chi byte cuoi? Thu tu dung khong? ===");
  endtask
 
  // ---- TEST 3: reset giữa chừng khi đang nhận frame (F9) ----
  task test_reset_mid_frame();
    $display("=== [TEST 3] Reset asserted mid-frame while sending 0x5A ===");
    fork
      send_byte(8'h5A);
      begin
        repeat(BIT_PERIOD*4) @(posedge clk); // đợi tới giữa chừng (khoảng bit thứ 3-4)
        $display("=== [TEST 3] Asserting reset mid-frame now ===");
        reset = 1;
        repeat(50) @(posedge clk);
        reset = 0;
        $display("=== [TEST 3] Reset deasserted, DUT should be back at idle ===");
      end
    join
    repeat(BIT_PERIOD*5) @(posedge clk); // để hệ thống ổn định sau reset
 
    // Gửi tiếp 1 byte sạch sau reset để xác nhận hệ thống hồi phục đúng, không bị kẹt state
    $display("=== [TEST 3b] Sending clean byte 0xC3 after recovery ===");
    send_byte(8'hC3);
    repeat(BIT_PERIOD*15) @(posedge clk);
    $display("=== [TEST 3] Done — check: Rx_data cuoi cung phai la 0xC3 (khong bi ket state tu byte 0x5A bi cat ngang) ===");
  endtask

// ---- TEST 4: glitch trên Rx_pin trước start bit thật (F10, rx_glitch_test) ----
task test_glitch();
  $display("=== [TEST 4] Glitch test: 1-cycle glitch on Rx_pin ===");
 
  // Đảm bảo line đang idle ổn định trước khi tạo glitch
  vif.Rx_pin = 1'b1;
  repeat(BIT_PERIOD*2) @(posedge clk);
 
  // Tạo glitch: kéo Rx_pin xuống 0 đúng 1 chu kỳ clock rồi trả về 1 ngay
  $display("=== [TEST 4] Injecting 1-cycle glitch now ===");
  vif.Rx_pin = 1'b0;
  @(posedge clk);
  vif.Rx_pin = 1'b1;
 
  // Chờ ĐỦ LÂU để "frame giả" (nếu bị false-trigger) chạy hết trọn 10 pulse rồi tự
  // quay về idle, trước khi gửi byte thật — tránh 2 frame chồng lấn gây nhiễu kết quả
  repeat(BIT_PERIOD*11) @(posedge clk);
  $display("=== [TEST 4] Check waveform: falling_edge_detected/Rx_IRQ co bi kich gia tu glitch khong (du doan: co, Rx_data se ra ~0xFF vi line giu muc 1) ===");
 
  // Gửi 1 byte thật sạch sau đó, xác nhận hệ thống hồi phục đúng dù vừa bị false-trigger
  $display("=== [TEST 4b] Sending real byte 0x99 after glitch settled ===");
  send_byte(8'h99);
  repeat(BIT_PERIOD*15) @(posedge clk);
  $display("=== [TEST 4] Done — check Rx_data cuoi cung phai la 0x99 (he thong hoi phuc dung sau glitch) ===");
endtask 

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    reset = 1;
    #100;
    reset = 0;
    #100;
 
    test_basic();
    #200;
    test_back_to_back();
    #200;
    test_reset_mid_frame();
    #200;
    test_glitch();
    $display("=== ALL DIRECTED TESTS DONE ===");
    #1000 $finish;
  end
 
endmodule
 
interface uart_pin_if(input logic clk, input logic reset);
  logic Rx_pin = 1'b1;
  logic Tx_pin;
endinterface
