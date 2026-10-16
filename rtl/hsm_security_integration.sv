
`timescale 1ns/1ps

module hsm_security_integration (
    input logic clk,
    input logic rst_n,

    input logic spi_event_i,
    input logic i2c_event_i,
    input logic can_event_i,
    input logic hsm_event_i,

    input logic [31:0] s_axi_awaddr,
    input logic s_axi_awvalid,
    output logic s_axi_awready,

    input logic [31:0] s_axi_wdata,
    input logic [3:0] s_axi_wstrb,
    input logic s_axi_wvalid,
    output logic s_axi_wready,

    output logic [1:0] s_axi_bresp,
    output logic s_axi_bvalid,
    input logic s_axi_bready,

    input logic [31:0] s_axi_araddr,
    input logic s_axi_arvalid,
    output logic s_axi_arready,

    output logic [31:0] s_axi_rdata,
    output logic [1:0] s_axi_rresp,
    output logic s_axi_rvalid,
    input logic s_axi_rready,

    input logic authenticated_i,
    input logic engine_busy_i,
    input logic engine_done_i,
    input logic [31:0] nonce_count_i,
    input logic nonce_ready_i,

    output logic engine_start_o,
    output logic [31:0] key_slot_o,
    output logic security_event_o,
    output logic hsm_locked_o
);

    logic hsm_internal_event;
    logic event_interface_lock;

    security_event_if u_security_event_if (
        .clk(clk),
        .rst_n(rst_n),
        .spi_event_i(spi_event_i),
        .i2c_event_i(i2c_event_i),
        .can_event_i(can_event_i),
        .hsm_event_i(hsm_event_i | hsm_internal_event),
        .security_event_o(security_event_o),
        .hsm_locked_o(event_interface_lock)
    );

    hsm_axi_lite_regs u_hsm_axi_lite_regs (
        .clk(clk),
        .rst_n(rst_n),

        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),

        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),

        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),

        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),

        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        .authenticated_i(authenticated_i),
        .security_error_i(hsm_event_i),
        .external_lock_i(event_interface_lock),

        .engine_busy_i(engine_busy_i),
        .engine_done_i(engine_done_i),
        .nonce_count_i(nonce_count_i),
        .nonce_ready_i(nonce_ready_i),

        .engine_start_o(engine_start_o),
        .key_slot_o(key_slot_o),
        .hsm_locked_o(hsm_locked_o),
        .security_event_o(hsm_internal_event)
    );

endmodule
