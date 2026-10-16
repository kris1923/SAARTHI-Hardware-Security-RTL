`timescale 1ns/1ps

module security_access_ctrl_sva (

    input logic clk,
    input logic reset,

    input logic access_req,
    input logic authenticated,
    input logic locked,
    input logic security_error,

    input logic access_grant,
    input logic busy,
    input logic ack
);

    // Reset must result in safe access state
    property p_reset_safe;
        @(posedge clk)
        reset |=> !access_grant;
    endproperty

    assert property (p_reset_safe)
        else $error("SVA FAIL: Access granted after reset");


    // Locked system cannot grant access
    property p_locked_no_access;
        @(posedge clk)
        locked |=> !access_grant;
    endproperty

    assert property (p_locked_no_access)
        else $error("SVA FAIL: Access granted while locked");


    // Security error blocks access
    property p_security_error_no_access;
        @(posedge clk)
        security_error |=> !access_grant;
    endproperty

    assert property (p_security_error_no_access)
        else $error("SVA FAIL: Access granted during security error");


    // Authentication is required
    property p_authentication_required;
        @(posedge clk)
        access_grant |-> $past(authenticated);
    endproperty

    assert property (p_authentication_required)
        else $error("SVA FAIL: Authentication requirement violated");


    // Access requires a previous request
    property p_access_requires_request;
        @(posedge clk)
        access_grant |-> $past(access_req);
    endproperty

    assert property (p_access_requires_request)
        else $error("SVA FAIL: Access granted without request");


    // Valid access conditions
    property p_valid_access;
        @(posedge clk)
        access_grant |-> (
            $past(access_req) &&
            $past(authenticated) &&
            !$past(locked) &&
            !$past(security_error)
        );
    endproperty

    assert property (p_valid_access)
        else $error("SVA FAIL: Invalid access grant");


    // Request produces busy indication
    property p_request_busy;
        @(posedge clk)
        access_req |=> busy;
    endproperty

    assert property (p_request_busy)
        else $error("SVA FAIL: Request did not produce BUSY");


    // Request produces acknowledgement
    property p_request_ack;
        @(posedge clk)
        access_req |=> ack;
    endproperty

    assert property (p_request_ack)
        else $error("SVA FAIL: Request did not produce ACK");


    // ACK requires request
    property p_ack_requires_request;
        @(posedge clk)
        ack |-> $past(access_req);
    endproperty

    assert property (p_ack_requires_request)
        else $error("SVA FAIL: ACK without request");


    // Unauthorized request must not grant access
    property p_unauthorized_access;
        @(posedge clk)
        (access_req && !authenticated) |=> !access_grant;
    endproperty

    assert property (p_unauthorized_access)
        else $error("SVA FAIL: Unauthorized access granted");

endmodule