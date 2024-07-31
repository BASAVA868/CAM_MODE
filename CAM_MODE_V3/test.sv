///////////////////////////////////////////////////////////////////////////////////////
//
//file name  : test.sv
//version    : 0.2
//description: starting of apb and pcie sequences to generate apb and pcie
//             transactions.
//
///////////////////////////////////////////////////////////////////////////////////////



class cam_config_tlp_test extends uvm_test;
  `uvm_component_utils(cam_config_tlp_test)

  cam_config_tlp_env env;
  cam_config_tlp_sequence cfg_tlp_seq;
  apb_master_seq apb_wr;
  apb_master_rd apb_rd;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = cam_config_tlp_env::type_id::create("env", this);
    cfg_tlp_seq = cam_config_tlp_sequence::type_id::create("cfg_tlp_seq");
    apb_wr = apb_master_seq::type_id::create("apb_wr");
    apb_rd = apb_master_rd::type_id::create("apb_rd");
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    repeat(5) begin
      fork
        apb_wr.start(env.apb_agent.m_sequencer); // Note: You'll need to create an APB agent and connect it properly
        cfg_tlp_seq.start(env.agent.sequencer);
      join

      fork 
        apb_rd.start(env.apb_agent.m_sequencer); // Note: You'll need to create an APB agent and connect it properly
        cfg_tlp_seq.start(env.agent.sequencer);
      join
    end
    phase.drop_objection(this);
  endtask
endclass
