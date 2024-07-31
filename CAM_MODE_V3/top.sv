///////////////////////////////////////////////////////////////////////////////////////
//
//file name   : top.sv
//version     : 0.2
//description : 
//             in this starting the test and instatintiating the design.
//             And setting the interfaces and generating the clock are
//             implemented.
//
//             note:
//             Additionaly used a shared_log file to track the apb and pcie
//             transactons in the same file.
//
///////////////////////////////////////////////////////////////////////////////////////




`include "uvm_macros.svh"
import uvm_pkg::*;
`include "apb.svh"
`include "pcie.svh"
`include "env.sv"
`include "test.sv"
`include "cam_rtl.sv"

module cam_config_tlp_tb;
  reg pclk;
  reg presetn;

  cam_config_tlp_if vif(pclk, presetn);
  apb_if vif_apb(pclk, presetn);

  CAM_Config_TLP dut (
    .pclk(pclk),
    .presetn(vif_apb.PRESET_N),
    .psel(vif_apb.PSEL),
    .paddr(vif_apb.PADDR),
    .penable(vif_apb.PENABLE),
    .pwrite(vif_apb.PWRITE),
    .pwdata(vif_apb.PWDATA),
    .prdata(vif_apb.PRDATA),
    .pready(vif_apb.PREADY),
    .o_cfg_tlp_data(vif.cfg_tlp),
    .i_cmpl_first(vif.cmpl_first),
    .TLP_first(vif.TLP_first),
    .o_cfg_tlp_valid(vif.cfg_tlp_valid),
    .i_cfg_tlp_ready(vif.cfg_tlp_ready),
    .i_cmpl_tlp_data(vif.cmpl_tlp),
    .i_cmpl_valid(vif.cmpl_valid),
    .o_cmpl_ready(vif.cmpl_ready)
  );

  // Shared log file handle
  integer shared_log_file;

  initial begin
    pclk = 0;
    forever #5 pclk = ~pclk;
  end

  initial begin
    presetn = 0;
    #100 presetn = 1;
  end

  initial begin
    // Open the shared log file
    shared_log_file = $fopen("shared_monitor.log", "a");
    if (shared_log_file == 0) begin
      $display("Failed to open shared log file");
      $finish;
    end

    // Set virtual interfaces
    uvm_config_db#(virtual cam_config_tlp_if)::set(null, "*", "vif", vif);
    uvm_config_db#(virtual apb_if)::set(null, "*", "vif_apb", vif_apb);
    
    // Set the shared log file handle in the configuration database
    uvm_config_db#(integer)::set(null, "*", "shared_log_file", shared_log_file);

    run_test("cam_config_tlp_test");
  end

  // Ensure the file is closed at the end
  final begin
    if (shared_log_file != 0)
      $fclose(shared_log_file);
  end
endmodule

