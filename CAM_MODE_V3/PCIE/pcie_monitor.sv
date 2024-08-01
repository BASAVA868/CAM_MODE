///////////////////////////////////////////////////////////////////////////////////////
//
//file name : pcie_monitor.sv
//version  : 0.2
//description: Monitoring both Config and Completion packets Using CFG
//             interface.
//
//////////////////////////////////////////////////////////////////////////////////////





import uvm_pkg::*;
`include "uvm_macros.svh"

class cam_config_tlp_monitor extends uvm_monitor;
  `uvm_component_utils(cam_config_tlp_monitor)

  virtual cam_config_tlp_if vif;
  uvm_analysis_port#(cam_config_tlp_transaction) ap;

  integer shared_log_file;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual cam_config_tlp_if)::get(this, "", "vif", vif))
      `uvm_fatal("MON", "Could not get vif")
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (!uvm_config_db#(integer)::get(this, "", "shared_log_file", shared_log_file))
      `uvm_fatal("LOG", "Failed to get shared log file handle")
  endfunction

  task run_phase(uvm_phase phase);
    cam_config_tlp_transaction tx;
//    logic [127:0] cfg_tlp;
    logic [127:0] cmpl_tlp;
    int cfg_dw_count, cmpl_dw_count;

    forever begin
      tx = cam_config_tlp_transaction::type_id::create("tx");
      @(posedge vif.pclk);

      // Monitor configuration transaction
      if (vif.cfg_tlp_valid && vif.cfg_tlp_ready) begin                              // also check for first_data_tlp
        cfg_dw_count = 0;
        tx.cfg_tlp = 128'h0;
        if(vif.cfg_tlp[2:0] == 3'b010 && vif.cfg_tlp[7:3] == 5'b00100) begin
          while ( cfg_dw_count < 4 && vif.cfg_tlp_valid && vif.cfg_tlp_ready) begin     // why 4????
            tx.cfg_tlp[32*cfg_dw_count +: 32] = vif.cfg_tlp;
            cfg_dw_count++;
            @(posedge vif.pclk);
          end
        end
        else if(vif.cfg_tlp[2:0] == 3'b000 && vif.cfg_tlp[7:3] == 5'b00100) begin
          while ( cfg_dw_count < 3 && vif.cfg_tlp_valid && vif.cfg_tlp_ready) begin     // why 4????
            tx.cfg_tlp[32*cfg_dw_count +: 32] = vif.cfg_tlp;
            cfg_dw_count++;
            @(posedge vif.pclk);
          end
        end

	cfg_pkt_rules_check(tx);
        log_cfg_transaction(tx.cfg_tlp);
      end

      // Monitor completion transaction
      if (vif.cmpl_valid && vif.cmpl_ready) begin
        cmpl_dw_count = 0;
        cmpl_tlp = 128'h0;

        while (cmpl_dw_count < 4 && vif.cmpl_valid && vif.cmpl_ready) begin
          cmpl_tlp[32*cmpl_dw_count +: 32] = vif.cmpl_tlp;
          cmpl_dw_count++;
          @(posedge vif.pclk);
        end

        log_cmpl_transaction(cmpl_tlp);
      end
    end
  endtask

