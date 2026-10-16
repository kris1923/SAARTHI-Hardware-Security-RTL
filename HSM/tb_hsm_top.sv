`timescale 1ns/1ps

module tb_hsm_top;

    logic clk;
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


    hsm_sva sva (

        .clk(clk),
        .reset(reset),

        .access_req(access_req),
        .authenticated(authenticated),
        .security_error(security_error),

        .access_grant(access_grant),
        .busy(busy),
        .crypto_done(crypto_done),
        .hsm_locked(hsm_locked)

    );


    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    initial begin

        reset          = 1'b1;

        access_req     = 1'b0;
        authenticated  = 1'b0;

        key_data       = 32'h12345678;
        crypto_data    = 32'hAABBCCDD;

        security_error = 1'b0;


        // ------------------------------------
        // TEST 1: RESET
        // ------------------------------------

        $display("HSM TEST 1: RESET");

        #20;

        reset = 1'b0;

        #10;


        // ------------------------------------
        // TEST 2: VALID AUTHENTICATED ACCESS
        // ------------------------------------

        $display("HSM TEST 2: AUTHENTICATED ACCESS");

        authenticated = 1'b1;
        access_req    = 1'b1;

        #10;

        access_req = 1'b0;

        #40;


        // ------------------------------------
        // TEST 3: SECURITY ERROR
        // ------------------------------------

        $display("HSM TEST 3: SECURITY ERROR");

        security_error = 1'b1;

        #10;

        security_error = 1'b0;

        #20;


        // ------------------------------------
        // TEST 4: LOCKED STATE
        // ------------------------------------

        $display("HSM TEST 4: LOCKED STATE");

        access_req = 1'b1;

        #20;

        access_req = 1'b0;

        #20;


        $display("HSM RTL + SVA TEST COMPLETED");

        $finish;

    end

endmodule