interface uart_rx_if(input logic clk, input logic reset);
  logic Rx_Din;
  logic IRQ_Clear;
  logic [7:0] Rx_Dout;
  logic Rx_IRQ;
  
  clocking drv_cb @(posedge clk);
    output Rx_Din, IRQ_Clear;
    input Rx_Dout, Rx_IRQ;
  endclocking

  modport DRV(clocking drv_cb, input clk, reset);
  modport MON(input clk, reset, Rx_Din, Rx_Dout, IRQ_Clear, Rx_IRQ);
endinterface

////////////////////////////////////////////////////////////////////////////////
package my_uart_rx_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class uart_seq_item extends uvm_sequence_item;
    `uvm_object_utils(uart_seq_item)
    
    rand bit [7:0] data;
    rand bit       inject_glitch; // 1: Chèn glitch trước frame, 0: Gửi bình thường

    function new(string name = "uart_seq_item");
      super.new(name);
    endfunction
  endclass

    `uvm_analysis_imp_decl(_exp)
    
  class uart_scoreboard extends uvm_subscriber#(uart_seq_item);
    `uvm_component_utils(uart_scoreboard)
    
    int pass_cnt, fail_cnt;
    bit [7:0] expected_queue[$];
    
    // Imp port để Driver đẩy data kỳ vọng vào queue
  uvm_analysis_imp_exp #(uart_seq_item, uart_scoreboard) exp_imp;
    
    // Port gửi trạng thái sang coverage: 1 = False Trigger, 0 = Match/Recover OK
    uvm_analysis_port #(bit) status_port;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      exp_imp     = new("exp_imp", this);
      status_port = new("status_port", this);
    endfunction

    
    // Tên hàm PHẢI LÀ write_exp (khớp với suffix _exp ở trên)
  virtual function void write_exp(uart_seq_item t);
    expected_queue.push_back(t.data);
  endfunction

    virtual function void write(uart_seq_item t);
      bit [7:0] expected;
      
      // Trường hợp 1: Nhận IRQ nhưng không có data mong đợi -> False Trigger do Glitch
      if (expected_queue.size() == 0) begin
        `uvm_warning(get_type_name(), $sformatf("FALSE TRIGGER DETECTED! Data=0x%0h", t.data))
        fail_cnt++;
        status_port.write(1'b1); // Gửi cờ False Trigger = 1
        return;
      end
                                                          
      // Trường hợp 2: Khớp data chuẩn -> Recovered / Valid Data
      expected = expected_queue.pop_front();                                     
      if (t.data == expected) begin
        `uvm_info(get_type_name(), $sformatf("Data 0x%0h matched successfully", t.data), UVM_LOW)
        pass_cnt++;
        status_port.write(1'b0); // Gửi cờ Recover OK = 0
      end else begin
        `uvm_error(get_type_name(), $sformatf("Data mismatch: Got 0x%0h, Expected 0x%0h", t.data, expected))
        fail_cnt++;
        status_port.write(1'b0);
      
      end
    endfunction
  endclass

  `uvm_analysis_imp_decl(_status)

  class uart_coverage extends uvm_subscriber #(uart_seq_item);
    `uvm_component_utils(uart_coverage)
    
    uvm_analysis_imp_status #(bit, uart_coverage) status_imp;                      
    
    bit false_trigger_occurred;
    bit recovered_correctly;

    covergroup cg;
      cp_false_trigger: coverpoint false_trigger_occurred { 
        bins hit  = {1}; 
        bins miss = {0}; 
      }
      cp_recovery: coverpoint recovered_correctly { 
        bins pass = {1}; 
        bins fail = {0}; 
      }
    endgroup

    function new(string name = "uart_coverage", uvm_component parent);
      super.new(name, parent);
      cg = new();
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      status_imp = new("status_imp", this);
    endfunction
                            
    virtual function void write(uart_seq_item t);
      // Dùng cho covergroup kiểm tra giá trị data nếu muốn
    endfunction
                            
    virtual function void write_status(bit is_false_trigger);
      if (is_false_trigger) begin
        false_trigger_occurred = 1'b1;
      end else begin
        recovered_correctly = 1'b1;
      end
      
      cg.sample();
    endfunction                        
  endclass

  class rx_driver extends uvm_driver #(uart_seq_item);
    `uvm_component_utils(rx_driver)

    virtual uart_rx_if.DRV rx_vi;
    int bit_period = 434;

    // Port để chuyển data mong đợi sang Scoreboard một cách độc lập
    uvm_analysis_port #(uart_seq_item) drv_exp_port;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      drv_exp_port = new("drv_exp_port", this);
      if (!uvm_config_db#(virtual uart_rx_if.DRV)::get(this, "", "vif_rx", rx_vi))
        `uvm_error("DRV", "uvm_config_db::get failed for vif_rx")
    endfunction

    // Task hỗ trợ gửi 1 frame UART đầy đủ
    task send_frame(bit [7:0] data);
      // Start bit (0)
      rx_vi.drv_cb.Rx_Din <= 1'b0; 
      repeat(bit_period) @(posedge rx_vi.clk);

      // 8 Data bits
      for (int i = 0; i < 8; i++) begin
        rx_vi.drv_cb.Rx_Din <= data[i]; 
        repeat(bit_period) @(posedge rx_vi.clk);
      end

      // Stop bit (1)
      rx_vi.drv_cb.Rx_Din <= 1'b1; 
      repeat(bit_period * 2) @(posedge rx_vi.clk);

      // Đợi IRQ và Clear IRQ
      wait(rx_vi.drv_cb.Rx_IRQ == 1'b1);
      @(posedge rx_vi.clk);
      rx_vi.drv_cb.IRQ_Clear <= 1'b1;
      @(posedge rx_vi.clk);
      rx_vi.drv_cb.IRQ_Clear <= 1'b0;
    endtask

    virtual task run_phase(uvm_phase phase);
      uart_seq_item tr;
      rx_vi.drv_cb.Rx_Din <= 1'b1; // Default Idle state
      
      forever begin
        seq_item_port.get_next_item(tr);

        // 1. Nếu transaction yêu cầu chèn Glitch trước khi truyền
        if (tr.inject_glitch) begin
          rx_vi.drv_cb.Rx_Din <= 1'b0; // Kéo Glitch xuống 0 trong 1 clock
          @(posedge rx_vi.clk);
          rx_vi.drv_cb.Rx_Din <= 1'b1;
          
          // Chờ cho bất kỳ FSM giả nào chạy xong (nếu DUT dính nhiễu)
          repeat(bit_period * 11) @(posedge rx_vi.clk);
          
          if (rx_vi.drv_cb.Rx_IRQ == 1'b1) begin
    		@(posedge rx_vi.clk);
   		 rx_vi.drv_cb.IRQ_Clear <= 1'b1;
    		@(posedge rx_vi.clk);
    	 rx_vi.drv_cb.IRQ_Clear <= 1'b0;
  			end
        end

        // 2. Gửi Data thật và push kỳ vọng sang Scoreboard
        drv_exp_port.write(tr);
        send_frame(tr.data);

        repeat(5) @(posedge rx_vi.clk);
        seq_item_port.item_done();
      end
    endtask
  endclass

  class rx_monitor extends uvm_monitor;
    `uvm_component_utils(rx_monitor)

    virtual uart_rx_if.MON rx_vi;
    uvm_analysis_port#(uart_seq_item) mon_analysis_port;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      mon_analysis_port = new("mon_analysis_port", this);
      if (!uvm_config_db#(virtual uart_rx_if.MON)::get(this, "", "vif_rx", rx_vi))
        `uvm_error(get_type_name(), "Didn't get handle to virtual interface")
    endfunction

    virtual task run_phase(uvm_phase phase);
      uart_seq_item tr;
      forever begin
        @(posedge rx_vi.Rx_IRQ); 
        tr = uart_seq_item::type_id::create("tr");
        tr.data = rx_vi.Rx_Dout;
        mon_analysis_port.write(tr);    
      end
    endtask
  endclass

  class rx_sequence extends uvm_sequence #(uart_seq_item);
    `uvm_object_utils(rx_sequence)

    function new(string name = "rx_sequence");
      super.new(name);
    endfunction

    task body;
      uart_seq_item tr;
      if (starting_phase != null) starting_phase.raise_objection(this);

      // Gửi 10 frame có chèn Glitch để test khả năng chống nhiễu & phục hồi
      repeat(10) begin
        tr = uart_seq_item::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with { inject_glitch == 1'b1; })
          `uvm_error("SEQ", "Randomize failed")
        finish_item(tr);
      end

      if (starting_phase != null) starting_phase.drop_objection(this);
    endtask
  endclass

  class uart_rx_agent extends uvm_agent;
    `uvm_component_utils(uart_rx_agent)
    
    uvm_sequencer#(uart_seq_item) sqr;
    rx_driver drv;
    rx_monitor mon;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (get_is_active()) begin
        sqr = uvm_sequencer#(uart_seq_item)::type_id::create("sqr", this);
        drv = rx_driver::type_id::create("drv", this);
      end
      mon = rx_monitor::type_id::create("mon", this);   
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (get_is_active())
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  class uart_rx_env extends uvm_env;
    `uvm_component_utils(uart_rx_env)

    uart_rx_agent agt;
    uart_scoreboard scb;
    uart_coverage cov;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agt = uart_rx_agent::type_id::create("agt", this);
      scb = uart_scoreboard::type_id::create("scb", this);
      cov = uart_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      // Kết nối Monitor -> Scoreboard & Coverage
      agt.mon.mon_analysis_port.connect(scb.analysis_export);
      agt.mon.mon_analysis_port.connect(cov.analysis_export);

      // Kết nối Driver (kỳ vọng) -> Scoreboard
      agt.drv.drv_exp_port.connect(scb.exp_imp); // Dùng custom write function/imp

      // Kết nối Scoreboard (trạng thái) -> Coverage
      scb.status_port.connect(cov.status_imp);
    endfunction
  endclass

  class uart_rx_test extends uvm_test;
    `uvm_component_utils(uart_rx_test)
    uart_rx_env env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = uart_rx_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      rx_sequence seq;
      phase.raise_objection(this);
      seq = rx_sequence::type_id::create("seq");
      seq.start(env.agt.sqr);
      phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
      real coverage_percentage;
      super.report_phase(phase);
      coverage_percentage = $get_coverage();
      
      $display("\n==========================================================");
      $display("       BÁO CÁO TỶ LỆ COVERAGE CHÍNH XÁC TỪ TESTBENCH       ");
      $display("==========================================================");
      $display("Tổng số điểm đạt được (Tổng hợp): %0.2f %%", coverage_percentage);
      $display("==========================================================\n");
    endfunction  
  endclass

endpackage
////////////////////////////////////////////////////////////////////////////////////////

module tb_rx_top;
  logic clk = 0;
  logic reset;
  always#10 clk = ~clk;
  
  uart_rx_if vif(clk,reset);
  
  UART_RX#(
    .rx_data_width(8),
    .sys_clk_freq(50000000),
    .rx_baudrate(115200)
  )rx_dut(
	.clk(clk),
	.reset(reset),
    .Rx_Din(vif.Rx_Din),
    .IRQ_Clear(vif.IRQ_Clear),
    .Rx_Dout(vif.Rx_Dout),
    .Rx_IRQ(vif.Rx_IRQ)
);
  initial begin
        reset = 1'b1;
    #100 reset = 1'b0;
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_rx_top); // Tham số thứ 2 là tên module top của bạn
  end
  
  initial begin
    uvm_config_db#(virtual uart_rx_if.DRV)::set(null, "*", "vif_rx", vif);
    uvm_config_db#(virtual uart_rx_if.MON)::set(null, "*", "vif_rx", vif);
    run_test("uart_rx_test");
  end
  
endmodule
