`timescale 1ns/1ps

module can_sva (

    input logic clk,
    input logic reset,

    input logic can_tx,
    input logic can_rx,

    input logic frame_active,
    input logic bit_error,
    input logic ack_error
);

    // CAN recessive state is logic HIGH
    property p_reset_safe;
        @(posedge clk)
        reset |=> can_tx;
    endproperty

    assert property (p_reset_safe)
        else $error("CAN FAIL: TX not recessive after reset");


    // TX/RX must be known
    property p_tx_known;
        @(posedge clk)
        !$isunknown(can_tx);
    endproperty

    assert property (p_tx_known)
        else $error("CAN FAIL: TX unknown");


    property p_rx_known;
        @(posedge clk)
        !$isunknown(can_rx);
    endproperty

    assert property (p_rx_known)
        else $error("CAN FAIL: RX unknown");


    // Valid frame should not have bit error
    property p_no_bit_error;
        @(posedge clk)
        frame_active |-> !bit_error;
    endproperty

    assert property (p_no_bit_error)
        else $error("CAN FAIL: Bit error during frame");


    // Valid frame should not have ACK error
    property p_no_ack_error;
        @(posedge clk)
        frame_active |-> !ack_error;
    endproperty

    assert property (p_no_ack_error)
        else $error("CAN FAIL: ACK error during frame");


    // Reset should not leave an active frame
    property p_reset_no_frame;
        @(posedge clk)
        reset |=> !frame_active;
    endproperty

    assert property (p_reset_no_frame)
        else $error("CAN FAIL: Frame active after reset");

endmodule