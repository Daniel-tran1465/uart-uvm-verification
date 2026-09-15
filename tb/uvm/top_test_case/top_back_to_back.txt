interface uart_if(
input logic clk
);

  logic reset;
logic Rx_pin = 1'b1;
logic Tx_pin;

endinterface

package my_uart_top_pkg;
import uvm_pkg::*;
`include "uvm_macros.svh"

class my_uart_top_items extends uvm_sequence_item;
  `uvm_object_utils(my_uart_top_items)
  

  rand bit [7:0] data; // driver dùng — byte gửi vào Rx_pin
  bit [7:0] echoed_data;      // monitor dùng — byte đọc được từ Tx_pin, KHÔNG rand
  
  function new(string name = "");
    super.new(name);
  endfunction
endclass

class uart_scoreboard extends uvm_subscriber #(my_uart_top_items);
  `uvm_component_utils(uart_scoreboard)                    // THÊM
  bit [7:0] sent_set[$];
  int echoed_cnt, dropped_estimate;

  function new(string name, uvm_component parent);          // THÊM
    super.new(name, parent);
  endfunction

  function void push_expected(bit [7:0] d);
    sent_set.push_back(d);
  endfunction

  function void write(my_uart_top_items t);
    bit found = 0;
    foreach (sent_set[i]) if (sent_set[i] == t.data) begin found = 1; break; end
    if (found) begin
      `uvm_info(get_type_name(), $sformatf("Echoed 0x%0h — hop le, nam trong tap da gui", t.data), UVM_LOW)
      echoed_cnt++;
    end else begin
      `uvm_warning(get_type_name(), $sformatf("Echoed 0x%0h — KHONG khop bat ky gia tri da gui nao (torn data nghi ngo)", t.data))  // ĐỔI uvm_error -> uvm_warning
      dropped_estimate++;
    end
  endfunction
endclass

`uvm_analysis_imp_decl(_overlap)                              // THÊM lại
class uart_coverage extends uvm_component;                    // ĐỔI base class, không cần uvm_subscriber(my_uart_top_items) nữa
  `uvm_component_utils(uart_coverage)

  uvm_analysis_imp_overlap #(bit, uart_coverage) overlap_imp;  // THÊM lại
  bit new_byte_during_tx_busy;

  covergroup cg;
    cp_echo_busy_overlap: coverpoint new_byte_during_tx_busy { bins hit = {1}; bins miss = {0}; }
  endgroup

  function new(string name = "uart_coverage", uvm_component parent);
    super.new(name, parent);
    cg = new();
  endfunction

  function void build_phase(uvm_phase phase);                 // THÊM lại
    super.build_phase(phase);
    overlap_imp = new("overlap_imp", this);
  endfunction

  virtual function void write_overlap(bit v);                 // ĐỔI đúng tên hàm TLM, đúng chữ ký
    new_byte_during_tx_busy = v;
    cg.sample();
  endfunction
endclass


class top_sequence extends uvm_sequence#(my_uart_top_items);
  `uvm_object_utils(top_sequence)
  
  function new(string name = "");
    super.new(name);
  endfunction
  
  task body;
    my_uart_top_items tr;
    if(starting_phase != null)
      starting_phase.raise_objection(this);
    repeat(200)
    begin
      tr = my_uart_top_items::type_id::create("tr");
      start_item(tr);
      
      if(!tr.randomize())
        `uvm_error("", "Randomize for UART failed")
        finish_item(tr);
    end
    
    if(starting_phase != null)
      starting_phase.drop_objection(this);
  endtask
endclass

class top_driver extends uvm_driver#(my_uart_top_items);
  `uvm_component_utils(top_driver)
  
    virtual uart_if uart_vi;
  int bit_period = 434;
  uart_scoreboard scb;
  uvm_analysis_port #(bit) overlap_port; 
  
  time last_frame_sent_time = 0;                              // THÊM lại
  localparam int ROUND_TRIP = 10 * 434;                        // THÊM lại
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual uart_if)::get(this, "", "vif_uart", uart_vi))
      `uvm_error("", "uvm_config_db::get failed")
    if(!uvm_config_db#(uart_scoreboard)::get(this, "", "scb", scb))   // THÊM
      `uvm_error("", "scoreboard handle not found")
      overlap_port = new("overlap_port", this);
      endfunction
   task run_phase(uvm_phase phase);
    	my_uart_top_items tr;
    	forever
          	begin
              seq_item_port.get_next_item(tr);
              scb.push_expected(tr.data); 
              
              if (last_frame_sent_time != 0 && ($time - last_frame_sent_time) < ROUND_TRIP)  // THÊM lại
        overlap_port.write(1'b1);
      else
        overlap_port.write(1'b0);
              
                        uart_vi.Rx_pin = 1'b0; 							repeat(bit_period)@(posedge uart_vi.clk);

					for(int i = 0; i<8; i++) begin
                      uart_vi.Rx_pin = tr.data[i]; 							repeat(bit_period)@(posedge uart_vi.clk);
   						 end
              uart_vi.Rx_pin = 1'b1; 								repeat(bit_period)@(posedge uart_vi.clk);
              
              
              last_frame_sent_time = $time;
              seq_item_port.item_done();
            end
    

    endtask   

    endclass
    
    class top_monitor extends uvm_monitor;
      `uvm_component_utils(top_monitor)
      
      function new(string name, uvm_component parent);
        super.new(name, parent);
      endfunction
      
      virtual uart_if uart_vi;
      
      uvm_analysis_port#(my_uart_top_items) mon_analysis_port;
      
      virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
  		mon_analysis_port = new("mon_analysis_port", this);
        if(!uvm_config_db#(virtual uart_if)::get(this,"", "vif_uart", uart_vi)) begin
            `uvm_error(get_type_name(), "Didn't get handle to virtual interface uart_if")
          end
        endfunction
      
      virtual task run_phase(uvm_phase phase);
          my_uart_top_items tr;
          int bit_period = 434;
	  bit [7:0] captured;

          forever begin
            @(posedge uart_vi.clk);
             @(negedge uart_vi.Tx_pin);
            repeat(bit_period/2)@(posedge uart_vi.clk);
            	for (int i = 0; i < 8; i++) begin
      				repeat(bit_period) @(posedge uart_vi.clk);
                  captured[i] = uart_vi.Tx_pin;
    			end
			repeat(bit_period) @(posedge uart_vi.clk);
            	tr = my_uart_top_items::type_id::create("tr");
            	tr.data = captured;
              mon_analysis_port.write(tr);
            end     

        endtask
      endclass

  class uart_agent extends uvm_agent;
        `uvm_component_utils(uart_agent)
    uvm_sequencer#(my_uart_top_items) sqr;
              top_driver drv;
              top_monitor mon;
              
              function new(string name, uvm_component parent);
                super.new(name, parent);
              endfunction
              
              function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                
                if(get_is_active())begin
                  sqr = uvm_sequencer#( my_uart_top_items)::type_id::create("sqr", this);
                  drv = top_driver::type_id::create("drv", this);
                end
                
                mon = top_monitor::type_id::create("mon", this);   
                  
              endfunction
              
              function void connect_phase(uvm_phase phase);
                super.connect_phase(phase);
                
                if(get_is_active())
                  drv.seq_item_port.connect(sqr.seq_item_export);
              endfunction
            endclass

      class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)
  
  uart_agent agt;
  uart_scoreboard scb;
  uart_coverage cov;
  
        function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    agt = uart_agent::type_id::create("agt", this);
    scb = uart_scoreboard::type_id::create("scb", this);
    cov = uart_coverage::type_id::create("cov", this);
    
    uvm_config_db#(uart_scoreboard)::set(this, "agt.drv", "scb", scb); //truyen handle xuong driver
    
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agt.mon.mon_analysis_port.connect(scb.analysis_export);
    agt.drv.overlap_port.connect(cov.overlap_imp);
  endfunction
  
endclass
      
      class uart_test extends uvm_test;
  `uvm_component_utils(uart_test)
  uart_env env;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uart_env::type_id::create("env", this);
  endfunction
  
  task run_phase(uvm_phase phase);
    
    top_sequence seq;
    phase.raise_objection(this);
    seq = top_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);
    phase.drop_objection(this);
    
  endtask

    virtual function void report_phase(uvm_phase phase);
    real coverage_percentage;
    super.report_phase(phase);
    
    // Hàm hệ thống của VCS tự động tính toán tổng số % coverage thu thập được
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

module tb_top;
  logic clk = 0;
  always#10 clk = ~clk;
  
  uart_if vif(clk);
  
  UART#(
    .data_width(8),
    .sysclkfreq(50000000),
    .baudrate(115200)
  )top_dut(
	.clk(clk),
    .reset(vif.reset),
    .Rx_pin(vif.Rx_pin),
    .Tx_pin(vif.Tx_pin)
);
  initial begin
        vif.reset = 1'b1;
    #100 vif.reset = 1'b0;
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top); // Tham số thứ 2 là tên module top của bạn
  end
  
  initial begin
    uvm_config_db#(virtual uart_if)::set(null, "*", "vif_uart", vif);
    run_test("uart_test");
    $dumpfile("dump.vcd"); 
    $dumpvars;
  end
  
endmodule
