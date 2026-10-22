
`timescale 1ns/1ps

module tb_spi_sva;

    logic clk;
    logic reset;

    logic cs_n;
    logic sclk;
    logic mosi;
    logic miso;

    // SPI monitor error output
    logic spi_error;

    // DUT: SPI Assertion Checker
    spi_sva dut (
        .clk(clk),
        .reset(reset),
        .cs_n(cs_n),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .spi_error_o(spi_error)
    );

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // SPI transfer task
    task spi_transfer;
        input [7:0] tx_data;
        input [7:0] rx_data;

        integer i;

        begin
            cs_n = 1'b0;
            sclk = 1'b0;

            for (i = 7; i >= 0; i = i - 1) begin
                mosi = tx_data[i];
                miso = rx_data[i];

                #5;
                sclk = 1'b1;

                #5;
                sclk = 1'b0;
            end

            cs_n = 1'b1;
            #10;
        end
    endtask

    // Main test sequence
    initial begin
        reset = 1'b1;
        cs_n  = 1'b1;
        sclk  = 1'b0;
        mosi  = 1'b0;
        miso  = 1'b0;

        #20;
        reset = 1'b0;

        $display("-----------------------------------");
        $display("SPI SVA TEST STARTED");
        $display("-----------------------------------");

        $display("TEST 1: SPI TRANSFER AA / CC");
        spi_transfer(8'hAA, 8'hCC);

        if (spi_error === 1'b0)
            $display("PASS: No SPI error during AA / CC");
        else
            $error("FAIL: Unexpected SPI error during AA / CC");

        $display("TEST 2: SPI TRANSFER D2 / 35");
        spi_transfer(8'hD2, 8'h35);

        if (spi_error === 1'b0)
            $display("PASS: No SPI error during D2 / 35");
        else
            $error("FAIL: Unexpected SPI error during D2 / 35");

        $display("-----------------------------------");
        $display("SPI SVA TEST COMPLETED");
        $display("-----------------------------------");

        #20;
        $finish;
    end

endmodule
