///////////////////////////////////////////////////////////////////////////////////////
//
//file name  : pcie_agent.sv
//version    : 0.2
//description: It contains the driver monitor and sequencer of pcie agent. 
//
///////////////////////////////////////////////////////////////////////////////////////

typedef uvm_sequencer#(cam_config_tlp_transaction) cam_config_tlp_sequencer;
class cam_config_tlp_agent extends uvm_agent;
  `uvm_component_utils(cam_config_tlp_agent)

  cam_config_tlp_driver    driver;
  cam_config_tlp_sequencer sequencer;
  cam_config_tlp_monitor   monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    driver    = cam_config_tlp_driver::type_id::create("driver", this);
    sequencer = cam_config_tlp_sequencer::type_id::create("sequencer", this);
    monitor   = cam_config_tlp_monitor::type_id::create("monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

