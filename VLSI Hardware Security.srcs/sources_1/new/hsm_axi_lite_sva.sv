`timescale 1ns/1ps

module hsm_axi_lite_sva (
    input logic clk,
    input logic rst_n,

    // Write address channel
    input logic [31:0] awaddr,
    input logic awvalid,
    input logic awready,

    // Write data channel
    input logic [31:0] wdata,
    input logic [3:0] wstrb,
    input logic wvalid,
    input logic wready,

    // Write response channel
    input logic [1:0] bresp,
    input logic bvalid,
    input logic bready,

    // Read address channel
    input logic [31:0] araddr,
    input logic arvalid,
    input logic arready,

    // Read data channel
    input logic [31:0] rdata,
    input logic [1:0] rresp,
    input logic rvalid,
    input logic rready
);

    // ------------------------------------------------
    // 1. Write address must remain stable while stalled
    // ------------------------------------------------
    property p_aw_stable;
        @(posedge clk) disable iff (!rst_n)
        awvalid && !awready
        |=> awvalid && $stable(awaddr);
    endproperty

    assert property (p_aw_stable)
        else $error("AXI SVA FAIL: AW address changed while stalled");

    // ------------------------------------------------
    // 2. Write data must remain stable while stalled
    // ------------------------------------------------
    property p_w_stable;
        @(posedge clk) disable iff (!rst_n)
        wvalid && !wready
        |=> wvalid &&
            $stable(wdata) &&
            $stable(wstrb);
    endproperty

    assert property (p_w_stable)
        else $error("AXI SVA FAIL: W data changed while stalled");

    // ------------------------------------------------
    // 3. Write response must remain stable while stalled
    // ------------------------------------------------
    property p_b_stable;
        @(posedge clk) disable iff (!rst_n)
        bvalid && !bready
        |=> bvalid && $stable(bresp);
    endproperty

    assert property (p_b_stable)
        else $error("AXI SVA FAIL: B response changed while stalled");

    // ------------------------------------------------
    // 4. Read address must remain stable while stalled
    // ------------------------------------------------
    property p_ar_stable;
        @(posedge clk) disable iff (!rst_n)
        arvalid && !arready
        |=> arvalid && $stable(araddr);
    endproperty

    assert property (p_ar_stable)
        else $error("AXI SVA FAIL: AR address changed while stalled");

    // ------------------------------------------------
    // 5. Read data must remain stable while stalled
    // ------------------------------------------------
    property p_r_stable;
        @(posedge clk) disable iff (!rst_n)
        rvalid && !rready
        |=> rvalid &&
            $stable(rdata) &&
            $stable(rresp);
    endproperty

    assert property (p_r_stable)
        else $error("AXI SVA FAIL: R response changed while stalled");

    // ------------------------------------------------
    // 6. Address and data payloads must be known
    // ------------------------------------------------
    property p_aw_known;
        @(posedge clk) disable iff (!rst_n)
        awvalid |-> !$isunknown(awaddr);
    endproperty

    assert property (p_aw_known)
        else $error("AXI SVA FAIL: Unknown AW address");

    property p_w_known;
        @(posedge clk) disable iff (!rst_n)
        wvalid |-> !$isunknown({wdata,wstrb});
    endproperty

    assert property (p_w_known)
        else $error("AXI SVA FAIL: Unknown W data or strobe");

    property p_ar_known;
        @(posedge clk) disable iff (!rst_n)
        arvalid |-> !$isunknown(araddr);
    endproperty

    assert property (p_ar_known)
        else $error("AXI SVA FAIL: Unknown AR address");

    // ------------------------------------------------
    // 7. Response signals must be known when valid
    // ------------------------------------------------
    property p_bresp_known;
        @(posedge clk) disable iff (!rst_n)
        bvalid |-> !$isunknown(bresp);
    endproperty

    assert property (p_bresp_known)
        else $error("AXI SVA FAIL: Unknown B response");

    property p_rresp_known;
        @(posedge clk) disable iff (!rst_n)
        rvalid |-> !$isunknown({rdata,rresp});
    endproperty

    assert property (p_rresp_known)
        else $error("AXI SVA FAIL: Unknown R response");

    // ------------------------------------------------
    // 8. Reset clears response-valid signals
    // ------------------------------------------------
    property p_reset_response_clear;
        @(posedge clk)
        !rst_n |=> (!bvalid && !rvalid);
    endproperty

    assert property (p_reset_response_clear)
        else $error("AXI SVA FAIL: Response valid not cleared by reset");

    // ------------------------------------------------
    // Coverage properties
    // ------------------------------------------------
    cover property (
        @(posedge clk) disable iff (!rst_n)
        awvalid && awready
    );

    cover property (
        @(posedge clk) disable iff (!rst_n)
        wvalid && wready
    );

    cover property (
        @(posedge clk) disable iff (!rst_n)
        bvalid && bready
    );

    cover property (
        @(posedge clk) disable iff (!rst_n)
        arvalid && arready
    );

    cover property (
        @(posedge clk) disable iff (!rst_n)
        rvalid && rready
    );

endmodule