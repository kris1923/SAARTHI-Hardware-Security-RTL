
`timescale 1ns/1ps

module can_sva (
    input  logic clk,
    input  logic reset,

    input  logic can_tx,
    input  logic can_rx,

    input  logic frame_active,
    input  logic bit_error,
    input  logic ack_error,

    output logic can_error_o
);

    // Sticky security-error flag.
    // Reset clears it; detected CAN faults set it.
    always_ff @(posedge clk) begin

        if (reset) begin
            can_error_o <= 1'b0;
        end
        else begin

            // Synthesizable CAN fault detection.
            if (frame_active && (bit_error || ack_error)) begin
                can_error_o <= 1'b1;
            end

`ifndef SYNTHESIS
            // Simulation-only X/Z detection.
            if ($isunknown(can_tx) || $isunknown(can_rx)) begin
                can_error_o <= 1'b1;
            end
`endif

        end
    end

    // Simulation-only CAN assertions.
`ifndef SYNTHESIS

    // CAN recessive state is logic HIGH.
    property p_reset_safe;
        @(posedge clk)
        reset |=> can_tx;
    endproperty

    assert property (p_reset_safe)
        else $error("CAN FAIL: TX not recessive after reset");

    // TX and RX must be known.
    property p_tx_known;
        @(posedge clk)
        disable iff (reset)
        !$isunknown(can_tx);
    endproperty

    assert property (p_tx_known)
        else $error("CAN FAIL: TX unknown");

    property p_rx_known;
        @(posedge clk)
        disable iff (reset)
        !$isunknown(can_rx);
    endproperty

    assert property (p_rx_known)
        else $error("CAN FAIL: RX unknown");

    // A frame must not have a bit error.
    property p_no_bit_error;
        @(posedge clk)
        disable iff (reset)
        frame_active |-> !bit_error;
    endproperty

    assert property (p_no_bit_error)
        else $error("CAN FAIL: Bit error during frame");

    // A frame must not have an ACK error.
    property p_no_ack_error;
        @(posedge clk)
        disable iff (reset)
        frame_active |-> !ack_error;
    endproperty

    assert property (p_no_ack_error)
        else $error("CAN FAIL: ACK error during frame");

    // Reset must not leave a frame active.
    property p_reset_no_frame;
        @(posedge clk)
        reset |=> !frame_active;
    endproperty

    assert property (p_reset_no_frame)
        else $error("CAN FAIL: Frame active after reset");

`endif

endmodule
