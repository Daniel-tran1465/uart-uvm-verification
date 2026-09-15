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

class uart_scoreboard extends uvm_subscriber#(my_uart_top_items);
  `uvm_component_utils(uart_scoreboard)
  int pass_cnt, fail_cnt;
  
  bit [7:0] expected_queue[$];
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void push_expected(bit [7:0] d);
    expected_queue.push_back(d);
  endfunction
  
  function void write(my_uart_top_items t);
    bit [7:0] expected;
    
    if(expected_queue.size() == 0)begin
      `uvm_error(get_type_name(), $sformatf("Received data=0x%0h but no expected value was pushed", t.data))
       fail_cnt++;
       return;
    end
                                                        
    expected = expected_queue.pop_front();                                     
    
    if(t.data == expected)begin
      `uvm_info(get_type_name(), $sformatf("data=0x%0h match with the expected data", t.data), UVM_LOW)
      pass_cnt++;
    end
    else begin
      `uvm_error(get_type_name(), $sformatf("data=0x%0h mismatch, expected data=0x%0h", t.data, expected))
      fail_cnt++;
    end
  endfunction
endclass
        
        class uart_coverage extends uvm_subscriber #(my_uart_top_items);
  `uvm_component_utils(uart_coverage)
  
  my_uart_top_items trans;

  covergroup cg;
    cp_data: coverpoint trans.data {
      bins zero      = {8'h00};
      bins all_ones  = {8'hFF};
      bins alt1      = {8'h55};
      bins alt2      = {8'hAA};
      bins others[8] = {[8'h01:8'hFE]};
    }
  endgroup
  
  function new(string name = "uart_coverage", uvm_component parent);
    super.new(name, parent);
    cg = new();
  endfunction
  
  virtual function void write(my_uart_top_items t);
    trans = t;
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
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual uart_if)::get(this, "", "vif_uart", uart_vi))
      `uvm_error("", "uvm_config_db::get failed")
    if(!uvm_config_db#(uart_scoreboard)::get(this, "", "scb", scb))   // THÊM
      `uvm_error("", "scoreboard handle not found")
      endfunction
   task run_phase(uvm_phase phase);
    	my_uart_top_items tr;
    	forever
          	begin
              seq_item_port.get_next_item(tr);
              scb.push_expected(tr.data); 
              
                        uart_vi.Rx_pin = 1'b0; 							repeat(bit_period)@(posedge uart_vi.clk);

					for(int i = 0; i<8; i++) begin
                      uart_vi.Rx_pin = tr.data[i]; 							repeat(bit_period)@(posedge uart_vi.clk);
   						 end
              uart_vi.Rx_pin = 1'b1; 								repeat(bit_period)@(posedge uart_vi.clk);
              
              repeat(bit_period*11) @(posedge uart_vi.clk);
              
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
    agt.mon.mon_analysis_port.connect(cov.analysis_export);
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
