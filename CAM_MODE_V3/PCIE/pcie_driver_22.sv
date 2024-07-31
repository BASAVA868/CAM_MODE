class cam_config_tlp_driver extends uvm_driver#(cam_config_tlp_transaction);
  `uvm_component_utils(cam_config_tlp_driver)

  virtual cam_config_tlp_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual cam_config_tlp_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Could not get vif")
  endfunction

  task run_phase(uvm_phase phase);
    cam_config_tlp_transaction tx;
    forever begin
      seq_item_port.get_next_item(tx);
      vif.cmpl_valid <= 1'b0;
      while (!vif.presetn) @(posedge vif.pclk);
      drive_completion(tx);
      seq_item_port.item_done();
    end
  endtask

  task drive_completion(cam_config_tlp_transaction tx);
    logic [31:0] dw1, dw2, dw3, dw4;
    bit[1:0] cnt;
    logic [2:0] fmt;
    logic [4:0] type;

    vif.cfg_tlp_ready <= 1'b1;
    // Wait for first DW from DUT
    while (!vif.TLP_first && vif.cfg_tlp_valid) @(posedge vif.pclk);
    dw1 = vif.cfg_tlp;
    cnt = cnt+1;
    // Extract format and type
    fmt = dw1[0:2];
    type = dw1[3:7];

    // Based on format, determine length
    if (fmt == 3'b010) 
      // 4 DWs (Completion with Data)
      while (!vif.cfg_tlp_valid) @(posedge vif.pclk);
      dw2 = vif.cfg_tlp;

      vif.cfg_tlp_ready <= 1'b1;
      while (!vif.cfg_tlp_valid) @(posedge vif.pclk);
      dw3 = vif.cfg_tlp;

      while (!vif.cfg_tlp_valid) @(posedge vif.pclk);
      dw4 = vif.cfg_tlp;

      // Generate the completion packet
      vif.cmpl_valid <= 1'b1;
      vif.cmpl_tlp <= {dw1, dw2, dw3, dw4};
    end else if (fmt == 3'b000) begin
      // 3 DWs (Completion without Data)
      vif.cfg_tlp_ready <= 1'b1;
      while (!vif.cfg_tlp_valid) @(posedge vif.pclk);
      vif.cfg_tlp_ready <= 1'b0;
      dw2 = vif.cfg_tlp;

      while (!vif.cfg_tlp_valid) @(posedge vif.pclk);
      dw3 = vif.cfg_tlp;

      // Generate the completion packet
      vif.cmpl_valid <= 1'b1;
      vif.cmpl_tlp <= {dw1, dw2, dw3, 32'b0}; // 4th DW is zero for 3 DW completion
    end else begin
      vif.cmpl_valid <= 1'b0;
      vif.cmpl_tlp <= 32'h0;
    end

    // Wait for completion ready
    @(posedge vif.pclk);
    while (!vif.cmpl_ready) @(posedge vif.pclk);

    // De-assert completion valid
    vif.cmpl_valid <= 1'b0;
    vif.cmpl_tlp <= 32'h0;
  endtask
endclass

