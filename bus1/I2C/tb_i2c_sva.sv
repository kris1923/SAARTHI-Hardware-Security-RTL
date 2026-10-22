`timescale 1ns/1ps

module tb_i2c_sva;

logic clk;
    logic reset;

logic scl;
    logic sda;

    logic i2c_error;

// I2C assertion checker
    i2c_sva dut (
        .clk(clk),
        .reset(reset),
        .scl(scl),
        .sda(sda),
        .i2c_error_o(i2c_error)
    );

// Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

// Generate I2C START condition
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

// Generate I2C STOP condition
    task i2c_stop;
        begin
            scl = 1'b1;
            sda = 1'b0;
            #10;

sda = 1'b1;
            #10;
        end
    endtask

// Send one byte and generate an ACK clock.
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

// ACK clock (simplified testbench model)
            scl = 1'b0;
            sda = 1'b0;
            #10;

scl = 1'b1;
            #10;

scl = 1'b0;
            sda = 1'b1;
        end
    endtask

// Main test sequence
    initial begin
        reset = 1'b1;
        scl = 1'b1;
        sda = 1'b1;

#20;
        reset = 1'b0;
        #10;

$display("-----------------------------------");
        $display("I2C SVA TEST STARTED");
        $display("-----------------------------------");

$display("TEST 1: START CONDITION");
        i2c_start();

$display("TEST 2: ADDRESS + WRITE (A0)");
        i2c_write_byte(8'hA0);

$display("TEST 3: DATA (CC)");
        i2c_write_byte(8'hCC);

$display("TEST 4: STOP CONDITION");
        i2c_stop();

        #20;

if (i2c_error === 1'b0)
            $display("PASS: No unknown-signal I2C error detected");
        else
            $display("CHECK: I2C error flag is HIGH");

$display("-----------------------------------");
        $display("I2C SVA TEST COMPLETED");
        $display("-----------------------------------");

$finish;
    end

endmodule