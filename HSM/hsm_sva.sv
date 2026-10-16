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

    // Authentication required
    property p_authentication_required;
        @(posedge clk)
        access_grant |-> $past(authenticated);
    endproperty

    assert property (p_authentication_required)
        else $error("HSM FAIL: Unauthenticated access");


    // Locked state blocks access
    property p_locked_no_access;
        @(posedge clk)
        hsm_locked |-> !access_grant;
    endproperty

    assert property (p_locked_no_access)
        else $error("HSM FAIL: Access while locked");


    // Security error forces lock
    property p_security_error_lock;
        @(posedge clk)
        security_error |=> hsm_locked;
    endproperty

    assert property (p_security_error_lock)
        else $error("HSM FAIL: Security error did not lock HSM");


// Protected operation must be associated with authorization.
// Authorization may occur in the same cycle that BUSY becomes active.
property p_busy_requires_authorization;
    @(posedge clk)
    busy |-> (access_grant || $past(access_grant));
endproperty

assert property (p_busy_requires_authorization)
    else $error("HSM FAIL: Busy without authorization");


    // Locked state blocks operation
    property p_locked_no_operation;
        @(posedge clk)
        hsm_locked |-> (!access_grant && !busy);
    endproperty

    assert property (p_locked_no_operation)
        else $error("HSM FAIL: Operation active while locked");


    // Completion follows crypto activity
    property p_completion_after_crypto;
        @(posedge clk)
        crypto_done |-> $past(busy);
    endproperty

    assert property (p_completion_after_crypto)
        else $error("HSM FAIL: Invalid crypto completion");


    // Unauthorized request cannot grant access
    property p_unauthorized_request;
        @(posedge clk)
        (access_req && !authenticated) |=> !access_grant;
    endproperty

    assert property (p_unauthorized_request)
        else $error("HSM FAIL: Unauthorized request granted");


    // Reset safe state
    property p_reset_safe;
        @(posedge clk)
        reset |=> (!access_grant && !busy);
    endproperty

    assert property (p_reset_safe)
        else $error("HSM FAIL: Unsafe state after reset");


    // Lock persistence
    property p_lock_persistence;
        @(posedge clk)
        hsm_locked && !reset |=> hsm_locked;
    endproperty

    assert property (p_lock_persistence)
        else $error("HSM FAIL: Lock state unexpectedly released");

endmodule