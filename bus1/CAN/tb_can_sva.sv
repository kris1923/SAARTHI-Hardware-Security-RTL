`timescale 1ns/1ps

module tb_can_sva;

logic clk;
    logic reset;

logic can_tx;
    logic can_rx;

logic frame_active;
    logic bit_error;
    logic ack_error;

    logic can_error;

// CAN assertion checker
    can_sva dut (
        .clk(clk),
        .reset(reset),
        .can_tx(can_tx),
        .can_rx(can_rx),
        .frame_active(frame_active),
        .bit_error(bit_error),
        .ack_error(ack_error),
        .can_error_o(can_error)
    );

// Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

initial begin
        reset        = 1'b1;
        can_tx       = 1'b1;
        can_rx       = 1'b1;
        frame_active = 1'b0;
        bit_error    = 1'b0;
        ack_error    = 1'b0;

#20;
        reset = 1'b0;

// TEST 1: Idle
        $display("-----------------------------------");
        $display("CAN SVA TEST STARTED");
        $display("TEST 1: IDLE");
        #20;

if (can_error === 1'b0)
            $display("PASS: No CAN error during idle");
        else
            $error("FAIL: Unexpected CAN error during idle");

// TEST 2: Normal frame
        $display("TEST 2: VALID FRAME");

frame_active = 1'b1;
        can_tx = 1'b0;
        can_rx = 1'b0;

        #30;

if (can_error === 1'b0)
            $display("PASS: No CAN error during valid frame");
        else
            $error("FAIL: Unexpected CAN error during valid frame");

// TEST 3: Inject a bit error
        $display("TEST 3: INJECT BIT ERROR");

bit_error = 1'b1;
        #10;

if (can_error === 1'b1)
            $display("PASS: CAN bit error detected");
        else
            $error("FAIL: CAN bit error was not detected");

// End the frame and clear stimulus fault.
        frame_active = 1'b0;
        bit_error = 1'b0;
        can_tx = 1'b1;
        can_rx = 1'b1;

        #20;

// TEST 4: Verify sticky error remains set
        $display("TEST 4: CHECK STICKY ERROR FLAG");

if (can_error === 1'b1)
            $display("PASS: CAN error flag remains set");
        else
            $error("FAIL: CAN error flag did not remain set");

$display("-----------------------------------");
        $display("CAN SVA TEST COMPLETED");
        $finish;
    end

endmodule