`timescale 1ns/1ps

module tb_spi_sva;

    logic clk;
    logic reset;

    logic cs_n;
    logic sclk;
    logic mosi;
    logic miso;

    spi_sva dut (
        .clk(clk),
        .reset(reset),
        .cs_n(cs_n),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

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


    initial begin

        reset = 1'b1;
        cs_n  = 1'b1;
        sclk  = 1'b0;
        mosi  = 1'b0;
        miso  = 1'b0;

        #20;

        reset = 1'b0;

        $display("SPI TEST 1: TRANSFER AA / CC");

        spi_transfer(
            8'hAA,
            8'hCC
        );

        $display("SPI TEST 2: TRANSFER D2 / 35");

        spi_transfer(
            8'hD2,
            8'h35
        );

        $display("SPI SVA TEST COMPLETED");

        #20;

        $finish;

    end

endmodule