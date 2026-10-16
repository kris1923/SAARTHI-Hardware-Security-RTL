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

    // Clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin

        reset          = 1'b1;
        access_req     = 1'b0;
        authenticated  = 1'b0;
        locked         = 1'b0;
        security_error = 1'b0;

        #20;

        reset = 1'b0;

        // --------------------------------
        // TEST 1
        // --------------------------------
        $display("TEST 1: RESET SAFETY");

        #20;

        // --------------------------------
        // TEST 2
        // --------------------------------
        $display("TEST 2: VALID AUTHENTICATED ACCESS");

        authenticated = 1'b1;
        access_req    = 1'b1;

        #10;

        access_req = 1'b0;

        #20;

        // --------------------------------
        // TEST 3
        // --------------------------------
        $display("TEST 3: UNAUTHENTICATED ACCESS");

        authenticated = 1'b0;
        access_req    = 1'b1;

        #10;

        access_req = 1'b0;

        #20;

        // --------------------------------
        // TEST 4
        // --------------------------------
        $display("TEST 4: LOCKED ACCESS");

        authenticated = 1'b1;
        locked        = 1'b1;
        access_req    = 1'b1;

        #10;

        access_req = 1'b0;

        #20;

        // --------------------------------
        // TEST 5
        // --------------------------------
        $display("TEST 5: SECURITY ERROR");

        locked         = 1'b0;
        authenticated = 1'b1;
        security_error = 1'b1;
        access_req     = 1'b1;

        #10;

        access_req = 1'b0;

        #20;

        security_error = 1'b0;

        $display("SVA SECURITY CONTROLLER TEST COMPLETED");

        #20;

        $finish;

    end

endmodule