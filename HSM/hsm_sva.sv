
`timescale 1ns/1ps

module hsm_sva (
    input logic clk,
    input logic reset,

    input logic access_req,
    input logic authenticated,
    input logic security_error,

    input logic access_grant,
    input logic busy,
    input logic crypto_done,
    input logic hsm_locked
);

    // Access requires previous-cycle authentication.
    property p_authentication_required;
        @(posedge clk)
        disable iff (reset)
        access_grant |-> $past(authenticated);
    endproperty

    assert property (p_authentication_required)
        else $error("HSM FAIL: Unauthenticated access");


    // REQUIRED PROPERTY 1:
    // A locked HSM must never grant access.
    property p_locked_no_access;
        @(posedge clk)
        disable iff (reset)
        hsm_locked |-> !access_grant;
    endproperty

    assert property (p_locked_no_access)
        else $error("HSM FAIL: Access while locked");


    // REQUIRED PROPERTY 2:
    // Access must be denied in the cycle following
    // a sampled security error.
    property p_security_error_no_access;
        @(posedge clk)
        disable iff (reset)
        security_error |=> !access_grant;
    endproperty

    assert property (p_security_error_no_access)
        else $error("HSM FAIL: Access after security error");


    // A security error must result in a locked state.
    property p_security_error_lock;
        @(posedge clk)
        disable iff (reset)
        security_error |=> hsm_locked;
    endproperty

    assert property (p_security_error_lock)
        else $error("HSM FAIL: Security error did not lock HSM");


    // Busy must be associated with authorization.
    property p_busy_requires_authorization;
        @(posedge clk)
        disable iff (reset)
        busy |-> (access_grant || $past(access_grant));
    endproperty

    assert property (p_busy_requires_authorization)
        else $error("HSM FAIL: Busy without authorization");


    // A locked HSM cannot grant access or remain busy.
    property p_locked_no_operation;
        @(posedge clk)
        disable iff (reset)
        hsm_locked |-> (!access_grant && !busy);
    endproperty

    assert property (p_locked_no_operation)
        else $error("HSM FAIL: Operation active while locked");


    // Completion must follow crypto activity.
    property p_completion_after_crypto;
        @(posedge clk)
        disable iff (reset)
        crypto_done |-> $past(busy);
    endproperty

    assert property (p_completion_after_crypto)
        else $error("HSM FAIL: Invalid crypto completion");


    // An unauthenticated request must not grant access
    // in the following cycle.
    property p_unauthorized_request;
        @(posedge clk)
        disable iff (reset)
        (access_req && !authenticated) |=> !access_grant;
    endproperty

    assert property (p_unauthorized_request)
        else $error("HSM FAIL: Unauthorized request granted");


    // Reset must leave access and busy inactive.
    property p_reset_safe;
        @(posedge clk)
        reset |=> (!access_grant && !busy);
    endproperty

    assert property (p_reset_safe)
        else $error("HSM FAIL: Unsafe state after reset");


    // Once locked, the HSM remains locked until reset.
    property p_lock_persistence;
        @(posedge clk)
        disable iff (reset)
        hsm_locked |=> hsm_locked;
    endproperty

    assert property (p_lock_persistence)
        else $error("HSM FAIL: Lock state unexpectedly released");

endmodule
