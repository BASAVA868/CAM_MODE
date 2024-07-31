module CAM_Config_TLP (
  // APB Interface
  input logic     pclk,
  input logic     presetn,
  input logic     psel,
  input logic [31:0]  paddr,
  input logic     penable,
  input logic     pwrite,
  input logic [31:0]  pwdata,
  output logic [0:31]  prdata,
  output logic     pready,

  // Config TLP Interface
  output logic [0:127] o_cfg_tlp,
  output logic     o_cfg_tlp_valid,
  input logic     i_cfg_tlp_ready,

  // Completion TLP Interface
  input logic [0:127] i_cmpl_tlp,
  input logic     i_cmpl_valid,
  output logic     o_cmpl_ready
);

  // FSM States
  typedef enum logic [1:0] {
    IDLE,
    CAPTURE_WRITE,
    CAPTURE_READ,
    WAIT_FOR_COMPLETION
  } fsm_state_t;
  fsm_state_t state, next_state;

  // Internal Registers
  logic [31:0] cf8_reg;
  logic [31:0] cfc_reg;

  // APB Read and Write Handling
  logic apb_read_pending;
  logic apb_write_pending;
  logic [31:0] apb_addr;

  logic write_ready;
  logic read_ready;

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
    end else begin
      state <= next_state;
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
        if (i_cfg_tlp_ready) begin
          next_state = WAIT_FOR_COMPLETION;
        end
      end
      CAPTURE_READ: begin
        if (i_cfg_tlp_ready) begin
          next_state = WAIT_FOR_COMPLETION;
        end
      end
      WAIT_FOR_COMPLETION: begin
        if (i_cmpl_valid && o_cmpl_ready) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Config TLP generation
  always_ff @(posedge pclk) begin
    if (!presetn) begin
      o_cfg_tlp <= 128'b0;
      o_cfg_tlp_valid <= 1'b0;
    end else begin
      case (state)
        CAPTURE_WRITE: begin
            // Generate the header for a config write TLP
            o_cfg_tlp[0:31] <= { // First DW
              3'b010,    // Fmt: Config Write
              5'b00100,   // Type: Config Write
              1'b0,     // T9
              3'b000,    // TC
              1'b0,     // T8
              1'b0,     // Attr
              1'b0,     // LN
              1'b0,     // TH
              1'b0,     // TD
              1'b0,     // EP
              2'b00,     // Attr
              2'b00,     // AT
              10'b0000000001 // Length: 1 DW
            };
            o_cfg_tlp[32:63] <= { // Second DW
              16'b0,      // Requester ID (could be modified as needed)
              8'b0,       // Tag
              4'b1111,     // Last DW BE
              4'b1111      // First DW BE
            };
            o_cfg_tlp[64:95] <= { // Third DW
              cf8_reg[23:16],  // Bus Number
              cf8_reg[15:11],  // Device Number
              cf8_reg[10:8],  // Function Number
              4'b0000,     // Reserved
              4'b0000,     // Extended Register Number
              cf8_reg[7:2],   // Register Number
              2'b00       // Reserved
            };
            o_cfg_tlp[96:127] <= cfc_reg; // Fourth DW: Data

            o_cfg_tlp_valid <= 1'b1;
          end
        CAPTURE_READ: begin
            // Generate the header for a config read TLP
            o_cfg_tlp[0:31] <= { // First DW
              3'b000,    // Fmt: Config Read
              5'b00100,   // Type: Config Read
              1'b0,     // T9
              3'b000,    // TC
              1'b0,     // T8
              1'b0,     // Attr
              1'b0,     // LN
              1'b0,     // TH
              1'b0,     // TD
              1'b0,     // EP
              2'b00,     // Attr
              2'b00,     // AT
              10'b0000000001 // Length: 1 DW
            };
            o_cfg_tlp[32:63] <= { // Second DW
              16'b0,      // Requester ID (could be modified as needed)
              8'b0,       // Tag
              4'b1111,     // Last DW BE
              4'b1111      // First DW BE
            };
            o_cfg_tlp[64:95] <= { // Third DW
              cf8_reg[23:16],  // Bus Number
              cf8_reg[15:11],  // Device Number
              cf8_reg[10:8],  // Function Number
              4'b0000,     // Reserved
              4'b0000,     // Extended Register Number
              cf8_reg[7:2],   // Register Number
              2'b00       // Reserved
            };
            o_cfg_tlp[96:127] <= 32'b0; // No data for config read

            o_cfg_tlp_valid <= 1'b1;
        end
        WAIT_FOR_COMPLETION: begin
          o_cfg_tlp_valid <= 1'b0;
        end
        default: begin
          o_cfg_tlp <= 128'b0;
          o_cfg_tlp_valid <= 1'b0;
        end
      endcase
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
    end else begin
      read_ready <= 1'b0;
      if (state == WAIT_FOR_COMPLETION && i_cmpl_valid) begin
        // Check completion type using fmt and type fields
	$display("value of _cmpl=%b",i_cmpl_tlp);
      if (i_cmpl_tlp[0:2] == 3'b000 && i_cmpl_tlp[3:7] == 5'b00100) begin // Cpl with Data
	$display("********************************************************************************************************");
        cfc_reg <= i_cmpl_tlp[96:127]; // Store the data in CFC register
        prdata[0:31] <= i_cmpl_tlp[96:127];  // Copy the data to APB read data
        read_ready <= 1'b1;
      end else begin // Cpl without Data
        write_ready <= 1'b1;
      end
      o_cmpl_ready <= 1'b1;
      // Clear pending flags
      apb_read_pending <= 1'b0;
      apb_write_pending <= 1'b0;
    end else begin
      o_cmpl_ready <= 1'b0;    
      end
    end
  end

  assign pready = (write_ready | read_ready);

endmodule

