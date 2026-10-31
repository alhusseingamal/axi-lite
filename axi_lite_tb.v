module axi_lite_tb;
    // Parameters
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    logic clk;
    logic rst_n;

    // AXI Lite signals
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [DATA_WIDTH-1:0] wdata;
    logic [3:0] wstrb;
    logic awvalid;
    logic wvalid;
    logic bready;
    
    logic [ADDR_WIDTH-1:0] araddr;
    logic arvalid;
    logic rready;
    logic rvalid;
    logic arready;
    
    logic awready;
    logic wready;
    logic bvalid;
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0] rresp;
    logic [1:0] bresp;
    logic [DATA_WIDTH-1:0] read_data;
    logic [DATA_WIDTH-1:0] expected_data;

    // DUT
    axi_lite #(
        .C_S_AXI_ADDR_WIDTH(ADDR_WIDTH),
        .C_S_AXI_DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .s_axi_aclk(clk),
        .s_axi_aresetn(rst_n),
        
        .s_axi_awaddr(awaddr),
        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_awvalid(awvalid),
        .s_axi_wvalid(wvalid),
        .s_axi_bready(bready),
        
        .s_axi_araddr(araddr),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rready(rready),
        
        .s_axi_awready(awready),
        .s_axi_wready(wready),
        .s_axi_bvalid(bvalid),
        .s_axi_bresp(bresp),
        
        .s_axi_rdata(rdata),
        .s_axi_rvalid(rvalid),
        .s_axi_rresp(rresp)
    );

    localparam T  = 10ns;
    
    localparam TA = 1ns;
    // this represents a small stimulus application delay after posedge clk
    // physically, it corresponds to a clock-to-output delay
    // previously, race conditions happened. By using TA, the testbench drive signals change shortly after 
    // posedge clk rather than simultaneously with it to prevent simulation race conditions with the DUT and SVA.



    initial begin
        clk = 0;
        forever #(T/2) clk = ~clk;
    end

    initial begin
        rst_n   = 1'b0;
        awvalid = 1'b0;
        wvalid  = 1'b0;
        bready  = 1'b0;
        arvalid = 1'b0;
        rready  = 1'b0;
        awaddr  = '0;
        wdata   = '0;
        wstrb   = '0;
        araddr  = '0;
        #(2*T);
        rst_n   = 1'b1;
    end

    
    
    
    
    
    
    
    
    // SVA - AXI-Lite Protocol

    // Reset check: slave valid/ready outputs must be low right after reset
    property p_reset_outputs;
        @(posedge clk) !rst_n |=> (!awready && !wready && !bvalid && !arready && !rvalid);
    endproperty
    a_reset_outputs: assert property (p_reset_outputs)
        else $error("[SVA] Slave outputs not cleared after reset!");

    // Handshake persistence: Once VALID is asserted without READY, it must stay HIGH
    //    and payload must remain stable until handshake occurs.
    property p_bvalid_stable;
        @(posedge clk) disable iff (!rst_n)
        (bvalid && !bready) |=> (bvalid && $stable(bresp));
    endproperty
    a_bvalid_stable: assert property (p_bvalid_stable)
        else $error("[SVA] bvalid dropped or bresp changed before bready!");

    property p_rvalid_stable;
        @(posedge clk) disable iff (!rst_n)
        (rvalid && !rready) |=> (rvalid && $stable(rdata) && $stable(rresp));
    endproperty
    a_rvalid_stable: assert property (p_rvalid_stable)
        else $error("[SVA] rvalid dropped or rdata/rresp changed before rready!");

    // Master stability checks (verifies TB driver tasks obey AXI rules too)
    property p_awvalid_stable;
        @(posedge clk) disable iff (!rst_n)
        (awvalid && !awready) |=> (awvalid && $stable(awaddr));
    endproperty
    a_awvalid_stable: assert property (p_awvalid_stable)
        else $error("[SVA] TB bug: awvalid/awaddr unstable before awready!");

    property p_wvalid_stable;
        @(posedge clk) disable iff (!rst_n)
        (wvalid && !wready) |=> (wvalid && $stable(wdata) && $stable(wstrb));
    endproperty
    a_wvalid_stable: assert property (p_wvalid_stable)
        else $error("[SVA] TB bug: wvalid/wdata unstable before wready!");

    property p_arvalid_stable;
        @(posedge clk) disable iff (!rst_n)
        (arvalid && !arready) |=> (arvalid && $stable(araddr));
    endproperty
    a_arvalid_stable: assert property (p_arvalid_stable)
        else $error("[SVA] TB bug: arvalid/araddr unstable before arready!");

    // Handshake completion: bvalid / rvalid should deassert the cycle after handshake
    a_bvalid_clear: assert property (@(posedge clk) disable iff (!rst_n) (bvalid && bready) |=> !bvalid)
        else $error("[SVA] bvalid did not clear after handshake!");

    a_rvalid_clear: assert property (@(posedge clk) disable iff (!rst_n) (rvalid && rready) |=> !rvalid)
        else $error("[SVA] rvalid did not clear after handshake!");

    // Single-cycle ready pulses (design-specific check as I chose single-cycle pulses)
    a_awready_pulse: assert property (@(posedge clk) disable iff (!rst_n) awready |=> !awready)
        else $error("[SVA] awready was high for more than 1 cycle");

    a_wready_pulse:  assert property (@(posedge clk) disable iff (!rst_n) wready  |=> !wready)
        else $error("[SVA] wready was high for more than 1 cycle");

    a_arready_pulse: assert property (@(posedge clk) disable iff (!rst_n) arready |=> !arready)
        else $error("[SVA] arready was high for more than 1 cycle");

    // No X/Z on control lines or valid read data
    a_no_x_ctrl: assert property (@(posedge clk) disable iff (!rst_n)
        !$isunknown({awvalid, awready, wvalid, wready, bvalid, bready, arvalid, arready, rvalid, rready}))
        else $error("[SVA] Unknown (X/Z) detected on handshake signals!");

    a_no_x_rdata: assert property (@(posedge clk) disable iff (!rst_n)
        rvalid |-> !$isunknown({rdata, rresp}))
        else $error("[SVA] Unknown (X/Z) on rdata/rresp when rvalid is HIGH!");

    // Cover properties
    c_write_handshake:     cover property (@(posedge clk) disable iff (!rst_n) bvalid && bready);
    c_read_handshake:      cover property (@(posedge clk) disable iff (!rst_n) rvalid && rready);
    c_bvalid_backpressure: cover property (@(posedge clk) disable iff (!rst_n) bvalid && !bready);
    c_rvalid_backpressure: cover property (@(posedge clk) disable iff (!rst_n) rvalid && !rready);

    
    
    
    
    
    
    
    
    
    
    // Driver Tasks (sample on posedge clk, drive after #TA)

    task automatic axi_lite_write(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data,
        input logic [3:0] strb,
        input integer bready_delay,
        input integer write_id
    );
        @(posedge clk);
        #TA;
        $display("Write %0d: Issued at time: %0t", write_id, $time);
        awaddr  = addr;
        wdata   = data;
        wstrb   = strb;
        awvalid = 1'b1;
        wvalid  = 1'b1;
        bready  = (bready_delay == 0) ? 1'b1 : 1'b0;

        // wait for AW and W handshakes independently on posedge clk
        fork
            begin
                do @(posedge clk); while (!(awvalid && awready));
                #TA;
                awvalid = 1'b0;
            end
            begin
                do @(posedge clk); while (!(wvalid && wready));
                #TA;
                wvalid = 1'b0;
            end
        join

        // msut wait for posedge when slave asserts bvalid
        do @(posedge clk); while (!bvalid);

        // if bready wasn't already high, hold off for bready_delay cycles to test backpressure
        if (!bready) begin
            if (bready_delay > 1)
                repeat (bready_delay - 1) @(posedge clk);
            #TA;
            bready = 1'b1;
            @(posedge clk); // let the (bvalid && bready) handshake occur on posedge
        end

        #TA; // wait past posedge before dropping bready so DUT sees bready == 1
        bready = 1'b0;
        $display("Write %0d: Finished at time: %0t", write_id, $time);
    endtask

    task automatic axi_lite_read(
        input logic [ADDR_WIDTH-1:0] addr,
        output logic [DATA_WIDTH-1:0] data,
        input integer rready_delay,
        input integer read_id
    );
        @(posedge clk);
        #TA;
        $display("Read %0d: Issued at time: %0t", read_id, $time);
        araddr  = addr;
        arvalid = 1'b1;
        rready  = (rready_delay == 0) ? 1'b1 : 1'b0;

        // wait for AR handshake
        do @(posedge clk); while (!(arvalid && arready));
        #TA;
        arvalid = 1'b0;

        // wait until slave asserts rvalid
        do @(posedge clk); while (!rvalid);

        if (!rready) begin
            if (rready_delay > 1)
                repeat (rready_delay - 1) @(posedge clk);
            #TA;
            rready = 1'b1;
            @(posedge clk); // handshake posedge where (rvalid && rready) == 1
        end

        data = rdata; // sample rdata right at the handshake posedge
        #TA;
        rready = 1'b0;
        $display("Read %0d: Finished at time: %0t", read_id, $time);
    endtask


    integer write_count, read_count;
    initial begin
        write_count = 0;
        read_count = 0;
    end

    
    
    
    
    
    
    
    
    
    // Test sequence
    // todo later: extend with automatic testcase generation rather than the fixed tests
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, axi_lite_tb);
        read_data = 0;
        expected_data = 0;
        
        @(posedge rst_n);

        $display("--- Starting AXI Lite Slave Tests ---");
        
        // Test 1: Normal Write and Read (bready/rready are immediately high)
        axi_lite_write(32'h0000_0000, 32'hE10108A7, 4'b1111, 0, ++write_count);
        axi_lite_write(32'h0000_0000, 32'hDEADBEEF, 4'b1111, 0, ++write_count);
        
        expected_data = 32'hDEADBEEF;
        axi_lite_read(32'h0000_0000, read_data, 0, ++read_count);
        axi_lite_read(32'h0000_0000, read_data, 0, ++read_count);
        assert(read_data == expected_data)
            $display("Test 1 Passed: Write/Read verified");
        else begin
            $error("Test 1 Failed: Expected %h, got %h", expected_data, read_data);
            $finish;
        end

        #20ns;

        // Test 2: Byte-level writes + 3-cycle backpressure (this exercises SVA stability)
        axi_lite_write(32'h0000_001C, 32'hFACEFFFF, 4'b1100, 3, ++write_count);
        
        axi_lite_read(32'h0000_001C, read_data, 3, ++read_count);
        expected_data = 32'hFACE0000;
        assert(read_data == expected_data)
            $display("Test 2 Passed: Byte-write & backpressure verified");
        else begin
            $error("Test 2 Failed: Expected %h, got %h", expected_data, read_data);
            $finish;
        end

        // Test 3: Staggered AW and W channels (AW arrives 2 cycles before W)
        @(posedge clk);
        #TA;
        $display("Test 3: Staggered write channels");
        awaddr  = 32'h0000_0004;
        awvalid = 1'b1;
        do @(posedge clk); while (!(awvalid && awready));
        #TA;
        awvalid = 1'b0;

        repeat (2) @(posedge clk);
        #TA;
        wdata  = 32'h1234_5678;
        wstrb  = 4'b1111;
        wvalid = 1'b1;
        do @(posedge clk); while (!(wvalid && wready));
        #TA;
        wvalid = 1'b0;

        do @(posedge clk); while (!bvalid);
        #TA;
        bready = 1'b1;
        @(posedge clk);
        #TA;
        bready = 1'b0;

        axi_lite_read(32'h0000_0004, read_data, 1, ++read_count);
        assert(read_data == 32'h1234_5678)
            $display("Test 3 Passed: Staggered AW/W verified");
        else begin
            $error("Test 3 Failed: Expected 12345678, got %h", read_data);
            $finish;
        end

        #20ns;
        $display("All tests completed successfully!");
        $finish;
    end

endmodule