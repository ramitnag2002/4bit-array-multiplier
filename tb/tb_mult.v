
`timescale 1ns/1ps

module tb_mult;

    reg clk;
    reg rst_n;
    reg [3:0] a, b;
    wire [7:0] p;

    integer i, j;
    integer errors;
    reg [7:0] expected;

    // Design Under Test
    mult_array dut (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .p(p)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        a = 0;
        b = 0;
        errors = 0;

        $dumpfile("mult.vcd");
        $dumpvars(0, tb_mult);

        // Hold reset low for two cycles
        repeat (2) @(negedge clk);
        rst_n = 1;

        // Exhaustive test: 16 x 16 = 256 vectors
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin

                @(negedge clk);
                a = i;
                b = j;
                expected = i * j;

                // Wait for two rising clock edges
                repeat (2) @(posedge clk);
                #2;

                if (p !== expected) begin
                    $display(
                        "Mismatch: a=%0d b=%0d p=%0d expected=%0d",
                        i, j, p, expected
                    );
                    errors = errors + 1;
                end

            end
        end

        if (errors == 0)
            $display("PASS: 256 vectors checked, 0 errors");
        else
            $display(
                "FAIL: 256 vectors checked, %0d errors",
                errors
            );

        $finish;
    end

endmodule

