
package hsm_regs_pkg;

    // =========================================
    // HSM REGISTER BANK ADDRESSES
    // =========================================

    localparam logic [7:0] SEC_CTRL_ADDR       = 8'h00;
    localparam logic [7:0] SEC_STATUS_ADDR     = 8'h04;
    localparam logic [7:0] SEC_FAULT_ADDR      = 8'h08;
    localparam logic [7:0] KEY_CTRL_ADDR       = 8'h0C;
    localparam logic [7:0] CRYPTO_CMD_ADDR     = 8'h10;
    localparam logic [7:0] CRYPTO_STATUS_ADDR  = 8'h14;
    localparam logic [7:0] NONCE_LOW_ADDR      = 8'h18;
    localparam logic [7:0] NONCE_HIGH_ADDR     = 8'h1C;
    localparam logic [7:0] EVENT_COUNT_ADDR    = 8'h20;

    // =========================================
    // AXI4-LITE HSM REGISTER OFFSETS
    // =========================================

    localparam logic [31:0] HSM_CTRL_OFFSET         = 32'h00;
    localparam logic [31:0] HSM_STATUS_OFFSET       = 32'h04;
    localparam logic [31:0] HSM_ERROR_OFFSET        = 32'h08;
    localparam logic [31:0] HSM_LOCK_OFFSET         = 32'h0C;
    localparam logic [31:0] HSM_KEY_SLOT_OFFSET     = 32'h10;
    localparam logic [31:0] HSM_NONCE_STATUS_OFFSET = 32'h14;
    localparam logic [31:0] HSM_VERSION_OFFSET      = 32'h18;

    // =========================================
    // CONTROL REGISTER BITS
    // =========================================

    localparam int CTRL_START_BIT = 0;

    localparam int SEC_ENABLE_BIT = 0;
    localparam int SEC_LOCK_BIT   = 1;

    // =========================================
    // STATUS REGISTER BITS
    // =========================================

    localparam int AUTH_BIT        = 0;
    localparam int BUSY_BIT        = 1;
    localparam int LOCKED_BIT      = 2;
    localparam int FAULT_BIT       = 3;
    localparam int CRYPTO_DONE_BIT = 4;

    // =========================================
    // HSM CONSTANTS
    // =========================================

    localparam logic [31:0] HSM_LOCK_MAGIC =
        32'h4C4F434B;

    localparam logic [31:0] HSM_VERSION_VALUE =
        32'h0001_0000;

endpackage
