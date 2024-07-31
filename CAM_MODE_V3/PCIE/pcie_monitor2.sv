import uvm_pkg::*; // Ensure to import UVM package
`include "uvm_macros.svh"

class cam_config_tlp_monitor extends uvm_monitor;
  `uvm_component_utils(cam_config_tlp_monitor)

  virtual cam_config_tlp_if vif;
  uvm_analysis_port#(cam_config_tlp_transaction) ap;

  // File handle for logging
  integer log_file;

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
    // Open the log file for writing
    log_file = $fopen("cam_config_tlp_monitor.log", "w");
    if (log_file == 0)
      `uvm_fatal("LOG", "Failed to open log file")
  endfunction

  function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    // Close the log file
    $fclose(log_file);
  endfunction

  task run_phase(uvm_phase phase);
    cam_config_tlp_transaction tx;
    forever begin
      @(posedge vif.pclk);

      // Log the transaction details
      if (vif.cfg_tlp_valid || vif.cmpl_valid) begin
        if (vif.cfg_tlp_valid) begin
          // Determine the type of transaction based on fmt field
          string fmt_str;
          if (vif.cfg_tlp[31:29] == 3'b010)
            fmt_str = "CFGWR";
          else if (vif.cfg_tlp[31:29] == 3'b000)
            fmt_str = "CFGRD";
          else
            fmt_str = "UNKNOWN";

          // Log the common fields
          $fwrite(log_file, "==> @%0t  %s (req_id %0d, tag %0d)\n", 
                  $time, fmt_str, vif.cfg_tlp[63:48], vif.cfg_tlp[47:40]);
          $fwrite(log_file, "    | fmt |   typ   |t|  tc |t|a|l|t|t|e|att| at|       length      |\n");
          $fwrite(log_file, "    | %03b |  %05b |%b|_ %03b _|%b|%b|%b|%b|%b|%b| %02b | %010b |\n", 
                  vif.cfg_tlp[31:29], vif.cfg_tlp[28:24], vif.cfg_tlp[23], vif.cfg_tlp[22:20], 
                  vif.cfg_tlp[19], vif.cfg_tlp[18], vif.cfg_tlp[17], vif.cfg_tlp[16], 
                  vif.cfg_tlp[15], vif.cfg_tlp[14], vif.cfg_tlp[13:12], vif.cfg_tlp[11:0]);
          $fwrite(log_file, "    |________ req_id: %04h _________|___ tag: %02h ___|lbe: %h |fbe: %h |\n",
                  vif.cfg_tlp[63:48], vif.cfg_tlp[47:40], vif.cfg_tlp[39:36], vif.cfg_tlp[35:32]);

          // Log specific fields for CFGWR and CFGRD
          if (fmt_str == "CFGWR" || fmt_str == "CFGRD") begin
            $fwrite(log_file, "    | bus: %02h | dev: %02h | func: %01h | rsvd: %01b | ext_reg: %01h | reg: %02h |\n",
                    vif.cfg_tlp[95:88], vif.cfg_tlp[87:83], vif.cfg_tlp[82:80], 
                    vif.cfg_tlp[79:76], vif.cfg_tlp[75:72], vif.cfg_tlp[71:66]);
            if (fmt_str == "CFGWR") begin
              $fwrite(log_file, "    | data: %08h |\n", vif.cfg_tlp[127:96]);
            end else begin
              $fwrite(log_file, "    | data: (not used for CFGRD) |\n");
            end
          end
        end

        if (vif.cmpl_valid && vif.cmpl_ready) begin
          // Determine the type of completion packet based on fmt field
          string cpl_fmt_str;
          if (vif.cmpl_tlp[31:29] == 3'b010)
            cpl_fmt_str = "Cpl";
          else if (vif.cmpl_tlp[31:29] == 3'b000)
            cpl_fmt_str = "CplD";
          else
            cpl_fmt_str = "UNKNOWN";

          // Log the common fields for completion transactions
          $fwrite(log_file, "<== @%0t  %s (req_id %0d, tag %0d, status %0d)\n", 
                  $time, cpl_fmt_str, vif.cmpl_tlp[63:48], vif.cmpl_tlp[47:40], vif.cmpl_tlp[39:37]);
          $fwrite(log_file, "    | fmt |   typ   |t|  tc |t|a|l|t|t|e|att| at|       length      |\n");
          $fwrite(log_file, "    | %03b |  %05b |%b|_ %03b _|%b|%b|%b|%b|%b|%b| %02b | %010b |\n", 
                  vif.cmpl_tlp[31:29], vif.cmpl_tlp[28:24], vif.cmpl_tlp[23], vif.cmpl_tlp[22:20], 
                  vif.cmpl_tlp[19], vif.cmpl_tlp[18], vif.cmpl_tlp[17], vif.cmpl_tlp[16], 
                  vif.cmpl_tlp[15], vif.cmpl_tlp[14], vif.cmpl_tlp[13:12], vif.cmpl_tlp[11:0]);
          $fwrite(log_file, "    |________ req_id: %04h _________|___ tag: %02h ___|lbe: %h |fbe: %h |\n",
                  vif.cmpl_tlp[63:48], vif.cmpl_tlp[47:40], vif.cmpl_tlp[39:36], vif.cmpl_tlp[35:32]);

          // Log specific fields for Cpl and CplD
          if (cpl_fmt_str == "Cpl" || cpl_fmt_str == "CplD") begin
            $fwrite(log_file, "    | status: %01b | bcm: %01b | byte_cnt: %04h | low_addr: %02h |\n",
                    vif.cmpl_tlp[36:35], vif.cmpl_tlp[34:33], vif.cmpl_tlp[32:29], vif.cmpl_tlp[28:24]);
            if (cpl_fmt_str == "CplD") begin
              $fwrite(log_file, "    | data: %08h |\n", vif.cmpl_tlp[127:96]);
            end else begin
              $fwrite(log_file, "    | data: (not used for Cpl) |\n");
            end
          end
        end
      end
    end
  endtask
endclass

