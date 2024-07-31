///////////////////////////////////////////////////////////////////////////////////////
//
//file name   : pcie_if.sv
//version     : 0.2
//description : Interfcae for the config and completiion packets.
//              Protocol assertions also implemented by using assertions for
//              config and completon packet by using the requesta nd
//              completion rules. 
//
//////////////////////////////////////////////////////////////////////////////////////




interface cam_config_tlp_if(input logic pclk, presetn);
  logic [31:0] cfg_tlp;
  logic        TLP_first;
  logic         cfg_tlp_valid;
  logic         cfg_tlp_ready;
  logic [31:0] cmpl_tlp;
  logic        cmpl_first;
  logic         cmpl_valid;
  logic         cmpl_ready;

//////////////////////////////////////////////////////////////////////////////////
//                   cfg_packet assertions
///////////////////////////////////////////////////////////////////////////////////

  property tc_check;
	  @(posedge pclk) (cfg_tlp_valid && TLP_first)  |-> (cfg_tlp[11:9] == 3'b000);
  endproperty
  property attr_check;
	  @(posedge pclk) (cfg_tlp_valid && TLP_first)  |-> (cfg_tlp[18:19] == 2'b00);
  endproperty
  property length_check;
	  @(posedge pclk) (cfg_tlp_valid && TLP_first)  |-> (cfg_tlp[31:22] == 10'b1);
  endproperty

  property first_BE_check;
	  @(posedge pclk) (cfg_tlp_valid && TLP_first && cfg_tlp_ready)  |=> first_match(##[0:$] (cfg_tlp_valid && cfg_tlp_ready)) |-> (cfg_tlp[31:28] == 4'b1111);
  endproperty

  property last_BE_check;
	  @(posedge pclk) (cfg_tlp_valid && TLP_first && cfg_tlp_ready)  |=> first_match(##[0:$] (cfg_tlp_valid && cfg_tlp_ready)) |-> (cfg_tlp[27:24] == 4'b0000);
  endproperty
 
  assert property(tc_check)
    else $error("Cfg TLP TC field is incorrect");

  assert property(attr_check)
    else $error("Cfg TLP attr field is incorrect");

  assert property(length_check)
    else $error("Cfg TLP length field is incorrect");

  assert property(first_BE_check)
    else $error("Cfg TLP first BE is incorrect");

  assert property(last_BE_check)
    else $error("Cfg TLP last BE is incorrect");




///////////////////////////////////////////////////////////////////////////////////
//                   cmpl_packet assertion
///////////////////////////////////////////////////////////////////////////////////

  // Combined property to check Cpl conditions for length
  property p_cpl_length;
    @(posedge pclk)
    ((cmpl_valid && cmpl_first && cmpl_ready) && (cmpl_tlp[7:5] == 3'b000 && cmpl_tlp[4:0] == 5'b01010)) |->  (cmpl_tlp[31:22] == 10'b0);
  endproperty


 // Combined property to check Cpl conditions for byte count
  property p_cpl_bytecnt;
    @(posedge pclk)
    ((cmpl_valid && cmpl_first && cmpl_ready) && (cmpl_tlp[7:5] == 3'b000 && cmpl_tlp[4:0] == 5'b01010)) |=> first_match(##[0:$] (cmpl_valid && cmpl_ready)) |-> (cmpl_tlp[31:20] == 'd4);
  endproperty

  // Combined property to check CplD conditions for length
  property p_cpld_length;
    @(posedge pclk) 
    ((cmpl_valid && cmpl_first && cmpl_ready) && (cmpl_tlp[7:5] == 3'b010 && cmpl_tlp[4:0] == 5'b01010)) |->  (cmpl_tlp[31:22] == 10'b1);
  endproperty


  // Combined property to check CplD conditions for byte count
  property p_cpld_bytecnt;
    @(posedge pclk) 
    ((cmpl_valid && cmpl_first && cmpl_ready) && (cmpl_tlp[7:5] == 3'b010 && cmpl_tlp[4:0] == 5'b01010)) |=> first_match(##[0:$] (cmpl_valid && cmpl_ready)) |-> (cmpl_tlp[31:20] == 'd4);
  endproperty


  // Assertions using the combined properties
  assert property (p_cpl_length)
    else $error("Cpl TLP length field is incorrect");

  assert property (p_cpl_bytecnt)
    else $error("Cpl TLP byte count field is incorrect");


  assert property (p_cpld_length)
    else $error("CplD TLP length field is incorrect");

  assert property (p_cpld_bytecnt)
    else $error("CplD TLP byte count field is incorrect");


endinterface

