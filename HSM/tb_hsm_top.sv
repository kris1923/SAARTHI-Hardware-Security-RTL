
`timescale 1ns/1ps

module tb_hsm_top;

    logic clk = 0;
    logic reset;
    logic access_req;
    logic authenticated;
    logic [31:0] key_data;
    logic [31:0] crypto_data;
    logic security_error;

    logic access_grant;
    logic busy;
    logic crypto_done;
    logic hsm_locked;

    int pass_count = 0;
    int fail_count = 0;

    // Independent SVA fault-injection checker
    logic fi_reset;
    logic fi_access_req;
    logic fi_authenticated;
    logic fi_security_error;
    logic fi_access_grant;
    logic fi_busy;
    logic fi_crypto_done;
    logic fi_hsm_locked;

    logic locked_fault_seen = 0;
    logic security_fault_seen = 0;
    logic previous_security_error = 0;

    always #5 clk = ~clk;

    hsm_top dut (
        .clk(clk),
        .reset(reset),
        .access_req(access_req),
        .authenticated(authenticated),
        .key_data(key_data),
        .crypto_data(crypto_data),
        .security_error(security_error),
        .access_grant(access_grant),
        .busy(busy),
        .crypto_done(crypto_done),
        .hsm_locked(hsm_locked)
    );

    hsm_sva fault_checker (
        .clk(clk),
        .reset(fi_reset),
        .access_req(fi_access_req),
        .authenticated(fi_authenticated),
        .security_error(fi_security_error),
        .access_grant(fi_access_grant),
        .busy(fi_busy),
        .crypto_done(fi_crypto_done),
        .hsm_locked(fi_hsm_locked)
    );

    // Observe fault conditions on clock edges.
    // These flags confirm that the invalid conditions were sampled.
    always @(posedge clk) begin
        if (!fi_reset) begin
            if (fi_hsm_locked && fi_access_grant)
                locked_fault_seen <= 1'b1;

            if (previous_security_error && fi_access_grant)
                security_fault_seen <= 1'b1;

            previous_security_error <= fi_security_error;
        end
        else begin
            previous_security_error <= 1'b0;
        end
    end

    task automatic check_result(
        input logic condition,
        input string description
    );
        begin
            if (condition === 1'b1) begin
                pass_count++;
                $display("PASS: %s", description);
            end
            else begin
                fail_count++;
                $display("FAIL: %s", description);
            end
        end
    endtask

    initial begin
        // Initialize DUT
        reset = 1;
        access_req = 0;
        authenticated = 0;
        key_data = 32'h1234_ABCD;
        crypto_data = 32'h5678_EF01;
        security_error = 0;

        // Initialize fault checker to safe values
        fi_reset = 1;
        fi_access_req = 0;
        fi_authenticated = 1;
        fi_security_error = 0;
        fi_access_grant = 0;
        fi_busy = 0;
        fi_crypto_done = 0;
        fi_hsm_locked = 0;

        $display("");
        $display("======================================");
        $display(" HSM RTL + SVA VERIFICATION START");
        $display("======================================");

        // TEST 1: Reset
        $display("\nTEST 1: RESET");

        repeat (2) @(negedge clk);
        reset = 0;
        @(negedge clk);

        check_result(
            !access_grant && !busy && !hsm_locked,
            "Reset recovery produces safe outputs"
        );

        // TEST 2: Authenticated request
        $display("\nTEST 2: AUTHENTICATED ACCESS");

        @(negedge clk);
        access_req = 1;
        authenticated = 1;

        // Let the FSM sample the request and enter AUTH_CHECK
        @(negedge clk);
        access_req = 0;

        // Next active edge enters AUTHORIZED
        @(negedge clk);

        check_result(
            access_grant && busy && !hsm_locked,
            "Authenticated request is granted"
        );

        // Next state is CRYPTO; busy remains high
        @(negedge clk);
        check_result(
            busy && !hsm_locked,
            "Crypto processing is active"
        );

        // Next state is COMPLETE; crypto_done pulses high
        @(negedge clk);
        check_result(
            crypto_done && !hsm_locked,
            "Crypto completion is observed"
        );

        // Allow return to IDLE before the security-error test
        @(negedge clk);
        @(negedge clk);

        // TEST 3: Security error locks the actual DUT
        $display("\nTEST 3: SECURITY ERROR");

        security_error = 1;
        @(negedge clk);
        security_error = 0;

        // The FSM enters LOCKED at the intervening positive edge
        @(negedge clk);

        check_result(
            hsm_locked && !access_grant && !busy,
            "Security error locks HSM and denies access"
        );

        // TEST 4: Lock persistence
        $display("\nTEST 4: LOCKED STATE");

        repeat (3) @(negedge clk);

        check_result(
            hsm_locked && !access_grant && !busy,
            "Locked state persists and access remains denied"
        );

        // TEST 5: Deliberately violate p_locked_no_access
        $display("\nTEST 5: LOCKED-ACCESS ASSERTION INJECTION");

        fi_reset = 1;
        @(negedge clk);
        fi_reset = 0;

        fi_authenticated = 1;
        fi_access_req = 0;
        fi_security_error = 0;
        fi_busy = 0;
        fi_crypto_done = 0;

        // Change signals away from the sampling edge
        @(negedge clk);
        fi_hsm_locked = 1;
        fi_access_grant = 1;

        // The next posedge should trigger p_locked_no_access.
        @(negedge clk);

        check_result(
            locked_fault_seen,
            "Locked-access violation was sampled"
        );

        fi_hsm_locked = 0;
        fi_access_grant = 0;

        // TEST 6: Deliberately violate p_security_error_no_access
        $display("\nTEST 6: SECURITY-ERROR ASSERTION INJECTION");

        fi_reset = 1;
        fi_access_grant = 0;
        fi_hsm_locked = 0;
        fi_security_error = 0;
        fi_authenticated = 1;
        fi_busy = 0;
        fi_crypto_done = 0;

        @(negedge clk);
        fi_reset = 0;

        // Sample a security error first
        @(negedge clk);
        fi_security_error = 1;
        fi_hsm_locked = 0;
        fi_access_grant = 0;

        // At the following sample, violate no-access and satisfy
        // the separate security-error-lock property.
        @(negedge clk);
        fi_security_error = 0;
        fi_hsm_locked = 1;
        fi_access_grant = 1;

        @(negedge clk);

        check_result(
            security_fault_seen,
            "Post-security-error access violation was sampled"
        );

        fi_access_grant = 0;
        fi_hsm_locked = 0;

        // Final summary
        $display("");
        $display("======================================");
        $display(" HSM FUNCTIONAL TEST SUMMARY");
        $display(" PASS COUNT: %0d", pass_count);
        $display(" FAIL COUNT: %0d", fail_count);
        $display("======================================");

        if (fail_count == 0)
            $display("PASS: All functional and fault-condition checks passed");
        else
            $fatal(1, "FAIL: One or more testbench checks failed");

        $display("");
        $display("NOTE: The two deliberate SVA violations should");
        $display("produce assertion errors in the simulator log.");
        $display("Those specific errors are expected in negative tests.");

        $finish;
    end

endmodule
