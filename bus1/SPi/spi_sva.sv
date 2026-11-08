`timescale 1ns/1ps

module spi_sva (
    input  logic clk,
    input  logic reset,
    input  logic cs_n,
    input  logic sclk,
    input  logic mosi,
    input  logic miso,

    output logic spi_error_o
);

    logic sclk_prev;

    // Synthesizable SPI monitoring logic.
    // Detect an SCLK rising edge while chip select is inactive.
    always_ff @(posedge clk) begin
        if (reset) begin
            spi_error_o <= 1'b0;
            sclk_prev   <= 1'b0;
        end
        else begin
            if (cs_n && sclk && !sclk_prev) begin
                spi_error_o <= 1'b1;
            end

            // Simulation-only X/Z detection.
`ifndef SYNTHESIS
            if (!cs_n &&
                ($isunknown(mosi) || $isunknown(miso))) begin
                spi_error_o <= 1'b1;
            end
`endif

            sclk_prev <= sclk;
        end
    end

    // Simulation-only assertions.
`ifndef SYNTHESIS

    // SPI clock must not have a rising edge while CS is inactive.
    property p_spi_selected;
        @(posedge sclk)
        disable iff (reset)
        !cs_n;
    endproperty

    assert property (p_spi_selected)
        else $error("SPI FAIL: SCLK edge while CS inactive");

    // MOSI must be known when sampled.
    property p_mosi_known;
        @(posedge sclk)
        disable iff (reset)
        !cs_n |-> !$isunknown(mosi);
    endproperty

    assert property (p_mosi_known)
        else $error("SPI FAIL: MOSI is unknown");

    // MISO must be known when sampled.
    property p_miso_known;
        @(posedge sclk)
        disable iff (reset)
        !cs_n |-> !$isunknown(miso);
    endproperty

    assert property (p_miso_known)
        else $error("SPI FAIL: MISO is unknown");

    // CS must be inactive during reset.
    property p_reset_spi_safe;
        @(posedge clk)
        reset |-> cs_n;
    endproperty

    assert property (p_reset_spi_safe)
        else $error("SPI FAIL: CS active during reset");

`endif

endmodule