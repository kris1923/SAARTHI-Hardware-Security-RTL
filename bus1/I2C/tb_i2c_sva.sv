`timescale 1ns/1ps

module tb_i2c_sva;

    logic clk;
    logic reset;

    logic scl;
    logic sda;

    i2c_sva dut (
        .clk(clk),
        .reset(reset),
        .scl(scl),
        .sda(sda)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    task i2c_start;

        begin

            scl = 1'b1;
            sda = 1'b1;

            #10;

            sda = 1'b0;

            #10;

            scl = 1'b0;

        end

    endtask


    task i2c_stop;

        begin

            scl = 1'b1;
            sda = 1'b0;

            #10;

            sda = 1'b1;

            #10;

        end

    endtask


    task i2c_write_byte;

        input [7:0] data;

        integer i;

        begin

            for (i = 7; i >= 0; i = i - 1) begin

                scl = 1'b0;
                sda = data[i];

                #10;

                scl = 1'b1;

                #10;

            end

            scl = 1'b0;

            sda = 1'b0;

            #10;

            scl = 1'b1;

            #10;

            scl = 1'b0;

            sda = 1'b1;

        end

    endtask


    initial begin

        reset = 1'b1;

        scl = 1'b1;
        sda = 1'b1;

        #20;

        reset = 1'b0;

        #10;

        $display("I2C TEST 1: START");

        i2c_start();

        $display("I2C TEST 2: ADDRESS + WRITE");

        i2c_write_byte(8'hA0);

        $display("I2C TEST 3: DATA");

        i2c_write_byte(8'hCC);

        $display("I2C TEST 4: STOP");

        i2c_stop();

        #20;

        $display("I2C SVA TEST COMPLETED");

        $finish;

    end

endmodule