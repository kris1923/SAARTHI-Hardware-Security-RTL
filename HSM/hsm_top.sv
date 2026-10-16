`timescale 1ns/1ps

module hsm_top (

    input logic clk,
    input logic reset,

    input logic access_req,
    input logic authenticated,

    input logic [31:0] key_data,
    input logic [31:0] crypto_data,

    input logic security_error,

    output logic access_grant,
    output logic busy,
    output logic crypto_done,
    output logic hsm_locked
);

    typedef enum logic [2:0] {

        ST_RESET      = 3'b000,
        ST_IDLE       = 3'b001,
        ST_AUTH_CHECK = 3'b010,
        ST_AUTHORIZED = 3'b011,
        ST_CRYPTO     = 3'b100,
        ST_COMPLETE   = 3'b101,
        ST_LOCKED     = 3'b110

    } hsm_state_t;


    hsm_state_t state;
    hsm_state_t next_state;

    logic [31:0] key_reg;
    logic [31:0] crypto_data_reg;


    // State and protected registers
    always_ff @(posedge clk) begin

        if (reset) begin

            state           <= ST_RESET;
            key_reg         <= 32'b0;
            crypto_data_reg <= 32'b0;

        end

        else begin

            state <= next_state;

            // Capture protected information only after authorization
            if (state == ST_AUTHORIZED) begin

                key_reg         <= key_data;
                crypto_data_reg <= crypto_data;

            end

        end

    end


    // Next-state logic
    always_comb begin

        next_state = state;

        // Highest security priority
        if (security_error) begin

            next_state = ST_LOCKED;

        end

        else begin

            case (state)

                ST_RESET:
                    next_state = ST_IDLE;

                ST_IDLE:
                    if (access_req)
                        next_state = ST_AUTH_CHECK;

                ST_AUTH_CHECK:
                    if (authenticated)
                        next_state = ST_AUTHORIZED;
                    else
                        next_state = ST_LOCKED;

                ST_AUTHORIZED:
                    next_state = ST_CRYPTO;

                ST_CRYPTO:
                    next_state = ST_COMPLETE;

                ST_COMPLETE:
                    next_state = ST_IDLE;

                ST_LOCKED:
                    next_state = ST_LOCKED;

                default:
                    next_state = ST_LOCKED;

            endcase

        end

    end


    // Output logic
    always_comb begin

        access_grant = 1'b0;
        busy         = 1'b0;
        crypto_done  = 1'b0;
        hsm_locked   = 1'b0;

        case (state)

            ST_AUTHORIZED: begin
                access_grant = 1'b1;
                busy         = 1'b1;
            end

            ST_CRYPTO: begin
                busy = 1'b1;
            end

            ST_COMPLETE: begin
                crypto_done = 1'b1;
            end

            ST_LOCKED: begin
                hsm_locked   = 1'b1;
                access_grant = 1'b0;
                busy         = 1'b0;
                crypto_done  = 1'b0;
            end

            default: begin
            end

        endcase

    end

endmodule