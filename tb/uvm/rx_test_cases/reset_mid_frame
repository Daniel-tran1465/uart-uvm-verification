 interface uart_rx_if(input logic clk);
      logic reset;
      logic Rx_Din;
      logic IRQ_Clear;
      logic [7:0] Rx_Dout;
      logic Rx_IRQ;
      
      clocking drv_cb@(posedge clk);
        output Rx_Din, IRQ_Clear;
        input Rx_Dout, Rx_IRQ;
      endclocking
   modport DRV(clocking drv_cb, input clk, output reset);
        modport MON(input clk,reset, Rx_Din, Rx_Dout, IRQ_Clear, Rx_IRQ);
        endinterface
////////////////////////////////////////////////////////////////////////////////
 package my_uart_rx_pkg;
 import uvm_pkg::*;
  `include "uvm_macros.svh"
class uart_seq_item extends uvm_sequence_item;
  
  `uvm_object_utils(uart_seq_item)
  
  rand bit [7:0] data;
  rand bit inject_glitch;
  rand bit [3:0] reset_at_bit; 
 
  function new(string name = "uart_seq_item");
    super.new(name);
  endfunction
  
endclass



              class uart_scoreboard extends uvm_subscriber#(uart_seq_item);
  `uvm_component_utils(uart_scoreboard)
  int pass_cnt, fail_cnt;
  
  bit [7:0] expected_queue[$];
  
  uvm_analysis_port #(bit) status_port;
                
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
    function void build_phase(uvm_phase phase);      // THÊM cả hàm này nếu chưa có
    super.build_phase(phase);
    status_port = new("status_port", this);
  endfunction
  
  function void push_expected(bit [7:0] d);
    expected_queue.push_back(d);
  endfunction
  
  function void write(uart_seq_item t);
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
      status_port.write(1'b1);
    end
    else begin
      `uvm_error(get_type_name(), $sformatf("data=0x%0h mismatch, expected data=0x%0h", t.data, expected))
      fail_cnt++;
      status_port.write(1'b0);
    end
  endfunction
endclass
        
     `uvm_analysis_imp_decl(_pos)
     `uvm_analysis_imp_decl(_status)
        class uart_coverage extends uvm_component;
  `uvm_component_utils(uart_coverage)
  
          uvm_analysis_imp_pos #(bit[3:0], uart_coverage) pos_imp;
          uvm_analysis_imp_status #(bit,      uart_coverage) status_imp;
  uart_seq_item trans;
	int reset_bit_position;   // reset xảy ra ở bit thứ mấy (0=start, 1-8=data, 9=stop)
	bit recovered_correctly;  // byte sạch gửi SAU reset có đúng không

          
covergroup cg_reset_mid_frame;
  cp_reset_position: coverpoint reset_bit_position {
    bins early = {0,1,2};
    bins mid   = {3,4,5,6};
    bins late  = {7,8,9};
  }
  cp_recovery: coverpoint recovered_correctly { bins pass = {1}; bins fail = {0}; }
endgroup
  
  function new(string name = "uart_coverage", uvm_component parent);
    super.new(name, parent);
    cg_reset_mid_frame = new();
  endfunction
  
  virtual function void write_pos(bit[3:0] pos);
  reset_bit_position = pos;   // chỉ LƯU giá trị, CHƯA sample vội
endfunction
          
  function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  pos_imp = new("pos_imp", this);
  status_imp = new("status_imp", this);
endfunction
          
 virtual function void write_status(bit is_pass);
  recovered_correctly = is_pass;
  cg_reset_mid_frame.sample();          
 endfunction
  
endclass
        
        class rx_sequence extends uvm_sequence #(uart_seq_item);
          `uvm_object_utils(rx_sequence)
          
          bit [3:0] positions[$] = '{1, 4, 8};
          
          function new(string name = "rx_sequence");
            super.new(name);
          endfunction
          
          task body;
            uart_seq_item tr;
            if(starting_phase != null)
      starting_phase.raise_objection(this);
            repeat(20)
              foreach (positions[i]) begin
        tr = uart_seq_item::type_id::create("tr");
        start_item(tr); 
        tr.reset_at_bit.rand_mode(0);
        tr.reset_at_bit = positions[i]; 
        if(!tr.randomize() )
          `uvm_error("", "Randomize for UART_RX failed")
          finish_item(tr);
      end
    
    if(starting_phase != null)
      starting_phase.drop_objection(this);
  endtask
endclass
      
        class rx_driver extends uvm_driver #(uart_seq_item);
          `uvm_component_utils(rx_driver)
    
          uvm_analysis_port #(bit [3:0]) pos_port;
          
    virtual uart_rx_if.DRV rx_vi;
          int bit_period = 434;
          int count_bit;
	  uart_scoreboard scb; //Handle tới scoreboard
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!
        uvm_config_db # (virtual uart_rx_if.DRV)::get(this, "", "vif_rx", rx_vi)
      )
        `uvm_error("", "uvm_config_db::get failed")
	if(!uvm_config_db#(uart_scoreboard)::get(this, "", "scb", scb))   // THÊM
      `uvm_error("", "scoreboard handle not found")
      pos_port = new("pos_port", this);
        endfunction
        
  task run_phase(uvm_phase phase);
      uart_seq_item tr;
      bit reset_occurred;
      forever
        begin
          seq_item_port.get_next_item(tr);
          scb.push_expected(tr.data); //Báo trước cho scoreboard ngay khi vừa nhận transaction

          rx_vi.drv_cb.Rx_Din <= 1'b0; repeat(bit_period)@(posedge rx_vi.clk);

	for(int i = 0; i<8; i++) begin
      rx_vi.drv_cb.Rx_Din <= tr.data[i]; repeat(bit_period)@(posedge rx_vi.clk);
      count_bit++;
      
      if(count_bit == tr.reset_at_bit) begin
        pos_port.write(tr.reset_at_bit);
        rx_vi.reset = 1'b1;
        rx_vi.drv_cb.Rx_Din <= 1'b1;
        repeat(50)@(posedge rx_vi.clk);
        rx_vi.reset = 1'b0;
        repeat(bit_period*5) @(posedge rx_vi.clk);
        reset_occurred = 1;
        break;
      end
      
    end
    	count_bit = 0;
          
          if (reset_occurred) begin
  // Gửi lại TRỌN VẸN 1 frame mới, sạch — không dựa vào phần dở dang trước đó
 			 	 rx_vi.drv_cb.Rx_Din <= 1'b0; repeat(bit_period) @(posedge rx_vi.clk);
  			for (int i = 0; i < 8; i++) begin
    			rx_vi.drv_cb.Rx_Din <= tr.data[i]; repeat(bit_period) @(posedge rx_vi.clk);
  				end
		end
          
         rx_vi.drv_cb.Rx_Din <= 1'b1; repeat(bit_period)@(posedge rx_vi.clk);
         
          wait(rx_vi.drv_cb.Rx_IRQ == 1);
          	@(posedge rx_vi.clk);
          	rx_vi.drv_cb.IRQ_Clear <= 1'b1;
          	@(posedge rx_vi.clk);
          	rx_vi.drv_cb.IRQ_Clear <= 1'b0;
            seq_item_port.item_done();
       
          
        end
    endtask
    
  endclass
      
      class rx_monitor extends uvm_monitor;
        `uvm_component_utils(rx_monitor)
        
        function new(string name, uvm_component parent);
          super.new(name, parent);
        endfunction
        
        virtual uart_rx_if.MON rx_vi;
        
        uvm_analysis_port#(uart_seq_item) mon_analysis_port;
        
        virtual function void build_phase(uvm_phase phase);
          super.build_phase(phase);
          
          mon_analysis_port = new("mon_analysis_port", this);
          
          if(!uvm_config_db#(virtual uart_rx_if.MON)::get(this,"", "vif_rx", rx_vi)) begin
            `uvm_error(get_type_name(), "Didn't get handle to virtual interface uart_rx_if")
          end
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
                
                if(get_is_active())begin
                  sqr = uvm_sequencer#(uart_seq_item)::type_id::create("sqr", this);
                  drv = rx_driver::type_id::create("drv", this);
                end
                
                mon = rx_monitor::type_id::create("mon", this);   
                  
              endfunction
              
              function void connect_phase(uvm_phase phase);
                super.connect_phase(phase);
                
                if(get_is_active())
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
    
    uvm_config_db#(uart_scoreboard)::set(this, "agt.drv", "scb", scb); //truyen handle xuong driver
    
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agt.mon.mon_analysis_port.connect(scb.analysis_export);
    
    agt.drv.pos_port.connect(cov.pos_imp);
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

module tb_rx_top;
  logic clk = 0;

  always#10 clk = ~clk;
  
  uart_rx_if vif(clk);
  
  UART_RX#(
    .rx_data_width(8),
    .sys_clk_freq(50000000),
    .rx_baudrate(115200)
  )rx_dut(
	.clk(clk),
    .reset(vif.reset),
    .Rx_Din(vif.Rx_Din),
    .IRQ_Clear(vif.IRQ_Clear),
    .Rx_Dout(vif.Rx_Dout),
    .Rx_IRQ(vif.Rx_IRQ)
);
  initial begin
        vif.reset = 1'b1;
    #100 vif.reset = 1'b0;
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_rx_top); // Tham số thứ 2 là tên module top của bạn
  end
  
  initial begin
    uvm_config_db#(virtual uart_rx_if.DRV)::set(null, "*", "vif_rx", vif);
    uvm_config_db#(virtual uart_rx_if.MON)::set(null, "*", "vif_rx", vif);
    run_test("uart_rx_test");
    $dumpfile("dump.vcd"); 
    $dumpvars;
  end
  
endmodule