task cfg_pkt_rules_check(cam_config_tlp_transaction tx);
        // Check the TC (Traffic Class) field
        if (tx.cfg_tlp[11:9] != 3'b000) begin
            `uvm_fatal(get_type_name(), $sformatf("Expected TC='d0 --- Actual TC='d%d", tx.cfg_tlp[11:9]));
        end
        
        // Check the Attr field
        if (tx.cfg_tlp[19:18] != 2'b00) begin
            `uvm_fatal(get_type_name(), $sformatf("Expected Attr='d0 --- Actual Attr='d%d", tx.cfg_tlp[19:18]));
        end
        
        // Check the length field
        if (tx.cfg_tlp[31:22] != 10'b0000000001) begin
            `uvm_fatal(get_type_name(), $sformatf("Expected length='d1 --- Actual length='d%d", tx.cfg_tlp[31:22]));
        end
        
        // First BE check (first 4 bits of TLP)
        if (tx.cfg_tlp[63:60] != 4'b1111) begin
            `uvm_fatal(get_type_name(), $sformatf("Expected First BE='b1111 --- Actual First BE='b%b", tx.cfg_tlp[63:60]));
        end
        
        // Last BE check (next 4 bits after First BE)
        if (tx.cfg_tlp[59:56] != 4'b0000) begin
            `uvm_fatal(get_type_name(), $sformatf("Expected Last BE='b0000 --- Actual Last BE='b%b", tx.cfg_tlp[59:56]));
        end
endtask
 

  task log_cfg_transaction(logic [127:0] cfg_tlp);
    string fmt_str = (cfg_tlp[2:0] == 3'b010 && cfg_tlp[7:3] == 5'b00100) ? "CFGWR" : 
                     (cfg_tlp[2:0] == 3'b000 && cfg_tlp[7:3] == 5'b00100) ? "CFGRD" : "UNKNOWN";

    //$display($time,"check for cfg_tlp_fmt=%b",cfg_tlp[2:0]);
    //$display($time,"check for cfg_tlp_type=%b",cfg_tlp[7:3]);
    $fwrite(shared_log_file, "==> @%0t  %s (req_id %0d, tag %0d)\n", 
            $time, fmt_str, cfg_tlp[47:32], cfg_tlp[55:48]);
    $fwrite(shared_log_file, "    | fmt |   typ   |t|  tc |t|a|l|t|t|e|att| at|       length      |\n");
    $fwrite(shared_log_file, "    | %03b |  %05b |%b|_ %03b _|%b|%b|%b|%b|%b|%b|%02b| %02b | %010b |\n", 
            cfg_tlp[2:0], cfg_tlp[7:3], cfg_tlp[8], cfg_tlp[11:9], 
            cfg_tlp[12], cfg_tlp[13], cfg_tlp[14], cfg_tlp[15], 
            cfg_tlp[16], cfg_tlp[17], cfg_tlp[19:18],cfg_tlp[21:20],cfg_tlp[31:22]);
    $fwrite(shared_log_file, "    |________ req_id: %04h _________|___ tag: %02h ___|lbe: %h |fbe: %h |\n",
            cfg_tlp[47:32], cfg_tlp[55:48], cfg_tlp[59:56], cfg_tlp[63:60]);

    if (fmt_str == "CFGWR" || fmt_str == "CFGRD") begin
      $fwrite(shared_log_file, "    | bus: %02h | dev: %02h | func: %01h | rsvd: %01b | ext_reg: %01h | reg: %02h |\n",
              cfg_tlp[71:64], cfg_tlp[76:72], cfg_tlp[79:77], 
              cfg_tlp[85:82], cfg_tlp[89:86], cfg_tlp[95:90]);
      if (fmt_str == "CFGWR") begin
        $fwrite(shared_log_file, "    | data: %08h |\n", cfg_tlp[127:96]);
      end else begin
        $fwrite(shared_log_file, "    | data: (not used for CFGRD) |\n");
      end
    end
  endtask

  task log_cmpl_transaction(logic [127:0] cmpl_tlp);
    string cpl_fmt_str = (cmpl_tlp[7:5] == 3'b000 && cmpl_tlp[4:0] == 5'b01010) ? "Cpl" :
                         (cmpl_tlp[7:5] == 3'b010 && cmpl_tlp[4:0] == 5'b01010) ? "CplD" : "UNKNOWN";

    $fwrite(shared_log_file, "<== @%0t  %s (req_id %0d, tag %0d, status %0d)\n", 
            $time, cpl_fmt_str, cmpl_tlp[79:64], cmpl_tlp[87:80], cmpl_tlp[90:88]);
    $fwrite(shared_log_file, "    | fmt |   typ   |t|  tc |t|a|l|t|t|e|att| at|       length      |\n");
    $fwrite(shared_log_file, "    | %03b |  %05b |%b|_ %03b _|%b|%b|%b|%b|%b|%b|%02b| %02b | %010b |\n", 
            cmpl_tlp[7:5], cmpl_tlp[4:0], cmpl_tlp[8], cmpl_tlp[11:9], 
            cmpl_tlp[12], cmpl_tlp[13], cmpl_tlp[14], cmpl_tlp[15], 
            cmpl_tlp[16], cmpl_tlp[17], cmpl_tlp[19:18],cmpl_tlp[21:20], cmpl_tlp[30:22]);
    $fwrite(shared_log_file, "    |_____ cpl_id: %04h ___|cpl_status: %01b|bcm: %01b|__ byte_cnt: %04h |\n",
            cmpl_tlp[47:32], cmpl_tlp[50:48], cmpl_tlp[51], cmpl_tlp[63:52]);
    $fwrite(shared_log_file, "    |_____ req_id: %04h ___|___ tag: %02h ___|rsvd20: %01b| low_addr: %02h |\n",
            cmpl_tlp[79:64], cmpl_tlp[87:80], cmpl_tlp[88], cmpl_tlp[95:89]);

    if (cpl_fmt_str == "CplD") begin
      $fwrite(shared_log_file, "    | data: %08h |\n", cmpl_tlp[127:96]);
    end else begin
      $fwrite(shared_log_file, "    | data: (not used for Cpl) |\n");
    end
  endtask
endclass

