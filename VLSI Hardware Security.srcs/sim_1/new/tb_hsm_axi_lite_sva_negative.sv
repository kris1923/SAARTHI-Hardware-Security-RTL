
`timescale 1ns / 1ps

module tb_hsm_axi_lite_sva_negative;

    logic clk;
    logic rst_n;

    // AXI Write Address Channel
    logic [31:0] awaddr;
    logic awvalid;
    logic awready;

    // AXI Write Data Channel
    logic [31:0] wdata;
    logic [3:0] wstrb;
    logic wvalid;
    logic wready;

    // AXI Write Response Channel
    logic [1:0] bresp;
    logic bvalid;
    logic bready;

    // AXI Read Address Channel
    logic [31:0] araddr;
    logic arvalid;
    logic arready;

    // AXI Read Data Channel
    logic [31:0] rdata;
    logic [1:0] rresp;
    logic rvalid;
    logic rready;

    integer test_count = 0;

    // 100 MHz clock
    always #5 clk = ~clk;


    // --------------------------------------------------
    // SVA CHECKER
    // --------------------------------------------------

    hsm_axi_lite_sva sva (

        .clk     (clk),
        .rst_n   (rst_n),

        .awaddr  (awaddr),
        .awvalid (awvalid),
        .awready (awready),

        .wdata   (wdata),
        .wstrb   (wstrb),
        .wvalid  (wvalid),
        .wready  (wready),

        .bresp   (bresp),
        .bvalid  (bvalid),
        .bready  (bready),

        .araddr  (araddr),
        .arvalid (arvalid),
        .arready (arready),

        .rdata   (rdata),
        .rresp   (rresp),
        .rvalid  (rvalid),
        .rready  (rready)
    );


    // --------------------------------------------------
    // RESET TASK
    // --------------------------------------------------

    task automatic reset_signals;

        begin

            @(negedge clk);

            rst_n = 1'b0;

            awaddr  = 32'd0;
            awvalid = 1'b0;
            awready = 1'b0;

            wdata   = 32'd0;
            wstrb   = 4'b0000;
            wvalid  = 1'b0;
            wready  = 1'b0;

            bresp  = 2'b00;
            bvalid = 1'b0;
            bready = 1'b0;

            araddr  = 32'd0;
            arvalid = 1'b0;
            arready = 1'b0;

            rdata  = 32'd0;
            rresp  = 2'b00;
            rvalid = 1'b0;
            rready = 1'b0;

            repeat (2) @(negedge clk);

            rst_n = 1'b1;

            repeat (2) @(negedge clk);

        end

    endtask


    // --------------------------------------------------
    // TEST 1: AWADDR CHANGES WHILE STALLED
    // --------------------------------------------------

    task automatic test_awaddr_violation;

        begin

            $display("\nTEST 1: AWADDR stability violation");

            reset_signals();

            awaddr  = 32'h00000010;
            awvalid = 1'b1;
            awready = 1'b0;

            // First sample: address is stalled
            @(posedge clk);

            // Change address before next sample
            @(negedge clk);

            awaddr = 32'h00000020;

            @(posedge clk);

            $display("EXPECTED: AW address stability assertion should fail");

            test_count = test_count + 1;

            @(negedge clk);

            awvalid = 1'b0;

        end

    endtask


    // --------------------------------------------------
    // TEST 2: WDATA CHANGES WHILE STALLED
    // --------------------------------------------------

    task automatic test_wdata_violation;

        begin

            $display("\nTEST 2: WDATA stability violation");

            reset_signals();

            wdata  = 32'h12345678;
            wstrb  = 4'b1111;
            wvalid = 1'b1;
            wready = 1'b0;

            // First sample: data is stalled
            @(posedge clk);

            // Change data before next sample
            @(negedge clk);

            wdata = 32'h87654321;

            @(posedge clk);

            $display("EXPECTED: WDATA stability assertion should fail");

            test_count = test_count + 1;

            @(negedge clk);

            wvalid = 1'b0;

        end

    endtask


    // --------------------------------------------------
    // TEST 3: BRESP CHANGES WHILE STALLED
    // --------------------------------------------------

    task automatic test_bresp_violation;

        begin

            $display("\nTEST 3: BRESP stability violation");

            reset_signals();

            bresp  = 2'b00;
            bvalid = 1'b1;
            bready = 1'b0;

            // First sample: response is stalled
            @(posedge clk);

            // Change response before next sample
            @(negedge clk);

            bresp = 2'b10;

            @(posedge clk);

            $display("EXPECTED: BRESP stability assertion should fail");

            test_count = test_count + 1;

            @(negedge clk);

            bvalid = 1'b0;

        end

    endtask


    // --------------------------------------------------
    // TEST 4: RDATA CHANGES WHILE STALLED
    // --------------------------------------------------

    task automatic test_rdata_violation;

        begin

            $display("\nTEST 4: RDATA stability violation");

            reset_signals();

            rdata  = 32'hAABBCCDD;
            rresp  = 2'b00;
            rvalid = 1'b1;
            rready = 1'b0;

            // First sample: read data is stalled
            @(posedge clk);

            // Change data before next sample
            @(negedge clk);

            rdata = 32'h11223344;

            @(posedge clk);

            $display("EXPECTED: RDATA stability assertion should fail");

            test_count = test_count + 1;

            @(negedge clk);

            rvalid = 1'b0;

        end

    endtask


    // --------------------------------------------------
    // MAIN TEST SEQUENCE
    // --------------------------------------------------

    initial begin

        clk = 1'b0;
        rst_n = 1'b0;

        awaddr = 0;
        awvalid = 0;
        awready = 0;

        wdata = 0;
        wstrb = 0;
        wvalid = 0;
        wready = 0;

        bresp = 0;
        bvalid = 0;
        bready = 0;

        araddr = 0;
        arvalid = 0;
        arready = 0;

        rdata = 0;
        rresp = 0;
        rvalid = 0;
        rready = 0;

        test_count = 0;

        $display("\n========================================");
        $display(" HSM AXI-LITE NEGATIVE SVA TEST START");
        $display("========================================");

        test_awaddr_violation();

        test_wdata_violation();

        test_bresp_violation();

        test_rdata_violation();

        reset_signals();

        $display("\n========================================");
        $display(" NEGATIVE TEST SEQUENCE COMPLETED");
        $display("========================================");

        $display("Injected violations: %0d", test_count);

        $display("Check the simulator log for four expected");
        $display("AXI SVA assertion failures.");

        $display("========================================\n");

        $finish;

    end


    // Simulation timeout
    initial begin

        #10000;

        $display("ERROR: Simulation timeout");

        $finish;

    end

endmodule
