
`timescale 1ns/1ps

module tb_hsm_security_integration;

    logic clk = 0;
    logic rst_n = 0;

    always #5 clk = ~clk;

    // External security events
    logic spi_event_i = 0;
    logic i2c_event_i = 0;
    logic can_event_i = 0;
    logic hsm_event_i = 0;

    // SPI monitor inputs
    logic spi_cs_n_i = 1;
    logic spi_sclk_i = 0;
    logic spi_mosi_i = 0;
    logic spi_miso_i = 0;

    // I2C monitor inputs
    logic i2c_scl_i = 1;
    logic i2c_sda_i = 1;

    // CAN monitor inputs
    logic can_tx_i = 1;
    logic can_rx_i = 1;
    logic can_frame_active_i = 0;
    logic can_bit_error_i = 0;
    logic can_ack_error_i = 0;

    // AXI-Lite signals
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

    // HSM control
    logic authenticated_i = 1;
    logic engine_busy_i = 0;
    logic engine_done_i = 0;
    logic [31:0] nonce_count_i = 0;
    logic nonce_ready_i = 1;

    wire engine_start_o;
    wire [31:0] key_slot_o;
    wire security_event_o;
    wire hsm_locked_o;

    // Protocol monitor status
    wire spi_monitor_error_o;
    wire i2c_monitor_error_o;
    wire can_monitor_error_o;

    integer errors = 0;

    logic [1:0] response;

    integer spi_alert_hits = 0;
    integer i2c_alert_hits = 0;
    integer can_alert_hits = 0;
    integer hsm_alert_hits = 0;
    integer reset_recovery_hits = 0;
    integer locked_write_reject_hits = 0;
    integer can_fault_lock_hits = 0;
    integer spi_fault_lock_hits = 0;
    integer i2c_fault_lock_hits = 0;

    // DUT
    hsm_security_integration dut (
        .clk(clk),
        .rst_n(rst_n),

        .spi_event_i(spi_event_i),
        .i2c_event_i(i2c_event_i),
        .can_event_i(can_event_i),
        .hsm_event_i(hsm_event_i),

        .spi_cs_n_i(spi_cs_n_i),
        .spi_sclk_i(spi_sclk_i),
        .spi_mosi_i(spi_mosi_i),
        .spi_miso_i(spi_miso_i),

        .i2c_scl_i(i2c_scl_i),
        .i2c_sda_i(i2c_sda_i),

        .can_tx_i(can_tx_i),
        .can_rx_i(can_rx_i),
        .can_frame_active_i(can_frame_active_i),
        .can_bit_error_i(can_bit_error_i),
        .can_ack_error_i(can_ack_error_i),

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
        .hsm_locked_o(hsm_locked_o),

        .spi_monitor_error_o(spi_monitor_error_o),
        .i2c_monitor_error_o(i2c_monitor_error_o),
        .can_monitor_error_o(can_monitor_error_o)
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

    // Reset helper
    task automatic reset_system;
        begin
            spi_event_i = 0;
            i2c_event_i = 0;
            can_event_i = 0;
            hsm_event_i = 0;

            spi_cs_n_i = 1;
            spi_sclk_i = 0;
            spi_mosi_i = 0;
            spi_miso_i = 0;

            i2c_scl_i = 1;
            i2c_sda_i = 1;

            can_tx_i = 1;
            can_rx_i = 1;
            can_frame_active_i = 0;
            can_bit_error_i = 0;
            can_ack_error_i = 0;

            rst_n = 0;
            repeat (3) @(negedge clk);

            rst_n = 1;
            repeat (3) @(negedge clk);
        end
    endtask

    // Check HSM lock after an external event
    task automatic check_lock(input string label_text);
        begin
            repeat (3) @(negedge clk);

            if (hsm_locked_o === 1'b1) begin
                $display("PASS: %s locked HSM", label_text);

                case (label_text)
                    "SPI alert": spi_alert_hits++;
                    "I2C alert": i2c_alert_hits++;
                    "CAN alert": can_alert_hits++;
                    "HSM alert": hsm_alert_hits++;
                endcase
            end
            else begin
                $display("FAIL: %s did not lock HSM", label_text);
                errors++;
            end
        end
    endtask

    // Main test sequence
    initial begin
        $display("");
        $display("============================================");
        $display("HSM SECURITY INTEGRATION TEST START");
        $display("============================================");

        reset_system();

        // TEST 1: External SPI alert
        $display("\nTEST 1: External SPI alert");
        spi_event_i = 1;
        check_lock("SPI alert");
        spi_event_i = 0;

        // TEST 2: Reset recovery
        $display("\nTEST 2: Reset recovery");
        reset_system();

        if (hsm_locked_o === 1'b0) begin
            $display("PASS: Reset cleared HSM lock");
            reset_recovery_hits++;
        end
        else begin
            $display("FAIL: Lock remained set after reset");
            errors++;
        end

        // TEST 3: External I2C alert
        $display("\nTEST 3: External I2C alert");
        i2c_event_i = 1;
        check_lock("I2C alert");
        i2c_event_i = 0;

        // TEST 4: External CAN alert
        $display("\nTEST 4: External CAN alert");
        reset_system();
        can_event_i = 1;
        check_lock("CAN alert");
        can_event_i = 0;

        // TEST 5: HSM alert
        $display("\nTEST 5: HSM alert");
        reset_system();
        hsm_event_i = 1;
        check_lock("HSM alert");
        hsm_event_i = 0;

        // TEST 6: Reject key-slot write while locked
        $display("\nTEST 6: Locked key-slot write rejected");
        axi_write(32'h10, 32'h0000_0022, response);

        if ((response === 2'b10) && (key_slot_o === 32'b0)) begin
            $display("PASS: Locked key-slot write rejected");
            locked_write_reject_hits++;
        end
        else begin
            $display("FAIL: response=%b key_slot=%08h",
                     response, key_slot_o);
            errors++;
        end

        // TEST 7: CAN monitor-originated bit error
        $display("\nTEST 7: CAN monitor fault locks HSM");
        reset_system();

        can_frame_active_i = 1;
        can_tx_i = 0;
        can_rx_i = 0;

        @(negedge clk);
        can_bit_error_i = 1;

        repeat (4) @(negedge clk);

        if ((can_monitor_error_o === 1'b1) &&
            (hsm_locked_o === 1'b1)) begin
            $display("PASS: CAN monitor fault raised error and locked HSM");
            can_fault_lock_hits++;
        end
        else begin
            $display("FAIL: CAN monitor error=%b HSM lock=%b",
                     can_monitor_error_o, hsm_locked_o);
            errors++;
        end

        can_bit_error_i = 0;
        can_frame_active_i = 0;

        // TEST 8: SPI monitor-originated unknown-data fault
        $display("\nTEST 8: SPI monitor fault locks HSM");
        reset_system();

        spi_cs_n_i = 0;
        spi_mosi_i = 1'bx;
        spi_miso_i = 0;

        repeat (4) @(negedge clk);

        if ((spi_monitor_error_o === 1'b1) &&
            (hsm_locked_o === 1'b1)) begin
            $display("PASS: SPI unknown-data fault raised error and locked HSM");
            spi_fault_lock_hits++;
        end
        else begin
            $display("FAIL: SPI monitor error=%b HSM lock=%b",
                     spi_monitor_error_o, hsm_locked_o);
            errors++;
        end

        // TEST 9: I2C monitor-originated unknown-line fault
        $display("\nTEST 9: I2C monitor fault locks HSM");
        reset_system();

        i2c_scl_i = 1'b1;
        i2c_sda_i = 1'bx;

        repeat (4) @(negedge clk);

        if ((i2c_monitor_error_o === 1'b1) &&
            (hsm_locked_o === 1'b1)) begin
            $display("PASS: I2C unknown-line fault raised error and locked HSM");
            i2c_fault_lock_hits++;
        end
        else begin
            $display("FAIL: I2C monitor error=%b HSM lock=%b",
                     i2c_monitor_error_o, hsm_locked_o);
            errors++;
        end

        // Restore SDA only AFTER verifying the injected fault.
        i2c_sda_i = 1'b1;
        @(negedge clk);

        // Functional coverage summary
        $display("");
        $display("============================================");
        $display("FUNCTIONAL COVERAGE SUMMARY");
        $display("============================================");

        $display("External SPI alert:       %0d/1", spi_alert_hits);
        $display("External I2C alert:       %0d/1", i2c_alert_hits);
        $display("External CAN alert:       %0d/1", can_alert_hits);
        $display("HSM alert:                %0d/1", hsm_alert_hits);
        $display("Reset recovery:           %0d/1", reset_recovery_hits);
        $display("Locked write rejected:    %0d/1", locked_write_reject_hits);
        $display("CAN monitor fault lock:   %0d/1", can_fault_lock_hits);
        $display("SPI monitor fault lock:   %0d/1", spi_fault_lock_hits);
        $display("I2C monitor fault lock:   %0d/1", i2c_fault_lock_hits);

        if (spi_alert_hits != 1 ||
            i2c_alert_hits != 1 ||
            can_alert_hits != 1 ||
            hsm_alert_hits != 1 ||
            reset_recovery_hits != 1 ||
            locked_write_reject_hits != 1 ||
            can_fault_lock_hits != 1 ||
            spi_fault_lock_hits != 1 ||
            i2c_fault_lock_hits != 1) begin
            $display("FAIL: One or more required scenarios are missing");
            errors++;
        end

        $display("--------------------------------------------");
        $display("TOTAL TESTBENCH ERRORS: %0d", errors);

        if (errors == 0)
            $display("ALL NINE INTEGRATION TESTS PASSED");
        else
            $display("INTEGRATION TESTS FAILED");

        $display("============================================");

        #20;

        if (errors != 0)
            $fatal(1, "Integration testbench failed");

        $finish;
    end

    // Watchdog
    initial begin
        #10000;
        $fatal(1, "FATAL: Integration test timeout");
    end

endmodule
