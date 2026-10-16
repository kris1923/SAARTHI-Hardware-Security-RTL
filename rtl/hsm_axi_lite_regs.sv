
`timescale 1ns/1ps

module hsm_axi_lite_regs (
    input  logic        clk,
    input  logic        rst_n,

    // AXI4-Lite write address channel
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,

    // AXI4-Lite write data channel
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,

    // AXI4-Lite write response channel
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    // AXI4-Lite read address channel
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,

    // AXI4-Lite read data channel
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // Security and engine inputs
    input  logic        authenticated_i,
    input  logic        security_error_i,
    input  logic        external_lock_i,
    input  logic        engine_busy_i,
    input  logic        engine_done_i,

    input  logic [31:0] nonce_count_i,
    input  logic        nonce_ready_i,

    // HSM outputs
    output logic        engine_start_o,
    output logic [31:0] key_slot_o,
    output logic        hsm_locked_o,
    output logic        security_event_o
);

    import hsm_regs_pkg::*;

    logic aw_hold;
    logic w_hold;

    logic [31:0] awaddr_hold;
    logic [31:0] wdata_hold;
    logic [3:0]  wstrb_hold;

    logic [31:0] key_slot_reg;
    logic locked_reg;
    logic done_reg;
    logic error_reg;

    wire aw_take = s_axi_awvalid && s_axi_awready;
    wire w_take  = s_axi_wvalid  && s_axi_wready;

    wire wr_fire =
        !s_axi_bvalid &&
        (aw_hold || aw_take) &&
        (w_hold  || w_take);

    wire [31:0] wr_addr =
        aw_hold ? awaddr_hold : s_axi_awaddr;

    wire [31:0] wr_data =
        w_hold ? wdata_hold : s_axi_wdata;

    wire [3:0] wr_strb =
        w_hold ? wstrb_hold : s_axi_wstrb;

    wire effective_lock = locked_reg | external_lock_i;

    assign s_axi_awready = !aw_hold && !s_axi_bvalid;
    assign s_axi_wready  = !w_hold  && !s_axi_bvalid;
    assign s_axi_arready = !s_axi_rvalid;

    assign key_slot_o   = key_slot_reg;
    assign hsm_locked_o = effective_lock;

    // Capture write address and write data independently.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            aw_hold     <= 1'b0;
            w_hold      <= 1'b0;
            awaddr_hold <= 32'b0;
            wdata_hold  <= 32'b0;
            wstrb_hold  <= 4'b0;
        end else begin
            if (aw_take) begin
                aw_hold     <= 1'b1;
                awaddr_hold <= s_axi_awaddr;
            end

            if (w_take) begin
                w_hold     <= 1'b1;
                wdata_hold <= s_axi_wdata;
                wstrb_hold <= s_axi_wstrb;
            end

            if (wr_fire) begin
                aw_hold <= 1'b0;
                w_hold  <= 1'b0;
            end
        end
    end

    // AXI-Lite write response and register update logic.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_axi_bvalid     <= 1'b0;
            s_axi_bresp      <= 2'b00;

            key_slot_reg     <= 32'b0;
            locked_reg       <= 1'b0;
            done_reg         <= 1'b0;
            error_reg        <= 1'b0;

            engine_start_o   <= 1'b0;
            security_event_o <= 1'b0;
        end else begin
            engine_start_o   <= 1'b0;
            security_event_o <= 1'b0;

            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;

            if (engine_done_i)
                done_reg <= 1'b1;

            if (security_error_i) begin
                error_reg        <= 1'b1;
                locked_reg       <= 1'b1;
                security_event_o <= 1'b1;
            end

            if (wr_fire) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;

                if (wr_strb != 4'b1111) begin
                    s_axi_bresp <= 2'b10;
                end else begin
                    case (wr_addr)

                        HSM_CTRL_OFFSET: begin
                            if (wr_data[CTRL_START_BIT]) begin
                                done_reg <= 1'b0;

                                if (authenticated_i &&
                                    !security_error_i &&
                                    !effective_lock) begin
                                    engine_start_o <= 1'b1;
                                end else begin
                                    error_reg        <= 1'b1;
                                    security_event_o <= 1'b1;
                                end
                            end
                        end

                        HSM_ERROR_OFFSET: begin
                            if (!effective_lock && wr_data[0]) begin
                                error_reg <= 1'b0;
                            end else if (effective_lock) begin
                                s_axi_bresp      <= 2'b10;
                                security_event_o <= 1'b1;
                            end
                        end

                        HSM_LOCK_OFFSET: begin
                            if (wr_data == HSM_LOCK_MAGIC) begin
                                locked_reg <= 1'b1;
                            end else begin
                                s_axi_bresp <= 2'b10;
                                error_reg   <= 1'b1;
                            end
                        end

                        HSM_KEY_SLOT_OFFSET: begin
                            if (!effective_lock) begin
                                key_slot_reg <= wr_data;
                            end else begin
                                s_axi_bresp      <= 2'b10;
                                error_reg        <= 1'b1;
                                security_event_o <= 1'b1;
                            end
                        end

                        default: begin
                            s_axi_bresp <= 2'b10;
                        end

                    endcase
                end
            end
        end
    end

    // AXI-Lite read register logic.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata  <= 32'b0;
            s_axi_rresp  <= 2'b00;
        end else begin
            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 1'b0;

            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;

                case (s_axi_araddr)

                    HSM_CTRL_OFFSET:
                        s_axi_rdata <= 32'b0;

                    HSM_STATUS_OFFSET:
                        s_axi_rdata <= {
                            27'b0,
                            nonce_ready_i,
                            authenticated_i,
                            effective_lock,
                            done_reg,
                            engine_busy_i
                        };

                    HSM_ERROR_OFFSET:
                        s_axi_rdata <= {31'b0, error_reg};

                    HSM_LOCK_OFFSET:
                        s_axi_rdata <= {31'b0, effective_lock};

                    HSM_KEY_SLOT_OFFSET:
                        s_axi_rdata <= key_slot_reg;

                    HSM_NONCE_STATUS_OFFSET:
                        s_axi_rdata <= nonce_count_i;

                    HSM_VERSION_OFFSET:
                        s_axi_rdata <= HSM_VERSION_VALUE;

                    default: begin
                        s_axi_rdata <= 32'b0;
                        s_axi_rresp <= 2'b10;
                    end

                endcase
            end
        end
    end

endmodule
