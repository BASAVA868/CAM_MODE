///////////////////////////////////////////////////////////////////////////////////////
//
//file name : pcie_driver.sv
//version  : 0.2
//description: Genertion of completion packets based on the configuration
//             packets recived at the device.Using CFG interface exchanging
//             the both config and completion packets.
//       Note: Wait for the total packet to be received.
//             Completion packet will be initited based on the fmt and type
//             after receiving all the DWs of respective request packet.
//
///////////////////////////////////////////////////////////////////////////////////////



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
      while(!vif.presetn) @(posedge vif.pclk);
      $display("no of times calling");
      drive_completion(tx);
      seq_item_port.item_done();
    end
  endtask


  // completion packet based on cfg type

  task drive_completion(cam_config_tlp_transaction tx);
    logic [127:0] received_cfg_tlp;
    int cnt;

    // Wait for cfg_tlp_valid from DUT
    vif.cfg_tlp_ready <= 1'b1;
    
        // Collect 4 DWs

    while (!vif.cfg_tlp_valid) @(posedge vif.pclk);
    if(vif.TLP_first) begin

      cnt = (vif.cfg_tlp[2:0] == 3'b010) ? 4 : 3 ;            // fmt = 010 : 3DW with data,  fmt =000 : 3DW no data,

      //logic [(32*cnt)-1:0] received_cfg_tlp;

      for (int i = 0; i < cnt; i++) begin
        while (!vif.cfg_tlp_valid && !vif.cfg_tlp_ready) @(posedge vif.pclk);
        received_cfg_tlp[32*i +: 32] = vif.cfg_tlp;
        //vif.dw_counter <= vif.dw_counter + 1;
        @(posedge vif.pclk);
      end
    end
    
    vif.cfg_tlp_ready <= 1'b0;
    // Generate and drive completion packet based on cfg_tlp
      
    `uvm_info(get_type_name(), $sformatf("Value of drv_cfg = %b",received_cfg_tlp),UVM_HIGH);
    
    if (received_cfg_tlp[2:0] == 3'b000 && received_cfg_tlp[7:3] == 5'b00100) begin
      // Read completion (4DW)
      //cmpl_cnt = cmpl_cnt+1;
      `uvm_info(get_type_name(), "///////////////////////////read///////////////////////////////////",UVM_HIGH);
      

      @(negedge vif.pclk);
      vif.cmpl_valid <= 1'b1;
      vif.cmpl_tlp[31:0] <= {9'b0,1'b1,13'b0, 1'b1,8'b01001010};                   // First DW of completion status and random data
      vif.cmpl_first   <= 1;

      @(posedge vif.pclk);
      while(!( vif.cmpl_valid && vif.cmpl_ready)) @(posedge vif.pclk);

       @(negedge vif.pclk);  
      vif.cmpl_tlp[31:0] <= {12'd4,1'b0,3'b000,16'h0100}; // Second DW             // BCM=0 for PCI, PCIe    and BCM=1 for PCI-X ???;
      vif.cmpl_first   <= 0;

      @(posedge vif.pclk);
      while(!( vif.cmpl_valid && vif.cmpl_ready)) @(posedge vif.pclk);

      @(negedge vif.pclk);
      vif.cmpl_tlp[31:0] <= {received_cfg_tlp[63:40],8'b0}; // Third DW

      @(posedge vif.pclk);
      while(!( vif.cmpl_valid && vif.cmpl_ready)) @(posedge vif.pclk);

      @(negedge vif.pclk);
      vif.cmpl_tlp[31:0] <= $random; // Fourth DW with random data

       @(posedge vif.pclk);
      while(!( vif.cmpl_valid && vif.cmpl_ready)) @(posedge vif.pclk);

      @(negedge vif.pclk);
      vif.cmpl_valid <= 1'b0;
      vif.cmpl_tlp <= 32'h0;

    end
   
   //Cmpl 

    else if (received_cfg_tlp[2:0] == 3'b010 && received_cfg_tlp[7:3] == 5'b00100 ) begin
      // Write completion (3DW)
      `uvm_info(get_type_name(), "///////////////////////////WRITE///////////////////////////////////",UVM_HIGH);
      //cmpl_cnt = cmpl_cnt+1;
      @(negedge vif.pclk);
      vif.cmpl_valid <= 1'b1;
      vif.cmpl_tlp[31:0] <= {24'h0,8'b00001010}; // First DW with random values
      vif.cmpl_first   <= 1;

      @(posedge vif.pclk);
      while(!( vif.cmpl_valid && vif.cmpl_ready)) @(posedge vif.pclk);
      `uvm_info(get_type_name(), "///////////////////////////FIRST_HANDSHAKE COMPLETE///////////////////////////////////",UVM_HIGH);
      

      @(negedge vif.pclk);
      vif.cmpl_tlp[31:0] <= {12'd4,1'b1,3'b000,16'h0100}; // Second DW
      vif.cmpl_first     <= 0;

      @(posedge vif.pclk);
      while(!( vif.cmpl_valid && vif.cmpl_ready)) @(posedge vif.pclk);
      `uvm_info(get_type_name(), "///////////////////////////SECOND_HANDSHAKE COMPLETE///////////////////////////////////",UVM_HIGH);

      @(negedge vif.pclk);
      vif.cmpl_tlp[31:0] <= {received_cfg_tlp[63:40],8'b0}; // Third DW
      $display($time,"Value of drv_cmpl_wr3 = %h", vif.cmpl_tlp);

      @(posedge vif.pclk);
      while(!( vif.cmpl_valid && vif.cmpl_ready)) @(posedge vif.pclk);
      `uvm_info(get_type_name(), "///////////////////////////THIRD_HANDSHAKE COMPLETE///////////////////////////////////",UVM_HIGH);

      @(negedge vif.pclk);
      vif.cmpl_valid <= 1'b0;
      vif.cmpl_tlp <= 32'h0;
    end
    //$display($time,"Value of drv_cmpl = %h", vif.cmpl_tlp);
 endtask
endclass

