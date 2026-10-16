`timescale 1ns/1ps

module i2c_sva (

    input logic clk,
    input logic reset,

    input logic scl,
    input logic sda
);

    // SDA and SCL must be known
    property p_scl_known;
        @(posedge clk)
        !$isunknown(scl);
    endproperty

    assert property (p_scl_known)
        else $error("I2C FAIL: SCL unknown");


    property p_sda_known;
        @(posedge clk)
        !$isunknown(sda);
    endproperty

    assert property (p_sda_known)
        else $error("I2C FAIL: SDA unknown");


    // SDA should remain stable while SCL is HIGH
    // except during START/STOP transitions.
    property p_sda_stable_high;
        @(posedge clk)
        (scl && !$rose(sda) && !$fell(sda))
        |-> $stable(sda);
    endproperty

    assert property (p_sda_stable_high)
        else $error("I2C FAIL: SDA stability violation");


    // START condition:
    // SDA HIGH -> LOW while SCL HIGH
    property p_start_condition;
        @(posedge clk)
        (scl && $past(sda) && !sda);
    endproperty

    // STOP condition:
    // SDA LOW -> HIGH while SCL HIGH
    property p_stop_condition;
        @(posedge clk)
        (scl && !$past(sda) && sda);
    endproperty

 

endmodule