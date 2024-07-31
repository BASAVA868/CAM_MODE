
//define uvm driver class named apb_maser_driver

class apb_master_driver extends uvm_driver#(apb_base_seq_item);

  //register the class with uvm factory
	`uvm_component_utils(apb_master_driver)
	
  //declare a virtual interface instance 
	virtual apb_if 			vif;
  //handle for base sequence
	apb_base_seq_item 	m_apb_base_seq_item;
	
  //constructor
  function new(string name = "apb_master_driver", uvm_component parent = null);
    //call the base class constructor
	  super.new(name, parent);
  endfunction: new	
	
  //build phase : set up the virtual interface connection
  function void build_phase(uvm_phase phase);
  //call the base class build phase
  	super.build_phase(phase);
	  if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif_apb", vif)) begin
		  `uvm_fatal(get_full_name(), "No virtual interface specified for apb_master_driver")
  	end 	
  endfunction
	
  //run_phase
  task run_phase(uvm_phase phase);
	  super.run_phase(phase);			
	  	vif.PSEL    	<= 1'b0; //init_signals();
	    vif.PENABLE  <= 1'b0;
	    master_get_drive();	
  endtask
	
// Task: master_get_drive
// Definition: this task select the transfer type
task master_get_drive();
	
  //forever loop to handle incoming sequence items
	forever begin
		m_apb_base_seq_item = apb_base_seq_item::type_id::create("m_apb_base_seq_item",this);
	  //get the next transaction item from sequence	
		seq_item_port.get_next_item(m_apb_base_seq_item);
    while (!vif.PRESET_N) @(posedge vif.PCLK);
		
	        //wait(!vif.PRESET_N);        //wait signal
		repeat(m_apb_base_seq_item.delay)
			@(negedge vif.PCLK);
		
		vif.PSEL    <= 1'b1;
		vif.PADDR   <= m_apb_base_seq_item.addr;
		vif.PWRITE  <= m_apb_base_seq_item.apb_tr;
		
		if(m_apb_base_seq_item.apb_tr == 1) //apb_master_seq_item::WRITE)
			vif.PWDATA  <= m_apb_base_seq_item.wdata;
      else
			  vif.PRDATA  <= m_apb_base_seq_item.rdata;
		
		@ (negedge vif.PCLK);
		vif.PENABLE <= '1;
		
		wait(vif.PREADY);	
		
		@ (negedge vif.PCLK);
		vif.PSEL    <= '0;
		vif.PENABLE <= '0;		
		//vif.PWRITE <= '0;		
		
    //handshake done back to the sequencer
		seq_item_port.item_done();
    uvm_report_info("APB_MASTER_DRIVER ", $sformatf(" %s",m_apb_base_seq_item.apb_master()));
	  m_apb_base_seq_item.print();
	end		
		
endtask

endclass // end of the class
