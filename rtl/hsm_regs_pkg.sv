
package hsm_regs_pkg;

    localparam logic [31:0] HSM_CTRL_OFFSET         = 32'h00;
    localparam logic [31:0] HSM_STATUS_OFFSET       = 32'h04;
    localparam logic [31:0] HSM_ERROR_OFFSET        = 32'h08;
    localparam logic [31:0] HSM_LOCK_OFFSET         = 32'h0C;
    localparam logic [31:0] HSM_KEY_SLOT_OFFSET     = 32'h10;
    localparam logic [31:0] HSM_NONCE_STATUS_OFFSET = 32'h14;
    localparam logic [31:0] HSM_VERSION_OFFSET      = 32'h18;

    localparam int CTRL_START_BIT = 0;

    localparam logic [31:0] HSM_LOCK_MAGIC    = 32'h4C4F434B;
    localparam logic [31:0] HSM_VERSION_VALUE = 32'h0001_0000;

endpackage
