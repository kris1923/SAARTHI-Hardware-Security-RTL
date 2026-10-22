
`timescale 1ns/1ps

module tb_sva_failure_injection;

    logic clk = 0;
    logic rst_n = 0;
    logic spi_event_i = 0;
    logic i2c_event_i = 0;
    logic can_event_i = 0;
    logic hsm_event_i = 0;

    logic security_event_o;
    logic hsm_locked_o;

    int assertion_failure_count = 0;

    security_event_if dut (
        .clk(clk),
        .rst_n(rst_n),
        .spi_event_i(spi_event_i),
        .i2c_event_i(i2c_event_i),
        .can_event_i(can_event_i),
        .hsm_event_i(hsm_event_i),
        .security_event_o(security_event_o),
        .hsm_locked_o(hsm_locked_o)
    );

    always #5 clk = ~clk;

    // Positive security property:
    // A sampled SPI event must result in the HSM being locked
    // at the next rising clock edge.
    property p_spi_event_locks_hsm;
        @(posedge clk) disable iff (!rst_n)
        $rose(spi_event_i) |=> hsm_locked_o;
    endproperty

    a_spi_event_locks_hsm:
        assert property (p_spi_event_locks_hsm)
        else begin
            assertion_failure_count++;
            $error("SVA FAILURE: SPI event did not lock the HSM");
        end

    // Deliberately incorrect property used only for negative testing.
    // It expects the HSM to remain unlocked after an SPI event.
    property p_injected_bad_expectation;
        @(posedge clk) disable iff (!rst_n)
        $rose(spi_event_i) |=> !hsm_locked_o;
    endproperty

    a_injected_bad_expectation:
        assert property (p_injected_bad_expectation)
        else begin
            assertion_failure_count++;
            $display("EXPECTED NEGATIVE-TEST FAILURE DETECTED");
        end

    initial begin
        $display("======================================");
        $display("SVA FAILURE-INJECTION TEST START");
        $display("======================================");

        rst_n = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;

        // Allow reset release to settle before injecting the event.
        repeat (2) @(negedge clk);

        spi_event_i = 1;
        @(negedge clk);
        spi_event_i = 0;

        // Wait for both concurrent assertions to evaluate.
        repeat (3) @(negedge clk);

        if (hsm_locked_o !== 1'b1)
            $error("FUNCTIONAL FAILURE: HSM did not lock");
        else
            $display("PASS: SPI event caused HSM lock");

        if (assertion_failure_count == 1)
            $display("PASS: Positive SVA passed; injected negative SVA failed as expected");
        else if (assertion_failure_count == 0)
            $error("NEGATIVE TEST FAILURE: injected assertion did not fail");
        else
            $error("Unexpected assertion failure count: %0d",
                   assertion_failure_count);

        $display("Total assertion failures counted: %0d",
                 assertion_failure_count);
        $display("SVA failure-injection test completed.");

        $finish;
    end

endmodule
