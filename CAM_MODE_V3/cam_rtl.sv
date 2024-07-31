/////////////////////////////////////////////////////////////////////////
//
//file name : cam_rtl.sv
//version  : 0.2
//description: Genertion of config packets based on the cf8/cfc registers
//             using APB interface and collecting the completion packets for
//             the initiated configuration packets using 32 bit interface.
//
//      Note : Wait for the total packet to be received.
//             state will be changed from wait for cmpletion to idle 
//             after receiving all the DWs of respective completion packet.
//
//
////////////////////////////////////////////////////////////////////////        





module CAM_Config_TLP (
  // APB Interface
  input logic        pclk,
  input logic        presetn,
  input logic        psel,
  input logic [31:0] paddr,
  input logic        penable,
  input logic        pwrite,
  input logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic       pready,

  // Config TLP Interface
  output logic [31:0] o_cfg_tlp_data,
  output logic        TLP_first,
  output logic        o_cfg_tlp_valid,
  input logic         i_cfg_tlp_ready,

  // Completion TLP Interface
  input logic [31:0] i_cmpl_tlp_data,
  input logic        i_cmpl_first,	  
  input logic        i_cmpl_valid,
  output logic       o_cmpl_ready
);

  // FSM States
  typedef enum logic [2:0] {
    IDLE,
    CAPTURE_WRITE,
    CAPTURE_READ,
    SEND_TLP,
    WAIT_FOR_COMPLETION
  } fsm_state_t;
  fsm_state_t state, next_state;

  logic [1:0] cnt=0;
  // Internal Registers
  logic [31:0] cf8_reg;
  logic [31:0] cfc_reg;

  // APB Read and Write Handling
  logic apb_read_pending;
  logic apb_write_pending;
  logic [31:0] apb_addr;

  logic write_ready;
  logic read_ready;

  // TLP Sending Counters
  logic [1:0] tlp_word_counter;
  logic [2:0] total_dws,cmpl_cnt;
  logic       is_write = 0;
  logic [127:0]received_cmpl_reg ;

  // APB interface logic: capture read/write requests
  always_ff @(posedge pclk) begin
    if (!presetn) begin
      cf8_reg <= 32'b0;
      cfc_reg <= 32'b0;
      apb_read_pending <= 1'b0;
      apb_write_pending <= 1'b0;
      apb_addr <= 32'b0;
      write_ready <= 1'b0;
    end else if (psel && penable && !apb_read_pending && !apb_write_pending) begin
      apb_addr <= paddr;
      if (pwrite) begin
        if (paddr == 32'hCF8) begin
          cf8_reg <= pwdata;
          write_ready <= 1'b1;
        end else if (paddr == 32'hCFC) begin
          cfc_reg <= pwdata;
          apb_write_pending <= 1'b1;
        end
      end else begin
        apb_read_pending <= 1'b1;
      end
    end else if (write_ready && !apb_write_pending) begin
      write_ready <= 1'b0;
    end
  end

  // FSM: state transitions
  always_ff @(posedge pclk) begin
    if (!presetn) begin
      state <= IDLE;
      tlp_word_counter <= 2'b00;
      //is_write <= 1'b0;
    end else begin
      state <= next_state;
      if (state == SEND_TLP && i_cfg_tlp_ready) begin
        tlp_word_counter <= tlp_word_counter + 2'b01;
      end else if (state != SEND_TLP) begin
        tlp_word_counter <= 2'b00;
      end
    end
  end

  // FSM: next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (apb_write_pending) begin
          next_state = CAPTURE_WRITE;
        end else if (apb_read_pending) begin
          next_state = CAPTURE_READ;
        end
      end
      CAPTURE_WRITE: begin
          next_state = SEND_TLP;
          is_write = 1'b1;
      end
      CAPTURE_READ: begin
          next_state = SEND_TLP;
          is_write = 1'b0;
      end
      SEND_TLP: begin
        if ((tlp_word_counter == 2'b11 && is_write) || (tlp_word_counter == 2'b10 && !is_write)) begin
          next_state = WAIT_FOR_COMPLETION;
        end
      end
      WAIT_FOR_COMPLETION: begin
        if (total_dws > 0 && cmpl_cnt == total_dws) begin
          next_state = IDLE;
        end
      end
    endcase
  end


  // Config TLP generation
  always_ff @(posedge pclk) begin
    if (!presetn) begin
      o_cfg_tlp_data <= 32'b0;
      o_cfg_tlp_valid <= 1'b0;
    end else begin
      o_cfg_tlp_data  <= 1'b0;
      o_cfg_tlp_valid <= 1'b0;

      // depending on the ready for first DW
      if (state == SEND_TLP && (tlp_word_counter != 2'b00 || i_cfg_tlp_ready)) begin
        case (tlp_word_counter)
          2'b00: begin
            o_cfg_tlp_data <= { // First DW
              10'b0000000001, // Length: 1 DW
              2'b00,         // AT
              2'b00,         // Attr
              1'b0,          // EP
              1'b0,          // TD
              1'b0,          // TH
              1'b0,          // LN
              1'b0,          // Attr
              1'b0,          // T8
              3'b000,        // TC
              1'b0,          // T9
              5'b00100,      // Type: Config Write/Read
              is_write ? 3'b010 : 3'b000 // Fmt: Config Write/Read
            };
            o_cfg_tlp_valid <= 1'b1;
	    TLP_first       <= 1;
          end
          2'b01: begin
	    TLP_first       <= 0;
            o_cfg_tlp_data  <= { // Second DW
              4'b1111,        // First DW BE
              4'b0000,        // Last DW BE
              8'b0,           // Tag
              16'b0           // Requester ID (could be modified as needed)
            };
            o_cfg_tlp_valid <= 1'b1;
          end
          2'b10: begin
            o_cfg_tlp_data <= { // Third DW
              2'b00,          // Reserved
              cf8_reg[7:2],   // Register Number
              4'b0000,        // Extended Register Number
              4'b0000,        // Reserved
              cf8_reg[10:8],  // Function Number
              cf8_reg[15:11], // Device Number
              cf8_reg[23:16]  // Bus Number
            };
            o_cfg_tlp_valid <= 1'b1;
          end
          2'b11: begin
            if (is_write) begin
              o_cfg_tlp_data <= cfc_reg; // Fourth DW: Data
              o_cfg_tlp_valid <= 1'b1;
            end
          end
        endcase
      end
    end
  end




  // Completion TLP handling
  always_ff @(posedge pclk) begin
    if (!presetn) begin
      o_cmpl_ready <= 1'b0;
      prdata <= 32'b0;
      apb_read_pending <= 1'b0;
      apb_write_pending <= 1'b0;
      read_ready <= 1'b0;
    end
    else begin
 
      if(state == WAIT_FOR_COMPLETION && cmpl_cnt==0)  o_cmpl_ready <= 1'b1; 	    
  
      if(state == WAIT_FOR_COMPLETION && (total_dws > 0 && (cmpl_cnt == total_dws)))
  	begin
          if (received_cmpl_reg[4:0] == 5'b01010 && received_cmpl_reg[7:5] == 3'b010)  // Cpl with Data
  	  begin
              cfc_reg <= received_cmpl_reg[127:96];
              prdata <= received_cmpl_reg[127:96]; // Copy the data to APB read data
              read_ready <= 1'b1;
  	      cmpl_cnt  <= 1'b0;
  	      o_cmpl_ready <= 1'b0;
              apb_read_pending <= 1'b0;
  	  end 
  	  else if(received_cmpl_reg[4:0] == 5'b01010 && received_cmpl_reg[7:5] == 3'b000) // cpl
            begin
              cfc_reg <= cfc_reg;
              prdata  <= prdata; // Copy the data to APB read data
              read_ready <= 1'b1;
  	      cmpl_cnt <= 1'b0;
  	      o_cmpl_ready<='b0;
              apb_write_pending <= 1'b0;
  	  end
	end	

     end	
end


// completion TLP

always_ff @(posedge pclk) begin
  if (!presetn) begin
      received_cmpl_reg <= 0;
      cmpl_cnt <= 0;
      total_dws <= 0;

  end else begin
       
      if (i_cmpl_valid) begin
          if (cmpl_cnt == 0 && i_cmpl_first) begin
              // Determine the total number of DWs to capture based on the TLP type
              total_dws <= (i_cmpl_tlp_data[7:5] == 3'b000) ? 3 : 4;
              cmpl_cnt <= 1;
              received_cmpl_reg[31:0] <= i_cmpl_tlp_data[31:0];

          end else if (cmpl_cnt < total_dws) begin
              // Capture subsequent DWs
              received_cmpl_reg[32*cmpl_cnt +: 32] <= i_cmpl_tlp_data[31:0];     /// [31:0]
              cmpl_cnt <= cmpl_cnt + 1;


          end 
     end
  end

end

  assign pready = (write_ready | read_ready);

endmodule




