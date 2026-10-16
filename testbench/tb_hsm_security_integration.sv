
`timescale 1ns/1ps

module tb_hsm_security_integration;

    logic clk = 0;
    logic rst_n = 0;
    always #5 clk = ~clk;

    logic spi_event_i = 0;
    logic i2c_event_i = 0;
    logic can_event_i = 0;
    logic hsm_event_i = 0;

    logic [31:0] s_axi_awaddr = 0;
    logic s_axi_awvalid = 0;
    wire s_axi_awready;

    logic [31:0] s_axi_wdata = 0;
    logic [3:0] s_axi_wstrb = 4'b1111;
    logic s_axi_wvalid = 0;
    wire s_axi_wready;

    wire [1:0] s_axi_bresp;
    wire s_axi_bvalid;
    logic s_axi_bready = 0;

    logic [31:0] s_axi_araddr = 0;
    logic s_axi_arvalid = 0;
    wire s_axi_arready;

    wire [31:0] s_axi_rdata;
    wire [1:0] s_axi_rresp;
    wire s_axi_rvalid;
    logic s_axi_rready = 0;

    logic authenticated_i = 1;
    logic engine_busy_i = 0;
    logic engine_done_i = 0;
    logic [31:0] nonce_count_i = 0;
    logic nonce_ready_i = 1;

    wire engine_start_o;
    wire [31:0] key_slot_o;
    wire security_event_o;
    wire hsm_locked_o;

    integer errors = 0;
    logic [1:0] response;

    // Phase 2 functional coverage counters
    integer spi_alert_hits = 0;
    integer i2c_alert_hits = 0;
    integer can_alert_hits = 0;
    integer hsm_alert_hits = 0;
    integer reset_recovery_hits = 0;
    integer locked_write_reject_hits = 0;

    hsm_security_integration dut (
        .clk(clk),
        .rst_n(rst_n),

        .spi_event_i(spi_event_i),
        .i2c_event_i(i2c_event_i),
        .can_event_i(can_event_i),
        .hsm_event_i(hsm_event_i),

        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),

        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),

        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),

        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),

        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        .authenticated_i(authenticated_i),
        .engine_busy_i(engine_busy_i),
        .engine_done_i(engine_done_i),
        .nonce_count_i(nonce_count_i),
        .nonce_ready_i(nonce_ready_i),

        .engine_start_o(engine_start_o),
        .key_slot_o(key_slot_o),
        .security_event_o(security_event_o),
        .hsm_locked_o(hsm_locked_o)
    );

    // AXI-Lite write task
    task automatic axi_write(
        input logic [31:0] addr,
        input logic [31:0] data,
        output logic [1:0] resp
    );
        integer timeout_count;
        bit aw_done;
        bit w_done;

        begin
            timeout_count = 0;
            aw_done = 0;
            w_done = 0;
            resp = 2'bxx;

            @(negedge clk);
            s_axi_awaddr = addr;
            s_axi_wdata = data;
            s_axi_wstrb = 4'b1111;
            s_axi_awvalid = 1;
            s_axi_wvalid = 1;
            s_axi_bready = 0;

            while ((!aw_done || !w_done) &&
                   timeout_count < 30) begin

                @(posedge clk);

                if (s_axi_awvalid && s_axi_awready)
                    aw_done = 1;

                if (s_axi_wvalid && s_axi_wready)
                    w_done = 1;

                @(negedge clk);

                if (aw_done)
                    s_axi_awvalid = 0;

                if (w_done)
                    s_axi_wvalid = 0;

                timeout_count = timeout_count + 1;
            end

            s_axi_awvalid = 0;
            s_axi_wvalid = 0;

            if (aw_done && w_done) begin
                s_axi_bready = 1;
                timeout_count = 0;

                while (!s_axi_bvalid && timeout_count < 30) begin
                    @(negedge clk);
                    timeout_count = timeout_count + 1;
                end

                if (s_axi_bvalid) begin
                    resp = s_axi_bresp;
                    @(posedge clk);
                    @(negedge clk);
                end
            end

            s_axi_bready = 0;
        end
    endtask

    // Check whether an alert locks the HSM and count coverage
    task automatic check_lock(input string label_text);
        begin
            repeat (3) @(negedge clk);

            if (hsm_locked_o) begin
                $display("PASS: %s locked HSM", label_text);

                case (label_text)
                    "SPI alert":
                        spi_alert_hits = spi_alert_hits + 1;

                    "I2C alert":
                        i2c_alert_hits = i2c_alert_hits + 1;

                    "CAN alert":
                        can_alert_hits = can_alert_hits + 1;

                    "HSM alert":
                        hsm_alert_hits = hsm_alert_hits + 1;
                endcase
            end
            else begin
                $display("FAIL: %s did not lock HSM", label_text);
                errors = errors + 1;
            end
        end
    endtask

    // Main integration tests
    initial begin
        $display("========================================");
        $display("HSM SECURITY INTEGRATION TEST START");
        $display("========================================");

        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        // Test 1: SPI alert
        $display("TEST 1: SPI alert");
        spi_event_i = 1;
        check_lock("SPI alert");
        spi_event_i = 0;

        // Test 2: Reset recovery
        $display("TEST 2: Reset recovery");
        rst_n = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        if (!hsm_locked_o) begin
            $display("PASS: reset cleared lock");
            reset_recovery_hits = reset_recovery_hits + 1;
        end
        else begin
            $display("FAIL: lock remained set after reset");
            errors = errors + 1;
        end

        // Test 3: I2C alert
        $display("TEST 3: I2C alert");
        i2c_event_i = 1;
        check_lock("I2C alert");
        i2c_event_i = 0;

        // Test 4: CAN alert after reset
        $display("TEST 4: CAN alert");
        rst_n = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        can_event_i = 1;
        check_lock("CAN alert");
        can_event_i = 0;

        // Test 5: External HSM alert
        $display("TEST 5: HSM alert");
        rst_n = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        hsm_event_i = 1;
        check_lock("HSM alert");
        hsm_event_i = 0;

        // Test 6: Reject key-slot write while locked
        $display("TEST 6: Locked key-slot write");
        axi_write(32'h10, 32'h0000_0022, response);

        if (response == 2'b10 && key_slot_o == 0) begin
            $display("PASS: locked key-slot write rejected");
            locked_write_reject_hits =
                locked_write_reject_hits + 1;
        end
        else begin
            $display(
                "FAIL: response=%b key_slot=%08h",
                response, key_slot_o
            );
            errors = errors + 1;
        end

        // Functional coverage summary
        $display("");
        $display("========================================");
        $display("FUNCTIONAL COVERAGE SUMMARY");
        $display("========================================");
        $display("SPI alert:             %0d/1", spi_alert_hits);
        $display("I2C alert:             %0d/1", i2c_alert_hits);
        $display("CAN alert:             %0d/1", can_alert_hits);
        $display("HSM alert:             %0d/1", hsm_alert_hits);
        $display("Reset recovery:        %0d/1", reset_recovery_hits);
        $display("Locked write rejected: %0d/1",
                 locked_write_reject_hits);

        if (spi_alert_hits != 1 ||
            i2c_alert_hits != 1 ||
            can_alert_hits != 1 ||
            hsm_alert_hits != 1 ||
            reset_recovery_hits != 1 ||
            locked_write_reject_hits != 1) begin

            $display("FAIL: one or more coverage scenarios missing");
            errors = errors + 1;
        end
        else begin
            $display("PASS: all six coverage scenarios exercised");
        end

        $display("----------------------------------------");

        if (errors == 0)
            $display("ALL INTEGRATION TESTS PASSED");
        else
            $display("INTEGRATION TESTS FAILED: %0d error(s)", errors);

        $display("----------------------------------------");

        #20;
        $finish;
    end

    // Watchdog timeout
    initial begin
        #10000;
        $display("FATAL: integration test timeout");
        $finish;
    end

endmodule
