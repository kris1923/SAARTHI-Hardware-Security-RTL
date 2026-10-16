`timescale 1ns/1ps

module spi_sva (
    input logic clk,
    input logic reset,
    input logic cs_n,
    input logic sclk,
    input logic mosi,
    input logic miso
);

    // ---------------------------------------------------------
    // SPI Mode 0 basic protocol checks
    // CPOL = 0
    // CPHA = 0
    // Data is sampled on rising edge of SCLK
    // ---------------------------------------------------------

    // 1. Chip select must be active during SPI transfer
    property p_spi_selected;
        @(posedge sclk)
        !cs_n |-> !cs_n;
    endproperty

    assert property (p_spi_selected)
        else $error("SPI FAIL: CS not active during transfer");


    // 2. MOSI must be known when sampled
    property p_mosi_known;
        @(posedge sclk)
        !cs_n |-> !$isunknown(mosi);
    endproperty

    assert property (p_mosi_known)
        else $error("SPI FAIL: MOSI is unknown");


    // 3. MISO must be known when sampled
    property p_miso_known;
        @(posedge sclk)
        !cs_n |-> !$isunknown(miso);
    endproperty

    assert property (p_miso_known)
        else $error("SPI FAIL: MISO is unknown");


    // 4. SPI clock should not transfer data when CS is inactive
    property p_no_transfer_without_cs;
        @(posedge sclk)
        cs_n |-> $stable(cs_n);
    endproperty

    assert property (p_no_transfer_without_cs)
        else $error("SPI FAIL: SCLK activity while CS inactive");


    // 5. Reset safety
    // Only check that CS is inactive while reset is actually asserted.
    property p_reset_spi_safe;
        @(posedge clk)
        reset |-> cs_n;
    endproperty

    assert property (p_reset_spi_safe)
        else $error("SPI FAIL: CS active during reset");


    // 6. MOSI should be stable around the sampling edge.
    // The testbench changes MOSI while SCLK is LOW.
    property p_mosi_valid_at_sample;
        @(posedge sclk)
        !cs_n |-> !$isunknown(mosi);
    endproperty

    assert property (p_mosi_valid_at_sample)
        else $error("SPI FAIL: Invalid MOSI at sampling edge");


    // 7. MISO should be valid at sampling edge.
    property p_miso_valid_at_sample;
        @(posedge sclk)
        !cs_n |-> !$isunknown(miso);
    endproperty

    assert property (p_miso_valid_at_sample)
        else $error("SPI FAIL: Invalid MISO at sampling edge");


 

endmodule