class cam_config_tlp_env extends uvm_env;
  `uvm_component_utils(cam_config_tlp_env)

  cam_config_tlp_agent    agent;
  apb_master_agent        apb_agent;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = cam_config_tlp_agent::type_id::create("agent", this);
    apb_agent = apb_master_agent::type_id::create("apb_agent", this);
  endfunction

  function void connect_phase(uvm_phase phase);
  endfunction
endclass
