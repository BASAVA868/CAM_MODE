//define apb_master sequence class
class apb_master_seq extends uvm_sequence#(apb_base_seq_item);
  
  //register the class with uvm factory
	`uvm_object_utils(apb_master_seq)
  
  //constructor
  function new(string name ="apb_master_seq");
    //call thebase class constructor
	  super.new(name);
  endfunction

  //task for defining the sequence body
  task body();
    //declare an instance of the apb_base_sequence item transaction
	  apb_base_seq_item m_apb_base_seq_item;	
    //create 10 random apb master sequences and send to master driver
  	repeat(1) begin
      //create a new instance of the apb_base_seq_item transaction
                  $display("inside apb_master_seq");
		  m_apb_base_seq_item = apb_base_seq_item::type_id::create("m_apb_base_seq_item");
		  /*start_item(m_apb_base_seq_item);          //start the transaction item
		  assert (m_apb_base_seq_item.randomize());   //randomize the transaction item
		  finish_item(m_apb_base_seq_item);*/         //finish the transaction item
      `uvm_do_with(m_apb_base_seq_item,{addr == 'hCF8;apb_tr==WRITE;})
      `uvm_do_with(m_apb_base_seq_item,{addr == 'hCFC;apb_tr==WRITE;})
	  end
  endtask
	
endclass  // end of the class




//define apb_master sequence class
class apb_master_rd extends uvm_sequence#(apb_base_seq_item);
  
  //register the class with uvm factory
	`uvm_object_utils(apb_master_rd)
  
  //constructor
  function new(string name ="apb_master_rd");
    //call thebase class constructor
	  super.new(name);
  endfunction

  //task for defining the sequence body
  task body();
    //declare an instance of the apb_base_sequence item transaction
	  apb_base_seq_item m_apb_base_seq_item;	
    //create 10 random apb master sequences and send to master driver
  	repeat(1) begin
      //create a new instance of the apb_base_seq_item transaction
                  $display("inside apb_master_rd");
		  m_apb_base_seq_item = apb_base_seq_item::type_id::create("m_apb_base_seq_item");
      `uvm_do_with(m_apb_base_seq_item,{addr == 'hCF8;apb_tr==WRITE;})
      `uvm_do_with(m_apb_base_seq_item,{addr == 'hCFC;apb_tr==READ;})
	  end
  endtask
	
endclass  // end of the class
