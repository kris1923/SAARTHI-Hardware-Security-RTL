`timescale 1ns/1ps

module i2c_sva (
    input  logic clk,
    input  logic reset,
    input  logic scl,
    input  logic sda,

    output logic i2c_error_o
);

    logic sda_prev;
    logic scl_prev;
    logic prev_valid;

    logic sda_changed;
    logic start_detected;
    logic stop_detected;
    logic illegal_sda_change;

    // Detect SDA transitions between clock samples.
    always_comb begin

        sda_changed =
            prev_valid &&
`ifndef SYNTHESIS
            !$isunknown(sda) &&
`endif
            (sda != sda_prev);

        // START: SDA changes HIGH to LOW while SCL is HIGH.
        start_detected =
            sda_changed &&
            (sda_prev == 1'b1) &&
            (sda == 1'b0) &&
            (scl == 1'b1);

        // STOP: SDA changes LOW to HIGH while SCL is HIGH.
        stop_detected =
            sda_changed &&
            (sda_prev == 1'b0) &&
            (sda == 1'b1) &&
            (scl == 1'b1);

        // SDA must remain stable while SCL is HIGH,
        // except during START and STOP.
        illegal_sda_change =
            sda_changed &&
            (scl == 1'b1) &&
            !start_detected &&
            !stop_detected;

    end

    // Store previous bus samples.
    always_ff @(posedge clk) begin

        if (reset) begin
            sda_prev   <= 1'b1;
            scl_prev   <= 1'b1;
            prev_valid <= 1'b0;
        end
        else begin

`ifndef SYNTHESIS
            // Simulation-only handling of unknown bus values.
            if (!$isunknown(scl) && !$isunknown(sda)) begin
                sda_prev   <= sda;
                scl_prev   <= scl;
                prev_valid <= 1'b1;
            end
            else begin
                prev_valid <= 1'b0;
            end
`else
            // Synthesizable sampling logic.
            sda_prev   <= sda;
            scl_prev   <= scl;
            prev_valid <= 1'b1;
`endif

        end
    end

    // Sticky I2C security error.
    // Cleared only by reset.
    always_ff @(posedge clk) begin

        if (reset) begin
            i2c_error_o <= 1'b0;
        end
        else begin

            if (illegal_sda_change) begin
                i2c_error_o <= 1'b1;
            end

`ifndef SYNTHESIS
            // Simulation-only X/Z detection.
            if ($isunknown(scl) || $isunknown(sda)) begin
                i2c_error_o <= 1'b1;
            end
`endif

        end
    end

    // Simulation-only assertions.
`ifndef SYNTHESIS

    // SCL must be known.
    property p_scl_known;
        @(posedge clk)
        disable iff (reset)
        !$isunknown(scl);
    endproperty

    assert property (p_scl_known)
        else $error("I2C FAIL: SCL unknown");

    // SDA must be known.
    property p_sda_known;
        @(posedge clk)
        disable iff (reset)
        !$isunknown(sda);
    endproperty

    assert property (p_sda_known)
        else $error("I2C FAIL: SDA unknown");

    // SDA transition during SCL HIGH must be START or STOP.
    property p_sda_change_high_is_start_or_stop;
        @(posedge clk)
        disable iff (reset)
        (sda_changed && (scl == 1'b1))
        |-> (start_detected || stop_detected);
    endproperty

    assert property (p_sda_change_high_is_start_or_stop)
        else $error("I2C FAIL: Illegal SDA transition while SCL HIGH");

`endif

endmodule