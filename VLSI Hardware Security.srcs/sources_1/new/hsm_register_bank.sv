
`timescale 1ns/1ps

module hsm_register_bank (
    input  logic        clk,
    input  logic        rst_n,

    // Internal register interface
    input  logic        wr_en,
    input  logic [7:0]  wr_addr,
    input  logic [31:0] wr_data,

    input  logic [7:0]  rd_addr,
    output logic [31:0] rd_data,

    // Security inputs
    input  logic        auth_ok,
    input  logic        crypto_busy,
    input  logic        crypto_done,
    input  logic        security_fault,
    input  logic [7:0]  security_fault_code,

    // Security event inputs
    input  logic        nonce_consume,
    input  logic        event_valid,

    // HSM outputs
    output logic        hsm_enable,
    output logic        hsm_locked,
    output logic        crypto_start,
    output logic [3:0]  key_slot_sel,
    output logic [63:0] nonce_counter,
    output logic [31:0] event_count
);

    import hsm_regs_pkg::*;

    logic        fault_latched;
    logic [7:0]  fault_code;

    // Synchronous active-low reset
    always_ff @(posedge clk) begin

        if (!rst_n) begin
            hsm_enable    <= 1'b0;
            hsm_locked    <= 1'b0;
            crypto_start  <= 1'b0;
            key_slot_sel  <= 4'b0000;

            nonce_counter <= 64'd0;
            event_count   <= 32'd0;

            fault_latched <= 1'b0;
            fault_code    <= 8'h00;
        end

        else begin

            // Default: one-cycle crypto start pulse
            crypto_start <= 1'b0;

            // Security fault capture
            if (security_fault) begin
                fault_latched <= 1'b1;
                fault_code    <= security_fault_code;
            end

            // Persistent nonce counter
            if (nonce_consume &&
                nonce_counter != 64'hFFFF_FFFF_FFFF_FFFF) begin
                nonce_counter <= nonce_counter + 1'b1;
            end

            // Saturating security event counter
            if (event_valid &&
                event_count != 32'hFFFF_FFFF) begin
                event_count <= event_count + 1'b1;
            end

            // Register write operations
            if (wr_en) begin

                case (wr_addr)

                    // Security control register
                    SEC_CTRL_ADDR: begin

                        if (!hsm_locked) begin

                            // Lock request takes priority.
                            // Preserve the existing enable state.
                            if (wr_data[SEC_LOCK_BIT]) begin
                                hsm_locked <= 1'b1;
                            end
                            else begin
                                hsm_enable <= wr_data[SEC_ENABLE_BIT];
                            end

                        end
                    end

                    // Key-slot selection
                    KEY_CTRL_ADDR: begin
                        if (hsm_enable && !hsm_locked && auth_ok)
                            key_slot_sel <= wr_data[3:0];
                    end

                    // Start cryptographic operation
                    CRYPTO_CMD_ADDR: begin
                        if (wr_data[0]) begin

                            if (hsm_enable &&
                                !hsm_locked &&
                                auth_ok &&
                                !fault_latched &&
                                !security_fault &&
                                !crypto_busy) begin

                                crypto_start <= 1'b1;

                            end
                            else begin
                                fault_latched <= 1'b1;
                                fault_code    <= 8'h02;
                            end

                        end
                    end

                    // Fault status: write 1 to clear
                    SEC_FAULT_ADDR: begin
                        if (wr_data[0] &&
                            !security_fault &&
                            !hsm_locked) begin

                            fault_latched <= 1'b0;
                            fault_code    <= 8'h00;
                        end
                    end

                    // All other registers are read-only
                    default: begin
                    end

                endcase
            end
        end
    end

    // Register read multiplexer
    always_comb begin

        rd_data = 32'h0000_0000;

        case (rd_addr)

            SEC_CTRL_ADDR: begin
                rd_data[SEC_ENABLE_BIT] = hsm_enable;
                rd_data[SEC_LOCK_BIT]   = hsm_locked;
            end

            SEC_STATUS_ADDR: begin
                rd_data[AUTH_BIT]        = auth_ok;
                rd_data[BUSY_BIT]        = crypto_busy;
                rd_data[LOCKED_BIT]      = hsm_locked;
                rd_data[FAULT_BIT]       = fault_latched;
                rd_data[CRYPTO_DONE_BIT] = crypto_done;
            end

            SEC_FAULT_ADDR: begin
                rd_data = {24'h0, fault_code};
            end

            KEY_CTRL_ADDR: begin
                rd_data[3:0] = key_slot_sel;
            end

            CRYPTO_STATUS_ADDR: begin
                rd_data[0] = crypto_busy;
                rd_data[1] = crypto_done;
            end

            NONCE_LOW_ADDR: begin
                rd_data = nonce_counter[31:0];
            end

            NONCE_HIGH_ADDR: begin
                rd_data = nonce_counter[63:32];
            end

            EVENT_COUNT_ADDR: begin
                rd_data = event_count;
            end

            default: begin
                rd_data = 32'h0000_0000;
            end

        endcase
    end

endmodule
