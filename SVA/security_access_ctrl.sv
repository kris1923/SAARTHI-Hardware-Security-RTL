`timescale 1ns/1ps

module security_access_ctrl (
    input  logic clk,
    input  logic reset,

    input  logic access_req,
    input  logic authenticated,
    input  logic locked,
    input  logic security_error,

    output logic access_grant,
    output logic busy,
    output logic ack
);

    always_ff @(posedge clk) begin

        if (reset) begin
            access_grant <= 1'b0;
            busy         <= 1'b0;
            ack          <= 1'b0;
        end

        else begin

            ack <= 1'b0;

            if (access_req) begin

                busy <= 1'b1;

                if (authenticated &&
                    !locked &&
                    !security_error) begin

                    access_grant <= 1'b1;

                end
                else begin

                    access_grant <= 1'b0;

                end

                ack <= 1'b1;
            end

            else begin

                busy         <= 1'b0;
                access_grant <= 1'b0;
            end
        end
    end

endmodule