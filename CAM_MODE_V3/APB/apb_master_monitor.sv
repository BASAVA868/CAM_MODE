//Define a apb master monitor class from uvm monitor
class apb_master_monitor extends uvm_monitor;

  //register the class with uvm factory
  `uvm_component_utils(apb_master_monitor)

  //declare a virtual interface instance 
  virtual apb_if vif;

  //analysis port : parameterized to apb_base_sequence item transaction
  uvm_analysis_port#(apb_base_seq_item) ap;  
  apb_base_seq_item tr;

  //file descriptor for logging
  integer log_file;

  //constructor
  function new(string name, uvm_component parent);
    //call the base class constructor
    super.new(name, parent);
    ap = new("ap", this);
  endfunction: new

  //build phase - get handle to virtual interface 
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif_apb", vif)) begin
      `uvm_fatal(get_full_name(), "No virtual interface specified for apb_master_driver")
    end
  endfunction

  //connect phase - get the shared log file handle from the configuration database
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (!uvm_config_db#(integer)::get(this, "", "shared_log_file", log_file))
      `uvm_fatal("LOG", "Failed to get shared log file handle")
  endfunction

  // Task: run_phase
  task run_phase(uvm_phase phase);
    //forever loop to monitor signals and send transactions    
    forever begin
      wait (vif.PSEL === 1'b1);

      tr = apb_base_seq_item::type_id::create("tr", this);
      tr.apb_tr = (this.vif.PWRITE) ? apb_base_seq_item::WRITE : apb_base_seq_item::READ;
      tr.addr = this.vif.PADDR;

      @ (posedge vif.PCLK);
      wait (this.vif.PENABLE === 1'b1 && this.vif.PREADY === 1'b1);

     // if (this.vif.PWRITE)   
        tr.wdata = this.vif.PWDATA; 
     // else 
        tr.rdata = this.vif.PRDATA;

      $display("value of prdata =%h",vif.PRDATA);
      wait (this.vif.PENABLE === 1'b0)
      uvm_report_info("APB_MASTER_MONITOR", $sformatf("%s", tr.apb_master()));     
      ap.write(tr); //Write to analysis port
      tr.print();

      // Log the transaction to the file
      $fwrite(log_file, "Transaction: %s\n", tr.apb_master());
    end
  endtask

  // Destructor to close the log file
  function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    // No need to close the log file here; it is managed in the testbench
  endfunction

endclass // end of the class

