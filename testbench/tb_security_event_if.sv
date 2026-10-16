
`timescale 1ns/1ps

module tb_security_event_if;

    logic clk = 0;
    logic rst_n = 0;

    logic spi_event_i = 0;
    logic i2c_event_i = 0;
    logic can_event_i = 0;
    logic hsm_event_i = 0;

    wire security_event_o;
    wire hsm_locked_o;

    integer errors = 0;

    always #5 clk = ~clk;

    security_event_if dut (
        .clk(clk),
        .rst_n(rst_n),
        .spi_event_i(spi_event_i),
        .i2c_event_i(i2c_event_i),
        .can_event_i(can_event_i),
        .hsm_event_i(hsm_event_i),
        .security_event_o(security_event_o),
        .hsm_locked_o(hsm_locked_o)
    );

    task automatic reset_dut;
        begin
            @(negedge clk);
            rst_n = 0;
            spi_event_i = 0;
            i2c_event_i = 0;
            can_event_i = 0;
            hsm_event_i = 0;

            repeat (2) @(negedge clk);
            rst_n = 1;
            @(negedge clk);
        end
    endtask

    task automatic check_event(input integer event_number);
        begin
            case (event_number)
                0: spi_event_i = 1;
                1: i2c_event_i = 1;
                2: can_event_i = 1;
                3: hsm_event_i = 1;
            endcase

            #1;
            if (security_event_o !== 1'b1) begin
                $display("FAIL: Event %0d did not trigger", event_number);
                errors = errors + 1;
            end

            @(posedge clk);
            #1;
            if (hsm_locked_o !== 1'b1) begin
                $display("FAIL: Event %0d did not lock HSM", event_number);
                errors = errors + 1;
            end else begin
                $display("PASS: Event %0d triggered HSM lock", event_number);
            end

            @(negedge clk);
            spi_event_i = 0;
            i2c_event_i = 0;
            can_event_i = 0;
            hsm_event_i = 0;

            #1;
            if (security_event_o !== 1'b0) begin
                $display("FAIL: Event output did not clear");
                errors = errors + 1;
            end

            // The lock must remain set after the alert disappears.
            if (hsm_locked_o !== 1'b1) begin
                $display("FAIL: HSM lock was not sticky");
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $display("====================================");
        $display("SECURITY EVENT INTERFACE TEST START");
        $display("====================================");

        reset_dut();

        $display("TEST 1: SPI alert");
        check_event(0);

        $display("TEST 2: I2C alert");
        reset_dut();
        check_event(1);

        $display("TEST 3: CAN alert");
        reset_dut();
        check_event(2);

        $display("TEST 4: HSM alert");
        reset_dut();
        check_event(3);

        $display("TEST 5: No alert after reset");
        reset_dut();
        #1;
        if (security_event_o !== 1'b0 || hsm_locked_o !== 1'b0) begin
            $display("FAIL: Outputs incorrect after reset");
            errors = errors + 1;
        end else begin
            $display("PASS: Outputs clear after reset");
        end

        $display("------------------------------------");
        if (errors == 0)
            $display("ALL SECURITY EVENT TESTS PASSED");
        else
            $display("TESTS FAILED: %0d error(s)", errors);
        $display("------------------------------------");

        #10;
        $finish;
    end

endmodule
