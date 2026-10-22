
`timescale 1ns/1ps

module hsm_security_integration (
    input logic clk,
    input logic rst_n,

    // External security events
    input logic spi_event_i,
    input logic i2c_event_i,
    input logic can_event_i,
    input logic hsm_event_i,

    // SPI monitor inputs
    input logic spi_cs_n_i,
    input logic spi_sclk_i,
    input logic spi_mosi_i,
    input logic spi_miso_i,

    // I2C monitor inputs
    input logic i2c_scl_i,
    input logic i2c_sda_i,

    // CAN monitor inputs
    input logic can_tx_i,
    input logic can_rx_i,
    input logic can_frame_active_i,
    input logic can_bit_error_i,
    input logic can_ack_error_i,

    // AXI-Lite write address
    input logic [31:0] s_axi_awaddr,
    input logic s_axi_awvalid,
    output logic s_axi_awready,

    // AXI-Lite write data
    input logic [31:0] s_axi_wdata,
    input logic [3:0] s_axi_wstrb,
    input logic s_axi_wvalid,
    output logic s_axi_wready,

    // AXI-Lite write response
    output logic [1:0] s_axi_bresp,
    output logic s_axi_bvalid,
    input logic s_axi_bready,

    // AXI-Lite read address
    input logic [31:0] s_axi_araddr,
    input logic s_axi_arvalid,
    output logic s_axi_arready,

    // AXI-Lite read data
    output logic [31:0] s_axi_rdata,
    output logic [1:0] s_axi_rresp,
    output logic s_axi_rvalid,
    input logic s_axi_rready,

    // HSM control inputs
    input logic authenticated_i,
    input logic engine_busy_i,
    input logic engine_done_i,
    input logic [31:0] nonce_count_i,
    input logic nonce_ready_i,

    // HSM outputs
    output logic engine_start_o,
    output logic [31:0] key_slot_o,
    output logic security_event_o,
    output logic hsm_locked_o,

    // Protocol monitor status
    output logic spi_monitor_error_o,
    output logic i2c_monitor_error_o,
    output logic can_monitor_error_o
);

    logic hsm_internal_event;
    logic event_interface_lock;

    logic spi_combined_event;
    logic i2c_combined_event;
    logic can_combined_event;

    // Combine external events and monitor faults.
    assign spi_combined_event =
        spi_event_i | spi_monitor_error_o;

    assign i2c_combined_event =
        i2c_event_i | i2c_monitor_error_o;

    assign can_combined_event =
        can_event_i | can_monitor_error_o;

    // SPI protocol monitor
    spi_sva u_spi_sva (
        .clk(clk),
        .reset(~rst_n),
        .cs_n(spi_cs_n_i),
        .sclk(spi_sclk_i),
        .mosi(spi_mosi_i),
        .miso(spi_miso_i),
        .spi_error_o(spi_monitor_error_o)
    );

    // I2C protocol monitor
    i2c_sva u_i2c_sva (
        .clk(clk),
        .reset(~rst_n),
        .scl(i2c_scl_i),
        .sda(i2c_sda_i),
        .i2c_error_o(i2c_monitor_error_o)
    );

    // CAN protocol monitor
    can_sva u_can_sva (
        .clk(clk),
        .reset(~rst_n),
        .can_tx(can_tx_i),
        .can_rx(can_rx_i),
        .frame_active(can_frame_active_i),
        .bit_error(can_bit_error_i),
        .ack_error(can_ack_error_i),
        .can_error_o(can_monitor_error_o)
    );

    // Common security-event bus
    security_event_if u_security_event_if (
        .clk(clk),
        .rst_n(rst_n),
        .spi_event_i(spi_combined_event),
        .i2c_event_i(i2c_combined_event),
        .can_event_i(can_combined_event),
        .hsm_event_i(hsm_event_i | hsm_internal_event),
        .security_event_o(security_event_o),
        .hsm_locked_o(event_interface_lock)
    );

    // AXI-Lite HSM register block
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
