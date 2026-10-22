
`timescale 1ns/1ps

module tb_hsm_axi_lite_regs;

    // Clock and reset
    logic clk = 0;
    logic rst_n = 0;

    always #5 clk = ~clk;

    // AXI-Lite write address channel
    logic [31:0] s_axi_awaddr = 0;
    logic s_axi_awvalid = 0;
    wire s_axi_awready;

    // AXI-Lite write data channel
    logic [31:0] s_axi_wdata = 0;
    logic [3:0] s_axi_wstrb = 4'b1111;
    logic s_axi_wvalid = 0;
    wire s_axi_wready;

    // AXI-Lite write response channel
    wire [1:0] s_axi_bresp;
    wire s_axi_bvalid;
    logic s_axi_bready = 0;

    // AXI-Lite read address channel
    logic [31:0] s_axi_araddr = 0;
    logic s_axi_arvalid = 0;
    wire s_axi_arready;

    // AXI-Lite read data channel
    wire [31:0] s_axi_rdata;
    wire [1:0] s_axi_rresp;
    wire s_axi_rvalid;
    logic s_axi_rready = 0;

    // HSM inputs
    logic authenticated_i = 0;
    logic security_error_i = 0;
    logic external_lock_i = 0;
    logic engine_busy_i = 0;
    logic engine_done_i = 0;
    logic [31:0] nonce_count_i = 7;
    logic nonce_ready_i = 1;

    // HSM outputs
    wire engine_start_o;
    wire [31:0] key_slot_o;
    wire hsm_locked_o;
    wire security_event_o;

    integer errors = 0;
    logic start_seen = 0;

    // Capture the one-cycle start pulse
    always @(posedge clk) begin
        if (!rst_n)
            start_seen <= 0;
        else if (engine_start_o)
            start_seen <= 1;
    end

    // DUT
    hsm_axi_lite_regs dut (
        .clk(clk),
        .rst_n(rst_n),

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
        .security_error_i(security_error_i),
        .external_lock_i(external_lock_i),

        .engine_busy_i(engine_busy_i),
        .engine_done_i(engine_done_i),
        .nonce_count_i(nonce_count_i),
        .nonce_ready_i(nonce_ready_i),

        .engine_start_o(engine_start_o),
        .key_slot_o(key_slot_o),
        .hsm_locked_o(hsm_locked_o),
        .security_event_o(security_event_o)
    );

    // ------------------------------------------------
    // AXI-Lite write task
    // ------------------------------------------------
    task automatic axi_write(
        input logic [31:0] addr,
        input logic [31:0] data,
        output logic [1:0] response
    );
        integer timeout_count;
        bit aw_done;
        bit w_done;

        begin
            response = 2'b00;
            timeout_count = 0;
            aw_done = 0;
            w_done = 0;

            @(negedge clk);
            s_axi_awaddr  = addr;
            s_axi_awvalid = 1;
            s_axi_wdata   = data;
            s_axi_wstrb   = 4'b1111;
            s_axi_wvalid  = 1;
            s_axi_bready  = 0;

            while ((!aw_done || !w_done) &&
                   timeout_count < 30) begin
                @(posedge clk);

                if (s_axi_awvalid && s_axi_awready)
                    aw_done = 1;

                if (s_axi_wvalid && s_axi_wready)
                    w_done = 1;

                timeout_count = timeout_count + 1;

                @(negedge clk);

                if (aw_done)
                    s_axi_awvalid = 0;

                if (w_done)
                    s_axi_wvalid = 0;
            end

            s_axi_awvalid = 0;
            s_axi_wvalid  = 0;

            if (!aw_done || !w_done) begin
                $display("TIMEOUT: write address/data handshake");
                response = 2'bxx;
            end
            else begin
                timeout_count = 0;
                s_axi_bready = 1;

                while (!s_axi_bvalid && timeout_count < 30) begin
                    @(negedge clk);
                    timeout_count = timeout_count + 1;
                end

                if (s_axi_bvalid) begin
                    response = s_axi_bresp;
                    @(posedge clk);
                    @(negedge clk);
                end
                else begin
                    $display("TIMEOUT: write response");
                    response = 2'bxx;
                end

                s_axi_bready = 0;
            end
        end
    endtask

    // ------------------------------------------------
    // AXI-Lite channel-ordering write task
    // aw_first=1: AW handshake, then delayed W handshake
    // aw_first=0: W handshake, then delayed AW handshake
    // ------------------------------------------------
    task automatic axi_write_ordered(
        input logic [31:0] addr,
        input logic [31:0] data,
        input bit aw_first,
        output logic [1:0] response
    );
        integer timeout_count;
        bit aw_done;
        bit w_done;
        bit b_done;
        begin
            response = 2'bxx;
            aw_done = 0;
            w_done = 0;
            b_done = 0;
            timeout_count = 0;

            @(negedge clk);
            s_axi_bready = 0;
            s_axi_awvalid = 0;
            s_axi_wvalid = 0;
            s_axi_awaddr = addr;
            s_axi_wdata = data;
            s_axi_wstrb = 4'b1111;

            if (aw_first) begin
                // First: address channel only.
                s_axi_awvalid = 1;
                timeout_count = 0;
                while (!aw_done && timeout_count < 30) begin
                    @(posedge clk);
                    if (s_axi_awvalid && s_axi_awready)
                        aw_done = 1;
                    timeout_count = timeout_count + 1;
                    if (!aw_done)
                        @(negedge clk);
                end
                @(negedge clk);
                s_axi_awvalid = 0;

                // Leave a visible gap before sending write data.
                if (aw_done) begin
                    repeat (3) @(negedge clk);
                    s_axi_wvalid = 1;
                    timeout_count = 0;
                    while (!w_done && timeout_count < 30) begin
                        @(posedge clk);
                        if (s_axi_wvalid && s_axi_wready)
                            w_done = 1;
                        timeout_count = timeout_count + 1;
                        if (!w_done)
                            @(negedge clk);
                    end
                    @(negedge clk);
                    s_axi_wvalid = 0;
                end
            end
            else begin
                // First: write-data channel only.
                s_axi_wvalid = 1;
                timeout_count = 0;
                while (!w_done && timeout_count < 30) begin
                    @(posedge clk);
                    if (s_axi_wvalid && s_axi_wready)
                        w_done = 1;
                    timeout_count = timeout_count + 1;
                    if (!w_done)
                        @(negedge clk);
                end
                @(negedge clk);
                s_axi_wvalid = 0;

                // Leave a visible gap before sending the address.
                if (w_done) begin
                    repeat (3) @(negedge clk);
                    s_axi_awvalid = 1;
                    timeout_count = 0;
                    while (!aw_done && timeout_count < 30) begin
                        @(posedge clk);
                        if (s_axi_awvalid && s_axi_awready)
                            aw_done = 1;
                        timeout_count = timeout_count + 1;
                        if (!aw_done)
                            @(negedge clk);
                    end
                    @(negedge clk);
                    s_axi_awvalid = 0;
                end
            end

            s_axi_awvalid = 0;
            s_axi_wvalid = 0;

            if (aw_done && w_done) begin
                // Wait for and accept the write response.
                s_axi_bready = 1;
                timeout_count = 0;
                while (!b_done && timeout_count < 30) begin
                    @(posedge clk);
                    if (s_axi_bvalid && s_axi_bready) begin
                        response = s_axi_bresp;
                        b_done = 1;
                    end
                    timeout_count = timeout_count + 1;
                    if (!b_done)
                        @(negedge clk);
                end
                @(negedge clk);
                s_axi_bready = 0;
            end

            if (!aw_done || !w_done) begin
                $display("FAIL: ordered write channel handshake timeout (AW=%0b W=%0b)", aw_done, w_done);
                response = 2'bxx;
            end
            else if (!b_done) begin
                $display("FAIL: ordered write response timeout");
                response = 2'bxx;
            end
        end
    endtask

    // ------------------------------------------------
    // AXI-Lite read task
    // ------------------------------------------------
    task automatic axi_read(
        input logic [31:0] addr,
        output logic [31:0] data,
        output logic [1:0] response
    );
        integer timeout_count;

        begin
            data = 0;
            response = 2'b00;
            timeout_count = 0;

            @(negedge clk);
            s_axi_araddr  = addr;
            s_axi_arvalid = 1;
            s_axi_rready  = 0;

            while (!s_axi_arready && timeout_count < 30) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (!s_axi_arready) begin
                $display("TIMEOUT: read address handshake");
                response = 2'bxx;
                s_axi_arvalid = 0;
            end
            else begin
                @(posedge clk);
                @(negedge clk);
                s_axi_arvalid = 0;

                timeout_count = 0;
                s_axi_rready = 1;

                while (!s_axi_rvalid && timeout_count < 30) begin
                    @(negedge clk);
                    timeout_count = timeout_count + 1;
                end

                if (s_axi_rvalid) begin
                    data = s_axi_rdata;
                    response = s_axi_rresp;
                    @(posedge clk);
                    @(negedge clk);
                end
                else begin
                    $display("TIMEOUT: read data response");
                    response = 2'bxx;
                end

                s_axi_rready = 0;
            end
        end
    endtask

    // ------------------------------------------------
    // Test sequence
    // ------------------------------------------------
    logic [31:0] read_data;
    logic [1:0] response;
    logic [1:0] ordered_response;

    initial begin
        $display("");
        $display("======================================");
        $display("HSM AXI-Lite REGISTER AND BUS-RECOVERY TEST START");
        $display("======================================");

        // Reset
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        // TEST 1: Read version
        $display("TEST 1: Read version");
        axi_read(32'h18, read_data, response);

        if (response == 2'b00 && read_data == 32'h0001_0000)
            $display("PASS: version = %08h", read_data);
        else begin
            $display("FAIL: version=%08h response=%b",
                     read_data, response);
            errors = errors + 1;
        end

        // TEST 2: Read nonce counter
        $display("TEST 2: Read nonce counter");
        axi_read(32'h14, read_data, response);

        if (response == 2'b00 && read_data == 32'd7)
            $display("PASS: nonce = %0d", read_data);
        else begin
            $display("FAIL: nonce=%0d response=%b",
                     read_data, response);
            errors = errors + 1;
        end

        // TEST 3: Configure key-slot handle
        $display("TEST 3: Configure key-slot handle");
        authenticated_i = 1;
        axi_write(32'h10, 32'h0000_0009, response);

        if (response == 2'b00 && key_slot_o == 32'h0000_0009)
            $display("PASS: key-slot handle = %08h", key_slot_o);
        else begin
            $display("FAIL: key-slot=%08h response=%b",
                     key_slot_o, response);
            errors = errors + 1;
        end

        // TEST 4: AW arrives before W; verify next transaction also works
        $display("TEST 4: AW before W plus recovery");
        axi_write_ordered(32'h10, 32'h0000_0021, 1'b1, ordered_response);
        axi_read(32'h10, read_data, response);
        if (ordered_response == 2'b00 && response == 2'b00 &&
            read_data == 32'h0000_0021) begin
            $display("PASS: AW-first write completed and follow-up read succeeded");
        end
        else begin
            $display("FAIL: AW-first write/recovery: write_resp=%b read_resp=%b data=%08h",
                     ordered_response, response, read_data);
            errors = errors + 1;
        end

        // TEST 5: W arrives before AW; verify next transaction also works
        $display("TEST 5: W before AW plus recovery");
        axi_write_ordered(32'h10, 32'h0000_0022, 1'b0, ordered_response);
        axi_read(32'h10, read_data, response);
        if (ordered_response == 2'b00 && response == 2'b00 &&
            read_data == 32'h0000_0022) begin
            $display("PASS: W-first write completed and follow-up read succeeded");
        end
        else begin
            $display("FAIL: W-first write/recovery: write_resp=%b read_resp=%b data=%08h",
                     ordered_response, response, read_data);
            errors = errors + 1;
        end

        // TEST 6: Reject unauthenticated start
        $display("TEST 6: Reject unauthenticated start");
        authenticated_i = 0;
        start_seen = 0;
        axi_write(32'h00, 32'h0000_0001, response);
        repeat (2) @(negedge clk);

        if (!start_seen && !engine_start_o)
            $display("PASS: unauthenticated start rejected");
        else begin
            $display("FAIL: unauthenticated start was accepted");
            errors = errors + 1;
        end

        // TEST 7: Authenticated start
        $display("TEST 7: Authenticated start");
        authenticated_i = 1;
        start_seen = 0;
        axi_write(32'h00, 32'h0000_0001, response);
        repeat (2) @(negedge clk);

        if (response == 2'b00 && start_seen)
            $display("PASS: authenticated start pulse detected");
        else begin
            $display("FAIL: authenticated start pulse missing");
            errors = errors + 1;
        end

        // TEST 8: Security error causes lock
        $display("TEST 8: Security error causes lock");
        security_error_i = 1;
        @(negedge clk);
        @(negedge clk);
        security_error_i = 0;

        if (hsm_locked_o)
            $display("PASS: HSM locked");
        else begin
            $display("FAIL: HSM did not lock");
            errors = errors + 1;
        end

        // TEST 9: Reject key-slot write when locked
        $display("TEST 9: Reject key-slot write when locked");
        axi_write(32'h10, 32'h0000_0011, response);

        if (response == 2'b10)
            $display("PASS: expected SLVERR for locked key-slot write");
        else begin
            $display("FAIL: expected SLVERR, got %b", response);
            errors = errors + 1;
        end

        if (key_slot_o == 32'h0000_0022)
            $display("PASS: key-slot unchanged while locked");
        else begin
            $display("FAIL: key-slot changed: %08h", key_slot_o);
            errors = errors + 1;
        end

        // TEST 10: Read status
        $display("TEST 10: Read status");
        axi_read(32'h04, read_data, response);

        if (response == 2'b00)
            $display("STATUS = %08h", read_data);
        else begin
            $display("FAIL: status read response=%b", response);
            errors = errors + 1;
        end

        $display("--------------------------------------");
        if (errors == 0)
            $display("ALL 10 TESTS PASSED");
        else
            $display("TESTS FAILED: %0d error(s)", errors);
        $display("--------------------------------------");

        #20;
        $finish;
    end

    // Prevent a stuck simulation from running forever
    initial begin
        #10000;
        $display("FATAL: simulation timeout");
        $finish;
    end

endmodule
