///////////////////////////////////////////////////////////////////////////////////////
//
//file name   : pcie_wr_seq.sv
//version     : 0.2
//description : pcie write sequence
//
///////////////////////////////////////////////////////////////////////////////////////



class cam_config_tlp_sequence extends uvm_sequence#(cam_config_tlp_transaction);
  `uvm_object_utils(cam_config_tlp_sequence)

  function new(string name = "cam_config_tlp_sequence");
    super.new(name);
  endfunction

  task body();
    cam_config_tlp_transaction tx;
    repeat(1) begin
      tx = cam_config_tlp_transaction::type_id::create("tx");
      start_item(tx);
      $display("inside pcie_wr_seq ");
      if (!tx.randomize()) begin
        `uvm_error("SEQ", "Config TLP Transaction randomization failed")
      end
      finish_item(tx);
    end
  endtask
endclass


