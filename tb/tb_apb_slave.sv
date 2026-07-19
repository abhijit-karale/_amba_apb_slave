// -----------------------------------------------------------------------------
// Testbench   : tb_apb_slave
// Description : Directed + constrained-random self-checking testbench for
//               the APB slave. Drives full SETUP->ACCESS protocol sequences,
//               checks read-after-write data integrity and error-response
//               behavior on out-of-range addresses.
// Author      : Abhijit Karale
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_apb_slave;

    logic        pclk, presetn;
    logic        psel, penable, pwrite;
    logic [7:0]  paddr;
    logic [31:0] pwdata, prdata;
    logic        pready, pslverr;

    int pass_count = 0;
    int fail_count = 0;
    logic [31:0] shadow_reg [0:3]; // reference model of the 4 registers

    apb_slave dut (
        .pclk(pclk), .presetn(presetn),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .prdata(prdata),
        .pready(pready), .pslverr(pslverr)
    );

    initial pclk = 0;
    always #5 pclk = ~pclk;

    // APB write transaction: SETUP phase then ACCESS phase
    task automatic apb_write(input [7:0] addr, input [31:0] data);
        @(posedge pclk);
        psel = 1; penable = 0; pwrite = 1; paddr = addr; pwdata = data;
        @(posedge pclk);
        penable = 1;
        @(posedge pclk);
        while (!pready) @(posedge pclk);
        // Hold psel/penable through one more edge - this is the edge at which
        // the register file actually captures pwdata (state==ACCESS as sampled
        // going into this edge).
        @(posedge pclk);
        if (!pslverr && addr[3:2] < 4)
            shadow_reg[addr[3:2]] = data;
        psel = 0; penable = 0;
        @(posedge pclk);
    endtask

    // APB read transaction: SETUP phase then ACCESS phase, checks prdata
    task automatic apb_read(input [7:0] addr);
        logic [31:0] expected;
        @(posedge pclk);
        psel = 1; penable = 0; pwrite = 0; paddr = addr;
        @(posedge pclk);
        penable = 1;
        @(posedge pclk);
        while (!pready) @(posedge pclk);
        #1;
        if (addr[3:2] < 4 && addr <= 8'h0F) begin
            expected = shadow_reg[addr[3:2]];
            if (prdata !== expected) begin
                $error("[FAIL] Read mismatch @addr=%0h: expected=%0h got=%0h", addr, expected, prdata);
                fail_count++;
            end else begin
                $display("[PASS] Read @addr=%0h matches expected=%0h", addr, expected);
                pass_count++;
            end
        end
        psel = 0; penable = 0;
        @(posedge pclk);
    endtask

    task automatic apb_read_expect_error(input [7:0] addr);
        @(posedge pclk);
        psel = 1; penable = 0; pwrite = 0; paddr = addr;
        @(posedge pclk);
        penable = 1;
        @(posedge pclk);
        while (!pready) @(posedge pclk);
        #1;
        if (pslverr) begin
            $display("[PASS] pslverr correctly asserted for out-of-range addr=%0h", addr);
            pass_count++;
        end else begin
            $error("[FAIL] pslverr NOT asserted for out-of-range addr=%0h", addr);
            fail_count++;
        end
        psel = 0; penable = 0;
        @(posedge pclk);
    endtask

    initial begin
        $dumpfile("waveform/apb_slave.vcd");
        $dumpvars(0, tb_apb_slave);

        $display("=========================================================");
        $display(" AMBA-APB Slave Peripheral Testbench");
        $display("=========================================================");

        presetn = 0; psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0;
        repeat (3) @(posedge pclk);
        presetn = 1;
        @(posedge pclk);

        $display("[TEST] Directed: write then read-back all 4 registers");
        apb_write(8'h00, 32'hCAFEBABE);
        apb_write(8'h04, 32'h12345678);
        apb_write(8'h08, 32'hDEADC0DE);
        apb_write(8'h0C, 32'hA5A5A5A5);
        apb_read(8'h00);
        apb_read(8'h04);
        apb_read(8'h08);
        apb_read(8'h0C);

        $display("[TEST] Directed: out-of-range address returns PSLVERR");
        apb_read_expect_error(8'h20);
        apb_read_expect_error(8'hFF);

        $display("[TEST] Constrained-random write/read regression (200 transactions)");
        for (int i = 0; i < 200; i++) begin
            logic [1:0] reg_sel;
            logic [31:0] rand_data;
            reg_sel   = $urandom_range(0,3);
            rand_data = $urandom;
            apb_write({4'b0, reg_sel, 2'b00}, rand_data);
            apb_read({4'b0, reg_sel, 2'b00});
        end

        $display("=========================================================");
        $display(" REGRESSION SUMMARY: PASS=%0d  FAIL=%0d", pass_count, fail_count);
        if (fail_count == 0)
            $display(" RESULT: ALL TESTS PASSED");
        else
            $display(" RESULT: %0d TEST(S) FAILED", fail_count);
        $display("=========================================================");

        #20 $finish;
    end

endmodule
