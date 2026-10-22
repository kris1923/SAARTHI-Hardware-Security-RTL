
`timescale 1ns/1ps

module tb_security_access_ctrl;

    logic clk;
    logic reset;
    logic access_req;
    logic authenticated;
    logic locked;
    logic security_error;

    logic access_grant;
    logic busy;
    logic ack;

    integer pass_count = 0;
    integer fail_count = 0;

    // Device under test
    security_access_ctrl dut (
        .clk(clk),
        .reset(reset),
        .access_req(access_req),
        .authenticated(authenticated),
        .locked(locked),
        .security_error(security_error),
        .access_grant(access_grant),
        .busy(busy),
        .ack(ack)
    );

    // SystemVerilog Assertions
    security_access_ctrl_sva sva (
        .clk(clk),
        .reset(reset),
        .access_req(access_req),
        .authenticated(authenticated),
        .locked(locked),
        .security_error(security_error),
        .access_grant(access_grant),
        .busy(busy),
        .ack(ack)
    );

    // 10 ns clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Reusable output-checking task
    task automatic check_result(
        input string test_name,
        input logic expected_grant,
        input logic expected_busy,
        input logic expected_ack
    );
        begin
            if ((access_grant === expected_grant) &&
                (busy         === expected_busy) &&
                (ack          === expected_ack)) begin

                $display("[%0t] PASS: %s", $time, test_name);
                pass_count = pass_count + 1;
            end
            else begin
                $error("[%0t] FAIL: %s", $time, test_name);
                $display("  Expected: grant=%b busy=%b ack=%b",
                         expected_grant, expected_busy, expected_ack);
                $display("  Actual:   grant=%b busy=%b ack=%b",
                         access_grant, busy, ack);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        // Initial values
        reset          = 1'b1;
        access_req     = 1'b0;
        authenticated  = 1'b0;
        locked         = 1'b0;
        security_error = 1'b0;

        // Keep reset active across clock edges
        repeat (2) @(negedge clk);
        #1;
        check_result("RESET SAFETY", 1'b0, 1'b0, 1'b0);

        reset = 1'b0;

        // TEST 1: Valid authenticated access
        @(negedge clk);
        authenticated = 1'b1;
        access_req    = 1'b1;

        @(posedge clk);
        #1;
        check_result("AUTHENTICATED ACCESS", 1'b1, 1'b1, 1'b1);

        // Remove request
        @(negedge clk);
        access_req = 1'b0;

        @(posedge clk);
        #1;
        check_result("ACCESS GRANT CLEARS", 1'b0, 1'b0, 1'b0);

        // TEST 2: Unauthenticated request
        @(negedge clk);
        authenticated = 1'b0;
        access_req    = 1'b1;

        @(posedge clk);
        #1;
        check_result("UNAUTHENTICATED ACCESS BLOCKED",
                     1'b0, 1'b1, 1'b1);

        @(negedge clk);
        access_req = 1'b0;

        @(posedge clk);
        #1;
        check_result("UNAUTHENTICATED REQUEST CLEARED",
                     1'b0, 1'b0, 1'b0);

        // TEST 3: Locked access
        @(negedge clk);
        authenticated = 1'b1;
        locked        = 1'b1;
        access_req    = 1'b1;

        @(posedge clk);
        #1;
        check_result("LOCKED ACCESS BLOCKED", 1'b0, 1'b1, 1'b1);

        @(negedge clk);
        access_req = 1'b0;
        locked     = 1'b0;

        @(posedge clk);
        #1;
        check_result("LOCKED REQUEST CLEARED", 1'b0, 1'b0, 1'b0);

        // TEST 4: Security error
        @(negedge clk);
        authenticated  = 1'b1;
        security_error = 1'b1;
        access_req     = 1'b1;

        @(posedge clk);
        #1;
        check_result("SECURITY ERROR BLOCKS ACCESS",
                     1'b0, 1'b1, 1'b1);

        @(negedge clk);
        access_req     = 1'b0;
        security_error = 1'b0;

        @(posedge clk);
        #1;
        check_result("SECURITY ERROR REQUEST CLEARED",
                     1'b0, 1'b0, 1'b0);

        // TEST 5: Reset during operation
        @(negedge clk);
        authenticated = 1'b1;
        access_req    = 1'b1;

        @(posedge clk);
        #1;
        check_result("ACCESS BEFORE RESET", 1'b1, 1'b1, 1'b1);

        @(negedge clk);
        reset = 1'b1;

        @(posedge clk);
        #1;
        check_result("RESET CLEARS ACCESS", 1'b0, 1'b0, 1'b0);

        @(negedge clk);
        reset      = 1'b0;
        access_req = 1'b0;

        @(posedge clk);
        #1;

        // Final summary
        $display("----------------------------------------");
        $display("SECURITY ACCESS CONTROLLER TEST SUMMARY");
        $display("PASS: %0d", pass_count);
        $display("FAIL: %0d", fail_count);
        $display("----------------------------------------");

        if (fail_count == 0)
            $display("RESULT: ALL OUTPUT CHECKS PASSED");
        else
            $error("RESULT: SOME OUTPUT CHECKS FAILED");

        #10;
        $finish;
    end

endmodule
