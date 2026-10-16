`timescale 1ns/1ps

module tb_can_sva;

    logic clk;
    logic reset;

    logic can_tx;
    logic can_rx;

    logic frame_active;
    logic bit_error;
    logic ack_error;

    can_sva dut (
        .clk(clk),
        .reset(reset),
        .can_tx(can_tx),
        .can_rx(can_rx),
        .frame_active(frame_active),
        .bit_error(bit_error),
        .ack_error(ack_error)
    );

    initial begin
        clk = 0;
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

        // TEST 1
        $display("CAN TEST 1: IDLE");

        #20;

        // TEST 2
        $display("CAN TEST 2: VALID FRAME");

        frame_active = 1'b1;

        can_tx = 1'b0;
        can_rx = 1'b0;

        #30;

        // TEST 3
        $display("CAN TEST 3: FRAME COMPLETE");

        frame_active = 1'b0;

        can_tx = 1'b1;
        can_rx = 1'b1;

        #20;

        $display("CAN SVA TEST COMPLETED");

        $finish;

    end

endmodule