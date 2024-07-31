///////////////////////////////////////////////////////////////////////////////////////
//
//file name  : pcie_pkt.sv
//version    : 0.2
//description: contains the fileds of config and completion packets.
//             and some necessary constraints. 
//
///////////////////////////////////////////////////////////////////////////////////////






class cam_config_tlp_transaction extends uvm_sequence_item;
  rand bit [127:0] cfg_tlp;
  bit              cfg_tlp_valid;
  rand bit         cfg_tlp_ready;
  
  rand bit [127:0] cmpl_tlp;
  rand bit         cmpl_valid;
  bit              cmpl_ready;

  `uvm_object_utils_begin(cam_config_tlp_transaction)
    `uvm_field_int(cfg_tlp, UVM_ALL_ON)
    `uvm_field_int(cfg_tlp_valid, UVM_ALL_ON)
    `uvm_field_int(cfg_tlp_ready, UVM_ALL_ON)
    `uvm_field_int(cmpl_tlp, UVM_ALL_ON)
    `uvm_field_int(cmpl_valid, UVM_ALL_ON)
    `uvm_field_int(cmpl_ready, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "cam_config_tlp_transaction");
    super.new(name);
  endfunction

  constraint cfg_tlp_c {
    cfg_tlp[31:29] inside {3'b010}; // Fmt: Config Write or Read
    cfg_tlp[28:24] == 5'b00100; // Type: Config Write or Read
  }

  constraint cmpl_tlp_c {
    cmpl_tlp[95:80] inside {16'h0100, 16'h0000}; // Completion with or without data
  }
endclass
