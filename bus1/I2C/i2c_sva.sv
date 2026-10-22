
`timescale 1ns/1ps

module i2c_sva (
    input  logic clk,
    input  logic reset,
    input  logic scl,
    input  logic sda,

    output logic i2c_error_o
);

    logic sda_prev;
    logic prev_valid;

    logic start_detected;
    logic stop_detected;
    logic illegal_sda_change;

    // Detect START and STOP conditions at the sampling clock.
    // START: SDA falls while SCL remains HIGH.
    // STOP:  SDA rises while SCL remains HIGH.
    always_comb begin
        start_detected =
            (scl === 1'b1) &&
            (sda_prev === 1'b1) &&
            (sda === 1'b0);

        stop_detected =
            (scl === 1'b1) &&
            (sda_prev === 1'b0) &&
            (sda === 1'b1);

        // An SDA transition while SCL is HIGH is legal only
        // when it represents START or STOP.
        illegal_sda_change =
            prev_valid &&
            (scl === 1'b1) &&
            (sda !== sda_prev) &&
            !start_detected &&
            !stop_detected;
    end

    // Track the previous known SDA sample.
    always_ff @(posedge clk) begin
        if (reset) begin
            sda_prev   <= 1'b1;
            prev_valid <= 1'b0;
        end
        else if (!$isunknown(sda)) begin
            sda_prev   <= sda;
            prev_valid <= 1'b1;
        end
        else begin
            prev_valid <= 1'b0;
        end
    end

    // Sticky security error: stays high until reset.
    always_ff @(posedge clk) begin
        if (reset) begin
            i2c_error_o <= 1'b0;
        end
        else if ($isunknown(scl) ||
                 $isunknown(sda) ||
                 illegal_sda_change) begin
            i2c_error_o <= 1'b1;
        end
    end

    // Assertions for unknown signal values.
    property p_scl_known;
        @(posedge clk)
        disable iff (reset)
        !$isunknown(scl);
    endproperty

    property p_sda_known;
        @(posedge clk)
        disable iff (reset)
        !$isunknown(sda);
    endproperty

    assert property (p_scl_known)
        else $error("I2C FAIL: SCL unknown");

    assert property (p_sda_known)
        else $error("I2C FAIL: SDA unknown");

    // An SDA transition during SCL HIGH must be START or STOP.
    property p_sda_change_high_is_start_or_stop;
        @(posedge clk)
        disable iff (reset)
        (prev_valid &&
         (scl === 1'b1) &&
         (sda !== sda_prev))
        |-> (start_detected || stop_detected);
    endproperty

    assert property (p_sda_change_high_is_start_or_stop)
        else $error("I2C FAIL: Illegal SDA transition while SCL HIGH");

endmodule
