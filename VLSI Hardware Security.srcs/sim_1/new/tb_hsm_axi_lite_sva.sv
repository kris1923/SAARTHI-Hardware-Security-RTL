
`timescale 1ns / 1ps

module tb_hsm_axi_lite_sva;

    // --------------------------------------------------
    // CLOCK AND RESET
    // --------------------------------------------------

    logic clk;
    logic rst_n;

    // --------------------------------------------------
    // HSM INPUT SIGNALS
    // --------------------------------------------------

    logic authenticated_i;
    logic security_error_i;
    logic external_lock_i;
    logic engine_busy_i;
    logic engine_done_i;
    logic [31:0] nonce_count_i;
    logic nonce_ready_i;

    // --------------------------------------------------
    // HSM OUTPUT SIGNALS
    // --------------------------------------------------

    wire engine_start_o;
    wire [31:0] key_slot_o;
    wire hsm_locked_o;
    wire security_event_o;

    // --------------------------------------------------
    // AXI4-LITE WRITE ADDRESS CHANNEL
    // Address width: 32 bits
    // --------------------------------------------------

    logic [31:0] s_axi_awaddr;
    logic s_axi_awvalid;
    wire s_axi_awready;

    // --------------------------------------------------
    // AXI4-LITE WRITE DATA CHANNEL
    // --------------------------------------------------

    logic [31:0] s_axi_wdata;
    logic [3:0] s_axi_wstrb;
    logic s_axi_wvalid;
    wire s_axi_wready;

    // --------------------------------------------------
    // AXI4-LITE WRITE RESPONSE CHANNEL
    // --------------------------------------------------

    wire [1:0] s_axi_bresp;
    wire s_axi_bvalid;
    logic s_axi_bready;

    // --------------------------------------------------
    // AXI4-LITE READ ADDRESS CHANNEL
    // Address width: 32 bits
    // --------------------------------------------------

    logic [31:0] s_axi_araddr;
    logic s_axi_arvalid;
    wire s_axi_arready;

    // --------------------------------------------------
    // AXI4-LITE READ DATA CHANNEL
    // --------------------------------------------------

    wire [31:0] s_axi_rdata;
    wire [1:0] s_axi_rresp;
    wire s_axi_rvalid;
    logic s_axi_rready;

    integer errors = 0;

    logic [31:0] read_value;


    // --------------------------------------------------
    // CLOCK GENERATION
    // 100 MHz = 10 ns period
    // --------------------------------------------------

    always #5 clk = ~clk;


    // --------------------------------------------------
    // DUT: HSM AXI4-LITE REGISTER MODULE
    // --------------------------------------------------

    hsm_axi_lite_regs dut (

        .clk              (clk),
        .rst_n            (rst_n),

        .s_axi_awaddr     (s_axi_awaddr),
        .s_axi_awvalid    (s_axi_awvalid),
        .s_axi_awready    (s_axi_awready),

        .s_axi_wdata      (s_axi_wdata),
        .s_axi_wstrb      (s_axi_wstrb),
        .s_axi_wvalid     (s_axi_wvalid),
        .s_axi_wready     (s_axi_wready),

        .s_axi_bresp      (s_axi_bresp),
        .s_axi_bvalid     (s_axi_bvalid),
        .s_axi_bready     (s_axi_bready),

        .s_axi_araddr     (s_axi_araddr),
        .s_axi_arvalid    (s_axi_arvalid),
        .s_axi_arready    (s_axi_arready),

        .s_axi_rdata      (s_axi_rdata),
        .s_axi_rresp      (s_axi_rresp),
        .s_axi_rvalid     (s_axi_rvalid),
        .s_axi_rready     (s_axi_rready),

        .authenticated_i  (authenticated_i),
        .security_error_i (security_error_i),
        .external_lock_i  (external_lock_i),
        .engine_busy_i    (engine_busy_i),
        .engine_done_i    (engine_done_i),
        .nonce_count_i    (nonce_count_i),
        .nonce_ready_i    (nonce_ready_i),

        .engine_start_o   (engine_start_o),
        .key_slot_o       (key_slot_o),
        .hsm_locked_o     (hsm_locked_o),
        .security_event_o (security_event_o)
    );


    // --------------------------------------------------
    // SVA CHECKER
    // --------------------------------------------------

    hsm_axi_lite_sva sva (

        .clk      (clk),
        .rst_n    (rst_n),

        .awaddr   (s_axi_awaddr),
        .awvalid  (s_axi_awvalid),
        .awready  (s_axi_awready),

        .wdata    (s_axi_wdata),
        .wstrb    (s_axi_wstrb),
        .wvalid   (s_axi_wvalid),
        .wready   (s_axi_wready),

        .bresp    (s_axi_bresp),
        .bvalid   (s_axi_bvalid),
        .bready   (s_axi_bready),

        .araddr   (s_axi_araddr),
        .arvalid  (s_axi_arvalid),
        .arready  (s_axi_arready),

        .rdata    (s_axi_rdata),
        .rresp    (s_axi_rresp),
        .rvalid   (s_axi_rvalid),
        .rready   (s_axi_rready)
    );


    // --------------------------------------------------
    // AXI WRITE TASK
    // --------------------------------------------------

    task automatic axi_write(
        input logic [31:0] address,
        input logic [31:0] data
    );

        bit aw_done;
        bit w_done;

        begin

            aw_done = 0;
            w_done  = 0;

            @(negedge clk);

            s_axi_awaddr  = address;
            s_axi_awvalid = 1'b1;

            s_axi_wdata   = data;
            s_axi_wstrb   = 4'b1111;
            s_axi_wvalid  = 1'b1;

            // Wait for both address and data handshakes

            while (!aw_done || !w_done) begin

                @(posedge clk);

                if (s_axi_awvalid && s_axi_awready)
                    aw_done = 1;

                if (s_axi_wvalid && s_axi_wready)
                    w_done = 1;

                @(negedge clk);

                if (aw_done)
                    s_axi_awvalid = 1'b0;

                if (w_done)
                    s_axi_wvalid = 1'b0;

            end

            // Hold BREADY low to create response backpressure

            s_axi_bready = 1'b0;

            repeat (3) begin

                @(negedge clk);

                if (!s_axi_bvalid) begin
                    $display("FAIL: BVALID not asserted");
                    errors = errors + 1;
                end

            end

            if (s_axi_bvalid)
                $display("PASS: B response held during backpressure");

            // Accept write response

            s_axi_bready = 1'b1;

            do begin
                @(posedge clk);
            end while (!s_axi_bvalid);

            @(negedge clk);

            s_axi_bready = 1'b0;

        end

    endtask


    // --------------------------------------------------
    // AXI READ TASK
    // --------------------------------------------------

    task automatic axi_read(
        input logic [31:0] address,
        output logic [31:0] read_data
    );

        begin

            @(negedge clk);

            s_axi_araddr  = address;
            s_axi_arvalid = 1'b1;

            // Wait for address acceptance

            do begin
                @(posedge clk);
            end while (!s_axi_arready);

            @(negedge clk);

            s_axi_arvalid = 1'b0;

            // Hold RREADY low to create response backpressure

            s_axi_rready = 1'b0;

            repeat (3) begin

                @(negedge clk);

                if (!s_axi_rvalid) begin
                    $display("FAIL: RVALID not asserted");
                    errors = errors + 1;
                end

            end

            if (s_axi_rvalid)
                $display("PASS: R response held during backpressure");

            read_data = s_axi_rdata;

            // Accept read response

            s_axi_rready = 1'b1;

            do begin
                @(posedge clk);
            end while (!s_axi_rvalid);

            @(negedge clk);

            s_axi_rready = 1'b0;

        end

    endtask


    // --------------------------------------------------
    // MAIN TEST SEQUENCE
    // --------------------------------------------------

    initial begin

        // Initialize clock and reset

        clk   = 1'b0;
        rst_n = 1'b0;

        // Initialize HSM inputs

        authenticated_i  = 1'b0;
        security_error_i = 1'b0;
        external_lock_i  = 1'b0;
        engine_busy_i    = 1'b0;
        engine_done_i    = 1'b0;

        nonce_count_i = 32'd0;
        nonce_ready_i = 1'b0;

        // Initialize AXI write signals

        s_axi_awaddr  = 32'd0;
        s_axi_awvalid = 1'b0;

        s_axi_wdata   = 32'd0;
        s_axi_wstrb   = 4'b0000;
        s_axi_wvalid  = 1'b0;

        s_axi_bready  = 1'b0;

        // Initialize AXI read signals

        s_axi_araddr  = 32'd0;
        s_axi_arvalid = 1'b0;

        s_axi_rready = 1'b0;

        errors = 0;

        $display("\n========================================");
        $display(" HSM AXI-LITE SVA VERIFICATION START");
        $display("========================================");


        // --------------------------------------------------
        // RESET
        // --------------------------------------------------

        repeat (3) @(negedge clk);

        rst_n = 1'b1;

        repeat (2) @(negedge clk);

        authenticated_i = 1'b1;

        nonce_count_i = 32'd7;
        nonce_ready_i = 1'b1;


        // --------------------------------------------------
        // TEST 1: AXI WRITE TRANSACTION
        // --------------------------------------------------

        $display("\nTEST 1: AXI write transaction");

        // Write key slot value 5 at address 0x10

        axi_write(32'h00000010, 32'd5);

        if (key_slot_o == 32'd5) begin

            $display("PASS: Key slot write");

        end
        else begin

            $display("FAIL: Key slot write. Actual = %h", key_slot_o);

            errors = errors + 1;

        end


        // --------------------------------------------------
        // TEST 2: AXI READ TRANSACTION
        // --------------------------------------------------

        $display("\nTEST 2: AXI read transaction");

        // Nonce status register address = 0x14

        axi_read(32'h00000014, read_value);

        if (read_value == 32'd7) begin

            $display("PASS: Nonce read = %h", read_value);

        end
        else begin

            $display("FAIL: Nonce read = %h", read_value);

            errors = errors + 1;

        end


        // --------------------------------------------------
        // TEST 3: WRITE ADDRESS CHANNEL HANDSHAKE
        // --------------------------------------------------

        $display("\nTEST 3: Write address channel");

        @(negedge clk);

        s_axi_awaddr  = 32'h00000010;
        s_axi_awvalid = 1'b1;

        // Keep address and valid stable until accepted

        do begin
            @(posedge clk);
        end while (!s_axi_awready);

        @(negedge clk);

        s_axi_awvalid = 1'b0;

        $display("PASS: AW address accepted");


        // --------------------------------------------------
        // TEST 4: RESET RESPONSE STATE
        // --------------------------------------------------

        $display("\nTEST 4: Reset response state");

        @(negedge clk);

        rst_n = 1'b0;

        s_axi_awvalid = 1'b0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;

        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        repeat (2) @(negedge clk);

        if (!s_axi_bvalid && !s_axi_rvalid) begin

            $display("PASS: Response valid signals cleared");

        end
        else begin

            $display("FAIL: Response valid signals not cleared");

            errors = errors + 1;

        end


        // --------------------------------------------------
        // FINAL RESULT
        // --------------------------------------------------

        $display("\n========================================");

        if (errors == 0) begin

            $display("ALL TESTS PASSED");
            $display("HSM AXI-LITE SVA TEST SUCCESSFUL");

        end
        else begin

            $display("SVA TEST FAILED: %0d errors", errors);

        end

        $display("========================================\n");

        $finish;

    end


    // --------------------------------------------------
    // SIMULATION TIMEOUT
    // --------------------------------------------------

    initial begin

        #10000;

        $display("ERROR: Simulation timeout");

        $finish;

    end

endmodule
