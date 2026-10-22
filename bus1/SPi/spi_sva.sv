
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

    // Track SPI protocol violations for the security-event bus.
    // This is a sticky error: reset clears it.
    always_ff @(posedge clk) begin
        if (reset) begin
            spi_error_o <= 1'b0;
        end
        else begin
            if ((!cs_n && ($isunknown(mosi) || $isunknown(miso))) ||
                (reset && !cs_n)) begin
                spi_error_o <= 1'b1;
            end
        end
    end

    // Chip select must be active when SPI data is sampled.
    property p_spi_selected;
        @(posedge sclk)
        !cs_n;
    endproperty

    assert property (p_spi_selected)
        else $error("SPI FAIL: SCLK edge while CS inactive");

    // MOSI must be known when sampled.
    property p_mosi_known;
        @(posedge sclk)
        !cs_n |-> !$isunknown(mosi);
    endproperty

    assert property (p_mosi_known)
        else $error("SPI FAIL: MOSI is unknown");

    // MISO must be known when sampled.
    property p_miso_known;
        @(posedge sclk)
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

endmodule
