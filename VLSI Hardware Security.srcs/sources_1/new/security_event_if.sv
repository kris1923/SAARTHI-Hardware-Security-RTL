
`timescale 1ns/1ps

module security_event_if (
    input  logic clk,
    input  logic rst_n,

    input  logic spi_event_i,
    input  logic i2c_event_i,
    input  logic can_event_i,
    input  logic hsm_event_i,

    output logic security_event_o,
    output logic hsm_locked_o
);

    logic security_event_sync;

    assign security_event_sync =
        spi_event_i |
        i2c_event_i |
        can_event_i |
        hsm_event_i;

    assign security_event_o = security_event_sync;

    // Sticky lock: stays active until reset.
    always_ff @(posedge clk) begin
        if (!rst_n)
            hsm_locked_o <= 1'b0;
        else if (security_event_sync)
            hsm_locked_o <= 1'b1;
    end

endmodule
