
`timescale 1ns/1ps

module tb_hsm_register_bank;

    // Clock and reset
    logic clk;
    logic rst_n;

    // Register write interface
    logic        wr_en;
    logic [7:0]  wr_addr;
    logic [31:0] wr_data;

    // Register read interface
    logic [7:0]  rd_addr;
    logic [31:0] rd_data;

    // Security inputs
    logic auth_ok;
    logic crypto_busy;
    logic crypto_done;
    logic security_fault;
    logic [7:0] security_fault_code;

    // Security event inputs
    logic nonce_consume;
    logic event_valid;

    // HSM outputs
    logic hsm_enable;
    logic hsm_locked;
    logic crypto_start;
    logic [3:0] key_slot_sel;
    logic [63:0] nonce_counter;
    logic [31:0] event_count;

    // Register addresses
    localparam logic [7:0] SEC_CTRL_ADDR      = 8'h00;
    localparam logic [7:0] SEC_STATUS_ADDR    = 8'h04;
    localparam logic [7:0] SEC_FAULT_ADDR     = 8'h08;
    localparam logic [7:0] KEY_CTRL_ADDR      = 8'h0C;
    localparam logic [7:0] CRYPTO_CMD_ADDR    = 8'h10;
    localparam logic [7:0] CRYPTO_STATUS_ADDR = 8'h14;
    localparam logic [7:0] NONCE_LOW_ADDR     = 8'h18;
    localparam logic [7:0] NONCE_HIGH_ADDR    = 8'h1C;
    localparam logic [7:0] EVENT_COUNT_ADDR   = 8'h20;

    // DUT instantiation
    hsm_register_bank dut (
        .clk(clk),
        .rst_n(rst_n),

        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),

        .rd_addr(rd_addr),
        .rd_data(rd_data),

        .auth_ok(auth_ok),
        .crypto_busy(crypto_busy),
        .crypto_done(crypto_done),
        .security_fault(security_fault),
        .security_fault_code(security_fault_code),

        .nonce_consume(nonce_consume),
        .event_valid(event_valid),

        .hsm_enable(hsm_enable),
        .hsm_locked(hsm_locked),
        .crypto_start(crypto_start),
        .key_slot_sel(key_slot_sel),
        .nonce_counter(nonce_counter),
        .event_count(event_count)
    );

    // Clock generation: 100 MHz
    // Period = 10 ns
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Register write task
    task automatic write_register(
        input logic [7:0] address,
        input logic [31:0] data
    );
        begin
            @(negedge clk);
            wr_en   = 1'b1;
            wr_addr = address;
            wr_data = data;

            @(negedge clk);
            wr_en   = 1'b0;
            wr_addr = 8'h00;
            wr_data = 32'h0000_0000;
        end
    endtask

    // Register read task
    task automatic read_register(
        input logic [7:0] address
    );
        begin
            @(negedge clk);
            rd_addr = address;
            #1;
            $display(
                "READ address=0x%02h data=0x%08h",
                address, rd_data
            );
        end
    endtask

    // Testbench execution
    initial begin

        $display("-------------------------------------");
        $display(" HSM REGISTER BANK TEST STARTED");
        $display("-------------------------------------");

        // Initialize inputs
        rst_n = 1'b0;

        wr_en = 1'b0;
        wr_addr = 8'h00;
        wr_data = 32'h0000_0000;

        rd_addr = 8'h00;

        auth_ok = 1'b0;
        crypto_busy = 1'b0;
        crypto_done = 1'b0;

        security_fault = 1'b0;
        security_fault_code = 8'h00;

        nonce_consume = 1'b0;
        event_valid = 1'b0;

        // TEST 1: RESET
        $display("\nTEST 1: RESET");

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        @(negedge clk);

        if (hsm_enable == 0 &&
            hsm_locked == 0 &&
            nonce_counter == 0 &&
            event_count == 0)
            $display("PASS: Reset successful");
        else
            $error("FAIL: Reset test");

        // TEST 2: ENABLE HSM
        $display("\nTEST 2: ENABLE HSM");

        write_register(SEC_CTRL_ADDR, 32'h0000_0001);

        if (hsm_enable)
            $display("PASS: HSM enabled");
        else
            $error("FAIL: HSM enable");

        // TEST 3: AUTHENTICATED KEY SLOT SELECTION
        $display("\nTEST 3: KEY SLOT SELECTION");

        auth_ok = 1'b1;

        write_register(KEY_CTRL_ADDR, 32'h0000_0005);

        if (key_slot_sel == 4'h5)
            $display("PASS: Key slot 5 selected");
        else
            $error("FAIL: Key slot selection");

        // TEST 4: UNAUTHENTICATED KEY ACCESS
        $display("\nTEST 4: UNAUTHENTICATED KEY ACCESS");

        auth_ok = 1'b0;

        write_register(KEY_CTRL_ADDR, 32'h0000_0003);

        if (key_slot_sel == 4'h5)
            $display("PASS: Unauthorized key selection blocked");
        else
            $error("FAIL: Unauthorized key selection accepted");

        // TEST 5: VALID CRYPTO REQUEST
        $display("\nTEST 5: VALID CRYPTO REQUEST");

        auth_ok = 1'b1;

        write_register(CRYPTO_CMD_ADDR, 32'h0000_0001);

        if (crypto_start)
            $display("PASS: Crypto request accepted");
        else
            $error("FAIL: Crypto request");

        // TEST 6: CRYPTO BUSY BLOCK
        $display("\nTEST 6: CRYPTO BUSY BLOCK");

        crypto_busy = 1'b1;

        write_register(CRYPTO_CMD_ADDR, 32'h0000_0001);

        if (!crypto_start)
            $display("PASS: Request blocked while crypto busy");
        else
            $error("FAIL: Busy protection");

        crypto_busy = 1'b0;

        // TEST 7: SECURITY FAULT
        $display("\nTEST 7: SECURITY FAULT");

        security_fault = 1'b1;
        security_fault_code = 8'hA5;

        @(negedge clk);
        security_fault = 1'b0;

        read_register(SEC_FAULT_ADDR);

        if (rd_data[7:0] == 8'hA5)
            $display("PASS: Security fault captured");
        else
            $error("FAIL: Security fault capture");

        // TEST 8: FAULT CLEAR
        $display("\nTEST 8: FAULT CLEAR");

        write_register(SEC_FAULT_ADDR, 32'h0000_0001);

        read_register(SEC_FAULT_ADDR);

        if (rd_data[7:0] == 8'h00)
            $display("PASS: Fault cleared");
        else
            $error("FAIL: Fault clear");

        // TEST 9: NONCE COUNTER
        $display("\nTEST 9: NONCE COUNTER");

        nonce_consume = 1'b1;
        repeat (3) @(negedge clk);
        nonce_consume = 1'b0;

        if (nonce_counter == 64'd3)
            $display("PASS: Nonce counter = 3");
        else
            $error("FAIL: Nonce counter value = %0d",
                   nonce_counter);

        read_register(NONCE_LOW_ADDR);

        // TEST 10: EVENT COUNTER
        $display("\nTEST 10: SECURITY EVENT COUNTER");

        event_valid = 1'b1;
        repeat (4) @(negedge clk);
        event_valid = 1'b0;

        if (event_count == 32'd4)
            $display("PASS: Event count = 4");
        else
            $error("FAIL: Event count = %0d", event_count);

        read_register(EVENT_COUNT_ADDR);

        // TEST 11: STATUS REGISTER
        $display("\nTEST 11: HSM STATUS");

        crypto_done = 1'b1;
        read_register(SEC_STATUS_ADDR);

        if (rd_data[4] == 1'b1)
            $display("PASS: Crypto done status visible");
        else
            $error("FAIL: Crypto done status");

        crypto_done = 1'b0;

        // TEST 12: PERMANENT LOCK
        $display("\nTEST 12: HSM LOCK");

        write_register(SEC_CTRL_ADDR, 32'h0000_0002);

        if (hsm_locked)
            $display("PASS: HSM locked");
        else
            $error("FAIL: HSM lock");

        // Attempt to disable HSM after locking
        write_register(SEC_CTRL_ADDR, 32'h0000_0000);

        if (hsm_enable && hsm_locked)
            $display("PASS: Locked HSM control protected");
        else
            $error("FAIL: HSM changed after lock");

        // Final status
        $display("\n-------------------------------------");
        $display(" HSM REGISTER BANK TEST COMPLETED");
        $display("-------------------------------------");

        $display("HSM ENABLE   = %b", hsm_enable);
        $display("HSM LOCKED   = %b", hsm_locked);
        $display("KEY SLOT     = %h", key_slot_sel);
        $display("NONCE COUNT  = %0d", nonce_counter);
        $display("EVENT COUNT  = %0d", event_count);

        #20;
        $finish;

    end

endmodule
